-- UsefulPlatesAndTooltips: русские тексты вкладки HealPrediction. Общие правила — в Locales\ruRU\Core.lua.
-- Copyright (c) 2026 Ironship. GPL-3.0-or-later, см. LICENSE.

local _, BIT = ...

BIT.RegisterLocale("ruRU", {
  -- предпросмотр и блок «Попробуйте»
  ["Incoming heal"] = "Входящее исцеление",
  ["HealPrediction sample"] = "Пример HealPrediction",
  ["+25 incoming, from the health edge"] = "+25 исцеления от края полосы здоровья",
  ["The Target frame option controls this sample; the other frame options control live frames. The segment starts at the health edge (the green bar's end) and is cropped at the bar's right end when the heal would overheal."] =
    "Этим примером управляет настройка рамки цели; остальные настройки рамок относятся к игровым рамкам. Сегмент начинается у края здоровья (конца зелёной полосы) и обрезается у правого края полосы, если исцеление превысит недостающее здоровье.",
  ["The client already knows how much healing is coming (UnitGetIncomingHeals). This module redraws direct heals and adds estimates for your own heals over time."] =
    "Клиент уже знает объём входящего исцеления (UnitGetIncomingHeals). Этот модуль отображает прямое исцеление и добавляет оценку ваших эффектов исцеления со временем.",

  -- рамки
  ["Target frame"] = "Рамка цели",
  ["The segment starts where the target's green ends and reaches as far as the incoming heal will."] =
    "Сегмент начинается там, где заканчивается зелёная полоса цели, и продолжается на величину входящего исцеления.",
  ["Player frame"] = "Рамка игрока",
  ["Your own health bar."] = "Ваша полоса здоровья.",
  ["Focus frame"] = "Рамка фокуса",
  ["Incoming heals and your HoTs on your focus."] = "Входящее исцеление и ваши периодические эффекты на фокусе.",
  ["Target of target frame"] = "Рамка цели цели",
  ["Blizzard's small target-of-target health bar, including when it shows you."] =
    "Небольшая полоса здоровья цели цели от Blizzard, в том числе когда на ней отображаетесь вы.",
  ["Party frames"] = "Рамки группы",
  ["Blizzard's classic party frames and the compact party members."] =
    "Классические и компактные рамки участников группы Blizzard.",
  ["Raid frames"] = "Рамки рейда",
  ["The compact raid members (CompactRaidFrameContainer), including the EllesmereUI raid members."] =
    "Компактные рамки участников рейда (CompactRaidFrameContainer), включая рамки рейда EllesmereUI.",

  -- числовые значения
  ["THE NUMBERS"] = "ЧИСЛА",
  ["All healers"] = "Все целители",
  ["Ask the client for its total incoming healing (every healer it tracks) instead of only your own. Where the client cannot tell the two apart, both read the same."] =
    "Запрашивать у клиента общий объём входящего исцеления (от всех отслеживаемых целителей), а не только ваш. Если клиент не различает их, оба значения будут одинаковы.",
  ["Other healers' share"] = "Доля других целителей",
  ["A second band behind yours for the part of the client's total that is not yours. Where the client cannot tell healers apart the band simply stays hidden."] =
    "Вторая полоса за вашей показывает часть общего исцеления клиента, полученную не от вас. Если клиент не различает целителей, эта полоса скрыта.",
  ["My heals over time"] = "Моё периодическое исцеление",
  ["Rejuvenation, Renew, Regrowth and Riptide are not part of the client's projection. After you cast one, the amount its description promises is drawn after your direct heal for the next few seconds of the effect. Refreshing another rank replaces the old estimate. Wild Growth uses a linear estimate on readable buff recipients or its known primary cast target, not guessed party recipients. Channels, pet heals and triggered heals are not treated as target HoTs. Readable own buffs recover existing effects and removals; when aura data is hidden, the last known expiry is used."] =
    "Омоложение, Обновление, Быстрое восстановление и Прилив не входят в прогноз клиента. После применения одного из них указанное в описании исцеление отображается вслед за прямым исцелением в течение следующих секунд действия эффекта. При обновлении эффекта другим рангом старая оценка заменяется. Для буйного роста линейная оценка строится по видимым получателям положительного эффекта или известной основной цели заклинания, а не по предполагаемым участникам группы. Направленные заклинания, исцеление питомцев и срабатывающие эффекты не считаются периодическим исцелением цели. Доступные собственные положительные эффекты позволяют восстановить текущие эффекты и их снятие; если данные аур скрыты, используется последнее известное время окончания.",
  ["Heal over time horizon"] = "Горизонт периодического исцеления",
  ["How many seconds of each heal over time are drawn ahead."] =
    "На сколько секунд вперёд отображать каждый периодический эффект исцеления.",

  -- сегмент
  ["THE SEGMENT"] = "СЕГМЕНТ",
  ["The fill of the incoming-heal segment: patterns, glass and bevel shadings, Blizzard's bar textures and every LibSharedMedia texture; the color tints them."] =
    "Заливка сегмента входящего исцеления: узоры, стеклянные и рельефные эффекты, текстуры полос Blizzard и все текстуры LibSharedMedia; цвет окрашивает их.",
  ["The incoming-heal segment's own color, or Custom color... for any you like; absorbs keep ShieldsInfo's look."] =
    "Собственный цвет сегмента входящего исцеления или любой выбранный вами цвет; поглощение сохраняет оформление ShieldsInfo.",
  ["Other healers' fill style"] = "Стиль заливки для других целителей",
  ["Other healers' fill color"] = "Цвет заливки для других целителей",
  ["Other healers' fill opacity"] = "Непрозрачность заливки для других целителей",
  ["Heal over time fill style"] = "Стиль заливки периодического исцеления",
  ["Heal over time fill color"] = "Цвет заливки периодического исцеления",
  ["Heal over time fill opacity"] = "Непрозрачность заливки периодического исцеления",
  ["How tall the segment is against the health bar; the top edge is the anchor."] =
    "Высота сегмента относительно полосы здоровья; точка привязки — верхний край.",
  ["Show a number"] = "Показывать число",
  ["A small ~ number for the direct heal plus your HoT horizon at the segment's right end, when the amounts are readable."] =
    "Небольшое число с символом ~ у правого края сегмента показывает прямое исцеление и периодическое исцеление за выбранный период, если эти значения доступны.",

  -- диагностика
  ["DIAGNOSTICS"] = "ДИАГНОСТИКА",
  ["What the client says"] = "Данные клиента",
  ["Prints UnitGetIncomingHeals for you and your group to chat, and the same to the log."] =
    "Выводит UnitGetIncomingHeals для вас и вашей группы в чат и журнал.",
  ["Debug lines in chat"] = "Отладочные сообщения в чате",
  ["Echo the module's notes while it reads and draws."] =
    "Выводить сообщения модуля во время считывания и отображения данных.",
  ["The number is the client's own incoming-heal projection (UnitGetIncomingHeals) - the same one Blizzard's raid frames use. This module only redraws direct heals; your own targeted HoTs are separate estimates from readable descriptions and spell power, independent of SpellDamageInfo's display settings. No crit guesses or addon messages. Hidden native values go unchanged to the bars. /upt healprobe prints what is readable."] =
    "Число — собственный прогноз входящего исцеления клиента (UnitGetIncomingHeals), тот же, что используют рамки рейда Blizzard. Модуль только отображает прямое исцеление; ваши периодические эффекты на цели оцениваются отдельно по доступным описаниям и силе заклинаний независимо от настроек отображения SpellDamageInfo. Критические удары не прогнозируются, сообщения аддонов не используются. Скрытые системные значения без изменений передаются полосам. Команда /upt healprobe выводит доступные данные.",
})
