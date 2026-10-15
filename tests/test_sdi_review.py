"""Exercise SDI item parsing, locale switching, count spacing, pets and secret payloads."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
fixture = (ROOT / "tests/test_bit.py").read_text(encoding="utf-8")
namespace = {"__file__": str(ROOT / "tests/test_bit.py")}
exec(compile(fixture.split('print("-- every module on")', 1)[0], "fixture", "exec"), namespace)
rt, G, BIT, _ = namespace["load"]()
rt.execute(r'''
ActionButton1 = CreateFrame("Button", "ActionButton1", UIParent)
ActionButton1:SetSize(36, 36)
ActionButton1.action = 1
ActionButton1.Count = ActionButton1:CreateFontString()
ActionButton1.Count:SetText("20")
PetActionButton1 = CreateFrame("Button", "PetActionButton1", UIParent)
function GetActionInfo(slot) if slot == 1 then return "item", 100 end end
function GetPetActionInfo(slot) return "Bite", 0, false, false, false, false, 101 end
C_ActionBar.GetActionDisplayCount = function() return "20" end
C_Item.GetItemSpell = function() return "Food", 100 end
spellDesc[100] = "Restores 1.290 health over 15 Sek."
spellDesc[101] = "Verursacht 55 Schaden."
''')
G.Fire("ADDON_LOADED", "UsefulPlatesAndTooltips")
G.Fire("PLAYER_LOGIN")
G.SDI = BIT.modules["SpellDamageInfo"]
rt.execute(r'''
local P = SDI.Parser
local items = {
  { "Restores 100 to 200 health over 2 min.", "en", 150, 120 },
  { "Stellt 100 bis 200 Gesundheit über 2 Min. wieder her.", "de", 150, 120 },
  { "Restores 100 health over 2 min.", "en", 100, 120 },
  { "Stellt 100 Gesundheit über 2 Min. wieder her.", "de", 100, 120 },
  { "Restores 1.290 health over 15 Sek.", "de", 1290, 15 },
  { "Restores 70 bis 90 health.", "de", 80 },
  { "Heals 66 damage over 6 Sek.", "de", 66, 6 },
  -- The German client's own item wordings: "Punkt(e)" between the amount and its unit, and
  -- the bandage's word order (duration before the amount) - Wolverband, healing potions, food.
  { "Benutzen: Heilt 7 Sek. lang 161 Punkt(e) Schaden.", "de", 161, 7 },
  { "Benutzen: Stellt 140 bis 180 Punkt(e) Gesundheit wieder her.", "de", 160 },
  { "Benutzen: Stellt 70 bis 90 Punkt(e) Gesundheit wieder her.", "de", 80 },
  { "Benutzen: Stellt im Verlauf von 21 Sek. 234 Punkt(e) Gesundheit wieder her. Ihr müsst beim Essen sitzen bleiben. Wenn ihr mindestens 10 Sek. mit Essen verbringt, werdet ihr satt und erhaltet 15 Min. lang 3 Stärke. Außerdem wird die durch Siege erhaltene Erfahrung um 5% erhöht. (1 Sek. Abklingzeit)", "de", 234, 21 },
  { "Benutzen: Heilt 7 Sek. lang 140 bis 180 Punkte Schaden.", "de", 160, 7 },
  { "Benutzen: Heilt 2 Sek. lang 611 Schadenspunkt(e).", "de", 611, 2 },
  { "Heilt 66 Schaden über 6 Sek.", "de", 66, 6 },
  { "Heilt 120 Gesundheit über 8 Sek.", "de", 120, 8 },
  { "Heilt 500 Schaden über 1 Min.", "de", 500, 60 },
}
for _, item in ipairs(items) do
  local v = assert(P.ParseItemHeal(item[1], item[2]), item[1])
  if item[4] then
    assert(v.hot.total == item[3] and v.hot.duration == item[4], item[1])
  else
    assert((v.heal.min + v.heal.max) / 2 == item[3], item[1])
  end
end
assert(rawget(_G, "m") == nil, "item parsing wrote a global")
assert(P.ParseItemHeal("Deals 200 Fire damage.", "en") == nil)
assert(P.ParseItemHeal("Restores 100 mana over 10 sec.", "en") == nil)
local mana = assert(P.ParseItemHeal("Restores 140 to 175 mana.", "de"))
local manaValue, manaKind = SDI.Estimate.ButtonValue(mana, "direct")
assert(manaValue == 157.5 and manaKind == "mana", "instant mana is hidden in direct mode")
local manaDE = assert(P.ParseItemHeal("Benutzen: Stellt 140 bis 175 Punkt(e) Mana wieder her.", "de"))
assert(manaDE.mana.min == 140 and manaDE.mana.max == 175, "German mana potion with Punkt(e)")
-- Malformed arithmetic used to retry the unchanged bracket forever. Bound this regression.
debug.sethook(function() error("formula parser did not terminate") end, "", 100000)
local ok, parsed = pcall(P.Parse, "Causes [1/0] Fire damage.", "en")
debug.sethook()
assert(ok and parsed == nil)
local view = assert(SDI.ComputeItem(100))
assert(view.hot.total == 1290 and view.hot.duration == 15)
-- The item's own German "Use:" line: "Punkt(e)" between the amount and its unit, and a
-- trailing cooldown clause ("(2 Min. Abklingzeit)") that is not a duration its amount ticks
-- over -- instant healing must survive both.
C_Item.GetItemSpell = function() return nil end
C_TooltipInfo = { GetHyperlink = function()
  return { lines = {
    { leftText = "Schwacher Heiltrank" },
    { leftText = "Benutzen: Stellt 70 bis 90 Punkt(e) Gesundheit wieder her. (2 Min. Abklingzeit)" },
    { leftText = "Benötigt Stufe 3" },
  } }
end }
local potion = assert(SDI.ComputeItem(5001))
assert(potion.heal.min == 70 and potion.heal.max == 90,
  "German use line with Punkt(e) and an Abklingzeit clause")
C_TooltipInfo.GetHyperlink = function()
  return { lines = {
    { leftText = "Wolverband" },
    { leftText = "Benutzen: Heilt 7 Sek. lang 161 Punkt(e) Schaden. (1 Min. Abklingzeit)" },
    { leftText = "Benötigt Erste Hilfe (50)" },
  } }
end
local bandage = assert(SDI.ComputeItem(5002))
assert(bandage.hot.total == 161 and bandage.hot.duration == 7,
  "German bandage use line with Punkt(e) and an Abklingzeit clause")
local tap = P.Read("Converts 58 Health into 58 Mana for you.", "de")
assert(tap.show == "special" and tap.special.healthCost == 58 and tap.special.manaGain == 58)
local funnel = P.Read("Gives 12 health to the caster's pet every second for 10 sec.", "en")
assert(funnel.show == "parsed" and funnel.parsed.healthCost == 120 and funnel.parsed.petHeal)
assert(funnel.parsed.heal == nil and funnel.parsed.hot == nil)
SDI.SetSetting("skipUtilityBars", false)
assert(#SDI._petButtons == 1 and SDI._labels[PetActionButton1]:IsShown())
SDI.ResetSettings()
assert(#SDI._petButtons == 0 and not SDI._labels[PetActionButton1]:IsShown())

-- Use font-dependent width, rather than the generic fixture's constant character width.
local main, side = SDI.NewLabel(ActionButton1), SDI.NewLabel(ActionButton1)
for _, fs in ipairs({ main, side }) do
  fs.SetFont = function(self, _, size) self.fontSize = size end
  fs.GetStringWidth = function(self) return #(self:GetText() or "") * self.fontSize * 0.5 end
end
SDI.SetSetting("position", "bottom")
SDI.SetSetting("size", 200)
SDI.DrawNumber(ActionButton1, main, side, "1290", SDI.Format.HEAL_COLOR, nil, true)
assert(main:GetStringWidth() <= 36 - 2 - 12 - 4, "healing covers the item count")
SDI.SetSetting("position", "top")
SDI.DrawNumber(ActionButton1, main, side, "123", SDI.Format.DAMAGE_COLOR, "1234", true,
  SDI.Format.HEAL_COLOR, "stacked")
assert(side:GetStringWidth() <= 36 - 2 - 12 - 4, "stacked bottom number covers the item count")
SDI.DrawNumber(ActionButton1, main, side, "-1290 HP", SDI.Format.HEAL_COLOR, "+1290 mana", true,
  SDI.Format.WEAPON_COLOR, "stacked")
assert(side.points[1][1] == "BOTTOMLEFT" and side.points[1][5] >= 14,
  "long stacked label still covers the item count at the minimum font")
assert(side:GetStringWidth() <= 34)

local secret = setmetatable({}, { __index = function() error("secret table was indexed") end })
function issecretvalue(value) return rawequal(value, secret) end
function UnitAttackPower() return 100, 20, -5 end
function UnitAttackSpeed() return 2.6, 1.8 end
function UnitRangedDamage() return 2, 10, 20 end
SDI._readWeapon()
assert(SDI._weaponStats.ap == 115 and SDI._weaponStats.offhandSpeed == 1.8)
assert(SDI._weaponStats.ranged == 15)
function UnitAttackPower() return 100, secret, -5 end
function UnitAttackSpeed() return 2.6, secret end
function UnitRangedDamage() return secret, secret, secret end
SDI._readWeapon()
assert(SDI._weaponStats.ap == 115, "partial secret AP erased the last readable buff")
assert(SDI._weaponStats.offhandSpeed == 1.8, "secret offhand speed erased its cache")
assert(SDI._weaponStats.ranged == 15)
function UnitAttackSpeed() return 2.6, nil end
function UnitRangedDamage() return 0, 0, 0 end
SDI._readWeapon()
assert(SDI._weaponStats.offhandSpeed == nil)
assert(SDI._weaponStats.ranged == nil and SDI._weaponStats.rangedSpeed == nil,
  "unequipping ranged weapon retained its old damage")
C_Spell.GetSpellInfo = function() return secret end
spellDesc[102] = "Verursacht 55 Schaden."
assert(SDI.Compute(102))
C_Item.GetItemSpell = function() return nil end
C_TooltipInfo = { GetHyperlink = function() return { lines = secret } end }
assert(SDI.ComputeItem(999) == nil)
C_TooltipInfo.GetHyperlink = function() return secret end
assert(SDI.ComputeItem(998) == nil)

-- A weapon poison: the coating text states the per-trigger damage and the chance, so the
-- poison item gets both - the number on its button and lines in its own tooltip.
local sfxDE = "Benutzen: Überzieht eine Waffe mit Gift, das 30 Minuten lang wirkt. Bei jedem Schlag besteht eine Chance von 20%, den Gegner zu vergiften und ihm sofort 13 bis 17 Naturschaden zuzufügen. 60 Aufladungen."
local sfxEN = "Use: Coats a weapon with poison that lasts 30 min. Each strike has a 20% chance of poisoning the enemy, causing 13 to 17 Nature damage. 60 charges."
local deadlyDE = "Benutzen: Überzieht eine Waffe mit Gift, das 30 Minuten lang wirkt.\r\nBei jedem Schlag besteht eine Chance von 30%, den Gegner 12 Sek. lang für 36 Punkt(e) Naturschaden zu vergiften. 60 Aufladungen."
for _, case in ipairs({ { sfxDE, "de" }, { sfxEN, "en" } }) do
  local read = assert(P.Read(case[1], case[2]), case[1])
  assert(read.show == "parsed" and read.proc == 20, case[1])
  assert(read.parsed.direct.min == 13 and read.parsed.direct.max == 17, case[1])
end
local deadly = assert(P.Read(deadlyDE, "de"))
assert(deadly.show == "parsed" and deadly.proc == 30 and deadly.parsed.dot.total == 36
  and deadly.parsed.dot.duration == 12)
C_Item.GetItemSpell = function() return "Sofort wirkendes Gift", 200 end
spellDesc[200] = sfxDE
C_TooltipInfo = { GetHyperlink = function() return { lines = {} } end }
local poison = assert(SDI.ComputeItem(5003))
assert(poison.direct.min == 13 and poison.direct.max == 17 and poison.proc == 20)
local poisonText = SDI.ButtonText(poison)
assert(poisonText == "15", tostring(poisonText)) -- the average of 13-17, as every damage range
GameTooltip.link = "item:5003"
GameTooltip.reviewLines = {}
GameTooltip.GetItem = function(self) return "item", self.link end
GameTooltip.AddLine = function(self, text) self.reviewLines[#self.reviewLines + 1] = text end
GameTooltip.NumLines = function(self) return #self.reviewLines end
local hookItems = assert(GameTooltip.scripts.OnTooltipSetItem, "no OnTooltipSetItem hook")
hookItems(GameTooltip)
local joined = table.concat(GameTooltip.reviewLines, " | ")
assert(joined:find("13", 1, true) and joined:find("17", 1, true) and joined:find("20", 1, true),
  joined)
''')

BIT.OpenSettings("SpellDamageInfo")
rt.execute(r'''
local window = SDI._optionsWindow()
SlashCmdList.SPELLDAMAGEINFO("lang en")
assert(window.mocks[1].caption:GetText() == "Immolate")
assert(window.rows.button.label:GetText() == SDI.Locales.en.OPT_BUTTON)
assert(window.rows.button.text:GetText() == SDI.Locales.en.OPT_BUTTON_TOTAL)
SlashCmdList.SPELLDAMAGEINFO("lang de")
assert(window.mocks[1].caption:GetText() == "Feuerbrand")
assert(window.rows.button.label:GetText() == SDI.Locales.de.OPT_BUTTON)
assert(window.rows.button.text:GetText() == SDI.Locales.de.OPT_BUTTON_TOTAL)
assert(window.reset:GetText() == SDI.Locales.de.OPT_RESET)
''')

for version in ("1.60.1", "12.0.0"):
    tip_rt, tip_G, tip_BIT, _ = namespace["load"](
        f'function GetBuildInfo() return "{version}" end'
    )
    tip_G.Fire("ADDON_LOADED", "UsefulPlatesAndTooltips")
    tip_G.Fire("PLAYER_LOGIN")
    tip_BIT.OpenSettings("SpellDamageInfo")
    tip_G.SDI = tip_BIT.modules["SpellDamageInfo"]
    tip_rt.execute(r'''
local window = SDI._optionsWindow()
GameTooltip.AddLine = function(self, text) self.reviewLine = text end
for _, lang in ipairs({ "de", "en", "de" }) do
  SlashCmdList.SPELLDAMAGEINFO("lang " .. lang)
  local L = SDI.Locales[lang]
  local note = SDI.IsRetail() and (" " .. L.OPT_RETAIL) or ""
  for _, entry in ipairs({ { "estimate", "OPT_ESTIMATE_TIP" }, { "weapon", "OPT_WEAPON_TIP" } }) do
    local row = window.rows[entry[1]]
    row:GetScript("OnEnter")(row)
    assert(GameTooltip.reviewLine == L[entry[2]] .. note,
      entry[1] .. " tooltip retained the previous language")
  end
end
''')

for language in ("en", "de"):
    off_rt, off_G, off_BIT, _ = namespace["load"](
        'UsefulPlatesAndTooltipsDB={modules={SpellDamageInfo={enabled=false}}}\n'
        f'UsefulPlatesAndTooltips_SpellDamageInfoDB={{interfaceLang="{language}"}}'
    )
    off_G.Fire("ADDON_LOADED", "UsefulPlatesAndTooltips")
    off_G.Fire("PLAYER_LOGIN")
    off_BIT.OpenSettings("SpellDamageInfo")
    module = off_BIT.modules["SpellDamageInfo"]
    scene = off_BIT._pages["SpellDamageInfo"].modulePreview
    assert scene is not None and not off_BIT.IsRunning("SpellDamageInfo")
    assert scene.title.text == module.Locales[language].OPT_OFF_SAMPLE
    assert scene.side.text == ("510 in 15 sec" if language == "en" else "510 in 15 Sek.")
    assert not any("could not" in str(text) for text in off_G.chat.values())

print("SDI review: item food/bandage, mixed locale, formulas, Life Tap, Health Funnel, count spacing, pet reset, secrets and live labels passed")
