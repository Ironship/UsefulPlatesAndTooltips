"""Real shipped poison clock/event routing; mocks cannot prove Retail exposes the aura signal."""
from pathlib import Path
from math import isclose

ROOT = Path(__file__).resolve().parent.parent
fixture = (ROOT / "tests/test_dot_retail.py").read_text(encoding="utf-8")
context = {"__file__": str(ROOT / "tests/test_dot_retail.py")}
exec(compile(fixture.split("for second_spell in", 1)[0], "retail_dot_fixture", "exec"), context)
fight, total, cast = (context[name] for name in ("fight", "total", "cast"))

POISONS = """
    playerClass = 'ROGUE'
    spellNames[2818], spellNames[2823] = 'Deadly Poison', 'Deadly Poison'
    spellDesc[2823] = 'Coats your weapons for 1 hour. Each strike has a 30% chance to poison the enemy for 46 Nature damage over 12 sec. Subsequent applications instantly deal 6 Nature damage.'
    mobA.auras, mobB.auras = {}, {}
    C_UnitAuras = {}
    function C_UnitAuras.GetUnitAuras(unit, filter)
        assert(filter == 'HARMFUL|PLAYER')
        if denyAuras then error('aura access restricted') end
        if hideAuras then return SECRET end
        local result = {}
        for _, aura in pairs(units[unit].auras) do
            if aura.sourceUnit == 'player' and aura.isHarmful then result[#result + 1] = aura end
        end
        return result
    end
    function C_UnitAuras.GetAuraDataByAuraInstanceID(unit, id)
        if denyAuras then error('aura access restricted') end
        return units[unit].auras[id]
    end
    function poison(unit, id, expiration, source, spell)
        local aura = { spellId = spell or 2818, auraInstanceID = id, sourceUnit = source or 'player',
            isHarmful = true, duration = 12, expirationTime = expiration }
        units[unit].auras[id] = aura
        return aura
    end
"""


def setup(extra=""):
    return fight(POISONS + extra)


def add(rt, game, unit="target", instance=101, expiration="now + 12", source="player", spell=2818):
    aura = game.poison(unit, instance, rt.eval(expiration), source, spell)
    game.Fire("UNIT_AURA", unit, rt.table_from({"addedAuras": rt.table_from([aura])}))
    return aura


def changed(rt, game, unit="target", instance=101):
    game.Fire("UNIT_AURA", unit, rt.table_from({"updatedAuraInstanceIDs": rt.table_from([instance])}))


def messages(game):
    return "\n".join(game.UsefulPlatesAndTooltips_DoTInfoDB.log.values())


rt, game, dot = setup()
cast(game, 2823)
assert total(dot) == 0
add(rt, game)
assert total(dot) == total(dot, "target") == 46
assert dot.dotBreakdownForUnit("target")[0][1].school == 8
game.Advance(6)
assert total(dot) == 23
game.Fire("UNIT_COMBAT", "target", "WOUND", "", 9999, 8)
assert total(dot) == 23
assert not dot.dotBreakdownForUnit("target")[0][1].refreshDue
print("ok coating/other damage do not start poison; confirmed poison contributes and decays without ticks")

# Tooltip periodic amount is not the subsequent instant hit, weapon-buff hour or proc probability.
for locale, desc in (
    ("enUS", "Each strike has a 30% chance to poison the enemy for 46 Nature damage over 12 sec. Subsequent applications instantly deal 6 Nature damage."),
    ("deDE", "Überzieht Eure Waffen für 1 Stunde. Das Gift verursacht im Verlauf von 12 Sek. 46 Naturschaden. Zusätzliche Anwendungen verursachen sofort 6 Naturschaden."),
):
    rt, game, dot = setup()
    game.GetLocale = rt.eval("function() return '" + locale + "' end")
    game.spellDesc[2823] = desc
    add(rt, game)
    assert total(dot) == 46
print("ok current EN/DE client description supplies poison amount/duration, excluding instant damage")

rt, game, dot = setup()
aura = add(rt, game)
game.Advance(6)
aura.expirationTime = rt.eval("now + 12")
changed(rt, game)
assert total(dot) == 46  # Poison reset is not a 30% Pandemic carry.
game.Advance(3)
changed(rt, game)  # Same expiration is not another refresh.
game.Fire("UNIT_AURA", "nameplate1", rt.table_from({"isFullUpdate": True}))
assert total(dot) == 34.5
game.Advance(10)
game.Tick(0.1)
assert total(dot) == 0
print("ok actual refresh resets clock without Pandemic; repeated updates/scans do not restart it; timer expires")

rt, game, dot = setup()
add(rt, game, expiration="SECRET")
assert total(dot) == 46
game.Advance(6)
assert total(dot) == 23
game.Fire("UNIT_AURA", "target", rt.table_from({"isFullUpdate": True}))
assert total(dot) == 23  # Hidden duration in a scan cannot restart the clock.
changed(rt, game)
assert total(dot) == 46
game.Advance(4)
assert isclose(total(dot), 46 * 8 / 12)
assert "own clock" in messages(game)
print("ok identified application/update starts own clock even with hidden expiration; scans cannot date a new refresh")

rt, game, dot = setup()
game.poison("target", 101, game.SECRET)
game.Fire("UNIT_AURA", "target", rt.table_from({"isFullUpdate": True}))
assert total(dot) == 0
assert "waiting for a readable effect application" in messages(game)
print("ok scanning an already-active hidden timer cannot invent its application time")

rt, game, dot = setup()
add(rt, game, expiration="SECRET")
game.Advance(3)
rt.execute("mobA.auras = {}")
game.poison("target", 102, game.SECRET)
game.Fire("UNIT_AURA", "target", rt.table_from({"isFullUpdate": True}))
assert total(dot) == 0
print("ok a new hidden instance found only by scanning cannot inherit the former instance's clock")

rt, game, dot = setup()
aura = add(rt, game, expiration="now + 6")
aura.duration = 6
changed(rt, game)
game.Advance(3)
assert total(dot) == 23
print("ok readable actual aura duration sets the damage rate instead of assuming tooltip duration")

rt, game, dot = setup()
add(rt, game)
game.Advance(3)
rt.execute("units.target = mobB")
game.Fire("PLAYER_TARGET_CHANGED")
assert total(dot, "target") == 0 and total(dot) == 34.5
add(rt, game, instance=202)
assert total(dot, "target") == total(dot, "nameplate2") == 46
assert total(dot) == 34.5
rt.execute("units.target = mobA")
game.Fire("PLAYER_TARGET_CHANGED")
assert total(dot, "target") == 34.5
print("ok target/plate share one poison and two mobs retain separate clocks across target switches")

rt, game, dot = setup()
add(rt, game)
cast(game, 172)
assert total(dot) == 1246
rt.execute("mobA.auras[101] = nil")
game.Fire("UNIT_AURA", "nameplate1", rt.table_from({"removedAuraInstanceIDs": rt.table_from([101])}))
assert total(dot) == 1200
print("ok poison removal clears only that aura, preserving cast DoTs")

rt, game, dot = setup()
add(rt, game)
game.poison("target", 102, rt.eval("now + 12"))
rt.execute("mobA.auras[101] = nil")
game.Fire("UNIT_AURA", "target", rt.table_from({"isFullUpdate": True}))
game.Fire("UNIT_AURA", "target", rt.table_from({"removedAuraInstanceIDs": rt.table_from([101])}))
assert total(dot) == 46
rt.execute("mobA.auras = {}")
game.Fire("UNIT_AURA", "target", rt.table_from({"isFullUpdate": True}))
assert total(dot) == 0
print("ok stale removal cannot delete a replacement instance; complete empty scan confirms removal")

rt, game, dot = setup()
add(rt, game, source="party1")
for spell in (2823, 383414, 8679, 3408, 5761, 315584):
    add(rt, game, instance=spell, spell=spell)
assert total(dot) == 0
print("ok another rogue's poison, coatings, instant poisons and non-damaging debuffs are excluded")

for field in ("spellId", "sourceUnit", "auraInstanceID", "isHarmful"):
    rt, game, dot = setup()
    aura = game.poison("target", 101, game.SECRET)
    aura[field] = game.SECRET
    game.Fire("UNIT_AURA", "target", rt.table_from({"addedAuras": rt.table_from([aura])}))
    assert total(dot) == 0
print("ok hidden spell/source/instance/harmful metadata cannot start an unconfirmed own clock")

for mode in ("denyAuras = true", "hideAuras = true"):
    rt, game, dot = setup(mode)
    game.Fire("UNIT_AURA", "target", game.SECRET)
    assert total(dot) == 0
    assert "aura access denied" in messages(game) or "aura list hidden" in messages(game)
    rt.execute("denyAuras, hideAuras = false, false")
    add(rt, game)
    assert total(dot) == 46
print("ok denied/hidden API is recorded and recovers when a readable application is available")

rt, game, dot = setup()
add(rt, game)
game.Advance(4)
rt.execute("denyAuras = true")
game.Fire("UNIT_AURA", "target", game.SECRET)
assert isclose(total(dot), 46 * 8 / 12)
game.Advance(9)
game.Tick(0.1)
assert total(dot) == 0
print("ok access loss cannot reset a known clock; it still decays and expires")

rt, game, dot = setup()
add(rt, game)
rt.execute("units.nameplate1 = nil")
game.Fire("NAME_PLATE_UNIT_REMOVED", "nameplate1")
rt.execute("units.target, units.nameplate1 = mobB, mobB")
game.Fire("PLAYER_TARGET_CHANGED")
game.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
assert total(dot) == total(dot, "target") == 0
print("ok recycled plate with a secret GUID cannot inherit another mob's poison")

rt, game, dot = setup()
add(rt, game)
rt.execute("mobA.auras = {}; units.target = nil")
game.Fire("PLAYER_ENTERING_WORLD")
assert total(dot) == 0
print("ok loading clears poison clocks rather than persisting fabricated aura state")

rt, game, dot = setup("playerClass = 'WARLOCK'")
add(rt, game)
assert total(dot) == 0
print("ok poison event tracking is enabled only for rogue")
