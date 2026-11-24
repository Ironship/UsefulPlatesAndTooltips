-- UsefulPlatesAndTooltips: the public HealPrediction API. See API.md.
-- Exposes own HoT/food/drink estimates and native incoming-heal readings for unit frame addons
-- and UI plugins (such as DaylightUI plugins that draw overlays in their own style).
-- Copyright (c) 2026 Ironship. GPL-3.0-or-later, see LICENSE.
local _, BIT = ...
local ns = BIT.Module("HealPrediction")
local bus = BIT.API
local Root = UsefulPlatesAndTooltips_API
if not bus or not Root then return end

local EVENT = "HEAL_PREDICTION_CHANGED"
local api = { API_VERSION = 1 }

local WATCHED = { "player", "target", "focus", "targettarget" }
for i = 1, 4 do WATCHED[#WATCHED + 1] = "party" .. i end
for i = 1, 40 do WATCHED[#WATCHED + 1] = "raid" .. i end

local lastSeen = {}
local dirtyUnits = {}

local function isSecret(v)
    if type(issecretvalue) ~= "function" then return false end
    local ok, r = pcall(issecretvalue, v)
    return ok and r == true
end

local function clearTable(t)
    for k in pairs(t) do t[k] = nil end
end

local function trace(msg)
    local db = ns._settings and ns._settings()
    if db and db.debug and BIT.SayModule then BIT.SayModule("HealPrediction", msg, "66ff99") end
end

bus.DeclareEvent(EVENT, "HealPrediction", trace)

local function running()
    return not ns.off and BIT.IsRunning("HealPrediction")
end

local function resolvedHorizon(horizon)
    if not isSecret(horizon) and type(horizon) == "number" and horizon > 0 and horizon == horizon then
        return horizon
    end
    return ns.HotHorizon and ns.HotHorizon() or math.huge
end

function api.GetHotHorizon()
    if not running() then return nil end
    return ns.HotHorizon and ns.HotHorizon() or math.huge
end

function api.GetHotAmount(unit, horizon)
    if not running() or isSecret(unit) or type(unit) ~= "string" or not ns.Hots then return 0 end
    local amount = ns.Hots.AmountFor(unit, resolvedHorizon(horizon))
    if not isSecret(amount) and type(amount) == "number" and amount > 0 then
        return math.floor(amount + 0.5)
    end
    return 0
end

function api.GetManaAmount(horizon)
    if not running() or not ns.Hots then return 0 end
    local amount = ns.Hots.ManaFor("player", resolvedHorizon(horizon))
    if not isSecret(amount) and type(amount) == "number" and amount > 0 then
        return math.floor(amount + 0.5)
    end
    return 0
end

function api.GetIncoming(unit, allHealers)
    if not running() or isSecret(unit) or type(unit) ~= "string" then return nil, 0 end
    if allHealers == nil then
        local db = ns._settings and ns._settings()
        allHealers = db and db.allHealers == true or false
    end
    local direct = ns.ReadIncoming and ns.ReadIncoming(unit, allHealers and true or false) or nil
    return direct, api.GetHotAmount(unit)
end

function api.RegisterCallback(owner, func)
    Root.RegisterCallback(owner, EVENT, func)
end

function api.UnregisterCallback(owner)
    Root.UnregisterCallback(owner, EVENT)
end

function ns.onHealPredictionEvent(unit)
    if not bus.HasListeners(EVENT) then return end
    if not isSecret(unit) and type(unit) == "string" and unit ~= "" then
        dirtyUnits[unit] = true
    end
end

local function unitExists(unit)
    if unit == "player" then return true end
    if type(UnitExists) ~= "function" then return false end
    local ok, exists = pcall(UnitExists, unit)
    return ok and not isSecret(exists) and exists == true
end

function ns.afterRefresh()
    if not bus.HasListeners(EVENT) then
        if next(lastSeen) then clearTable(lastSeen) end
        if next(dirtyUnits) then clearTable(dirtyUnits) end
        return
    end
    local db = ns._settings and ns._settings()
    local allHealers = db and db.allHealers == true or false
    for _, unit in ipairs(WATCHED) do
        local state
        if unitExists(unit) then
            local direct = ns.ReadIncoming and ns.ReadIncoming(unit, allHealers) or nil
            local directTag = "0"
            if direct ~= nil then
                if isSecret(direct) then
                    directTag = "S"
                elseif type(direct) == "number" and direct > 0 then
                    directTag = tostring(math.floor(direct + 0.5))
                end
            end
            local hot = api.GetHotAmount(unit)
            local mana = unit == "player" and api.GetManaAmount() or 0
            state = directTag .. "|" .. hot .. "|" .. mana
        end
        local forced = dirtyUnits[unit]
        dirtyUnits[unit] = nil
        if state ~= lastSeen[unit] or forced then
            lastSeen[unit] = state
            bus.Fire(EVENT, unit)
        end
    end
    if next(dirtyUnits) then
        local extra = {}
        for unit in pairs(dirtyUnits) do extra[#extra + 1] = unit end
        clearTable(dirtyUnits)
        for _, unit in ipairs(extra) do bus.Fire(EVENT, unit) end
    end
end

bus.Register("HealPrediction", api, { module = "HealPrediction" })
