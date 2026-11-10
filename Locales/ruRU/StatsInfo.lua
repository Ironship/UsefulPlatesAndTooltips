-- UsefulPlatesAndTooltips: русские тексты вкладки StatsInfo. Общие правила — в Locales\ruRU\Core.lua.
-- Copyright (c) 2026 Ironship. GPL-3.0-or-later, см. LICENSE.

local _, BIT = ...

BIT.RegisterLocale("ruRU", {
  -- предпросмотр и блок «Попробуйте»
  ["Live preview (sample item, not your gear)"] = "Предпросмотр (пример предмета, не ваша экипировка)",
  ["StatsInfo sample (not your gear)"] = "Пример StatsInfo (не ваша экипировка)",
  ["Preview: sample item"] = "Предпросмотр: пример предмета",
  ["Quest rewards (sample)"] = "Награды за задания (пример)",
  ["Static sample: bag and quest arrows follow their settings; live upgrades are rated against your gear."] =
    "Статический пример: стрелки для сумок и заданий соответствуют настройкам; игровые улучшения сравниваются с вашей экипировкой.",
  ["The size the preview's text is drawn in. The same field the shared appearance editor changes."] =
    "Размер текста в предпросмотре. Это же значение меняется в общем редакторе оформления.",
  ["Scales the preview's card, rows, icons and bag button. The same field the shared appearance editor changes."] =
    "Масштабирует карточку, строки, значки и кнопку сумки в предпросмотре. Это же значение меняется в общем редакторе оформления.",
  ["How see-through the preview's lines and bag button are. The same field the shared appearance editor changes."] =
    "Прозрачность строк и кнопки сумки в предпросмотре. Это же значение меняется в общем редакторе оформления.",

  -- пример предмета: формулировки самой игры в подсказке предмета
  ["Embossed Leather Vest (sample)"] = "Тиснёный кожаный жилет (пример)",
  ["Item Level 28"] = "Уровень предмета 28",
  ["120 Armor"] = "120 брони",
  ["+3 Stamina"] = "+3 к выносливости",
  ["+3 Intellect"] = "+3 к интеллекту",

  -- вкладки
  ["Arrows"] =
    "Стрелки",
  ["Help"] =
    "Справка",
  ["IN THE ITEM'S TOOLTIP"] =
    "В ПОДСКАЗКЕ ПРЕДМЕТА",
  ["HOW MUCH OF IT"] =
    "НАСКОЛЬКО ПОДРОБНО",
  ["WHERE THE ARROWS SHOW"] =
    "ГДЕ ПОКАЗЫВАТЬ СТРЕЛКИ",
  ["WHERE ON THE ITEM"] =
    "МЕСТО НА ПРЕДМЕТЕ",
  ["Corner"] =
    "Угол",
  ["Top right"] =
    "Справа вверху",
  ["Top left"] =
    "Слева вверху",
  ["Bottom right"] =
    "Справа внизу",
  ["Bottom left"] =
    "Слева внизу",
  ["The corner of the item the arrow and the spec icon sit in, for when another addon's mark (a junk coin, an item level) already uses one. Baganator places its corner marks itself: pick the same corner in its Icon Corners settings. Quest reward arrows keep their own place."] =
    "Угол предмета, в котором находятся стрелка и значок специализации, на случай, если метка другого аддона (монета хлама, уровень предмета) уже занимает один из углов. Baganator размещает свои угловые метки сам: выберите тот же угол в его настройках Icon Corners. Стрелки наград за задания остаются на своём месте.",
  ["Horizontal nudge"] =
    "Сдвиг по горизонтали",
  ["Vertical nudge"] =
    "Сдвиг по вертикали",
  ["Pixels right (+) or left (-) of the corner."] =
    "Пиксели вправо (+) или влево (-) от угла.",
  ["Pixels up (+) or down (-) from the corner."] =
    "Пиксели вверх (+) или вниз (-) от угла.",
  ["Arrow size"] =
    "Размер стрелки",
  ["The size of the arrow, the spec icon and the +N cue."] =
    "Размер стрелки, значка специализации и пометки +N.",
  ["Use the game's own upgrade arrow in Blizzard's bags"] =
    "Использовать игровую стрелку улучшения в сумках Blizzard",
  ["Blizzard's bag buttons have an upgrade arrow of their own, in a place the game chose. Checked: an upgrade lights that one. Unchecked: this addon's arrow is drawn instead, in the corner chosen above. Other bag addons always get this addon's arrow."] =
    "У ячеек сумок Blizzard есть собственная стрелка улучшения в месте, выбранном игрой. С галочкой: улучшение включает её. Без галочки: вместо неё рисуется стрелка этого аддона в выбранном выше углу. В других аддонах для сумок всегда используется стрелка этого аддона.",
  ["WHAT THE ICONS STAND FOR"] =
    "ЧТО ОЗНАЧАЮТ ЗНАЧКИ",
  ["HOW EACH SPEC RATES THE ITEM"] =
    "КАК СПЕЦИАЛИЗАЦИИ ОЦЕНИВАЮТ ПРЕДМЕТ",
  ["ARROWS ON BAG ITEMS"] =
    "СТРЕЛКИ У ПРЕДМЕТОВ В СУМКАХ",
  ["DIAGNOSTICS"] =
    "ДИАГНОСТИКА",
  ["Static sample. The coin stands for another addon's junk mark; the arrows follow the Arrows tab. Live upgrades are rated against your gear."] =
    "Статический пример. Монета изображает метку хлама другого аддона; стрелки следуют вкладке «Стрелки». Игровые улучшения сравниваются с вашей экипировкой.",
  ["Legend"] = "Обозначения",
  ["Ratings"] = "Оценки",
  ["Bag arrows"] = "Стрелки сумки",

  -- вкладка «Отображение»
  ["Show what the item changes against the equipped one"] =
    "Показывать разницу с надетым предметом",
  ["The differences against the item you wear in that slot, in the item's tooltip."] =
    "Показывает в подсказке предмета разницу с тем, который надет в этом слоте.",
  ["Under each stat, what it gives you"] = "Что даёт каждая характеристика",
  ["Health, mana, armor, attack power, crit, hit and the rest, under each difference. The Help tab has the icons."] =
    "Здоровье, мана, броня, сила атаки, критический удар, меткость и прочие параметры под каждой разницей. Значки указаны на вкладке «Справка».",
  ["How each spec of your class rates the item"] = "Оценка предмета для каждой специализации вашего класса",
  ["The Help tab explains the numbers."] = "Числа объясняются на вкладке «Справка».",
  ["Icons instead of words"] = "Значки вместо слов",
  ["Icons and one line each, instead of words."] = "Значок и отдельная строка для каждого параметра вместо слов.",
  ["Arrows on bag items"] = "Стрелки у предметов в сумках",
  ["Green up for an upgrade, red down only when every path is worse. The Help tab explains them."] =
    "Зелёная стрелка вверх означает улучшение; красная вниз появляется, только если все варианты хуже. Подробнее — на вкладке «Справка».",
  ["The beneficiary spec icon on an up arrow"] = "Значок подходящей специализации на стрелке вверх",
  ["+N for the rest of the specs it is an upgrade for, ~ for the approximate healer score. Needs the arrows on."] =
    "+N для остальных специализаций, которым предмет подходит как улучшение; ~ для примерной оценки целителя. Требуется включить стрелки.",
  ["Quest reward arrows"] = "Стрелки у наград за задания",
  ["A green up arrow on every usable upgrade. The reward with the highest positive '% better' rating shown in its tooltip gets a second arrow. If nothing is an upgrade, a coin marks the choice with the highest vendor price."] =
    "Зелёная стрелка вверх у каждого подходящего улучшения. Награда с самым высоким положительным значением «% лучше» в подсказке получает вторую стрелку. Если улучшений нет, монета отмечает предмет с самой высокой ценой у торговца.",
  ["Arrows on loot, rolls and merchants"] = "Стрелки у добычи, при бросках и у торговцев",
  ["The same bag verdict on loot slots, need/greed rolls and merchant buttons."] =
    "Та же оценка, что и для сумки, отображается в ячейках добычи, при бросках «нужно/не откажусь» и на кнопках торговца.",
  ["Hover a box for what it does. The preview at the left follows these boxes at once."] =
    "Наведите курсор на флажок, чтобы узнать, что он делает. Предпросмотр слева сразу обновляется согласно выбранным настройкам.",

  -- вкладка «Обозначения»
  ["What the icons stand for"] = "Что означают значки",
  ["Under each difference: what the stats give this character -- the game's own numbers, worked out as its character sheet works them out. Green is up, red is down."] =
    "Под каждой разницей указано, что характеристики дают персонажу: значения самой игры, рассчитанные так же, как на листе персонажа. Зелёный цвет означает увеличение, красный — уменьшение.",
  ["Armor is 2 per Agility and mana regeneration a quarter of Spirit, as measured on Forever. Health regeneration from Spirit is the character sheet's own number (standing, out of combat), taken per point of Spirit: it assumes the two are proportional. In combat the game may hide these numbers; then the line is left out."] =
    "На Forever одна единица ловкости даёт 2 брони, а восстановление маны равно четверти духа. Восстановление здоровья от духа берётся из листа персонажа (стоя, вне боя) и рассчитывается на единицу духа, предполагая пропорциональную зависимость. В бою игра может скрывать эти числа; тогда строка не отображается.",

  -- вкладка «Оценки»
  ["How each spec rates the item"] = "Оценка предмета для каждой специализации",
  ["Each spec of your class rates the item against what you wear: \"25% better dmg spec\" means its stats are worth a quarter more to that spec."] =
    "Каждая специализация вашего класса сравнивает предмет с надетой экипировкой: «на 25% лучше для специализации урона» означает, что характеристики предмета на четверть ценнее для этой специализации.",
  ["A tank has two numbers: for survival (less damage taken) and for threat gen. (holding aggro)."] =
    "Для танка указываются два значения: выживаемость (снижение получаемого урона) и создание угрозы (удержание противников).",
  ["With nothing worth comparing, or a change past the cap: \">300% ...\", at most triple."] =
    "Если сравнивать не с чем или изменение превышает ограничение: «>300% ...», максимум втрое.",
  ["Each healer spec (druid Restoration, priest Holy, paladin Holy, shaman Restoration) is rated by this addon's own starter heuristic, and its line is marked \"(approx.)\": an approximate item score, not a measured healing gain."] =
    "Каждая специализация целителя (друид «Исцеление», жрец «Свет», паладин «Свет», шаман «Исцеление») оценивается по начальной эвристике аддона; строка помечена «(прибл.)». Это примерная оценка предмета, а не измеренный прирост исцеления.",
  ["Its weights are design choices of this addon (tools/data/healer_weights.json): 1 x +Healing, 1 x Spell Power, 0.5 x Intellect, 0.5 x Spirit and 2 x MP5. Every other stat counts for nothing to it."] =
    "Веса заданы разработчиками аддона (tools/data/healer_weights.json): 1 × бонус к исцелению, 1 × сила заклинаний, 0,5 × интеллект, 0,5 × дух и 2 × MP5. Все прочие характеристики не учитываются.",
  ["The other ratings use ForeverSim's stat weights, measured on a level 60 build of each spec with its own talents, gear and buffs: below 60 they are an estimate."] =
    "Для остальных оценок используются веса характеристик ForeverSim, измеренные на персонажах 60-го уровня для каждой специализации с её талантами, экипировкой и усилениями. Для уровней ниже 60 это приблизительная оценка.",
  ["A weapon's damage per second counts as the simulator weighs it for the spec: main hand, off hand and ranged slot apart."] =
    "Урон оружия в секунду учитывается согласно весам симулятора для специализации; оружие в правой руке, левой руке и дальнобойном слоте оценивается отдельно.",
  ["Not counted: what a hunter's pet gets from your stats, weapon skill, and Spirit for the specs the simulator does not weigh it for."] =
    "Не учитываются: бонусы характеристик для питомца охотника, навык владения оружием и дух для специализаций, для которых симулятор не рассчитывает веса.",
  ["Always show the full tooltip"] = "Всегда показывать полную подсказку",
  ["Off: one line, the best spec and its arrow. Hold Shift for the full breakdown."] =
    "Если выключено: одна строка с лучшей специализацией и стрелкой. Удерживайте Shift, чтобы увидеть подробности.",
  ["Hold Shift for the full breakdown."] = "Удерживайте Shift, чтобы увидеть подробности.",

  -- вкладка «Стрелки сумки»
  ["On the game's own bags and the Baganator bag grid: green up when at least one spec's score is outright better and none of it worse."] =
    "В стандартных сумках игры и сетке Baganator: зелёная стрелка вверх появляется, если оценка хотя бы для одной специализации определённо лучше и ни для одной не хуже.",
  ["Red down only when every replacement path is strictly worse for every spec. Mixed, equal or unknown: no arrow."] =
    "Красная стрелка вниз появляется, только если все возможные замены строго хуже для каждой специализации. Смешанная, равная или неизвестная оценка — без стрелки.",
  ["Always against what you wear in that slot, never a BiS verdict."] =
    "Сравнение всегда проводится с надетым предметом в том же слоте; это не оценка BiS.",
  ["Stats the simulator does not model are compared conservatively by the raw differences, with no spec icon; the healer's approximate score gets a ~ icon."] =
    "Характеристики, не учитываемые симулятором, сравниваются осторожно по исходным значениям без значка специализации; примерная оценка целителя помечается значком ~.",
  ["While the client hides stats (in combat) or the item's data has not arrived, no arrow is shown."] =
    "Стрелка не отображается, если клиент скрывает характеристики (в бою) или данные предмета ещё не получены.",
  ["DoesItDiePlus StatsInfo: green up / red down against what you wear"] =
    "DoesItDiePlus StatsInfo: зелёная стрелка вверх / красная вниз относительно надетой экипировки",

  -- строка проверки
  ["Record the probe"] = "Записать проверку",
  ["%d recorded so far"] = "Записей: %d",

  -- заголовки сравнения в подсказке предмета
  ["Against %s"] = "Сравнение с %s",
  ["Against %s:"] = "Сравнение с %s:",
  ["Compared with your gear: %s"] = "По сравнению с вашей экипировкой: %s",
  ["an empty slot"] = "пустой слот",
  ["the same stats"] = "те же характеристики",
  ["Finger slot 1"] = "Слот пальца 1",
  ["Finger slot 2"] = "Слот пальца 2",
  ["Trinket slot 1"] = "Слот аксессуара 1",
  ["Trinket slot 2"] = "Слот аксессуара 2",

  -- строки вердикта
  ["Better than your gear"] = "Лучше вашей экипировки",
  ["Worse than your gear"] = "Хуже вашей экипировки",
  ["best spec"] = "лучшая специализация",
  ["Fills an empty slot"] = "Занимает пустой слот",
  ["Lower score in an empty slot"] = "Оценка ниже, чем у пустого слота",
  ["score changes from zero"] = "оценка меняется с нуля",
  ["%s, approx."] = "%s, прибл.",
  ["%s (approx.)"] = "%s (прибл.)",
  ["No clear upgrade; hold Shift for details"] = "Нет явного улучшения; удерживайте Shift для подробностей",
  ["No clear upgrade for this slot"] = "Нет явного улучшения для этого слота",
  ["Cannot use this item"] = "Вы не можете использовать этот предмет",

  -- оценки специализаций, шаблон для каждой строки (число заменяет %s)
  ["%s%% better dmg spec"] = "На %s%% лучше для специализации урона",
  ["%s%% worse dmg spec"] = "На %s%% хуже для специализации урона",
  ["%s%% better for survival"] = "На %s%% лучше для выживаемости",
  ["%s%% worse for survival"] = "На %s%% хуже для выживаемости",
  ["%s%% better for threat gen."] = "На %s%% лучше для создания угрозы",
  ["%s%% worse for threat gen."] = "На %s%% хуже для создания угрозы",
  ["%s%% better healer score"] = "Оценка целителя лучше на %s%%",
  ["%s%% worse healer score"] = "Оценка целителя хуже на %s%%",
  ["%s%% better"] = "Лучше на %s%%",
  ["%s%% worse"] = "Хуже на %s%%",

  -- строки для танков
  ["Uncrittable: %s/%s (need %s)"] = "Невосприимчивость к критическим ударам: %s/%s (нужно %s)",
  ["Avoidance: %.2f%% / 102.4%% (miss+dodge+parry+block)"] =
    "Избегание: %.2f%% / 102.4%% (промах+уклонение+парирование+блок)",
  ["Avoidance: %.2f%% / 102.4%% (dodge+parry+block, no miss)"] =
    "Избегание: %.2f%% / 102.4%% (уклонение+парирование+блок, без промахов)",

  -- ценность характеристик словами (в строках со значками используются сокращения)
  ["armor"] = "броня",
  ["attack power"] = "сила атаки",
  ["AP"] = "СА",
  ["crit"] = "критический удар",
  ["dodge"] = "уклонение",
  ["health"] = "здоровье",
  ["mana"] = "мана",
  ["spell crit"] = "критический эффект заклинания",
  ["mana per 5 sec. when not casting"] = "восполнение маны за 5 сек. без применения заклинаний",
  ["mana/5s"] = "мана/5 сек.",
  ["hit"] = "меткость",
  ["haste"] = "скорость",
  ["expertise"] = "мастерство",
  ["parry"] = "парирование",
  ["block"] = "блок",
  ["block value"] = "значение блока",
  ["defense"] = "защита",
  ["healing"] = "исцеление",
  ["spell power"] = "сила заклинаний",
  ["health per 5 sec. out of combat"] = "восполнение здоровья за 5 сек. вне боя",
  ["health/5s"] = "здоровье/5 сек.",

  -- специализации (Fire находится в Core.lua)
  ["Feral (Bear)"] = "Сила зверя (медведь)",
  ["Feral (Cat)"] = "Сила зверя (кошка)",
  ["Balance"] = "Баланс",
  ["Restoration"] = "Исцеление",
  ["Beast Mastery"] = "Повелитель зверей",
  ["Marksmanship"] = "Стрельба",
  ["Survival"] = "Выживание",
  ["Arcane"] = "Тайная магия",
  ["Protection"] = "Защита",
  ["Retribution"] = "Воздаяние",
  ["Holy"] = "Свет",
  ["Shadow"] = "Тьма",
  ["Discipline"] = "Послушание",
  ["Combat"] = "Бой",
  ["Subtlety"] = "Скрытность",
  ["Assassination"] = "Ликвидация",
  ["Elemental"] = "Стихии",
  ["Enhancement"] = "Совершенствование",
  ["Affliction"] = "Колдовство",
  ["Demonology"] = "Демонология",
  ["Destruction"] = "Разрушение",
  ["Destruction (DS/Ruin)"] = "Разрушение (DS/Ruin)",
  ["Arms"] = "Оружие",
  ["Fury"] = "Неистовство",
})
