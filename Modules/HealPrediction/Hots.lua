-- UsefulPlatesAndTooltips module HealPrediction: the heals over time you cast, which the client's own incoming-heal
-- projection leaves out (UnitGetIncomingHeals covers direct heals only). When a cast of yours that heals over time
-- succeeds, the amount the spell's description promises is remembered for the friendly it was cast on and handed to
-- the overlay as a second segment behind the direct heal: an estimate, drawn for the next few seconds of the effect
-- and then left to run out. Nothing is read from auras (hidden in combat on Forever); a dispelled or cancelled
-- effect keeps showing until its time is up.
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
    local playerName = ask(UnitIsPlayer, unit) == true and fullName(unit) or nil
    return type(guid) == "string" and guid or playerName, playerName
end

local sent = {}    -- [castGUID or spellID] = { key, name (player alias, realm included), at }
local active = {}  -- [GUID or player full name] = { [spellID] = { total, duration, at } }
local reportedErrors = {}
local function report(message)
    if reportedErrors[message] then return end
    reportedErrors[message] = true
    BIT.Say("HealPrediction: " .. message)
end

local function settings()
    return ns._settings and ns._settings() or nil
end

local function spellData()
    local module = BIT.modules and BIT.modules.SpellDamageInfo
    if type(module) ~= "table" or type(module.Compute) ~= "function" then return nil end
    return module
end

-- Resolve bare names against known friendlies; same-name players on different realms are ambiguous.
local function recipientKey(targetName)
    if isSecret(targetName) then return end
    local named = plainName(targetName)
    if named then
        local found, alias, ambiguous
        local function consider(unit)
            if ask(UnitExists, unit) ~= true or ask(UnitCanAssist, "player", unit) ~= true then return end
            local name = fullName(unit)
            if name and (name == named or (not named:find("-", 1, true) and name:match("^[^-]+") == named)) then
                local key, playerName = unitIdentity(unit)
                if not key then ambiguous = true return end
                if found and found ~= key and (not alias or alias ~= playerName) then ambiguous = true end
                if not found or key ~= playerName then found, alias = key, playerName end
            end
        end
        for _, unit in ipairs({ "player", "target", "focus", "mouseover" }) do consider(unit) end
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

function Hots.OnSent(targetName, castGUID, spellID)
    local db = settings()
    if ns.off or not db or db.showHots == false then return end
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
end

function Hots.OnSucceeded(castGUID, spellID)
    local key = token(castGUID, spellID)
    local entry = key and sent[key]
    if key then sent[key] = nil end
    local db = settings()
    if ns.off or not db or db.showHots == false or isSecret(spellID) or type(spellID) ~= "number" then return end
    if not entry or entry.ambiguous or GetTime() - entry.at > MAX_PENDING_SECONDS then return end
    local module = spellData()
    if not module then return end
    local ok, view = pcall(module.Compute, spellID)
    if not ok then report("HoT estimate failed for spell " .. spellID .. ": " .. tostring(view)) return end
    if type(view) ~= "table" or type(view.hot) ~= "table" then return end
    -- A spell that also hurts is not a heal over time on a friend; the direct part of a heal is the client's.
    if view.direct or view.dot then return end
    if not entry.key then report("HoT recipient unavailable or ambiguous for spell " .. spellID) return end
    local total, duration = tonumber(view.hot.total), tonumber(view.hot.duration)
    if not total or not duration or total <= 0 or duration <= 0
        or total ~= total or duration ~= duration or total == math.huge or duration == math.huge then
        report("Invalid HoT estimate for spell " .. spellID)
        return
    end
    local list = active[entry.key] or (entry.name and active[entry.name]) or {}
    active[entry.key] = list
    list[spellID] = { total = total, duration = duration, at = GetTime() }
    if entry.name then active[entry.name] = list end
end

-- The healing still to come from your own heals over time on this unit's frame, over the next
-- `horizon` seconds of each effect; nil when there is none.
function Hots.AmountFor(unit, horizon)
    local db = settings()
    if ns.off or not db or db.showHots == false or not next(active) then return nil end
    if ask(UnitCanAssist, "player", unit) ~= true then return nil end
    local key, name = unitIdentity(unit)
    local list = (key and active[key]) or (name and active[name])
    if not list then return nil end
    horizon = tonumber(horizon) or 4
    local now, sum = GetTime(), 0
    for spellID, hot in pairs(list) do
        local left = hot.at + hot.duration - now
        if left <= 0 then
            list[spellID] = nil
        else
            sum = sum + hot.total * math.min(left, horizon) / hot.duration
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

function Hots.Reset()
    sent, active = {}, {}
end

local frame = CreateFrame("Frame")
for _, event in ipairs({ "UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_INTERRUPTED", "PLAYER_ENTERING_WORLD", "PLAYER_DEAD" }) do
    pcall(frame.RegisterEvent, frame, event)
end
frame:SetScript("OnEvent", function(_, event, unit, arg2, arg3, arg4)
    if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_DEAD" then
        Hots.Reset()
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
