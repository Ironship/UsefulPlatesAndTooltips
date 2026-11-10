local frames, named, textures = {}, {}, {}
local unpackValues = unpack or table.unpack

local function widget(parent)
    local w = { parent = parent, children = {}, width = 126, height = 20, shown = true }
    if parent then parent.children[#parent.children + 1] = w end
    local methods = {
        SetPoint = function() end,
        ClearAllPoints = function() end,
        SetSize = function(self, width, height) self.width, self.height = width, height end,
        SetWidth = function(self, width) self.width = width end,
        SetHeight = function(self, height) self.height = height end,
        SetAllPoints = function(self, other)
            if other then self.width, self.height = other.width, other.height end
        end,
        GetWidth = function(self) return self.width end,
        GetHeight = function(self) return self.height end,
        GetParent = function(self) return self.parent end,
        GetChildren = function(self) return unpackValues(self.children) end,
        GetName = function(self) return self.name end,
        GetFrameStrata = function(self) return self.strata or "MEDIUM" end,
        SetFrameStrata = function(self, value) self.strata = value end,
        GetFrameLevel = function(self) return self.level or 1 end,
        SetFrameLevel = function(self, value) self.level = value end,
        IsForbidden = function() return false end,
        SetShown = function(self, value) self.shown = value end,
        SetAlpha = function(self, value) self.alpha = value end,
        Show = function(self) self.shown = true end,
        Hide = function(self) self.shown = false end,
        SetTexture = function(self, value) self.texture = value; textures[#textures + 1] = self end,
        SetStatusBarTexture = function(self, value) self.texture = value end,
        GetStatusBarTexture = function(self)
            if not self.statusTexture then self.statusTexture = widget(self) end
            return self.statusTexture
        end,
        SetMinMaxValues = function(self, min, max) self.min, self.max = min, max end,
        SetValue = function(self, value) self.value = value end,
        SetScript = function(self, event, callback) self.scripts[event] = callback end,
        CreateAnimationGroup = function(self) return widget(self) end,
        CreateAnimation = function(self) return widget(self) end,
        CreateTexture = function(self)
            local child = widget(self)
            child.SetColorTexture = function() end
            return child
        end,
        CreateFontString = function(self) return widget(self) end,
    }
    w.scripts = {}
    return setmetatable(w, { __index = function(_, key)
        if methods[key] then return methods[key] end
        if type(key) == "string" and key:match("^[A-Z]") then return function() end end
    end })
end

UIParent = widget()
CreateFrame = function(_, name, parent)
    local frame = widget(parent or UIParent)
    frame.name = name
    frames[#frames + 1] = frame
    if name then named[name] = frame end
    return frame
end
issecretvalue = function() return false end
GetTime = function() return 1 end
wipe = function(t) for key in pairs(t) do t[key] = nil end end
C_Timer = { After = function() end }
C_Spell = { GetSpellTexture = function(id) return "spell:" .. id end }
UnitExists = function() return false end
UnitCanAttack = function() return false end
UnitIsDeadOrGhost = function() return false end
UnitHealth = function() return 0 end
UnitHealthMax = function() return 0 end
GameFontNormalSmall = { GetFont = function() return "font", 10 end }
STANDARD_TEXT_FONT = "font"
SlashCmdList = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, text) io.stderr:write(text, "\n") end }

local ns = {}
local BIT = {
    modules = {},
    Looks = {
        Palette = {},
        Rgb = function() return { 1, 1, 1 } end,
        Texture = function() return nil end,
    },
    Plate = {
        WidgetHost = function(plate) return plate end,
    },
    UI = { BarMask = { Apply = function() end, RefreshTexture = function() end } },
}
BIT.Module = function() return ns end
local settingsCore = {}
assert(loadfile("Core/Init.lua"))("UsefulPlatesAndTooltips", settingsCore)
BIT.Settings = settingsCore.Settings

assert(loadfile("Modules/CastPrediction/Core.lua"))("UsefulPlatesAndTooltips", BIT)
local settings = ns.ensureDB()
assert(settings.showKillSpellIcon == true, "new settings must enable killing spell icons")
UsefulPlatesAndTooltipsDB.modules.CastPrediction = { showKillSpellIcon = false }
settings = ns.ensureDB()
assert(settings.showKillSpellIcon == true, "legacy false must migrate to the new default once")
settings.showKillSpellIcon = false
settings = ns.ensureDB()
assert(settings.showKillSpellIcon == false, "a manual choice after migration must survive reload")
settings.showKillSpellIcon = true
local bar, portrait = widget(UIParent), widget(UIParent)
ns.setDisplayHost({ healthBar = bar, portrait = portrait, layerFrame = bar })
local plate, plateBar = widget(UIParent), widget(UIParent)
ns.setPlatePreview({ plate = plate, healthBar = plateBar })

local state = {
    name = "Shadow Bolt", spellID = 686, min = 480, max = 540, value = 510,
    school = "shadow", health = 350, maxHealth = 1000,
}
local killWindow = assert(named.UsefulPlatesAndTooltips_CastPredictionKill)
local killBar, icon = killWindow.children[1], killWindow.children[1].children[1]
local function draw(health)
    state.health = health
    ns.setPreviewState(state)
    ns._refresh()
end
local function iconIsInLethalClip()
    local fill = math.max(0, math.min(1, killBar.value / killBar.max))
    return killBar.alpha == 1 and fill >= 1 - icon.width / killBar.width
end
local function hasTexture(path)
    for _, texture in ipairs(textures) do
        if texture.texture == path then return true end
    end
    return false
end

draw(700)
assert(killWindow.shown and not iconIsInLethalClip(), "nonlethal preview must clip the kill icon")
assert(bar.value == 70 and plateBar.value == 70, "preview health bars must follow the selected health")
assert(icon.texture == "spell:686", "the default must use the killing spell icon")
assert(icon.width == settings.killIconSize and icon.height == settings.killIconSize
    and killWindow.width == settings.killIconSize and killBar.height == settings.killIconSize,
    "target spell icons and their clipping window must be enlarged together")

draw(350)
assert(killWindow.shown and iconIsInLethalClip(), "lethal preview must reveal the kill icon")
assert(bar.value == 35 and plateBar.value == 35, "target and nameplate preview health must update together")
assert(killBar.max == 350 and killBar.value == 480, "kill threshold must use target HP and minimum damage")

settings.showKillSpellIcon = false
draw(350)
assert(icon.texture == "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8", "disabling spell icons must use the fallback")
assert(icon.width == settings.killIconSize and killWindow.width == settings.killIconSize,
    "generic fallback icons must use the configured target size")
settings.showKillSpellIcon = true
draw(350)
assert(icon.texture == "spell:686", "spell icon must replace the generic icon for a cast")
state.spellID = 2098
draw(350)
assert(icon.texture == "spell:2098", "changing the preview spell must update its icon")
assert(icon.width == settings.killIconSize, "Eviscerate must use the configured target spell icon size")
state.preview = true
draw(350)
assert(hasTexture("Interface\\AddOns\\UsefulPlatesAndTooltips\\Modules\\DoTInfo\\Textures\\DashV4"),
    "finisher preview must use the finisher fill")
state.spellID, state.min = 22568, 520
draw(350)
assert(icon.texture == "spell:22568" and iconIsInLethalClip(),
    "Ferocious Bite preview must update to its lethal spell icon")
settings.plateIconSize = 22
draw(350)
assert(icon.width == settings.killIconSize and killWindow.width == settings.killIconSize,
    "target spell icon size must be independent of nameplate and other frame sizing")

settings.showMarker = false
draw(350)
assert(killWindow.shown and iconIsInLethalClip(), "the kill icon must be independent of the damage marker")
settings.showKillIcon = false
draw(350)
assert(not killWindow.shown, "disabling the kill icon must hide it")

settings.showKillIcon, settings.showMarker, settings.nameplateMode = true, true, "markerIcon"
settings.killIconSize = 48
state.preview, state.spellID, state.min, state.value = false, 686, 480, 510
draw(700)
assert(icon.width == 48 and killWindow.width == 48 and killBar.height == 48,
    "changing target icon size must resize its icon, window and clipping bar")
local plateWindow, plateIconBar, plateIcon
for _, frame in ipairs(frames) do
    if frame.parent == plate then
        for _, child in ipairs(frame.children) do
            if child.width == 10000 then
                assert(not plateWindow, "nameplates must not contain a second ungated impact bar")
                plateWindow, plateIconBar, plateIcon = frame, child, child.children[1]
            end
        end
    end
end
assert(plateWindow and plateIcon.texture == "spell:686")
local function plateIconVisible()
    local fill = math.max(0, math.min(1, plateIconBar.value / plateIconBar.max))
    return plateWindow.shown and plateIconBar.shown
        and plateIconBar.alpha == 1 and fill >= 1 - plateIcon.width / plateIconBar.width
end
assert(not plateIconVisible(), "nonlethal prediction must clip every nameplate kill icon")
draw(500)
assert(not plateIconVisible(), "average damage alone must not reveal a nameplate kill icon")
settings.killIconSize, settings.plateIconSize = 128, 128
draw(480.001)
assert(not iconIsInLethalClip() and not plateIconVisible(),
    "even the largest icons must be completely hidden just below lethal")
assert(killBar.alpha == 0 and plateIconBar.alpha == 0,
    "clipping must not expose any portion of a nonlethal icon")
draw(480)
assert(iconIsInLethalClip() and plateIconVisible(),
    "minimum damage exactly equal to health must reveal the complete icons")
assert(killBar.alpha == 1 and plateIconBar.alpha == 1)
settings.killIconSize, settings.plateIconSize = 48, 22
draw(350)
assert(plateIconVisible(), "lethal minimum damage must reveal the spell icon")
settings.showKillSpellIcon, settings.killIcon = false, "impact"
draw(700)
assert(plateIcon.texture ~= "spell:686" and not plateIconVisible(),
    "fallback impact must obey the same nonlethal clipping threshold")
draw(480)
assert(plateIconVisible(), "fallback impact must appear at the lethal threshold")
settings.showKillIcon = false
draw(350)
assert(not plateWindow.shown and not plateIconVisible(),
    "disabling kill icons must hide both spell and impact icons")
settings.showKillIcon, settings.showKillSpellIcon = true, true
draw(350)
assert(plateIconVisible() and plateIcon.texture == "spell:686")
settings.plateIconSize = 30
draw(350)
assert(plateIcon.width == 30 and plateWindow.width == 30 and icon.width == 48,
    "nameplate and target icon sizes must remain independently configurable")
settings.showMarker = false
draw(350)
assert(not plateWindow.shown, "nameplate icons must respect the existing marker switch")

local function findUpvalue(fn, wanted, seen)
    seen = seen or {}
    if seen[fn] then return end
    seen[fn] = true
    for i = 1, math.huge do
        local name, value = debug.getupvalue(fn, i)
        if not name then break end
        if name == wanted then return value end
        if type(value) == "function" then
            local found = findUpvalue(value, wanted, seen)
            if found then return found end
        end
    end
end
local drawMarker = assert(findUpvalue(ns._refresh, "drawMarker"))
local drawPlate = assert(findUpvalue(ns._refresh, "drawPlate"))
local plateWidgets = assert(findUpvalue(ns._refresh, "widgetsByPlate"))[plate]
local secretHealth = setmetatable({}, {
    __lt = function() error("secret health compared") end,
    __le = function() error("secret health compared") end,
})
issecretvalue = function(value) return value == secretHealth end
settings.showMarker, settings.showKillIcon = true, true
assert(drawMarker(510, 1000, secretHealth, state))
assert(killBar.max == secretHealth and killBar.alpha == 1 and killWindow.shown,
    "secret health must pass raw to the native bar and retain its clipping indicator")
assert(drawPlate(plateWidgets, 510, 1000, secretHealth, state))
assert(plateIconBar.max == secretHealth and plateIconBar.alpha == 1 and plateWindow.shown,
    "secret health must retain the nameplate's native clipping indicator")
assert(plateWidgets.marker.shown and plateWidgets.marker.value == 510,
    "secret health must not interrupt the damage marker")
issecretvalue = function() return false end
draw(480.001)
assert(killBar.alpha == 0, "readable health must restore exact gating after secret health")
draw(480)
assert(killBar.alpha == 1, "readable lethal equality must restore the complete icon")

print("CastPrediction kill-icon visibility and spell-icon regression checks passed.")
