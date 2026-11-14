-- UsefulPlatesAndTooltips: the German texts of the HealPrediction tab. The conventions are in Locales\deDE\Core.lua.
-- Copyright (c) 2026 Ironship. GPL-3.0-or-later, see LICENSE.

local _, BIT = ...

BIT.RegisterLocale("deDE", {
  -- the live preview and its TRY IT block
  ["Incoming heal"] = "Heilung",
  ["HealPrediction sample"] = "Heilungsprognose-Beispiel",
  ["+25 incoming, from the health edge"] = "+25 eingehend, ab der Gesundheitskante",
  ["The Target frame option controls this sample; the other frame options control live frames. The segment starts at the health edge (the green bar's end) and is cropped at the bar's right end when the heal would overheal."] =
    "Die Option Zielfenster steuert dieses Beispiel; die anderen Fensteroptionen steuern die echten Fenster. Das Segment beginnt an der Gesundheitskante (dem Ende der grünen Leiste) und wird am rechten Ende der Leiste abgeschnitten, wenn die Heilung überheilen würde.",
  ["The client already knows how much healing is coming (UnitGetIncomingHeals). This module redraws direct heals and adds estimates for your own heals over time."] =
    "Der Client weiß bereits, wie viel Heilung eingeht (UnitGetIncomingHeals). Dieses Modul zeichnet direkte Heilung neu und ergänzt Schätzungen für Eure eigene Heilung über Zeit.",

  -- the frames
  ["Target frame"] = "Zielfenster",
  ["The segment starts where the target's green ends and reaches as far as the incoming heal will."] =
    "Das Segment beginnt dort, wo das Grün des Ziels endet, und reicht so weit, wie die eingehende Heilung reichen wird.",
  ["Player frame"] = "Spielerfenster",
  ["Your own health bar."] = "Eure eigene Gesundheitsleiste.",
  ["Focus frame"] = "Fokusfenster",
  ["Incoming heals and your HoTs on your focus."] = "Eingehende Heilung und Eure HoTs auf Eurem Fokus.",
  ["Target of target frame"] = "Ziel-des-Ziels-Fenster",
  ["Blizzard's small target-of-target health bar, including when it shows you."] =
    "Blizzards kleine Gesundheitsleiste für das Ziel des Ziels, auch wenn sie Euch zeigt.",
  ["Party frames"] = "Gruppenfenster",
  ["Blizzard's classic party frames and the compact party members."] =
    "Blizzards klassische Gruppenfenster und die kompakten Gruppenmitglieder.",
  ["Raid frames"] = "Schlachtzugsfenster",
  ["The compact raid members (CompactRaidFrameContainer), including the EllesmereUI raid members."] =
    "Die kompakten Schlachtzugsmitglieder (CompactRaidFrameContainer), einschließlich der Schlachtzugsmitglieder von EllesmereUI.",

  -- the numbers
  ["THE NUMBERS"] = "DIE ZAHLEN",
  ["All healers"] = "Alle Heiler",
  ["Ask the client for its total incoming healing (every healer it tracks) instead of only your own. Where the client cannot tell the two apart, both read the same."] =
    "Den Client nach seiner gesamten eingehenden Heilung fragen (jeder Heiler, den er verfolgt), statt nur nach Eurer eigenen. Wo der Client die beiden nicht unterscheiden kann, liefern beide denselben Wert.",
  ["Other healers' share"] = "Anteil anderer Heiler",
  ["A second band behind yours for the part of the client's total that is not yours. Where the client cannot tell healers apart the band simply stays hidden."] =
    "Ein zweites Band hinter Eurem für den Teil der Gesamtsumme des Clients, der nicht von Euch stammt. Wo der Client Heiler nicht unterscheiden kann, bleibt das Band einfach verborgen.",
  ["My heals over time"] = "Meine Heilung über Zeit",
  ["Rejuvenation, Renew, Regrowth and Riptide are not part of the client's projection. After you cast one, the amount its description promises is drawn after your direct heal for the whole remaining effect, or only for the horizon below when that is switched off. Refreshing another rank replaces the old estimate. Wild Growth uses a linear estimate on readable buff recipients or its known primary cast target, not guessed party recipients. Channels, pet heals and triggered heals are not treated as target HoTs. Readable own buffs recover existing effects and removals; when aura data is hidden, the last known expiry is used."] =
    "Rejuvenation, Renew, Regrowth und Riptide sind nicht Teil der Projektion des Clients. Nachdem Ihr einen davon gewirkt habt, wird die Menge, die seine Beschreibung verspricht, nach Eurer direkten Heilung für den gesamten Resteffekt eingezeichnet, oder nur für die Vorausschau unten, wenn diese ausgeschaltet ist. Wird ein anderer Rang aufgefrischt, ersetzt er die alte Schätzung. Wild Growth nutzt eine lineare Schätzung für Empfänger mit lesbarem Stärkungszauber oder für sein bekanntes primäres Wirkziel, nicht für geratene Gruppenempfänger. Kanalisierungen, Begleiterheilungen und ausgelöste Heilungen werden nicht als HoTs auf dem Ziel behandelt. Lesbare eigene Stärkungszauber erfassen bereits laufende Effekte und Entfernungen nachträglich; sind die Auradaten verborgen, wird der zuletzt bekannte Ablaufzeitpunkt verwendet.",
  ["Whole remaining effect"] = "Gesamter Resteffekt",
  ["Draw all the healing each of your heals over time still has to do, to its end, instead of only its next few seconds. A fresh Rejuvenation shows its full total, which runs down as the ticks land. The number shows the same total."] =
    "Zeichnet die gesamte Heilung, die jede Eurer Heilungen über Zeit noch wirken wird, bis zu ihrem Ende, statt nur ihrer nächsten Sekunden. Eine frische Verjüngung zeigt ihre volle Summe, die mit jedem Tick abnimmt. Die Zahl zeigt dieselbe Summe.",
  ["Food on my frame"] = "Essen auf meinem Fenster",
  ["While you eat, the health the food still has to give is drawn on your own health bar, like a heal over time (food is an item's effect, not a heal you cast). A potion works at once and has nothing to show."] =
    "Während Ihr esst, wird die Gesundheit, die das Essen noch gibt, auf Eurer eigenen Gesundheitsleiste wie eine Heilung über Zeit eingezeichnet (Essen ist der Effekt eines Gegenstands, keine gewirkte Heilung). Ein Trank wirkt sofort und hat nichts zu zeigen.",
  ["Drinks on my mana bar"] = "Getränke auf meiner Manaleiste",
  ["While you drink, the mana the drink still has to give is drawn on your own mana bar, from the end of your current mana."] =
    "Während Ihr trinkt, wird das Mana, das das Getränk noch gibt, auf Eurer eigenen Manaleiste eingezeichnet, ab dem Ende Eures aktuellen Manas.",
  ["Heal over time horizon"] = "Vorausschau: Heilung über Zeit",
  ["How many seconds of each heal over time are drawn ahead. Used only when Whole remaining effect is off."] =
    "Wie viele Sekunden jeder Heilung über Zeit im Voraus eingezeichnet werden. Wird nur verwendet, wenn Gesamter Resteffekt ausgeschaltet ist.",

  -- the segment
  ["THE SEGMENT"] = "DAS SEGMENT",
  ["The fill of the incoming-heal segment: patterns, glass and bevel shadings, Blizzard's bar textures and every LibSharedMedia texture; the color tints them."] =
    "Die Füllung des Segments für eingehende Heilung: Muster, Glas- und Abschrägungsschattierungen, die Leistentexturen von Blizzard und jede LibSharedMedia-Textur; die Farbe tönt sie.",
  ["The incoming-heal segment's own color, or Custom color... for any you like; absorbs keep ShieldsInfo's look."] =
    "Die eigene Farbe des Segments für eingehende Heilung oder Eigene Farbe... für eine beliebige; Absorptionen behalten das Aussehen von ShieldsInfo.",
  ["Other healers' fill style"] = "Füllstil: andere Heiler",
  ["Other healers' fill color"] = "Füllfarbe: andere Heiler",
  ["Other healers' fill opacity"] = "Deckkraft: andere Heiler",
  ["Heal over time fill style"] = "Füllstil: Heilung über Zeit",
  ["Heal over time fill color"] = "Füllfarbe: Heilung über Zeit",
  ["Heal over time fill opacity"] = "Deckkraft: Heilung über Zeit",
  ["How tall the segment is against the health bar; the top edge is the anchor."] =
    "Wie hoch das Segment im Verhältnis zur Gesundheitsleiste ist; die Oberkante ist der Anker.",
  ["Show a number"] = "Zahl zeigen",
  ["A small ~ number for the direct heal plus your heals over time at the segment's right end, when the amounts are readable."] =
    "Eine kleine ~-Zahl für die direkte Heilung plus Eure Heilung über Zeit am rechten Ende des Segments, wenn die Mengen lesbar sind.",

  -- diagnostics
  ["DIAGNOSTICS"] = "DIAGNOSE",
  ["What the client says"] = "Was der Client meldet",
  ["Prints UnitGetIncomingHeals for you and your group to chat, and the same to the log."] =
    "Gibt UnitGetIncomingHeals für Euch und Eure Gruppe im Chat aus, und dasselbe ins Protokoll.",
  ["Debug lines in chat"] = "Debug-Zeilen im Chat",
  ["Echo the module's notes while it reads and draws."] =
    "Gibt die Notizen des Moduls aus, während es liest und zeichnet.",
  ["The number is the client's own incoming-heal projection (UnitGetIncomingHeals) - the same one Blizzard's raid frames use. This module only redraws direct heals; your own targeted HoTs are separate estimates from readable descriptions and spell power, independent of SpellDamageInfo's display settings. No crit guesses or addon messages. Hidden native values go unchanged to the bars. /upt healprobe prints what is readable."] =
    "Die Zahl ist die eigene Projektion des Clients für eingehende Heilung (UnitGetIncomingHeals) - dieselbe, die die Schlachtzugsfenster von Blizzard verwenden. Dieses Modul zeichnet nur direkte Heilung neu; Eure eigenen gezielten HoTs sind getrennte Schätzungen aus lesbaren Beschreibungen und Zaubermacht, unabhängig von den Anzeigeeinstellungen von SpellDamageInfo. Keine Schätzungen kritischer Treffer und keine Addon-Nachrichten. Verborgene native Werte gehen unverändert an die Leisten. /upt healprobe gibt aus, was lesbar ist.",
})
