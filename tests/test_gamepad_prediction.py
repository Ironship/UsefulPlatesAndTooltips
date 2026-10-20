"""User regression: rank-1 Fireball versus 42 HP, plus Forever's native gamepad crossbar."""
from math import isclose

from test_cast_prediction import load


def scenario(retail):
    rt, game, addon = load()
    game.retailClient = retail
    rt.execute(r'''
        function GetBuildInfo()
            if retailClient then return '12.1.0', '69933', '', 120100 end
            return '1.60.1', '70450', '', 16001
        end
        function GetLocale() return 'deDE' end
        spellNames[133] = 'Feuerball'
        spellDesc[133] = 'Schleudert eine glühende Kugel hinaus, die 14 bis 22 Punkt(e) Feuerschaden sowie 4 Sek. lang 2 Punkt(e) zusätzlichen Feuerschaden verursacht.'
        castTimes[133] = 1500
        wolf = { guid = 'Wolf-A', name = 'Junger Wolf', hostile = true, health = 42, max = 42 }
        otherWolf = { guid = 'Wolf-B', name = 'Junger Wolf', hostile = true, health = 90, max = 90 }
        units.target, units.nameplate1 = wolf, wolf
        function UnitCanAttack(_, unit) return units[unit] and units[unit].hostile == true end
        function UnitName(unit) return units[unit] and units[unit].name end
        function UnitIsUnit(a, b) return units[a] ~= nil and rawequal(units[a], units[b]) end
        plate, otherPlate = NewPlate(), NewPlate()
        C_NamePlate.GetNamePlateForUnit = function(unit)
            if units[unit] == wolf then return plate elseif units[unit] == otherWolf then return otherPlate end
        end
        function GetActionInfo(slot)
            if slot == 301 then return 'spell', 133 elseif slot == 333 then return 'macro', 133, 'spell' end
        end
        SECRET = {}
        function issecretvalue(v) return rawequal(v, SECRET) end
        function GameFontNormalSmall:GetFont() return 'Fonts\FRIZQT__.TTF', 12, '' end

        -- Native buttons are owned by a page unit, not ActionButton1..12; the current
        -- storage slot comes from CalculateAction (including page changes and reserved slots).
        function MakePadButton()
            local button = CreateFrame('CheckButton', nil, UIParent)
            button:SetSize(36, 36)
            button.slot = 301
            button.CalculateAction = function(self) return self.slot end
            button.SetAttribute = function() error('addon wrote a secure gamepad attribute') end
            local index = getmetatable(button).__index
            setmetatable(button, { __index = function(self, key)
                if key == 'action' then error('do not read cached gamepad .action') end
                return index(self, key)
            end })
            return button
        end
        padButton = MakePadButton()
        GamepadMainActionBarFrame = CreateFrame('Frame', 'GamepadMainActionBarFrame', UIParent)
        GamepadMainActionBarFrame.PageUnit = {
            actionBars = { rightBar = { actionButtons = { padButton } } },
            callbacks = {},
            AddPageChangeCallback = function(self, fn) table.insert(self.callbacks, fn) end,
        }
    ''')
    spell = addon.modules.SpellDamageInfo
    cast = addon.modules.CastPrediction
    spell.DecideLangsAtLoad()
    spell.SetSetting("button", "total")
    game.Fire("ADDON_LOADED", "Blizzard_GamepadActionBars")
    label = spell._labels[game.padButton]
    assert label is not None and label.shown and label.text == "20", "native gamepad button lacks 18 + 2"
    spell.SetSetting("button", "direct")
    assert label.text == "18", "direct mode includes Fireball's DoT"
    game.padButton.slot = 333
    rt.execute('for _, callback in ipairs(GamepadMainActionBarFrame.PageUnit.callbacks) do callback() end')
    assert label.shown and label.text == "18", "gamepad page change loses macro spell damage"
    assert len(list(game.GamepadMainActionBarFrame.PageUnit.callbacks.values())) == 1
    game.padButton.slot = game.SECRET
    spell.Refresh()
    assert not label.shown, "secret action slot was used"
    game.padButton.slot = 0
    spell.Refresh()
    assert not label.shown, "reserved gamepad action got a damage number"
    game.padButton.slot = 301
    rt.execute('lateButton = MakePadButton(); table.insert(GamepadMainActionBarFrame.PageUnit.actionBars.rightBar.actionButtons, lateButton)')
    game.Fire("ACTIONBAR_SLOT_CHANGED", 301)
    assert spell._labels[game.lateButton].text == "18"
    spell.SetSetting("button", "off")
    assert not label.shown and not spell._labels[game.lateButton].shown
    spell.SetSetting("button", "direct")

    view = cast.BuildView(133)
    assert (view.min, view.max) == (14, 22)
    parsed = spell.Parser.Read(game.spellDesc[133], "de", retail).parsed
    assert parsed.dot.total == 2
    game.Fire("UNIT_SPELLCAST_SENT", "player", "Junger Wolf", "hard-fireball", 133)
    game.Fire("UNIT_SPELLCAST_START", "player", "hard-fireball", 133)
    assert cast._cast() is not None
    assert cast._marker().shown and cast._marker().value == 18 and cast._marker().maxValue == 42
    damage = cast.nameplateDamageBase(game.plate, game.plate.UnitFrame.healthBar)
    assert isclose(damage / 42, 3 / 7), "direct marker is not 43% of the 42 HP wolf"
    game.Fire("UNIT_SPELLCAST_INTERRUPTED", "player", "hard-fireball", 133)

    # Native controller/action targeting without a clicked hard target.
    game.target = None
    game.units.target = None
    game.units.softenemy = game.wolf
    game.Fire("UNIT_SPELLCAST_SENT", "player", "Junger Wolf", "soft-fireball", 133)
    game.Fire("UNIT_SPELLCAST_START", "player", "soft-fireball", 133)
    assert cast._cast() is not None, "soft-target-only cast has no prediction"
    assert cast.nameplateDamageBase(game.plate, game.plate.UnitFrame.healthBar) == 18
    assert not cast._marker().shown, "empty hard-target frame got a marker"
    game.units.softenemy = game.otherWolf
    game.units.nameplate2 = game.otherWolf
    game.Fire("PLAYER_SOFT_ENEMY_CHANGED")
    assert cast.nameplateDamageBase(game.plate, game.plate.UnitFrame.healthBar) == 18
    assert cast.nameplateDamageBase(game.otherPlate, game.otherPlate.UnitFrame.healthBar) == 0
    game.Fire("UNIT_SPELLCAST_INTERRUPTED", "player", "soft-fireball", 133)
    assert cast.nameplateDamageBase(game.plate, game.plate.UnitFrame.healthBar) == 0
    print(f"ok {'Retail' if retail else 'Forever'}: Fireball 18/42 + separate 2 DoT, gamepad slots/pages, soft targeting")


if __name__ == "__main__":
    scenario(False)
    scenario(True)
