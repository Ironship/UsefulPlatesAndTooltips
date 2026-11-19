"""Builds Modules/StatsInfo/EffectData.lua: what the effects of Forever's items, its consumables and its set
bonuses give in stats, so StatsInfo can rate them (an item's value is not only its static stats).

    python tools/make_effects.py [--sha <wowsims/forever commit>] [--build 1.60.1.70790]

Sources (cached in tools/db2-cache, delete it to fetch again):
  * wowsims/forever (MIT, github.com/wowsims/forever) at one pinned commit: assets/database/db.json (the items with
    their effects and the consumables, whose stats its generator already worked out) and
    assets/db_inputs/spell_store_inputs.json (the game's spell rows: durations, aura types and values, proc options).
  * the game's own ItemSetSpell table from wago.tools (which spell each set threshold casts).

What is counted, and how (the part that is an estimate is marked):
  * an item effect whose spell gives stats through auras the sim's parser reads the same way (see AURAS below):
      equip     - always there: the stats as they are;
      use       - on a cooldown: the stats times duration / cooldown (the share of the time it is up);
      proc      - on hit or cast: the stats times the share of the time it is up. A proc per minute is exact; a
                  chance per hit assumes one eligible hit every two seconds (an estimate, marked "~").
  * a set bonus: the stats it gives once the threshold of pieces is worn (StatsInfo counts the pieces itself).
  * a consumable: the stats its buff gives while it lasts (the sim's own parse; a potion lasts seconds).
  * percentages (crit, hit, haste, dodge, parry, block) stay percentages here: StatsInfo turns them into the
    rating of the character's level, which is what the weights are in.
  What is not counted: damage, healing and absorb effects, stacking effects, effects against some creature types
  only, resistances. An item that has such an effect is listed in UNRATED so the tooltip can say so.
"""
import argparse
import collections
import csv
import gzip
import json
import math
import re
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / "tools" / "db2-cache"
OUT = ROOT / "Modules" / "StatsInfo" / "EffectData.lua"
SIM_SHA = "c831b30f914b3b1b070cf63bc87d3af6953657b3"  # wowsims/forever master, 2026-11-19
SIM_RAW = "https://raw.githubusercontent.com/wowsims/forever/{sha}/{path}"

STAT_KEYS = ["ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_AGILITY_SHORT", "ITEM_MOD_STAMINA_SHORT",
             "ITEM_MOD_INTELLECT_SHORT", "ITEM_MOD_SPIRIT_SHORT"]  # the game's stat order of A_MOD_STAT
# the sim's Stat enum (proto/common.proto) -> the client's item keys (as tools/make_weights.py reads them back)
SIM_STAT = {
    0: "ITEM_MOD_STRENGTH_SHORT", 1: "ITEM_MOD_AGILITY_SHORT", 2: "ITEM_MOD_STAMINA_SHORT",
    3: "ITEM_MOD_INTELLECT_SHORT", 4: "ITEM_MOD_SPELL_HEALING_DONE_SHORT", 5: "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT",
    6: "ITEM_MOD_ARCANE_DAMAGE_DONE_SHORT", 7: "ITEM_MOD_FIRE_DAMAGE_DONE_SHORT",
    8: "ITEM_MOD_FROST_DAMAGE_DONE_SHORT", 9: "ITEM_MOD_HOLY_DAMAGE_DONE_SHORT",
    10: "ITEM_MOD_NATURE_DAMAGE_DONE_SHORT", 11: "ITEM_MOD_SHADOW_DAMAGE_DONE_SHORT",
    13: "ITEM_MOD_SPIRIT_SHORT", 14: "ITEM_MOD_ATTACK_POWER_SHORT", 15: "ITEM_MOD_RANGED_ATTACK_POWER_SHORT",
    16: "ITEM_MOD_FERAL_ATTACK_POWER_SHORT", 17: "ITEM_MOD_HIT_RATING_SHORT", 18: "ITEM_MOD_CRIT_RATING_SHORT",
    19: "ITEM_MOD_HASTE_RATING_SHORT", 20: "ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT",
    21: "ITEM_MOD_EXPERTISE_RATING_SHORT", 22: "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT",
    23: "ITEM_MOD_BLOCK_RATING_SHORT", 24: "ITEM_MOD_BLOCK_VALUE_SHORT", 25: "ITEM_MOD_DODGE_RATING_SHORT",
    26: "ITEM_MOD_PARRY_RATING_SHORT", 27: "RESISTANCE0_NAME", 28: "ITEM_MOD_EXTRA_ARMOR_SHORT",
    29: "ITEM_MOD_HEALTH_SHORT", 30: "ITEM_MOD_MANA_SHORT", 31: "ITEM_MOD_MANA_REGENERATION_SHORT",
    37: "ITEM_MOD_PHYSICAL_DAMAGE_DONE_SHORT", 38: "ITEM_MOD_EXTRA_ARMOR_SHORT",
}
# the weights table prices these; anything else (resistances, spell piercing, health) is dropped from the data
PRICED = set()
SCHOOL_KEYS = {1: "ITEM_MOD_PHYSICAL_DAMAGE_DONE_SHORT", 2: "ITEM_MOD_HOLY_DAMAGE_DONE_SHORT",
               4: "ITEM_MOD_FIRE_DAMAGE_DONE_SHORT", 8: "ITEM_MOD_NATURE_DAMAGE_DONE_SHORT",
               16: "ITEM_MOD_FROST_DAMAGE_DONE_SHORT", 32: "ITEM_MOD_SHADOW_DAMAGE_DONE_SHORT",
               64: "ITEM_MOD_ARCANE_DAMAGE_DONE_SHORT"}
MAGIC = 126
# A_MOD_RATING's misc bits (sim/core/dbcenums/ratings.go) -> what StatsInfo prices
RATING_BITS = [
    (0x2, "defense"), (0x4, "dodge"), (0x8, "parry"), (0x10, "block"),
    (0x20 | 0x40 | 0x80, "hit"), (0x100 | 0x200 | 0x400, "crit"),
    (0x20000 | 0x40000 | 0x80000, "haste"), (0x800000, "expertise"),
]
RATING_KEY = {"defense": "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT", "dodge": "ITEM_MOD_DODGE_RATING_SHORT",
              "parry": "ITEM_MOD_PARRY_RATING_SHORT", "block": "ITEM_MOD_BLOCK_RATING_SHORT",
              "hit": "ITEM_MOD_HIT_RATING_SHORT", "crit": "ITEM_MOD_CRIT_RATING_SHORT",
              "haste": "ITEM_MOD_HASTE_RATING_SHORT", "expertise": "ITEM_MOD_EXPERTISE_RATING_SHORT"}
# aura types that are a percentage of something a rating also gives: kept as "pct" for StatsInfo to convert
PCT_AURAS = {52: "crit", 57: "crit", 54: "hit", 55: "hit", 138: "haste", 140: "haste", 192: "haste", 319: "haste",
             65: "haste", 47: "parry", 49: "dodge", 51: "block"}
# aura types that only change how a spell is cast or a fight is run: nothing a stat can stand for, and no reason
# to tell the player the effect is unrated
HARMLESS = {4, 17, 154, 155, 144, 77, 31, 33, 129, 12, 41, 117, 232, 56, 73, 10, 14, 15, 87, 69, 3, 8, 24, 53, 23,
            42, 43, 107, 108, 22 | 0x1000}
# The implicit targets whose aura the wearer has: the caster (1), and the party, raid or an ally the effect names
# (the sim's items list the Lion Horn of Stormwind's party armor and Rock Sentinel's ally armor as the wearer's own).
WEARER_TARGETS = {1, 4, 20, 21, 32, 56, 57, 61}
DAMAGE_EFFECTS = {2, 10, 30, 8, 9, 64}  # school damage, heal, ... as a spell effect (not an aura)


def fetch(url, path):
    CACHE.mkdir(parents=True, exist_ok=True)
    if path.exists() and path.stat().st_size > 0:
        return path
    for attempt in range(3):
        r = subprocess.run(["curl", "-s", "-f", "-L", "-m", "300", "-o", str(path), url])
        if r.returncode == 0 and path.exists() and path.stat().st_size > 0:
            return path
        time.sleep(2 + attempt)
    sys.exit(f"could not fetch {url}")


class Spells:
    def __init__(self, store):
        self.effects = store["Effects"]
        self.misc = store["Misc"]
        self.opts = store["AuraOptions"]
        self.names = store["Names"]

    def duration(self, sid):
        d = (self.misc.get(str(sid)) or {}).get("DurationMs") or 0
        return d / 1000.0

    def stats(self, sid, depth=0):
        """(stats, pct, other): the stat keys and percentages the spell's auras give, and whether it has an effect
        this module cannot stand for with stats (damage, healing, absorb, stacking, ...). A proc aura
        (A_PROC_TRIGGER_SPELL) is followed one step to the buff it casts."""
        stats = collections.Counter()
        pct = {}
        other = False
        ap = rap = 0
        for e in self.effects.get(str(sid), []):
            t, a, bp, misc = e["Type"], e["Aura"], e["BasePoints"], e["Misc"]
            if t != 6:
                if t in DAMAGE_EFFECTS:
                    other = True
                continue
            # only an aura that lands on the wearer is theirs (WEARER_TARGETS). An enemy's debuff (a weapon that lowers the target's armor) is not a stat.
            if (e.get("Target") or [0])[0] not in WEARER_TARGETS:
                if a in (22, 674, 13, 135, 29, 99, 124, 189) or a in PCT_AURAS:
                    other = other or (e.get("Target") or [0])[0] not in (0, 5)  # an enemy's debuff: say so
                continue
            if a == 42 and e["TriggerID"] and depth == 0:  # the proc aura: what the buff it casts gives
                s2, p2, o2 = self.stats(e["TriggerID"], 1)
                for k, v in s2.items():
                    stats[k] += v
                for k, v in p2.items():
                    pct[k] = max(pct.get(k, 0), v)
                other = other or o2
                continue
            if a == 29:  # A_MOD_STAT
                if misc == -1:
                    for k in STAT_KEYS:
                        stats[k] += bp
                elif 0 <= misc <= 4:
                    stats[STAT_KEYS[misc]] += bp
            elif a == 99:
                ap += bp
            elif a == 124:
                rap += bp
            elif a == 13:  # A_MOD_DAMAGE_DONE by school mask
                if misc & 127 == 127 or misc == 127:
                    stats["ITEM_MOD_SPELL_DAMAGE_DONE_SHORT"] += bp
                    stats["ITEM_MOD_PHYSICAL_DAMAGE_DONE_SHORT"] += bp
                elif misc & MAGIC == MAGIC:
                    stats["ITEM_MOD_SPELL_DAMAGE_DONE_SHORT"] += bp
                else:
                    for bit, key in SCHOOL_KEYS.items():
                        if misc & bit:
                            stats[key] += bp
            elif a == 135:
                stats["ITEM_MOD_SPELL_HEALING_DONE_SHORT"] += bp
            elif a == 189:  # A_MOD_RATING: one rating converts into melee, ranged and spell alike
                for mask, name in RATING_BITS:
                    if misc & mask:
                        stats[RATING_KEY[name]] = max(stats[RATING_KEY[name]], bp)
            elif a == 85 and misc == 0:  # A_MOD_POWER_REGEN, mana, per 5 sec
                stats["ITEM_MOD_MANA_REGENERATION_SHORT"] += bp
            elif a == 274:  # A_MOD_BLOCK_VALUE_FLAT
                stats["ITEM_MOD_BLOCK_VALUE_SHORT"] += bp
            elif a in (34, 250):  # A_MOD_INCREASE_HEALTH(_2): flat health
                stats["ITEM_MOD_HEALTH_SHORT"] += bp
            elif a == 123 and misc & 1 and bp < 0:  # A_MOD_TARGET_RESISTANCE on armor: armor penetration
                stats["ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT"] += -bp
            elif a == 674:  # A_MOD_ARMOR_NO_MODS: bonus armor
                stats["ITEM_MOD_EXTRA_ARMOR_SHORT"] += bp
            elif a == 22 and misc & 1:  # A_MOD_RESISTANCE, armor
                stats["RESISTANCE0_NAME"] += bp
            elif a in PCT_AURAS:
                if 0 < bp <= 100:  # +N percent; a slow, a stun or an odd marker value is not a stat
                    pct[PCT_AURAS[a]] = max(pct.get(PCT_AURAS[a], 0), bp)
            elif a in HARMLESS or a == 0:
                pass
            elif a in (3, 53, 8, 69, 15, 24, 42, 43, 107, 108):
                other = True
            else:
                other = True
        if ap or rap:
            if ap == rap:
                stats["ITEM_MOD_ATTACK_POWER_SHORT"] += ap  # one "+N Attack Power": melee and ranged alike
            else:
                if ap:
                    stats["ITEM_MOD_ATTACK_POWER_SHORT"] += ap
                if rap:
                    stats["ITEM_MOD_RANGED_ATTACK_POWER_SHORT"] += rap
        return {k: v for k, v in stats.items() if v}, pct, other


# the sim's PseudoStat indexes (proto/common.proto) that are a percentage a rating also gives
PSEUDO_PCT = {4: "dodge", 5: "parry", 12: "hit", 13: "hit", 24: "hit", 14: "crit", 15: "crit", 25: "crit",
              16: "block", 20: "haste", 21: "haste", 22: "haste"}


def pseudo_pct(arr):
    """The percentages (crit, hit, haste, dodge, parry, block) of a sim pseudo-stat array; one channel's number
    is the percentage (the melee, ranged and spell ones state the same crit, so the largest stands)."""
    out = {}
    for idx, v in enumerate(arr or []):
        kind = PSEUDO_PCT.get(idx)
        if kind and v and 0 < v <= 100:
            out[kind] = max(out.get(kind, 0), v)
    return out


def uptime(kind, e, dur):
    """The share of the time the effect is up, and whether it is an estimate."""
    if kind == "equip":
        return 1.0, False
    if kind == "use":
        use = e.get("onUse") or {}
        cd = use.get("cooldownMs") or 0
        if cd <= 0:
            cd = use.get("categoryCooldownMs") or 0
        if cd <= 0 or dur <= 0:
            return 0.0, True
        return min(1.0, dur / (cd / 1000.0)), False
    proc = e.get("proc") or {}
    icd = (proc.get("icdMs") or 0) / 1000.0
    approx = False
    if proc.get("ppm"):
        rate = proc["ppm"] / 60.0
    elif proc.get("procChance"):
        rate = proc["procChance"] * 0.5  # one eligible hit every two seconds
        approx = True
    else:
        return 0.0, True
    if dur <= 0:
        return 0.0, True
    if icd >= dur:  # the buff cannot be refreshed while it runs: it is up dur out of dur + the wait for a proc
        rate = rate / (1 + rate * max(0.0, icd - dur))
        return (dur * rate) / (1 + dur * rate), approx
    return 1 - math.exp(-rate * dur), approx


def lua_val(v):
    return f"{v:g}" if isinstance(v, float) else str(v)


def lua_stats(d, pct=None):
    parts = [f"{k} = {lua_val(round(v, 4))}" for k, v in sorted(d.items())]
    if pct:
        parts.append("pct = { " + ", ".join(f"{k} = {lua_val(v)}" for k, v in sorted(pct.items())) + " }")
    return "{ " + ", ".join(parts) + " }"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sha", default=SIM_SHA)
    ap.add_argument("--build", default="1.60.1.70790")
    args = ap.parse_args()
    db = json.load(open(fetch(SIM_RAW.format(sha=args.sha, path="assets/database/db.json"),
                              CACHE / f"sim-db-{args.sha[:8]}.json"), encoding="utf-8"))
    store = json.loads(gzip.decompress(open(fetch(
        SIM_RAW.format(sha=args.sha, path="assets/db_inputs/spell_store_inputs.json"),
        CACHE / f"sim-spells-{args.sha[:8]}.json.gz"), "rb").read()))
    sets_csv = fetch(f"https://wago.tools/db2/ItemSetSpell/csv?build={args.build}",
                     CACHE / f"ItemSetSpell-{args.build}.csv")
    spells = Spells(store)

    # ---- item effects ---------------------------------------------------------------------------------------
    items_out, unrated, mismatches, checked = {}, [], [], 0
    for it in db["items"]:
        entries, any_other = [], False
        for e in it.get("itemEffects") or []:
            kind = "use" if "onUse" in e else "proc" if "proc" in e else "equip"
            sid = e["buffId"]
            stats, pct, other = spells.stats(sid)
            dur = (e.get("effectDurationMs") or 0) / 1000.0
            if dur <= 0:
                dur = spells.duration(sid)
            # the sim's own parse of the stats, where it has one: the check that this reads the auras the same
            sim = {}
            so = (e.get("scalingOptions") or {}).get("0") or {}
            for idx, v in (so.get("stats") or {}).items():
                if int(idx) in SIM_STAT and v:
                    sim[SIM_STAT[int(idx)]] = sim.get(SIM_STAT[int(idx)], 0) + v
            if sim:
                checked += 1
                # the sim writes "+N Attack Power" as both the melee and the ranged number
                if "ITEM_MOD_ATTACK_POWER_SHORT" in sim and sim.get("ITEM_MOD_RANGED_ATTACK_POWER_SHORT") == \
                        sim["ITEM_MOD_ATTACK_POWER_SHORT"]:
                    del sim["ITEM_MOD_RANGED_ATTACK_POWER_SHORT"]
                if {k: v for k, v in stats.items()} != sim:
                    mismatches.append((it["id"], it["name"], sid, stats, sim))
            if not stats and not pct:
                if kind != "equip" and other:
                    any_other = True
                continue
            if "stackingAura" in e or "stackProc" in e:
                any_other = True  # a stacking buff: the base counts, the stacks on top of it do not
            f, approx = uptime(kind, e, dur)
            if f <= 0:
                continue
            entry = {"kind": kind, "f": round(f, 4), "stats": stats, "pct": pct, "approx": approx}
            if kind == "use":
                entry["dur"] = dur
                entry["cd"] = ((e.get("onUse") or {}).get("cooldownMs") or 0) / 1000.0
            if kind == "proc":
                entry["dur"] = dur
            entries.append(entry)
            if other and kind != "equip":
                any_other = True
        # "+2% to hit" written on the item itself (its pseudo stats), where no equip effect already says it
        static = pseudo_pct(it.get("pseudoStats"))
        have = {k for e2 in entries if e2["kind"] == "equip" for k in e2["pct"]}
        static = {k: v for k, v in static.items() if k not in have}
        if static:
            entries.append({"kind": "equip", "f": 1.0, "stats": {}, "pct": static, "approx": False})
        if entries:
            items_out[it["id"]] = entries
        if any_other:
            unrated.append(it["id"])

    # ---- set bonuses ------------------------------------------------------------------------------------------
    item_set = {it["id"]: it["setId"] for it in db["items"] if it.get("setId")}
    sets = collections.defaultdict(dict)  # setId -> threshold -> (stats, pct)
    sets_unrated = set()
    with open(sets_csv, encoding="utf-8", newline="") as fh:
        for r in csv.DictReader(fh):
            sid, sset, thr = int(r["SpellID"]), int(r["ItemSetID"]), int(r["Threshold"])
            if str(sid) not in spells.effects:
                continue
            stats, pct, other = spells.stats(sid)
            if stats or pct:
                cur = sets[sset].setdefault(thr, ({}, {}))
                for k, v in stats.items():
                    cur[0][k] = cur[0].get(k, 0) + v
                for k, v in pct.items():
                    cur[1][k] = max(cur[1].get(k, 0), v)
            if other:
                sets_unrated.add(sset)
    used_sets = {s for s in item_set.values() if s in sets}

    # ---- consumables -------------------------------------------------------------------------------------------
    consumables = {}
    ctype = {1: "potion", 2: "flask", 3: "food", 4: "scroll", 11: "elixir", 12: "conjured", 7: "other"}
    for c in db["consumables"]:
        stats = collections.Counter()
        for idx, v in enumerate(c.get("stats") or []):
            if v and idx in SIM_STAT:
                stats[SIM_STAT[idx]] += v
        cpct = pseudo_pct(c.get("pseudoStats"))
        if not stats and not cpct:
            continue
        if stats.get("ITEM_MOD_ATTACK_POWER_SHORT") and \
                stats.get("ITEM_MOD_RANGED_ATTACK_POWER_SHORT") == stats["ITEM_MOD_ATTACK_POWER_SHORT"]:
            del stats["ITEM_MOD_RANGED_ATTACK_POWER_SHORT"]
        fx = (c.get("itemEffects") or [{}])[0]
        dur = spells.duration(fx["buffId"]) if fx.get("buffId") else 0
        if c.get("type") == 3:
            dur = 0  # food: the spell is the eating (10 s), the well-fed buff it casts is not in the data
        cd = max(0.0, ((fx.get("onUse") or {}).get("categoryCooldownMs") or 0) / 1000.0)
        consumables[c["id"]] = {"kind": ctype.get(c.get("type"), "other"), "dur": dur, "cd": cd,
                                "stats": dict(stats), "pct": cpct, "lvl": c.get("lvl") or 0,
                                "group": c.get("groupKey") or ""}

    # ---- write ----------------------------------------------------------------------------------------------
    out = [
        "-- UsefulPlatesAndTooltips module StatsInfo: what the effects of items, consumables and set bonuses give.",
        "-- Generated by tools/make_effects.py; change it there. Not edited by hand.",
        "--",
        f"-- Data: wowsims/forever {args.sha[:12]} (MIT; github.com/wowsims/forever: assets/database/db.json and",
        "-- assets/db_inputs/spell_store_inputs.json, the game's spell rows) and the game's ItemSetSpell table.",
        "-- f: the share of the time an effect is up (1 for an equip effect); approx: a proc by chance per hit,",
        "-- which assumes one eligible hit every two seconds. pct: percentages StatsInfo turns into the rating",
        "-- of the character's level. UNRATED: items with an effect that is not stats (damage, healing, stacks).",
        "",
        "local _, BIT = ...",
        "local M = BIT.Module(\"StatsInfo\")",
        "",
        "M.EFFECT_ITEMS = {",
    ]
    for iid in sorted(items_out):
        parts = []
        for e in items_out[iid]:
            extra = "".join(f", {k} = {lua_val(round(e[k], 3))}" for k in ("dur", "cd") if k in e)
            parts.append(f'{{ kind = "{e["kind"]}", f = {lua_val(e["f"])}{", approx = true" if e["approx"] else ""}'
                         f"{extra}, stats = {lua_stats(e['stats'])}"
                         f"{', pct = { ' + ', '.join(f'{k} = {lua_val(v)}' for k, v in sorted(e['pct'].items())) + ' }' if e['pct'] else ''} }}")
        out.append(f"  [{iid}] = {{ " + ", ".join(parts) + " },")
    out += ["}", "", "M.EFFECT_UNRATED = {"]
    out += [f"  [{i}] = true," for i in sorted(set(unrated))]
    out += ["}", "", "-- item -> set, and set -> { { pieces, stats, pct }, ... } in the order of the pieces", "M.ITEM_SETS = {"]
    for iid in sorted(item_set):
        if item_set[iid] in used_sets:
            out.append(f"  [{iid}] = {item_set[iid]},")
    out += ["}", "", "M.SETS = {"]
    for sid in sorted(used_sets):
        rows = []
        for thr in sorted(sets[sid]):
            st, pc = sets[sid][thr]
            rows.append(f"{{ {thr}, {lua_stats(st)}{', { ' + ', '.join(f'{k} = {lua_val(v)}' for k, v in sorted(pc.items())) + ' }' if pc else ''} }}")
        out.append(f"  [{sid}] = {{ " + ", ".join(rows) + " },")
    out += ["}", "", "M.SETS_UNRATED = {"]
    out += [f"  [{s}] = true," for s in sorted(sets_unrated & used_sets)]
    out += ["}", "", "-- item -> { kind, seconds it lasts, shared cooldown, stats, level, exclusive group }", "M.CONSUMABLES = {"]
    for cid in sorted(consumables):
        c = consumables[cid]
        out.append(f'  [{cid}] = {{ kind = "{c["kind"]}", dur = {lua_val(round(c["dur"], 1))}, '
                   f'cd = {lua_val(round(c["cd"], 1))}, lvl = {c["lvl"]}, group = "{c["group"]}", '
                   f"stats = {lua_stats(c['stats'])}"
                   f"{', pct = { ' + ', '.join(f'{k} = {lua_val(v)}' for k, v in sorted(c['pct'].items())) + ' }' if c['pct'] else ''} }},")
    out += ["}", ""]
    OUT.write_text("\n".join(out), encoding="utf-8", newline="\n")
    print(f"wrote {OUT}")
    print(f"item effects counted: {len(items_out)} items ({sum(len(v) for v in items_out.values())} effects), "
          f"{len(set(unrated))} items with an unrated effect")
    print(f"sets with a counted bonus: {len(used_sets)} ({sum(1 for i,s in item_set.items() if s in used_sets)} items); "
          f"consumables with stats: {len(consumables)}")
    print(f"checked against the sim's own parse: {checked} effects, {len(mismatches)} differ")
    for m in mismatches[:25]:
        print("   ", m)


if __name__ == "__main__":
    main()
