"""UsefulPlatesAndTooltips module CastPrediction — the passive talent multipliers (Talents.lua),
tested against the same fake game tests/test_bit.py uses.

    python tests/test_cast_prediction_talents.py

Forever folds no talents into spell descriptions, so the module multiplies the cast's estimate
by the curated passive percents, with ranks read from the client's talent tree by spell name
(C_ClassTalents/C_Traits). Retail descriptions already hold them: there the multiplier is 1.
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


def fake_prefix():
    src = (pathlib.Path(__file__).parent / "test_bit.py").read_text(encoding="utf-8")
    tree = ast.parse(src)
    for node in tree.body:
        if isinstance(node, ast.Assign) and any(
            isinstance(t, ast.Name) and t.id == "FAKE" for t in node.targets
        ):
            return ast.literal_eval(node.value)
    raise SystemExit("tests/test_bit.py no longer holds FAKE = ...; adapt test_cast_prediction_talents.py")


FAKE = fake_prefix()

EXT = r"""
-- The client version decides Retail vs Forever; the tests flip this.
buildVersion = "1.60.1"
function GetBuildInfo() return buildVersion, "70009", "Sep 23 2026", 16001 end
function GetLocale() return "enUS" end
playerClass = "MAGE"
local realUnitClass = UnitClass
function UnitClass() return "Magier", playerClass, 8 end
-- The talent tree: two nodes. Node 101 is Fire Power 5/5, node 102 is Arcane Instability 3/3;
-- the names come from the spell ids via C_Spell.GetSpellName (spellNames).
traitsOff = false
firePowerRank = 5
C_ClassTalents = { GetActiveConfigID = function() return 7 end }
C_Traits = {
    GetConfigInfo = function(id) if traitsOff then return nil end return { treeIDs = { 1 } } end,
    GetTreeNodes = function(treeID) return { 101, 102 } end,
    GetNodeInfo = function(configID, nodeID)
        if nodeID == 101 then return { ranksPurchased = firePowerRank, maxRanks = 5, activeEntry = 11 } end
        if nodeID == 102 then return { ranksPurchased = 3, maxRanks = 3, activeEntry = 12 } end
    end,
    GetEntryInfo = function(configID, entry) return { definitionID = entry } end,
    GetDefinitionInfo = function(definition)
        if definition == 11 then return { spellID = 5001 } end
        if definition == 12 then return { spellID = 5002 } end
    end,
}
spellNames[5001] = "Fire Power"
spellDesc[5001] = "Increases the damage done by your Fire spells by 10%."
spellNames[5002] = "Arcane Instability"
spellDesc[5002] = "Increases your spell damage and critical strike chance by 3%."
castTimes = {}
local baseGetSpellInfo = C_Spell.GetSpellInfo
C_Spell.GetSpellInfo = function(id)
    if castTimes[id] then return { castTime = castTimes[id] } end
    return { castTime = 0 }
end
castTimes[FIRE_SPELL] = 2500
castTimes[FROST_SPELL] = 2000
"""
EXT = EXT.replace("FIRE_SPELL", str(FIRE_SPELL)).replace("FROST_SPELL", str(FROST_SPELL))


def multiplier(talents, name, school):
    res = talents.MultiplierFor(name, school)
    return res[0], res[1]


def check(label, actual, expected, tolerance=0.0001):
    if isinstance(actual, float) or isinstance(expected, float):
        ok = actual is not None and abs(actual - expected) < tolerance
    else:
        ok = actual == expected
    print(("ok   " if ok else "FAIL ") + label + ("" if ok else f"   (got {actual!r}, expected {expected!r})"))
    return ok


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
    G.units.target = rt.eval('{ guid = "Creature-Talents", health = 800, max = 1000 }')
    G.spellNames[FIRE_SPELL] = "Fireball"
    G.spellDesc[FIRE_SPELL] = "Inflicts 500 to 600 Fire damage."
    G.spellNames[FROST_SPELL] = "Frostbolt"
    G.spellDesc[FROST_SPELL] = "Inflicts 400 to 500 Frost damage."
    return rt, G, addon


def main():
    failures = 0
    rt, G, addon = load()
    ns = addon.modules.CastPrediction
    talents = ns.Talents
    settings = ns._settings()

    print("-- the curated list and the tree read")
    failures += not check("Talents is loaded", talents is not None, True)
    failures += not check("the list holds entries", len(talents.LIST) > 0, True)
    failures += not check("no manual force to start", len(settings.talentForce), 0)

    mult, percent = multiplier(talents, "Fireball", "fire")
    failures += not check("Fire Power 5/5 and Arcane Instability 3/3 stack on fire", mult, 1 + 0.10 + 0.03)
    failures += not check("  percent carried for the trace", percent, 0.13, 1e-9)
    mult, _ = multiplier(talents, "Frostbolt", "frost")
    failures += not check("only the all-school talent hits frost", mult, 1.03)

    G.playerClass = "WARLOCK"
    mult, _ = multiplier(talents, "Shadow Bolt", "shadow")
    failures += not check("Shadow Mastery has no ranks in this tree -> none applied", mult, 1.0)
    G.playerClass = "MAGE"

    print("-- the tree cache and its invalidation")
    G.firePowerRank = 2
    mult, _ = multiplier(talents, "Fireball", "fire")
    failures += not check("a changed tree is not seen before Invalidate", mult, 1.13)
    talents.Invalidate()
    mult, _ = multiplier(talents, "Fireball", "fire")
    failures += not check("after Invalidate the new rank applies", mult, 1 + 0.04 + 0.03)

    print("-- the manual override (Auto is the default; Off and Max are forced)")
    settings.talentForce["MAGE_FIRE_POWER"] = "off"
    mult, _ = multiplier(talents, "Fireball", "fire")
    failures += not check("Off removes the fire talent", mult, 1.03)
    settings.talentForce["MAGE_FIRE_POWER"] = "max"
    mult, _ = multiplier(talents, "Fireball", "fire")
    failures += not check("Max applies the full rank without the tree", mult, 1.13)
    settings.talentForce["MAGE_FIRE_POWER"] = None

    print("-- an unavailable tree leaves Auto unknown (no guessing)")
    G.traitsOff = True
    talents.Invalidate()
    mult, _ = multiplier(talents, "Frostbolt", "frost")
    failures += not check("nothing is applied when nothing answers", mult, 1.0)
    mult, _ = multiplier(talents, "Fireball", "fire")
    failures += not check("  the fire talent stays out too", mult, 1.0)
    G.traitsOff = False
    talents.Invalidate()

    print("-- Retail never adds talents (its descriptions hold them)")
    G.buildVersion = "12.1.0"
    mult, _ = multiplier(talents, "Fireball", "fire")
    failures += not check("the Retail gate returns 1", mult, 1.0)
    G.buildVersion = "1.60.1"

    print("-- a cast carries the multiplier into the marker")
    G.firePowerRank = 5
    talents.Invalidate()
    G.Fire("UNIT_SPELLCAST_START", "player", "cast-1", FIRE_SPELL)
    cast = ns._cast()
    failures += not check("the cast is up", cast is not None, True)
    failures += not check("  its lowest end holds the talents", cast.prediction.min, 565.0, 1e-3)
    failures += not check("  its highest end too", cast.prediction.max, 678.0, 1e-3)
    failures += not check("  and the percent is remembered", cast.prediction.talentPercent, 0.13, 1e-9)
    ns._refresh()
    failures += not check("the label shows the multiplied value", ns._label().text, "Fireball 622")
    G.Fire("UNIT_SPELLCAST_FAILED", "player", "cast-1", FIRE_SPELL)

    print("-- the probe answers for the class")
    lines = talents.ProbeLines()
    joined = []
    for i in range(1, len(lines) + 1):
        joined.append(str(lines[i]))
    text = "\n".join(joined)
    failures += not check("the probe lists the class", "class MAGE" in text, True)
    failures += not check("  and the fire talent with its rank", "Fire Power: rank 5/5" in text, True)
    failures += not check("  with the live description", "Fire spells by 10%" in text, True)

    print(f"failed: {failures}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
