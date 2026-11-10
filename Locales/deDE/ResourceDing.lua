-- UsefulPlatesAndTooltips: the German texts of the ResourceDing tab. The conventions are in Locales\deDE\Core.lua.
-- Copyright (c) 2026 Ironship. GPL-3.0-or-later, see LICENSE.

local _, BIT = ...

BIT.RegisterLocale("deDE", {
  -- the live preview and its TRY IT block
  ["Soul shards"] = "Seelensplitter",
  ["Vertical offset"] = "Höhenversatz",
  ["Shard diamonds"] = "Splitter-Rauten",
  ["Sample: %d of %d combo points"] = "Beispiel: %d von %d Combopunkten",
  ["Sample: %d of %d combo points (full)"] = "Beispiel: %d von %d Combopunkten (voll)",
  ["Sample: %d of %d soul shards"] = "Beispiel: %d von %d Seelensplittern",
  ["Sample: %d of %d soul shards (full)"] = "Beispiel: %d von %d Seelensplittern (voll)",
  ["Hear a single cue when your class finisher resource reaches maximum. The preview is a silent sample drawn with the live dots and diamonds, not your target."] =
    "Ein einzelner Ton, wenn die Finisher-Ressource Eurer Klasse das Maximum erreicht. Die Vorschau ist ein lautloses Beispiel mit den echten Kreisen und Rauten, nicht Euer Ziel.",
  ["How many combo points or soul shards the sample shows."] =
    "Wie viele Combopunkte oder Seelensplitter das Beispiel zeigt.",
  ["Size of the combo points and soul shards."] = "Größe der Combopunkte und Seelensplitter.",
  ["Offset for the resource in the selected tab."] = "Versatz der Ressource im gewählten Reiter.",
  ["Purple diamonds under the target, the same setting as the Shards tab."] =
    "Lila Rauten unter dem Ziel, dieselbe Einstellung wie im Reiter Splitter.",

  -- the tabs
  ["Shards"] = "Splitter",
  ["Mana"] = "Mana",
  ["Sound"] = "Ton",

  -- the Combo tab
  ["Show the points as dots under the target's nameplate"] =
    "Punkte als Kreise unter der Namensplakette des Ziels zeigen",
  ["Your class resource as circles below the target's health bar. Warlocks use these when shard diamonds are off."] =
    "Eure Klassenressource als Kreise unter der Gesundheitsleiste des Ziels. Hexenmeister nutzen sie, wenn die Splitter-Rauten ausgeschaltet sind.",
  ["Dot / diamond size"] = "Größe der Kreise / Rauten",
  ["How big the circles and the shard diamonds are."] = "Wie groß die Kreise und die Splitter-Rauten sind.",
  ["Dot vertical offset (- = above)"] = "Vertikaler Versatz der Kreise (- = darüber)",
  ["How far the dots sit from the health bar. The same seat as the hunter rail: top of the row, -offset under the bar."] =
    "Wie weit die Kreise von der Gesundheitsleiste entfernt sind. Dieselbe Lage wie bei der Jägerleiste: Oberkante der Reihe, -Versatz unter der Leiste.",

  -- the Shards tab
  ["Sound when a shard comes in"] = "Ton bei jedem neuen Seelensplitter",
  ["One cue for a new whole Soul Shard: player power on Retail, bag items on Classic. This also announces the last shard when the bar fills."] =
    "Ein Ton für jeden neuen ganzen Seelensplitter: auf Retail über die Spielerkraft, auf Classic über die Gegenstände in den Taschen. Er meldet auch den letzten Splitter, wenn die Leiste voll wird.",
  ["Purple diamonds under the target"] = "Lila Rauten unter dem Ziel",
  ["Each Soul Shard as a purple diamond below the target's health bar."] =
    "Jeder Seelensplitter als lila Raute unter der Gesundheitsleiste des Ziels.",
  ["Shard vertical offset (- = above)"] = "Vertikaler Versatz der Splitter-Rauten (- = darüber)",
  ["How far the diamonds sit from the health bar; they move independently of the dots."] =
    "Wie weit die Rauten von der Gesundheitsleiste entfernt sind; sie bewegen sich unabhängig von den Kreisen.",

  -- the Mana tab
  ["Sound when mana reaches the level"] = "Ton, wenn das Mana die Schwelle erreicht",
  ["One cue when your mana climbs back to the level."] = "Ein Ton, wenn Euer Mana wieder auf die Schwelle steigt.",
  ["Mana level, %"] = "Mana-Schwelle, %",
  ["Sound at the level"] = "Ton bei der Schwelle",

  -- the Sound tab
  ["Sounds, dots and diamonds"] = "Töne, Kreise und Rauten",
  ["The whole module: the finisher sound and the marks under the target."] =
    "Das ganze Modul: der Finisher-Ton und die Markierungen unter dem Ziel.",
  ["Only play while in combat"] = "Nur im Kampf abspielen",
  ["Sound when the bar fills"] = "Ton bei voller Leiste",
  ["The cue at full combo points. Unchecked keeps the dots and diamonds and only mutes this sound."] =
    "Der Hinweiston bei vollen Combopunkten. Ohne Haken bleiben Kreise und Rauten, nur dieser Ton ist stumm.",
  ["A full bar out of combat stays quiet; it dings the moment combat starts."] =
    "Eine volle Leiste außerhalb des Kampfes bleibt still; der Ton erklingt, sobald der Kampf beginnt.",
  ["Hear it"] = "Anhören",
  ["Test sound"] = "Ton testen",
  ["Supported: %s. Classes without one of these get no finisher sound."] =
    "Unterstützt: %s. Klassen ohne eine dieser Ressourcen erhalten keinen Finisher-Ton.",

  -- the sounds
  ["Auction House"] = "Auktionshaus",
  ["Ready Check"] = "Bereitschaftscheck",
  ["Quest Complete"] = "Quest abgeschlossen",
  ["Level Up"] = "Stufenaufstieg",
  ["UI Bell"] = "UI-Glocke",
  ["Loot Coins"] = "Beutemünzen",
  ["Raid Warning"] = "Schlachtzugswarnung",

  -- the resources and the detected line
  ["Combo Points"] = "Combopunkte",
  ["Chi"] = "Chi",
  ["Holy Power"] = "Heilige Kraft",
  ["Soul Shards"] = "Seelensplitter",
  ["Arcane Charges"] = "Arkane Ladungen",
  ["Essence"] = "Essenz",
  ["Detected: %s (%d / %d)"] = "Erkannt: %s (%d / %d)",
  ["Detected: %s (count hidden by the game)"] = "Erkannt: %s (Anzahl vom Spiel verborgen)",
  ["Detected: %s (inactive for this spec/form)"] = "Erkannt: %s (für diese Spezialisierung/Gestalt inaktiv)",
  ["No finisher resource for this class"] = "Keine Finisher-Ressource für diese Klasse",

  -- the appearance sample
  ["ResourceDing sample (silent, not your target)"] = "ResourceDing-Beispiel (lautlos, nicht Euer Ziel)",
  ["3 of 5"] = "3 von 5",
  ["5 of 5 (full)"] = "5 von 5 (voll)",

  -- the /rding command
  ["|cff66ccffResourceDing:|r enabled"] = "|cff66ccffResourceDing:|r aktiviert",
  ["|cff66ccffResourceDing:|r disabled"] = "|cff66ccffResourceDing:|r deaktiviert",
})
