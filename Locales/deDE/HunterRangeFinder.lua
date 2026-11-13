-- UsefulPlatesAndTooltips: the German texts of the HunterRangeFinder tab. The conventions are in Locales\deDE\Core.lua.
-- Copyright (c) 2026 Ironship. GPL-3.0-or-later, see LICENSE.

local _, BIT = ...

BIT.RegisterLocale("deDE", {
  -- the tab strip and the class note
  ["Rail"] = "Jägerleiste",
  ["The rail rides above the target's nameplate while a living hostile target is selected; unlock to drag it to a screen spot of your own."] =
    "Die Leiste sitzt über der Namensplakette des Ziels, solange ein lebendes feindliches Ziel gewählt ist; entsperrt sie, um sie an eine Stelle Eurer Wahl auf dem Bildschirm zu ziehen.",
  ["The native range rail appears only on a Hunter. On another class these settings wait for the hunter alt; the preview and the appearance editor need no hunter and no target."] =
    "Die native Reichweitenleiste erscheint nur bei einem Jäger. Bei einer anderen Klasse warten diese Einstellungen auf Euren Jäger; die Vorschau und der Editor für das Aussehen brauchen weder einen Jäger noch ein Ziel.",

  -- the Display tab
  ["Unlock and move"] = "Entsperren",
  ["Lock position"] = "Sperren",
  ["Unlock and drag the rail to a screen spot of your own. It locks when you leave this page."] =
    "Entsperren und die Leiste an eine Stelle Eurer Wahl ziehen. Beim Verlassen dieser Seite wird sie gesperrt.",
  ["Dragged position"] = "Verschobene Position",
  ["Reset position"] = "Zurücksetzen",
  ["Back to the requested centre offset."] = "Zurück zum vorgegebenen Versatz von der Bildschirmmitte.",
  ["Attach to target nameplate"] = "An Namensplakette des Ziels anheften",
  ["The rail rides above the target's nameplate, like the ResourceDing dots. It is hidden when that plate is not visible. Unchecked keeps the draggable screen position."] =
    "Die Leiste sitzt über der Namensplakette des Ziels, wie die Kreise von ResourceDing. Ist die Plakette nicht sichtbar, wird die Leiste ausgeblendet. Ohne Häkchen bleibt die verschiebbare Bildschirmposition erhalten.",
  ["Vertical offset (- = above)"] = "Vertikaler Versatz (- = darüber)",
  ["How far the rail sits from the plate's health bar. The same seat as the combo dots: top of the row, -offset under the bar."] =
    "Wie weit die Leiste von der Gesundheitsleiste der Plakette entfernt sitzt. Derselbe Platz wie bei den Combopunkten: Oberkante der Reihe, -Versatz unter der Leiste.",
  ["Show range text"] = "Reichweitentext zeigen",
  ["The label under the rail (25-30 yd, MELEE, DEAD ZONE). Unchecked keeps only the coloured rail and the MELEE / Dead Zone icons."] =
    "Die Beschriftung unter der Leiste (25-30 m, NAHKAMPF, TOTZONE). Ohne Häkchen bleiben nur die farbige Leiste und die Symbole für Nahkampf / Totzone.",
  ["Show Dead Zone skull (native)"] = "Totzonen-Totenkopf zeigen (nativ)",
  ["Native Blizzard raid skull for the 5-8 yd dead zone. Unchecked hides it."] =
    "Nativer Totenkopf (Schlachtzugssymbol) von Blizzard für die Totzone von 5-8 m. Ohne Häkchen wird er ausgeblendet.",
  ["Show Melee mark (native sword)"] = "Nahkampf-Schwert zeigen (nativ)",
  ["Native Blizzard sword glyph for melee reach. Unchecked hides it."] =
    "Natives Blizzard-Schwertsymbol für die Nahkampfreichweite. Ohne Häkchen wird es ausgeblendet.",

  -- the Range tab
  ["Extended range past 35 yd (Hawk Eye)"] = "Erweiterte Reichweite über 35 m (Hawk Eye)",
  ["Seven dots instead of six. Auto-detected from Auto Shot's reach when the spellbook answers; tick manually otherwise."] =
    "Sieben Punkte statt sechs. Wird automatisch aus der Reichweite von Auto Shot erkannt, wenn das Zauberbuch antwortet; andernfalls das Häkchen selbst setzen.",
  ["Auto Shot's reach reads"] = "Reichweite laut Auto Shot",
  ["Auto Shot's own maximum range, read from the spellbook. Past 35 yd the seventh dot exists."] =
    "Die eigene Maximalreichweite von Auto Shot, aus dem Zauberbuch gelesen. Jenseits von 35 m gibt es den siebten Punkt.",
  ["%s yd"] = "%s m",
  ["not answered by this client"] = "von diesem Client nicht beantwortet",
  ["The bands are approximate item probes, never exact yards: 8-10, 10-15, 15-20, 20-25, 25-30 and 30-35 yd. MELEE is Wing Clip's reach; the 5-8 yd dead zone sits between melee and the first dot. /upt hunterprobe prints what the client answers for the probes."] =
    "Die Bereiche sind ungefähre Gegenstandsproben, keine exakten Meter: 8-10, 10-15, 15-20, 20-25, 25-30 und 30-35 m. NAHKAMPF ist die Reichweite von Wing Clip; die Totzone von 5-8 m liegt zwischen Nahkampf und dem ersten Punkt. /upt hunterprobe gibt aus, was der Client für die Proben antwortet.",

  -- the Appearance tab (the shape choice; the rest is shared)

  -- the live preview and its band switch
  ["Target band"] = "Zielbereich",
  ["Walks the mock target through every band the rail shows: Y10 to Y35, the 35+ yd seventh dot, MELEE and the dead zone."] =
    "Führt das Beispielziel durch jeden Bereich, den die Leiste zeigt: Y10 bis Y35, den siebten Punkt bei 35+ m, NAHKAMPF und die Totzone.",
  ["Drawn by the same code as the live HUD, on a mock enemy nameplate. Six dots by default; a seventh past 35 yd only with Hawk Eye."] =
    "Vom selben Code gezeichnet wie das echte HUD, auf einer gegnerischen Beispiel-Namensplakette. Standardmäßig sechs Punkte; ein siebter jenseits von 35 m nur mit Hawk Eye.",

  -- the labels under the rail and the band switch texts (display only; the band ids stay Y10 .. DEAD)
  ["8-10 yd"] = "8-10 m",
  ["10-15 yd"] = "10-15 m",
  ["15-20 yd"] = "15-20 m",
  ["20-25 yd"] = "20-25 m",
  ["25-30 yd"] = "25-30 m",
  ["30-35 yd"] = "30-35 m",
  ["35+ yd"] = "35+ m",
  ["MELEE"] = "NAHKAMPF",
  ["DEAD ZONE"] = "TOTZONE",
  ["Y10  8-10 yd"] = "Y10  8-10 m",
  ["Y15  10-15 yd"] = "Y15  10-15 m",
  ["Y20  15-20 yd"] = "Y20  15-20 m",
  ["Y25  20-25 yd"] = "Y25  20-25 m",
  ["Y30  25-30 yd"] = "Y30  25-30 m",
  ["Y35  30-35 yd"] = "Y35  30-35 m",
  ["MAX  35+ yd (seventh dot)"] = "MAX  35+ m (siebter Punkt)",
  ["MELEE  Wing Clip's reach"] = "NAHKAMPF  Wing Clip",
  ["DEAD  5-8 yd dead zone"] = "TOTZONE  5-8 m",
})
