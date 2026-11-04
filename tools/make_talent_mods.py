"""Writes Core/TalentModsData.lua: the talents of WoW: Forever that raise damage or healing, with the percent of every rank.

    python tools/make_talent_mods.py [--build 1.60.1.70755]

Everything comes from the client's own tables (wago.tools CSVs, cached in tools/db2-cache, delete it to fetch again):
  TraitTree / TraitNode / TraitNodeXTraitNodeEntry / TraitNodeEntry   which talents sit on a live class tree, and their ranks
  TraitDefinition                                                       the talent's spell
  SpellEffect                                                           what that spell does (the aura and its class mask)
  TraitDefinitionEffectPoints + CurvePoint                              the value of each rank of each effect
  SkillLine / SkillLineAbility / SpellClassOptions                      which class spells a "spell mod" reaches

Two kinds of effect are read:
  aura 79   "damage done" by school (Moonfury, Darkness): every spell of the schools in the mask
  aura 108  a percent "spell mod" (Shadow Mastery, Aftermath): operation 0 = direct damage or healing, 22 = over time,
            8 = every effect, 3 / 12 / 23 = the first / second / third effect; it reaches the spells of the talent's own
            family (SpellClassOptions.SpellClassSet) that share a bit of the effect's class mask
Left out on purpose (SKIP): talents that need a weapon, a shield, a form, a proc or a cooldown, and absorb shields.
A spell can sit on two live trees (druid, shaman): the definition whose values rise with the rank wins.
"""
import argparse
import collections
import csv
import json
import re
import subprocess
import sys
import time
from pathlib import Path

root = Path(__file__).resolve().parent.parent
CACHE = root / "tools" / "db2-cache"
TABLES = ("SpellName", "SpellEffect", "SkillLine", "SkillLineAbility", "SpellClassOptions", "TraitTree", "TraitNode",
          "TraitNodeXTraitNodeEntry", "TraitNodeEntry", "TraitDefinition", "TraitDefinitionEffectPoints", "CurvePoint")
CLASS_SET = {"3": "MAGE", "4": "WARRIOR", "5": "WARLOCK", "6": "PRIEST", "7": "DRUID", "8": "ROGUE", "9": "HUNTER",
             "10": "PALADIN", "11": "SHAMAN"}
CLASS_MASK = {1: "WARRIOR", 2: "PALADIN", 4: "HUNTER", 8: "ROGUE", 16: "PRIEST", 64: "SHAMAN", 128: "MAGE", 256: "WARLOCK",
              1024: "DRUID"}
NOT_CLASS_LINE = re.compile(r"^(Pet|Beast Training|Mounts|Companions|Meditation|Racial|Orc Racial|Comprehension|Runes|GENERIC)")
SKIP = re.compile(r"Weapon Specialization|Wand Specialization|Lone Wolf|Bestial Wrath|Death Wish|Arcane Power|Power Infusion|"
                  r"Shadowform|Bastion|^Ice Barrier$|Decimation|Frost Warding|Improved Power Word: Shield|"
                  r"Improved Health Funnel|Ranged Weapon")
OPS = {"0": "d", "22": "o", "8": "both", "3": 0, "12": 1, "23": 2}


def fetch(table, build):
    CACHE.mkdir(parents=True, exist_ok=True)
    path = CACHE / f"{table}-{build}.csv"
    if path.exists() and path.stat().st_size > 0:
        return path
    url = f"https://wago.tools/db2/{table}/csv?build={build}"
    for attempt in range(3):
        r = subprocess.run(["curl", "-s", "-f", "-m", "300", "-o", str(path), url])
        if r.returncode == 0 and path.exists() and path.stat().st_size > 0:
            return path
        time.sleep(2 + attempt)
    sys.exit(f"could not fetch {url}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--build", default="1.60.1.70755")
    build = ap.parse_args().build

    def rows(table):
        with open(fetch(table, build), encoding="utf-8", newline="") as f:
            return list(csv.DictReader(f))

    names = {r["ID"]: r["Name_lang"] for r in rows("SpellName")}
    effects = collections.defaultdict(list)
    for r in rows("SpellEffect"):
        if r["DifficultyID"] == "0":
            effects[r["SpellID"]].append(r)
    for v in effects.values():
        v.sort(key=lambda r: int(r["EffectIndex"]))
    class_options = {r["SpellID"]: r for r in rows("SpellClassOptions")}

    # the class spells that do damage or healing, and which effect is direct (d) or over time (o)
    lines = {r["ID"]: r for r in rows("SkillLine")}
    line_class = collections.defaultdict(collections.Counter)
    abilities = rows("SkillLineAbility")
    for r in abilities:
        if int(r["ClassMask"]) in CLASS_MASK:
            line_class[r["SkillLine"]][int(r["ClassMask"])] += 1
    parts_of = {}
    for r in abilities:
        line = lines.get(r["SkillLine"])
        if not line or line["CategoryID"] not in ("7", "9") or NOT_CLASS_LINE.match(line["DisplayName_lang"]):
            continue
        if int(r["ClassMask"]) not in CLASS_MASK and len(line_class[r["SkillLine"]]) != 1:
            continue
        parts = {}
        for e in effects.get(r["Spell"], []):
            i = int(e["EffectIndex"])
            if e["Effect"] in ("2", "9", "10", "62"):
                parts[i] = "d"
            elif e["Effect"] in ("6", "27", "35", "65") and e["EffectAura"] in ("3", "53", "8"):
                parts[i] = "o"
        if parts:
            parts_of[r["Spell"]] = parts

    def affected(class_set, masks, want):
        out = []
        for sid, parts in parts_of.items():
            o = class_options.get(sid)
            if not o or o["SpellClassSet"] != class_set:
                continue
            if any(int(o[f"SpellClassMask_{i}"]) & int(masks[i]) for i in range(4)):
                if want == "both" or want in set(parts.values()):
                    out.append((sid, None))
                elif isinstance(want, int) and parts.get(want):
                    out.append((sid, parts[want]))
        return out

    # live class trees: a tree with Flags & 1; its class is the family most of its talent spells belong to
    definitions = {r["ID"]: r for r in rows("TraitDefinition")}
    entries_by_id = {r["ID"]: r for r in rows("TraitNodeEntry")}
    trees = {r["ID"]: r for r in rows("TraitTree")}
    nodes = {r["ID"]: r for r in rows("TraitNode")}
    entries, tree_defs = {}, collections.defaultdict(set)
    for x in rows("TraitNodeXTraitNodeEntry"):
        node, e = nodes.get(x["TraitNodeID"]), entries_by_id.get(x["TraitNodeEntryID"])
        tree = trees.get(node["TraitTreeID"]) if node else None
        if e and tree and int(tree["Flags"]) & 1:
            entries[e["TraitDefinitionID"]] = e
            tree_defs[node["TraitTreeID"]].add(e["TraitDefinitionID"])
    tree_class = {}
    for tid, dids in tree_defs.items():
        c = collections.Counter(class_options[definitions[d]["SpellID"]]["SpellClassSet"] for d in dids
                                if d in definitions and definitions[d]["SpellID"] in class_options
                                and class_options[definitions[d]["SpellID"]]["SpellClassSet"] in CLASS_SET)
        tree_class[tid] = CLASS_SET[c.most_common(1)[0][0]] if c else None
    definition_tree = {d: t for t, ds in tree_defs.items() for d in ds}

    points = collections.defaultdict(dict)
    for r in rows("TraitDefinitionEffectPoints"):
        points[r["TraitDefinitionID"]][int(r["EffectIndex"])] = r
    curve = collections.defaultdict(dict)
    for r in rows("CurvePoint"):
        curve[r["CurveID"]][int(float(r["Pos_0"]))] = float(r["Pos_1"])

    def by_rank(did, index, base, max_ranks):
        point = points.get(did, {}).get(index)
        if point and point["CurveID"] in curve:
            return [curve[point["CurveID"]].get(r, 0.0) for r in range(1, max_ranks + 1)]
        return [base] * max_ranks

    talents = []
    for did, entry in entries.items():
        definition = definitions.get(did)
        if not definition:
            continue
        spell, max_ranks = definition["SpellID"], int(entry["MaxRanks"])
        options = class_options.get(spell)
        mods = []
        for e in effects.get(spell, []):
            if e["Effect"] != "6":
                continue
            aura, index = e["EffectAura"], int(e["EffectIndex"])
            values = by_rank(did, index, float(e["EffectBasePointsF"] or 0), max_ranks)
            masks = [e[f"EffectSpellClassMask_{k}"] for k in range(4)]
            if aura == "79":
                mods.append({"k": "s", "m": int(e["EffectMiscValue_0"]), "p": values})
            elif aura == "108" and e["EffectMiscValue_0"] in OPS and options and any(int(m) for m in masks):
                op = OPS[e["EffectMiscValue_0"]]
                if isinstance(op, str):
                    ids = sorted({int(s) for s, _ in affected(options["SpellClassSet"], masks, op)})
                    if ids:
                        mods.append({"k": {"d": "d", "o": "o", "both": "b"}[op], "ids": ids, "p": values})
                else:
                    by_part = collections.defaultdict(set)
                    for s, part in affected(options["SpellClassSet"], masks, op):
                        by_part[part].add(int(s))
                    for part, ids in by_part.items():
                        mods.append({"k": part, "ids": sorted(ids), "p": values})
        if mods:
            talents.append({"cls": tree_class.get(definition_tree.get(did)), "name": names.get(spell, "?"),
                            "id": int(spell), "max": max_ranks, "mods": mods})

    def weight(t):
        return sum(max(m["p"]) * (len(set(m["p"])) > 1 or t["max"] == 1) + max(m["p"]) * 0.001 for m in t["mods"])
    best = {}
    for t in talents:
        key = (t["cls"], t["id"])
        if key not in best or weight(t) > weight(best[key]):
            best[key] = t

    def ranges(ids):
        out, i = [], 0
        while i < len(ids):
            j = i
            while j + 1 < len(ids) and ids[j + 1] == ids[j] + 1:
                j += 1
            out.append(str(ids[i]) if i == j else f"{ids[i]}-{ids[j]}")
            i = j + 1
        return ",".join(out)

    def nums(p):
        return "{" + ",".join("%g" % v for v in p) + "}"

    by_class, kept = {}, 0
    for t in sorted(best.values(), key=lambda t: (t["cls"] or "", t["name"])):
        if not t["cls"] or SKIP.search(t["name"]):
            continue
        kept += 1
        mods = []
        for m in t["mods"]:
            if m["k"] == "s":
                mods.append('{k="s",m=%d,p=%s}' % (m["m"], nums(m["p"])))
            else:
                mods.append('{k="%s",ids="%s",p=%s}' % (m["k"], ranges(m["ids"]), nums(m["p"])))
        by_class.setdefault(t["cls"], []).append('    {id=%d,en="%s",max=%d,mods={\n      %s}},' % (
            t["id"], t["name"].replace('"', '\\"'), t["max"], ",\n      ".join(mods)))

    out = [
        "-- DoesItDiePlus: the talents of WoW: Forever that change the damage or healing of your spells, with the value of every",
        f"-- rank, read from the client's own tables (build {build}): TraitNodeEntry/TraitDefinition give the talent spell, its",
        "-- effects give what it modifies, TraitDefinitionEffectPoints + Curve/CurvePoint give the value of each rank, and",
        "-- SpellClassOptions names the spells a \"spell mod\" reaches (same spell family, shared class-mask bit).",
        "-- Generated by tools/make_talent_mods.py; do not edit by hand. Copyright (c) 2026 Ironship. GPL-3.0-or-later.",
        "--",
        "-- Per talent: id = the talent's spell id, max = its ranks, mods:",
        "--   k=\"s\"  every spell of the schools in the mask m (1 physical, 2 holy, 4 fire, 8 nature, 16 frost, 32 shadow, 64 arcane)",
        "--   k=\"d\"  the direct damage or healing of the spell ids in ids (a list of ids and id ranges)",
        "--   k=\"o\"  the periodic damage or healing of those spells, k=\"b\" both",
        "-- p[rank] = the percent that rank adds. Left out on purpose: talents that need a weapon, a shield, a form, a proc or",
        "-- a cooldown (Death Wish, Weapon Specialization, Shadowform, Decimation...), which the aura rules or nothing handle.",
        "",
        "local _, BIT = ...",
        "BIT = BIT or {}",
        "BIT.TalentModData = {",
    ]
    for cls in sorted(by_class):
        out.append(f"  {cls} = {{")
        out += by_class[cls]
        out.append("  },")
    out.append("}")
    (root / "Core" / "TalentModsData.lua").write_text("\n".join(out) + "\n", encoding="utf-8", newline="\n")
    print(f"Core/TalentModsData.lua: {kept} talents of {len(best)} with a damage or healing modifier (build {build})")


if __name__ == "__main__":
    main()
