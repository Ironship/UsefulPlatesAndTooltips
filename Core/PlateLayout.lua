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

local function isSecret(v)
  if type(issecretvalue) ~= "function" then return false end
  local ok, r = pcall(issecretvalue, v)
  return ok and r == true
end

local function field(tbl, key)
  return tbl[key]
end

local function readField(tbl, key)
  if type(tbl) ~= "table" then return nil end
  local ok, value = pcall(field, tbl, key)
  if ok and not isSecret(value) then return value end
end

local function read(fn, ...)
  if type(fn) ~= "function" then return end
  local ok, value = pcall(fn, ...)
  if ok and not isSecret(value) then return value end
end

-- The frame family of each unit, for EUI's global ("EllesmereUIUnitFrames_Focus") and Blizzard's
-- ("FocusFrameHealthBar"); any other unit is the target's. Blizzard's focus frame is built from the target
-- frame's template, so its bar and portrait sit at the target frame's paths.
local FRAME_PART = { player = "Player", focus = "Focus", targettarget = "TargetTarget" }

-- Hooks for other addons' frames (Core/Integrations/*.lua and public Frames API): each source returns
-- what it finds, or nothing. Every registration accepts either (fn) or (owner, fn) so external addons
-- can replace or unregister their own sources.
--   Plate.RegisterUnitFrameSource([owner,] function(unit, part) return host, bar, portrait end)
--   Plate.RegisterPlateBarSource([owner,] function(plate) return bar, path end)
--   Plate.RegisterGroupFramesSource([owner,] function(out) ... end) -- appends { unit, bar, host, kind }
--   Plate.RegisterPowerBarSource([owner,] function(unit) return bar end)
--   Plate.RegisterActionButtonSource([owner,] function(add) add(button, slotFn) end)
Plate.unitFrameSources, Plate.plateBarSources = {}, {}
Plate.groupFrameSources, Plate.powerBarSources, Plate.actionButtonSources = {}, {}, {}

local ALL_SOURCE_LISTS = {
  Plate.unitFrameSources,
  Plate.plateBarSources,
  Plate.groupFrameSources,
  Plate.powerBarSources,
  Plate.actionButtonSources,
}

local function registerSource(list, ownerOrFn, fn)
  local owner, callback
  if type(ownerOrFn) == "function" and fn == nil then
    owner, callback = ownerOrFn, ownerOrFn
  else
    assert(not isSecret(ownerOrFn) and ownerOrFn ~= nil, "Plate source registration requires an owner")
    assert(type(fn) == "function", "Plate source registration requires a function")
    owner, callback = ownerOrFn, fn
  end
  for _, entry in ipairs(list) do
    if entry.owner == owner then
      entry.fn = callback
      return
    end
  end
  list[#list + 1] = { owner = owner, fn = callback }
end

local function unregisterSource(list, owner)
  if isSecret(owner) or owner == nil then return end
  for i = #list, 1, -1 do
    if list[i].owner == owner then
      list[i].dead = true
      table.remove(list, i)
    end
  end
end

local clearPlateCaches
local actionButtonWatchers = {}

function Plate.OnActionButtonSourcesChanged(fn)
  if type(fn) == "function" then actionButtonWatchers[#actionButtonWatchers + 1] = fn end
end

local function notifyActionButtonWatchers()
  for _, fn in ipairs(actionButtonWatchers) do pcall(fn) end
end

function Plate.RegisterUnitFrameSource(ownerOrFn, fn) registerSource(Plate.unitFrameSources, ownerOrFn, fn) end
function Plate.RegisterPlateBarSource(ownerOrFn, fn)
  registerSource(Plate.plateBarSources, ownerOrFn, fn)
  if clearPlateCaches then clearPlateCaches() end
end
function Plate.RegisterGroupFramesSource(ownerOrFn, fn) registerSource(Plate.groupFrameSources, ownerOrFn, fn) end
function Plate.RegisterPowerBarSource(ownerOrFn, fn) registerSource(Plate.powerBarSources, ownerOrFn, fn) end
function Plate.RegisterActionButtonSource(ownerOrFn, fn)
  registerSource(Plate.actionButtonSources, ownerOrFn, fn)
  notifyActionButtonWatchers()
end

function Plate.UnregisterSources(owner)
  if isSecret(owner) or owner == nil then return end
  local hadButtons = false
  for _, entry in ipairs(Plate.actionButtonSources) do
    if entry.owner == owner then hadButtons = true; break end
  end
  for _, list in ipairs(ALL_SOURCE_LISTS) do unregisterSource(list, owner) end
  if clearPlateCaches then clearPlateCaches() end
  if hadButtons then notifyActionButtonWatchers() end
end

-- EUI keeps Blizzard's frames alive but hidden, so follow the profile's active source.
local function unitFrameBase(unit)
  local part = FRAME_PART[unit] or "Target"
  -- A frame the player named (Core/Frames.lua: /upt frame, DoTInfo > Behavior) comes before everything else.
  local Frames = BIT.Frames
  if Frames then
    local key = FRAME_PART[unit] and string.lower(FRAME_PART[unit]) or "target"
    local path = Frames.Get(key)
    if path ~= "" then
      local bar = Frames.Resolve(path)
      -- a path saved from a pick that landed on an overlay bar of the same frame (TempMaxHealthLoss, absorb) means its health bar
      if bar and Frames.HealthBarOf then bar = Frames.HealthBarOf(bar) end
      if bar then
        -- A replacement frame that is hidden (no target, switched off) hides the marks with it.
        if not Frames.Shown(bar) then return end
        return Frames.Root(bar, unit), bar, nil
      end
    end
  end
  -- Enhance QoL's unit frames hard-hide Blizzard's (reparented under a hidden frame, flagged _eqolUFHidden) and draw
  -- their own: EQOLUF<Part>Frame with the bar EQOLUF<Part>Health. Marks go on that bar; while its frame is not
  -- shown (no target) there is nothing to mark, and Blizzard's hidden bar must not get them.
  local blizzard = unit ~= "targettarget"
    and ((unit == "player" and PlayerFrame) or (unit == "focus" and FocusFrame) or (unit ~= "player" and unit ~= "focus" and TargetFrame))
    or nil
  if type(blizzard) == "table" and readField(blizzard, "_eqolUFHidden") == true then
    local frame, bar = _G["EQOLUF" .. part .. "Frame"], _G["EQOLUF" .. part .. "Health"]
    if type(frame) ~= "table" or type(bar) ~= "table" or read(frame.IsForbidden, frame) == true
        or read(bar.IsForbidden, bar) == true or read(frame.IsVisible, frame) ~= true then return end
    return frame, bar, nil
  end
  -- X-Perl (and its forks, which keep the frame names) hides Blizzard's frames and draws XPerl_<Part>, with the bar
  -- at .statsFrame.healthBar and the portrait in .portraitFrame. It can be loaded with one frame type switched
  -- off, so its frame only counts while it is on screen or Blizzard's carries X-Perl's own "disabled" flag.
  local perl = unit ~= "targettarget" and _G["XPerl_" .. part] or nil
  if type(perl) == "table" and read(perl.IsForbidden, perl) ~= true and (read(perl.IsVisible, perl) == true
      or (type(blizzard) == "table" and readField(blizzard, "XPerlDisabled") == true)) then
    local stats = readField(perl, "statsFrame")
    local bar = type(stats) == "table" and readField(stats, "healthBar")
    if type(bar) ~= "table" then bar = _G["XPerl_" .. part .. "statsFramehealthBar"] end
    if type(bar) == "table" and read(bar.IsForbidden, bar) ~= true then
      local portrait = readField(perl, "portraitFrame")
      if type(portrait) ~= "table" then portrait = _G["XPerl_" .. part .. "portraitFrame"] end
      if type(portrait) ~= "table" or read(portrait.IsVisible, portrait) ~= true then portrait = nil end
      return perl, bar, portrait
    end
  end
  -- Frame addons registered in Core/Integrations (ElvUI, HydraUI, DaylightUI, ...) or via the public Frames API.
  for _, entry in ipairs(Plate.unitFrameSources) do
    local ok, host, bar, portrait = pcall(entry.fn, unit, part)
    if ok then
      if isSecret(host) or type(host) ~= "table" or read(host.IsForbidden, host) == true then host = nil end
      if isSecret(bar) or type(bar) ~= "table" or read(bar.IsForbidden, bar) == true then bar = nil end
      if isSecret(portrait) or type(portrait) ~= "table" or read(portrait.IsForbidden, portrait) == true then portrait = nil end
      if host or bar then return host, bar, portrait end
    end
  end
  if unit == "targettarget" then
    local tot = _G.TargetFrameToT or (type(TargetFrame) == "table" and TargetFrame.totFrame)
    local bar = type(tot) == "table" and (tot.HealthBar or tot.healthbar or tot.healthBar)
    if type(bar) ~= "table" then bar = _G.TargetFrameToTHealthBar end
    if type(bar) == "table" and read(bar.IsVisible, bar) == false and read(UnitExists, "targettarget") == true then return end
    return tot, bar, nil
  end
  local modules = type(EllesmereUI) == "table" and EllesmereUI._ModuleNS
  local eui = type(modules) == "table" and modules.EllesmereUIUnitFrames
  local source = type(eui) == "table" and read(eui.GetUnitFrameSource, unit)
  if source == "hidden" then return end
  local custom = _G["EllesmereUIUnitFrames_" .. part]
  if source == "eui" or (source ~= "blizzard" and type(custom) == "table"
      and read(custom.IsVisible, custom) == true) then
    if type(custom) ~= "table" or read(custom.IsForbidden, custom) == true then return end
    local bar, portrait = custom.Health, custom.Portrait
    if type(bar) ~= "table" or read(bar.IsForbidden, bar) == true then return end
    if type(portrait) ~= "table" or read(portrait.IsVisible, portrait) ~= true then portrait = nil end
    return custom, bar, portrait
  end
  local frame
  if unit == "player" then frame = PlayerFrame elseif unit == "focus" then frame = FocusFrame else frame = TargetFrame end
  local content = type(frame) == "table" and (unit == "player" and frame.PlayerFrameContent or frame.TargetFrameContent)
  local main = type(content) == "table" and (unit == "player" and content.PlayerFrameContentMain or content.TargetFrameContentMain)
  local container = type(main) == "table" and main.HealthBarsContainer
  local bar = type(container) == "table" and container.HealthBar
  if type(bar) ~= "table" then bar = type(main) == "table" and main.HealthBar end
  if type(bar) ~= "table" then bar = type(frame) == "table" and frame.HealthBar end
  if type(bar) ~= "table" then bar = type(frame) == "table" and frame.healthbar end
  if type(bar) ~= "table" then bar = _G[part .. "FrameHealthBar"] end
  -- BetterBlizzFrames hides the original bar when its larger target/focus mirror is active.
  if unit ~= "player" and type(BBF) == "table" and type(frame) == "table" then
    local mirror = read(BBF.HealthBar, frame)
    if type(mirror) == "table" then bar = mirror end
  end
  -- The unit is there but Blizzard's bar is not on screen: a unit frame addon this file does not know has hidden
  -- it. Marks laid over a hidden bar float wherever that bar was left, so there is nothing to mark (a frame
  -- named with /upt frame is used above). Without the unit the frame is merely hidden, and stays the answer.
  if type(bar) == "table" and read(bar.IsVisible, bar) == false
      and read(UnitExists, FRAME_PART[unit] and unit or "target") == true then return end
  local portraitHost = type(frame) == "table" and frame.TargetFrameContainer
  local portrait = type(portraitHost) == "table" and portraitHost.Portrait
  if type(portrait) ~= "table" then portrait = _G[part .. "FramePortrait"] end
  if type(portrait) ~= "table" then portrait = type(frame) == "table" and frame.portrait end
  return frame, bar, portrait
end

-- Whether a health bar's fill runs right to left, so marks measured from "no health" start at its right edge:
-- a StatusBar with reverse fill (mirrored unit frames), or X-Perl's inverse bars, which fill with the health
-- that is missing and leave the health that remains at the right end.
function Plate.FillsReversed(bar)
  if type(bar) ~= "table" then return false end
  local reverse = read(bar.GetReverseFill, bar) == true
  local name = read(bar.GetName, bar)
  if type(name) == "string" and name:find("^XPerl_") and type(XPerlDB) == "table" then
    local inverse = read(function() return XPerlDB.bar.inverse end)
    if inverse then reverse = not reverse end
  end
  return reverse
end

-- Blizzard's Camelot unit frames make the HealthBar frame taller than the bar the player sees: it starts 3 above its
-- container (HealthBarsContainer, 126 x 15) and ends 2 below it, and the container's HealthBarMask cuts the fill to the
-- container's shape. Marks laid over the whole frame stick out above and below the visible bar (an outline, a glow), so
-- they take the container's top and bottom. Returns how far the visible bar lies inside the frame at the top and at the
-- bottom, in the frame's own units: 0, 0 for any other frame (no mask-holding container of the same width, a container
-- that is not smaller) and whenever the numbers cannot be read.
local insetCache = setmetatable({}, { __mode = "k" })
local INSET_TTL = 1 -- the frame's layout does not change from one draw to the next: asked once a second per bar

function Plate.BarInset(bar)
  if type(bar) ~= "table" then return 0, 0 end
  local now, cached = GetTime(), insetCache[bar]
  if cached and now - cached.at < INSET_TTL then return cached.top, cached.bottom end
  local top, bottom = Plate.ReadBarInset(bar)
  if cached then
    cached.top, cached.bottom, cached.at = top, bottom, now
  else
    insetCache[bar] = { top = top, bottom = bottom, at = now }
  end
  return top, bottom
end

function Plate.ReadBarInset(bar)
  local ok, top, bottom = pcall(function()
    -- The settings previews' mock bars (Core/Preview.lua) say so themselves: their parent is the whole mock frame, not a
    -- container with a mask of the bar's width, so the measurement below finds nothing.
    local declared = bar.uptBarInset
    if type(declared) == "table" then return declared[1], declared[2] end
    local container = bar:GetParent()
    if type(container) ~= "table" or container.HealthBarMask == nil then return 0, 0 end
    local values = { bar:GetTop(), bar:GetBottom(), bar:GetLeft(), bar:GetRight(),
      container:GetTop(), container:GetBottom(), container:GetLeft(), container:GetRight() }
    for i = 1, 8 do
      local v = values[i]
      if type(v) ~= "number" or (type(issecretvalue) == "function" and issecretvalue(v)) then return 0, 0 end
    end
    local barTop, barBottom, barLeft, barRight, boxTop, boxBottom, boxLeft, boxRight = unpack(values)
    local insetTop, insetBottom = barTop - boxTop, boxBottom - barBottom
    if math.abs(barLeft - boxLeft) > 1 or math.abs(barRight - boxRight) > 1 then return 0, 0 end
    if insetTop < 0 or insetBottom < 0 or insetTop + insetBottom <= 0 or insetTop + insetBottom >= (barTop - barBottom) then
      return 0, 0
    end
    return insetTop, insetBottom
  end)
  if ok and type(top) == "number" and type(bottom) == "number" then return top, bottom end
  return 0, 0
end

-- The frame, health bar and portrait of a unit's frame. The kill icon spot the player named (Core/Frames.lua) replaces
-- the portrait of the target frame, whichever frame the bar comes from.
function Plate.UnitFrame(unit)
  local host, bar, portrait = unitFrameBase(unit)
  local Frames = BIT.Frames
  if Frames and (host or bar) and unit ~= "player" and unit ~= "focus" and unit ~= "targettarget" then
    local icon = Frames.Resolve(Frames.Get("icon"))
    if icon then portrait = icon end
  end
  return host, bar, portrait
end

local function usablePowerBar(bar)
  return type(bar) == "table" and read(bar.IsForbidden, bar) ~= true and read(bar.IsVisible, bar) == true
    and read(bar.GetObjectType, bar) == "StatusBar"
end

-- The power/mana StatusBar for a unit ("player" by default), from registered integrations,
-- EllesmereUI, then Blizzard's PlayerFrame mana bar.
function Plate.PowerBar(unit)
  unit = unit or "player"
  for _, entry in ipairs(Plate.powerBarSources) do
    local ok, bar = pcall(entry.fn, unit)
    if ok and usablePowerBar(bar) then return bar end
  end
  if unit == "player" then
    local eui = _G.EllesmereUIUnitFrames_Player
    if type(eui) == "table" and usablePowerBar(eui.Power) then return eui.Power end
    local frame = _G.PlayerFrame
    local content = type(frame) == "table" and frame.PlayerFrameContent
    local main = type(content) == "table" and content.PlayerFrameContentMain
    local area = type(main) == "table" and main.ManaBarArea
    local bar = type(area) == "table" and area.ManaBar
    if usablePowerBar(bar) then return bar end
    if usablePowerBar(_G.PlayerFrameManaBar) then return _G.PlayerFrameManaBar end
  end
  return nil
end

local function validGroupUnit(unit)
  if isSecret(unit) or type(unit) ~= "string" then return false end
  return unit == "player" or unit:match("^party%d+$") ~= nil
    or unit:match("^raid%d+$") ~= nil or unit:match("^arena%d+$") ~= nil
end

local function appendGroupEntry(out, entry)
  if type(entry) ~= "table" then return end
  local unit, bar = entry.unit, entry.bar
  if not validGroupUnit(unit) or type(bar) ~= "table" or read(bar.IsForbidden, bar) == true then return end
  local host = type(entry.host) == "table" and read(entry.host.IsForbidden, entry.host) ~= true and entry.host or bar
  local kind = (entry.kind == "party" or entry.kind == "raid") and entry.kind or nil
  out[#out + 1] = { unit = unit, bar = bar, host = host, kind = kind }
end

local function collectEllesmereGroupFrames(out)
  local modules = type(EllesmereUI) == "table" and EllesmereUI._ModuleNS
  local eui = type(modules) == "table" and modules.EllesmereUIRaidFrames
  if type(eui) ~= "table" then return end
  local internals = type(eui._internals) == "table" and eui._internals
  local function addMembers(members)
    if type(members) ~= "table" then return end
    for unit, frame in pairs(members) do
      if not isSecret(unit) and type(unit) == "string" and (unit == "player"
          or unit:match("^party%d+$") or unit:match("^raid%d+$")) then
        local data = read(eui.GetFFD, frame)
        local current = type(frame) == "table" and read(frame.GetAttribute, frame, "unit")
        if current == unit and type(data) == "table" and type(data.health) == "table"
            and read(frame.IsVisible, frame) == true then
          appendGroupEntry(out, { unit = unit, bar = data.health, host = frame })
        end
      end
    end
  end
  addMembers(internals and internals.unitToButton)
  addMembers(eui._partyUnitToButton)
end

-- Addon group (party/raid) frames shared by HealPrediction, ShieldsInfo and CastPrediction:
-- EllesmereUI plus every source registered via Plate.RegisterGroupFramesSource (DaylightUI,
-- public Frames API, ...). Appends normalized { unit, bar, host, kind } entries to `out`.
function Plate.CollectGroupFrames(out)
  out = out or {}
  collectEllesmereGroupFrames(out)
  for _, entry in ipairs(Plate.groupFrameSources) do
    local collected = {}
    local ok, returned = pcall(entry.fn, collected)
    if ok then
      if type(returned) == "table" and returned ~= collected then
        for _, item in ipairs(returned) do appendGroupEntry(out, item) end
      end
      for _, item in ipairs(collected) do appendGroupEntry(out, item) end
    end
  end
  return out
end

-- Action buttons provided by registered integrations (DaylightUI, public Frames API, ...).
-- Calls add(button, slotResolver) for each valid non-forbidden button.
function Plate.CollectActionButtons(add)
  if type(add) ~= "function" then return end
  for _, entry in ipairs(Plate.actionButtonSources) do
    local current = entry
    pcall(current.fn, function(button, getSlot)
      if type(button) == "table" and read(button.IsForbidden, button) ~= true
          and type(button.GetObjectType) == "function" then
        local resolver
        if type(getSlot) == "function" then
          resolver = function(b)
            if current.dead then return nil end
            return getSlot(b)
          end
        end
        add(button, resolver)
      end
    end)
  end
end

local function visibleHealthBar(bar)
  if type(bar) ~= "table" then return false end
  if read(bar.IsForbidden, bar) == true then return false end
  if read(bar.IsVisible, bar) == false then return false end
  local alpha = read(bar.GetEffectiveAlpha, bar)
  return type(alpha) ~= "number" or alpha > 0
end

-- For the integrations: Plate.Read is the pcall reader of this file, Plate.VisibleHealthBar its visibility test.
function Plate.Read(fn, ...) return read(fn, ...) end
function Plate.VisibleHealthBar(bar) return visibleHealthBar(bar) end

local function isUnder(frame, plate)
  for _ = 1, 12 do
    frame = read(frame.GetParent, frame)
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

-- A plate with no health bar to find (a name-only plate of a friendly NPC, say) was searched again every second, one
-- walk over the plate's whole frame tree each, for every such plate on screen. A search that finds nothing now waits
-- twice as long before the next one (1, 2, 4, then 8 seconds); a plate handed to another unit starts over (below).
local FAIL_BACKOFF_STEPS = 3
local function searchWait(cached) return SEARCH_INTERVAL * 2 ^ math.min(cached.fails or 0, FAIL_BACKOFF_STEPS) end

local function autoHealthBar(plate)
  local cached, now = searchCache[plate], GetTime()
  if cached and cached.bar and visibleHealthBar(cached.bar) and isUnder(cached.bar, plate) then
    return cached.bar, cached.path
  end
  if cached and now - cached.at < searchWait(cached) then return nil, "health bar search pending" end
  local ok, bar, path = pcall(searchHealthBar, plate)
  if not ok then bar, path = nil, "health bar search unavailable" end
  searchCache[plate] = { bar = bar, path = path, at = now, fails = bar and 0 or ((cached and cached.fails or 0) + 1) }
  return bar, path or "no visible health bar found"
end

-- Threat Plates parents its plate frame to WorldFrame, so the search above never reaches it: the plate only
-- references it as plate.TPFrame (Active while Threat Plates draws the unit), with the bar at .visual.Healthbar
-- (.healthbar in older versions). Adapted from Does It Die v0.8.4.
local function threatPlatesBar(plate)
  local tp = plate.TPFrame
  if type(tp) ~= "table" or tp.Active ~= true or type(tp.visual) ~= "table" then return end
  local bar = tp.visual.Healthbar
  if not visibleHealthBar(bar) then bar = tp.visual.healthbar end
  if visibleHealthBar(bar) then return bar end
end

-- Prefer known integrations, then visible Blizzard bars, then a cached search of addon fields.
function Plate.WidgetHost(plate)
  if type(plate) ~= "table" then return nil end
  local unitFrame = readField(plate, "unitFrame")
  if type(unitFrame) == "table" and readField(unitFrame, "PlateFrame") == plate then
    return unitFrame
  end
  return plate
end

local function ellesmereChildBar(child, plate)
  if child.nameplate == plate and type(child.health) == "table" and child:IsVisible()
    and visibleHealthBar(child.health) then return child.health end
end

local function platynatorChildBar(child)
  if type(child.widgets) ~= "table" or not child:IsVisible() then return end
  for _, widget in ipairs(child.widgets) do
    if type(widget.details) == "table" and widget.details.kind == "health"
      and visibleHealthBar(widget.statusBar) then
      return widget.statusBar
    end
  end
end

local function blizzardPlateBar(plate)
  local unitFrame = plate.UnitFrame
  if type(unitFrame) ~= "table" then return end
  local container = unitFrame.HealthBarsContainer
  if type(container) == "table" then
    if visibleHealthBar(container.healthBar) then return container.healthBar, "UnitFrame.HealthBarsContainer.healthBar" end
    if visibleHealthBar(container.HealthBar) then return container.HealthBar, "UnitFrame.HealthBarsContainer.HealthBar" end
  end
  if visibleHealthBar(unitFrame.healthBar) then return unitFrame.healthBar, "UnitFrame.healthBar" end
  if visibleHealthBar(unitFrame.HealthBar) then return unitFrame.HealthBar, "UnitFrame.HealthBar" end
end

local function resolveHealthBar(plate)
  if type(plate) ~= "table" then return nil, "no nameplate" end
  if read(plate.IsForbidden, plate) == true then return nil, "forbidden nameplate" end
  local Frames = BIT.Frames
  if Frames then
    local path = Frames.Get("plate")
    if path ~= "" then
      local bar = Frames.ResolveFromPlate(plate, path)
      if bar and visibleHealthBar(bar) then return bar, "custom " .. path end
    end
  end
  for _, entry in ipairs(Plate.plateBarSources) do
    local ok, bar, path = pcall(entry.fn, plate)
    if ok and visibleHealthBar(bar) then
      return bar, (not isSecret(path) and type(path) == "string") and path or "custom source"
    end
  end
  if type(EllesmereNameplates_NS) == "table" then
    local children = { pcall(plate.GetChildren, plate) }
    if children[1] then
      for i = 2, #children do
        local ok, bar = pcall(ellesmereChildBar, children[i], plate)
        if ok and type(bar) == "table" then return bar, "EllesmereUINameplates.health" end
      end
    end
  end
  if type(Platynator) == "table" then
    local children = { pcall(plate.GetChildren, plate) }
    if children[1] then
      for i = 2, #children do
        local ok, bar = pcall(platynatorChildBar, children[i])
        if ok and type(bar) == "table" then return bar, "Platynator.widgets.health.statusBar" end
      end
    end
  end
  local host = Plate.WidgetHost(plate)
  if host ~= plate then
    local bar = readField(host, "healthBar")
    if visibleHealthBar(bar) then return bar, "Plater.unitFrame.healthBar" end
  end
  local tpOk, tpBar = pcall(threatPlatesBar, plate)
  if tpOk and tpBar then return tpBar, "ThreatPlates.TPFrame.visual.Healthbar" end
  local ok, bar, path = pcall(blizzardPlateBar, plate)
  if ok and bar then return bar, path end
  return autoHealthBar(plate)
end

-- Every module with something on a plate asks for its health bar, several of them on every tick (ShieldsInfo for every
-- plate on screen, the DoT markers, the cast marker, the range icon): the answer, a bar or none, is kept for a second
-- per plate, so the lookup above runs rarely however many ask. A plate that is handed to another unit forgets it at once.
local lookupCache = setmetatable({}, { __mode = "k" })
local rightEdgeCache = setmetatable({}, { __mode = "k" })
local LOOKUP_TTL = 1.0

clearPlateCaches = function()
  for k in pairs(lookupCache) do lookupCache[k] = nil end
  for k in pairs(searchCache) do searchCache[k] = nil end
  for k in pairs(rightEdgeCache) do rightEdgeCache[k] = nil end
end

function Plate.HealthBar(plate)
  if type(plate) ~= "table" then return nil, "no nameplate" end
  local entry, now = lookupCache[plate], GetTime()
  if entry and now - entry.at < LOOKUP_TTL then return entry.bar, entry.path end
  local bar, path = resolveHealthBar(plate)
  if entry then
    entry.bar, entry.path, entry.at = bar, path, now
  else
    lookupCache[plate] = { bar = bar, path = path, at = now }
  end
  return bar, path
end

do
  local watcher = CreateFrame("Frame")
  watcher:RegisterEvent("NAME_PLATE_UNIT_ADDED")
  watcher:SetScript("OnEvent", function(_, _, unit)
    if type(unit) ~= "string" or (type(issecretvalue) == "function" and issecretvalue(unit))
      or not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return end
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if ok and type(plate) == "table" then
      lookupCache[plate] = nil
      searchCache[plate] = nil
      rightEdgeCache[plate] = nil
    end
  end)
end

-- Blizzard's own Mouseover Cast (Options > Combat, no macro): with it on and its key held (or none set), a cast
-- goes on the mob under the mouse whatever the target is. Names cannot tell that apart: in a pack every mob shares
-- the target's name. Returns "mouseover" when such a cast would land there: the option is plainly on, the unit is
-- attackable and alive, and the cast names no other mob (sentName unreadable or empty counts as no name).
-- Adapted from Does It Die v0.9.4 (Joe Greive, MIT).
function Plate.MouseoverCastUnit(sentName)
  local getBool = (C_CVar and C_CVar.GetCVarBool) or GetCVarBool
  if read(getBool, "enableMouseoverCast") ~= true then return nil end
  local key = read(GetModifiedClick, "MOUSEOVERCAST")
  if key ~= "NONE" and read(IsModifiedClick, "MOUSEOVERCAST") ~= true then return nil end
  if read(UnitExists, "mouseover") ~= true or read(UnitCanAttack, "player", "mouseover") ~= true
      or read(UnitIsDeadOrGhost, "mouseover") == true then return nil end
  local secret = type(issecretvalue) == "function" and issecretvalue(sentName)
  if not secret and type(sentName) == "string" and sentName ~= "" and read(UnitName, "mouseover") ~= sentName then
    return nil
  end
  return "mouseover"
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
  local hunter = -52
  local hs = moduleSettings("HunterRangeFinder")
  if hs and type(hs.plateOffset) == "number" then hunter = hs.plateOffset end
  local dots, shards = -52, -52
  local rd = (type(BIT.PortedDB) == "function" and BIT.PortedDB("ResourceDing")) or UsefulPlatesAndTooltips_ResourceDingDB
  if type(rd) == "table" then
    if type(rd.dotOffset) == "number" then dots = rd.dotOffset end
    if type(rd.shardOffset) == "number" then shards = rd.shardOffset end
  end
  return hunter, dots, shards
end

-- Horizontal offset past healthBar's RIGHT edge for right-side nameplate icons so they clear
-- Blizzard's external level badge (e.g. Forever's [12] indicator) while sitting tight (+4) on
-- wide/custom plates (Plater, ElvUI, Threat Plates) that have no external right-side badge.
function Plate.RightEdgeOffset(plate, healthBar)
  if type(plate) ~= "table" or type(healthBar) ~= "table" then return 4 end
  local now = GetTime()
  local cached = rightEdgeCache[plate]
  if cached and cached.bar == healthBar and (now - cached.at) < INSET_TTL then
    return cached.value
  end
  local hr = read(healthBar.GetRight, healthBar)
  local badge = plate.uptLevelBadge
  local uf = not badge and read(function() return plate.UnitFrame end) or nil
  if type(uf) == "table" and (read(uf.IsForbidden, uf) == true or read(uf.IsVisible, uf) == false) then
    uf = nil
  end
  if not badge and type(uf) == "table" then
    badge = read(function()
      return uf.LevelFrame or uf.levelFrame or uf.LevelIndicator or uf.Level or uf.ClassificationFrame
        or (type(uf.HealthBarsContainer) == "table" and uf.HealthBarsContainer.LevelFrame)
    end)
  end
  local result
  if type(badge) == "table" and read(badge.IsShown, badge) == true and read(badge.IsVisible, badge) ~= false then
    local br = read(badge.GetRight, badge)
    if type(br) == "number" and type(hr) == "number" then
      local extra = math.floor(br - hr + 0.5)
      if extra > 0 and extra < 60 then result = extra + 4 end
    end
    result = result or (cached and cached.bar == healthBar and cached.value) or 36
  elseif type(hr) ~= "number" then
    return (cached and cached.bar == healthBar and cached.value) or 4
  else
    local ht = read(healthBar.GetTop, healthBar)
    local hb = read(healthBar.GetBottom, healthBar)
    local maxExtra = 0
    local function consider(obj)
      if type(obj) ~= "table" or obj == healthBar or read(obj.IsShown, obj) ~= true
          or read(obj.IsVisible, obj) == false then return end
      local l, r, t, b = read(obj.GetLeft, obj), read(obj.GetRight, obj), read(obj.GetTop, obj), read(obj.GetBottom, obj)
      if type(l) ~= "number" or type(r) ~= "number" or type(t) ~= "number" or type(b) ~= "number" then return end
      if r > hr + 6 and l >= hr - 6 and (r - hr) < 60 and (r - l) <= 48 and (t - b) <= 36 then
        if type(ht) ~= "number" or type(hb) ~= "number" or (t > hb - 4 and b < ht + 4) then
          local e = math.floor(r - hr + 0.5)
          if e > maxExtra then maxExtra = e end
        end
      end
    end
    local function scanContainer(c)
      if type(c) ~= "table" then return end
      for _, getter in ipairs({ c.GetChildren, c.GetRegions }) do
        if type(getter) == "function" then
          local res = { pcall(getter, c) }
          if res[1] then
            for i = 2, #res do consider(res[i]) end
          end
        end
      end
    end
    if type(uf) == "table" then
      scanContainer(uf)
      local hbc = read(function() return uf.HealthBarsContainer end)
      if type(hbc) == "table" then scanContainer(hbc) end
      local barParent = read(healthBar.GetParent, healthBar)
      if type(barParent) == "table" and barParent ~= plate and barParent ~= uf and barParent ~= hbc then
        scanContainer(barParent)
      end
    end
    result = maxExtra > 0 and (maxExtra + 4) or 4
  end
  if cached then
    cached.bar, cached.value, cached.at = healthBar, result, now
  else
    rightEdgeCache[plate] = { bar = healthBar, value = result, at = now }
  end
  return result
end

-- DoTInfo's lethal DoT damage on this unit when DoTInfo is actively showing a kill icon for that
-- surface (target frame vs nameplate). Used by CastPrediction to hide its competing kill icon.
function Plate.DotKillDamage(unit, forPlate)
  if type(unit) ~= "string" then return 0 end
  if type(BIT.IsRunning) == "function" and not BIT.IsRunning("DoTInfo") then return 0 end
  local dot = BIT.modules and BIT.modules.DoTInfo
  if type(dot) ~= "table" or type(dot.LethalKillDamage) ~= "function" then return 0 end
  local ok, amount = pcall(dot.LethalKillDamage, unit, forPlate)
  if ok and type(amount) == "number" and amount > 0 then return amount end
  return 0
end

-- Whether DoTInfo's Execute/Finisher icon is currently occupying the right-hand slot on this plate.
-- Range uses this to dock cleanly beside Execute in the same horizontal row.
function Plate.ExecuteShownOnPlate(plate)
  if type(plate) ~= "table" then return false, 0 end
  if type(BIT.IsRunning) == "function" and not BIT.IsRunning("DoTInfo") then return false, 0 end
  local dot = BIT.modules and BIT.modules.DoTInfo
  if type(dot) ~= "table" or type(dot.HasPlateExecute) ~= "function" then return false, 0 end
  local ok, shown, size = pcall(dot.HasPlateExecute, plate)
  if ok and shown then return true, tonumber(size) or 22 end
  return false, 0
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
  local rd = (type(BIT.PortedDB) == "function" and BIT.PortedDB("ResourceDing")) or UsefulPlatesAndTooltips_ResourceDingDB or {}
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
  check(rows.hunter, rows.dots, BIT.L("Hunter rail overlaps combo dots."))
  check(rows.hunter, rows.shards, BIT.L("Hunter rail overlaps shard diamonds."))
  check(rows.dots, rows.shards, BIT.L("Combo dots overlap shard diamonds."))
  if #parts == 0 then return BIT.L("Nameplate lanes are clear.") end
  return table.concat(parts, " ")
end
