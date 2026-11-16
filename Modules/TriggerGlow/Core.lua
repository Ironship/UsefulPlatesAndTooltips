-- UsefulPlatesAndTooltips module TriggerGlow (experimental): a glow on the action bar button of a spell whose
-- moment has come, the way Blizzard glows a proc. Three kinds of moment (Data.lua):
--   * the target is at or below a share of its health (Execute, Hammer of Wrath)
--   * a friendly target is below a share of its health (Divine Grace)
--   * the game says the spell can be cast now (Overpower, Revenge, Mongoose Bite, Counterattack, Victory Rush)
-- Copyright (c) 2026 Ironship. GPL-3.0-or-later, see LICENSE.
--
-- The glow is a frame of ours hanging on the button. Blizzard's own alert manager is never called: it belongs
-- to secure code (our call would taint it) and its UpdateSpellAlert hides an alert whose spell is not a proc.
--
-- The target's health is hidden from addons in a fight (UnitHealth and UnitHealthPercent return secret values).
-- UnitHealthPercent(unit, false, curve) hands the percentage to a curve the client evaluates itself, and the
-- result goes straight into SetAlpha, which accepts a secret value: the glow is opaque at or below the share and
-- invisible above it, without the addon ever reading the number. The same call works when the value is readable.

local ADDON_NAME, BIT = ...
local ns = BIT.Module("TriggerGlow")

local DEFAULTS = {
  hp = true,              -- Execute, Hammer of Wrath
  heal = true,            -- Divine Grace
  reactive = true,        -- Overpower, Revenge, Mongoose Bite, Counterattack, Victory Rush
  spells = {},            -- [rule key] = false switches one spell off
  executePct = 20,        -- the share of the enemy's health the window opens at
  healPct = 50,           -- the share of a friend's health a heal is wanted below
  needResources = false,  -- also ask the game whether the spell can be cast (enough rage, mana)
  combatOnly = false,
  style = "blizzard",     -- "blizzard" (the proc animation) | "border" (a pulsing frame)
  hpColor = "native",
  healColor = "native",
  reactiveColor = "native",
  size = 140,             -- glow size, % of the button (Blizzard's proc glow is 140)
  opacity = 100,
  debug = false,
  log = {},
}
ns.DEFAULTS = DEFAULTS

local settings
local MAX_LOG = 150

local function trace(msg)
  if not settings then return end
  local log = settings.log
  if type(log) ~= "table" then log = {}; settings.log = log end
  log[#log + 1] = string.format("%.1f %s", GetTime and GetTime() or 0, msg)
  if #log > MAX_LOG then table.remove(log, 1) end
  if settings.debug then print("|cff888888TriggerGlow: " .. msg .. "|r") end
end
ns.trace = trace

local function isSecret(v)
  if type(issecretvalue) ~= "function" then return false end
  local ok, secret = pcall(issecretvalue, v)
  return ok and secret == true
end

-- A yes/no question to the client: true, false, or nil when it errors or the answer is hidden.
local function ask(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, v = pcall(fn, ...)
  if not ok or isSecret(v) or v == nil then return nil end
  return v and true or false
end

local function readNumber(obj, method)
  if type(obj[method]) ~= "function" then return nil end
  local ok, v = pcall(obj[method], obj)
  if ok and not isSecret(v) and type(v) == "number" then return v end
  return nil
end

---------------------------------------------------------------------------------------------
-- Settings in use
---------------------------------------------------------------------------------------------

local function cfg() return settings or DEFAULTS end

-- BIT.Settings hands a table default over as it is; these two belong to the saved settings alone.
local function prepareSettings()
  settings = BIT.Settings("TriggerGlow", DEFAULTS)
  if settings.spells == DEFAULTS.spells then settings.spells = {} end
  if settings.log == DEFAULTS.log then settings.log = {} end
  ns.settings = settings
end

local function clampNumber(v, lo, hi, fallback)
  v = tonumber(v)
  if not v or v ~= v then return fallback end
  if v < lo then return lo elseif v > hi then return hi end
  return v
end

local function opacity() return clampNumber(cfg().opacity, 10, 100, 100) / 100 end
local function ruleEnabled(rule)
  local c = cfg()
  if c[rule.group] == false then return false end
  return type(c.spells) ~= "table" or c.spells[rule.key] ~= false
end
local function rulePct(rule)
  local c = cfg()
  if rule.pctKey == "healPct" then return clampNumber(c.healPct, 5, 95, 50) end
  return clampNumber(c.executePct, 5, 60, 20)
end

local function colorOf(rule)
  local group
  for _, g in ipairs(ns.GROUPS) do if g.id == rule.group then group = g end end
  local id = group and cfg()[group.colorKey]
  local rgb = id and id ~= "native" and BIT.Looks and BIT.Looks.Rgb and BIT.Looks.Rgb(id)
  return rgb or nil
end

---------------------------------------------------------------------------------------------
-- Spell on a button
---------------------------------------------------------------------------------------------

local function spellOnSlot(slot)
  if isSecret(slot) or type(slot) ~= "number" or type(GetActionInfo) ~= "function" then return nil end
  local ok, kind, id, sub = pcall(GetActionInfo, slot)
  if not ok or isSecret(kind) or isSecret(id) or isSecret(sub) then return nil end
  if kind == "spell" and type(id) == "number" then return id end
  -- a /cast macro reports ("macro", spellID, "spell")
  if kind == "macro" and sub == "spell" and type(id) == "number" then return id end
  return nil
end

local spellNames = {}
local function nameOf(id)
  local name = spellNames[id]
  if name then return name end
  if type(C_Spell) == "table" and type(C_Spell.GetSpellName) == "function" then
    local ok, v = pcall(C_Spell.GetSpellName, id)
    if ok and not isSecret(v) and type(v) == "string" and v ~= "" then name = v end
  elseif type(GetSpellInfo) == "function" then
    local ok, v = pcall(GetSpellInfo, id)
    if ok and not isSecret(v) and type(v) == "string" and v ~= "" then name = v end
  end
  if name then spellNames[id] = name end
  return name
end

-- The client's name of every rule's spells, for a rank the data does not list.
local nameRules = {}
local nameRulesBuilt = 0
local function buildNameRules()
  local missing = 0
  for _, rule in ipairs(ns.RULES) do
    for _, id in ipairs(rule.ids) do
      local name = nameOf(id)
      if name then nameRules[name] = rule else missing = missing + 1 end
    end
  end
  nameRulesBuilt = (GetTime and GetTime() or 0)
  return missing
end

local function ruleFor(spellID)
  local rule = ns.ById[spellID]
  if rule then return rule end
  if next(nameRules) == nil or (GetTime and GetTime() - nameRulesBuilt > 30) then buildNameRules() end
  local name = nameOf(spellID)
  return name and nameRules[name] or nil
end
ns.RuleFor = ruleFor

---------------------------------------------------------------------------------------------
-- Action buttons (the same bars SpellDamageInfo draws its numbers on, found independently)
---------------------------------------------------------------------------------------------

local BAR_PREFIXES = {
  "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarLeftButton",
  "MultiBarRightButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button", "BonusActionButton",
  "MultiCastActionButton", "OverrideActionBarButton",
}

local buttons, seenButton = {}, {}
local gamepadButtons, euiButtons, labButtons = {}, {}, {}
local labHooked, labOwner, gamepadHosts = {}, {}, {}
local scheduleRescan

local function labLibraries()
  local libs = {}
  if type(LibStub) ~= "table" or type(LibStub.IterateLibraries) ~= "function" then return libs end
  local ok, iter, state, key = pcall(LibStub.IterateLibraries, LibStub)
  if not ok or type(iter) ~= "function" then return libs end
  for name, lib in iter, state, key do
    if type(name) == "string" and name:find("^LibActionButton%-1%.0") and type(lib) == "table" then
      libs[#libs + 1] = lib
    end
  end
  return libs
end

local function addButton(b)
  if type(b) == "table" and not seenButton[b] and type(b.GetObjectType) == "function" then
    seenButton[b] = true
    buttons[#buttons + 1] = b
  end
end

local function collectButtons()
  local prefixes, seenPrefix = {}, {}
  local function addPrefix(p)
    if type(p) == "string" and not seenPrefix[p] then
      seenPrefix[p] = true
      prefixes[#prefixes + 1] = p
    end
  end
  if type(ActionButtonUtil) == "table" and type(ActionButtonUtil.ActionBarButtonNames) == "table" then
    for _, p in ipairs(ActionButtonUtil.ActionBarButtonNames) do addPrefix(p) end
  end
  for _, p in ipairs(BAR_PREFIXES) do addPrefix(p) end
  for _, prefix in ipairs(prefixes) do
    for i = 1, 12 do addButton(_G[prefix .. i]) end
  end
  if type(EllesmereUI) == "table" or type(EABButton1) == "table" then
    for i = 1, 180 do
      local b = _G["EABButton" .. i]
      if type(b) == "table" then euiButtons[b] = true; addButton(b) end
    end
  end
  for _, lib in ipairs(labLibraries()) do
    local found
    if type(lib.GetAllButtons) == "function" then
      local ok, result, state, key = pcall(lib.GetAllButtons, lib)
      if ok and type(result) == "table" then
        found = result
      elseif ok and type(result) == "function" then
        found = {}
        for b in result, state, key do found[b] = true end
      end
    end
    if not found and type(lib.buttonRegistry) == "table" then found = lib.buttonRegistry end
    if found then
      for b in pairs(found) do
        if type(b) == "table" and not seenButton[b] then labButtons[b] = true; addButton(b) end
      end
    end
    if not labHooked[lib] and type(lib.RegisterCallback) == "function" then
      labHooked[lib] = true
      pcall(lib.RegisterCallback, labOwner, "OnButtonCreated", function() scheduleRescan() end)
      pcall(lib.RegisterCallback, labOwner, "OnButtonContentsChanged", function() scheduleRescan() end)
    end
  end
  -- Forever's native crossbar keeps its buttons in page units, outside ActionButton1..12.
  local host = GamepadMainActionBarFrame
  local page = type(host) == "table" and host.PageUnit
  local bars = type(page) == "table" and page.actionBars
  if type(bars) == "table" then
    for _, bar in pairs(bars) do
      if type(bar) == "table" and type(bar.actionButtons) == "table" then
        for _, b in ipairs(bar.actionButtons) do
          if type(b) == "table" and type(b.CalculateAction) == "function" then
            gamepadButtons[b] = true
            addButton(b)
          end
        end
      end
    end
    if not gamepadHosts[host] then
      gamepadHosts[host] = true
      -- hooksecurefunc keeps our callback out of Blizzard's page-change table; the work waits for the timer.
      if type(hooksecurefunc) == "function" and type(page.OnPageChange) == "function" then
        pcall(hooksecurefunc, page, "OnPageChange", function() scheduleRescan() end)
      end
      if type(host.HookScript) == "function" then pcall(host.HookScript, host, "OnShow", function() scheduleRescan() end) end
    end
  end
end

local function slotOf(button)
  local slot = button.action
  if not isSecret(slot) and type(slot) == "number" and slot > 0 then return slot end
  if type(button.CalculateAction) == "function" then
    local ok, value = pcall(button.CalculateAction, button)
    if ok and not isSecret(value) and type(value) == "number" and value > 0 then return value end
  end
  return nil
end

-- A LibActionButton button holds an action slot, or a spell or macro of its own.
local function labSpell(button)
  if type(button.GetAction) ~= "function" then return nil end
  local ok, kind, action = pcall(button.GetAction, button)
  if not ok or isSecret(kind) or isSecret(action) then return nil end
  if kind == "action" then
    if type(action) == "number" and action > 0 then return spellOnSlot(action) end
  elseif kind == "spell" then
    if type(action) == "number" then return action end
  elseif kind == "macro" then
    if type(action) == "number" and type(GetMacroSpell) == "function" then
      local okm, id = pcall(GetMacroSpell, action)
      if okm and not isSecret(id) and type(id) == "number" then return id end
    end
  end
  return nil
end

local function buttonSpell(button)
  if gamepadButtons[button] then
    local ok, value = pcall(button.CalculateAction, button)
    if ok and not isSecret(value) then return spellOnSlot(value) end
    return nil
  elseif euiButtons[button] then
    if type(button.GetAttribute) ~= "function" then return nil end
    local ok, value = pcall(button.GetAttribute, button, "action")
    if ok and not isSecret(value) and type(value) == "number" and value > 0 then return spellOnSlot(value) end
    return nil
  elseif labButtons[button] then
    return labSpell(button)
  end
  return spellOnSlot(slotOf(button))
end

---------------------------------------------------------------------------------------------
-- The glow frame
---------------------------------------------------------------------------------------------

local glows = setmetatable({}, { __mode = "k" })       -- [button] = { blizzard = frame, border = frame }
local sampleGlows = setmetatable({}, { __mode = "k" }) -- the same for the frames of the settings sample

local function currentStyle()
  return cfg().style == "border" and "border" or "blizzard"
end

local function buttonSize(button)
  local w, h = readNumber(button, "GetWidth"), readNumber(button, "GetHeight")
  if not w or w < 8 then w = 45 end
  if not h or h < 8 then h = w end
  return w, h
end

local function createGlow(button, kind)
  local f
  if kind == "blizzard" then
    local ok, frame = pcall(CreateFrame, "Frame", nil, button, "ActionButtonSpellAlertTemplate")
    if ok and type(frame) == "table" and frame.ProcLoop and frame.ProcLoopFlipbook then
      f = frame
      f.glowKind = "blizzard"
      -- Blizzard's template binds OnHide twice and never OnShow: a bar that is hidden and shown again would
      -- leave the loop stopped on its first frame.
      f:SetScript("OnShow", function(self)
        local start = self.ProcStartAnim
        if self.ProcLoop and not self.ProcLoop:IsPlaying() and not (start and start:IsPlaying()) then
          self.ProcLoop:Play()
        end
      end)
    end
  end
  if not f then
    f = CreateFrame("Frame", nil, button)
    f:Hide()
    local t = f:CreateTexture(nil, "OVERLAY")
    t:SetAllPoints()
    t:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    t:SetBlendMode("ADD")
    f.border = t
    local pulse = t:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local a = pulse:CreateAnimation("Alpha")
    a:SetFromAlpha(1)
    a:SetToAlpha(0.35)
    a:SetDuration(0.5)
    f.pulse = pulse
    f.glowKind = "border"
    f:SetScript("OnShow", function(self) if self.pulse then self.pulse:Play() end end)
    f:SetScript("OnHide", function(self) if self.pulse then self.pulse:Stop() end end)
  end
  f.on = false
  return f
end

-- Size and tint, applied when the glow is shown and whenever a setting changed.
local function styleGlow(f, button, rule)
  local w, h = buttonSize(button)
  local scale = clampNumber(cfg().size, 100, 250, 140) / 100
  local rgb = rule and colorOf(rule)
  local key = string.format("%d/%d/%.2f/%s", w, h, scale, rgb and table.concat(rgb, ",") or "native")
  if f.styleKey == key then return end
  f.styleKey = key
  f:ClearAllPoints()
  f:SetPoint("CENTER", button, "CENTER", 0, 0)
  if f.glowKind == "blizzard" then
    f:SetSize(w * scale, h * scale)
    local r, g, b = 1, 1, 1
    if rgb then r, g, b = rgb[1], rgb[2], rgb[3] end
    for _, region in ipairs({ f.ProcStartFlipbook, f.ProcLoopFlipbook, f.ProcAltGlow }) do
      if region then region:SetVertexColor(r, g, b) end
    end
  else
    f:SetSize(w * scale * 1.35, h * scale * 1.35)
    local r, g, b = 1, 0.85, 0.35
    if rgb then r, g, b = rgb[1], rgb[2], rgb[3] end
    f.border:SetVertexColor(r, g, b)
  end
end

local function showGlow(f)
  if f.on then return end
  f.on = true
  f:Show()
  if f.glowKind == "blizzard" then
    if f.ProcStartAnim then f.ProcStartAnim:Play() else f.ProcLoop:Play() end
  elseif f.pulse then
    f.pulse:Play()
  end
end

local function hideGlow(f)
  if not f.on then return end
  f.on = false
  if f.ProcStartAnim then f.ProcStartAnim:Stop() end
  if f.ProcLoop then f.ProcLoop:Stop() end
  if f.pulse then f.pulse:Stop() end
  f:Hide()
end

local function glowFor(button, store)
  store = store or glows
  local set = store[button]
  if not set then set = {}; store[button] = set end
  local kind = currentStyle()
  local f = set[kind]
  if not f then f = createGlow(button, kind); set[kind] = f end
  -- the other style never stays up
  for k, other in pairs(set) do
    if k ~= kind and other.on then hideGlow(other) end
  end
  return f
end

-- The same glow on any frame, for the settings sample: ns.SampleGlow(frame, rule, on, alpha).
function ns.SampleGlow(frame, rule, on, alpha)
  local f = glowFor(frame, sampleGlows)
  f.styleKey = nil
  styleGlow(f, frame, rule)
  if on then
    showGlow(f)
    f:SetAlpha(alpha or opacity())
  else
    hideGlow(f)
  end
end

---------------------------------------------------------------------------------------------
-- What opens a window
---------------------------------------------------------------------------------------------

-- A curve the client evaluates against the target's health share: `level` at or below the share, 0 a hair above
-- it. Linear with a ramp of 0.3 % points, so it does not depend on how a step curve treats its edge.
local curves = {}
local function curveFor(pct, level)
  if type(C_CurveUtil) ~= "table" or type(C_CurveUtil.CreateCurve) ~= "function" then return nil end
  local key = string.format("%.3f/%.3f", pct, level)
  local curve = curves[key]
  if curve then return curve end
  local ok, c = pcall(C_CurveUtil.CreateCurve)
  if not ok or type(c) ~= "table" then return nil end
  if type(c.SetType) == "function" and type(Enum) == "table" and type(Enum.LuaCurveType) == "table" then
    pcall(c.SetType, c, Enum.LuaCurveType.Linear)
  end
  local edge = pct / 100
  pcall(c.AddPoint, c, 0, level)
  pcall(c.AddPoint, c, edge, level)
  pcall(c.AddPoint, c, math.min(1, edge + 0.003), 0)
  if edge + 0.003 < 1 then pcall(c.AddPoint, c, 1, 0) end
  curves[key] = c
  return c
end

local function usableNow(spellID)
  if type(C_Spell) == "table" and type(C_Spell.IsSpellUsable) == "function" then
    local ok, usable, noPower = pcall(C_Spell.IsSpellUsable, spellID)
    if ok and not isSecret(usable) and usable ~= nil then return usable and true or false, noPower and true or false end
    return nil
  end
  if type(IsUsableSpell) == "function" then
    local ok, usable, noPower = pcall(IsUsableSpell, spellID)
    if ok and not isSecret(usable) and usable ~= nil then return usable and true or false, noPower and true or false end
  end
  return nil
end

-- Is "target" a unit this rule is about? Unknown answers (a hidden value) do not rule a target out.
local function targetFits(rule)
  if ask(UnitExists, "target") ~= true then return false end
  if ask(UnitIsDead, "target") == true then return false end
  if rule.target == "friend" then
    if ask(UnitCanAssist, "player", "target") == false then return false end
    if rule.notSelf and ask(UnitIsUnit, "target", "player") == true then return false end
  else
    if ask(UnitCanAttack, "player", "target") == false then return false end
  end
  return true
end

-- The glow's opacity for the target's health: true and a number or a secret value, or false when nothing can
-- be said. A secret value is never compared, not even with nil.
local function healthAlpha(rule)
  local pct, level = rulePct(rule), opacity()
  local curve = curveFor(pct, level)
  if curve and type(UnitHealthPercent) == "function" then
    local ok, a = pcall(UnitHealthPercent, "target", false, curve)
    if ok and (isSecret(a) or type(a) == "number") then return true, a end
  end
  -- Without the client's curve: the plain numbers, when they can be read.
  if type(UnitHealth) == "function" and type(UnitHealthMax) == "function" then
    local ok1, h = pcall(UnitHealth, "target")
    local ok2, m = pcall(UnitHealthMax, "target")
    if ok1 and ok2 and not isSecret(h) and not isSecret(m) and type(h) == "number" and type(m) == "number" and m > 0 then
      return true, (h / m * 100 <= pct) and level or 0
    end
  end
  return false
end
ns.HealthAlpha = healthAlpha

local active = {}      -- list of { button, rule, spell }
local activeBy = {}    -- [button] = entry
local testUntil = 0

-- Whether the entry's glow is up, and with which opacity.
local function windowFor(entry)
  local rule = entry.rule
  if not ruleEnabled(rule) then return false end
  if cfg().combatOnly and ask(UnitAffectingCombat, "player") == false then return false end
  if rule.target then
    if not targetFits(rule) then return false end
    if cfg().needResources then
      local usable = usableNow(entry.spell)
      if usable == false then return false end
    end
    local has, a = healthAlpha(rule)
    if not has then return false end
    return true, a
  end
  local usable = usableNow(entry.spell)
  if usable == true then return true, opacity() end
  return false
end

local lastState = setmetatable({}, { __mode = "k" })

local function updateEntry(entry, testing)
  local on, alpha
  if testing then on, alpha = true, opacity() else on, alpha = windowFor(entry) end
  local button = entry.button
  local f = glows[button] and glows[button][currentStyle()]
  if on then
    f = glowFor(button)
    styleGlow(f, button, entry.rule)
    showGlow(f)
    f:SetAlpha(alpha)
  elseif f and f.on then
    hideGlow(f)
  end
  if lastState[button] ~= (on and true or false) then
    lastState[button] = on and true or false
    if not testing then
      trace(string.format("%s %s on %s", on and "GLOW" or "off", entry.rule.key, tostring(button:GetName() or "button")))
    end
  end
end

local function updateAll()
  local testing = testUntil > (GetTime and GetTime() or 0)
  for _, entry in ipairs(active) do updateEntry(entry, testing) end
end
ns.Update = updateAll

local function rescan()
  collectButtons()
  local list, by = {}, {}
  for _, b in ipairs(buttons) do
    local spell = buttonSpell(b)
    if spell then
      local rule = ruleFor(spell)
      if rule then
        local entry = { button = b, rule = rule, spell = spell }
        list[#list + 1] = entry
        by[b] = entry
      end
    end
  end
  -- a button that no longer carries one of the spells loses its glow
  for b, set in pairs(glows) do
    if not by[b] then
      for _, f in pairs(set) do if f.on then hideGlow(f) end end
      lastState[b] = nil
    end
  end
  local changed = #list ~= #active
  if not changed then
    for i, e in ipairs(list) do
      local o = active[i]
      if not o or o.button ~= e.button or o.spell ~= e.spell then changed = true break end
    end
  end
  active, activeBy = list, by
  if changed then
    local names = {}
    for _, e in ipairs(list) do names[#names + 1] = e.rule.key .. "=" .. tostring(e.button:GetName() or "?") end
    trace("buttons with a glow rule: " .. (#list > 0 and table.concat(names, ", ") or "none"))
  end
  updateAll()
end
ns.Rescan = rescan

---------------------------------------------------------------------------------------------
-- Events and the timer
---------------------------------------------------------------------------------------------

local frame = CreateFrame("Frame")
local dirtyScan, dirtyUpdate = false, false
local sinceUpdate, sinceScan = 0, 0
local UPDATE_EVERY, SCAN_EVERY = 0.1, 2

scheduleRescan = function() dirtyScan = true end

local EVENTS = {
  "PLAYER_ENTERING_WORLD", "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR",
  "UPDATE_SHAPESHIFT_FORM", "UPDATE_OVERRIDE_ACTIONBAR", "SPELLS_CHANGED", "PLAYER_TALENT_UPDATE",
  "ACTIVE_TALENT_GROUP_CHANGED", "UPDATE_BINDINGS",
}
local UPDATE_EVENTS = {
  "PLAYER_TARGET_CHANGED", "ACTIONBAR_UPDATE_USABLE", "SPELL_UPDATE_USABLE", "PLAYER_REGEN_ENABLED",
  "PLAYER_REGEN_DISABLED", "UPDATE_SHAPESHIFT_FORMS",
}

local function register(event)
  return pcall(frame.RegisterEvent, frame, event)
end

local function onUpdate(_, elapsed)
  if not settings then return end
  sinceUpdate = sinceUpdate + elapsed
  sinceScan = sinceScan + elapsed
  if dirtyScan or sinceScan >= SCAN_EVERY then
    dirtyScan, sinceScan = false, 0
    rescan()
    sinceUpdate = 0
    return
  end
  if dirtyUpdate or sinceUpdate >= UPDATE_EVERY then
    dirtyUpdate, sinceUpdate = false, 0
    if #active > 0 then updateAll() end
  end
end

frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, arg1)
  if event == "ADDON_LOADED" then
    if arg1 ~= ADDON_NAME then return end
    self:UnregisterEvent("ADDON_LOADED")
    if BIT.ShouldRun and not BIT.ShouldRun("TriggerGlow") then
      ns.off = true
      self:UnregisterAllEvents()
      return
    end
    prepareSettings()
    for _, e in ipairs(EVENTS) do register(e) end
    for _, e in ipairs(UPDATE_EVENTS) do register(e) end
    -- the target's health: only the target's, not every unit's
    if not pcall(self.RegisterUnitEvent, self, "UNIT_HEALTH", "target") then register("UNIT_HEALTH") end
    pcall(self.RegisterUnitEvent, self, "UNIT_MAXHEALTH", "target")
    self:SetScript("OnUpdate", onUpdate)
    if BIT.Perf then BIT.Perf.Watch(self, "OnUpdate", "TriggerGlow") end
    dirtyScan = true
    trace(string.format("start: IsSpellUsable %s, UnitHealthPercent %s, curves %s",
      (type(C_Spell) == "table" and type(C_Spell.IsSpellUsable) == "function") and "yes" or "no",
      type(UnitHealthPercent) == "function" and "yes" or "no",
      (type(C_CurveUtil) == "table" and type(C_CurveUtil.CreateCurve) == "function") and "yes" or "no"))
    return
  end
  if not settings then return end
  for _, e in ipairs(EVENTS) do
    if event == e then dirtyScan = true return end
  end
  dirtyUpdate = true
end)

---------------------------------------------------------------------------------------------
-- Settings shared with the options tab
---------------------------------------------------------------------------------------------

ns._settings = function() return settings end
ns._defaults = function() return DEFAULTS end

-- A setting changed: styles, curves and glows are drawn again.
function ns.Apply()
  curves = {}
  for _, store in ipairs({ glows, sampleGlows }) do
    for _, set in pairs(store) do
      for _, f in pairs(set) do f.styleKey = nil end
    end
  end
  if settings then
    dirtyUpdate = true
    updateAll()
  end
  if ns.RefreshSample then ns.RefreshSample() end
end

if BIT.RegisterWaker then
  BIT.RegisterWaker("TriggerGlow", function()
    if not settings and type(BIT.Settings) == "function" then prepareSettings() end
  end)
end

---------------------------------------------------------------------------------------------
-- Test and probe
---------------------------------------------------------------------------------------------

-- Every button that carries one of the spells glows for a few seconds, whatever the target and the game say.
function ns.Test(seconds)
  if not settings then return 0 end
  rescan()
  if #active == 0 then
    BIT.Say(BIT.L("TriggerGlow: none of its spells is on your action bars (Execute, Hammer of Wrath, Divine Grace, "
      .. "Overpower, Revenge, Mongoose Bite, Counterattack, Victory Rush)."))
    return 0
  end
  testUntil = (GetTime and GetTime() or 0) + (seconds or 6)
  updateAll()
  if C_Timer and type(C_Timer.After) == "function" then
    C_Timer.After((seconds or 6) + 0.2, function() updateAll() end)
  end
  BIT.Say(string.format(BIT.L("TriggerGlow: test glow on %d button(s) for %d seconds."), #active, seconds or 6))
  return #active
end

local function shown(v)
  if v == nil then return "nil" end
  if isSecret(v) then return "secret" end
  if type(v) == "number" then return string.format("%.3f", v) end
  return tostring(v)
end

function ns.Probe()
  local lines = {}
  local function add(s) lines[#lines + 1] = s end
  if not settings then add("TriggerGlow is switched off (/reload after switching it on).") return lines end
  rescan()
  add(string.format("API: C_Spell.IsSpellUsable %s, UnitHealthPercent %s, C_CurveUtil %s, ActionButtonSpellAlertTemplate frame %s",
    (type(C_Spell) == "table" and type(C_Spell.IsSpellUsable) == "function") and "yes" or "no",
    type(UnitHealthPercent) == "function" and "yes" or "no",
    (type(C_CurveUtil) == "table" and type(C_CurveUtil.CreateCurve) == "function") and "yes" or "no",
    (function()
      local ok, f = pcall(CreateFrame, "Frame", nil, UIParent, "ActionButtonSpellAlertTemplate")
      if ok and f then f:Hide(); return f.ProcLoop and "yes" or "frame without ProcLoop" end
      return "no"
    end)()))
  add(string.format("style %s, size %s%%, opacity %s%%; target exists %s, can attack %s",
    currentStyle(), shown(cfg().size), shown(cfg().opacity),
    shown(ask(UnitExists, "target")), shown(ask(UnitCanAttack, "player", "target"))))
  if #active == 0 then add("no button carries Execute, Hammer of Wrath, Divine Grace, Overpower, Revenge, Mongoose Bite, Counterattack or Victory Rush") end
  for _, e in ipairs(active) do
    local name = e.button:GetName() or "?"
    local line = string.format("%s: %s (spell %d, %s) enabled %s", name, e.rule.key, e.spell, tostring(nameOf(e.spell)),
      tostring(ruleEnabled(e.rule)))
    local usable, noPower = usableNow(e.spell)
    line = line .. string.format(", usable %s (not enough resource %s)", shown(usable), shown(noPower))
    if e.rule.target then
      local curve = curveFor(rulePct(e.rule), opacity())
      local ok, a = false, nil
      if curve and type(UnitHealthPercent) == "function" then ok, a = pcall(UnitHealthPercent, "target", false, curve) end
      line = line .. string.format(", target fits %s, curve alpha %s", tostring(targetFits(e.rule)), ok and shown(a) or "n/a")
      if curve and type(curve.Evaluate) == "function" then
        local pts = {}
        for _, x in ipairs({ 0.05, rulePct(e.rule) / 100, rulePct(e.rule) / 100 + 0.01, 0.9 }) do
          local okc, y = pcall(curve.Evaluate, curve, x)
          pts[#pts + 1] = string.format("%.0f%%=%s", x * 100, okc and shown(y) or "err")
        end
        line = line .. "; curve " .. table.concat(pts, " ")
      end
    end
    local set = glows[e.button]
    local f = set and set[currentStyle()]
    line = line .. string.format(", glow %s", f and (f.on and "UP" or "down") or "not built")
    add(line)
  end
  return lines
end

if BIT.RegisterCommand then
  BIT.RegisterCommand("glowprobe", function()
    for _, line in ipairs(ns.Probe()) do print(line) end
  end)
  BIT.RegisterCommand("glowtest", function() ns.Test(6) end)
end
