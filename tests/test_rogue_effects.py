"""Both shipped clients: rogue ranks, stacked poisons, bleed clocks and live aura damage.

These event/API mocks verify routing and arithmetic, not what Retail exposes during real combat.
"""
from math import isclose
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
fixture = (ROOT / "tests/test_dot_retail.py").read_text(encoding="utf-8")
context = {"__file__": str(ROOT / "tests/test_dot_retail.py")}
exec(compile(fixture.split("for second_spell in", 1)[0], "retail_fixture", "exec"), context)
total, cast = (context[name] for name in ("total", "cast"))

WORLD = """
    playerClass = 'ROGUE'
    function GetLocale() return 'enUS' end
    SECRET = SECRET or {}
    function issecretvalue(v) return rawequal(v, SECRET) end
    mobA = mobA or { guid = 'Creature-A', identity = 'A', name = 'Mob A', health = 1000, max = 1000 }
    mobB = mobB or { guid = 'Creature-B', identity = 'B', name = 'Mob B', health = 1000, max = 1000 }
    units.target, units.nameplate1, units.nameplate2 = mobA, mobA, mobB
    function UnitName(u) return units[u] and units[u].name end
    function UnitCanAttack(_, u) return units[u] ~= nil and u ~= 'player' end
    function UnitIsUnit(a, b) return units[a] ~= nil and units[a] == units[b] end
    mobA.auras, mobB.auras = {}, {}
    C_UnitAuras = {}
    function C_UnitAuras.GetUnitAuras(u, filter)
        assert(filter == 'HARMFUL|PLAYER')
        if denyAuras then error('aura access restricted') end
        local result = {}
        for _, aura in pairs(units[u].auras) do
            if aura.sourceUnit == 'player' and aura.isHarmful then result[#result + 1] = aura end
        end
        return result
    end
    function C_UnitAuras.GetAuraDataByAuraInstanceID(u, id) return units[u].auras[id] end
    C_TooltipInfo = { GetUnitAuraByAuraInstanceID = function(u, id)
        local aura = units[u].auras[id]
        if denyTooltip then error('tooltip access restricted') end
        return { lines = { { leftText = aura.text or 'Aura title' } } }
    end }
    function effect(u, spell, id, duration, expiration, stacks, text)
        local aura = { spellId = spell, auraInstanceID = id, sourceUnit = 'player', isHarmful = true,
            duration = duration, expirationTime = expiration, applications = stacks, text = text }
        units[u].auras[id] = aura
        return aura
    end
    spellNames[703], spellDesc[703] = 'Garrote', 'Garrotes the enemy, causing 144 damage over 18 sec.'
    spellNames[1943], spellDesc[1943] = 'Rupture', 'Finishing move that causes damage over time. 1 point: 159 damage over 8 sec. 2 points: 222 damage over 10 sec. 3 points: 295 damage over 12 sec. 4 points: 377 damage over 14 sec. 5 points: 469 damage over 16 sec.'
    spellNames[2818], spellNames[2823] = 'Deadly Poison', 'Deadly Poison'
    spellDesc[2823] = 'Coats your weapons. Each strike has a 30% chance to poison the enemy for 24 Nature damage over 12 sec. Stacks up to 5 times.'
    for _, id in ipairs({ 385627, 360194, 381628, 394021 }) do spellNames[id] = 'Effect ' .. id end
    spellDesc[385627] = 'Deals 50 Nature damage instantly and an additional 140 Nature damage over 14 sec. Each poison increases damage by 20%.'
    spellDesc[360194] = 'Deals 160 Bleed damage over 16 sec. Increases damage by 20%.'
    spellDesc[381628] = ''
    spellDesc[394021] = 'Mutilate causes an additional 45% of its damage over 8 sec.'
"""


def setup(retail, extra=""):
    if retail:
        return context["fight"](WORLD + extra)
    rt, game, addon, _ = context["context"]["load"](WORLD + extra)
    game.Fire("ADDON_LOADED", "UsefulPlatesAndTooltips")
    game.Fire("PLAYER_ENTERING_WORLD")
    return rt, game, addon.modules["DoTInfo"]


def add(rt, game, spell, instance=101, duration=12, expiration=None, stacks=1, text=None, unit="target"):
    if expiration is None:
        expiration = rt.eval("now") + duration
    aura = game.effect(unit, spell, instance, duration, expiration, stacks, text)
    game.Fire("UNIT_AURA", unit, rt.table_from({"addedAuras": rt.table_from([aura])}))
    return aura


def changed(rt, game, instance=101, unit="target"):
    game.Fire("UNIT_AURA", unit, rt.table_from({"updatedAuraInstanceIDs": rt.table_from([instance])}))


def scan(rt, game, unit="target"):
    game.Fire("UNIT_AURA", unit, rt.table_from({"isFullUpdate": True}))


def remove(rt, game, instance=101, unit="target"):
    rt.execute(f"units.{unit}.auras[{instance}] = nil")
    game.Fire("UNIT_AURA", unit, rt.table_from({"removedAuraInstanceIDs": rt.table_from([instance])}))


# Amounts from the committed Forever client snapshot, supplied by live descriptions (never hardcoded in Lua).
for aura_id, coating_id, amount, rank in (
    (2818, 2823, 24, ""), (2819, 2824, 36, " II"), (11353, 11355, 56, " III"),
    (11354, 11356, 72, " IV"), (25349, 25351, 92, " V"),
):
    rt, game, dot = setup(False)
    game.spellNames[aura_id] = "Deadly Poison" + rank
    game.spellDesc[coating_id] = f"Each strike has a 30% chance to poison the enemy for {amount} Nature damage over 12 sec. Stacks up to 5 times."
    aura = add(rt, game, aura_id)
    assert total(dot) == amount
    for stacks in range(2, 6):
        game.Advance(1)
        aura.applications, aura.expirationTime = stacks, rt.eval("now + 12")
        changed(rt, game)
        assert total(dot) == amount * stacks
    game.Advance(3)
    aura.expirationTime = rt.eval("now + 12")
    changed(rt, game)  # Reapplication at five stacks still refreshes.
    assert total(dot) == amount * 5
    game.Advance(6)
    assert total(dot) == amount * 2.5
    game.Fire("UNIT_COMBAT", "target", "WOUND", "", 999, 8)
    assert total(dot) == amount * 2.5
    remove(rt, game)
    assert total(dot) == 0
print("ok Forever's five Deadly Poison ranks use live amounts, stacks, five-stack refreshes and exact removals")

rt, game, dot = setup(False)
add(rt, game, 2818)
game.spellNames[2819], game.spellDesc[2824] = "Deadly Poison II", "Causes 36 Nature damage over 12 sec."
rt.execute("mobA.auras[101] = nil")
add(rt, game, 2819, instance=102, stacks=3)
assert total(dot) == 108 and len(dot.dotBreakdownForUnit("target")[0]) == 1
game.Fire("UNIT_AURA", "target", rt.table_from({"removedAuraInstanceIDs": rt.table_from([101])}))
assert total(dot) == 108
print("ok changing poison rank replaces its family once; stale old-instance removals cannot erase it")

for retail in (False, True):
    for text, expected in (("Causes 30 Nature damage every 3 sec.", 120),
                           ("Verursacht alle 3 Sek. 30 Naturschaden.", 120),
                           ("Verursacht 30 Naturschaden alle 3 Sek.", 120),
                           ("Verursacht alle 2 Sek. 1.200,5 Naturschaden.", 7203)):
        rt, game, dot = setup(retail)
        add(rt, game, 2818, stacks=game.SECRET, text=text)
        assert total(dot) == expected  # Current tooltip already includes stacks and damage modifiers.
        game.Advance(6)
        assert total(dot) == expected / 2
    rt, game, dot = setup(retail, "denyTooltip = true")
    add(rt, game, 2818, stacks=game.SECRET)
    assert total(dot) == (24 if retail else 0)
print("ok EN/DE current aura tick amounts avoid double stack multiplication; hidden stacks never become guessed stacks")

for retail in (False, True):
    rt, game, dot = setup(retail)
    game.comboPoints = 5
    cast(game, 1943)
    if not retail:
        game.Advance(2)
        game.Fire("UNIT_COMBAT", "target", "WOUND", "", 59, 1)
    before = total(dot)
    assert before > 0
    add(rt, game, 1943, duration=16, expiration=rt.eval("now") + (16 if retail else 14))
    assert total(dot) == before and len(dot.dotBreakdownForUnit("target")[0]) == 1
    remove(rt, game)
    assert total(dot) == 0
    rt, game, dot = setup(retail)
    add(rt, game, 1943, duration=16)
    assert total(dot) == 0  # A new finisher aura with only CP rows cannot tell us points spent.
    aura = game.effect("target", 1943, 101, 16, rt.eval("now + 10"), 1, "Causes 60 Bleed damage every 2 sec.")
    scan(rt, game)
    assert total(dot) == 300
    game.Advance(2)
    assert total(dot) == 240
    remove(rt, game)
    assert total(dot) == 0
print("ok both clients preserve a Rupture CP snapshot and recover an already-active bleed from its current aura tooltip")

for spell in (703, 8631, 8632, 8633, 11289, 11290):
    rt, game, dot = setup(False)
    game.spellNames[spell], game.spellDesc[spell] = game.spellNames[703], game.spellDesc[703]
    cast(game, spell)
    game.Advance(3)
    game.Fire("UNIT_COMBAT", "target", "WOUND", "", 28, 1)
    assert total(dot) == 140
    add(rt, game, spell, duration=18, expiration=rt.eval("now + 15"))
    assert total(dot) == 140
    scan(rt, game)
    assert total(dot) == 140
    remove(rt, game)
    assert total(dot) == 0
print("ok every Forever Garrote rank retains learned/AP-adjusted ticks instead of resetting to base description damage")

for retail in (False, True):
    for spell, duration in ((703, 18), (1943, 16)):
        rt, game, dot = setup(retail)
        game.comboPoints = 5
        add(rt, game, spell, duration=duration, text="Causes 20 Bleed damage every 2 sec.")
        cast(game, spell)  # UNIT_AURA can arrive before this cast's SUCCEEDED event.
        assert total(dot) == duration * 10
        remove(rt, game)
        assert total(dot) == 0
print("ok aura-before-cast event order retains current damage and exact-instance removal in both clients")

for retail in (False, True):
    rt, game, dot = setup(retail)
    game.comboPoints = 5
    game.Fire("UNIT_SPELLCAST_SENT", "player", "Mob A", "BeforeSwitch", 1943)
    add(rt, game, 1943, duration=16, text="Causes 20 Bleed damage every 2 sec.")
    rt.execute("units.target = mobB")
    game.Fire("PLAYER_TARGET_CHANGED")
    game.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "BeforeSwitch", 1943)
    assert total(dot) == 160 and total(dot, "target") == 0
    remove(rt, game, unit="nameplate1")
    assert total(dot) == 0
print("ok post-cast aura synchronization follows the SENT recipient after switching targets")

for spell, duration in ((381628, 6), (394021, 8), (385627, 14)):
    rt, game, dot = setup(True)
    add(rt, game, spell, duration=duration)
    assert total(dot) == 0  # An empty or talent-percent description is not current periodic damage.
    text = "Causes 1,200 Bleed damage every 2 sec."
    add(rt, game, spell, duration=duration, text=text)
    assert total(dot) == 600 * duration
    game.Advance(2)
    assert total(dot) == 600 * (duration - 2)
print("ok Retail's Internal Bleeding, Doomblade and scaling Kingsbane read actual aura damage without inventing talent amounts")

for locale, text in (("enUS", "Causes 45% of Mutilate damage every 2 sec."),
                     ("deDE", "Verursacht 45% Schaden alle 2 Sek."),
                     ("deDE", "Verursacht 45% Schaden über 8 Sek.")):
    rt, game, dot = setup(True)
    game.GetLocale = rt.eval("function() return '" + locale + "' end")
    add(rt, game, 394021, duration=8, text=text)
    assert total(dot) == 0
    game.spellDesc[385627] = text
    cast(game, 385627)
    assert total(dot) == 0
print("ok percentage-only EN/DE aura/spell descriptions cannot become flat tick or total damage")

rt, game, dot = setup(True)
aura = add(rt, game, 385627, duration=14, expiration=game.SECRET, text="Causes 20 Nature damage every 2 sec.")
game.Advance(4)
aura.text = "Causes 40 Nature damage every 2 sec."
changed(rt, game)
assert total(dot) == 200  # Scaling update changes damage rate, not the fixed Kingsbane end time.
scan(rt, game)
assert total(dot) == 200
game.Advance(11)
game.Tick(0.1)
assert total(dot) == 0
rt, game, dot = setup(True)
cast(game, 385627)
assert total(dot) == 140
game.Advance(4)
cast(game, 385627, guid="Second")
assert total(dot) == 140  # Kingsbane has no Pandemic carry.
cast(game, 360194, guid="Deathmark")
assert total(dot) == 300
assert not any(entry.refreshDue for entry in dot.dotBreakdownForUnit("target")[0].values())
print("ok Kingsbane scaling keeps its end time; direct Kingsbane/Deathmark casts exclude instant damage and Pandemic")

for retail in (False, True):
    rt, game, dot = setup(retail)
    add(rt, game, 2818, stacks=2)
    game.Advance(3)
    amount = 24 if retail else 48
    assert total(dot) == amount * .75
    rt.execute("units.target = mobB")
    game.Fire("PLAYER_TARGET_CHANGED")
    assert total(dot, "target") == 0 and total(dot) == amount * .75
    add(rt, game, 703, instance=202, duration=18, text="Causes 20 Bleed damage every 3 sec.")
    assert total(dot, "target") == total(dot, "nameplate2") == 120
    rt.execute("units.target = mobA")
    game.Fire("PLAYER_TARGET_CHANGED")
    assert total(dot, "target") == amount * .75
    rt.execute("mobA.auras = {}; mobB.auras = {}; units.target = nil")
    game.Fire("PLAYER_ENTERING_WORLD")
    assert total(dot) == total(dot, "nameplate2") == 0
print("ok both clients keep target/plate clocks per mob and clear stale clocks on a loading screen")

rt, game, dot = setup(False, """
    local originalGUID = UnitGUID
    function UnitGUID(unit) if unit == 'target' then return SECRET end return originalGUID(unit) end
""")
add(rt, game, 2818, stacks=2)
assert total(dot, "target") == total(dot) == 48
print("ok Forever can resolve a secret target GUID through a matching readable nameplate")

for retail in (False, True):
    rt, game, dot = setup(retail)
    for spell in (2823, 8679, 13219, 3408, 5761, 383414):
        add(rt, game, spell, instance=spell)
    assert total(dot) == 0
    aura = game.effect("target", 2818, 101, 12, rt.eval("now + 12"), 5, None)
    aura.sourceUnit = "party1"
    game.Fire("UNIT_AURA", "target", rt.table_from({"addedAuras": rt.table_from([aura])}))
    assert total(dot) == 0
    aura.sourceUnit = "player"
    aura.text = game.SECRET
    changed(rt, game)
    assert total(dot) == (24 if retail else 120)
    game.Advance(3)
    before = total(dot)
    rt.execute("denyAuras = true")
    game.Fire("UNIT_AURA", "target", game.SECRET)
    assert isclose(total(dot), before)
print("ok instant/non-damaging poisons and other owners are excluded; secret tooltips/API failures preserve known clocks")

# Retail's late-proc lesson: Forever must recover readable aura state even without UNIT_AURA.
def pulse(game, seconds=.3):
    game.Advance(seconds)
    game.Tick(seconds)


rt, game, dot = setup(False)
aura = game.effect("target", 2818, 501, 12, game.GetTime() + 12, 1, None)
assert total(dot) == 0
pulse(game)
assert isclose(total(dot), 24 * 11.7 / 12)
game.Advance(3)
aura.applications, aura.expirationTime = 5, game.GetTime() + 12
pulse(game)
assert isclose(total(dot), 120 * 11.7 / 12)
game.Advance(1)
aura.expirationTime = game.GetTime() + 12
pulse(game)
assert isclose(total(dot), 120 * 11.7 / 12)
rt.execute("mobA.auras = {}")
pulse(game)
assert total(dot) == 0
print("ok Forever catches missed late procs, stack changes, five-stack refreshes and dispels without UNIT_AURA")

rt, game, dot = setup(False)
aura = game.effect("nameplate1", 2818, 501, 12, game.GetTime() + 12, 2, None)
rt.execute("units.target = mobB")
game.Fire("PLAYER_TARGET_CHANGED")
pulse(game)
assert isclose(total(dot), 48 * 11.7 / 12) and total(dot, "target") == 0
rt.execute("mobA.auras = {}")
pulse(game)
assert total(dot) == 0
print("ok Forever resynchronizes an off-target poison through its nameplate without moving it to the new target")

rt, game, dot = setup(False)
cast(game, 703)
game.Advance(3)
game.Fire("UNIT_COMBAT", "target", "WOUND", "", 28, 1)
game.effect("target", 703, 501, 18, 18, 1, None)
pulse(game)
assert total(dot) == 140 and dot.db.ticks[703] == 28
pulse(game)
assert total(dot) == 140
print("ok periodic Forever scans preserve learned/AP-adjusted bleed ticks instead of replacing them with base damage")

# A scan that CAN read the aura tooltip must not downgrade a learned bleed to a prediction:
# the learned ticks stay and keep matching the combat log (OFF-1 follow-up).
rt, game, dot = setup(False)
cast(game, 703)
game.Advance(3)
game.Fire("UNIT_COMBAT", "target", "WOUND", "", 28, 1)
assert total(dot) == 140 and dot.db.ticks[703] == 28
game.effect("target", 703, 501, 18, game.GetTime() + 15, 1, "Causing 24 damage every 3 sec.")
game.Advance(0.1)
pulse(game)  # the periodic scan reads the aura (+0.3s)
assert total(dot) == 140, total(dot)  # old code replaced the learned dot with a prediction here
game.Advance(2.6)
game.Fire("UNIT_COMBAT", "target", "WOUND", "", 28, 1)
assert total(dot) == 112, total(dot)  # the next learned tick matched: 4 ticks of 28 remain
print("ok a readable aura tooltip keeps a learned bleed matching its ticks")

rt, game, dot = setup(False)
aura = add(rt, game, 2818, expiration=game.SECRET)
for _ in range(10): pulse(game)
assert isclose(total(dot), 18), "rescanning a hidden expiry must not renew the own clock"
rt.execute("denyAuras = true")
for _ in range(10): pulse(game)
assert isclose(total(dot), 12)
rt.execute("denyAuras = false; mobA.auras = {}")
game.effect("target", 2818, 502, 12, game.SECRET, 1, None)
pulse(game)
assert total(dot) == 0, "a new hidden instance discovered by scanning has no known application time"
print("ok Forever scans cannot extend hidden clocks or date an unobserved new application; access loss keeps the last known clock")

rt, game, dot = setup(False, """
    auraScans = 0
    units.softenemy = units.target
    local getter = C_UnitAuras.GetUnitAuras
    function C_UnitAuras.GetUnitAuras(unit, filter) auraScans = auraScans + 1; return getter(unit, filter) end
""")
game.auraScans = 0
pulse(game)
assert game.auraScans == 2, "target/softenemy/plate aliases must share one scan per mob"
for _ in range(5): pulse(game, .02)
assert game.auraScans == 2, "rapid display updates must not re-poll aura state"
pulse(game, .2)
assert game.auraScans == 4
dot.off = True
for _ in range(25): pulse(game, .02)
assert game.auraScans == 4
print("ok Forever polling is limited to four Hz per mob, deduplicates aliases and stops when DoTInfo is off")
