# DoesItDiePlus

DoesItDiePlus, formerly Useful Plates and Tooltips, is my implementation of Does It Die which went too far from the original addon. I still commit my changes to Does It Die if possible. Here I implement and test changes which are not only for WoW Forever but also for Retail and Classic.

DoesItDiePlus, formerly Useful Plates and Tooltips, is an extended take on [Does It Die](https://www.curseforge.com/wow/addons/does-it-die) by Joe Greive: its DoT-damage marker plus cast and heal prediction, shields, hunter range, resource sounds, action-button damage numbers and tooltip item comparisons. It shows DoT marks, shields and range on nameplates, damage and healing numbers on action buttons, and item comparisons in tooltips. Every part can be switched off.

The name changed in 0.9.90; the addon folder (`UsefulPlatesAndTooltips`), the `/upt` command and your saved settings stay as they were, so updating keeps your configuration. Other addons can read the DoT numbers through the API in [API.md](API.md); Retail specifics are in [RETAIL.md](RETAIL.md).

Current differences. What my addon has:

## DoT marker (DoTInfo)

Shows the damage your DoTs or Bleeds still have to deal as a marker on the target's health bar. If the target's health ends inside the marker, a skull on the portrait says the DoTs will kill it. When you cast spell then it shows during cast time estimation how much it might do on target.

Nameplate marks use the visible health bar, with dedicated support for EllesmereUI and Platynator and a cached automatic search for other nameplate addons. If no visible bar is found, DoTInfo can still show the kill icon beside the nameplate when "Marker and kill icon" is enabled.

The same marker (and kill icon) can sit on your focus frame, Blizzard's or EllesmereUI's, for your DoTs on the focused enemy ("Show on focus frame" in the Nameplates tab); `[@focus]` casts go on the focus. In Forever's instances mob GUIDs are secret: DoTInfo then keeps each mob apart by its nameplate, so tab-dotting a pack works (needs enemy nameplates on). The kill icon can be up to 128 px. "Show on target frame" (Marker tab) takes the marker off the target frame only; nameplates and the focus frame keep theirs. With a pack of same-named mobs, a second one under the mouse makes the cast's target unknown and the estimate stays hidden; "Target beats mouseover" (Behavior tab, and the same option in Cast prediction) lets your target win instead, at the cost of marking the wrong mob if you cast `@mouseover` macros on a pack mate. Plater replaces nameplates, not the screen target unit frame: its nameplate marker is handled separately. If another addon replaces your screen target frame, use DoTInfo > Behavior > Target health bar > Pick and click that addon's health bar; leave the field empty for Blizzard's or EllesmereUI's automatically detected target bar.

Description parsing covers English, German, Spanish, French, Korean, Brazilian Portuguese and Chinese (simplified and traditional), after Does It Die; the non-German languages are from Forever's own tooltips and not yet verified on a client in those languages. Other unit frame addons: name their target, focus or player health bar (and a spot for the kill icon, and a nameplate bar the automatic search misses) under DoTInfo > Behavior, with a Pick button that takes the frame you click (it also finds a bar that the addon moved into an unnamed holder, as EllesmereUI does, when a named frame still keeps it as a field), or by `/upt frame target ElvUF_Target.Health` and `/upt pick target`. ShieldsInfo and HealPrediction use the same frames. A hidden replacement frame hides the marks with it; with nothing set, nothing changes. After Does It Die's custom frames. Threat Plates' health bar is found automatically (it hangs off WorldFrame, not the nameplate). Other addons can read the DoT numbers through the `UsefulPlatesAndTooltips_DoTAPI` global, see [API.md](API.md).

`/dotinfo check` reads every spell in your spellbook and lists the ones whose text mentions seconds but gives no DoT (full texts go to the saved log), so a client in another language can show what is still unread. Parser failures are counted explicitly, with the spell id and original error in the saved log. In Forever, `/dotinfo ticks` (Behavior tab > View) lists the tick sizes learned from your casts next to what the tooltips predict. The check also keeps its findings in the saved settings (`census`, one entry per class, 80 of each at most): the unread texts, cut to 320 bytes, and the DoTs it read with the total and duration their text gave, to set against the learned tick sizes.

Forever can hide `UNIT_COMBAT` damage amounts during combat. Such ticks now match by readable school and the existing timing windows, with duplicate unit-token reports counted once. They confirm a waiting DoT and anchor its schedule without changing learned damage; the estimate keeps the last learned or description value. A same-school foreign hit inside a tick window can still be mistaken for a tick. Size-based rhythm discovery, damage learning and starting traps or crit-triggered procs still require readable amounts. Retail tracking is unchanged. A DoT that has not ticked yet keeps the tick size it was applied with, so another mob's tick no longer moves its marker; Forget, Reset and a corrected learned size still reach it.

![simulation](https://i.imgur.com/rI5Kdyv.gif)

<img width="465" height="407" alt="WowB_Bx6Sgl1bvb-ezgif com-optimize (1)" src="https://github.com/user-attachments/assets/7cf3fe30-5752-4cec-9bb4-2e4ece2af2c9" />

## Textures and colors

DoTInfo (target frame, nameplates, focus), CastPrediction, **ShieldsInfo** and **HealPrediction** share one catalog (`Core/Looks.lua`), so every texture and color below is in all four:

- **89 fill textures**, in groups: *Basic* (flat, fade in from the left), *Blizzard*'s own bar textures, *Soft* shadings that give a bar depth (glass, bevel, cylinder, tube, chrome, rim and center glow, fades), *Bar shapes* (capsule, a bright leading edge, segments of 5, 10 or 20), *Patterns* (stripes both ways, lines, scanlines, crosshatch, grid, checkerboard, dots, diamonds, hexagons, triangles, argyle, plaid, houndstooth, zigzag, chevrons, waves, bricks, sparkles, crosses, rings, carbon fibre, noise, brushed metal), *Organic* (clouds, marble, wood grain, camouflage, leopard spots, cracked earth, glowing veins, bubbles, fish scales, water ripples, sand, zebra), *Material* (leather, woven cloth, basket weave, scratched metal, beveled tiles, rivets, louvers) and *Colorful* (rainbow, fire, lava, blood, sunset, plasma, aurora, ice, ocean, flame, toxic, gold, steel blue: these keep their own colors, the fill color does not tint them, only the opacity applies). The fill color tints all the others. Where another addon brought **LibSharedMedia** (ElvUI, Details, ...), every statusbar texture it knows is in the list too, under "Shared media".
- **Colors**: 33 named colors, and **Custom color...** at the end of every color list opens Blizzard's color picker; the choice is saved as `#rrggbb`. This works for fills, outlines and labels.
- **Drop-down lists** that scroll (mouse wheel), show a swatch or a preview of each texture, and group their entries.
- **DoTInfo look presets** (the "Look presets" button, applied to the target frame and the nameplates): Minimal, Classic, Juicy, Glass, Neon, Blood, Frost, Toxic, Carbon, Ember and Debug.
- **CastPrediction** has a texture for a cast, one for a channel and one (with its own color and opacity) for the finisher preview, so the three never look alike. A missing texture (a shared-media pack that is gone) falls back to flat.

- **ShieldsInfo**: the fill style is a drop-down over the whole catalog (it kept its own shield art as extra entries); the absorb color stays in its Appearance panel, which already has a color picker.
- **HealPrediction**: a texture and a color for each of the three bands (your heal, other healers, heals over time), 33 colors and a custom color instead of six.
- A texture with colors of its own (the Colorful group) is not tinted by the color setting anywhere; only the opacity applies.

The generated patterns are made by `tools/make_fill_textures.py`.

### Every settings window works the same way

All nine modules build their options from one set of rows (`Core/LookRows.lua`): the same label column and control column, the same drop-down (a "v", a color swatch, a texture preview or a picture, scrolling), the same slider (label, slider, value, opacities as a percentage), the same check box (label, then the box), one "Look presets" button where a module has presets, a "Reset this tab" button on every tab, and the same "TRY IT" heading and inline sliders under the live previews that have sliders. The same setting has the same name everywhere: *Fill style*, *Fill color*, *Fill opacity*, *Outline*, *Outline color*, *Outline opacity*, *Text position/size/color*, *Icon horizontal/vertical offset*. If you add a setting, build it with these rows, not with a new widget.

## CastPrediction

<img width="400" height="400" alt="{3045F908-1D52-4E85-8F2D-19C7AF79044C}" src="https://github.com/user-attachments/assets/8d6dc029-3979-47fb-b450-7cf5a0375956" />

Shows the damage of the spell you are casting on the enemy's health bar and nameplate. Direct hits use a solid translucent fill; channels use vertical bands for the damage remaining. Colors follow the spell's school, matching DoTInfo. The Marker tab has separate switches for the target, focus, party, raid and nameplate frames. Copies appear only when a frame represents the cast's recipient; party/raid members are normally friendly, so outgoing damage predictions do not ordinarily appear on those frames.

**Finisher preview** (Prediction tab, on by default; rogues, druids and anyone with a damage finisher on the action bars): while your target has combo points, the same marker shows what your strongest damage finisher on the bars (Eviscerate, Ferocious Bite, a rune's Between the Eyes: whatever SpellDamageInfo can price from the description's per-point rows) would deal at that count, so you can see whether it kills before you press it. It is drawn with its own fill (Flame, top to bottom, at 70% opacity by default. Flame has colors of its own, so the color setting only matters for the other fill styles; a cast is solid, a channel has vertical dashes, DoTs diagonal stripes), growing from the health edge to the left like a cast. Its fill style, color and opacity are on the Marker tab. It reads the same description rows as the numbers on the bar button, so on Forever it leaves out the attack power the text says it adds: the real hit is at least the marked amount, and the kill icon only counts that certain part. A real cast shows its own prediction instead, the preview never learns from hits, and finishers that deal damage over time (Rupture, Rip), that only stun or buff (Kidney Shot, Slice and Dice) and the combo point builders (Sinister Strike, Backstab, Claw, Shred) are not previewed. Not yet checked in the game.

The fill covers health backwards from its current edge: 20 damage at 60/100 HP covers 60 down to 40. It follows health changes and clips overkill inside the bar. Action targeting works without clicking a target, and the prediction stays on the original enemy if the reticle moves. Hidden GUIDs use a nameplate-session key, discarded when the plate disappears; this does not require DoTInfo to be enabled. The cast's reported recipient is matched against target, focus, mouseover and nameplates.

The estimate also holds the talents and effects the description leaves out (Forever): Arcane Instability, Shadow Mastery, Aftermath, Darkness, Searing Light, Moonfury and the rest of the curated list, and, while the client shows the aura, Arcane Power, Power Infusion, Ice Barrier, Improved Scorch, Curse of the Elements, Demonic Sacrifice, Improved Shadow Bolt, Shadow and Flame, Decimation, Incinerate against your Immolate, Power in Light, Shadow Weaving, Shadowform, Stormstrike, Rage of the Farseer and Eureka!. Talent ranks are matched by spell id as well as name, so a client in another language reads them. Auras are hidden in combat on Forever, so they apply out of combat only; the hit calibration carries the rest.

What the hits teach is a running mean of what each hit says the factor should have been, pulled toward 1 by two hits' worth in what a cast shows, with a memory of about nine hits. (Versions up to 0.9.83 blended each hit's ratio to the already scaled prediction into the factor and so settled on the square root of the truth, 0.89 where 0.80 was right; factors saved by them are squared once on the first load.) On Retail only direct physical hits are learned from: the description holds the player's own numbers but not the target's armor, which took 30% off a hunter's Steady Shot in a saved log. A cast whose hit matched nothing the estimate expects, while damage of its school landed within reach of it, is tallied, and `/upt castpred learned` lists the learned factors with their hits and that tally, so a spell whose factor is too far from 1 to be learned shows. `/upt castpred census` reads the whole talent tree into the saved settings (`census`): each talent's live text (cut to 90 bytes, 240 for the talents the lists use or that it flags), marking the talents with a percent next to damage or healing that the lists do not use; `/upt castpred census clear` removes it. Nothing is read or kept until you ask.

Penance's damage channel uses the three bolts stated in its description: the immediate bolt is already spent, then the remaining two bolts disappear at their scheduled times. Channel timing changes update the schedule. Scripted volleys without linked coefficient data use description amounts, not an invented spell-power share.

Only the first matched impact can calibrate a cast; later damage cannot add samples or restart its fade. This is still a heuristic: `UNIT_COMBAT` does not identify the attacker or spell. Cached estimates are refreshed after spell, talent, equipment, player-aura and manual spell-power changes, retaining the last readable description when the client hides it.

The direct hit is separate from DoTInfo's damage-over-time marker. For rank-1 Fireball, the unmodified average is 18 damage on impact plus 2 over time. Critical strikes, procs and resists can change the result. `/upt cast` opens the settings and preview.

## Heal prediction and shields on nameplates

<img width="477" height="282" alt="{655C0DAD-5C68-4D0B-9374-CD94B9CD9476}" src="https://github.com/user-attachments/assets/70f1d92e-80d6-4d9f-b3ca-42899f926e27" />

<img width="236" height="108" alt="{182459A7-7224-45BB-BB6B-D8D1FA35FDD0}" src="https://github.com/user-attachments/assets/e6f429a0-ca1c-4813-9b66-29f6ef7b489b" />

### ShieldsInfo

Shows remaining absorbs on the player, target, focus, party, raid and nameplate health bars. The Frames tab provides an independent checkbox for each category; party and raid are separate switches. The overlay uses the selected fill and opacity with the shared absorb color.

### HealPrediction

Incoming healing on player, target, focus, Blizzard's target-of-target, party and raid frames, drawn from the current health edge. Each frame category is enabled by default and has its own switch. Focus and target-of-target also show your own HoTs when they point to you. Direct healing uses the client's `UnitGetIncomingHeals` reading. The other healers' share is a second band behind yours (the client's total is drawn first and your own heal over it); "All healers" draws the total in your color instead. Heals over time that you cast (Rejuvenation, Renew, Regrowth's tick part) are not part of the client's reading, so the amount their description promises is drawn after your direct heal for the next few seconds of the effect, as an estimate that runs out with the effect's time. Without a direct heal, the HoT starts at the health edge rather than an empty direct-heal texture. Readable own buffs recover already-active effects and their actual expiry/removal; when aura data is hidden, the last known effect or cast estimate is retained. HoT recipients use readable GUIDs, with realm-qualified player names as the fallback: ambiguous bare names or unreadable identities are not assigned to a same-named player. An unambiguous player-name match includes self even when the client does not report self-assistance. Without a recipient name, the existing friendly-target/self assumption remains. Failed, interrupted or more than 15-second-old pending casts are discarded. "Show a number" includes the direct heal and visible HoT horizon. `/upt heals` opens the settings.

Own HoT estimates work even when SpellDamageInfo is disabled or its action-button spell-power estimate is off. Recasting another rank of the same named HoT replaces the old estimate; different HoTs still add together. Wild Growth uses a linear approximation of its front-loaded healing: readable own buffs identify recipients, otherwise only the known primary cast target is estimated. Lightwell clicks, Tranquility/Mend Pet channels and conditional heals do not create persistent target HoTs.

HealPrediction retains readable healing power on login, equipment/player-aura changes and leaving combat, independently of SpellDamageInfo's event loop. If healing power has never been readable in this session, the estimate can only use the description's base amount.

Forever's space-separated cast recipient is matched against the exact two `UnitName` results, without discarding hyphens or guessing a surname. Temporary `/upt healdebug [player|target|focus|targettarget]` diagnostics show aura access, recipient identity at the last cast and now, the estimated HoT amount and overlay state. Hidden values are printed as `SECRET`, not copied into chat. When aura access is blocked, a HoT cast before `/reload` cannot be recovered; cast it again before collecting the diagnostic output.

## Spell, item and heal numbers on action bars (SpellDamageInfo)

![image](https://media.forgecdn.net/attachments/description/1724766/description_757732fe-af02-49e8-9c9e-5faed9f66325.png)

Damage and healing numbers on your action buttons and in spell tooltips.

Holy Shock, Penance and Holy Nova show both their damage and healing amounts, in separate colors (not a claim that both hit the selected target). Binding Heal's amount and spell-power share are per recipient rather than the sum of both healing effects. Dark Sacrifice shows its total health cost and mana gain; its tooltip retains the health-cost duration.

Forever's native gamepad crossbar also gets the numbers, including after changing pages. Total mode includes the direct hit and DoT; Direct mode shows only the hit.

On Forever the numbers include your talents: 38 talents that add a percent to a school or to named spells (Moonfury, Shadow Mastery, Aftermath, Improved Renew, Spiritual Healing, Concussion and more) are read from the talent tree, with the value of every rank taken from the client's data (`tools/make_talent_mods.py`). Forever's descriptions leave talents out; Retail's already hold them, so there nothing is added. Switch it off with "Include talents" in the SpellDamageInfo settings; `/upt castpred talents` lists what is read.

Bars built on LibActionButton (Bartender4, ElvUI and others) get the numbers too, for spells, macros and items on their buttons; this is new and not yet checked in the game with those addons.

![damage prediction](https://i.imgur.com/ySumj4S.png) ![healing prediction](https://i.imgur.com/xvGpoTg.png)

### Spell coverage audit

This pass compared 3052 English/German client descriptions across all nine Forever classes, using the [SpellDamageInfo client snapshot](https://github.com/Ironship/SpellDamageInfo/blob/main/tests/fixtures/forever_client_texts.json) and the [spellbook list](https://github.com/Ironship/SpellDamageInfo/blob/main/tests/fixtures/forever_spellbook_all.json). Current mechanics were checked against [ForeverDB](https://foreverdb.net/spells), build 1.60.1.70707. These are parser and estimate checks, not in-game confirmation; Forever's custom spells are not treated as TBC or Retail versions.

| Class | Representative readings checked | Prediction boundary |
| --- | --- | --- |
| Priest | Renew, Lesser/Flash/Greater Heal, Prayer of Healing, Binding Heal, Penance, Holy Nova, Dark Sacrifice | Renew is tracked; direct/group/channel heals remain the client's projection. Lightwell and Contingency Plan need an actual trigger, not just their cast. |
| Druid | Rejuvenation, Regrowth, Healing Touch, Wild Growth, Tranquility, Moonfire, Wrath | Own readable HoT buffs are tracked; hidden Wild Growth recipients and Tranquility's party/channel are not guessed. |
| Shaman | Riptide, Healing Wave, Lesser Healing Wave, Chain Heal, Healing Stream Totem, Lightning Bolt | Riptide's HoT is tracked; Chain Heal bounces and totem pulses are not target HoTs. |
| Paladin | Holy Light, Flash of Light, Holy Shock, Lay on Hands, Seal of Light | Native direct healing; reactive seal/Vigil effects are not treated as heals at cast time. |
| Hunter | Mend Pet, Serpent Sting, Arcane Shot, Multi-Shot, Aimed Shot | Mend Pet is a pet channel, not a HoT on the selected friendly. |
| Mage | Fireball, Frostbolt, Frostfire Bolt, Arcane Missiles, Blizzard | Damage readings; ground/area channels do not establish a selected recipient. |
| Warlock | Shadow Bolt, Immolate, Corruption, Drain Life, Siphon Life, Health Funnel, Life Tap | Drains and pet health transfers are not friendly-target HoTs. |
| Rogue | Eviscerate, Rupture, Garrote, Sinister Strike, poisons | Weapon/combo readings remain separate; no generic friendly-target HoTs. |
| Warrior | Heroic Strike, Execute, Rend, Shield Slam, Bloodthirst | Weapon/rage readings remain separate; no generic friendly-target HoTs. |

HoT dispels, Lifebloom-style stacking/blooms, talent-modified healing, exact Wild Growth tick weights and hidden group recipients remain unverified or deliberately unsupported. A parsed tooltip number alone is not proof of correct live prediction.

## Easier stats comparison (StatsInfo)

In an item's tooltip: how it compares with what you wear, what each difference is worth to your character, and how each spec of your class rates the item. Ratings use ForeverSim weights. Tanks also get survival and threat.

Spirit is worth mana per 5 seconds (read from the client, so it is right for any class) and, as the character sheet's Spirit tooltip works it out, health per 5 seconds out of combat, standing: a warrior or rogue, who has no mana, sees the health. The health figure takes the regeneration to be proportional to Spirit, as the mana one is; that is not measured.

Every healer (Restoration druid or shaman, Holy priest or paladin) gets a score marked `(approx.)`. It is a heuristic, because ForeverSim does not simulate healing. **Work in progress.**

Tooltips are one line. Hold Shift to see the full version. Upgrade arrows also appear on bag, loot, need/greed and merchant buttons.

![stats comparison](https://i.imgur.com/wXVwDG6.png) ![another look on item](https://i.imgur.com/RIdkm9d.png)

## Resource tracker for Rogue/Druid and Warlock (ResourceDing)

A sound when your combo points (or another finisher resource) are full, and dots under or above the target that show the points.

Casters get a sound when mana climbs to a set level: 100% by default, 80% for warlocks. Warlocks also get a sound for each Soul Shard that enters the bags, and purple diamonds under the target's nameplate show how many shards you carry.

![warlock shards](https://i.imgur.com/tVzNFEL.png)

<img width="770" height="644" alt="{A2976187-8F39-4399-8EDD-20452A06DA38}" src="https://github.com/user-attachments/assets/e5005294-7f55-4156-bb6b-13d998ea834f" />

## Hunter range indicator

For hunters only. A range rail sits above the target's nameplate, or at a spot you place on screen: six dots, and a seventh past 35 yd when Hawk Eye is detected or switched on. A sword marks melee range, and a skull marks the dead zone. Range labels show just the band (e.g. `25-30 yd`), centred below the dots or bar; melee/dead-zone text and its optional icon are centred together on the same anchor, in both the HUD and preview. The bands are approximate, not exact yard measurements.

Hunter and ResourceDing dots share the same shaded orb, dark socket and bezel. Appearance samples use each module's renderer; changes also update the open preview. ResourceDing has an Appearance tab for its palette and opacity.

![range indicator](https://i.imgur.com/AGTwBqF.gif)

![range in game](https://i.imgur.com/gON8KAq.gif)

## Estimation for crit based procs (Deep Wounds, Ignite)

Rip and Rupture use your combo points. Immolation Trap is tracked: placing it only arms it, and the DoT starts on the mob that takes its first tick. Ignite (mages) and Deep Wounds (warriors) are lit by critical hits, which no cast announces: a crit counts as yours when you cast at that mob just before (for Deep Wounds also when you swing at it alone), and the talent is assumed unless the talent tree shows no points. Ignite shows 8% a point of the fire crit over 4 s (rolling what the running one still owed into the new one), Deep Wounds 20% a point of your main hand's average damage over 12 s. The first tick confirms the guess. Forever only; switch them off in DoTInfo > Behavior.

**Current release: Forever 0.9.112 / Retail 0.9.121.** Cumulative changes since 0.9.110 include finisher previews (Eviscerate, Ferocious Bite and rune finishers), killing-spell icons independent of the damage-marker toggle, arrows on every quest reward upgrade with a double arrow on the best, and the Forever self-cast HoT recipient fix. HealPrediction now also covers focus and Blizzard's target-of-target frames. The release includes the shared catalog of 89 fill textures and 33 colors plus custom colors, consistent settings controls and presets, health-bar shape-mask fixes, DoT/proc tracking improvements, Enhance QoL frame support and Forever build 70790 data from 0.9.111.

These are full installable packages, not patches. When upgrading from 0.9.110, back up your saved variables and replace the addon folder while the game is closed; restart the game to load the new files. The killing-spell icon option is enabled once on upgrade; you can switch it off again. Other saved choices are retained, including a previously disabled player healing frame. Rejuvenation on the player frame was confirmed in Forever combat; focus/target-of-target visuals, complete healing-spell coverage and Retail gameplay have not been verified for this release.

**DoT timing caveats:** when the client hides tick sizes, Immolation Trap and Wyvern Sting are inferred from the rhythm of same-school hits; unrelated damage with matching timing can be mistaken for a tick. Paladins who know the Righteous Judgement rune get a Holy DoT after a critical Judgement or Crusader Strike (40% of the hit, as the rune's text says). With Enhance QoL's unit frames the marks follow its player, target and focus frames.

## Confirmed support for EllesmereUI, Platynator, Threat Plates, ElvUI etc.

## Gamepad support and tests (I play gamepad mainly)

Settings support native gamepads and ConsolePort. Assign Open settings under Options → Key Bindings → AddOns → DoesItDiePlus. LB/RB switches module tabs, the D-pad selects controls, A / Cross activates the selected control, left/right adjusts sliders and B / Circle closes the window. The gold outline shows focus and scrolls into view. With ConsolePort active, its interface cursor and configured hints handle navigation.

On clients with the modern Settings API, the DoesItDiePlus, DoTInfo and SpellDamageInfo launchers use native settings-list buttons. Select the add-on, move right with the D-pad and confirm to open its window. Older clients retain the canvas page.

## Building

Build the Forever ZIP with `python tools/build_zip.py`, or the Retail ZIP with `python tools/build_zip.py --retail`. Packages are written to `dist/` and checked against the source files.

Modules are maintained directly in `Modules/`. The remaining tools regenerate stat weights (`make_weights.py`, using `tools/data/`) and textures (`make_resource_textures.py`, `make_ui_textures.py`).

## Licence

GPL-3.0-or-later, see [LICENSE](LICENSE).

Third-party parts keep their own MIT notices:

*   **DoTInfo** is based on [Does It Die](https://www.curseforge.com/wow/addons/does-it-die) by Joe Greive, with my own updates, fixes and changes (I port some of those into Does It Die as I want it to be as complete as possible); see `Modules/DoTInfo/LICENSE-DoesItDie.txt`.
*   **ShieldsInfo** is adapted from [Shield Aura Forever](https://github.com/JasonEcks/ShieldAuraForever) by JasonEcks and contributors; see `Modules/ShieldsInfo/LICENSE-ShieldAuraForever.txt`.
*   **SpellDamageInfo's options window** is adapted from Does It Die by Joe Greive; see `Modules/SpellDamageInfo/LICENSE-SpellDamageInfo.txt`.
*   **Stat weights** come from [ForeverSim](https://github.com/laurencestokes/foreversim) (MIT), built on [WoWSims](https://github.com/wowsims/forever) and Elliot Wood's Forever sim; see `Modules/StatsInfo/LICENSE-ForeverSim.txt`.
