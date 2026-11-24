-- Regression test for DaylightUI + DoTInfo compatibility:
--   1) ADDON_LOADED LIFO ordering sets _G.DoesItDie before PLAYER_LOGIN (and never overwrites standalone / disabled)
--   2) Core/Integrations/DaylightUI.lua reads UnitFrames / Nameplates dot settings and supports plate.unitToken
--   3) Nameplates.lua hides marker/skull, zeros nameplateDamageBase, and zeros gated-twin plan damage on daylightTint
--   4) RogueAuras.lua disables native and gated containers on target and nameplates when daylightTint is active
--   5) Core.lua hides remainingBar / flash / nativePoisonBase / skullWindow while leaving options preview unaffected
-- Run from repository root: lua tools/check_daylight_dot_integration.lua

local unpackValues = unpack or table.unpack

local frames = {}
local namedFrames = {}
local auraContainers = {}
local clock = 100

local function advanceTime(dt)
    clock = clock + dt
end

local function makeWidget(frameType, name, parent, template)
    local w = {
        objectType = frameType or "Frame",
        name = name,
        parent = parent,
        template = template,
        children = {},
        regions = {},
        animGroups = {},
        scripts = {},
        events = {},
        unitEvents = {},
        shown = (frameType ~= "AuraContainer"),
        visible = true,
        alpha = 1,
        width = 140,
        height = 18,
        scale = 1,
        strata = "MEDIUM",
        level = 2,
        min = 0,
        max = 100,
        value = 0,
        reverse = false,
        playCount = 0,
    }
    if parent and type(parent.children) == "table"
        and frameType ~= "Texture" and frameType ~= "FontString"
        and frameType ~= "AnimationGroup" and frameType ~= "Animation"
        and frameType ~= "Alpha" and frameType ~= "Translation" and frameType ~= "Scale" then
        parent.children[#parent.children + 1] = w
    end

    local methods = {
        GetObjectType = function(self) return self.objectType end,
        IsForbidden = function() return false end,
        IsProtected = function() return false end,
        Show = function(self) self.shown = true end,
        Hide = function(self) self.shown = false end,
        SetShown = function(self, v) self.shown = v and true or false end,
        IsShown = function(self) return self.shown == true end,
        IsVisible = function(self)
            local cur = self
            while type(cur) == "table" do
                if cur.shown == false or cur.visible == false then return false end
                cur = cur.parent
            end
            return true
        end,
        SetAlpha = function(self, v) self.alpha = v end,
        GetAlpha = function(self) return self.alpha end,
        GetEffectiveAlpha = function(self) return self.alpha end,
        SetPoint = function() end,
        GetPoint = function() return "CENTER", parent, "CENTER", 0, 0 end,
        ClearAllPoints = function() end,
        SetAllPoints = function(self, other)
            if type(other) == "table" then self.width, self.height = other.width, other.height end
        end,
        SetSize = function(self, width, height) self.width, self.height = width, height end,
        GetSize = function(self) return self.width, self.height end,
        SetWidth = function(self, width) self.width = width end,
        GetWidth = function(self) return self.width end,
        SetHeight = function(self, height) self.height = height end,
        GetHeight = function(self) return self.height end,
        GetLeft = function() return 100 end,
        GetRight = function(self) return 100 + self.width end,
        GetTop = function(self) return 100 + self.height end,
        GetBottom = function() return 100 end,
        SetScale = function(self, s) self.scale = s end,
        GetScale = function(self) return self.scale end,
        GetEffectiveScale = function(self) return self.scale end,
        IsIgnoringParentScale = function() return false end,
        SetParent = function(self, newParent) self.parent = newParent end,
        GetParent = function(self) return self.parent end,
        GetChildren = function(self) return unpackValues(self.children) end,
        GetRegions = function(self) return unpackValues(self.regions) end,
        GetName = function(self) return self.name end,
        GetDebugName = function(self) return self.name or self.objectType end,
        SetFrameStrata = function(self, s) self.strata = s end,
        GetFrameStrata = function(self) return self.strata end,
        SetFrameLevel = function(self, l) self.level = l end,
        GetFrameLevel = function(self) return self.level end,
        SetClipsChildren = function(self, v) self.clipsChildren = v and true or false end,
        DoesClipChildren = function(self) return self.clipsChildren == true end,
        RegisterEvent = function(self, ev) self.events[ev] = true end,
        RegisterUnitEvent = function(self, ev, unit) self.unitEvents[ev] = unit end,
        UnregisterEvent = function(self, ev) self.events[ev] = nil; self.unitEvents[ev] = nil end,
        UnregisterAllEvents = function(self) self.events = {}; self.unitEvents = {} end,
        SetScript = function(self, kind, fn) self.scripts[kind] = fn end,
        GetScript = function(self, kind) return self.scripts[kind] end,
        HookScript = function(self, kind, fn)
            local prev = self.scripts[kind]
            self.scripts[kind] = function(...)
                if prev then prev(...) end
                fn(...)
            end
        end,
        SetStatusBarTexture = function(self, tex)
            self.texture = tex
            if not self.statusTexture then self.statusTexture = makeWidget("Texture", nil, self) end
        end,
        GetStatusBarTexture = function(self)
            if not self.statusTexture then self.statusTexture = makeWidget("Texture", nil, self) end
            return self.statusTexture
        end,
        SetStatusBarColor = function() end,
        SetMinMaxValues = function(self, minV, maxV) self.min, self.max = minV, maxV end,
        GetMinMaxValues = function(self) return self.min, self.max end,
        SetValue = function(self, v) self.value = v end,
        GetValue = function(self) return self.value end,
        SetReverseFill = function(self, v) self.reverse = v and true or false end,
        GetReverseFill = function(self) return self.reverse end,
        CreateTexture = function(self)
            local tex = makeWidget("Texture", nil, self)
            tex.SetColorTexture = function() end
            tex.SetTexture = function(s, path) s.texture = path end
            tex.GetTexture = function(s) return s.texture end
            tex.SetVertexColor = function(s, r, g, b, a) s.color = { r, g, b, a } end
            tex.GetVertexColor = function(s)
                local c = s.color or { 1, 1, 1, 1 }
                return c[1], c[2], c[3], c[4]
            end
            self.regions[#self.regions + 1] = tex
            return tex
        end,
        CreateFontString = function(self)
            local fs = makeWidget("FontString", nil, self)
            fs.SetText = function(s, text) s.text = text end
            fs.GetFont = function() return "font", 10 end
            self.regions[#self.regions + 1] = fs
            return fs
        end,
        CreateAnimationGroup = function(self)
            local ag = makeWidget("AnimationGroup", nil, self)
            ag.Play = function(s) s.playCount = s.playCount + 1; s.playing = true end
            ag.Stop = function(s) s.playing = false end
            ag.CreateAnimation = function(s, animType)
                return makeWidget(animType or "Animation", nil, s)
            end
            self.animGroups[#self.animGroups + 1] = ag
            return ag
        end,
        -- AuraContainer (WoW: Forever native aura segments)
        AddAuraSlot = function(self, slot, filter, opts)
            self.slot = slot
            if opts and type(opts.initializeFrame) == "function" then
                local button = makeWidget("Button", nil, self)
                self.slotButton = button
                opts.initializeFrame(button)
            end
        end,
        SetUnit = function(self, unit) self.unit = unit end,
        SetEnabled = function(self, v) self.enabled = v and true or false end,
        UpdateAllAuras = function(self) self.updatedAt = clock end,
    }

    return setmetatable(w, {
        __index = function(_, key)
            if methods[key] then return methods[key] end
            if type(key) == "string" and key:match("^[A-Z]") then return function() end end
        end,
    })
end

UIParent = makeWidget("Frame", "UIParent")
CreateFrame = function(frameType, name, parent, template)
    local f = makeWidget(frameType, name, parent or UIParent, template)
    frames[#frames + 1] = f
    if name then namedFrames[name] = f end
    if frameType == "AuraContainer" then auraContainers[#auraContainers + 1] = f end
    return f
end

issecretvalue = function() return false end
GetTime = function() return clock end
time = function() return 1700000000 end
wipe = function(t) for k in pairs(t) do t[k] = nil end end
unpack = unpack or table.unpack
strlower = string.lower
strtrim = function(s) return (tostring(s or ""):match("^%s*(.-)%s*$")) end
CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end
GetLocale = function() return "enUS" end
GetBuildInfo = function() return "1.15.0", "70790", "Nov 1 2026", 11500 end
GameFontNormalSmall = { GetFont = function() return "font", 10 end }
STANDARD_TEXT_FONT = "font"
SlashCmdList = {}
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
hooksecurefunc = function() end
C_Timer = { After = function() end }
InCombatLockdown = function() return false end
UnitAffectingCombat = function() return false end
GetModifiedClick = function() return "NONE" end
IsModifiedClick = function() return false end
C_CVar = { GetCVarBool = function() return false end, GetCVar = function() return "1" end }
Enum = {
    PowerType = { ComboPoints = 4 },
    DurationTextBindingProperty = { RemainingPercent = 1 },
    StatusBarTimerDirection = { RemainingTime = 0 },
    SpellBookSpellBank = { Player = 0 },
}
C_StringUtil = { CreateNumericRuleFormatter = function() return { SetBreakpoints = function() end } end }
C_XMLUtil = { GetTemplateInfo = function(name) return name == "CustomAuraContainerTemplate" and {} or nil end }
C_AddOns = { IsAddOnLoaded = function() return true end, GetAddOnMetadata = function() return "1.0.0" end }
C_UnitAuras = { GetBuffDataByIndex = function() return nil end, GetPlayerAuraBySpellID = function() return nil end }

local SPELLS = {
    [172] = { name = "Corruption", desc = "Corrupts the target, causing 108 Shadow damage over 18 sec." },
    [18288] = { name = "Amplify Curse", desc = "Increases the effect of your next curse." },
    [980] = { name = "Bane of Agony", desc = "Causes 72 Shadow damage over 24 sec." },
}
C_Spell = {
    GetSpellName = function(id) return SPELLS[id] and SPELLS[id].name end,
    GetSpellDescription = function(id) return SPELLS[id] and SPELLS[id].desc end,
    GetSpellTexture = function(id) return "spell:" .. tostring(id) end,
}
IsSpellKnown = function(id) return id == 172 end
IsPlayerSpell = function(id) return id == 172 end
IsSpellKnownOrOverridesKnown = function(id) return id == 172 end
C_SpellBook = {
    GetNumSpellBookSkillLines = function() return 1 end,
    GetSpellBookSkillLineInfo = function(line)
        if line == 1 then return { itemIndexOffset = 0, numSpellBookItems = 1 } end
    end,
    GetSpellBookItemInfo = function(index)
        if index == 1 then return { spellID = 172 } end
    end,
}

UnitName = function(u)
    if u == "player" then return "Gromix" end
    if u == "target" or u == "nameplate1" then return "Clattering Scorpid" end
end
GetRealmName = function() return "Verdabnet" end
UnitClass = function() return "Warlock", "WARLOCK", 9 end

local SECRET_VALUE = setmetatable({}, { __index = function() error("secret read") end })
local issecretBase = issecretvalue
issecretvalue = function(v) return v == SECRET_VALUE end

local unitExistsFn
local units = {
    player = { guid = "Player-93-0001", exists = true, attack = false },
    target = { guid = "Creature-0-93-1-1-3125-001", exists = true, attack = true, hp = 800, max = 1000 },
    nameplate1 = { guid = "Creature-0-93-1-1-3125-001", exists = true, attack = true, hp = 800, max = 1000 },
}
UnitGUID = function(u) return units[u] and units[u].guid end
UnitExists = function(u)
    if unitExistsFn then return unitExistsFn(u) end
    return units[u] and units[u].exists == true or false
end
UnitCanAttack = function(_, u) return units[u] and units[u].attack == true or false end
UnitIsDead = function() return false end
UnitIsDeadOrGhost = function() return false end
UnitHealth = function(u) return units[u] and units[u].hp or 0 end
UnitHealthMax = function(u) return units[u] and units[u].max or 1 end
UnitGetTotalAbsorbs = function() return 0 end

-- DaylightUI mock frames & settings
local dTargetFrame = makeWidget("Frame", "DaylightTargetFrame")
local dTargetHealth = makeWidget("StatusBar", "DaylightTargetHealth", dTargetFrame)
local dTargetPortrait = makeWidget("Texture", "DaylightTargetPortrait", dTargetFrame)

local dPlate = makeWidget("Frame", "DaylightPlate1")
local dPlateHealth = makeWidget("StatusBar", "DaylightPlate1Health", dPlate)

local blizzPlate1 = makeWidget("Frame", "BlizzPlate1")
blizzPlate1.unitToken = "nameplate1" -- deliberately omit namePlateUnitToken & UnitFrame to test plate.unitToken fallback

C_NamePlate = {
    GetNamePlateForUnit = function(unit)
        if unit == "nameplate1" then return blizzPlate1 end
    end,
}

local daylightSettings = {
    UnitFrames = { ["target.dotTint"] = true, ["target.dotSkull"] = true },
    Nameplates = { dotTint = true, dotSkull = true },
}
DaylightUI = {
    API = {
        Frames = function(kind)
            local items = {}
            if kind == "unit" then items = { { dTargetFrame, "target" } } end
            local i = 0
            return function()
                i = i + 1
                if items[i] then return items[i][1], items[i][2] end
            end
        end,
        GetNameplate = function(unit)
            if unit == "nameplate1" then return dPlate end
        end,
        Parts = function(frame)
            if frame == dTargetFrame then
                return { health = dTargetHealth, portrait = dTargetPortrait }
            elseif frame == dPlate then
                return { health = dPlateHealth }
            end
        end,
        GetSetting = function(scope, path)
            return daylightSettings[scope] and daylightSettings[scope][path]
        end,
    },
}

-- Load addon files in TOC order
local BIT = {
    L = function(s) return s end,
    RegisterCommand = function() end,
    modules = {},
}
BIT.modules.SpellDamageInfo = {
    Compute = function(id)
        if id == 172 then
            return { school = 32, dot = { total = 108 } }
        end
    end,
}

assert(loadfile("Core/Init.lua"))("UsefulPlatesAndTooltips", BIT)
assert(loadfile("Core/PlateLayout.lua"))("UsefulPlatesAndTooltips", BIT)
assert(loadfile("Core/API.lua"))("UsefulPlatesAndTooltips", BIT)
assert(loadfile("Core/Integrations/DaylightUI.lua"))("UsefulPlatesAndTooltips", BIT)
assert(loadfile("Modules/DoTInfo/Locale.lua"))("UsefulPlatesAndTooltips", BIT)
assert(loadfile("Modules/DoTInfo/NativeAuraIDs.lua"))("UsefulPlatesAndTooltips", BIT)
assert(loadfile("Modules/DoTInfo/Core.lua"))("UsefulPlatesAndTooltips", BIT)
assert(loadfile("Modules/DoTInfo/KillCheck.lua"))("UsefulPlatesAndTooltips", BIT)
assert(loadfile("Modules/DoTInfo/SwingIcon.lua"))("UsefulPlatesAndTooltips", BIT)
assert(loadfile("Modules/DoTInfo/RogueAuras.lua"))("UsefulPlatesAndTooltips", BIT)
assert(loadfile("Modules/DoTInfo/Nameplates.lua"))("UsefulPlatesAndTooltips", BIT)
assert(loadfile("Modules/DoTInfo/API.lua"))("UsefulPlatesAndTooltips", BIT)

local ns = BIT.Module("DoTInfo")

-- 1) Core/Integrations/DaylightUI.lua: plate.unitToken fallback + DaylightDotDisplay checks
local foundBar, foundPath = BIT.Plate.HealthBar(blizzPlate1)
assert(foundBar == dPlateHealth and foundPath == "DaylightUI.nameplate.health",
    "DaylightUI integration must resolve plate.unitToken fallback")
assert(select(1, BIT.Plate.DaylightDotDisplay("unit", "target", dTargetHealth)) == true)
assert(select(2, BIT.Plate.DaylightDotDisplay("unit", "target", dTargetHealth)) == true)
assert(select(1, BIT.Plate.DaylightDotDisplay("nameplate", "nameplate1", dPlateHealth)) == true)
assert(select(2, BIT.Plate.DaylightDotDisplay("nameplate", "nameplate1", dPlateHealth)) == true)
assert(select(1, BIT.Plate.DaylightDotDisplay("nameplate", "nameplate1", makeWidget("StatusBar"))) == false,
    "unrelated health bar must never match DaylightDotDisplay")

-- 2) ADDON_LOADED LIFO ordering: fire frames in reverse registration order (API.lua BEFORE Core.lua / Init.lua)
local addonLoadedFrames = {}
for _, f in ipairs(frames) do
    if f.events.ADDON_LOADED and type(f.scripts.OnEvent) == "function" then
        addonLoadedFrames[#addonLoadedFrames + 1] = f
    end
end
for i = #addonLoadedFrames, 1, -1 do
    local f = addonLoadedFrames[i]
    f.scripts.OnEvent(f, "ADDON_LOADED", "UsefulPlatesAndTooltips")
end
assert(_G.DoesItDie == _G.UsefulPlatesAndTooltips_DoTAPI,
    "_G.DoesItDie must be set during ADDON_LOADED even under LIFO dispatch order (prior to PLAYER_LOGIN)")
assert(type(ns.db) == "table", "DoTInfo Core must initialize ns.db on ADDON_LOADED")

-- Verify DaylightUI/Dots.lua callback & API contract + ns.afterRefresh safety against UnitExists errors/secrets
local borrowedCalls = 0
local lastBorrowedUnit
_G.DoesItDie.RegisterCallback("DaylightUI", function(_, unit)
    borrowedCalls = borrowedCalls + 1
    lastBorrowedUnit = unit
end)
unitExistsFn = function(u)
    if u == "target" then return SECRET_VALUE end
    if u == "focus" then error("restricted unit") end
    return units[u] and units[u].exists == true or false
end
assert(pcall(ns.afterRefresh), "ns.afterRefresh must survive secret/erroring UnitExists")
unitExistsFn = nil

-- Fire PLAYER_ENTERING_WORLD and cast Corruption (172) on target
local coreFrame, platesDriver
for _, f in ipairs(frames) do
    if f.events.UNIT_COMBAT and type(f.scripts.OnEvent) == "function" then coreFrame = f end
    if f.scripts.OnUpdate and f:IsShown() and not f.events.ADDON_LOADED and not f.events.UNIT_AURA then
        platesDriver = f
    end
end
assert(coreFrame, "Core.lua event frame not found")
assert(platesDriver, "Nameplates.lua driver frame not found")

coreFrame.scripts.OnEvent(coreFrame, "PLAYER_ENTERING_WORLD")
for _, f in ipairs(frames) do
    if f.events.NAME_PLATE_UNIT_ADDED and f ~= coreFrame and type(f.scripts.OnEvent) == "function" then
        f.scripts.OnEvent(f, "NAME_PLATE_UNIT_ADDED", "nameplate1")
    end
end
coreFrame.scripts.OnEvent(coreFrame, "NAME_PLATE_UNIT_ADDED", "nameplate1")

-- Advance clock past generic spellbook slice so RogueAuras builds generic Warlock Corruption spec
advanceTime(0.5)
ns.RogueNative.UpdateRogueAuras()
advanceTime(0.5)
ns.RogueNative.UpdateRogueAuras()

coreFrame.scripts.OnEvent(coreFrame, "UNIT_SPELLCAST_SENT", "player", "Clattering Scorpid", "cast-1", 172)
coreFrame.scripts.OnEvent(coreFrame, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 172)
assert(borrowedCalls >= 1 and (lastBorrowedUnit == "target" or lastBorrowedUnit == "nameplate1"),
    "DoesItDie callback must notify listener when Corruption lands")
assert(_G.DoesItDie.GetRemainingDamage("nameplate1") == 108,
    "DoesItDie.GetRemainingDamage must report tracked Corruption damage (108)")

-- Trigger a lethal DoT (>800 dmg on 800 HP mob) so skullWindow / nameplate iconWindow would light if allowed
for k = 2, 10 do
    coreFrame.scripts.OnEvent(coreFrame, "UNIT_SPELLCAST_SENT", "player", "Clattering Scorpid", "cast-" .. k, 980)
    coreFrame.scripts.OnEvent(coreFrame, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast-" .. k, 980)
end
-- Ensure Corruption is set to 900 via repeated corruption? Wait: Agony adds 72 (108+72=180). Give Corruption a higher remaining or lower mob HP to 100!
units.target.hp, units.nameplate1.hp = 80, 1000
ns.refresh()

local remainingBar = assert(namedFrames.UsefulPlatesAndTooltips_DoTInfoRemaining)
local skullWindow = assert(namedFrames.UsefulPlatesAndTooltips_DoTInfoSkull)
local fillLayer, outlineLayer, clipLayer, sparkLayer =
    remainingBar.children[1], remainingBar.children[10], remainingBar.children[11], remainingBar.children[12]
local flashTex = fillLayer.regions[#fillLayer.regions]
local flashInGroup = flashTex.animGroups[1]

-- 3) Core.lua target suppression while keeping options preview intact
assert(remainingBar:IsShown() == false, "target remainingBar must hide when Daylight owns tint and showLabel is false")
assert(skullWindow:IsShown() == false, "target skullWindow must hide when Daylight owns dotSkull")
assert(fillLayer:IsShown() == false and clipLayer:IsShown() == false and outlineLayer:IsShown() == false and sparkLayer:IsShown() == false,
    "marker layers must all be hidden when Daylight owns target tint")
assert(ns.nativePoisonBase("target", dTargetFrame, dTargetHealth) == 0,
    "nativePoisonBase must return 0 when Daylight owns target tint")
local playsBefore = flashInGroup.playCount
ns.playFlash()
assert(flashInGroup.playCount == playsBefore, "playFlash must not trigger while Daylight owns target tint")

-- Label mode keeps remainingBar shown only for text, while layers + nativePoisonBase stay suppressed
ns.db.showLabel = true
ns.refresh()
assert(remainingBar:IsShown() == true, "remainingBar stays shown when showLabel is true")
assert(fillLayer:IsShown() == false and clipLayer:IsShown() == false and outlineLayer:IsShown() == false and sparkLayer:IsShown() == false,
    "marker visual layers stay hidden when Daylight owns tint even with showLabel on")
assert(ns.nativePoisonBase("target", dTargetFrame, dTargetHealth) == 0,
    "nativePoisonBase stays 0 while Daylight owns tint even with showLabel on")
ns.db.showLabel = false

-- Options preview must never be suppressed by DaylightUI settings
local previewHost = {
    healthBar = makeWidget("StatusBar", "PreviewHealth"),
    portrait = makeWidget("Texture", "PreviewPortrait"),
    layerFrame = makeWidget("Frame", "PreviewWindow"),
}
ns.setDisplayHost(previewHost)
ns.setPreviewState({ health = 50, dots = { { name = "Corruption", school = 32, damage = 80 } } })
ns.refresh()
assert(remainingBar:IsShown() == true and fillLayer:IsShown() == true and skullWindow:IsShown() == true,
    "options preview must continue drawing both marker and skull even when DaylightUI hides live target markers")
ns.setPreviewState(nil)
ns.setDisplayHost(nil)

-- 4) Nameplates.lua suppression & gated twin plan zeroing + independent dotTint/dotSkull toggles
local capturedPlan
local realSetPlan = ns.RogueNative.SetPlan
ns.RogueNative.SetPlan = function(plate, items, reverse)
    capturedPlan = { plate = plate, reverse = reverse, items = {} }
    for name, item in pairs(items) do
        capturedPlan.items[name] = { offset = item.offset, damage = item.damage }
    end
    return realSetPlan(plate, items, reverse)
end

-- Helper to drive two nameplate ticks (for kill-icon two-frame reveal)
local function tickPlates()
    advanceTime(0.25)
    platesDriver.scripts.OnUpdate(platesDriver, 0.25)
end

-- First with Daylight Nameplates dotTint=false, dotSkull=true -> gated plan must populate >0
daylightSettings.Nameplates.dotTint = false
daylightSettings.Nameplates.dotSkull = true
tickPlates()
assert(ns.nameplateDamageBase(blizzPlate1, dPlateHealth) > 0,
    "nameplateDamageBase must be >0 when Daylight dotTint is disabled")
assert(capturedPlan and capturedPlan.items["Corruption"] and capturedPlan.items["Corruption"].damage > 0,
    "SetPlan must receive positive Corruption damage when Daylight dotTint is disabled")

-- Now enable Daylight Nameplates dotTint=true -> gated plan MUST zero Corruption immediately!
daylightSettings.Nameplates.dotTint = true
daylightSettings.Nameplates.dotSkull = true
tickPlates()
assert(ns.nameplateDamageBase(blizzPlate1, dPlateHealth) == 0,
    "nameplateDamageBase must be 0 when Daylight dotTint is enabled")
assert(capturedPlan and capturedPlan.items["Corruption"] and capturedPlan.items["Corruption"].damage == 0,
    "SetPlan must zero gated twin damage when Daylight dotTint is enabled")

local plateWidgets
for _, child in ipairs(blizzPlate1.children) do
    if child.objectType == "StatusBar" and #child.children >= 4 then
        plateWidgets = child
    end
end
assert(plateWidgets and plateWidgets:IsShown() == false, "plate w.marker must hide when Daylight dotTint is enabled")

-- Check independent nameplate dotSkull = false reveals kill icon while marker remains hidden
daylightSettings.Nameplates.dotSkull = false
tickPlates()
tickPlates()
local visibleIconWindow = false
for _, child in ipairs(blizzPlate1.children) do
    if child ~= plateWidgets and child:IsShown() and child.alpha and child.alpha > 0 then
        visibleIconWindow = true
    end
end
assert(visibleIconWindow and plateWidgets:IsShown() == false,
    "disabling only Daylight nameplate dotSkull must reveal kill icon while keeping marker hidden")

-- 5) RogueAuras.lua suppression:
--    a) while Daylight dotTint is enabled from startup, zero AuraContainers are created
assert(#auraContainers == 0, "expected RogueAuras to allocate zero containers while Daylight dotTint is active")

--    b) turning Daylight dotTint off creates and enables target & nameplate native/gated AuraContainers
daylightSettings.UnitFrames["target.dotTint"] = false
daylightSettings.UnitFrames["target.dotSkull"] = false
daylightSettings.Nameplates.dotTint = false
daylightSettings.Nameplates.dotSkull = false
advanceTime(0.25)
ns.refresh()
coreFrame.scripts.OnUpdate(coreFrame, 0.25)
tickPlates()
ns.RogueNative.UpdateRogueAuras()

assert(remainingBar:IsShown() == true and fillLayer:IsShown() == true and skullWindow:IsShown() == true,
    "Core.lua must restore target marker and skull when Daylight dotTint/dotSkull are turned off")
assert(ns.nativePoisonBase("target", dTargetFrame, dTargetHealth) > 0,
    "Core.lua must restore nativePoisonBase > 0 when Daylight dotTint is turned off")
assert(plateWidgets:IsShown() == true and ns.nameplateDamageBase(blizzPlate1, dPlateHealth) > 0,
    "Nameplates.lua must restore marker when Daylight dotTint is turned off")

local enabledCount = 0
for _, ac in ipairs(auraContainers) do
    if ac.enabled then enabledCount = enabledCount + 1 end
end
assert(#auraContainers > 0 and enabledCount > 0,
    "RogueAuras must create and enable native/gated AuraContainers when Daylight dotTint is turned off")

--    c) turning Daylight dotTint back on disables & hides every active AuraContainer (even in combat)
daylightSettings.UnitFrames["target.dotTint"] = true
daylightSettings.Nameplates.dotTint = true
advanceTime(0.25)
ns.RogueNative.UpdateRogueAuras()
for _, ac in ipairs(auraContainers) do
    assert(ac.enabled == false and ac:IsShown() == false,
        "every RogueAuras AuraContainer must be disabled and hidden when Daylight dotTint turns back on")
end

--    d) turning Daylight dotTint off again re-enables the existing containers
daylightSettings.UnitFrames["target.dotTint"] = false
daylightSettings.Nameplates.dotTint = false
advanceTime(0.25)
ns.RogueNative.UpdateRogueAuras()
enabledCount = 0
for _, ac in ipairs(auraContainers) do
    if ac.enabled then enabledCount = enabledCount + 1 end
end
assert(enabledCount > 0, "RogueAuras must re-enable native/gated AuraContainers when Daylight dotTint is turned off again")

-- 6) Isolated offerDaylightCompatibility() edge cases (standalone DoesItDie, disabled DoTInfo, late DaylightUI load)
_G.DoesItDie.UnregisterCallback("DaylightUI")
_G.DoesItDie = nil
_G.DaylightUI = nil
_G.UsefulPlatesAndTooltips_DoTAPI = nil
local function testCompatibility(opts)
    local handlers = {}
    local existing = opts.existingGlobal
    _G.DoesItDie = nil
    _G.DaylightUI = nil
    local apiEnv = setmetatable({
        _G = nil,
        UsefulPlatesAndTooltips_API = _G.UsefulPlatesAndTooltips_API,
        UnitExists = function() return false end,
        issecretvalue = function() return false end,
        CreateFrame = function()
            local f = {}
            f.RegisterEvent = function() end
            f.SetScript = function(_, kind, fn) handlers[kind] = fn end
            return f
        end,
    }, { __index = _G })
    apiEnv._G = apiEnv
    apiEnv.DaylightUI = opts.hasDaylightUI and {} or nil
    apiEnv.DoesItDie = existing
    apiEnv.UsefulPlatesAndTooltips_DoTAPI = nil
    local ns2 = { trace = function() end }
    local running = opts.running
    local bit2 = {
        API = {
            DeclareEvent = function() end,
            Register = function() end,
            HasListeners = function() return false end,
        },
        Module = function() return ns2 end,
        IsRunning = function() return running end,
    }
    local chunk = assert(loadfile("Modules/DoTInfo/API.lua", "t", apiEnv))
    chunk("UsefulPlatesAndTooltips", bit2)
    return apiEnv, ns2, handlers
end

-- Case A: standalone DoesItDie must never be overwritten
do
    local sentinel = { standalone = true }
    local env, ns2, handlers = testCompatibility({ hasDaylightUI = true, existingGlobal = sentinel, running = true })
    ns2.offerDaylightCompatibility()
    handlers.OnEvent(nil, "ADDON_LOADED", "UsefulPlatesAndTooltips")
    assert(env.DoesItDie == sentinel, "must never overwrite existing standalone _G.DoesItDie")
end

-- Case B: DoTInfo disabled -> _G.DoesItDie stays nil
do
    local env, ns2, handlers = testCompatibility({ hasDaylightUI = true, existingGlobal = nil, running = false })
    ns2.offerDaylightCompatibility()
    handlers.OnEvent(nil, "ADDON_LOADED", "UsefulPlatesAndTooltips")
    assert(env.DoesItDie == nil, "must leave _G.DoesItDie nil when DoTInfo is switched off")
end

-- Case C: DaylightUI loads AFTER UsefulPlatesAndTooltips -> ADDON_LOADED("DaylightUI") bridges it
do
    local env, ns2, handlers = testCompatibility({ hasDaylightUI = false, existingGlobal = nil, running = true })
    ns2.offerDaylightCompatibility()
    assert(env.DoesItDie == nil)
    env.DaylightUI = {}
    handlers.OnEvent(nil, "ADDON_LOADED", "DaylightUI")
    assert(env.DoesItDie == env.UsefulPlatesAndTooltips_DoTAPI,
        "late ADDON_LOADED('DaylightUI') must bridge _G.DoesItDie")
end

print("check_daylight_dot_integration: ok")
