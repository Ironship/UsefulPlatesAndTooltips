-- UsefulPlatesAndTooltips module HealPrediction: the settings tab (/upt heals) with a live
-- sample. The segment the module draws is built on a mock party bar with plain numbers, so what
-- is tuned here is exactly what the game shows.
local _, BIT = ...

local ns = BIT.Module("HealPrediction")

local WINDOW_WIDTH, WINDOW_HEIGHT = 840, 500
local PREVIEW_WIDTH = 290
local COL_HEIGHT = 440
local ROW_HEIGHT = 26
local SIDE = 12

local window
local controls = {}
local panel

local function db() return ns._settings() end

local function refreshControls()
    for _, control in ipairs(controls) do
        if control.Refresh then control:Refresh() end
    end
end

local function changed()
    refreshControls()
    if panel then panel:Refresh() end
    if ns._updateAll then ns._updateAll() end
end

---------------------------------------------------------------------------------------------
-- Row builders (the same shapes the other modules' tabs use)
---------------------------------------------------------------------------------------------

local tabKeys -- the settings keys the tab builds, for its "Reset this tab"
local function note(key)
    if tabKeys and key then tabKeys[#tabKeys + 1] = key end
end

-- The rows are the shared ones (Core/LookRows.lua), the same widgets, geometry and wording in every module.
local function place(row, y, height)
    table.insert(controls, row)
    return BIT.UI.PlaceRow(row, y, row.standard and row:GetHeight() or height or ROW_HEIGHT)
end

local function checkRow(parent, labelText, key, tooltip)
    note(key)
    return BIT.Looks.Rows.Check(parent, labelText, function() return db()[key] end, function(value)
        db()[key] = value
        changed()
    end, { tooltip = tooltip, settings = db })
end

local function sliderRow(parent, labelText, key, min, max, step, format, tooltip)
    note(key)
    local opts = { tooltip = tooltip, settings = db }
    if type(format) == "function" then opts.display = format elseif key:find("Opacity$") or key == "heightPercent" then opts.suffix = "%" end
    return BIT.Looks.Rows.Slider(parent, labelText, min, max, step, function() return db()[key] end, function(value)
        db()[key] = value
        changed()
    end, opts)
end

local function choiceRow(parent, labelText, key, list, tooltip)
    note(key)
    return BIT.Looks.Rows.Choice(parent, labelText, list, function() return db()[key] end, function(id)
        db()[key] = id
        changed()
    end, { tooltip = tooltip, settings = db })
end

local function buttonRow(parent, labelText, buttonText, onClick, tooltip)
    return BIT.Looks.Rows.Button(parent, labelText, buttonText, function()
        onClick()
        refreshControls()
    end, { tooltip = tooltip, settings = db })
end

-- A section header, with room above it once there is something above it.
local function section(parent, y, text)
    if y > 0 then y = y + 8 end
    return place(BIT.UI.Header(parent, text), y, 28)
end

-- A wrapped note; the next row starts below its measured height.
local NOTE_WIDTH = 470
local function noteRow(parent, y, text)
    local row = BIT.UI.Note(parent, text, NOTE_WIDTH)
    return place(row, y + 4, row:GetHeight() + 10)
end

---------------------------------------------------------------------------------------------
-- The right column
---------------------------------------------------------------------------------------------

local function buildSettings(parent)
    local y = section(parent, 0, "FRAMES")
    y = place(checkRow(parent, "Target frame", "target",
        "The segment starts where the target's green ends and reaches as far as the incoming heal will."), y)
    y = place(checkRow(parent, "Player frame", "player", "Your own health bar."), y)
    y = place(checkRow(parent, "Focus frame", "focus", "Incoming heals and your HoTs on your focus."), y)
    y = place(checkRow(parent, "Target of target frame", "targettarget",
        "Blizzard's small target-of-target health bar, including when it shows you."), y)
    y = place(checkRow(parent, "Party frames", "party",
        "Blizzard's classic party frames and the compact party members."), y)
    y = place(checkRow(parent, "Raid frames", "raid",
        "The compact raid members (CompactRaidFrameContainer), including the EllesmereUI raid members."), y)
    y = section(parent, y, "THE NUMBERS")
    y = place(checkRow(parent, "All healers", "allHealers",
        "Ask the client for its total incoming healing (every healer it tracks) instead of only your "
        .. "own. Where the client cannot tell the two apart, both read the same."), y)
    y = place(checkRow(parent, "Other healers' share", "showOthers",
        "A second band behind yours for the part of the client's total that is not yours. Where the client "
        .. "cannot tell healers apart the band simply stays hidden."), y)
    y = place(checkRow(parent, "My heals over time", "showHots",
        "Rejuvenation, Renew, Regrowth and Riptide are not part of the client's projection. After you cast one, "
        .. "the amount its description promises is drawn after your direct heal for the next few seconds of "
        .. "the effect. Refreshing another rank replaces the old estimate. Wild Growth uses a linear estimate on "
        .. "readable buff recipients or its known primary cast target, not guessed party recipients. Channels, pet heals and triggered heals are "
        .. "not treated as target HoTs. Readable own buffs recover existing effects and removals; "
        .. "when aura data is hidden, the last known expiry is used."), y)
    y = place(sliderRow(parent, "Heal over time horizon", "hotHorizon", 1, 15, 1,
        function(value) return math.floor(value + 0.5) .. " s" end,
        "How many seconds of each heal over time are drawn ahead."), y, 40)
    y = section(parent, y, "THE SEGMENT")
    y = place(choiceRow(parent, "Fill style", "fillTexture", BIT.Looks.Textures(),
        "The fill of the incoming-heal segment: patterns, glass and bevel shadings, Blizzard's bar textures and every "
        .. "LibSharedMedia texture; the color tints them."), y)
    y = place(choiceRow(parent, "Fill color", "fillColor", BIT.Looks.ColorList(),
        "The incoming-heal segment's own color, or Custom color... for any you like; absorbs keep ShieldsInfo's look."), y)
    y = place(sliderRow(parent, "Fill opacity", "fillOpacity", 0, 100, 5, nil, nil), y, 40)
    y = place(choiceRow(parent, "Other healers' fill style", "otherTexture", BIT.Looks.Textures(), nil), y)
    y = place(choiceRow(parent, "Other healers' fill color", "otherColor", BIT.Looks.ColorList(), nil), y)
    y = place(sliderRow(parent, "Other healers' fill opacity", "otherOpacity", 0, 100, 5, nil, nil), y)
    y = place(choiceRow(parent, "Heal over time fill style", "hotTexture", BIT.Looks.Textures(), nil), y)
    y = place(choiceRow(parent, "Heal over time fill color", "hotColor", BIT.Looks.ColorList(), nil), y)
    y = place(sliderRow(parent, "Heal over time fill opacity", "hotOpacity", 0, 100, 5, nil, nil), y)
    y = place(sliderRow(parent, "Height", "heightPercent", 15, 100, 5, nil,
        "How tall the segment is against the health bar; the top edge is the anchor."), y, 40)
    y = place(checkRow(parent, "Show a number", "showText",
        "A small ~ number for the direct heal plus your HoT horizon at the segment's right end, "
        .. "when the amounts are readable."), y)
    y = section(parent, y, "DIAGNOSTICS")
    y = place(buttonRow(parent, "What the client says", "Print", function()
        ns.Probe()
    end, "Prints UnitGetIncomingHeals for you and your group to chat, and the same to the log."), y)
    y = place(checkRow(parent, "Debug lines in chat", "debug",
        "Echo the module's notes while it reads and draws."), y)
    y = noteRow(parent, y, "The number is the client's own incoming-heal projection "
        .. "(UnitGetIncomingHeals) - the same one Blizzard's raid frames use. This module only "
        .. "redraws direct heals; your own targeted HoTs are separate estimates from readable descriptions "
        .. "and spell power, independent of SpellDamageInfo's display settings. No crit guesses or addon "
        .. "messages. Hidden native values go unchanged to the bars. /upt healprobe prints what is readable.")
    return y
end

---------------------------------------------------------------------------------------------
-- The preview pane
---------------------------------------------------------------------------------------------

local function buildPreview(pane)
    pane:SetSize(PREVIEW_WIDTH, COL_HEIGHT)
    BIT.UI.Backdrop(pane, 0.09)

    local title = pane:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", SIDE, -12)
    title:SetText(BIT.L("Live preview"))
    local rule = pane:CreateTexture(nil, "ARTWORK")
    rule:SetColorTexture(unpack(BIT.UI.COLOR.divider))
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", 8, -34)
    rule:SetPoint("TOPRIGHT", -8, -34)

    -- The same Murloc target frame the other tabs preview on, with the module's own segment
    -- drawn from the health edge exactly as it is on the real frame.
    local scene = BIT.UI.Preview.Scene(pane, PREVIEW_WIDTH - 2 * SIDE, 122)
    scene:SetPoint("TOP", pane, "TOP", 0, -44)

    local mock = BIT.UI.Preview.TargetFrame(scene, { name = "Murloc Raider", level = "12", health = 60 })
    mock.frame:SetPoint("CENTER", scene, "CENTER", 0, 0)
    mock.bar:SetMinMaxValues(0, 100)
    mock.bar:SetValue(60)

    local state = { health = 60, heal = 25, others = 12 }
    local sampleHotTotal, sampleHotDuration = 30, 12
    local function redraw()
        mock.bar:SetValue(state.health)
        if mock.healthPercent then mock.healthPercent:SetText(string.format("%d%%", state.health)) end
        local horizon = tonumber(db().hotHorizon) or 4
        local hot = sampleHotTotal * math.min(horizon, sampleHotDuration) / sampleHotDuration
        ns.DrawSample(mock.bar, 100, state.heal, state.heal + state.others, hot)
    end

    -- The two sliders are the sample's own numbers, never settings.
    local tryIt = BIT.Looks.TryItHeader(pane, scene)
    local healthSlider = BIT.Looks.PreviewSlider(pane, "Health", 1, 100,
        function() return state.health end,
        function(value)
            state.health = math.max(1, math.min(100, math.floor(value + 0.5)))
            redraw()
        end)
    healthSlider:SetPoint("TOPLEFT", tryIt, "BOTTOMLEFT", -4, -4)
    local healSlider = BIT.Looks.PreviewSlider(pane, "Incoming heal", 0, 100,
        function() return state.heal end,
        function(value)
            state.heal = math.max(0, math.min(100, math.floor(value + 0.5)))
            redraw()
        end)
    healSlider:SetPoint("TOPLEFT", healthSlider, "BOTTOMLEFT", 0, 0)

    local hint = pane:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", healSlider, "BOTTOMLEFT", 6, -12)
    hint:SetWidth(PREVIEW_WIDTH - 2 * SIDE)
    hint:SetJustifyH("LEFT")
    hint:SetText(BIT.L("The Target frame option controls this sample; the other frame options control live frames. "
        .. "The segment starts at the health edge (the green bar's "
        .. "end) and is cropped at the bar's right end when the heal would overheal."))

    pane.title = title
    pane.hint = hint
    pane.healthSlider = healthSlider
    pane.healSlider = healSlider
    pane.Refresh = redraw
    redraw()
end

local function renderPreview(sample, style)
    BIT.Style.ApplyText(sample.title, style, "text")
    BIT.Style.ApplyText(sample.label, style, "text")
end

---------------------------------------------------------------------------------------------
-- The tab
---------------------------------------------------------------------------------------------

if BIT.RegisterTab then
    BIT.RegisterTab("HealPrediction", {
        title = "Heal prediction",
        summary = "Incoming healing on player, target, focus, target-of-target, party and raid frames "
            .. "(native direct heals and estimates for your own HoTs).",
        width = WINDOW_WIDTH, height = WINDOW_HEIGHT,
        build = function(parent)
            if window == parent then return end
            window = parent
            controls = {}
            local note1 = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            note1:SetPoint("TOPLEFT", 12, -6)
            note1:SetPoint("RIGHT", -12, 0)
            note1:SetJustifyH("LEFT")
            note1:SetText(BIT.L("The client already knows how much healing is coming (UnitGetIncomingHeals). "
                .. "This module redraws direct heals and adds estimates for your own heals over time."))
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
            local column = BIT.UI.ScrollColumn(area)
            column:SetPoint("TOPLEFT", area, "TOPLEFT", 6, -42)
            column:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT", -6, 40)
            tabKeys = {}
            column:Fit((buildSettings(column.content) or 0) + 12)
            local keys = tabKeys
            tabKeys = nil
            -- "Reset this tab": the same button, in the same place, as every other module.
            local reset = BIT.Looks.ResetButton(area, function()
                for _, key in ipairs(keys) do db()[key] = ns._defaults()[key] end
                changed()
            end)
            reset:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT", -10, 10)
            refreshControls()
            if ns._updateAll then ns._updateAll() end
        end,
        buildPreview = function(pane)
            local sample = CreateFrame("Frame", nil, pane)
            sample:SetSize(PREVIEW_WIDTH, 90)
            sample.title = sample:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            sample.title:SetPoint("TOPLEFT", 12, -8)
            sample.title:SetText(BIT.L("HealPrediction sample"))
            sample.label = sample:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            sample.label:SetPoint("TOPLEFT", 12, -34)
            sample.label:SetText(BIT.L("+25 incoming, from the health edge"))
            return sample
        end,
        previewRender = renderPreview,
        capabilities = { roles = { "text" }, shapes = false, geometry = false, border = false,
            font = true, scale = false, opacity = true },
    })
    BIT.tabWords.heals, BIT.tabWords.heal = "HealPrediction", "HealPrediction"
end

ns.openOptions = function()
    if BIT.OpenSettings then BIT.OpenSettings("HealPrediction") end
end
