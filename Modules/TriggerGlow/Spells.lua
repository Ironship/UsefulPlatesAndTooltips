-- UsefulPlatesAndTooltips module TriggerGlow: every spell the lethal glow can apply to, by class.
-- Copyright (c) 2026 Ironship. GPL-3.0-or-later, see LICENSE.
--
-- Generated 2026-11-16 from the player's /sdi dump of the 1697 class spell descriptions (the English client) and
-- the repo's own spell parser: a spell is listed when the parser reads its description as direct damage and
-- CastPrediction can price it (CastPrediction.buildView refuses wordings it cannot read, multi-hit and per-swing
-- spells), so these are the spells a kill estimate exists for. The class is the client's SpellClassSet
-- (SpellClassOptions, build 1.60.1.70888), with the skill line's class mask where it is missing. A weapon attack
-- (Heroic Strike, Sinister Strike), a finisher and a spell whose description the client leaves as an unresolved
-- formula (Frostbolt) have no price here; if the client reads one of them at run time it shows under
-- "Other spells found on your bars" in the settings. A spell is named by its English name; a rank missing from
-- the ids is found by the client's name of the first one.

local _, BIT = ...
local ns = BIT.Module("TriggerGlow")

ns.LETHAL_CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }

ns.LETHAL = {
  WARRIOR = {
    { name = "Execute", ids = { 5308, 20658, 20660, 20661, 20662 } },
    { name = "Hamstring", ids = { 1715, 7372, 7373 } },
    { name = "Intercept", ids = { 20252, 20616, 20617 } },
    { name = "Mocking Blow", ids = { 694, 7400, 7402, 20559, 20560 } },
    { name = "Pummel", ids = { 6552, 6554 } },
    { name = "Shield Bash", ids = { 72, 1671, 1672 } },
    { name = "Shield Slam", ids = { 23922, 23923, 23924, 23925 } },
    { name = "Thunder Clap", ids = { 6343, 8198, 8204, 8205, 11580, 11581 } },
  },
  PALADIN = {
    { name = "Exorcism", ids = { 879, 5614, 5615, 10312, 10313, 10314, 415068, 415069, 415070, 415071, 415072, 415073 } },
    { name = "Hammer of Wrath", ids = { 24239, 24274, 24275 } },
    { name = "Holy Shock", ids = { 25902, 25911, 25912 } },
    { name = "Holy Wrath", ids = { 2812, 10318 } },
  },
  HUNTER = {
    { name = "Arcane Shot", ids = { 3044, 14281, 14282, 14283, 14284, 14285, 14286, 14287 } },
    { name = "Explosive Trap", ids = { 13813, 14316, 14317 } },
    { name = "Wing Clip", ids = { 2974, 14267, 14268 } },
  },
  ROGUE = {
    { name = "Gouge", ids = { 1776, 1777, 8629, 11285, 11286 } },
    { name = "Kick", ids = { 1766, 1767, 1768, 1769 } },
  },
  PRIEST = {
    { name = "Chastise", ids = { 1277331, 1277332, 1277333, 1277334, 1277335 } },
    { name = "Holy Fire", ids = { 14914, 15261, 15262, 15263, 15264, 15265, 15266, 15267 } },
    { name = "Holy Nova", ids = { 15237, 15430, 15431, 27799, 27800, 27801 } },
    { name = "Mind Blast", ids = { 8092, 8102, 8103, 8104, 8105, 8106, 10945, 10946, 10947 } },
    { name = "Mind Spike", ids = { 431655 } },
    { name = "Shadow Word: Death", ids = { 401955, 1309595, 1309633, 1309635, 1309636 } },
    { name = "Smite", ids = { 585, 591, 598, 984, 1004, 6060, 10933, 10934 } },
  },
  SHAMAN = {
    { name = "Chain Lightning", ids = { 421, 930, 2860, 10605, 408479, 408481, 408482, 408484 } },
    { name = "Earth Shock", ids = { 8042, 8044, 8045, 8046, 10412, 10413, 10414 } },
    { name = "Fire Nova", ids = { 408341, 408342, 408343, 408344, 408345 } },
    { name = "Flame Shock", ids = { 8050, 8052, 8053, 10447, 10448, 29228 } },
    { name = "Frost Shock", ids = { 8056, 8058, 10472, 10473 } },
    { name = "Lava Burst", ids = { 408490, 408491, 1238299, 1238300, 1238373, 1238376, 1326047 } },
    { name = "Lightning Bolt", ids = { 403, 529, 548, 915, 943, 6041, 10391, 10392, 15207, 15208, 408439, 408440, 408441, 408442, 408443, 408472, 408473, 408474, 408475, 408477 } },
  },
  MAGE = {
    { name = "Arcane Barrage", ids = { 400610 } },
    { name = "Arcane Blast", ids = { 400574, 1239696, 1239697, 1239699, 1239700 } },
    { name = "Arcane Explosion", ids = { 1449, 8437, 8438, 8439, 10201, 10202 } },
    { name = "Arcane Surge", ids = { 425124 } },
    { name = "Arcane Wrath", ids = { 1326079, 1326080, 1326081, 1326082 } },
    { name = "Balefire Bolt", ids = { 428878 } },
    { name = "Blast Wave", ids = { 11113, 13018, 13019, 13020, 13021 } },
    { name = "Fire Blast", ids = { 2136, 2137, 2138, 8412, 8413, 10197, 10199, 400616, 400618, 400619, 400620, 400621, 400622, 400623 } },
    { name = "Fireball", ids = { 133, 143, 145, 3140, 8400, 8401, 8402, 10148, 10149, 10150, 10151, 25306 } },
    { name = "Flamestrike", ids = { 2120, 2121, 8422, 8423, 10215, 10216 } },
    { name = "Frostfire Bolt", ids = { 401502, 1237312, 1237313 } },
    { name = "Ice Lance", ids = { 400640, 1240044, 1240045, 1240046, 1240047, 1312002 } },
    { name = "Living Bomb", ids = { 400613 } },
    { name = "Pyroblast", ids = { 11366, 12505, 12522, 12523, 12524, 12525, 12526, 18809 } },
    { name = "Scorch", ids = { 2948, 8444, 8445, 8446, 10205, 10206, 10207 } },
    { name = "Spellfrost Bolt", ids = { 412532 } },
  },
  WARLOCK = {
    { name = "Chaos Bolt", ids = { 403629 } },
    { name = "Conflagrate", ids = { 17962, 18930, 18931, 18932, 1293817, 1293818 } },
    { name = "Death Coil", ids = { 6789, 17925, 17926 } },
    { name = "Immolate", ids = { 348, 707, 1094, 2941, 11665, 11667, 11668, 25309 } },
    { name = "Incinerate", ids = { 412758, 1293812, 1293813 } },
    { name = "Inferno", ids = { 1122 } },
    { name = "Searing Pain", ids = { 5676, 17919, 17920, 17921, 17922, 17923 } },
    { name = "Shadow Bolt", ids = { 686, 695, 705, 1088, 1106, 7641, 11659, 11660, 11661, 25307 } },
    { name = "Shadowburn", ids = { 17877, 18867, 18868, 18869, 18870, 18871 } },
    { name = "Shadowflame", ids = { 426320 } },
    { name = "Soul Fire", ids = { 6353, 17924 } },
  },
  DRUID = {
    { name = "Moonfire", ids = { 8921, 8924, 8925, 8926, 8927, 8928, 8929, 9833, 9834, 9835 } },
    { name = "Rake", ids = { 1822, 1823, 1824, 9904 } },
    { name = "Starfire", ids = { 2912, 8949, 8950, 8951, 9875, 9876, 25298 } },
    { name = "Starsurge", ids = { 417157 } },
    { name = "Sunfire", ids = { 414684, 414687, 414689 } },
    { name = "Swipe", ids = { 769, 779, 780, 9754, 9908 } },
    { name = "Wrath", ids = { 5176, 5177, 5178, 5179, 5180, 6780, 8905, 9912 } },
  },
}

-- Ids the parser prices as direct damage that are not a cast dealing it (see the header of Core.lua's lethal part).
ns.LETHAL_SKIP = {
  names = { "Seal of Fury", "Seal of Righteousness", "Instant Poison", "Instant Poison II", "Instant Poison III", "Instant Poison IV", "Instant Poison V", "Instant Poison VI", "Touch of Weakness", "Shadowguard", "Lightning Shield", "Frostbrand Weapon", "Felfire", "Hellfire Effect", "Thorns", "Maul" },
  ids = { 324, 325, 467, 782, 905, 945, 1075, 2652, 2943, 5857, 6807, 6808, 6809, 8033, 8038, 8134, 8681, 8687, 8691, 8914, 8972, 9745, 9756, 9880, 9881, 9910, 10431, 10432, 10456, 11341, 11342, 11343, 11681, 11682, 16355, 16356, 18137, 19261, 19262, 19264, 19265, 19266, 19308, 19309, 19310, 19311, 19312, 20163, 20287, 20288, 20289, 20290, 20291, 20292, 20293, 20419, 20421, 20422, 20423, 24530, 26363, 26364, 26365, 26366, 26367, 26369, 26370, 28377, 28378, 28379, 28380, 28381, 28382, 1311649, 1311656 },
}

-- id -> record, name -> record, and the skip sets as lookups.
ns.LethalById, ns.LethalByName, ns.LethalSkipId, ns.LethalSkipName = {}, {}, {}, {}
for _, class in ipairs(ns.LETHAL_CLASSES) do
  for _, rec in ipairs(ns.LETHAL[class]) do
    rec.class = class
    ns.LethalByName[rec.name] = rec
    for _, id in ipairs(rec.ids) do ns.LethalById[id] = rec end
  end
end
for _, id in ipairs(ns.LETHAL_SKIP.ids) do ns.LethalSkipId[id] = true end
for _, name in ipairs(ns.LETHAL_SKIP.names) do ns.LethalSkipName[name] = true end
