# Useful Plates and Tooltips

It shows DoT marks, shields and range on nameplates, damage and healing numbers on action buttons, and item comparisons in tooltips. Every part can be switched off.

Build the Forever ZIP with `python tools/build_zip.py`, or the Retail ZIP with `python tools/build_zip.py --retail`. Packages are written to `dist/` and checked against the source files.

Modules are maintained directly in `Modules/`. The remaining tools regenerate stat weights (`make_weights.py`, using `tools/data/`) and textures (`make_resource_textures.py`, `make_ui_textures.py`).

### DoTInfo

Shows the damage your DoTs or Bleeds still have to deal as a marker on the target's health bar. If the target's health ends inside the marker, a skull on the portrait says the DoTs will kill it. When you cast spell then it shows during cast time estimation how much it might do on target.

![simulation](https://i.imgur.com/rI5Kdyv.gif)

<img width="465" height="407" alt="WowB_Bx6Sgl1bvb-ezgif com-optimize (1)" src="https://github.com/user-attachments/assets/7cf3fe30-5752-4cec-9bb4-2e4ece2af2c9" />

# There are also shields and healing predictions...
<img width="477" height="282" alt="{655C0DAD-5C68-4D0B-9374-CD94B9CD9476}" src="https://github.com/user-attachments/assets/70f1d92e-80d6-4d9f-b3ca-42899f926e27" />


<img width="236" height="108" alt="{182459A7-7224-45BB-BB6B-D8D1FA35FDD0}" src="https://github.com/user-attachments/assets/e6f429a0-ca1c-4813-9b66-29f6ef7b489b" />


Rip and Rupture use your combo points. Procs from critical hits, such as Ignite and Deep Wounds, are not tracked as they are based on RNG i still think how this can be improved.

### WIP
Channeling and casting prediction for normal spells.

<img width="1064" height="1009" alt="{3045F908-1D52-4E85-8F2D-19C7AF79044C}" src="https://github.com/user-attachments/assets/8d6dc029-3979-47fb-b450-7cf5a0375956" />

### CastPrediction

Shows the damage of the spell you are casting on the enemy's health bar and nameplate. Direct hits use a solid translucent fill; channels use vertical bands for the damage remaining. Colors follow the spell's school, matching DoTInfo.

The fill covers health backwards from its current edge: 20 damage at 60/100 HP covers 60 down to 40. It follows health changes and clips overkill inside the bar. Action targeting works without clicking a target, and the prediction stays on the original enemy if the reticle moves.

The direct hit is separate from DoTInfo's damage-over-time marker. For rank-1 Fireball, the unmodified average is 18 damage on impact plus 2 over time. Critical strikes, procs and resists can change the result. `/upt cast` opens the settings and preview.

### HealPrediction

Incoming healing on target, party and raid frames, drawn from the current health edge. It uses the client's `UnitGetIncomingHeals` reading. The "All healers" option shows the client's total instead of only your heals. `/upt heals` opens the settings.

### HunterRange

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

Bars built on LibActionButton (Bartender4, ElvUI and others) get no numbers. Blizzard's action bars do.

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
