# DoesItDiePlus

DoesItDiePlus, formerly Useful Plates and Tooltips, is my take on [Does It Die](https://www.curseforge.com/wow/addons/does-it-die) that has grown well beyond the original addon. I still contribute changes back to Does It Die where possible. Here I build and test features for WoW Forever as well as Retail and Classic.

What it adds:

## Compared with Does It Die

Based on the [Does It Die source at `a771a3d`](https://github.com/swirllyman/DoesItDie/tree/a771a3de41e3881eee7e86fd0bcf207d116fbb1f), checked on November 8, 2026, these capabilities are implemented here but not in that upstream version:

| Added capability | What the code does |
| --- | --- |
| [Direct-spell and channel prediction](Modules/CastPrediction/Core.lua) | Predicts damage from spells such as Frostbolt and Shadow Bolt during casting and projectile travel, plus remaining channel damage. Upstream's casting estimate covers only the periodic part of DoT spells. |
| [Healing prediction](Modules/HealPrediction/Core.lua) and [HoTs](Modules/HealPrediction/Hots.lua) | Draws client-reported incoming healing on unit frames, with an optional all-healers view and separate estimates for your own targeted HoTs. |
| [Shield overlays](Modules/ShieldsInfo/ShieldsInfo.lua) | Draws client-reported remaining absorbs on unit frames and accessible nameplates. |
| [Action-bar and tooltip estimates](Modules/SpellDamageInfo/Core.lua) | Adds spell and item damage, healing, absorb and mana numbers, including supported macro and pet-action slots. |
| [Equipment comparison](Modules/StatsInfo/StatsInfo.lua) | Adds stat changes against equipped items and specialization-based item scores, using ForeverSim weights and an approximate healer model. |
| [Resource tracking](Modules/ResourceDing/Core.lua) and [Soul Shards](Modules/ResourceDing/Shards.lua) | Shows resource markers and configurable sounds for a full resource bar or shard gains; counts bag-item shards on Classic/Forever and power-based shards on Retail. |
| [Hunter range HUD](Modules/HunterRangeFinder/HunterRangeFinder.lua) | Uses spell/item range checks for approximate distance bands, melee range and the dead zone, not exact yard measurements. |
| [Crit-triggered DoT estimates](Modules/DoTInfo/ProcDots.lua) | Estimates Ignite and Deep Wounds from readable hits on Forever, with heuristic ownership attribution. |
| [Gamepad navigation](Core/Gamepad.lua) | Adds directional navigation, activation and tab switching to the settings UI. |

DoT damage markers, kill icons, focus/nameplate displays, custom-frame attachment and a public DoT API already exist upstream; they are not unique additions here. Availability still depends on the client's APIs and readable combat data.

## CastPrediction of normal spells

I wanted to have fun on a mage or a Destruction warlock too.

![cast prediction](https://github.com/user-attachments/assets/8d6dc029-3979-47fb-b450-7cf5a0375956)

## Heal prediction and shields on nameplates

![heal prediction and shields](https://media.forgecdn.net/attachments/description/1724766/description_602c1ac4-5e97-4734-b606-4502f2d52572.png)

## Spell, item and heal numbers on action bars

![action bar numbers](https://media.forgecdn.net/attachments/description/1724766/description_757732fe-af02-49e8-9c9e-5faed9f66325.png)

![damage prediction](https://i.imgur.com/ySumj4S.png) ![healing prediction](https://i.imgur.com/xvGpoTg.png)

## Easier stats comparison

![stats comparison](https://i.imgur.com/wXVwDG6.png) ![another look on item](https://i.imgur.com/RIdkm9d.png)

## Resource tracker for Rogue/Druid and Warlock

![warlock shards](https://i.imgur.com/tVzNFEL.png)

![resource tracker settings](https://github.com/user-attachments/assets/e5005294-7f55-4156-bb6b-13d998ea834f)

## Hunter range indicator

![range indicator](https://i.imgur.com/AGTwBqF.gif)

![range in game](https://i.imgur.com/gON8KAq.gif)

## And more

- Confirmed support for EllesmereUI, Platynator, Threat Plates, ElvUI and others.
- Gamepad support, tested on a gamepad (I mainly play with one).
- Estimates for crit-based procs (Deep Wounds, Ignite).
- A [public API](API.md) for other addons to read DoT and pending-cast damage estimates.
- Automatic target/focus health-bar selection for BetterBlizzFrames (not yet verified in game).

English DoT descriptions correctly read thousands separators, such as `1,168` damage; localized parsing keeps
the original text.

## Languages

The settings window, tooltips and chat lines support English, German and Russian. Automatic selection follows the supported `textLocale` CVar, then the game locale; other languages show English. `/upt lang` shows the language in use; `/upt lang auto`, `/upt lang en`, `/upt lang deDE` or `/upt lang ruRU` changes it after `/reload`. Short aliases `de` and `ru` work too. `/upt lang missing` lists missing translations. SpellDamageInfo has its own switch, `/sdi lang auto|en|de|ru` (also `ruRU`), and a Russian choice in its settings.

Some Forever clients report English even with German or Russian spell text. Automatic selection uses `textLocale` when available; otherwise select `/upt lang ruRU` and `/sdi lang ru` explicitly for the interface. The SDI parser detects Russian descriptions and keeps reading Forever's mixed English descriptions. Developer diagnostics remain English.

Spell descriptions are read in English, German and Russian. The Russian SDI pack is based on an actual WoW: Forever `/sdi dump all`: damage ranges, DoTs/channels, healing/HoTs, shields, health transfers, reductions, weapon attacks, finishers and seals. Its UTF-8 case folding and duration units do not depend on the host's C locale. DoTInfo reuses that reader and registers the dump's Russian spell names, including Forever's renamed spells.

Descriptions with missing numbers/durations, per-tick damage ranges, or damage derived from another effect still stay unread rather than guessed. SDI dumps and misses distinguish `utility` from `unread-damage`/`unread-effect` and include the parser reason. A seal with no per-hit effect is intentionally blank; its Judgement belongs on Judgement's button. Russian consumable item wordings and Retail-specific descriptions are not comprehensively verified by this Forever spell dump.

Run `lua tools\check_ru_locale.lua` for the small runnable regression check. Pass a local SavedVariables path as the optional argument to check the actual `dumpAll.spells` records and print coverage by category. The check reads only; it never executes or writes SavedVariables, and only the necessary spell samples are kept in the repository.

For another language, `/sdi dump all` from a client in that language supplies the wordings (saved on `/reload`). Korean and Chinese still need their own parser packs and case handling where applicable.

DoTInfo also retains partial fallback readers for Spanish, French, Korean, Brazilian Portuguese and Chinese. These do not provide full spell-parser or interface support.

A language is a few files, each listed in both `.toc` files:

- `Locales/<code>/*.lua`: interface texts; the English text is the key, so English has no file (see `Core/Locale.lua`).
- `Modules/SpellDamageInfo/Parser_<code>.lua`: the wordings of the spell damage parser (see LANGUAGE PACKS in `Parser.lua`).
- `Modules/DoTInfo/Locale_<code>.lua`: the DoT description reader (see `Locale.lua` there).

## Licence

GPL-3.0-or-later, see [LICENSE](LICENSE). The resource tracker and the range indicator come from my own earlier addons.

Third-party parts keep their own MIT notices:

*   **DoTInfo** is based on [Does It Die](https://www.curseforge.com/wow/addons/does-it-die) by Joe Greive, with my own updates, fixes and changes (I port some of them back to Does It Die to contribute to the main project); see `Modules/DoTInfo/LICENSE-DoesItDie.txt`.
*   **ShieldsInfo** is adapted from [Shield Aura Forever](https://github.com/JasonEcks/ShieldAuraForever) by JasonEcks and contributors; see `Modules/ShieldsInfo/LICENSE-ShieldAuraForever.txt`.
*   **SpellDamageInfo's options window** is adapted from Does It Die by Joe Greive; see `Modules/SpellDamageInfo/LICENSE-SpellDamageInfo.txt`.
*   **Stat weights** come from [ForeverSim](https://github.com/laurencestokes/foreversim) (MIT), built on [WoWSims](https://github.com/wowsims/forever) and Elliot Wood's Forever sim; see `Modules/StatsInfo/LICENSE-ForeverSim.txt`.
