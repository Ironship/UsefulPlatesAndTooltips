-- Regression check for the DoTInfo kill icon on nameplates/focus: a newly needed icon must never be revealed
-- in the frame its window is first shown (stale StatusBar fill flashed it on every DoT cast).
-- Run from the repository root: lua tools/check_dotinfo_kill_icon_flash.lua
local function region()
    local r = { shown = false, alpha = 1 }
    return setmetatable(r, { __index = function(_, k)
        if k == "Show" then return function(s) s.shown = true end end
        if k == "Hide" then return function(s) s.shown = false end end
        if k == "SetShown" then return function(s, v) s.shown = v and true or false end end
        if k == "SetAlpha" then return function(s, v) s.alpha = v end end
        if k == "GetStatusBarTexture" or k == "CreateTexture" then return function() return region() end end
        if k == "GetFrameLevel" then return function() return 5 end end
        return function() end
    end })
end
CreateFrame = function() return region() end
UIParent = region()

local ns = { lists = {}, findById = function() return {} end, colorOf = function() return 1, 1, 1, 1 end,
    dotColor = function() return { 1, 1, 1 } end, shielded = function() return false end }
local BIT = { Module = function() return ns end, Plate = { HealthBar = function() end,
    WidgetHost = function() return region() end } }
assert(loadfile("Modules/DoTInfo/Nameplates.lua"))("UsefulPlatesAndTooltips", BIT)

local api = ns.barMarker
local db = { showMarkers = true, nameplateMode = "markerIcon", plateDotColors = "single", nameplateIconSize = 55,
    nameplateIconPosition = "left", plateIconOffsetX = 0, plateIconOffsetY = 0 }
local w = api.widgetsFor(region(), region())
local entries = { { damage = 900, name = "Corruption" } }
local function visible() return w.iconWindow.shown and w.iconWindow.alpha > 0 end

assert(api.draw(w, entries, 900, 1000, 800, db, false, "nameplate1"))
assert(w.iconWindow.shown and not visible(), "first draw must lay out the icon window invisibly")
api.draw(w, entries, 900, 1000, 800, db, false, "nameplate1")
assert(visible(), "second draw reveals the icon")
api.hide(w)
api.draw(w, entries, 900, 1000, 800, db, false, "nameplate1")
assert(not visible(), "re-shown after hide: no flash on the first frame")
ns.shielded = function() return true end
api.draw(w, entries, 900, 1000, 800, db, false, "nameplate1")
assert(not w.iconWindow.shown, "a detected shield hides the icon")
ns.shielded = function() return false end
api.draw(w, entries, 900, 1000, 800, db, false, "nameplate1")
assert(not visible(), "after a shield-hide the next reveal is deferred too")
print("check_dotinfo_kill_icon_flash: ok")
