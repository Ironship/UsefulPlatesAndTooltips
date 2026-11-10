-- UsefulPlatesAndTooltips: русские тексты вкладки HunterRangeFinder. Общие правила — в Locales\ruRU\Core.lua.
-- Copyright (c) 2026 Ironship. GPL-3.0-or-later, см. LICENSE.

local _, BIT = ...

BIT.RegisterLocale("ruRU", {
  -- вкладка и примечание для класса
  ["Rail"] = "Шкала",
  ["The rail rides above the target's nameplate while a living hostile target is selected; unlock to drag it to a screen spot of your own."] =
    "Шкала отображается над табличкой выбранной живой враждебной цели; разблокируйте её, чтобы перетащить в любое место экрана.",
  ["The native range rail appears only on a Hunter. On another class these settings wait for the hunter alt; the preview and the appearance editor need no hunter and no target."] =
    "Системная шкала дальности отображается только у охотника. Для других классов эти настройки доступны персонажу-охотнику; предпросмотр и редактор оформления не требуют ни охотника, ни цели.",

  -- вкладка «Отображение»
  ["Unlock and move"] = "Разблокировать и переместить",
  ["Lock position"] = "Закрепить положение",
  ["Unlock, drag the rail to a screen spot of your own, then lock to save its position."] =
    "Разблокируйте шкалу, перетащите её в нужное место на экране, затем закрепите, чтобы сохранить положение.",
  ["Dragged position"] = "Перемещённое положение",
  ["Reset position"] = "Сбросить положение",
  ["Back to the requested centre offset."] = "Вернуться к заданному смещению от центра.",
  ["Attach to target nameplate"] = "Закрепить на табличке цели",
  ["The rail rides above the target's nameplate, like the ResourceDing dots. Unchecked keeps the draggable screen position."] =
    "Шкала отображается над табличкой цели, как точки ResourceDing. Если снять флажок, сохранится возможность перемещать её по экрану.",
  ["Vertical offset (- = above)"] = "Смещение по вертикали (− = вверх)",
  ["How far the rail sits from the plate's health bar. The same seat as the combo dots: top of the row, -offset under the bar."] =
    "Расстояние шкалы от полосы здоровья таблички. Положение такое же, как у точек серии приёмов: верхний край ряда, смещение под полосой со знаком минус.",
  ["Show range text"] = "Показывать дальность текстом",
  ["The label under the rail (25-30 yd, MELEE, DEAD ZONE). Unchecked keeps only the coloured rail and the MELEE / Dead Zone icons."] =
    "Подпись под шкалой (25–30 м, БЛИЖНИЙ БОЙ, МЁРТВАЯ ЗОНА). Если снять флажок, останется только цветная шкала и значки ближнего боя и мёртвой зоны.",
  ["Show Dead Zone skull (native)"] = "Показывать череп мёртвой зоны (системный)",
  ["Native Blizzard raid skull for the 5-8 yd dead zone. Unchecked hides it."] =
    "Системный рейдовый череп Blizzard для мёртвой зоны 5–8 м. Если снять флажок, он будет скрыт.",
  ["Show Melee mark (native sword)"] = "Показывать отметку ближнего боя (системный меч)",
  ["Native Blizzard sword glyph for melee reach. Unchecked hides it."] =
    "Системный значок меча Blizzard для дистанции ближнего боя. Если снять флажок, он будет скрыт.",

  -- вкладка «Дальность»
  ["Extended range past 35 yd (Hawk Eye)"] = "Дальность свыше 35 м (Орлиный глаз)",
  ["Seven dots instead of six. Auto-detected from Auto Shot's reach when the spellbook answers; tick manually otherwise."] =
    "Семь точек вместо шести. Автоматически определяется по дальности Автоматической стрельбы, если доступна книга заклинаний; иначе отметьте вручную.",
  ["Auto Shot's reach reads"] = "Дальность автоматической стрельбы",
  ["Auto Shot's own maximum range, read from the spellbook. Past 35 yd the seventh dot exists."] =
    "Максимальная дальность автоматической стрельбы по данным книги заклинаний. За пределом 35 м появляется седьмая точка.",
  ["%s yd"] = "%s м",
  ["not answered by this client"] = "клиент не предоставил данные",
  ["The bands are approximate item probes, never exact yards: 8-10, 10-15, 15-20, 20-25, 25-30 and 30-35 yd. MELEE is Wing Clip's reach; the 5-8 yd dead zone sits between melee and the first dot. /upt hunterprobe prints what the client answers for the probes."] =
    "Диапазоны определяются приблизительно по предметам и не являются точными значениями в метрах: 8–10, 10–15, 15–20, 20–25, 25–30 и 30–35 м. БЛИЖНИЙ БОЙ соответствует дальности Подрезать крылья; мёртвая зона 5–8 м находится между ближним боем и первой точкой. Команда /upt hunterprobe выводит ответы клиента для проверок.",

  -- вкладка «Оформление» (настройка формы; остальные параметры общие)

  -- предпросмотр и переключение диапазонов
  ["Target band"] = "Диапазон цели",
  ["Walks the mock target through every band the rail shows: Y10 to Y35, the 35+ yd seventh dot, MELEE and the dead zone."] =
    "Переключает тестовую цель между диапазонами шкалы: Y10–Y35, седьмая точка за 35 м, ближний бой и мёртвая зона.",
  ["Drawn by the same code as the live HUD, on a mock enemy nameplate. Six dots by default; a seventh past 35 yd only with Hawk Eye."] =
    "Отображается тем же кодом, что и игровой интерфейс, на тестовой табличке противника. По умолчанию шесть точек; седьмая за 35 м появляется только с «Орлиным глазом».",

  -- подписи под шкалой и переключатели диапазона (идентификаторы диапазонов остаются Y10 .. DEAD)
  ["8-10 yd"] = "8–10 м",
  ["10-15 yd"] = "10–15 м",
  ["15-20 yd"] = "15–20 м",
  ["20-25 yd"] = "20–25 м",
  ["25-30 yd"] = "25–30 м",
  ["30-35 yd"] = "30–35 м",
  ["35+ yd"] = "35+ м",
  ["MELEE"] = "БЛИЖНИЙ БОЙ",
  ["DEAD ZONE"] = "МЁРТВАЯ ЗОНА",
  ["Y10  8-10 yd"] = "Y10  8–10 м",
  ["Y15  10-15 yd"] = "Y15  10–15 м",
  ["Y20  15-20 yd"] = "Y20  15–20 м",
  ["Y25  20-25 yd"] = "Y25  20–25 м",
  ["Y30  25-30 yd"] = "Y30  25–30 м",
  ["Y35  30-35 yd"] = "Y35  30–35 м",
  ["MAX  35+ yd (seventh dot)"] = "MAX  35+ м (седьмая точка)",
  ["MELEE  Wing Clip's reach"] = "БЛИЖНИЙ БОЙ  дальность Подрезать крылья",
  ["DEAD  5-8 yd dead zone"] = "МЁРТВАЯ ЗОНА  5–8 м",
})
