-- UsefulPlatesAndTooltips module HealPrediction: the heals over time you cast, which the client's own incoming-heal
-- projection leaves out (UnitGetIncomingHeals covers direct heals only). When a cast of yours that heals over time
-- succeeds, the amount the spell's description promises is remembered for the friendly it was cast on and handed to
-- the overlay as a second segment behind the direct heal: an estimate, drawn for the next few seconds of the effect
-- and then left to run out. Readable own buffs also recover existing effects and their actual expiry;
-- when aura data is hidden, the last known effect or cast estimate is retained.
local _, BIT = ...
local ns = BIT.Module("HealPrediction")

local Hots = {}
ns.Hots = Hots

local MAX_PENDING_SECONDS = 15 -- a SENT without its SUCCEEDED is forgotten after this

local function isSecret(v)
    if type(issecretvalue) ~= "function" then return false end
    local ok, r = pcall(issecretvalue, v)
    return ok and r or false
end

local function ask(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b = pcall(fn, ...)
    if not ok or isSecret(a) then return nil end
    if isSecret(b) then return nil end
    return a, b
end

local function plainName(name)
    if isSecret(name) or type(name) ~= "string" or name == "" then return nil end
    return (name:gsub("%s+", ""))
end

local function fullName(unit)
    local name, realm = ask(UnitFullName or UnitName, unit)
    name = plainName(name)
    if not name then return end
    if name:find("-", 1, true) then return name end
    realm = plainName(realm) or plainName(ask(GetNormalizedRealmName)) or plainName(ask(GetRealmName))
    if realm then return name .. "-" .. realm end
end

local function unitIdentity(unit)
    local guid = ask(UnitGUID, unit)
    local playerName = (unit == "player" or ask(UnitIsPlayer, unit) == true) and fullName(unit) or nil
    return type(guid) == "string" and guid or playerName, playerName
end

local function debugValue(value)
    if isSecret(value) then return "SECRET" end
    return tostring(value)
end

local function debugIdentity(unit)
    local okName, name, realm = pcall(UnitName, unit)
    local okFull, full, fullRealm = pcall(UnitFullName, unit)
    local okGUID, guid = pcall(UnitGUID, unit)
    return string.format("%s: UnitName=%s/%s UnitFullName=%s/%s GUID=%s exists=%s",
        unit, okName and debugValue(name) or "error", debugValue(realm),
        okFull and debugValue(full) or "error", debugValue(fullRealm),
        okGUID and debugValue(guid) or "error", debugValue(ask(UnitExists, unit)))
end

local sent = {}    -- [castGUID or spellID] = { key, name (player alias, realm included), at }
local lastSent = "none"
local lastSentIdentity = "none"
local active = {}  -- [GUID or player full name] = { [spell name or ID] = { total, duration, expiresAt } }
local reportedErrors = {}
local function report(message)
    local db = ns._settings and ns._settings()
    if not db or db.debug ~= true then return end
    if reportedErrors[message] then return end
    reportedErrors[message] = true
    BIT.Say("HealPrediction: " .. message)
end

local function settings()
    return ns._settings and ns._settings() or nil
end

local function spellData()
    local module = BIT.modules and BIT.modules.SpellDamageInfo
    if type(module) ~= "table" or type(module.ComputeHot) ~= "function" then return nil end
    return module
end

local function plainPositive(v)
    return not isSecret(v) and type(v) == "number" and v > 0 and v < math.huge and v == v
end

-- Food and drink: the effect of an item the player uses ("Restores 59 health over 18 sec. Must remain seated while eating.")
-- is no spell that heals a target, but it does run for the player like a heal over time: health (food) and mana (drink) still
-- to come over the rest of the aura. SpellDamageInfo reads such a text (ComputeConsumable); an instant potion has no over-time
-- part and gives nothing here. Returns { total, duration, mana, manaDuration, consumable }, family, true; the player's own.
local function consumable(module, spellID)
    if type(module.ComputeConsumable) ~= "function" then return end
    local ok, view, name = pcall(module.ComputeConsumable, spellID)
    if not ok or type(view) ~= "table" then return end
    local entry = { consumable = true }
    local hot, mana = view.hot, view.manaOverTime
    if type(hot) == "table" and plainPositive(hot.total) and plainPositive(hot.duration) then
        entry.total, entry.duration = hot.total, hot.duration
    end
    if type(mana) == "table" and plainPositive(mana.total) and plainPositive(mana.duration) then
        entry.mana, entry.manaDuration = mana.total, mana.duration
        entry.duration = entry.duration or mana.duration
    end
    if not entry.total and not entry.mana then return end
    local family = (not isSecret(name) and type(name) == "string" and name ~= "") and name or spellID
    return entry, family, true
end

-- allowSelf: the player's own buffs and casts, where a consumable's effect counts too. Returns the estimate, its family and
-- whether it is such an effect.
local function estimate(spellID, allowSelf)
    local module = spellData()
    if not module then return end
    local ok, hot, family = pcall(module.ComputeHot, spellID)
    if not ok then report("HoT estimate failed for spell " .. spellID .. ": " .. tostring(hot)) return end
    if type(hot) ~= "table" then
        if allowSelf then return consumable(module, spellID) end
        return
    end
    if isSecret(hot.total) or isSecret(hot.duration) then return end
    local total, duration = tonumber(hot.total), tonumber(hot.duration)
    if not total or not duration or total <= 0 or duration <= 0
        or total ~= total or duration ~= duration or total == math.huge or duration == math.huge then
        report("Invalid HoT estimate for spell " .. spellID)
        return
    end
    if isSecret(family) or type(family) ~= "string" or family == "" then family = spellID end
    return { total = total, duration = duration }, family
end

local function auraHots(unit)
    local fn = C_UnitAuras and (C_UnitAuras.GetBuffDataByIndex or C_UnitAuras.GetAuraDataByIndex)
    if type(fn) ~= "function" and type(UnitBuff) ~= "function" then return end
    local list = {}
    for i = 1, 40 do
        local aura
        if type(fn) == "function" then
            local ok, data = pcall(fn, unit, i, "HELPFUL|PLAYER")
            if not ok or isSecret(data) then
                report("Aura data unavailable for " .. unit .. "; retaining the last HoT estimate")
                return
            end
            if data == nil then return list end
            if type(data) ~= "table" then return end
            aura = data
        else
            local ok, name, _, _, _, duration, expires, source, _, _, id = pcall(UnitBuff, unit, i, "PLAYER")
            if not ok or isSecret(name) then return end
            if name == nil then return list end
            aura = { spellId = id, duration = duration, expirationTime = expires, sourceUnit = source }
        end
        local id, source = aura.spellId, aura.sourceUnit
        if isSecret(id) or isSecret(source) then return end
        if type(id) == "number" and (source == "player" or ask(UnitIsUnit, source, "player") == true) then
            local hot, family = estimate(id, unit == "player")
            if hot then
                local duration, expires = aura.duration, aura.expirationTime
                if isSecret(duration) or isSecret(expires) then return end
                if type(duration) ~= "number" or type(expires) ~= "number" then return end
                if duration > 0 and duration < math.huge and expires < math.huge and expires > GetTime() then
                    hot.expiresAt = expires
                    list[family] = hot
                end
            end
        end
    end
    -- A full list without its terminator may be truncated: keep the last known effects.
end

-- Resolve bare names against known friendlies; same-name players on different realms are ambiguous.
local function recipientKey(targetName)
    if isSecret(targetName) then return end
    local named = plainName(targetName)
    if named then
        local found, alias, ambiguous
        local function consider(unit)
            if ask(UnitExists, unit) ~= true
                or (unit ~= "player" and ask(UnitCanAssist, "player", unit) ~= true) then return end
            local name = fullName(unit)
            local matched = name and (name == named or (not named:find("-", 1, true) and name:match("^[^-]+") == named))
            if not matched then
                -- Forever's SENT target joins the two UnitName results with a space.
                local first, second = ask(UnitName, unit)
                matched = type(first) == "string" and type(second) == "string" and second ~= ""
                    and targetName == first .. " " .. second
            end
            if matched then
                local key, playerName = unitIdentity(unit)
                if not key then ambiguous = true return end
                if found and found ~= key and (not alias or alias ~= playerName) then ambiguous = true end
                if not found or key ~= playerName then found, alias = key, playerName end
            end
        end
        for _, unit in ipairs({ "player", "target", "focus", "targettarget", "mouseover" }) do consider(unit) end
        for i = 1, 4 do consider("party" .. i) end
        for i = 1, 40 do consider("raid" .. i) end
        if ambiguous then return end
        if found then return found, alias end
        if named:find("-", 1, true) then return named, named end
        return
    end
    -- ponytail: an unnamed cast uses the game's default target/self assumption, not a macro parser.
    if ask(UnitExists, "target") == true and ask(UnitCanAssist, "player", "target") == true then
        return unitIdentity("target")
    end
    return unitIdentity("player")
end

local function token(castGUID, spellID)
    if not isSecret(castGUID) and type(castGUID) == "string" then return castGUID end
    if not isSecret(spellID) and type(spellID) == "number" then return spellID end
end

-- Whether anything of ours is drawn at all: heals over time, food, drink.
local function anyOn(db)
    return db.showHots ~= false or db.showFood ~= false or db.showDrink ~= false
end

function Hots.OnSent(targetName, castGUID, spellID)
    local db = settings()
    if ns.off or not db or not anyOn(db) then return end
    local key = token(castGUID, spellID)
    if not key then return end
    local now = GetTime()
    for old, entry in pairs(sent) do
        if now - entry.at > MAX_PENDING_SECONDS then sent[old] = nil end
    end
    if type(key) == "number" and sent[key] then
        sent[key].ambiguous = true
        return
    end
    local recipient, name = recipientKey(targetName)
    sent[key] = { key = recipient, name = name, at = now }
    lastSent = string.format("%s target=%s -> %s", debugValue(spellID), debugValue(targetName), debugValue(recipient))
    lastSentIdentity = debugIdentity("player")
end

local lastCast = "none"

function Hots.OnSucceeded(castGUID, spellID)
    local key = token(castGUID, spellID)
    local entry = key and sent[key]
    if key then sent[key] = nil end
    local db = settings()
    if ns.off or not db or not anyOn(db) or isSecret(spellID) or type(spellID) ~= "number" then return end
    local hot, family, own = estimate(spellID, true)
    if hot and own then
        -- an item's effect is the player's own, whoever is selected
        local ownKey, ownName = unitIdentity("player")
        entry = { key = ownKey, name = ownName, at = GetTime() }
    elseif not entry or entry.ambiguous or GetTime() - entry.at > MAX_PENDING_SECONDS then
        lastCast = spellID .. ": no matching SENT (key " .. tostring(key) .. ")"
        return
    end
    if not hot then lastCast = spellID .. ": not a HoT / no estimate" return end
    if not entry.key then
        lastCast = spellID .. ": recipient unavailable"
        report("HoT recipient unavailable or ambiguous for spell " .. spellID)
        return
    end
    lastCast = spellID .. ": " .. string.format("%.0f", hot.total or hot.mana or 0) .. " on " .. tostring(entry.key)
    local list = active[entry.key] or (entry.name and active[entry.name]) or {}
    active[entry.key] = list
    hot.expiresAt = GetTime() + hot.duration
    list[family] = hot
    if entry.name then active[entry.name] = list end
end

-- The unit's running effects, from its readable own buffs, else the last known ones; nil when there are none.
local function listFor(unit)
    if unit ~= "player" and ask(UnitIsUnit, unit, "player") == true then unit = "player" end
    if unit ~= "player" and ask(UnitCanAssist, "player", unit) ~= true then return nil end
    local key, name = unitIdentity(unit)
    local list = auraHots(unit)
    if list then
        if key then active[key] = list end
        if name then active[name] = list end
    else
        list = (key and active[key]) or (name and active[name])
    end
    return list, unit
end

-- The healing still to come from your own heals over time on this unit's frame, over the next
-- `horizon` seconds of each effect (math.huge: all that is left of it, so a fresh Rejuvenation is
-- its whole total and the figure runs down as the ticks land); nil when there is none. On the player's
-- own frame food counts too (an effect of an item you use, Hots' consumable), as its own setting.
function Hots.AmountFor(unit, horizon)
    local db = settings()
    if ns.off or not db or not anyOn(db) then return nil end
    local list
    list, unit = listFor(unit)
    if not list then return nil end
    horizon = tonumber(horizon) or 4
    local now, sum = GetTime(), 0
    for family, hot in pairs(list) do
        local left = hot.expiresAt - now
        if left <= 0 then
            list[family] = nil
        elseif hot.total then
            local shown = hot.consumable and db.showFood ~= false or (not hot.consumable and db.showHots ~= false)
            if shown then sum = sum + hot.total * math.min(left, horizon) / hot.duration end
        end
    end
    if next(list) == nil then
        for alias, value in pairs(active) do
            if value == list then active[alias] = nil end
        end
    end
    if sum <= 0 then return nil end
    return sum
end

-- The mana a drink still has to give on the player's mana bar, over the next `horizon` seconds of it; nil when there is none.
function Hots.ManaFor(unit, horizon)
    local db = settings()
    if ns.off or not db or db.showDrink == false then return nil end
    local list
    list, unit = listFor(unit)
    if unit ~= "player" or not list then return nil end
    horizon = tonumber(horizon) or 4
    local now, sum = GetTime(), 0
    for _, hot in pairs(list) do
        local left = hot.expiresAt - now
        if left > 0 and hot.mana and hot.manaDuration then
            sum = sum + hot.mana * math.min(left, horizon) / hot.manaDuration
        end
    end
    if sum <= 0 then return nil end
    return sum
end

function Hots.Reset()
    sent, active = {}, {}
end

-- ponytail: temporary /upt healdebug lines; remove once the in-game HoT overlay is confirmed.
function Hots.Debug(unit)
    unit = unit or "player"
    local s = debugValue
    local lines = {}
    local db = settings()
    lines[#lines + 1] = string.format("HoT %s: showHots=%s off=%s GetBuffDataByIndex=%s GetAuraDataByIndex=%s UnitBuff=%s ComputeHot=%s",
        unit, s(db and db.showHots), s(ns.off), type(C_UnitAuras and C_UnitAuras.GetBuffDataByIndex),
        type(C_UnitAuras and C_UnitAuras.GetAuraDataByIndex), type(UnitBuff), type(spellData() and spellData().ComputeHot))
    local fn = C_UnitAuras and (C_UnitAuras.GetBuffDataByIndex or C_UnitAuras.GetAuraDataByIndex)
    for i = 1, 40 do
        local ok, d, src, id, dur, exp
        if type(fn) == "function" then
            ok, d = pcall(fn, unit, i, "HELPFUL")
            if not ok then lines[#lines + 1] = "aura " .. i .. " error: " .. s(d) break end
            if isSecret(d) then lines[#lines + 1] = "aura " .. i .. ": SECRET table" break end
            if type(d) ~= "table" then break end
            src, id, dur, exp = d.sourceUnit, d.spellId, d.duration, d.expirationTime
        elseif type(UnitBuff) == "function" then
            local name, _
            ok, name, _, _, _, dur, exp, src, _, _, id = pcall(UnitBuff, unit, i)
            if not ok or isSecret(name) or name == nil then break end
        else
            break
        end
        local hot = (not isSecret(id) and type(id) == "number") and estimate(id) or nil
        local remaining = s(exp)
        if not isSecret(exp) and type(exp) == "number" then
            remaining = string.format("%.1f", exp - GetTime())
        end
        lines[#lines + 1] = string.format("aura %d: id=%s src=%s dur=%s exp=%s est=%s", i, s(id), s(src), s(dur),
            remaining,
            hot and string.format("%.0f/%ss", hot.total, hot.duration) or "nil")
    end
    local list = auraHots(unit)
    local n = 0
    if list then for _ in pairs(list) do n = n + 1 end end
    local rejuv = estimate(774)
    lines[#lines + 1] = "own HoTs from auras: " .. (list and n or "nil (unreadable)") .. "; last cast: " .. lastCast
        .. "; Rejuv(774) estimate: " .. (rejuv and string.format("%.0f", rejuv.total) or "nil")
    lines[#lines + 1] = "last sent: " .. lastSent
    lines[#lines + 1] = "at SENT " .. lastSentIdentity
    lines[#lines + 1] = "now " .. debugIdentity(unit)
    lines[#lines + 1] = "AmountFor: " .. s(Hots.AmountFor(unit, ns.HotHorizon and ns.HotHorizon() or (db and db.hotHorizon)))
    return lines
end

local frame = CreateFrame("Frame")
for _, event in ipairs({ "UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_INTERRUPTED", "PLAYER_ENTERING_WORLD", "PLAYER_DEAD", "PLAYER_EQUIPMENT_CHANGED",
    "PLAYER_REGEN_ENABLED", "UNIT_AURA" }) do
    pcall(frame.RegisterEvent, frame, event)
end
frame:SetScript("OnEvent", function(_, event, unit, arg2, arg3, arg4)
    if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_DEAD" then
        Hots.Reset()
    end
    if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_EQUIPMENT_CHANGED"
        or event == "PLAYER_REGEN_ENABLED" or (event == "UNIT_AURA" and not isSecret(unit) and unit == "player") then
        local db = settings()
        local module = spellData()
        if not ns.off and db and db.showHots ~= false and module and module.RefreshHealingBonus then
            module.RefreshHealingBonus()
        end
    elseif isSecret(unit) or unit ~= "player" then
        return
    elseif event == "UNIT_SPELLCAST_SENT" then
        Hots.OnSent(arg2, arg3, arg4) -- unit, target, castGUID, spellID
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        Hots.OnSucceeded(arg2, arg3)  -- unit, castGUID, spellID
    else
        local key = token(arg2, arg3)
        if key then sent[key] = nil end
    end
end)
if BIT.Perf then BIT.Perf.Watch(frame, "OnEvent", "HealPrediction.Hots") end
