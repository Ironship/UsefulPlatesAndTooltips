-- UsefulPlatesAndTooltips: русские тексты окна настроек и основных модулей.
-- Copyright (c) 2026 Ironship. GPL-3.0-or-later, см. LICENSE.
--
-- Ключи — английские строки из кода; сохраняйте все %s и %d в том же порядке.
-- Общие строки находятся здесь, тексты отдельных модулей — в их собственных файлах.

local _, BIT = ...

BIT.RegisterLocale("ruRU", {
  -- вкладки
  ["Spells"] = "Заклинания",
  ["SpellDamageInfo"] = "SpellDamageInfo",
  ["The damage and healing from each spell's description on your action buttons and in its tooltip."] =
    "Урон и исцеление из описания каждого заклинания на кнопках действий и в подсказке.",
  ["Cast"] = "Применение",
  ["Cast prediction"] = "Прогноз заклинаний",
  ["The damage the spell you are casting should deal, drawn on enabled unit frames and the target's nameplate. Channels show estimated damage remaining until the channel ends. Crits, procs and resists cannot be predicted."] =
    "Предполагаемый урон применяемого заклинания на выбранных рамках и табличке цели. Для поддерживаемых заклинаний показывается оставшийся урон до конца применения. Критические удары, срабатывания эффектов и сопротивление предсказать нельзя.",
  ["DoTs"] = "Периодический урон",
  ["DoTInfo"] = "DoTInfo",
  ["Marks on the target's health bar the damage your DoTs still have to deal, with a kill icon when they will finish it."] =
    "Показывает на полосе здоровья цели оставшийся урон от ваших эффектов периодического урона и значок убийства, если они добьют цель.",
  ["Stats"] = "Характеристики",
  ["StatsInfo"] = "StatsInfo",
  ["In an item's tooltip: what its stats change against the item you wear in that slot."] =
    "В подсказке предмета показывает, как его характеристики изменятся по сравнению с надетым предметом в том же слоте.",
  ["Points"] = "Очки",
  ["ResourceDing"] = "ResourceDing",
  ["A sound when your combo points are full, and the points as dots under the target; for casters a sound when mana climbs to a level, and for warlocks one on each Soul Shard."] =
    "Звук при заполнении серии приёмов и точки под целью; для заклинателей — звук при достижении заданного уровня маны, для чернокнижников — звук при получении каждого осколка души.",
  ["Range"] = "Дальность",
  ["A red X over your target while it is out of range, a green checkmark while it is in range."] =
    "Красный крест над целью вне досягаемости и зелёная галочка, когда цель в пределах досягаемости.",
  ["Shields"] = "Щиты",
  ["The remaining absorb of a shield on your frames and nameplates."] =
    "Остаток поглощения щита на рамках и табличках.",
  ["Heals"] = "Исцеление",
  ["Heal prediction"] = "Прогноз исцеления",
  ["Incoming healing on player, target, focus, target-of-target, party and raid frames (native direct heals and estimates for your own HoTs)."] =
    "Входящее исцеление на рамках игрока, цели, фокуса, цели цели, группы и рейда (системное прямое исцеление и оценка ваших эффектов исцеления со временем).",
  ["Hunter"] = "Охотник",
  ["Hunter range"] = "Дальность охотника",
  ["Six native dots tell a hunter the approximate range, 8-10 yd to 30-35 yd; a seventh past 35 yd with Hawk Eye."] =
    "Шесть системных точек показывают охотнику примерную дальность от 8–10 до 30–35 м; с «Орлиным глазом» добавляется седьмая точка дальше 35 м.",
  ["Hunter only. Settings are here for an alt."] = "Только для охотников. Настройки доступны и для другого персонажа.",

  -- окно настроек
  ["Settings"] = "Настройки",
  ["Enable %s"] = "Включить %s",
  ["Reload UI"] = "Перезагрузить интерфейс",
  ["Reset module"] = "Сбросить модуль",
  ["Reset all settings for %s? The interface will reload. Module enable state, learned data and shared settings are kept."] =
    "Сбросить все настройки модуля %s? Интерфейс будет перезагружен. Состояние модуля, накопленные данные и общие настройки сохранятся.",
  ["Cannot reset %s: defaults are unavailable."] = "Не удалось сбросить %s: настройки по умолчанию недоступны.",
  ["Cannot reset settings: reloading the interface is unavailable."] = "Не удалось сбросить настройки: перезагрузка интерфейса недоступна.",
  ["Cannot reset %s: its settings are invalid."] = "Не удалось сбросить %s: настройки повреждены.",
  ["Cannot reset %s appearance: %s"] = "Не удалось сбросить оформление %s: %s",
  ["Running."] = "Работает.",
  ["Open settings"] = "Открыть настройки",
  ["Open the settings window. You can also type /upt."] = "Открывает окно настроек. Также можно ввести /upt.",
  ["The settings have their own window. You can also type /upt."] =
    "Настройки открываются в отдельном окне. Также можно ввести /upt.",
  ["Switched on after a reload of the interface."] = "Включится после перезагрузки интерфейса.",
  ["Switched off after a reload of the interface."] = "Выключится после перезагрузки интерфейса.",
  ["Its settings are here while it runs; its appearance and a sample preview are below -- they need no module runtime. Tick Enable to open the settings before the next reload."] =
    "Настройки доступны здесь, пока модуль работает; его оформление и пример ниже доступны и без запущенного модуля. Отметьте «Включить», чтобы открыть настройки до следующей перезагрузки.",
  ["This module is switched off. Tick Enable above to open its settings and live preview before the next reload."] =
    "Этот модуль выключен. Отметьте «Включить» выше, чтобы открыть его настройки и предпросмотр до следующей перезагрузки.",
  ["%s is switched off. /upt opens the settings, where it can be switched on."] =
    "%s выключен. Введите /upt, чтобы открыть настройки и включить его.",
  ["%s/%s: tabs"] = "%s/%s: вкладки",
  ["%s/%s: select  ·  %s/%s: move / adjust  ·  %s: activate  ·  %s: back"] =
    "%s/%s: выбрать  ·  %s/%s: переместить / настроить  ·  %s: применить  ·  %s: назад",
  ["ConsolePort: D-pad: select · use the cursor's button hints"] =
    "ConsolePort: крестовина: выбор · следуйте подсказкам кнопок курсора",
  ["/upt opens the settings; /upt <part> opens a part's tab (%s); /upt probe records what StatsInfo can read; /upt lang sets the language."] =
    "/upt открывает настройки; /upt <part> открывает вкладку модуля (%s); /upt probe записывает данные, доступные StatsInfo; /upt lang меняет язык.",

  -- команда смены языка
  ["%d texts shown so far have no translation in this language."] =
    "Пока без перевода на этот язык показано строк: %d.",
  ["Unknown language %s. Use auto, en or one of: %s."] =
    "Неизвестный язык %s. Используйте auto, en или один из вариантов: %s.",
  ["Auto (game language)"] = "Авто (язык игры)",
  ["The language of the settings, tooltips and chat lines of this addon. It changes after a reload. Auto follows the game's language."] =
    "Язык настроек, подсказок и строк чата этого аддона. Меняется после перезагрузки. «Авто» следует языку игры.",
  ["The language changes after /reload."] = "Язык изменится после команды /reload.",
  ["Language: %s. /upt lang auto, /upt lang en, /upt lang <code> (%s) or /upt lang missing."] =
    "Язык: %s. /upt lang auto, /upt lang en, /upt lang <code> (%s) или /upt lang missing.",

  -- выбор рамки
  ["the health bar"] = "полоса здоровья",
  ["where the kill icon should go"] = "место для значка убийства",
  ["(this frame has no name to save)"] = "(у этой рамки нет имени для сохранения)",
  ["nothing under the mouse"] = "под курсором ничего нет",
  ["DoesItDiePlus: click %s (right-click to cancel)"] = "DoesItDiePlus: щёлкните %s (правый щелчок — отмена)",
  ["Frame pick stopped after an error: %s. You can still type a frame name."] =
    "Выбор рамки остановлен из-за ошибки: %s. Имя рамки можно ввести вручную.",
  ["Frame pick cancelled."] = "Выбор рамки отменён.",
  ["Nothing to pick there."] = "Здесь нечего выбрать.",
  ["That frame has no name to save, so it cannot be found again after a reload. Try the frame around it, or type a path."] =
    "У этой рамки нет имени для сохранения, поэтому после перезагрузки её не найти. Выберите внешнюю рамку или введите путь.",
  ["automatic"] = "автоматически",
  ["%s not found"] = "%s не найдена",
  ["/upt frame target|icon|focus|player|plate <path> sets one (\"clear\" removes it); /upt pick target|icon|focus|player"] =
    "/upt frame target|icon|focus|player|plate <path> задаёт рамку (\"clear\" удаляет её); /upt pick target|icon|focus|player",
  ["/upt pick target|icon|focus|player, then click the frame on screen (right-click cancels)."] =
    "/upt pick target|icon|focus|player, затем щёлкните нужную рамку на экране (правый щелчок отменяет выбор).",
  ["Click the spot for the kill icon. Right-click cancels."] =
    "Щёлкните место для значка убийства. Правый щелчок отменяет выбор.",
  ["Click the health bar of %s. Right-click cancels."] =
    "Щёлкните полосу здоровья %s. Правый щелчок отменяет выбор.",
  ["Picked %s for %s."] = "Для %s выбрана рамка %s.",

  -- дорожки на табличках
  ["Hunter rail overlaps combo dots."] = "Шкала охотника перекрывает точки серии приёмов.",
  ["Hunter rail overlaps shard diamonds."] = "Шкала охотника перекрывает ромбы осколков.",
  ["Combo dots overlap shard diamonds."] = "Точки серии приёмов перекрывают ромбы осколков.",
  ["Nameplate lanes are clear."] = "Дорожки на табличках не перекрываются.",

  -- общие настройки и предпросмотр
  ["Live preview"] = "Предпросмотр",
  ["Nameplate lanes"] = "Дорожки таблички",
  ["Bar"] = "Полоса",
  ["Display"] = "Отображение",
  ["Position"] = "Положение",
  ["Preview"] = "Предпросмотр",
  ["Player"] = "Игрок",
  ["Target"] = "Цель",
  ["Party"] = "Группа",
  ["Print"] = "Вывести",
  ["Height"] = "Высота",
  ["Health"] = "Здоровье",
  ["Frost"] = "Лёд",
  ["Marker"] = "Маркер",
  ["Text"] = "Текст",
  ["Nameplates"] = "Таблички",
  ["Reset"] = "Сбросить",
  ["Combo"] = "Серия приёмов",
  ["Combo points"] = "Очки серии приёмов",
  ["Effects"] = "Эффекты",
  ["Spell"] = "Заклинание",
  ["TRY IT"] = "ПОПРОБУЙТЕ",
  ["Target health"] = "Здоровье цели",
  ["FRAMES"] = "РАМКИ",
  ["Show on target frame"] = "Показывать на рамке цели",
  ["Show on focus frame"] = "Показывать на рамке фокуса",
  ["Show on nameplates"] = "Показывать на табличках",
  ["Target beats mouseover"] = "Цель важнее наведения курсора",
  ["Fill color"] = "Цвет заливки",
  ["Fill opacity"] = "Непрозрачность заливки",
  ["Fill style"] = "Стиль заливки",
  ["Outline"] = "Контур",
  ["Outline color"] = "Цвет контура",
  ["Outline opacity"] = "Непрозрачность контура",
  ["Text position"] = "Положение текста",
  ["Centered on the bar"] = "По центру полосы",
  ["Left of the bar"] = "Слева от полосы",
  ["Inside the bar, right end"] = "Внутри полосы, у правого края",
  ["Text size"] = "Размер текста",
  ["Text color"] = "Цвет текста",
  ["Icon size"] = "Размер значка",
  ["Icon horizontal offset"] = "Смещение значка по горизонтали",
  ["Icon vertical offset"] = "Смещение значка по вертикали",
  ["Reset this tab"] = "Сбросить эту вкладку",
  ["Look presets  v"] = "Шаблоны оформления  v",
  ["%d-%d of %d"] = "%d–%d из %d",
  ["Off"] = "Выкл.",
  ["None"] = "Нет",
  ["Solid"] = "Сплошной",
  ["Dashed"] = "Пунктирный",
  ["Raid skull"] = "Рейдовый череп",
  ["Red X"] = "Красный крест",

  -- панель оформления
  ["Appearance"] = "Оформление",
  ["APPEARANCE"] = "ОФОРМЛЕНИЕ",
  ["Advanced"] = "Дополнительно",
  ["Hide advanced"] = "Скрыть дополнительные настройки",
  ["Editing: this module"] = "Настройка: этот модуль",
  ["Editing: all modules"] = "Настройка: все модули",
  ["Palette (arbitrary RGB)"] = "Палитра (произвольный RGB)",
  ["RGB %s:"] = "RGB %s:",
  ["Font path:"] = "Путь к шрифту:",
  ["Font size"] = "Размер шрифта",
  ["Text outline"] = "Контур текста",
  ["Thick outline"] = "Толстый контур",
  ["Scale"] = "Масштаб",
  ["Opacity"] = "Непрозрачность",
  ["Size"] = "Размер",
  ["Shape"] = "Форма",
  ["Border"] = "Граница",
  ["Thickness"] = "Толщина",
  ["Gap"] = "Интервал",
  ["Length"] = "Длина",
  ["Segments"] = "Сегменты",
  ["Stripes"] = "Полосы",
  ["Reduced motion"] = "Уменьшить анимацию",
  ["Limits the animations (pulses, glides, sweeps) to the calm ones."] =
    "Ограничивает анимации (пульсацию, скольжение и пробег) более спокойными вариантами.",
  ["Minimal"] = "Минималистичный",
  ["Classic"] = "Классический",
  ["Juicy"] = "Яркий",
  ["Minimal preset"] = "Минималистичный шаблон",
  ["Reset this module's appearance"] = "Сбросить оформление этого модуля",
  ["Reset shared appearance (all modules)"] = "Сбросить общее оформление (все модули)",
  ["Reset changes only the appearance: gameplay settings, sounds, anchors and learned values stay."] =
    "Сброс затрагивает только оформление: игровые настройки, звуки, точки привязки и накопленные значения сохраняются.",
  ["Sample: fictitious data, not the live game"] = "Пример: вымышленные данные, не из игры",
  ["Sample text 123"] = "Пример текста 123",

  -- роли цветов палитры
  ["accent"] = "акцент",
  ["text"] = "текст",
  ["muted"] = "приглушённый",
  ["damage"] = "урон",
  ["heal"] = "исцеление",
  ["absorb"] = "поглощение",
  ["good"] = "хорошо",
  ["bad"] = "плохо",
  ["unknown"] = "неизвестно",
  ["resource"] = "ресурс",
  ["distanceNear"] = "дальность: близко",
  ["distanceMid"] = "дальность: средняя",
  ["distanceFar"] = "дальность: далеко",

  -- палитра цветов
  ["Custom color..."] = "Свой цвет...",
  ["Custom %s"] = "Свой цвет: %s",
  ["Purple"] = "Пурпурный",
  ["Gold"] = "Золотой",
  ["White"] = "Белый",
  ["Red"] = "Красный",
  ["Orange"] = "Оранжевый",
  ["Green"] = "Зелёный",
  ["Cyan"] = "Голубой",
  ["Pink"] = "Розовый",
  ["Black"] = "Чёрный",
  ["Crimson"] = "Алый",
  ["Maroon"] = "Бордовый",
  ["Coral"] = "Коралловый",
  ["Amber"] = "Янтарный",
  ["Yellow"] = "Жёлтый",
  ["Lime"] = "Лаймовый",
  ["Forest"] = "Лесной",
  ["Mint"] = "Мятный",
  ["Teal"] = "Бирюзовый",
  ["Sky blue"] = "Небесно-голубой",
  ["Blue"] = "Синий",
  ["Navy"] = "Тёмно-синий",
  ["Indigo"] = "Индиго",
  ["Violet"] = "Фиолетовый",
  ["Magenta"] = "Пурпурно-красный",
  ["Lavender"] = "Лавандовый",
  ["Peach"] = "Персиковый",
  ["Bone"] = "Костяной",
  ["Brown"] = "Коричневый",
  ["Olive"] = "Оливковый",
  ["Ice"] = "Ледяной",
  ["Silver"] = "Серебряный",
  ["Gray"] = "Серый",
  ["Charcoal"] = "Угольный",

  -- группы текстур
  ["Basic"] = "Основные",
  ["Blizzard"] = "Blizzard",
  ["Soft"] = "Мягкие",
  ["Bar shapes"] = "Формы полос",
  ["Patterns"] = "Узоры",
  ["Organic"] = "Природные",
  ["Material"] = "Материалы",
  ["Colorful (own colors)"] = "Цветные (собственные цвета)",
  ["Shared media"] = "Общие медиафайлы",

  -- текстуры
  ["Flat"] = "Плоская",
  ["Fade in from left"] = "Появление слева",
  ["Health bar texture"] = "Текстура полосы здоровья",
  ["Raid bar texture"] = "Текстура рейдовой полосы",
  ["Raid power texture"] = "Текстура рейдового ресурса",
  ["Skill bar texture"] = "Текстура полосы умения",
  ["Loading bar texture"] = "Текстура полосы загрузки",
  ["Glass (light top, dark bottom)"] = "Стекло (свет сверху, тёмное снизу)",
  ["Bevel (light to dark)"] = "Скос (от светлого к тёмному)",
  ["Cylinder (bright middle)"] = "Цилиндр (светлая середина)",
  ["Inset (dark to light)"] = "Вдавленная (от тёмного к светлому)",
  ["Top shine"] = "Блик сверху",
  ["Rim glow (top and bottom)"] = "Свечение по краям (сверху и снизу)",
  ["Fade out to the right"] = "Затухание вправо",
  ["Fade out to the left"] = "Затухание влево",
  ["Fade at both ends"] = "Затухание с обоих концов",
  ["Diagonal stripes"] = "Диагональные полосы",
  ["Diagonal stripes, other way"] = "Диагональные полосы в другую сторону",
  ["Wide diagonal stripes"] = "Широкие диагональные полосы",
  ["Vertical lines"] = "Вертикальные линии",
  ["Vertical lines, wide"] = "Широкие вертикальные линии",
  ["Horizontal lines"] = "Горизонтальные линии",
  ["Horizontal lines, wide"] = "Широкие горизонтальные линии",
  ["Scanlines"] = "Строки развертки",
  ["Crosshatch"] = "Перекрёстная штриховка",
  ["Grid"] = "Сетка",
  ["Checkerboard"] = "Шахматная доска",
  ["Dots"] = "Точки",
  ["Big dots"] = "Крупные точки",
  ["Diamonds"] = "Ромбы",
  ["Zigzag"] = "Зигзаг",
  ["Chevrons"] = "Шевроны",
  ["Waves"] = "Волны",
  ["Bricks"] = "Кирпичи",
  ["Carbon fibre"] = "Углеродное волокно",
  ["Noise"] = "Шум",
  ["Brushed metal"] = "Шлифованный металл",
  ["Tube (round highlight)"] = "Трубка (круглый блик)",
  ["Chrome bands"] = "Хромированные полосы",
  ["Glass, strong"] = "Стекло, яркое",
  ["Glow in the middle"] = "Свечение в центре",
  ["Dark edges"] = "Тёмные края",
  ["Two tones (light over dark)"] = "Два тона (светлый над тёмным)",
  ["Four steps"] = "Четыре ступени",
  ["Capsule (rounded ends)"] = "Капсула (скруглённые концы)",
  ["Bright leading edge"] = "Яркий передний край",
  ["Segments, 5 (20% each)"] = "Сегменты: 5 (по 20%)",
  ["Segments, 10 (10% each)"] = "Сегменты: 10 (по 10%)",
  ["Segments, 20 (5% each)"] = "Сегменты: 20 (по 5%)",
  ["Hexagons"] = "Шестиугольники",
  ["Triangles"] = "Треугольники",
  ["Argyle diamonds"] = "Ромбы аргайл",
  ["Plaid"] = "Шотландская клетка",
  ["Houndstooth"] = "Гусиная лапка",
  ["Sparkles"] = "Искры",
  ["Crosses"] = "Кресты",
  ["Rings"] = "Кольца",
  ["Clouds"] = "Облака",
  ["Marble"] = "Мрамор",
  ["Wood grain"] = "Древесная текстура",
  ["Camouflage"] = "Камуфляж",
  ["Leopard spots"] = "Пятна леопарда",
  ["Cracked earth"] = "Потрескавшаяся земля",
  ["Glowing veins"] = "Светящиеся прожилки",
  ["Bubbles"] = "Пузыри",
  ["Fish scales"] = "Рыбья чешуя",
  ["Water ripples"] = "Рябь на воде",
  ["Sand"] = "Песок",
  ["Zebra"] = "Зебра",
  ["Leather"] = "Кожа",
  ["Woven cloth"] = "Тканое полотно",
  ["Basket weave"] = "Плетёная корзина",
  ["Scratched metal"] = "Поцарапанный металл",
  ["Beveled tiles"] = "Скошенные плитки",
  ["Rivets"] = "Заклёпки",
  ["Louvers"] = "Жалюзи",
  ["Rainbow"] = "Радуга",
  ["Fire"] = "Огонь",
  ["Lava"] = "Лава",
  ["Blood"] = "Кровь",
  ["Sunset"] = "Закат",
  ["Plasma"] = "Плазма",
  ["Aurora"] = "Северное сияние",
  ["Ocean (light to deep)"] = "Океан (от светлого к тёмному)",
  ["Flame (top to bottom)"] = "Пламя (сверху вниз)",
  ["Toxic"] = "Ядовитый",
  ["Steel blue"] = "Стальной синий",
})

-- The settings reorganisation (0.9.131-beta.5): the Frames page, the Show on blocks, shared labels and tips.
BIT.RegisterLocale("ruRU", {
  ["Only for another unit frame addon (ElvUI, Shadowed Unit Frames, ...) or custom nameplates: tell the addon where its health bars are. Empty rows are automatic. The markers of DoTs, Cast, Shields and Heals use these."] =
    "Только для другого аддона рамок (ElvUI, Shadowed Unit Frames, ...) или своих табличек: укажите аддону, где находятся их полосы здоровья. Пустые строки работают автоматически. Эти значения используют маркеры вкладок «DoT», «Применение», «Щиты» и «Лечение».",
  ["Where another unit frame addon's health bars are, for every marker the addon draws."] =
    "Где находятся полосы здоровья другого аддона рамок, для каждого маркера аддона.",
  ["The art of the fill: patterns, glass and bevel shadings, Blizzard's bar textures and every LibSharedMedia texture."] =
    "Вид заливки: узоры, стеклянные и рельефные оттенки, текстуры полос Blizzard и любая текстура LibSharedMedia.",
  ["The fill's color. A style with colors of its own ignores it."] =
    "Цвет заливки. Стиль со своими цветами его игнорирует.",
  ["How strongly the fill covers what is under it."] =
    "Насколько сильно заливка закрывает то, что под ней.",
  ["Which end of the bar the fill starts from."] =
    "С какого края полосы начинается заливка.",
  ["A hairline around the marker."] =
    "Тонкая линия вокруг маркера.",
  ["The color of the outline."] =
    "Цвет контура.",
  ["How strongly the outline shows."] =
    "Насколько заметен контур.",
  ["The width of the outline in pixels."] =
    "Толщина контура в пикселях.",
  ["The length of each dash of a dashed outline."] =
    "Длина каждого штриха пунктирного контура.",
  ["The size of the text in pixels."] =
    "Размер текста в пикселях.",
  ["The color of the text."] =
    "Цвет текста.",
  ["Where the text sits."] =
    "Где расположен текст.",
  ["How see-through everything of this part is."] =
    "Насколько прозрачно всё в этой части.",
  ["Makes everything of this part bigger or smaller."] =
    "Увеличивает или уменьшает всё в этой части.",
  ["The space between the parts, in pixels."] =
    "Расстояние между частями в пикселях.",
  ["How long the parts are, in pixels."] =
    "Длина частей в пикселях.",
  ["How thick the parts are, in pixels."] =
    "Толщина частей в пикселях.",
  ["The shape the parts are drawn in."] =
    "Форма, в которой рисуются части.",
  ["SHOW ON"] =
    "ГДЕ ПОКАЗЫВАТЬ",
  ["The target's own plate gets the same marker, with its own colors on the Nameplates tab; enemy bars are red."] =
    "Табличка цели получает такой же маркер со своими цветами на вкладке «Таблички»; полосы противников красные.",
  ["BEHAVIOR"] =
    "ПОВЕДЕНИЕ",
  ["MANA COST"] =
    "СТОИМОСТЬ МАНЫ",
  ["DoTs has its own kill icon (DoTs > Kill icon). If you use both, set both, or switch one off."] =
    "У DoT есть свой значок убийства (DoT > Значок убийства). Если вы используете оба, настройте оба или отключите один.",
  ["Cast prediction has its own kill icon (Cast > Marker). If you use both, set both, or switch one off."] =
    "У прогноза каста есть свой значок убийства (Применение > Маркер). Если вы используете оба, настройте оба или отключите один.",
  ["Keep this on to show the marker on your screen's target health bar. Plater changes nameplates, not that frame; if you use a separate unit frame addon, set its bar on the Frames page. Turn off to keep the marker on nameplates and the focus frame only. On Retail this also hides the rogue's aura icons above the target bar. The kill icon has its own switch in the Kill icon tab."] =
    "Оставьте настройку включённой, чтобы маркер отображался на полосе здоровья цели на экране. Plater изменяет таблички, а не эту рамку; если вы используете отдельный аддон рамок, укажите его полосу на странице «Рамки». Отключите настройку, чтобы маркер оставался только на табличках и рамке фокуса. В Retail это также скрывает значки аур разбойника над полосой цели. У значка убийства отдельная настройка на вкладке «Значок убийства».",
  ["Draws the same marker (and optionally the kill icon) on your focus frame's health bar for your DoTs on the focused enemy, in the nameplate look (Nameplates tab)."] =
    "Отображает такой же маркер (и, при желании, значок убийства) на полосе здоровья рамки фокуса для ваших DoT на противнике в фокусе, в оформлении табличек (вкладка «Таблички»).",
  ["Draws a marker (and optionally the kill icon) on every enemy nameplate with your DoTs on it, in its own look on the Nameplates tab."] =
    "Отображает маркер (и, при желании, значок убийства) на каждой табличке противника с вашими DoT, в собственном оформлении на вкладке «Таблички».",
  ["Show dividers between DoTs"] =
    "Показывать разделители между DoT",
  ["Glow thickness"] =
    "Толщина свечения",
  ["Another unit frame addon"] =
    "Другой аддон рамок",
  ["Open Frames"] =
    "Открыть «Рамки»",
  ["ElvUI, Shadowed Unit Frames and other unit frame addons: where their health bars are is set once for every marker, on the Frames page."] =
    "ElvUI, Shadowed Unit Frames и другие аддоны рамок: где находятся их полосы здоровья, задаётся один раз для всех маркеров на странице «Рамки».",
  ["Features"] =
    "Функции",
  ["Experiments (on by default in this beta)"] =
    "Эксперименты (в этой бете включены по умолчанию)",
  ["Aura-gated segments on nameplates (experiment)"] =
    "Сегменты по ауре на табличках (эксперимент)",
  ["Aura-gated segment on the target frame (experiment)"] =
    "Сегмент по ауре на рамке цели (эксперимент)",
  ["Diagnostics"] =
    "Диагностика",
  ["Show native next to plain segments"] =
    "Показывать нативные рядом с обычными сегментами",
  ["Show on player frame"] =
    "Показывать на рамке игрока",
  ["Show on target of target frame"] =
    "Показывать на рамке цели цели",
  ["The fill style of the band for the healing other healers have coming."] =
    "Вид заливки полосы для лечения других целителей.",
  ["The color of the band for the healing other healers have coming."] =
    "Цвет полосы для лечения других целителей.",
  ["How strongly the band for other healers' healing covers the bar."] =
    "Насколько сильно полоса лечения других целителей закрывает полосу.",
  ["The fill style of the segment for your heals over time."] =
    "Вид заливки сегмента для вашего лечения со временем.",
  ["The color of the segment for your heals over time."] =
    "Цвет сегмента для вашего лечения со временем.",
  ["How strongly the segment for your heals over time covers the bar."] =
    "Насколько сильно сегмент вашего лечения со временем закрывает полосу.",
  ["The Show on target frame option controls this sample; the other Show on options control live frames. The segment starts at the health edge (the green bar's end) and is cropped at the bar's right end when the heal would overheal."] =
    "Параметр «Показывать на рамке цели» управляет этим образцом; остальные параметры «Показывать на…» управляют реальными рамками. Сегмент начинается от края здоровья (конец зелёной полосы) и обрезается у правого края полосы, если лечение будет избыточным.",
  ["How high the rail sits above the plate's health bar. Positive is up, negative is under the bar. The same seat as the combo dots."] =
    "Как высоко планка находится над полосой здоровья таблички. Положительное значение — вверх, отрицательное — под полосой. То же место, что у очков серии.",
  ["Mark size"] =
    "Размер метки",
  ["Dot size (saved)"] =
    "Размер точек (сохраняется)",
  ["Size of the combo points and soul shards. This changes the saved setting, the same one as on the Combo tab."] =
    "Размер очков серии и осколков души. Это меняет сохранённую настройку, ту же, что на вкладке «Серия».",
  ["Height (saved)"] =
    "Высота (сохраняется)",
  ["Height of the resource in the selected tab. Positive is up, negative is under the bar. This changes the saved setting, the same one as on the Combo / Shards tab."] =
    "Высота ресурса на выбранной вкладке. Положительное значение — вверх, отрицательное — под полосой. Это меняет сохранённую настройку, ту же, что на вкладке «Серия приёмов» / «Осколки».",
  ["Dot height above the bar"] =
    "Высота точек над полосой",
  ["How high the dots sit above the health bar. Positive is up, negative is under the bar. The same seat as the hunter rail."] =
    "Как высоко точки находятся над полосой здоровья. Положительное значение — вверх, отрицательное — под полосой. То же место, что у планки охотника.",
  ["Shard height above the bar"] =
    "Высота осколков над полосой",
  ["How high the diamonds sit above the health bar. Positive is up, negative is under the bar; they move independently of the dots."] =
    "Как высоко ромбы находятся над полосой здоровья. Положительное значение — вверх, отрицательное — под полосой; они двигаются независимо от точек.",
  ["Show on"] =
    "Показывать на",
})

-- Simulate (0.9.131-beta.6): the shared Simulate block, its scenes and names.
BIT.RegisterLocale("ruRU", {
  ["SIMULATE"] =
    "СИМУЛЯЦИЯ",
  ["Simulate"] =
    "Симуляция",
  ["Settings you change while it plays show at once."] =
    "Настройки, которые вы меняете во время воспроизведения, действуют сразу.",
  ["A cast lands and the health drops; the next one is lethal and shows the kill icon."] =
    "Заклинание попадает, здоровье падает; следующее смертельно и показывает значок убийства.",
  ["A heal is cast and lands, then its heal over time ticks down."] =
    "Лечение применяется и достигает цели, затем его лечение со временем убывает.",
  ["The target runs in through every band, from 35+ yd to melee and the dead zone."] =
    "Цель подбегает через все полосы, от 35+ ярдов до ближнего боя и мёртвой зоны.",
  ["Try: out of range"] =
    "Проверка: вне зоны действия",
  ["Try: no nameplate"] =
    "Проверка: нет таблички",
  ["The target steps in and out of range, then loses its nameplate."] =
    "Цель входит в зону действия и выходит из неё, затем теряет табличку.",
  ["The points come in one by one, then the finisher spends them."] =
    "Очки накапливаются по одному, затем завершающий приём их тратит.",
  ["Three hits land: the shield takes them first, then the health, and the shield breaks."] =
    "Приходят три удара: сначала их принимает щит, потом здоровье, и щит ломается.",
  ["Reset frames"] = "Сбросить рамки",
  ["Frames reset: %d paths cleared, the addon finds the frames by itself again."] =
    "Рамки сброшены: очищено путей: %d, аддон снова находит рамки сам.",
  ["Frames: no path was set, the addon already finds the frames by itself."] =
    "Рамки: ни один путь не был задан, аддон уже находит рамки сам.",

  -- Профили
  ["Profiles"] = "Профили",
  ["Profile: %s"] = "Профиль: %s",
  ["Default"] = "По умолчанию",
  ["Default (shared)"] = "По умолчанию (общий)",
  ["Separate settings and enabled modules per character, or shared across characters."] =
    "Отдельные настройки и включённые модули для каждого персонажа или общие для всех.",
  ["Profiles save which modules are enabled and all module settings (appearance, frames and options). Learned combat data and language are kept across profiles. Switching profiles reloads the interface."] =
    "Профили сохраняют список включённых модулей и все настройки модулей (оформление, рамки и параметры). Накопленные боевые данные и язык сохраняются между профилями. Переключение профиля перезагружает интерфейс.",
  ["Character: %s"] = "Персонаж: %s",
  ["Unknown"] = "Неизвестно",
  ["Active profile: %s"] = "Активный профиль: %s",
  ["After reload: %s"] = "После перезагрузки: %s",
  ["Active: %s  ->  After reload: %s"] = "Активен: %s  ->  После перезагрузки: %s",
  ["Click to manage character profiles and enabled modules."] =
    "Нажмите, чтобы управлять профилями персонажей и включёнными модулями.",
  ["THIS CHARACTER"] = "ЭТОТ ПЕРСОНАЖ",
  ["Active profile"] = "Активный профиль",
  ["Which profile this character uses. Default is shared across characters; choose this character's name or create a named profile for separate settings and enabled modules."] =
    "Какой профиль использует этот персонаж. Профиль «По умолчанию» общий для всех; выберите имя персонажа или создайте свой профиль для отдельных настроек и модулей.",
  ["%s (new character profile)"] = "%s (новый профиль персонажа)",
  ["Create a separate profile for %s (copying current settings) and reload the interface?"] =
    "Создать отдельный профиль для %s (скопировав текущие настройки) и перезагрузить интерфейс?",
  ["Switch this character to profile \"%s\" and reload the interface?"] =
    "Переключить этого персонажа на профиль «%s» и перезагрузить интерфейс?",
  ["Switch %s back to the shared Default profile and reload the interface?"] =
    "Вернуть %s на общий профиль «По умолчанию» и перезагрузить интерфейс?",
  ["Switch %s to its own profile \"%s\" and reload the interface?"] =
    "Переключить %s на собственный профиль «%s» и перезагрузить интерфейс?",
  ["Switch & reload"] = "Переключить",
  ["Switch back to Default (shared)"] = "Вернуться к общему профилю",
  ["Use %s's profile"] = "Использовать профиль %s",
  ["Use separate profile for this character"] = "Отдельный профиль для этого персонажа",
  ["MODULES IN THIS PROFILE"] = "МОДУЛИ В ЭТОМ ПРОФИЛЕ",
  ["Enable all"] = "Включить все",
  ["Disable all"] = "Выключить все",
  ["Reload UI to edit the newly selected profile."] =
    "Перезагрузите интерфейс, чтобы редактировать выбранный профиль.",
  ["Changes take effect after a reload of the interface."] =
    "Изменения вступят в силу после перезагрузки интерфейса.",
  ["Tick which modules run in this profile."] =
    "Отметьте модули, которые должны работать в этом профиле.",
  ["MANAGE PROFILES"] = "УПРАВЛЕНИЕ ПРОФИЛЯМИ",
  ["New profile"] = "Новый профиль",
  ["Create a named profile (e.g. Healer, Tank, Alt) and switch this character to it."] =
    "Создать именованный профиль (например, Лекарь, Танк, Альт) и переключить на него этого персонажа.",
  ["Copy current"] = "Копия текущего",
  ["Blank"] = "Пустой",
  ["Enter a profile name first."] = "Сначала введите название профиля.",
  ["A profile named \"%s\" already exists."] = "Профиль с названием «%s» уже существует.",
  ["Create profile \"%s\" (copying current settings), switch this character to it and reload?"] =
    "Создать профиль «%s» (копию текущих настроек), переключиться на него и перезагрузить интерфейс?",
  ["Create blank profile \"%s\" (defaults), switch this character to it and reload?"] =
    "Создать пустой профиль «%s» (по умолчанию), переключиться на него и перезагрузить интерфейс?",
  ["Create & reload"] = "Создать",
  ["Copy settings from"] = "Скопировать настройки из",
  ["Overwrite this profile's settings with a copy from another profile (keeps learned combat data)."] =
    "Заменить настройки этого профиля копией из другого профиля (накопленные боевые данные сохранятся).",
  ["Copy"] = "Копировать",
  ["Copy all settings from \"%s\" into \"%s\" and reload the interface? Learned combat data is kept."] =
    "Скопировать все настройки из «%s» в «%s» и перезагрузить интерфейс? Накопленные боевые данные сохранятся.",
  ["Copy & reload"] = "Копировать",
  ["(no other profiles)"] = "(нет других профилей)",
  ["Delete profile"] = "Удалить профиль",
  ["Remove a profile that is not currently in use. Default cannot be deleted."] =
    "Удалить профиль, который сейчас не используется. Профиль «По умолчанию» удалить нельзя.",
  ["Delete"] = "Удалить",
  ["Delete profile \"%s\"? Any character using it will fall back to Default."] =
    "Удалить профиль «%s»? Все персонажи с этим профилем вернутся к профилю «По умолчанию».",
  ["Deleted profile \"%s\"."] = "Профиль «%s» удалён.",
  ["(none to delete)"] = "(нечего удалять)",
  ["Reset profile"] = "Сбросить профиль",
  ["Reset all settings in profile \"%s\" to defaults and reload? Learned combat data is kept."] =
    "Сбросить все настройки профиля «%s» к значениям по умолчанию и перезагрузить? Накопленные боевые данные сохранятся.",
  ["Could not switch profile (%s)."] = "Не удалось переключить профиль (%s).",
  ["Could not create profile (%s)."] = "Не удалось создать профиль (%s).",
  ["Could not copy profile (%s)."] = "Не удалось скопировать профиль (%s).",
  ["Could not delete profile (%s)."] = "Не удалось удалить профиль (%s).",
  ["Profiles: %s"] = "Профили: %s",
  ["Character name is unavailable."] = "Имя персонажа недоступно.",
  ["Created and selected profile \"%s\" (copied from current). Use /reload to apply."] =
    "Создан и выбран профиль «%s» (копия текущего). Введите /reload для применения.",
  ["Selected profile \"%s\". Use /reload to apply."] = "Выбран профиль «%s». Введите /reload для применения.",
  ["Selected the shared Default profile. Use /reload to apply."] =
    "Выбран общий профиль «По умолчанию». Введите /reload для применения.",
  ["Copied settings from \"%s\" into \"%s\". Use /reload to apply."] =
    "Настройки скопированы из «%s» в «%s». Введите /reload для применения.",
  ["/upt profile opens Profiles; /upt profile list|char|default|use <name>|new <name>|copy <name>|delete <name>"] =
    "/upt profile открывает вкладку «Профили»; /upt profile list|char|default|use <имя>|new <имя>|copy <имя>|delete <имя>",

  -- журнал ошибок вкладки отладки
  ["Clear"] = "Очистить",
  ["Test"] = "Тест",
  ["Errors and blocked actions of this addon (%d)"] = "Ошибки и заблокированные действия этого аддона (%d)",
  ["Nothing caught since the last reload. Lua errors and \"blocked action\" reports that name this addon appear here with their stack."] =
    "С последней перезагрузки ничего не поймано. Ошибки Lua и сообщения о заблокированных действиях, упоминающие этот аддон, появятся здесь со стеком вызовов.",
  ["SPELL NUMBERS (SPELLDAMAGEINFO)"] = "ЧИСЛА ЗАКЛИНАНИЙ (SPELLDAMAGEINFO)",
  ["DOTS (DOTINFO)"] = "ПЕРИОДИЧЕСКИЙ УРОН (DOTINFO)",
  ["CAST PREDICTION"] = "ПРОГНОЗ ЗАКЛИНАНИЙ",
  ["HEAL PREDICTION"] = "ПРОГНОЗ ИСЦЕЛЕНИЯ",
  ["STATS AND BAG ARROWS (STATSINFO)"] = "ХАРАКТЕРИСТИКИ И СТРЕЛКИ СУМОК (STATSINFO)",
  ["POINTS AND SOUNDS (RESOURCEDING)"] = "ОЧКИ И ЗВУКИ (RESOURCEDING)",
  ["RANGE"] = "ДАЛЬНОСТЬ",
  ["PERFORMANCE"] = "ПРОИЗВОДИТЕЛЬНОСТЬ",
  ["FRAMES AND API"] = "РАМКИ И API",

  -- общие заголовки разделов вкладок
  ["FILL"] = "ЗАЛИВКА",
  ["OUTLINE"] = "КОНТУР",
  ["KILL ICON"] = "ЗНАЧОК УБИЙСТВА",
  ["ABSORB NUMBER"] = "ЧИСЛО ПОГЛОЩЕНИЯ",
  ["POSITION"] = "ПОЛОЖЕНИЕ",
  ["INDICATORS"] = "ИНДИКАТОРЫ",
  ["FEATURES"] = "ФУНКЦИИ",
  ["EXPERIMENTS (ON BY DEFAULT IN THIS BETA)"] = "ЭКСПЕРИМЕНТЫ (В ЭТОЙ БЕТЕ ВКЛЮЧЕНЫ ПО УМОЛЧАНИЮ)",

  -- переключатель стиля значков и группы значков убийства
  ["Art style"] = "Стиль значков",
  ["Style: %s"] = "Стиль: %s",
  ["Art style: %s."] = "Стиль значков: %s.",
  ["Art style: %s. /upt art 2d | pixel | classic"] = "Стиль значков: %s. /upt art 2d | pixel | classic",
  ["Stylized 2D"] = "Стилизованный 2D",
  ["Pixel Art"] = "Пиксель-арт",
  ["Switches Soul Shards, combo orbs, range marks, upgrade arrows and markers between Stylized 2D, Pixel Art and Classic. Takes effect at once."] =
    "Переключает осколки души, сферы серии, метки дальности, стрелки улучшений и маркеры между стилизованным 2D, пиксель-артом и классикой. Действует сразу.",
  ["Faceted skull"] = "Гранёный череп",
  ["Lethal crosshair"] = "Смертельный прицел",
  ["Execution blades"] = "Клинки казни",
  ["Crystal checkmark"] = "Кристальная галочка",
  ["Crystal cross"] = "Кристальный крест",
  ["Pixel skull"] = "Пиксельный череп",
  ["Pixel crosshair"] = "Пиксельный прицел",
  ["Pixel blades"] = "Пиксельные клинки",
  ["Pixel checkmark"] = "Пиксельная галочка",
  ["Pixel cross"] = "Пиксельный крест",
  ["Show what execute/finisher is watched and test its icon for 5 seconds."] =
    "Показать отслеживаемую способность добивания и проверить её значок в течение 5 секунд.",
  ["Manage profiles..."] = "Управление профилями...",
  ["Click to switch profile or manage character profiles."] =
    "Нажмите, чтобы переключить профиль или управлять профилями персонажей.",
  ["Changes saved. Type /reload to apply."] = "Изменения сохранены. Введите /reload для применения.",
  ["Profile \"%s\" reset to defaults. Type /reload to apply."] =
    "Профиль \"%s\" сброшен к стандартным настройкам. Введите /reload для применения.",
  ["%s settings reset to defaults. Type /reload to apply."] =
    "Настройки %s сброшены к стандартным. Введите /reload для применения.",
})
