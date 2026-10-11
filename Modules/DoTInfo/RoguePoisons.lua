-- Own poison clocks use identified aura applications/refreshes, never arbitrary melee hits.
local _, BIT = ...
local ns = BIT.Module("DoTInfo")
local R = ns.Retail
if not R then return end

local events, status = nil, {}

local function secret(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

local function plain(value, kind)
    return not secret(value) and type(value) == kind
end

local function positive(value)
    return plain(value, "number") and value > 0 and value < math.huge
end

local function report(unit, reason)
    if status[unit] == reason then return end
    status[unit] = reason
    R.PoisonTrace("POISON " .. unit .. ": " .. reason)
end

local function hostile(unit)
    if not plain(unit, "string") or (unit ~= "target" and unit ~= "softenemy"
        and not unit:match("^nameplate%d+$")) then return false end
    local ok, value = pcall(UnitCanAttack, "player", unit)
    return ok and plain(value, "boolean") and value
end

local function describe(aura, filtered)
    if not plain(aura, "table") then return nil, "aura data hidden" end
    local spellID = aura.spellId
    if not plain(spellID, "number") then return nil, "aura spell ID hidden" end
    local config = R.poisonSpells[spellID]
    if not config then return end
    if not filtered then
        local source = aura.sourceUnit
        if not plain(source, "string") then return nil, "poison owner hidden" end
        if source ~= "player" then return end
        if not plain(aura.isHarmful, "boolean") or not aura.isHarmful then return end
    end
    local instanceID = aura.auraInstanceID
    if not positive(instanceID) then return nil, "poison instance ID hidden" end
    local name = C_Spell.GetSpellName(spellID)
    local desc = C_Spell.GetSpellDescription(config.descriptionID)
    local total, school, duration = R.Parse(spellID, desc)
    if not total or not plain(name, "string") then return nil, "poison description unavailable" end
    local expiration = aura.expirationTime
    if positive(aura.duration) then duration = aura.duration end
    return { spellID = spellID, auraInstanceID = instanceID, name = name,
        total = total, school = school, duration = duration,
        expirationTime = positive(expiration) and expiration or nil }
end

local function observe(unit, aura, filtered, signal, seen)
    local info, reason = describe(aura, filtered)
    if reason then return reason end
    if not info then return end
    if seen then seen[info.spellID] = true end
    if R.ObservePoison(unit, info, signal) then
        report(unit, info.expirationTime and "clock synchronized" or "own clock running")
    else
        report(unit, "waiting for a readable poison application")
    end
end

local function scan(unit)
    if not C_UnitAuras or type(C_UnitAuras.GetUnitAuras) ~= "function" then
        report(unit, "aura API unavailable")
        return
    end
    local ok, reason = pcall(function()
        local auras = C_UnitAuras.GetUnitAuras(unit, "HARMFUL|PLAYER")
        if not plain(auras, "table") then return "aura list hidden" end
        local seen, unavailable = {}, nil
        for _, aura in ipairs(auras) do
            unavailable = observe(unit, aura, true, false, seen) or unavailable
        end
        -- An incomplete/hidden scan cannot prove removal of a poison already on our clock.
        if not unavailable then R.RemovePoisons(unit, seen) end
        return unavailable
    end)
    if not ok then reason = "aura access denied" end
    if reason then report(unit, reason) end
end

local function update(unit, updateInfo)
    if not hostile(unit) then return end
    local ok, reason = pcall(function()
        if not plain(updateInfo, "table") then return "aura update hidden" end
        if secret(updateInfo.isFullUpdate) then return "aura update hidden" end
        if updateInfo.isFullUpdate then scan(unit); return end
        local added, updated, removed = updateInfo.addedAuras,
            updateInfo.updatedAuraInstanceIDs, updateInfo.removedAuraInstanceIDs
        if secret(added) or secret(updated) or secret(removed) then return "aura update hidden" end
        local unavailable
        for _, aura in ipairs(added or {}) do
            unavailable = observe(unit, aura, false, true) or unavailable
        end
        for _, id in ipairs(updated or {}) do
            if not positive(id) then
                unavailable = "poison instance ID hidden"
            elseif C_UnitAuras and type(C_UnitAuras.GetAuraDataByAuraInstanceID) == "function" then
                local aura = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, id)
                -- shortcut: with hidden expiration an identified aura update is assumed to refresh it;
                -- verify this against live UNIT_AURA behavior before treating the clock as accurate.
                if not secret(aura) and aura ~= nil then
                    unavailable = observe(unit, aura, false, true) or unavailable
                elseif secret(aura) then
                    unavailable = "aura data hidden"
                end
            else
                unavailable = "aura API unavailable"
            end
        end
        local ids = {}
        for _, id in ipairs(removed or {}) do if positive(id) then ids[id] = true end end
        R.RemovePoisons(unit, nil, ids)
        return unavailable
    end)
    if not ok then reason = "aura access denied" end
    if reason then scan(unit) end
end

function R.StartRoguePoisons()
    if events or ns.off or not ns.db then return end
    local ok, _, class = pcall(UnitClass, "player")
    if not ok or secret(class) or class ~= "ROGUE" then return end
    events = CreateFrame("Frame")
    for _, event in ipairs({ "UNIT_AURA", "PLAYER_TARGET_CHANGED", "PLAYER_ENTERING_WORLD",
        "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED" }) do events:RegisterEvent(event) end
    events:SetScript("OnEvent", function(_, event, unit, updateInfo)
        if event == "UNIT_AURA" then
            update(unit, updateInfo)
        elseif event == "NAME_PLATE_UNIT_REMOVED" then
            if plain(unit, "string") then status[unit] = nil end
        elseif event == "NAME_PLATE_UNIT_ADDED" then
            if hostile(unit) then scan(unit) end
        else
            wipe(status)
            for _, token in ipairs({ "target", "softenemy" }) do if hostile(token) then scan(token) end end
            if event == "PLAYER_ENTERING_WORLD" then
                for i = 1, 40 do
                    local token = "nameplate" .. i
                    if hostile(token) then scan(token) end
                end
            end
        end
    end)
end
