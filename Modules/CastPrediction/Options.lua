-- UsefulPlatesAndTooltips module CastPrediction: the settings tab (/upt castpred) with a live
-- preview. The window's left column holds the preview: the module's real marker drawn on mock
-- frames (Core/Preview.lua) and fed plain numbers, the same way DoTInfo's preview does; the right
-- column holds the settings, split into sub-tabs.
local _, BIT = ...

local ns = BIT.Module("CastPrediction")

local WINDOW_WIDTH, WINDOW_HEIGHT = 840, 500
local PREVIEW_WIDTH = 290
local COL_HEIGHT = 440
local ROW_HEIGHT = 26
local SIDE = 12
local HEALTH_SCALE = 10 -- the mock bars are 0..100; the marker works on a 0..1000 health scale

local window
local areas
local tabButtons
local controls = {}
local panel
local preview = { health = 62, spell = 1 } -- TRY IT: the preview's own numbers, never settings

-- The sample casts the preview walks through, in the order of the button.
local SAMPLE_SPELLS = {
    { name = "Frostbolt",      min = 410, max = 450, school = 16 },
    { name = "Fireball",       min = 600, max = 760, school = 4 },
    { name = "Shadow Bolt",    min = 480, max = 540, school = 32 },
    { name = "Lightning Bolt", min = 430, max = 490, school = 8 },
    { name = "Pyroblast",      min = 780, max = 980, school = 4 },
    { name = "Arcane Missiles (channel)", min = 280, max = 320, school = 64, channel = true },
}

local function db() return ns._settings() end

local function currentSpell()
    return SAMPLE_SPELLS[preview.spell] or SAMPLE_SPELLS[1]
end

-- Values the marker shows in the preview: the chosen sample cast at its average, against a mock
-- target whose health runs on the same 0..1000 scale.
local function previewState()
    local spell = currentSpell()
    local health = preview.health * HEALTH_SCALE
    return {
        name = spell.name,
        min = spell.min,
        max = spell.max,
        value = (spell.min + spell.max) / 2,
        school = spell.school,
        channel = spell.channel,
        health = health,
        maxHealth = 100 * HEALTH_SCALE,
    }
end

local function refreshControls()
    for _, control in ipairs(controls) do
        if control.Refresh then control:Refresh() end
    end
end

local function updatePreview()
    if not panel then return end
    ns.setPreviewState(previewState())
    if panel.spellButton then panel.spellButton:SetText(currentSpell().name) end
    if panel.healthSlider then panel.healthSlider:Refresh() end
    ns._refresh()
end

local function changed()
    refreshControls()
    updatePreview()
end

local function inCombat()
    return type(InCombatLockdown) == "function" and InCombatLockdown() and true or false
end

local function releasePreview()
    ns.setPreviewState(nil)
    ns.setDisplayHost(nil)
    ns.setPlatePreview(nil)
end

-- The preview takes the display over out of combat; in combat the real target keeps it, exactly
-- like DoTInfo's preview.
local hostsSet = false
local function syncDisplayHost()
    if not (panel and window and window:IsShown()) then return end
    if hostsSet and inCombat() then
        hostsSet = false
        releasePreview()
        if panel.combatNote then panel.combatNote:Show() end
    elseif not hostsSet and not inCombat() then
        hostsSet = true
        if panel.combatNote then panel.combatNote:Hide() end
        ns.setDisplayHost(panel.host)
        ns.setPlatePreview(panel.plateHost)
        updatePreview()
    end
end

---------------------------------------------------------------------------------------------
-- Row builders: the core's own widgets, placed in a column
---------------------------------------------------------------------------------------------

local function place(row, y, height)
    row:SetPoint("TOPLEFT", row:GetParent(), "TOPLEFT", 6, -y)
    row:SetPoint("RIGHT", row:GetParent(), "RIGHT", -6, 0)
    table.insert(controls, row)
    return y + (height or ROW_HEIGHT)
end

local function checkRow(parent, labelText, key, tooltip)
    return BIT.UI.Check(parent, labelText, function() return db()[key] end, function(value)
        db()[key] = value
        changed()
    end, tooltip)
end

local function sliderRow(parent, labelText, key, min, max, step, format, tooltip)
    return BIT.UI.Slider(parent, labelText, min, max, step, function() return db()[key] end, function(value)
        db()[key] = value
        changed()
    end, format, tooltip)
end

-- A cycle button: clicking walks the list, the current entry names the button.
local function choiceRow(parent, labelText, key, list, tooltip)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW_HEIGHT)
    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.label:SetPoint("LEFT", 0, 0)
    row.label:SetText(labelText)
    local button = BIT.UI.Button(row, "", 180, nil)
    button:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    local function current()
        local value = db()[key]
        for _, entry in ipairs(list) do
            if entry.id == value then return entry end
        end
        return list[1] or { label = "?" }
    end
    button:SetScript("OnClick", function()
        local entry = current()
        local nextIndex = 1
        for i, candidate in ipairs(list) do
            if candidate.id == entry.id then nextIndex = i % #list + 1 end
        end
        db()[key] = list[nextIndex].id
        changed()
    end)
    if tooltip then
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(labelText, 1, 0.82, 0)
            GameTooltip:AddLine(tooltip, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    row.Refresh = function(self)
        button:SetText(current().label)
        self.label:SetText(labelText)
    end
    row:Refresh()
    return row
end

local function buttonRow(parent, labelText, buttonText, onClick, tooltip)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW_HEIGHT)
    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.label:SetPoint("LEFT", 0, 0)
    row.label:SetText(labelText)
    local button = BIT.UI.Button(row, buttonText, 180, function()
        onClick()
        changed()
    end)
    button:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    if tooltip then
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(buttonText, 1, 0.82, 0)
            GameTooltip:AddLine(tooltip, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    row.Refresh = function(self)
        button:SetText(buttonText)
        self.label:SetText(labelText)
    end
    return row
end

-- A cycle row over a table of choices; get/set work on any value (Auto is the absence of a value).
local function forceRow(parent, labelText, choices, get, set, tooltip)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW_HEIGHT)
    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.label:SetPoint("LEFT", 0, 0)
    row.label:SetText(labelText)
    local button = BIT.UI.Button(row, choices[1].label, 180, nil)
    button:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    local function current()
        local value = get()
        for _, choice in ipairs(choices) do
            if choice.id == value then return choice end
        end
        return choices[1]
    end
    button:SetScript("OnClick", function()
        local choice = current()
        local nextIndex = 1
        for i, candidate in ipairs(choices) do
            if candidate.id == choice.id then nextIndex = i % #choices + 1 end
        end
        local nextChoice = choices[nextIndex]
        set(nextChoice.id ~= "auto" and nextChoice.id or nil)
        changed()
    end)
    if tooltip then
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(labelText, 1, 0.82, 0)
            GameTooltip:AddLine(tooltip, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    row.Refresh = function(self)
        button:SetText(current().label)
        self.label:SetText(labelText)
    end
    row:Refresh()
    return row
end

-- One curated talent of the player's class: Auto (the client's tree answers) / Off / Max rank.
-- The force lives in settings.talentForce[key]; Auto is the absence of a value.
local TALENT_CHOICES = {
    { id = "auto", label = "Auto (detect)" },
    { id = "off",  label = "Off" },
    { id = "max",  label = "Max rank" },
}
local function talentForceRow(parent, entry, tooltip)
    return forceRow(parent, entry.en, TALENT_CHOICES,
        function()
            local force = db().talentForce
            return force and force[entry.key] or nil
        end,
        function(value)
            db().talentForce = db().talentForce or {}
            db().talentForce[entry.key] = value
        end, tooltip)
end

-- One curated aura: Auto (read it when the client shows it) / Off.
local AURA_CHOICES = {
    { id = "auto", label = "Auto (read)" },
    { id = "off",  label = "Off" },
}
local function auraForceRow(parent, entry, tooltip)
    return forceRow(parent, string.format("%s (%s)", entry.en, entry.unit), AURA_CHOICES,
        function()
            local force = db().auraForce
            return force and force[entry.key] or nil
        end,
        function(value)
            db().auraForce = db().auraForce or {}
            db().auraForce[entry.key] = value
        end, tooltip)
end

local function header(parent, text)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetText(text)
    label:SetTextColor(1, 0.82, 0)
    local rule = parent:CreateTexture(nil, "ARTWORK")
    rule:SetColorTexture(unpack(BIT.UI.COLOR.divider))
    rule:SetHeight(1)
    rule:SetPoint("LEFT", label, "RIGHT", 8, 0)
    return label
end

local function note(parent, text)
    local line = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    line:SetWidth(470)
    line:SetJustifyH("LEFT")
    line:SetText(text)
    return line
end

local function colorList(school)
    local list = ns._colorList and ns._colorList() or {}
    if school then
        local fills = { { id = "school", label = "Spell school" } }
        for _, entry in ipairs(list) do fills[#fills + 1] = entry end
        return fills
    end
    return list
end

---------------------------------------------------------------------------------------------
-- The sub-tabs of the right column
---------------------------------------------------------------------------------------------

local function buildMarkerTab(parent)
    local y = place(header(parent, "THE MARKER"), 0, ROW_HEIGHT)
    y = place(checkRow(parent, "Show the marker", "showMarker",
        "The predicted damage, drawn across the target's health bar while a cast is in flight."), y)
    y = place(header(parent, "SOLID CASTS / BANDED CHANNELS"), y, ROW_HEIGHT)
    y = place(choiceRow(parent, "Fill color", "fillColor", colorList(true),
        "Only your own cast is ever drawn on the bar."), y)
    y = place(sliderRow(parent, "Fill opacity", "fillOpacity", 0, 100, 5, nil,
        "How strongly the fill covers the health bar."), y, 40)
    y = place(choiceRow(parent, "Outline", "outlineStyle", {
        { id = "solid", label = "Solid" },
        { id = "none", label = "None" },
    }, "A hairline around the marker; it can pulse while the cast is in flight."), y)
    y = place(choiceRow(parent, "Outline color", "outlineColor", colorList(), nil), y)
    y = place(sliderRow(parent, "Outline opacity", "outlineOpacity", 0, 100, 5, nil, nil), y, 40)
    y = place(checkRow(parent, "Pulse the outline", "pulseOutline",
        "A soft breathing of the outline while the cast is in flight."), y)
    y = place(checkRow(parent, "Kill icon on the portrait", "showKillIcon",
        "A skull when even the lowest end of the cast's range would finish the target. Drawn by a "
        .. "status bar, so it works with hidden health too."), y)
    y = place(choiceRow(parent, "Kill icon", "killIcon", {
        { id = "skull", label = "Raid skull" },
        { id = "cross", label = "Red X" },
        { id = "impact", label = "Impact" },
    }, "Which icon the lethal cue uses."), y)
    local hint = note(parent, "The marker covers health backwards from the current HP edge. "
        .. "At 60/100 HP, 20 damage covers 60 down to 40. Overkill is clipped inside the bar.")
    hint:SetPoint("TOPLEFT", parent, "TOPLEFT", 6, -y - 6)
end

local function buildLabelTab(parent)
    local y = place(header(parent, "THE LABEL"), 0, ROW_HEIGHT)
    y = place(checkRow(parent, "Show a label", "showLabel",
        "The spell name and the number, at the spot picked below."), y)
    y = place(choiceRow(parent, "Label shows", "labelMode", {
        { id = "amount", label = "Damage" },
        { id = "range", label = "Damage range" },
        { id = "percent", label = "Percent of the target's health" },
    }, "Damage is the single estimate picked on the Prediction tab; the range shows both ends; "
        .. "the percent needs a readable target health (out of combat in Forever)."), y)
    y = place(choiceRow(parent, "Label position", "labelPosition", {
        { id = "left", label = "Left of the bar" },
        { id = "center", label = "Centered on the bar" },
        { id = "right", label = "Inside the bar, right end" },
    }, nil), y)
    y = place(sliderRow(parent, "Label size", "labelSize", 8, 20, 1, nil, nil), y, 40)
    y = place(choiceRow(parent, "Label color", "labelColor", colorList(), nil), y)
end

local function buildNameplateTab(parent)
    local y = place(header(parent, "NAMEPLATES"), 0, ROW_HEIGHT)
    y = place(choiceRow(parent, "On nameplates", "nameplateMode", {
        { id = "off", label = "Off" },
        { id = "marker", label = "Marker on the health bar" },
        { id = "markerIcon", label = "Marker and an impact icon" },
    }, "The target's own plate gets the same marker, with its own colors; enemy bars are red."), y)
    y = place(choiceRow(parent, "Fill color", "plateFillColor", colorList(true), nil), y)
    y = place(sliderRow(parent, "Fill opacity", "plateFillOpacity", 0, 100, 5, nil, nil), y, 40)
    y = place(choiceRow(parent, "Outline", "plateOutlineStyle", {
        { id = "solid", label = "Solid" },
        { id = "none", label = "None" },
    }, nil), y)
    y = place(choiceRow(parent, "Outline color", "plateOutlineColor", colorList(), nil), y)
    y = place(sliderRow(parent, "Outline opacity", "plateOutlineOpacity", 0, 100, 5, nil, nil), y, 40)
    y = place(sliderRow(parent, "Icon size", "plateIconSize", 12, 32, 1, nil,
        "The impact icon beside or above the plate."), y, 40)
    y = place(choiceRow(parent, "Icon position", "plateIconPosition", {
        { id = "left", label = "Left of the bar" },
        { id = "above", label = "Above the bar" },
        { id = "right", label = "Right of the bar" },
    }, nil), y)
    y = place(sliderRow(parent, "Icon offset X", "plateIconOffsetX", -40, 40, 1, nil, nil), y, 40)
    y = place(sliderRow(parent, "Icon offset Y", "plateIconOffsetY", -40, 40, 1, nil, nil), y, 40)
end

local function buildPredictionTab(parent)
    local y = place(header(parent, "THE PREDICTION"), 0, ROW_HEIGHT)
    y = place(choiceRow(parent, "The marker shows", "estimate", {
        { id = "average", label = "Average of the range" },
        { id = "min", label = "Lowest of the range" },
        { id = "max", label = "Highest of the range" },
    }, "The expected damage the description and your spell power give."), y)
    y = place(checkRow(parent, "Only cast spells", "castOnly",
        "Show casts and channels. Instant spells are hidden unless this option is switched off."), y)
    y = place(checkRow(parent, "Learn from hits", "learn",
        "Every non-crit hit that matches the cast bends the estimate toward what you actually deal. "
        .. "On Retail the description already holds your spell power, so nothing is learned there."), y)
    y = place(checkRow(parent, "Manual spell power", "manualPower",
        "Use your own number instead of the client's reading, for testing or when the client hides it."), y)
    y = place(sliderRow(parent, "Spell power", "manualPowerValue", 0, 1200, 10, nil,
        "Applied through the spell's own coefficient, like the client's own reading would be."), y, 40)
    y = place(buttonRow(parent, "Learned factors", "Reset", function()
        ns.resetLearned()
    end, "Forget what earlier hits taught the estimate."), y)
    y = place(header(parent, "TALENTS (FOREVER)"), y)
    local playerClass = ns.Talents and ns.Talents.PlayerClass and ns.Talents.PlayerClass() or nil
    local applicable = {}
    if ns.Talents and ns.Talents.LIST then
        for _, entry in ipairs(ns.Talents.LIST) do
            if entry.class == playerClass then applicable[#applicable + 1] = entry end
        end
    end
    if #applicable == 0 then
        local none = note(parent, "No curated passive talent multipliers for this class (or the character "
            .. "class could not be read). Retail tooltips already include talents, so nothing is added there.")
        none:SetPoint("TOPLEFT", parent, "TOPLEFT", 6, -y - 6)
    else
        for _, entry in ipairs(applicable) do
            y = place(talentForceRow(parent, entry,
                "Auto reads the talent's rank from the client's talent tree (C_Traits). Off skips it; "
                .. "Max rank applies it without asking. Retail never adds talents: its descriptions hold them."), y)
        end
    end
    y = place(header(parent, "AURAS (READ WHEN VISIBLE)"), y)
    y = place(checkRow(parent, "Include auras", "useAuras",
        "Buffs on you and debuffs on the target that the description does not hold: Arcane Power, "
        .. "Power Infusion, Arcane Blast stacks, Improved Scorch, Curse of the Elements."), y)
    if ns.Auras and ns.Auras.LIST then
        for _, entry in ipairs(ns.Auras.LIST) do
            y = place(auraForceRow(parent, entry,
                "Auto applies this while the client shows it. WoW: Forever hides auras in combat, so there it "
                .. "only ever applies out of combat; the hit calibration carries the rest. "
                .. "/upt castpred auras prints what is readable right now."), y)
        end
    end
    local hint = note(parent, "The estimate is the description's own damage range plus your spell "
        .. "power through the spell's coefficient, the detected passive talents and the readable auras. "
        .. "Critical strikes roll about double, so a crit can outrun the marker: the prediction is an honest "
        .. "estimate, never a promise. /upt castpred talents and /upt castpred auras print what the client answers.")
    hint:SetPoint("TOPLEFT", parent, "TOPLEFT", 6, -y - 6)
end

local function buildTabs(parent, area)
    areas = {}
    tabButtons = {}
    local function selectTab(name)
        for candidate, frame in pairs(areas) do
            frame:SetShown(candidate == name)
        end
        for candidate, button in pairs(tabButtons) do
            BIT.UI.TabSelected(button, candidate == name)
        end
    end
    local x = 6
    for _, name in ipairs({ "Marker", "Label", "Nameplates", "Prediction" }) do
        local frame = CreateFrame("Frame", nil, area)
        frame:SetPoint("TOPLEFT", area, "TOPLEFT", 0, -32)
        frame:SetSize(WINDOW_WIDTH - PREVIEW_WIDTH - 30, COL_HEIGHT - 36)
        frame:Hide()
        areas[name] = frame
        local button = CreateFrame("Button", nil, area, "PanelTopTabButtonTemplate")
        button:SetText(name)
        button.text = button:GetFontString()
        button:SetSize(button.text:GetStringWidth() + 20, 26)
        button.text:SetPoint("CENTER")
        BIT.UI.SkinTabButton(button, button.text)
        button:SetPoint("TOPLEFT", x, -6)
        x = x + button:GetWidth() + 2
        button:SetScript("OnClick", function() selectTab(name) end)
        tabButtons[name] = button
    end
    buildMarkerTab(areas.Marker)
    buildLabelTab(areas.Label)
    buildNameplateTab(areas.Nameplates)
    buildPredictionTab(areas.Prediction)
    selectTab("Marker")
    parent.castpredTabs = tabButtons
    parent.castpredAreas = areas
end

---------------------------------------------------------------------------------------------
-- The preview pane: mock target frame and nameplate, drawn by the real marker code
---------------------------------------------------------------------------------------------

local function buildPreview(pane)
    pane:SetSize(PREVIEW_WIDTH, COL_HEIGHT)
    BIT.UI.Backdrop(pane, 0.09)

    local title = pane:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", SIDE, -12)
    title:SetText("Live preview")
    local titleRule = pane:CreateTexture(nil, "ARTWORK")
    titleRule:SetColorTexture(unpack(BIT.UI.COLOR.divider))
    titleRule:SetHeight(1)
    titleRule:SetPoint("TOPLEFT", 8, -34)
    titleRule:SetPoint("TOPRIGHT", -8, -34)

    local scene = BIT.UI.Preview.Scene(pane, PREVIEW_WIDTH - 2 * SIDE, 216)
    scene:SetPoint("TOP", pane, "TOP", 0, -44)

    local mock = BIT.UI.Preview.TargetFrame(scene, { name = "Murloc Raider", level = "12", health = preview.health })
    mock.frame:SetPoint("TOP", scene, "TOP", 0, -6)
    pane.host = mock.host

    local plateMock = BIT.UI.Preview.Nameplate(scene, { name = "Murloc Raider", level = "12", health = preview.health })
    plateMock.frame:SetPoint("BOTTOM", scene, "BOTTOM", 0, 10)
    pane.plateHost = { plate = plateMock.frame, healthBar = plateMock.bar }

    -- While a fight is on, the marker is on the real target; the preview returns after combat.
    pane.combatNote = scene:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pane.combatNote:SetPoint("CENTER", scene, "CENTER")
    pane.combatNote:SetWidth(PREVIEW_WIDTH - 60)
    pane.combatNote:SetJustifyH("CENTER")
    pane.combatNote:SetText("In combat: the marker is on your target. The preview resumes after combat.")
    pane.combatNote:Hide()

    -- TRY IT: the preview's own numbers, never settings.
    local tryIt = pane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tryIt:SetPoint("TOPLEFT", scene, "BOTTOMLEFT", 4, -12)
    tryIt:SetText("TRY IT")
    tryIt:SetTextColor(1, 0.82, 0)

    local healthSlider = BIT.UI.Slider(pane, "Target health", 1, 100, 1,
        function() return preview.health end,
        function(value)
            preview.health = math.max(1, math.min(100, math.floor(value + 0.5)))
            updatePreview()
        end, "%%")
    healthSlider:SetPoint("TOPLEFT", tryIt, "BOTTOMLEFT", -6, -2)
    pane.healthSlider = healthSlider

    local spellRow = CreateFrame("Frame", nil, pane)
    spellRow:SetHeight(ROW_HEIGHT)
    spellRow:SetPoint("TOPLEFT", healthSlider, "BOTTOMLEFT", 6, -2)
    spellRow:SetPoint("RIGHT", pane, "RIGHT", -SIDE, 0)
    local spellLabel = spellRow:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    spellLabel:SetPoint("LEFT", 0, 0)
    spellLabel:SetText("Sample cast")
    pane.spellButton = BIT.UI.Button(spellRow, currentSpell().name, 150, function()
        preview.spell = preview.spell % #SAMPLE_SPELLS + 1
        updatePreview()
    end)
    pane.spellButton:SetPoint("RIGHT", spellRow, "RIGHT", 0, 0)

    local hint = pane:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", spellRow, "BOTTOMLEFT", 0, -10)
    hint:SetWidth(PREVIEW_WIDTH - 2 * SIDE)
    hint:SetJustifyH("LEFT")
    hint:SetText("The same marker the game shows, on mock frames. While this window is open out of "
        .. "combat the marker draws here; a fight hands it back to your target.")

    pane.title = title
    pane.hint = hint

    local sinceCheck = 0
    pane:SetScript("OnUpdate", function(self, elapsed)
        sinceCheck = sinceCheck + elapsed
        if sinceCheck < 0.25 then return end
        sinceCheck = 0
        syncDisplayHost()
    end)
end

-- The shared appearance pass the tab system runs on each rebuild.
local function renderPreview(sample, style)
    BIT.Style.ApplyText(sample.title, style, "text")
    BIT.Style.ApplyText(sample.label, style, "text")
end

---------------------------------------------------------------------------------------------
-- The tab
---------------------------------------------------------------------------------------------

if BIT.RegisterTab then
    BIT.RegisterTab("CastPrediction", {
        title = "Cast prediction",
        summary = "The damage the spell you are casting should deal, drawn on the target's health bar "
            .. "and nameplate. Channels show estimated damage remaining until the channel ends. "
            .. "Crits, procs and resists cannot be predicted.",
        width = WINDOW_WIDTH, height = WINDOW_HEIGHT,
        build = function(parent)
            if window == parent then return end
            window = parent
            controls = {}
            local note1 = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            note1:SetPoint("TOPLEFT", 12, -6)
            note1:SetPoint("RIGHT", -12, 0)
            note1:SetJustifyH("LEFT")
            note1:SetText("The marker shows what the description and your spell power give; hits seen in "
                .. "combat tune it. Crits, procs and resists stay unpredictable.")

            local pane = CreateFrame("Frame", nil, parent, "BackdropTemplate")
            pane:SetPoint("TOPLEFT", 10, -46)
            buildPreview(pane)
            panel = pane

            local area = CreateFrame("Frame", nil, parent, "BackdropTemplate")
            area:SetPoint("TOPLEFT", pane, "TOPRIGHT", 10, 0)
            area:SetSize(WINDOW_WIDTH - PREVIEW_WIDTH - 30, COL_HEIGHT)
            BIT.UI.Backdrop(area, 0.09)
            local divider = area:CreateTexture(nil, "ARTWORK")
            divider:SetColorTexture(unpack(BIT.UI.COLOR.divider))
            divider:SetHeight(1)
            divider:SetPoint("TOPLEFT", 8, -34)
            divider:SetPoint("TOPRIGHT", -8, -34)
            buildTabs(parent, area)

            refreshControls()
            updatePreview()
            syncDisplayHost()

            parent:SetScript("OnShow", function()
                updatePreview()
                syncDisplayHost()
            end)
            parent:SetScript("OnHide", function()
                -- The core keeps the built page and only hides it on a tab switch; the pane and the
                -- preview wiring must survive that, so only the display handover is released.
                hostsSet = false
                releasePreview()
            end)
        end,
        buildPreview = function(pane)
            -- The core's OFF-scene sample: a static line naming the module, no live numbers.
            local sample = CreateFrame("Frame", nil, pane)
            sample:SetSize(PREVIEW_WIDTH, 90)
            sample.title = sample:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            sample.title:SetPoint("TOPLEFT", 12, -8)
            sample.title:SetText("CastPrediction sample")
            sample.label = sample:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            sample.label:SetPoint("TOPLEFT", 12, -34)
            sample.label:SetText("Frostbolt 410-450 (estimate)")
            return sample
        end,
        previewRender = renderPreview,
        capabilities = { roles = { "text" }, shapes = false, geometry = false, border = false,
            font = true, scale = false, opacity = true },
    })
    BIT.tabWords.cast, BIT.tabWords.castpred = "CastPrediction", "CastPrediction"
end

if BIT.RegisterWaker then
    BIT.RegisterWaker("CastPrediction", function()
        ns.ensureDB()
    end)
end

ns.openOptions = function()
    if BIT.OpenSettings then BIT.OpenSettings("CastPrediction") end
end
