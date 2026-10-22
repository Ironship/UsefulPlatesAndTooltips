-- UsefulPlatesAndTooltips: one owner for the marks that share a nameplate.
-- Copyright (c) 2026 Ironship. GPL-3.0-or-later, see LICENSE.
--
-- The live seat, for the hunter rail and for ResourceDing's dots and diamonds, is
-- SetPoint("TOP", healthBar, "BOTTOM", 0, -offset). Positive offset moves the widget down.
-- In that frame (positive y up, origin on the health bar's bottom edge) the widget's top is
-- at y = -offset and its body occupies [top - height, top]. The previews use the same seat.
-- Range's check sits above the bar (BOTTOM to TOP) and is not part of this span.

local _, BIT = ...

local Plate = {}
BIT.Plate = Plate

-- Body heights of the live widgets. The hunter rail is the row of dots plus its icons;
-- the resource rows are one dot tall (ResourceDing's default dot size).
Plate.HUNTER_RAIL_HEIGHT = 16
Plate.DOT_ROW_HEIGHT = 14
Plate.SHARD_ROW_HEIGHT = 14
Plate.SHIELD_EDGE = 4

local function read(fn, ...)
  if type(fn) ~= "function" then return end
  local ok, value = pcall(fn, ...)
  if ok and not (type(issecretvalue) == "function" and issecretvalue(value)) then return value end
end

-- EUI keeps Blizzard's frames alive but hidden, so follow the profile's active source.
function Plate.UnitFrame(unit)
  local modules = type(EllesmereUI) == "table" and EllesmereUI._ModuleNS
  local eui = type(modules) == "table" and modules.EllesmereUIUnitFrames
  local source = type(eui) == "table" and read(eui.GetUnitFrameSource, unit)
  if source == "hidden" then return end
  local custom = _G["EllesmereUIUnitFrames_" .. (unit == "player" and "Player" or "Target")]
  if source == "eui" or (source ~= "blizzard" and type(custom) == "table"
      and read(custom.IsVisible, custom) == true) then
    if type(custom) ~= "table" or read(custom.IsForbidden, custom) == true then return end
    local bar, portrait = custom.Health, custom.Portrait
    if type(bar) ~= "table" or read(bar.IsForbidden, bar) == true then return end
    if type(portrait) ~= "table" or read(portrait.IsVisible, portrait) ~= true then portrait = nil end
    return custom, bar, portrait
  end
  local frame
  if unit == "player" then frame = PlayerFrame else frame = TargetFrame end
  local content = type(frame) == "table" and (unit == "player" and frame.PlayerFrameContent or frame.TargetFrameContent)
  local main = type(content) == "table" and (unit == "player" and content.PlayerFrameContentMain or content.TargetFrameContentMain)
  local container = type(main) == "table" and main.HealthBarsContainer
  local bar = type(container) == "table" and container.HealthBar
  if type(bar) ~= "table" then bar = type(main) == "table" and main.HealthBar end
  if type(bar) ~= "table" then bar = type(frame) == "table" and frame.HealthBar end
  if type(bar) ~= "table" then bar = type(frame) == "table" and frame.healthbar end
  if type(bar) ~= "table" then bar = _G[unit == "player" and "PlayerFrameHealthBar" or "TargetFrameHealthBar"] end
  local portraitHost = type(frame) == "table" and frame.TargetFrameContainer
  local portrait = type(portraitHost) == "table" and portraitHost.Portrait
  if type(portrait) ~= "table" then portrait = _G[unit == "player" and "PlayerFramePortrait" or "TargetFramePortrait"] end
  if type(portrait) ~= "table" then portrait = type(frame) == "table" and frame.portrait end
  return frame, bar, portrait
end

local function visibleHealthBar(bar)
  local ok, visible = pcall(function()
    if type(bar) ~= "table" or read(bar.IsForbidden, bar) == true
      or read(bar.IsVisible, bar) == false then return false end
    local alpha = read(bar.GetEffectiveAlpha, bar)
    return type(alpha) ~= "number" or alpha > 0
  end)
  return ok and visible == true
end

local function isUnder(frame, plate)
  for _ = 1, 12 do
    frame = read(function() return frame:GetParent() end)
    if type(frame) ~= "table" then return false end
    if frame == plate then return true end
  end
  return false
end

-- Adapted from Does It Die (Joe Greive, MIT); see Modules/DoTInfo/LICENSE-DoesItDie.txt.
local SEARCH_DEPTH, MAX_TABLE_ENTRIES, SEARCH_INTERVAL = 4, 200, 1
local searchCache = setmetatable({}, { __mode = "k" })

local function tableFields(container, plain)
  local ok, fields = pcall(function()
    local found, count = {}, 0
    for key, value in pairs(container) do
      count = count + 1
      if plain and count > MAX_TABLE_ENTRIES then return end
      if type(key) == "string" and type(value) == "table" then
        found[#found + 1] = { key, value }
      end
    end
    table.sort(found, function(a, b) return a[1] < b[1] end)
    return found
  end)
  if ok then return fields end
end

local function searchHealthBar(plate)
  local unitFrame = read(function() return plate.UnitFrame end)
  local queue = { { node = plate, path = "", depth = 0, plain = false } }
  local seen, head = { [plate] = true }, 1
  while queue[head] do
    local item = queue[head]
    head = head + 1
    local fields = tableFields(item.node, item.plain)
    if fields then
      for _, field in ipairs(fields) do
        local key, value = field[1], field[2]
        local ok, found = pcall(function()
          return key:lower():find("health", 1, true) and read(value.GetObjectType, value) == "StatusBar"
            and visibleHealthBar(value) and isUnder(value, plate)
        end)
        if ok and found then return value, "auto " .. item.path .. key end
      end
      if item.depth < SEARCH_DEPTH then
        for _, field in ipairs(fields) do
          local key, value = field[1], field[2]
          if not seen[value] and value ~= unitFrame then
            seen[value] = true
            -- A broken framework object must not stop the other branches.
            local ok, frame = pcall(function() return value:GetObjectType() end)
            frame = ok and type(frame) == "string"
            local visit = not frame or read(function()
              return read(value.IsForbidden, value) == false
                and read(value.GetObjectType, value) ~= "StatusBar" and isUnder(value, plate)
            end)
            if visit then
              queue[#queue + 1] = { node = value, path = item.path .. key .. ".",
                depth = item.depth + 1, plain = not frame }
            end
          end
        end
      end
    end
  end
end

local function autoHealthBar(plate)
  local cached, now = searchCache[plate], GetTime()
  if cached and cached.bar and visibleHealthBar(cached.bar) and isUnder(cached.bar, plate) then
    return cached.bar, cached.path
  end
  if cached and now - cached.at < SEARCH_INTERVAL then return nil, "health bar search pending" end
  local ok, bar, path = pcall(searchHealthBar, plate)
  if not ok then bar, path = nil, "health bar search unavailable" end
  searchCache[plate] = { bar = bar, path = path, at = now }
  return bar, path or "no visible health bar found"
end

-- Prefer known integrations, then visible Blizzard bars, then a cached search of addon fields.
function Plate.HealthBar(plate)
  if type(plate) ~= "table" then return nil, "no nameplate" end
  if read(plate.IsForbidden, plate) == true then return nil, "forbidden nameplate" end
  if type(EllesmereNameplates_NS) == "table" then
    local children = { pcall(plate.GetChildren, plate) }
    if children[1] then
      for i = 2, #children do
        local ok, bar = pcall(function()
          local child = children[i]
          if child.nameplate == plate and type(child.health) == "table" and child:IsVisible()
            and visibleHealthBar(child.health) then return child.health end
        end)
        if ok and type(bar) == "table" then return bar, "EllesmereUINameplates.health" end
      end
    end
  end
  if type(Platynator) == "table" then
    local children = { pcall(plate.GetChildren, plate) }
    if children[1] then
      for i = 2, #children do
        local child = children[i]
        local ok, bar = pcall(function()
          if type(child.widgets) ~= "table" or not child:IsVisible() then return end
          for _, widget in ipairs(child.widgets) do
            if type(widget.details) == "table" and widget.details.kind == "health"
              and visibleHealthBar(widget.statusBar) then
              return widget.statusBar
            end
          end
        end)
        if ok and type(bar) == "table" then return bar, "Platynator.widgets.health.statusBar" end
      end
    end
  end
  local ok, bar, path = pcall(function()
    local unitFrame = plate.UnitFrame
    if type(unitFrame) ~= "table" then return end
    local container = unitFrame.HealthBarsContainer
    if type(container) == "table" then
      if visibleHealthBar(container.healthBar) then return container.healthBar, "UnitFrame.HealthBarsContainer.healthBar" end
      if visibleHealthBar(container.HealthBar) then return container.HealthBar, "UnitFrame.HealthBarsContainer.HealthBar" end
    end
    if visibleHealthBar(unitFrame.healthBar) then return unitFrame.healthBar, "UnitFrame.healthBar" end
    if visibleHealthBar(unitFrame.HealthBar) then return unitFrame.HealthBar, "UnitFrame.HealthBar" end
  end)
  if ok and bar then return bar, path end
  return autoHealthBar(plate)
end

-- Bottom and top of a widget seated with the live formula, positive y up.
function Plate.Span(offset, height)
  local top = -(tonumber(offset) or 0)
  local h = tonumber(height) or 0
  if h < 0 then h = 0 end
  return top - h, top
end

-- True when the two bodies share any vertical space. Touching edges do not count.
function Plate.Clash(offsetA, heightA, offsetB, heightB)
  local a0, a1 = Plate.Span(offsetA, heightA)
  local b0, b1 = Plate.Span(offsetB, heightB)
  return a0 < b1 and b0 < a1
end

local function moduleSettings(name)
  if type(BIT.DB) ~= "function" then return nil end
  local saved = BIT.DB()
  local modules = type(saved) == "table" and saved.modules or nil
  local s = type(modules) == "table" and modules[name] or nil
  if type(s) ~= "table" then return nil end
  return s
end

-- Hunter rail offset, combo-dot offset, shard offset. Missing saved values are the defaults.
function Plate.ReadOffsets()
  local hunter = -60
  local hs = moduleSettings("HunterRangeFinder")
  if hs and type(hs.plateOffset) == "number" then hunter = hs.plateOffset end
  local dots, shards = -60, -60
  local rd = UsefulPlatesAndTooltips_ResourceDingDB
  if type(rd) == "table" then
    if type(rd.dotOffset) == "number" then dots = rd.dotOffset end
    if type(rd.shardOffset) == "number" then shards = rd.shardOffset end
  end
  return hunter, dots, shards
end

-- The hunter rail is actually on the plate: the module is running, the player is a hunter,
-- and the rail is attached. A non-hunter keeps the Range check even if this module is on.
function Plate.HunterOwnsNameplate(plate)
  if plate then
    local hunter = BIT.modules and BIT.modules.HunterRangeFinder
    return hunter and type(hunter.OwnsNameplate) == "function" and hunter.OwnsNameplate(plate) or false
  end
  if type(BIT.IsRunning) ~= "function" or not BIT.IsRunning("HunterRangeFinder") then return false end
  local class
  if type(UnitClass) == "function" then
    class = select(2, UnitClass("player"))
  end
  if type(issecretvalue) == "function" and issecretvalue(class) then return false end
  if class ~= "HUNTER" then return false end
  local s = moduleSettings("HunterRangeFinder")
  if s and s.attachToPlate == false then return false end
  return true
end

-- DoTInfo has a marker's worth of damage on this unit. Shields use it to yield the fill.
function Plate.DotOnUnit(unit)
  if type(unit) ~= "string" then return false end
  if type(BIT.IsRunning) ~= "function" or not BIT.IsRunning("DoTInfo") then return false end
  local dot = BIT.modules and BIT.modules.DoTInfo
  if type(dot) ~= "table" or type(dot.HasMarker) ~= "function" then return false end
  local ok, on = pcall(dot.HasMarker, unit)
  return ok and on == true
end

-- A refresh is due when time left is still positive and inside the largest of one tick,
-- three seconds, and a quarter of the duration.
function Plate.RefreshDue(remaining, duration, interval)
  remaining = tonumber(remaining)
  if not remaining or remaining <= 0 then return false end
  duration = tonumber(duration) or 0
  interval = tonumber(interval) or 0
  if interval < 0 then interval = 0 end
  local portion = duration > 0 and duration * 0.25 or 0
  local window = math.max(interval, 3, portion)
  return remaining <= window
end

-- Available indicator rows on this character, independent of whether a target
-- currently exists. These dimensions drive the settings overlap warnings.
function Plate.Rows()
  local function on(name)
    return BIT.IsRunning(name) or (BIT.woke and BIT.woke[name] == true)
  end
  local hunter, dots, shards = Plate.ReadOffsets()
  local rd = UsefulPlatesAndTooltips_ResourceDingDB or {}
  local size = math.min(24, math.max(8, tonumber(rd.dotSize) or 14))
  local resource = BIT.modules and BIT.modules.ResourceDing
  local kind = resource and resource.GetResource and resource.GetResource()
  local hasPoints = false
  if kind and type(resource.GetResourceState) == "function" then
    local ok, _, _, maximum = pcall(resource.GetResourceState)
    hasPoints = ok and type(maximum) == "number" and maximum > 0
  end
  local class = type(UnitClass) == "function" and select(2, UnitClass("player"))
  local catForm = false
  if class == "DRUID" and type(GetShapeshiftFormID) == "function" then
    local ok, form = pcall(GetShapeshiftFormID)
    if ok then
      local readable = true
      if type(issecretvalue) == "function" then
        local checked, secret = pcall(issecretvalue, form)
        readable = checked and not secret
      end
      catForm = readable and form == 1
    end
  end
  local classicShards = resource and type(resource.IsClassic) == "function" and resource.IsClassic()
  local hasDiamonds = on("ResourceDing") and rd.enabled ~= false and rd.shardDiamonds ~= false
    and class == "WARLOCK" and (classicShards or hasPoints)
  local hs = moduleSettings("HunterRangeFinder") or {}
  return {
    hunter = { on = on("HunterRangeFinder") and class == "HUNTER" and hs.attachToPlate ~= false,
      offset = hunter, height = Plate.HUNTER_RAIL_HEIGHT },
    dots = { on = on("ResourceDing") and rd.enabled ~= false and rd.dots ~= false and hasPoints
      and not hasDiamonds and (class ~= "DRUID" or catForm),
      offset = dots, height = size },
    shards = { on = hasDiamonds,
      offset = shards, height = size },
  }
end

function Plate.ClashText(rows)
  rows = rows or Plate.Rows()
  local parts = {}
  local function check(a, b, text)
    if a.on and b.on and Plate.Clash(a.offset, a.height, b.offset, b.height) then
      parts[#parts + 1] = text
    end
  end
  check(rows.hunter, rows.dots, "Hunter rail overlaps combo dots.")
  check(rows.hunter, rows.shards, "Hunter rail overlaps shard diamonds.")
  check(rows.dots, rows.shards, "Combo dots overlap shard diamonds.")
  if #parts == 0 then return "Nameplate lanes are clear." end
  return table.concat(parts, " ")
end
