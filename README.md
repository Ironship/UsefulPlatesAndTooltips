# DoesItDiePlus

DoesItDiePlus, formerly Useful Plates and Tooltips, is my take on [Does It Die](https://www.curseforge.com/wow/addons/does-it-die) that has grown well beyond the original addon. I still contribute changes back to Does It Die where possible. Here I build and test features for WoW Forever as well as Retail and Classic.

What it adds:

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

The settings window, tooltips and chat lines follow the game language. German is translated; every other language shows English. `/upt lang` shows the language in use, `/upt lang auto`, `/upt lang en` or `/upt lang deDE` changes it (after `/reload`) and `/upt lang missing` lists the texts a language still lacks. The spell damage window has its own switch, `/sdi lang`.

Some Forever clients report English even with German spell text; select `/upt lang deDE` explicitly in that case. Developer diagnostics and sample spell names remain English.

Spell descriptions are read in English and German. For another language I need `/sdi dump all` from a client in that language (it is written to the saved variables on `/reload`). Russian, Korean and Chinese also need changes to the parser first, because its text handling assumes Latin letters.

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
