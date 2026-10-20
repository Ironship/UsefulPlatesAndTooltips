"""Regression: a selected friendly pet must not intercept Action Targeting damage."""
from test_cast_prediction import EXT, FAKE, ROOT, LuaRuntime


def fight(retail, hidden_guid=False):
    rt = LuaRuntime(unpack_returned_tuples=True)
    rt.execute(FAKE + EXT)
    game = rt.globals()
    game.retailClient, game.hiddenGUID = retail, hidden_guid
    rt.execute(r'''
        function GetBuildInfo()
            if retailClient then return '12.1.0','69933','',120100 end
            return '1.60.1','70450','',16001
        end
        function GetLocale() return 'enUS' end
        function GameFontNormalSmall:GetFont() return 'Fonts\FRIZQT__.TTF',12,'' end
        SECRET = {}
        function issecretvalue(v) return rawequal(v, SECRET) end
        enemy = {guid='Enemy-A',identity='A',name='Spider',health=300,max=500,hostile=true}
        other = {guid='Enemy-B',identity='B',name='Wolf',health=400,max=500,hostile=true}
        pet = {guid='Pet',identity='Pet',name='Voidwalker',health=500,max=500,hostile=false}
        plateEnemy = {guid='Enemy-A',identity='A',name='Spider',health=300,max=500,hostile=true}
        if hiddenGUID then enemy.guid = SECRET end
        units.target, units.pet, units.softenemy = pet, pet, enemy
        units.nameplate1, units.nameplate2 = plateEnemy, other
        target = {hostile=false}
        function UnitCanAttack(_, unit) return units[unit] ~= nil and units[unit].hostile == true end
        function UnitName(unit) return units[unit] and units[unit].name end
        function UnitIsUnit(a,b)
            return units[a] ~= nil and units[b] ~= nil and units[a].identity == units[b].identity
        end
        plate, otherPlate = NewPlate(), NewPlate()
        function C_NamePlate.GetNamePlateForUnit(unit)
            if units[unit] and units[unit].identity == 'A' then return plate end
            if units[unit] == other then return otherPlate end
        end
        spellNames[172], spellDesc[172] = 'Corruption','Causes 120 Shadow damage over 12 sec.'
        spellNames[686], spellDesc[686] = 'Shadow Bolt','Deals 40 Shadow damage.'
        spellNames[5143], spellDesc[5143] = 'Arcane Missiles','Deals 90 Arcane damage over 3 sec.'
        castTimes[172], castTimes[686] = 1500,1500
        function UnitChannelInfo()
            return 'Arcane Missiles',nil,nil,GetTime()*1000,(GetTime()+3)*1000,false,false,5143
        end
    ''')
    addon = rt.eval('{}')
    loader = rt.eval("function(src,name,addon) return assert(loadstring(src,'@'..name))('UsefulPlatesAndTooltips',addon) end")
    toc = 'UsefulPlatesAndTooltips_Mainline.toc' if retail else 'UsefulPlatesAndTooltips.toc'
    for line in (ROOT / toc).read_text(encoding='utf-8').splitlines():
        if line.strip() and not line.startswith('#'):
            name = line.strip().replace('\\', '/')
            loader((ROOT / name).read_text(encoding='utf-8'), name, addon)
    game.Fire('ADDON_LOADED', 'UsefulPlatesAndTooltips')
    game.Fire('PLAYER_LOGIN')
    game.Fire('PLAYER_ENTERING_WORLD')
    cast = addon.modules.CastPrediction
    cast._settings().useAuras = False
    cast._settings().useTalents = False
    cast._settings().manualPower = True
    cast._settings().manualPowerValue = 0
    cast._settings().learn = False
    return rt, game, addon.modules.DoTInfo, cast


def total(dot, unit):
    return dot.dotBreakdownForUnit(unit)[1]


def dots(retail, sent_name):
    rt, game, dot, _ = fight(retail)
    name = game.SECRET if sent_name == 'secret' else sent_name
    game.Fire('UNIT_SPELLCAST_SENT', 'player', name, 'dot', 172)
    game.Fire('UNIT_SPELLCAST_START', 'player', 'dot', 172)
    assert total(dot, 'nameplate1') == 120, 'DoT preview missing from action-targeted enemy'
    assert total(dot, 'target') == 0, 'friendly pet received the DoT preview'
    game.units.softenemy = game.other
    game.Fire('PLAYER_SOFT_ENEMY_CHANGED')
    game.Fire('UNIT_SPELLCAST_SUCCEEDED', 'player', 'dot', 172)
    assert total(dot, 'nameplate1') == 120 and total(dot, 'nameplate2') == 0
    assert total(dot, 'target') == 0, 'friendly pet received the confirmed DoT'
    game.Tick(0.2)
    assert dot.nameplateDamageBase(game.plate, game.plate.UnitFrame.healthBar) == 120
    if not retail:
        game.Advance(3)
        game.Fire('UNIT_COMBAT', 'nameplate1', 'WOUND', '', 30, 32)
        assert total(dot, 'nameplate1') == 90, 'tick was routed to the selected pet'


def damage(retail, channel, hidden_guid=False):
    rt, game, dot, cast = fight(retail, hidden_guid)
    spell, amount = (5143, 90) if channel else (686, 40)
    game.Fire('UNIT_SPELLCAST_SENT', 'player', 'Spider', 'damage', spell)
    event = 'UNIT_SPELLCAST_CHANNEL_START' if channel else 'UNIT_SPELLCAST_START'
    game.Fire(event, 'player', 'damage', spell)
    assert cast._cast() is not None, 'friendly hard target blocked the action-targeted cast'
    assert cast.nameplateDamageBase(game.plate, game.plate.UnitFrame.healthBar) == amount
    assert not cast._marker().shown, 'damage marker appeared on the friendly target frame'
    game.units.softenemy = game.other
    game.Fire('PLAYER_SOFT_ENEMY_CHANGED')
    assert cast.nameplateDamageBase(game.plate, game.plate.UnitFrame.healthBar) == amount
    assert cast.nameplateDamageBase(game.otherPlate, game.otherPlate.UnitFrame.healthBar) == 0
    ending = 'UNIT_SPELLCAST_CHANNEL_STOP' if channel else 'UNIT_SPELLCAST_INTERRUPTED'
    game.Fire(ending, 'player', 'damage', spell)
    assert cast.nameplateDamageBase(game.plate, game.plate.UnitFrame.healthBar) == 0


def controls(retail):
    rt, game, dot, cast = fight(retail)
    game.units.target, game.units.softenemy = game.enemy, game.other
    game.Fire('PLAYER_TARGET_CHANGED')
    game.Fire('UNIT_SPELLCAST_SENT', 'player', 'Spider', 'hard', 172)
    game.Fire('UNIT_SPELLCAST_SUCCEEDED', 'player', 'hard', 172)
    assert total(dot, 'target') == 120 and total(dot, 'softenemy') == 0
    game.Fire('UNIT_SPELLCAST_SENT', 'player', 'Spider', 'hard-damage', 686)
    game.Fire('UNIT_SPELLCAST_START', 'player', 'hard-damage', 686)
    assert cast._marker().shown and cast._marker().value == 40

    rt, game, dot, cast = fight(retail)
    game.units.softenemy = None
    game.Fire('UNIT_SPELLCAST_SENT', 'player', '', 'no-enemy', 172)
    game.Fire('UNIT_SPELLCAST_SUCCEEDED', 'player', 'no-enemy', 172)
    assert total(dot, 'target') == 0, 'DoT assigned to a friendly target without an enemy'
    game.Fire('UNIT_SPELLCAST_START', 'player', 'no-enemy', 686)
    assert cast._cast() is None

    # Forever can receive SENT before the client has selected its dynamic recipient.
    if not retail:
        game.Fire('UNIT_SPELLCAST_SENT', 'player', '', 'dynamic', 172)
        game.units.softenemy = game.enemy
        game.Fire('UNIT_SPELLCAST_SUCCEEDED', 'player', 'dynamic', 172)
        assert total(dot, 'nameplate1') == 120 and total(dot, 'target') == 0


if __name__ == '__main__':
    failures = []
    for retail in (False, True):
        cases = [(f'DoT SENT={name!r}', lambda name=name: dots(retail, name)) for name in ('Spider', '', 'secret')]
        cases += [(f'{"channel" if channel else "cast"}, hiddenGUID={hidden}',
                   lambda channel=channel, hidden=hidden: damage(retail, channel, hidden))
                  for channel in (False, True) for hidden in (False, True)]
        cases.append(('hostile precedence, friendly-only and dynamic targeting', lambda: controls(retail)))
        for label, check in cases:
            label = f'{"Retail" if retail else "Forever"}: {label}'
            try:
                check()
                print('ok', label)
            except AssertionError as error:
                failures.append(label)
                print('FAIL', label, '-', error)
    assert not failures, f'{len(failures)} action-targeting regressions'
