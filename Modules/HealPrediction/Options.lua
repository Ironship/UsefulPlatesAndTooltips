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

local function place(row, y, height)
    table.insert(controls, row)
    return BIT.UI.PlaceRow(row, y, height or ROW_HEIGHT)
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
        refreshControls()
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
    return row
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
    y = place(checkRow(parent, "Player frame", "player", "Your own frame, off by default."), y)
    y = place(checkRow(parent, "Party frames", "party",
        "Blizzard's classic party frames and the compact party members."), y)
    y = place(checkRow(parent, "Raid frames", "raid",
        "The compact raid members (CompactRaidFrameContainer), including the EllesmereUI raid members."), y)
    y = section(parent, y, "THE NUMBERS")
    y = place(checkRow(parent, "All healers", "allHealers",
        "Ask the client for its total incoming healing (every healer it tracks) instead of only your "
        .. "own. Where the client cannot tell the two apart, both read the same."), y)
    y = section(parent, y, "THE SEGMENT")
    y = place(choiceRow(parent, "Color", "fillColor", {
        { id = "green", label = "Green" }, { id = "cyan", label = "Cyan" }, { id = "gold", label = "Gold" },
        { id = "white", label = "White" }, { id = "purple", label = "Purple" }, { id = "black", label = "Black" },
    }, "The incoming-heal segment's own color; absorbs keep ShieldsInfo's look."), y)
    y = place(sliderRow(parent, "Opacity", "fillOpacity", 0, 100, 5, nil, nil), y, 40)
    y = place(sliderRow(parent, "Height", "heightPercent", 15, 100, 5, nil,
        "How tall the segment is against the health bar; the top edge is the anchor."), y, 40)
    y = place(checkRow(parent, "Show a number", "showText",
        "A small ~ number at the segment's right end, when the client gives a readable amount."), y)
    y = section(parent, y, "DIAGNOSTICS")
    y = place(buttonRow(parent, "What the client says", "Print", function()
        ns.Probe()
    end, "Prints UnitGetIncomingHeals for you and your group to chat, and the same to the log."), y)
    y = place(checkRow(parent, "Debug lines in chat", "debug",
        "Echo the module's notes while it reads and draws."), y)
    y = noteRow(parent, y, "The number is the client's own incoming-heal projection "
        .. "(UnitGetIncomingHeals) - the same one Blizzard's raid frames use. This module only "
        .. "redraws it: no heal math, no crit guesses, no addon messages. WoW: Forever may hide "
        .. "some values in combat; a hidden value draws nothing rather than a guess. /upt healprobe "
        .. "prints what is readable.")
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
    title:SetText("Live preview")
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

    local state = { health = 60, heal = 25 }
    local function redraw()
        mock.bar:SetValue(state.health)
        if mock.healthPercent then mock.healthPercent:SetText(string.format("%d%%", state.health)) end
        ns.DrawSample(mock.bar, 100, state.heal)
    end

    -- The two sliders are the sample's own numbers, never settings.
    local healthSlider = BIT.UI.Slider(pane, "Health", 1, 100, 1,
        function() return state.health end,
        function(value)
            state.health = math.max(1, math.min(100, math.floor(value + 0.5)))
            redraw()
        end, function(value) return math.floor(value + 0.5) .. "%" end)
    healthSlider:SetPoint("TOPLEFT", scene, "BOTTOMLEFT", 0, -14)
    local healSlider = BIT.UI.Slider(pane, "Incoming heal", 0, 100, 1,
        function() return state.heal end,
        function(value)
            state.heal = math.max(0, math.min(100, math.floor(value + 0.5)))
            redraw()
        end)
    healSlider:SetPoint("TOPLEFT", healthSlider, "BOTTOMLEFT", 0, -6)

    local hint = pane:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", healSlider, "BOTTOMLEFT", 6, -12)
    hint:SetWidth(PREVIEW_WIDTH - 2 * SIDE)
    hint:SetJustifyH("LEFT")
    hint:SetText("The same segment the game draws, starting at the health edge (the green bar's "
        .. "end) and cropping at the bar's right end when the heal would overheal.")

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
        summary = "Incoming healing, drawn where the target's, party's and raid's health ends "
            .. "(the client's own projection; nothing is computed here).",
        width = WINDOW_WIDTH, height = WINDOW_HEIGHT,
        build = function(parent)
            if window == parent then return end
            window = parent
            controls = {}
            local note1 = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            note1:SetPoint("TOPLEFT", 12, -6)
            note1:SetPoint("RIGHT", -12, 0)
            note1:SetJustifyH("LEFT")
            note1:SetText("The client already knows how much healing is coming (UnitGetIncomingHeals). "
                .. "This module redraws that number on Blizzard's frames instead of calculating it.")
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
            column:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT", -6, 8)
            column:Fit((buildSettings(column.content) or 0) + 12)
            refreshControls()
            if ns._updateAll then ns._updateAll() end
        end,
        buildPreview = function(pane)
            local sample = CreateFrame("Frame", nil, pane)
            sample:SetSize(PREVIEW_WIDTH, 90)
            sample.title = sample:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            sample.title:SetPoint("TOPLEFT", 12, -8)
            sample.title:SetText("HealPrediction sample")
            sample.label = sample:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            sample.label:SetPoint("TOPLEFT", 12, -34)
            sample.label:SetText("+25 incoming, from the health edge")
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
