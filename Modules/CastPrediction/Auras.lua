-- UsefulPlatesAndTooltips module CastPrediction: the aura-driven modifiers a damage cast sees --
-- buffs on the player and debuffs on the target that the spell description does NOT hold.
-- Curated from the research (BattleInfoTool-audits/castprediction-research/10- and 30-):
--   * Arcane Power (12042) +30% damage, Power Infusion (10060) +20% damage -- player buffs,
--   * Arcane Blast stacks (400573) +10% per stack to OTHER spells, max 4 -- player buff,
--   * Improved Scorch (22959) +3% per stack fire taken from you, max 5 -- target debuff,
--   * Curse of the Elements (11722) +10% fire and frost taken -- target debuff (the Forever
--     version is said to cover all magic schools; marked verify until read in game).
--
-- WoW: Forever hides auras in combat, so there these modifiers only ever apply out of combat
-- (the hit calibration carries the in-combat effect instead); an unreadable aura is never
-- treated as absent, it just adds nothing. Retail reads auras normally. Every entry can be
-- switched off in the settings; /upt castpred auras prints what is readable right now.
local _, BIT = ...
local ns = BIT.Module("CastPrediction")

local Auras = {}
ns.Auras = Auras

local MAGIC = { fire = true, frost = true, frostfire = true, arcane = true, shadow = true, nature = true, holy = true }

-- ids: the aura's own spell ids. names: fallback when the client reports no id (English first).
-- percent: a flat multiplier (0.30 = +30%). perStack/maxStacks: per application, capped.
-- notSpells: the aura never applies to these casts (Arcane Blast's own stacks, on Arcane Blast).
-- verify: the magnitude or the school list still needs a live read; never applied until then.
Auras.LIST = {
    { key = "PLAYER_ARCANE_POWER", en = "Arcane Power", unit = "player",
        ids = { 12042 }, names = { "Arcane Power" }, percent = 0.30, schools = MAGIC },
    { key = "PLAYER_POWER_INFUSION", en = "Power Infusion", unit = "player",
        ids = { 10060 }, names = { "Power Infusion" }, percent = 0.20, schools = MAGIC },
    { key = "PLAYER_ARCANE_BLAST", en = "Arcane Blast stacks", unit = "player",
        ids = { 400573 }, names = { "Arcane Blast" }, perStack = 0.10, maxStacks = 4, schools = MAGIC,
        notSpells = { ["Arcane Blast"] = true } },
    { key = "TARGET_IMPROVED_SCORCH", en = "Improved Scorch", unit = "target", debuff = true,
        ids = { 22959 }, names = { "Improved Scorch" }, perStack = 0.03, maxStacks = 5, schools = { fire = true } },
    { key = "TARGET_CURSE_OF_ELEMENTS", en = "Curse of the Elements", unit = "target", debuff = true,
        ids = { 11722 }, names = { "Curse of the Elements", "Fluch der Elemente" },
        percent = 0.10, schools = { fire = true, frost = true }, verify = true },
    -- Fingers of Frost makes the next Ice Lance count as hitting a Frozen target (x3, 16 Oct).
    -- Kept verify: the client coefficient for Ice Lance is 0 and the sim's fit is ~0.10, so the
    -- x3 only multiplies an estimate that still needs a live read first.
    { key = "PLAYER_FINGERS_OF_FROST", en = "Fingers of Frost", unit = "player",
        ids = { 400669 }, names = { "Fingers of Frost" }, percent = 2.00,
        spells = { ["Ice Lance"] = true }, verify = true },
}

local function isSecret(v)
    if type(issecretvalue) ~= "function" then return false end
    local ok, r = pcall(issecretvalue, v)
    return ok and r or false
end

local function settings()
    return ns._settings and ns._settings()
end

---------------------------------------------------------------------------------------------
-- Reading one unit's buffs or debuffs, secret-safe
---------------------------------------------------------------------------------------------

-- { [spellID] = stacks } for the unit's buffs (debuff=false) or debuffs, plus `unreadable`
-- when the client refused to answer (a secret value): the caller then applies nothing.
local function scan(unit, debuff)
    local found, unreadable = {}, false
    local modern = C_UnitAuras and (debuff and type(C_UnitAuras.GetDebuffDataByIndex) == "function"
        or type(C_UnitAuras.GetBuffDataByIndex) == "function")
    for i = 1, 40 do
        local ok, aura
        if modern then
            local fn = debuff and C_UnitAuras.GetDebuffDataByIndex or C_UnitAuras.GetBuffDataByIndex
            ok, aura = pcall(fn, unit, i)
            if not ok or isSecret(aura) then
                unreadable = true
                break
            end
            if type(aura) ~= "table" then break end -- the list ended
            local id = aura.spellId
            if isSecret(id) then
                unreadable = true
            elseif type(id) == "number" then
                local stacks = aura.applications
                found[id] = (not isSecret(stacks) and type(stacks) == "number" and stacks) or 1
            end
        else
            local fn = debuff and UnitDebuff or UnitBuff
            if type(fn) ~= "function" then return nil end
            -- UnitBuff/UnitDebuff: name, icon, count, type, duration, expiration, source,
            -- stealable, nameplateShowPersonal, spellId (pcall adds the ok first).
            local ok, name, _, count, _, _, _, _, _, _, id = pcall(fn, unit, i)
            if not ok or isSecret(name) then
                if not ok then return nil end
                unreadable = true
            elseif name == nil then
                break -- the list ended
            elseif isSecret(id) or isSecret(count) then
                unreadable = true
            elseif type(id) == "number" then
                found[id] = (type(count) == "number" and not isSecret(count) and count) or 1
            end
        end
    end
    return found, unreadable
end
Auras.Scan = scan

-- The stacks of one entry's aura on its unit, or nil when no API answers at all.
local function stacksOf(entry, cache)
    local key = entry.unit .. (entry.debuff and ":d" or ":b")
    local found, unreadable
    local cached = cache[key]
    if cached then
        found, unreadable = cached[1], cached[2]
    else
        found, unreadable = scan(entry.unit, entry.debuff)
        cache[key] = { found, unreadable }
    end
    if not found then return nil, true end
    for _, id in ipairs(entry.ids or {}) do
        local stacks = found[id]
        if stacks then return stacks end
    end
    return 0, unreadable
end

---------------------------------------------------------------------------------------------
-- The multiplier for one cast
---------------------------------------------------------------------------------------------

-- Multiplication, not addition: Arcane Power multiplies, a taken-debuff multiplies again.
-- Returns multiplier (1 when nothing applies), percent-ish total for the trace, and a note.
function Auras.MultiplierFor(name, school, class)
    local db = settings()
    if db and db.useAuras == false then return 1, 0 end
    local list = Auras.LIST
    local mult, notes, unknown = 1, {}, false
    local cache = {}
    for _, entry in ipairs(list) do
        if not (db and db.auraForce and db.auraForce[entry.key] == "off") then
            local applies = false
            if entry.spells then
                applies = type(name) == "string" and entry.spells[name] or false
            end
            if not applies and entry.schools and type(school) == "string" then
                applies = entry.schools[school] or false
            end
            if applies and entry.notSpells and type(name) == "string" and entry.notSpells[name] then applies = false end
            if applies and entry.verify then applies = false end
            if applies then
                local stacks, unreadable = stacksOf(entry, cache)
                if unreadable then unknown = true end
                if stacks and stacks > 0 then
                    local percent
                    if entry.perStack then
                        percent = entry.perStack * math.min(stacks, entry.maxStacks or stacks)
                    else
                        percent = entry.percent or 0
                    end
                    if percent > 0 then
                        mult = mult * (1 + percent)
                        notes[#notes + 1] = string.format("%s%s +%.0f%%", entry.en,
                            stacks > 1 and (" x" .. stacks) or "", percent * 100)
                    end
                end
            end
        end
    end
    return mult, mult - 1, table.concat(notes, ", "), unknown
end

-- The probe: what is readable right now for each entry (own unit and target), stacks included.
function Auras.ProbeLines()
    local lines = {}
    lines[#lines + 1] = "auras: " .. (type(C_UnitAuras) == "table" and "C_UnitAuras"
        or (type(UnitBuff) == "function" and "UnitBuff/UnitDebuff") or "no aura API")
    local cache = {}
    for _, entry in ipairs(Auras.LIST) do
        local stacks, unreadable = stacksOf(entry, cache)
        local db = settings()
        local forced = db and db.auraForce and db.auraForce[entry.key] or "auto"
        lines[#lines + 1] = string.format("%s [%s]: stacks %s%s (force %s)%s", entry.en, entry.unit,
            stacks and tostring(stacks) or "?", unreadable and " (unreadable)" or "", tostring(forced),
            entry.verify and " [magnitude to verify]" or "")
    end
    return lines
end

return Auras
