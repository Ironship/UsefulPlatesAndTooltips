"""UsefulPlatesAndTooltips module CastPrediction, tested against the same fake game tests/test_bit.py uses.

    python tests/test_cast_prediction.py

The fake comes from tests/test_bit.py (AST-extracted). The module is loaded with the real core
files and the SpellDamageInfo files it leans on (its parser, coefficients and spell power), in
.toc order, so BIT.Module, BIT.Settings, BIT.RegisterTab and BIT.tabWords behave as in the game.
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

FROSTBOLT = 900116
DOT_SPELL = 172


def fake_prefix():
    src = (pathlib.Path(__file__).parent / "test_bit.py").read_text(encoding="utf-8")
    tree = ast.parse(src)
    for node in tree.body:
        if isinstance(node, ast.Assign) and any(
            isinstance(t, ast.Name) and t.id == "FAKE" for t in node.targets
        ):
            return ast.literal_eval(node.value)
    raise SystemExit("tests/test_bit.py no longer holds FAKE = ...; adapt test_cast_prediction.py")


FAKE = fake_prefix()

# Test-only game extensions, in the same chunk as the FAKE (mock()/methods stay reachable).
EXT = r"""
-- The default fake answers German; the parser gets English tooltip texts here.
function GetLocale() return "enUS" end
-- Spell power the client reports per school index (Frost = 5).
function GetSpellBonusDamage(i) if i == 5 then return 210 end return 0 end
function GetSpellBonusHealing() return 0 end
-- Cast times the client reports per spell id, in ms.
castTimes = { [900116] = 3000 }
local realGetSpellInfo = C_Spell.GetSpellInfo
C_Spell.GetSpellInfo = function(id)
    if castTimes[id] then return { castTime = castTimes[id] } end
    return { castTime = 0 }
end
-- The target frame's own furniture, so BIT.Plate.UnitFrame finds a health bar to draw on.
TargetFrameHealthBar = mock("TargetFrameHealthBar")
TargetFramePortrait = mock("TargetFramePortrait")
-- Native setters, recorded, so the tests see the raw numbers that reach the widgets.
setterCalls = {}
function methods.SetValue(self, v) self.value = v table.insert(setterCalls, { self, "SetValue", v }) end
function methods.SetMinMaxValues(self, lo, hi)
    self.minValue, self.maxValue = lo, hi
    table.insert(setterCalls, { self, "SetMinMaxValues", lo, hi })
end
function methods.GetMinMaxValues(self) return self.minValue or 0, self.maxValue or 1 end
function methods.SetTextColored(self, ...) end
"""


def check(label, actual, expected):
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
    G.units.target = rt.eval('{ guid = "Creature-CastPred", health = 800, max = 1000 }')
    G.units.nameplate1 = G.units.target
    G.spellNames[FROSTBOLT] = "Frostbolt"
    G.spellDesc[FROSTBOLT] = "Inflicts 429 to 479 Frost damage."
    G.spellNames[DOT_SPELL] = "Verderbnis"
    G.spellDesc[DOT_SPELL] = "Corrupts the target, causing 40 Shadow damage over 12 sec."
    return rt, G, addon


def main():
    failures = 0
    rt, G, addon = load()
    ns = addon.modules.CastPrediction
    settings = ns._settings()

    print("-- load and settings")
    failures += not check("CastPrediction runs", addon.state.CastPrediction, "on")
    failures += not check("the module keeps its namespace", addon.modules.CastPrediction is not None, True)
    failures += not check("the tab is registered", addon.tabs.CastPrediction is not None, True)
    failures += not check("/upt cast opens it", addon.tabWords.cast, "CastPrediction")
    failures += not check("settings use school colors", settings.fillColor, "school")
    failures += not check("with the cast gate on by default", settings.castOnly, True)

    print("-- the spell view (description + spell power through the coefficient)")
    view = ns.BuildView(FROSTBOLT)
    # 3.0 s cast, no coefficient table entry: Classic's rule, 3.0/3.5 of 210 spell power = 180.
    failures += not check("a direct-damage spell parses", view is not None, True)
    failures += not check("  its range holds the spell power", (view.min, view.max), (429 + 180, 479 + 180))
    failures += not check("  the school is frost", view.school, "frost")
    failures += not check("  the estimate is flagged", view.estimated, True)
    failures += not check("a pure DoT is not a prediction", ns.BuildView(DOT_SPELL), False)

    print("-- a cast shows the marker on the target's health bar")
    G.Fire("UNIT_SPELLCAST_START", "player", "cast-1", FROSTBOLT)
    cast = ns._cast()
    failures += not check("the cast is tracked", cast is not None, True)
    failures += not check("  its expected range", (cast.prediction.min, cast.prediction.max), (609.0, 659.0))
    ns._refresh()
    marker = ns._marker()
    failures += not check("the marker is shown", marker.shown, True)
    failures += not check("  on the target's own scale", (marker.minValue, marker.maxValue), (0, 1000))
    failures += not check("  at the average", marker.value, 634.0)
    failures += not check("  the kill cue asks with the low end", ns._killBar().value, 609.0)
    failures += not check("the label names the cast", ns._label().text, "Frostbolt 634")
    kill = ns._killWindow()
    failures += not check("the kill icon asks the widget's own comparison", kill.shown, True)

    print("-- the cast lands: a matching hit calibrates the estimate")
    G.Advance(3)
    G.Fire("UNIT_SPELLCAST_STOP", "player", "cast-1", FROSTBOLT)
    G.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", FROSTBOLT)
    failures += not check("the cast waits for the hit", ns._cast().succeededAt is not None, True)
    G.Fire("UNIT_COMBAT", "target", "WOUND", "", 620, 16)
    learned = ns._learned()[FROSTBOLT]
    failures += not check("the hit was learned", learned is not None and learned.samples, 1)
    failures += not check("  the factor bends toward the hit", abs(learned.factor - 0.9927) < 0.01, True)
    G.Advance(2)
    ns._housekeep(G.GetTime())
    failures += not check("the marker is gone once the impact faded", ns._cast(), None)
    ns._refresh()
    failures += not check("  and hides", marker.shown or False, False)

    print("-- a failed cast drops the estimate at once")
    G.Fire("UNIT_SPELLCAST_START", "player", "cast-2", FROSTBOLT)
    failures += not check("the cast is up again", ns._cast() is not None, True)
    G.Fire("UNIT_SPELLCAST_FAILED", "player", "cast-2", FROSTBOLT)
    failures += not check("a failed cast is dropped", ns._cast(), None)

    print("-- a target change drops it too")
    G.Fire("UNIT_SPELLCAST_START", "player", "cast-3", FROSTBOLT)
    G.Fire("PLAYER_TARGET_CHANGED")
    failures += not check("the cast follows the old target out", ns._cast(), None)

    print("-- crits land but never teach the factor")
    ns.resetLearned()
    G.Fire("PLAYER_ENTERING_WORLD")
    G.target = rt.eval("{ hostile = true }")
    G.units.target = rt.eval('{ guid = "Creature-CastPred", health = 800, max = 1000 }')
    G.Fire("UNIT_SPELLCAST_START", "player", "cast-4", FROSTBOLT)
    G.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-4", FROSTBOLT)
    G.Fire("UNIT_COMBAT", "target", "WOUND", "CRITICAL", 1250, 16)
    failures += not check("a crit is not learned", ns._learned()[FROSTBOLT], None)
    failures += not check("but it proves the hit landed", ns._cast().landedAt is not None, True)

    print("-- instant casts stay silent unless asked for")
    G.Fire("PLAYER_ENTERING_WORLD")
    G.target = rt.eval("{ hostile = true }")
    G.units.target = rt.eval('{ guid = "Creature-CastPred", health = 800, max = 1000 }')
    G.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-5", FROSTBOLT)
    failures += not check("an instant is ignored by default", ns._cast(), None)
    settings.castOnly = False
    G.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-6", FROSTBOLT)
    failures += not check("with the gate open it shows", ns._cast() is not None, True)
    failures += not check("  and is marked an instant", ns._cast().instant, True)
    settings.castOnly = True

    print("-- the preview draws with plain numbers")
    G.Fire("PLAYER_ENTERING_WORLD")
    makeHost = rt.eval("function(bar, portrait) return { healthBar = bar, portrait = portrait } end")
    makeState = rt.eval("function() return { name = 'Frostbolt', min = 609, max = 659, value = 634, "
                        "school = 16, health = 620, maxHealth = 1000 } end")
    ns.setDisplayHost(makeHost(G.TargetFrameHealthBar, G.TargetFramePortrait))
    ns.setPreviewState(makeState())
    ns._refresh()
    failures += not check("the marker shows the preview's value", marker.value, 634)
    failures += not check("  on the preview's scale", marker.maxValue, 1000)
    failures += not check("  with its own label", ns._label().text, "Frostbolt 634")
    ns.setPreviewState(None)
    ns.setDisplayHost(None)
    ns._refresh()
    failures += not check("the preview releases the display", marker.shown or False, False)

    print("-- the settings tab survives a tab switch (it is built once, then hidden and shown)")
    rawequal = rt.eval("function(a, b) return rawequal(a, b) end")
    addon.OpenSettings("CastPrediction")
    page = addon._pages["CastPrediction"]
    pane = ns._previewPane()
    failures += not check("the tab builds and holds its preview pane", pane is not None, True)
    page.Hide(page)
    failures += not check("hiding the page releases the preview display", ns._previewHostsSet(), False)
    page.Show(page)
    failures += not check("showing it again keeps the same pane", rawequal(ns._previewPane(), pane), True)
    failures += not check("  and re-arms the preview", ns._previewHostsSet(), True)
    page.Hide(page)
    failures += not check("the pane stays for the next show", rawequal(ns._previewPane(), pane), True)

    print(f"failed: {failures}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
