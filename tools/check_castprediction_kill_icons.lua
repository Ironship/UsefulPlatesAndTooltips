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
    return killBar.max > 0 and killBar.value / killBar.max >= 1 - icon.width / killBar.width
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
assert(icon.width == 36 and icon.height == 36 and killWindow.width == 36 and killBar.height == 36,
    "target spell icons and their clipping window must be enlarged together")

draw(350)
assert(killWindow.shown and iconIsInLethalClip(), "lethal preview must reveal the kill icon")
assert(bar.value == 35 and plateBar.value == 35, "target and nameplate preview health must update together")
assert(killBar.max == 350 and killBar.value == 480, "kill threshold must use target HP and minimum damage")

settings.showKillSpellIcon = false
draw(350)
assert(icon.texture == "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8", "disabling spell icons must use the fallback")
assert(icon.width == settings.plateIconSize and killWindow.width == settings.plateIconSize,
    "generic fallback icons must retain their previous size")
settings.showKillSpellIcon = true
draw(350)
assert(icon.texture == "spell:686", "spell icon must replace the generic icon for a cast")
state.spellID = 2098
draw(350)
assert(icon.texture == "spell:2098", "changing the preview spell must update its icon")
assert(icon.width == 36, "Eviscerate must use the larger target spell icon")
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
assert(icon.width == 36 and killWindow.width == 36,
    "target spell icon size must be independent of nameplate and other frame sizing")

settings.showMarker = false
draw(350)
assert(killWindow.shown and iconIsInLethalClip(), "the kill icon must be independent of the damage marker")
settings.showKillIcon = false
draw(350)
assert(not killWindow.shown, "disabling the kill icon must hide it")

print("CastPrediction kill-icon visibility and spell-icon regression checks passed.")
