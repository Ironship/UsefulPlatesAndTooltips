"""UsefulPlatesAndTooltips module HealPrediction, tested against the same fake game tests/test_bit.py uses.

    python tests/test_heal_prediction.py

The module draws the client's own incoming-heal projection (UnitGetIncomingHeals) on Blizzard's
frames. Raw readings -- secrets included -- reach the StatusBar setters untouched; only a
proven-plain zero (or no answer) hides the segment.
"""
import ast
import pathlib
import sys

from lupa.lua51 import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
TOC = (ROOT / "UsefulPlatesAndTooltips.toc").read_text(encoding="utf-8").splitlines()
FILES = [line.strip().replace("\\", "/") for line in TOC if line.strip() and not line.startswith("#")]
LOADED = [name for name in FILES if name.startswith("Core/") or name.startswith("Modules/HealPrediction/")]


def fake_prefix():
    src = (pathlib.Path(__file__).parent / "test_bit.py").read_text(encoding="utf-8")
    tree = ast.parse(src)
    for node in tree.body:
        if isinstance(node, ast.Assign) and any(
            isinstance(t, ast.Name) and t.id == "FAKE" for t in node.targets
        ):
            return ast.literal_eval(node.value)
    raise SystemExit("tests/test_bit.py no longer holds FAKE = ...; adapt test_heal_prediction.py")


FAKE = fake_prefix()

EXT = r"""
function GetBuildInfo() return "1.60.1", "70009", "Sep 23 2026", 16001 end
function GetLocale() return "enUS" end
SECRET = { secret = true }
function issecretvalue(v) return rawequal(v, SECRET) end
-- The client's answer: incoming.own[unit] / incoming.all[unit] (nil = nothing coming).
incoming = { own = {}, all = {} }
function UnitGetIncomingHeals(unit, healer)
    if healer == "player" then return incoming.own[unit] end
    return incoming.all[unit]
end
-- The player frame's furniture (the target frame's already exists in the fake), so
-- BIT.Plate.UnitFrame finds bars for both.
PlayerFrame = mock("PlayerFrame")
PlayerFrame.PlayerFrameContent = mock("pcontent", PlayerFrame)
PlayerFrame.PlayerFrameContent.PlayerFrameContentMain = mock("pmain", PlayerFrame.PlayerFrameContent)
PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.HealthBarsContainer = mock("pbars",
    PlayerFrame.PlayerFrameContent.PlayerFrameContentMain)
PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.HealthBarsContainer.HealthBar = mock("playerhealthbar",
    PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.HealthBarsContainer)
-- A classic party frame for party1.
PartyMemberFrame1 = mock("PartyMemberFrame")
PartyMemberFrame1.HealthBar = mock("partyHealth")
-- A bare bar for the sample drawing.
sampleBar = mock("sampleStatusBar")
-- Native setter recording (the fake already stores value/min/max; keep names consistent).
function methods.SetMinMaxValues(self, lo, hi) self.minValue, self.maxValue = lo, hi end
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
    G.target = rt.eval("{ hostile = false }")
    G.units.target = rt.eval('{ guid = "Creature-Heal", health = 400, max = 1000 }')
    G.units.player = rt.eval('{ guid = "Player-1", health = 700, max = 1000 }')
    G.units.party1 = rt.eval('{ guid = "Player-2", health = 500, max = 900 }')
    return rt, G, addon


def rawequal(rt):
    return rt.eval("function(a, b) return rawequal(a, b) end")


def main():
    failures = 0
    rt, G, addon = load()
    ns = addon.modules.HealPrediction
    settings = ns._settings()
    eq = rawequal(rt)

    print("-- load")
    failures += not check("the module runs", addon.state.HealPrediction, "on")
    failures += not check("the tab is registered", addon.tabs.HealPrediction is not None, True)
    failures += not check("/upt heals opens it", addon.tabWords.heals, "HealPrediction")

    print("-- the target's incoming healing")
    plate = addon.Plate
    targetBar = plate.UnitFrame("target")[1]
    playerFrameBar = plate.UnitFrame("player")[1]
    partyBar = G.PartyMemberFrame1.HealthBar
    G.incoming.own = rt.eval('{ target = 120 }')
    G.incoming.all = rt.eval('{ target = 300 }')
    ns._updateAll()
    overlays = ns._overlays()
    o = overlays[targetBar]
    failures += not check("an overlay is drawn", o is not None, True)
    failures += not check("  with the own-heal reading", o.bar.value, 120)
    failures += not check("  on the health scale", (o.bar.minValue, o.bar.maxValue), (0, 1000))
    failures += not check("  and shown", bool(o.clip.shown), True)

    print("-- all healers ask the client for its total")
    settings.allHealers = True
    ns._updateAll()
    failures += not check("the total replaces the own number", o.bar.value, 300)
    settings.allHealers = False
    ns._updateAll()
    failures += not check("and back to the own number", o.bar.value, 120)

    print("-- nothing coming hides; a secret flows untouched")
    G.incoming.own = rt.eval('{ target = 0 }')
    G.incoming.all = rt.eval('{}')
    ns._updateAll()
    failures += not check("a plain zero hides the segment", bool(o.clip.shown), False)
    G.incoming.own = rt.eval('{ target = SECRET }')
    G.incoming.all = rt.eval('{ target = SECRET }')
    ns._updateAll()
    failures += not check("a secret reading is shown", bool(o.clip.shown), True)
    failures += not check("  and reaches SetValue untouched", eq(o.bar.value, G.SECRET), True)
    G.incoming.own = rt.eval('{ target = 120 }')
    G.incoming.all = rt.eval('{ target = 300 }')

    print("-- the player frame is off by default")
    ns._updateAll()
    failures += not check("no overlay on the player frame", overlays[playerFrameBar], None)
    settings.player = True
    G.incoming.own = rt.eval('{ target = 120, player = 55, party1 = 80 }')
    ns._updateAll()
    failures += not check("enabling it draws", overlays[playerFrameBar] is not None, True)
    failures += not check("  at the player's reading", overlays[playerFrameBar].bar.value, 55)
    settings.player = False

    print("-- classic party frames")
    ns._updateAll()
    po = overlays[partyBar]
    failures += not check("party1 gets its own segment", po is not None, True)
    failures += not check("  at its reading", po.bar.value, 80)
    failures += not check("  on its own scale", po.bar.maxValue, 900)
    settings.party = False
    ns._updateAll()
    failures += not check("switching party off hides it", bool(po.clip.shown), False)
    settings.party = True

    print("-- a dead unit never shows a segment")
    G.units.party1.dead = True
    ns._updateAll()
    failures += not check("dead hides it", bool(po.clip.shown), False)
    G.units.party1.dead = False

    print("-- the sample drawing uses the same code")
    sample = ns.DrawSample(G.sampleBar, 100, 40)
    failures += not check("the sample draws", sample, True)
    so = overlays[G.sampleBar]
    failures += not check("  at the given numbers", (so.bar.value, so.bar.maxValue), (40, 100))
    ns.HideSample(G.sampleBar)

    print("-- the probe speaks")
    lines = ns.Probe()
    joined = []
    for i in range(1, len(lines) + 1):
        joined.append(str(lines[i]))
    text = "\n".join(joined)
    failures += not check("the probe reports the API", "UnitGetIncomingHeals present" in text, True)
    failures += not check("  and the target line", "target: own 120, all 300" in text, True)

    print(f"failed: {failures}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
