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
    local ok, a = pcall(fn, ...)
    if not ok or isSecret(a) then return nil end
    return a
end

-- A name without its realm: the cast event names a cross-realm player "Name-Realm", the unit frame "Name".
local function plainName(name)
    if isSecret(name) or type(name) ~= "string" or name == "" then return nil end
    return (name:gsub("%-.*$", ""))
end

local sent = {}    -- [castGUID or spellID] = { name, at }
local active = {}  -- [name] = { [spellID] = { total, duration, at } }

local function settings()
    return ns._settings and ns._settings() or nil
end

local function spellData()
    local module = BIT.modules and BIT.modules.SpellDamageInfo
    if type(module) ~= "table" or type(module.Compute) ~= "function" then return nil end
    return module
end

-- Who the cast went to: the name the client sent, or, for a cast without one, the target when it is a
-- friend and yourself otherwise (the game retargets a beneficial spell to you when the target is hostile).
local function recipientName(targetName)
    local named = plainName(targetName)
    if named then return named end
    if ask(UnitExists, "target") == true and ask(UnitCanAssist, "player", "target") == true then
        return plainName(ask(UnitName, "target"))
    end
    return plainName(ask(UnitName, "player"))
end

local function token(castGUID, spellID)
    if not isSecret(castGUID) and type(castGUID) == "string" then return castGUID end
    if not isSecret(spellID) and type(spellID) == "number" then return spellID end
end

function Hots.OnSent(targetName, castGUID, spellID)
    local key = token(castGUID, spellID)
    if not key then return end
    local now = GetTime()
    for old, entry in pairs(sent) do
        if now - entry.at > MAX_PENDING_SECONDS then sent[old] = nil end
    end
    sent[key] = { name = recipientName(targetName), at = now }
end

function Hots.OnSucceeded(castGUID, spellID)
    local db = settings()
    if not db or db.showHots == false or isSecret(spellID) or type(spellID) ~= "number" then return end
    local key = token(castGUID, spellID)
    local entry = key and sent[key]
    if key then sent[key] = nil end
    if not entry or not entry.name then return end
    local module = spellData()
    if not module then return end
    local ok, view = pcall(module.Compute, spellID)
    if not ok or type(view) ~= "table" or type(view.hot) ~= "table" then return end
    -- A spell that also hurts is not a heal over time on a friend; the direct part of a heal is the client's.
    if view.direct or view.dot then return end
    local total, duration = tonumber(view.hot.total), tonumber(view.hot.duration)
    if not total or not duration or total <= 0 or duration <= 0 then return end
    active[entry.name] = active[entry.name] or {}
    active[entry.name][spellID] = { total = total, duration = duration, at = GetTime() }
end

-- The healing still to come from your own heals over time on this unit's frame, over the next
-- `horizon` seconds of each effect; nil when there is none.
function Hots.AmountFor(unit, horizon)
    local db = settings()
    if not db or db.showHots == false or not next(active) then return nil end
    local name = plainName(ask(UnitName, unit))
    local list = name and active[name]
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
    if next(list) == nil then active[name] = nil end
    if sum <= 0 then return nil end
    return sum
end

function Hots.Reset()
    sent, active = {}, {}
end

local frame = CreateFrame("Frame")
for _, event in ipairs({ "UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_SUCCEEDED", "PLAYER_ENTERING_WORLD", "PLAYER_DEAD" }) do
    pcall(frame.RegisterEvent, frame, event)
end
frame:SetScript("OnEvent", function(_, event, unit, arg2, arg3, arg4)
    if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_DEAD" then
        Hots.Reset()
    elseif isSecret(unit) or unit ~= "player" then
        return
    elseif event == "UNIT_SPELLCAST_SENT" then
        Hots.OnSent(arg2, arg3, arg4) -- unit, target, castGUID, spellID
    else
        Hots.OnSucceeded(arg2, arg3)  -- unit, castGUID, spellID
    end
end)
