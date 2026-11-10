-- UsefulPlatesAndTooltips: the German texts of the StatsInfo tab. The conventions are in Locales\deDE\Core.lua.
-- Copyright (c) 2026 Ironship. GPL-3.0-or-later, see LICENSE.

local _, BIT = ...

BIT.RegisterLocale("deDE", {
  -- the live preview and its TRY IT block
  ["Live preview (sample item, not your gear)"] = "Live-Vorschau (Beispielgegenstand, nicht Eure Ausrüstung)",
  ["StatsInfo sample (not your gear)"] = "StatsInfo-Beispiel (nicht Eure Ausrüstung)",
  ["Preview: sample item"] = "Vorschau: Beispielgegenstand",
  ["Quest rewards (sample)"] = "Questbelohnungen (Beispiel)",
  ["Static sample: bag and quest arrows follow their settings; live upgrades are rated against your gear."] =
    "Statisches Beispiel: Taschen- und Questpfeile folgen ihren Einstellungen; echte Upgrades werden an Eurer Ausrüstung gemessen.",
  ["The size the preview's text is drawn in. The same field the shared appearance editor changes."] =
    "Die Größe, in der der Text der Vorschau gezeichnet wird. Dasselbe Feld, das der gemeinsame Editor für das Aussehen ändert.",
  ["Scales the preview's card, rows, icons and bag button. The same field the shared appearance editor changes."] =
    "Skaliert die Karte, die Zeilen, die Symbole und die Taschenschaltfläche der Vorschau. Dasselbe Feld, das der gemeinsame Editor für das Aussehen ändert.",
  ["How see-through the preview's lines and bag button are. The same field the shared appearance editor changes."] =
    "Wie durchsichtig die Zeilen und die Taschenschaltfläche der Vorschau sind. Dasselbe Feld, das der gemeinsame Editor für das Aussehen ändert.",

  -- the sample item: the game's own words for what a real item tooltip shows
  ["Embossed Leather Vest (sample)"] = "Geprägte Lederweste (Beispiel)",
  ["Item Level 28"] = "Gegenstandsstufe 28",
  ["120 Armor"] = "120 Rüstung",
  ["+3 Stamina"] = "+3 Ausdauer",
  ["+3 Intellect"] = "+3 Intelligenz",

  -- the tabs
  ["Arrows"] =
    "Pfeile",
  ["Help"] =
    "Hilfe",
  ["IN THE ITEM'S TOOLTIP"] =
    "IM TOOLTIP DES GEGENSTANDS",
  ["HOW MUCH OF IT"] =
    "WIE VIEL DAVON",
  ["WHERE THE ARROWS SHOW"] =
    "WO DIE PFEILE ERSCHEINEN",
  ["WHERE ON THE ITEM"] =
    "WO AUF DEM GEGENSTAND",
  ["Corner"] =
    "Ecke",
  ["Top right"] =
    "Oben rechts",
  ["Top left"] =
    "Oben links",
  ["Bottom right"] =
    "Unten rechts",
  ["Bottom left"] =
    "Unten links",
  ["The corner of the item the arrow and the spec icon sit in, for when another addon's mark (a junk coin, an item level) already uses one. Baganator places its corner marks itself: pick the same corner in its Icon Corners settings. Quest reward arrows keep their own place."] =
    "Die Ecke des Gegenstands, in der Pfeil und Spezialisierungssymbol sitzen, falls die Markierung eines anderen Addons (eine Plundermünze, eine Gegenstandsstufe) dort schon liegt. Baganator platziert seine Eckmarkierungen selbst: wählt dieselbe Ecke in dessen Einstellungen „Icon Corners“. Pfeile bei Questbelohnungen behalten ihren Platz.",
  ["Horizontal nudge"] =
    "Horizontal verschieben",
  ["Vertical nudge"] =
    "Vertikal verschieben",
  ["Pixels right (+) or left (-) of the corner."] =
    "Pixel rechts (+) oder links (-) von der Ecke.",
  ["Pixels up (+) or down (-) from the corner."] =
    "Pixel über (+) oder unter (-) der Ecke.",
  ["Arrow size"] =
    "Pfeilgröße",
  ["The size of the arrow, the spec icon and the +N cue."] =
    "Die Größe von Pfeil, Spezialisierungssymbol und +N-Hinweis.",
  ["Use the game's own upgrade arrow in Blizzard's bags"] =
    "Den spieleigenen Upgrade-Pfeil in Blizzards Taschen verwenden",
  ["Blizzard's bag buttons have an upgrade arrow of their own, in a place the game chose. Checked: an upgrade lights that one. Unchecked: this addon's arrow is drawn instead, in the corner chosen above. Other bag addons always get this addon's arrow."] =
    "Blizzards Taschenplätze haben einen eigenen Upgrade-Pfeil an einer vom Spiel gewählten Stelle. Mit Haken: Ein Upgrade lässt diesen aufleuchten. Ohne Haken: Stattdessen wird der Pfeil dieses Addons in der oben gewählten Ecke gezeichnet. Andere Taschen-Addons bekommen immer den Pfeil dieses Addons.",
  ["WHAT THE ICONS STAND FOR"] =
    "WOFÜR DIE SYMBOLE STEHEN",
  ["HOW EACH SPEC RATES THE ITEM"] =
    "WIE JEDE SPEZIALISIERUNG BEWERTET",
  ["ARROWS ON BAG ITEMS"] =
    "PFEILE BEI GEGENSTÄNDEN IN TASCHEN",
  ["DIAGNOSTICS"] =
    "DIAGNOSE",
  ["Static sample. The coin stands for another addon's junk mark; the arrows follow the Arrows tab. Live upgrades are rated against your gear."] =
    "Statisches Beispiel. Die Münze steht für die Plundermarkierung eines anderen Addons; die Pfeile folgen dem Reiter Pfeile. Echte Upgrades werden an Eurer Ausrüstung gemessen.",
  ["Legend"] = "Legende",
  ["Ratings"] = "Bewertungen",
  ["Bag arrows"] = "Taschenpfeile",

  -- the Display tab
  ["Show what the item changes against the equipped one"] =
    "Zeigen, was der Gegenstand gegenüber dem getragenen ändert",
  ["The differences against the item you wear in that slot, in the item's tooltip."] =
    "Die Unterschiede zu dem Gegenstand, den Ihr an diesem Platz tragt, im Tooltip des Gegenstands.",
  ["Under each stat, what it gives you"] = "Unter jedem Wert, was er Euch bringt",
  ["Health, mana, armor, attack power, crit, hit and the rest, under each difference. The Help tab has the icons."] =
    "Gesundheit, Mana, Rüstung, Angriffskraft, kritische Treffer, Treffer und das Übrige, unter jedem Unterschied. Der Reiter Hilfe zeigt die Symbole.",
  ["How each spec of your class rates the item"] = "Wie jede Spezialisierung Eurer Klasse den Gegenstand bewertet",
  ["The Help tab explains the numbers."] = "Der Reiter Hilfe erklärt die Zahlen.",
  ["Icons instead of words"] = "Symbole statt Text",
  ["Icons and one line each, instead of words."] = "Symbole und je eine Zeile statt Text.",
  ["Arrows on bag items"] = "Pfeile bei Gegenständen in Taschen",
  ["Green up for an upgrade, red down only when every path is worse. The Help tab explains them."] =
    "Grün nach oben bei einem Upgrade, rot nach unten nur, wenn jeder Weg schlechter ist. Der Reiter Hilfe erklärt sie.",
  ["The beneficiary spec icon on an up arrow"] = "Das Symbol der begünstigten Spezialisierung am Pfeil nach oben",
  ["+N for the rest of the specs it is an upgrade for, ~ for the approximate healer score. Needs the arrows on."] =
    "+N für die übrigen Spezialisierungen, für die er ein Upgrade ist, ~ für die ungefähre Heilerwertung. Braucht eingeschaltete Pfeile.",
  ["Quest reward arrows"] = "Pfeile bei Questbelohnungen",
  ["A green up arrow on every usable upgrade. The reward with the highest positive '% better' rating shown in its tooltip gets a second arrow. If nothing is an upgrade, a coin marks the choice with the highest vendor price."] =
    "Ein grüner Pfeil nach oben bei jedem verwendbaren Upgrade. Die Belohnung mit der höchsten positiven '% besser'-Bewertung in ihrem Tooltip erhält einen zweiten Pfeil. Ist nichts ein Upgrade, markiert eine Münze die Wahl mit dem höchsten Händlerpreis.",
  ["Arrows on loot, rolls and merchants"] = "Pfeile bei Beute, Würfen und Händlern",
  ["The same bag verdict on loot slots, need/greed rolls and merchant buttons."] =
    "Dasselbe Taschenurteil bei Beuteplätzen, Bedarf/Gier-Würfen und Händler-Schaltflächen.",
  ["Hover a box for what it does. The preview at the left follows these boxes at once."] =
    "Haltet die Maus über ein Kästchen, um zu sehen, was es bewirkt. Die Vorschau links folgt diesen Kästchen sofort.",

  -- the Legend tab
  ["What the icons stand for"] = "Wofür die Symbole stehen",
  ["Under each difference: what the stats give this character -- the game's own numbers, worked out as its character sheet works them out. Green is up, red is down."] =
    "Unter jedem Unterschied: was die Werte diesem Charakter bringen -- die eigenen Zahlen des Spiels, so berechnet, wie sie auch das Charakterfenster berechnet. Grün heißt mehr, Rot weniger.",
  ["Armor is 2 per Agility and mana regeneration a quarter of Spirit, as measured on Forever. Health regeneration from Spirit is the character sheet's own number (standing, out of combat), taken per point of Spirit: it assumes the two are proportional. In combat the game may hide these numbers; then the line is left out."] =
    "Die Rüstung beträgt 2 pro Beweglichkeit und die Manaregeneration ein Viertel der Willenskraft, wie auf Forever gemessen. Die Gesundheitsregeneration durch Willenskraft ist die eigene Zahl des Charakterfensters (im Stehen, außerhalb des Kampfes), als Wert je Punkt Willenskraft genommen: Das setzt voraus, dass beides proportional ist. Im Kampf kann das Spiel diese Zahlen verbergen; dann entfällt die Zeile.",

  -- the Ratings tab
  ["How each spec rates the item"] = "Wie jede Spezialisierung den Gegenstand bewertet",
  ["Each spec of your class rates the item against what you wear: \"25% better dmg spec\" means its stats are worth a quarter more to that spec."] =
    "Jede Spezialisierung Eurer Klasse bewertet den Gegenstand im Vergleich zu dem, was Ihr tragt: \"25% besser für Schadens-Spez.\" bedeutet, dass seine Werte dieser Spezialisierung ein Viertel mehr wert sind.",
  ["A tank has two numbers: for survival (less damage taken) and for threat gen. (holding aggro)."] =
    "Ein Tank hat zwei Zahlen: fürs Überleben (weniger erlittener Schaden) und für Bedrohung (Aggro halten).",
  ["With nothing worth comparing, or a change past the cap: \">300% ...\", at most triple."] =
    "Bei nichts Vergleichbarem oder einer Änderung über der Obergrenze: \">300% ...\", höchstens dreifach.",
  ["Each healer spec (druid Restoration, priest Holy, paladin Holy, shaman Restoration) is rated by this addon's own starter heuristic, and its line is marked \"(approx.)\": an approximate item score, not a measured healing gain."] =
    "Jede Heiler-Spezialisierung (Druide Wiederherstellung, Priester Heilig, Paladin Heilig, Schamane Wiederherstellung) wird nach der eigenen Startheuristik dieses Addons bewertet, und ihre Zeile ist mit \"(ca.)\" markiert: eine ungefähre Gegenstandswertung, kein gemessener Heilungsgewinn.",
  ["Its weights are design choices of this addon (tools/data/healer_weights.json): 1 x +Healing, 1 x Spell Power, 0.5 x Intellect, 0.5 x Spirit and 2 x MP5. Every other stat counts for nothing to it."] =
    "Ihre Gewichte sind Designentscheidungen dieses Addons (tools/data/healer_weights.json): 1 x +Heilung, 1 x Zaubermacht, 0,5 x Intelligenz, 0,5 x Willenskraft und 2 x MP5. Jeder andere Wert zählt für sie nichts.",
  ["The other ratings use ForeverSim's stat weights, measured on a level 60 build of each spec with its own talents, gear and buffs: below 60 they are an estimate."] =
    "Die übrigen Bewertungen nutzen die Wertgewichtungen von ForeverSim, gemessen an einem Stufe-60-Aufbau jeder Spezialisierung mit eigenen Talenten, eigener Ausrüstung und eigenen Stärkungszaubern: unter Stufe 60 sind sie nur eine Schätzung.",
  ["A weapon's damage per second counts as the simulator weighs it for the spec: main hand, off hand and ranged slot apart."] =
    "Der Schaden pro Sekunde einer Waffe zählt so, wie der Simulator ihn für die Spezialisierung gewichtet: Waffenhand, Nebenhand und Distanzwaffe getrennt.",
  ["Not counted: what a hunter's pet gets from your stats, weapon skill, and Spirit for the specs the simulator does not weigh it for."] =
    "Nicht gezählt: was das Tier eines Jägers aus Euren Werten erhält, Waffenfertigkeit und Willenskraft bei den Spezialisierungen, für die der Simulator sie nicht gewichtet.",
  ["Always show the full tooltip"] = "Immer den vollständigen Tooltip zeigen",
  ["Off: one line, the best spec and its arrow. Hold Shift for the full breakdown."] =
    "Aus: eine Zeile, die beste Spezialisierung und ihr Pfeil. Haltet die Umschalttaste gedrückt für die vollständige Aufschlüsselung.",
  ["Hold Shift for the full breakdown."] = "Haltet die Umschalttaste gedrückt für die vollständige Aufschlüsselung.",

  -- the Bag arrows tab
  ["On the game's own bags and the Baganator bag grid: green up when at least one spec's score is outright better and none of it worse."] =
    "In den Taschen des Spiels und im Taschenraster von Baganator: grün nach oben, wenn die Wertung mindestens einer Spezialisierung eindeutig besser ist und keine schlechter.",
  ["Red down only when every replacement path is strictly worse for every spec. Mixed, equal or unknown: no arrow."] =
    "Rot nach unten nur, wenn jeder Ersatzweg für jede Spezialisierung eindeutig schlechter ist. Gemischt, gleich oder unbekannt: kein Pfeil.",
  ["Always against what you wear in that slot, never a BiS verdict."] =
    "Immer im Vergleich zu dem, was Ihr an diesem Platz tragt, nie ein BiS-Urteil.",
  ["Stats the simulator does not model are compared conservatively by the raw differences, with no spec icon; the healer's approximate score gets a ~ icon."] =
    "Werte, die der Simulator nicht abbildet, werden vorsichtig anhand der reinen Unterschiede verglichen, ohne Spezialisierungssymbol; die ungefähre Wertung des Heilers bekommt ein ~-Symbol.",
  ["While the client hides stats (in combat) or the item's data has not arrived, no arrow is shown."] =
    "Solange der Client Werte verbirgt (im Kampf) oder die Daten des Gegenstands noch nicht angekommen sind, wird kein Pfeil gezeigt.",
  ["DoesItDiePlus StatsInfo: green up / red down against what you wear"] =
    "DoesItDiePlus StatsInfo: grün nach oben / rot nach unten gegenüber Eurer Ausrüstung",

  -- the probe row
  ["Record the probe"] = "Messung aufzeichnen",
  ["%d recorded so far"] = "%d bisher aufgezeichnet",

  -- the lines in an item's tooltip: the headings of a comparison
  ["Against %s"] = "Vergleich mit: %s",
  ["Against %s:"] = "Vergleich mit: %s",
  ["Compared with your gear: %s"] = "Verglichen mit Eurer Ausrüstung: %s",
  ["an empty slot"] = "leerer Platz",
  ["the same stats"] = "dieselben Werte",
  ["Finger slot 1"] = "Fingerplatz 1",
  ["Finger slot 2"] = "Fingerplatz 2",
  ["Trinket slot 1"] = "Schmuckplatz 1",
  ["Trinket slot 2"] = "Schmuckplatz 2",

  -- the verdict lines
  ["Better than your gear"] = "Besser als Eure Ausrüstung",
  ["Worse than your gear"] = "Schlechter als Eure Ausrüstung",
  ["best spec"] = "beste Spezialisierung",
  ["Fills an empty slot"] = "Füllt einen leeren Platz",
  ["Lower score in an empty slot"] = "Niedrigere Wertung bei leerem Platz",
  ["score changes from zero"] = "Wertung ändert sich von null",
  ["%s, approx."] = "%s, ca.",
  ["%s (approx.)"] = "%s (ca.)",
  ["No clear upgrade; hold Shift for details"] = "Kein klares Upgrade; Umschalttaste für Details gedrückt halten",
  ["No clear upgrade for this slot"] = "Kein klares Upgrade für diesen Platz",
  ["Cannot use this item"] = "Dieser Gegenstand ist nicht verwendbar",

  -- the spec ratings, one template per line (the number is the %s)
  ["%s%% better dmg spec"] = "%s%% besser für Schadens-Spez.",
  ["%s%% worse dmg spec"] = "%s%% schlechter für Schadens-Spez.",
  ["%s%% better for survival"] = "%s%% besser fürs Überleben",
  ["%s%% worse for survival"] = "%s%% schlechter fürs Überleben",
  ["%s%% better for threat gen."] = "%s%% besser für Bedrohung",
  ["%s%% worse for threat gen."] = "%s%% schlechter für Bedrohung",
  ["%s%% better healer score"] = "%s%% bessere Heilerwertung",
  ["%s%% worse healer score"] = "%s%% schlechtere Heilerwertung",
  ["%s%% better"] = "%s%% besser",
  ["%s%% worse"] = "%s%% schlechter",

  -- the tank lines
  ["Uncrittable: %s/%s (need %s)"] = "Kritimmun: %s/%s (noch %s nötig)",
  ["Avoidance: %.2f%% / 102.4%% (miss+dodge+parry+block)"] =
    "Vermeidung: %.2f%% / 102.4%% (Verfehlen+Ausweichen+Parieren+Blocken)",
  ["Avoidance: %.2f%% / 102.4%% (dodge+parry+block, no miss)"] =
    "Vermeidung: %.2f%% / 102.4%% (Ausweichen+Parieren+Blocken, ohne Verfehlen)",

  -- what the stats are worth, in words (the icon line uses the short ones)
  ["armor"] = "Rüstung",
  ["attack power"] = "Angriffskraft",
  ["AP"] = "AK",
  ["crit"] = "Krit.",
  ["dodge"] = "Ausweichen",
  ["health"] = "Gesundheit",
  ["mana"] = "Mana",
  ["spell crit"] = "Zauberkrit.",
  ["mana per 5 sec. when not casting"] = "Mana pro 5 Sek. ohne Zaubern",
  ["mana/5s"] = "Mana/5 Sek.",
  ["hit"] = "Treffer",
  ["haste"] = "Tempo",
  ["expertise"] = "Waffenkunde",
  ["parry"] = "Parieren",
  ["block"] = "Blocken",
  ["block value"] = "Blockwert",
  ["defense"] = "Verteidigung",
  ["healing"] = "Heilung",
  ["spell power"] = "Zaubermacht",
  ["health per 5 sec. out of combat"] = "Gesundheit pro 5 Sek. außerhalb des Kampfes",
  ["health/5s"] = "Gesundheit/5 Sek.",

  -- the specs (Fire is in Core.lua)
  ["Feral (Bear)"] = "Wilder Kampf (Bär)",
  ["Feral (Cat)"] = "Wilder Kampf (Katze)",
  ["Balance"] = "Gleichgewicht",
  ["Restoration"] = "Wiederherstellung",
  ["Beast Mastery"] = "Tierherrschaft",
  ["Marksmanship"] = "Treffsicherheit",
  ["Survival"] = "Überleben",
  ["Arcane"] = "Arkan",
  ["Protection"] = "Schutz",
  ["Retribution"] = "Vergeltung",
  ["Holy"] = "Heilig",
  ["Shadow"] = "Schatten",
  ["Discipline"] = "Disziplin",
  ["Combat"] = "Kampf",
  ["Subtlety"] = "Täuschung",
  ["Assassination"] = "Meucheln",
  ["Elemental"] = "Elementar",
  ["Enhancement"] = "Verstärkung",
  ["Affliction"] = "Gebrechen",
  ["Demonology"] = "Dämonologie",
  ["Destruction"] = "Zerstörung",
  ["Destruction (DS/Ruin)"] = "Zerstörung (DS/Ruin)",
  ["Arms"] = "Waffen",
  ["Fury"] = "Furor",
})
