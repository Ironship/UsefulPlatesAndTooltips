"""Projected loss follows native HP geometry, with school colors and distinct cast/channel fills."""
from pathlib import Path
from math import isclose

ROOT = Path(__file__).resolve().parent.parent
fixture = ROOT / "tests/test_bit.py"
context = {"__file__": str(fixture)}
exec(compile(fixture.read_text(encoding="utf-8").split('print("-- every module on")', 1)[0],
             "bit_fixture", "exec"), context)


def scenario(retail):
    rt, game, addon, _ = context["load"](saved=r'''
        function GetBuildInfo()
            if retailClient then return '12.1.0','69933','',120100 end
            return '1.60.1','70450','',16001
        end
        function GetLocale() return 'enUS' end
        function GameFontNormalSmall:GetFont() return 'Fonts\FRIZQT__.TTF',12,'' end
        function C_Spell.GetSpellInfo() return {castTime=1500} end
        function UnitCanAttack(_, unit) return units[unit] ~= nil end
        function UnitName() return 'Wolf' end
        function NativeScale(self)
            return (self.scale or 1) * (self.parent and NativeScale(self.parent) or 1)
        end
        function InstallGeometry(frame)
            local createTexture=frame.CreateTexture
            frame.CreateTexture=function(self, ...)
                local texture=createTexture(self, ...)
                InstallGeometry(texture)
                return texture
            end
            frame.SetAllPoints=function(self, host) self.allPoints=host or self.parent end
            frame.SetClipsChildren=function(self, flag) self.clipsChildren=flag end
            frame.SetReverseFill=function(self, flag) self.reverse=flag end
            frame.GetReverseFill=function(self) return self.reverse or false end
            frame.SetOrientation=function(self, value) self.orientation=value end
            frame.GetOrientation=function(self) return self.orientation or 'HORIZONTAL' end
            frame.GetWidth=function(self)
                if self.allPoints then return self.allPoints:GetWidth()*NativeScale(self.allPoints)/NativeScale(self) end
                return self.width or 100
            end
            frame.GetHeight=function(self)
                if self.allPoints then return self.allPoints:GetHeight()*NativeScale(self.allPoints)/NativeScale(self) end
                return self.height or 20
            end
            frame.SetMinMaxValues=function(self, lo, hi) self.minimum,self.maximum=lo,hi end
            frame.SetValue=function(self, value) self.value=value end
            frame.SetTexture=function(self, texture) self.texture=texture end
            frame.SetVertexColor=function(self, ...) self.tint={...} end
            frame.SetHorizTile=function(self, flag) self.horizTile=flag end
            frame.SetVertTile=function(self, flag) self.vertTile=flag end
        end
        for _, frame in ipairs(AllFrames) do InstallGeometry(frame) end
        local create=CreateFrame
        function CreateFrame(...)
            local frame=create(...)
            InstallGeometry(frame)
            return frame
        end
        target={hostile=true}
        units.target={guid='Wolf',health=60,max=100}
        units.nameplate1=units.target
        plate=NewPlate()
        for _, frame in ipairs(AllFrames) do InstallGeometry(frame) end
        spellNames[900999]='Test Fire'
        spellDesc[900999]='Deals 20 Fire damage.'
        spellNames[5143]='Arcane Missiles'
        spellDesc[5143]='Deals 20 Arcane damage over 4 sec.'
        function UnitChannelInfo() return 'Arcane Missiles',nil,nil,GetTime()*1000,(GetTime()+4)*1000,false,false,5143 end
        UsefulPlatesAndTooltipsDB={modules={CastPrediction={fillColor='red',plateFillColor='white'}}}
    ''')
    game.retailClient = retail
    game.Fire("ADDON_LOADED", "UsefulPlatesAndTooltips")
    game.Fire("PLAYER_LOGIN")
    module = addon.modules.CastPrediction
    module._settings().useAuras = False
    module._settings().useTalents = False
    module._settings().learn = False
    host = addon.Plate.UnitFrame("target")[1]
    plate_host = game.plate.UnitFrame.healthBar
    for bar in (host, plate_host):
        bar.SetWidth(bar, 200)
        bar.SetHeight(bar, 20)
    host.scale = 1.25
    plate_host.scale = 0.8

    def refresh(health, maximum=100):
        game.units.target.health, game.units.target.max = health, maximum
        for bar in (host, plate_host):
            bar.SetMinMaxValues(bar, 0, maximum)
            bar.SetValue(bar, health)
        module._refresh()

    def visible_interval(marker, bar, health, maximum):
        # Model native anchoring/StatusBar fill in physical pixels, then apply native clipping.
        clip = marker.GetParent(marker)
        assert clip.clipsChildren and game.Same(clip.allPoints, bar)
        vertical = bar.orientation == "VERTICAL"
        anchor = marker.points[1]
        assert game.Same(anchor[2], bar.GetStatusBarTexture(bar))
        assert marker.reverse == (not bool(bar.reverse))
        if vertical:
            assert anchor[1] == ("BOTTOMLEFT" if bar.reverse else "TOPLEFT")
            native_width = bar.GetHeight(bar) * game.NativeScale(bar)
            marker_width = marker.height * game.NativeScale(marker)
        else:
            assert anchor[1] == ("TOPLEFT" if bar.reverse else "TOPRIGHT")
            native_width = bar.GetWidth(bar) * game.NativeScale(bar)
            marker_width = marker.width * game.NativeScale(marker)
        assert isclose(native_width, marker_width), "overlay scale drifted from health scale"
        edge = native_width * ((1 - health / maximum) if bar.reverse else health / maximum)
        amount = marker.value / marker.maximum * marker_width
        start, end = (edge, edge + amount) if bar.reverse else (edge - amount, edge)
        return max(0, start) / native_width * maximum, min(native_width, end) / native_width * maximum

    game.Fire("UNIT_SPELLCAST_START", "player", "cast", 900999)
    refresh(60)
    marker = module._marker()
    assert visible_interval(marker, host, 60, 100) == (40, 60)
    widgets = module._plateWidgets(game.plate)
    assert module._settings().fillColor == module._settings().plateFillColor == "school"
    for health, maximum, expected in ((60, 100, (40, 60)), (35, 100, (15, 35)),
                                      (10, 100, (0, 10)), (100, 200, (80, 100))):
        refresh(health, maximum)
        assert visible_interval(marker, host, health, maximum) == expected
        assert visible_interval(widgets.marker, plate_host, health, maximum) == expected
    for bar in (host, plate_host):
        bar.reverse = True
    refresh(35)
    for overlay, bar in ((marker, host), (widgets.marker, plate_host)):
        actual = visible_interval(overlay, bar, 35, 100)
        assert all(isclose(x, y) for x, y in zip(actual, (65, 85)))
        bar.orientation = "VERTICAL"
    refresh(35)
    for overlay, bar in ((marker, host), (widgets.marker, plate_host)):
        actual = visible_interval(overlay, bar, 35, 100)
        assert all(isclose(x, y) for x, y in zip(actual, (65, 85)))
        bar.orientation, bar.reverse = "HORIZONTAL", False
    refresh(60)

    direct = module._fill()
    assert direct.texture.endswith("WHITE8X8") and not direct.horizTile
    fire = addon.modules.DoTInfo.dotColor(rt.table(school=4), "school")
    assert tuple(direct.tint[i] for i in (1, 2, 3)) == tuple(fire[i] for i in (1, 2, 3))
    assert tuple(widgets.fill.tint[i] for i in (1, 2, 3)) == tuple(fire[i] for i in (1, 2, 3))
    game.Fire("UNIT_SPELLCAST_CHANNEL_START", "player", "channel", 5143)
    assert direct.texture.endswith("DashH2") and direct.horizTile and direct.vertTile
    assert widgets.fill.texture.endswith("DashH2")
    arcane = addon.modules.DoTInfo.dotColor(rt.table(school=64), "school")
    assert tuple(direct.tint[i] for i in (1, 2, 3)) == tuple(arcane[i] for i in (1, 2, 3))

    # Host HP remains unreadable to addon arithmetic; the native scale still receives it unchanged.
    rt.execute('''
        local function forbidden() error('addon calculated with secret health') end
        SECRET_HP=setmetatable({}, {__sub=forbidden,__div=forbidden,__lt=forbidden,__le=forbidden})
        SECRET_MAX=setmetatable({}, {__sub=forbidden,__div=forbidden,__lt=forbidden,__le=forbidden})
        function issecretvalue(v) return rawequal(v,SECRET_HP) or rawequal(v,SECRET_MAX) end
        function UnitHealth() return SECRET_HP end
        function UnitHealthMax() return SECRET_MAX end
    ''')
    module._refresh()
    assert marker.shown and game.Same(marker.maximum, game.SECRET_MAX)
    assert widgets.marker.shown and game.Same(widgets.marker.maximum, game.SECRET_MAX)
    assert module._label().shown
    print(f"ok {'Retail' if retail else 'Forever'}: partial/moving HP, overkill clip, scaled/reverse/vertical bars, patterns, school colors, secret HP")


if __name__ == "__main__":
    scenario(False)
    scenario(True)
