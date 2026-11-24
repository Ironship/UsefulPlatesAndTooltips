-- UsefulPlatesAndTooltips module DoTInfo: options window. Based on the standalone DoT addon's options
-- at e4faef4 by Joe Greive (MIT); it lives only here now and is edited directly.
-- DoTInfo options window (/dotinfo).
--
-- Left: a live preview. The addon's real marker and kill icon are attached to a mock target frame here (see
-- ns.setDisplayHost in Core.lua) and fed plain numbers from the preview sliders, so the preview runs the
-- same drawing code as combat. Right: tabbed settings. Top: presets.
--
-- Controls are built from basic widgets (CheckButton, Slider, Button) rather than Blizzard templates, so they
-- don't depend on templates behaving the same in Forever. Settings are written straight to ns.db.

local ADDON_NAME, BIT = ...
-- UsefulPlatesAndTooltips's own namespace for the module, shared by its four files.
local ns = BIT.Module("DoTInfo")

local WHITE = "Interface\\Buttons\\WHITE8X8"
local TAB_ROWS = ns.Retail and 2 or 3 -- three tabs per row; Forever has the Native auras tab as a seventh
local WINDOW_WIDTH, WINDOW_HEIGHT = 840, 560
local HEADER_HEIGHT = 52 -- title bar: title, presets, close button
local TAB_HEIGHT = 26
local PREVIEW_WIDTH = 290
local ROW_HEIGHT = 26
local SETTINGS_LAYOUT = BIT.Looks.LAYOUT -- one geometry for every module's rows (Core/LookRows.lua)
local PREVIEW_LAYOUT = BIT.Looks.PREVIEW_LAYOUT
local DISABLED_ALPHA = 0.35
local SIMULATION_STEP = 0.5 -- seconds

-- Presets style both the target marker and nameplates; accuracy settings are left alone.
local PRESETS = {
    { id = "minimal", label = "Minimal", values = {
        showSkull = true, skullIcon = "cross", skullSize = 40, skullPulse = false,
        showMarkers = true, fillTexture = "flat", fillColor = "purple", fillOpacity = 35, dotColors = "single",
        outlineStyle = "solid", outlineThickness = 1, outlineColor = "purple", outlineOpacity = 100,
        smoothMotion = true, flashOnApply = false, pulseOutline = false,
        showSpark = false, showGlow = false, showShine = false, scrollStripes = false, showLabel = false,
    } },
    { id = "classic", label = "Classic", values = {
        showSkull = true, skullIcon = "skull", skullSize = 48, skullPulse = true,
        showMarkers = true, fillTexture = "smooth", fillColor = "red", fillOpacity = 60, dotColors = "single",
        outlineStyle = "dashed", dashLength = 4, outlineThickness = 2, outlineColor = "gold", outlineOpacity = 100,
        smoothMotion = true, flashOnApply = true, pulseOutline = false,
        showSpark = true, showGlow = false, showShine = false, scrollStripes = false, showLabel = false,
    } },
    { id = "juicy", label = "Juicy", values = {
        showSkull = true, skullIcon = "shades", skullSize = 64, skullPulse = true,
        showMarkers = true, fillTexture = "stripes", fillColor = "red", fillOpacity = 100, dotColors = "each",
        segmentDividers = true, outlineStyle = "dashed", dashLength = 4, outlineThickness = 1, outlineColor = "red",
        outlineOpacity = 85, smoothMotion = true, flashOnApply = true, pulseOutline = true,
        showSpark = true, showGlow = true, glowSize = 7, showShine = true, shineInterval = 3, scrollStripes = true,
        showLabel = false,
    } },
    { id = "glass", label = "Glass", values = {
        showSkull = true, skullIcon = "boss", skullSize = 44, skullPulse = false,
        showMarkers = true, fillTexture = "gloss", fillColor = "sky", fillOpacity = 85, dotColors = "single",
        outlineStyle = "solid", outlineThickness = 1, outlineColor = "ice", outlineOpacity = 90,
        smoothMotion = true, flashOnApply = false, pulseOutline = false,
        showSpark = false, showGlow = true, glowSize = 4, showShine = true, shineInterval = 4, scrollStripes = false,
        showLabel = false,
    } },
    { id = "neon", label = "Neon", values = {
        showSkull = true, skullIcon = "skull", skullSize = 56, skullPulse = true,
        showMarkers = true, fillTexture = "scanlines", fillColor = "magenta", fillOpacity = 90, dotColors = "single",
        outlineStyle = "dashed", dashLength = 4, outlineThickness = 2, outlineColor = "cyan", outlineOpacity = 100,
        smoothMotion = true, flashOnApply = true, pulseOutline = true,
        showSpark = true, showGlow = true, glowSize = 10, showShine = false, scrollStripes = false, showLabel = false,
    } },
    { id = "blood", label = "Blood", values = {
        showSkull = true, skullIcon = "skull", skullSize = 56, skullPulse = true,
        showMarkers = true, fillTexture = "cylinder", fillColor = "crimson", fillOpacity = 95, dotColors = "single",
        outlineStyle = "solid", outlineThickness = 1, outlineColor = "maroon", outlineOpacity = 100,
        smoothMotion = true, flashOnApply = true, pulseOutline = false,
        showSpark = true, showGlow = false, showShine = false, scrollStripes = false, showLabel = false,
    } },
    { id = "frost", label = "Frost", values = {
        showSkull = true, skullIcon = "cross", skullSize = 44, skullPulse = false,
        showMarkers = true, fillTexture = "noise", fillColor = "ice", fillOpacity = 75, dotColors = "single",
        outlineStyle = "solid", outlineThickness = 1, outlineColor = "sky", outlineOpacity = 100,
        smoothMotion = true, flashOnApply = false, pulseOutline = false,
        showSpark = false, showGlow = true, glowSize = 5, showShine = true, shineInterval = 5, scrollStripes = false,
        showLabel = false,
    } },
    { id = "toxic", label = "Toxic", values = {
        showSkull = true, skullIcon = "check", skullSize = 48, skullPulse = true,
        showMarkers = true, fillTexture = "waves", fillColor = "lime", fillOpacity = 80, dotColors = "single",
        outlineStyle = "dashed", dashLength = 4, outlineThickness = 1, outlineColor = "forest", outlineOpacity = 100,
        smoothMotion = true, flashOnApply = true, pulseOutline = true,
        showSpark = false, showGlow = true, glowSize = 6, showShine = false, scrollStripes = false, showLabel = false,
    } },
    { id = "carbon", label = "Carbon", values = {
        showSkull = true, skullIcon = "boss", skullSize = 48, skullPulse = false,
        showMarkers = true, fillTexture = "carbon", fillColor = "charcoal", fillOpacity = 95, dotColors = "single",
        outlineStyle = "solid", outlineThickness = 1, outlineColor = "gold", outlineOpacity = 100,
        smoothMotion = true, flashOnApply = false, pulseOutline = false,
        showSpark = false, showGlow = false, showShine = true, shineInterval = 6, scrollStripes = false, showLabel = false,
    } },
    { id = "ember", label = "Ember", values = {
        showSkull = true, skullIcon = "skull", skullSize = 52, skullPulse = true,
        showMarkers = true, fillTexture = "bevel", fillColor = "amber", fillOpacity = 90, dotColors = "single",
        outlineStyle = "solid", outlineThickness = 2, outlineColor = "orange", outlineOpacity = 100,
        smoothMotion = true, flashOnApply = true, pulseOutline = true,
        showSpark = true, showGlow = true, glowSize = 7, showShine = false, scrollStripes = false, showLabel = false,
    } },
    { id = "debug", label = "Debug", values = {
        showSkull = true, skullIcon = "cross", skullPulse = false,
        showMarkers = true, fillTexture = "flat", fillOpacity = 60, dotColors = "each", segmentDividers = true,
        outlineStyle = "solid", outlineThickness = 1, outlineColor = "white", outlineOpacity = 100,
        smoothMotion = false, flashOnApply = true, pulseOutline = false,
        showSpark = false, showGlow = false, showShine = false, scrollStripes = false,
        showLabel = true, labelPosition = "left", labelSize = 10, labelColor = "white",
    } },
}

local window
local controls = {} -- every settings/preview row, refreshed after each change
local tabs, activeTab = {}, nil
local menu -- shared dropdown list
local simulation

-- Preview numbers, in % of the mock target's max health.
local preview = {
    health = 60,
    dots = {
        { name = "Corruption", school = 32, damage = 27, tick = 4, refreshDue = true },
        { name = "Immolate", school = 4, damage = 18, tick = 5 },
    },
}

local function db() return ns.db end

local function findEntry(list, id)
    for _, entry in ipairs(list) do
        if entry.id == id then return entry end
    end
end

local function setBackdrop(frame, shade, alpha)
    BIT.UI.Backdrop(frame, shade, alpha)
end

---------------------------------------------------------------------------
-- Preview
---------------------------------------------------------------------------

local function previewTotal()
    local total = 0
    for _, dot in ipairs(preview.dots) do total = total + dot.damage end
    return total
end

-- Splits a total over the two sample DoTs (60/40).
local function setPreviewDamage(total)
    preview.dots[1].damage = total * 0.6
    preview.dots[2].damage = total * 0.4
end

local function refreshControls()
    for _, control in ipairs(controls) do control:Refresh() end
end

local function inCombat()
    return (InCombatLockdown and InCombatLockdown()) or (UnitAffectingCombat and UnitAffectingCombat("player"))
end

-- The preview only takes over the display out of combat: in combat the real target comes first, even with the
-- window open (settings changes still apply to it live).
local function syncDisplayHost()
    -- Visible, not just shown: when the window is built into another addon's settings (UsefulPlatesAndTooltips), its
    -- own frame stays "shown" while the settings around it are closed, and the end of a fight then put the
    -- marker back on the preview's mock target frame, drawn where the closed window had been.
    if not window or not window:IsVisible() then return end
    local paused = inCombat() and true or false
    window.combatNote:SetShown(paused)
    window.mock:SetAlpha(paused and 0.3 or 1)
    window.mockPlate:SetAlpha(paused and 0.3 or 1)
    window.simulateButton:SetEnabled(not paused)
    window.flashButton:SetEnabled(not paused)
    if paused ~= window.previewPaused then
        window.previewPaused = paused
        if paused and simulation then
            simulation:Cancel()
            simulation = nil
            window.simulateButton:SetText(BIT.L("Simulate"))
        end
        ns.setDisplayHost((not paused) and window.host or nil)
        ns.setPlatePreview((not paused) and window.plateHost or nil, preview)
    end
end

-- The verdict badge under the preview scene: one look per outcome.
local VERDICT_STYLES = {
    none = { icon = "Interface\\Common\\Indicator-Gray",
        bg = { 0.11, 0.11, 0.12 }, edge = { 0.32, 0.32, 0.34 }, text = { 0.72, 0.72, 0.72 } },
    survives = { icon = "Interface\\Common\\Indicator-Yellow",
        bg = { 0.19, 0.14, 0.04 }, edge = { 0.85, 0.62, 0.12 }, text = { 1, 0.82, 0.35 } },
    lethal = { icon = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull", -- when the chosen kill icon has no path
        bg = { 0.05, 0.19, 0.07 }, edge = { 0.30, 0.85, 0.35 }, text = { 0.55, 1, 0.55 } },
    dead = { icon = "Interface\\RaidFrame\\ReadyCheck-Ready",
        bg = { 0.10, 0.13, 0.10 }, edge = { 0.35, 0.50, 0.35 }, text = { 0.70, 0.85, 0.70 } },
}
local PREVIEW_MAX_HEALTH = 142 -- the mock murloc's health, for the number on its bar

-- The kill icon picked in the settings, so the badge shows the same icon the portrait gets.
local function chosenKillIcon()
    local entry = ns.findById and ns.lists and ns.findById(ns.lists.icons, db().skullIcon)
    return entry and entry.path or VERDICT_STYLES.lethal.icon
end

local function setVerdict(kind, text, detail)
    local style = VERDICT_STYLES[kind]
    local badge = window.statusBadge
    badge:SetBackdropColor(style.bg[1], style.bg[2], style.bg[3], 0.95)
    badge:SetBackdropBorderColor(style.edge[1], style.edge[2], style.edge[3], 0.9)
    badge.accent:SetColorTexture(style.edge[1], style.edge[2], style.edge[3], 1)
    badge.icon:SetTexture((kind == "lethal" and chosenKillIcon())
        or (kind == "dead" and BIT.Art and BIT.Art.Texture and BIT.Art.Texture("rangeIn"))
        or style.icon)
    window.status:SetText(text)
    window.status:SetTextColor(style.text[1], style.text[2], style.text[3])
    window.statusDetail:SetText(detail or "")
end

local function updatePreview()
    if not window then return end
    window.healthBar:SetValue(preview.health)
    window.plateHealthBar:SetValue(preview.health)
    local total, health = previewTotal(), preview.health
    local function pct(value) return math.floor(value + 0.5) .. "%" end
    -- The numbers the game's own target frame shows on its bar: percent left, health right.
    window.healthPercent:SetText(pct(health))
    window.healthValue:SetText(tostring(math.floor(PREVIEW_MAX_HEALTH * health / 100 + 0.5)))
    if health <= 0 then
        setVerdict("dead", BIT.L("Target died"), "")
    elseif total <= 0 then
        setVerdict("none", BIT.L("No DoTs on the target"), "")
    elseif total * (tonumber(ns.db and ns.db.killMargin) or 100) / 100 >= health then
        setVerdict("lethal", BIT.L("DoTs kill it"), string.format(BIT.L("%s vs %s"), pct(total), pct(health)))
    else
        setVerdict("survives", string.format(BIT.L("Survives by %s"), pct(health - total)),
            string.format(BIT.L("%s vs %s"), pct(total), pct(health)))
    end
    ns.refresh()
end

local function stopSimulation()
    if simulation then
        simulation:Cancel()
        simulation = nil
    end
    if window then window.simulateButton:SetText(BIT.L("Simulate")) end
end

-- A scripted fight: a DoT lands, ticks, a second DoT lands and makes it lethal, ticks until the target dies.
local function startSimulation()
    stopSimulation()
    preview.health = 80
    setPreviewDamage(0)
    local step = 0
    simulation = C_Timer.NewTicker(SIMULATION_STEP, function()
        step = step + 1
        if step == 1 then
            preview.dots[1].damage = 32
            ns.playFlash()
        elseif step == 5 then
            preview.dots[2].damage = 50
            ns.playFlash()
        else
            local dealt = 0
            for _, dot in ipairs(preview.dots) do
                local tick = math.min(dot.damage, dot.tick)
                dot.damage = dot.damage - tick
                dealt = dealt + tick
            end
            preview.health = math.max(0, preview.health - dealt)
        end
        updatePreview()
        refreshControls()
        if preview.health <= 0 or (step > 5 and previewTotal() <= 0) then stopSimulation() end
    end)
    window.simulateButton:SetText(BIT.L("Stop"))
    updatePreview()
    refreshControls()
end

---------------------------------------------------------------------------
-- Controls
---------------------------------------------------------------------------

local function changed()
    updatePreview()
    refreshControls()
end

local rowOpts -- below
local function makeRow(parent, labelText, opts)
    return BIT.Looks.Rows.Row(parent, labelText, rowOpts(opts))
end

rowOpts = function(opts)
    opts = opts or {}
    return { tooltip = opts.tooltip, enabledIf = opts.enabledIf, layout = opts.layout, suffix = opts.suffix,
        display = opts.display, settings = db, register = function(row) table.insert(controls, row) end }
end

-- The check box, slider and drop-down are the shared rows (Core/LookRows.lua): every module's options look the same.
local function checkbox(parent, key, labelText, opts)
    return BIT.Looks.Rows.Check(parent, labelText, function() return db()[key] end, function(value)
        db()[key] = value
        changed()
    end, rowOpts(opts))
end

-- get/set work on any value (settings or preview numbers).
local function sliderRow(parent, labelText, min, max, step, get, set, opts)
    return BIT.Looks.Rows.Slider(parent, labelText, min, max, step, get, set, rowOpts(opts))
end

local function slider(parent, key, labelText, min, max, step, opts)
    return sliderRow(parent, labelText, min, max, step,
        function() return db()[key] end,
        function(value)
            db()[key] = value
            changed()
        end, opts)
end

local function closeMenu()
    if BIT.Looks then BIT.Looks.ClosePickList() end
end

-- The shared drop-down (Core/Looks.lua): scrolls, shows a swatch or a texture preview, groups entries.
local function openMenu(owner, list, current, pick)
    BIT.Looks.PickList(owner, list, current, pick)
end

local function choice(parent, key, labelText, list, opts)
    local menuList = list
    if list == ns.lists.colors then menuList = BIT.Looks.ColorList() end
    return BIT.Looks.Rows.Choice(parent, labelText, menuList, function() return db()[key] end, function(id)
        db()[key] = id
        changed()
    end, rowOpts(opts))
end

local function pushButton(parent, text, width, onClick)
    return BIT.UI.FitButton(parent, BIT.L(text), width, onClick)
end

local function actionRow(parent, labelText, buttonText, onClick, opts)
    return BIT.Looks.Rows.Button(parent, labelText, buttonText, onClick, rowOpts(opts))
end

---------------------------------------------------------------------------
-- Tabs
---------------------------------------------------------------------------

local function selectTab(tab)
    closeMenu()
    activeTab = tab
    for _, other in ipairs(tabs) do
        local selected = other == tab
        other.column:SetShown(selected)
        BIT.UI.TabSelected(other.button, selected)
        if other.footer then other.footer:SetShown(selected) end
    end
end

-- A tab whose methods add rows top to bottom and remember the setting keys, for "Reset this tab".
local function addTab(name)
    local area = window.settingsArea
    local tab = { keys = {}, y = 0 }
    tab.column = BIT.UI.ScrollColumn(area)
    tab.column:SetPoint("TOPLEFT", area, "TOPLEFT", 6, -40 - (TAB_ROWS - 1) * TAB_HEIGHT)
    tab.column:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT", -6, 40)
    tab.column:Hide()
    tab.content = tab.column.content

    local button = CreateFrame("Button", nil, area, "PanelTopTabButtonTemplate")
    button:SetText(BIT.L(name))
    button.text = button:GetFontString()
    button:SetSize(BIT.UI.TabWidth(button.text), TAB_HEIGHT)
    button.text:SetPoint("CENTER")
    BIT.UI.SkinTabButton(button, button.text)
    local previous = tabs[#tabs]
    -- Native tabs grow to fit their end caps on show; keep three per row.
    if previous and #tabs % 3 ~= 0 then
        button:SetPoint("LEFT", previous.button, "RIGHT", BIT.UI.TAB_GAP, 0)
    else
        button:SetPoint("TOPLEFT", area, "TOPLEFT", 8, -8 - math.floor(#tabs / 3) * TAB_HEIGHT)
    end
    button:SetScript("OnClick", function() selectTab(tab) end)
    tab.button = button

    local function place(row, key)
        row:SetPoint("TOPLEFT", tab.content, "TOPLEFT", 0, -tab.y)
        tab.y = tab.y + (row.standard and row:GetHeight() or ROW_HEIGHT)
        if key then table.insert(tab.keys, key) end
        return row
    end
    function tab:checkbox(key, ...) return place(checkbox(self.content, key, ...), key) end
    function tab:slider(key, ...) return place(slider(self.content, key, ...), key) end
    function tab:choice(key, ...) return place(choice(self.content, key, ...), key) end
    function tab:action(...) return place(actionRow(self.content, ...)) end
    function tab:gap() self.y = self.y + 8 end
    function tab:header(text)
        if self.y > 0 then self.y = self.y + 8 end
        local row = BIT.UI.Header(self.content, text)
        row:SetPoint("TOPLEFT", self.content, "TOPLEFT", 6, -self.y)
        row:SetPoint("RIGHT", self.content, "RIGHT", -6, 0)
        self.y = self.y + 24
        return row
    end
    function tab:note(text)
        local row = BIT.UI.Note(self.content, text, 464)
        row:SetPoint("TOPLEFT", self.content, "TOPLEFT", 6, -tab.y)
        tab.y = tab.y + row:GetHeight() + 8
        return row
    end
    function tab:finish()
        self.column:Fit(self.y + 12)
    end

    table.insert(tabs, tab)
    return tab
end

local function resetTab(tab)
    for _, key in ipairs(tab.keys) do db()[key] = ns.DEFAULTS[key] end
    changed()
end

local function copyMarkerStyleToPlates()
    local settings = db()
    settings.plateFillTexture, settings.plateFillColor, settings.plateFillOpacity =
        settings.fillTexture, settings.fillColor, settings.fillOpacity
    settings.plateDotColors, settings.plateIcon = settings.dotColors, settings.skullIcon
    settings.plateOutlineStyle, settings.plateDashLength = settings.outlineStyle, settings.dashLength
    settings.plateOutlineThickness = math.min(settings.outlineThickness, 3)
    settings.plateOutlineColor, settings.plateOutlineOpacity = settings.outlineColor, settings.outlineOpacity
end

local function applyPreset(preset)
    for key, value in pairs(preset.values) do db()[key] = value end
    copyMarkerStyleToPlates()
    changed()
    ns.print(string.format(BIT.L("%s preset applied to the target frame and nameplates."), BIT.L(preset.label)))
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------

local function isDashed(settings) return settings.outlineStyle == "dashed" end
local function hasOutline(settings) return settings.outlineStyle ~= "none" end
local function singleColor(settings) return settings.dotColors == "single" end
local function perDot(settings) return settings.dotColors ~= "single" end
local function showsLabel(settings) return settings.showLabel end
-- "Show damage marker" is the master of every unit (Core.lua, ns.markersFor): the focus and nameplate lists need it, and
-- the kill icon rows need the kill icon.
local function markersOn(settings) return settings.showMarkers end
local function killOn(settings) return settings.showSkull end

local function buildTabs()
    local lists = ns.lists
    lists.fills.kind = "texture" -- the shared drop-down merges the whole catalog into it

    local icon = addTab("Kill icon")
    icon:checkbox("showSkull", "Show kill icon",
        { tooltip = "Shows an icon at the chosen position when your DoTs on the target will kill it." })
    icon:choice("skullIcon", "Kill icon", lists.icons, { enabledIf = killOn })
    icon:slider("skullSize", "Kill icon size", 12, 128, 1, { enabledIf = killOn })
    icon:checkbox("swingKill", "Count one weapon hit", { enabledIf = killOn, tooltip = "A weapon icon shows when your DoTs plus one "
        .. "average hit of your best weapon attack (melee swing, wand or ranged shot) would kill; the kill icon "
        .. "itself still means the DoTs alone are enough. The hit is "
        .. "the character sheet's average: armor, misses and crits are not counted, and the Kill margin applies. "
        .. "The marker itself still shows only the DoTs." })
    icon:slider("killMargin", "Kill margin", 50, 100, 5, { suffix = "%", enabledIf = killOn, tooltip = "The icon shows only when this "
        .. "share of the estimated DoT damage is enough to kill. Lower it if mobs that heal or regenerate survive the "
        .. "icon; 100% compares the full estimate. The marker always shows the full estimate." })
    icon:choice("skullPosition", "Kill icon position", {
        { id = "portrait", label = "Portrait" },
        { id = "left", label = "Left of the bar" },
        { id = "right", label = "Right of the bar" },
        { id = "above", label = "Above the bar" },
        { id = "below", label = "Below the bar" },
    }, { enabledIf = killOn })
    icon:checkbox("skullPulse", "Pulse", { enabledIf = killOn, tooltip = "Gently pulses the icon while it's showing." })
    icon:slider("skullOffsetX", "Icon horizontal offset", -120, 120, 1,
        { enabledIf = killOn, tooltip = "Pixels right (+) or left (-) of the chosen position." })
    icon:slider("skullOffsetY", "Icon vertical offset", -120, 120, 1,
        { enabledIf = killOn, tooltip = "Pixels up (+) or down (-) from the chosen position." })
    if not ns.Retail then
        local execOn = function(s) return s.execShow end
        local execPlatesOn = function(s) return s.execShow and s.execPlates end
        icon:header("EXECUTE / FINISHER")
        icon:checkbox("execShow", "Show execute / finisher icon", { tooltip = "Shows Execute, Hammer of Wrath, Shadow Word: Death, "
            .. "Shadowburn, Ferocious Bite or Eviscerate above the target portrait when its estimated hit would kill the target. "
            .. "Learns real hit ratios from the damage meter after combat." })
        icon:checkbox("execPlates", "Also on enemy nameplates", { enabledIf = execOn,
            tooltip = "Shows the execute icon beside enemy nameplates too. Finishers (Ferocious Bite, Eviscerate) show only on the target's plate." })
        icon:slider("execSize", "Execute icon size", 16, 64, 1, { enabledIf = execOn })
        icon:slider("execOffsetX", "Execute horizontal offset", -120, 120, 1,
            { enabledIf = execOn, tooltip = "Pixels right (+) or left (-) of the portrait." })
        icon:slider("execOffsetY", "Execute vertical offset", -120, 120, 1,
            { enabledIf = execOn, tooltip = "Pixels up (+) or down (-) above the portrait." })
        icon:slider("execPlateSize", "Nameplate execute icon size", 12, 48, 1, { enabledIf = execPlatesOn })
        icon:choice("execPlatePosition", "Nameplate execute position", lists.nameplateIconPositions, { enabledIf = execPlatesOn })
        icon:slider("execPlateOffsetX", "Nameplate execute horizontal offset", -180, 180, 1,
            { enabledIf = execPlatesOn, tooltip = "Pixels right (+) or left (-) of the chosen nameplate position." })
        icon:slider("execPlateOffsetY", "Nameplate execute vertical offset", -120, 120, 1,
            { enabledIf = execPlatesOn, tooltip = "Pixels up (+) or down (-) from the chosen nameplate position." })
    end
    icon:gap()
    icon:note("Cast prediction has its own kill icon (Cast > Marker). If you use both, set both, or switch one off.")

    local marker = addTab("Marker")
    marker:header("SHOW ON")
    marker:checkbox("showMarkers", "Show damage marker", { tooltip = "Marks the damage your DoTs still have to "
        .. "deal on the target's health bar. If the health ends inside it, the target dies." })
    marker:checkbox("targetMarkers", "Show on target frame", { enabledIf = function(s) return s.showMarkers end,
        tooltip = "Keep this on to show the marker on your screen's target health bar. Plater changes nameplates, "
        .. "not that frame; if you use a separate unit frame addon, set its bar on the Frames page. "
        .. "Turn off to keep the marker on nameplates and the focus frame only. On Retail this also hides the rogue's "
        .. "aura icons above the target bar. The kill icon has its own switch in the Kill icon tab." })
    marker:choice("focusMode", "Show on focus frame", lists.nameplateModes, { enabledIf = markersOn, tooltip = "Draws the same marker "
        .. "(and optionally the kill icon) on your focus frame's health bar for your DoTs on the focused enemy, "
        .. "in the nameplate look (Nameplates tab)." })
    marker:choice("nameplateMode", "Show on nameplates", lists.nameplateModes, { enabledIf = markersOn, tooltip = "Draws a marker "
        .. "(and optionally the kill icon) on every enemy nameplate with your DoTs on it, in its own look on the Nameplates tab." })
    marker:header("FILL")
    marker:choice("dotColors", "DoT colors", lists.dotColors, { tooltip = "One color, or one segment per DoT "
        .. "with green poisons, purple curses/shadow damage and red bleeds. Rainbow gives each spell a separate color." })
    marker:choice("fillTexture", "Fill style", lists.fills)
    marker:choice("fillColor", "Fill color", lists.colors, { enabledIf = singleColor,
        tooltip = "Used when DoT colors is set to one color." })
    marker:slider("fillOpacity", "Fill opacity", 0, 100, 5, { suffix = "%" })
    marker:choice("fillDirection", "Fill direction", lists.plateFillDirections, { tooltip = "Which end of the "
        .. "target health bar the marker starts from. Follow health bar turns it around on a mirrored bar that "
        .. "drains the other way; choose Right to left if your unit frame addon is not recognized." })
    marker:checkbox("segmentDividers", "Show dividers between DoTs", { enabledIf = perDot })
    marker:header("OUTLINE")
    marker:choice("outlineStyle", "Outline", lists.outlines)
    marker:choice("dashLength", "Dash length", lists.dashLengths, { enabledIf = isDashed })
    marker:slider("outlineThickness", "Outline thickness", 1, 8, 1, { enabledIf = hasOutline })
    marker:choice("outlineColor", "Outline color", lists.colors, { enabledIf = hasOutline })
    marker:slider("outlineOpacity", "Outline opacity", 0, 100, 5, { suffix = "%", enabledIf = hasOutline })
    if not ns.Retail then
        marker:header("PARTY")
        marker:checkbox("partyDots", "Share DoTs with party", { tooltip = "Shares your DoT estimates in open-world "
            .. "parties and raids with group members who also enable this option (compatible with DoesItDie), so the "
            .. "marker and kill icon include everyone's DoTs." })
        marker:choice("partyDotColor", "Party DoT color", lists.colors,
            { enabledIf = function(s) return s.partyDots end,
              tooltip = "Segment color used for party members' shared DoTs." })
    end

    local effects = addTab("Effects")
    effects:checkbox("smoothMotion", "Smooth motion",
        { tooltip = "The marker grows in when it appears and glides to new values instead of jumping." })
    effects:checkbox("flashOnApply", "Flash on new DoT")
    effects:checkbox("showSpark", "Spark", { tooltip = "A bright flare on the marker's edge when a DoT lands." })
    effects:checkbox("pulseOutline", "Pulse the outline", { enabledIf = hasOutline })
    effects:gap()
    effects:checkbox("showGlow", "Glow", { enabledIf = hasOutline, tooltip = "Soft halo in the outline color." })
    effects:slider("glowSize", "Glow thickness", 2, 16, 1,
        { enabledIf = function(s) return hasOutline(s) and s.showGlow end })
    effects:checkbox("showShine", "Shine sweep")
    effects:slider("shineInterval", "Shine every", 2, 10, 1,
        { suffix = "s", enabledIf = function(s) return s.showShine end })
    effects:checkbox("scrollStripes", "Scroll stripes", { tooltip = "Animates the diagonal stripes fill.",
        enabledIf = function(s) return s.fillTexture == "stripes" and singleColor(s) end })

    local text = addTab("Text")
    text:checkbox("showLabel", "Show text",
        { tooltip = "Remaining DoT damage next to the health bar (a per-DoT breakdown with DoT colors)." })
    text:choice("labelPosition", "Text position", lists.labelPositions, { enabledIf = showsLabel })
    text:slider("labelSize", "Text size", 8, 20, 1, { enabledIf = showsLabel })
    text:choice("labelColor", "Text color", lists.colors, { enabledIf = showsLabel })

    -- Presets match both bars; these controls allow a separate nameplate look afterwards.
    -- The focus frame uses the nameplates' look and icon (Focus.lua), so these rows stay live while either shows.
    local platesOn = function(s) return s.showMarkers and (s.nameplateMode ~= "off" or s.focusMode ~= "off") end
    local plateIcon = function(s) return s.showMarkers and (s.nameplateMode == "markerIcon" or s.focusMode == "markerIcon") end
    local plateSingle = function(s) return platesOn(s) and s.plateDotColors == "single" end
    local plateOutline = function(s) return platesOn(s) and s.plateOutlineStyle ~= "none" end
    local plates = addTab("Nameplates")
    plates:header("KILL ICON")
    plates:choice("plateIcon", "Kill icon", lists.icons, { enabledIf = plateIcon })
    plates:slider("nameplateIconSize", "Kill icon size", 12, 128, 1, { enabledIf = plateIcon })
    plates:choice("nameplateIconPosition", "Kill icon position", lists.nameplateIconPositions,
        { enabledIf = plateIcon })
    plates:slider("plateIconOffsetX", "Icon horizontal offset", -180, 180, 1,
        { enabledIf = plateIcon, tooltip = "Pixels right (+) or left (-) of the chosen position." })
    plates:slider("plateIconOffsetY", "Icon vertical offset", -120, 120, 1,
        { enabledIf = plateIcon, tooltip = "Pixels up (+) or down (-) from the chosen position." })
    plates:header("FILL")
    plates:choice("plateDotColors", "DoT colors", lists.dotColors, { enabledIf = platesOn,
        tooltip = "By effect type: green poisons, purple curses/shadow damage and red bleeds. Rainbow: a separate color per spell." })
    plates:choice("plateFillTexture", "Fill style", lists.fills, { enabledIf = platesOn })
    plates:choice("plateFillDirection", "Fill direction", lists.plateFillDirections)
    plates:choice("plateFillColor", "Fill color", lists.colors, { enabledIf = plateSingle })
    plates:slider("plateFillOpacity", "Fill opacity", 0, 100, 5, { suffix = "%", enabledIf = platesOn })
    plates:header("OUTLINE")
    plates:choice("plateOutlineStyle", "Outline", lists.outlines, { enabledIf = platesOn })
    plates:choice("plateDashLength", "Dash length", lists.dashLengths,
        { enabledIf = function(s) return platesOn(s) and s.plateOutlineStyle == "dashed" end })
    plates:slider("plateOutlineThickness", "Outline thickness", 1, 3, 1, { enabledIf = plateOutline })
    plates:choice("plateOutlineColor", "Outline color", lists.colors, { enabledIf = plateOutline })
    plates:slider("plateOutlineOpacity", "Outline opacity", 0, 100, 5, { suffix = "%", enabledIf = plateOutline })
    plates.footer = pushButton(window.settingsArea, "Copy from Marker tab", 160, function()
        copyMarkerStyleToPlates()
        changed()
    end)
    plates.footer:SetPoint("BOTTOMLEFT", 10, 10)
    plates.footer:Hide()

    local behavior = addTab("Behavior")
    behavior:header("BEHAVIOR")
    if not ns.Retail then
        behavior:choice("waitFirstTick", "Wait for first tick", lists.waitModes, { tooltip = "Whether a new DoT "
            .. "counts before its first tick lands. \"When unsure\" waits for finishers with unknown combo points "
            .. "and spells the addon hasn't seen tick yet." })
    end
    behavior:checkbox("refreshCue", "Show refresh marks",
        { tooltip = ns.Retail and "A gold edge when the estimated time left is within the 30% Pandemic refresh window."
            or "A gold edge on that DoT's segment while the time left is inside the refresh window: "
            .. "one tick, three seconds, or a quarter of the duration, whichever is longer. "
            .. "The damage number stays off unless you turn it on." })
    if not ns.Retail then
        behavior:checkbox("procDots", "Ignite, Deep Wounds, traps", { tooltip = "Mages and warriors: a critical hit lights "
            .. "Ignite (a share of the fire crit over 4 s) or Deep Wounds (a share of your weapon damage over 12 s), "
            .. "with no cast to say so. Assumes you have the talent (when the talent tree can be read and shows no "
            .. "points, nothing is drawn). A crit counts as yours when you cast at that mob just before, or, for "
            .. "Deep Wounds, swing at it while alone; the first tick confirms it. Traps (Immolation Trap) are "
            .. "tracked as well." })
        behavior:checkbox("deathMark", "Death Mark (experimental)", { tooltip = "Rogues: shows what Death Mark has "
            .. "stored so far as one more segment, until it goes off 6 s after the finisher, never above the cap in its "
            .. "description. Garrote and Rupture ticks count twice. Experimental, off by default: the game doesn't say "
            .. "who hit the marked mob, so every hit on it counts as yours. In a party or raid the others' damage is "
            .. "counted too and the estimate runs high. Not tested in game." })
    end
    behavior:checkbox("targetOverMouseover", "Target beats mouseover", { tooltip =
        "For packs of mobs with the same name. With the mouse over a second mob of the pack, the addon "
        .. "can't tell which of the two your spell goes to and hides the estimate. With this on, your target "
        .. "(or focus, or the soft target when nothing is targeted) wins over the mob under the mouse. (If you cast with @mouseover macros, "
        .. "the estimate could then show on the wrong mob.)" })
    behavior:checkbox("estimateDuringCast", "Estimate during casting", { tooltip = "Shows a DoT with a cast time "
        .. "while you're still casting it. Once the cast lands the normal estimate takes over; an interrupted or "
        .. "failed cast removes it." })
    if ns.Retail then
        behavior:action("Retail damage estimate", "Info", function()
            ns.print(BIT.L("Rogue bleed and poison icons use WoW's aura timers. DoT damage is estimated from your casts and spell descriptions; dispels, immunities, procs and damage modifiers may change it."))
        end, { tooltip = "The skull means estimated damage exceeds health. It is a prediction, not a confirmed kill." })
    else
        behavior:action("Learned tick sizes", "View", function() ns.toggleTickViewer() end, { tooltip = "What each of "
            .. "your DoTs really ticks for, learned from earlier casts and used instead of the tooltip's number. "
            .. "You can also type /dotinfo ticks." })
        behavior:action("Forget learned sizes", "Reset", function() ns.resetLearnedTicks() end,
            { tooltip = "Forget the tick sizes learned from earlier casts." })
    end
    -- Another addon's unit frames live on the hub's Frames page (Core/FramesPage.lua): they steer every marker.
    behavior:header("DIAGNOSTICS")
    behavior:action("Another unit frame addon", "Open Frames", function()
        if BIT.OpenSettings then BIT.OpenSettings("Frames") end
    end, { tooltip = "ElvUI, Shadowed Unit Frames and other unit frame addons: where their health bars are is set once "
        .. "for every marker, on the Frames page." })
    behavior:checkbox("debug", "Debug lines in chat",
        { tooltip = ns.Retail and "Prints each DoT cast and damage estimate to chat."
            or "Prints each DoT cast, matched tick and estimate to chat." })
    if not ns.Retail then
        -- WoW: Forever. Segments drawn by the game's own aura frames (RogueAuras.lua); a tab of their own so Behavior fits.
        local native = addTab("Native auras")
        native:header("FEATURES")
        native:checkbox("nativeDots", "Native aura segments", { tooltip = "Deadly Poison, Deep Wound, Ignite, "
            .. "Righteous Judgement, Immolation Trap, Explosive Trap, Wyvern Sting and Flamestrike are drawn from the real "
            .. "aura: its start, time left and removal come from the game, the size from the spell description and your "
            .. "stats. Switch it off to go back to the plain estimates (the old guesses for traps and Wyvern Sting return). "
            .. "Takes effect at once." })
        native:checkbox("nativeStacks", "Deadly Poison stack count", { enabledIf = function(s) return s.nativeDots end, tooltip = "A small number above the bar's left "
            .. "end with the stacks of your Deadly Poison on that mob (the game draws it, the addon cannot read it)." })
        native:checkbox("nativeAllDots", "Native segment for every DoT (experimental)", { tooltip = "Draws a segment from "
            .. "the real aura (its start, time left and removal) for every damage over time you know, wherever Lua has no DoT "
            .. "of its own on that mob: other mobs, mobs out of sight, effects nothing announces. The size comes from the "
            .. "spell description and your stats. One or two extra aura frames per spell on every hostile nameplate: check "
            .. "/upt perf before keeping it on. On by default in this beta. The spells of \"Native aura segments\" are drawn this "
            .. "way whenever that option is on." })
        native:header("EXPERIMENTS (ON BY DEFAULT IN THIS BETA)")
        native:checkbox("nativeGateReplace", "Aura-gated segments on nameplates (experiment)", { enabledIf = function(s) return s.showMarkers and s.nameplateMode ~= "off" and s.plateDotColors ~= "single" end, tooltip = "The DoT "
            .. "segments on nameplates are drawn by the game's own aura frames, with the length the addon calculates (they "
            .. "still drop tick by tick), so a segment is shown only while the real aura is on the mob: when a mob resets "
            .. "after you run away, a DoT is dispelled or resisted, it disappears at once instead of a few seconds later. "
            .. "The addon never reads the aura. Only DoTs whose spell puts the aura on the target itself are drawn this "
            .. "way (not Curse of Agony, Siphon Life, traps, poisons), and only with a colour per DoT (not \"One colour\"). "
            .. "The kill icon and the damage number still use the addon's own numbers. On by default in this beta." })
        native:checkbox("nativeGate", "Aura-gated segment on the target frame (experiment)", { tooltip = "An experiment: a second thin "
            .. "row under the bar (cyan) as long as the addon's own remaining damage of a DoT it draws (so it drops tick by "
            .. "tick like the segment on the bar), but shown only while the real aura is on the mob: the game shows and hides "
            .. "it, the addon never reads the aura. Watch it when a mob resets after you run away, a DoT is dispelled or "
            .. "resisted. Needs \"Native segment for every DoT\" for DoTs the addon does not have fixed segments for. On by "
            .. "default in this beta." })
        native:header("DIAGNOSTICS")
        native:checkbox("nativeShowAll", "Show native next to plain segments", { enabledIf = function(s) return s.nativeDots or s.nativeAllDots or s.nativeGateReplace or s.nativeGate end, tooltip = "For checking the "
            .. "native segments: they are normally hidden wherever the addon draws the same DoT itself (a warlock's own "
            .. "Corruption, for instance). With this on they are drawn anyway, white and half transparent in a thin row under "
            .. "the bar, starting at its left edge, so you can compare their length and time left with the plain segment on "
            .. "the bar. Cast a single DoT on a mob and watch both. Off by default." })
    end
    for _, tab in ipairs(tabs) do tab:finish() end
end

local function buildPreview(pane)
    -- y in px from the pane's top; every block on the same 12 px side margins.
    local SIDE = 12
    local CARD_WIDTH = PREVIEW_WIDTH - 2 * SIDE -- 266
    local RULE = BIT.UI.COLOR.divider

    -- Title row, level with the tab row on the right (its divider is also 34 px down).
    BIT.UI.PreviewHeader(pane, "Live preview", SIDE)

    -- Scene (44..234): shared dusky world backdrop and mock frames (Core/Preview.lua).
    local scene = BIT.UI.Preview.Scene(pane, CARD_WIDTH, 190)
    scene:SetPoint("TOP", pane, "TOP", 0, -44)

    local targetMock = BIT.UI.Preview.TargetFrame(scene, {
        name = "Murloc Raider", level = "12", health = preview.health, layerFrame = window,
    })
    targetMock.frame:SetPoint("TOP", scene, "TOP", 0, -4)
    window.healthPercent = targetMock.healthPercent
    window.healthValue = targetMock.healthValue
    window.healthBar = targetMock.healthBar
    window.host = targetMock.host
    window.mock = targetMock.frame

    local plateMock = BIT.UI.Preview.Nameplate(scene, {
        width = 190, name = "Murloc Raider", level = "12", health = preview.health,
    })
    plateMock.frame:SetPoint("BOTTOM", scene, "BOTTOM", 0, 22)
    window.mockPlate = plateMock.frame
    window.plateHealthBar = plateMock.bar
    window.plateHost = { plate = plateMock.frame, healthBar = plateMock.bar }

    -- Shown over the mock frames while combat has the display back on the real target. On its own layer above
    -- the scene: a font string on the pane would draw under it.
    local noteLayer = CreateFrame("Frame", nil, scene)
    noteLayer:SetAllPoints(scene)
    noteLayer:SetFrameLevel(targetMock.frame:GetFrameLevel() + 10)
    window.combatNote = noteLayer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    window.combatNote:SetPoint("CENTER", scene, "CENTER")
    window.combatNote:SetWidth(CARD_WIDTH - 24)
    window.combatNote:SetText(BIT.L("In combat: the marker and kill icon are showing on your target. "
        .. "The preview resumes after combat."))
    window.combatNote:Hide()

    -- Verdict badge (242..272), right under the scene it describes: accent stripe, icon, verdict, numbers.
    local badge = CreateFrame("Frame", nil, pane, "BackdropTemplate")
    badge:SetSize(CARD_WIDTH, 30)
    badge:SetPoint("TOP", scene, "BOTTOM", 0, -8)
    badge:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    badge.accent = badge:CreateTexture(nil, "ARTWORK")
    badge.accent:SetPoint("TOPLEFT", 1, -1)
    badge.accent:SetPoint("BOTTOMLEFT", 1, 1)
    badge.accent:SetWidth(3)
    badge.icon = badge:CreateTexture(nil, "ARTWORK")
    badge.icon:SetSize(18, 18)
    badge.icon:SetPoint("LEFT", badge, "LEFT", 12, 0)
    window.statusDetail = badge:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    window.statusDetail:SetPoint("RIGHT", badge, "RIGHT", -10, 0)
    window.statusDetail:SetJustifyH("RIGHT")
    window.statusDetail:SetTextColor(0.75, 0.75, 0.75)
    window.status = badge:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    window.status:SetPoint("LEFT", badge.icon, "RIGHT", 8, 0)
    window.status:SetPoint("RIGHT", window.statusDetail, "LEFT", -8, 0)
    window.status:SetJustifyH("LEFT")
    window.status:SetWordWrap(false)
    window.statusBadge = badge

    -- Try it: the preview's own numbers (not settings).
    local tryIt = BIT.Looks.TryItHeader(pane, badge, 0, -16)
    local health = sliderRow(pane, "Target health", 0, 100, 1,
        function() return preview.health end,
        function(value)
            stopSimulation()
            preview.health = value
            updatePreview()
        end, { layout = PREVIEW_LAYOUT, suffix = "%" })
    health:SetPoint("TOPLEFT", tryIt, "BOTTOMLEFT", -6, -6) -- rows start 6 px in, so their labels sit on the margin
    local damage = sliderRow(pane, "DoT damage", 0, 100, 1,
        function() return math.floor(previewTotal() + 0.5) end,
        function(value)
            stopSimulation()
            setPreviewDamage(value)
            updatePreview()
        end, { layout = PREVIEW_LAYOUT, suffix = "%",
            tooltip = "Remaining damage of two sample DoTs, in % of the target's max health." })
    damage:SetPoint("TOPLEFT", health, "BOTTOMLEFT", 0, 0)

    -- Single-row SIMULATE block matching BIT.Looks.Simulate in every other preview pane.
    local simBlock = CreateFrame("Frame", nil, pane)
    simBlock:SetPoint("TOPLEFT", damage, "BOTTOMLEFT", 6, -12)
    simBlock:SetPoint("RIGHT", pane, "RIGHT", -SIDE, 0)
    simBlock:SetHeight(24)
    local simHead = simBlock:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    simHead:SetPoint("LEFT", simBlock, "LEFT", 0, 0)
    simHead:SetText(BIT.L("SIMULATE"))
    local hc = BIT.UI.COLOR.heading
    simHead:SetTextColor(hc[1], hc[2], hc[3])
    window.flashButton = pushButton(simBlock, "Flash", 64, function() ns.playFlash() end)
    window.flashButton:SetHeight(20)
    window.flashButton:SetPoint("RIGHT", simBlock, "RIGHT", 0, 0)
    window.simulateButton = pushButton(simBlock, "Simulate", 82, function()
        if simulation then stopSimulation() else startSimulation() end
    end)
    window.simulateButton:SetHeight(20)
    window.simulateButton:SetPoint("RIGHT", window.flashButton, "LEFT", -6, 0)
    local simRule = simBlock:CreateTexture(nil, "ARTWORK")
    simRule:SetColorTexture(RULE[1], RULE[2], RULE[3], RULE[4])
    simRule:SetHeight(1)
    simRule:SetPoint("LEFT", simHead, "RIGHT", 8, 0)
    simRule:SetPoint("RIGHT", window.simulateButton, "LEFT", -8, 0)

    BIT.UI.PreviewHint(pane, "While this window is open, the marker and kill icon are drawn here instead of on your target.", SIDE)
end

-- The presets, the preview and the settings, in window: the addon's own window, below its title bar
-- with the presets beside anchor (its close button), or inside UsefulPlatesAndTooltips the tab it is built into.
local function buildContent(top, anchor, withSummary)
    -- Presets, right-aligned in the title bar: the shared "Look presets" button.
    local presetLabel = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    local presetButton = BIT.Looks.PresetButton(window, PRESETS, applyPreset)
    presetButton:SetPoint("RIGHT", anchor, "LEFT", -8, 0)
    presetLabel:SetPoint("RIGHT", presetButton, "LEFT", -8, 0)
    presetLabel:SetText(BIT.L("Both bars"))
    if withSummary and BIT.UI.TabSummary then
        BIT.UI.TabSummary(window, BIT.L("Marks on the target's health bar the damage your DoTs still have to deal, "
            .. "with a kill icon when they will finish it."), presetLabel)
    end

    local pane = CreateFrame("Frame", nil, window, "BackdropTemplate")
    pane:SetPoint("TOPLEFT", 10, -top)
    pane:SetPoint("BOTTOMLEFT", 10, 10)
    pane:SetWidth(PREVIEW_WIDTH)
    setBackdrop(pane, 0.09)
    buildPreview(pane)

    local area = CreateFrame("Frame", nil, window, "BackdropTemplate")
    area:SetPoint("TOPLEFT", pane, "TOPRIGHT", 10, 0)
    area:SetPoint("BOTTOMRIGHT", -10, 10)
    setBackdrop(area, 0.09)
    window.settingsArea = area

    local divider = area:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(unpack(BIT.UI.COLOR.divider))
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", 8, -34 - (TAB_ROWS - 1) * TAB_HEIGHT)
    divider:SetPoint("TOPRIGHT", -8, -34 - (TAB_ROWS - 1) * TAB_HEIGHT)

    buildTabs()
    local reset = BIT.Looks.ResetButton(area, function() resetTab(activeTab) end)
    reset:SetPoint("BOTTOMRIGHT", -10, 10)

    window:SetScript("OnShow", function()
        ns.setPreviewState(preview)
        window.previewPaused = nil
        syncDisplayHost()
        refreshControls()
        updatePreview()
    end)
    window:SetScript("OnHide", function()
        stopSimulation()
        closeMenu()
        ns.setPreviewState(nil)
        ns.setDisplayHost(nil)
        ns.setPlatePreview(nil)
    end)
    -- Combat hands the display back to the real target, and after combat back to the preview.
    window:RegisterEvent("PLAYER_REGEN_DISABLED")
    window:RegisterEvent("PLAYER_REGEN_ENABLED")
    window:SetScript("OnEvent", function() syncDisplayHost() end)
    selectTab(tabs[1])
end

local function createWindow()
    local _, _, close
    window, _, close = BIT.UI.NativeWindow("UsefulPlatesAndTooltips_DoTInfoOptions", "DoTInfo", WINDOW_WIDTH, WINDOW_HEIGHT)
    window:SetPoint("CENTER")
    if BIT.UI and BIT.UI.CloseOnEscape then BIT.UI.CloseOnEscape(window) end

    local anchor = CreateFrame("Frame", nil, window)
    anchor:SetSize(1, 22)
    anchor:SetPoint("TOPRIGHT", -10, -28)
    buildContent(HEADER_HEIGHT + 16, anchor, true)
end

function ns.openOptions()
    if not ns.db then return end
    if BIT.OpenSettings then BIT.OpenSettings("DoTInfo") return end
    if not window then createWindow() end
    if window:IsShown() then
        window:Hide()
    else
        window:Show()
    end
end

-- Options > AddOns > DoTInfo: a short page with a button that opens the window.
function ns.registerOptions()
    local function openSettings()
        if not (window and window:IsShown()) then ns.openOptions() end
    end
    if type(BIT.UI.RegisterSettingsLauncher) == "function" and BIT.UI.RegisterSettingsLauncher("DoTInfo",
        BIT.L("Open the options window with a live preview. You can also type /dotinfo."), openSettings) then return end
    local panel = CreateFrame("Frame")
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("DoTInfo")
    title:SetTextColor(BIT.UI.COLOR.heading[1], BIT.UI.COLOR.heading[2], BIT.UI.COLOR.heading[3])
    local text = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    text:SetText(BIT.L("Settings have their own window with a live preview. You can also type /dotinfo."))
    local open = pushButton(panel, "Open settings", 180, openSettings)
    open:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -14)
    local category = Settings.RegisterCanvasLayoutCategory(panel, "DoTInfo")
    Settings.RegisterAddOnCategory(category)
end

-- Inside UsefulPlatesAndTooltips: the window's content in its tab, with the presets at the tab's top right.
-- BIT Minimal OFF-scene sample: a static mock bar with a fixed tick label, never
-- live ticks and never real nameplates.
local function buildDoTPreview(parent)
  local scene = CreateFrame("Frame", nil, parent)
  scene:SetSize(560, 120)
  scene.title = scene:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  scene.title:SetPoint("TOPLEFT", 12, -4)
  scene.title:SetText(BIT.L("DoTInfo sample (not your bars)"))
  scene.bar = CreateFrame("StatusBar", nil, scene)
  scene.bar:SetSize(180, 20)
  scene.bar:SetPoint("TOPLEFT", 12, -30)
  scene.bar:SetStatusBarTexture(WHITE)
  scene.bar:SetStatusBarColor(0.65, 0.2, 0.85)
  scene.bar:SetMinMaxValues(0, 100)
  scene.bar:SetValue(60)
  local back = scene.bar:CreateTexture(nil, "BACKGROUND")
  back:SetAllPoints()
  back:SetColorTexture(0.12, 0.04, 0.16, 1)
  scene.label = scene:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  scene.label:SetPoint("TOPLEFT", 12, -56)
  scene.label:SetText(BIT.L("450 over 3 ticks"))
  scene.label:SetHeight(14)
  return scene
end

local function renderDoTPreview(scene, style)
  BIT.Style.ApplyText(scene.title, style, "text")
  BIT.Style.ApplyText(scene.label, style, "text")
  -- Native-Y min/max reflow: bar height, label row and scene height derive
  -- from the shared font size; widths stay fixed (no scale capability).
  -- The window is never resized.
  local fontSize = style.fontSize or 12
  local barH = math.max(20, fontSize + 6)
  local barDepth = 4 + fontSize + 8
  local labDepth = barDepth + barH + 4
  scene.bar:ClearAllPoints()
  scene.bar:SetPoint("TOPLEFT", 12, -barDepth)
  scene.bar:SetSize(180, barH)
  scene.label:ClearAllPoints()
  scene.label:SetPoint("TOPLEFT", 12, -labDepth)
  scene:SetSize(560, labDepth + fontSize + 16)
end

if BIT.RegisterTab then
    BIT.RegisterTab("DoTInfo", {
        title = "DoTInfo",
        summary = "Marks on the target's health bar the damage your DoTs still have to deal, with a kill icon "
            .. "when they will finish it.",
        width = WINDOW_WIDTH, height = WINDOW_HEIGHT,
        build = function(parent)
            if window == parent then return end
            stopSimulation()
            closeMenu()
            if window then
                window:Hide()
                window:UnregisterAllEvents()
                window:SetScript("OnShow", nil)
                window:SetScript("OnHide", nil)
                window:SetScript("OnEvent", nil)
            end
            controls, tabs, activeTab = {}, {}, nil
            window = parent
            local anchor = CreateFrame("Frame", nil, parent)
            anchor:SetSize(1, 22)
            anchor:SetPoint("TOPRIGHT", -10, -8)
            buildContent(BIT.UI.TAB_TOP or 44, anchor, true)
        end,
        buildPreview = buildDoTPreview,
        previewRender = renderDoTPreview,
        capabilities = { roles = { "text" }, shapes = false,
            geometry = false, border = false, font = true, scale = false, opacity = true },
    })
    BIT.tabWords.dot, BIT.tabWords.did = "DoTInfo", "DoTInfo"
end

if BIT.Art and type(BIT.Art.Subscribe) == "function" then
    BIT.Art.Subscribe(function()
        if window then
            updatePreview()
            refreshControls()
        end
    end)
end
