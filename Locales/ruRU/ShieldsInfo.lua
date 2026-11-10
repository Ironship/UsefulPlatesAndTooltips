-- UsefulPlatesAndTooltips: русские тексты вкладки ShieldsInfo. Общие правила — в Locales\ruRU\Core.lua.
-- Copyright (c) 2026 Ironship. GPL-3.0-or-later, см. LICENSE.

local _, BIT = ...

BIT.RegisterLocale("ruRU", {
  -- предпросмотр и выбор рамки
  ["Shields sample (fixed data)"] = "Пример щитов (фиксированные данные)",
  ["Bar health"] = "Здоровье полосы",
  ["How full the mock health bar is, in % of its sample maximum."] =
    "Заполнение тестовой полосы здоровья в процентах от максимума примера.",
  ["Shield absorb"] = "Поглощение щитом",
  ["How much of the bar the sample shield covers, in % of its sample maximum. The preview runs on this fixed sample number only."] =
    "Какую часть полосы занимает тестовый щит в процентах от максимума примера. Предпросмотр использует только это фиксированное значение.",
  ["The preview paints a fixed sample with the same painter as the live overlays; no live absorb is read here."] =
    "Предпросмотр использует фиксированный пример и тот же способ отрисовки, что и игровые наложения; реальное поглощение здесь не считывается.",
  ["FRAME"] = "РАМКА",
  ["Nameplate"] = "Табличка",
  ["Your player frame"] = "Ваша рамка игрока",
  ["Your target frame"] = "Ваша рамка цели",
  ["A party frame"] = "Рамка группы",
  ["An enemy nameplate"] = "Табличка противника",

  -- вкладки
  ["Frames"] = "Рамки",
  ["Fill"] = "Заливка",
  ["Extra shield effects land here later. The shared appearance editor below paints the overlay's colour, opacity and text."] =
    "Дополнительные эффекты щитов появятся здесь позже. Общий редактор оформления ниже задаёт цвет, непрозрачность и текст наложения.",

  -- настройки рамок
  ["On your player frame"] = "На рамке игрока",
  ["The shield over your own health bar."] = "Щит поверх вашей полосы здоровья.",
  ["On your target frame"] = "На рамке цели",
  ["The shield over your target's health bar."] = "Щит поверх полосы здоровья вашей цели.",
  ["On your focus frame"] = "На рамке фокуса",
  ["The shield over your focus's health bar."] = "Щит поверх полосы здоровья вашего фокуса.",
  ["On party frames"] = "На рамках группы",
  ["The shields over classic and compact party member frames."] =
    "Щиты поверх классических и компактных рамок участников группы.",
  ["On raid frames"] = "На рамках рейда",
  ["The shields over compact raid member frames."] =
    "Щиты поверх компактных рамок участников рейда.",
  ["Show the absorb number"] =
    "Показывать число поглощения",
  ["How much absorb is left, as a number on the player, target and focus health bars. It also shows in combat. Party, raid and nameplate bars are too small for it."] =
    "Сколько поглощения осталось, числом на полосах здоровья игрока, цели и фокуса. Отображается и в бою. Полосы группы, рейда и табличек для него слишком малы.",
  ["Number position"] =
    "Положение числа",
  ["Left end of the bar"] =
    "Левый край полосы",
  ["Middle of the bar"] =
    "Середина полосы",
  ["Right end of the bar"] =
    "Правый край полосы",
  ["Number size"] =
    "Размер числа",
  ["On nameplates"] = "На табличках",
  ["The shields over every accessible nameplate."] = "Щиты поверх всех доступных табличек.",

  -- заливка
  ["The fill art of the shield overlay: patterns, glass and bevel shadings, Blizzard's bar textures, the shield art and every LibSharedMedia texture; the absorb color tints them."] =
    "Оформление заливки щита: узоры, стеклянные и рельефные эффекты, текстуры полос Blizzard, изображение щита и все текстуры LibSharedMedia; цвет поглощения окрашивает их.",
  ["How solid the shield fill is. 100% is solid; lower lets the health bar under it show through."] =
    "Непрозрачность заливки щита. При 100% заливка сплошная; меньшие значения позволяют видеть полосу здоровья под ней.",
  ["Absorb color"] = "Цвет поглощения",
  ["The color of the shield fill: the shared appearance's absorb color."] =
    "Цвет заливки щита — общий цвет поглощения в настройках оформления.",
  ["Health bar"] = "Полоса здоровья",
  ["Raid bar"] = "Рейдовая полоса",
  ["Shield aura"] = "Аура щита",
  ["Mirrored aura"] = "Отражённая аура",
  ["Shield art"] = "Изображение щита",

  -- шаблоны оформления
  ["Look presets"] = "Шаблоны оформления",
  ["Only the fill style and its opacity change; your frame switches stay."] =
    "Изменятся только стиль и непрозрачность заливки; настройки рамок сохранятся.",
})
