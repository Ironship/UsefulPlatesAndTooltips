-- DaylightUI: connects DoesItDiePlus to Daylight UI's public API (DaylightUI.API) so every mark
-- that sits on a health bar, power bar, group tile, nameplate or action button works automatically
-- without touching Daylight UI's internals. Hooks into Core/PlateLayout.lua.
-- Copyright (c) 2026 Ironship. GPL-3.0-or-later, see LICENSE.
--
-- DaylightUI.API (WoW: Forever):
--   API.Frames(kind)       iterates real frames (never previews) for "unit", "party", "raid", "actionbutton"
--   API.GetNameplate(unit) returns the active Daylight UI nameplate for a nameplate unit token
--   API.Parts(frame)       returns named pieces: health, power, portrait, model, classIcon, ...
--   API.ButtonInfo(button) returns { slot, ... } for action buttons on bars 1-8
local _, BIT = ...
local Plate = BIT.Plate
if not Plate then return end
local read = Plate.Read

local function isSecret(v)
  if type(issecretvalue) ~= "function" then return false end
  local ok, r = pcall(issecretvalue, v)
  return ok and r == true
end

local function daylightAPI()
  local ui = _G.DaylightUI
  local api = type(ui) == "table" and ui.API or nil
  return type(api) == "table" and api or nil
end

local function eachFrame(api, kind, visit)
  if type(api.Frames) ~= "function" then return end
  pcall(function()
    for frame, unit in api.Frames(kind) do
      if not isSecret(frame) and type(frame) == "table" and read(frame.IsForbidden, frame) ~= true then
        local cleanUnit = (not isSecret(unit)) and unit or nil
        if visit(frame, cleanUnit) == true then return end
      end
    end
  end)
end

local function partsOf(api, frame)
  if type(api.Parts) ~= "function" then return nil end
  local parts = read(api.Parts, frame)
  return type(parts) == "table" and parts or nil
end

local function visiblePortrait(parts)
  for _, key in ipairs({ "portrait", "model", "classIcon" }) do
    local region = parts[key]
    if type(region) == "table" and read(region.IsForbidden, region) ~= true
        and read(region.IsVisible, region) == true then
      local alpha = read(region.GetEffectiveAlpha, region)
      if type(alpha) ~= "number" or alpha > 0 then return region end
    end
  end
  return nil
end

local function findUnitFrame(api, wantedUnit)
  local foundFrame, foundParts
  eachFrame(api, "unit", function(frame, unit)
    if unit == wantedUnit and read(frame.IsVisible, frame) == true then
      local parts = partsOf(api, frame)
      if parts then
        foundFrame, foundParts = frame, parts
        return true
      end
    end
  end)
  return foundFrame, foundParts
end

function Plate.DaylightDotDisplay(kind, unit, bar)
  local api = daylightAPI()
  if not api or type(api.GetSetting) ~= "function" or type(bar) ~= "table" then return false, false end

  if kind == "unit" and unit == "target" then
    local _, parts = findUnitFrame(api, unit)
    if not parts or parts.health ~= bar or read(bar.IsVisible, bar) == false then return false, false end
    return read(api.GetSetting, "UnitFrames", "target.dotTint") == true,
        read(api.GetSetting, "UnitFrames", "target.dotSkull") == true
  end

  if kind == "nameplate" and type(unit) == "string" and type(api.GetNameplate) == "function" then
    local frame = read(api.GetNameplate, unit)
    if type(frame) ~= "table" or read(frame.IsForbidden, frame) == true
        or read(frame.IsVisible, frame) ~= true then return false, false end
    local parts = partsOf(api, frame)
    if not parts or parts.health ~= bar or read(bar.IsVisible, bar) == false then return false, false end
    return read(api.GetSetting, "Nameplates", "dotTint") == true,
        read(api.GetSetting, "Nameplates", "dotSkull") == true
  end

  return false, false
end

local UNIT_FOR_PART = {
  Player = "player",
  Target = "target",
  Focus = "focus",
  TargetTarget = "targettarget",
}

Plate.RegisterUnitFrameSource("DaylightUI", function(_, part)
  local wanted = UNIT_FOR_PART[part]
  if not wanted then return end
  local api = daylightAPI()
  if not api then return end
  local frame, parts = findUnitFrame(api, wanted)
  if not frame or not parts then return end
  local bar = parts.health
  if type(bar) ~= "table" or read(bar.IsForbidden, bar) == true or read(bar.IsVisible, bar) == false then return end
  return frame, bar, visiblePortrait(parts)
end)

Plate.RegisterPowerBarSource("DaylightUI", function(unit)
  if type(unit) ~= "string" then return end
  local api = daylightAPI()
  if not api then return end
  local _, parts = findUnitFrame(api, unit)
  return parts and parts.power or nil
end)

Plate.RegisterGroupFramesSource("DaylightUI", function(out)
  local api = daylightAPI()
  if not api then return end
  for _, kind in ipairs({ "party", "raid" }) do
    eachFrame(api, kind, function(frame, unit)
      if type(unit) == "string" and (unit == "player" or unit:match("^party%d+$") or unit:match("^raid%d+$"))
          and read(frame.IsVisible, frame) == true then
        local parts = partsOf(api, frame)
        local bar = parts and parts.health
        if type(bar) == "table" and read(bar.IsForbidden, bar) ~= true and read(bar.IsVisible, bar) ~= false then
          out[#out + 1] = { unit = unit, bar = bar, host = frame, kind = kind }
        end
      end
    end)
  end
end)

Plate.RegisterPlateBarSource("DaylightUI", function(plate)
  local api = daylightAPI()
  if not api or type(api.GetNameplate) ~= "function" then return end
  local token = read(function() return plate.namePlateUnitToken end)
  if type(token) ~= "string" then
    token = read(function() return plate.unitToken end)
  end
  if type(token) ~= "string" then
    token = read(function() return plate.UnitFrame and plate.UnitFrame.unit end)
  end
  if type(token) ~= "string" then return end
  local dPlate = read(api.GetNameplate, token)
  if type(dPlate) ~= "table" or read(dPlate.IsForbidden, dPlate) == true
      or read(dPlate.IsVisible, dPlate) ~= true then return end
  local parts = partsOf(api, dPlate)
  local bar = parts and parts.health
  if Plate.VisibleHealthBar(bar) and read(bar.GetObjectType, bar) == "StatusBar" then
    return bar, "DaylightUI.nameplate.health"
  end
end)

local function actionButtonSlot(button)
  local api = daylightAPI()
  if not api or type(api.ButtonInfo) ~= "function" then return nil end
  local info = read(api.ButtonInfo, button)
  local slot = type(info) == "table" and info.slot or nil
  if not isSecret(slot) and type(slot) == "number" and slot > 0 then return slot end
end

Plate.RegisterActionButtonSource("DaylightUI", function(add)
  local api = daylightAPI()
  if not api then return end
  eachFrame(api, "actionbutton", function(button)
    add(button, actionButtonSlot)
  end)
end)
