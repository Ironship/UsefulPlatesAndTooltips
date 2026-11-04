"""Writes Modules/SpellDamageInfo/SpellCoefficientsLinked.lua: spell power shares for spells whose damage or healing the
client's SpellEffect tables do not attach to the spell itself.

    python tools/make_linked_coefficients.py [--build 1.60.1.70755]

Holy Shock, Fire Nova, Consecration, Blizzard and Rain of Fire cast a second spell (or an area trigger) that carries the
number. The cast spell's description names it: "$25912s1 Holy damage", "${$1280346m1*8}", "${$1279976m1*$d}". This reads
those references, takes the EffectBonusCoefficient of the referenced effect and, where the description multiplies it
(by a count or by the duration), the number of ticks. Only the spells in WHITELIST are written: each one was checked
against the shape the parser reads from Forever's own text (one direct hit, a heal beside it, or one total over time).
Hurricane (a number per tick), the seals (several numbers in a description), Penance (three bolts) and Healing Rain
(a script term) are left to the rules.
"""
import argparse
import collections
import csv
import re
import subprocess
import sys
import time
from pathlib import Path

root = Path(__file__).resolve().parent.parent
CACHE = root / "tools" / "db2-cache"
TABLES = ("SpellName", "Spell", "SpellEffect", "SpellMisc", "SpellDuration", "SkillLineAbility")
WHITELIST = ("Holy Shock", "Fire Nova", "Consecration", "Blizzard", "Rain of Fire")


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
    descriptions = {r["ID"]: r["Description_lang"] for r in rows("Spell")}
    durations = {r["ID"]: int(r["Duration"]) for r in rows("SpellDuration")}
    duration = {r["SpellID"]: durations.get(r["DurationIndex"], 0) for r in rows("SpellMisc") if r["DifficultyID"] == "0"}
    effects = collections.defaultdict(list)
    for r in rows("SpellEffect"):
        if r["DifficultyID"] == "0":
            effects[r["SpellID"]].append(r)
    for v in effects.values():
        v.sort(key=lambda r: int(r["EffectIndex"]))
    learnable = {r["Spell"] for r in rows("SkillLineAbility")}

    def share(ref, index):
        """(kind, coefficient) of effect `index` (1-based, as in $m1) of spell `ref`."""
        es = effects.get(ref, [])
        if index - 1 >= len(es):
            return None
        e = es[index - 1]
        c = float(e["EffectBonusCoefficient"] or 0)
        if c <= 0:
            return None
        if e["Effect"] == "2":
            return "damage", c
        if e["Effect"] == "10":
            return "heal", c
        return None

    result = {}
    for sid, name in names.items():
        if name not in WHITELIST or sid not in learnable:
            continue
        text = descriptions.get(sid, "")
        entry = collections.defaultdict(float)
        # ${count*$ref m1}, ${$ref m1*count} and ${$ref m1*$d}: a total over time
        for m in re.finditer(r"\$\{\s*(?:(\d+)\s*\*\s*)?\$(\d{4,})[sm](\d)\s*(?:\*\s*(\d+|\$d))?", text):
            before, ref, index, after = m.groups()
            got = share(ref, int(index))
            if not got:
                continue
            ticks = 1.0
            if before:
                ticks *= int(before)
            if after:
                ticks *= duration.get(sid, 0) / 1000 if after == "$d" else int(after)
            entry["o" if got[0] == "damage" else "ho"] += got[1] * ticks
        # $ref s1: one hit or one heal
        for m in re.finditer(r"(?<![{*\d])\$(\d{4,})s(\d)", text):
            got = share(m.group(1), int(m.group(2)))
            if got:
                entry["d" if got[0] == "damage" else "h"] += got[1]
        if entry:
            result[int(sid)] = {k: round(v, 3) for k, v in entry.items()}

    lines = [
        "-- UsefulPlatesAndTooltips module SpellDamageInfo: spell power shares for spells whose damage or healing the client's",
        f"-- SpellEffect tables attach to a second spell (build {build}); see tools/make_linked_coefficients.py for how each",
        "-- number is worked out. Generated; do not edit by hand. Copyright (c) 2026 Ironship. GPL-3.0-or-later.",
        "-- Only fills spells SpellCoefficients.lua does not have; the same keys as there (d, o, h, ho).",
        "",
        "local _, BIT = ...",
        "local ns = BIT.Module(\"SpellDamageInfo\")",
        "",
        "local linked = {",
    ]
    for sid in sorted(result):
        body = ",".join(f"{k}={result[sid][k]:g}" for k in ("d", "o", "h", "ho") if k in result[sid])
        lines.append(f"  [{sid}]={{{body}}},  -- {names[str(sid)]}")
    lines += [
        "}",
        "",
        "local forever = ns.SpellCoefficients and ns.SpellCoefficients.forever",
        "if forever then",
        "  for id, entry in pairs(linked) do",
        "    if forever[id] == nil then forever[id] = entry end",
        "  end",
        "end",
        "",
    ]
    (root / "Modules" / "SpellDamageInfo" / "SpellCoefficientsLinked.lua").write_text("\n".join(lines), encoding="utf-8", newline="\n")
    print(f"SpellCoefficientsLinked.lua: {len(result)} spells of {len(WHITELIST)} names (build {build})")


if __name__ == "__main__":
    main()
