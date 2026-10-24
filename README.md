# Useful Plates and Tooltips

Settings support native gamepads and ConsolePort. Assign Open settings under Options → Key Bindings → AddOns → Useful Plates and Tooltips. LB/RB switches module tabs, the D-pad selects controls, A / Cross activates the selected control, left/right adjusts sliders and B / Circle closes the window. The gold outline shows focus and scrolls into view. With ConsolePort active, its interface cursor and configured hints handle navigation.

It shows DoT marks, shields and range on nameplates, damage and healing numbers on action buttons, and item comparisons in tooltips. Every part can be switched off.

Build the Forever ZIP with `python tools/build_zip.py`, or the Retail ZIP with `python tools/build_zip.py --retail`. Packages are written to `dist/` and checked against the source files.

Modules are maintained directly in `Modules/`. The remaining tools regenerate stat weights (`make_weights.py`, using `tools/data/`) and textures (`make_resource_textures.py`, `make_ui_textures.py`).

### DoTInfo

Shows the damage your DoTs or Bleeds still have to deal as a marker on the target's health bar. If the target's health ends inside the marker, a skull on the portrait says the DoTs will kill it. When you cast spell then it shows during cast time estimation how much it might do on target.

Nameplate marks use the visible health bar, with dedicated support for EllesmereUI and Platynator and a cached automatic search for other nameplate addons. If no visible bar is found, DoTInfo can still show the kill icon beside the nameplate when "Marker and kill icon" is enabled.

The same marker (and kill icon) can sit on your focus frame, Blizzard's or EllesmereUI's, for your DoTs on the focused enemy ("Show on focus frame" in the Nameplates tab); `[@focus]` casts go on the focus. In Forever's instances mob GUIDs are secret: DoTInfo then keeps each mob apart by its nameplate, so tab-dotting a pack works (needs enemy nameplates on). The kill icon can be up to 128 px.

Description parsing covers English, German, Spanish, French, Korean, Brazilian Portuguese and Chinese (simplified and traditional), after Does It Die; the non-German languages are from Forever's own tooltips and not yet verified on a client in those languages. Other unit frame addons: name their target, focus or player health bar (and a spot for the kill icon, and a nameplate bar the automatic search misses) under DoTInfo > Behavior, with a Pick button that takes the frame you click, or by `/upt frame target ElvUF_Target.Health` and `/upt pick target`. ShieldsInfo and HealPrediction use the same frames. A hidden replacement frame hides the marks with it; with nothing set, nothing changes. After Does It Die's custom frames.

`/dotinfo check` reads every spell in your spellbook and lists the ones whose text mentions seconds but gives no DoT (full texts go to the saved log), so a client in another language can show what is still unread. In Forever, `/dotinfo ticks` (Behavior tab > View) lists the tick sizes learned from your casts next to what the tooltips predict.

![simulation](https://i.imgur.com/rI5Kdyv.gif)

<img width="465" height="407" alt="WowB_Bx6Sgl1bvb-ezgif com-optimize (1)" src="https://github.com/user-attachments/assets/7cf3fe30-5752-4cec-9bb4-2e4ece2af2c9" />

# There are also shields and healing predictions...
<img width="477" height="282" alt="{655C0DAD-5C68-4D0B-9374-CD94B9CD9476}" src="https://github.com/user-attachments/assets/70f1d92e-80d6-4d9f-b3ca-42899f926e27" />


<img width="236" height="108" alt="{182459A7-7224-45BB-BB6B-D8D1FA35FDD0}" src="https://github.com/user-attachments/assets/e6f429a0-ca1c-4813-9b66-29f6ef7b489b" />


Rip and Rupture use your combo points. Immolation Trap is tracked: placing it only arms it, and the DoT starts on the mob that takes its first tick. Ignite (mages) and Deep Wounds (warriors) are lit by critical hits, which no cast announces: a crit counts as yours when you cast at that mob just before (for Deep Wounds also when you swing at it alone), and the talent is assumed unless the talent tree shows no points. Ignite shows 8% a point of the fire crit over 4 s (rolling what the running one still owed into the new one), Deep Wounds 20% a point of your main hand's average damage over 12 s. The first tick confirms the guess. Forever only; switch them off in DoTInfo > Behavior.

### WIP
Channeling and casting prediction for normal spells.

<img width="1064" height="1009" alt="{3045F908-1D52-4E85-8F2D-19C7AF79044C}" src="https://github.com/user-attachments/assets/8d6dc029-3979-47fb-b450-7cf5a0375956" />

### CastPrediction

Shows the damage of the spell you are casting on the enemy's health bar and nameplate. Direct hits use a solid translucent fill; channels use vertical bands for the damage remaining. Colors follow the spell's school, matching DoTInfo.

The fill covers health backwards from its current edge: 20 damage at 60/100 HP covers 60 down to 40. It follows health changes and clips overkill inside the bar. Action targeting works without clicking a target, and the prediction stays on the original enemy if the reticle moves.

The estimate also holds the talents and effects the description leaves out (Forever): Fire Power, Piercing Ice, Arcane Instability, Shadow Mastery, Aftermath, Darkness, Searing Light, Moonfury and the rest of the curated list, and, while the client shows the aura, Arcane Power, Power Infusion, Arcane Blast stacks, Improved Scorch, Curse of the Elements, Demonic Sacrifice, Improved Shadow Bolt, Shadow and Flame, Decimation, Incinerate against your Immolate, Power in Light, Shadow Weaving, Shadowform, Stormstrike, Lava Burst against your Flame Shock, Rage of the Farseer and Eureka!. Talent ranks are matched by spell id as well as name, so a client in another language reads them. Auras are hidden in combat on Forever, so they apply out of combat only; the hit calibration carries the rest.

The direct hit is separate from DoTInfo's damage-over-time marker. For rank-1 Fireball, the unmodified average is 18 damage on impact plus 2 over time. Critical strikes, procs and resists can change the result. `/upt cast` opens the settings and preview.

### HealPrediction

Incoming healing on target, party and raid frames, drawn from the current health edge. It uses the client's `UnitGetIncomingHeals` reading. The other healers' share is a second band behind yours (the client's total is drawn first and your own heal over it); "All healers" draws the total in your color instead. Heals over time that you cast (Rejuvenation, Renew, Regrowth's tick part) are not part of the client's reading, so the amount their description promises is drawn after your direct heal for the next few seconds of the effect, as an estimate that runs out with the effect's time. `/upt heals` opens the settings.

### HunterRange

Hunter and ResourceDing dots share the same shaded orb, dark socket and bezel. Appearance samples use each module's renderer; changes also update the open preview. ResourceDing has an Appearance tab for its palette and opacity.

For hunters only. A range rail sits above the target's nameplate, or at a spot you place on screen: six dots, and a seventh past 35 yd when Hawk Eye is detected or switched on. A sword marks melee range, and a skull marks the dead zone. The bands are approximate, not exact yard measurements.

![range indicator](https://i.imgur.com/AGTwBqF.gif)
![range in game](https://i.imgur.com/gON8KAq.gif)

### ResourceDing

A sound when your combo points (or another finisher resource) are full, and dots under or above the target that show the points.

Casters get a sound when mana climbs to a set level: 100% by default, 80% for warlocks. Warlocks also get a sound for each Soul Shard that enters the bags, and purple diamonds under the target's nameplate show how many shards you carry.

![warlock shards](https://i.imgur.com/tVzNFEL.png) ![rogue combo points](https://i.imgur.com/1ITWdUb.png)

### SpellDamageInfo

![image](https://media.forgecdn.net/attachments/description/1724766/description_757732fe-af02-49e8-9c9e-5faed9f66325.png)

Damage and healing numbers on your action buttons and in spell tooltips.

Forever's native gamepad crossbar also gets the numbers, including after changing pages. Total mode includes the direct hit and DoT; Direct mode shows only the hit.

Bars built on LibActionButton (Bartender4, ElvUI and others) get the numbers too, for spells, macros and items on their buttons; this is new and not yet checked in the game with those addons.

![damage prediction](https://i.imgur.com/ySumj4S.png) ![healing prediction](https://i.imgur.com/xvGpoTg.png)

### StatsInfo

In an item's tooltip: how it compares with what you wear, what each difference is worth to your character, and how each spec of your class rates the item. Ratings use ForeverSim weights. Tanks also get survival and threat.

Every healer (Restoration druid or shaman, Holy priest or paladin) gets a score marked `(approx.)`. It is a heuristic, because ForeverSim does not simulate healing. **Work in progress.**

Tooltips are one line. Hold Shift to see the full version. Upgrade arrows also appear on bag, loot, need/greed and merchant buttons.

![stats comparison](https://i.imgur.com/wXVwDG6.png) ![another look on item](https://i.imgur.com/RIdkm9d.png)


## Confirmed support for

*   Platynator
*   EllesmereUI

## Licence

GPL-3.0-or-later, see [LICENSE](LICENSE).

Third-party parts keep their own MIT notices:

*   **DoTInfo** is based on [Does It Die](https://www.curseforge.com/wow/addons/does-it-die) by Joe Greive; see `Modules/DoTInfo/LICENSE-DoesItDie.txt`.
*   **ShieldsInfo** is adapted from [Shield Aura Forever](https://github.com/JasonEcks/ShieldAuraForever) by JasonEcks and contributors; see `Modules/ShieldsInfo/LICENSE-ShieldAuraForever.txt`.
*   **SpellDamageInfo's options window** is adapted from Does It Die by Joe Greive; see `Modules/SpellDamageInfo/LICENSE-SpellDamageInfo.txt`.
*   **Stat weights** come from [ForeverSim](https://github.com/laurencestokes/foreversim) (MIT), built on [WoWSims](https://github.com/wowsims/forever) and Elliot Wood's Forever sim; see `Modules/StatsInfo/LICENSE-ForeverSim.txt`.

On clients with the modern Settings API, the UPT, DoTInfo and SpellDamageInfo launchers use native settings-list buttons. Select the add-on, move right with the D-pad and confirm to open its window. Older clients retain the canvas page.
