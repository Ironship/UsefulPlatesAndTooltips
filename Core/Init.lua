-- UsefulPlatesAndTooltips: one addon made of parts (modules), each of which can be switched off.
-- Copyright (c) 2026 Ironship. GPL-3.0-or-later, see LICENSE.
--
-- Every module keeps its own namespace, BIT.Module(name), so two modules can both have a "db"
-- or an "L" without meeting. A module's code runs at load like any addon's; at ADDON_LOADED,
-- the first moment the saved settings can be read, it asks BIT.ShouldRun(name) and, when the
-- answer is no, unregisters its events and stays silent. Switching a module on or off takes
-- effect at the next /reload.

local ADDON, BIT = ...
BIT = BIT or {}
BIT.name = ADDON or "UsefulPlatesAndTooltips"
BIT.modules = {} -- name -> the module's namespace
BIT.order = {}   -- module names in the order their files load: the order of the settings tabs
BIT.state = {}   -- name -> "on" | "off", decided at ADDON_LOADED

function BIT.Module(name)
  local m = BIT.modules[name]
  if not m then
    m = { moduleName = name }
    BIT.modules[name] = m
    BIT.order[#BIT.order + 1] = name
  end
  return m
end

local function say(msg)
  if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage("|cff66bbffDoesItDiePlus|r: " .. tostring(msg))
  elseif print then
    print("DoesItDiePlus: " .. tostring(msg))
  end
end
BIT.Say = say

---------------------------------------------------------------------------------------------
-- Saved settings and character profiles:
--   UsefulPlatesAndTooltipsDB (root / BIT.GlobalDB()):
--     language, window, perf, probes   -- account-wide, shared by every profile
--     modules, appearance, frames      -- the shared "Default" profile (kept in place for full
--                                         compatibility; ported modules keep their own globals
--                                         for "Default")
--     profileKeys[charKey] = name      -- per-character profile choice (missing => "Default")
--     profiles[name] = {               -- non-Default profiles (character or custom named)
--       modules    = { [moduleName] = { enabled = bool, ... } },
--       appearance = { ... },
--       frames     = { ... },
--       ported     = { SpellDamageInfo = {...}, DoTInfo = {...}, ResourceDing = {...} },
--     }
-- BIT.DB() returns the active profile table for this session (locked when the root DB is bound
-- at ADDON_LOADED so running modules never split-brain across two profiles before /reload).
-- BIT.PortedDB(name) returns the active profile's sub-table for a ported module.
---------------------------------------------------------------------------------------------

local DEFAULT_PROFILE = "Default"
local MAX_PROFILE_NAME = 48

local PORTED_LEGACY = {
  SpellDamageInfo = "UsefulPlatesAndTooltips_SpellDamageInfoDB",
  DoTInfo = "UsefulPlatesAndTooltips_DoTInfoDB",
  ResourceDing = "UsefulPlatesAndTooltips_ResourceDingDB",
}

-- Per-character learned/diagnostic keys stripped when copying one profile into another,
-- and preserved when resetting or overwriting a profile so learned ticks/history stay intact.
local TRANSIENT_MODULE_KEYS = {
  CastPrediction = { log = true, learned = true },
  TriggerGlow = { log = true, lethalOther = true },
  StatsInfo = { log = true },
  HealPrediction = { log = true },
}
local TRANSIENT_PORTED_KEYS = {
  DoTInfo = { log = true, ticks = true, tickWeights = true, intervals = true, chars = true, auras = true },
  SpellDamageInfo = { castHistory = true, misses = true, dump = true, dumpAll = true, dumpItems = true, interfaceLang = true },
}
local PRESERVED_MODULE_KEYS = {
  CastPrediction = { learned = true, talentEngine = true },
}
local PRESERVED_PORTED_KEYS = {
  DoTInfo = { chars = true, ticks = true, tickWeights = true, intervals = true, version = true },
  SpellDamageInfo = { castHistory = true },
}

local function isSecret(v)
  if type(issecretvalue) ~= "function" then return false end
  local ok, r = pcall(issecretvalue, v)
  return ok and r or false
end

local function trim(text)
  if type(text) ~= "string" then return "" end
  if type(strtrim) == "function" then return strtrim(text) end
  return text:match("^%s*(.-)%s*$") or ""
end

local function deepCopy(value, skipKeys)
  if type(value) ~= "table" then return value end
  local out = {}
  for k, v in pairs(value) do
    if not (skipKeys and skipKeys[k]) then
      out[k] = deepCopy(v)
    end
  end
  return out
end

local function characterKey()
  if type(UnitName) ~= "function" then return nil end
  local okN, name = pcall(UnitName, "player")
  if not okN or isSecret(name) or type(name) ~= "string" or name == "" then return nil end
  if UNKNOWNOBJECT and name == UNKNOWNOBJECT then return nil end
  local realm
  if type(GetRealmName) == "function" then
    local okR, r = pcall(GetRealmName)
    if okR and not isSecret(r) and type(r) == "string" and r ~= "" then realm = r end
  end
  return realm and (name .. " - " .. realm) or name
end

local function ensureProfileShape(profile)
  if type(profile) ~= "table" then profile = {} end
  if type(profile.modules) ~= "table" then profile.modules = {} end
  if type(profile.ported) ~= "table" then profile.ported = {} end
  return profile
end

local function ensureLegacyPorted(name)
  local globalName = PORTED_LEGACY[name]
  if not globalName then return {} end
  local tbl = rawget(_G, globalName)
  if type(tbl) ~= "table" then
    tbl = {}
    _G[globalName] = tbl
  end
  return tbl
end

local function readProfileView(root, name)
  if name == DEFAULT_PROFILE then
    local ported = {}
    for modName, globalName in pairs(PORTED_LEGACY) do
      local tbl = rawget(_G, globalName)
      if type(tbl) == "table" then ported[modName] = tbl end
    end
    return {
      modules = type(root.modules) == "table" and root.modules or {},
      appearance = type(root.appearance) == "table" and root.appearance or nil,
      frames = type(root.frames) == "table" and root.frames or nil,
      ported = ported,
    }
  end
  return type(root.profiles[name]) == "table" and root.profiles[name] or nil
end

local function writeProfileData(root, name, data)
  if name == DEFAULT_PROFILE then
    root.modules = type(data.modules) == "table" and data.modules or {}
    root.appearance = data.appearance
    root.frames = data.frames
    for modName, globalName in pairs(PORTED_LEGACY) do
      local tbl = type(data.ported) == "table" and data.ported[modName] or nil
      _G[globalName] = type(tbl) == "table" and tbl or {}
    end
    return
  end
  root.profiles[name] = ensureProfileShape(data)
end

local boundRoot, activeProfileName, activeProfile, profileDirty

local function globalDB()
  if type(UsefulPlatesAndTooltipsDB) ~= "table" then UsefulPlatesAndTooltipsDB = {} end
  local root = UsefulPlatesAndTooltipsDB
  if boundRoot ~= root then
    if type(root.modules) ~= "table" then root.modules = {} end
    if type(root.profileKeys) ~= "table" then root.profileKeys = {} end
    if type(root.profiles) ~= "table" then root.profiles = {} end
    root.profiles[DEFAULT_PROFILE] = nil -- Default lives at root
    local key = characterKey()
    local wanted = key and type(root.profileKeys[key]) == "string" and root.profileKeys[key] or DEFAULT_PROFILE
    if wanted ~= DEFAULT_PROFILE and type(root.profiles[wanted]) ~= "table" then wanted = DEFAULT_PROFILE end
    activeProfileName = wanted
    if wanted == DEFAULT_PROFILE then
      activeProfile = root
    else
      activeProfile = ensureProfileShape(root.profiles[wanted])
      root.profiles[wanted] = activeProfile
    end
    profileDirty = false
    boundRoot = root
  end
  return root
end
BIT.GlobalDB = globalDB

local function db()
  globalDB()
  if type(activeProfile.modules) ~= "table" then activeProfile.modules = {} end
  return activeProfile
end
BIT.DB = db

-- The settings table of a ported module (SpellDamageInfo, DoTInfo, ResourceDing) inside the active profile.
function BIT.PortedDB(name)
  globalDB()
  if activeProfileName == DEFAULT_PROFILE then
    return ensureLegacyPorted(name)
  end
  if type(activeProfile.ported) ~= "table" then activeProfile.ported = {} end
  if type(activeProfile.ported[name]) ~= "table" then activeProfile.ported[name] = {} end
  return activeProfile.ported[name]
end

-- Copy settings from `src` profile view into a fresh profile table, omitting per-character learned/log data,
-- and optionally preserving learned data already stored in `keepFrom`.
local function cloneProfileSettings(src, keepFrom)
  local dst = ensureProfileShape({})
  if type(src) == "table" then
    if type(src.modules) == "table" then
      for modName, modTbl in pairs(src.modules) do
        if type(modTbl) == "table" then
          local skip = TRANSIENT_MODULE_KEYS[modName] or { log = true }
          dst.modules[modName] = deepCopy(modTbl, skip)
        end
      end
    end
    if type(src.appearance) == "table" then dst.appearance = deepCopy(src.appearance) end
    if type(src.frames) == "table" then dst.frames = deepCopy(src.frames) end
    if type(src.ported) == "table" then
      for modName, modTbl in pairs(src.ported) do
        if type(modTbl) == "table" then
          local skip = TRANSIENT_PORTED_KEYS[modName] or { log = true }
          dst.ported[modName] = deepCopy(modTbl, skip)
        end
      end
    end
  end
  if type(keepFrom) == "table" then
    if type(keepFrom.modules) == "table" then
      for modName, keys in pairs(PRESERVED_MODULE_KEYS) do
        local oldMod = keepFrom.modules[modName]
        if type(oldMod) == "table" then
          for k in pairs(keys) do
            if oldMod[k] ~= nil then
              dst.modules[modName] = dst.modules[modName] or {}
              dst.modules[modName][k] = deepCopy(oldMod[k])
            end
          end
        end
      end
    end
    if type(keepFrom.ported) == "table" then
      for modName, keys in pairs(PRESERVED_PORTED_KEYS) do
        local oldMod = keepFrom.ported[modName]
        if type(oldMod) == "table" then
          for k in pairs(keys) do
            if oldMod[k] ~= nil then
              dst.ported[modName] = dst.ported[modName] or {}
              dst.ported[modName][k] = deepCopy(oldMod[k])
            end
          end
        end
      end
    end
  end
  return dst
end

local Profiles = { DEFAULT = DEFAULT_PROFILE }
BIT.Profiles = Profiles

function Profiles.CharacterKey()
  return characterKey()
end

function Profiles.Active()
  globalDB()
  return activeProfileName or DEFAULT_PROFILE
end

function Profiles.Selected()
  local root = globalDB()
  local key = characterKey()
  local wanted = key and type(root.profileKeys[key]) == "string" and root.profileKeys[key] or DEFAULT_PROFILE
  if wanted ~= DEFAULT_PROFILE and type(root.profiles[wanted]) ~= "table" then return DEFAULT_PROFILE end
  return wanted
end

function Profiles.PendingReload()
  globalDB()
  return (Profiles.Selected() ~= Profiles.Active()) or (profileDirty == true)
end

function Profiles.SanitizeName(name)
  local s = trim(name)
  if s == "" then return nil end
  if #s > MAX_PROFILE_NAME then s = s:sub(1, MAX_PROFILE_NAME) end
  if s:lower() == DEFAULT_PROFILE:lower() then return DEFAULT_PROFILE end
  return s
end

function Profiles.Exists(name)
  local root = globalDB()
  if type(name) ~= "string" then return false end
  if name == DEFAULT_PROFILE then return true end
  return type(root.profiles[name]) == "table"
end

function Profiles.List()
  local root = globalDB()
  local names = {}
  for name, tbl in pairs(root.profiles) do
    if type(name) == "string" and type(tbl) == "table" and name ~= DEFAULT_PROFILE then
      names[#names + 1] = name
    end
  end
  table.sort(names, function(a, b) return a:lower() < b:lower() end)
  table.insert(names, 1, DEFAULT_PROFILE)
  return names
end

-- Create a profile (blank if sourceName is nil, else a clean copy of sourceName).
function Profiles.Create(name, sourceName)
  local clean = Profiles.SanitizeName(name)
  if not clean then return false, "empty" end
  local root = globalDB()
  if Profiles.Exists(clean) then return false, "exists" end
  if sourceName ~= nil then
    local src = readProfileView(root, sourceName)
    if type(src) ~= "table" then return false, "missing_source" end
    root.profiles[clean] = cloneProfileSettings(src, nil)
  else
    root.profiles[clean] = ensureProfileShape({})
  end
  return true, clean
end

-- Assign profile `name` to this character (takes effect on /reload; never swaps tables under running modules).
-- opts.create: create if missing; opts.copyFromCurrent: seed a newly created profile from the active profile.
function Profiles.Use(name, opts)
  local clean = Profiles.SanitizeName(name)
  if not clean then return false, "empty" end
  local key = characterKey()
  if not key then return false, "no_character" end
  local root = globalDB()
  local created = false
  if not Profiles.Exists(clean) then
    if not (opts and opts.create) then return false, "missing" end
    local src = (opts and opts.copyFromCurrent) and readProfileView(root, activeProfileName) or nil
    root.profiles[clean] = src and cloneProfileSettings(src, nil) or ensureProfileShape({})
    created = true
  end
  if clean == DEFAULT_PROFILE then
    root.profileKeys[key] = nil
  else
    root.profileKeys[key] = clean
  end
  return true, created
end

-- Overwrite the character's selected profile with settings copied from `sourceName` (learned data preserved).
function Profiles.CopyFrom(sourceName)
  local root = globalDB()
  local cleanSource = Profiles.SanitizeName(sourceName)
  local targetName = Profiles.Selected()
  if not cleanSource or cleanSource == targetName then return false, "same" end
  local src = readProfileView(root, cleanSource)
  if type(src) ~= "table" then return false, "missing" end
  local oldTarget = readProfileView(root, targetName)
  writeProfileData(root, targetName, cloneProfileSettings(src, oldTarget))
  if targetName == activeProfileName then profileDirty = true end
  return true, targetName
end

-- Reset `name` (defaults to this character's selected profile) back to defaults, keeping learned data.
function Profiles.Reset(name)
  local root = globalDB()
  local targetName = name ~= nil and Profiles.SanitizeName(name) or Profiles.Selected()
  if not targetName or not Profiles.Exists(targetName) then return false, "missing" end
  local oldTarget = readProfileView(root, targetName)
  writeProfileData(root, targetName, cloneProfileSettings(nil, oldTarget))
  if targetName == activeProfileName then profileDirty = true end
  return true, targetName
end

-- Delete a non-Default profile that is neither active nor selected by this character.
function Profiles.Delete(name)
  local root = globalDB()
  local clean = Profiles.SanitizeName(name)
  if not clean then return false, "missing" end
  if clean == DEFAULT_PROFILE then return false, "default" end
  if clean == Profiles.Active() or clean == Profiles.Selected() then return false, "in_use" end
  if type(root.profiles[clean]) ~= "table" then return false, "missing" end
  root.profiles[clean] = nil
  for charKey, assigned in pairs(root.profileKeys) do
    if assigned == clean then root.profileKeys[charKey] = nil end
  end
  return true
end

-- The settings table of one module in UsefulPlatesAndTooltipsDB, created with its defaults.
function BIT.Settings(name, defaults)
  local d = db()
  if type(d.modules[name]) ~= "table" then d.modules[name] = {} end
  local s = d.modules[name]
  for k, v in pairs(defaults or {}) do
    if type(s[k]) ~= type(v) or (type(v) == "number"
      and (s[k] ~= s[k] or s[k] == math.huge or s[k] == -math.huge)) then s[k] = v end
  end
  return s
end

function BIT.IsSwitchedOn(name)
  local s = db().modules[name]
  return not (type(s) == "table" and s.enabled == false)
end

function BIT.SetSwitchedOn(name, on)
  BIT.Settings(name).enabled = on and true or false
end

---------------------------------------------------------------------------------------------
-- Switching modules on and off
---------------------------------------------------------------------------------------------

-- Called by a module at ADDON_LOADED: should it run? Remembers the answer for the settings.
function BIT.ShouldRun(name)
  if not BIT.IsSwitchedOn(name) then
    BIT.state[name] = "off"
    return false
  end
  BIT.state[name] = "on"
  return true
end

function BIT.IsRunning(name) return BIT.state[name] == "on" end

-- A module's own slash command while the module is off.
function BIT.SayOff(name)
  say(string.format(BIT.L("%s is switched off. /upt opens the settings, where it can be switched on."), name))
end

---------------------------------------------------------------------------------------------
-- Settings tabs: a module registers how to build its settings into a tab (Core/Settings.lua).
---------------------------------------------------------------------------------------------

BIT.tabs = {} -- name -> { title, build = function(parent), onShow, onHide }

function BIT.RegisterTab(name, tab)
  BIT.Module(name) -- keeps the order of the files
  tab.name = name
  BIT.tabs[name] = tab
end

-- A waker fills a switched-off module's saved defaults so its settings page can be built
-- the moment Enable is ticked. It must not register events, collect buttons, or start
-- gameplay: that still waits for the next /reload. Opening a tab does not call it.
BIT.wakers = {}
BIT.woke = {}

function BIT.RegisterWaker(name, fn)
  BIT.wakers[name] = fn
end

function BIT.Wake(name)
  if BIT.woke[name] or BIT.IsRunning(name) then return true end
  local fn = BIT.wakers[name]
  if type(fn) ~= "function" then return false end
  local ok, err = pcall(fn)
  if not ok then
    say(name .. " settings could not be prepared: " .. tostring(err))
    return false
  end
  BIT.woke[name] = true
  return true
end

---------------------------------------------------------------------------------------------
-- The core's own start: the saved settings.
---------------------------------------------------------------------------------------------

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, arg1)
  if event == "ADDON_LOADED" and arg1 == BIT.name then
    local root = globalDB()
    if BIT.Perf then BIT.Perf.Attach(root) end
    self:UnregisterEvent("ADDON_LOADED")
  end
end)
