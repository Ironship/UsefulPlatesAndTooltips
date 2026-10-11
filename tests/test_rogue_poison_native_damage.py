"""Native poison projection setup with all addon aura reads denied and native buttons locked.

Mocks validate bindings/format rules and lifecycle; they do not prove WoW's secret rendering.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
fixture = ROOT / "tests/test_rogue_auras_retail.py"
context = {"__file__": str(fixture)}
exec(compile(fixture.read_text(encoding="utf-8").split("rt, game, dot = boot()", 1)[0],
             "native_fixture", "exec"), context)

PROJECTION = r"""
function GetLocale() return 'enUS' end
Enum.DurationTextBindingProperty = { RemainingPercent = 1 }
Enum.StatusBarTimerDirection = { RemainingTime = 1 }
spellDesc[2823] = 'Coats your weapons for 1 hour. Each strike has a 30% chance to poison the enemy for 46 Nature damage over 12 sec. Subsequent applications instantly deal 6 Nature damage.'
function UnitHealthMax() return SECRET end
formatters, poisonBindings = {}, {}
C_StringUtil = { CreateNumericRuleFormatter = function()
    local f = { writes = 0 }
    function f:SetBreakpoints(rules) self.rules = rules; self.writes = self.writes + 1 end
    table.insert(formatters, f)
    return f
end }
local factory = CreateFrame
function CreateFrame(kind, name, parent, template)
    local frame = factory(kind, name, parent, template)
    if kind == 'StatusBar' then
        frame.SetMinMaxValues = function(self, min, max) self.min, self.max = min, max end
        frame.SetValue = function(self, value) self.value = value end
    end
    if kind ~= 'AuraContainer' then return frame end
    frame.AddAuraSlot = function(self, key, filter, options)
        assert(key == 'deadlyDamage' and filter == 'HARMFUL|PLAYER')
        assert(options.candidateFilters.includeSpellIDs[2818])
        local count = 0; for _ in pairs(options.candidateFilters.includeSpellIDs) do count = count + 1 end
        assert(count == 1, 'other rogue auras cannot feed the Deadly Poison projection')
        local button = FakeMock('AuraButton', self)
        local record = { container = self, button = button, nativeVisible = false }
        button.SetDurationBar = function(_, bar, opts) record.timer, record.direction = bar, opts.direction end
        button.SetDurationText = function(_, text, opts)
            if slotInitializerFails then error('duration binding failed') end
            record.text, record.format = text, opts.textFormat
        end
        pcall(options.initializeFrame, button)  -- Blizzard's secure callback also swallows errors.
        if not slotInitializerFails then assert(record.timer and record.text and record.format) end
        setmetatable(button, { __index = function() error('restricted native button was read') end })
        -- Children inherit the same access restriction. Only native bindings may mutate them now.
        for _, child in ipairs(button.children) do
            setmetatable(child, { __index = function() error('restricted native child was read') end })
        end
        table.insert(poisonBindings, record)
        return button
    end
    return frame
end
function FindProjection(parent)
    for i = #poisonBindings, 1, -1 do
        if rawequal(poisonBindings[i].container.parent, parent) then return poisonBindings[i] end
    end
end
-- Test-only model of the C engine; addon Lua never receives this fraction or visibility.
function NativePoison(record, fraction)
    record.nativeVisible = fraction ~= nil and record.container.enabled == true
    if not record.nativeVisible then record.nativeText = nil; return end
    record.nativeFraction = fraction
    local component = record.format.components[1]
    local rule = component.formatter.rules[1]
    if rule.format == '' then record.nativeText = ''; return end
    local result = fraction / rule.components[1].div
    result = math.floor(result / rule.components[1].step + 0.5) * rule.components[1].step
    record.nativeText = string.format(record.format.formatString, string.format(rule.format, result))
end
"""


def setup(extra=""):
    rt, game, dot = context["boot"](PROJECTION + extra)
    dot.db.showLabel = True
    game.Fire("PLAYER_ENTERING_WORLD")
    return rt, game, dot


rt, game, dot = setup()
target, plate = game.FindProjection(game.TargetFrame), game.FindProjection(game.plateA)
assert len(game.poisonBindings) == 2 and game.auraCalls == 0
for binding in (target, plate):
    assert binding.direction == 1
    assert binding.format.components[1].property == 1
    assert len(binding.button.points) == 0  # SetAllPoints uses the HP scale's fill texture.
    assert binding.timer.parent.kind == "AuraButton"
    game.NativePoison(binding, 1)
    assert binding.nativeText == "~46"
    game.NativePoison(binding, .5)
    assert binding.nativeText == "~23"
    game.NativePoison(binding, .25)
    assert binding.nativeText == "~12"
    game.NativePoison(binding, None)
    assert not binding.nativeVisible and binding.nativeText is None
print("ok exact Deadly Poison native slots supply countdown damage while addon aura reads are denied")

# An invisible plain StatusBar maps full poison damage to secret max HP; the native countdown
# is nested in its fill without reading width, health, duration, aura state or native children.
scales = [f for f in game.AllFrames.values()
          if f.kind == "StatusBar" and f.parent.kind != "AuraButton" and f.value == 46]
assert len(scales) == 2
for scale in scales:
    assert game.Same(scale.max, game.SECRET)
    assert scale.height == 2 and scale.template == "DisableUntrustedLayoutScriptsTemplate"
    assert scale.parent.kind != "AuraButton"
writes = sum(f.writes for f in game.formatters.values())
for _ in range(30):
    dot.Retail.UpdateRogueAuras()
assert game.auraCalls == 0 and sum(f.writes for f in game.formatters.values()) == writes
print("ok hidden HP is passed only to native scales; repeated rendering never probes restricted frames or resets timers")

game.spellDesc[2823] = "Poison deals 92 Nature damage over 12 sec."
dot.Retail.UpdateRogueAuras()
game.NativePoison(plate, .5)
assert plate.nativeText == "~46" and len(game.poisonBindings) == 2
dot.db.showLabel = False
dot.Retail.UpdateRogueAuras()
game.NativePoison(plate, .5)
assert plate.nativeText == ""  # The damage strip still has its HP scale.
assert all(f.value == 92 for f in scales)
dot.db.showLabel = True
game.spellDesc[2823] = game.SECRET
dot.Retail.UpdateRogueAuras()
game.NativePoison(plate, .5)
assert plate.nativeText == "" and all(f.value == 0 for f in scales)
print("ok changed spell amounts update native formatting; label preferences and hidden descriptions cannot leave stale numbers")

game.spellDesc[2823] = "Poison deals 46 Nature damage over 12 sec."
dot.db.showMarkers = False
dot.Retail.UpdateRogueAuras()
game.NativePoison(plate, .5)
assert not plate.nativeVisible and all(f.value == 0 for f in scales)
dot.db.showMarkers = True
dot.db.nameplateMode = "off"
dot.Retail.UpdateRogueAuras()
game.NativePoison(target, .5)
game.NativePoison(plate, .5)
assert target.nativeVisible and not plate.nativeVisible
dot.db.nameplateMode = "markerIcon"
game.Fire("NAME_PLATE_UNIT_REMOVED", "nameplate1")
game.NativePoison(plate, .5)
assert not plate.nativeVisible
rt.execute("plateMap.nameplate3 = plateA; units.nameplate3 = { hostile = true }")
game.Fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
assert game.FindProjection(game.plateA).container.unit == "nameplate3"
print("ok native poison follows marker settings and recycled nameplates without leaking prior visibility")

rt, game, dot = setup("""
    local original = C_StringUtil.CreateNumericRuleFormatter
    C_StringUtil.CreateNumericRuleFormatter = function() error('formatter failed') end
""")
assert len(game.poisonBindings) == 0
assert game.FindContainer(game.TargetFrame).enabled and game.FindContainer(game.plateA).enabled
print("ok native damage setup failures leave ordinary rogue aura icons operational")

rt, game, dot = setup("slotInitializerFails = true")
assert game.FindContainer(game.TargetFrame).enabled and game.FindContainer(game.plateA).enabled
for frame in game.AllFrames.values():
    if frame.kind == "StatusBar" and frame.parent.kind != "AuraButton":
        assert frame.value == 0 and not frame.shown
print("ok swallowed native initializer errors disable the incomplete projection without blocking aura icons")

rt, game, dot = setup("""
function GetLocale() return 'deDE' end
spellDesc[2823] = 'Überzieht Eure Waffen mit einem tödlichen Gift. Bei jedem Schlag besteht eine Chance von 30%, den Gegner zu vergiften. Das Gift verursacht im Verlauf von 12 Sek. 46 Naturschaden. Weitere Anwendungen auf das Ziel verursachen sofort 6 Naturschaden.'
""")
game.NativePoison(game.FindProjection(game.plateA), .5)
assert game.FindProjection(game.plateA).nativeText == "~23"
print("ok the reported German tooltip supplies periodic damage without proc chance or immediate hits")

# Drive the complete shipped Retail load order and the same denied access seen in SavedVariables.
rt = context["context"]["LuaRuntime"](unpack_returned_tuples=True)
rt.execute(context["context"]["FAKE"] + context["NATIVE"] + PROJECTION)
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
dot.db.showLabel = True
dot.Retail.UpdateRogueAuras()
plate = game.FindProjection(game.plateA)
game.NativePoison(plate, .5)
assert plate.nativeVisible and plate.nativeText == "~23"
assert any("aura access denied" in text for text in game.UsefulPlatesAndTooltips_DoTInfoDB.log.values())
assert any("NATIVE POISON damage display ready" in text for text in game.UsefulPlatesAndTooltips_DoTInfoDB.log.values())
assert dot.dotBreakdownForUnit("target")[1] == 0  # Native projection is separate from the Lua sum/skull.
calls = game.auraCalls
game.Tick(.3)
assert game.auraCalls == calls and len(game.poisonBindings) == 2
print("ok complete Retail addon load renders native poison alongside denied aura logs without inventing Lua proc state")

# Model a client whose incremental native updates stall: only a requested full refresh
# synchronizes the C-owned projection. All aura state below is test-only, never addon input.
rt, game, dot = setup()
rt.execute(r"""
nativeExpiry = {}
for _, container in ipairs(containers) do
    local refresh = container.UpdateAllAuras
    container.UpdateAllAuras = function(self)
        refresh(self)
        for _, record in ipairs(poisonBindings) do
            if rawequal(record.container, self) then
                local expiry = nativeExpiry[self.unit]
                local fraction = expiry and math.max(0, math.min(1, (expiry - GetTime()) / 12))
                NativePoison(record, fraction and fraction > 0 and fraction or nil)
            end
        end
    end
end
function NativeApply(unit) nativeExpiry[unit] = GetTime() + 12 end
""")
plate, target = game.FindProjection(game.plateA), game.FindProjection(game.TargetFrame)
game.Fire("PLAYER_TARGET_CHANGED")
assert not plate.nativeVisible and not target.nativeVisible  # First hit has no proc.
game.Advance(1)
game.NativeApply("nameplate1")
game.NativeApply("target")
game.Fire("UNIT_AURA", "nameplate1", game.SECRET)
assert plate.nativeVisible and plate.nativeText == "~46", "later proc must appear without target/nameplate recreation"
assert not target.nativeVisible  # An event for one token does not refresh every host.
game.Fire("UNIT_AURA", "target", game.SECRET)
assert target.nativeVisible and target.nativeText == "~46"
assert game.auraCalls == 0
game.Advance(6)
dot.Retail.UpdateRogueAuras()
assert plate.nativeText == "~23" and target.nativeText == "~23"
before = plate.container.refreshCalls
for _ in range(30):
    dot.Retail.UpdateRogueAuras()
assert plate.container.refreshCalls == before  # No full rescan on every rendering call.
game.NativeApply("nameplate1")
game.Fire("UNIT_AURA", "nameplate1", game.SECRET)
assert plate.nativeText == "~46" and target.nativeText == "~23"
print("ok later poison applications and renewals refresh the affected native container without reading hidden payloads")

# No readable UNIT_AURA token/event: shared rendering must still resynchronize periodically.
game.Advance(2)
game.NativeApply("nameplate1")
dot.Retail.UpdateRogueAuras()
assert plate.nativeText == "~46"
game.Advance(.1)
dot.Retail.UpdateRogueAuras()
assert plate.container.refreshCalls == before + 2
game.Advance(.2)
dot.Retail.UpdateRogueAuras()
assert plate.container.refreshCalls == before + 3 and plate.nativeText == "~45"
game.Fire("UNIT_AURA", game.SECRET, game.SECRET)
game.Fire("UNIT_AURA", "player", game.SECRET)
assert plate.container.refreshCalls == before + 3  # Hidden/unrelated tokens are not inspected or fan out.
game.Advance(12)
dot.Retail.UpdateRogueAuras()
assert not plate.nativeVisible and not target.nativeVisible
game.NativeApply("nameplate1")
game.Fire("UNIT_AURA", "nameplate1", game.SECRET)
assert plate.nativeVisible  # Reapplication after expiration does not need a new combat/target.
game.nativeExpiry["nameplate1"] = None
game.Fire("UNIT_AURA", "nameplate1", game.SECRET)
assert not plate.nativeVisible
assert game.auraCalls == 0 and len(game.poisonBindings) == 2
print("ok bounded native rescans recover missing incremental events, expiration, removal and reapplication on the same plate")
