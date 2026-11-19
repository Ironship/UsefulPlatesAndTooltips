"""Builds Modules/StatsInfo/Weights.lua from tools/data/foreversim_weights.json: for each class, its
specs, with an icon, a role and ForeverSim's stat weights put under the keys C_Item.GetItemStats uses.

    python tools/make_weights.py

The data are ForeverSim's raw weights (DPS, TPS or TMI per point), one run per spec or build. Here each
becomes a weight per point of the item's stat, in points of the spec's reference stat (Agility for a cat,
Spell Damage for a mage, Armor for a tank's survival). Forever pays an item's hit and crit into both
the melee and the spell pool, so an item's hit is worth the melee and the spell weight together, and so is
its crit (and its haste, which items give as one rating). A weapon's damage per second has the sim's own
weight, main hand, off hand and ranged apart. The healers (druid Restoration, priest Holy, paladin
Holy, shaman Restoration) have no sim weights: ForeverSim does not simulate healing, so those specs
are rated by the sim repo's EP presets for a Holy priest (tools/data/healer_weights.json; an
approximation, not a measured result).
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "tools", "data", "foreversim_weights.json")
OUT = os.path.join(ROOT, "Modules", "StatsInfo", "Weights.lua")

# ForeverSim's stat -> the GetItemStats keys it prices. A key under several stats gets their sum.
KEYS = {
    "Strength": ["ITEM_MOD_STRENGTH_SHORT"],
    "Agility": ["ITEM_MOD_AGILITY_SHORT"],
    "Stamina": ["ITEM_MOD_STAMINA_SHORT"],
    "Intellect": ["ITEM_MOD_INTELLECT_SHORT"],
    "Spirit": ["ITEM_MOD_SPIRIT_SHORT"],
    "Attack Power": ["ITEM_MOD_ATTACK_POWER_SHORT"],
    # An item's attack power raises ranged attack power too: Forever's "+20 Attack Power" (spell 9331)
    # carries both auras (99 and 124), so for a hunter it is worth the ranged weight.
    "Ranged Attack Power": ["ITEM_MOD_RANGED_ATTACK_POWER_SHORT", "ITEM_MOD_ATTACK_POWER_SHORT"],
    "Feral Attack Power": ["ITEM_MOD_FERAL_ATTACK_POWER_SHORT"],
    "Spell Damage": ["ITEM_MOD_SPELL_DAMAGE_DONE_SHORT", "ITEM_MOD_SPELL_POWER_SHORT"],
    "Arcane Spell Damage": ["ITEM_MOD_ARCANE_DAMAGE_DONE_SHORT"],
    "Fire Spell Damage": ["ITEM_MOD_FIRE_DAMAGE_DONE_SHORT"],
    "Frost Spell Damage": ["ITEM_MOD_FROST_DAMAGE_DONE_SHORT"],
    "Holy Spell Damage": ["ITEM_MOD_HOLY_DAMAGE_DONE_SHORT"],
    "Nature Spell Damage": ["ITEM_MOD_NATURE_DAMAGE_DONE_SHORT"],
    "Shadow Spell Damage": ["ITEM_MOD_SHADOW_DAMAGE_DONE_SHORT"],
    # "+N Weapon Damage": item stat 83, which the sim reads as its physical damage stat
    # (tools/database/dbc/maps.go) and its stat weights call Bonus Weapon Damage.
    "Bonus Weapon Damage": ["ITEM_MOD_PHYSICAL_DAMAGE_DONE_SHORT"],
    "Melee Hit Rating": ["ITEM_MOD_HIT_RATING_SHORT", "ITEM_MOD_HIT_MELEE_RATING_SHORT",
                         "ITEM_MOD_HIT_RANGED_RATING_SHORT", "ITEM_MOD_HIT_SPELL_RATING_SHORT"],
    "Spell Hit Rating": ["ITEM_MOD_HIT_RATING_SHORT", "ITEM_MOD_HIT_MELEE_RATING_SHORT",
                         "ITEM_MOD_HIT_RANGED_RATING_SHORT", "ITEM_MOD_HIT_SPELL_RATING_SHORT"],
    "Melee Crit Rating": ["ITEM_MOD_CRIT_RATING_SHORT", "ITEM_MOD_CRIT_MELEE_RATING_SHORT",
                          "ITEM_MOD_CRIT_RANGED_RATING_SHORT", "ITEM_MOD_CRIT_SPELL_RATING_SHORT"],
    "Spell Crit Rating": ["ITEM_MOD_CRIT_RATING_SHORT", "ITEM_MOD_CRIT_MELEE_RATING_SHORT",
                          "ITEM_MOD_CRIT_RANGED_RATING_SHORT", "ITEM_MOD_CRIT_SPELL_RATING_SHORT"],
    "Melee Haste Rating": ["ITEM_MOD_HASTE_RATING_SHORT"],
    "Spell Haste Rating": ["ITEM_MOD_HASTE_RATING_SHORT"],
    "Expertise Rating": ["ITEM_MOD_EXPERTISE_RATING_SHORT"],
    "Armor Penetration": ["ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT"],
    "Defense Rating": ["ITEM_MOD_DEFENSE_SKILL_RATING_SHORT"],
    "Dodge": ["ITEM_MOD_DODGE_RATING_SHORT"],
    "Parry": ["ITEM_MOD_PARRY_RATING_SHORT"],
    "Block Rating": ["ITEM_MOD_BLOCK_RATING_SHORT"],
    "Block Value": ["ITEM_MOD_BLOCK_VALUE_SHORT"],
    "MP5": ["ITEM_MOD_MANA_REGENERATION_SHORT"],
    "Armor": ["RESISTANCE0_NAME"],
    # "+50 Bonus Armor" (item stat 50, 314 items: Mithril Insignia, Band of the Great Tortoise, the Defender weapons):
    # a stat of its own in the client's item stats (ITEM_MOD_EXTRA_ARMOR_SHORT), and the sim weighs it separately
    # from Armor (about nine tenths of it: bonus armor escapes the percent armor modifiers).
    "Bonus Armor": ["ITEM_MOD_EXTRA_ARMOR_SHORT"],
}
# A weapon's damage per second, by where the weapon is.
WEAPONS = {"Main Hand DPS": "mainHand", "Off Hand DPS": "offHand", "Ranged DPS": "ranged"}
# Not item stats, or not ones an item's stat list carries: mana, spell piercing (no run has a weight for it).
SKIPPED = {"Mana", "Spell Piercing"}
# What each of a spec's measures is, and the sim's metric for it.
# A tank's survival is the sim's TMI (Theck-Meloree Index): how big the damage spikes are against the tank's
# health, so Stamina counts as well as armor and avoidance; its damage taken per second (DTPS) gave Stamina
# nothing, and a Stamina item read as only a loss (Forever pays rage from a hit as damage x 10 / max health,
# sim/core/rage.go, so more health is less threat).
METRICS = {"damage": "DPS", "threat": "TPS", "survival": "TMI"}

# A healer's measure is NOT a ForeverSim run: ForeverSim does not simulate healing, so its weights
# cannot be measured. It is the sim repo's community EP for a Holy priest, kept in tools/data/healer_weights.json
# (its coefficients are DESIGN CHOICES, provenance and assumptions documented there), born the same way
# into Weights.lua with approximate = true so the tooltip marks it "(approx.)". The same model rates
# every healer spec (one file, several entries in SPECS below). HEALER_RUNS keeps the two sources
# apart: a spec named here is taken from the healer file, never from a sim run.
# Feral forms fight with the weapon's DPS (the sim never measures it: its shapeshifted
# runs carry no "Main Hand DPS" row). Game-measured on Forever: a 16.0 DPS weapon adds
# ~15.6 melee DPS in Bear Form, i.e. 1 weapon DPS ~= 1 feral DPS ~= 14 Feral Attack Power
# (the classic 14 AP = 1 DPS rule; the sim's own Feral Attack Power row confirms the rate).
# So a feral damage/threat mainHand is 14 * the run's Feral Attack Power weight, in points
# of the measure's reference stat. Survival keeps mainHand 0 (DPS does not mitigate).
FERAL_RUNS = {"druid_bear", "druid_cat"}
FERAL_AP_PER_DPS = 14
HEALER_RUNS = {"druid_restoration", "priest_holy", "paladin_holy", "shaman_restoration"}
HEALER_DATA = os.path.join(ROOT, "tools", "data", "healer_weights.json")

# class -> specs: (run, name shown, icon, role, reference stat of each measure). The icons are the game's
# own, from Forever 1.60.1.70009's tables: a talent tree's icon (TalentTab), or for a build named after a
# spell, that spell's (SpellMisc): Mortal Strike for Arms, Smite, Sinister Strike, Backstab and Demonic
# Sacrifice. Shown names are the specs those builds belong to. Tanks are weighed by survival (in Armor) and by threat.
DAMAGE = "damage"
SPECS = {
    "DRUID": [("druid_bear", "Feral (Bear)", "Ability_Racial_BearForm", "tank", {"survival": "Armor", "threat": "Agility"}),
                  ("druid_cat", "Feral (Cat)", "Ability_Druid_CatForm", DAMAGE, {"damage": "Agility"}),
                  ("druid_balance", "Balance", "Spell_Nature_StarFall", DAMAGE, {"damage": "Spell Damage"}),
                  # the druid's healer: its measure comes from HEALER_DATA (never a sim run), see HEALER_RUNS.
                  # The icon is the Restoration talent tree's own (Spell_Nature_HealingTouch, the Healing Touch
                  # spell's icon), as the three above are their trees'.
                  ("druid_restoration", "Restoration", "Spell_Nature_HealingTouch", "healing",
                   {"healing": HEALER_DATA})],
    "HUNTER": [("hunter_bm", "Beast Mastery", "Ability_Hunter_BeastTaming", DAMAGE, {"damage": "Agility"}),
               ("hunter_mm", "Marksmanship", "Ability_Marksmanship", DAMAGE, {"damage": "Agility"}),
               ("hunter_sv", "Survival", "Ability_Hunter_SwiftStrike", DAMAGE, {"damage": "Agility"})],
    "MAGE": [("mage_arcane", "Arcane", "Spell_Holy_MagicalSentry", DAMAGE, {"damage": "Spell Damage"}),
             ("mage_fire", "Fire", "Spell_Fire_FireBolt02", DAMAGE, {"damage": "Spell Damage"}),
             ("mage_frost", "Frost", "Spell_Frost_FrostBolt02", DAMAGE, {"damage": "Spell Damage"})],
    "PALADIN": [("paladin_protection", "Protection", "Spell_Holy_DevotionAura", "tank",
                 {"survival": "Armor", "threat": "Strength"}),
                ("paladin_retribution", "Retribution", "Spell_Holy_AuraOfLight", DAMAGE, {"damage": "Strength"}),
                # the paladin's healer, from HEALER_DATA like druid Restoration (see HEALER_RUNS); the icon
                # is the Holy talent tree's own (Spell_Holy_HolyBolt), as the two above are their trees'.
                ("paladin_holy", "Holy", "Spell_Holy_HolyBolt", "healing", {"healing": HEALER_DATA})],
    "PRIEST": [("priest_shadow", "Shadow", "Spell_Shadow_ShadowWordPain", DAMAGE, {"damage": "Spell Damage"}),
               ("priest_smite", "Discipline", "Spell_Holy_HolySmite", DAMAGE, {"damage": "Spell Damage"}),
               # the priest's healer: the Holy talent tree's own icon (Spell_Holy_HolyNova).
               ("priest_holy", "Holy", "Spell_Holy_HolyNova", "healing", {"healing": HEALER_DATA})],
    "ROGUE": [("rogue_ss", "Combat", "Spell_Shadow_RitualOfSacrifice", DAMAGE, {"damage": "Attack Power"}),
              ("rogue_backstab", "Subtlety", "Ability_BackStab", DAMAGE, {"damage": "Attack Power"}),
              ("rogue_mutilate", "Assassination", "Ability_Rogue_Eviscerate", DAMAGE, {"damage": "Attack Power"})],
    "SHAMAN": [("shaman_elemental", "Elemental", "Spell_Nature_Lightning", DAMAGE, {"damage": "Spell Damage"}),
               ("shaman_enhancement", "Enhancement", "Spell_Nature_LightningShield", DAMAGE,
                {"damage": "Attack Power"}),
               # the shaman's healer: the Restoration talent tree's own icon (Spell_Nature_HealingWaveGreater,
               # the Greater Healing Wave spell's), as druid Restoration's is its tree's.
               ("shaman_restoration", "Restoration", "Spell_Nature_HealingWaveGreater", "healing",
                {"healing": HEALER_DATA})],
    "WARLOCK": [("warlock_affliction", "Affliction", "Spell_Shadow_DeathCoil", DAMAGE, {"damage": "Spell Damage"}),
                ("warlock_demonology", "Demonology", "Spell_Shadow_Metamorphosis", DAMAGE, {"damage": "Spell Damage"}),
                ("warlock_destruction", "Destruction", "Spell_Shadow_RainOfFire", DAMAGE, {"damage": "Spell Damage"}),
                ("warlock_dsruin", "Destruction (DS/Ruin)", "Spell_Shadow_PsychicScream", DAMAGE, {"damage": "Spell Damage"})],
    "WARRIOR": [("warrior_protection", "Protection", "Ability_Warrior_DefensiveStance", "tank",
                 {"survival": "Armor", "threat": "Strength"}),
                ("warrior_arms", "Arms", "Ability_Warrior_SavageBlow", DAMAGE, {"damage": "Strength"}),
                ("warrior_fury", "Fury", "Ability_Warrior_InnerRage", DAMAGE, {"damage": "Strength"})],
}


# ForeverSim leaves a stat out of a run when the run's gear has it capped (no Melee Hit Rating at all for Arms,
# Retribution and Survival: their sim gear is at the hit cap), which this table would read as "hit is worthless", and
# a few weights come out negative (a mana-limited build that runs dry sooner with Haste), which count as 0. For a
# player under the cap an item's hit is the most valuable stat it can have, so both gaps are filled from the sim
# repo's own EP presets (tools/data/ep_presets.json), as a ratio to a stat the run did measure:
#   weight = the run's anchor weight x preset(stat) / preset(anchor), the mean of the presets named.
# (run, measure, stat to fill, anchor stat in the run, [presets], preset stat, preset anchor stat)
EP_FILLS = [
    ("warrior_arms", "damage", "Melee Hit Rating", "Melee Crit Rating", ["warrior__dps/Pre-BiS - Arms"],
     "StatHitRating", "StatCritRating"),
    ("paladin_retribution", "damage", "Melee Hit Rating", "Melee Crit Rating",
     ["paladin__retribution/Holy Shock", "paladin__retribution/Unsealed Wrath"], "StatHitRating", "StatCritRating"),
    ("hunter_sv", "damage", "Melee Hit Rating", "Melee Crit Rating", ["hunter__dps/Melee"],
     "StatHitRating", "StatCritRating"),
    ("hunter_mm", "damage", "Melee Haste Rating", "Melee Crit Rating", ["hunter__dps/Turret"],
     "StatHasteRating", "StatCritRating"),
    ("priest_smite", "damage", "Spell Haste Rating", "Spell Crit Rating", ["priest__dps/Smite"],
     "StatHasteRating", "StatCritRating"),
]
EP_PRESETS = json.load(open(os.path.join(ROOT, "tools", "data", "ep_presets.json"), encoding="utf-8"))["presets"]


def fill_from_presets(metric, run_name, kind):
    """Adds the weights EP_FILLS names to the metric where the run has none (or a negative one)."""
    for run, measure, stat, anchor, presets, p_stat, p_anchor in EP_FILLS:
        if run != run_name or measure != kind:
            continue
        value, ci = metric.get(stat, [0, 0])
        if value > 0 and value >= ci:
            continue
        base = metric.get(anchor, [0, 0])[0]
        ratios = [EP_PRESETS[p][p_stat] / EP_PRESETS[p][p_anchor] for p in presets]
        if base <= 0 or not ratios:
            continue
        ratio = sum(ratios) / len(ratios)
        metric[stat] = [base * ratio, 0]
        print(f"  {run_name} {kind}: {stat} had {value:+.4f}, filled as {ratio:.2f} x {anchor} from {', '.join(presets)}")


# The caps of a spec. The numbers are the game's own: the Forever character sheet's hit tooltip lists them
# (CR_<CLASS>_HIT_CAP_TOOLTIP in the client's GlobalStrings: "To never miss Raid Bosses: 8.00% Melee/Ranged, 17.00%
# Spells, 27.00% Dual Wielding"; the expertise tooltip: a raid boss dodges 6.50%), and they are the sim repo's
# (ui/specs/<class>/<spec>/spec.ts: statCaps, softCapBreakpoints). A step is (percentage, what a point is worth
# from there on, as a share of what it is worth below the first step); the last step of a dual wielder or of
# Arms is 0. The shares come from the sim's postCapEPs against the same preset's hit EP: Fury 0.57 of 1.69,
# Arms 0.57 of 4.70, Enhancement 1.9 and 1.73 of 5.20 (tools/data/ep_presets.json). A rogue's 3.06 between 8 and
# 27 is more than its 2.42 below 8, so a rogue's hit counts in full up to 27. StatsInfo reads the character's
# current hit and expertise with the formulas of the game's character sheet and counts the stat by these steps.
HARD_8 = [(8, 0)]
CAPS = {
    "druid_balance": {"hit": ("spell", [(17, 0)])},
    "druid_cat": {"hit": ("melee", HARD_8), "exp": [(6.5, 0)]},
    "druid_bear": {"hit": ("melee", HARD_8), "exp": [(6.5, 0)]},
    "hunter_bm": {"hit": ("ranged", HARD_8)}, "hunter_mm": {"hit": ("ranged", HARD_8)},
    "hunter_sv": {"hit": ("ranged", HARD_8)},
    "mage_arcane": {"hit": ("spell", [(17, 0)])}, "mage_fire": {"hit": ("spell", [(17, 0)])},
    "mage_frost": {"hit": ("spell", [(17, 0)])},
    "paladin_protection": {"hit": ("melee", HARD_8), "exp": [(6.5, 0)]},
    "paladin_retribution": {"hit": ("melee", HARD_8), "exp": [(6.5, 0)]},
    "priest_shadow": {"hit": ("spell", [(17, 0)])}, "priest_smite": {"hit": ("spell", [(17, 0)])},
    "rogue_ss": {"hit": ("melee", [(27, 0)]), "exp": [(6.5, 0)]},
    "rogue_backstab": {"hit": ("melee", [(27, 0)]), "exp": [(6.5, 0)]},
    "rogue_mutilate": {"hit": ("melee", [(27, 0)]), "exp": [(6.5, 0)]},
    "shaman_elemental": {"hit": ("spell", [(17, 0)])},
    "shaman_enhancement": {"hit": ("melee", [(8, 0.37), (20, 0.33), (27, 0)]), "exp": [(6.5, 0)]},
    "warlock_affliction": {"hit": ("spell", [(17, 0)])}, "warlock_demonology": {"hit": ("spell", [(17, 0)])},
    "warlock_destruction": {"hit": ("spell", [(17, 0)])}, "warlock_dsruin": {"hit": ("spell", [(17, 0)])},
    "warrior_protection": {"hit": ("melee", HARD_8), "exp": [(6.5, 0)]},
    "warrior_arms": {"hit": ("melee", [(8, 0.12), (27, 0)]), "exp": [(6.5, 0)]},
    "warrior_fury": {"hit": ("melee", [(8, 0.34), (27, 0)]), "exp": [(6.5, 0)]},
}


def steps_lua(steps):
    return "{ " + ", ".join(f"{{ {cap:g}, {mult:g} }}" for cap, mult in steps) + " }"


def caps_lua(run_name):
    caps = CAPS.get(run_name)
    if not caps:
        return ""
    parts = []
    if "hit" in caps:
        kind, steps = caps["hit"]
        parts.append(f'hit = {{ kind = "{kind}", steps = {steps_lua(steps)} }}')
    if "exp" in caps:
        parts.append(f"exp = {{ steps = {steps_lua(caps['exp'])} }}")
    return ", caps = { " + ", ".join(parts) + " }"


def significant(metric, stat, reference):
    """A raw weight of the metric, or 0 where it is smaller than its own 90% confidence interval: the sim's
    noise (a bear's Stamina for damage taken was -0.031 +- 0.044), which as the base of a percentage made
    nonsense."""
    value, ci = metric.get(stat, [0, 0])
    if stat == reference:
        return value
    return value if abs(value) >= ci else 0


def measure(run, run_name, kind, reference):
    """One measure of a spec as Lua: its reference stat, the weights of a weapon's damage per second in
    each place, and the item weights, all in points of the reference stat."""
    metric = run["metrics"][METRICS[kind]]
    fill_from_presets(metric, run_name, kind)
    ref = significant(metric, reference, reference)
    if ref == 0:
        raise SystemExit(f"{reference} has no weight to count in")
    weights, weapons = {}, {field: 0 for field in WEAPONS.values()}
    for stat in metric:
        value = significant(metric, stat, reference) / ref
        if stat in WEAPONS:
            weapons[WEAPONS[stat]] = value
        elif stat in SKIPPED:
            continue
        elif value < 0:
            # An item's stat never hurts: a negative weight is the sim's fight (a mana-limited caster that
            # runs dry sooner with Haste, a tank whose rage per hit falls with more health), not harm, and
            # it made a strict superset of stats read as worse (a chest with more armor and more Stamina
            # "37% worse for threat gen.", +20 Haste "42% worse" for Discipline). So it counts as nothing.
            print(f"  {run_name} {kind}: {stat} weighs {value:.4f}, counted as 0")
            continue
        elif stat not in KEYS:
            raise SystemExit(f"no item key for ForeverSim's {stat!r}")
        else:
            for key in KEYS[stat]:
                weights[key] = weights.get(key, 0) + value
    if run_name in FERAL_RUNS and kind in ("damage", "threat"):
        fap = significant(metric, "Feral Attack Power", reference) / ref
        weapons["mainHand"] = round(FERAL_AP_PER_DPS * fap, 3)
    return measure_lua(reference, weights, weapons, False, caps_lua(run_name))


def heuristic_measure(data):
    """A healer's measure from the healer data file: the same wire shape as a simulated measure, with
    approximate = true so the tooltip marks the rating "(approx.)". The weights are already the item
    keys GetItemStats uses (no KEYS translation: the healer model prices the game's own stats), rounded
    the same way as the sim's, with the weapon weights 0 (a healer's weapon stats count, not its DPS)."""
    weights = {k: v for k, v in data["weights"].items() if round(v, 4) != 0}
    if not weights:
        raise SystemExit(f"{HEALER_DATA}: no weights left after rounding")
    return measure_lua(data["reference"], weights, {field: 0 for field in WEAPONS.values()}, True)


def measure_lua(reference, weights, weapons, approximate, caps=""):
    weights = {k: round(v, 4) for k, v in sorted(weights.items()) if round(v, 4) != 0}
    w = {k: round(v, 3) for k, v in weapons.items()}
    approx = approximate and "approximate = true, " or ""
    return (f"{{ reference = \"{reference}\", {approx}mainHand = {w['mainHand']:g}, offHand = {w['offHand']:g}, "
            f"ranged = {w['ranged']:g}{caps}, weights = {lua_table(weights, 6)} }}")


def lua_table(d, indent):
    pad = " " * indent
    return "{\n" + "".join(f"{pad}  {k} = {v:g},\n" for k, v in d.items()) + pad + "}"


def build(run):
    """What a run was measured on, for the comment above its spec."""
    s = run["setup"]
    what = s.get("note") or ", ".join(s.get("presets") or []) or "the sim's defaults"
    return f"{run['page'].split('/forever/')[1].rstrip('/')}: {what}; talents {s['talents']}"


def main():
    data = json.load(open(DATA, encoding="utf-8"))
    src, runs = data["source"], data["runs"]
    healer = json.load(open(HEALER_DATA, encoding="utf-8"))
    # One comment per healer spec: its place ("druid/restoration"), then the shared model's own words.
    def healer_comment(run_name):
        return f"{run_name.replace('_', '/', 1)}: {healer['model']}; {healer['source']}"
    lines = [
        "-- UsefulPlatesAndTooltips module StatsInfo: how much each spec wants an item's stats.",
        "-- Generated by tools/make_weights.py from tools/data/foreversim_weights.json and",
        "-- tools/data/healer_weights.json; change it there.",
        "--",
        f"-- Stat weights from ForeverSim, {src['site']}",
        f"-- ({src['sim']}).",
        f"-- Run {src['run']}.",
        "-- A weight is per point of the item's stat, in points of the measure's reference stat. Forever pays an",
        "-- item's hit and crit into both the melee and the spell pool, so those keys carry both weights.",
        "-- Hit and haste that ForeverSim left out (gear at the cap) or measured negative for a few specs are filled",
        "-- from the sim repo's EP presets as a ratio to crit (EP_FILLS in tools/make_weights.py).",
        "-- A weight smaller than its own 90% confidence interval is left out as the sim's noise, and a negative",
        "-- one counts as 0: a stat on an item never hurts (the sim's negative weights are its mana and rage",
        "-- limits, and made an item with strictly more stats read as worse).",
        "-- mainHand, offHand, ranged: the worth of a point of a weapon's damage per second in that place (0 where",
        "-- the spec does not fight with it: a caster's weapon, an Arms warrior's off hand). Cat and Bear Form",
        "-- fight with the weapon's DPS (FERAL_RUNS below): their mainHand is game-measured, not simulated.",
        "--",
        "-- The healers (druid Restoration, priest Holy, paladin Holy, shaman Restoration) are rated by",
        f"-- UsefulPlatesAndTooltips's own starter heuristic (an approximation, marked '(approx.)' in the tooltip;",
        f"-- {healer['model']}), NOT a simulation: ForeverSim does not simulate healing, so no measured",
        "-- healer weights exist.",
        "",
        "local _, BIT = ...",
        "local M = BIT.Module(\"StatsInfo\")",
        "",
        "M.WEIGHTS_SOURCE = \"ForeverSim stat weights, 2026-09-27, level 60 builds of each spec; "
        f"the healers (druid Restoration, priest Holy, paladin Holy, shaman Restoration): {healer['source']}\"",
        "",
        "M.SPECS = {",
    ]
    used, used_healers = set(), set()
    for cls, specs in SPECS.items():
        lines.append(f"  {cls} = {{")
        for run_name, name, icon, role, refs in specs:
            if run_name in HEALER_RUNS:
                if run_name in runs:
                    raise SystemExit(f"{run_name!r} is both a sim run and a healer run: pick one source")
                used_healers.add(run_name)
                lines.append(f"    -- {healer_comment(run_name)}")
                measure_texts = {kind: heuristic_measure(healer) for kind in refs}
            else:
                run = runs[run_name]
                used.add(run_name)
                lines.append(f"    -- {build(run)}")
                measure_texts = {kind: measure(run, run_name, kind, reference) for kind, reference in refs.items()}
            lines.append(f"    {{ name = \"{name}\", icon = \"Interface\\\\Icons\\\\{icon}\", role = \"{role}\",")
            for kind, text in measure_texts.items():
                lines.append(f"      {kind} = {text},")
            lines.append("    },")
        lines.append("  },")
    lines.append("}")
    missing = set(runs) - used
    if missing:
        raise SystemExit(f"runs not used: {sorted(missing)}")
    missing_healers = HEALER_RUNS - used_healers
    if missing_healers:
        raise SystemExit(f"healer runs not used: {sorted(missing_healers)}")
    open(OUT, "w", encoding="utf-8", newline="\n").write("\n".join(lines) + "\n")
    print("wrote", OUT)


if __name__ == "__main__":
    main()
