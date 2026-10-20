"""Cast/channel lifecycle and real target/nameplate widgets on both client branches."""
from math import isclose
import json

from test_cast_prediction import FROSTBOLT, ROOT, load

CHANNEL = 5143


def scenario(retail):
    rt, g, addon = load()
    g.retailClient = retail
    rt.execute('''
        function GetBuildInfo()
            if retailClient then return "12.1.0", "69933", "", 120100 end
            return "1.60.1", "70009", "", 16001
        end
        SECRET = {}
        function issecretvalue(v) return rawequal(v, SECRET) end
        function UnitChannelInfo()
            if hiddenTiming then return "Arcane Missiles", nil, nil, SECRET, SECRET, false, false, 5143 end
            return "Arcane Missiles", nil, nil, channelStart * 1000, channelEnd * 1000, false, false, 5143
        end
        plate = NewPlate()
    ''')
    ns = addon.modules.CastPrediction
    ns._settings().useTalents = False
    ns._settings().useAuras = False
    ns._settings().manualPower = True
    ns._settings().manualPowerValue = 100
    g.spellNames[CHANNEL] = "Arcane Missiles"
    g.spellDesc[CHANNEL] = "Launches Arcane Missiles at the enemy, causing 100 Arcane damage each second for 3 sec."
    total = 300 if retail else 300 + 100 * 0.858

    def start(guid="channel-1"):
        g.channelStart = g.GetTime()
        g.channelEnd = g.channelStart + 3
        g.Fire("UNIT_SPELLCAST_CHANNEL_START", "player", guid, CHANNEL)

    def drawn(amount):
        assert ns._marker().shown
        assert isclose(ns._marker().value, amount, abs_tol=1e-7)
        assert isclose(ns.nameplateDamageBase(g.plate, g.plate.UnitFrame.healthBar), amount, abs_tol=1e-7)

    assert ns.BuildView(CHANNEL) is False
    start()
    assert ns._cast().channel is True
    drawn(total)
    assert ns._marker().maxValue == 1000

    # Channels succeed at their start; success must not start projectile expiry.
    g.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "channel-1", CHANNEL)
    g.Fire("UNIT_SPELLCAST_STOP", "player", "channel-1", CHANNEL)
    g.Advance(1.8)
    ns._refresh()
    drawn(total * 0.4)
    assert ns._cast().succeededAt is None

    # Tick amounts have no spell/source identity. Never treat a tick as the whole cast.
    g.Fire("UNIT_COMBAT", "target", "WOUND", "", total, 64)
    assert ns._cast().landedAt is None
    assert ns._learned()[CHANNEL] is None
    drawn(total * 0.4)

    g.channelEnd = g.GetTime() + 0.3
    g.Fire("UNIT_SPELLCAST_CHANNEL_UPDATE", "player", "channel-1", CHANNEL)
    drawn(total * 0.1)
    g.Fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "old-channel", CHANNEL)
    assert ns._cast() is not None
    g.Fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "channel-1", CHANNEL)
    assert ns._cast() is None
    assert not ns._marker().shown
    assert ns.nameplateDamageBase(g.plate, g.plate.UnitFrame.healthBar) == 0

    # SENT records the actual selection before START; a macro with a different recipient stays quiet.
    g.Fire("PLAYER_ENTERING_WORLD")
    g.units.target = rt.eval('{ guid = "Target-Mob", name = "Target", health = 700, max = 1000 }')
    rt.execute('function UnitName(unit) return units[unit] and units[unit].name end')
    g.Fire("UNIT_SPELLCAST_SENT", "player", "Focus", "macro-1", FROSTBOLT)
    g.Fire("UNIT_SPELLCAST_START", "player", "macro-1", FROSTBOLT)
    assert ns._cast() is None
    g.Fire("UNIT_SPELLCAST_SENT", "player", "Target", "sent-1", FROSTBOLT)
    g.Fire("UNIT_SPELLCAST_START", "player", "sent-1", FROSTBOLT)
    assert ns._cast() is not None
    g.Fire("UNIT_SPELLCAST_SENT", "player", "Target", "sent-2", FROSTBOLT)
    g.units.target = rt.eval('{ guid = "Different-Mob", name = "Different", health = 700, max = 1000 }')
    g.Fire("PLAYER_TARGET_CHANGED")
    g.Fire("UNIT_SPELLCAST_START", "player", "sent-2", FROSTBOLT)
    assert ns._cast() is None

    # Success before channel start and a missing STOP still expire at the channel's end.
    g.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "channel-2", CHANNEL)
    start("channel-2")
    g.Advance(3.1)
    ns._refresh()
    assert ns._cast() is None
    assert not ns._marker().shown

    start("channel-3")
    g.Fire("UNIT_SPELLCAST_INTERRUPTED", "player", "channel-3", CHANNEL)
    assert ns._cast() is None
    start("channel-4")
    g.Fire("PLAYER_TARGET_CHANGED")
    assert ns._cast() is None

    g.hiddenTiming = True
    start("channel-5")
    assert ns._cast() is None
    g.hiddenTiming = False
    start("channel-6")
    g.hiddenTiming = True
    g.Fire("UNIT_SPELLCAST_CHANNEL_UPDATE", "player", "channel-6", CHANNEL)
    assert ns._cast() is None
    g.hiddenTiming = False

    # Healing channels and friendly targets cannot acquire an enemy damage marker.
    g.spellDesc[CHANNEL] = "Heals the target for 300 over 3 sec."
    g.Advance(6)
    start("healing-channel")
    assert ns._cast() is None
    g.target.hostile = False
    g.Fire("UNIT_SPELLCAST_START", "player", "friendly-cast", FROSTBOLT)
    assert ns._cast() is None
    g.target.hostile = True

    # Ordinary casts still draw on both bars. Only post-success hits of the right school land.
    g.Fire("UNIT_SPELLCAST_START", "player", "direct-1", FROSTBOLT)
    amount = ns._cast().prediction.value
    drawn(amount)
    g.Fire("UNIT_COMBAT", "target", "WOUND", "", amount, 16)
    assert ns._cast().landedAt is None
    g.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "direct-1", FROSTBOLT)
    g.Fire("UNIT_COMBAT", "target", "WOUND", "", amount, 4)
    assert ns._cast().landedAt is None
    g.Advance(0.1)
    g.Fire("UNIT_COMBAT", "target", "WOUND", "", amount, 16)
    assert ns._cast().landedAt is not None

    # Do not redraw on another unit before PLAYER_TARGET_CHANGED is delivered.
    g.Fire("UNIT_SPELLCAST_START", "player", "direct-2", FROSTBOLT)
    g.units.target = rt.eval('{ guid = "Another-Mob", health = 700, max = 1000 }')
    ns._refresh()
    assert not ns._marker().shown
    assert ns.nameplateDamageBase(g.plate, g.plate.UnitFrame.healthBar) == 0
    print(f"ok {'Retail' if retail else 'Forever'}: casts, channels, timing, both bars, interruption, recipient guards")


if __name__ == "__main__":
    scenario(False)
    scenario(True)
    rt, g, addon = load()
    module = addon.modules.CastPrediction
    module._settings().manualPower = True
    module._settings().manualPowerValue = 100
    rows = json.loads((ROOT / "tools/dot_fixtures/data/forever_spellbook.json").read_text(encoding="utf-8"))
    for name, spell_id, expected in (("Arcane Missiles", 25345, 1188), ("Mind Flay", 18807, 440.1),
                                      ("Drain Life", 11700, 305), ("Drain Soul", 11675, 470)):
        row = next(row for row in rows if row["name"] == name)
        g.spellNames[spell_id], g.spellDesc[spell_id] = name, row["tooltip"]
        view = module.BuildView(spell_id, True)
        assert view and isclose(view.min, expected), name
        assert module.BuildView(spell_id) is False, name
    for name, spell_id in (("Blizzard", 10187), ("Hurricane", 17402)):
        g.spellDesc[spell_id] = next(row["tooltip"] for row in rows if row["name"] == name)
        assert module.BuildView(spell_id, True) is False, name
    print("ok Forever spellbook: Arcane Missiles, Mind Flay, Drain Life, Drain Soul; area channels excluded")
