-- UsefulPlatesAndTooltips: the German texts of the settings window and of the Core files.
-- Copyright (c) 2026 Ironship. GPL-3.0-or-later, see LICENSE.
--
-- The key is the English text in the code; keep every %s and %d of it, in the same order. Texts used by more than
-- one part live here, the texts of one part in its own file. The form of address is "Ihr", as in SpellDamageInfo.

local _, BIT = ...

BIT.RegisterLocale("deDE", {
  -- the tabs
  ["Spells"] = "Zauber",
  ["SpellDamageInfo"] = "SpellDamageInfo",
  ["The damage and healing from each spell's description on your action buttons and in its tooltip."] =
    "Der Schaden und die Heilung aus der Beschreibung jedes Zaubers, auf Euren Aktionsleisten und in seinem Tooltip.",
  ["Cast"] = "Wirken",
  ["Cast prediction"] = "Zauberprognose",
  ["The damage the spell you are casting should deal, drawn on enabled unit frames and the target's nameplate. Channels show estimated damage remaining until the channel ends. Crits, procs and resists cannot be predicted."] =
    "Der Schaden, den der gewirkte Zauber voraussichtlich verursacht, eingezeichnet auf den aktivierten Einheitenfenstern und der Namensplakette des Ziels. Kanalisierte Zauber zeigen den geschätzten Restschaden bis zum Ende der Kanalisierung. Kritische Treffer, Procs und Widerstand lassen sich nicht vorhersagen.",
  ["DoTs"] = "DoTs",
  ["DoTInfo"] = "DoTInfo",
  ["Marks on the target's health bar the damage your DoTs still have to deal, with a kill icon when they will finish it."] =
    "Markiert auf der Gesundheitsleiste des Ziels den Schaden, den Eure DoTs noch verursachen, mit einem Kill-Symbol, wenn sie das Ziel erledigen.",
  ["Stats"] = "Werte",
  ["StatsInfo"] = "StatsInfo",
  ["In an item's tooltip: what its stats change against the item you wear in that slot."] =
    "Im Tooltip eines Gegenstands: was seine Werte gegenüber dem Gegenstand ändern, den Ihr an diesem Platz tragt.",
  ["Points"] = "Punkte",
  ["ResourceDing"] = "ResourceDing",
  ["A sound when your combo points are full, and the points as dots under the target; for casters a sound when mana climbs to a level, and for warlocks one on each Soul Shard."] =
    "Ein Ton, wenn Eure Combopunkte voll sind, und die Punkte als Kreise unter dem Ziel; für Zauberwirker ein Ton, wenn das Mana eine Schwelle erreicht, und für Hexenmeister einer bei jedem Seelensplitter.",
  ["Range"] = "Reichweite",
  ["A red X over your target while it is out of range, a green checkmark while it is in range."] =
    "Ein rotes X über Eurem Ziel, solange es außer Reichweite ist, und ein grünes Häkchen, solange es in Reichweite ist.",
  ["Shields"] = "Schilde",
  ["The remaining absorb of a shield on your frames and nameplates."] =
    "Die verbleibende Absorption eines Schilds auf Euren Fenstern und Namensplaketten.",
  ["Heals"] = "Heilung",
  ["Heal prediction"] = "Heilungsprognose",
  ["Incoming healing on player, target, focus, target-of-target, party and raid frames (native direct heals and estimates for your own HoTs)."] =
    "Eingehende Heilung auf Spieler-, Ziel-, Fokus-, Ziel-des-Ziels-, Gruppen- und Schlachtzugsfenstern (native direkte Heilung und Schätzungen für Eure eigenen HoTs).",
  ["Hunter"] = "Jäger",
  ["Hunter range"] = "Jägerreichweite",
  ["Six native dots tell a hunter the approximate range, 8-10 yd to 30-35 yd; a seventh past 35 yd with Hawk Eye."] =
    "Sechs native Punkte zeigen einem Jäger die ungefähre Reichweite an, von 8-10 m bis 30-35 m; ein siebter jenseits von 35 m mit Falkenauge.",
  ["Hunter only. Settings are here for an alt."] = "Nur für Jäger. Die Einstellungen stehen hier für einen Zweitcharakter.",

  -- the window
  ["Settings"] = "Einstellungen",
  ["Enable %s"] = "%s aktivieren",
  ["Reload UI"] = "UI neu laden",
  ["Reset module"] = "Modul zurücksetzen",
  ["Reset all settings for %s? The interface will reload. Module enable state, learned data and shared settings are kept."] =
    "Alle Einstellungen für %s zurücksetzen? Die Oberfläche wird neu geladen. Modulstatus, erlernte Daten und gemeinsame Einstellungen bleiben erhalten.",
  ["Cannot reset %s: defaults are unavailable."] = "%s kann nicht zurückgesetzt werden: Standardwerte fehlen.",
  ["Cannot reset settings: reloading the interface is unavailable."] = "Einstellungen können nicht zurückgesetzt werden: Die Oberfläche kann nicht neu geladen werden.",
  ["Cannot reset %s: its settings are invalid."] = "%s kann nicht zurückgesetzt werden: Die Einstellungen sind ungültig.",
  ["Cannot reset %s appearance: %s"] = "Das Aussehen von %s kann nicht zurückgesetzt werden: %s",
  ["Running."] = "Läuft.",
  ["Open settings"] = "Einstellungen öffnen",
  ["Open the settings window. You can also type /upt."] = "Öffnet das Einstellungsfenster. Ihr könnt auch /upt eingeben.",
  ["The settings have their own window. You can also type /upt."] =
    "Die Einstellungen haben ein eigenes Fenster. Ihr könnt auch /upt eingeben.",
  ["Switched on after a reload of the interface."] = "Wird nach einem Neuladen der Oberfläche eingeschaltet.",
  ["Switched off after a reload of the interface."] = "Wird nach einem Neuladen der Oberfläche ausgeschaltet.",
  ["Its settings are here while it runs; its appearance and a sample preview are below -- they need no module runtime. Tick Enable to open the settings before the next reload."] =
    "Seine Einstellungen stehen hier, solange es läuft; sein Aussehen und eine Beispielvorschau stehen unten -- sie brauchen keine Modullaufzeit. Setzt das Häkchen bei Aktivieren, um die Einstellungen schon vor dem nächsten Neuladen zu öffnen.",
  ["This module is switched off. Tick Enable above to open its settings and live preview before the next reload."] =
    "Dieses Modul ist ausgeschaltet. Setzt oben das Häkchen bei Aktivieren, um seine Einstellungen und die Live-Vorschau schon vor dem nächsten Neuladen zu öffnen.",
  ["%s is switched off. /upt opens the settings, where it can be switched on."] =
    "%s ist ausgeschaltet. /upt öffnet die Einstellungen, in denen es eingeschaltet werden kann.",
  ["%s/%s: tabs"] = "%s/%s: Reiter",
  ["%s/%s: select  ·  %s/%s: move / adjust  ·  %s: activate  ·  %s: back"] =
    "%s/%s: wählen  ·  %s/%s: bewegen / anpassen  ·  %s: aktivieren  ·  %s: zurück",
  ["ConsolePort: D-pad: select · use the cursor's button hints"] =
    "ConsolePort: Steuerkreuz: wählen · die Tastenhinweise des Cursors nutzen",
  ["/upt opens the settings; /upt <part> opens a part's tab (%s); /upt probe records what StatsInfo can read; /upt lang sets the language."] =
    "/upt öffnet die Einstellungen; /upt <Teil> öffnet den Reiter eines Teils (%s); /upt probe zeichnet auf, was StatsInfo lesen kann; /upt lang stellt die Sprache ein.",

  -- the language command
  ["%d texts shown so far have no translation in this language."] =
    "%d bisher angezeigte Texte haben in dieser Sprache keine Übersetzung.",
  ["Unknown language %s. Use auto, en or one of: %s."] = "Unbekannte Sprache %s. Nutzt auto, en oder eine von: %s.",
  ["Auto (game language)"] = "Auto (Spielsprache)",
  ["The language of the settings, tooltips and chat lines of this addon. It changes after a reload. Auto follows the game's language."] =
    "Die Sprache der Einstellungen, Tooltips und Chatzeilen dieses Addons. Sie ändert sich nach einem Neuladen. Auto folgt der Sprache des Spiels.",
  ["The language changes after /reload."] = "Die Sprache ändert sich nach /reload.",
  ["Language: %s. /upt lang auto, /upt lang en, /upt lang <code> (%s) or /upt lang missing."] =
    "Sprache: %s. /upt lang auto, /upt lang en, /upt lang <Code> (%s) oder /upt lang missing.",

  -- the frame picker
  ["the health bar"] = "die Gesundheitsleiste",
  ["where the kill icon should go"] = "die Stelle für das Kill-Symbol",
  ["(this frame has no name to save)"] = "(dieses Fenster hat keinen speicherbaren Namen)",
  ["nothing under the mouse"] = "nichts unter der Maus",
  ["DoesItDiePlus: click %s (right-click to cancel)"] = "DoesItDiePlus: Klickt auf %s (Rechtsklick bricht ab)",
  ["Frame pick stopped after an error: %s. You can still type a frame name."] =
    "Die Fensterwahl wurde nach einem Fehler beendet: %s. Ihr könnt den Fensternamen weiterhin eintippen.",
  ["Frame pick cancelled."] = "Fensterwahl abgebrochen.",
  ["Nothing to pick there."] = "Dort gibt es nichts zu wählen.",
  ["That frame has no name to save, so it cannot be found again after a reload. Try the frame around it, or type a path."] =
    "Dieses Fenster hat keinen Namen zum Speichern und wäre nach einem Neuladen nicht mehr auffindbar. Versucht das umgebende Fenster oder tippt einen Pfad ein.",
  ["automatic"] = "automatisch",
  ["%s not found"] = "%s nicht gefunden",
  ["/upt frame target|icon|focus|player|plate <path> sets one (\"clear\" removes it); /upt pick target|icon|focus|player"] =
    "/upt frame target|icon|focus|player|plate <Pfad> setzt einen (\"clear\" entfernt ihn); /upt pick target|icon|focus|player",
  ["/upt pick target|icon|focus|player, then click the frame on screen (right-click cancels)."] =
    "/upt pick target|icon|focus|player, danach das Fenster auf dem Bildschirm anklicken (Rechtsklick bricht ab).",
  ["Click the spot for the kill icon. Right-click cancels."] =
    "Klickt auf die Stelle für das Kill-Symbol. Ein Rechtsklick bricht ab.",
  ["Click the health bar of %s. Right-click cancels."] =
    "Klickt auf die Gesundheitsleiste von %s. Ein Rechtsklick bricht ab.",
  ["Picked %s for %s."] = "%s für %s gewählt.",

  -- the nameplate lanes
  ["Hunter rail overlaps combo dots."] = "Die Jägerleiste überlappt die Combopunkte.",
  ["Hunter rail overlaps shard diamonds."] = "Die Jägerleiste überlappt die Splitter-Rauten.",
  ["Combo dots overlap shard diamonds."] = "Die Combopunkte überlappen die Splitter-Rauten.",
  ["Nameplate lanes are clear."] = "Die Bahnen der Namensplaketten sind frei.",

  -- the shared rows and the preview
  ["Live preview"] = "Live-Vorschau",
  ["Nameplate lanes"] = "Bahnen der Namensplaketten",
  ["Bar"] = "Balken",
  ["Display"] = "Anzeige",
  ["Position"] = "Position",
  ["Preview"] = "Vorschau",
  ["Player"] = "Spieler",
  ["Target"] = "Ziel",
  ["Party"] = "Gruppe",
  ["Print"] = "Ausgeben",
  ["Height"] = "Höhe",
  ["Health"] = "Gesundheit",
  ["Frost"] = "Frost",
  ["Marker"] = "Markierung",
  ["Text"] = "Text",
  ["Nameplates"] = "Namensplaketten",
  ["Reset"] = "Zurücksetzen",
  ["Combo"] = "Combo",
  ["Combo points"] = "Combopunkte",
  ["Effects"] = "Effekte",
  ["Spell"] = "Zauber",
  ["TRY IT"] = "AUSPROBIEREN",
  ["Target health"] = "Zielgesundheit",
  ["FRAMES"] = "FENSTER",
  ["Show on target frame"] = "Im Zielfenster zeigen",
  ["Show on focus frame"] = "Im Fokusfenster zeigen",
  ["Show on nameplates"] = "Auf Namensplaketten zeigen",
  ["Target beats mouseover"] = "Ziel hat Vorrang vor Mouseover",
  ["Fill color"] = "Füllfarbe",
  ["Fill opacity"] = "Deckkraft der Füllung",
  ["Fill style"] = "Füllstil",
  ["Outline"] = "Umriss",
  ["Outline color"] = "Umrissfarbe",
  ["Outline opacity"] = "Deckkraft des Umrisses",
  ["Text position"] = "Textposition",
  ["Centered on the bar"] = "Auf der Leiste zentriert",
  ["Left of the bar"] = "Links der Leiste",
  ["Inside the bar, right end"] = "In der Leiste, rechtes Ende",
  ["Text size"] = "Textgröße",
  ["Text color"] = "Textfarbe",
  ["Icon size"] = "Symbolgröße",
  ["Icon horizontal offset"] = "Symbol, horizontaler Versatz",
  ["Icon vertical offset"] = "Symbol, vertikaler Versatz",
  ["Reset this tab"] = "Diesen Reiter zurücksetzen",
  ["Look presets  v"] = "Stilvorlagen  v",
  ["%d-%d of %d"] = "%d-%d von %d",
  ["Off"] = "Aus",
  ["None"] = "Keine",
  ["Solid"] = "Durchgezogen",
  ["Dashed"] = "Gestrichelt",
  ["Raid skull"] = "Schlachtzugs-Totenkopf",
  ["Red X"] = "Rotes X",

  -- the appearance panel
  ["Appearance"] = "Aussehen",
  ["APPEARANCE"] = "AUSSEHEN",
  ["Advanced"] = "Erweitert",
  ["Hide advanced"] = "Erweitert ausblenden",
  ["Editing: this module"] = "Bearbeitet: dieses Modul",
  ["Editing: all modules"] = "Bearbeitet: alle Module",
  ["Palette (arbitrary RGB)"] = "Palette (beliebiges RGB)",
  ["RGB %s:"] = "RGB %s:",
  ["Font path:"] = "Schriftpfad:",
  ["Font size"] = "Schriftgröße",
  ["Text outline"] = "Textumriss",
  ["Thick outline"] = "Dicker Umriss",
  ["Scale"] = "Skalierung",
  ["Opacity"] = "Deckkraft",
  ["Size"] = "Größe",
  ["Shape"] = "Form",
  ["Border"] = "Rand",
  ["Thickness"] = "Stärke",
  ["Gap"] = "Abstand",
  ["Length"] = "Länge",
  ["Segments"] = "Segmente",
  ["Stripes"] = "Streifen",
  ["Reduced motion"] = "Weniger Bewegung",
  ["Limits the animations (pulses, glides, sweeps) to the calm ones."] =
    "Beschränkt die Animationen (Pulsieren, Gleiten, Wischen) auf die ruhigen.",
  ["Minimal"] = "Minimal",
  ["Classic"] = "Klassisch",
  ["Juicy"] = "Saftig",
  ["Minimal preset"] = "Vorlage Minimal",
  ["Reset this module's appearance"] = "Aussehen dieses Moduls zurücksetzen",
  ["Reset shared appearance (all modules)"] = "Gemeinsames Aussehen zurücksetzen (alle Module)",
  ["Reset changes only the appearance: gameplay settings, sounds, anchors and learned values stay."] =
    "Zurücksetzen ändert nur das Aussehen: Spieleinstellungen, Töne, Anker und gelernte Werte bleiben erhalten.",
  ["Sample: fictitious data, not the live game"] = "Beispiel: erfundene Daten, nicht das laufende Spiel",
  ["Sample text 123"] = "Beispieltext 123",

  -- the colors of the palette roles
  ["accent"] = "Akzent",
  ["text"] = "Text",
  ["muted"] = "gedämpft",
  ["damage"] = "Schaden",
  ["heal"] = "Heilung",
  ["absorb"] = "Absorption",
  ["good"] = "gut",
  ["bad"] = "schlecht",
  ["unknown"] = "unbekannt",
  ["resource"] = "Ressource",
  ["distanceNear"] = "Entfernung: nah",
  ["distanceMid"] = "Entfernung: mittel",
  ["distanceFar"] = "Entfernung: weit",

  -- the color palette
  ["Custom color..."] = "Eigene Farbe...",
  ["Custom %s"] = "Eigene %s",
  ["Purple"] = "Lila",
  ["Gold"] = "Gold",
  ["White"] = "Weiß",
  ["Red"] = "Rot",
  ["Orange"] = "Orange",
  ["Green"] = "Grün",
  ["Cyan"] = "Cyan",
  ["Pink"] = "Rosa",
  ["Black"] = "Schwarz",
  ["Crimson"] = "Karmesinrot",
  ["Maroon"] = "Weinrot",
  ["Coral"] = "Koralle",
  ["Amber"] = "Bernstein",
  ["Yellow"] = "Gelb",
  ["Lime"] = "Limette",
  ["Forest"] = "Waldgrün",
  ["Mint"] = "Minze",
  ["Teal"] = "Blaugrün",
  ["Sky blue"] = "Himmelblau",
  ["Blue"] = "Blau",
  ["Navy"] = "Marineblau",
  ["Indigo"] = "Indigo",
  ["Violet"] = "Violett",
  ["Magenta"] = "Magenta",
  ["Lavender"] = "Lavendel",
  ["Peach"] = "Pfirsich",
  ["Bone"] = "Knochenweiß",
  ["Brown"] = "Braun",
  ["Olive"] = "Oliv",
  ["Ice"] = "Eis",
  ["Silver"] = "Silber",
  ["Gray"] = "Grau",
  ["Charcoal"] = "Anthrazit",

  -- the texture groups
  ["Basic"] = "Grundlegend",
  ["Blizzard"] = "Blizzard",
  ["Soft"] = "Weich",
  ["Bar shapes"] = "Balkenformen",
  ["Patterns"] = "Muster",
  ["Organic"] = "Organisch",
  ["Material"] = "Material",
  ["Colorful (own colors)"] = "Bunt (eigene Farben)",
  ["Shared media"] = "Gemeinsame Medien",

  -- the textures
  ["Flat"] = "Flach",
  ["Fade in from left"] = "Von links einblenden",
  ["Health bar texture"] = "Gesundheitsleisten-Textur",
  ["Raid bar texture"] = "Schlachtzugsleisten-Textur",
  ["Raid power texture"] = "Schlachtzugs-Ressourcentextur",
  ["Skill bar texture"] = "Fertigkeitsleisten-Textur",
  ["Loading bar texture"] = "Ladebalken-Textur",
  ["Glass (light top, dark bottom)"] = "Glas (oben hell, unten dunkel)",
  ["Bevel (light to dark)"] = "Abschrägung (hell zu dunkel)",
  ["Cylinder (bright middle)"] = "Zylinder (helle Mitte)",
  ["Inset (dark to light)"] = "Vertieft (dunkel zu hell)",
  ["Top shine"] = "Glanz oben",
  ["Rim glow (top and bottom)"] = "Randglühen (oben und unten)",
  ["Fade out to the right"] = "Nach rechts ausblenden",
  ["Fade out to the left"] = "Nach links ausblenden",
  ["Fade at both ends"] = "An beiden Enden ausblenden",
  ["Diagonal stripes"] = "Diagonale Streifen",
  ["Diagonal stripes, other way"] = "Diagonale Streifen, andere Richtung",
  ["Wide diagonal stripes"] = "Breite diagonale Streifen",
  ["Vertical lines"] = "Senkrechte Linien",
  ["Vertical lines, wide"] = "Senkrechte Linien, breit",
  ["Horizontal lines"] = "Waagerechte Linien",
  ["Horizontal lines, wide"] = "Waagerechte Linien, breit",
  ["Scanlines"] = "Rasterzeilen",
  ["Crosshatch"] = "Kreuzschraffur",
  ["Grid"] = "Gitter",
  ["Checkerboard"] = "Schachbrett",
  ["Dots"] = "Punkte",
  ["Big dots"] = "Große Punkte",
  ["Diamonds"] = "Rauten",
  ["Zigzag"] = "Zickzack",
  ["Chevrons"] = "Winkel",
  ["Waves"] = "Wellen",
  ["Bricks"] = "Ziegel",
  ["Carbon fibre"] = "Carbonfaser",
  ["Noise"] = "Rauschen",
  ["Brushed metal"] = "Gebürstetes Metall",
  ["Tube (round highlight)"] = "Röhre (runder Glanz)",
  ["Chrome bands"] = "Chrombänder",
  ["Glass, strong"] = "Glas, stark",
  ["Glow in the middle"] = "Glühen in der Mitte",
  ["Dark edges"] = "Dunkle Ränder",
  ["Two tones (light over dark)"] = "Zwei Töne (hell über dunkel)",
  ["Four steps"] = "Vier Stufen",
  ["Capsule (rounded ends)"] = "Kapsel (runde Enden)",
  ["Bright leading edge"] = "Helle Vorderkante",
  ["Segments, 5 (20% each)"] = "Segmente, 5 (je 20%)",
  ["Segments, 10 (10% each)"] = "Segmente, 10 (je 10%)",
  ["Segments, 20 (5% each)"] = "Segmente, 20 (je 5%)",
  ["Hexagons"] = "Sechsecke",
  ["Triangles"] = "Dreiecke",
  ["Argyle diamonds"] = "Argyle-Rauten",
  ["Plaid"] = "Schottenkaro",
  ["Houndstooth"] = "Hahnentritt",
  ["Sparkles"] = "Funkeln",
  ["Crosses"] = "Kreuze",
  ["Rings"] = "Ringe",
  ["Clouds"] = "Wolken",
  ["Marble"] = "Marmor",
  ["Wood grain"] = "Holzmaserung",
  ["Camouflage"] = "Tarnmuster",
  ["Leopard spots"] = "Leopardenflecken",
  ["Cracked earth"] = "Rissiger Boden",
  ["Glowing veins"] = "Glühende Adern",
  ["Bubbles"] = "Blasen",
  ["Fish scales"] = "Fischschuppen",
  ["Water ripples"] = "Wasserwellen",
  ["Sand"] = "Sand",
  ["Zebra"] = "Zebra",
  ["Leather"] = "Leder",
  ["Woven cloth"] = "Gewebter Stoff",
  ["Basket weave"] = "Korbgeflecht",
  ["Scratched metal"] = "Zerkratztes Metall",
  ["Beveled tiles"] = "Abgeschrägte Kacheln",
  ["Rivets"] = "Nieten",
  ["Louvers"] = "Lamellen",
  ["Rainbow"] = "Regenbogen",
  ["Fire"] = "Feuer",
  ["Lava"] = "Lava",
  ["Blood"] = "Blut",
  ["Sunset"] = "Sonnenuntergang",
  ["Plasma"] = "Plasma",
  ["Aurora"] = "Aurora",
  ["Ocean (light to deep)"] = "Ozean (hell zu tief)",
  ["Flame (top to bottom)"] = "Flamme (oben nach unten)",
  ["Toxic"] = "Giftig",
  ["Steel blue"] = "Stahlblau",
})

-- The settings reorganisation (0.9.131-beta.5): the Frames page, the Show on blocks, shared labels and tips.
BIT.RegisterLocale("deDE", {
  ["Only for another unit frame addon (ElvUI, Shadowed Unit Frames, ...) or custom nameplates: tell the addon where its health bars are. Empty rows are automatic. The markers of DoTs, Cast, Shields and Heals use these."] =
    "Nur für ein anderes Einheitenfenster-Addon (ElvUI, Shadowed Unit Frames, ...) oder eigene Namensplaketten: Sagt dem Addon, wo dessen Gesundheitsleisten sind. Leere Zeilen sind automatisch. Die Markierungen von DoTs, Wirken, Schilden und Heilung nutzen diese Angaben.",
  ["Where another unit frame addon's health bars are, for every marker the addon draws."] =
    "Wo die Gesundheitsleisten eines anderen Einheitenfenster-Addons sind, für jede Markierung des Addons.",
  ["The art of the fill: patterns, glass and bevel shadings, Blizzard's bar textures and every LibSharedMedia texture."] =
    "Die Optik der Füllung: Muster, Glas- und Kantenschattierungen, Blizzards Leistentexturen und jede LibSharedMedia-Textur.",
  ["The fill's color. A style with colors of its own ignores it."] =
    "Die Farbe der Füllung. Eine Optik mit eigenen Farben ignoriert sie.",
  ["How strongly the fill covers what is under it."] =
    "Wie stark die Füllung das Darunterliegende überdeckt.",
  ["Which end of the bar the fill starts from."] =
    "Von welchem Ende der Leiste die Füllung ausgeht.",
  ["A hairline around the marker."] =
    "Eine feine Linie um die Markierung.",
  ["The color of the outline."] =
    "Die Farbe der Umrandung.",
  ["How strongly the outline shows."] =
    "Wie stark die Umrandung zu sehen ist.",
  ["The width of the outline in pixels."] =
    "Die Breite der Umrandung in Pixeln.",
  ["The length of each dash of a dashed outline."] =
    "Die Länge jedes Strichs einer gestrichelten Umrandung.",
  ["The size of the text in pixels."] =
    "Die Größe des Textes in Pixeln.",
  ["The color of the text."] =
    "Die Farbe des Textes.",
  ["Where the text sits."] =
    "Wo der Text sitzt.",
  ["How see-through everything of this part is."] =
    "Wie durchsichtig alles an diesem Teil ist.",
  ["Makes everything of this part bigger or smaller."] =
    "Macht alles an diesem Teil größer oder kleiner.",
  ["The space between the parts, in pixels."] =
    "Der Abstand zwischen den Teilen in Pixeln.",
  ["How long the parts are, in pixels."] =
    "Wie lang die Teile sind, in Pixeln.",
  ["How thick the parts are, in pixels."] =
    "Wie dick die Teile sind, in Pixeln.",
  ["The shape the parts are drawn in."] =
    "Die Form, in der die Teile gezeichnet werden.",
  ["SHOW ON"] =
    "ANZEIGEN AUF",
  ["The target's own plate gets the same marker, with its own colors on the Nameplates tab; enemy bars are red."] =
    "Die Namensplakette des Ziels bekommt dieselbe Markierung, mit eigenen Farben im Reiter Namensplaketten; gegnerische Leisten sind rot.",
  ["BEHAVIOR"] =
    "VERHALTEN",
  ["MANA COST"] =
    "MANAKOSTEN",
  ["DoTs has its own kill icon (DoTs > Kill icon). If you use both, set both, or switch one off."] =
    "DoTs hat ein eigenes Kill-Symbol (DoTs > Kill-Symbol). Nutzt Ihr beide, stellt beide ein oder schaltet eines aus.",
  ["Cast prediction has its own kill icon (Cast > Marker). If you use both, set both, or switch one off."] =
    "Die Zauberprognose hat ein eigenes Kill-Symbol (Wirken > Markierung). Nutzt Ihr beide, stellt beide ein oder schaltet eines aus.",
  ["Keep this on to show the marker on your screen's target health bar. Plater changes nameplates, not that frame; if you use a separate unit frame addon, set its bar on the Frames page. Turn off to keep the marker on nameplates and the focus frame only. On Retail this also hides the rogue's aura icons above the target bar. The kill icon has its own switch in the Kill icon tab."] =
    "Lasst dies eingeschaltet, damit die Markierung auf der Gesundheitsleiste Eures Zielfensters erscheint. Plater ändert Namensplaketten, nicht dieses Fenster; nutzt Ihr ein separates Einheitenfenster-Addon, legt dessen Leiste auf der Seite Fenster fest. Schaltet dies aus, damit die Markierung nur auf Namensplaketten und im Fokusfenster bleibt. In Retail blendet dies auch die Aura-Symbole des Schurken über der Zielleiste aus. Das Kill-Symbol hat im Reiter Kill-Symbol einen eigenen Schalter.",
  ["Draws the same marker (and optionally the kill icon) on your focus frame's health bar for your DoTs on the focused enemy, in the nameplate look (Nameplates tab)."] =
    "Zeichnet dieselbe Markierung (und wahlweise das Kill-Symbol) auf die Gesundheitsleiste Eures Fokusfensters für Eure DoTs auf dem Fokusziel, in der Namensplaketten-Optik (Reiter Namensplaketten).",
  ["Draws a marker (and optionally the kill icon) on every enemy nameplate with your DoTs on it, in its own look on the Nameplates tab."] =
    "Zeichnet eine Markierung (und wahlweise das Kill-Symbol) auf jede gegnerische Namensplakette mit Euren DoTs, in einer eigenen Optik im Reiter Namensplaketten.",
  ["Show dividers between DoTs"] =
    "Trennlinien zwischen DoTs zeigen",
  ["Glow thickness"] =
    "Dicke des Leuchtens",
  ["Another unit frame addon"] =
    "Anderes Einheitenfenster-Addon",
  ["Open Frames"] =
    "Fenster öffnen",
  ["ElvUI, Shadowed Unit Frames and other unit frame addons: where their health bars are is set once for every marker, on the Frames page."] =
    "ElvUI, Shadowed Unit Frames und andere Einheitenfenster-Addons: Wo deren Gesundheitsleisten sind, wird einmal für alle Markierungen auf der Seite Fenster festgelegt.",
  ["Features"] =
    "Funktionen",
  ["Experiments (on by default in this beta)"] =
    "Experimente (in dieser Beta standardmäßig an)",
  ["Aura-gated segments on nameplates (experiment)"] =
    "Aura-gesteuerte Segmente auf Namensplaketten (Experiment)",
  ["Aura-gated segment on the target frame (experiment)"] =
    "Aura-gesteuertes Segment im Zielfenster (Experiment)",
  ["Diagnostics"] =
    "Diagnose",
  ["Show native next to plain segments"] =
    "Native neben einfachen Segmenten zeigen",
  ["Show on player frame"] =
    "Auf Spielerfenster anzeigen",
  ["Show on target of target frame"] =
    "Auf Ziel-des-Ziels-Fenster anzeigen",
  ["The fill style of the band for the healing other healers have coming."] =
    "Die Füllung des Bandes für die Heilung anderer Heiler.",
  ["The color of the band for the healing other healers have coming."] =
    "Die Farbe des Bandes für die Heilung anderer Heiler.",
  ["How strongly the band for other healers' healing covers the bar."] =
    "Wie stark das Band für die Heilung anderer Heiler die Leiste überdeckt.",
  ["The fill style of the segment for your heals over time."] =
    "Die Füllung des Abschnitts für Eure Heilung über Zeit.",
  ["The color of the segment for your heals over time."] =
    "Die Farbe des Abschnitts für Eure Heilung über Zeit.",
  ["How strongly the segment for your heals over time covers the bar."] =
    "Wie stark der Abschnitt für Eure Heilung über Zeit die Leiste überdeckt.",
  ["The Show on target frame option controls this sample; the other Show on options control live frames. The segment starts at the health edge (the green bar's end) and is cropped at the bar's right end when the heal would overheal."] =
    "Die Option „Auf Zielfenster anzeigen“ steuert dieses Beispiel; die anderen Optionen „Anzeigen auf“ steuern echte Fenster. Der Abschnitt beginnt am Ende des Gesundheitsbereichs (Ende der grünen Leiste) und wird am rechten Leistenende abgeschnitten, wenn die Heilung überheilen würde.",
  ["How high the rail sits above the plate's health bar. Positive is up, negative is under the bar. The same seat as the combo dots."] =
    "Wie hoch die Leiste über der Gesundheitsleiste der Namensplakette sitzt. Positiv ist oben, negativ unter der Leiste. Derselbe Platz wie bei den Combo-Punkten.",
  ["Mark size"] =
    "Größe der Markierung",
  ["Dot size (saved)"] =
    "Punktgröße (gespeichert)",
  ["Size of the combo points and soul shards. This changes the saved setting, the same one as on the Combo tab."] =
    "Größe der Combo-Punkte und Seelensplitter. Dies ändert die gespeicherte Einstellung, dieselbe wie im Reiter Combo.",
  ["Height (saved)"] =
    "Höhe (gespeichert)",
  ["Height of the resource in the selected tab. Positive is up, negative is under the bar. This changes the saved setting, the same one as on the Combo / Shards tab."] =
    "Höhe der Ressource im gewählten Reiter. Positiv ist oben, negativ unter der Leiste. Dies ändert die gespeicherte Einstellung, dieselbe wie im Reiter Combo / Splitter.",
  ["Dot height above the bar"] =
    "Höhe der Punkte über der Leiste",
  ["How high the dots sit above the health bar. Positive is up, negative is under the bar. The same seat as the hunter rail."] =
    "Wie hoch die Punkte über der Gesundheitsleiste sitzen. Positiv ist oben, negativ unter der Leiste. Derselbe Platz wie bei der Jägerleiste.",
  ["Shard height above the bar"] =
    "Höhe der Splitter über der Leiste",
  ["How high the diamonds sit above the health bar. Positive is up, negative is under the bar; they move independently of the dots."] =
    "Wie hoch die Rauten über der Gesundheitsleiste sitzen. Positiv ist oben, negativ unter der Leiste; sie bewegen sich unabhängig von den Punkten.",
  ["Show on"] =
    "Anzeigen auf",
})

-- Simulate (0.9.131-beta.6): the shared Simulate block, its scenes and names.
BIT.RegisterLocale("deDE", {
  ["SIMULATE"] =
    "SIMULIEREN",
  ["Simulate"] =
    "Simulieren",
  ["Settings you change while it plays show at once."] =
    "Einstellungen, die Ihr währenddessen ändert, wirken sofort.",
  ["A cast lands and the health drops; the next one is lethal and shows the kill icon."] =
    "Ein Zauber trifft und die Gesundheit sinkt; der nächste ist tödlich und zeigt das Kill-Symbol.",
  ["A heal is cast and lands, then its heal over time ticks down."] =
    "Eine Heilung wird gewirkt und landet, danach tickt ihre Heilung über Zeit herunter.",
  ["The target runs in through every band, from 35+ yd to melee and the dead zone."] =
    "Das Ziel läuft durch jedes Band, von 35+ yd bis in den Nahkampf und die tote Zone.",
  ["Try: out of range"] =
    "Testen: außer Reichweite",
  ["Try: no nameplate"] =
    "Testen: keine Namensplakette",
  ["The target steps in and out of range, then loses its nameplate."] =
    "Das Ziel tritt in und aus der Reichweite und verliert dann seine Namensplakette.",
  ["The points come in one by one, then the finisher spends them."] =
    "Die Punkte kommen einzeln, dann verbraucht sie der Finisher.",
  ["Three hits land: the shield takes them first, then the health, and the shield breaks."] =
    "Drei Treffer landen: Der Schild nimmt sie zuerst, dann die Gesundheit, und der Schild bricht.",
  ["Reset frames"] = "Rahmen zurücksetzen",
  ["Frames reset: %d paths cleared, the addon finds the frames by itself again."] =
    "Rahmen zurückgesetzt: %d Pfade gelöscht, das Addon findet die Rahmen wieder selbst.",
  ["Frames: no path was set, the addon already finds the frames by itself."] =
    "Rahmen: Es war kein Pfad gesetzt, das Addon findet die Rahmen bereits selbst.",

  -- Profiles
  ["Profiles"] = "Profile",
  ["Profile: %s"] = "Profil: %s",
  ["Default"] = "Standard",
  ["Default (shared)"] = "Standard (geteilt)",
  ["Separate settings and enabled modules per character, or shared across characters."] =
    "Getrennte Einstellungen und aktive Module pro Charakter oder gemeinsam für alle Charaktere.",
  ["Profiles save which modules are enabled and all module settings (appearance, frames and options). Learned combat data and language are kept across profiles. Switching profiles reloads the interface."] =
    "Profile speichern, welche Module aktiv sind, sowie alle Moduleinstellungen (Aussehen, Rahmen und Optionen). Gelernte Kampfdaten und die Sprache bleiben profilübergreifend erhalten. Ein Profilwechsel lädt die Oberfläche neu.",
  ["Character: %s"] = "Charakter: %s",
  ["Unknown"] = "Unbekannt",
  ["Active profile: %s"] = "Aktives Profil: %s",
  ["After reload: %s"] = "Nach Neuladen: %s",
  ["Active: %s  ->  After reload: %s"] = "Aktiv: %s  ->  Nach Neuladen: %s",
  ["Click to manage character profiles and enabled modules."] =
    "Klicken, um Charakterprofile und aktive Module zu verwalten.",
  ["THIS CHARACTER"] = "DIESER CHARAKTER",
  ["Active profile"] = "Aktives Profil",
  ["Which profile this character uses. Default is shared across characters; choose this character's name or create a named profile for separate settings and enabled modules."] =
    "Welches Profil dieser Charakter nutzt. Standard wird zwischen Charakteren geteilt; wählt den Charakternamen oder erstellt ein benanntes Profil für eigene Einstellungen und aktive Module.",
  ["%s (new character profile)"] = "%s (neues Charakterprofil)",
  ["Create a separate profile for %s (copying current settings) and reload the interface?"] =
    "Ein eigenes Profil für %s erstellen (kopiert die aktuellen Einstellungen) und die Oberfläche neu laden?",
  ["Switch this character to profile \"%s\" and reload the interface?"] =
    "Diesen Charakter auf das Profil „%s“ umschalten und die Oberfläche neu laden?",
  ["Switch %s back to the shared Default profile and reload the interface?"] =
    "%s zurück auf das gemeinsame Standardprofil schalten und die Oberfläche neu laden?",
  ["Switch %s to its own profile \"%s\" and reload the interface?"] =
    "%s auf sein eigenes Profil „%s“ umschalten und die Oberfläche neu laden?",
  ["Switch & reload"] = "Wechseln & neu laden",
  ["Switch back to Default (shared)"] = "Zurück zu Standard (geteilt)",
  ["Use %s's profile"] = "Profil von %s nutzen",
  ["Use separate profile for this character"] = "Eigenes Profil für diesen Charakter nutzen",
  ["MODULES IN THIS PROFILE"] = "MODULE IN DIESEM PROFIL",
  ["Enable all"] = "Alle an",
  ["Disable all"] = "Alle aus",
  ["Reload UI to edit the newly selected profile."] =
    "Oberfläche neu laden, um das neu gewählte Profil zu bearbeiten.",
  ["Changes take effect after a reload of the interface."] =
    "Änderungen werden nach einem Neuladen der Oberfläche wirksam.",
  ["Tick which modules run in this profile."] =
    "Hakt an, welche Module in diesem Profil laufen.",
  ["MANAGE PROFILES"] = "PROFILE VERWALTEN",
  ["New profile"] = "Neues Profil",
  ["Create a named profile (e.g. Healer, Tank, Alt) and switch this character to it."] =
    "Erstellt ein benanntes Profil (z. B. Heiler, Tank, Twink) und schaltet diesen Charakter darauf um.",
  ["Copy current"] = "Aktuelles kopieren",
  ["Blank"] = "Leer",
  ["Enter a profile name first."] = "Gebt zuerst einen Profilnamen ein.",
  ["A profile named \"%s\" already exists."] = "Ein Profil namens „%s“ existiert bereits.",
  ["Create profile \"%s\" (copying current settings), switch this character to it and reload?"] =
    "Profil „%s“ erstellen (kopiert aktuelle Einstellungen), darauf umschalten und neu laden?",
  ["Create blank profile \"%s\" (defaults), switch this character to it and reload?"] =
    "Leeres Profil „%s“ (Standardwerte) erstellen, darauf umschalten und neu laden?",
  ["Create & reload"] = "Erstellen & neu laden",
  ["Copy settings from"] = "Einstellungen kopieren von",
  ["Overwrite this profile's settings with a copy from another profile (keeps learned combat data)."] =
    "Überschreibt die Einstellungen dieses Profils mit einer Kopie eines anderen Profils (gelernte Kampfdaten bleiben erhalten).",
  ["Copy"] = "Kopieren",
  ["Copy all settings from \"%s\" into \"%s\" and reload the interface? Learned combat data is kept."] =
    "Alle Einstellungen von „%s“ nach „%s“ kopieren und die Oberfläche neu laden? Gelernte Kampfdaten bleiben erhalten.",
  ["Copy & reload"] = "Kopieren & neu laden",
  ["(no other profiles)"] = "(keine weiteren Profile)",
  ["Delete profile"] = "Profil löschen",
  ["Remove a profile that is not currently in use. Default cannot be deleted."] =
    "Entfernt ein derzeit nicht genutztes Profil. Standard kann nicht gelöscht werden.",
  ["Delete"] = "Löschen",
  ["Delete profile \"%s\"? Any character using it will fall back to Default."] =
    "Profil „%s“ löschen? Jeder Charakter mit diesem Profil fällt auf Standard zurück.",
  ["Deleted profile \"%s\"."] = "Profil „%s“ gelöscht.",
  ["(none to delete)"] = "(nichts zum Löschen)",
  ["Reset profile"] = "Profil zurücksetzen",
  ["Reset all settings in profile \"%s\" to defaults and reload? Learned combat data is kept."] =
    "Alle Einstellungen im Profil „%s“ auf Standardwerte zurücksetzen und neu laden? Gelernte Kampfdaten bleiben erhalten.",
  ["Could not switch profile (%s)."] = "Profil konnte nicht gewechselt werden (%s).",
  ["Could not create profile (%s)."] = "Profil konnte nicht erstellt werden (%s).",
  ["Could not copy profile (%s)."] = "Profil konnte nicht kopiert werden (%s).",
  ["Could not delete profile (%s)."] = "Profil konnte nicht gelöscht werden (%s).",
  ["Profiles: %s"] = "Profile: %s",
  ["Character name is unavailable."] = "Charaktername ist nicht verfügbar.",
  ["Created and selected profile \"%s\" (copied from current). Use /reload to apply."] =
    "Profil „%s“ erstellt und gewählt (vom aktuellen kopiert). Mit /reload anwenden.",
  ["Selected profile \"%s\". Use /reload to apply."] = "Profil „%s“ gewählt. Mit /reload anwenden.",
  ["Selected the shared Default profile. Use /reload to apply."] =
    "Gemeinsames Standardprofil gewählt. Mit /reload anwenden.",
  ["Copied settings from \"%s\" into \"%s\". Use /reload to apply."] =
    "Einstellungen von „%s“ nach „%s“ kopiert. Mit /reload anwenden.",
  ["/upt profile opens Profiles; /upt profile list|char|default|use <name>|new <name>|copy <name>|delete <name>"] =
    "/upt profile öffnet Profile; /upt profile list|char|default|use <Name>|new <Name>|copy <Name>|delete <Name>",

  -- the Debug tab error log
  ["Clear"] = "Leeren",
  ["Test"] = "Testen",
  ["Errors and blocked actions of this addon (%d)"] = "Fehler und blockierte Aktionen dieses Addons (%d)",
  ["Nothing caught since the last reload. Lua errors and \"blocked action\" reports that name this addon appear here with their stack."] =
    "Seit dem letzten Neuladen wurde nichts abgefangen. Lua-Fehler und Meldungen über „blockierte Aktionen“, die dieses Addon nennen, erscheinen hier mit ihrem Stack.",
  ["SPELL NUMBERS (SPELLDAMAGEINFO)"] = "ZAUBERZAHLEN (SPELLDAMAGEINFO)",
  ["DOTS (DOTINFO)"] = "DOTS (DOTINFO)",
  ["CAST PREDICTION"] = "ZAUBERPROGNOSE",
  ["HEAL PREDICTION"] = "HEILUNGSPROGNOSE",
  ["STATS AND BAG ARROWS (STATSINFO)"] = "WERTE UND TASCHENPFEILE (STATSINFO)",
  ["POINTS AND SOUNDS (RESOURCEDING)"] = "PUNKTE UND TÖNE (RESOURCEDING)",
  ["RANGE"] = "REICHWEITE",
  ["PERFORMANCE"] = "LEISTUNG",
  ["FRAMES AND API"] = "FENSTER UND API",

  -- unified ALL-CAPS section headers across module tabs
  ["FILL"] = "FÜLLUNG",
  ["OUTLINE"] = "UMRISS",
  ["KILL ICON"] = "KILL-SYMBOL",
  ["ABSORB NUMBER"] = "ABSORPTIONSZAHL",
  ["POSITION"] = "POSITION",
  ["INDICATORS"] = "ANZEIGEN",
  ["FEATURES"] = "FUNKTIONEN",
  ["EXPERIMENTS (ON BY DEFAULT IN THIS BETA)"] = "EXPERIMENTE (IN DIESER BETA STANDARDMÄSSIG AN)",
})
