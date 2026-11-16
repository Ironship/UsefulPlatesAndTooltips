-- UsefulPlatesAndTooltips module TriggerGlow: the spells that get a glow, and what opens the window for each.
-- Copyright (c) 2026 Ironship. GPL-3.0-or-later, see LICENSE.
--
-- The ids are the ranks of Forever build 1.60.1 as the client's own spell descriptions list them (the
-- player's /sdi dump of every language; the wording is the source of each condition below). A rank that is
-- missing here is still found by its name (Core.lua matches the client's name of the first id), so a build
-- that adds a rank does not need a data change.
--
-- group "hp":       a target at or below a share of its health opens the window (Execute, Hammer of Wrath);
--                   "enemy" targets an attackable unit, the share is a setting (executePct, default 20).
-- group "heal":     a friendly target below a share of its health (Divine Grace, "below 50% Health", not on
--                   yourself); the share is a setting (healPct).
-- group "reactive": the game itself says when the spell can be cast (an Overpower after a dodge, a Revenge
--                   after a block, dodge or parry, a Victory Rush after a kill): C_Spell.IsSpellUsable.
--
-- group "kill":     not a rule of this table: any spell on a bar whose direct damage CastPrediction can price glows
--                   while the target's health is at or below that damage (Core.lua, killPct). This is what a
--                   Shadow Word: Death (401955, 1309595, 1309633, 1309635, 1309636) gets: its description in this
--                   build has no health condition (damage, and a backlash when the target survives), so no rule.

local _, BIT = ...
local ns = BIT.Module("TriggerGlow")

ns.GROUPS = {
  { id = "hp", label = "Execute-type spells", colorKey = "hpColor", enableKey = "hp" },
  { id = "heal", label = "Heal for a low-health friend", colorKey = "healColor", enableKey = "heal" },
  { id = "reactive", label = "Reactive spells", colorKey = "reactiveColor", enableKey = "reactive" },
  { id = "kill", label = "Lethal damage", colorKey = "killColor", enableKey = "kill" },
}

ns.RULES = {
  {
    key = "execute", group = "hp", label = "Execute", target = "enemy", pctKey = "executePct",
    ids = { 5308, 20658, 20660, 20661, 20662 },
    note = "Only usable on enemies that have 20% or less health.",
  },
  {
    key = "hammerOfWrath", group = "hp", label = "Hammer of Wrath", target = "enemy", pctKey = "executePct",
    ids = { 24239, 24274, 24275 },
    note = "Only usable on enemies that have 20% or less health.",
  },
  {
    key = "divineGrace", group = "heal", label = "Divine Grace", target = "friend", pctKey = "healPct", notSelf = true,
    ids = { 1277370, 1277371, 1277372, 1277374, 1277376, 1277377, 1277378 },
    note = "Heals a friendly target below 50% health; cannot be cast on yourself.",
  },
  {
    key = "overpower", group = "reactive", label = "Overpower",
    ids = { 7384, 7887, 11584, 11585 },
    note = "Only usable after the target dodges.",
  },
  {
    key = "revenge", group = "reactive", label = "Revenge",
    ids = { 6572, 6574, 7379, 11600, 11601, 25288 },
    note = "Only usable after you block, dodge or parry.",
  },
  {
    key = "mongooseBite", group = "reactive", label = "Mongoose Bite",
    ids = { 1495, 14269, 14270, 14271 },
    note = "Only usable after you dodge.",
  },
  {
    key = "counterattack", group = "reactive", label = "Counterattack",
    ids = { 19306, 20909, 20910, 1242634 },
    note = "Only usable after you parry.",
  },
  {
    key = "victoryRush", group = "reactive", label = "Victory Rush",
    ids = { 402927 },
    note = "Only usable within 20 seconds after you kill an enemy that gives experience or honor.",
  },
}

-- id -> rule, and key -> rule.
ns.ById, ns.ByKey = {}, {}
for _, rule in ipairs(ns.RULES) do
  ns.ByKey[rule.key] = rule
  for _, id in ipairs(rule.ids) do ns.ById[id] = rule end
end
