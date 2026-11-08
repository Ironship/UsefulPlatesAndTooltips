local frames, chat, now = {}, {}, 100

local function widget(parent)
  local w = { parent = parent, children = {}, shown = false, width = 150, height = 20 }
  if parent then parent.children[#parent.children + 1] = w end
  function w:CreateFontString()
    return widget(self)
  end
  function w:SetStatusBarTexture(path)
    local texture = rawget(self, "statusTexture")
    if not texture then
      texture = widget(self)
      rawset(self, "statusTexture", texture)
    end
    texture.path = path
  end
  function w:GetStatusBarTexture()
    local texture = rawget(self, "statusTexture")
    if not texture then
      texture = widget(self)
      rawset(self, "statusTexture", texture)
    end
    return texture
  end
  function w:SetScript(event, callback) self.scripts[event] = callback end
  function w:SetFrameLevel(value) self.frameLevel = value end
  function w:GetFrameLevel() return rawget(self, "frameLevel") or 1 end
  function w:SetWidth(value) self.width = value end
  function w:SetHeight(value) self.height = value end
  function w:GetWidth() return self.width end
  function w:GetHeight() return self.height end
  function w:SetMinMaxValues(min, max) self.min, self.max = min, max end
  function w:SetValue(value) self.value = value end
  function w:SetShown(value) self.shown = value end
  function w:Show() self.shown = true end
  function w:Hide() self.shown = false end
  function w:SetPoint(point, relative, relativePoint)
    self.points = rawget(self, "points") or {}
    self.points[point] = { relative, relativePoint }
  end
  function w:ClearAllPoints() end
  function w:SetAllPoints() end
  function w:SetClipsChildren() end
  function w:SetStatusBarColor(...) self.color = { ... } end
  function w:SetTexture(path) self.path = path end
  function w:SetHorizTile() end
  function w:SetVertTile() end
  function w:SetText(value) self.text = value end
  return setmetatable(w, { __index = function(_, key)
    if key == "scripts" then return {} end
    return function() end
  end })
end

CreateFrame = function(_, _, parent)
  local frame = widget(parent)
  frame.scripts = {}
  function frame:RegisterEvent() end
  function frame:UnregisterEvent() end
  function frame:UnregisterAllEvents() end
  frames[#frames + 1] = frame
  return frame
end
issecretvalue = function() return false end
GetTime = function() return now end
DEFAULT_CHAT_FRAME = { AddMessage = function(_, message) chat[#chat + 1] = message end }
local units = {
  player = { name = "Alistary", realm = "Realm", guid = "Player-1", exists = true, isPlayer = false, assist = false },
  target = { name = "Wolf", guid = "Creature-1", exists = true, isPlayer = false, assist = false },
  party1 = { name = "Healer", realm = "Realm", guid = "Player-2", exists = true, isPlayer = true, assist = true },
  focus = { name = "FocusFriend", realm = "Realm", guid = "Player-3", exists = true, isPlayer = true, assist = true },
  mouseover = { name = "MouseFriend", realm = "Realm", guid = "Player-4", exists = true, isPlayer = true, assist = true },
}
UnitExists = function(unit) return units[unit] and units[unit].exists or false end
UnitCanAssist = function(_, unit) return units[unit] and units[unit].assist or false end
UnitFullName = function(unit)
  local u = units[unit]
  return u and u.name, u and u.realm
end
UnitName = function(unit) return units[unit] and units[unit].name end
UnitGUID = function(unit) return units[unit] and units[unit].guid end
UnitIsPlayer = function(unit) return units[unit] and units[unit].isPlayer or false end
GetNormalizedRealmName = function() return "Realm" end
UnitIsDeadOrGhost = function() return false end
UnitHealthMax = function() return 1000 end
local incoming = { player = { own = 50, all = 50 }, party1 = { own = 100, all = 130 } }
UnitGetIncomingHeals = function(unit, healer)
  local data = incoming[unit]
  return data and (healer and data.own or data.all)
end

local settings
local ns = {}
local BIT = {
  modules = { HealPrediction = ns, SpellDamageInfo = {
    L = {}, Format = {}, DescriptionLang = function() return "de" end,
  } },
  Settings = function(_, defaults)
    settings = {}
    for key, value in pairs(defaults) do settings[key] = value end
    return settings
  end,
  ShouldRun = function() return true end,
  Say = function(message) chat[#chat + 1] = message end,
  Looks = {
    Palette = {},
    Rgb = function() return { 0.35, 1, 0.45 } end,
    Texture = function() return { path = "test", raw = false, tiled = false } end,
  },
  UI = { BarMask = { ApplyToBar = function() end, Refresh = function() end } },
}
BIT.Module = function(name) return BIT.modules[name] end
GetBuildInfo = function() return "1.60.1", "", "", 16001 end
GetSpellBonusHealing = function() return 0 end
C_Spell = {
  GetSpellDescription = function(id)
    if id == 774 then return "Heilt beim Ziel im Verlauf von 12 Sek. insgesamt 32 Gesundheit." end
  end,
  GetSpellInfo = function(id)
    if id == 774 then return { name = "Verj\195\188ngung", castTime = 0 } end
  end,
}
for _, file in ipairs({ "Parser.lua", "Parser_enUS.lua", "Parser_deDE.lua", "Estimate.lua", "Core.lua" }) do
  assert(loadfile("Modules/SpellDamageInfo/" .. file))("UsefulPlatesAndTooltips", BIT)
end
local totalHot = assert(BIT.modules.SpellDamageInfo.ComputeHot(774)).total

assert(loadfile("Modules/HealPrediction/Core.lua"))("UsefulPlatesAndTooltips", BIT)
local coreFrame = frames[#frames]
coreFrame.scripts.OnEvent(coreFrame, "ADDON_LOADED", "UsefulPlatesAndTooltips")
assert(settings.player == true, "player-frame prediction must be enabled by default")
assert(loadfile("Modules/HealPrediction/Hots.lua"))("UsefulPlatesAndTooltips", BIT)

ns.Hots.OnSent("Alistary", "cast-self", 774)
ns.Hots.OnSucceeded("cast-self", 774)
assert(ns.Hots.AmountFor("player", 3) == 8,
  "self HoT resolution must not depend on UnitCanAssist(player, player)")

ns.Hots.OnSent(nil, "cast-auto-self", 774)
ns.Hots.OnSucceeded("cast-auto-self", 774)
assert(ns.Hots.AmountFor("player", 3) == 8, "an unnamed cast with hostile target must resolve to self")

ns.Hots.OnSent("Healer", "cast-party", 774)
ns.Hots.OnSucceeded("cast-party", 774)
assert(ns.Hots.AmountFor("party1", 3) == 8, "a named party recipient must resolve to its unit frame")
ns.Hots.OnSent("FocusFriend", "cast-focus", 774)
ns.Hots.OnSucceeded("cast-focus", 774)
assert(ns.Hots.AmountFor("focus", 3) == 8, "focus recipients must resolve")
ns.Hots.OnSent("MouseFriend", "cast-mouseover", 774)
ns.Hots.OnSucceeded("cast-mouseover", 774)
assert(ns.Hots.AmountFor("mouseover", 3) == 8, "mouseover recipients must resolve")
assert(#chat == 0, "recipient diagnostics must stay out of chat outside debug mode")

units.focus = { name = "Twin", realm = "RealmA", guid = "Player-5", exists = true, isPlayer = true, assist = true }
units.party2 = { name = "Twin", realm = "RealmB", guid = "Player-6", exists = true, isPlayer = true, assist = true }
ns.Hots.OnSent("Twin", "cast-ambiguous", 774)
ns.Hots.OnSucceeded("cast-ambiguous", 774)
assert(ns.Hots.AmountFor("focus", 3) == nil and ns.Hots.AmountFor("party2", 3) == nil,
  "an ambiguous bare name must not be assigned to either same-named player")

local playerBar, partyBar = widget(), widget()
ns.UpdateBar("player", playerBar, settings.player)
ns.UpdateBar("party1", partyBar, settings.party)
local expectedHot = totalHot * settings.hotHorizon / 12
assert(playerBar.children[2].shown and playerBar.children[2].children[1].value == 50,
  "the player's direct incoming heal must draw on an enabled health bar")
assert(playerBar.children[3].shown and math.abs(playerBar.children[3].children[1].value - expectedHot) < 0.001,
  "the player's HoT must draw after the direct heal")
assert(partyBar.children[2].shown and partyBar.children[2].children[1].value == 100,
  "another player's direct incoming heal must draw")
assert(partyBar.children[3].shown and math.abs(partyBar.children[3].children[1].value - expectedHot) < 0.001,
  "another player's HoT must draw")

local sampleBar = widget()
assert(ns.DrawSample(sampleBar, 1000, 25, 12, 10), "the Heals preview should draw its sample")
assert(sampleBar.children[3].shown, "the preview should show HoTs with the setting enabled")
settings.showHots = false
assert(ns.DrawSample(sampleBar, 1000, 25, 12, 10), "the preview should redraw after a setting change")
assert(not sampleBar.children[3].shown, "the preview must follow the HoT visibility setting")

settings.showHots = true
settings.allHealers = true
settings.showText = true
assert(ns.DrawSample(sampleBar, 100, 25, 37, 10), "the preview should redraw for all-healers mode")
assert(sampleBar.children[2].children[1].value == 37 and not sampleBar.children[1].shown,
  "the all-healers preview must use the total in the primary band")
assert(sampleBar.children[2].children[1].children[2].text == "~47",
  "the preview number must include the all-healers amount and the visible HoT")
settings.target = false
assert(ns.DrawSample(sampleBar, 100, 25, 37, 10), "the preview should redraw when the target frame is disabled")
assert(not sampleBar.children[2].shown and not sampleBar.children[3].shown,
  "the target-frame option must hide the preview overlay")
settings.target = true
settings.allHealers = false
settings.debug = true
ns.Hots.OnSent("NotInGroup", "cast-unresolved", 774)
ns.Hots.OnSucceeded("cast-unresolved", 774)
assert(#chat == 1 and chat[1]:find("recipient unavailable", 1, true),
  "an unresolved recipient should be reported only when debug is enabled")

ns.Hots.Reset()
incoming.player = { own = nil, all = nil }
UnitHealthMax = function() return 111 end
playerBar:SetMinMaxValues(0, 111)
playerBar:SetValue(83)
local aura = {
  auraInstanceID = 42, name = "Verj\195\188ngung", icon = 136081, applications = 0,
  dispelName = "Magic", duration = 12, expirationTime = now + 11,
  sourceUnit = "player", spellId = 774, isFromPlayerOrPlayerPet = true, isHelpful = true,
}
C_UnitAuras = { GetAuraDataByIndex = function(unit, index, filter)
  assert(filter == "HELPFUL|PLAYER", "only own healing buffs should be queried")
  if unit == "player" and index == 1 then return aura end
end }
ns.UpdateBar("player", playerBar, true)
local hotClip = playerBar.children[3]
assert(ns.Hots.AmountFor("player", 12) == 32 * 11 / 12,
  "an existing own Rejuvenation must recover its remaining healing without a SENT event")
assert(hotClip.shown and math.abs(hotClip.children[1].value - 32 * 4 / 12) < 0.001,
  "a HoT alone on the 75%-HP player must show a nonzero horizon prediction")
assert(hotClip.points.TOPLEFT[1] == playerBar:GetStatusBarTexture(),
  "without a direct heal the HoT must anchor to health, not the empty direct-heal texture")
assert(playerBar.children[2].children[1].children[2].text == "~11",
  "Show a number must also display a HoT-only estimate")
local secret = {}
issecretvalue = function(value) return value == secret end
aura.expirationTime = secret
ns.UpdateBar("player", playerBar, true)
assert(hotClip.shown, "hidden aura timing must retain the last readable estimate")
aura.expirationTime = now + 11
C_UnitAuras.GetBuffDataByIndex = C_UnitAuras.GetAuraDataByIndex
C_UnitAuras.GetAuraDataByIndex = nil
now = now + 3
playerBar:SetValue(91)
ns.UpdateBar("player", playerBar, true)
assert(ns.Hots.AmountFor("player", 12) == 32 * 8 / 12 and hotClip.shown,
  "remaining healing must decrease after a tick, not restart the buff")
incoming.player = { own = 10, all = 10 }
ns.UpdateBar("player", playerBar, true)
assert(hotClip.points.TOPLEFT[1] == playerBar.children[2].children[1]:GetStatusBarTexture(),
  "a concurrent direct heal must move the HoT behind that heal")
incoming.player = { own = 0, all = 0 }
ns.UpdateBar("player", playerBar, true)
assert(hotClip.points.TOPLEFT[1] == playerBar:GetStatusBarTexture(),
  "ending the direct heal must return the HoT to the moving health edge")
now = now + 7
ns.UpdateBar("player", playerBar, true)
assert(math.abs(hotClip.children[1].value - 32 / 12) < 0.001,
  "the final second must shrink the displayed horizon to the remaining effect")
now = now + 1
aura = nil
ns.UpdateBar("player", playerBar, true)
assert(ns.Hots.AmountFor("player", 12) == nil and not hotClip.shown,
  "expiry must clear the prediction and hide its overlay")
aura = { spellId = 774, duration = 12, expirationTime = now + 12, sourceUnit = "party1" }
ns.UpdateBar("player", playerBar, true)
assert(not hotClip.shown, "another healer's buff must not be counted as my HoT")
aura.sourceUnit = "player"
ns.UpdateBar("player", playerBar, true)
assert(hotClip.shown, "a refreshed own buff must reappear")
aura = nil
ns.UpdateBar("player", playerBar, true)
assert(not hotClip.shown, "a readable removal must hide the HoT before its predicted expiry")
C_UnitAuras = nil
UnitBuff = function(unit, index)
  if unit == "player" and index == 1 then
    return "Verj\195\188ngung", 136081, 0, "Magic", 12, now + 12, "player", false, false, 774
  end
end
ns.UpdateBar("player", playerBar, true)
assert(hotClip.shown and ns.Hots.AmountFor("player", 3) == 8,
  "the legacy UnitBuff tuple must also recover the same healing buff")

print("HealPrediction recipient, estimate, overlay and preview checks passed.")
