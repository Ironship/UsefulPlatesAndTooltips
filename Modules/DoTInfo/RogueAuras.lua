-- Blizzard owns these aura icons, timers and stacks; Lua never reads their combat state.
local _, BIT = ...
local ns = BIT.Module("DoTInfo")
local R = ns.Retail
if not R then return end

local SIZE, GAP, MAX_PLATES = 18, 2, 40
local AURA_REFRESH_INTERVAL = 0.25
local spellIDs = {
    [703] = true, [1943] = true, -- Garrote, Rupture (including Crimson Tempest copies)
    [2818] = true, [383414] = true, -- Deadly Poison, Amplifying Poison stacks
    [385627] = true, [360194] = true, -- Kingsbane, Deathmark
    [381628] = true, [394021] = true, -- Internal Bleeding, Mutilated Flesh
}
local targetEntry, byPlate, activeUnits, failedHosts = nil, {}, {}, {}
local started, events = false, nil

local function secret(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

local function ask(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, value = pcall(fn, ...)
    if ok and not secret(value) then return value end
end

local function usable(object)
    if secret(object) or object == nil then return false end
    local ok, forbidden = pcall(function() return object.IsForbidden and object:IsForbidden() end)
    return ok and not secret(forbidden) and not forbidden
end

local function healthBar(parent, onPlate)
    if not usable(parent) then return end
    local ok, bar = pcall(function()
        if onPlate then
            return BIT.Plate.HealthBar(parent)
        end
        local main = parent.TargetFrameContent and parent.TargetFrameContent.TargetFrameContentMain
        return (main and main.HealthBarsContainer and main.HealthBarsContainer.HealthBar)
            or (main and main.HealthBar) or TargetFrameHealthBar or parent.healthbar
    end)
    if ok and usable(bar) then return bar end
end

local function initialize(button)
    button:SetSize(SIZE, SIZE)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(button)
    local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    cooldown:SetAllPoints(button)
    cooldown:SetDrawEdge(false)
    cooldown:SetHideCountdownNumbers(true)
    local duration = button:CreateFontString(nil, "OVERLAY")
    duration:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    duration:SetPoint("BOTTOM", button, "BOTTOM", 0, 0)
    local count = button:CreateFontString(nil, "OVERLAY")
    count:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    count:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
    -- Every binding immediately updates its display, so style regions before registering them.
    button:SetIcon(icon)
    button:SetDurationCooldown(cooldown)
    button:SetDurationText(duration)
    button:SetApplicationCount(count)
end

local function poisonAmount()
    local desc = ask(C_Spell and C_Spell.GetSpellDescription, 2823)
    local total = desc and R.Parse(2818, desc)
    if type(total) == "number" and total > 0 and total < math.huge then return total end
end

local function poisonAppearance(entry)
    local config, parts = {}, {}
    local onPlate = entry.parent ~= TargetFrame
    for _, key in ipairs({ "fillTexture", "fillColor", "fillOpacity", "dotColors", "outlineStyle",
        "dashLength", "outlineThickness", "outlineColor", "outlineOpacity", "segmentDividers",
        "pulseOutline", "showGlow", "glowSize", "showShine", "shineInterval", "scrollStripes", "labelSize", "labelColor" }) do
        local setting = onPlate and key ~= "segmentDividers" and key ~= "labelSize" and key ~= "labelColor"
            and ("plate" .. key:sub(1, 1):upper() .. key:sub(2)) or key
        config[key] = ns.db[setting]
        if config[key] == nil and ns.DEFAULTS then config[key] = ns.DEFAULTS[setting] end
        parts[#parts + 1] = tostring(config[key])
    end
    config.onPlate = onPlate
    config.name = ask(C_Spell and C_Spell.GetSpellName, 2818) or "Deadly Poison"
    return config, table.concat(parts, "|")
end

local function createPoisonDamage(entry, config, signature)
    local property = Enum and Enum.DurationTextBindingProperty
    local direction = Enum and Enum.StatusBarTimerDirection
    if type(entry.container.AddAuraSlot) ~= "function" or not property or not direction
        or type(property.RemainingPercent) ~= "number" or type(direction.RemainingTime) ~= "number"
        or not C_StringUtil or type(C_StringUtil.CreateNumericRuleFormatter) ~= "function" then
        if ns.TraceRogueAura then ns.TraceRogueAura("NATIVE POISON duration formatting unavailable") end
        return
    end
    local scale, base, container, formatter, initialized, initializerError
    local ok, err = pcall(function()
        -- This plain HP scale stays outside restricted aura buttons. Its fill supplies native geometry.
        for _, key in ipairs({ "poisonScale", "poisonBase" }) do
            if not entry[key] then
                local bar = CreateFrame("StatusBar", nil, entry.parent, "DisableUntrustedLayoutScriptsTemplate")
                bar:SetAllPoints(entry.bar)
                bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
                bar:SetStatusBarColor(0, 0, 0, 0)
                bar:SetMinMaxValues(0, 1)
                bar:SetValue(0)
                entry[key] = bar
            end
        end
        scale, base = entry.poisonScale, entry.poisonBase
        container = CreateFrame("AuraContainer", nil, entry.parent, "CustomAuraContainerTemplate")
        container:SetSize(1, 1)
        container:SetPoint("BOTTOMLEFT", entry.bar, "TOPLEFT", 0, 4)
        formatter = C_StringUtil.CreateNumericRuleFormatter()
        formatter:SetBreakpoints({ { threshold = 0, format = "" } })
        container:AddAuraSlot("deadlyDamage", "HARMFUL|PLAYER", {
            candidateFilters = { includeSpellIDs = { [2818] = true } },
            initializeFrame = function(button)
                -- The native factory swallows callback errors, so retain setup failure explicitly.
                initialized, initializerError = pcall(function()
                    button:SetPoint("TOPLEFT", base:GetStatusBarTexture(), "TOPRIGHT")
                    button:SetPoint("BOTTOMRIGHT", scale:GetStatusBarTexture(), "BOTTOMRIGHT")
                    local clip = CreateFrame("Frame", nil, button, "DisableUntrustedLayoutScriptsTemplate")
                    local padding = (config.glowSize or 0) + (config.outlineThickness or 1)
                    clip:SetPoint("TOPLEFT", entry.bar, "TOPLEFT", 0, padding)
                    clip:SetPoint("BOTTOMRIGHT", entry.bar, "BOTTOMRIGHT", 0, -padding)
                    clip:SetClipsChildren(true)
                    local timer = CreateFrame("StatusBar", nil, clip, "DisableUntrustedLayoutScriptsTemplate")
                    timer:SetAllPoints(button)
                    timer:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
                    timer:SetStatusBarColor(0.2, 1, 0.2, 0.9)
                    if ns.stylePoisonSegment then ns.stylePoisonSegment(timer, entry.bar, config) end
                    local label = button:CreateFontString(nil, "OVERLAY")
                    label:SetFont("Fonts\\FRIZQT__.TTF", config.labelSize or 11, "OUTLINE")
                    if ns.colorOf then label:SetTextColor(ns.colorOf(config.labelColor)) else label:SetTextColor(0.2, 1, 0.2) end
                    label:SetPoint("BOTTOMRIGHT", entry.bar, "TOPRIGHT", -2, 2)
                    button:SetDurationText(label, { textFormat = {
                        formatString = "{}", components = {
                            { property = property.RemainingPercent, formatter = formatter },
                        },
                    } })
                    button:SetDurationBar(timer, { direction = direction.RemainingTime })
                end)
                -- Native visibility, timers and formatted damage stay inside the restricted button.
            end,
        })
        assert(initialized, initializerError or "native initializer did not run")
    end)
    if not ok then
        if scale then pcall(scale.Hide, scale) end
        if container then pcall(container.SetEnabled, container, false); pcall(container.Hide, container) end
        if ns.TraceRogueAura then
            ns.TraceRogueAura("NATIVE POISON setup failed: " .. (type(err) == "string" and not secret(err) and err or "restricted"))
        end
        return
    end
    if ns.TraceRogueAura then ns.TraceRogueAura("NATIVE POISON damage display ready") end
    return { container = container, scale = scale, base = base, formatter = formatter, signature = signature }
end

local function updatePoisonOffset(entry, unit, enabled)
    local damage = entry and entry.poisonDamage
    if not damage then return end
    local offset = enabled and ns.nativePoisonBase and ns.nativePoisonBase(unit, entry.parent, entry.bar) or 0
    if offset ~= damage.offset or damage.total ~= damage.offsetTotal then
        damage.base:SetValue(offset)
        damage.scale:SetValue(damage.width and (damage.total or 0) or offset + (damage.total or 0))
        damage.offset, damage.offsetTotal = offset, damage.total
    end
end

local function updatePoisonDamage(entry, unit, enabled)
    local config, signature = poisonAppearance(entry)
    if enabled and signature ~= entry.poisonSignature and not (ask(InCombatLockdown) == true
        and ask(entry.parent.IsProtected, entry.parent) == true) then
        -- Restricted descendants cannot be restyled; replace only the poison slot, not the aura icons.
        local old = entry.poisonDamage
        local replacement = createPoisonDamage(entry, config, signature)
        if replacement then
            if old then pcall(old.container.SetEnabled, old.container, false); pcall(old.container.Hide, old.container) end
            entry.poisonDamage = replacement
        end
        entry.poisonSignature = signature
    end
    local damage = entry.poisonDamage
    if not damage then return end
    local total = enabled and poisonAmount() or nil
    if enabled and ns.dotBreakdownForUnit then
        local entries = ns.dotBreakdownForUnit(unit)
        for _, effect in ipairs(entries) do
            if effect.familyID == 2818 then total = nil; break end -- Already drawn by the plain DoT segments.
        end
    end
    local label = ns.db and ns.db.showLabel == true
    if total ~= damage.total or label ~= damage.label then
        damage.formatter:SetBreakpoints({ total and label and {
            -- Duration text supplies 0..100 percent, unlike the timer bar's 0..1 fraction.
            threshold = 0, format = "~%.0f", components = { { div = 100 / total, step = 1 } },
        } or { threshold = 0, format = "" } })
        damage.total, damage.label = total, label
    end
    if enabled then
        local maximum = UnitHealthMax(unit)
        damage.scale:SetMinMaxValues(0, maximum)
        damage.base:SetMinMaxValues(0, maximum)
        local width = ask(entry.bar.GetWidth, entry.bar)
        local barScale = ask(entry.bar.GetEffectiveScale, entry.bar)
        local ownScale = ask(damage.scale.GetEffectiveScale, damage.scale)
        if type(width) == "number" and width > 0 and width < math.huge
            and type(barScale) == "number" and barScale > 0 and barScale < math.huge
            and type(ownScale) == "number" and ownScale > 0 and ownScale < math.huge then width = width * barScale / ownScale
        else width = nil end
        if width and (width ~= width or width >= math.huge) then width = nil end
        if width ~= damage.width then
            damage.scale:ClearAllPoints()
            if width then
                -- Translate a full HP-sized scale; clip the resulting countdown only at the HP bar's edge.
                damage.scale:SetPoint("TOPLEFT", damage.base:GetStatusBarTexture(), "TOPRIGHT")
                damage.scale:SetPoint("BOTTOMLEFT", damage.base:GetStatusBarTexture(), "BOTTOMRIGHT")
                damage.scale:SetWidth(width)
            else damage.scale:SetAllPoints(entry.bar) end
            damage.width, damage.offset = width, nil
        end
    end
    updatePoisonOffset(entry, unit, enabled)
    -- shortcut: hidden full-bar geometry or poison above max HP clips early; replace when native uncapped sizing is available.
end

local function create(parent, bar)
    if failedHosts[parent] == bar then return end
    if ask(InCombatLockdown) == true and ask(parent.IsProtected, parent) == true then return end
    local container
    local ok = pcall(function()
        container = CreateFrame("AuraContainer", nil, parent, "CustomAuraContainerTemplate")
        assert(type(container.AddAuraGroup) == "function" and type(container.SetUnit) == "function"
            and type(container.SetEnabled) == "function" and type(container.UpdateAllAuras) == "function")
        container:SetSize(1, 1)
        container:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 0, 4)
        local strata = ask(bar.GetFrameStrata, bar)
        if type(strata) == "string" then container:SetFrameStrata(strata) end
        local level = ask(bar.GetFrameLevel, bar)
        container:SetFrameLevel(type(level) == "number" and level + 5 or 200)
        container:AddAuraGroup("rogue", "HARMFUL|PLAYER", {
            candidateFilters = { includeSpellIDs = spellIDs },
            initializeFrame = initialize,
            maxFrameCount = 8,
            layout = { elementWidth = SIZE, elementHeight = SIZE, elementSpacing = GAP },
        })
    end)
    if not ok then
        -- A failed initializer must not allocate another batch on every shared refresh.
        failedHosts[parent] = bar
        if usable(container) then
            pcall(container.SetEnabled, container, false)
            pcall(container.Hide, container)
        end
        return
    end
    local entry = { container = container, parent = parent, bar = bar }
    return entry
end

local function displayContainer(entry, state, unit, enabled, refresh)
    local container = state.container
    if not usable(container) then return end
    -- Nameplate addons re-level health bars while active; keep native projections above them.
    local level, strata = ask(entry.bar.GetFrameLevel, entry.bar), ask(entry.bar.GetFrameStrata, entry.bar)
    level = type(level) == "number" and level + 5 or 200
    if level ~= state.level and pcall(container.SetFrameLevel, container, level) then state.level = level end
    if type(strata) == "string" and strata ~= state.strata
        and pcall(container.SetFrameStrata, container, strata) then state.strata = strata end
    if enabled and state.unit ~= unit then
        if not pcall(container.SetUnit, container, unit) then return end
        state.unit = unit
    end
    if state.enabled ~= enabled then
        if not pcall(container.SetEnabled, container, enabled) then return end
        state.enabled = enabled
    end
    local now = GetTime()
    -- Recheck native aura state for late procs and missed incremental updates; keep its real expiry.
    if enabled and (refresh == true or refresh == unit or (refresh == false
        and (not state.refreshedAt or now - state.refreshedAt >= AURA_REFRESH_INTERVAL))) then
        pcall(container.UpdateAllAuras, container)
        state.refreshedAt = now
    end
    -- A protected parent can defer visibility changes until combat ends; disabling still clears auras.
    if state.shown ~= enabled then
        if ask(InCombatLockdown) == true and (ask(container.IsProtected, container) == true
            or ask(entry.parent.IsProtected, entry.parent) == true) then return end
        local method = enabled and container.Show or container.Hide
        if pcall(method, container) then state.shown = enabled end
    end
end

local function display(entry, unit, enabled, refresh)
    if not entry then return end
    local ok, err = pcall(updatePoisonDamage, entry, unit, enabled)
    if not ok and not entry.poisonError then
        entry.poisonError = true
        if ns.TraceRogueAura then
            ns.TraceRogueAura("NATIVE POISON update failed: " .. (type(err) == "string" and not secret(err) and err or "restricted"))
        end
    end
    displayContainer(entry, entry, unit, enabled, refresh)
    if entry.poisonDamage then displayContainer(entry, entry.poisonDamage, unit, enabled, refresh) end
end

local function hostile(unit)
    return ask(UnitExists, unit) == true and ask(UnitCanAttack, "player", unit) == true
end

local function update(refresh)
    if not started or not ns.db then return end
    local markers = ns.db.showMarkers ~= false
    local targetBar = healthBar(TargetFrame, false)
    if targetEntry and (targetEntry.parent ~= TargetFrame or targetEntry.bar ~= targetBar) then
        display(targetEntry, nil, false)
        targetEntry = nil
    end
    if markers and targetBar and hostile("target") then
        targetEntry = targetEntry or create(TargetFrame, targetBar)
        display(targetEntry, "target", true, refresh)
    else
        display(targetEntry, nil, false)
    end
    local current = {}
    for unit in pairs(activeUnits) do
        local plate = ask(C_NamePlate and C_NamePlate.GetNamePlateForUnit, unit)
        local bar = healthBar(plate, true)
        if bar then
            local entry = byPlate[plate]
            if entry and entry.bar ~= bar then display(entry, nil, false); entry = nil end
            local enabled = markers and ns.db.nameplateMode ~= "off" and hostile(unit)
            if enabled and not entry then entry = create(plate, bar); byPlate[plate] = entry end
            if entry then
                current[entry] = true
                display(entry, unit, enabled, refresh)
            end
        end
    end
    for _, entry in pairs(byPlate) do
        if not current[entry] then display(entry, nil, false) end
    end
end

function R.UpdateRogueAuras()
    update(false)
end

-- Follow plain marker animation/ticks immediately, without resampling any native aura state.
function R.UpdatePoisonOffset(parent)
    local entry = parent == TargetFrame and targetEntry or byPlate[parent]
    if entry then updatePoisonOffset(entry, entry.unit, entry.enabled) end
end

local function seedPlates()
    wipe(activeUnits)
    for i = 1, MAX_PLATES do
        local token = "nameplate" .. i
        if ask(UnitExists, token) == true then activeUnits[token] = true end
    end
end

function R.StartRogueAuras()
    if started or ns.off or not ns.db then return end
    local ok, _, class = pcall(UnitClass, "player")
    if not ok or secret(class) or class ~= "ROGUE" then return end
    if not C_XMLUtil or type(C_XMLUtil.GetTemplateInfo) ~= "function" then return end
    if not events then
        events = CreateFrame("Frame")
        for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "NAME_PLATE_UNIT_ADDED",
            "NAME_PLATE_UNIT_REMOVED", "UNIT_FACTION", "UNIT_AURA", "PLAYER_REGEN_ENABLED", "ADDON_LOADED" }) do
            events:RegisterEvent(event)
        end
        events:SetScript("OnEvent", function(_, event, unit)
            if event == "ADDON_LOADED" and (secret(unit) or unit ~= "Blizzard_AuraContainer") then return end
            if not started then
                if event ~= "PLAYER_ENTERING_WORLD" and event ~= "PLAYER_REGEN_ENABLED"
                    and event ~= "ADDON_LOADED" then return end
                R.StartRogueAuras()
                if not started then return end
            end
            if event == "UNIT_AURA" then
                if secret(unit) or type(unit) ~= "string"
                    or (unit ~= "target" and not activeUnits[unit]) then return end
                update(unit) -- Request a native refresh for this token without inspecting aura data.
                return
            end
            if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_REGEN_ENABLED" then wipe(failedHosts) end
            if event == "PLAYER_ENTERING_WORLD" then
                display(targetEntry, nil, false)
                for _, entry in pairs(byPlate) do display(entry, nil, false) end
                seedPlates()
            elseif event == "NAME_PLATE_UNIT_ADDED" or event == "NAME_PLATE_UNIT_REMOVED" then
                if secret(unit) or type(unit) ~= "string" or not unit:match("^nameplate%d+$") then return end
                activeUnits[unit] = event == "NAME_PLATE_UNIT_ADDED" and true or nil
            end
            update(true)
        end)
    end
    if C_AddOns and ask(C_AddOns.IsAddOnLoaded, "Blizzard_AuraContainer") ~= true then
        if type(C_AddOns.LoadAddOn) == "function" then pcall(C_AddOns.LoadAddOn, "Blizzard_AuraContainer") end
    end
    if ask(C_XMLUtil.GetTemplateInfo, "CustomAuraContainerTemplate") == nil then return end
    started = true
    seedPlates()
    update(false)
end
