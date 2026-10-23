-- UsefulPlatesAndTooltips module DoTInfo: the focus frame. The damage marker (and optionally the kill icon) on
-- the focus frame's health bar, for your DoTs on the focused mob. From Does It Die v0.8.0's Focus.lua by Joe
-- Greive (MIT; based on toughnuts99's patch, issue #12), rebuilt on this module's nameplate widgets
-- (ns.barMarker): the look is the Nameplates tab's, the mode (focusMode) is the focus frame's own.
--
-- Tracking is per mob already (ns.dotBreakdownForUnit) and UNIT_COMBAT reports hits on the focus, so this is only
-- display. The same secret-value trick as the nameplates: StatusBars are fed the mob's hidden health and do the
-- comparing. The widgets hang off a frame of our own rather than the bar's parent: unit frame addons may put the
-- bar in a clipping frame, which would cut off a kill icon beside the bar. So they're hidden by hand whenever
-- there's no focus, the bar isn't visible or there are no DoTs, and pinned so the nameplate refresh leaves them
-- alone. Bar: EllesmereUI's focus frame, else Blizzard's (BIT.Plate.UnitFrame("focus")).

local ADDON_NAME, BIT = ...
-- UsefulPlatesAndTooltips's own namespace for the module, shared by its files.
local ns = BIT.Module("DoTInfo")

local UPDATE_INTERVAL = 0.2
local LAYER_CHECK_INTERVAL = 1
local MAX_LEVEL = 10000

local function isSecret(v)
    if type(issecretvalue) ~= "function" then return false end
    local ok, r = pcall(issecretvalue, v)
    return ok and r or false
end

local host = CreateFrame("Frame", nil, UIParent)
host:SetAllPoints(UIParent)
local widgets

-- The look the nameplates use, except the mode.
local focusLook = setmetatable({}, { __index = function(_, key)
    if key == "nameplateMode" then return ns.db.focusMode end
    return ns.db[key]
end })

local function hide()
    if widgets then ns.barMarker.hide(widgets) end
end

local function shown(bar)
    local ok, visible = pcall(bar.IsVisible, bar)
    return not ok or isSecret(visible) or visible ~= false
end

local function dead()
    local ok, isDead = pcall(UnitIsDeadOrGhost, "focus")
    return ok and not isSecret(isDead) and isDead == true
end

-- Highest strata/level anywhere in the focus frame: the bar's own level isn't enough, since Blizzard's focus frame
-- (like the target frame) has art layered far above its health bar, and can re-layer it any time.
local STRATA_RANK = {
    BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8,
}
local layerCheckedAt, layerBar, topStrata, topLevel = -math.huge, nil, nil, nil

local function topLayer(root)
    local bestStrata, bestLevel = "BACKGROUND", 0
    local function visit(frame, depth)
        -- Some of Blizzard's frames report a secret strata/level; those are skipped (their children aren't).
        local okS, strata = pcall(frame.GetFrameStrata, frame)
        local okL, level = pcall(frame.GetFrameLevel, frame)
        if okS and okL and not isSecret(strata) and not isSecret(level) and type(level) == "number" then
            local rank, bestRank = STRATA_RANK[strata] or 0, STRATA_RANK[bestStrata] or 0
            if rank > bestRank then
                bestStrata, bestLevel = strata, level
            elseif rank == bestRank and level > bestLevel then
                bestLevel = level
            end
        end
        if depth < 6 then
            local okC, children = pcall(function() return { frame:GetChildren() } end)
            if okC then
                for _, child in ipairs(children) do visit(child, depth + 1) end
            end
        end
    end
    visit(root, 0)
    return bestStrata, bestLevel
end

-- The frame that holds `bar`: its topmost ancestor below UIParent.
local function frameRoot(region)
    local current = region
    for _ = 1, 20 do
        local ok, parent = pcall(current.GetParent, current)
        if not ok or isSecret(parent) or type(parent) ~= "table" or parent == UIParent then return current end
        current = parent
    end
    return current
end

-- Keeps the widgets above everything on the frame that holds `bar` (looked at most once a second).
local function updateLayering(w, bar, now)
    if bar ~= layerBar or now - layerCheckedAt >= LAYER_CHECK_INTERVAL then
        layerCheckedAt, layerBar = now, bar
        local ok, strata, level = pcall(topLayer, frameRoot(bar))
        if ok and (strata ~= topStrata or level ~= topLevel) then
            topStrata, topLevel = strata, level
            if ns.trace then
                ns.trace(string.format("LAYER focus frame top is %s/%d; focus marker placed above it", strata, level))
            end
        end
    end
    if not topStrata then return end
    -- The nameplates' own placement (keepAbove) runs on every draw and only rewrites what it placed when the bar's
    -- level changed; follow it, so this runs again whenever it did.
    local signature = tostring(w.barLevel) .. "|" .. tostring(w.barStrata) .. "|" .. topStrata .. "|" .. topLevel
    if w.focusLayer == signature then return end
    w.focusLayer = signature
    w.marker:SetFrameStrata(topStrata)
    w.iconWindow:SetFrameStrata(topStrata)
    w.marker:SetFrameLevel(math.min(topLevel + 1, MAX_LEVEL - 3))
    w.iconWindow:SetFrameLevel(math.min(topLevel + 2, MAX_LEVEL - 2))
    w.iconBar:SetFrameLevel(math.min(topLevel + 3, MAX_LEVEL - 1))
end

local function refresh()
    local db = ns.db
    if not db or not ns.barMarker then return end
    if db.focusMode == "off" then return hide() end
    local okExists, exists = pcall(UnitExists, "focus")
    if not okExists or isSecret(exists) or not exists or dead() then return hide() end
    local _, bar = BIT.Plate.UnitFrame("focus")
    if type(bar) ~= "table" or not shown(bar) then return hide() end
    local entries, total = ns.dotBreakdownForUnit("focus")
    if total <= 0 then return hide() end
    widgets = ns.barMarker.widgetsFor(host, bar)
    widgets.pinned = true
    ns.barMarker.draw(widgets, entries, total, UnitHealthMax("focus"), UnitHealth("focus"), focusLook)
    updateLayering(widgets, bar, GetTime())
end

local driver = CreateFrame("Frame")
local sinceUpdate = 0
local reportedError = false
driver:SetScript("OnUpdate", function(self, elapsed)
    -- switched off in UsefulPlatesAndTooltips (Core.lua decides at ADDON_LOADED): stop for good
    if ns.off then self:SetScript("OnUpdate", nil) return end
    sinceUpdate = sinceUpdate + elapsed
    if sinceUpdate < UPDATE_INTERVAL then return end
    sinceUpdate = 0
    local ok, err = pcall(refresh)
    if not ok then
        pcall(hide)
        if not reportedError and ns.trace then
            reportedError = true
            ns.trace("ERROR in focus update: " .. tostring(err))
            ns.print("Focus display error (logged): " .. tostring(err))
        end
    end
end)
