-- UsefulPlatesAndTooltips module CastPrediction: the passive talent multipliers a damage cast
-- actually sees on WoW: Forever, where the client's tooltip does NOT fold talents into the
-- numbers (unlike Retail, whose descriptions already hold them; there they must never be added
-- again). The list is curated from the Forever research (BattleInfoTool-audits/castprediction-
-- research/10-forever-classes-talents.md, section 7): only talents that multiply the damage of
-- a cast unconditionally, with their Forever magnitudes.
--
-- Ranks are read from the client's talent tree (C_ClassTalents/C_Traits, the modern trait API on
-- both clients) by matching the node's spell NAME, with IsPlayerSpell as a last resort; a manual
-- Auto/Off/Max override per talent exists in the settings for clients where nothing answers.
-- Everything is pcall'd and cached: an unavailable talent API never stops a cast from showing,
-- it only leaves the multiplier out (and says so in the trace log).
local _, BIT = ...
local ns = BIT.Module("CastPrediction")

local Talents = {}
ns.Talents = Talents

local CACHE_SECONDS = 30

local function isSecret(v)
    if type(issecretvalue) ~= "function" then return false end
    local ok, r = pcall(issecretvalue, v)
    return ok and r or false
end

-- Same rule as SpellDamageInfo: Forever answers like Retail to WOW_PROJECT_ID, so the version
-- decides (Retail is 10 and up, Forever 1.60, Classic Era 1.15).
local function isRetail()
    if type(GetBuildInfo) ~= "function" then return false end
    local ok, version = pcall(GetBuildInfo)
    if not ok or isSecret(version) or type(version) ~= "string" then return false end
    local major = tonumber(version:match("^(%d+)"))
    return major ~= nil and major >= 10
end

Talents.IsRetail = isRetail

local function spellName(spellID)
    local fn = (C_Spell and C_Spell.GetSpellName) or GetSpellInfo
    if type(fn) ~= "function" or type(spellID) ~= "number" then return nil end
    local ok, name = pcall(fn, spellID)
    if ok and not isSecret(name) and type(name) == "string" then return name end
    return nil
end
Talents.SpellName = spellName

local function spellDescription(spellID)
    local fn = (C_Spell and C_Spell.GetSpellDescription) or GetSpellDescription
    if type(fn) ~= "function" or type(spellID) ~= "number" then return nil end
    local ok, text = pcall(fn, spellID)
    if ok and not isSecret(text) and type(text) == "string" and text ~= "" then return text end
    return nil
end

---------------------------------------------------------------------------------------------
-- The curated list (Forever): includes only what a cast-damage estimate should multiply
---------------------------------------------------------------------------------------------

-- perRank: the percent per rank as a fraction. byRank: the percent of each rank when it is not
-- linear (Searing Light reads 2% then 5%). schools: which parsed schools it multiplies.
-- spells: name-limited talents (only these spells' casts). verify: the magnitude still needs a
-- live tooltip read; it is reported by the probe but never applied until confirmed here.
Talents.LIST = {
    { key = "MAGE_FIRE_POWER", class = "MAGE", en = "Fire Power", ids = { 11124 }, perRank = 0.02, maxRank = 5,
        schools = { fire = true } },
    { key = "MAGE_PIERCING_ICE", class = "MAGE", en = "Piercing Ice", ids = { 11151 }, perRank = 0.02, maxRank = 3,
        schools = { frost = true, frostfire = true } },
    { key = "MAGE_ARCANE_INSTABILITY", class = "MAGE", en = "Arcane Instability", ids = { 15058 }, perRank = 0.01,
        maxRank = 3, schools = { arcane = true, fire = true, frost = true, frostfire = true } },
    { key = "WARLOCK_SHADOW_MASTERY", class = "WARLOCK", en = "Shadow Mastery", ids = { 18271 }, perRank = 0.01,
        maxRank = 5, schools = { shadow = true } },
    -- Immolate's initial hit +10% a point (client curve, beta pass 17 Sep): the only part of Immolate this
    -- module predicts.
    { key = "WARLOCK_AFTERMATH", class = "WARLOCK", en = "Aftermath", ids = { 18119 }, perRank = 0.10, maxRank = 5,
        spells = { ["Immolate"] = true } },
    { key = "PRIEST_DARKNESS", class = "PRIEST", en = "Darkness", ids = { 15259 }, perRank = 0.02, maxRank = 5,
        schools = { shadow = true } },
    { key = "PRIEST_SEARING_LIGHT", class = "PRIEST", en = "Searing Light", ids = { 14909 }, byRank = { 0.02, 0.05 },
        maxRank = 2, schools = { holy = true } },
    { key = "DRUID_MOONFURY", class = "DRUID", en = "Moonfury", ids = { 16896 }, perRank = 0.02, maxRank = 5,
        schools = { arcane = true, nature = true } },
    { key = "PALADIN_CRUSADE", class = "PALADIN", en = "Crusade", perRank = 0.02, maxRank = 2,
        schools = { holy = true, physical = true } },
    { key = "PALADIN_SACRED_ARBITER", class = "PALADIN", en = "Sacred Arbiter", ids = { 1311087 }, perRank = 0.10,
        maxRank = 1, spells = { ["Holy Strike"] = true } },
    -- Seen in the Forever trees, magnitude still to be confirmed from the live tooltip:
    { key = "SHAMAN_CONCUSSION", class = "SHAMAN", en = "Concussion", ids = { 16035 }, perRank = 0.01, maxRank = 5,
        verify = true, spells = { ["Lightning Bolt"] = true, ["Chain Lightning"] = true, ["Earth Shock"] = true } },
    { key = "SHAMAN_CALL_OF_FLAME", class = "SHAMAN", en = "Call of Flame", ids = { 16038 }, perRank = 0.02,
        maxRank = 3, verify = true,
        spells = { ["Lava Burst"] = true, ["Fire Nova"] = true, ["Flame Shock"] = true } },
    { key = "WARLOCK_AGONIZING_FLAMES", class = "WARLOCK", en = "Agonizing Flames", ids = { 17927 },
        byRank = { 0.03, 0.07, 0.10 }, maxRank = 3, verify = true, spells = { ["Immolate"] = true } },
    -- Ranks that only matter together with an aura (Auras.lua reads them through `talent`); never applied here.
    -- Improved Shadow Bolt 4% a point while the 12 s debuff (17794) is on the target (beta pass).
    { key = "WARLOCK_IMPROVED_SHADOW_BOLT", class = "WARLOCK", en = "Improved Shadow Bolt", ids = { 17793 },
        perRank = 0.04, maxRank = 5, auraOnly = true },
    -- Shadow and Flame 2% a point on Shadow Bolt and Incinerate while its 20 s buffs (1293816, 426311) are up.
    { key = "WARLOCK_SHADOW_AND_FLAME", class = "WARLOCK", en = "Shadow and Flame", ids = { 426316 },
        perRank = 0.02, maxRank = 5, auraOnly = true },
    -- Decimation 3/6% on Shadow Bolt and Searing Pain while its buff (440873) is up (target under 35%).
    { key = "WARLOCK_DECIMATION", class = "WARLOCK", en = "Decimation", ids = { 440870 }, byRank = { 0.03, 0.06 },
        maxRank = 2, auraOnly = true },
    -- Power in Light 2% a point on Smite and Penance against your own Holy Fire.
    { key = "PRIEST_POWER_IN_LIGHT", class = "PRIEST", en = "Power in Light", ids = { 1309969 }, perRank = 0.02,
        maxRank = 5, auraOnly = true },
}

local function percentFor(entry, rank)
    if entry.byRank then return entry.byRank[math.min(rank, #entry.byRank)] or 0 end
    return (entry.perRank or 0) * rank
end
Talents.PercentFor = percentFor

---------------------------------------------------------------------------------------------
-- Reading the talent tree (C_ClassTalents / C_Traits), by node spell name
---------------------------------------------------------------------------------------------

-- { [name] = { rank = n, maxRank = n, spellID = id } } for every node the client names, or nil.
local function collectTree()
    if type(C_Traits) ~= "table" or type(C_ClassTalents) ~= "table" then return nil end
    local configID
    if type(C_ClassTalents.GetActiveConfigID) == "function" then
        local ok, id = pcall(C_ClassTalents.GetActiveConfigID)
        if ok and not isSecret(id) and type(id) == "number" then configID = id end
    end
    if not configID then return nil end
    local ok, info = pcall(C_Traits.GetConfigInfo, configID)
    if not ok or isSecret(info) or type(info) ~= "table" then return nil end
    local treeIDs = info.treeIDs
    if type(treeIDs) ~= "table" then return nil end

    local found, any = {}, false
    local byId = {}
    local function spellIDOf(nodeID, nodeInfo)
        local id = nodeInfo.spellID
        if type(id) == "number" and not isSecret(id) then return id end
        local entry = nodeInfo.activeEntry
        if type(entry) ~= "number" or isSecret(entry) then return nil end
        local okEntry, entryInfo = pcall(C_Traits.GetEntryInfo, configID, entry)
        if not okEntry or isSecret(entryInfo) or type(entryInfo) ~= "table" then return nil end
        local definition = entryInfo.definitionID
        if type(definition) ~= "number" or isSecret(definition) then return nil end
        local okDef, definitionInfo = pcall(C_Traits.GetDefinitionInfo, definition)
        if not okDef or isSecret(definitionInfo) or type(definitionInfo) ~= "table" then return nil end
        id = definitionInfo.spellID or definitionInfo.overrideSpellID
        if type(id) == "number" and not isSecret(id) then return id end
        return nil
    end
    for i = 1, #treeIDs do
        local treeID = treeIDs[i]
        if type(treeID) == "number" and not isSecret(treeID) then
            local okNodes, nodeIDs = pcall(C_Traits.GetTreeNodes, treeID)
            if okNodes and not isSecret(nodeIDs) and type(nodeIDs) == "table" then
                for j = 1, #nodeIDs do
                    local nodeID = nodeIDs[j]
                    if type(nodeID) == "number" and not isSecret(nodeID) then
                        local okNode, nodeInfo = pcall(C_Traits.GetNodeInfo, configID, nodeID)
                        if okNode and not isSecret(nodeInfo) and type(nodeInfo) == "table" then
                            any = true
                            local rank = nodeInfo.ranksPurchased
                            local maxRank = nodeInfo.maxRanks
                            local spellID = spellIDOf(nodeID, nodeInfo)
                            local name = spellID and spellName(spellID)
                            if name and type(rank) == "number" and not isSecret(rank) then
                                found[name] = { rank = rank, maxRank = maxRank, spellID = spellID }
                            end
                            -- by spell id too: a name is localised, the id is not
                            if spellID and type(rank) == "number" and not isSecret(rank) then
                                byId[spellID] = { rank = rank, maxRank = maxRank, spellID = spellID }
                            end
                        end
                    end
                end
            end
        end
    end
    if not any then return nil end
    return found, byId
end
Talents._collectTree = collectTree

local treeCache, idCache, treeCacheAt
function Talents.Invalidate()
    treeCache, idCache, treeCacheAt = nil, nil, nil
end

local function tree()
    local ok, t = pcall(GetTime)
    local now = ok and type(t) == "number" and t or 0
    if treeCache and now - (treeCacheAt or 0) < CACHE_SECONDS then return treeCache, idCache end
    treeCacheAt = now
    local okCollect, collected, byId = pcall(collectTree)
    treeCache = (okCollect and collected) or nil
    idCache = (okCollect and byId) or nil
    return treeCache, idCache
end

-- The rank of one curated talent: the manual override first, else the tree by name, else
-- IsPlayerSpell (only a one-rank talent can be told apart this way). nil when nothing knows.
local function rankOf(entry)
    local settings = ns._settings and ns._settings()
    if not settings then return nil end
    local forced = settings.talentForce and settings.talentForce[entry.key]
    if forced == "off" then return 0 end
    if forced == "max" then return entry.maxRank end

    local t, byId = tree()
    if byId and entry.ids then
        for _, id in ipairs(entry.ids) do
            if byId[id] then return byId[id].rank, byId[id] end
        end
    end
    if t then
        local node = t[entry.en] or (entry.de and t[entry.de])
        if node then return node.rank, node end
    end

    if entry.maxRank == 1 and entry.ids then
        local fn = IsPlayerSpell or IsSpellKnown
        if type(fn) == "function" then
            for _, id in ipairs(entry.ids) do
                local ok, known = pcall(fn, id)
                if ok and not isSecret(known) and known == true then return 1 end
            end
        end
    end
    return nil
end
Talents.RankOf = rankOf

-- The rank the talent tree gives a talent by spell id (else by name), with no settings or overrides involved: for
-- other modules (DoTInfo's Ignite and Deep Wounds). nil when the tree cannot be read or does not list it.
function Talents.NodeRank(ids, name)
    local t, byId = tree()
    if byId and type(ids) == "table" then
        for _, id in ipairs(ids) do
            if byId[id] then return byId[id].rank end
        end
    end
    if t and name and t[name] then return t[name].rank end
    return nil
end

-- The curated entry of a key (Auras.lua asks for the ranks behind its auras).
function Talents.ByKey(key)
    for _, entry in ipairs(Talents.LIST) do
        if entry.key == key then return entry end
    end
end

local function playerClass()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, token = pcall(UnitClass, "player")
    if ok and not isSecret(token) and type(token) == "string" then return token end
    return nil
end
Talents.PlayerClass = playerClass

-- The multiplier one cast sees on this client: 1 + percent of every applicable talent, or 1
-- when nothing applies or the client is Retail (whose descriptions already hold talents).
-- Returns multiplier, percent (0 when none), and a short note for the trace log.
function Talents.MultiplierFor(name, school, class)
    if isRetail() then return 1, 0 end
    local settings = ns._settings and ns._settings()
    if settings and settings.useTalents == false then return 1, 0 end
    class = class or playerClass()
    local percent, notes, unknown = 0, {}, false
    for _, entry in ipairs(Talents.LIST) do
        if entry.class == class and not entry.auraOnly then
            local applies = false
            if entry.spells then
                applies = type(name) == "string" and entry.spells[name] or false
            end
            if not applies and entry.schools and type(school) == "string" then
                applies = entry.schools[school] or false
            end
            if applies then
                local rank = rankOf(entry)
                if rank == nil then
                    unknown = true
                elseif rank > 0 and not entry.verify then
                    local add = percentFor(entry, rank)
                    if add > 0 then
                        percent = percent + add
                        notes[#notes + 1] = string.format("%s %d/%d +%.0f%%", entry.en, rank, entry.maxRank, add * 100)
                    end
                end
            end
        end
    end
    return 1 + percent, percent, table.concat(notes, ", "), unknown
end

-- The probe: what the class's trees answer for the curated talents, with the live description
-- so a magnitude marked verify can be confirmed in game. Returns a list of chat lines.
function Talents.ProbeLines()
    local class = playerClass()
    local lines = {}
    local t = tree()
    lines[#lines + 1] = string.format("class %s; talent tree %s; Retail=%s",
        tostring(class), t and (tostring((next(t) ~= nil) and "read" or "empty")) or "unavailable",
        tostring(isRetail()))
    for _, entry in ipairs(Talents.LIST) do
        if entry.class == class then
            local rank, node = rankOf(entry)
            local settings = ns._settings and ns._settings()
            local forced = settings and settings.talentForce and settings.talentForce[entry.key] or "auto"
            local applied = percentFor(entry, rank or 0)
            lines[#lines + 1] = string.format("%s: rank %s/%d (force %s), applies +%.0f%%%s%s",
                entry.en, rank and tostring(rank) or "?", entry.maxRank, tostring(forced), applied * 100,
                entry.verify and " [magnitude to verify]" or "",
                node and node.spellID and (" [spell " .. node.spellID .. "]") or "")
            if node and node.spellID then
                local text = spellDescription(node.spellID)
                if text then
                    lines[#lines + 1] = "    " .. text:gsub("\n", " ")
                end
            end
        end
    end
    return lines
end

return Talents
