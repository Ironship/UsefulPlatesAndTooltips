"""EUI 9.5.5 contracts against both shipped UPT runtimes; native WoW rendering needs gameplay."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parent.parent
fixture = ROOT / "tests/test_rogue_effects.py"
context = {"__file__": str(fixture)}
exec(compile(fixture.read_text(encoding="utf-8").split("# Amounts from the committed", 1)[0],
             "rogue_fixture", "exec"), context)
base = {"__file__": str(ROOT / "tests/test_bit.py")}
exec(compile((ROOT / "tests/test_bit.py").read_text(encoding="utf-8").split('print("-- every module on")', 1)[0],
             "bit_fixture", "exec"), base)

UNITS = r"""
EllesmereUI = { _ModuleNS = {} }
euiSource = 'eui'
EllesmereUI._ModuleNS.EllesmereUIUnitFrames = { GetUnitFrameSource = function() return euiSource end }
euiPlayer = CreateFrame('Button', 'EllesmereUIUnitFrames_Player', UIParent)
euiPlayer.Health = FakeMock('StatusBar', euiPlayer)
euiTarget = CreateFrame('Button', 'EllesmereUIUnitFrames_Target', UIParent)
euiTarget.Health = FakeMock('StatusBar', euiTarget)
euiTarget.Portrait = FakeMock('portrait', euiTarget)
euiTarget.Health:SetSize(180, 20)
local factory = CreateFrame
function CreateFrame(...)
    local frame = factory(...)
    frame.SetAllPoints = function(self, other) self.allPoints = other end
    return frame
end
"""

WORLD = UNITS + r"""
function GameFontNormalSmall:GetFont() return 'Fonts\\FRIZQT__.TTF',12,'' end
target = {hostile=true}
function UnitPower(_, power) return power==4 and 3 or 100 end
function UnitPowerMax(_, power) return power==4 and 5 or 100 end
function GetComboPoints() return 3 end
plateA, plateB = NewPlate(), NewPlate()
function plateA:GetChildren() return unpack(self.children) end
function plateB:GetChildren() return unpack(self.children) end
function C_NamePlate.GetNamePlateForUnit(unit)
    if units[unit] == mobA then return plateA elseif units[unit] == mobB then return plateB end
end
function C_NamePlate.GetNamePlates() return {plateA,plateB} end
plateA.UnitFrame.unit, plateB.UnitFrame.unit = 'nameplate1', 'nameplate2'
EllesmereNameplates_NS = {plates={}}
function EUIPlate(base, unit)
    local frame = FakeMock('EUI plate', base)
    frame.nameplate = base
    frame.health = FakeMock('StatusBar', frame)
    frame.health:SetSize(180, 20)
    EllesmereNameplates_NS.plates[unit] = frame
    base.UnitFrame.healthBar:Hide()
    return frame
end
euiPlate = EUIPlate(plateA,'nameplate1')
euiPlateB = EUIPlate(plateB,'nameplate2')
euiAction = 61
EABButton1 = CreateFrame('CheckButton', 'EABButton1', UIParent)
EABButton1:SetSize(36,36)
EABButton1.GetAttribute = function(_, key) assert(key=='action'); return euiAction end
local index = getmetatable(EABButton1).__index
setmetatable(EABButton1,{__index=function(self,key)
    if key=='action' then error('EUI .action is protected; read the secure attribute') end
    return index(self,key)
end})
EABButton1.SetAttribute = function() error('UPT wrote to an EUI secure attribute') end
function GetActionInfo(slot)
    if slot==61 then return 'spell',703 elseif slot==73 then return 'macro',1943,'spell' end
end
"""


def boot(retail, extra=""):
    rt = base["LuaRuntime"](unpack_returned_tuples=True)
    rt.execute(base["FAKE"])
    if retail:
        rt.execute("function GetBuildInfo() return '12.1.0','69933','',120100 end")
    rt.execute(context["WORLD"] + WORLD + extra)
    addon = rt.table()
    loader = rt.eval("function(src,name,addon) return assert(loadstring(src,'@'..name))('UsefulPlatesAndTooltips',addon) end")
    toc = "UsefulPlatesAndTooltips_Mainline.toc" if retail else "UsefulPlatesAndTooltips.toc"
    for name in (ROOT / toc).read_text(encoding="utf-8").splitlines():
        if name.strip() and not name.startswith("#"):
            name = name.strip().replace("\\", "/")
            loader((ROOT / name).read_text(encoding="utf-8"), name, addon)
    game = rt.globals()
    game.Fire("ADDON_LOADED", "UsefulPlatesAndTooltips")
    game.Fire("PLAYER_ENTERING_WORLD")
    game.Fire("PLAYER_LOGIN")
    return rt, game, addon, addon.modules["DoTInfo"]


def pulse(game):
    game.Advance(1)
    game.Tick(1)


class EllesmereCompatibility(unittest.TestCase):
    def test_resources_and_forever_range_follow_visible_bar_replacement(self):
        for retail in (False, True):
            with self.subTest(retail=retail):
                rt, game, addon, dot = boot(retail)
                rd = addon.modules["ResourceDing"]
                rd.RefreshDots()
                row = rd._dotsRow()
                self.assertTrue(row.shown)
                self.assertTrue(game.Same(row.points[1][2], game.euiPlate.health))
                rt.execute("euiPlate.health:Hide(); euiPlate=EUIPlate(plateA,'nameplate1')")
                rd.RefreshDots()
                self.assertTrue(game.Same(row.points[1][2], game.euiPlate.health))
                rt.execute("euiPlate:Hide()")
                rd.RefreshDots()
                self.assertFalse(row.shown)
        rt, game, addon, dot = boot(False)
        range_module = addon.modules["Range"]
        range_module.Check = rt.eval("function() return 'out' end")
        range_module.Update()
        self.assertTrue(game.Same(range_module._icon().points[1][2], game.euiPlate.health))
        rt, game, addon, dot = boot(False, "playerClass='HUNTER'; inRange[75]=true; inRange[2974]=false")
        game.Fire("PLAYER_TARGET_CHANGED")
        for _ in range(3):
            game.Advance(0.1)
            game.Tick(0.1)
        hud = addon.modules["HunterRangeFinder"]._hud()
        self.assertTrue(game.Same(hud.points[1][2], game.euiPlate.health))
        rt.execute("euiPlate.health:Hide(); euiPlate=EUIPlate(plateA,'nameplate1')")
        pulse(game)
        self.assertTrue(game.Same(hud.points[1][2], game.euiPlate.health))

    def test_disabled_stats_does_not_register_eui_bag_painter(self):
        rt, game, addon, dot = boot(False, r"""
            UsefulPlatesAndTooltipsDB={modules={StatsInfo={enabled=false}}}
            registered=0
            EUI_Bags={RegisterItemOverlayIcon=function() registered=registered+1 end}
        """)
        game.Fire("ADDON_LOADED", "EllesmereUIBags")
        self.assertEqual(game.registered, 0)

    def test_shields_follow_eui_player_target_nameplate_and_party(self):
        for retail in (False, True):
            with self.subTest(retail=retail):
                rt, game, addon, dot = boot(retail, r"""
                    function UnitGetTotalAbsorbs() return SECRET end
                    euiParty=FakeMock('party',UIParent)
                    euiParty.GetAttribute=function() return 'party1' end
                    partyHealth=FakeMock('party HP',euiParty)
                    EllesmereUI._ModuleNS.EllesmereUIRaidFrames={
                        _internals={unitToButton={party1=euiParty}},
                        GetFFD=function() return {health=partyHealth} end,
                    }
                """)
                shield = addon.modules["ShieldsInfo"]
                shield.Update()
                for bar in (game.euiPlayer.Health, game.euiTarget.Health, game.euiPlate.health, game.partyHealth):
                    overlay = shield._overlay(bar)
                    self.assertIsNotNone(overlay)
                    self.assertTrue(overlay.bar.shown)
                    self.assertTrue(game.Same(overlay.bar.value, game.SECRET))
                old = shield._overlay(game.euiTarget.Health)
                rt.execute("euiTarget.Health=FakeMock('new target HP',euiTarget); euiParty.GetAttribute=function() return SECRET end")
                shield.Update()
                self.assertFalse(old.bar.shown)
                self.assertFalse(shield._overlay(game.partyHealth).bar.shown)
                self.assertTrue(shield._overlay(game.euiTarget.Health).bar.shown)

    def test_new_protected_eui_shield_host_waits_until_combat_ends(self):
        for retail in (False, True):
            with self.subTest(retail=retail):
                rt, game, addon, dot = boot(retail, "function UnitGetTotalAbsorbs() return 75 end")
                shield = addon.modules["ShieldsInfo"]
                rt.execute("""
                    combat=true
                    function InCombatLockdown() return combat end
                    euiTarget.Health=FakeMock('protected HP',euiTarget)
                    euiTarget.Health.IsProtected=function() return true end
                """)
                shield.Update()
                self.assertIsNone(shield._overlay(game.euiTarget.Health))
                rt.execute("combat=false")
                shield.Update()
                self.assertTrue(shield._overlay(game.euiTarget.Health).bar.shown)

    def test_visible_nameplate_bar_and_recycled_health_are_used(self):
        for retail in (False, True):
            with self.subTest(retail=retail):
                rt, game, addon, dot = boot(retail)
                context["cast"](game, 703)
                pulse(game)
                bar, path = addon.Plate.HealthBar(game.plateA)
                self.assertTrue(game.Same(bar, game.euiPlate.health))
                self.assertEqual(path, "EllesmereUINameplates.health")
                self.assertGreater(dot.nameplateDamageBase(game.plateA, game.euiPlate.health), 0)
                rt.execute("euiPlate.health:Hide(); euiPlate=EUIPlate(plateA,'nameplate1')")
                pulse(game)
                self.assertGreater(dot.nameplateDamageBase(game.plateA, game.euiPlate.health), 0)
                rt.execute("euiPlate:Hide()")
                pulse(game)
                self.assertEqual(dot.nameplateDamageBase(game.plateA, game.euiPlate.health), 0)

    def test_target_profile_bar_and_portrait_changes_are_followed(self):
        for retail in (False, True):
            with self.subTest(retail=retail):
                rt, game, addon, dot = boot(retail)
                context["cast"](game, 703)
                pulse(game)
                self.assertTrue(game.Same(game.UsefulPlatesAndTooltips_DoTInfoRemaining.allPoints, game.euiTarget.Health))
                rt.execute("euiTarget.Health=FakeMock('new HP',euiTarget); euiTarget.Portrait=FakeMock('new portrait',euiTarget)")
                pulse(game)
                self.assertTrue(game.Same(game.UsefulPlatesAndTooltips_DoTInfoRemaining.allPoints, game.euiTarget.Health))
                rt.execute("euiSource='hidden'")
                pulse(game)
                self.assertFalse(game.UsefulPlatesAndTooltips_DoTInfoRemaining.shown)
                rt.execute("euiSource='blizzard'")
                pulse(game)
                self.assertFalse(game.Same(game.UsefulPlatesAndTooltips_DoTInfoRemaining.allPoints, game.euiTarget.Health))
                self.assertTrue(game.UsefulPlatesAndTooltips_DoTInfoRemaining.shown)

    def test_action_numbers_follow_secure_slot_pages_and_hidden_values(self):
        for retail in (False, True):
            with self.subTest(retail=retail):
                rt, game, addon, dot = boot(retail)
                sdi = addon.modules["SpellDamageInfo"]
                sdi.Refresh()
                self.assertTrue(sdi._labels[game.EABButton1].shown)
                first = sdi._labels[game.EABButton1].text
                rt.execute("euiAction=73")
                game.Fire("ACTIONBAR_PAGE_CHANGED")
                self.assertTrue(sdi._labels[game.EABButton1].shown)
                self.assertNotEqual(sdi._labels[game.EABButton1].text, first)
                rt.execute("euiAction=SECRET")
                game.Fire("ACTIONBAR_PAGE_CHANGED")
                self.assertFalse(sdi._labels[game.EABButton1].shown)
                rt.execute("""
                    EABButton180=CreateFrame('CheckButton','EABButton180',UIParent)
                    EABButton180.GetAttribute=function() return 61 end
                """)
                game.Fire("PLAYER_REGEN_ENABLED")
                self.assertTrue(sdi._labels[game.EABButton180].shown)
                before = len(sdi._buttons)
                sdi.RecollectButtons()
                self.assertEqual(len(sdi._buttons), before)

    def test_native_poison_uses_eui_target_and_retires_old_container(self):
        fixture = ROOT / "tests/test_rogue_poison_native_damage.py"
        native = {"__file__": str(fixture)}
        exec(compile(fixture.read_text(encoding="utf-8").split("rt, game, dot = setup()", 1)[0],
                     "native_fixture", "exec"), native)
        rt, game, dot = native["setup"](UNITS)
        projection = game.FindProjection(game.euiTarget)
        self.assertIsNotNone(projection)
        self.assertTrue(projection.container.enabled)
        self.assertTrue(game.Same(game.FindIcons(game.euiTarget).parent, game.euiTarget))
        rt.execute("euiSource='hidden'")
        dot.Retail.UpdateRogueAuras()
        self.assertFalse(projection.container.enabled)
        rt.execute("euiSource='blizzard'")
        dot.Retail.UpdateRogueAuras()
        self.assertTrue(game.FindProjection(game.TargetFrame).container.enabled)
        self.assertFalse(projection.container.enabled)

    def test_forever_bag_callback_keeps_state_off_secure_buttons_and_reuses_marker(self):
        rt, game, addon, dot = boot(False, r"""
            callbacks={}
            EUI_Bags={RegisterItemOverlayIcon=function(id,fn) callbacks[id]=fn end,
                UnregisterItemOverlayIcon=function(id) callbacks[id]=nil end}
            bagButton=FakeMock('secure item button',UIParent)
            bagHost=FakeMock('text overlay',bagButton)
            bagButton._textOverlay=bagHost
            setmetatable(bagButton,{__index=getmetatable(bagButton).__index,
                __newindex=function() error('custom state written onto an EUI secure button') end})
            liveLink='item:1'
            C_Container=C_Container or {}
            C_Container.GetContainerItemInfo=function() return {hyperlink=liveLink,stackCount=1} end
        """)
        stats = addon.modules["StatsInfo"]
        stats.BagVerdictState = rt.eval("function() return 'ok',{verdict='up'} end")
        self.assertEqual(len(list(game.callbacks.keys())), 1)
        callback = next(iter(game.callbacks.values()))
        data = rt.table_from({"bag": 0, "slot": 1, "itemLink": "item:1"})
        callback(game.bagButton, data)
        self.assertEqual(len(game.bagHost.children), 1)
        marker = game.bagHost.children[1]
        self.assertTrue(marker.shown)
        callback(game.bagButton, rt.table_from({"bag": 0, "slot": 0}))
        self.assertFalse(marker.shown)
        callback(game.bagButton, data)
        self.assertTrue(marker.shown)
        self.assertEqual(len(game.bagHost.children), 1, "recycling an empty slot leaked a marker")
        rt.execute("liveLink='item:2'")
        stats.RefreshBags(True)
        self.assertFalse(marker.shown, "a recycled slot kept the previous item's verdict")
        callback(game.bagButton, rt.table_from({"bag": 0, "slot": 1, "itemLink": "item:2"}))
        self.assertTrue(marker.shown)
        stats.DisableBagMarkers()
        self.assertFalse(marker.shown)
        self.assertEqual(len(list(game.callbacks.keys())), 0)
        stats.EnableBagMarkers()
        self.assertEqual(len(list(game.callbacks.keys())), 1)

    def test_late_bag_load_and_combat_deferred_marker(self):
        rt, game, addon, dot = boot(False)
        stats = addon.modules["StatsInfo"]
        stats.BagVerdictState = rt.eval("function() return 'ok',{verdict='down'} end")
        rt.execute(r"""
            callbacks={}
            EUI_Bags={RegisterItemOverlayIcon=function(id,fn) callbacks[id]=fn end,
                UnregisterItemOverlayIcon=function(id) callbacks[id]=nil end}
            combat=true
            function InCombatLockdown() return combat end
            bagButton=FakeMock('secure bag button',UIParent)
            bagHost=FakeMock('text overlay',bagButton)
            bagButton._textOverlay=bagHost
            C_Container=C_Container or {}
            C_Container.GetContainerItemInfo=function() return {hyperlink='item:3',stackCount=1} end
        """)
        game.Fire("ADDON_LOADED", "EllesmereUIBags")
        callback = next(iter(game.callbacks.values()))
        callback(game.bagButton, rt.table_from({"bag": 0, "slot": 1, "itemLink": "item:3"}))
        self.assertEqual(len(game.bagHost.children), 0)
        rt.execute("combat=false")
        game.Fire("PLAYER_REGEN_ENABLED")
        self.assertEqual(len(game.bagHost.children), 1)
        self.assertTrue(game.bagHost.children[1].shown)


if __name__ == "__main__":
    unittest.main(verbosity=2)
