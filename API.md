# DoT API

For addon authors: show Useful Plates and Tooltips' DoT estimate (how much damage the player's DoTs still have to
deal) on your own unit frames or nameplates. Available when the addon is installed and its DoTInfo module is on. Add
`## OptionalDeps: UsefulPlatesAndTooltips` to your `.toc` and check that the global exists before using it.
Adapted from the [Does It Die](https://www.curseforge.com/wow/addons/does-it-die) API (Joe Greive, MIT); the global
has its own name, so both addons can be installed together.

```lua
local DoT = UsefulPlatesAndTooltips_DoTAPI
if DoT and DoT.API_VERSION >= 1 then ... end
```

## Functions

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

### `DoT.RegisterCallback(owner, func)` / `DoT.UnregisterCallback(owner)`

`func(event, unit)` runs when the remaining damage on `target`, `focus` or a `nameplateN` changes, or that unit now
shows another mob, including changes between mobs with no tracked DoTs. `event` is `"DOTS_CHANGED"`. `owner` is any value identifying you (your addon's name, a frame);
registering again with the same owner replaces the function. Changes are checked every 0.1 seconds and on casts and
ticks. Errors in your function are caught and written to the addon's DoT log; they don't stop other callbacks.

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

`Modules/DoTInfo/Nameplates.lua` and `Focus.lua` are full examples, with smoothing, per-DoT segments and layering.
