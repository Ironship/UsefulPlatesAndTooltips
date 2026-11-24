-- UsefulPlatesAndTooltips module HealPrediction: the settings tab (/upt heals) with a live
-- sample. The segment the module draws is built on a mock party bar with plain numbers, so what
-- is tuned here is exactly what the game shows.
local _, BIT = ...

local ns = BIT.Module("HealPrediction")

local WINDOW_WIDTH, WINDOW_HEIGHT = 840, 560
local PREVIEW_WIDTH = 290
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

-- A setting as the rows show it: a key the saved settings lack yet (a new option) shows its default, which is also what
-- the module acts on, instead of an unchecked box next to a feature that is running.
local function value(key)
    local v = db()[key]
    if v == nil and ns._defaults then v = ns._defaults()[key] end
    return v
end

-- Rows that only mean something while another switch is in a state: they dim otherwise, by setting key. The client's
-- total (All healers) leaves no room for the other healers' band, and the heal-over-time rows need the HoT overlay.
local function othersOn() return not value("allHealers") and value("showOthers") ~= false end
local function hotsOn() return value("showHots") ~= false end
local WHEN = {
    showOthers = function() return not value("allHealers") end,
    otherTexture = othersOn, otherColor = othersOn, otherOpacity = othersOn,
    hotWhole = hotsOn, hotTexture = hotsOn, hotColor = hotsOn, hotOpacity = hotsOn,
}

local function checkRow(parent, labelText, key, tooltip)
    note(key)
    return BIT.Looks.Rows.Check(parent, labelText, function() return value(key) end, function(value)
        db()[key] = value
        changed()
    end, { tooltip = tooltip, settings = db, enabledIf = WHEN[key] })
end

local function sliderRow(parent, labelText, key, min, max, step, format, tooltip, enabledIf)
    note(key)
    local opts = { tooltip = tooltip, settings = db, enabledIf = enabledIf or WHEN[key] }
    if type(format) == "function" then opts.display = format elseif key:find("Opacity$") or key == "heightPercent" then opts.suffix = "%" end
    return BIT.Looks.Rows.Slider(parent, labelText, min, max, step, function() return value(key) end, function(value)
        db()[key] = value
        changed()
    end, opts)
end

local function choiceRow(parent, labelText, key, list, tooltip)
    note(key)
    return BIT.Looks.Rows.Choice(parent, labelText, list, function() return value(key) end, function(id)
        db()[key] = id
        changed()
    end, { tooltip = tooltip, settings = db, enabledIf = WHEN[key] })
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
    local y = section(parent, 0, "SHOW ON")
    y = place(checkRow(parent, "Show on player frame", "player", "Your own health bar."), y)
    y = place(checkRow(parent, "Show on target frame", "target",
        "The segment starts where the target's green ends and reaches as far as the incoming heal will."), y)
    y = place(checkRow(parent, "Show on focus frame", "focus", "Incoming heals and your HoTs on your focus."), y)
    y = place(checkRow(parent, "Show on target of target frame", "targettarget",
        "Blizzard's small target-of-target health bar, including when it shows you."), y)
    y = place(checkRow(parent, "Show on party frames", "party",
        "Blizzard's classic party frames and the compact party members."), y)
    y = place(checkRow(parent, "Show on raid frames", "raid",
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
        .. "the amount its description promises is drawn after your direct heal for the whole remaining effect, "
        .. "or only for the horizon below when that is switched off. Refreshing another rank replaces the old estimate. Wild Growth uses a linear estimate on "
        .. "readable buff recipients or its known primary cast target, not guessed party recipients. Channels, pet heals and triggered heals are "
        .. "not treated as target HoTs. Readable own buffs recover existing effects and removals; "
        .. "when aura data is hidden, the last known expiry is used."), y)
    y = place(checkRow(parent, "Whole remaining effect", "hotWhole",
        "Draw all the healing each of your heals over time still has to do, to its end, instead of only its next "
        .. "few seconds. A fresh Rejuvenation shows its full total, which runs down as the ticks land. The number shows the same total."), y)
    y = place(checkRow(parent, "Food on my frame", "showFood",
        "While you eat, the health the food still has to give is drawn on your own health bar, like a heal over time "
        .. "(food is an item's effect, not a heal you cast). A potion works at once and has nothing to show."), y)
    y = place(checkRow(parent, "Drinks on my mana bar", "showDrink",
        "While you drink, the mana the drink still has to give is drawn on your own mana bar, from the end of your "
        .. "current mana."), y)
    y = place(sliderRow(parent, "Heal over time horizon", "hotHorizon", 1, 15, 1,
        function(value) return math.floor(value + 0.5) .. " s" end,
        "How many seconds of each heal over time are drawn ahead. Used only when Whole remaining effect is off.",
        function() return hotsOn() and value("hotWhole") == false end), y, 40)
    y = section(parent, y, "THE SEGMENT")
    y = place(choiceRow(parent, "Fill style", "fillTexture", BIT.Looks.Textures(),
        "The fill of the incoming-heal segment: patterns, glass and bevel shadings, Blizzard's bar textures and every "
        .. "LibSharedMedia texture; the color tints them."), y)
    y = place(choiceRow(parent, "Fill color", "fillColor", BIT.Looks.ColorList(),
        "The incoming-heal segment's own color, or Custom color... for any you like; absorbs keep ShieldsInfo's look."), y)
    y = place(sliderRow(parent, "Fill opacity", "fillOpacity", 0, 100, 5, nil, nil), y, 40)
    y = place(choiceRow(parent, "Other healers' fill style", "otherTexture", BIT.Looks.Textures(),
        "The fill style of the band for the healing other healers have coming."), y)
    y = place(choiceRow(parent, "Other healers' fill color", "otherColor", BIT.Looks.ColorList(),
        "The color of the band for the healing other healers have coming."), y)
    y = place(sliderRow(parent, "Other healers' fill opacity", "otherOpacity", 0, 100, 5, nil,
        "How strongly the band for other healers' healing covers the bar."), y)
    y = place(choiceRow(parent, "Heal over time fill style", "hotTexture", BIT.Looks.Textures(),
        "The fill style of the segment for your heals over time."), y)
    y = place(choiceRow(parent, "Heal over time fill color", "hotColor", BIT.Looks.ColorList(),
        "The color of the segment for your heals over time."), y)
    y = place(sliderRow(parent, "Heal over time fill opacity", "hotOpacity", 0, 100, 5, nil,
        "How strongly the segment for your heals over time covers the bar."), y)
    y = place(sliderRow(parent, "Height", "heightPercent", 15, 100, 5, nil,
        "How tall the segment is against the health bar; the top edge is the anchor."), y, 40)
    y = place(checkRow(parent, "Show a number", "showText",
        "A small ~ number for the direct heal plus your heals over time at the segment's right end, "
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
    BIT.UI.Backdrop(pane, 0.09)

    local title = BIT.UI.PreviewHeader(pane, "Live preview", SIDE)

    -- The same Murloc target frame the other tabs preview on, with the module's own segment
    -- drawn from the health edge exactly as it is on the real frame.
    local scene = BIT.UI.Preview.Scene(pane, PREVIEW_WIDTH - 2 * SIDE, 122)
    scene:SetPoint("TOP", pane, "TOP", 0, -44)

    -- The frame the sample sits on: target, player or party, each with its own "Show on" switch.
    local kits = {
        target = BIT.UI.Preview.TargetFrame(scene, { name = "Murloc Raider", level = "12", health = 45 }),
        player = BIT.UI.Preview.PlayerFrame(scene, { name = "You", health = 45 }),
        party = BIT.UI.Preview.PartyBar(scene, { name = "Kaya", width = 190, health = 45 }),
    }
    local FRAMES = { { id = "target", label = "Target" }, { id = "player", label = "Player" }, { id = "party", label = "Party" } }
    local which = "target"
    local mock = kits.target
    for id, kit in pairs(kits) do
        kit.frame:SetPoint("CENTER", scene, "CENTER", 0, 0)
        kit.bar:SetMinMaxValues(0, 100)
        kit.bar:SetValue(45)
        kit.frame:SetShown(id == which)
    end

    local TARGET_MAX_HEALTH, PLAYER_MAX_HEALTH = 142, 100
    local FRAME_HINT = {
        target = "Show on target frame",
        player = "Show on player frame",
        party = "Show on party frames",
    }
    local state = { health = 45, heal = 20, others = 10 }
    local sampleHotTotal, sampleHotDuration = 30, 12

    local statusBar = CreateFrame("Frame", nil, pane, "BackdropTemplate")
    statusBar:SetPoint("TOPLEFT", scene, "BOTTOMLEFT", 0, -8)
    statusBar:SetPoint("TOPRIGHT", scene, "BOTTOMRIGHT", 0, -8)
    statusBar:SetHeight(22)
    BIT.UI.Backdrop(statusBar, 0.06)
    local statusText = statusBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusText:SetPoint("LEFT", statusBar, "LEFT", 8, 0)
    statusText:SetPoint("RIGHT", statusBar, "RIGHT", -8, 0)
    statusText:SetJustifyH("CENTER")
    statusBar.text = statusText

    local hint
    local function hexOf(colorId)
        local r, g, b = 0.4, 1, 0.4
        if ns.ColorOf then r, g, b = ns.ColorOf(colorId, 100) end
        return string.format("|cff%02x%02x%02x",
            math.max(0, math.min(255, math.floor((r or 1) * 255 + 0.5))),
            math.max(0, math.min(255, math.floor((g or 1) * 255 + 0.5))),
            math.max(0, math.min(255, math.floor((b or 1) * 255 + 0.5))))
    end

    local function updateStatus(hot)
        local s = db()
        if s[which] == false then
            statusText:SetText("|cff888888" .. string.format(BIT.L("Hidden (%s is off)"), BIT.L(FRAME_HINT[which] or FRAME_HINT.target)) .. "|r")
            return
        end
        if state.simPhase then
            statusText:SetText("|cffffd24d" .. state.simPhase .. "|r")
            return
        end
        local parts = {}
        if s.allHealers then
            local all = (state.heal or 0) + (state.others or 0)
            if all > 0 then
                parts[#parts + 1] = hexOf(s.fillColor) .. BIT.L("All") .. " +" .. math.floor(all + 0.5) .. "%|r"
            end
        else
            if (state.heal or 0) > 0 then
                parts[#parts + 1] = hexOf(s.fillColor) .. BIT.L("Own") .. " +" .. math.floor(state.heal + 0.5) .. "%|r"
            end
            if s.showOthers ~= false and (state.others or 0) > 0 then
                parts[#parts + 1] = hexOf(s.otherColor) .. BIT.L("Others") .. " +" .. math.floor(state.others + 0.5) .. "%|r"
            end
        end
        if s.showHots ~= false and hot and hot > 0 then
            parts[#parts + 1] = hexOf(s.hotColor) .. BIT.L("HoT") .. " +" .. math.floor(hot + 0.5) .. "%|r"
        end
        if #parts == 0 then
            statusText:SetText("|cff888888" .. BIT.L("No incoming heal") .. "|r")
        else
            statusText:SetText(table.concat(parts, "  |cff666666/|r  "))
        end
    end

    local function updateHint()
        if not hint then return end
        local opt = BIT.L(FRAME_HINT[which] or FRAME_HINT.target)
        hint:SetText(string.format(BIT.L("The %s option controls this sample; the other Show on options control live frames. "
            .. "The segment starts at the health edge (the green bar's end) and is cropped at the bar's right end when the heal would overheal."), opt))
    end

    local function redraw()
        mock.bar:SetValue(state.health)
        if mock.healthPercent then mock.healthPercent:SetText(string.format("%d%%", math.floor(state.health + 0.5))) end
        if mock.healthValue then
            local maxHp = which == "player" and PLAYER_MAX_HEALTH or TARGET_MAX_HEALTH
            mock.healthValue:SetText(tostring(math.floor(maxHp * state.health / 100 + 0.5)))
        end
        local horizon = ns.HotHorizon and ns.HotHorizon() or tonumber(db().hotHorizon) or 4
        -- hotRemaining: seconds of the sample HoT left (the Simulate scene runs it down; otherwise it is fresh)
        local hot = sampleHotTotal * math.min(horizon, state.hotRemaining or sampleHotDuration) / sampleHotDuration
        ns.DrawSample(mock.bar, 100, state.heal, state.heal + state.others, hot, which)
        updateStatus(hot)
        updateHint()
    end

    -- FRAME: which mock carries the sample (the same switch and header as ShieldsInfo's preview).
    local whichFrame = BIT.Looks.TryItHeader(pane, statusBar, 0, -10, "FRAME")
    local switch = CreateFrame("Frame", nil, pane)
    switch:SetSize(PREVIEW_WIDTH - 2 * SIDE, 22)
    switch:SetPoint("TOPLEFT", whichFrame, "BOTTOMLEFT", 0, -4)
    local switchButtons = {}
    local left = 0
    for _, entry in ipairs(FRAMES) do
        local label = BIT.L(entry.label)
        local button = BIT.UI.Button(switch, label, 66, function()
            if which == entry.id then return end
            if ns.HideSample then ns.HideSample(mock.bar) end
            kits[which].frame:Hide()
            which, mock = entry.id, kits[entry.id]
            mock.frame:Show()
            for id, b in pairs(switchButtons) do b:SetAlpha(id == which and 1 or 0.55) end
            redraw()
        end)
        local fs = button.GetFontString and button:GetFontString()
        local w = math.max(66, math.ceil(fs and fs.GetStringWidth and fs:GetStringWidth() or 0) + 18)
        button:SetSize(w, 20)
        button:SetPoint("TOPLEFT", switch, "TOPLEFT", left, 0)
        button:SetAlpha(entry.id == which and 1 or 0.55)
        switchButtons[entry.id] = button
        left = left + w + 4
    end

    -- The two sliders are the sample's own numbers, never settings.
    local saved, sim
    local tryIt = BIT.Looks.TryItHeader(pane, switch)
    local healthSlider = BIT.Looks.PreviewSlider(pane, "Health", 1, 100,
        function() return state.health end,
        function(value)
            state.health = math.max(1, math.min(100, math.floor(value + 0.5)))
            if state.simulating and sim and sim.Stop then
                if saved then state.heal, state.others = saved.heal, saved.others end
                saved = nil
                sim.Stop()
                return
            end
            redraw()
        end)
    healthSlider:SetPoint("TOPLEFT", tryIt, "BOTTOMLEFT", -6, -4)
    local healSlider = BIT.Looks.PreviewSlider(pane, "Incoming heal", 0, 100,
        function() return state.heal end,
        function(value)
            state.heal = math.max(0, math.min(100, math.floor(value + 0.5)))
            if state.simulating and sim and sim.Stop then
                if saved then state.health, state.others = saved.health, saved.others end
                saved = nil
                sim.Stop()
                return
            end
            redraw()
        end)
    healSlider:SetPoint("TOPLEFT", healthSlider, "BOTTOMLEFT", 0, 0)

    -- SIMULATE: wounded target -> direct heal cast -> another healer joins -> heals land -> HoT ticks to full.
    sim = BIT.Looks.Simulate(pane, healSlider, {
        x = 6, y = -10, length = 9.6,
        text = "A direct heal is cast, another healer joins, both land, and a heal over time ticks the target to full.",
        start = function()
            saved = { health = state.health, heal = state.heal, others = state.others }
            state.simulating = true
        end,
        frame = function(t)
            if t < 0.4 then
                state.health, state.heal, state.others, state.hotRemaining = 40, 0, 0, 0
                state.simPhase = BIT.L("Wounded (40% HP)")
            elseif t < 1.4 then
                state.health, state.heal, state.others, state.hotRemaining = 40, 20, 0, 0
                state.simPhase = BIT.L("Casting direct heal (+20%)")
            elseif t < 2.8 then
                state.health, state.heal, state.others, state.hotRemaining = 40, 20, 10, 0
                state.simPhase = BIT.L("Other healer joins (+10%)")
            else
                local since = t - 2.8
                local ticks = math.min(4, math.floor(since / 1.5))
                state.heal, state.others = 0, 0
                state.health = math.min(100, math.floor(70 + ticks * 7.5 + 0.5))
                state.hotRemaining = math.max(0, sampleHotDuration - ticks * 3)
                state.simPhase = ticks >= 4 and BIT.L("Full health")
                    or string.format(BIT.L("Heal landed - HoT tick %d/4"), ticks)
            end
            redraw()
            if healthSlider.Refresh then healthSlider:Refresh() end
            if healSlider.Refresh then healSlider:Refresh() end
        end,
        finish = function()
            state.simulating = false
            state.simPhase = nil
            state.hotRemaining = nil
            if saved then
                state.health, state.heal, state.others = saved.health, saved.heal, saved.others
                saved = nil
            end
            redraw()
            if healthSlider.Refresh then healthSlider:Refresh() end
            if healSlider.Refresh then healSlider:Refresh() end
        end,
    })
    pane.simulate = sim

    hint = BIT.UI.PreviewHint(pane, "The Show on target frame option controls this sample; the other Show on options control live frames. "
        .. "The segment starts at the health edge (the green bar's "
        .. "end) and is cropped at the bar's right end when the heal would overheal.", SIDE)

    pane.title = title
    pane.hint = hint
    pane.statusBar = statusBar
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
            BIT.UI.TabSummary(parent, BIT.L("The client already knows how much healing is coming (UnitGetIncomingHeals). "
                .. "This module redraws direct heals and adds estimates for your own heals over time."))
            local pane = CreateFrame("Frame", nil, parent, "BackdropTemplate")
            pane:SetPoint("TOPLEFT", 10, -(BIT.UI.TAB_TOP or 44))
            pane:SetPoint("BOTTOMLEFT", 10, 10)
            pane:SetWidth(PREVIEW_WIDTH)
            buildPreview(pane)
            panel = pane
            local area = CreateFrame("Frame", nil, parent, "BackdropTemplate")
            area:SetPoint("TOPLEFT", pane, "TOPRIGHT", 10, 0)
            area:SetPoint("BOTTOMRIGHT", -10, 10)
            BIT.UI.Backdrop(area, 0.09)
            BIT.UI.PreviewHeader(area, "Settings", 12)
            local column = BIT.UI.ScrollColumn(area)
            column:SetPoint("TOPLEFT", area, "TOPLEFT", 6, -40)
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
