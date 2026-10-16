# Useful Plates and Tooltips

It shows DoT marks, shields and range on nameplates, damage and healing numbers on action buttons, and item comparisons in tooltips. Every part can be switched off.

### DoTInfo

Shows the damage your DoTs or Bleeds still have to deal as a marker on the target's health bar. If the target's health ends inside the marker, a skull on the portrait says the DoTs will kill it. When you cast spell then it shows during cast time estimation how much it might do on target.

![simulation](https://i.imgur.com/rI5Kdyv.gif) ![damage](https://i.imgur.com/QfaSkDy.png)

Rip and Rupture use your combo points. Procs from critical hits, such as Ignite and Deep Wounds, are not tracked yet.

### SpellDamageInfo

![image](https://media.forgecdn.net/attachments/description/1724766/description_757732fe-af02-49e8-9c9e-5faed9f66325.png)

Damage and healing numbers on your action buttons and in spell tooltips.

Bars built on LibActionButton (Bartender4, ElvUI and others) get no numbers. Blizzard's action bars do.

![damage prediction](https://i.imgur.com/ySumj4S.png) ![healing prediction](https://i.imgur.com/xvGpoTg.png)

### StatsInfo

In an item's tooltip: how it compares with what you wear, what each difference is worth to your character, and how each spec of your class rates the item. Ratings use ForeverSim weights. Tanks also get survival and threat.

Every healer (Restoration druid or shaman, Holy priest or paladin) gets a score marked `(approx.)`. It is a heuristic, because ForeverSim does not simulate healing. **Work in progress.**

Tooltips are one line. Hold Shift to see the full version. Upgrade arrows also appear on bag, loot, need/greed and merchant buttons.

![stats comparison](https://i.imgur.com/wXVwDG6.png) ![another look on item](https://i.imgur.com/RIdkm9d.png)

### ResourceDing

A sound when your combo points (or another finisher resource) are full, and dots under or above the target that show the points.

Casters get a sound when mana climbs to a set level: 100% by default, 80% for warlocks. Warlocks also get a sound for each Soul Shard that enters the bags, and purple diamonds under the target's nameplate show how many shards you carry.

![warlock shards](https://i.imgur.com/tVzNFEL.png) ![rogue combo points](https://i.imgur.com/1ITWdUb.png)

### Range

A green checkmark over your target while your measuring spell reaches it, and a red X while none does. Action buttons go grey when the target is out of range (on by default).

### ShieldsInfo

Remaining absorb shields, drawn on your health bar, your target's, party frames and nameplates.

![shields info](https://i.imgur.com/iqUSKt4.png) ![shield in party](https://i.imgur.com/NkpFqdh_d.png?maxwidth=520&shape=thumb&fidelity=high)

### HunterRangeFinder

For hunters only. A range rail sits above the target's nameplate, or at a spot you place on screen: six dots, and a seventh past 35 yd when Hawk Eye is detected or switched on. A sword marks melee range, and a skull marks the dead zone. The bands are approximate, not exact yard measurements.

![range indicator](https://i.imgur.com/L7bopvP.png) ![dead zone](https://i.imgur.com/Ur0rxKh.png) ![melee range](https://i.imgur.com/4CfMLky.png)

## Confirmed support for

*   Platynator
*   EllesmereUI

## Credits and licence

GPL-3.0-or-later, see [LICENSE](LICENSE). Third-party parts keep their own notices:

*   **DoTInfo** is based on [Does It Die](https://www.curseforge.com/wow/addons/does-it-die) by Joe Greive (MIT), through Ironship's German fork.
*   **SpellDamageInfo** and **ResourceDing** come from the standalone addons of the same names made by me.
*   **StatsInfo** is written after the idea of RatingBuster (Whitetooth, GPL), with none of its code or tables. Stat weights come from [ForeverSim](https://github.com/laurencestokes/foreversim), built on WoWSims and Elliot Wood's Forever sim.
*   **ShieldsInfo** bundles the MIT notice of Shield Aura Forever (`Modules/ShieldsInfo/LICENSE-ShieldAuraForever.txt`).
