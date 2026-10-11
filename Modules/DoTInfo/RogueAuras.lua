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

local function createPoisonDamage(entry)
    local property = Enum and Enum.DurationTextBindingProperty
    local direction = Enum and Enum.StatusBarTimerDirection
    if type(entry.container.AddAuraSlot) ~= "function" or not property or not direction
        or type(property.RemainingPercent) ~= "number" or type(direction.RemainingTime) ~= "number"
        or not C_StringUtil or type(C_StringUtil.CreateNumericRuleFormatter) ~= "function" then
        if ns.TraceRogueAura then ns.TraceRogueAura("NATIVE POISON duration formatting unavailable") end
        return
    end
    local scale, formatter, initialized, initializerError
    local ok, err = pcall(function()
        -- This plain HP scale stays outside restricted aura buttons. Its fill supplies native geometry.
        scale = CreateFrame("StatusBar", nil, entry.parent, "DisableUntrustedLayoutScriptsTemplate")
        scale:SetAllPoints(entry.bar)
        scale:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
        scale:SetStatusBarColor(0, 0, 0, 0)
        scale:SetMinMaxValues(0, 1)
        scale:SetValue(0)
        formatter = C_StringUtil.CreateNumericRuleFormatter()
        formatter:SetBreakpoints({ { threshold = 0, format = "" } })
        entry.container:AddAuraSlot("deadlyDamage", "HARMFUL|PLAYER", {
            candidateFilters = { includeSpellIDs = { [2818] = true } },
            initializeFrame = function(button)
                -- The native factory swallows callback errors, so retain setup failure explicitly.
                initialized, initializerError = pcall(function()
                    button:SetAllPoints(scale:GetStatusBarTexture())
                    local timer = CreateFrame("StatusBar", nil, button, "DisableUntrustedLayoutScriptsTemplate")
                    timer:SetAllPoints(button)
                    timer:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
                    timer:SetStatusBarColor(0.2, 1, 0.2, 0.9)
                    local label = button:CreateFontString(nil, "OVERLAY")
                    label:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
                    label:SetTextColor(0.2, 1, 0.2)
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
        if ns.TraceRogueAura then
            ns.TraceRogueAura("NATIVE POISON setup failed: " .. (type(err) == "string" and not secret(err) and err or "restricted"))
        end
        return
    end
    if ns.TraceRogueAura then ns.TraceRogueAura("NATIVE POISON damage display ready") end
    return { scale = scale, formatter = formatter }
end

local function updatePoisonDamage(entry, unit, enabled)
    local damage = entry.poisonDamage
    if not damage then return end
    local total = enabled and poisonAmount() or nil
    local label = ns.db and ns.db.showLabel == true
    if total ~= damage.total or label ~= damage.label then
        damage.formatter:SetBreakpoints({ total and label and {
            -- Duration text supplies 0..100 percent, unlike the timer bar's 0..1 fraction.
            threshold = 0, format = "~%.0f", components = { { div = 100 / total, step = 1 } },
        } or { threshold = 0, format = "" } })
        damage.total, damage.label = total, label
    end
    if enabled then damage.scale:SetMinMaxValues(0, UnitHealthMax(unit)) end
    damage.scale:SetValue(total or 0)
    -- shortcut: full damage above max HP clips the width; use the native number until a wider scale is available.
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
    entry.poisonDamage = createPoisonDamage(entry)
    return entry
end

local function display(entry, unit, enabled, refresh)
    if not entry then return end
    local container = entry.container
    if not usable(container) then return end
    -- Nameplate addons re-level health bars while active; keep native projections above them.
    local level, strata = ask(entry.bar.GetFrameLevel, entry.bar), ask(entry.bar.GetFrameStrata, entry.bar)
    level = type(level) == "number" and level + 5 or 200
    if level ~= entry.level and pcall(container.SetFrameLevel, container, level) then entry.level = level end
    if type(strata) == "string" and strata ~= entry.strata
        and pcall(container.SetFrameStrata, container, strata) then entry.strata = strata end
    local ok, err = pcall(updatePoisonDamage, entry, unit, enabled)
    if not ok and not entry.poisonError then
        entry.poisonError = true
        if ns.TraceRogueAura then
            ns.TraceRogueAura("NATIVE POISON update failed: " .. (type(err) == "string" and not secret(err) and err or "restricted"))
        end
    end
    if enabled and entry.unit ~= unit then
        if not pcall(container.SetUnit, container, unit) then return end
        entry.unit = unit
    end
    if entry.enabled ~= enabled then
        if not pcall(container.SetEnabled, container, enabled) then return end
        entry.enabled = enabled
    end
    local now = GetTime()
    -- Recheck native aura state for late procs and missed incremental updates; keep its real expiry.
    if enabled and (refresh == true or refresh == unit or (refresh == false
        and (not entry.refreshedAt or now - entry.refreshedAt >= AURA_REFRESH_INTERVAL))) then
        pcall(container.UpdateAllAuras, container)
        entry.refreshedAt = now
    end
    -- A protected parent can defer visibility changes until combat ends; disabling still clears auras.
    if entry.shown ~= enabled then
        if ask(InCombatLockdown) == true and (ask(container.IsProtected, container) == true
            or ask(entry.parent.IsProtected, entry.parent) == true) then return end
        local method = enabled and container.Show or container.Hide
        if pcall(method, container) then entry.shown = enabled end
    end
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
