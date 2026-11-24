-- UsefulPlatesAndTooltips module DoTInfo: execute / finisher kill icon.
-- Ported from DoesItDie PR #39, #44, #48, #53 and 1241c54 by Joe Greive (MIT; see LICENSE-DoesItDie.txt).
--
-- Shows the player's execute ability (Execute, Hammer of Wrath, Shadow Word: Death, Shadowburn) or finisher
-- (Ferocious Bite, Eviscerate) beside the target frame and enemy nameplates when its estimated hit would kill.
-- Uses the clipped-StatusBar secret-HP trick so target/nameplate health is never read in Lua. Forever only.

local _, BIT = ...
local ns = BIT.Module("DoTInfo")

local BAR_LENGTH = 10000
local UPDATE_INTERVAL = 0.1
local LEARN_RATIO_MIN, LEARN_RATIO_MAX = 0.5, 3
local LEARN_WEIGHT_CAP = 10
local SPELL_CRIT_MULTIPLIER, MELEE_CRIT_MULTIPLIER = 1.5, 2
local RAGE, ENERGY = 1, 3
local POWER_NAMES = { [RAGE] = "rage", [ENERGY] = "energy" }

-- Per class: English name and Classic Era spell IDs (highest rank first; Forever renumbers some ranks, so
-- findAbility checks IDs, name and the spellbook and picks the strongest known rank). Ferocious Bite base cost
-- is 25 energy on Forever (overridden live by C_Spell.GetSpellPowerCost when readable).
local EXECUTES = {
    WARRIOR = { name = "Execute", ids = { 20662, 20661, 20660, 20658, 5308 }, melee = true, power = RAGE, cost = 15 },
    DRUID = { name = "Ferocious Bite", ids = { 31018, 22829, 22828, 22827, 22568 }, melee = true, finisher = true,
        power = ENERGY, cost = 25 },
    ROGUE = { name = "Eviscerate", ids = { 31016, 11300, 11299, 8624, 8623, 6762, 6761, 6760, 2098 }, melee = true,
        finisher = true },
    PALADIN = { name = "Hammer of Wrath", ids = { 24239, 24274, 24275 }, school = 2 },
    PRIEST = { name = "Shadow Word: Death", ids = {}, school = 6 },
    WARLOCK = { name = "Shadowburn", ids = { 18871, 18870, 18869, 18868, 18867, 17877 }, school = 6 },
}

local db

local function isSecret(v)
    if type(issecretvalue) ~= "function" then return false end
    local ok, r = pcall(issecretvalue, v)
    return ok and r or false
end

local function readable(kind, fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn, ...)
    if ok and not isSecret(v) and type(v) == kind then return v end
end

local function trace(msg)
    if ns.trace then ns.trace(msg) end
end

---------------------------------------------------------------------------
-- Ability discovery & estimate
---------------------------------------------------------------------------

local ability
local parseHit

local function knows(spellID)
    if type(IsPlayerSpell) == "function" then return readable("boolean", IsPlayerSpell, spellID) == true end
    return readable("boolean", IsSpellKnown, spellID) == true
end

local function spellbookIDs(names)
    local found = {}
    local SB = C_SpellBook
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or "spell"
    for index = 1, 1000 do
        local id, name
        if SB and SB.GetSpellBookItemInfo then
            local info = readable("table", SB.GetSpellBookItemInfo, index, bank)
            if not info then break end
            id, name = info.spellID or info.actionID, info.name
        elseif GetSpellBookItemInfo then
            local ok, kind, spellID = pcall(GetSpellBookItemInfo, index, "spell")
            if not ok or not kind then break end
            if kind == "SPELL" then id = spellID end
        else
            break
        end
        if type(id) == "number" and not isSecret(id) then
            name = name or readable("string", C_Spell and C_Spell.GetSpellName, id)
            if name and names[name] then found[#found + 1] = id end
        end
    end
    return found
end

local function findAbility()
    local _, class = UnitClass("player")
    local info = EXECUTES[class]
    if not info then return nil, nil, "class " .. tostring(class) .. " has none" end
    local names = { [info.name] = true }
    for _, id in ipairs(info.ids) do
        local name = readable("string", C_Spell and C_Spell.GetSpellName, id)
        if name then names[name] = true end
    end
    local candidates, seen = {}, {}
    local function add(id)
        if type(id) == "number" and not isSecret(id) and not seen[id] then
            seen[id] = true
            candidates[#candidates + 1] = id
        end
    end
    for _, id in ipairs(info.ids) do if knows(id) then add(id) end end
    for name in pairs(names) do
        local spell = C_Spell and C_Spell.GetSpellInfo and readable("table", C_Spell.GetSpellInfo, name)
        local id = spell and spell.spellID
        if type(id) == "number" and not isSecret(id) and (knows(id) or not info.ids[1]) then add(id) end
    end
    local ok, fromBook = pcall(spellbookIDs, names)
    if ok then for _, id in ipairs(fromBook) do add(id) end end
    local best, bestHit, parts = nil, -1, {}
    for _, id in ipairs(candidates) do
        local low = parseHit(readable("string", C_Spell and C_Spell.GetSpellDescription, id), 5)
        parts[#parts + 1] = id .. "=" .. tostring(low)
        if (low or 0) > bestHit then best, bestHit = id, low or 0 end
    end
    if not best then return nil, nil, "none of " .. info.name .. "'s ranks known" end
    return best, info, table.concat(parts, " ")
end

local ABILITY_RETRY_SECONDS = 3
local lastAbilityTry, lastAbilityWhy = -math.huge, nil

local function updateAbility()
    lastAbilityTry = GetTime()
    local id, info, why = findAbility()
    if not id then
        ability = nil
        if why ~= lastAbilityWhy then
            lastAbilityWhy = why
            trace("EXEC no ability watched: " .. tostring(why))
        end
        return
    end
    if id == (ability and ability.spellID) then return end
    lastAbilityWhy = nil
    ability = { spellID = id, info = info,
        name = readable("string", C_Spell and C_Spell.GetSpellName, id) or info.name,
        icon = readable("number", C_Spell and C_Spell.GetSpellTexture, id)
            or readable("string", C_Spell and C_Spell.GetSpellTexture, id) or "Interface\\Icons\\INV_Sword_48" }
    trace(string.format("EXEC watching %s (%d); ranks known, low end at 5 points: %s", ability.name, id, why))
end

-- Strip thousands separators ("1,020", "1.020", "1 020", "1\194\160020") while leaving decimals ("2.0") intact.
local function plainNumbers(desc)
    for _ = 1, 2 do
        desc = desc:gsub("(%d),(%d%d%d)%f[^%d]", "%1%2")
        desc = desc:gsub("(%d)%.(%d%d%d)%f[^%d]", "%1%2")
        desc = desc:gsub("(%d)\194\160(%d%d%d)%f[^%d]", "%1%2")
        desc = desc:gsub("(%d) (%d%d%d)%f[^%d]", "%1%2")
    end
    return desc
end

function parseHit(desc, points)
    if type(desc) ~= "string" or isSecret(desc) then return nil end
    desc = plainNumbers(desc)
    local perPower = desc:match("each extra point of %a+ into (%d+%.?%d*)")
    local rows, highest = {}, 0
    for n, rowLow, rowHigh in desc:gmatch("(%d+)[^%d\n]-:%s*(%d+)%s*%-%s*(%d+)") do
        n = tonumber(n)
        rows[n] = { tonumber(rowLow), tonumber(rowHigh) }
        highest = math.max(highest, n)
    end
    if highest > 0 then
        local row = rows[math.max(1, math.min(points or 1, highest))] or rows[1] or rows[highest]
        return row[1], row[2], tonumber(perPower) or 0
    end
    local low, high = desc:match("(%d+) to (%d+)")
    if not low then low = desc:match("(%d+) damage") end
    if not low then
        local plain = desc:gsub("%d+%s*%%", "")
        low, high = plain:match("(%d+)[^%d]-(%d+)")
        local between = low and plain:match(low .. "([^%d]-)" .. high)
        if not between or #between > 8 then
            low, high = plain:match("(%d+)"), nil
        end
    end
    low = tonumber(low)
    if not low then return nil end
    return low, tonumber(high) or low, tonumber(perPower) or 0
end

local function hitOf(spellID, points)
    return parseHit(readable("string", C_Spell and C_Spell.GetSpellDescription, spellID), points)
end

local function extraPower(spellID, info)
    if not info.power then return 0 end
    local power = readable("number", UnitPower, "player", info.power)
    if not power then return nil end
    local cost = info.cost or 0
    local costs = C_Spell and readable("table", C_Spell.GetSpellPowerCost, spellID)
    for _, c in ipairs(costs or {}) do
        if not isSecret(c.type) and c.type == info.power and not isSecret(c.cost) and type(c.cost) == "number" then
            cost = c.cost
        end
    end
    return math.max(0, power - cost)
end

local function comboPoints()
    if type(ns.currentComboPoints) ~= "function" then return 1, false end
    local points, source = ns.currentComboPoints()
    if not points then return 1, false end
    return points, source == "read"
end

local function learnedRatio(spellID)
    local d = db or ns.db
    local saved = d and d.execRatios and d.execRatios[spellID]
    return saved and saved.ratio or 1
end

local function estimate()
    if not ability then return nil end
    local info, points = ability.info, nil
    if info.finisher then
        points = comboPoints()
        if points <= 0 then
            return nil, string.format(BIT.L("%s: no combo points, so no icon."), ability.name)
        end
    end
    local low, _, perPower = hitOf(ability.spellID, points)
    if not low then
        local desc = C_Spell and C_Spell.GetSpellDescription and select(2, pcall(C_Spell.GetSpellDescription, ability.spellID))
        if C_Spell and C_Spell.RequestLoadSpellData then pcall(C_Spell.RequestLoadSpellData, ability.spellID) end
        local shown = desc == nil and "nil" or isSecret(desc) and "secret" or string.format("%q", tostring(desc):sub(1, 160))
        return nil, string.format(BIT.L("%s: its tooltip has no damage number this addon can read."), ability.name)
            .. string.format(" (%d: %s)", ability.spellID, shown)
    end
    local extra = perPower > 0 and extraPower(ability.spellID, info) or 0
    local ratio = learnedRatio(ability.spellID)
    local hit = (low + perPower * (extra or 0)) * ratio
    return hit, string.format("%s: %s%d%s x %.2f learned = %d", ability.name,
        points and string.format("%d point(s) ", points) or "", low,
        perPower > 0 and string.format(" + %d %s x %g", extra or 0, POWER_NAMES[info.power] or "power", perPower)
        or "", ratio, hit)
end

---------------------------------------------------------------------------
-- Learning from Blizzard's damage meter (Core/Meter.lua)
---------------------------------------------------------------------------

local tally = {}
local atSend = {}

local function onCastSent(castGUID, spellID)
    if not ability or isSecret(spellID) or spellID ~= ability.spellID then return end
    if not castGUID or isSecret(castGUID) then return end
    local sent = { extra = extraPower(spellID, ability.info) or false }
    if ability.info.finisher then sent.points, sent.pointsRead = comboPoints() end
    atSend[castGUID] = sent
end

local function onCastSucceeded(castGUID, spellID)
    if not ability or isSecret(spellID) or spellID ~= ability.spellID then return end
    local sent = castGUID and not isSecret(castGUID) and atSend[castGUID]
    if sent then atSend[castGUID] = nil end
    local finisher = ability.info.finisher
    local low, high, perPower = hitOf(spellID, sent and sent.points)
    if not low then return end
    local t = tally[spellID] or { casts = 0, expected = 0 }
    tally[spellID] = t
    t.casts = t.casts + 1
    local extra = sent and sent.extra
    if perPower > 0 and not extra then
        t.unclear = (POWER_NAMES[ability.info.power] or "power") .. " wasn't readable at a cast"
    elseif finisher and not (sent and sent.pointsRead and sent.points and sent.points > 0) then
        t.unclear = "combo points weren't readable at a cast (counted ones can be too few)"
    end
    t.expected = t.expected + (low + high) / 2 + perPower * (extra or 0)
end

local function critFactor(info)
    local chance
    if info.melee then
        chance = readable("number", GetCritChance)
    else
        chance = readable("number", GetSpellCritChance, info.school)
    end
    local multiplier = info.melee and MELEE_CRIT_MULTIPLIER or SPELL_CRIT_MULTIPLIER
    return 1 + math.max(0, math.min(100, chance or 0)) / 100 * (multiplier - 1), chance
end

-- totals: { [spellID] = damage } from BIT.Meter.Totals (or array of { spellID, totalAmount } for tests).
local function learn(totalsOrSpells, counted)
    db = db or ns.db
    if not db then return 0 end
    db.execRatios = db.execRatios or {}
    local totals = {}
    if type(totalsOrSpells) == "table" then
        if #totalsOrSpells > 0 and type(totalsOrSpells[1]) == "table" then
            for _, sp in ipairs(totalsOrSpells) do
                if not isSecret(sp.spellID) and not isSecret(sp.totalAmount) and type(sp.totalAmount) == "number" then
                    totals[sp.spellID] = sp.totalAmount
                end
            end
        else
            for id, amount in pairs(totalsOrSpells) do
                if type(id) == "number" and type(amount) == "number" and not isSecret(amount) then
                    totals[id] = amount
                end
            end
        end
    end
    local learned = 0
    for spellID, t in pairs(counted) do
        local name = readable("string", C_Spell and C_Spell.GetSpellName, spellID) or tostring(spellID)
        local total = totals[spellID]
        if t.unclear then
            trace(string.format("EXEC LEARN %s skipped: %s", name, t.unclear))
        elseif not total or total <= 0 then
            trace(string.format("EXEC LEARN %s skipped: no damage meter total (%d cast(s), all missed?)", name,
                t.casts))
        else
            local factor, chance = critFactor(ability and ability.info or {})
            local ratio = total / factor / t.expected
            if ratio < LEARN_RATIO_MIN or ratio > LEARN_RATIO_MAX then
                trace(string.format("EXEC LEARN %s skipped: meter %d over %d cast(s) is %.2fx the tooltip", name,
                    total, t.casts, ratio))
            else
                local old = db.execRatios[spellID]
                local weight = old and math.min(old.weight or 0, LEARN_WEIGHT_CAP) or 0
                local blended = ((old and old.ratio or 0) * weight + ratio * t.casts) / (weight + t.casts)
                db.execRatios[spellID] = { ratio = math.floor(blended * 1000 + 0.5) / 1000, weight = weight + t.casts }
                learned = learned + 1
                trace(string.format("EXEC LEARN %s: meter %d over %d cast(s), crit %s%% (x%.2f) = %.2fx the "
                    .. "tooltip, saved %.3f", name, total, t.casts, chance and string.format("%.1f", chance) or "?",
                    factor, ratio, db.execRatios[spellID].ratio))
            end
        end
    end
    return learned
end

local function learnAfterCombat(counted, triesLeft)
    if type(InCombatLockdown) == "function" and InCombatLockdown() then
        trace("EXEC LEARN skipped: a new fight started before the damage meter could be read")
        return
    end
    if not (BIT.Meter and type(BIT.Meter.Totals) == "function") then return end
    local damage, why = BIT.Meter.Totals(triesLeft <= 0)
    if not damage then
        if why == "wait" and triesLeft > 0 and C_Timer and type(C_Timer.After) == "function" then
            C_Timer.After(BIT.Meter.RETRY or 0.5, function() learnAfterCombat(counted, triesLeft - 1) end)
            return
        end
        trace("EXEC LEARN skipped: damage meter " .. (why == "wait" and "still empty or hidden" or tostring(why)))
        return
    end
    learn(damage, counted)
end

---------------------------------------------------------------------------
-- Target frame execute icon
---------------------------------------------------------------------------

local window = CreateFrame("Frame", "UsefulPlatesAndTooltips_DoTInfoExecute", UIParent)
window:SetClipsChildren(true)
window:SetFrameStrata("HIGH")
window:Hide()
if BIT.OwnOverlays then BIT.OwnOverlays[window] = true end

local bar = CreateFrame("StatusBar", nil, window)
bar:SetPoint("RIGHT", window, "RIGHT")
bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
bar:SetStatusBarColor(0, 0, 0, 0)

local icon = bar:CreateTexture(nil, "OVERLAY")
icon:SetPoint("RIGHT", bar:GetStatusBarTexture(), "RIGHT")

local pulse = icon:CreateAnimationGroup()
pulse:SetLooping("BOUNCE")
do
    local fade = pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0.5)
    fade:SetDuration(0.6)
    fade:SetSmoothing("IN_OUT")
end

local testUntil
local lastAnchor, lastSize, lastX, lastY, lastIcon, lastPreview

local function place(anchor, preview)
    local size = db.execSize or 32
    local ox, oy = db.execOffsetX or 0, db.execOffsetY or 8
    if anchor == lastAnchor and size == lastSize and ox == lastX and oy == lastY
        and ability.icon == lastIcon and preview == lastPreview then
        return
    end
    lastAnchor, lastSize, lastX, lastY, lastIcon, lastPreview = anchor, size, ox, oy, ability.icon, preview
    window:SetFrameStrata(preview and "FULLSCREEN" or "HIGH")
    window:SetSize(size, size)
    bar:SetSize(BAR_LENGTH, size)
    icon:SetSize(size, size)
    icon:SetTexture(ability.icon)
    window:ClearAllPoints()
    window:SetPoint("BOTTOM", anchor, "TOP", ox, oy)
    pulse:Play()
end

local function targetDead()
    return readable("boolean", UnitIsDead, "target") == true
end

local function usable()
    if not (C_Spell and C_Spell.IsSpellUsable) then return true end
    return readable("boolean", C_Spell.IsSpellUsable, ability.spellID) ~= false
end

local lastTraced
local function update()
    if not ability and GetTime() - lastAbilityTry >= ABILITY_RETRY_SECONDS then updateAbility() end
    local anchor, visibilityFrame, preview
    if type(ns.killIconAnchor) == "function" then
        anchor, visibilityFrame, preview = ns.killIconAnchor()
    end
    if not (db.execShow and ability and anchor) then return window:Hide() end
    place(anchor, preview)
    if preview or (testUntil and GetTime() < testUntil) then
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(1)
        return window:Show()
    end
    if not UnitExists("target") or targetDead() or readable("boolean", UnitCanAttack, "player", "target") == false then
        return window:Hide()
    end
    if visibilityFrame and readable("boolean", visibilityFrame.IsVisible, visibilityFrame) == false then
        return window:Hide()
    end
    local hit, how = estimate()
    if not hit or not usable() then return window:Hide() end
    if how ~= lastTraced then
        lastTraced = how
        trace("EXEC estimate " .. how)
    end
    local ok = pcall(function()
        bar:SetMinMaxValues(0, UnitHealth("target"))
        bar:SetValue(hit)
    end)
    window:SetShown(ok)
end

---------------------------------------------------------------------------
-- Enemy nameplate execute icons
---------------------------------------------------------------------------

local MAX_PLATES = 40
local PLATE_LEVEL_ABOVE, FALLBACK_LEVEL = 22, 200
local plateIcons = {}
local shownHosts = {}

local function plateIconFor(host, plate, healthBar, pooled)
    local p = plateIcons[host]
    if not p then
        p = { window = CreateFrame("Frame", nil, host) }
        p.window:SetClipsChildren(true)
        p.bar = CreateFrame("StatusBar", nil, p.window)
        p.bar:SetPoint("RIGHT", p.window, "RIGHT")
        p.bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
        p.bar:SetStatusBarColor(0, 0, 0, 0)
        p.icon = p.bar:CreateTexture(nil, "OVERLAY")
        p.icon:SetPoint("RIGHT", p.bar:GetStatusBarTexture(), "RIGHT")
        if pooled and type(host.HookScript) == "function" then
            host:HookScript("OnHide", function() p.window:Hide() end)
        end
        plateIcons[host] = p
    end
    if p.healthBar ~= healthBar then
        p.healthBar, p.layoutKey = healthBar, nil
        local strata = readable("string", healthBar.GetFrameStrata, healthBar)
        if strata then
            p.window:SetFrameStrata(strata)
            p.bar:SetFrameStrata(strata)
        end
        local level = readable("number", healthBar.GetFrameLevel, healthBar) or FALLBACK_LEVEL
        p.window:SetFrameLevel(level + PLATE_LEVEL_ABOVE)
        p.bar:SetFrameLevel(level + PLATE_LEVEL_ABOVE + 1)
    end
    local size = db.execPlateSize or 22
    local pos = db.execPlatePosition or "right"
    local ox, oy = db.execPlateOffsetX or 0, db.execPlateOffsetY or 0
    local rightPad = pos == "right" and BIT.Plate and type(BIT.Plate.RightEdgeOffset) == "function"
        and BIT.Plate.RightEdgeOffset(plate, healthBar) or 4
    local layoutKey = size .. ":" .. pos .. ":" .. ox .. ":" .. oy .. ":" .. rightPad .. ":" .. tostring(ability.icon)
    if p.layoutKey ~= layoutKey then
        p.layoutKey, p.size, p.texture = layoutKey, size, ability.icon
        p.window:SetSize(size, size)
        p.bar:SetSize(BAR_LENGTH, size)
        p.icon:SetSize(size, size)
        p.icon:SetTexture(ability.icon)
        p.window:ClearAllPoints()
        if pos == "left" then
            p.window:SetPoint("RIGHT", healthBar, "LEFT", -4 + ox, oy)
        elseif pos == "above" then
            p.window:SetPoint("BOTTOM", healthBar, "TOP", ox, 4 + oy)
        elseif pos == "below" then
            p.window:SetPoint("TOP", healthBar, "BOTTOM", ox, -4 + oy)
        else
            p.window:SetPoint("LEFT", healthBar, "RIGHT", rightPad + ox, oy)
        end
    end
    return p
end

local function drawPlateIcon(host, plate, healthBar, pooled, health, hit)
    local p = plateIconFor(host, plate, healthBar, pooled)
    local ok = pcall(function()
        p.bar:SetMinMaxValues(0, health)
        p.bar:SetValue(hit)
    end)
    p.window:SetShown(ok)
    shownHosts[host] = ok or nil
    if ok then
        local readableHealth = not isSecret(health) and type(health) == "number" and health or nil
        p.active = readableHealth == nil or hit >= readableHealth
    else
        p.active = false
    end
end

local function updatePlate(unit, plate, targetPlate, testing)
    if readable("boolean", UnitIsDead, unit) == true then return end
    if readable("boolean", UnitCanAttack, "player", unit) == false then return end
    local isTarget = targetPlate ~= nil and plate == targetPlate
    if ability.info.finisher and not isTarget then return end
    local healthBar = ns.plateHealthBar(plate)
    if not healthBar then return end
    local host = BIT.Plate and BIT.Plate.WidgetHost and BIT.Plate.WidgetHost(plate) or plate
    if testing then return drawPlateIcon(host, plate, healthBar, host ~= plate, 1, 1) end
    local hit = estimate()
    if not hit or (isTarget and not usable()) then return end
    drawPlateIcon(host, plate, healthBar, host ~= plate, UnitHealth(unit), hit)
end

local function updatePlates()
    local previousHosts = shownHosts
    shownHosts = {}
    if db.execShow and db.execPlates and ability and ns.plateHealthBar then
        local preview = ns.platePreview and ns.platePreview()
        if preview then drawPlateIcon(preview.plate, preview.plate, preview.healthBar, false, 1, 1) end
        if C_NamePlate and C_NamePlate.GetNamePlateForUnit and db.nameplateMode ~= "off" then
            local testing = testUntil and GetTime() < testUntil
            local okTarget, targetPlate = pcall(C_NamePlate.GetNamePlateForUnit, "target")
            if not okTarget then targetPlate = nil end
            for i = 1, MAX_PLATES do
                local unit = "nameplate" .. i
                if UnitExists(unit) then
                    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
                    local forbidden = ok and plate and plate.IsForbidden and plate:IsForbidden()
                    if ok and plate and not forbidden then updatePlate(unit, plate, targetPlate, testing) end
                end
            end
        end
    end
    for host in pairs(previousHosts) do
        if not shownHosts[host] and plateIcons[host] then
            plateIcons[host].window:Hide()
            plateIcons[host].active = false
        end
    end
end

function ns.HasPlateExecute(plate)
    if not (db and db.execShow and db.execPlates and ability and type(plate) == "table") then return false, 0 end
    if (db.execPlatePosition or "right") ~= "right" then return false, 0 end
    local host = BIT.Plate and BIT.Plate.WidgetHost and BIT.Plate.WidgetHost(plate) or plate
    local p = plateIcons[host]
    if p and shownHosts[host] and p.active then
        return true, p.size or db.execPlateSize or 22
    end
    return false, 0
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("SPELLS_CHANGED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player")
events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
events:SetScript("OnEvent", function(self, event, ...)
    if ns.off or ns.Retail then
        self:UnregisterAllEvents()
        self:SetScript("OnUpdate", nil)
        window:Hide()
        return
    end
    db = ns.db
    if not db then return end
    if event == "PLAYER_LOGIN" or event == "SPELLS_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
        updateAbility()
    elseif event == "UNIT_SPELLCAST_SENT" then
        local _, _, castGUID, spellID = ...
        onCastSent(castGUID, spellID)
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local _, castGUID, spellID = ...
        onCastSucceeded(castGUID, spellID)
    elseif event == "PLAYER_REGEN_ENABLED" then
        local counted = tally
        tally, atSend = {}, {}
        if next(counted) == nil then return end
        if C_Timer and type(C_Timer.After) == "function" then
            local retry = BIT.Meter and BIT.Meter.RETRY or 0.5
            local tries = BIT.Meter and BIT.Meter.TRIES or 20
            C_Timer.After(retry, function() learnAfterCombat(counted, tries) end)
        end
    end
end)

local sinceUpdate = 0
events:SetScript("OnUpdate", function(self, elapsed)
    if ns.off or ns.Retail then
        self:UnregisterAllEvents()
        self:SetScript("OnUpdate", nil)
        window:Hide()
        return
    end
    sinceUpdate = sinceUpdate + elapsed
    if sinceUpdate < UPDATE_INTERVAL then return end
    sinceUpdate = 0
    db = ns.db
    if not db then return end
    local ok, err = pcall(update)
    if ok then ok, err = pcall(updatePlates) end
    if not ok then
        window:Hide()
        if err ~= lastTraced then
            lastTraced = err
            trace("EXEC error: " .. tostring(err))
        end
    end
end)
if BIT.Perf then
    BIT.Perf.Watch(events, "OnEvent", "DoTInfo.exec")
    BIT.Perf.Watch(events, "OnUpdate", "DoTInfo.exec")
end

-- /dotinfo exec: what's watched and estimated, and the icon shown for 5 seconds to check its position.
function ns.executeCommand()
    db = ns.db
    updateAbility()
    if not ability then
        ns.print(BIT.L("No execute ability found (Execute, Hammer of Wrath, Shadow Word: Death, Shadowburn, Ferocious Bite or Eviscerate)."))
        return
    end
    local hit, how = estimate()
    ns.print(how or BIT.L("No estimate."))
    if db and not db.execShow then ns.print(BIT.L("The execute icon is switched off (Kill icon tab).")) end
    testUntil = GetTime() + 5
    trace("EXEC test: " .. tostring(how))
end

function ns.forgetExecuteLearning()
    if ns.db and ns.db.execRatios then wipe(ns.db.execRatios) end
end

ns.execute = { plateIcons = plateIcons, parseHit = parseHit, learn = learn, estimate = estimate, updateAbility = updateAbility,
    takeTally = function() local t = tally; tally = {}; return t end }
