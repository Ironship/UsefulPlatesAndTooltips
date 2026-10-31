-- UsefulPlatesAndTooltips module HealPrediction: the incoming healing the client already knows,
-- drawn on Blizzard's unit frames -- target, party and raid -- as a segment that starts at the
-- health edge and reaches as far as the heal will (the classic heal-prediction look).
--
-- The number comes straight from the client (UnitGetIncomingHeals): on both clients this is the
-- native projection the raid frames themselves use, fed by the healer's own addon-visible casts
-- or by the game's own bookkeeping. This module never computes heals from spell descriptions and
-- never guesses: it only redraws what the client reports, and everything the client reports as a
-- secret value flows into StatusBar setters untouched, exactly like ShieldsInfo's absorb bars.
--
-- v1 draws the player's OWN incoming heals (UnitGetIncomingHeals(unit, "player")); the switch
-- "All healers" asks for the client's total (UnitGetIncomingHeals(unit)) instead, where the
-- client can tell. /upt healprobe prints what is readable right now.
local ADDON_NAME, BIT = ...
local ns = BIT.Module("HealPrediction")

local UPDATE_INTERVAL = 0.2

local DEFAULTS = {
    target = true,   -- the target frame
    player = false,  -- the player frame (your own frame rarely needs it)
    party = true,    -- classic and compact party frames
    raid = true,     -- raid frames (the compact container)
    allHealers = false, -- ask for the client's total instead of only your own heals
    fillColor = "green",
    fillOpacity = 55,
    showOthers = true,  -- the other healers' share, behind your own (needs the client to tell them apart)
    otherColor = "cyan",
    otherOpacity = 40,
    showHots = true,    -- your own heals over time, which the client's projection leaves out
    hotColor = "gold",
    hotOpacity = 40,
    hotHorizon = 4,     -- seconds of each heal over time drawn ahead
    heightPercent = 45, -- the segment's share of the bar's height, anchored to the top edge
    showText = false,   -- a small number at the segment's right end ("~120")
    debug = false,
}

local COLOR_PRESETS = {
    { id = "green",  label = "Green",  rgb = { 0.35, 1, 0.45 } },
    { id = "cyan",   label = "Cyan",   rgb = { 0.2, 0.9, 1 } },
    { id = "gold",   label = "Gold",   rgb = { 1, 0.85, 0.1 } },
    { id = "white",  label = "White",  rgb = { 1, 1, 1 } },
    { id = "purple", label = "Purple", rgb = { 0.7, 0.3, 1 } },
    { id = "black",  label = "Black",  rgb = { 0, 0, 0 } },
}
local COLOR_BY_ID = {}
for _, preset in ipairs(COLOR_PRESETS) do COLOR_BY_ID[preset.id] = preset.rgb end

local WHITE = "Interface\\Buttons\\WHITE8X8"

local settings
local function db() return settings end

local function print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ff99HealPrediction|r " .. msg)
end

local warned = false
local function trace(msg)
    if settings and settings.debug then print(msg) end
end

local function isSecret(v)
    if type(issecretvalue) ~= "function" then return false end
    local ok, r = pcall(issecretvalue, v)
    return ok and r or false
end

local function ask(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b = pcall(fn, ...)
    if not ok then return nil end
    return a, b
end

local function colorOf(id, opacityPercent)
    local rgb = COLOR_BY_ID[id] or COLOR_BY_ID.green
    return rgb[1], rgb[2], rgb[3], (tonumber(opacityPercent) or 100) / 100
end

---------------------------------------------------------------------------------------------
-- The reading
---------------------------------------------------------------------------------------------

-- What the client says is coming to this unit from the player (allHealers: from everyone the
-- client tracks). nil when the API is missing or refused; a secret value is a value and is
-- returned untouched -- it only ever reaches the setters.
local function readIncoming(unit, allHealers)
    if type(UnitGetIncomingHeals) ~= "function" then return nil end
    local ok, v
    if allHealers then
        ok, v = pcall(UnitGetIncomingHeals, unit)
    else
        ok, v = pcall(UnitGetIncomingHeals, unit, "player")
    end
    if not ok then return nil end
    return v
end
ns.ReadIncoming = readIncoming

---------------------------------------------------------------------------------------------
-- The overlay: a clipping frame at the health edge, and the segment inside it
---------------------------------------------------------------------------------------------

-- healthBar -> { clip = Frame, bar = StatusBar, label = FontString, unit = unit }
local overlays = setmetatable({}, { __mode = "k" })

local function hideOverlay(o)
    if not o then return end
    pcall(function()
        o.clip:Hide()
        if o.others then o.others.clip:Hide() end
        if o.hot then o.hot.clip:Hide() end
    end)
end

local function usableBar(frame)
    if type(frame) ~= "table" then return nil end
    local ok = pcall(function()
        if type(frame.IsForbidden) == "function" and frame:IsForbidden() then error("forbidden") end
    end)
    if not ok then return nil end
    return frame
end

-- The health bar's width, for the segment's own scale: the very same number the health bar
-- uses (the fill fraction is heal / maxHealth of the bar's whole width). A secret or missing
-- width falls back to 150, like DoTInfo's shine sweep does.
local function healthBarWidth(healthBar)
    local width = ask(healthBar.GetWidth, healthBar)
    if isSecret(width) or type(width) ~= "number" or width <= 0 or width == math.huge then return 150 end
    return width
end

local function healthBarHeight(healthBar)
    local height = ask(healthBar.GetHeight, healthBar)
    if isSecret(height) or type(height) ~= "number" or height <= 0 or height == math.huge then return 20 end
    return height
end

-- One band of the overlay: a clipping frame and the status bar inside it.
local function newLayer(healthBar, levelOffset, withLabel)
    local clip = CreateFrame("Frame", nil, healthBar)
    clip:SetClipsChildren(true)
    clip:SetFrameLevel((healthBar:GetFrameLevel() or 0) + levelOffset)
    local bar = CreateFrame("StatusBar", nil, clip)
    bar:SetStatusBarTexture(WHITE)
    -- The frame's own HealthBarMask keeps the segment inside the visible bar.
    if BIT.UI and BIT.UI.BarMask then BIT.UI.BarMask.Apply(bar:GetStatusBarTexture(), healthBar, true) end
    local layer = { clip = clip, bar = bar }
    if withLabel then
        layer.label = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        layer.label:SetPoint("LEFT", bar:GetStatusBarTexture(), "RIGHT", 2, 0)
    end
    clip:Hide()
    return layer
end

-- The overlay for one health bar, created once and reused: the other healers' band at the back, your own
-- direct heal over it, and your heals over time after the direct heal's end. Creation can run in combat,
-- where the client may refuse a child of a protected bar: the build is wrapped and nothing is
-- cached on failure, so the next tick retries.
local function overlayFor(healthBar)
    if type(healthBar) ~= "table" then return nil end
    if not usableBar(healthBar) then return nil end
    local o = overlays[healthBar]
    if o then return o end
    if ask(InCombatLockdown) == true and ask(healthBar.IsProtected, healthBar) == true then return nil end
    local ok, built = pcall(function()
        local others = newLayer(healthBar, 1, false)
        local own = newLayer(healthBar, 2, true)
        local hot = newLayer(healthBar, 3, false)
        return { clip = own.clip, bar = own.bar, label = own.label, others = others, hot = hot,
            unit = nil, height = nil, colors = nil }
    end)
    if not ok or type(built) ~= "table" then return nil end
    overlays[healthBar] = built
    return built
end

-- Anchors the clip at the health edge and the segment inside it, so the fill starts where the
-- green ends and is cropped at the bar's right end (overheal spills nowhere).
local function layoutOverlay(o, healthBar)
    local width = healthBarWidth(healthBar)
    local height = healthBarHeight(healthBar)
    local fraction = (tonumber(db().heightPercent) or 45) / 100
    local segmentHeight = math.max(2, math.floor(height * fraction + 0.5))
    local signature = width .. ":" .. height .. ":" .. segmentHeight
    local fill = ask(healthBar.GetStatusBarTexture, healthBar)
    if isSecret(fill) then fill = nil end
    local ownFill = ask(o.bar.GetStatusBarTexture, o.bar)
    if isSecret(ownFill) then ownFill = nil end
    if o.layoutSignature == signature and o.healthFill == fill and o.ownFill == ownFill then return end
    local hasFill = fill ~= nil and (type(fill) == "table" or type(fill) == "userdata")
    -- Secret-safe: the anchor is the health fill's moving right edge; no Lua math on it. Without a fill
    -- texture the band is drawn across the whole bar (a plain left-to-right band).
    local function anchorClip(clip, after)
        clip:ClearAllPoints()
        if after then
            clip:SetPoint("TOPLEFT", after, "TOPRIGHT")
            clip:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMRIGHT")
        else
            clip:SetAllPoints(healthBar)
        end
    end
    local function sizeBar(layer)
        layer.bar:ClearAllPoints()
        layer.bar:SetPoint("TOPLEFT", layer.clip, "TOPLEFT")
        layer.bar:SetPoint("BOTTOMLEFT", layer.clip, "BOTTOMLEFT")
        layer.bar:SetWidth(width)
        layer.bar:SetHeight(segmentHeight)
    end
    anchorClip(o.clip, hasFill and fill or nil)
    sizeBar(o)
    if o.others then
        anchorClip(o.others.clip, hasFill and fill or nil)
        sizeBar(o.others)
    end
    if o.hot then
        -- after the end of the direct heal: the own bar's fill reaches health + heal
        local after = (ownFill ~= nil and (type(ownFill) == "table" or type(ownFill) == "userdata")) and ownFill
            or (hasFill and fill or nil)
        anchorClip(o.hot.clip, after)
        sizeBar(o.hot)
    end
    o.layoutSignature, o.healthFill, o.ownFill = signature, fill, ownFill
end

local function paintLayer(layer, color, opacity)
    local r, g, b, a = colorOf(color, opacity)
    pcall(function()
        layer.bar:SetStatusBarColor(r, g, b, a)
        layer.bar:SetStatusBarTexture(WHITE)
    end)
end

local function paintOverlay(o)
    paintLayer(o, db().fillColor, db().fillOpacity)
    if o.others then paintLayer(o.others, db().otherColor, db().otherOpacity) end
    if o.hot then paintLayer(o.hot, db().hotColor, db().hotOpacity) end
end

-- Feeds one band: the value goes to the status bar untouched (it may be secret); a plain zero hides it.
local function setLayer(layer, maxHealth, value)
    if not layer then return end
    if value == nil or (not isSecret(value) and (type(value) ~= "number" or value <= 0)) then
        layer.clip:Hide()
        return
    end
    layer.bar:SetMinMaxValues(0, maxHealth)
    layer.bar:SetValue(value)
    layer.bar:Show()
    layer.clip:Show()
end

-- One unit's incoming heals on one health bar. Secret-safe: the reading (plain or secret) is
-- fed only into SetMinMaxValues/SetValue; only a proven-plain zero hides the segment.
local function updateBar(unit, healthBar, enabled)
    local o = type(healthBar) == "table" and overlays[healthBar] or nil
    if type(healthBar) ~= "table" or not enabled or isSecret(unit) or type(unit) ~= "string" then
        hideOverlay(o)
        return
    end
    if type(UnitIsDeadOrGhost) == "function" then
        local ok, dead = pcall(UnitIsDeadOrGhost, unit)
        if ok and not isSecret(dead) and dead == true then hideOverlay(o) return end
    end
    local incoming = readIncoming(unit, db().allHealers)
    local plainZero = incoming == nil or (not isSecret(incoming) and (type(incoming) ~= "number" or incoming <= 0))
    -- The other healers' share: the client's total behind your own band (when "All healers" already
    -- draws the total in your color there is nothing to add).
    local everyone
    if db().showOthers ~= false and not db().allHealers then
        everyone = readIncoming(unit, true)
        if everyone ~= nil and not isSecret(everyone) and (type(everyone) ~= "number" or everyone <= 0) then
            everyone = nil
        end
    end
    -- Where the client cannot tell the healers apart the two readings are equal: nothing of theirs to show.
    if everyone ~= nil and not isSecret(everyone) and not isSecret(incoming) and type(incoming) == "number"
        and everyone <= incoming then
        everyone = nil
    end
    local hot = ns.Hots and ns.Hots.AmountFor(unit, db().hotHorizon) or nil
    if plainZero and everyone == nil and hot == nil then hideOverlay(o) return end
    local maxHealth = ask(UnitHealthMax, unit)
    if maxHealth == nil then hideOverlay(o) return end
    if not o then
        o = overlayFor(healthBar)
        if not o then return end
    end
    o.unit = unit
    local ok, err = pcall(function()
        layoutOverlay(o, healthBar)
        paintOverlay(o)
        -- Your own band stays shown (empty) while a heal over time follows it, so that band has a fill
        -- edge to start from.
        if plainZero then
            o.bar:SetMinMaxValues(0, maxHealth)
            o.bar:SetValue(0)
            o.bar:Show()
            o.clip:Show()
        else
            setLayer(o, maxHealth, incoming)
        end
        setLayer(o.others, maxHealth, everyone)
        setLayer(o.hot, maxHealth, hot)
        local showLabel = db().showText and not plainZero and not isSecret(incoming)
        o.label:SetShown(showLabel and true or false)
        if showLabel then
            o.label:SetText(string.format("~%d", math.floor(incoming + 0.5)))
        end
    end)
    if not ok then
        o.layoutSignature = nil
        hideOverlay(o)
        if o.lastError ~= err then
            o.lastError = err
            trace("ERROR in display update: " .. tostring(err))
            print("Display error: " .. tostring(err))
        end
    end
end
ns.UpdateBar = updateBar

---------------------------------------------------------------------------------------------
-- Which frames to draw on (the same representations ShieldsInfo supports)
---------------------------------------------------------------------------------------------

local function playerBar()
    if BIT.Plate and BIT.Plate.UnitFrame then return select(2, BIT.Plate.UnitFrame("player")) end
    return type(_G.PlayerFrameHealthBar) == "table" and _G.PlayerFrameHealthBar or nil
end

local function targetBar()
    if BIT.Plate and BIT.Plate.UnitFrame then return select(2, BIT.Plate.UnitFrame("target")) end
    return type(_G.TargetFrameHealthBar) == "table" and _G.TargetFrameHealthBar or nil
end

local function memberUnit(frame)
    local unit = frame and frame.unit or ask(frame.GetAttribute, frame, "unit")
    if isSecret(unit) or type(unit) ~= "string" then return nil end
    if unit:match("^party%d+$") or unit:match("^raid%d+$") then return unit end
    return nil
end

local function collectMember(frame, bars)
    if type(frame) ~= "table" then return end
    local ok = pcall(function()
        if type(frame.IsForbidden) == "function" and frame:IsForbidden() then error("forbidden") end
    end)
    if not ok then return end
    local unit = memberUnit(frame)
    if not unit then return end
    local bar = frame.HealthBar or frame.healthBar
    if type(frame.HealthBarContainer) == "table" and type(frame.HealthBarContainer.HealthBar) == "table" then
        bar = frame.HealthBarContainer.HealthBar
    end
    if type(bar) ~= "table" then return end
    bars[#bars + 1] = { unit = unit, bar = bar }
end

local function poolFrames(pool, bars)
    if type(pool) ~= "table" then return end
    local members = pool.unitFrames or pool.activeFrames
    if type(members) == "table" then
        for _, frame in pairs(members) do
            local unit = memberUnit(frame)
            if unit then
                local bar = frame.HealthBar or frame.healthBar
                if type(bar) == "table" then bars[#bars + 1] = { unit = unit, bar = bar } end
            end
        end
    end
end

-- Classic party frames, the PartyFrame pool, the compact party/raid members and the EUI raid
-- members: one bar is listed once no matter how many owners report it.
local function groupBars()
    local bars = {}
    for i = 1, 4 do
        local g = _G["PartyMemberFrame" .. i]
        local bar = g and (g.HealthBar or g.healthBar)
        if type(bar) ~= "table" then bar = _G["PartyMemberFrame" .. i .. "HealthBar"] end
        if type(bar) == "table" then bars[#bars + 1] = { unit = "party" .. i, bar = bar } end
    end
    local pf = _G.PartyFrame
    if type(pf) == "table" then poolFrames(pf.PartyMemberFramePool, bars) end
    local cpf = _G.CompactPartyFrame
    if type(cpf) == "table" and type(cpf.memberUnitFrames) == "table" then
        for _, frame in pairs(cpf.memberUnitFrames) do collectMember(frame, bars) end
    end
    local crc = _G.CompactRaidFrameContainer
    if type(crc) == "table" then
        if type(crc.memberUnitFrames) == "table" then
            for _, frame in pairs(crc.memberUnitFrames) do collectMember(frame, bars) end
        else
            poolFrames(crc, bars)
        end
    end
    local modules = type(EllesmereUI) == "table" and EllesmereUI._ModuleNS
    local eui = type(modules) == "table" and modules.EllesmereUIRaidFrames
    local internals = type(eui) == "table" and eui._internals
    local function addMembers(members)
        if type(members) ~= "table" then return end
        for unit, frame in pairs(members) do
            if not isSecret(unit) and type(unit) == "string" and (unit == "player"
                or unit:match("^party%d+$") or unit:match("^raid%d+$")) then
                local data = ask(eui.GetFFD, frame)
                local current = type(frame) == "table" and ask(frame.GetAttribute, frame, "unit")
                if not isSecret(current) and current == unit and type(data) == "table" and type(data.health) == "table"
                    and ask(frame.IsVisible, frame) == true then
                    bars[#bars + 1] = { unit = unit, bar = data.health }
                end
            end
        end
    end
    addMembers(type(internals) == "table" and internals.unitToButton)
    addMembers(type(eui) == "table" and eui._partyUnitToButton)
    local seen, out = {}, {}
    for _, b in ipairs(bars) do
        if not seen[b.bar] then
            seen[b.bar] = true
            out[#out + 1] = b
        end
    end
    return out
end

local function updateAll()
    if not settings then return end
    local seen = {}
    local function update(unit, bar, enabled)
        if type(bar) == "table" then seen[bar] = true end
        updateBar(unit, bar, enabled)
    end
    update("player", playerBar(), settings.player)
    update("target", targetBar(), settings.target)
    if settings.party or settings.raid then
        for _, entry in ipairs(groupBars()) do
            local isRaid = entry.unit:match("^raid%d+$") ~= nil
            local wanted
            if isRaid then wanted = settings.raid else wanted = settings.party end
            update(entry.unit, entry.bar, wanted)
        end
    end
    -- Replaced primary bars and departed group bars must both leave the display.
    for healthBar, o in pairs(overlays) do
        if not seen[healthBar] then hideOverlay(o) end
    end
end
ns.UpdateAll = updateAll

---------------------------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------------------------

local UNIT_EVENTS = {
    UNIT_HEAL_PREDICTION = true,
    UNIT_HEALTH = true,
    UNIT_MAXHEALTH = true,
}

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
for event in pairs(UNIT_EVENTS) do frame:RegisterEvent(event) end

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON_NAME then return end
        if BIT.ShouldRun and not BIT.ShouldRun("HealPrediction") then
            ns.off = true
            self:UnregisterAllEvents()
            self:SetScript("OnUpdate", nil)
            return
        end
        settings = BIT.Settings("HealPrediction", DEFAULTS)
        ns.settings = settings
        updateAll()
        self:UnregisterEvent("ADDON_LOADED")
        return
    end
    if not settings then return end
    if UNIT_EVENTS[event] then
        -- The events fire for every unit and every change; one bounded pass on the tick keeps
        -- the group scans off the event path (a 40-man health tick storm stays cheap).
        return
    end
    -- PLAYER_ENTERING_WORLD / GROUP_ROSTER_UPDATE / PLAYER_TARGET_CHANGED
    updateAll()
end)

-- Periodic updates also advance HoTs and discover late or replaced frames.
local sinceUpdate = 0
frame:SetScript("OnUpdate", function(self, elapsed)
    if not settings then return end
    sinceUpdate = sinceUpdate + elapsed
    if sinceUpdate < UPDATE_INTERVAL then return end
    sinceUpdate = 0
    local ok, err = pcall(updateAll)
    if not ok and not warned then
        warned = true
        print("Update error (logged once): " .. tostring(err))
    end
end)

---------------------------------------------------------------------------------------------
-- The probe: what the client answers right now
---------------------------------------------------------------------------------------------

local function probeValue(v)
    if v == nil then return "nil" end
    if isSecret(v) then return "secret" end
    if type(v) == "number" then return tostring(math.floor(v + 0.5)) end
    return "unknown"
end

function ns.Probe()
    local lines = {}
    lines[#lines + 1] = "UnitGetIncomingHeals " .. (type(UnitGetIncomingHeals) == "function" and "present" or "missing")
        .. "; C_UnitAuras " .. (type(C_UnitAuras) == "table" and "present" or "missing")
    local function line(unit)
        if type(UnitExists) == "function" then
            local ok, exists = pcall(UnitExists, unit)
            if not ok or not exists then return end
        end
        lines[#lines + 1] = string.format("%s: own %s, all %s, maxHealth %s", unit,
            probeValue(readIncoming(unit, false)), probeValue(readIncoming(unit, true)),
            probeValue(ask(UnitHealthMax, unit)))
    end
    line("player")
    line("target")
    for i = 1, 40 do
        local unit = "raid" .. i
        if type(UnitExists) == "function" then
            local ok, exists = pcall(UnitExists, unit)
            if not ok or not exists then break end
            line(unit)
        else
            break
        end
    end
    for i = 1, 4 do line("party" .. i) end
    for _, text in ipairs(lines) do print(text) end
    return lines
end

if BIT.RegisterCommand then
    BIT.RegisterCommand("healprobe", function() ns.Probe() end)
end

-- The settings tab's sample: the very same overlay, on a mock bar, with plain numbers.
function ns.DrawSample(healthBar, maxHealth, heal, others, hot)
    if not settings then return false end
    local o = overlayFor(healthBar)
    if not o then return false end
    local ok = pcall(function()
        layoutOverlay(o, healthBar)
        paintOverlay(o)
        setLayer(o, maxHealth, heal)
        if not heal or heal <= 0 then
            o.bar:SetMinMaxValues(0, maxHealth)
            o.bar:SetValue(0)
            o.clip:Show()
        end
        setLayer(o.others, maxHealth, settings.showOthers ~= false and not settings.allHealers and others or nil)
        setLayer(o.hot, maxHealth, settings.showHots ~= false and hot or nil)
        o.label:SetShown((settings.showText and heal and heal > 0) and true or false)
        if settings.showText and heal and heal > 0 then o.label:SetText(string.format("~%d", math.floor(heal + 0.5))) end
    end)
    return ok
end

function ns.HideSample(healthBar)
    local o = overlays[healthBar]
    if o then hideOverlay(o) end
end

-- Shared with the options module.
ns._settings = function() return settings end
ns._updateAll = updateAll
ns.DEFAULTS = DEFAULTS

if BIT.RegisterWaker then
    BIT.RegisterWaker("HealPrediction", function()
        if not settings and type(BIT.Settings) == "function" then
            settings = BIT.Settings("HealPrediction", DEFAULTS)
            ns.settings = settings
        end
    end)
end
