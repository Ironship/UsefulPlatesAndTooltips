"""Both clients: reconcile rogue predictions after Vanish without treating PvP as an NPC reset."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parent.parent
fixture = ROOT / "tests/test_rogue_effects.py"
context = {"__file__": str(fixture)}
exec(compile(fixture.read_text(encoding="utf-8").split("# Amounts from the committed", 1)[0],
             "rogue_fixture", "exec"), context)
total, cast, add = (context[name] for name in ("total", "cast", "add"))

WORLD = """
    combat = true
    comboPoints = 1
    function GameFontNormalSmall:GetFont() return 'Fonts\\\\FRIZQT__.TTF', 12, '' end
    target = { hostile = true }
    mobA.fighting, mobB.fighting = true, true
    mobA.visible, mobB.visible = true, true
    mobA.isPlayer, mobB.isPlayer = false, false
    function UnitExists(unit) return units[unit] ~= nil end
    function UnitIsVisible(unit) return units[unit] and units[unit].visible end
    function UnitIsPlayer(unit) return units[unit] and units[unit].isPlayer end
    function UnitAffectingCombat(unit)
        if unit == 'player' then return combat end
        return units[unit] and units[unit].fighting
    end
    units.softenemy = mobA
"""


def setup(retail):
    rt, game, dot = context["setup"](retail, WORLD)
    cast(game, 703, guid="Garrote")
    cast(game, 1943, guid="Rupture")
    add(rt, game, 2818)
    pulse(game, 1)
    assert total(dot) > 0
    assert {e.familyID for e in dot.dotBreakdownForUnit("nameplate1")[0].values()} == {703, 1943, 2818}
    assert not any("ERROR" in line for line in dot.db.log.values())
    return rt, game, dot


def pulse(game, seconds=0.3):
    game.Advance(seconds)
    game.Tick(seconds)
    assert not any("ERROR" in line for line in game.UsefulPlatesAndTooltips_DoTInfoDB.log.values())


def leave(rt, game, reset=True, event=True):
    rt.execute("combat=false")
    if reset:
        rt.execute("mobA.fighting=false; mobA.auras={}; mobA.health=mobA.max")
    if event:
        game.Fire("PLAYER_REGEN_ENABLED")


class CombatReset(unittest.TestCase):
    def test_reset_after_vanish_clears_bleeds_and_poison_with_target_lost(self):
        for retail in (False, True):
            with self.subTest(retail=retail):
                rt, game, dot = setup(retail)
                rt.execute("target=nil; units.target=nil; units.softenemy=nil")
                game.Fire("PLAYER_TARGET_CHANGED")
                leave(rt, game)
                pulse(game)
                self.assertEqual(total(dot), 0)
                self.assertFalse(dot.HasMarker("nameplate1"))
                rt.execute("units.target=mobA; target={hostile=true}")
                game.Fire("PLAYER_TARGET_CHANGED")
                self.assertEqual(total(dot, "target"), 0, "reselecting the reset NPC resurrected its clocks")

    def test_delayed_npc_reset_is_reconciled_without_another_aura_event(self):
        for retail in (False, True):
            with self.subTest(retail=retail):
                rt, game, dot = setup(retail)
                leave(rt, game, reset=False)
                pulse(game)
                self.assertGreater(total(dot), 0, "NPC still fighting somebody lost its active effects")
                rt.execute("mobA.fighting=false; mobA.auras={}")
                pulse(game)
                self.assertEqual(total(dot), 0)

    def test_pvp_and_other_mob_effects_survive_our_combat_exit(self):
        for retail in (False, True):
            with self.subTest(retail=retail):
                rt, game, dot = setup(retail)
                rt.execute("mobA.isPlayer=true; mobA.fighting=false")
                leave(rt, game, reset=False)
                pulse(game)
                self.assertGreater(total(dot), 0)
                self.assertTrue(dot.HasMarker("nameplate1"))
                rt, game, dot = setup(retail)
                rt.execute("units.target=mobB")
                game.Fire("PLAYER_TARGET_CHANGED")
                cast(game, 703, name="Mob B", guid="OtherNPC")
                pulse(game, 0.7)
                leave(rt, game)
                pulse(game)
                self.assertEqual(total(dot), 0)
                self.assertGreater(total(dot, "nameplate2"), 0, "reset leaked into a different NPC")

    def test_periodic_reconciliation_recovers_a_missing_combat_exit_event(self):
        for retail in (False, True):
            with self.subTest(retail=retail):
                rt, game, dot = setup(retail)
                leave(rt, game, event=False)
                pulse(game)
                self.assertEqual(total(dot), 0)

    def test_hidden_or_denied_aura_scans_do_not_prove_reset(self):
        for retail in (False, True):
            for hidden in ("denyAuras=true", "C_UnitAuras.GetUnitAuras=function() return SECRET end",
                           "mobA.auras[999]={spellId=SECRET,sourceUnit='player',isHarmful=true}"):
                with self.subTest(retail=retail, hidden=hidden):
                    rt, game, dot = setup(retail)
                    leave(rt, game, event=False)
                    rt.execute(hidden)
                    game.Fire("PLAYER_REGEN_ENABLED")
                    pulse(game)
                    self.assertGreater(total(dot), 0)

    def test_unreadable_or_out_of_range_npc_state_preserves_cast_predictions(self):
        for retail in (False, True):
            for state in ("mobA.visible=false", "mobA.visible=SECRET", "mobA.isPlayer=SECRET",
                          "mobA.fighting=SECRET", "combat=SECRET", "UnitIsPlayer=function() error('restricted') end"):
                with self.subTest(retail=retail, state=state):
                    rt, game, dot = setup(retail)
                    leave(rt, game, event=False)
                    rt.execute(state)
                    game.Fire("PLAYER_REGEN_ENABLED")
                    pulse(game)
                    entries = dot.dotBreakdownForUnit("nameplate1")[0]
                    self.assertTrue(any(e.familyID == 703 for e in entries.values()))

    def test_fresh_opening_bleed_waits_for_its_aura(self):
        for retail in (False, True):
            with self.subTest(retail=retail):
                rt, game, dot = context["setup"](retail, WORLD + "combat=false; mobA.fighting=false")
                cast(game, 703)
                pulse(game, 0.1)
                self.assertGreater(total(dot), 0)
                add(rt, game, 703, instance=102, duration=18)
                rt.execute("combat=true; mobA.fighting=true")
                pulse(game, 0.7)
                self.assertGreater(total(dot), 0)

    def test_forever_reset_preserves_learned_tick_sizes(self):
        rt, game, dot = setup(False)
        game.Advance(2)
        game.Fire("UNIT_COMBAT", "target", "WOUND", "", 28, 1)
        self.assertEqual(dot.db.ticks[703], 28)
        leave(rt, game)
        pulse(game)
        self.assertEqual(total(dot), 0)
        self.assertEqual(dot.db.ticks[703], 28)

    def test_readable_existing_auras_survive_even_on_an_idle_npc(self):
        for retail in (False, True):
            with self.subTest(retail=retail):
                rt, game, dot = setup(retail)
                add(rt, game, 703, instance=102, duration=18)
                add(rt, game, 1943, instance=103, duration=8)
                leave(rt, game, reset=False)
                rt.execute("mobA.fighting=false")
                pulse(game)
                entries = dot.dotBreakdownForUnit("nameplate1")[0]
                self.assertEqual({e.familyID for e in entries.values()}, {703, 1943, 2818})

    def test_reconciliation_is_throttled_deduplicated_and_disabled_with_module(self):
        for retail in (False, True):
            with self.subTest(retail=retail):
                rt, game, dot = setup(retail)
                rt.execute("""
                    auraScans=0
                    local getter=C_UnitAuras.GetUnitAuras
                    C_UnitAuras.GetUnitAuras=function(...)
                        auraScans=auraScans+1; return getter(...)
                    end
                """)
                if retail:
                    pulse(game)
                    self.assertEqual(game.auraScans, 0, "Retail polled protected combat auras")
                rt.execute("combat=false; mobA.fighting=false; mobB.fighting=false; auraScans=0")
                game.Fire("PLAYER_REGEN_ENABLED")
                self.assertEqual(game.auraScans, 2, "aliases rescanned the same NPC")
                for _ in range(5):
                    pulse(game, 0.02)
                self.assertEqual(game.auraScans, 2)
                pulse(game, 0.2)
                self.assertEqual(game.auraScans, 4)
                dot.off = True
                game.Fire("PLAYER_REGEN_ENABLED")
                pulse(game)
                self.assertEqual(game.auraScans, 4)


if __name__ == "__main__":
    unittest.main(verbosity=2)
