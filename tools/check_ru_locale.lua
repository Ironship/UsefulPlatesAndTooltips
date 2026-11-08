-- Run from the repository root: lua tools\check_ru_locale.lua [SavedVariables.lua]
-- Optional input is read as spell records only, never executed or written.
local modules = {}
local BIT = { Module = function(name)
  modules[name] = modules[name] or {}
  return modules[name]
end }
local function load(path) assert(loadfile(path))("UPT", BIT) end
local root = "Modules\\SpellDamageInfo\\"
for _, file in ipairs({ "Parser", "Parser_enUS", "Parser_deDE", "Parser_ruRU", "Locale", "Locale_ruRU" }) do
  load(root .. file .. ".lua")
end
local ns, Parser = modules.SpellDamageInfo, modules.SpellDamageInfo.Parser

-- Minimal records from the Russian Forever dump, not the account's SavedVariables.
local samples = {
  { 10, "Осыпает выбранную область ледяными осколками, нанося 192 ед. урона от магии льда за 8 сек.",
    { show = "parsed", parsed = { dot = { total = 192, duration = 8 }, school = "frost" } } },
  { 17, "Вытягивает частичку души участника группы и создает из нее щит, поглощающий 44 ед. урона. Время действия – 30 сек. Пока персонаж защищен, применение заклинаний не может быть прервано получением урона. Повторно применить щит можно только через 15 сек.",
    { show = "special", special = { absorb = 44 }, parsed = false } },
  { 53, "Удар в спину, наносящий цели 150% урона от оружия и еще 15 ед. Для удара нужно находиться за спиной цели и держать кинжал в правой руке. Длина серии приемов увеличивается на 1.",
    { show = "weapon", weapon = { pct = 150, bonus = 15 } } },
  { 99, "Друид издает устрашающий рев, снижающий силу атаки в ближнем бою находящихся рядом противников на 46. Время действия – 30 сек.",
    { reduction = { amount = 46, stat = "attackpower", percent = false } } },
  { 116, "В противника летит ледяная стрела, наносящая от 18 до 20 ед. урона от магии льда и снижающая скорость передвижения на 40% на 5 сек.",
    { show = "parsed", parsed = { direct = { min = 18, max = 20 }, school = "frost" } } },
  { 133, "Бросок огненного шара, который наносит 14 - 23 ед. урона от огня единовременно и 2 ед. урона от огня в течение 4 сек.",
    { parsed = { direct = { min = 14, max = 23 }, dot = { total = 2, duration = 4 } } } },
  { 139, "Излечение цели на 45 ед. в течение 15 сек.",
    { parsed = { hot = { total = 45, duration = 15 } }, healing = { target = true } } },
  { 172, "Порча цели с нанесением ей 40 ед. урона от темной магии за 12 сек.",
    { parsed = { dot = { total = 40, duration = 12 }, school = "shadow" } } },
  { 331, "Исцеление дружественной цели на 36 - 47 ед.",
    { parsed = { heal = { min = 36, max = 47 } } } },
  { 687, "Усиливает броню на 40 и повышает скорость восстановления здоровья на 3 ед. раз в 5 сек. Время действия – 30 мин.",
    { parsed = { hp5 = 3 } } },
  { 689, "Вы похищаете у цели 10 ед. здоровья раз в 1 сек. и восполняете себе здоровье в том же объеме. Время действия – 5 сек.",
    { parsed = { transfer = true, dot = { total = 50, duration = 5 }, hot = { total = 50, duration = 5 } } } },
  { 702, "Уменьшает наносимый целью физический урон на 4 ед. на 2 мин. Одновременно на цель может действовать только одно проклятие каждого чернокнижника.",
    { reduction = { amount = 4, stat = "damage", percent = false } } },
  { 755, "Передает прислужнику 12 ед. здоровья раз в сек. в течение 10 сек. Требуется поддержание заклинания. Создает сниженный уровень угрозы.",
    { parsed = { petHeal = true, healthCost = 120 } } },
  { 772, "Наносит цели кровоточащую рану, из-за которой она теряет 15 ед. здоровья за 9 сек.",
    { parsed = { dot = { total = 15, duration = 9 }, school = "physical" } } },
  { 1454, "Преобразует 48 ед. здоровья в 48 ед. маны. Дух позволяет преобразовать больше здоровья.",
    { special = { healthCost = 48, mana = { min = 48, max = 48 } } } },
  { 1822, "Наносит противнику глубокую рану. Противник теряет 27 и дополнительно 60 здоровья за 9 сек. в результате кровотечения. Длина серии приемов увеличивается на 1.",
    { parsed = { direct = { min = 27, max = 27 }, dot = { total = 60, duration = 9 } } } },
  { 1949, "Погружает заклинателя и находящихся рядом с ним противников в волны пламени, наносящие заклинателю 82 ед. урона от огня, а его противникам – 82 ед. урона от огня раз в 1 сек. Время действия – 15 сек.",
    { parsed = { dot = { total = 1230, duration = 15 }, school = "fire" } } },
  { 2098, "Завершающий удар, наносящий урон в зависимости от длины серии:\r\n1 прием: 6-10 ед. урона\r\n 2 приема: 11-15 ед. урона\r\n 3 приема: 16-20 ед. урона\r\n 4 приема: 21-25 ед. урона\r\n 5 приемов: 26-30 ед. урона.",
    { show = "finisher", finisher = { top = 5, points = { [1] = { min = 6, max = 10 }, [5] = { min = 26, max = 30 } } } } },
  { 2835, "Смазать оружие ядом, действующим в течение 30 мин.\r\nКаждый удар с вероятностью 30% отравляет противника ядом, наносящим 24 ед. урона от сил природы за 12 сек. Суммируется на каждой цели до 5 раз. Количество зарядов – 90.",
    { parsed = { dot = { total = 24, duration = 12 } }, proc = 30 } },
  { 3674, "Снижает скорость передвижения цели на 70%, наносит 150 ед. урона от темной магии и похищает 150 ед. маны за 30 сек.",
    { parsed = { dot = { total = 150, duration = 30 } } } },
  { 5143, "Атака противника чародейскими снарядами, наносящими 24 ед. урона от тайной магии раз в секунду в течение 3 сек.",
    { parsed = { dot = { total = 72, duration = 3 }, school = "arcane" } } },
  { 5394, "Создание рядом с заклинателем Тотема исцеляющего потока прочностью 5 ед. и временем существования 5 мин., который исцеляет участников группы на расстоянии 30 м. на 5 ед. здоровья раз в 2 сек.",
    { show = "special", special = { heal = { min = 5, max = 5 }, every = 2 } } },
  { 8017, "Усиливает оружие шамана, увеличивая силу атаки в ближнем бою на 45 и увеличивая угрозу, создаваемую при использовании этого оружия. Время действия – 60 мин.",
    { show = "weapon", weapon = { kind = "ap", amount = 45 } } },
  { 20271, "Высвобождает энергию печати и обрушивает ее на противника. Не поглощает эффект печати. Каждая печать имеет индивидуальный эффект при свершении \"Правосудия\".",
    { show = "judgement", isJudgement = true } },
  { 20473, "Взрывает цель с помощью энергии светлой магии, нанося 175 - 189 ед. урона от светлой магии противнику или обеспечивая 150 - 162 исцеления союзнику.",
    { parsed = { direct = { min = 175, max = 189 }, heal = { min = 150, max = 162 } } } },
  { 401502, "Выпускает стрелу ледяного огня, наносящую 92 - 108 ед. урона от ледяного огня сразу и еще 27 ед. урона от ледяного огня за 9 сек., а также снижающую скорость передвижения цели на 40%. В расчет берется наименьшее из значений сопротивления огню и магии льда. Заклинание относится к обеим школам.",
    { parsed = { direct = { min = 92, max = 108 }, dot = { total = 27, duration = 9 }, school = "frostfire" } } },
  { 403629, "Поражает противника стрелой хаотичного пламени, наносящей 56-71 ед. урона от магии Хаоса. Стрела Хаоса всегда попадает в цель, преодолевает сопротивление противника и позволяет вашим заклинаниям огня игнорировать эффекты поглощения. Монстры, уровень которых превышает ваш на 4 или более, с высокой вероятностью сопротивляются \"Стреле Хаоса\".",
    { parsed = { direct = { min = 56, max = 71 }, school = "chaos" } } },
  { 1240770, "Восстанавливает вам и союзнику 283 - 341 ед. здоровья. Создает низкий уровень угрозы.",
    { parsed = { heal = { min = 283, max = 341 }, healTargets = 2 } } },
  { 118, "Превращает противника в овцу, которая бродит вокруг в течение 20 сек. Овца не может атаковать и применять заклинания, но быстро восполняет здоровье и ману. Урон снимает эффект. Одновременно действует только на одну цель. Действует только на животных, гуманоидов и зверьков.",
    { parsed = false, weapon = false, special = false } },
  { 131, "Позволяет цели дышать под водой в течение 10 мин.",
    { parsed = false, unread = "utility" } },
  { 8129, "Вытягивает у цели 191 - 203 ед. маны. За каждую единицу похищенной маны цель получает 0,5 ед. урона от темной магии.",
    { parsed = false, unread = "unread-damage" } },
  { 6201, "Создает крошечный камень здоровья, способный восстановить 120 ед. здоровья.\r\n\r\nСозданные камни исчезают при выходе из игры на 15 мин. и более.",
    { parsed = false, unread = "utility" } },
  { 12294, "Жестокий удар, наносящий урон от оружия и еще 85 ед., а также оставляющий серьезную рану, снижающую эффективность исцеления на 50% в течение 10 сек.",
    { show = "weapon", weapon = { kind = "weapon", pct = 100, bonus = 85 } } },
  { 8232, "Усиливает ваше оружие ветром. Каждый удар с вероятностью 20% позволяет провести еще 2 атаки с увеличенной на 46 силой атаки ближнего боя. Применение к основному оружию не дает также получать эффект тотема неистовства ветра. Время действия – 60 мин.",
    { show = "weapon", weapon = { kind = "extra", attacks = 2, amount = 46 } } },
  { 19434, "Прицельный выстрел, наносящий 40 ед. дополнительного урона в дальнем бою. \"Прицельный выстрел\" имеет общее время восстановления с \"Залпом\".",
    { show = "weapon", weapon = { kind = "next", bonus = 40, ranged = true } } },
  { 413259, "Взрыв темной магии, наносящий цели и противникам рядом с ней от 10 до 11 ед. урона от темной магии раз в 1 сек. в течение 6 сек. Действует в радиусе 10 м от цели.",
    { parsed = false, unread = "unread-damage", reason = "periodic-range" } },
}

local function contains(actual, expected, label)
  assert(type(actual) == "table", label .. ": missing table")
  for key, value in pairs(expected) do
    local path = label .. "." .. tostring(key)
    if type(value) == "table" then contains(actual[key], value, path)
    else assert(actual[key] == value, path .. ": expected " .. tostring(value) .. ", got " .. tostring(actual[key])) end
  end
end
for _, sample in ipairs(samples) do
  contains(Parser.Read(sample[2], "ru"), sample[3], tostring(sample[1]))
end
contains(Parser.Read(samples[5][2]), samples[5][3], "auto-detect")
contains(Parser.Read(samples[5][2], "en"), { lang = "ru", parsed = { direct = { min = 18, max = 20 } } },
  "Russian text on English-reporting Forever client")
contains(Parser.Read("Deals 18 to 20 Frost damage.", "ru"), {
  lang = "en", parsed = { direct = { min = 18, max = 20 }, school = "frost" },
}, "mixed-English")
contains(Parser.Read("Verursacht 12 Sek. lang 40 Punkt(e) Schattenschaden.", "de"), {
  parsed = { dot = { total = 40, duration = 12 }, school = "shadow" },
}, "German")
contains(Parser.Read("Deals 20 Fire damage over 1 min.", "en"), {
  parsed = { dot = { total = 20, duration = 60 } },
}, "English-minutes")

GetLocale = function() return "enUS" end
GetCVar = function() return "ruRU" end
ns.DecideLangsAtLoad()
ns.SetInterfaceAndRefreshL("auto")
assert(ns.DescriptionLang() == "ru" and ns.L.lang == "ru")
ns.SetInterfaceAndRefreshL("en")
assert(ns.L.lang == "en")
local saved, onLoad, langCommand = {}, nil, nil
BIT.name = "UPT"
BIT.DB = function() return saved end
BIT.RegisterCommand = function(_, command) langCommand = command end
BIT.Say = function() end
CreateFrame = function()
  return {
    RegisterEvent = function() end, UnregisterEvent = function() end,
    SetScript = function(_, _, callback) onLoad = callback end,
  }
end
load("Core\\Locale.lua")
local toc = assert(io.open("UsefulPlatesAndTooltips.toc", "r"))
for line in toc:lines() do
  if line:match("^Locales\\ruRU\\") then load(line) end
end
toc:close()
local frame = CreateFrame()
onLoad(frame, "ADDON_LOADED", "UPT")
assert(BIT.L("Spells") ~= "Spells", "UPT auto must follow textLocale=ruRU even when GetLocale=enUS")
langCommand("en")
onLoad(frame, "ADDON_LOADED", "UPT")
assert(BIT.L("Spells") == "Spells", "explicit English must override automatic Russian")
langCommand("ru")
onLoad(frame, "ADDON_LOADED", "UPT")
assert(BIT.L("Spells") ~= "Spells", "/upt lang ru alias")
load("Modules\\DoTInfo\\Locale.lua")
load("Modules\\DoTInfo\\Locale_ruRU.lua")
local total, school, duration = modules.DoTInfo.locale.parseDot(samples[8][2], 1)
assert(total == 40 and school == 32 and duration == 12)
assert(modules.DoTInfo.locale.parseDot(samples[19][2], 1) == nil, "poison enchant is not a target DoT")

if arg[1] then
  local file = assert(io.open(arg[1], "rb"))
  local source = file:read("*a")
  file:close()
  local spells = assert(source:match('UsefulPlatesAndTooltips_SpellDamageInfoDB = {%s*%["dumpAll"%] = {%s*%["spells"%] = {(.-)%s*},%s*%["'),
    "No SDI dumpAll.spells in input")
  local records, counts, byID = 0, {}, {}
  for id, text in spells:gmatch('%["id"%] = (%d+),%s*%["text"%] = "([^\r\n]*)",') do
    text = text:gsub("\\(.)", function(c)
      local escapes = { n = "\n", r = "\r", t = "\t", ['"'] = '"', ["\\"] = "\\" }
      assert(escapes[c], "Unsupported SavedVariables string escape: " .. c)
      return escapes[c]
    end)
    local e = Parser.Read(text, "ru")
    local kind = e.show or (e.reduction and "reduction") or (e.isSeal and "seal") or e.unread or "unclassified"
    counts[kind] = (counts[kind] or 0) + 1
    records, byID[tonumber(id)] = records + 1, text
  end
  for _, sample in ipairs(samples) do
    assert(byID[sample[1]] == sample[2], "Dump record changed: " .. sample[1])
    contains(Parser.Read(byID[sample[1]], "ru"), sample[3], "dump." .. sample[1])
  end
  assert(records > 0, "No spell records")
  for _, kind in ipairs({ "parsed", "special", "weapon", "finisher", "judgement", "reduction",
    "seal", "utility", "unread-damage", "unread-effect", "unclassified" }) do
    print(kind .. ": " .. (counts[kind] or 0))
  end
  print("Read-only dump audit: " .. records .. " records")
end
print("Russian locale, SDI and DoT checks passed (" .. #samples .. " dump samples).")
