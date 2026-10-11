"""Shipped Retail addon: native poison follows plain DoT segments and their saved appearance."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
fixture = ROOT / "tests/test_rogue_poison_native_damage.py"
context = {"__file__": str(fixture)}
exec(compile(fixture.read_text(encoding="utf-8").split("rt, game, dot = setup()", 1)[0],
             "native_projection_fixture", "exec"), context)

rt = context["context"]["context"]["LuaRuntime"](unpack_returned_tuples=True)
rt.execute(context["context"]["context"]["FAKE"] + context["context"]["NATIVE"] + context["PROJECTION"] + r"""
units.target.guid = 'Creature-A'
units.nameplate1 = units.target
function UnitIsUnit(a, b) return units[a] ~= nil and rawequal(units[a], units[b]) end
function GameFontNormalSmall:GetFont() return 'Fonts\\FRIZQT__.TTF', 10 end
function methods.SetVertexColor(self, ...) self.tint = { ... } end
function methods.SetHorizTile(self, value) self.horizTile = value end
function methods.SetVertTile(self, value) self.vertTile = value end
function methods.SetGradient(self, ...) self.gradient = { ... } end
function methods.SetLooping(self, value) self.looping = value end
function methods.Play(self) self.playing = true end
function methods.GetEffectiveScale() return 1 end
""")
addon = rt.eval("{}")
loader = rt.eval("function(src, name, addon) return assert(loadstring(src, '@' .. name))"
                 "('UsefulPlatesAndTooltips', addon) end")
for name in (ROOT / "UsefulPlatesAndTooltips_Mainline.toc").read_text(encoding="utf-8").splitlines():
    if name.strip() and not name.startswith("#"):
        name = name.strip().replace("\\", "/")
        loader((ROOT / name).read_text(encoding="utf-8"), name, addon)
game = rt.globals()
game.Fire("ADDON_LOADED", "UsefulPlatesAndTooltips")
game.Fire("PLAYER_ENTERING_WORLD")
dot = addon.modules["DoTInfo"]
dot.db.smoothMotion = False
dot.db.showLabel = True
target, plate = game.FindProjection(game.TargetFrame), game.FindProjection(game.plateA)
rawget = rt.eval("rawget")


def geometry(binding, fraction):
    points = binding.button.points
    assert len(points) == 2, "poison must start after the plain DoT span, not at the HP bar's left edge"
    assert points[1][1] == "TOPLEFT" and points[1][3] == "TOPRIGHT"
    base, end = points[1][2].parent, points[2][2].parent
    assert game.Same(base.max, game.SECRET) and game.Same(end.max, game.SECRET)
    # Test-only native geometry: secret max HP is 1000. Addon never receives that number.
    remaining = end.value if len(end.points) == 2 else end.value - base.value
    return base.value, base.value + remaining * fraction


def observe(spell, amount, instance):
    return dot.ObserveRogueAura("target", rt.table_from({
        "spellID": spell, "familyID": spell, "name": "Rupture" if spell == 1943 else "Deadly Poison",
        "total": amount, "school": 1 if spell == 1943 else 8, "duration": 12, "interval": 2,
        "expirationTime": game.GetTime() + 12, "auraInstanceID": instance,
        "manual": spell == 1943, "poison": spell == 2818,
    }), "added")


assert geometry(target, 1) == (0, 46)
assert observe(1943, 300, 1)
dot.refresh()
game.Tick(.3)
assert geometry(target, .5) == (300, 323)
assert geometry(plate, .5) == (300, 323)
game.Advance(2)
dot.refresh()
game.Tick(.3)
assert geometry(target, .5) == (250, 273)
assert geometry(plate, .5) == (250, 273)
dot.RemoveRogueAuras("target", None, rt.table_from({1: True}))
dot.refresh()
game.Tick(.3)
assert geometry(target, .5) == (0, 23) and geometry(plate, .5) == (0, 23)
print("ok target and nameplate append poison after bleeds, including ticks and bleed removal")

assert observe(1943, 300, 2)
assert observe(2818, 46, 3)
dot.refresh()
game.Tick(.3)
assert geometry(target, .5) == (346, 346)
assert geometry(plate, .5) == (346, 346)
game.NativePoison(target, .5)
assert target.nativeText == "", "a readable poison already in the plain marker must not be counted twice"
dot.RemoveRogueAuras("target", None, rt.table_from({3: True}))
dot.refresh()
game.Tick(.3)
assert geometry(target, .5) == (300, 323)
print("ok readable poison uses existing styled segments without a duplicate native projection")


def descendants(frame):
    for child in rawget(frame, "children").values():
        yield child
        yield from descendants(child)


def fill(binding):
    return next(child for child in descendants(binding.timer)
                if rawget(child, "texture") and rawget(child, "tint") and len(child.points) == 2
                and child.points[1][1] == "TOPLEFT")


icons = (game.FindIcons(game.TargetFrame), game.FindIcons(game.plateA))
for prefix in ("", "plate"):
    for key, value in {"fillTexture": "stripes", "dotColors": "school", "fillOpacity": 70,
                       "outlineStyle": "dashed", "dashLength": 8, "outlineThickness": 2}.items():
        setting = prefix + key[0].upper() + key[1:] if prefix else key
        dot.db[setting] = value
dot.db.pulseOutline, dot.db.showGlow, dot.db.showShine = True, True, True
dot.Retail.UpdateRogueAuras()
target2, plate2 = game.FindProjection(game.TargetFrame), game.FindProjection(game.plateA)
for previous, current in ((target, target2), (plate, plate2)):
    assert not previous.container.enabled and current.container.enabled
    skin = fill(current)
    assert skin.texture.endswith("Stripes") and skin.horizTile and skin.vertTile
    assert list(skin.tint.values()) == [.35, 1, .35, .7]
    assert any(rawget(child, "texture") and rawget(child, "texture").endswith("DashH8")
               and rawget(child, "height") == 2 for child in descendants(current.timer))
    assert geometry(current, .5) == (300, 323)
    game.NativePoison(current, .5)
    assert current.nativeText == "~23"
assert any(rawget(child, "playing") and rawget(child, "looping") == "BOUNCE" for child in descendants(target2.timer))
assert any(rawget(child, "texture") and rawget(child, "texture").endswith("Shine") for child in descendants(target2.timer))
assert game.Same(icons[0], game.FindIcons(game.TargetFrame)) and game.Same(icons[1], game.FindIcons(game.plateA))
bindings = len(game.poisonBindings)
for _ in range(20):
    dot.Retail.UpdateRogueAuras()
assert len(game.poisonBindings) == bindings
print("ok striped appearance, school colors, opacity, outline, pulse and shine follow settings without rebuilding rogue icons")

dot.db.fillTexture, dot.db.dotColors, dot.db.fillColor, dot.db.fillOpacity = "flat", "single", "purple", 35
dot.db.outlineStyle, dot.db.pulseOutline, dot.db.showGlow, dot.db.showShine = "solid", False, False, False
dot.Retail.UpdateRogueAuras()
simple = game.FindProjection(game.TargetFrame)
assert fill(simple).texture == "Interface\\Buttons\\WHITE8X8"
assert list(fill(simple).tint.values()) == [.7, .3, 1, .35]
assert not any(rawget(child, "playing") for child in descendants(simple.timer))
assert game.Same(plate2.container, game.FindProjection(game.plateA).container)
assert game.auraCalls >= 1  # Legacy API reads were denied; the native projection never reads its children.
print("ok simple appearance and separate plate settings replace only the affected restricted poison slot")

# Smooth target growth must move the poison at the same frame cadence, not one refresh behind.
dot.db.smoothMotion = True
dot.RemoveRogueAuras("target", None, rt.table_from({2: True}))
dot.refresh()
assert observe(1943, 500, 4)
dot.refresh()
for _ in range(5):
    game.Tick(.02)
    base, end = geometry(game.FindProjection(game.TargetFrame), .5)
    assert base == game.UsefulPlatesAndTooltips_DoTInfoRemaining.value
    assert end - base == 23
print("ok smooth marker animation keeps poison adjacent on every frame")

rt.execute("function InCombatLockdown() return true end; TargetFrame.IsProtected = function() return true end")
before = len(game.poisonBindings)
dot.db.fillTexture = "raid"
dot.Retail.UpdateRogueAuras()
assert len(game.poisonBindings) == before and simple.container.enabled
rt.execute("function InCombatLockdown() return false end")
game.Fire("PLAYER_REGEN_ENABLED")
raid = game.FindProjection(game.TargetFrame)
assert not simple.container.enabled and raid.container.enabled
assert fill(raid).texture == "Interface\\RaidFrame\\Raid-Bar-Hp-Fill"
print("ok protected style changes wait for combat end while retaining the working projection")

game.slotInitializerFails = True
dot.db.fillTexture = "smooth"
dot.Retail.UpdateRogueAuras()
assert raid.container.enabled
before = len(game.poisonBindings)
for _ in range(5):
    dot.Retail.UpdateRogueAuras()
assert len(game.poisonBindings) == before
print("ok a failed replacement retains the previous poison display without repeated allocation")

game.slotInitializerFails = False
dot.db.fillTexture, dot.db.smoothMotion = "flat", False
dot.RemoveRogueAuras("target", None, rt.table_from({4: True}))
assert observe(1943, 900, 5)
game.spellDesc[2823] = "Poison deals 200 Nature damage over 12 sec."
dot.refresh()
edge = game.FindProjection(game.TargetFrame)
assert geometry(edge, .5) == (900, 1000), "clip after the countdown, not before multiplying by remaining time"
assert geometry(edge, .25) == (900, 950)
clip = edge.timer.parent
assert clip.points[1][1] == "TOPLEFT" and clip.points[2][1] == "BOTTOMRIGHT"
assert game.Same(clip.points[1][2], edge.container.points[1][2])
print("ok poison retains its HP scale near the right edge and its native timer is clipped inside the health bar")

health = edge.container.points[1][2]
for width in (game.SECRET, float("nan"), float("inf")):
    game.testWidth = width
    health.GetWidth = rt.eval("function() return testWidth end")
    dot.Retail.UpdateRogueAuras()
    end = edge.button.points[2][2].parent
    assert len(end.points) == 0 and game.Same(end.allPoints, health)
health.GetWidth = rt.eval("function() return 100 end")
dot.Retail.UpdateRogueAuras()
assert len(edge.button.points[2][2].parent.points) == 2
print("ok hidden or invalid geometry uses native anchors and recovers without arithmetic on secret values")

dot.db.nameplateMode = "off"
dot.Retail.UpdateRogueAuras()
before = len(game.poisonBindings)
dot.db.plateFillTexture = "raid"
dot.Retail.UpdateRogueAuras()
assert len(game.poisonBindings) == before
dot.db.nameplateMode = "markerIcon"
dot.Retail.UpdateRogueAuras()
assert len(game.poisonBindings) == before + 1
assert fill(game.FindProjection(game.plateA)).texture == "Interface\\RaidFrame\\Raid-Bar-Hp-Fill"
print("ok inactive nameplates defer style allocation until shown again")

# An own-clock effect applied first still follows later effects with a readable expiry.
# Refining its amount/clock must not move an active segment among the other estimates.
dot.RemoveRogueAuras("target", rt.table_from({}), None)


def effect(spell, name, amount, instance, expiration=None):
    info = {"spellID": spell, "familyID": spell, "name": name, "total": amount, "school": 8,
            "duration": 12, "clockDuration": 12, "interval": 2, "auraInstanceID": instance,
            "expirationTime": expiration}
    assert dot.ObserveRogueAura("target", rt.table_from(info), "added")


def order(unit="target"):
    return [entry.name for entry in dot.dotBreakdownForUnit(unit)[0].values()]


effect(2818, "Deadly Poison", 46, 10)
game.Advance(1)
effect(1943, "Rupture", 300, 11, game.GetTime() + 12)
game.Advance(1)
effect(385627, "Kingsbane", 80, 12)
expected = ["Rupture", "Deadly Poison", "Kingsbane"]
assert order() == order("nameplate1") == expected
effect(2818, "Deadly Poison", 69, 10, game.GetTime() + 12)
assert order() == order("nameplate1") == expected
dot.refresh()
game.Tick(.3)
assert geometry(game.FindProjection(game.TargetFrame), .5)[0] > 300
game.NativePoison(game.FindProjection(game.TargetFrame), .5)
assert game.FindProjection(game.TargetFrame).nativeText == ""
print("ok own-clock estimates follow readable effects and retain their position when damage and expiry are refined")
