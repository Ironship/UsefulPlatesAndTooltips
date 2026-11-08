# Public API

For addon authors: show DoesItDiePlus' DoT and pending-cast damage estimates on your own unit frames or nameplates.
Add `## OptionalDeps: UsefulPlatesAndTooltips` to your `.toc` and read the API at `PLAYER_LOGIN` or later,
after module settings have loaded.
Adapted from the [Does It Die](https://www.curseforge.com/wow/addons/does-it-die) API (Joe Greive, MIT); the global
has its own name, so both addons can be installed together.

```lua
local API = UsefulPlatesAndTooltips_API
local DoT = API and API.Get("DoT")
local Cast = API and API.Get("CastPrediction")
```

The original DoT global remains available for existing consumers:

```lua
local DoT = UsefulPlatesAndTooltips_DoTAPI
if DoT and DoT.API_VERSION >= 1 then ... end
```

## Module discovery and callbacks

`UsefulPlatesAndTooltips_API.API_VERSION` is `1`. Sub-APIs have independent versions; check `API_VERSION >= n`.
Additions can raise a version; incompatible contracts need a different API name.

| Function | Result |
|---|---|
| `API.Get(name)` | `"DoT"` or `"CastPrediction"` API table, or `nil` if absent or disabled |
| `API.GetVersion(name)` | Sub-API version, or `nil` |
| `API.GetModules()` | A new list of enabled sub-API names |
| `API.GetEvents()` | A new list of declared event names, including disabled modules |
| `API.GetAddonVersion()` | TOC version string, or `nil` if unavailable |
| `API.RegisterCallback(owner, event, func)` | Registers `func(event, unit)`; one callback per owner and event |
| `API.UnregisterCallback(owner [, event])` | Removes that owner's callback for one event, or all events |

Callbacks run in registration order. Registering the same owner/event replaces its function; removing a callback
takes effect immediately, while a newly registered callback first runs on the next event. Each callback runs
under `pcall`, and failures are logged once without stopping other listeners. Unknown events, missing owners and
non-function callbacks raise an error. Disabled modules are absent from `Get` and do not emit events; changing a
module's enabled setting takes effect after `/reload`.

| Event | Meaning |
|---|---|
| `DOTS_CHANGED` | DoT damage or tracked identity changed for `target`, `focus` or a `nameplateN` |
| `CAST_PREDICTION_CHANGED` | A pending cast started, ended, changed an exposed field, or moved to another unit token |

For cast events, `unit` is the current recipient token, the previous token when the cast ends, or `nil` when the
recipient is not visible on a supported token. Consumers with multiple bars should refresh all their cast overlays,
including the old recipient's. Changes are checked every 0.1 seconds and on relevant game events.

`/upt api` prints API versions, module availability and listener counts.

## DoT API (version 2)

`API.Get("DoT")` and `UsefulPlatesAndTooltips_DoTAPI` refer to the same table. Damage and DoT-list functions retain
their version-1 contract; version 2 adds `CanTrack` and shared callback registration.

### `DoT.GetRemainingDamage(unit) -> damage, count`

The total damage the player's DoTs on the mob behind `unit` still have to deal (rounded), and how many DoTs that is.
`0, 0` when there are none, the unit can't be tracked or the DoTInfo module is off. `target`, `focus` and `nameplateN`
are the units the tracking can keep up to date, since `UNIT_COMBAT` only reports hits on those.

### `DoT.GetDoTs(unit) -> list`

The player's DoTs on that mob, oldest first. A new table on every call, safe to keep. Each entry:

| Field | |
|---|---|
| `name` | Spell name (as the client shows it) |
| `spellID` | Spell ID of the cast (can be missing on Retail) |
| `school` | School bit mask (1 Physical, 2 Holy, 4 Fire, 8 Nature, 16 Frost, 32 Shadow, 64 Arcane) |
| `damage` | Remaining damage (rounded) |
| `appliedAt`, `expiresAt` | `GetTime()` seconds |
| `provisional` | `true` while the spell is still being cast (it is dropped if the cast fails) |

DoTs waiting for their first tick (when the addon isn't sure they landed) aren't listed.

### `DoT.CanTrack(unit) -> boolean`

Whether this existing unit has an identity the enabled module can resolve now. Distinguishes an empty estimate
from an unavailable identity. This does not promise that every effect on the unit was observed; updates still
depend on the tracked units and readable client events.

### `DoT.RegisterCallback(owner, func)` / `DoT.UnregisterCallback(owner)`

`func(event, unit)` runs when the remaining damage on `target`, `focus` or a `nameplateN` changes, or that unit now
shows another mob, including changes between mobs with no tracked DoTs. `event` is `"DOTS_CHANGED"`. `owner` is any value identifying you (your addon's name, a frame);
registering again with the same owner replaces the function. Changes are checked every 0.1 seconds and on casts and
ticks. Errors in your function are caught and written to the addon's DoT log; they don't stop other callbacks.

These are aliases for `API.RegisterCallback(owner, "DOTS_CHANGED", func)` and
`API.UnregisterCallback(owner, "DOTS_CHANGED")`; registering through both with the same owner replaces, rather
than duplicates, the callback.

## CastPrediction API (version 1)

`API.Get("CastPrediction")` returns the API while CastPrediction is enabled, on Forever and Retail.
Estimates include the module's calibration, talents and readable effects. They are not guaranteed hits.
Finisher previews, settings previews and the short display after an observed impact are excluded.

### `Cast.GetCurrent() -> table or nil`

A new snapshot of the actual pending cast, safe to retain or modify. `nil` when no cast is pending or the module is off.

| Field | Meaning |
|---|---|
| `spellID`, `name` | Spell ID and readable localized name |
| `school` | School bit mask; Frostfire is 20, unsupported school names return `nil` |
| `damage` | Rounded estimate selected by the user's min/average/max setting |
| `min`, `max` | Rounded damage range |
| `channel`, `instant` | Booleans |
| `startedAt` | `GetTime()` seconds |
| `endsAt` | Channel end time, otherwise absent |
| `unit` | Current recipient token (`target`, `focus`, `mouseover`, `softenemy`, `nameplateN`), or absent |

Channels expose remaining damage, not the full original total. Recipient lookup follows the tracked identity,
not the recipient's name. Returned snapshots contain prediction data only, not frames or secret health values.

### `Cast.GetPredictedDamage(unit) -> damage, min, max`

The rounded pending damage aimed at this unit, or `0, 0, 0` when none is known. A different token for the same
tracked recipient works too. It is independent of whether the addon's own marker is enabled or visible.

## Drawing it: the health is secret

Forever keeps the target's health secret: addon code can pass it to widgets but can't compare it or do math with it.
So you can't write `if damage >= UnitHealth(unit)`. Let a `StatusBar` do the comparison instead.

**Marker on the health bar.** A transparent `StatusBar` laid over your health bar, with the mob's max health as its
max and the remaining damage as its value. Its fill texture spans the damage, from the bar's left edge, on the same
scale as the health. Draw your marker over that fill. If the health ends inside it, the DoTs will kill the mob.

```lua
local marker = CreateFrame("StatusBar", nil, healthBar)
marker:SetAllPoints(healthBar) -- the bar must fill left to right and be exactly the fill area
marker:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
marker:SetStatusBarColor(1, 0.8, 0, 0.5)

local function update(unit)
    marker:SetMinMaxValues(0, UnitHealthMax(unit)) -- secret is fine here
    marker:SetValue((DoT.GetRemainingDamage(unit)))
end
```

**Kill icon (show something only when lethal).** A long `StatusBar` (say 10,000 px) inside a small frame that clips
its children, anchored at the frame's right edge, with max = current health and value = remaining damage. Put the
icon at the end of the bar's fill. The fill only reaches the visible window when damage >= health, so the icon slides
into view exactly then.

```lua
local window = CreateFrame("Frame", nil, portrait)
window:SetSize(24, 24)
window:SetPoint("CENTER", portrait)
window:SetClipsChildren(true)

local bar = CreateFrame("StatusBar", nil, window)
bar:SetSize(10000, 24)
bar:SetPoint("RIGHT", window, "RIGHT")
bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
bar:SetStatusBarColor(0, 0, 0, 0)

local icon = bar:CreateTexture(nil, "OVERLAY")
icon:SetSize(24, 24)
icon:SetPoint("RIGHT", bar:GetStatusBarTexture(), "RIGHT")
icon:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")

local function update(unit)
    bar:SetMinMaxValues(0, UnitHealth(unit))
    bar:SetValue((DoT.GetRemainingDamage(unit)))
end
```

DoT and cast estimates are plain numbers, so consumers may add their first return values:
`DoT.GetRemainingDamage(unit) + Cast.GetPredictedDamage(unit)`. Check both APIs exist before doing so.

`Modules/DoTInfo/Nameplates.lua` and `Focus.lua` are full examples, with smoothing, per-DoT segments and layering.
