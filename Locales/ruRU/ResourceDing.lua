-- UsefulPlatesAndTooltips: русские тексты вкладки ResourceDing. Общие правила — в Locales\ruRU\Core.lua.
-- Copyright (c) 2026 Ironship. GPL-3.0-or-later, см. LICENSE.

local _, BIT = ...

BIT.RegisterLocale("ruRU", {
  -- предпросмотр и блок «Попробуйте»
  ["Soul shards"] = "Осколки души",
  ["Vertical offset"] = "Смещение по вертикали",
  ["Shard diamonds"] = "Ромбы осколков",
  ["Sample: %d of %d combo points"] = "Пример: %d из %d очков серии приёмов",
  ["Sample: %d of %d combo points (full)"] = "Пример: %d из %d очков серии приёмов (полная серия)",
  ["Sample: %d of %d soul shards"] = "Пример: %d из %d осколков души",
  ["Sample: %d of %d soul shards (full)"] = "Пример: %d из %d осколков души (полный запас)",
  ["Hear a single cue when your class finisher resource reaches maximum. The preview is a silent sample drawn with the live dots and diamonds, not your target."] =
    "Услышать одиночный сигнал, когда ресурс завершающего приёма вашего класса достигнет максимума. Предпросмотр — беззвучный пример с теми же точками и ромбами, он не отображается на вашей цели.",
  ["How many combo points or soul shards the sample shows."] =
    "Количество очков серии приёмов или осколков души в примере.",
  ["Size of the combo points and soul shards."] = "Размер точек серии приёмов и осколков души.",
  ["Offset for the resource in the selected tab."] = "Смещение ресурса на выбранной вкладке.",
  ["Purple diamonds under the target, the same setting as the Shards tab."] =
    "Пурпурные ромбы под целью; настройка совпадает с вкладкой «Осколки».",

  -- вкладки
  ["Shards"] = "Осколки",
  ["Mana"] = "Мана",
  ["Sound"] = "Звук",

  -- вкладка «Серия приёмов»
  ["Show the points as dots under the target's nameplate"] =
    "Показывать точки под табличкой цели",
  ["Your class resource as circles below the target's health bar. Warlocks use these when shard diamonds are off."] =
    "Ресурс класса отображается кружками под полосой здоровья цели. Чернокнижники используют их, когда ромбы осколков отключены.",
  ["Dot / diamond size"] = "Размер точек / ромбов",
  ["How big the circles and the shard diamonds are."] = "Размер кружков и ромбов осколков.",
  ["Dot vertical offset (- = above)"] = "Смещение точек по вертикали (− = вверх)",
  ["How far the dots sit from the health bar. The same seat as the hunter rail: top of the row, -offset under the bar."] =
    "Расстояние точек от полосы здоровья. Положение такое же, как у шкалы охотника: верхний край ряда, смещение под полосой со знаком минус.",

  -- вкладка «Осколки»
  ["Sound when a shard comes in"] = "Звук при получении осколка",
  ["One cue for a new whole Soul Shard: player power on Retail, bag items on Classic. This also announces the last shard when the bar fills."] =
    "Одиночный сигнал при получении целого осколка души: на Retail — по ресурсу игрока, на Classic — по предметам в сумках. Сигнал также звучит при получении последнего осколка и заполнении полосы.",
  ["Purple diamonds under the target"] = "Пурпурные ромбы под целью",
  ["Each Soul Shard as a purple diamond below the target's health bar."] =
    "Каждый осколок души отображается пурпурным ромбом под полосой здоровья цели.",
  ["Shard vertical offset (- = above)"] = "Смещение ромбов по вертикали (− = вверх)",
  ["How far the diamonds sit from the health bar; they move independently of the dots."] =
    "Расстояние ромбов от полосы здоровья; они перемещаются независимо от точек.",

  -- вкладка «Мана»
  ["Sound when mana reaches the level"] = "Звук при достижении уровня маны",
  ["One cue when your mana climbs back to the level."] = "Одиночный сигнал, когда запас маны снова достигнет заданного уровня.",
  ["Mana level, %"] = "Уровень маны, %",
  ["Sound at the level"] = "Звук при достижении уровня",

  -- вкладка «Звук»
  ["Sounds, dots and diamonds"] = "Звуки, точки и ромбы",
  ["The whole module: the finisher sound and the marks under the target."] =
    "Весь модуль: звук завершающего приёма и отметки под целью.",
  ["Only play while in combat"] = "Воспроизводить только в бою",
  ["Sound when the bar fills"] = "Звук при заполнении шкалы",
  ["The cue at full combo points. Unchecked keeps the dots and diamonds and only mutes this sound."] =
    "Сигнал при полной серии приемов. Без галочки точки и ромбы остаются, отключается только этот звук.",
  ["A full bar out of combat stays quiet; it dings the moment combat starts."] =
    "Полная полоса вне боя не издаёт звуков; сигнал прозвучит при начале боя.",
  ["Hear it"] = "Прослушать",
  ["Test sound"] = "Проверить звук",
  ["Supported: %s. Classes without one of these get no finisher sound."] =
    "Поддерживается: %s. Для классов без такого ресурса звук завершающего приёма недоступен.",

  -- звуки
  ["Auction House"] = "Аукцион",
  ["Ready Check"] = "Проверка готовности",
  ["Quest Complete"] = "Задание выполнено",
  ["Level Up"] = "Новый уровень",
  ["UI Bell"] = "Сигнал интерфейса",
  ["Loot Coins"] = "Монеты добычи",
  ["Raid Warning"] = "Рейдовое предупреждение",

  -- ресурсы и строка распознавания
  ["Combo Points"] = "Очки серии приёмов",
  ["Chi"] = "Энергия ци",
  ["Holy Power"] = "Энергия Света",
  ["Soul Shards"] = "Осколки души",
  ["Arcane Charges"] = "Чародейские заряды",
  ["Essence"] = "Энергия",
  ["Detected: %s (%d / %d)"] = "Обнаружено: %s (%d / %d)",
  ["Detected: %s (count hidden by the game)"] = "Обнаружено: %s (количество скрыто игрой)",
  ["Detected: %s (inactive for this spec/form)"] = "Обнаружено: %s (неактивно для этой специализации/формы)",
  ["No finisher resource for this class"] = "У этого класса нет ресурса завершающего приёма",

  -- пример оформления
  ["ResourceDing sample (silent, not your target)"] = "Пример ResourceDing (без звука, не ваша цель)",
  ["3 of 5"] = "3 из 5",
  ["5 of 5 (full)"] = "5 из 5 (полный запас)",

  -- команда /rding
  ["|cff66ccffResourceDing:|r enabled"] = "|cff66ccffResourceDing:|r включён",
  ["|cff66ccffResourceDing:|r disabled"] = "|cff66ccffResourceDing:|r выключен",
})
