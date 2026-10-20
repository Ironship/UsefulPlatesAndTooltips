"""UsefulPlatesAndTooltips module CastPrediction — the aura modifiers (Auras.lua), tested against
the same fake game tests/test_bit.py uses.

    python tests/test_cast_prediction_auras.py

Buffs on the player and debuffs on the target multiply the cast estimate when the client shows
them. An aura the client hides (a secret value, or Forever in combat) adds nothing -- it is never
treated as absent -- and every entry can be switched off.
"""
import ast
import pathlib
import sys

from lupa.lua51 import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
TOC = (ROOT / "UsefulPlatesAndTooltips.toc").read_text(encoding="utf-8").splitlines()
FILES = [line.strip().replace("\\", "/") for line in TOC if line.strip() and not line.startswith("#")]
LOADED = [name for name in FILES if name.startswith("Core/") or name.startswith("Modules/SpellDamageInfo/")
          or name.startswith("Modules/CastPrediction/")]

FIRE_SPELL = 900117
FROST_SPELL = 900118
ARCANE_BLAST = 900119


def fake_prefix():
    src = (pathlib.Path(__file__).parent / "test_bit.py").read_text(encoding="utf-8")
    tree = ast.parse(src)
    for node in tree.body:
        if isinstance(node, ast.Assign) and any(
            isinstance(t, ast.Name) and t.id == "FAKE" for t in node.targets
        ):
            return ast.literal_eval(node.value)
    raise SystemExit("tests/test_bit.py no longer holds FAKE = ...; adapt test_cast_prediction_auras.py")


FAKE = fake_prefix()

EXT = r"""
function GetBuildInfo() return "1.60.1", "70009", "Sep 23 2026", 16001 end
function GetLocale() return "enUS" end
playerClass = "MAGE"
-- The aura store: units.player/target with buffs/debuffs arrays of { spellId, applications }.
auras = { player = { buffs = {}, debuffs = {} }, target = { buffs = {}, debuffs = {} } }
SECRET = { secret = true }
function issecretvalue(v) return rawequal(v, SECRET) end
local function byIndex(unit, i, kind)
    local list = auras[unit] and auras[unit][kind]
    if not list then return nil end
    return list[i]
end
C_UnitAuras = {
    GetBuffDataByIndex = function(unit, i) return byIndex(unit, i, "buffs") end,
    GetDebuffDataByIndex = function(unit, i) return byIndex(unit, i, "debuffs") end,
}
castTimes = {}
local baseGetSpellInfo = C_Spell.GetSpellInfo
C_Spell.GetSpellInfo = function(id)
    if castTimes[id] then return { castTime = castTimes[id] } end
    return { castTime = 0 }
end
castTimes[FIRE_SPELL] = 2500
castTimes[FROST_SPELL] = 2000
castTimes[ARCANE_BLAST] = 2500
"""
EXT = EXT.replace("FIRE_SPELL", str(FIRE_SPELL)).replace("FROST_SPELL", str(FROST_SPELL)).replace("ARCANE_BLAST", str(ARCANE_BLAST))


def check(label, actual, expected, tolerance=0.0001):
    if isinstance(actual, float) or isinstance(expected, float):
        ok = actual is not None and abs(actual - expected) < tolerance
    else:
        ok = actual == expected
    print(("ok   " if ok else "FAIL ") + label + ("" if ok else f"   (got {actual!r}, expected {expected!r})"))
    return ok


def multiplier(auras, name, school):
    res = auras.MultiplierFor(name, school)
    return res[0], res[1]


def load():
    rt = LuaRuntime(unpack_returned_tuples=True)
    rt.execute(FAKE + EXT)
    G = rt.globals()
    addon = rt.eval("{}")
    loader = rt.eval("function(src, name, addon) local f = assert(loadstring(src, '@' .. name)); "
                     "return f('UsefulPlatesAndTooltips', addon) end")
    for name in LOADED:
        loader((ROOT / name).read_text(encoding="utf-8"), name, addon)
    G.Fire("ADDON_LOADED", "UsefulPlatesAndTooltips")
    G.Fire("PLAYER_LOGIN")
    G.target = rt.eval("{ hostile = true }")
    G.units.target = rt.eval('{ guid = "Creature-Auras", health = 800, max = 1000 }')
    G.spellNames[FIRE_SPELL] = "Fireball"
    G.spellDesc[FIRE_SPELL] = "Inflicts 500 to 600 Fire damage."
    G.spellNames[FROST_SPELL] = "Frostbolt"
    G.spellDesc[FROST_SPELL] = "Inflicts 400 to 500 Frost damage."
    G.spellNames[ARCANE_BLAST] = "Arcane Blast"
    G.spellDesc[ARCANE_BLAST] = "Inflicts 450 to 550 Arcane damage."
    return rt, G, addon


def set_aura(rt, unit, kind, entries):
    if not entries:
        rt.execute(f"auras.{unit}.{kind} = {{}}")
        return
    parts = ", ".join(f"{{ spellId = {sid}, applications = {stacks} }}" for sid, stacks in entries)
    rt.execute(f"auras.{unit}.{kind} = {{ {parts} }}")


def main():
    failures = 0
    rt, G, addon = load()
    ns = addon.modules.CastPrediction
    auras = ns.Auras
    settings = ns._settings()

    print("-- readable auras multiply the estimate")
    set_aura(rt, "player", "buffs", [(12042, 1)])          # Arcane Power +30%
    mult, percent = multiplier(auras, "Fireball", "fire")
    failures += not check("Arcane Power is applied", mult, 1.30)
    failures += not check("  and reported for the trace", percent, 0.30, 1e-9)

    set_aura(rt, "target", "debuffs", [(22959, 5)])        # Improved Scorch 5 stacks +15%
    mult, _ = multiplier(auras, "Fireball", "fire")
    failures += not check("Improved Scorch stacks multiply again", mult, 1.30 * 1.15)
    mult, _ = multiplier(auras, "Frostbolt", "frost")
    failures += not check("  and do not touch frost", mult, 1.30)
    set_aura(rt, "target", "debuffs", [])

    print("-- Arcane Blast stacks help other spells, never the Arcane Blast itself")
    set_aura(rt, "player", "buffs", [(400573, 4)])
    mult, _ = multiplier(auras, "Fireball", "fire")
    failures += not check("four stacks give +40%", mult, 1.40)
    mult, _ = multiplier(auras, "Arcane Blast", "arcane")
    failures += not check("the Arcane Blast cast itself is left alone", mult, 1.0)

    print("-- a verify entry is never applied until read in game")
    set_aura(rt, "player", "buffs", [])
    set_aura(rt, "target", "debuffs", [(11722, 1)])        # Curse of the Elements (verify)
    mult, _ = multiplier(auras, "Fireball", "fire")
    failures += not check("Curse of the Elements stays out (verify)", mult, 1.0)
    set_aura(rt, "target", "debuffs", [])

    print("-- a hidden aura adds nothing and never errors")
    rt.execute("auras.player.buffs = { { spellId = SECRET, applications = 1 } }")
    res = auras.MultiplierFor("Fireball", "fire")
    failures += not check("a secret aura leaves the estimate alone", res[0], 1.0)
    failures += not check("  and is marked unknown", res[3], True)

    print("-- the master switch and per-entry Off")
    set_aura(rt, "player", "buffs", [(12042, 1)])
    settings.useAuras = False
    mult, _ = multiplier(auras, "Fireball", "fire")
    failures += not check("the switch turns auras off", mult, 1.0)
    settings.useAuras = True
    settings.auraForce["PLAYER_ARCANE_POWER"] = "off"
    mult, _ = multiplier(auras, "Fireball", "fire")
    failures += not check("one entry can be switched off", mult, 1.0)
    settings.auraForce["PLAYER_ARCANE_POWER"] = None

    print("-- the probe reads stacks")
    lines = auras.ProbeLines()
    joined = []
    for i in range(1, len(lines) + 1):
        joined.append(str(lines[i]))
    text = "\n".join(joined)
    failures += not check("the probe names Arcane Power", "Arcane Power [player]: stacks 1" in text, True)

    print("-- a cast carries auras into the marker")
    set_aura(rt, "player", "buffs", [(12042, 1)])
    set_aura(rt, "target", "debuffs", [(22959, 5)])
    G.Fire("UNIT_SPELLCAST_START", "player", "cast-1", FIRE_SPELL)
    cast = ns._cast()
    failures += not check("the cast is up", cast is not None, True)
    failures += not check("  with Arcane Power and Scorch in the range", cast.prediction.min, 500 * 1.30 * 1.15, 1e-2)
    failures += not check("  and the aura total remembered", cast.prediction.auraPercent, 1.30 * 1.15 - 1, 1e-6)
    G.Fire("UNIT_SPELLCAST_FAILED", "player", "cast-1", FIRE_SPELL)

    print(f"failed: {failures}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
