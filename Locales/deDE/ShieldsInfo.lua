-- UsefulPlatesAndTooltips: the German texts of the ShieldsInfo tab. The conventions are in Locales\deDE\Core.lua.
-- Copyright (c) 2026 Ironship. GPL-3.0-or-later, see LICENSE.

local _, BIT = ...

BIT.RegisterLocale("deDE", {
  -- the live preview and its frame switch
  ["Shields sample (fixed data)"] = "Beispiel für Schilde (feste Daten)",
  ["Bar health"] = "Gesundheit",
  ["How full the mock health bar is, in % of its sample maximum."] =
    "Wie voll die Beispiel-Gesundheitsleiste ist, in % ihres Beispielmaximums.",
  ["Shield absorb"] = "Absorption",
  ["How much of the bar the sample shield covers, in % of its sample maximum. The preview runs on this fixed sample number only."] =
    "Wie viel der Leiste das Beispielschild bedeckt, in % seines Beispielmaximums. Die Vorschau läuft nur mit dieser festen Beispielzahl.",
  ["The preview paints a fixed sample with the same painter as the live overlays; no live absorb is read here."] =
    "Die Vorschau zeichnet ein festes Beispiel mit derselben Zeichenroutine wie die echten Überlagerungen; hier wird keine echte Absorption ausgelesen.",
  ["FRAME"] = "FENSTER",
  ["Nameplate"] = "Plakette",
  ["Your player frame"] = "Euer Spielerfenster",
  ["Your target frame"] = "Euer Zielfenster",
  ["A party frame"] = "Ein Gruppenfenster",
  ["An enemy nameplate"] = "Eine gegnerische Namensplakette",

  -- the tabs
  ["Frames"] = "Fenster",
  ["Fill"] = "Füllung",
  ["Extra shield effects land here later. The shared appearance editor below paints the overlay's colour, opacity and text."] =
    "Weitere Schildeffekte folgen später hier. Der gemeinsame Editor für das Aussehen darunter gestaltet Farbe, Deckkraft und Text der Überlagerung.",

  -- the frame switches
  ["On your player frame"] = "Auf Eurem Spielerfenster",
  ["The shield over your own health bar."] = "Das Schild über Eurer eigenen Gesundheitsleiste.",
  ["On your target frame"] = "Auf Eurem Zielfenster",
  ["The shield over your target's health bar."] = "Das Schild über der Gesundheitsleiste Eures Ziels.",
  ["On your focus frame"] = "Auf Eurem Fokusfenster",
  ["The shield over your focus's health bar."] = "Das Schild über der Gesundheitsleiste Eures Fokus.",
  ["On party frames"] = "Auf Gruppenfenstern",
  ["The shields over classic and compact party member frames."] =
    "Die Schilde über den klassischen und kompakten Gruppenmitgliederfenstern.",
  ["On raid frames"] = "Auf Schlachtzugsfenstern",
  ["The shields over compact raid member frames."] =
    "Die Schilde über den kompakten Schlachtzugsmitgliederfenstern.",
  ["On nameplates"] = "Auf Namensplaketten",
  ["The shields over every accessible nameplate."] = "Die Schilde über jeder zugänglichen Namensplakette.",

  -- the fill
  ["The fill art of the shield overlay: patterns, glass and bevel shadings, Blizzard's bar textures, the shield art and every LibSharedMedia texture; the absorb color tints them."] =
    "Die Füllgrafik der Schildüberlagerung: Muster, Glas- und Abschrägungsschattierungen, die Leistentexturen von Blizzard, die Schildgrafik und jede LibSharedMedia-Textur; die Absorptionsfarbe tönt sie.",
  ["How solid the shield fill is. 100% is solid; lower lets the health bar under it show through."] =
    "Wie deckend die Schildfüllung ist. 100% ist deckend; weniger lässt die Gesundheitsleiste darunter durchscheinen.",
  ["Absorb color"] = "Absorptionsfarbe",
  ["The color of the shield fill: the shared appearance's absorb color."] =
    "Die Farbe der Schildfüllung: die Absorptionsfarbe des gemeinsamen Aussehens.",
  ["Health bar"] = "Gesundheitsleiste",
  ["Raid bar"] = "Schlachtzugsleiste",
  ["Shield aura"] = "Schildaura",
  ["Mirrored aura"] = "Gespiegelte Aura",
  ["Shield art"] = "Schildgrafik",

  -- the look presets
  ["Look presets"] = "Stilvorlagen",
  ["Only the fill style and its opacity change; your frame switches stay."] =
    "Nur der Füllstil und seine Deckkraft ändern sich; Eure Fensterschalter bleiben erhalten.",
})
