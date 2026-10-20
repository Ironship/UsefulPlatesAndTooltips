-- UsefulPlatesAndTooltips module CastPrediction: while a damage spell with a cast time is on its
-- way to the target, show the damage it is expected to deal as a marker on the target's health
-- bar and nameplate -- the same idea as DoTInfo's remaining-DoT marker, for spells that are not
-- DoTs (Frostbolt, Fireball, Pyroblast, Shadow Bolt, Lightning Bolt, ...). Channels show the
-- damage remaining over their readable channel time; their ticks never calibrate a whole cast.
--
-- A prediction, not a promise: the cast's damage is a range (the description's own numbers plus
-- the player's spell power), and critical strikes, procs and partial resists cannot be predicted.
-- What stays readable on WoW: Forever (target health, player stats and auras are secret in
-- combat):
--   * our own casts (UNIT_SPELLCAST_START/STOP/SUCCEEDED) and the spell description -> the damage
--     range and the school (through the SpellDamageInfo module's parser and coefficient tables)
--   * UNIT_COMBAT amounts on units -> the hits that actually land, which calibrate the estimate
-- StatusBars accept secret values, so the "this cast would be lethal" comparison is done by the
-- widget, not by Lua (see the kill icon notes in the Display section).

local ADDON_NAME, BIT = ...
local ns = BIT.Module("CastPrediction")

local UPDATE_INTERVAL = 0.1
local CAST_MAX_SECONDS = 15 -- a lost end event never leaves a marker behind
local CAST_STOP_GRACE = 0.5 -- STOP and SUCCEEDED can arrive in either order, a hair apart
local PROJECTILE_GRACE = 1.5 -- keep the marker after a successful cast while the hit flies in
local LANDED_GRACE = 0.35 -- a landed hit flashes and the marker lingers this long
local RECHECK = 5 -- re-read a spell's description no more often than this
-- Calibration from UNIT_COMBAT hits: a hit is this spell's when its amount sits within the
-- predicted range with tolerance, or within the crit band of the prediction (crits still count
-- as "landed", they just never teach the estimate).
local LEARN_TOLERANCE = 0.35
local CRIT_MIN_RATIO, CRIT_MAX_RATIO = 1.3, 2.3
local LEARN_RATE = 1 / 3
local LEARN_MIN_FACTOR, LEARN_MAX_FACTOR = 0.25, 4
local COMBAT_FRAME = 0.05 -- two UNIT_COMBAT events this close are one hit on several unit tokens
local MAX_LOG = 500

-- School names (SpellDamageInfo's parser) to the bit the combat log/UNIT_COMBAT reports.
local SCHOOL_MASKS = {
    physical = 1, holy = 2, fire = 4, nature = 8, frost = 16, shadow = 32, arcane = 64,
    frostfire = 4 + 16, -- both components are reported; either was this cast's
}

-- User options (edited in the module's settings tab, saved in UsefulPlatesAndTooltipsDB).
local DEFAULTS = {
    -- The marker on the target frame's health bar
    showMarker = true,
    fillColor = "school",
    fillOpacity = 45,
    outlineStyle = "solid",
    outlineColor = "white",
    outlineOpacity = 100,
    pulseOutline = true,
    showKillIcon = true,
    killIcon = "skull",
    -- The label
    showLabel = true,
    labelMode = "amount",  -- amount | range | percent
    labelPosition = "center",
    labelSize = 10,
    labelColor = "white",
    -- Nameplates: their own look, since enemy plates are red. Defaults read well on red.
    nameplateMode = "marker", -- off | marker | markerIcon
    plateFillColor = "school",
    plateFillOpacity = 45,
    plateOutlineStyle = "solid",
    plateOutlineColor = "white",
    plateOutlineOpacity = 100,
    plateIconSize = 18,
    plateIconPosition = "left", -- the level badge sits right of the bar on Forever's plates
    plateIconOffsetX = 0,
    plateIconOffsetY = 15,
    -- The prediction itself
    estimate = "average", -- average | min | max
    learn = true,         -- calibrate the estimate from hits seen in combat
    useTalents = true,    -- multiply Forever casts by the detected passive talent percents
    useAuras = true,      -- multiply by readable buffs and target debuffs
    castOnly = true,      -- only spells that are actually cast (not instant casts)
    manualPower = false,  -- use manualPowerValue instead of the client's spell power reading
    manualPowerValue = 0,
    debug = false,
}

local COLOR_PRESETS = {
    { id = "purple", label = "Purple", rgb = { 0.7, 0.3, 1 } },
    { id = "gold",   label = "Gold",   rgb = { 1, 0.85, 0.1 } },
    { id = "white",  label = "White",  rgb = { 1, 1, 1 } },
    { id = "red",    label = "Red",    rgb = { 1, 0.2, 0.2 } },
    { id = "orange", label = "Orange", rgb = { 1, 0.55, 0.1 } },
    { id = "green",  label = "Green",  rgb = { 0.3, 1, 0.3 } },
    { id = "cyan",   label = "Cyan",   rgb = { 0.2, 0.9, 1 } },
    { id = "pink",   label = "Pink",   rgb = { 1, 0.45, 0.6 } },
    { id = "black",  label = "Black",  rgb = { 0, 0, 0 } },
}
local COLOR_BY_ID = {}
for _, preset in ipairs(COLOR_PRESETS) do COLOR_BY_ID[preset.id] = preset.rgb end
local COLOR_LIST = {}
for _, preset in ipairs(COLOR_PRESETS) do COLOR_LIST[#COLOR_LIST + 1] = { id = preset.id, label = preset.label } end

local KILL_ICONS = {
    { id = "skull",  label = "Raid skull",  path = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8" },
    { id = "cross",  label = "Red X",       path = "Interface\\RaidFrame\\ReadyCheck-NotReady" },
    { id = "impact", label = "Impact",      path = "Interface\\SpellShadow\\Spell_Shadow_Shadowfury" },
}

local settings

local function print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffffbb33CastPrediction|r " .. msg)
end

-- Always recorded to SavedVariables (settings.log) for diagnosing accuracy; echoed to chat with
-- /upt castpred debug, like DoTInfo does.
local function trace(msg)
    if not settings then return end
    table.insert(settings.log, string.format("%.1f %s", GetTime(), msg))
    if #settings.log > MAX_LOG then table.remove(settings.log, 1) end
    if settings.debug then print("|cff888888" .. msg .. "|r") end
end

local function isSecret(v)
    if type(issecretvalue) ~= "function" then return false end
    local ok, r = pcall(issecretvalue, v)
    return ok and r or false
end

local function number(v)
    return not isSecret(v) and type(v) == "number" and v or nil
end

local function read(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok and not isSecret(value) then return value end
end

-- A stable key for the mob behind a unit token, nil when it cannot be tracked. A secret GUID only
-- affects that one token: another token naming the same mob still identifies it (UnitIsUnit).
local warnedSecretGuid = false
local function unitKey(unit)
    local ok, guid = pcall(UnitGUID, unit)
    if ok and not isSecret(guid) then return guid end
    if ok and isSecret(guid) and type(UnitIsUnit) == "function" then
        for i = 1, 40 do
            local plateUnit = "nameplate" .. i
            local sameOK, same = pcall(UnitIsUnit, plateUnit, unit)
            if sameOK and not isSecret(same) and same == true then
                local guidOK, plateGUID = pcall(UnitGUID, plateUnit)
                if guidOK and not isSecret(plateGUID) and plateGUID then return plateGUID end
            end
        end
    end
    if unit ~= "target" then return nil end
    if not warnedSecretGuid then
        warnedSecretGuid = true
        trace("Target GUID is secret; the current target's own token is used as the key")
    end
    return "target"
end

local function targetIsDead()
    local ok, dead = pcall(UnitIsDead, "target")
    return ok and not isSecret(dead) and dead
end

---------------------------------------------------------------------------------------------
-- Spell data (through the SpellDamageInfo module: its parser, coefficients and spell power)
---------------------------------------------------------------------------------------------

local function sdi()
    local module = BIT.modules and BIT.modules.SpellDamageInfo
    if type(module) ~= "table" or type(module.Parser) ~= "table" or type(module.Estimate) ~= "table" then return nil end
    return module
end

local function isRetail()
    local module = sdi()
    return (module and type(module.IsRetail) == "function" and module.IsRetail()) and true or false
end

local function spellName(spellID)
    local fn = (C_Spell and C_Spell.GetSpellName) or GetSpellInfo
    if type(fn) ~= "function" then return nil end
    local ok, name = pcall(fn, spellID)
    if ok and not isSecret(name) and type(name) == "string" then return name end
    return nil
end

local function getDescription(spellID)
    local fn = (C_Spell and C_Spell.GetSpellDescription) or GetSpellDescription
    if type(fn) ~= "function" then return nil end
    local ok, text = pcall(fn, spellID)
    if not ok or isSecret(text) or type(text) ~= "string" or text == "" then return nil end
    return text
end

local loadRequested = {}
local function requestLoad(spellID)
    if loadRequested[spellID] then return end
    loadRequested[spellID] = true
    if C_Spell and type(C_Spell.RequestLoadSpellData) == "function" then
        pcall(C_Spell.RequestLoadSpellData, spellID)
    elseif type(RequestLoadSpellData) == "function" then
        pcall(RequestLoadSpellData, spellID)
    end
end

local function getCastTime(spellID)
    if C_Spell and type(C_Spell.GetSpellInfo) == "function" then
        local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
        if ok and not isSecret(info) and type(info) == "table" then
            local ms = number(info.castTime)
            if ms then return ms / 1000 end
        end
    end
    if type(GetSpellInfo) == "function" then
        local ok, _, _, _, ms = pcall(GetSpellInfo, spellID)
        if ok then
            ms = number(ms)
            if ms then return ms / 1000 end
        end
    end
    return nil
end

-- Last readable spell power by school index (2..7). In combat the client may return secret
-- values; then the last value read out of combat stays in use (as SpellDamageInfo does).
local bonusDamage = {}
local bonusReadAt = 0
local function readBonus()
    local now = GetTime()
    if now - bonusReadAt < 1 and next(bonusDamage) then return end
    bonusReadAt = now
    if type(GetSpellBonusDamage) ~= "function" then return end
    for i = 2, 7 do
        local v = number(read(GetSpellBonusDamage, i))
        if v then bonusDamage[i] = v end
    end
end

-- The parsed view of a spell: { min, max, school, name, castTime, estimated, coefUsed } or false
-- when the spell has no direct damage in its description (a pure DoT, a heal, a utility spell).
-- Cached; a text that cannot be read now leaves the last reading in use.
local viewCache = {}
local function buildView(spellID, channel)
    if isSecret(spellID) or type(spellID) ~= "number" then return false end
    local cacheKey = channel and (spellID .. ":channel") or spellID
    local cached = viewCache[cacheKey]
    if cached and not isSecret(cached.checked) and GetTime() - cached.checked < RECHECK then
        return cached.view
    end
    local module = sdi()
    if not module then return false end
    local text = getDescription(spellID)
    if not text then
        requestLoad(spellID)
        if cached then
            cached.checked = GetTime()
            return cached.view
        end
        return false
    end
    -- A selected enemy does not establish who stands inside a ground/area channel.
    if channel then
        local lower = string.lower(text)
        for _, phrase in ipairs({ "target area", "nearby enemies", "all enemies", "zielgebiet", "umkreis" }) do
            if lower:find(phrase, 1, true) then return false end
        end
    end
    local entry = module.Parser.Read(text, module.DescriptionLang and module.DescriptionLang() or nil, isRetail())
    local parsed = entry and entry.parsed
    local view = false
    if parsed and (parsed.direct or (channel and parsed.dot)) then
        local castTime = getCastTime(spellID)
        local coef = module.SpellCoefficientsFor and module.SpellCoefficientsFor(spellID) or nil
        local bonus
        if not isRetail() and settings and settings.manualPower then
            local perSchool = tonumber(settings.manualPowerValue)
            bonus = perSchool and perSchool > 0 and perSchool or nil
        elseif not isRetail() then
            readBonus()
            bonus = module.Estimate.DamageBonus(parsed.school, bonusDamage)
        end
        -- On Retail the description's numbers already hold the player's spell power.
        local applied = module.Estimate.Apply(parsed, castTime, bonus, nil, coef)
        local direct = applied and applied.direct
        local periodic = channel and applied and applied.dot
        if direct or periodic then
            local total = periodic and periodic.total or 0
            view = {
                min = (direct and direct.min or 0) + total,
                max = (direct and direct.max or 0) + total,
                school = parsed.school or applied.school,
                name = spellName(spellID) or parsed.name,
                castTime = castTime,
                estimated = applied.estimated and true or false,
            }
        end
    end
    viewCache[cacheKey] = { view = view, text = text, checked = GetTime() }
    if view then
        trace(string.format("SPELL %s (id %d): %d-%d %s%s", tostring(view.name), spellID, math.floor(view.min + 0.5),
            math.floor(view.max + 0.5), tostring(view.school), view.estimated and " (with spell power)" or ""))
    end
    return view
end

ns.BuildView = buildView

---------------------------------------------------------------------------------------------
-- Calibration: hits seen in combat adjust the estimate
---------------------------------------------------------------------------------------------

local function learnedEntry(spellID)
    local entry = settings.learned[spellID]
    if type(entry) ~= "table" then return nil end
    return entry
end

local function factorFor(spellID)
    local entry = learnedEntry(spellID)
    if not entry or not settings or not settings.learn then return 1 end
    local factor = tonumber(entry.factor)
    if not factor then return 1 end
    if factor < LEARN_MIN_FACTOR then factor = LEARN_MIN_FACTOR end
    if factor > LEARN_MAX_FACTOR then factor = LEARN_MAX_FACTOR end
    return factor
end

-- The prediction the marker shows: { min, max, value } scaled by what earlier hits taught, by
-- the passive talent percents the client reports (Forever only; Retail descriptions hold them),
-- and by readable buffs and target debuffs (Arcane Power, Arcane Blast stacks, Improved Scorch,
-- ...; an aura the client will not show, or a Forever combat with hidden auras, adds nothing).
local function predictionFor(view, spellID)
    if not view then return nil end
    local factor = isRetail() and 1 or factorFor(spellID)
    local min, max = view.min * factor, view.max * factor
    local talentPercent = 0
    if ns.Talents and type(ns.Talents.MultiplierFor) == "function" then
        local okTalents, mult, percent = pcall(ns.Talents.MultiplierFor, view.name, view.school)
        if okTalents and type(mult) == "number" and mult > 0 then
            min, max = min * mult, max * mult
            talentPercent = type(percent) == "number" and percent or 0
        end
    end
    local auraPercent = 0
    if ns.Auras and type(ns.Auras.MultiplierFor) == "function" then
        local okAuras, amult, apercent = pcall(ns.Auras.MultiplierFor, view.name, view.school)
        if okAuras and type(amult) == "number" and amult > 0 then
            min, max = min * amult, max * amult
            auraPercent = type(apercent) == "number" and apercent or 0
        end
    end
    local value
    if settings.estimate == "min" then
        value = min
    elseif settings.estimate == "max" then
        value = max
    else
        value = (min + max) / 2
    end
    return { min = min, max = max, value = value, factor = factor, talentPercent = talentPercent,
        auraPercent = auraPercent, samples = (learnedEntry(spellID) or {}).samples }
end

-- A non-crit hit of `amount` teaches the factor; a hit outside the range is refused (someone
-- else's damage, or a wildly different rank). Crits only prove the cast landed. expected is the
-- scaled prediction the marker is showing; comparing against it keeps the factor honest even
-- after earlier hits already moved it.
local function noteHit(spellID, amount, isCrit, expected)
    if not settings or not settings.learn or isRetail() then return end -- on Retail the numbers already hold everything
    local view = viewCache[spellID] and viewCache[spellID].view
    if type(amount) ~= "number" or amount <= 0 then return end
    if isCrit then return end
    expected = tonumber(expected) or (view and ((view.min + view.max) / 2)) or nil
    if not expected or expected <= 0 then return end
    local ratio = amount / expected
    -- Outside the window it is someone else's damage or a wildly different rank; refuse it
    -- (crits already left above: only the marked CRITICAL flag is trusted for those).
    if ratio < 1 - LEARN_TOLERANCE or ratio > 1 + LEARN_TOLERANCE then return end
    local entry = learnedEntry(spellID)
    if not entry then
        entry = { factor = 1, samples = 0 }
        settings.learned[spellID] = entry
    end
    local factor = tonumber(entry.factor) or 1
    local smoothed = factor * (1 - LEARN_RATE) + ratio * LEARN_RATE
    if smoothed < LEARN_MIN_FACTOR then smoothed = LEARN_MIN_FACTOR end
    if smoothed > LEARN_MAX_FACTOR then smoothed = LEARN_MAX_FACTOR end
    entry.factor = smoothed
    entry.samples = (tonumber(entry.samples) or 0) + 1
    trace(string.format("LEARN %s: hit %d vs expected %d -> factor %.2f (%d sample(s))",
        spellName(spellID) or tostring(spellID), math.floor(amount + 0.5), math.floor(expected + 0.5),
        smoothed, entry.samples))
end

function ns.resetLearned()
    if not settings then return end
    settings.learned = {}
    trace("learned factors cleared")
    print("Learned factors cleared.")
end

---------------------------------------------------------------------------------------------
-- The cast in progress
---------------------------------------------------------------------------------------------

-- One cast at a time (the player has one cast bar): { key, spellID, name, view, prediction,
-- startedAt, castGUID, stoppedAt, succeededAt, landedAt }
local castInProgress
local lastCombatAt, combatFrameHits = 0, {}

local function sameCast(cast, castGUID, spellID)
    if not cast then return false end
    local readable = not isSecret(castGUID) and type(castGUID) == "string" and castGUID or nil
    if readable and type(cast.castGUID) == "string" then return readable == cast.castGUID end
    return not isSecret(spellID) and cast.spellID == spellID
end

local function hostileTarget(unit)
    unit = unit or "target"
    return read(UnitExists, unit) == true and read(UnitCanAttack, "player", unit) == true
        and read(UnitIsDeadOrGhost, unit) ~= true
end

local function selectedEnemy()
    if hostileTarget("target") then return "target" end
    return hostileTarget("softenemy") and "softenemy" or nil
end

-- Resolve the recorded recipient, even when action targeting has moved to another enemy.
local function castUnit()
    if not castInProgress then return end
    for _, unit in ipairs({ "target", "softenemy" }) do
        if read(UnitExists, unit) == true and unitKey(unit) == castInProgress.key then return unit end
    end
    for i = 1, 40 do
        local unit = "nameplate" .. i
        if read(UnitExists, unit) == true and unitKey(unit) == castInProgress.key then return unit end
    end
end

local recipients = {}
local function castToken(castGUID, spellID)
    if not isSecret(castGUID) and type(castGUID) == "string" then return castGUID end
    return number(spellID)
end

-- Snapshot SENT so a focus/mouseover macro or a selection change cannot mark the wrong mob.
local function onCastSent(targetName, castGUID, spellID)
    local token = castToken(castGUID, spellID)
    if not token then return end
    local unit = selectedEnemy()
    local key = unit and unitKey(unit) or nil
    local named = not isSecret(targetName) and type(targetName) == "string" and targetName ~= ""
    if named and unit and read(UnitName, unit) ~= targetName then key = nil end
    for _, other in ipairs({ "focus", "mouseover", "softenemy" }) do
        if read(UnitExists, other) == true and read(UnitCanAttack, "player", other) ~= false
            and (not named or read(UnitName, other) == targetName) and unitKey(other) ~= key then
            key = nil
        end
    end
    local now = GetTime()
    for oldToken, sent in pairs(recipients) do
        if now - sent.at > CAST_MAX_SECONDS then recipients[oldToken] = nil end
    end
    recipients[token] = { key = key, at = now }
end

local function targetsSelected(castGUID, spellID, unit)
    local token = castToken(castGUID, spellID)
    local sent = token and recipients[token]
    return not sent or (sent.key ~= nil and sent.key == unitKey(unit))
end

-- Channel times can be secret: never compare or calculate with them before checking.
local function channelTimes(spellID)
    if type(UnitChannelInfo) ~= "function" then return end
    local ok, _, _, _, startMS, endMS, _, _, id, empowered = pcall(UnitChannelInfo, "player")
    startMS, endMS, id = number(startMS), number(endMS), number(id)
    if not ok or (id and id ~= spellID) or isSecret(empowered) or empowered == true then return end
    if not startMS or not endMS or startMS ~= startMS or endMS ~= endMS
        or startMS == math.huge or endMS == math.huge or endMS <= startMS then return end
    return startMS / 1000, endMS / 1000
end

local function dropCast(reason)
    if not castInProgress then return end
    if reason then trace("CAST " .. tostring(castInProgress.name) .. " dropped: " .. reason) end
    castInProgress = nil
end

-- UNIT_SPELLCAST_START (player). Returns true when a marker now shows for the cast.
local function onCastStart(castGUID, spellID, channel)
    dropCast(nil)
    if isSecret(spellID) or type(spellID) ~= "number" then return end
    local unit = selectedEnemy()
    if not unit or not targetsSelected(castGUID, spellID, unit) then return end
    local key = unitKey(unit)
    if not key then return end
    local startedAt, endsAt
    if channel then
        startedAt, endsAt = channelTimes(spellID)
        if not startedAt or endsAt <= GetTime() then return end
    end
    local view = buildView(spellID, channel)
    if not view then return end
    local prediction = predictionFor(view, spellID)
    if not prediction then return end
    castInProgress = {
        key = key,
        softTarget = unit == "softenemy",
        spellID = spellID,
        name = view.name or spellName(spellID) or "?",
        view = view,
        prediction = prediction,
        startedAt = startedAt or GetTime(),
        channel = channel and true or nil,
        endsAt = endsAt,
        channelDuration = channel and (endsAt - startedAt) or nil,
        totalPrediction = channel and prediction or nil,
        castGUID = (not isSecret(castGUID) and type(castGUID) == "string") and castGUID or nil,
    }
    trace(string.format("CASTING %s: expected %d-%d (showing %d%s%s%s)", tostring(castInProgress.name),
        math.floor(prediction.min + 0.5), math.floor(prediction.max + 0.5), math.floor(prediction.value + 0.5),
        prediction.samples and (" , factor from " .. prediction.samples .. " hit(s)") or "",
        (prediction.talentPercent or 0) > 0 and string.format(", talents +%.0f%%", prediction.talentPercent * 100) or "",
        (prediction.auraPercent or 0) > 0 and string.format(", auras +%.0f%%", prediction.auraPercent * 100) or ""))
    return true
end

-- UNIT_SPELLCAST_SUCCEEDED (player): the cast went through; the marker stays while the hit flies.
-- An instant cast (no START) shows briefly too, when the option allows it.
local function onCastSucceeded(castGUID, spellID)
    if castInProgress and sameCast(castInProgress, castGUID, spellID) then
        if castInProgress.channel then return true end -- channels succeed at their start
        castInProgress.succeededAt = GetTime()
        return true
    end
    if settings.castOnly then return end
    local view = buildView(spellID)
    local unit = selectedEnemy()
    if not view or not unit or not targetsSelected(castGUID, spellID, unit) then return end
    local key = unitKey(unit)
    if not key then return end
    local prediction = predictionFor(view, spellID)
    if not prediction then return end
    castInProgress = {
        key = key,
        softTarget = unit == "softenemy",
        spellID = spellID,
        name = view.name or spellName(spellID) or "?",
        view = view,
        prediction = prediction,
        startedAt = GetTime(),
        succeededAt = GetTime(),
        castGUID = (not isSecret(castGUID) and type(castGUID) == "string") and castGUID or nil,
        instant = true,
    }
    return true
end

-- UNIT_SPELLCAST_STOP / FAILED / INTERRUPTED (player). Returns true when the marker was dropped.
local function onCastEnded(event, castGUID, spellID)
    if not castInProgress or not sameCast(castInProgress, castGUID, spellID) then return false end
    if event == "UNIT_SPELLCAST_STOP" then
        if castInProgress.channel then return false end
        castInProgress.stoppedAt = castInProgress.stoppedAt or GetTime()
        return false
    end
    dropCast(event == "UNIT_SPELLCAST_INTERRUPTED" and "interrupted" or "failed")
    return true
end

-- UNIT_COMBAT on any unit: a WOUND (or ABSORB) whose school matches the cast and whose amount
-- sits in the predicted band is this cast landing; it calibrates the estimate. Crits match the
-- band too (their ratio is inside the tolerated one) but never teach it.
local function onUnitCombat(unit, action, flag, amount, school)
    if not castInProgress or castInProgress.channel or not castInProgress.succeededAt then return end
    if isSecret(action) then return end
    local key = unitKey(unit)
    if not key or key ~= castInProgress.key then return end
    local absorbed = action == "ABSORB"
    if action ~= "WOUND" and not absorbed then return end
    amount = number(amount)
    if not amount then return end
    local nowHit = GetTime()
    if nowHit - lastCombatAt > COMBAT_FRAME then
        combatFrameHits = {}
        lastCombatAt = nowHit
    end
    local signature = castInProgress.spellID .. ":" .. amount .. ":" .. tostring(school)
    if combatFrameHits[signature] then return end -- the same hit on another token
    combatFrameHits[signature] = true

    local mask = number(school)
    local expects = castInProgress.view and castInProgress.view.school and SCHOOL_MASKS[castInProgress.view.school]
    if mask and expects then
        -- Frostfire reports as either of its two schools; a plain school matches its own bit only.
        local match = (expects == 20) and (mask == 4 or mask == 16) or (expects == mask)
        if not match then return end
    end

    local isCrit = not isSecret(flag) and flag == "CRITICAL"
    local prediction = castInProgress.prediction
    local lo = prediction.min * (1 - LEARN_TOLERANCE)
    local hi = prediction.max * (1 + LEARN_TOLERANCE)
    local withinRange = amount >= lo and amount <= hi
    local withinCrit = amount >= prediction.value * CRIT_MIN_RATIO and amount <= prediction.value * CRIT_MAX_RATIO
    if absorbed then
        -- The shield ate the hit: this cast landed; nothing to learn from a 0 or a partial.
        castInProgress.landedAt = nowHit
        trace(string.format("HIT absorbed on %s; marker holds until it fades", tostring(unit)))
        return true
    end
    if not withinRange and not withinCrit then return end
    castInProgress.landedAt = nowHit
    if withinRange then noteHit(castInProgress.spellID, amount, isCrit, prediction.value) end
    trace(string.format("HIT %s %d%s matched to the cast (expected %d-%d)",
        tostring(castInProgress.name), math.floor(amount + 0.5), isCrit and " CRIT" or "",
        math.floor(castInProgress.prediction.min + 0.5), math.floor(castInProgress.prediction.max + 0.5)))
    return true
end

local function housekeep(now)
    if not castInProgress then return end
    if castInProgress.channel then
        local cast = castInProgress
        -- shortcut: remaining damage follows time; use discrete ticks when their schedule is known.
        local remaining = math.min(1, math.max(0, (cast.endsAt - now) / cast.channelDuration))
        if remaining <= 0 then return dropCast("channel finished") end
        local total = cast.totalPrediction
        cast.prediction = { min = total.min * remaining, max = total.max * remaining,
            value = total.value * remaining }
    elseif castInProgress.landedAt then
        if now - castInProgress.landedAt > LANDED_GRACE then dropCast("impact faded") end
    elseif castInProgress.succeededAt then
        if now - castInProgress.succeededAt > PROJECTILE_GRACE then dropCast("no hit seen") end
    elseif castInProgress.stoppedAt then
        if now - castInProgress.stoppedAt > CAST_STOP_GRACE then dropCast("stopped without succeeding") end
    elseif now - castInProgress.startedAt > CAST_MAX_SECONDS then
        dropCast("never finished")
    end
end

---------------------------------------------------------------------------------------------
-- Display: the marker, its label and the kill icon; drawn while a cast is predicted
---------------------------------------------------------------------------------------------

local function colorOf(id, opacityPercent)
    local rgb = COLOR_BY_ID[id] or COLOR_BY_ID.white
    return rgb[1], rgb[2], rgb[3], (opacityPercent or 100) / 100
end

local WHITE = "Interface\\Buttons\\WHITE8X8"
local CHANNEL_PATTERN = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Modules\\DoTInfo\\Textures\\DashH2"

local function paintDamage(texture, color, opacity, state)
    local channel = state and state.channel == true
    texture:SetTexture(channel and CHANNEL_PATTERN or WHITE, "REPEAT", "REPEAT")
    texture:SetHorizTile(channel)
    texture:SetVertTile(channel)
    local r, g, b, a = colorOf(color, opacity)
    local dot = BIT.modules and BIT.modules.DoTInfo
    if color == "school" and dot and type(dot.dotColor) == "function" then
        local school = state and state.school
        local rgb = dot.dotColor({ school = SCHOOL_MASKS[school] or number(school) }, "school")
        r, g, b = rgb[1], rgb[2], rgb[3]
    end
    texture:SetVertexColor(r, g, b, a)
end

-- The native health texture supplies the moving edge. Only public bar dimensions enter Lua;
-- health and maximum health stay in StatusBar setters, including when the client hides them.
local function layoutDamage(markerBar, clip, host)
    if not host then return false end
    local fill = read(host.GetStatusBarTexture, host)
    clip:ClearAllPoints()
    clip:SetAllPoints(host)
    -- The clip's dimensions use our parent scale even if the health widget has a different scale.
    local width, height = number(read(clip.GetWidth, clip)), number(read(clip.GetHeight, clip))
    if not fill or not width or not height or width <= 0 or height <= 0 then return false end
    local vertical = read(host.GetOrientation, host) == "VERTICAL"
    local reverse = read(host.GetReverseFill, host) == true
    markerBar:ClearAllPoints()
    markerBar:SetOrientation(vertical and "VERTICAL" or "HORIZONTAL")
    markerBar:SetReverseFill(not reverse)
    if vertical then
        local edge = reverse and "BOTTOM" or "TOP"
        markerBar:SetPoint(edge .. "LEFT", fill, edge .. "LEFT")
        markerBar:SetPoint(edge .. "RIGHT", fill, edge .. "RIGHT")
        markerBar:SetHeight(height)
    else
        local edge = reverse and "LEFT" or "RIGHT"
        markerBar:SetPoint("TOP" .. edge, fill, "TOP" .. edge)
        markerBar:SetPoint("BOTTOM" .. edge, fill, "BOTTOM" .. edge)
        markerBar:SetWidth(width)
    end
    return true
end

local function findById(list, id)
    for _, entry in ipairs(list) do
        if entry.id == id then return entry end
    end
    return list[1]
end

-- Damage retreats from the current HP edge; clipping contains overkill within the health bar.
local markerClip = CreateFrame("Frame", nil, UIParent)
markerClip:SetClipsChildren(true)
local marker = CreateFrame("StatusBar", "UsefulPlatesAndTooltips_CastPredictionMarker", markerClip)
marker:SetStatusBarTexture(WHITE)
marker:SetStatusBarColor(0, 0, 0, 0)
marker:Hide()
local span = marker:GetStatusBarTexture()

local fillLayer = CreateFrame("Frame", nil, marker)
fillLayer:SetAllPoints()

local fillTex = fillLayer:CreateTexture(nil, "ARTWORK")
fillTex:SetPoint("TOPLEFT", span, "TOPLEFT")
fillTex:SetPoint("BOTTOMRIGHT", span, "BOTTOMRIGHT")

local flashTex = fillLayer:CreateTexture(nil, "OVERLAY")
flashTex:SetPoint("TOPLEFT", span, "TOPLEFT")
flashTex:SetPoint("BOTTOMRIGHT", span, "BOTTOMRIGHT")
flashTex:SetColorTexture(1, 1, 1, 1)
flashTex:SetBlendMode("ADD")
flashTex:SetAlpha(0)

local flashAnim = flashTex:CreateAnimationGroup()
local flashIn = flashAnim:CreateAnimation("Alpha")
flashIn:SetFromAlpha(0)
flashIn:SetToAlpha(0.8)
flashIn:SetDuration(0.08)
flashIn:SetOrder(1)
local flashOut = flashAnim:CreateAnimation("Alpha")
flashOut:SetFromAlpha(0.8)
flashOut:SetToAlpha(0)
flashOut:SetDuration(0.4)
flashOut:SetSmoothing("OUT")
flashOut:SetOrder(2)

-- The outline: four hairline edges on the span (solid only; no dash textures ship with this
-- module). The span's length is secret-driven, so the edges are anchored to it, never sized.
local outlineLayer = CreateFrame("Frame", nil, marker)
outlineLayer:SetAllPoints()
local edges = {}
do
    local function edge(texture)
        texture:SetTexture(WHITE)
        table.insert(edges, texture)
        return texture
    end
    local top = edge(outlineLayer:CreateTexture(nil, "OVERLAY", nil, 7))
    top:SetPoint("TOPLEFT", span, "TOPLEFT")
    top:SetPoint("TOPRIGHT", span, "TOPRIGHT")
    top:SetHeight(1)
    local bottom = edge(outlineLayer:CreateTexture(nil, "OVERLAY", nil, 7))
    bottom:SetPoint("BOTTOMLEFT", span, "BOTTOMLEFT")
    bottom:SetPoint("BOTTOMRIGHT", span, "BOTTOMRIGHT")
    bottom:SetHeight(1)
    local left = edge(outlineLayer:CreateTexture(nil, "OVERLAY", nil, 7))
    left:SetPoint("TOPLEFT", span, "TOPLEFT")
    left:SetPoint("BOTTOMLEFT", span, "BOTTOMLEFT")
    left:SetWidth(1)
    local right = edge(outlineLayer:CreateTexture(nil, "OVERLAY", nil, 7))
    right:SetPoint("TOPRIGHT", span, "TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT", span, "BOTTOMRIGHT")
    right:SetWidth(1)
end

local outlinePulse = outlineLayer:CreateAnimationGroup()
outlinePulse:SetLooping("BOUNCE")
do
    local alpha = outlinePulse:CreateAnimation("Alpha")
    alpha:SetFromAlpha(1)
    alpha:SetToAlpha(0.45)
    alpha:SetDuration(0.7)
    alpha:SetSmoothing("IN_OUT")
end

-- The kill icon: addon code cannot compare the (secret) health with the prediction, but a
-- StatusBar can. A clipped window over the portrait holds a very long bar anchored at its right
-- end; the icon rides the bar's fill edge. Short of lethal, that edge sits left of the window
-- (clipped away); at lethal it reaches the window's right edge and slides into view.
local KILL_BAR_LENGTH = 10000
local killWindow = CreateFrame("Frame", "UsefulPlatesAndTooltips_CastPredictionKill", UIParent)
killWindow:SetClipsChildren(true)
killWindow:Hide()
local killBar = CreateFrame("StatusBar", nil, killWindow)
killBar:SetPoint("RIGHT", killWindow, "RIGHT")
killBar:SetStatusBarTexture(WHITE)
killBar:SetStatusBarColor(0, 0, 0, 0)
local killIcon = killBar:CreateTexture(nil, "OVERLAY")
killIcon:SetPoint("RIGHT", killBar:GetStatusBarTexture(), "RIGHT")

local killPulse = killIcon:CreateAnimationGroup()
killPulse:SetLooping("BOUNCE")
do
    local alpha = killPulse:CreateAnimation("Alpha")
    alpha:SetFromAlpha(1)
    alpha:SetToAlpha(0.45)
    alpha:SetDuration(0.7)
    alpha:SetSmoothing("IN_OUT")
end

local labelLayer = CreateFrame("Frame", nil, UIParent)
local label = labelLayer:CreateFontString(nil, "OVERLAY")
labelLayer:Hide()

-- Where the marker is attached: the target frame's health bar and portrait (live), or the
-- settings preview's mock frames. previewState is tried first: while the settings window is open
-- out of combat, the preview keeps the marker (see Options.lua).
local healthBar, skullAnchor
local previewHost, previewState
local appliedSignature

-- The kill icon sits centred on the portrait (the preview's host carries one too).
local function positionKill()
    if not killWindow then return end
    killWindow:ClearAllPoints()
    if skullAnchor then
        killWindow:SetPoint("CENTER", skullAnchor, "CENTER")
    else
        killWindow:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    end
end

function ns.setDisplayHost(host)
    previewHost = host
    healthBar = host and host.healthBar or nil
    skullAnchor = host and (host.portrait or host.layerFrame) or nil
    appliedSignature = nil
    if not host then
        marker:ClearAllPoints()
        marker:Hide()
        markerClip:Hide()
        labelLayer:Hide()
        killWindow:Hide()
    end
    positionKill()
end

-- state: { name, min, max, value, school, health (percent of max), samples } or nil.
function ns.setPreviewState(state)
    previewState = state
    appliedSignature = nil
end

local function attach()
    local portrait, bar
    if previewHost then
        portrait, bar = previewHost.portrait, previewHost.healthBar
    elseif BIT.Plate and BIT.Plate.UnitFrame then
        local _, plateBar, platePortrait = BIT.Plate.UnitFrame("target")
        bar, portrait = plateBar, platePortrait
    else
        local tf = TargetFrame
        local main = tf and tf.TargetFrameContent and tf.TargetFrameContent.TargetFrameContentMain
        bar = (main and main.HealthBarsContainer and main.HealthBarsContainer.HealthBar)
            or (main and main.HealthBar) or TargetFrameHealthBar or (tf and tf.healthbar)
        local portraitHost = tf and tf.TargetFrameContainer
        portrait = (portraitHost and portraitHost.Portrait) or TargetFramePortrait or (tf and tf.portrait)
    end
    healthBar = bar
    skullAnchor = portrait or healthBar
    if healthBar then
        marker:ClearAllPoints()
        marker:SetAllPoints(healthBar)
    end
    positionKill()
    appliedSignature = nil
    return healthBar ~= nil
end

-- Keeps our frames above everything on the target frame; Blizzard can re-layer it at any time.
local STRATA_RANK = {
    BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8,
}
local layerCheckedAt, lastStrata, lastLevel = 0, nil, nil
local function topLayerOf(frame)
    local topStrata, topLevel = "BACKGROUND", 0
    local function visit(f, depth)
        local ok, forbidden = pcall(function() return f.IsForbidden and f:IsForbidden() end)
        if not ok or isSecret(forbidden) or forbidden then return end
        local readOK, strata, level = pcall(function() return f:GetFrameStrata(), f:GetFrameLevel() end)
        if readOK and not isSecret(strata) and not isSecret(level) and type(strata) == "string" and type(level) == "number" then
            local rank, topRank = STRATA_RANK[strata] or 0, STRATA_RANK[topStrata] or 0
            if rank > topRank then
                topStrata, topLevel = strata, level
            elseif rank == topRank and level > topLevel then
                topLevel = level
            end
        end
        if depth < 6 then
            local children = { pcall(f.GetChildren, f) }
            if children[1] then
                for i = 2, #children do visit(children[i], depth + 1) end
            end
        end
    end
    visit(frame or UIParent, 0)
    return topStrata, topLevel
end

local function updateLayering(now)
    if now - layerCheckedAt < 1 then return end
    layerCheckedAt = now
    local strata, level
    if previewHost then
        -- One strata above the options window; dropdowns and tooltips sit higher still.
        strata, level = "FULLSCREEN", 1
    else
        local ok
        ok, strata, level = pcall(topLayerOf, healthBar or TargetFrame)
        if not ok then return end
    end
    for i, frame in ipairs({ markerClip, marker, fillLayer, outlineLayer, labelLayer, killWindow, killBar }) do
        frame:SetFrameStrata(strata)
        frame:SetFrameLevel(level + i)
    end
    if strata ~= lastStrata or level ~= lastLevel then
        lastStrata, lastLevel = strata, level
        trace(string.format("LAYER target frame top is %s/%d", tostring(strata), tonumber(level) or 0))
    end
end

-- The client's small font, with a plain path kept in reach for hosts (and tests) that answer
-- without a font object.
local function labelFontPath()
    if type(GameFontNormalSmall) == "table" and type(GameFontNormalSmall.GetFont) == "function" then
        local ok, path = pcall(GameFontNormalSmall.GetFont, GameFontNormalSmall)
        if ok and type(path) == "string" then return path end
    end
    return STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end

local function applyAppearance(state)
    if not settings then return end
    local parts = {}
    for _, key in ipairs({ "fillColor", "fillOpacity", "outlineStyle", "outlineColor",
        "outlineOpacity", "pulseOutline", "showKillIcon", "killIcon", "showLabel", "labelMode", "labelPosition",
        "labelSize", "labelColor", "plateIconSize" }) do
        parts[#parts + 1] = tostring(settings[key])
    end
    parts[#parts + 1] = tostring(state and state.school)
    parts[#parts + 1] = tostring(state and state.channel)
    local signature = table.concat(parts, "|")
    if signature == appliedSignature then return end
    appliedSignature = signature

    paintDamage(fillTex, settings.fillColor, settings.fillOpacity, state)

    local or_, og, ob, oa = colorOf(settings.outlineColor, settings.outlineOpacity)
    for _, texture in ipairs(edges) do
        texture:SetVertexColor(or_, og, ob, oa)
        texture:SetShown(settings.outlineStyle ~= "none")
    end
    if settings.pulseOutline and settings.outlineStyle ~= "none" then
        outlinePulse:Play()
    else
        outlinePulse:Stop()
    end

    local icon = findById(KILL_ICONS, settings.killIcon)
    killIcon:SetTexture(icon.path)
    killIcon:SetSize(settings.plateIconSize, settings.plateIconSize)
    killWindow:SetSize(settings.plateIconSize, settings.plateIconSize)
    killBar:SetSize(KILL_BAR_LENGTH, settings.plateIconSize)
    if settings.showKillIcon then killPulse:Play() else killPulse:Stop() end
    positionKill()

    local fontPath = labelFontPath()
    label:SetFont(fontPath, settings.labelSize, "OUTLINE")
    label:SetTextColor(colorOf(settings.labelColor))
    label:ClearAllPoints()
    if healthBar then
        if settings.labelPosition == "center" then
            label:SetPoint("CENTER", healthBar, "CENTER")
        elseif settings.labelPosition == "right" then
            label:SetPoint("RIGHT", healthBar, "RIGHT", -4, 0)
        else
            label:SetPoint("RIGHT", healthBar, "LEFT", -6, 0)
        end
    end
    label:SetShown(settings.showLabel)
end

-- The label of a cast: "Frostbolt 430", "Frostbolt 410-450" or "Frostbolt 24%" of the target's
-- maximum health. maxHealth may be secret in combat; then the percent mode falls back to damage.
local function labelText(state, maxHealth)
    local name = state.name or "Cast"
    local value = math.floor((state.value or 0) + 0.5)
    if settings.labelMode == "range" then
        return string.format("%s %d-%d", name, math.floor((state.min or 0) + 0.5), math.floor((state.max or 0) + 0.5))
    end
    if settings.labelMode == "percent" then
        local readable = number(maxHealth)
        if readable and readable > 0 then
            return string.format("%s %.0f%%", name, math.min(999, (state.value or 0) / readable * 100))
        end
    end
    return string.format("%s %d", name, value)
end

local function playFlash()
    if settings.showMarker then
        flashAnim:Stop()
        flashAnim:Play()
    end
end
ns.playFlash = playFlash

local function hideAll()
    marker:Hide()
    markerClip:Hide()
    labelLayer:Hide()
    killWindow:Hide()
end

-- Draws one marker. damage may be plain (preview); maxHealth and health may be secret: they only
-- ever go into StatusBar min/max, never into Lua math. The kill icon compares the LOWEST end of
-- the range (a lethal cue must not lie: only damage the spell is certain to reach counts).
local function drawMarker(damage, maxHealth, health, state)
    local killValue = number(state.min) or damage
    local ok = pcall(function()
        if not layoutDamage(marker, markerClip, healthBar) then error("health bar layout unavailable") end
        marker:SetMinMaxValues(0, maxHealth)
        marker:SetValue(damage)
        killBar:SetMinMaxValues(0, health)
        killBar:SetValue(killValue)
    end)
    if not ok then
        hideAll()
        return false
    end
    applyAppearance(state)
    markerClip:SetShown(settings.showMarker)
    marker:SetShown(settings.showMarker)
    labelLayer:SetShown(settings.showMarker)
    killWindow:SetShown(settings.showMarker and settings.showKillIcon and state.kill ~= false)
    label:SetText(labelText(state, maxHealth))
    return true
end

-- The target frame's health bar is the host; the preview host replaces it while its window is
-- open out of combat. Returns true when the marker shows.
local function updateMarker(now)
    if previewState then
        local state = previewState
        if not state.value or state.value <= 0 or (state.health or 1) <= 0 then return hideAll() end
        updateLayering(now)
        local maxHealth = number(state.maxHealth) or math.max(state.health, 0.01)
        return drawMarker(state.value, maxHealth, math.max(state.health, 0.01), state)
    end
    if castInProgress and (not hostileTarget() or unitKey("target") ~= castInProgress.key) then
        hideAll()
        return false
    end
    if not castInProgress or castInProgress.landedAt then
        if castInProgress and castInProgress.landedAt then
            -- The hit landed: flash the marker where it was and let it fade out.
            local prediction = castInProgress.prediction
            return drawMarker(prediction.value, UnitHealthMax("target"), UnitHealth("target"), {
                name = castInProgress.name, min = prediction.min, max = prediction.max,
                value = prediction.value, school = castInProgress.view.school,
            })
        else
            hideAll()
        end
        return marker:IsShown()
    end
    if not UnitExists("target") or targetIsDead() then
        hideAll()
        return false
    end
    if not healthBar then attach() end
    if not healthBar and not previewHost then
        hideAll()
        return false
    end
    updateLayering(now)
    local prediction = castInProgress.prediction
    return drawMarker(prediction.value, UnitHealthMax("target"), UnitHealth("target"), {
        name = castInProgress.name, min = prediction.min, max = prediction.max, value = prediction.value,
        school = castInProgress.view.school, channel = castInProgress.channel,
    })
end

---------------------------------------------------------------------------------------------
-- Nameplates: the same marker, drawn on the target's own plate
---------------------------------------------------------------------------------------------

local MAX_PLATES = 40
local widgetsByPlate = {}

local function createPlateWidgets(plate, healthBar)
    local w = { healthBar = healthBar, signature = nil, displayDamage = 0 }
    w.clip = CreateFrame("Frame", nil, plate)
    w.clip:SetClipsChildren(true)
    w.marker = CreateFrame("StatusBar", nil, w.clip)
    w.marker:SetStatusBarTexture(WHITE)
    w.marker:SetStatusBarColor(0, 0, 0, 0)
    w.marker:SetPoint("TOPLEFT", healthBar, "TOPLEFT")
    w.marker:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMRIGHT")
    w.span = w.marker:GetStatusBarTexture()
    w.fill = w.marker:CreateTexture(nil, "ARTWORK")
    w.fill:SetPoint("TOPLEFT", w.span, "TOPLEFT")
    w.fill:SetPoint("BOTTOMRIGHT", w.span, "BOTTOMRIGHT")
    w.edges = {}
    local function edge(texture)
        texture:SetTexture(WHITE)
        table.insert(w.edges, texture)
        return texture
    end
    local top = edge(w.marker:CreateTexture(nil, "OVERLAY", nil, 7))
    top:SetPoint("TOPLEFT", w.span, "TOPLEFT")
    top:SetPoint("TOPRIGHT", w.span, "TOPRIGHT")
    top:SetHeight(1)
    local bottom = edge(w.marker:CreateTexture(nil, "OVERLAY", nil, 7))
    bottom:SetPoint("BOTTOMLEFT", w.span, "BOTTOMLEFT")
    bottom:SetPoint("BOTTOMRIGHT", w.span, "BOTTOMRIGHT")
    bottom:SetHeight(1)
    local left = edge(w.marker:CreateTexture(nil, "OVERLAY", nil, 7))
    left:SetPoint("TOPLEFT", w.span, "TOPLEFT")
    left:SetPoint("BOTTOMLEFT", w.span, "BOTTOMLEFT")
    left:SetWidth(1)
    local right = edge(w.marker:CreateTexture(nil, "OVERLAY", nil, 7))
    right:SetPoint("TOPRIGHT", w.span, "TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT", w.span, "BOTTOMRIGHT")
    right:SetWidth(1)
    local iconWindow = CreateFrame("Frame", nil, plate)
    iconWindow:SetSize(settings and settings.plateIconSize or 18, settings and settings.plateIconSize or 18)
    w.icon = iconWindow:CreateTexture(nil, "OVERLAY")
    w.icon:SetAllPoints()
    w.iconWindow = iconWindow
    w.marker:Hide()
    iconWindow:Hide()
    widgetsByPlate[plate] = w
    return w
end

local function plateStyleSignature()
    return table.concat({ tostring(settings.plateFillColor), tostring(settings.plateFillOpacity),
        tostring(settings.plateOutlineStyle), tostring(settings.plateOutlineColor), tostring(settings.plateOutlineOpacity),
        tostring(settings.nameplateMode), tostring(settings.plateIconSize), tostring(settings.plateIconPosition),
        tostring(settings.plateIconOffsetX), tostring(settings.plateIconOffsetY) }, "|")
end

local function applyPlateStyle(w, state)
    local signature = plateStyleSignature() .. ":" .. tostring(state and state.school)
        .. ":" .. tostring(state and state.channel)
    if w.signature == signature then return end
    w.signature = signature
    paintDamage(w.fill, settings.plateFillColor, settings.plateFillOpacity, state)
    local or_, og, ob, oa = colorOf(settings.plateOutlineColor, settings.plateOutlineOpacity)
    for _, texture in ipairs(w.edges) do
        texture:SetVertexColor(or_, og, ob, oa)
        texture:SetShown(settings.plateOutlineStyle ~= "none")
    end
    local size = settings.plateIconSize
    w.iconWindow:SetSize(size, size)
    w.icon:SetSize(size, size)
    w.icon:SetTexture(findById(KILL_ICONS, "impact").path)
    w.iconWindow:ClearAllPoints()
    local x, y = settings.plateIconOffsetX, settings.plateIconOffsetY
    if settings.plateIconPosition == "left" then
        w.iconWindow:SetPoint("RIGHT", w.healthBar, "LEFT", -4 + x, y)
    elseif settings.plateIconPosition == "above" then
        w.iconWindow:SetPoint("BOTTOM", w.healthBar, "TOP", x, 4 + y)
    else
        w.iconWindow:SetPoint("LEFT", w.healthBar, "RIGHT", 4 + x, y)
    end
end

local function hidePlateWidgets(w)
    w.displayDamage = 0
    w.marker:Hide()
    w.clip:Hide()
    w.iconWindow:Hide()
end

-- Above the plate's health bar, in its strata, on every draw: the client re-levels plates while
-- they live (the target's, overlapping ones) and can otherwise cover a marker levelled once. The
-- level can be secret on Forever; then a fixed high level.
local FALLBACK_PLATE_LEVEL = 200
local function keepPlateAbove(w)
    local healthBar = w.healthBar
    local ok, level = pcall(healthBar.GetFrameLevel, healthBar)
    if not ok or isSecret(level) or type(level) ~= "number" then level = FALLBACK_PLATE_LEVEL end
    local okStrata, strata = pcall(healthBar.GetFrameStrata, healthBar)
    if not okStrata or isSecret(strata) or type(strata) ~= "string" then strata = nil end
    if level == w.barLevel and strata == w.barStrata then return end
    w.barLevel, w.barStrata = level, strata
    if strata then
        w.clip:SetFrameStrata(strata)
        w.marker:SetFrameStrata(strata)
        w.iconWindow:SetFrameStrata(strata)
    end
    -- The icon sits well above: plate decorations beside the bar (the level badge) must not cover it.
    w.clip:SetFrameLevel(level + 5)
    w.marker:SetFrameLevel(level + 6)
    w.iconWindow:SetFrameLevel(level + 20)
end

local function drawPlate(w, damage, maxHealth, health, state)
    keepPlateAbove(w)
    applyPlateStyle(w, state)
    local ok = pcall(function()
        if not layoutDamage(w.marker, w.clip, w.healthBar) then error("health bar layout unavailable") end
        w.marker:SetMinMaxValues(0, maxHealth)
        w.marker:SetValue(damage)
    end)
    if not ok then
        hidePlateWidgets(w)
        return false
    end
    w.marker:SetShown(settings.showMarker)
    w.clip:SetShown(settings.showMarker)
    w.displayDamage = settings.showMarker and damage or 0
    w.iconWindow:SetShown(settings.showMarker and settings.nameplateMode == "markerIcon")
    return true
end

local function widgetsFor(plate, healthBar)
    local w = widgetsByPlate[plate]
    if w then
        if w.healthBar ~= healthBar then
            w.healthBar = healthBar
            w.marker:ClearAllPoints()
            w.marker:SetPoint("TOPLEFT", healthBar, "TOPLEFT")
            w.marker:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMRIGHT")
            w.signature = nil
        end
        return w
    end
    return createPlateWidgets(plate, healthBar)
end

function ns.nameplateDamageBase(plate, bar)
    local w = widgetsByPlate[plate]
    return w and w.healthBar == bar and w.displayDamage or 0
end

-- The options window's mock nameplate: { plate, healthBar }, drawn by the same code as real
-- plates with plain numbers (see Options.lua).
local previewPlate
function ns.setPlatePreview(host)
    local old = previewPlate
    previewPlate = host
    if old and old ~= host then
        local w = widgetsByPlate[old.plate]
        if w then hidePlateWidgets(w) end
    end
end

local seenPlates = {}

-- The target's own plate, if one is up: the target's plate via its token, else matched by key.
local function findTargetPlate(unit)
    if not (C_NamePlate and type(C_NamePlate.GetNamePlateForUnit) == "function") then return nil end
    local plate = read(C_NamePlate.GetNamePlateForUnit, unit)
    if type(plate) == "table" then return plate end
    if not castInProgress then return nil end
    for i = 1, MAX_PLATES do
        local unit = "nameplate" .. i
        if UnitExists(unit) then
            local key = unitKey(unit)
            if key and key == castInProgress.key then
                plate = read(C_NamePlate.GetNamePlateForUnit, unit)
                if type(plate) == "table" then return plate end
            end
        end
    end
    return nil
end

local function targetKnownDead(unit)
    if type(UnitIsDeadOrGhost) ~= "function" then return false end
    local ok, dead = pcall(UnitIsDeadOrGhost, unit)
    return ok and not isSecret(dead) and dead == true
end

local function refreshPlates(now)
    wipe(seenPlates)
    local unit = castUnit()
    if castInProgress and not castInProgress.softTarget and unitKey("target") ~= castInProgress.key then unit = nil end
    -- The options preview keeps the plate marker; the real plates stay hidden then.
    if previewPlate then
        seenPlates[previewPlate.plate] = true
        local w = widgetsFor(previewPlate.plate, previewPlate.healthBar)
        if previewState and previewState.value and previewState.value > 0 and settings.nameplateMode ~= "off"
            and (previewState.health or 1) > 0 then
            drawPlate(w, previewState.value, number(previewState.maxHealth) or math.max(previewState.health, 0.01),
                math.max(previewState.health, 0.01), previewState)
        else
            hidePlateWidgets(w)
        end
    elseif settings.nameplateMode ~= "off" and castInProgress and not castInProgress.landedAt
        and unit and not targetKnownDead(unit) then
        local plate = findTargetPlate(unit)
        if plate then
            local forbidden = read(plate.IsForbidden, plate)
            if not forbidden then
                seenPlates[plate] = true
                local healthBar = BIT.Plate and BIT.Plate.HealthBar and BIT.Plate.HealthBar(plate)
                if healthBar then
                    local w = widgetsFor(plate, healthBar)
                    drawPlate(w, castInProgress.prediction.value, UnitHealthMax(unit), UnitHealth(unit), {
                        school = castInProgress.view.school, channel = castInProgress.channel,
                    })
                end
            end
        end
    end
    for plate, w in pairs(widgetsByPlate) do
        if not seenPlates[plate] then hidePlateWidgets(w) end
    end
end

---------------------------------------------------------------------------------------------
-- Refresh loop (DoTInfo's pattern): the OnUpdate tick redraws; errors are reported once
---------------------------------------------------------------------------------------------

local reportedErrors = {}
local function refresh()
    local now = GetTime()
    housekeep(now)
    local ok = pcall(updateMarker, now)
    if not ok then
        dropCast("display error")
        hideAll()
    end
    refreshPlates(now)
end

local function safeRefresh()
    local ok, err = pcall(refresh)
    if not ok and not reportedErrors[err] then
        reportedErrors[err] = true
        trace("ERROR in display update: " .. tostring(err))
        print("Display error (logged): " .. tostring(err))
    end
end

---------------------------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------------------------

function ns.ensureDB()
    settings = BIT.Settings("CastPrediction", DEFAULTS)
    if settings.markerStyleVersion ~= 2 then
        settings.fillColor, settings.plateFillColor = "school", "school"
        settings.markerStyleVersion = 2
    end
    if type(settings.learned) ~= "table" then settings.learned = {} end
    if type(settings.log) ~= "table" then settings.log = {} end
    if type(settings.talentForce) ~= "table" then settings.talentForce = {} end
    if type(settings.auraForce) ~= "table" then settings.auraForce = {} end
    -- A number the settings want but a stale save holds as a string or nil.
    settings.manualPowerValue = tonumber(settings.manualPowerValue) or 0
    ns.settings = settings
    return settings
end
ns.DEFAULTS = DEFAULTS

function ns.resetLog()
    if settings then settings.log = {} end
end

---------------------------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------------------------

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
pcall(frame.RegisterEvent, frame, "PLAYER_SOFT_ENEMY_CHANGED")
frame:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
frame:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player")
frame:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "player")
frame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
frame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", "player")
frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
frame:RegisterEvent("UNIT_COMBAT")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
-- Never register COMBAT_LOG_EVENT_UNFILTERED: Forever forbids it and shows a "blocked" popup.

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        if ... ~= ADDON_NAME then return end
        if BIT.ShouldRun and not BIT.ShouldRun("CastPrediction") then
            ns.off = true
            self:UnregisterAllEvents()
            self:SetScript("OnUpdate", nil)
            return
        end
        ns.ensureDB()
        trace("===== session start =====")
        attach()
        self:UnregisterEvent("ADDON_LOADED")

    elseif not settings then
        return

    elseif event == "PLAYER_ENTERING_WORLD" then
        dropCast("loading screen")
        wipe(recipients)
        bonusReadAt = 0
        viewCache = {}
        if ns.Talents then ns.Talents.Invalidate() end
        safeRefresh()

    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        if ns.Talents then ns.Talents.Invalidate() end
        dropCast("specialization changed")
        safeRefresh()

    elseif event == "PLAYER_TARGET_CHANGED" then
        dropCast("target changed")
        for _, sent in pairs(recipients) do
            if sent.key == "target" then sent.key = nil end
        end
        safeRefresh()

    elseif event == "PLAYER_SOFT_ENEMY_CHANGED" then
        safeRefresh()

    elseif event == "UNIT_SPELLCAST_SENT" then
        local _, targetName, castGUID, spellID = ...
        onCastSent(targetName, castGUID, spellID)

    elseif event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        local _, castGUID, spellID = ...
        if onCastStart(castGUID, spellID, event == "UNIT_SPELLCAST_CHANNEL_START") then safeRefresh() end

    elseif event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
        local _, castGUID, spellID = ...
        if castInProgress and castInProgress.channel and sameCast(castInProgress, castGUID, spellID) then
            local _, endsAt = channelTimes(castInProgress.spellID)
            if endsAt then castInProgress.endsAt = endsAt else dropCast("channel timing unavailable") end
            safeRefresh()
        end

    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        local _, castGUID, spellID = ...
        if castInProgress and castInProgress.channel and sameCast(castInProgress, castGUID, spellID) then
            dropCast("channel stopped")
            safeRefresh()
        end

    elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_FAILED"
        or event == "UNIT_SPELLCAST_INTERRUPTED" then
        local _, castGUID, spellID = ...
        if onCastEnded(event, castGUID, spellID) then safeRefresh() end

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local _, castGUID, spellID = ...
        if onCastSucceeded(castGUID, spellID) then safeRefresh() end

    elseif event == "UNIT_COMBAT" then
        if onUnitCombat(...) then
            safeRefresh()
            playFlash()
        end
    end
end)

local sinceUpdate = 0
frame:SetScript("OnUpdate", function(self, elapsed)
    if not settings then return end
    sinceUpdate = sinceUpdate + elapsed
    if sinceUpdate < UPDATE_INTERVAL then return end
    sinceUpdate = 0
    safeRefresh()
end)

---------------------------------------------------------------------------------------------
-- Commands (/upt castpred, /upt castprobe, ...)
---------------------------------------------------------------------------------------------

if BIT.RegisterCommand then
    BIT.RegisterCommand("castpred", function(rest)
        local cmd = strlower(strtrim(rest or ""))
        if cmd == "" or cmd == "options" or cmd == "config" then
            if BIT.OpenSettings then BIT.OpenSettings("CastPrediction") end
        elseif cmd == "line" then
            settings.showMarker = not settings.showMarker
            print("Health bar marker " .. (settings.showMarker and "ON" or "OFF") .. ".")
        elseif cmd == "reset" then
            ns.resetLearned()
        elseif cmd == "talents" then
            if ns.Talents and type(ns.Talents.ProbeLines) == "function" then
                for _, line in ipairs(ns.Talents.ProbeLines()) do print(line) end
            else
                print("Talents file not loaded.")
            end
        elseif cmd == "auras" then
            if ns.Auras and type(ns.Auras.ProbeLines) == "function" then
                for _, line in ipairs(ns.Auras.ProbeLines()) do print(line) end
            else
                print("Auras file not loaded.")
            end
        elseif cmd == "debug" then
            settings.debug = not settings.debug
            print("Debug " .. (settings.debug and "ON" or "OFF") .. ".")
        elseif cmd == "help" then
            print("/upt castpred - open the settings; line - toggle the marker; talents - what the talent tree "
                .. "answers; auras - what buffs/debuffs are readable; reset - forget learned factors; debug - echo the trace log")
        else
            print("CastPrediction: /upt castpred [line|talents|auras|reset|debug]")
        end
    end)
end

-- What spell is on the player's cast bar right now (diagnostics).
local function probeSpellID()
    if type(UnitChannelInfo) == "function" then
        local ok, _, _, _, _, _, _, _, spellID = pcall(UnitChannelInfo, "player")
        if ok and number(spellID) then return spellID, true end
    end
    if type(UnitCastingInfo) == "function" then
        local ok, _, _, _, _, _, _, _, _, spellID = pcall(UnitCastingInfo, "player")
        if ok then return number(spellID), false end
    end
end

if BIT.RegisterCommand then
    BIT.RegisterCommand("castprobe", function()
        local spellID, channel = probeSpellID()
        if not spellID then
            print("No spell is being cast right now.")
            return
        end
        local view = buildView(spellID, channel)
        local name = spellName(spellID) or "?"
        if not view then
            print(string.format("%s (id %d): no readable damage description for this cast.", name, spellID))
            return
        end
        local prediction = predictionFor(view, spellID)
        print(string.format("%s (id %d): %d-%d %s%s; showing %d%s", name, spellID, math.floor(view.min + 0.5),
            math.floor(view.max + 0.5), tostring(view.school), view.estimated and " (with spell power)" or "",
            math.floor(prediction.value + 0.5),
            prediction.samples and ("; factor from " .. prediction.samples .. " hit(s)") or ""))
    end)
end

---------------------------------------------------------------------------------------------
-- For the tests
---------------------------------------------------------------------------------------------

ns._settings = function() return settings end
ns._cast = function() return castInProgress end
ns._colorList = function() return COLOR_LIST end
ns._startCast = onCastStart
ns._succeedCast = onCastSucceeded
ns._endCast = onCastEnded
ns._combat = onUnitCombat
ns._housekeep = housekeep
ns._refresh = safeRefresh
ns._marker = function() return marker end
ns._fill = function() return fillTex end
ns._plateWidgets = function(plate) return widgetsByPlate[plate] end
ns._killWindow = function() return killWindow end
ns._killBar = function() return killBar end
ns._label = function() return label end
ns._viewCache = function() return viewCache end
ns._learned = function() return settings and settings.learned or {} end
