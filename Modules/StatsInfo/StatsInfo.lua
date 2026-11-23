-- UsefulPlatesAndTooltips module StatsInfo: in an item's tooltip, what it changes against what you wear.
-- Copyright (c) 2026 Ironship. GPL-3.0-or-later, see LICENSE.
--
-- Written from scratch after the idea of RatingBuster (Whitetooth, GPL), none of whose code or
-- tables are used. The stats are the game's own: C_Item.GetItemStats, with the client's names for
-- them, so nothing here depends on the language of the tooltip.
--
-- Under each stat, what it gives the character (M.Worth). Only what the game shows to hold: see
-- there. /upt probe records what this client reports (the functions it has, the character's stats
-- and chances, and the equipped items' stats and tooltip lines) into the saved variables; the
-- breakdown was built from five of them.

local _, BIT = ...
local M = BIT.Module("StatsInfo")

local DEFAULTS = {
  compare = true, -- the differences against the equipped item
  worth = true,   -- under each difference, what it gives the character
  specs = true,   -- how each spec of the class rates the item (Weights.lua)
  icons = true,   -- icons and one line each, instead of words
  bagMarkers = true,   -- the small green/red arrows over the game's own bag buttons
  questMarkers = true, -- every upgrade reward; double arrow on the best, or the coin if none
  bagSpecIcons = true, -- on an up arrow, the beneficiary spec's icon (+N for the rest)
  worldMarkers = true, -- the same arrows on loot, need/greed rolls and merchant buttons
  bagArrowCorner = "topright", -- which corner of the item the arrows sit in (BagMarkers.lua M.MarkerLayout)
  bagArrowX = 0, bagArrowY = 0, -- a nudge from that corner, in pixels
  bagArrowScale = 100,         -- the arrows' size in percent
  bagNativeUp = true,          -- Blizzard bags: the game's own upgrade arrow for an upgrade (its place is the game's)
  detail = "full",  -- tooltip density: "compact" (one line; Shift or "full" expands it)
  specFilter = "all", -- which specs are rated, in the tooltip, on the arrows and on quest rewards: "all", "auto" (the talent tree in use) or "manual" (the roles below)
  specDamage = true,  -- manual: damage specs
  specTank = true,    -- manual: tank specs (and the tank caps lines)
  specHealing = true, -- manual: healer specs
  caps = true,        -- hit and expertise count only up to their caps (spell hit 17%, melee 8%, expertise 6.5%)
  effects = true,     -- the ratings count an item's effects (trinkets, procs) and its set's bonuses (Effects.lua)
  consumables = true, -- elixirs, flasks, food, potions and scrolls: what the buff is worth against your gear
  tankCaps = true,    -- the uncrittable and avoidance lines under a tank's gear (a tank spec still has to be rated)
}

-- Inventory slots an item of an equip location goes into. Two slots: compared with each.
local SLOTS = {
  INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_BODY = { 4 },
  INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 },
  INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 },
  INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 }, INVTYPE_WEAPON = { 16, 17 },
  INVTYPE_SHIELD = { 17 }, INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_WEAPONOFFHAND = { 17 },
  INVTYPE_HOLDABLE = { 17 }, INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 },
  INVTYPE_RELIC = { 18 }, INVTYPE_TABARD = { 19 },
}
-- A two-hander replaces both hands: compared with the two together.
local BOTH_HANDS = { INVTYPE_2HWEAPON = true }

-- The stats shown first, in this order; any other stat an item has comes after them.
local FIRST = {
  "ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_AGILITY_SHORT", "ITEM_MOD_STAMINA_SHORT", "ITEM_MOD_INTELLECT_SHORT",
  "ITEM_MOD_SPIRIT_SHORT", "RESISTANCE0_NAME", "ITEM_MOD_SPELL_POWER_SHORT", "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT",
}
local RANK = {}
for i, key in ipairs(FIRST) do RANK[key] = i end

local settings

local function isSecret(v)
  if type(issecretvalue) ~= "function" then return false end
  local ok, secret = pcall(issecretvalue, v)
  return ok and secret or false
end

local function ask(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b, c, d, e, f, g = pcall(fn, ...)
  if not ok then return nil end
  return a, b, c, d, e, f, g
end

-- One tooltip build asks itemStats for the same link many times (Compare once, SpecRatings
-- once per spec's measure, the tank gate again) and the character's own answers once per
-- stat line. The memo below holds those answers from the outermost call of one build to its
-- end (memoized wraps the public entries), so a build pays for each link once: no stats are
-- kept between builds, so nothing goes stale when the client's data arrives, and outside a
-- build (a direct call, /upt probe) nothing is cached at all -- exactly the old behavior.
-- The tables handed out are shared within the build and read-only to their takers.
local statsMemo, charMemo = {}, {}
local memoDepth = 0
local NO_VALUE = {}

-- Build-scoped scratch tables, one arena per allocation site (take below). One tooltip
-- build used to allocate a fresh table for every part, row, record and buffer in it --
-- 140 tables per hover (harness-measured), all garbage the moment the tooltip is built,
-- and a hover storm turns that into GC stutter. take() hands out the next table of a
-- site's arena, wiped, and the arena rewinds when a new build opens: after the first
-- hover's high-water mark a warm hover allocates none of them and the live tables stop
-- growing. Only builds share them (memoDepth > 0, i.e. inside memoized's pcall): a
-- direct call outside a build gets plain fresh tables, so every result that leaves a
-- build (M.Compare, M.SpecRatings, M.TooltipLines to BagMarkers, QuestMarkers and the
-- test suites) is exactly the private table it always was.
local scratch = {}

local function resetScratch()
  for _, site in pairs(scratch) do site.n = 0 end
end

local function take(name)
  if memoDepth <= 0 then return {} end
  local site = scratch[name]
  if not site then
    site = { n = 0 }
    scratch[name] = site
  end
  local i = site.n + 1
  site.n = i
  local t = site[i]
  if t == nil then
    t = {}
    site[i] = t
  else
    for k in pairs(t) do t[k] = nil end -- reuse must read as a fresh {}
  end
  return t
end

-- Fresh tables, never pooled: the public entries' own results outlive their build.
local function fresh() return {} end

local function memoOpen()
  if memoDepth == 0 then
    for k in pairs(statsMemo) do statsMemo[k] = nil end
    for k in pairs(charMemo) do charMemo[k] = nil end
    resetScratch()
  end
  memoDepth = memoDepth + 1
end

local function memoClose()
  memoDepth = memoDepth - 1
  if memoDepth <= 0 then
    memoDepth = 0
    for k in pairs(statsMemo) do statsMemo[k] = nil end
    for k in pairs(charMemo) do charMemo[k] = nil end
  end
end

-- The entries that are one build: TooltipLines is the hover itself; Compare and SpecRatings
-- are its parts (BagMarkers and QuestMarkers call them directly too, where each call is one
-- build of its own). Each of them returns exactly one value, and it comes back unchanged:
-- pcall keeps an error from leaking the open build (it is always closed again on the way
-- out) and the error goes up unchanged.
local function memoized(fn)
  return function(...)
    memoOpen()
    local ok, a = pcall(fn, ...)
    memoClose()
    if not ok then error(a, 0) end
    return a
  end
end

-- What the character is, asked at most once per build: its class behind the specs, and the
-- worth lines' per-point answers (they do not depend on n). Fresh again at every build; a
-- direct M.Worth call outside a build asks live, as it always did.
local function charFact(key, compute)
  if memoDepth > 0 then
    local hit = charMemo[key]
    if hit ~= nil then
      if hit == NO_VALUE then return nil end
      return hit
    end
  end
  local v = compute()
  if memoDepth > 0 then
    if v == nil then charMemo[key] = NO_VALUE else charMemo[key] = v end
  end
  return v
end

-- The class behind M.SPECS, or nil; one read per build. The compute bodies are named
-- functions, hoisted out of the call sites: a closure literal per call is itself one
-- allocation per hover and per spec line, and these run a dozen times per tooltip.
local function computeClass()
  local _, class = ask(UnitClass, "player")
  return type(class) == "string" and not isSecret(class) and class or nil
end

local function charClass()
  return charFact("class", computeClass)
end

-- The name the client gives a stat key ("Beweglichkeit"), or nil when it has none.
local function statName(key)
  if type(key) ~= "string" or isSecret(key) then return nil end
  local name = _G[key]
  if type(name) == "string" and name ~= "" then return name end
  return nil
end

-- withoutEnchant and tooltipEnchant are defined after RATINGS, in the ENCHANT block below.
local withoutEnchant, tooltipEnchant

-- An item's stats, key -> number, or {}. A key the client has no name for is left out: the same
-- stat also comes under a key it names (Forever gives a ring's frost resistance both as
-- RESISTANCE4_NAME and as ITEM_MOD_FROST_RESISTANCE_SHORT, the second unnamed).
-- C_Item.GetItemStats may leave an item's enchant out (the probe proved it: the Embossed Leather
-- Vest reads 62 Armor and 2 Stamina while its tooltip says "Enchanted: Stamina +1 and Armor +8"),
-- so a key the parsed tooltip enchant names is reconciled against the client's own answer for the
-- link without its enchant field; the answer for the whole link stays the baseline, and a missing
-- clean answer or enchant never drops or doubles a stat. A secret clean stat (the client hides a
-- value in combat, marking it with issecretvalue) is never added to or guessed from: the baseline
-- keeps the stat.
local function itemStats(link, alloc)
  -- A nil or secret link (in combat) must never reach the link rewrite or the enchant memo: the
  -- client raises on secret keys, so nothing is asked and nothing is cached.
  if type(link) ~= "string" or isSecret(link) then return alloc("itemStats") end
  -- Within one tooltip build the answer is asked for the same link a dozen times and more: it
  -- is computed once per build and handed out read-only for the rest of it (see memoOpen).
  if memoDepth > 0 then
    local hit = statsMemo[link]
    if hit then return hit end
  end
  -- Baseline: the client's own GetItemStats answer for the whole link. Some clients count an
  -- enchant in it, some leave it out, and that answer is never dropped or added to blindly.
  -- Where both a trusted parse of the enchant and a stats answer for the link without its
  -- enchant field exist, a key the enchant names reads base + enchant; every other key keeps the
  -- baseline. Without the clean answer (an error, a nil) nothing is invented or doubled: the
  -- baseline stands, a missing enchant beats a wrong stat.
  local out = alloc("itemStats")
  local stats = ask(C_Item and C_Item.GetItemStats, link)
  if type(stats) ~= "table" then stats = ask(GetItemStats, link) end
  if type(stats) == "table" then
    for k, v in pairs(stats) do
      -- NaN (NaN ~= 0 in Lua) and infinities must never reach the weights arithmetic
      if type(k) == "string" and statName(k) and not isSecret(v) and type(v) == "number"
          and v ~= 0 and v == v and v ~= math.huge and v ~= -math.huge then out[k] = v end
    end
  end
  local plain = withoutEnchant(link)
  local clean = ask(C_Item and C_Item.GetItemStats, plain)
  if type(clean) ~= "table" then clean = ask(GetItemStats, plain) end
  if type(clean) == "table" then
    for k, v in pairs(tooltipEnchant(link)) do
      if type(k) == "string" and statName(k) and not isSecret(v) and type(v) == "number" and v ~= 0
          and v == v and v ~= math.huge and v ~= -math.huge then
        local base = clean[k]
        -- A secret clean stat (the client hides the value in combat, marking it with
        -- issecretvalue -- the value may still be a number) is never arithmetic'd on or
        -- guessed from: the full link's own answer keeps the stat.
        if not isSecret(base) then
          if type(base) ~= "number" then base = 0 end
          out[k] = base + v
        end
      end
    end
  end
  if memoDepth > 0 then statsMemo[link] = out end
  return out
end
local function itemStatsFresh(link) return itemStats(link, fresh) end
M.ItemStats = memoized(itemStatsFresh)

local function equipLoc(link)
  local _, _, _, loc = ask(C_Item and C_Item.GetItemInfoInstant, link)
  if loc == nil then _, _, _, loc = ask(GetItemInfoInstant, link) end
  return type(loc) == "string" and not isSecret(loc) and loc or nil
end

-- CanUseItem checks the player's restrictions on passive gear too; IsUsableItem checks
-- an item's usable action and can reject an ordinary belt. Missing APIs prove nothing.
function M.CanEquipItem(link)
  if type(link) ~= "string" or isSecret(link) then return nil end
  local canUse = C_PlayerInfo and C_PlayerInfo.CanUseItem
  if type(canUse) ~= "function" then return true end
  local id = ask(C_Item and C_Item.GetItemInfoInstant, link)
  if isSecret(id) then return nil end
  if id == nil then id = ask(GetItemInfoInstant, link) end
  if isSecret(id) or type(id) ~= "number" or id ~= id or id <= 0 or id == math.huge then return nil end
  local cached = ask(C_Item and C_Item.IsItemDataCachedByID, id)
  if isSecret(cached) or cached == false then return nil end
  local allowed = ask(canUse, id)
  if not isSecret(allowed) and type(allowed) == "boolean" then return allowed end
  return nil
end

local function equipped(slot)
  local link = ask(GetInventoryItemLink, "player", slot)
  -- A secret link is not a link: it reads as a string (type() cannot tell), but Compare
  -- equates it with the new link below and that comparison raises on a combat-secret value
  -- (the bag handlers went down to it). A hidden link is an unknown baseline,
  -- distinct from a genuinely empty slot (nil).
  if isSecret(link) then return nil, true end
  if type(link) ~= "string" then return nil, link ~= nil end
  return link
end

-- Whether the client's answers for link can be trusted yet. The new link has this guard in
-- Compare; a worn link needs it too: an heirloom whose stats are not cached yet reads as {},
-- and its block would print the new item's full stats under the worn item's name (a duplicated
-- recommendation). Uncached worn stats skip the block; the tooltip is rebuilt on arrival.
local function itemCached(link)
  local id = ask(C_Item and C_Item.GetItemInfoInstant, link)
  if isSecret(id) then return false end
  if not id or not (C_Item and C_Item.IsItemDataCachedByID) then return true end -- cannot tell: old behavior
  return ask(C_Item.IsItemDataCachedByID, id) ~= false
end

-- The differences' order: the stat block's own order first (RANK), then the client's name.
-- Named and shared: an anonymous comparator was one more closure per comparison per hover.
local function diffSort(a, b)
  local ra, rb = RANK[a.key] or 100, RANK[b.key] or 100
  if ra ~= rb then return ra < rb end
  return (statName(a.key) or a.key) < (statName(b.key) or b.key)
end

-- target: the slot the item would go into, when it is not the one compared with (a shield
-- against the two-hander it would take off). Named, not a closure per M.Compare call:
-- it runs twice per hover and used to allocate twice per hover.
local function compareWith(slots, target, new, comparisons, alloc)
  local old, names, wornSlots = alloc("cmpOld"), alloc("cmpNames"), alloc("cmpWornSlots")
  for _, slot in ipairs(slots) do
    local worn, unknown = equipped(slot)
    if unknown then return end -- an unreadable worn item is never priced as an empty slot
    if worn then
      local wornStats = itemStats(worn, alloc)
      if next(wornStats) == nil and not itemCached(worn) then
        return -- stats still loading: no invented block; the tooltip rebuilds on arrival
      end
      names[#names + 1] = worn
      wornSlots[#wornSlots + 1] = slot
      for k, v in pairs(wornStats) do old[k] = (old[k] or 0) + v end
    end
  end
  local diffs, keys = alloc("cmpDiffs"), alloc("cmpKeys")
  for k in pairs(new) do keys[k] = true end
  for k in pairs(old) do keys[k] = true end
  for k in pairs(keys) do
    local d = (new[k] or 0) - (old[k] or 0)
    -- SI-124: a diff that renders as +0.0 (e.g. +0.04 DPS) is noise, not a line.
    if d ~= 0 and math.abs(d) >= 0.05 then
      local entry = alloc("cmpDiff")
      entry.key, entry.diff = k, d
      diffs[#diffs + 1] = entry
    end
  end
  -- A named comparison with no worn stats behind it would print the new item's full
  -- numbers under the worn item's name (a duplicated recommendation): the worn data was
  -- unavailable (uncached heirloom, an answer the parser does not name). The block is
  -- skipped; the empty-slot block carries the same numbers honestly. An all-empty
  -- comparison ("the same stats") stays: it is true either way.
  if #names > 0 and next(old) == nil and #diffs > 0 then return end
  -- a sort of zero or one element is already in order (no call, no comparator run)
  if #diffs > 1 then table.sort(diffs, diffSort) end
  -- againstSlots: the slots compared with, an empty one included; wornSlots lists only the
  -- ones carrying an item (it indexes against, SpecRatings needs it so). The tooltip names
  -- the block's slot from againstSlots: a ring's two blocks otherwise read as one repeated.
  local record = alloc("cmpRecord")
  record.against, record.slots, record.againstSlots = names, wornSlots, slots
  record.diffs = diffs
  record.offHand = (target or (#slots == 1 and slots[1])) == 17
  comparisons[#comparisons + 1] = record
end

-- What wearing link instead of what is in its slot changes: a list of { key, diff }, sorted,
-- and what it is compared with; nil when there is nothing to compare with, or when link is
-- worn (in either of two slots). Rings and trinkets: one comparison with each worn. A one-hand
-- weapon: with the main hand, an empty one too (it goes there, and a weapon in the off hand stays;
-- set against the off hand, an identical dagger was rated as its main-hand worth over its off-hand one).
local function compareBody(link, alloc)
  if type(link) ~= "string" or isSecret(link) then return nil end
  if M.CanEquipItem(link) ~= true then return nil end
  local loc = equipLoc(link)
  if not loc then return nil end
  -- Not before the client has the item: its stats would read as none, every stat lost. The tooltip is
  -- built again when the data arrives.
  local id = ask(C_Item and C_Item.GetItemInfoInstant, link)
  if isSecret(id) then return nil end
  if id and C_Item and C_Item.IsItemDataCachedByID and ask(C_Item.IsItemDataCachedByID, id) == false then return nil end
  local slots
  if BOTH_HANDS[loc] then
    slots = alloc("compSlots")
    slots[1], slots[2] = 16, 17
  else
    slots = SLOTS[loc]
    if not slots then slots = alloc("compSlots") end
  end
  for _, slot in ipairs(slots) do
    if equipped(slot) == link then return nil end -- the item worn
  end
  local new = itemStats(link, alloc)
  local comparisons = alloc("comparisons")
  local mainHand, unknownMainHand = equipped(16)
  if unknownMainHand and #slots == 1 and slots[1] == 17 then return nil end
  if BOTH_HANDS[loc] then
    local s = alloc("compSlots")
    s[1], s[2] = 16, 17
    compareWith(s, nil, new, comparisons, alloc)
  elseif loc == "INVTYPE_WEAPON" then
    local s = alloc("compSlots")
    s[1] = 16
    compareWith(s, nil, new, comparisons, alloc) -- it goes into the main hand
    -- ...or, for a dual wielder, into the off hand: with a weapon worn there, the item is also set
    -- against that one (priced as an off-hand weapon on both sides: compareWith marks the block offHand).
    -- Judged only against the main hand, a dagger that beats a worn off-hand dagger read as a loss, and
    -- the bag arrow went red. An empty off hand, a shield or a held item is no off-hand weapon: no block.
    local offHandItem = equipped(17)
    local offLoc = offHandItem and equipLoc(offHandItem)
    if offLoc == "INVTYPE_WEAPON" or offLoc == "INVTYPE_WEAPONOFFHAND" then
      local o = alloc("compSlots")
      o[1] = 17
      compareWith(o, nil, new, comparisons, alloc)
    end
  elseif #slots == 1 and slots[1] == 17 and mainHand and equipLoc(mainHand) == "INVTYPE_2HWEAPON" then
    local s = alloc("compSlots")
    s[1] = 16
    compareWith(s, 17, new, comparisons, alloc) -- an off-hand item takes the two-hander off
  else
    for _, slot in ipairs(slots) do
      local s = alloc("compSlots")
      s[1] = slot
      compareWith(s, nil, new, comparisons, alloc)
    end
  end
  return #comparisons > 0 and comparisons or nil
end

function M.Compare(link)
  return compareBody(link, fresh)
end
M.Compare = memoized(M.Compare)

-- Pure number -> text formatters, memoized. One hover of the same item formats the same
-- values again and again ("+8", "-0.2", "0.28% crit", "13% better for survival"), and
-- every call allocated fresh strings -- they are the other half of the hover's garbage.
-- Same input, same bytes out: a lookup cannot change a tooltip. Bounded like the enchant
-- memo: when a cache fills, it is wiped and grows again (never without limit).
local TEXT_MEMO_MAX = 256

-- (number) -> text
local function memo1(fn)
  local cache, n = {}, 0
  return function(v)
    if v ~= v then return fn(v) end -- NaN is never a table key; nor a number here
    local hit = cache[v]
    if hit then return hit end
    local text = fn(v)
    if n >= TEXT_MEMO_MAX then
      for k in pairs(cache) do cache[k] = nil end
      n = 0
    end
    cache[v] = text
    n = n + 1
    return text
  end
end

-- (number, flag) -> text, one cache per flag bucket
local function memo2(fn)
  local yesCache, noCache, yesN, noN = {}, {}, 0, 0
  return function(v, flag)
    if v ~= v then return fn(v, flag) end
    local cache, n
    if flag then cache, n = yesCache, yesN else cache, n = noCache, noN end
    local hit = cache[v]
    if hit then return hit end
    local text = fn(v, flag)
    if n >= TEXT_MEMO_MAX then
      for k in pairs(cache) do cache[k] = nil end
      n = 0
    end
    cache[v] = text
    n = n + 1
    if flag then yesN = n else noN = n end
    return text
  end
end

-- A stat's change as text: whole numbers as they are, others to one decimal (1.9 damage per second).
local signed = memo1(function(v)
  local text = (v == math.floor(v)) and string.format("%d", v) or string.format("%.1f", v)
  return (v > 0 and "+" or "") .. text
end)

---------------------------------------------------------------------------------------------
-- What a stat gives
---------------------------------------------------------------------------------------------

-- What the game itself says, worked out as Forever's own character sheet does it
-- (Blizzard_UIPanels_Game/Camelot/PaperDollFrameStats.lua): GetCritChanceFromStat and
-- GetSpellCritChanceFromStat give the crit that a number of points of Agility or Intellect bring,
-- GetDodgeChanceFromAttribute the dodge the character's whole Agility brings, GetAttackPowerForStat
-- the attack power and UnitHPPerStamina the health a point of Stamina gives. Forever's client holds
-- the per-class, per-level ratios behind them (PlayerExpectedStat.db2); Classic Era and Retail have
-- no FromStat functions, and there those lines are left out. Armor is 2 per Agility and mana
-- regeneration a quarter of Spirit, as five probes on Forever showed; mana is MANA_PER_INTELLECT
-- (15). In combat the answers can be secret: then the line is left out.

local function num(v) return type(v) == "number" and not isSecret(v) and v or nil end

-- The character's live numbers behind the tank caps and the worth lines' shield check
-- (defense skill, level, dodge, parry, block chance): they move only with gear, buffs, form
-- or level, yet every hover read them all again. They are kept for a short TTL and dropped
-- on the events that can change them (the loader below listens), so a hover storm reads each
-- of them at most once per change. An answer that is secret or missing is never kept (it may
-- become visible later): it is asked again the next time.
local TANK_TTL = 1.0
local tankMemo = {}
local function tankForget()
  for k in pairs(tankMemo) do tankMemo[k] = nil end
end

local function tankRead(key, compute)
  local t = ask(GetTime)
  local hit = tankMemo[key]
  if hit and type(t) == "number" and t >= hit.t and (t - hit.t) <= TANK_TTL then return hit.v end
  local v = compute()
  if type(v) == "number" and not isSecret(v) and v == v and v ~= math.huge and v ~= -math.huge then
    if type(t) == "number" then tankMemo[key] = { t = t, v = v } end
  else
    tankMemo[key] = nil
  end
  return v
end

-- The compute bodies below are named functions shared by every caller: a closure literal
-- in a call position is allocated on every call, and these run a dozen times per hover.
local function readLevel() return num(ask(UnitLevel, "player")) end

-- The character's level, as tankMissChance and the uncrittable target read it.
local function tankLevel()
  return tankRead("lvl", readLevel)
end

local function computeMana()
  local max = num(ask(UnitPowerMax, "player", 0))
  return max ~= nil and max > 0
end

local function usesMana()
  return charFact("mana", computeMana)
end

-- Mana a second, out of casting, per point of Spirit, to the thousandth the game gives it in
-- (7.751 and 0.001 for 31 Spirit: 0.25, not the 0.2499... the subtraction leaves).
local function computeRegen()
  local _, spirit = ask(UnitStat, "player", 5)
  spirit = num(spirit)
  local base, casting = ask(GetManaRegen)
  base, casting = num(base), num(casting) or 0
  if not (spirit and base and spirit > 0) then return nil end
  return math.floor((base - casting) / spirit * 1000 + 0.5) / 1000
end

local function regenPerSpirit()
  return charFact("regen", computeRegen)
end

-- Health a second, out of combat, per point of Spirit: what the character sheet's Spirit tooltip adds up
-- (GetHealthRegenFromSpirit, times the 0.75 it takes for a character standing; Blizzard_UIPanels_Game/Camelot/
-- PaperDollFrameStats.lua), over the Spirit it comes from. It takes the regeneration to be proportional to
-- Spirit, as mana's is on Forever (a quarter of it, whatever the class); health's was not measured. A field of the
-- module table, not a local: this file is at Lua's limit of local variables.
function M.ComputeHealthRegen()
  local _, spirit = ask(UnitStat, "player", 5)
  spirit = num(spirit)
  local fromSpirit = num(ask(GetHealthRegenFromSpirit))
  if not (spirit and fromSpirit and spirit > 0) then return nil end
  return fromSpirit * 0.75 / spirit
end

local function attackPower(stat, n)
  local v = num(ask(GetAttackPowerForStat, stat, math.abs(n)))
  if not v or v == 0 then return nil end
  return n < 0 and -v or v
end

-- A "...FromStat" answer (a fraction) for n points, as a percentage with n's sign.
local function chanceFromStat(fn, stat, n)
  local v = num(ask(fn, stat, math.abs(n)))
  if not v then return nil end
  v = v * 100
  return n < 0 and -v or v
end

-- Dodge a point of Agility gives: the dodge the character's Agility brings, over that Agility.
local function computeDodgePerAgi()
  local total = num(ask(GetDodgeChanceFromAttribute))
  local _, agi = ask(UnitStat, "player", 2)
  agi = num(agi)
  if not (total and agi and agi > 0) then return nil end
  return total * 100 / agi
end

local function dodgePerAgility()
  return charFact("dodgePerAgi", computeDodgePerAgi)
end

local function constant(name, fallback)
  local v = _G[name]
  return type(v) == "number" and v or fallback
end

local percent = memo1(function(v) return string.format("%+.2f%%", v) end)
local function worthShowing(v) return v and math.abs(v) >= 0.005 end

-- An item's rating and what it is: its kind, and the game's rating index (a global of the character sheet,
-- with its number on Forever as a fallback). Forever's items give crit and hit as points of rating, one
-- rating for melee, ranged and spells alike; the percentage it makes depends on the level.
local RATINGS = {
  ITEM_MOD_CRIT_RATING_SHORT = { "crit", "CR_CRIT_MELEE", 9 }, ITEM_MOD_CRIT_MELEE_RATING_SHORT = { "crit", "CR_CRIT_MELEE", 9 },
  ITEM_MOD_CRIT_RANGED_RATING_SHORT = { "crit", "CR_CRIT_RANGED", 10 },
  ITEM_MOD_CRIT_SPELL_RATING_SHORT = { "spellcrit", "CR_CRIT_SPELL", 11 },
  ITEM_MOD_HIT_RATING_SHORT = { "hit", "CR_HIT_MELEE", 6 }, ITEM_MOD_HIT_MELEE_RATING_SHORT = { "hit", "CR_HIT_MELEE", 6 },
  ITEM_MOD_HIT_RANGED_RATING_SHORT = { "hit", "CR_HIT_RANGED", 7 }, ITEM_MOD_HIT_SPELL_RATING_SHORT = { "hit", "CR_HIT_SPELL", 8 },
  ITEM_MOD_HASTE_RATING_SHORT = { "haste", "CR_HASTE_MELEE", 18 },
  ITEM_MOD_EXPERTISE_RATING_SHORT = { "expertise", "CR_EXPERTISE", 24 },
  ITEM_MOD_DODGE_RATING_SHORT = { "dodge", "CR_DODGE", 3 }, ITEM_MOD_PARRY_RATING_SHORT = { "parry", "CR_PARRY", 4 },
  ITEM_MOD_BLOCK_RATING_SHORT = { "block", "CR_BLOCK", 5 },
  ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = { "defense", "CR_DEFENSE_SKILL", 2 },
}

---------------------------------------------------------------------------------------------
-- The tooltip's enchant line (ENCHANT): C_Item.GetItemStats may leave an item's enchant out, so
-- the enchant's stats are read from the client's own words (the localized ITEM_ENCHANTMENT
-- header, or the enchant line type when the client has one) -- nothing guessed. The client's own
-- GetItemStats answer for the whole link is the baseline: a key the enchant names is reconciled
-- against the answer for the link without its enchant field (base + enchant), every other key
-- keeps the baseline, and without the clean answer nothing is invented or doubled. Only a line
-- the client marks as an enchant counts: the localized ITEM_ENCHANTMENT header (which may be a
-- format with a %s in it), or the enchant tooltip line type (Enum.TooltipDataLineType.
-- ItemEnchantmentPermanent) when the client has one; the ordinary stat, equip and proc lines are
-- never read. Only the stats this module knows are taken, and an enchant the words do not give
-- cleanly (a proc phrase, a percent, a duration, a name with no number, any prose around the
-- stat) adds nothing: a missing enchant beats a wrong stat. A phrase naming a bundle of stats
-- at once ("+4 All Stats", "Alle Werte +4") is taken as the keys it is made of (ENCHANT_BUNDLES
-- below). A tooltip that was not there (no
-- data, no lines, or only the bare title) is never cached as "no enchant", and neither is a
-- tooltip with a secret line: the scan is re-run when the lines may have arrived.
---------------------------------------------------------------------------------------------

-- The link without its enchant field (the second number after "item:", everything else
-- kept: the base for GetItemStats; a link without the field is returned as it is),
-- memoized per link (the same handful of links is rewritten on every hover), bounded like
-- the other memos: a plain gsub allocated a fresh string per link per hover.
local plainMemo, plainCount = {}, 0
withoutEnchant = function(link)
  if type(link) ~= "string" then return link end
  local hit = plainMemo[link]
  if hit then return hit end
  local plain = (link:gsub("item:(%d+):(%d+)", "item:%1:", 1))
  if plainCount >= TEXT_MEMO_MAX then
    for k in pairs(plainMemo) do plainMemo[k] = nil end
    plainCount = 0
  end
  plainMemo[link] = plain
  plainCount = plainCount + 1
  return plain
end

-- The keys an enchant can give, by their client names; the longer name first, so "Attack Power"
-- is matched whole and "Power" never inside it. A key the client has no name for cannot be read
-- back out of a tooltip line.
local ENCHANT_KEYS = {
  "ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_AGILITY_SHORT", "ITEM_MOD_STAMINA_SHORT",
  "ITEM_MOD_INTELLECT_SHORT", "ITEM_MOD_SPIRIT_SHORT", "RESISTANCE0_NAME",
  "ITEM_MOD_DAMAGE_PER_SECOND_SHORT", "ITEM_MOD_ATTACK_POWER_SHORT",
  "ITEM_MOD_SPELL_HEALING_DONE_SHORT", "ITEM_MOD_SPELL_POWER_SHORT",
  "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT", "ITEM_MOD_SHADOW_DAMAGE_DONE_SHORT",
  "ITEM_MOD_PHYSICAL_DAMAGE_DONE_SHORT", "ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT",
  "ITEM_MOD_DEFENSE_SKILL_SHORT", "ITEM_MOD_BLOCK_VALUE_SHORT",
  "ITEM_MOD_HEALTH_SHORT", "ITEM_MOD_MANA_SHORT",
  "ITEM_MOD_MANA_REGENERATION_SHORT", "ITEM_MOD_POWER_REGEN0_SHORT",
  "ITEM_MOD_FERAL_ATTACK_POWER_SHORT",
  "RESISTANCE1_NAME", "RESISTANCE2_NAME", "RESISTANCE3_NAME",
  "RESISTANCE4_NAME", "RESISTANCE5_NAME", "RESISTANCE6_NAME",
  "ITEM_MOD_HOLY_RESISTANCE_SHORT", "ITEM_MOD_FIRE_RESISTANCE_SHORT",
  "ITEM_MOD_NATURE_RESISTANCE_SHORT", "ITEM_MOD_FROST_RESISTANCE_SHORT",
  "ITEM_MOD_SHADOW_RESISTANCE_SHORT", "ITEM_MOD_ARCANE_RESISTANCE_SHORT",
}
for key in pairs(RATINGS) do ENCHANT_KEYS[#ENCHANT_KEYS + 1] = key end

-- A bundle of stats an enchant names as one phrase ("+4 All Stats", "Alle Werte +4"): no key
-- and no client name of its own names the bundle (no GlobalString holds it), so the enchant's
-- own words are read in the locales it is written in and expanded into the keys it is made
-- of; a phrase behind one connector ("+4 to All Stats", "+4 auf alle Werte") is the same
-- component. The marker keys never reach the stats: parseEnchantText expands them and a
-- leaked one names no stat. Anything else stays prose and adds nothing.
local ENCHANT_BUNDLES = {
  { marker = "\1all", -- the five primary stats
    keys = { "ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_AGILITY_SHORT", "ITEM_MOD_STAMINA_SHORT",
      "ITEM_MOD_INTELLECT_SHORT", "ITEM_MOD_SPIRIT_SHORT" },
    phrases = { "All Stats", "Alle Werte", "Wszystkie statystyki", "Все характеристики",
      "Toutes les caractéristiques", "Todas las estadísticas", "Tutte le statistiche" } },
  { marker = "\1res", -- every school of resistance, but never Armor
    keys = { "RESISTANCE1_NAME", "RESISTANCE2_NAME", "RESISTANCE3_NAME",
      "RESISTANCE4_NAME", "RESISTANCE5_NAME", "RESISTANCE6_NAME" },
    phrases = { "All Resistances", "Alle Widerstandsarten", "Wszystkie odporności",
      "Все сопротивления", "Toutes les résistances", "Todas las resistencias",
      "Tutte le resistenze" } },
}
-- The words a phrase may stand behind ("to All Stats", "auf alle Werte"), and the phrase
-- itself: one connector between the number and the phrase, in the languages above.
local BUNDLE_BRIDGES = { "", "to ", "to the ", "auf ", "zu ", "um ", "de ", "para ", "per " }
local bundleKeys = {}
for _, b in ipairs(ENCHANT_BUNDLES) do
  bundleKeys[b.marker] = b.keys
  b.names = {}
  for _, phrase in ipairs(b.phrases) do
    for _, form in ipairs({ phrase, (phrase:gsub("^%a", string.lower)), (phrase:lower()) }) do
      for _, bridge in ipairs(BUNDLE_BRIDGES) do
        b.names[#b.names + 1] = bridge .. form
      end
    end
  end
end

-- The names an enchant can be written with, longest first. They are the client's own global
-- strings (fixed per locale) with the bundles' static phrases on top: the ~400-entry list is
-- built and sorted once and then reused -- it was rebuilt and re-sorted on every parse, which
-- on an uncacheable tooltip meant every hover. The snapshot is thrown away and rebuilt only
-- when one of the global strings behind it actually changes (the test suites rebind them to
-- model another locale).
local enchantNamesCache, enchantNamesSig = nil, nil

local function enchantNames()
  if enchantNamesCache then
    local same = true
    for i = 1, #ENCHANT_KEYS do
      local key = ENCHANT_KEYS[i]
      if enchantNamesSig[key] ~= _G[key] then
        same = false
        break
      end
    end
    if same then return enchantNamesCache end
  end
  local byName = {}
  for _, key in ipairs(ENCHANT_KEYS) do
    local name = statName(key)
    if name and not byName[name] then byName[name] = { name = name, key = key } end
  end
  for _, b in ipairs(ENCHANT_BUNDLES) do
    for _, name in ipairs(b.names) do
      if not byName[name] then byName[name] = { name = name, key = b.marker } end
    end
  end
  local names = {}
  for _, n in pairs(byName) do names[#names + 1] = n end
  table.sort(names, function(a, b) return #a.name > #b.name end)
  enchantNamesCache = names
  enchantNamesSig = {}
  for i = 1, #ENCHANT_KEYS do
    local key = ENCHANT_KEYS[i]
    enchantNamesSig[key] = _G[key]
  end
  return names
end

-- The line type the client marks an enchant line with, when it exposes one: the client's own
-- enum name for it (the generated TooltipInfoSharedDocumentation; on Classic: ItemEnchantmentPermanent).
local function enchantLineType()
  local t = Enum and Enum.TooltipDataLineType
  if type(t) ~= "table" then return nil end
  local v = t.ItemEnchantmentPermanent
  return type(v) == "number" and v or nil
end

-- The line type the client marks a tooltip's title (the item's name line) with, when it
-- exposes one: a tooltip whose only line is the title has not built its lines yet.
local function nameLineType()
  local t = Enum and Enum.TooltipDataLineType
  if type(t) ~= "table" then return nil end
  local v = t.ItemName
  return type(v) == "number" and v or nil
end

-- The enchant's words of a tooltip line (after the header), or nil when the line is not marked
-- as an enchant.
local function enchantTextOf(line)
  -- The client wraps a tooltip line in colour codes (|cAARRGGBB ... |r) when it is coloured:
  -- they are taken off first, so the header is found inside them.
  local text = type(line) == "table" and line.leftText or nil
  if type(text) ~= "string" or isSecret(text) then return nil end
  text = (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
  local header = _G.ITEM_ENCHANTMENT
  if type(header) == "string" and header ~= "" then
    -- The header may be a format with a %s in it ("Enchanted: %s"): the words before the %s are
    -- the prefix the line starts with.
    local prefix = header:gsub("%%s", "")
    if prefix ~= "" and text:sub(1, #prefix) == prefix then return text:sub(#prefix + 1) end
  end
  local t = enchantLineType()
  if t and line.type == t then return text end
  return nil
end

-- A signed number straight after a position ("+1 ..."), or the one straight before it
-- ("... +1"), the two ways an enchant names its stats; as text, or nil.
local function numberAt(text, at)
  local t = text:match("^%s*(%+?%-?%d+%.?%d*)", at)
  return t and t ~= "" and t or nil
end

-- The words between two stat components of an enchant: a comma or the word "and"
-- ("und" in German), with the spaces around it; nil when other words stand there.
local function separatorAt(text, at)
  local rest = text:sub(at)
  local sep = rest:match("^%s*,%s*") or rest:match("^%s+and%s+") or rest:match("^%s+und%s+")
  return sep and #sep or nil
end

-- One stat component at position at: a known stat name with a signed number on one side
-- of it ("Stamina +1", "+8 Armor", "Stamina+1"), the name at a word's boundary; the key,
-- the number and the position after the component, or nothing when the words there are
-- not a component (a name without a number, a number with no name beside it, prose).
local function componentAt(text, names, at)
  local start, name, key
  for _, n in ipairs(names) do
    local s = text:find(n.name, at, true)
    if s and (not start or s < start) then start, name, key = s, n.name, n.key end
  end
  if start and not text:sub(at, start - 1):match("%S") then
    local before, afterC = text:sub(start - 1, start - 1), text:sub(start + #name, start + #name)
    if not (before:match("%w") or afterC:match("%w")) then
      local n = numberAt(text, start + #name)
      if n then
        local _, numEnd = text:find("^%s*(%+?%-?%d+%.?%d*)", start + #name)
        return key, tonumber(n), numEnd + 1
      end
    end
  end
  local n = numberAt(text, at)
  if n then
    local _, numEnd = text:find("^%s*(%+?%-?%d+%.?%d*)", at)
    local s2, name2, key2
    for _, n2 in ipairs(names) do
      local s = text:find(n2.name, numEnd + 1, true)
      if s and (not s2 or s < s2) then s2, name2, key2 = s, n2.name, n2.key end
    end
    if s2 and not text:sub(numEnd + 1, s2 - 1):match("%S") then
      local before = text:sub(s2 - 1, s2 - 1)
      local afterC = text:sub(s2 + #name2, s2 + #name2)
      if not (before:match("%w") or afterC:match("%w")) then
        return key2, tonumber(n), s2 + #name2
      end
    end
  end
  return nil
end

-- The stats of an enchant's words: only clean stat components count -- a name with its
-- number on one side ("Stamina +1", "+8 Armor", "Stamina+1"), a component joined to the
-- next by a comma or "and"/"und". Any other word (a proc phrase like "Chance on hit: ..."
-- or "Use: ...", a percent, a duration, a name without a number) makes the whole line
-- prose, and the enchant adds nothing: only the stats this module knows are taken, and a
-- missing enchant beats a wrong stat.
local function parseEnchantText(text)
  local out = take("parseOut") -- merged into tooltipEnchant's own table at once
  local names = enchantNames()
  local pos, len = 1, #text
  local first = true
  while pos <= len do
    if text:sub(pos):match("^%s*$") then break end -- trailing whitespace ends the words
    if not first then
      local sep = separatorAt(text, pos)
      if not sep then return {} end
      pos = pos + sep
    end
    local key, n, nextPos = componentAt(text, names, pos)
    if not key then return {} end
    local bundle = bundleKeys[key]
    if bundle then
      for _, real in ipairs(bundle) do out[real] = (out[real] or 0) + n end
    else
      out[key] = (out[key] or 0) + n
    end
    pos = nextPos
    first = false
  end
  return out
end

-- The enchant stats read for link, cached once the tooltip data was there: an enchant is fixed in
-- the link, so a read tooltip's answer stands. A tooltip that has not built its lines (the item's
-- data has not arrived: no data, no lines at all, or only the bare title) is scanned again when it
-- may have arrived -- never kept as "no enchant". Neither is a tooltip holding a secret line (a
-- value the client hides may be the enchant line): the scan is re-run then too. The memo holds at
-- most ENCHANT_MEMO_MAX links (a session hovering the whole bank would otherwise grow it without
-- limit): when it is full the next new link wipes it and the reads start over.
local ENCHANT_MEMO_MAX = 256
local enchantMemo, enchantMemoCount = {}, 0
tooltipEnchant = function(link)
  -- A nil or secret link must never index the memo: the client raises on secret keys.
  if type(link) ~= "string" or isSecret(link) then return {} end
  local known = enchantMemo[link]
  if known ~= nil then return known end
  local out = {}
  local data = ask(C_TooltipInfo and C_TooltipInfo.GetHyperlink, link)
  -- The read tooltip's answer is kept only when it is complete and nothing is hidden: at
  -- least one line beyond the bare title (the item's name line, the only line of a tooltip
  -- whose data has not arrived), and no secret line. A title-only tooltip and a tooltip
  -- with a secret line are scanned again, and an enchant they do not show is not invented.
  if type(data) == "table" and type(data.lines) == "table" and #data.lines > 0 then
    local cacheable, hidden, titleType = false, false, nameLineType()
    for _, line in ipairs(data.lines) do
      if type(line) == "table" and isSecret(line.leftText) then
        hidden = true -- the hidden line may be the enchant: not a final answer
      elseif not (titleType and line.type == titleType) then
        cacheable = true -- a line beyond the title: the tooltip was built
        local text = enchantTextOf(line)
        if text then
          for key, n in pairs(parseEnchantText(text)) do out[key] = (out[key] or 0) + n end
        end
      end
    end
    -- a hidden line anywhere sticks: the scan is re-run when nothing is hidden any more
    if cacheable and not hidden then
      if enchantMemoCount >= ENCHANT_MEMO_MAX then
        for k in pairs(enchantMemo) do enchantMemo[k] = nil end
        enchantMemoCount = 0
      end
      enchantMemo[link] = out
      enchantMemoCount = enchantMemoCount + 1
    end
  end
  return out
end

-- The live chance reads behind the tank lines and the shield check: named (shared), so a
-- hover allocates no closure per read.
local function readBlock() return num(ask(GetBlockChance)) end
local function readDodge() return num(ask(GetDodgeChance)) end
local function readParry() return num(ask(GetParryChance)) end

local function computeShield()
  local class = charClass()
  if not class or isSecret(class) then return false end
  if class ~= "WARRIOR" and class ~= "PALADIN" and class ~= "SHAMAN" then return false end
  local bv = tankRead("block", readBlock)
  return (bv or 0) > 0
end

-- Strength gives block value (0.05 per point, RatingBuster Classic / StatLogic VanillaLogic
-- ADD_BLOCK_VALUE_MOD_STR value 0.05) but only while actually blocking: a shield-capable
-- class (warrior, paladin, shaman) with nonzero block chance. A 2H or empty off-hand
-- blocks nothing, so the line stays out. Class and chance both guarded (ask + pcall);
-- a secret class (in combat) fails silent: no line.
local function usesShield()
  return charFact("shield", computeShield)
end

local function computeForm()
  local form = ask(GetShapeshiftFormID)
  if form == nil or isSecret(form) then return false end
  return form == 1 or form == 5 or form == 8
end

-- Feral Attack Power is attack power 1:1 (RatingBuster Classic / StatLogic VanillaLogic
-- ADD_AP_MOD_FERAL_ATTACK_POWER value 1 for Cat/Bear/Dire Bear) but only in form: outside
-- Cat/Bear it would lie, so nothing is shown. The form is asked the guarded way Range asks
-- it (GetShapeshiftFormID: Cat 1, Bear 5, Dire Bear 8, see Range.lua DRUID_FORM_SPELLS and
-- SpellDamageInfo CAT_FORM); a secret or unknown form fails silent: no line.
local function inFeralForm()
  return charFact("form", computeForm)
end

-- One part of a worth line, appended where it belongs: kind and value flat in one array
-- (a { kind =, value = } table per part was 13 of a hover's 140 allocations).
local function addPart(parts, kind, value)
  local n = #parts
  parts[n + 1] = kind
  parts[n + 2] = value
end

-- What n points of the stat under key give this character: { kind, value, kind, value, ... },
-- flat, in the order shown. The array is build-scoped scratch (see take): every caller
-- reads it out at once (M.Worth joins it, TooltipLines sums it), so a hover allocates none.
function M.WorthParts(key, n)
  local parts = take("worthParts")
  if key == "ITEM_MOD_STRENGTH_SHORT" then
    local ap = attackPower(1, n)
    if ap then addPart(parts, "ap", ap) end
    if usesShield() then addPart(parts, "blockvalue", n * 0.05) end
  elseif key == "ITEM_MOD_AGILITY_SHORT" then
    addPart(parts, "armor", constant("ARMOR_PER_AGILITY", 2) * n)
    local ap = attackPower(2, n)
    if ap then addPart(parts, "ap", ap) end
    local crit = chanceFromStat(GetCritChanceFromStat, 2, n)
    if worthShowing(crit) then addPart(parts, "crit", crit) end
    local dodge = dodgePerAgility()
    if dodge and worthShowing(dodge * n) then addPart(parts, "dodge", dodge * n) end
  elseif key == "ITEM_MOD_STAMINA_SHORT" then
    -- SI-249: in combat the answers can be secret; then the line is left out.
    -- A fallback 10*modifier would invent health (e.g. +20) the game hid.
    local rawPer, rawMod = ask(UnitHPPerStamina, "player"), ask(GetUnitMaxHealthModifier, "player")
    if isSecret(rawPer) or isSecret(rawMod) then return parts end
    local per = num(rawPer)
    if not per then per = 10 * (num(rawMod) or 1) end
    -- SI-250: round half away from zero, so -10.5 is -11, not -10.
    local v = per * n
    addPart(parts, "health", v >= 0 and math.floor(v + 0.5) or math.ceil(v - 0.5))
  elseif key == "ITEM_MOD_INTELLECT_SHORT" then
    if usesMana() then
      addPart(parts, "mana", constant("MANA_PER_INTELLECT", 15) * n)
      local spellCrit = chanceFromStat(GetSpellCritChanceFromStat, 4, n)
      if worthShowing(spellCrit) then addPart(parts, "spellcrit", spellCrit) end
    end
  elseif key == "ITEM_MOD_SPIRIT_SHORT" then
    local per = usesMana() and regenPerSpirit()
    if per and per > 0 then addPart(parts, "regen", math.floor(per * n * 50 + 0.5) / 10) end
    local healthPer = charFact("hpregen", M.ComputeHealthRegen)
    if healthPer and healthPer > 0 then
      local regen = math.floor(healthPer * n * 50 + 0.5) / 10
      if regen ~= 0 then addPart(parts, "hpregen", regen) end -- "+0 health" says nothing
    end
  elseif key == "ITEM_MOD_EXTRA_ARMOR_SHORT" then
    addPart(parts, "armor", n) -- "+50 Bonus Armor": armor all the same (the sim weighs it beside Armor)
  elseif key == "ITEM_MOD_HEALTH_SHORT" then
    -- flat health on the item (an enchant or a gem gives it), not through Stamina
    addPart(parts, "health", n)
  elseif key == "ITEM_MOD_MANA_SHORT" then
    addPart(parts, "mana", n)
  elseif key == "ITEM_MOD_BLOCK_VALUE_SHORT" then
    addPart(parts, "blockvalue", n)
  elseif key == "ITEM_MOD_SPELL_HEALING_DONE_SHORT" then
    addPart(parts, "healing", n)
  elseif key == "ITEM_MOD_SPELL_POWER_SHORT" or key == "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT" then
    addPart(parts, "spellpower", n)
  elseif key == "ITEM_MOD_DEFENSE_SKILL_SHORT" then
    -- Flat +Defense skill: no such key in the client's GlobalStrings (only
    -- ITEM_MOD_DEFENSE_SKILL_RATING_SHORT exists) and none seen in GetItemStats data;
    -- kept defensively. Honest raw skill ("+X defense", kind "defense" with its existing
    -- word and ShieldWall icon), not the 0.04% avoidance RatingBuster converts it to.
    addPart(parts, "defense", n)
  elseif key == "ITEM_MOD_FERAL_ATTACK_POWER_SHORT" then
    -- 1:1 attack power, but only in Cat/Bear form (see inFeralForm above).
    if inFeralForm() then addPart(parts, "ap", n) end
  elseif RATINGS[key] then
    -- the game's own conversion at this level, as its character sheet does it
    local kind, name, number = RATINGS[key][1], RATINGS[key][2], RATINGS[key][3]
    local index = type(_G[name]) == "number" and _G[name] or number
    local v = num(ask(GetCombatRatingBonusForCombatRatingValue, index, math.abs(n)))
    if v and v ~= 0 then addPart(parts, kind, n < 0 and -v or v) end
  end
  return parts
end

local WORTH_WORDS = {
  armor = "armor", ap = "attack power", crit = "crit", dodge = "dodge", health = "health", mana = "mana",
  spellcrit = "spell crit", regen = "mana per 5 sec. when not casting", hit = "hit", haste = "haste",
  expertise = "expertise", parry = "parry", block = "block", blockvalue = "block value", defense = "defense",
  healing = "healing", spellpower = "spell power", hpregen = "health per 5 sec. out of combat",
}
local PERCENT_KINDS = { crit = true, dodge = true, spellcrit = true, hit = true, haste = true, expertise = true,
  parry = true, block = true }
-- The word beside each icon on the icon line, short.
local WORTH_SHORT = {
  armor = "armor", ap = "AP", crit = "crit", dodge = "dodge", health = "health", mana = "mana",
  spellcrit = "spell crit", regen = "mana/5s", hit = "hit", haste = "haste", expertise = "expertise",
  parry = "parry", block = "block", blockvalue = "block value", defense = "defense", healing = "healing",
  spellpower = "spell power", hpregen = "health/5s",
}
local function worthValue(kind, value) return PERCENT_KINDS[kind] and percent(value) or signed(value) end

-- The worth segment in words ("+0.28% crit"), memoized per (kind, value): the same item's
-- hover builds the same handful of segments every time it is hovered.
local worthWordMemo, worthWordCount = {}, 0
local function worthWord(kind, value)
  if value ~= value then return worthValue(kind, value) .. " " .. BIT.L(WORTH_WORDS[kind]) end -- NaN keys raise
  local byValue = worthWordMemo[kind]
  if not byValue then
    byValue = {}
    worthWordMemo[kind] = byValue
  end
  local hit = byValue[value]
  if hit then return hit end
  local text = worthValue(kind, value) .. " " .. BIT.L(WORTH_WORDS[kind])
  if worthWordCount >= TEXT_MEMO_MAX then
    for k in pairs(worthWordMemo) do worthWordMemo[k] = nil end
    worthWordCount = 0
  end
  byValue[value] = text
  worthWordCount = worthWordCount + 1
  return text
end

-- Up green, down red: the colour of a value by its sign. Memoized per (sign, text): the
-- same coloured segment recurs on every hover of the same item.
local UP, DOWN = "|cff4dff4d", "|cffff5959"
local bySignMemo = { [1] = {}, [-1] = {}, [0] = {} }
local bySignCount = { [1] = 0, [-1] = 0, [0] = 0 }
local function bySign(v, text)
  local bucket = v > 0 and 1 or v < 0 and -1 or 0
  local cache = bySignMemo[bucket]
  local hit = cache[text]
  if hit then return hit end
  local out = text
  if bucket == 1 then out = UP .. text .. "|r" elseif bucket == -1 then out = DOWN .. text .. "|r" end
  local n = bySignCount[bucket]
  if n >= TEXT_MEMO_MAX then
    for k in pairs(cache) do cache[k] = nil end
    n = 0
  end
  cache[text] = out
  bySignCount[bucket] = n + 1
  return out
end

-- What n points of the stat under key give this character, as text, or nil; each value coloured by
-- whether it goes up or down when coloured is set.
function M.Worth(key, n, coloured)
  local out = take("worthOut")
  local parts = M.WorthParts(key, n)
  for i = 1, #parts, 2 do
    local kind, value = parts[i], parts[i + 1]
    local text = worthWord(kind, value)
    out[#out + 1] = coloured and bySign(value, text) or text
  end
  return #out > 0 and table.concat(out, ", ") or nil
end

---------------------------------------------------------------------------------------------
-- How each spec of the class rates an item (Weights.lua: ForeverSim's stat weights)
---------------------------------------------------------------------------------------------

-- A percentage always: old and new are both worths to the spec's measure.
-- Past MAX_PERCENT either way it caps: a ring worth 0.15 against
-- nothing is ">300%", not "+29817%". An empty slot (old 0, new something) is
-- the same cap, not infinity; nothing against nothing is 0 and stays hidden.
local MAX_PERCENT = 300
local RANGED_LOCS = { INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true, INVTYPE_THROWN = true }

-- An item's worth to one of a spec's measures, in points of the measure's reference stat; offHand: it is
-- (or would be) in the off hand. A weapon's damage per second has the sim's own weight for where it is:
-- main hand, off hand or ranged slot (0 where the spec does not fight with it: a caster, the paw of Cat
-- and Bear Form, an Arms warrior's off hand).
-- The health a point of Stamina gives this character (the game's own answer; 10 at level 60 when it gives none).
local function computeHpPerStamina()
  local per = num(ask(UnitHPPerStamina, "player"))
  return per and per > 0 and per or 10
end

-- The worth of a table of stats (key -> amount) to a measure. Flat health has no weight of its own (the sim
-- weighs Stamina): it counts as the Stamina it would take to give it, so a flask of 1200 health is worth to a
-- tank what 120 Stamina is.
local function statsWorth(measure, stats, skip)
  local total = 0
  for key, amount in pairs(stats) do
    local w = measure.weights[key]
    if w and not (skip and skip[key]) then total = total + w * amount end
  end
  local health = stats.ITEM_MOD_HEALTH_SHORT
  if health and health ~= 0 and not measure.weights.ITEM_MOD_HEALTH_SHORT then
    local stamina = measure.weights.ITEM_MOD_STAMINA_SHORT
    if stamina then total = total + stamina * health / charFact("hpPerStamina", computeHpPerStamina) end
  end
  return total
end

local function worthTo(measure, link, offHand, alloc, skip)
  local stats = itemStats(link, alloc)
  local total = statsWorth(measure, stats, skip)
  -- what its effects give on average (a trinket is its use effect; Effects.lua)
  if M.EffectStats then total = total + statsWorth(measure, M.EffectStats(link), skip) end
  local dps = stats.ITEM_MOD_DAMAGE_PER_SECOND_SHORT
  if dps then
    local w
    if RANGED_LOCS[equipLoc(link) or ""] then w = measure.ranged elseif offHand then w = measure.offHand
    else w = measure.mainHand end
    if w and w ~= 0 then total = total + w * dps end
  end
  return total
end

-- For each spec of the player's class, the item against what it is compared with: { { spec, parts } },
-- a part per measure (damage; survival and threat for a tank; healing for a healer): { kind, percent } always.
-- Past MAX_PERCENT either way it caps at ">300%"/"<-300%" (capped = true): a ring worth 0.15
-- against nothing reads ">300%", not "+29817%". An empty slot (old 0, new something) is the same
-- cap, not infinity; nothing against nothing is 0 and stays hidden via changesNothing.
-- slots: the slot of each item in against; offHand: the item would go into the off hand.
-- The measures a spec is rated on; constant lists (they used to be built per spec on every
-- hover): a tank's two, a healer's one, a damage spec's one.
local TANK_MEASURES = { "survival", "threat" }
local HEAL_MEASURES = { "healing" }
local DAMAGE_MEASURES = { "damage" }

local EMPTY = {} -- a read-only stand-in for "nothing to compare with"; never written to

-- Which specs are rated at all (the settings' "Specs to rate"): every spec of the class, the talent
-- tree the character is in ("auto"), or the roles ticked ("manual"). One place, so the tooltip's
-- lines, its one-line summary, the bag and quest arrows and the beneficiary icon all agree.
-- The talent trees of each class in the client's order (TalentTab.OrderIndex): { tab id, the
-- names of M.SPECS that belong to it }. The id is what C_SpecializationInfo.GetSpecializationInfo
-- answers in Forever (the TalentTab row), the position is the fallback when a client answers
-- another id. Feral has two rated specs (Bear, Cat) in one tree, a warlock's Destruction two builds.
local TREES = {
  DRUID = { { 283, "Balance" }, { 281, "Feral (Bear)", "Feral (Cat)" }, { 282, "Restoration" } },
  HUNTER = { { 361, "Beast Mastery" }, { 363, "Marksmanship" }, { 362, "Survival" } },
  MAGE = { { 81, "Arcane" }, { 41, "Fire" }, { 61, "Frost" } },
  PALADIN = { { 382, "Holy" }, { 383, "Protection" }, { 381, "Retribution" } },
  PRIEST = { { 201, "Discipline" }, { 202, "Holy" }, { 203, "Shadow" } },
  ROGUE = { { 182, "Assassination" }, { 181, "Combat" }, { 183, "Subtlety" } },
  SHAMAN = { { 261, "Elemental" }, { 263, "Enhancement" }, { 262, "Restoration" } },
  WARLOCK = { { 302, "Affliction" }, { 303, "Demonology" }, { 301, "Destruction", "Destruction (DS/Ruin)" } },
  WARRIOR = { { 161, "Arms" }, { 164, "Fury" }, { 163, "Protection" } },
}

-- The tree the character has its points in (the one the game calls the primary), or nil when the
-- client does not say (no points yet, a secret, an API this client lacks): then nothing is hidden.
-- The helpers live in one block with computeTree: this file is at Lua's limit of 200 local variables.
local computeTree
do
-- The tree of the client's tab number: by the tab's id when the client answers one, else by position.
local function treeAt(trees, getInfo, index)
  local id = ask(getInfo, index)
  if type(id) == "number" and not isSecret(id) then
    for _, tree in ipairs(trees) do
      if tree[1] == id then return tree end
    end
  end
  return trees[index]
end

-- The points spent in each of the three trees: { n1, n2, n3 }, or nil when the client does not say (every
-- answer is the 7th value of GetSpecializationInfo, after id, name, description, icon, role, primary stat).
local function treePoints(getInfo)
  local points, any = {}, false
  for i = 1, 3 do
    local _, _, _, _, _, _, spent = ask(getInfo, i)
    if type(spent) == "number" and not isSecret(spent) then
      points[i] = spent
      any = true
    else
      points[i] = 0
    end
  end
  return any and points or nil
end

function computeTree()
  local class = charClass()
  local trees = class and TREES[class]
  if not trees then return nil end
  local info = C_SpecializationInfo
  local getSpec = type(info) == "table" and info.GetSpecialization or GetSpecialization or GetPrimaryTalentTree
  local getInfo = type(info) == "table" and info.GetSpecializationInfo or GetSpecializationInfo
  local index = ask(getSpec)
  if type(index) ~= "number" or isSecret(index) or index < 1 then index = nil end
  -- The points decide first: the tree with the most is the character's spec (a hunter with 4 points in
  -- Beast Mastery and 33 in Survival is Survival), whatever "the primary tree" call says. A tie goes to the
  -- one the client names, else to the first; no points at all falls back to the client's answer.
  local points = treePoints(getInfo)
  if points then
    local best = 0
    for i = 1, 3 do
      if points[i] > best then best = points[i] end
    end
    if best > 0 then
      if index and points[index] == best then return treeAt(trees, getInfo, index) end
      for i = 1, 3 do
        if points[i] == best then return treeAt(trees, getInfo, i) end
      end
    end
  end
  if not index then return nil end
  return treeAt(trees, getInfo, index)
end
end

local function inTree(tree, spec)
  for i = 2, #tree do
    if tree[i] == spec.name then return true end
  end
  return false
end

-- The tree "auto" rates: only when one of the class's rated specs is in it, else nil (all specs).
local function autoTree(specs)
  local tree = charFact("tree", computeTree)
  if not tree then return nil end
  for _, spec in ipairs(specs) do
    if inTree(tree, spec) then return tree end
  end
  return nil
end

local function specWanted(spec, mode, tree)
  if mode == "manual" then
    local s = settings or DEFAULTS
    -- a single spec can be turned off by name ("Survival"): three hunter specs are all damage
    local key = spec.pickKey
    if not key then
      key = "spec:" .. tostring(spec.name)
      spec.pickKey = key
    end
    if s[key] == false then return false end
    if spec.role == "tank" then return s.specTank ~= false end
    if spec.role == "healing" then return s.specHealing ~= false end
    return s.specDamage ~= false
  end
  if mode == "auto" and tree then return inTree(tree, spec) end
  return true
end

-- Whether any spec of this role ("tank", "healing", "damage") is rated; the tank caps lines follow it.
local function roleWanted(role)
  local mode = (settings or DEFAULTS).specFilter
  if mode ~= "auto" and mode ~= "manual" then return true end
  local class = charClass()
  local specs = class and M.SPECS and M.SPECS[class]
  if not specs then return true end
  local tree = mode == "auto" and autoTree(specs) or nil
  for _, spec in ipairs(specs) do
    if spec.role == role and specWanted(spec, mode, tree) then return true end
  end
  return false
end

-- The helpers of the set bonuses and the consumables' lines are fields of one table: this file is at Lua's
-- limit of 200 local variables.
local FX = {}

-- The pieces of each counted set that is worn: { [setId] = pieces }, once per build.
function FX.computeSets() return M.SetCounts(equipped) end

-- The sets a swap touches, and their piece counts before and after it: nil when it touches none.
function FX.setSwap(link, against)
  if not M.SetOf then return nil end
  local newSet = M.SetOf(link)
  local touched
  for _, worn in ipairs(against) do
    local s = M.SetOf(worn)
    if s then touched = touched or {}; touched[#touched + 1] = s end
  end
  if not newSet and not touched then return nil end
  local counts = charFact("sets", FX.computeSets)
  if not counts then return nil end
  local before, after = {}, {}
  local function touch(s)
    if before[s] == nil then before[s], after[s] = counts[s] or 0, counts[s] or 0 end
  end
  if newSet then touch(newSet); after[newSet] = after[newSet] + 1 end
  for _, s in ipairs(touched or EMPTY) do touch(s); after[s] = after[s] - 1 end
  return before, after
end

-- Hit and expertise are counted by the steps of a measure's `caps` (the game's own caps, see make_weights.py): a
-- point is worth in full below the first step and, from each step on, the share the step names (0 for a hard cap;
-- a dual wielder has two steps, 8% for special attacks and 27% for white hits). The value of an item's hit is its
-- marginal value to the character's total, so a swap that crosses the cap counts only the part below it. Needs the
-- character's current percentages (Effects.lua: the game's own sheet formulas); where the client does not answer,
-- the stat is counted in full, as before.
FX.HIT_KEYS = { ITEM_MOD_HIT_RATING_SHORT = true, ITEM_MOD_HIT_MELEE_RATING_SHORT = true,
  ITEM_MOD_HIT_RANGED_RATING_SHORT = true, ITEM_MOD_HIT_SPELL_RATING_SHORT = true }
FX.EXP_KEYS = { ITEM_MOD_EXPERTISE_RATING_SHORT = true }

function FX.capContextBuild(measure)
  local caps = measure.caps
  if not caps or not M.CapCurrent then return nil end
  local ctx = {}
  local function add(name, keys, current, steps)
    local weight = 0
    for key in pairs(keys) do weight = math.max(weight, measure.weights[key] or 0) end
    local per = M.PercentPerRating(name)
    local now = M.CapCurrent(current)
    if weight > 0 and per and now then
      ctx[#ctx + 1] = { keys = keys, weight = weight, per = per, now = now, steps = steps, name = name }
    end
  end
  if caps.hit then add("hit", FX.HIT_KEYS, caps.hit.kind, caps.hit.steps) end
  if caps.exp then add("expertise", FX.EXP_KEYS, "expertise", caps.exp.steps) end
  if #ctx == 0 then return nil end
  -- the keys the cap terms take over: only those with a cap here (a stat the client did not answer for stays linear)
  ctx.skip = {}
  for _, c in ipairs(ctx) do
    for key in pairs(c.keys) do ctx.skip[key] = true end
  end
  return ctx
end

-- A measure's cap context is kept for a second (the same answers the readings would give, see Effects.lua
-- M.CapCurrent) and dropped when the gear, an aura, the form or the level change: a bag refresh rates a hundred
-- items, and each of them used to read the same hit and expertise for every measure of every spec.
FX.ctxCache = {}
function FX.computeNow() return ask(GetTime) end
-- the readings' expiry and the contexts built from them go together
for _, name in ipairs({ "CapExpire", "CapForget" }) do
  local base = M[name]
  if base then
    M[name] = function(...)
      FX.ctxCache = {}
      return base(...)
    end
  end
end

function FX.capContext(measure)
  if not measure.caps or (M.settings and M.settings.caps == false) then return nil end
  -- once per build (the measure table is the key: no closure and no string per rating)
  if memoDepth > 0 then
    local hit = charMemo[measure]
    if hit ~= nil then
      if hit == NO_VALUE then return nil end
      return hit
    end
  end
  local t = charFact("now", FX.computeNow)
  local entry = FX.ctxCache[measure]
  local ctx
  if entry and type(t) == "number" and t >= entry.t and (t - entry.t) <= 1 then
    ctx = entry.ctx or nil
  else
    ctx = FX.capContextBuild(measure)
    if type(t) == "number" then FX.ctxCache[measure] = { t = t, ctx = ctx or false } end
  end
  if memoDepth > 0 then
    if ctx == nil then charMemo[measure] = NO_VALUE else charMemo[measure] = ctx end
  end
  return ctx
end

-- The rating of a capped stat an item gives (its stats and the average of its effects): "hit" is the sum of the
-- four hit keys (an item has one of them), "expertise" the one key. Direct reads: this runs for every item rated.
function FX.capRating(name, link, alloc)
  local stats = itemStats(link, alloc)
  local effects = M.EffectStats and M.EffectStats(link) or EMPTY
  if name == "hit" then
    return (stats.ITEM_MOD_HIT_RATING_SHORT or 0) + (stats.ITEM_MOD_HIT_MELEE_RATING_SHORT or 0)
      + (stats.ITEM_MOD_HIT_RANGED_RATING_SHORT or 0) + (stats.ITEM_MOD_HIT_SPELL_RATING_SHORT or 0)
      + (effects.ITEM_MOD_HIT_RATING_SHORT or 0) + (effects.ITEM_MOD_HIT_MELEE_RATING_SHORT or 0)
      + (effects.ITEM_MOD_HIT_RANGED_RATING_SHORT or 0) + (effects.ITEM_MOD_HIT_SPELL_RATING_SHORT or 0)
  end
  return (stats.ITEM_MOD_EXPERTISE_RATING_SHORT or 0) + (effects.ITEM_MOD_EXPERTISE_RATING_SHORT or 0)
end

-- The percentage of x that counts: in full to the first step, then by each step's share.
function FX.counted(steps, x)
  local total, from, share = 0, 0, 1
  for i = 1, #steps do
    local step = steps[i]
    if x <= step[1] then return total + (x - from) * share end
    total = total + (step[1] - from) * share
    from, share = step[1], step[2]
  end
  return total + (x - from) * share
end

-- What counts of the cap-limited stats, in the measure's own points, for the item and for what it replaces.
function FX.capTerms(ctx, link, against, alloc)
  local newValue, oldValue = 0, 0
  for _, c in ipairs(ctx) do
    local rNew = FX.capRating(c.name, link, alloc)
    local rOld = 0
    for _, worn in ipairs(against) do rOld = rOld + FX.capRating(c.name, worn, alloc) end
    if rNew ~= 0 or rOld ~= 0 then
      local base = c.now - rOld * c.per -- the character without what is worn there
      local counted = FX.counted
      oldValue = oldValue + c.weight * (counted(c.steps, c.now) - counted(c.steps, base)) / c.per
      newValue = newValue + c.weight * (counted(c.steps, base + rNew * c.per) - counted(c.steps, base)) / c.per
    end
  end
  return newValue, oldValue
end

-- What the bonuses of the sets in counts ({ [setId] = pieces }) are worth to a measure.
function FX.setWorth(measure, counts)
  local total = 0
  for set, pieces in pairs(counts) do
    local bonus = M.SetBonusStats(set, pieces)
    if bonus then total = total + statsWorth(measure, bonus) end
  end
  return total
end

local function specRatingsBody(link, against, slots, offHand, alloc)
  if M.CanEquipItem(link) ~= true then return nil end
  local class = charClass()
  -- A secret class (in combat) must not be used as a table key.
  local specs = type(class) == "string" and not isSecret(class) and M.SPECS and M.SPECS[class]
  if not specs then return nil end
  local out = alloc("specRows")
  against = against or EMPTY
  local mode = (settings or DEFAULTS).specFilter
  local tree = mode == "auto" and autoTree(specs) or nil
  local setBefore, setAfter = FX.setSwap(link, against)
  for _, spec in ipairs(specs) do
    if specWanted(spec, mode, tree) then
      local row = alloc("specRow")
      row.spec = spec
      row.parts = alloc("specRowParts")
      local measures
      if spec.role == "tank" then measures = TANK_MEASURES
      elseif spec.role == "healing" then measures = HEAL_MEASURES
      else measures = DAMAGE_MEASURES end
      for _, kind in ipairs(measures) do
        local measure = spec[kind]
        local capCtx = FX.capContext(measure) -- hit and expertise, counted up to their caps
        local skip = capCtx and capCtx.skip or nil
        local new, old = worthTo(measure, link, offHand, alloc, skip), 0
        for i, worn in ipairs(against) do old = old + worthTo(measure, worn, slots and slots[i] == 17, alloc, skip) end
        if capCtx then
          local capNew, capOld = FX.capTerms(capCtx, link, against, alloc)
          new, old = new + capNew, old + capOld
        end
        -- the bonuses of the sets the swap touches, as they stand after it and as they stood before
        if setBefore then
          new = new + FX.setWorth(measure, setAfter)
          old = old + FX.setWorth(measure, setBefore)
        end
        local part = alloc("specPart")
        part.kind, part.reference = kind, measure.reference
        if measure.approximate then part.approx = true end
        if math.abs(old) > 0.05 then
          local p = (new - old) / math.abs(old) * 100
          if p > MAX_PERCENT then part.percent, part.capped = MAX_PERCENT, true
          elseif p < -MAX_PERCENT then part.percent, part.capped = -MAX_PERCENT, true
          else part.percent = p end
        elseif new > 0.05 then
          part.percent, part.capped = MAX_PERCENT, true -- empty slot / worn worth nothing: past the cap
          part.noBaseline = true
        elseif new < -0.05 then
          part.percent, part.capped = -MAX_PERCENT, true
          part.noBaseline = true
        else
          part.percent = 0
        end
        row.parts[#row.parts + 1] = part
      end
      out[#out + 1] = row
    end
  end
  -- Manual with no box that fits this class (a hunter with only "Tank specs" ticked, or none): no
  -- opinion at all. An empty list would let BagMarkers fall back to the raw stat differences and
  -- draw arrows for exactly what the player switched off; nil is its "cannot be rated" (no arrow).
  if #out == 0 then return nil end
  return out
end

function M.SpecRatings(link, against, slots, offHand)
  return specRatingsBody(link, against, slots, offHand, fresh)
end
M.SpecRatings = memoized(M.SpecRatings)

-- The colour a rating line is tinted by: memoized per (threshold bucket, text), like bySign.
local colouredMemo = { [1] = {}, [-1] = {}, [0] = {} }
local colouredCount = { [1] = 0, [-1] = 0, [0] = 0 }
local function coloured(v, text)
  local bucket = v > 0.05 and 1 or v < -0.05 and -1 or 0
  local cache = colouredMemo[bucket]
  local hit = cache[text]
  if hit then return hit end
  local colour = bucket == 1 and "|cff4dff4d" or bucket == -1 and "|cffff5959" or "|cffb3b3b3"
  local out = colour .. text .. "|r"
  local n = colouredCount[bucket]
  if n >= TEXT_MEMO_MAX then
    for k in pairs(cache) do cache[k] = nil end
    n = 0
  end
  cache[text] = out
  colouredCount[bucket] = n + 1
  return out
end

-- What a tank's two numbers are for, and a damage spec's one: terse, so it cannot read
-- as the character's own damage going up ("+52% damage"). "60% better dmg spec".
-- A healer's part is a score of the heuristic model (Weights.lua), not an actual healing gain,
-- and ratingText marks it "(approx.)". One template per line (the number is the %s), so a
-- language can place the words as it needs to.
local function ratingTemplate(kind, better)
  if kind == "damage" then
    return better and BIT.L("%s%% better dmg spec") or BIT.L("%s%% worse dmg spec")
  elseif kind == "survival" then
    return better and BIT.L("%s%% better for survival") or BIT.L("%s%% worse for survival")
  elseif kind == "threat" then
    return better and BIT.L("%s%% better for threat gen.") or BIT.L("%s%% worse for threat gen.")
  elseif kind == "healing" then
    return better and BIT.L("%s%% better healer score") or BIT.L("%s%% worse healer score")
  end
  return better and BIT.L("%s%% better") or BIT.L("%s%% worse")
end

-- A number to one decimal under 10, whole from 10 up, and no ".0" on a whole number: "+8 Agility", as
-- the stat line says it, and 9.96 is "10", not "10.0". Memoized (see memo1/memo2).
local shortNumber = memo2(function(n, sign)
  local fmt = (math.abs(n) < 10) and "%.1f" or "%.0f"
  return (string.format(sign and ("%+" .. fmt:sub(2)) or fmt, n):gsub("%.0$", ""))
end)

-- A rating in words, always a percentage: "25% better dmg spec", "12% worse for survival".
-- Past the cap it reads ">300% ..."/"<-300% ...": a ring worth 0.15 against nothing,
-- an empty slot, or a change past MAX_PERCENT. No points currency ("like +8 Agility").
-- A heuristic part (the healer's) is marked "(approx.)": an approximate item score, not a
-- measured gain. Memoized per (percent, flags, kind): the same item's hover rates the same
-- numbers for the same specs every time.
local ratingMemo, ratingCount = {}, 0
local function ratingTextBuild(part)
  local v = part.percent or 0
  local number = part.capped and ((v > 0 and ">" or "<-") .. MAX_PERCENT) or shortNumber(math.abs(v))
  local text = string.format(ratingTemplate(part.kind, v > 0), number)
  if part.approx then text = string.format(BIT.L("%s (approx.)"), text) end
  return coloured(v, text)
end

local function ratingText(part)
  local v = part.percent or 0
  local kind = part.kind
  if v ~= v or kind == nil then return ratingTextBuild(part) end -- never a table key
  local byV = ratingMemo[v]
  if not byV then
    byV = {}
    ratingMemo[v] = byV
  end
  local flags = (part.capped and 1 or 0) + (part.approx and 2 or 0)
  local byFlags = byV[flags]
  if not byFlags then
    byFlags = {}
    byV[flags] = byFlags
  end
  local hit = byFlags[kind]
  if hit then return hit end
  local text = ratingTextBuild(part)
  if ratingCount >= TEXT_MEMO_MAX then
    for k in pairs(ratingMemo) do ratingMemo[k] = nil end
    ratingCount = 0
  end
  byFlags[kind] = text
  ratingCount = ratingCount + 1
  return text
end

local ICONS = {
  armor = "Interface\\Icons\\INV_Chest_Chain_05", ap = "Interface\\Icons\\Ability_Warrior_BattleShout",
  crit = "Interface\\Icons\\Ability_CriticalStrike", dodge = "Interface\\Icons\\Ability_Rogue_Feint",
  health = "Interface\\Icons\\Spell_Holy_SealOfSacrifice", mana = "Interface\\Icons\\INV_Potion_76",
  spellcrit = "Interface\\Icons\\Spell_Fire_FlameBolt", regen = "Interface\\Icons\\INV_Drink_07",
  hit = "Interface\\Icons\\Ability_Hunter_SniperShot", haste = "Interface\\Icons\\Spell_Nature_Bloodlust",
  expertise = "Interface\\Icons\\Ability_Warrior_Revenge", parry = "Interface\\Icons\\Ability_Parry",
  block = "Interface\\Icons\\Ability_Defend", blockvalue = "Interface\\Icons\\INV_Shield_05",
  defense = "Interface\\Icons\\Ability_Warrior_ShieldWall",
  healing = "Interface\\Icons\\Spell_Holy_Heal", spellpower = "Interface\\Icons\\Spell_Nature_Lightning",
  hpregen = "Interface\\Icons\\INV_Misc_Bandage_15",
}
M.ICONS = ICONS
local DIVIDER = "|TInterface\\Common\\UI-TooltipDivider-Transparent:8:200|t"

-- An icon in a line of text, its baked-in border trimmed.
-- An icon in a line of text, its baked-in border trimmed. Memoized per (path, size): the
-- same ~20 icons at two sizes make up every icon on every hover, and each call formatted a
-- fresh string. The paths are the constant tables above and the specs' own, so the cache is
-- bounded by them and by the two sizes.
local iconMemo = {}
local function icon(path, size)
  size = size or 14
  local bySize = iconMemo[path]
  if not bySize then
    bySize = {}
    iconMemo[path] = bySize
  end
  local text = bySize[size]
  if not text then
    text = string.format("|T%s:%d:%d:0:0:64:64:5:59:5:59|t", path, size, size)
    bySize[size] = text
  end
  return text
end
M.IconText = icon

-- A rating that changes nothing: what ratingText shows as 0%.
local function changesNothing(part) return math.abs(part.percent or 0) < 0.05 end

-- Shared by the compact summary and the bag/reward badges: a tank's two measures
-- pointing in opposite directions are a tradeoff, never an unequivocal upgrade.
function M.RatingVerdict(parts)
  local up, down, approx = false, false, false
  for _, part in ipairs(parts) do
    local value = part.percent or 0
    if part.approx then approx = true end
    if value >= 0.05 then up = true elseif value <= -0.05 then down = true end
  end
  if up and not down then return "up", approx end
  if down and not up then return "down", approx end
  return "none", approx
end

-- The ratings with something to say: a spec the item changes nothing for is left out, and so is a
-- tank's number that stays the same. { { spec, parts } }, possibly empty.
local function worthSaying(ratings)
  local out = take("sayingRows")
  for _, r in ipairs(ratings) do
    local parts = take("sayingParts")
    for _, part in ipairs(r.parts) do
      if not changesNothing(part) then parts[#parts + 1] = part end
    end
    if #parts > 0 then
      local row = take("sayingRow")
      row.spec, row.parts = r.spec, parts
      out[#out + 1] = row
    end
  end
  return out
end

local function clear(t)
  for i = #t, 1, -1 do t[i] = nil end
end

-- The divider and the specs' ratings, if any of them changes. A spec that changes nothing has no line,
-- and the healers are among the specs (each healer spec is rated, its line marked "(approx.)").
-- The working buffers are hoisted out of the per-spec loops and cleared, not rebuilt (one
-- measures/words/row array per call instead of one per spec per hover).
local function specLines(lines, ratings, alloc)
  ratings = worthSaying(ratings)
  if #ratings == 0 then return end
  local divider = alloc("line")
  divider[1], divider[2], divider[3], divider[4] = DIVIDER, 1, 1, 1
  lines[#lines + 1] = divider -- the specs' ratings apart from the stats
  if settings and settings.icons then
    local parts = take("specTextParts")
    local measures = take("specMeasures")
    for _, r in ipairs(ratings) do
      -- one icon per spec (two icons side by side were drawn over each other in game)
      clear(measures)
      for _, part in ipairs(r.parts) do
        measures[#measures + 1] = ratingText(part)
      end
      local piece = take("specTextPart")
      piece.text = icon(r.spec.icon) .. " " .. BIT.L(r.spec.name) .. ": " .. table.concat(measures, ", ")
      piece.long = #r.parts > 1
      parts[#parts + 1] = piece
    end
    -- a long rating on a line of its own (a tank's two numbers, "better (like +8 Agility)"), the other
    -- specs two to a line
    local row = take("specRowBuf")
    for _, part in ipairs(parts) do
      if part.long then
        -- a short one waiting for its pair goes first, so the specs keep the class's order
        if #row > 0 then
          local l = alloc("line")
          l[1], l[2], l[3], l[4] = row[1], 1, 1, 1
          lines[#lines + 1] = l
          clear(row)
        end
        local l = alloc("line")
        l[1], l[2], l[3], l[4] = part.text, 1, 1, 1
        lines[#lines + 1] = l
      else
        row[#row + 1] = part.text
        if #row == 2 then
          local l = alloc("line")
          l[1], l[2], l[3], l[4] = table.concat(row, "     "), 1, 1, 1
          lines[#lines + 1] = l
          clear(row)
        end
      end
    end
    if #row > 0 then
      local l = alloc("line")
      l[1], l[2], l[3], l[4] = row[1], 1, 1, 1
      lines[#lines + 1] = l
    end
  else
    local words = take("specWords")
    for _, r in ipairs(ratings) do
      clear(words)
      for _, part in ipairs(r.parts) do words[#words + 1] = ratingText(part) end
      local l = alloc("line")
      l[1], l[2], l[3], l[4] = "  " .. BIT.L(r.spec.name) .. ": " .. table.concat(words, ", "), 0.8, 0.8, 0.8
      lines[#lines + 1] = l
    end
  end
end

-- The item's name out of its link; memoized (the same links are named on every hover of
-- the same item), bounded like the other memos.
local itemNameMemo, itemNameCount = {}, 0
local function itemName(link)
  if type(link) ~= "string" or isSecret(link) then return "?" end
  local hit = itemNameMemo[link]
  if hit then return hit end
  local name = (link:match("%[(.-)%]")) or "?"
  if itemNameCount >= TEXT_MEMO_MAX then
    for k in pairs(itemNameMemo) do itemNameMemo[k] = nil end
    itemNameCount = 0
  end
  itemNameMemo[link] = name
  itemNameCount = itemNameCount + 1
  return name
end

-- The slot words a comparison block names ("Finger slot 1"): a ring or a trinket compares
-- with each worn slot and gets one block per slot, and without the slot's name the two
-- blocks read as one repeated ("Against Woven Belt", "Against Woven Belt") and look like a
-- bug in the tooltip. Only these two locations have two blocks to tell apart.
local SLOT_WORDS = {
  [11] = "Finger slot 1", [12] = "Finger slot 2",
  [13] = "Trinket slot 1", [14] = "Trinket slot 2",
}

-- The block's slot as it follows the item's name ("Against Woven Belt (Finger slot 1)"),
-- or "" where the words would say nothing (a chest has one slot; a two-hander's block
-- already joins the two hands with " + "). An empty block names its slot when the tooltip
-- is nothing but empty slots -- two bare "an empty slot" blocks read as one repeated again
-- -- but not beside a named one, where "Against an empty slot" is clear as it stands.
local function slotLabel(c, allEmpty)
  local slots = c.againstSlots
  if type(slots) ~= "table" or #slots ~= 1 then return "" end
  local word = SLOT_WORDS[slots[1]]
  if not word then return "" end
  if #c.against == 0 and not allEmpty then return "" end
  return " (" .. BIT.L(word) .. ")"
end

-- Whether the game's inspect window is open on someone else's character: the tooltip being
-- built then carries THEIR item, and every comparison in it is against OUR gear. The
-- inspect UI is not one shape on every client (Forever's Blizzard_InspectUI raises
-- InspectFrame, older builds name the doll InspectPaperDollFrame, newer APIs hang the frame
-- off C_InspectUI), so each shape is asked for its own IsShown; anything absent, or not a
-- frame that answers, reads false and nothing is assumed to exist.
local function frameShown(frame)
  return type(frame) == "table" and type(frame.IsShown) == "function" and ask(frame.IsShown, frame) == true
end

local function inspectShown()
  if frameShown(InspectFrame) or frameShown(InspectPaperDollFrame) then return true end
  local cui = C_InspectUI
  return type(cui) == "table" and frameShown(cui.InspectFrame)
end

local function inspecting()
  local ok, shown = pcall(inspectShown)
  return ok and shown == true
end

-- A summary can be green for an unequivocal gaining spec, and red only if every
-- evaluated spec loses. Contradictory tank measures and neutral specs block red.
local function bestPart(ratings)
  local best, spec, down, downSpec
  local allDown, changed = true, false
  for _, r in ipairs(ratings) do
    local verdict = M.RatingVerdict(r.parts)
    if verdict ~= "down" then allDown = false end
    for _, part in ipairs(r.parts) do
      if not changesNothing(part) then
        changed = true
        if verdict == "up" and (not best or part.percent > best.percent) then
          best, spec = part, r.spec
        elseif verdict == "down" and (not down or part.percent > down.percent) then
          down, downSpec = part, r.spec
        end
      end
    end
  end
  if not best and allDown then best, spec = down, downSpec end
  return best, spec, changed, allDown
end

-- The same best positive rating shown in the compact tooltip line, across all legal
-- replacement paths. Quest rewards use it to identify the strongest visible upgrade.
function M.BestUpgradePercent(link)
  local best
  for _, comparison in ipairs(M.Compare(link) or EMPTY) do
    local ratings = M.SpecRatings(link, comparison.against, comparison.slots, comparison.offHand)
    local part = ratings and bestPart(ratings)
    if part and part.percent > 0 and (not best or part.percent > best) then
      best = part.percent
    end
  end
  return best
end

-- The small stream arrows BagMarkers paints on a bag button's corner, in a line of text.
-- UI-MicroStream-Green ships pointing down (a download chevron), so the up arrow's |T
-- escape mirrors it vertically (the top and bottom texels swapped) and its tip points up;
-- UI-MicroStream-Red is used as shipped, tip down. The texels are normalized (0..1), so the
-- whole file draws whatever its size is.
local ARROW_UP = "|TInterface\\Buttons\\UI-MicroStream-Green:12:12:0:0:1:1:0:1:1:0|t"
local ARROW_DOWN = "|TInterface\\Buttons\\UI-MicroStream-Red:12:12:0:0:1:1:0:1:0:1|t"

-- The at-a-glance line for a tooltip carrying someone else's item: which way it goes against
-- our own gear, and the best spec's number behind it ("Better than your gear (best spec:
-- 25% better dmg spec)").
local function gearLine(part, spec, comparison)
  local v = part.percent or 0
  local arrow, word = ARROW_UP, BIT.L("Better than your gear")
  if v < 0 then arrow, word = ARROW_DOWN, BIT.L("Worse than your gear") end
  local who = spec and BIT.L(spec.name) or BIT.L("best spec")
  if comparison and part.noBaseline then
    if #comparison.against == 0 then
      local emptyWord = v > 0 and BIT.L("Fills an empty slot") or BIT.L("Lower score in an empty slot")
      if part.approx then who = string.format(BIT.L("%s, approx."), who) end
      return arrow .. " " .. coloured(v, emptyWord) .. " (" .. who .. ")"
    end
    local zero = BIT.L("score changes from zero")
    if part.approx then zero = string.format(BIT.L("%s (approx.)"), zero) end
    return arrow .. " " .. coloured(v, word) .. " (" .. who .. ": " .. coloured(v, zero) .. ")"
  end
  return arrow .. " " .. coloured(v, word) .. " (" .. who .. ": " .. ratingText(part) .. ")"
end

---------------------------------------------------------------------------------------------
-- Tank caps (independent of WorthParts): whether the character is uncrittable (440 defense
-- skill vs a boss +3) and how far its avoidance is from 102.4% (miss+dodge+parry+block).
-- Shown when it matters: the player has a tank spec in M.SPECS, or the item itself carries
-- defensive stats. Every number comes from the client's live APIs behind ask/pcall with an
-- isSecret guard; when no API answers, the line is left out entirely (fail silent, nothing
-- guessed). Worded through BIT.L, colours as the rest (UP green when capped, DOWN red below).
---------------------------------------------------------------------------------------------

local UNCRITTABLE_DEFENSE = 440
local AVOIDANCE_CAP = 102.4

-- Item keys that make the item itself tank-relevant (defense/dodge/parry/block families,
-- including flat defense skill and block value as block family).
local TANK_STATS = {
  ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = true,
  ITEM_MOD_DEFENSE_SKILL_SHORT = true,
  ITEM_MOD_DODGE_RATING_SHORT = true,
  ITEM_MOD_PARRY_RATING_SHORT = true,
  ITEM_MOD_BLOCK_RATING_SHORT = true,
  ITEM_MOD_BLOCK_VALUE_SHORT = true,
}

-- Whether the player's class has a tank spec in M.SPECS (Druid Bear, Paladin Protection,
-- Warrior Protection). Guarded like SpecRatings (ask + pcall); a secret class fails silent.
local function hasTankSpec()
  local class = charClass()
  if type(class) ~= "string" or isSecret(class) then return false end
  local specs = M.SPECS and M.SPECS[class]
  if type(specs) ~= "table" then return false end
  for _, s in ipairs(specs) do
    if type(s) == "table" and s.role == "tank" then return true end
  end
  return false
end

local function itemHasTankStats(link, alloc)
  local stats = itemStats(link, alloc)
  if type(stats) ~= "table" then return false end
  for k, v in pairs(stats) do
    if TANK_STATS[k] and type(v) == "number" and not isSecret(v) and v ~= 0 then return true end
  end
  return false
end

-- The character's current defense skill, or nil when no API answers (fail silent).
-- Forever exposes it as UnitDefenseSkill, Classic Era as UnitDefense (base +
-- modifier); each tried behind ask/pcall with an isSecret guard. GetDefense()
-- does not exist as a callable API and is never invented here.
local UnitDefenseFn = UnitDefenseSkill or UnitDefense
local function readDefenseSkill()
  local a, b = ask(UnitDefenseFn, "player")
  if isSecret(a) or isSecret(b) then return nil end
  if type(a) == "number" and type(b) == "number" then return a + b end
  if type(a) == "number" then return a end
  return nil
end

local function tankDefenseSkill()
  return tankRead("def", readDefenseSkill)
end

-- Miss chance vs a boss +3 from defense skill and level: 5% base plus 0.04% per point of
-- (defense - boss weapon skill), boss skill = (level+3)*5. Needs both defense and a sane
-- UnitLevel("player"); otherwise nil (the caller then shows dodge+parry+block only).
local function tankMissChance(defense)
  if type(defense) ~= "number" or defense ~= defense then return nil end
  local lvl = tankLevel()
  if not lvl or lvl <= 0 then return nil end
  local miss = 5 + (defense - (lvl + 3) * 5) * 0.04
  if miss ~= miss or miss == math.huge or miss == -math.huge then return nil end
  if miss < 0 then miss = 0 end
  return miss
end

local wholeText = memo1(function(v)
  if v == math.floor(v) then return string.format("%d", v) end
  return string.format("%.1f", v)
end)

-- The tank lines for link: {} when nothing can be said honestly. Gate: a tank-spec player
-- sees them on any piece of gear (an item that fits one of the slots in SLOTS: not food, a Hearthstone, a bag, a quiver
-- or ammo, whatever empty-looking equipLoc the client answers for those); anyone else only on a defensive item.
-- Each line needs its own API:
-- Uncrittable needs defense skill; Avoidance needs dodge+parry+block (all three, live
-- GetDodgeChance/GetParryChance/GetBlockChance) plus optionally miss (defense+level).
local function tankExtraLines(link, alloc)
  if type(link) ~= "string" or isSecret(link) then return alloc("tankLines") end
  if not roleWanted("tank") then return alloc("tankLines") end -- "Specs to rate" leaves the tanks out
  if (settings or DEFAULTS).tankCaps == false then return alloc("tankLines") end -- the Tooltip tab's "Tank lines" box
  local loc = equipLoc(link)
  local worn = loc ~= nil and (SLOTS[loc] ~= nil or BOTH_HANDS[loc] == true)
  if not (hasTankSpec() and worn) and not itemHasTankStats(link, alloc) then return alloc("tankLines") end
  local out = alloc("tankLines")
  local def = tankDefenseSkill()
  if type(def) == "number" and def == def and def ~= math.huge and def ~= -math.huge then
    -- Uncrittable target scales with level (boss +3: level*5 + 140, i.e. 440 at 60);
    -- without a sane level the fixed 440 stands in as the level-60 reference.
    local lvl = tankLevel()
    local target = (lvl and lvl > 0) and (lvl * 5 + 140) or UNCRITTABLE_DEFENSE
    local need = target - def
    if need < 0 then need = 0 end
    local text = string.format(BIT.L("Uncrittable: %s/%s (need %s)"),
      wholeText(def), wholeText(target), wholeText(need))
    local l = alloc("line")
    l[1], l[2], l[3], l[4] = ((def >= target) and UP or DOWN) .. text .. "|r", 1, 1, 1
    out[#out + 1] = l
  end
  local dodge = tankRead("dodge", readDodge)
  local parry = tankRead("parry", readParry)
  local block = tankRead("block", readBlock)
  if dodge and parry and block then
    local miss = (def ~= nil) and tankMissChance(def) or nil
    local total, text
    if miss then
      total = miss + dodge + parry + block
      text = string.format(BIT.L("Avoidance: %.2f%% / 102.4%% (miss+dodge+parry+block)"), total)
    else
      total = dodge + parry + block
      text = string.format(BIT.L("Avoidance: %.2f%% / 102.4%% (dodge+parry+block, no miss)"), total)
    end
    local l = alloc("line")
    l[1], l[2], l[3], l[4] = ((total + 1e-9 >= AVOIDANCE_CAP) and UP or DOWN) .. text .. "|r", 1, 1, 1
    out[#out + 1] = l
  end
  return out
end

-- The names of the items a comparison is against, joined as the heading names them
-- ("Worn Band + Old Loop"): one helper, no closure per comparison block.
local function namesJoined(links)
  local t = take("namesJoined")
  for i, l in ipairs(links) do t[i] = itemName(l) end
  return table.concat(t, " + ")
end

-- The tooltip lines for link: { text, r, g, b }. gameCompares: the game shows its own comparison beside
-- this tooltip ("If you replace this item, the following stat changes will occur"), so the differences
-- are not repeated. Each block names the slot it is against ("Against Woven Belt (Finger slot 1)"):
-- a ring or trinket gets one block per slot and the same worn item can stand in both. When the
-- tooltip carries someone else's item (the inspect window open) the heading says the comparison is
-- with YOUR gear and the block ends with the up/down arrow and the best spec's number.
-- alloc: fresh for the public entry (its rows outlive the build), take for the hover path
-- (add() copies every row into the tooltip before the next build may reuse it).
local worthSegMemo, worthSegCount = {}, 0
local function worthSegBuild(kind, value)
  -- the icons line's own short words (WORTH_SHORT: "AP"), not the words-mode ones
  return icon(ICONS[kind], 12) .. " " .. bySign(value, worthValue(kind, value) .. " " .. BIT.L(WORTH_SHORT[kind]))
end

local function worthSeg(kind, value)
  if value ~= value then return worthSegBuild(kind, value) end -- NaN is never a table key
  local byValue = worthSegMemo[kind]
  if not byValue then
    byValue = {}
    worthSegMemo[kind] = byValue
  end
  local hit = byValue[value]
  if hit then return hit end
  local text = worthSegBuild(kind, value)
  if worthSegCount >= TEXT_MEMO_MAX then
    for k in pairs(worthSegMemo) do worthSegMemo[k] = nil end
    worthSegCount = 0
  end
  byValue[value] = text
  worthSegCount = worthSegCount + 1
  return text
end

-- The stat's own line text ("+4 Strength"), memoized per (name, change): the same item's
-- hover writes the same few stat lines every time it is hovered.
local statTextMemo, statTextCount = {}, 0
local function statText(diff, key)
  local name = statName(key) or key
  if diff ~= diff then return signed(diff) .. " " .. name end -- NaN is never a table key
  local byDiff = statTextMemo[name]
  if not byDiff then
    byDiff = {}
    statTextMemo[name] = byDiff
  end
  local hit = byDiff[diff]
  if hit then return hit end
  local text = signed(diff) .. " " .. name
  if statTextCount >= TEXT_MEMO_MAX then
    for k in pairs(statTextMemo) do statTextMemo[k] = nil end
    statTextCount = 0
  end
  byDiff[diff] = text
  statTextCount = statTextCount + 1
  return text
end

local function tooltipWantsFull()
  if (settings or DEFAULTS).detail == "full" then return true end
  if type(IsShiftKeyDown) == "function" and IsShiftKeyDown() then return true end
  return false
end

-- One line: the best spec and its arrow. Worth, the spec wall and the tank block stay in the full body.
local function tooltipLinesCompact(link, alloc)
  local lines = alloc("lines")
  if not (settings and (settings.compare or settings.specs)) then return lines end
  local comps = compareBody(link, alloc) or EMPTY
  local best, bestSpec, bestComparison, down, downSpec, downComparison
  local allDown, changed = true, false
  for _, c in ipairs(comps) do
    local ratings = specRatingsBody(link, c.against, c.slots, c.offHand, alloc)
    if ratings then
      local part, spec, hasChange, downOnly = bestPart(ratings)
      changed, allDown = changed or hasChange, allDown and downOnly
      if part and part.percent > 0 and (not best or part.percent > best.percent) then
        best, bestSpec, bestComparison = part, spec, c
      elseif part and part.percent < 0 and (not down or part.percent > down.percent) then
        down, downSpec, downComparison = part, spec, c
      end
    else
      allDown = false
    end
  end
  if not best and allDown then best, bestSpec, bestComparison = down, downSpec, downComparison end
  if best then
    local line = alloc("line")
    line[1], line[2], line[3], line[4] = gearLine(best, bestSpec, bestComparison), 1, 1, 1
    lines[#lines + 1] = line
  elseif changed then
    local line = alloc("line")
    line[1], line[2], line[3], line[4] = BIT.L("No clear upgrade; hold Shift for details"), 0.7, 0.7, 0.7
    lines[#lines + 1] = line
  end
  return lines
end

-- A percentage to one decimal ("14.8", "17"), as the character sheet shows hit and expertise.
function FX.percentText(v)
  return (string.format("%.1f", v):gsub("%.0$", ""))
end

-- A line for an item that gives a capped stat: the cap and where the character stands, for the first spec rated
-- that has one ("Hit counts up to 17%: you have 14.8%").
function FX.capNote(link, alloc)
  if M.settings and M.settings.caps == false then return nil end
  local class = charClass()
  local specs = type(class) == "string" and not isSecret(class) and M.SPECS and M.SPECS[class]
  if not specs then return nil end
  local mode = (settings or DEFAULTS).specFilter
  local tree = mode == "auto" and autoTree(specs) or nil
  for _, spec in ipairs(specs) do
    if specWanted(spec, mode, tree) then
      for _, kind in ipairs(spec.role == "tank" and TANK_MEASURES or spec.role == "healing" and HEAL_MEASURES
          or DAMAGE_MEASURES) do
        local ctx = FX.capContext(spec[kind])
        for _, c in ipairs(ctx or EMPTY) do
          if FX.capRating(c.name, link, alloc) ~= 0 then
            return string.format(BIT.L(c.name == "hit" and "Hit counts up to %s%%: you have %s%%"
              or "Expertise counts up to %s%%: you have %s%%"), FX.percentText(c.steps[1][1]), FX.percentText(c.now))
          end
        end
      end
    end
  end
  return nil
end

-- What a consumable's buff is worth, as a share of what the character's gear is worth, to each spec rated: an
-- elixir that gives 25 Agility to a character whose gear is worth 2000 Agility is 1.25%. A potion lasts seconds,
-- a flask hours: the line names how long. Nothing is said for a spec the buff's stats are not worth anything to.
function FX.gearWorth(measure)
  local total = 0
  for _, slot in ipairs(M.WORN_SLOTS) do
    local worn = equipped(slot)
    if worn then total = total + worthTo(measure, worn, slot == 17, fresh) end
  end
  local counts = charFact("sets", FX.computeSets)
  if counts then total = total + FX.setWorth(measure, counts) end
  return total
end

function M.ConsumableLines(link, alloc)
  local lines = alloc("lines")
  local c = M.CONSUMABLES and M.CONSUMABLES[M.ItemIDOf(link)]
  if not c then return lines end
  local class = charClass()
  local specs = type(class) == "string" and not isSecret(class) and M.SPECS and M.SPECS[class]
  if not specs then return lines end
  local mode = (settings or DEFAULTS).specFilter
  local tree = mode == "auto" and autoTree(specs) or nil
  local rows = take("consumableRows")
  local buff = M.ExpandStats(c.stats, c.pct) -- the stats of the buff, its percentages as rating of this level
  for _, spec in ipairs(specs) do
    if specWanted(spec, mode, tree) then
      local measures
      if spec.role == "tank" then measures = TANK_MEASURES
      elseif spec.role == "healing" then measures = HEAL_MEASURES
      else measures = DAMAGE_MEASURES end
      local words = {}
      for _, kind in ipairs(measures) do
        local measure = spec[kind]
        local gear = FX.gearWorth(measure)
        local value = statsWorth(measure, buff)
        if gear > 0.05 and math.abs(value) > 0.0005 then
          local p = value / gear * 100
          local text = string.format(BIT.L("%s%% %s"), shortNumber(p, true), BIT.L(kind == "damage" and "damage"
            or kind == "survival" and "survival" or kind == "threat" and "threat" or "healing"))
          if measure.approximate then text = string.format(BIT.L("%s (approx.)"), text) end
          words[#words + 1] = coloured(p, text)
        end
      end
      if #words > 0 then
        rows[#rows + 1] = icon(spec.icon) .. " " .. BIT.L(spec.name) .. ": " .. table.concat(words, ", ")
      end
    end
  end
  if #rows == 0 then return lines end
  local divider = alloc("line")
  divider[1], divider[2], divider[3], divider[4] = DIVIDER, 1, 1, 1
  lines[#lines + 1] = divider
  local head = alloc("line")
  local lasts = M.DurationText(c.kind ~= "food" and c.dur or 0)
  head[1], head[2], head[3], head[4] = lasts
    and string.format(BIT.L("The buff is worth, against your gear (%s):"), lasts)
    or BIT.L("The buff is worth, against your gear:"), 0.4, 0.73, 1
  lines[#lines + 1] = head
  for _, text in ipairs(rows) do
    local l = alloc("line")
    l[1], l[2], l[3], l[4] = text, 1, 1, 1
    lines[#lines + 1] = l
  end
  return lines
end

local function tooltipLinesBody(link, gameCompares, alloc)
  -- an elixir, a flask, food, a potion or a scroll with stats: its buff against the gear, not a comparison
  if settings and settings.consumables ~= false and M.CONSUMABLES and M.ItemIDOf then
    local id = M.ItemIDOf(link)
    if id and M.CONSUMABLES[id] then return M.ConsumableLines(link, alloc) end
  end
  local allowed = M.CanEquipItem(link)
  if allowed ~= true then
    local lines = alloc("lines")
    local loc = allowed == false and equipLoc(link)
    if loc and (SLOTS[loc] or BOTH_HANDS[loc]) and settings and (settings.compare or settings.specs) then
      local line = alloc("line")
      line[1], line[2], line[3], line[4] = BIT.L("Cannot use this item"), 1, 0.35, 0.35
      lines[#lines + 1] = line
    end
    return lines
  end
  if not tooltipWantsFull() then return tooltipLinesCompact(link, alloc) end
  local lines = alloc("lines")
  if not (settings and (settings.compare or settings.specs)) then return lines end
  local comps = compareBody(link, alloc) or EMPTY
  -- Nothing of ours in any slot: the empty blocks then name their slots as well.
  local allEmpty = true
  for _, c in ipairs(comps) do
    if #c.against > 0 then allEmpty = false end
  end
  local foreign = settings.compare and inspecting()
  for _, c in ipairs(comps) do
    if settings.compare then
    local against = #c.against > 0 and namesJoined(c.against) or BIT.L("an empty slot")
    against = against .. slotLabel(c, allEmpty)
    -- one whole template per heading, colon included, so a language can word it as it needs to
    local head
    if foreign then
      head = string.format(BIT.L("Compared with your gear: %s"), against)
    elseif settings.icons then
      head = string.format(BIT.L("Against %s"), against)
    else
      head = string.format(BIT.L("Against %s:"), against)
    end
    -- The differences, unless the tooltip has them already: the game's own comparison, or an empty slot,
    -- where they are the item's own stats.
    local showDiffs = #c.against > 0 and not gameCompares
    if settings.icons then
      local l = alloc("line")
      l[1], l[2], l[3], l[4] = head, 0.4, 0.73, 1
      lines[#lines + 1] = l
      if showDiffs and #c.diffs == 0 then
        l = alloc("line")
        l[1], l[2], l[3], l[4] = BIT.L("the same stats"), 0.7, 0.7, 0.7
        lines[#lines + 1] = l
      end
      -- the differences, three to a line, and below them what they give, summed, with icons
      -- (the buffers are scratch and cleared in place; re-allocating one mid-loop was garbage)
      local row, sums, order = take("diffRow"), take("diffSums"), take("diffOrder")
      for i, d in ipairs(c.diffs) do
        row[#row + 1] = coloured(d.diff, statText(d.diff, d.key))
        if #row == 3 or i == #c.diffs then
          if showDiffs then
            local l2 = alloc("line")
            l2[1], l2[2], l2[3], l2[4] = table.concat(row, "   "), 1, 1, 1
            lines[#lines + 1] = l2
          end
          clear(row)
        end
        if settings.worth then
          local parts = M.WorthParts(d.key, d.diff)
          -- the item's own armor too, so the armor icon's total agrees with the Armor line (+50 Armor and
          -- +4 Agility's +8 armor are +58, not +8)
          if d.key == "RESISTANCE0_NAME" then
            clear(parts)
            addPart(parts, "armor", d.diff)
          end
          for j = 1, #parts, 2 do
            local kind, value = parts[j], parts[j + 1]
            if not sums[kind] then order[#order + 1] = kind end
            sums[kind] = (sums[kind] or 0) + value
          end
        end
      end
      local worth = take("worthRow")
      for _, kind in ipairs(order) do
        if sums[kind] ~= 0 and (not PERCENT_KINDS[kind] or worthShowing(sums[kind])) then
          worth[#worth + 1] = worthSeg(kind, sums[kind])
        end
        if #worth == 3 then -- three to a line
          local l2 = alloc("line")
          l2[1], l2[2], l2[3], l2[4] = table.concat(worth, "   "), 0.7, 0.7, 0.7
          lines[#lines + 1] = l2
          clear(worth)
        end
      end
      if #worth > 0 then
        local l2 = alloc("line")
        l2[1], l2[2], l2[3], l2[4] = table.concat(worth, "   "), 0.7, 0.7, 0.7
        lines[#lines + 1] = l2
      end
    else
      local l = alloc("line")
      l[1], l[2], l[3], l[4] = head, 0.4, 0.73, 1
      lines[#lines + 1] = l
      if showDiffs and #c.diffs == 0 then
        l = alloc("line")
        l[1], l[2], l[3], l[4] = "  " .. BIT.L("the same stats"), 0.7, 0.7, 0.7
        lines[#lines + 1] = l
      end
      for _, d in ipairs(c.diffs) do
        local up = d.diff > 0
        local worth = settings.worth and M.Worth(d.key, d.diff, true)
        local stat = statText(d.diff, d.key)
        if showDiffs then
          local l2 = alloc("line")
          l2[1], l2[2], l2[3], l2[4] = "  " .. stat, up and 0.3 or 1, up and 1 or 0.35, up and 0.3 or 0.35
          lines[#lines + 1] = l2
          if worth then
            l2 = alloc("line")
            l2[1], l2[2], l2[3], l2[4] = "      " .. worth, 0.7, 0.7, 0.7
            lines[#lines + 1] = l2
          end
        elseif worth then -- the stat only to say what its worth is of
          local l2 = alloc("line")
          l2[1], l2[2], l2[3], l2[4] = "  " .. bySign(d.diff, stat) .. ": " .. worth, 0.7, 0.7, 0.7
          lines[#lines + 1] = l2
        end
      end
    end
    end
    -- The specs' ratings, and for someone else's item the up/down line in front of them:
    -- the arrow and the best spec's number. The ratings are measured for the arrow even
    -- when the specs' own lines are switched off.
    local ratings = (settings.specs or foreign)
      and specRatingsBody(link, c.against, c.slots, c.offHand, alloc)
    if ratings then
      if foreign then
        local best, spec, changed = bestPart(ratings)
        if best then
          local l = alloc("line")
          l[1], l[2], l[3], l[4] = gearLine(best, spec), 1, 1, 1
          lines[#lines + 1] = l
        elseif changed then
          local l = alloc("line")
          l[1], l[2], l[3], l[4] = BIT.L("No clear upgrade for this slot"), 0.7, 0.7, 0.7
          lines[#lines + 1] = l
        end
      end
      if settings.specs then specLines(lines, ratings, alloc) end
    end
  end
  -- Tank caps: one independent section after the comparisons (once per tooltip, not per
  -- worn slot), only when the gate holds and an API answers. A pcall keeps a throwing
  -- client from costing the tooltip; on error nothing is added.
  do
    local ok, extra = pcall(tankExtraLines, link, alloc)
    if ok and type(extra) == "table" and #extra > 0 then
      -- No stacked dividers: specLines may have closed with its own.
      if #lines > 0 and lines[#lines][1] ~= DIVIDER then
        local l = alloc("line")
        l[1], l[2], l[3], l[4] = DIVIDER, 1, 1, 1
        lines[#lines + 1] = l
      end
      for _, l in ipairs(extra) do lines[#lines + 1] = l end
    end
  end
  -- What was counted beyond the stats: the item's effects and its set (and what is not rated), and a capped stat.
  if settings and settings.specs and M.EffectNotes then
    local ok, notes = pcall(M.EffectNotes, link, charFact("sets", FX.computeSets))
    local capOk, capLine = pcall(FX.capNote, link, alloc)
    if ok and capOk and capLine and type(notes) == "table" then notes[#notes + 1] = capLine end
    if ok and type(notes) == "table" and #notes > 0 then
      if #lines > 0 and lines[#lines][1] ~= DIVIDER then
        local l = alloc("line")
        l[1], l[2], l[3], l[4] = DIVIDER, 1, 1, 1
        lines[#lines + 1] = l
      end
      for _, text in ipairs(notes) do
        local l = alloc("line")
        l[1], l[2], l[3], l[4] = text, 0.7, 0.7, 0.7
        lines[#lines + 1] = l
      end
    end
  end
  return lines
end

function M.TooltipLines(link, gameCompares)
  return tooltipLinesBody(link, gameCompares, fresh)
end
M.TooltipLines = memoized(M.TooltipLines)

-- The hover path: the same lines, byte for byte, but built out of the build-scoped scratch
-- (take), so a warm hover allocates no rows or records at all. add() copies every row into
-- the tooltip before the next hover's build may reuse the scratch.
local function tooltipLinesHover(link, gameCompares)
  return tooltipLinesBody(link, gameCompares, take)
end
local hoverTooltipLines = memoized(tooltipLinesHover)

-- What add() last put on a tooltip (weak-keyed: pooled tooltips die with their frame). The
-- client fires the item callback for the same tooltip more than once: a comparison refresh,
-- or its own re-processing of a tooltip our AddLine touched, which can come in a later frame
-- while the tooltip still holds the block. A fire for a tooltip that has not been cleared
-- since we added must not rebuild and append the whole block again (the tooltip would keep
-- growing, rebuilt row by row on every fire: the game stutters). cleared counts each
-- tooltip's native clears, so rec.gen tells "still holds our block" from "rebuilt since";
-- the row count catches a clear the event missed. The record is reused per tooltip (filled
-- in place), so a hover storm allocates none. cleared/watched live on this table so the
-- chunk's local count does not grow (Lua 5.1 allows 200 active locals per chunk).
local addedTo = setmetatable({}, { __mode = "k" })
addedTo.cleared = setmetatable({}, { __mode = "k" }) -- [tooltip] = native clears so far
addedTo.watched = setmetatable({}, { __mode = "k" }) -- [tooltip] = true once hooked

-- Count a tooltip's native clears (OnTooltipCleared fires from ClearLines and SetItem
-- rebuilds) once per tooltip object; GameTooltip and ItemRefTooltip are the only ones
-- add() writes on, so the hook count stays tiny.
addedTo.watchClears = function(tooltip)
  if addedTo.watched[tooltip] or type(tooltip.HookScript) ~= "function" then return end
  addedTo.watched[tooltip] = true
  pcall(tooltip.HookScript, tooltip, "OnTooltipCleared", function(t)
    addedTo.cleared[t] = (addedTo.cleared[t] or 0) + 1
  end)
end

-- The block rows, copied onto the tooltip. Named, so the hot path allocates no closure and
-- a throwing client cannot strand the re-entry flag below.
addedTo.copyRows = function(tooltip, out)
  for _, line in ipairs(out) do tooltip:AddLine(line[1], line[2], line[3], line[4]) end
end

-- The only tooltips this module writes on: the game's own hover tooltip and the one a
-- clicked link opens. Everything else the post-call fires for is left alone -- above all
-- the Blizzard comparison tooltips (ShoppingTooltip1/2/3), which carry an item of their
-- own and fire the very same Enum.TooltipDataType.Item post-call while the player holds
-- Shift or the compare setting is on. Without this guard each of them would cost a whole
-- TooltipLines build per hover (three builds where one is enough); with it they cost the
-- one comparison below and nothing else. BagMarkers/QuestMarkers never hook tooltips, so
-- this is the only such filter in the module.
local function trackedTooltip(tooltip)
  return tooltip == GameTooltip or tooltip == ItemRefTooltip
end

local hooked -- hookTooltips registers once: PLAYER_LOGIN runs it once, and a second
             -- registration would only make add() run twice per tooltip (the guard above
             -- would swallow the duplicate lines, but not the double bookkeeping).
local inAdd -- a build in flight owns the scratch arenas: never start a second one inside
            -- it. It spans the row copy too: a client callback from AddLine re-entering
            -- here would otherwise corrupt the rows being copied out and loop.

local function hookTooltips()
  if hooked then return end
  hooked = true
  local function add(tooltip)
    if inAdd or not trackedTooltip(tooltip) then return end
    local _, link = ask(tooltip.GetItem, tooltip)
    if type(link) ~= "string" or isSecret(link) then return end
    -- A fire for a tooltip that still holds the block we added (same link, no native clear
    -- since, rows still counted) is skipped: rebuilding would append the whole block again
    -- and build it again. The clear counter is the only "rebuild" signal -- a re-fire
    -- without a clear keeps the rows the tooltip holds whatever the density says, or a
    -- Shift toggle would stack a second block below the first. A tooltip cleared since --
    -- or one we never filled -- falls through to a fresh add.
    addedTo.watchClears(tooltip)
    local t = ask(GetTime)
    local density = tooltipWantsFull() and "full" or "compact"
    local rec = addedTo[tooltip]
    if rec and rec.link == link then
      local n = ask(tooltip.NumLines, tooltip)
      local rowsHeld = n == nil or (rec.lines and n >= rec.lines)
      if rowsHeld and rec.gen == (addedTo.cleared[tooltip] or 0) then
        return
      end
    end
    -- the game compares by itself when the setting says so, or while Shift is held
    local gameCompares = TooltipUtil and ask(TooltipUtil.ShouldDoItemComparison, tooltip) == true
    -- A throwing client anywhere in the comparison must not cost the tooltip. The flag spans
    -- the copy: a client callback from AddLine re-entering here (Forever re-processes a
    -- tooltip our own AddLine touched) must not start a second build over the rows being
    -- copied out -- the block is already built, and the fire is answered by these rows.
    inAdd = true
    local ok, out = pcall(hoverTooltipLines, link, gameCompares)
    if ok and type(out) == "table" then
      pcall(addedTo.copyRows, tooltip, out)
      if not rec then
        rec = {}
        addedTo[tooltip] = rec
      end
      rec.link, rec.density = link, density
      rec.t = type(t) == "number" and t or nil
      rec.gen = addedTo.cleared[tooltip] or 0
      rec.lines = ask(tooltip.NumLines, tooltip)
    end
    inAdd = false
  end
  if type(TooltipDataProcessor) == "table" and type(TooltipDataProcessor.AddTooltipPostCall) == "function"
    and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, (BIT.Perf and BIT.Perf.Wrap("StatsInfo.itemTooltip", add) or add))
  elseif GameTooltip and type(GameTooltip.HookScript) == "function" then
    GameTooltip:HookScript("OnTooltipSetItem", (BIT.Perf and BIT.Perf.Wrap("StatsInfo.itemTooltip", add) or add))
    -- trackedTooltip accepts ItemRefTooltip (chat links); the legacy branch must hook it too,
    -- or clicked links get no block on a client without TooltipDataProcessor.
    if type(ItemRefTooltip) == "table" and type(ItemRefTooltip.HookScript) == "function" then
      ItemRefTooltip:HookScript("OnTooltipSetItem", add)
    end
  end
end

---------------------------------------------------------------------------------------------
-- /upt probe: what this client reports, for the breakdown
---------------------------------------------------------------------------------------------

-- Functions the breakdown could be built on; the probe records which of them exist.
local PROBED_FUNCTIONS = {
  "GetCritChance", "GetRangedCritChance", "GetSpellCritChance", "GetDodgeChance", "GetParryChance",
  "GetBlockChance", "GetShieldBlock", "GetHitModifier", "GetSpellHitModifier", "GetCritChanceFromAgility",
  "GetSpellCritChanceFromIntellect", "GetAttackPowerForStat", "GetUnitHealthModifier",
  "GetUnitMaxHealthModifier", "GetManaRegen", "GetPowerRegen", "GetCombatRating", "GetCombatRatingBonus",
  "GetCombatRatingBonusForCombatRatingValue", "GetSpellBonusDamage", "GetSpellBonusHealing", "UnitStat", "UnitArmor", "UnitAttackPower",
  "UnitRangedAttackPower", "UnitDefense", "UnitDefenseSkill", "UnitResistance", "UnitClass", "UnitLevel", "GetShapeshiftFormID",
  "GetItemStats", "GetInventoryItemLink",
  "GetCritChanceFromStat", "GetSpellCritChanceFromStat", "GetDodgeChanceFromAttribute", "UnitHPPerStamina",
  "GetManaRegenFromSpirit", "GetRangedAttackPowerForStat", "GetHealthRegen", "GetHealthRegenFromSpirit",
  "GetExpertise", "GetRangedHitModifier", "GetOffhandHitModifier", -- the hit and expertise caps ("Count hit and expertise only up to their caps")
}

local function plain(v)
  if isSecret(v) then return "<secret>" end
  if type(v) == "number" or type(v) == "string" or type(v) == "boolean" then return v end
  return v == nil and "<nil>" or ("<" .. type(v) .. ">")
end

local function record(fn, ...)
  if type(fn) ~= "function" then return "<no function>" end
  local out = { pcall(fn, ...) }
  if not out[1] then return "<error: " .. tostring(out[2]) .. ">" end
  local values = {}
  for i = 2, #out do values[#values + 1] = plain(out[i]) end
  return values
end

function M.Probe()
  local p = {}
  local build, buildNumber = ask(GetBuildInfo)
  p.build = tostring(build) .. "." .. tostring(buildNumber)
  p.locale = ask(GetLocale)
  p.level = plain(ask(UnitLevel, "player"))
  local _, class = ask(UnitClass, "player")
  p.class = class
  local _, race = ask(UnitRace, "player")
  p.race = race
  p.inCombat = plain(ask(InCombatLockdown))
  p.form = plain(ask(GetShapeshiftFormID))
  p.functions = {}
  for _, name in ipairs(PROBED_FUNCTIONS) do p.functions[name] = type(_G[name]) end
  p.functions["C_Item.GetItemStats"] = type(C_Item and C_Item.GetItemStats)
  p.functions["C_PaperDollInfo"] = type(C_PaperDollInfo)
  p.functions["C_TooltipInfo.GetInventoryItem"] = type(C_TooltipInfo and C_TooltipInfo.GetInventoryItem)
  -- "Specs to rate: Automatic" asks these: what the client answers for the talent tree in use
  local specApi = type(C_SpecializationInfo) == "table" and C_SpecializationInfo or {}
  p.functions["C_SpecializationInfo.GetSpecialization"] = type(specApi.GetSpecialization)
  p.functions["C_SpecializationInfo.GetSpecializationInfo"] = type(specApi.GetSpecializationInfo)
  p.functions["GetSpecialization"] = type(GetSpecialization)
  p.functions["GetPrimaryTalentTree"] = type(GetPrimaryTalentTree)
  local tree = computeTree()
  p.specTree = tree and tree[1] or "<none: Automatic rates every spec>"
  p.specFilter = tostring((settings or DEFAULTS).specFilter)

  local v = {}
  for i = 1, 5 do v["UnitStat" .. i] = record(UnitStat, "player", i) end
  v.GetSpecialization = record(specApi.GetSpecialization or GetSpecialization or GetPrimaryTalentTree)
  for i = 1, 3 do v["GetSpecializationInfo" .. i] = record(specApi.GetSpecializationInfo or GetSpecializationInfo, i) end
  -- what the hit and expertise caps read (Effects.lua M.CapCurrent): the character sheet's own formulas
  v.GetExpertise = record(GetExpertise)
  v.GetRangedHitModifier = record(GetRangedHitModifier)
  v.GetCombatRatingBonusHitMelee = record(GetCombatRatingBonus, type(CR_HIT_MELEE) == "number" and CR_HIT_MELEE or 6)
  v.GetCombatRatingBonusHitSpell = record(GetCombatRatingBonus, type(CR_HIT_SPELL) == "number" and CR_HIT_SPELL or 8)
  v.GetCombatRatingBonusForValueHit10 = record(GetCombatRatingBonusForCombatRatingValue,
    type(CR_HIT_MELEE) == "number" and CR_HIT_MELEE or 6, 10)
  v.ShouldUnitStatsBeSecret = record(C_Secrets and C_Secrets.ShouldUnitStatsBeSecret)
  if M.CapCurrent then
    p.capCurrent = { melee = M.CapCurrent("melee"), ranged = M.CapCurrent("ranged"), spell = M.CapCurrent("spell"),
      expertise = M.CapCurrent("expertise") }
  end
  v.UnitHealthMax = record(UnitHealthMax, "player")
  v.UnitPowerMax0 = record(UnitPowerMax, "player", 0)
  v.UnitArmor = record(UnitArmor, "player")
  v.UnitAttackPower = record(UnitAttackPower, "player")
  v.UnitRangedAttackPower = record(UnitRangedAttackPower, "player")
  v.UnitDefense = record(UnitDefense, "player")
  v.GetCritChance = record(GetCritChance)
  v.GetRangedCritChance = record(GetRangedCritChance)
  for school = 1, 7 do v["GetSpellCritChance" .. school] = record(GetSpellCritChance, school) end
  v.GetDodgeChance = record(GetDodgeChance)
  v.GetParryChance = record(GetParryChance)
  v.GetBlockChance = record(GetBlockChance)
  v.GetHitModifier = record(GetHitModifier)
  v.GetSpellHitModifier = record(GetSpellHitModifier)
  v.GetCritChanceFromAgility = record(GetCritChanceFromAgility, "player")
  v.GetSpellCritChanceFromIntellect = record(GetSpellCritChanceFromIntellect, "player")
  for stat = 1, 2 do v["GetAttackPowerForStat" .. stat .. "_10"] = record(GetAttackPowerForStat, stat, 10) end
  v.GetCritChanceFromStat2_10 = record(GetCritChanceFromStat, 2, 10)
  v.GetSpellCritChanceFromStat4_10 = record(GetSpellCritChanceFromStat, 4, 10)
  v.GetDodgeChanceFromAttribute = record(GetDodgeChanceFromAttribute)
  v.UnitHPPerStamina = record(UnitHPPerStamina, "player")
  v.GetUnitHealthModifier = record(GetUnitHealthModifier, "player")
  v.GetManaRegen = record(GetManaRegen)
  v.GetManaRegenFromSpirit = record(GetManaRegenFromSpirit)
  v.GetHealthRegen = record(GetHealthRegen)
  v.GetHealthRegenFromSpirit = record(GetHealthRegenFromSpirit)
  v.GetSpellBonusDamage2 = record(GetSpellBonusDamage, 2)
  v.GetSpellBonusHealing = record(GetSpellBonusHealing)
  p.values = v

  p.items = {}
  for slot = 1, 19 do
    local link = equipped(slot)
    if link then
      local item = { link = link, stats = {} }
      for k, n in pairs(itemStatsFresh(link)) do item.stats[k] = n end
      local data = ask(C_TooltipInfo and C_TooltipInfo.GetInventoryItem, "player", slot)
      if type(data) == "table" and type(data.lines) == "table" then
        item.lines = {}
        for _, line in ipairs(data.lines) do
          local left = line.leftText
          if type(left) == "string" and not isSecret(left) then item.lines[#item.lines + 1] = left end
        end
      end
      p.items[slot] = item
    end
  end

  local db = type(BIT.GlobalDB) == "function" and BIT.GlobalDB() or BIT.DB()
  if type(db.probes) ~= "table" then db.probes = {} end
  db.probes[#db.probes + 1] = p
  local count = 0
  for _ in pairs(p.items) do count = count + 1 end
  BIT.Say(string.format("probe %d recorded (%s level %s, %d equipped items). It is saved at logout or /reload.",
    #db.probes, tostring(class), tostring(p.level), count))
  return p
end

BIT.RegisterCommand("probe", function() M.Probe() end)

---------------------------------------------------------------------------------------------
-- Start, and the settings tab
---------------------------------------------------------------------------------------------

local function prepareStatsSettings()
  settings = BIT.Settings("StatsInfo", DEFAULTS)
  M.settings = settings
end
if BIT.RegisterWaker then BIT.RegisterWaker("StatsInfo", prepareStatsSettings) end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self, event, name)
  if event == "ADDON_LOADED" then
    if name ~= BIT.name then return end
    self:UnregisterEvent("ADDON_LOADED")
    if not BIT.ShouldRun("StatsInfo") then self:UnregisterAllEvents() return end
    prepareStatsSettings()
    local global = type(BIT.GlobalDB) == "function" and BIT.GlobalDB() or BIT.DB()
    global.statsLearned = nil -- what 0.4.x measured in play; the game's own numbers replace it
  elseif event == "PLAYER_LOGIN" then
    self:UnregisterEvent("PLAYER_LOGIN")
    -- The tank caps' numbers move with gear, buffs, form and level: on those events the
    -- short-lived cache (tankRead above) is dropped and the next hover reads them live again.
    self:RegisterUnitEvent("UNIT_AURA", "player")
    self:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")
    self:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
    self:RegisterEvent("PLAYER_LEVEL_UP")
    hookTooltips()
  else
    tankForget()
    if M.CapExpire then M.CapExpire() end -- gear, auras, form or level changed: hit and expertise are read again
  end
end)

-- A settings-only sample: an explicit mock item tooltip with this module's own lines on it,
-- not the live GameTooltip and not the character's gear. The preview is static on purpose
-- (the policy DoTInfo's buildDoTPreview follows): every number below is hardcoded, no live
-- API is ever read for it, and it measures nothing and hooks nothing.

-- The sample item and its numbers, fixed: an item against an empty slot, so the worth line
-- carries the whole story ("Against an empty slot: +30 health +45 mana"). The words are the
-- English keys of the locale files, translated when the lines are built; the worth and rating
-- words come from the same helpers the real lines use, so the sample cannot drift from them.
local SAMPLE = {
  title = "Embossed Leather Vest (sample)",
  itemLines = {
    { "Item Level 28", 0.5, 0.5, 0.5 },
    { "120 Armor", 1, 1, 1 },
    { "+3 Stamina", 1, 1, 1 },
    { "+3 Intellect", 1, 1, 1 },
  },
  against = "an empty slot",
  stats = {
    { stat = "+3 Stamina", value = 30, kind = "health" },
    { stat = "+3 Intellect", value = 45, kind = "mana" },
  },
  specs = {
    { icon = "Interface\\Icons\\Spell_Shadow_DeathCoil", name = "Affliction", number = ">300" },
    { icon = "Interface\\Icons\\Spell_Shadow_RainOfFire", name = "Destruction", number = "25" },
  },
}

-- The mock tooltip's lines under the current settings: TooltipLines' own shapes, on the
-- hardcoded numbers above. { text, r, g, b }; the divider and the icon escapes are the ones
-- the real lines carry.
local function sampleLines(iconSize)
  local s = settings or DEFAULTS
  local out = {}
  local function add(text, r, g, b) out[#out + 1] = { text = text, r = r, g = g, b = b } end
  add(BIT.L(SAMPLE.title), 1, 1, 1)
  for _, l in ipairs(SAMPLE.itemLines) do add(BIT.L(l[1]), l[2], l[3], l[4]) end
  if not tooltipWantsFull() then
    if s.compare or s.specs then
      local best = SAMPLE.specs[1]
      add(gearLine({ percent = MAX_PERCENT, capped = true, noBaseline = true, kind = "damage" },
        best, { against = {} }), 1, 1, 1)
    end
    return out
  end
  if s.compare then
    add(DIVIDER, 1, 1, 1)
    local against = BIT.L(SAMPLE.against)
    if s.icons then
      add(string.format(BIT.L("Against %s"), against), 0.4, 0.73, 1)
      if s.worth then
        local row = {}
        for _, d in ipairs(SAMPLE.stats) do
          row[#row + 1] = icon(ICONS[d.kind], iconSize) .. " " .. UP .. worthValue(d.kind, d.value)
            .. " " .. BIT.L(WORTH_SHORT[d.kind]) .. "|r"
        end
        add(table.concat(row, "   "), 0.7, 0.7, 0.7)
      end
    else
      add(string.format(BIT.L("Against %s:"), against), 0.4, 0.73, 1)
      for _, d in ipairs(SAMPLE.stats) do
        if s.worth then
          add("  " .. UP .. BIT.L(d.stat) .. "|r: " .. UP .. worthWord(d.kind, d.value) .. "|r", 0.7, 0.7, 0.7)
        end
      end
    end
  end
  if s.specs then
    add(DIVIDER, 1, 1, 1)
    for _, r in ipairs(SAMPLE.specs) do
      local rating = string.format(ratingTemplate("damage", true), r.number)
      if s.icons then
        add(icon(r.icon, iconSize) .. " " .. BIT.L(r.name) .. ": " .. rating, 1, 1, 1)
      else
        add("  " .. BIT.L(r.name) .. ": " .. rating, 0.8, 0.8, 0.8)
      end
    end
  end
  return out
end

-- The mock tooltip inside scene: a dark tooltip card, a bag button mock, and sample quest
-- reward buttons. The arrows are the game's own small
-- stream arrow -- Interface\Buttons\UI-MicroStream-Green, the same file BagMarkers paints in
-- a real bag button's corner -- not the old WHITE8X8 pieces (commit 221cdee moved the bag
-- and quest badges to the Blizzard arrows; the mock follows). The tooltip, bag badge and
-- sample quest markers are re-laid-out by renderMockTooltip on every change.
local TIP_LINES = 20 -- the sample never needs more; the pool is padded with blanks
local BAG_SLOT = 36 -- a mock bag slot, the size the arrows' geometry is made for
local function buildMockTooltip(scene)
  local tip = CreateFrame("Frame", nil, scene, "BackdropTemplate")
  BIT.UI.Backdrop(tip, 0.09, 0.98)
  scene.tip = tip
  scene.tipLines = {}
  for i = 1, TIP_LINES do
    local line = tip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    line:SetJustifyH("LEFT")
    scene.tipLines[i] = line
  end
  -- Three bag slots, painted by BagMarkers' own painter (M.PaintVerdictMarker, M.SeatMarker): an upgrade with
  -- its spec icon, a plain upgrade and a downgrade. They follow the Arrows tab at once: the corner, the nudge,
  -- the size and the spec icon. The coin on the first slot stands for another addon's junk mark, so a clash
  -- with the arrows shows here before it shows in the bags.
  scene.bagSlots = {}
  local faces = { "Interface\\Icons\\INV_Chest_Leather_01", "Interface\\Icons\\INV_Boots_05",
    "Interface\\Icons\\INV_Gauntlets_04" }
  for i = 1, 3 do
    local slot = CreateFrame("Frame", nil, scene)
    slot:SetSize(BAG_SLOT, BAG_SLOT)
    local face = slot:CreateTexture(nil, "BACKGROUND")
    face:SetAllPoints()
    face:SetTexture(faces[i])
    face:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    local badge = CreateFrame("Frame", nil, slot)
    badge:EnableMouse(false)
    badge:SetSize(24, 24)
    badge:SetPoint("TOPRIGHT", slot, "TOPRIGHT", -2, -2)
    slot.badge = badge
    scene.bagSlots[i] = slot
  end
  scene.bag = scene.bagSlots[1]
  local coin = scene.bag:CreateTexture(nil, "ARTWORK")
  coin:SetSize(14, 14)
  coin:SetPoint("TOPLEFT", scene.bag, "TOPLEFT", 1, -1)
  coin:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
  scene.junkCoin = coin
  scene.caption = scene:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  scene.caption:SetJustifyH("LEFT")
  scene.caption:SetText(BIT.L("Static sample. The coin stands for another addon's junk mark; the arrows "
    .. "follow the Arrows tab. Live upgrades are rated against your gear."))
  local rewards = CreateFrame("Frame", nil, scene)
  rewards:SetSize(184, 48)
  scene.questRewardRow = rewards
  local rewardLabel = rewards:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  rewardLabel:SetJustifyH("LEFT")
  rewardLabel:SetText(BIT.L("Quest rewards (sample)"))
  scene.questRewardLabel = rewardLabel
  scene.questRewardIcons, scene.questRewardArrows, scene.questBestArrows = {}, {}, {}
  local rewardTextures = {
    "Interface\\Icons\\INV_Weapon_Shortblade_01",
    "Interface\\Icons\\INV_Staff_13",
    "Interface\\Icons\\INV_Misc_QuestionMark",
  }
  for i, texture in ipairs(rewardTextures) do
    local item = CreateFrame("Frame", nil, rewards)
    item:SetSize(32, 32)
    local itemIcon = item:CreateTexture(nil, "BACKGROUND")
    itemIcon:SetAllPoints()
    itemIcon:SetTexture(texture)
    scene.questRewardIcons[i] = item
    if i < 3 then
      local arrow = item:CreateTexture(nil, "OVERLAY")
      arrow:SetTexture("Interface\\Buttons\\UI-MicroStream-Green")
      arrow:SetTexCoord(0, 1, 1, 0)
      arrow:SetVertexColor(1, 1, 1, 1)
      scene.questRewardArrows[i] = arrow
      if i == 2 then
        local bestArrow = item:CreateTexture(nil, "OVERLAY")
        bestArrow:SetTexture("Interface\\Buttons\\UI-MicroStream-Green")
        bestArrow:SetTexCoord(0, 1, 1, 0)
        bestArrow:SetVertexColor(1, 1, 1, 1)
        scene.questBestArrows[i] = bestArrow
      end
    end
  end
end

-- The mock tooltip redrawn at a style: font size, scale and opacity all show here, whether
-- they come from the shared appearance editor (UI.Appearance) or from the TRY IT sliders.
-- Pure layout over the hardcoded sample: no live API, no settings writes.
--   font size  every font in the mock, and the heights the rows and the title are measured at
--   scale      the card's width, the rows' line boxes, the bag button mock and its badge
--   opacity    the rows, the caption, the title and the whole bag button mock
--
-- The sample grows with wrapped text; the outer settings scroll owns overflow.
local SCENE_HEIGHT = 280
local MIN_FONT, MAX_FONT = 6, 24
local MIN_SCALE, MAX_SCALE = 0.5, 2
-- The bag button mock's corner badge, the geometry BagMarkers paints in a real button's
-- corner: a MARKER x MARKER box at the button's TOPRIGHT holding the arrow, with the
-- ICON x ICON beneficiary icon inside the corner and the +N cue under it. All of it is
-- scaled with the button mock, so the Scale slider zooms the badge as it zooms the button.
-- The sample verdicts the three mock bag slots are painted with (BagMarkers' own verdict shape).
local function sampleBagVerdicts()
  local first, second = SAMPLE.specs[1], SAMPLE.specs[2] or SAMPLE.specs[1]
  return {
    { verdict = "up", beneficiaries = { { spec = { icon = first.icon } }, { spec = { icon = second.icon } } } },
    { verdict = "up", beneficiaries = {} },
    { verdict = "down" },
  }
end

local function clamp(v, lo, hi)
  if type(v) ~= "number" then return lo end
  if v < lo then return lo elseif v > hi then return hi end
  return v
end

local function renderMockTooltip(scene, style)
  style = type(style) == "table" and style or {}
  local fs = clamp(tonumber(style.fontSize) or 12, MIN_FONT, MAX_FONT)
  local scale = clamp(tonumber(style.scale) or 1, MIN_SCALE, MAX_SCALE)
  local opacity = clamp(tonumber(style.opacity) or 1, 0, 1)
  local font = type(style.font) == "string" and style.font or "Fonts\\FRIZQT__.TTF"
  local outline = (style.outline == "NONE" or type(style.outline) ~= "string") and "" or style.outline
  local width = tonumber(ask(scene.GetWidth, scene)) or 336
  scene:SetHeight(SCENE_HEIGHT)
  -- One row's own wrapped height (the client measures the text at its constrained width),
  -- or the font's line height where the client cannot say.
  local function measure(slot, fallback)
    local h = tonumber(ask(slot.GetStringHeight, slot))
    if h and h > 0 then return h end
    return fallback
  end
  -- Every font in the mock is drawn at the clamped font size; every painted part of it is
  -- drawn at the clamped opacity, so the three TRY IT fields are all visible here:
  -- font size moves the text and the heights measured for it, scale moves the card's width,
  -- the rows' line boxes, the button mock and its badge, opacity fades the whole scene.
  if scene.title then
    if BIT.Style and BIT.Style.ApplyText then
      pcall(BIT.Style.ApplyText, scene.title, style, "text")
    end
    scene.title:SetFont(font, fs, outline) -- the clamped size, not the raw style's
    scene.title:ClearAllPoints()
    scene.title:SetPoint("TOPLEFT", 12, -4)
    scene.title:SetPoint("RIGHT", scene, "RIGHT", -12, 0) -- wrapped into the card
    scene.title:SetText(BIT.L("Preview: sample item"))
    scene.title:SetHeight(0)
  end
  local titleDepth = scene.title and (measure(scene.title, fs + 8) + 8) or (fs + 16)
  -- Measure the footer before placing it below the complete tooltip.
  local bagSize = clamp(math.floor(BAG_SLOT * scale + 0.5), 18, 54)
  local k = bagSize / BAG_SLOT -- the slots' zoom: the arrows are painted at their real size and zoom with them
  local captionFont = clamp(fs - 2, 9, 14)
  local caption = scene.caption
  caption:ClearAllPoints()
  caption:SetPoint("BOTTOMLEFT", scene, "BOTTOMLEFT", 12, 6)
  caption:SetPoint("BOTTOMRIGHT", scene, "BOTTOMRIGHT", -12, 6)
  caption:SetFont(font, captionFont, outline)
  caption:SetTextColor(0.7, 0.7, 0.7, opacity)
  local captionH = measure(caption, captionFont + 2)
  local bagTop
  local rewardSize = math.max(18, math.floor(30 * scale + 0.5))
  local markerSize = math.max(14, math.floor(22 * scale + 0.5))
  local showQuestArrows = (settings or DEFAULTS).questMarkers ~= false
  local iconSize = clamp(math.floor(12 * scale + 0.5), 8, 24)
  local lines = sampleLines(iconSize)
  local tip = scene.tip
  tip:ClearAllPoints()
  tip:SetPoint("TOPLEFT", 12, -titleDepth)
  -- The card's width follows the scale (a narrower card at 0.5x wraps the rows into more
  -- lines, a wider one at 2x spreads them out again).
  local cardW = clamp(math.floor(300 * scale + 0.5), 120, math.max(120, width - 24))
  tip:SetWidth(cardW)
  -- The line box a row is laid out in: the row's own wrapped height, never shorter than the
  -- scaled one, so the rows spread apart when the scale grows.
  local rowBox = (fs + 4) * scale
  -- Keep every sample row; place the bag and reward preview after the measured tooltip.
  local y = 6
  for i, slot in ipairs(scene.tipLines) do
    local entry = lines[i]
    slot:ClearAllPoints()
    if entry then
      slot:SetText(entry.text)
      slot:SetFont(font, fs, outline)
      slot:SetTextColor(entry.r, entry.g, entry.b, opacity)
      slot:SetPoint("TOPLEFT", tip, "TOPLEFT", 8, -y)
      slot:SetPoint("RIGHT", tip, "RIGHT", -8, 0)
      local h = math.max(measure(slot, fs + 4), rowBox)
      slot:Show()
      y = y + h
    else
      slot:SetText("")
      slot:Hide()
    end
  end
  tip:SetHeight(y + 2)
  bagTop = titleDepth + y + 16
  local showBagArrows = (settings or DEFAULTS).bagMarkers ~= false
  local verdicts = sampleBagVerdicts()
  for i, slot in ipairs(scene.bagSlots) do
    slot:SetScale(k)
    slot:SetAlpha(opacity) -- the slots fade with the lines above them
    slot:ClearAllPoints()
    slot:SetPoint("TOPLEFT", scene, "TOPLEFT", (12 + (i - 1) * (bagSize + 8)) / k, -bagTop / k)
    if type(M.SeatMarker) == "function" then pcall(M.SeatMarker, slot.badge, slot) end
    if type(M.PaintVerdictMarker) == "function" then
      pcall(M.PaintVerdictMarker, slot.badge, showBagArrows and verdicts[i] or nil)
    end
  end
  local rewardTop = bagTop + bagSize + 12
  local rewardRow = scene.questRewardRow
  rewardRow:ClearAllPoints()
  rewardRow:SetPoint("TOPLEFT", scene, "TOPLEFT", 12, -rewardTop)
  rewardRow:SetSize(math.max(184, 3 * rewardSize + 16), captionFont + rewardSize + 8)
  rewardRow:SetAlpha(opacity)
  scene.questRewardLabel:ClearAllPoints()
  scene.questRewardLabel:SetPoint("TOPLEFT", rewardRow, "TOPLEFT", 0, 0)
  scene.questRewardLabel:SetFont(font, captionFont, outline)
  scene.questRewardLabel:SetTextColor(0.7, 0.7, 0.7, opacity)
  for i, item in ipairs(scene.questRewardIcons) do
    item:ClearAllPoints()
    item:SetPoint("TOPLEFT", rewardRow, "TOPLEFT", (i - 1) * (rewardSize + 8), -captionFont - 4)
    item:SetSize(rewardSize, rewardSize)
    local arrow = scene.questRewardArrows[i]
    if arrow then
      arrow:SetSize(markerSize, markerSize)
      arrow:ClearAllPoints()
      arrow:SetPoint("TOPRIGHT", item, "TOPRIGHT", -1, -1)
      arrow:SetShown(showQuestArrows)
    end
    local bestArrow = scene.questBestArrows[i]
    if bestArrow then
      bestArrow:SetSize(math.floor(markerSize * 0.75), math.floor(markerSize * 0.75))
      bestArrow:ClearAllPoints()
      bestArrow:SetPoint("TOPRIGHT", item, "TOPRIGHT", -8, -8)
      bestArrow:SetShown(showQuestArrows)
    end
  end
  scene:SetHeight(rewardTop + captionFont + rewardSize + 8 + captionH + 14)
  if scene.onLayout then scene.onLayout() end
end

local function buildStatsPreview(parent)
  local scene = CreateFrame("Frame", nil, parent)
  scene:SetSize(560, SCENE_HEIGHT)
  scene.title = scene:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  scene.title:SetText(BIT.L("StatsInfo sample (not your gear)"))
  buildMockTooltip(scene)
  return scene
end

local function renderStatsPreview(scene, style)
  renderMockTooltip(scene, style)
end

-- The style the preview draws in: the shared appearance editor's (UI.Appearance) own
-- fields, so changing font size, scale or opacity there -- or in the TRY IT sliders below
-- the preview -- moves the preview.
local function resolvedStyle()
  if BIT.Style and BIT.Style.Resolve then
    local ok, s = pcall(BIT.Style.Resolve, "StatsInfo")
    if ok and type(s) == "table" then return s end
  end
  return {}
end

local previewScene -- the built mock tooltip; redrawn on every settings or style change
local tryItSliders = {} -- the TRY IT slider rows, re-seated on the stored style after a render
local function renderPreview()
  if not previewScene then return end
  renderMockTooltip(previewScene, resolvedStyle())
  -- The thumbs and their value labels always show what the style holds -- including a write
  -- this file never made (the shared appearance editor, a preset, a reset), so a slider can
  -- never look as if it were still on the value it was built at.
  for _, holder in ipairs(tryItSliders) do
    if type(holder.Refresh) == "function" then pcall(holder.Refresh, holder) end
  end
end

local function styleGet(key, fallback)
  return function()
    local v = tonumber(resolvedStyle()[key])
    return v or fallback
  end
end

local function styleSet(key)
  return function(v)
    if BIT.Style and BIT.Style.Set then pcall(BIT.Style.Set, "StatsInfo", key, v) end
    renderPreview()
  end
end

-- Every style write re-renders the preview, whoever made it: these sliders above, or the
-- shared appearance editor, a preset or a reset elsewhere. The same contract the other
-- modules' previews follow (HunterRangeFinder, ShieldsInfo and ResourceDing subscribe too).
if BIT.Style and BIT.Style.Subscribe then
  pcall(BIT.Style.Subscribe, "StatsInfo", function() renderPreview() end)
end

BIT.RegisterTab("StatsInfo", {
  defaults = DEFAULTS,
  buildPreview = buildStatsPreview,
  previewRender = renderStatsPreview,
  capabilities = { roles = { "text" }, shapes = false,
    geometry = false, border = false, font = true, scale = true, opacity = true },
  title = "StatsInfo",
  summary = "In an item's tooltip: what its stats change against the item you wear in that slot.",
  -- the preview card at the left, the settings in tabs at its right
  width = 760, height = 560,
  build = function(parent)
    local UI, Rows = BIT.UI, BIT.Looks.Rows
    local PANE_WIDTH = 300
    local LAYOUT = { label = 200, control = 130 } -- the settings column is narrower than the other modules'

    -- Left: the live preview card, like every other module's. A static sample item (the preview never reads
    -- the live API): the tooltip lines, three bag slots and the quest rewards. It follows the settings at the
    -- right and the TRY IT sliders under it.
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetPoint("TOPLEFT", 10, -10)
    card:SetWidth(PANE_WIDTH + 16)
    UI.Backdrop(card, 0.09)
    local cardTitle = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cardTitle:SetPoint("TOPLEFT", 12, -12)
    cardTitle:SetText(BIT.L("Live preview"))
    local cardRule = card:CreateTexture(nil, "ARTWORK")
    cardRule:SetColorTexture(unpack(UI.COLOR.divider))
    cardRule:SetHeight(1)
    cardRule:SetPoint("TOPLEFT", 8, -34)
    cardRule:SetPoint("TOPRIGHT", -8, -34)

    local pane = CreateFrame("Frame", nil, card)
    pane:SetPoint("TOPLEFT", 8, -40)
    pane:SetWidth(PANE_WIDTH)
    pane.title = pane:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    previewScene = pane
    pane:RegisterEvent("MODIFIER_STATE_CHANGED")
    pane:SetScript("OnEvent", function(_, _, key)
      if pane:IsVisible() and (key == "LSHIFT" or key == "RSHIFT") then renderPreview() end
    end)
    buildMockTooltip(pane)

    -- TRY IT: the appearance the preview is drawn in -- the same three fields the shared appearance editor
    -- writes, so either one moves the preview. Each row is registered in tryItSliders so renderPreview
    -- re-seats its thumb on the stored value after any write.
    local tryIt = BIT.Looks.TryItHeader(pane, pane, 0, -10)
    local tryLayout = BIT.Looks.PREVIEW_LAYOUT
    local fontSlider = Rows.Slider(pane, "Font size", 6, 48, 1,
      styleGet("fontSize", 12), styleSet("fontSize"),
      { layout = tryLayout, suffix = " px",
        tooltip = "The size the preview's text is drawn in. The same field the shared appearance editor changes." })
    local scaleSlider = Rows.Slider(pane, "Scale", 0.5, 3, 0.05,
      styleGet("scale", 1), styleSet("scale"),
      { layout = tryLayout, display = function(v) return string.format("%.2fx", v) end,
        tooltip = "Scales the preview's card, rows, icons and bag button. The same field the shared appearance editor changes." })
    local opacitySlider = Rows.Slider(pane, "Opacity", 0, 1, 0.05,
      styleGet("opacity", 1), styleSet("opacity"),
      { layout = tryLayout, display = function(v) return math.floor(v * 100 + 0.5) .. "%" end,
        tooltip = "How see-through the preview's lines and bag button are. The same field the shared appearance editor changes." })
    tryItSliders = { fontSlider, scaleSlider, opacitySlider }
    fontSlider:SetPoint("TOPLEFT", tryIt, "BOTTOMLEFT", -4, -4)
    scaleSlider:SetPoint("TOPLEFT", fontSlider, "BOTTOMLEFT", 0, 0)
    opacitySlider:SetPoint("TOPLEFT", scaleSlider, "BOTTOMLEFT", 0, 0)
    -- The card wraps the sample and the sliders, whatever height the sample measured itself at.
    local AREA_HEIGHT = 500
    pane.onLayout = function()
      local height = 40 + (pane:GetHeight() or 0) + 10 + 20 + 3 * 26 + 14
      card:SetHeight(height)
      parent:SetHeight(math.max(AREA_HEIGHT, height) + 20)
    end

    -- Right: the settings, in tabs, with "Reset this tab" under them.
    local area = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    area:SetPoint("TOPLEFT", card, "TOPRIGHT", 10, 0)
    area:SetPoint("RIGHT", parent, "RIGHT", -10, 0)
    area:SetHeight(AREA_HEIGHT)
    UI.Backdrop(area, 0.09)
    local divider = area:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(unpack(UI.COLOR.divider))
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", 8, -34)
    divider:SetPoint("TOPRIGHT", -8, -34)

    local controls = {} -- every settings row, refreshed after each change
    local function refreshControls()
      for _, row in ipairs(controls) do
        if type(row.Refresh) == "function" then pcall(row.Refresh, row) end
      end
    end
    -- One change path for every control and for "Reset this tab": the switch itself, what it turns on or off
    -- in the game, the bags (and Baganator's corner marks) repainted, then the rows and the preview.
    local function apply(key, value, quiet)
      settings[key] = value
      if key == "bagMarkers" then
        if value then M.EnableBagMarkers() else M.DisableBagMarkers() end
      elseif key == "questMarkers" then
        if value then M.EnableQuestMarkers() else M.DisableQuestMarkers() end
      elseif key == "worldMarkers" then
        if value and M.EnableWorldMarkers then M.EnableWorldMarkers()
        elseif not value and M.DisableWorldMarkers then M.DisableWorldMarkers() end
      end
      if quiet then return end
      if type(M.RefreshBags) == "function" then M.RefreshBags(true) end
      refreshControls()
      renderPreview()
    end
    local function rowOpts(opts)
      opts = opts or {}
      return { tooltip = opts.tooltip, enabledIf = opts.enabledIf, suffix = opts.suffix, display = opts.display,
        layout = LAYOUT, settings = function() return settings or DEFAULTS end,
        register = function(row) controls[#controls + 1] = row end }
    end

    local tabs, active = {}, nil
    local resetButton
    local function selectTab(tab)
      if not tab then return end
      if BIT.Looks and BIT.Looks.ClosePickList then BIT.Looks.ClosePickList() end
      active = tab
      for _, other in ipairs(tabs) do
        local on = other == tab
        -- Show/Hide under pcall, one tab at a time: a raising widget must not leave two contents up.
        pcall(on and other.column.Show or other.column.Hide, other.column)
        pcall(UI.TabSelected, other.button, on)
      end
      if resetButton then resetButton:SetShown(#tab.keys > 0) end
    end
    local function addTab(name)
      local tab = { keys = {}, y = 0 }
      tab.column = UI.ScrollColumn(area)
      tab.column:SetPoint("TOPLEFT", area, "TOPLEFT", 6, -40)
      tab.column:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT", -6, 40)
      tab.column:Hide()
      tab.content = tab.column.content
      local button = CreateFrame("Button", nil, area, "PanelTopTabButtonTemplate")
      -- "caption", not "text": the settings read a frame's .text as the string it shows
      button:SetText(BIT.L(name))
      button.caption = button:GetFontString()
      button:SetSize(UI.TabWidth(button.caption), 26)
      button.caption:SetPoint("CENTER")
      UI.SkinTabButton(button, button.caption)
      local previous = tabs[#tabs]
      if previous then
        button:SetPoint("LEFT", previous.button, "RIGHT", UI.TAB_GAP, 0)
      else
        button:SetPoint("TOPLEFT", area, "TOPLEFT", 8, -8)
      end
      button:SetScript("OnClick", function() selectTab(tab) end)
      tab.button = button

      function tab:place(row, height)
        self.y = UI.PlaceRow(row, self.y, row.standard and row:GetHeight() or height or 26)
        return row
      end
      function tab:header(text)
        if self.y > 0 then self.y = self.y + 8 end
        return self:place(UI.Header(self.content, text), 26)
      end
      function tab:check(key, label, opts)
        self.keys[#self.keys + 1] = key
        return self:place(Rows.Check(self.content, label,
          function() return (settings or DEFAULTS)[key] end,
          function(v) apply(key, v) end, rowOpts(opts)))
      end
      function tab:slider(key, label, min, max, step, opts)
        self.keys[#self.keys + 1] = key
        return self:place(Rows.Slider(self.content, label, min, max, step,
          function() return tonumber((settings or DEFAULTS)[key]) or DEFAULTS[key] end,
          function(v) apply(key, v) end, rowOpts(opts)))
      end
      function tab:choice(key, label, list, opts)
        self.keys[#self.keys + 1] = key
        return self:place(Rows.Choice(self.content, label, list,
          function() return (settings or DEFAULTS)[key] end,
          function(id) apply(key, id) end, rowOpts(opts)))
      end
      -- A wrapped paragraph (already translated); muted is the grey of a footnote.
      function tab:text(text, muted)
        local row = CreateFrame("Frame", nil, self.content)
        row.text = row:CreateFontString(nil, "OVERLAY", muted and "GameFontDisableSmall" or "GameFontHighlightSmall")
        row.text:SetPoint("TOPLEFT", 0, 0)
        row.text:SetWidth(LAYOUT.label + LAYOUT.control + 40)
        row.text:SetJustifyH("LEFT")
        row.text:SetWordWrap(true)
        row.text:SetText(text)
        local h = row.text:GetStringHeight()
        h = math.max(14, type(h) == "number" and math.ceil(h) or 14)
        row:SetHeight(h)
        return self:place(row, h + 8)
      end
      function tab:finish() self.column:Fit(self.y + 12) end
      tabs[#tabs + 1] = tab
      return tab
    end

    -- Tooltip: what the item tooltip shows.
    local tooltipTab = addTab("Tooltip")
    tooltipTab:header("IN THE ITEM'S TOOLTIP")
    tooltipTab:check("compare", "Show what the item changes against the equipped one",
      { tooltip = "The differences against the item you wear in that slot, in the item's tooltip." })
    tooltipTab:check("worth", "Under each stat, what it gives you",
      { tooltip = "Health, mana, armor, attack power, crit, hit and the rest, under each difference. "
        .. "The Help tab has the icons." })
    tooltipTab:check("specs", "How each spec of your class rates the item",
      { tooltip = "The Help tab explains the numbers." })
    tooltipTab:check("icons", "Icons instead of words",
      { tooltip = "Icons and one line each, instead of words." })
    tooltipTab:check("caps", "Count hit and expertise only up to their caps",
      { tooltip = "Spell hit counts up to 17%, melee and ranged hit up to 8% (a dual wielder's melee hit is not "
        .. "capped here), expertise up to 6.5%: above that a point is worth nothing, so an item whose hit you "
        .. "no longer need is not rated for it. Uses your current hit and expertise as the character sheet "
        .. "shows them. Off: every point counts in full." })
    tooltipTab:check("effects", "Count effects and set bonuses in the ratings",
      { tooltip = "A trinket is mostly its use effect, a set piece its set's bonus: the ratings, the arrows and the "
        .. "quest reward marks count them (an effect that is up part of the time counts for that part). Damage, "
        .. "healing and stacking effects are not stats; such an item says it has one that is not rated." })
    tooltipTab:check("consumables", "Rate elixirs, flasks, food, potions and scrolls",
      { tooltip = "Under a consumable that gives stats, what its buff is worth to each spec, as a share of what "
        .. "your gear is worth." })
    tooltipTab:check("tankCaps", "Tank lines: uncrittable and avoidance",
      { tooltip = "Under a tank's gear: how far the defense skill is from uncrittable (a boss three levels above "
        .. "you) and where avoidance stands against its cap. Off: both lines are left out and the tank ratings "
        .. "stay. They show only while a tank spec is rated (Specs to rate)." })
    tooltipTab:header("SPECS TO RATE")
    tooltipTab:choice("specFilter", "Specs to rate", {
      { id = "all", label = "All specs of the class" },
      { id = "auto", label = "Automatic: my talent spec" },
      { id = "manual", label = "Manual: pick the roles" },
    }, { tooltip = "Which specs the tooltip rates, the arrows on bags, loot and quest rewards count, and the "
        .. "spec icon names. Automatic follows the talent tree you have your points in (all specs if the game "
        .. "does not say). Manual uses the boxes below." })
    local manualSpecs = function(s) return s.specFilter == "manual" end
    tooltipTab:check("specDamage", "Damage specs",
      { enabledIf = manualSpecs, tooltip = "Rate the damage specs of your class. Needs Manual." })
    tooltipTab:check("specTank", "Tank specs",
      { enabledIf = manualSpecs, tooltip = "Rate the tank specs, and show the tank caps lines (uncrittable, "
        .. "avoidance). Needs Manual." })
    tooltipTab:check("specHealing", "Healer specs",
      { enabledIf = manualSpecs, tooltip = "Rate the healer specs (an approximate score). Needs Manual." })
    -- One box per spec of the player's class: the roles above cannot tell a hunter's three damage specs apart.
    local pickClass = charClass()
    local pickSpecs = pickClass and M.SPECS and M.SPECS[pickClass]
    if pickSpecs and #pickSpecs > 1 then
      tooltipTab:text(BIT.L("Or pick single specs of your class (a spec you turn off here is not rated, "
        .. "whatever its role says). Needs Manual."), true)
      for _, spec in ipairs(pickSpecs) do
        local key = "spec:" .. tostring(spec.name)
        tooltipTab.keys[#tooltipTab.keys + 1] = key
        tooltipTab:place(Rows.Check(tooltipTab.content, spec.name,
          function() return (settings or DEFAULTS)[key] ~= false end,
          function(v) apply(key, v) end,
          rowOpts({ enabledIf = manualSpecs,
            tooltip = "Rate this spec. Off: its lines, arrows and quest marks are left out. Needs Manual." })))
      end
    end
    tooltipTab:header("HOW MUCH OF IT")
    tooltipTab.keys[#tooltipTab.keys + 1] = "detail"
    tooltipTab:place(Rows.Check(tooltipTab.content, "Always show the full tooltip",
      function() return (settings or DEFAULTS).detail == "full" end,
      function(v) apply("detail", v and "full" or "compact") end,
      rowOpts({ tooltip = "Off: one line, the best spec and its arrow. Hold Shift for the full breakdown." })))
    tooltipTab:text(BIT.L("Hold Shift for the full breakdown."), true)

    -- Arrows: where the upgrade arrows show, and where on the item they sit.
    local arrowsOn = function(s) return s.bagMarkers or s.worldMarkers end
    local arrows = addTab("Arrows")
    arrows:header("WHERE THE ARROWS SHOW")
    arrows:check("bagMarkers", "Arrows on bag items",
      { tooltip = "Green up for an upgrade, red down only when every path is worse. The Help tab explains them." })
    arrows:check("bagSpecIcons", "The beneficiary spec icon on an up arrow",
      { enabledIf = function(s) return s.bagMarkers end,
        tooltip = "+N for the rest of the specs it is an upgrade for, ~ for the approximate healer score. "
          .. "Needs the arrows on." })
    arrows:check("questMarkers", "Quest reward arrows",
      { tooltip = "A green up arrow on every usable upgrade. The reward with the highest positive "
        .. "'% better' rating shown in its tooltip gets a second arrow. If nothing is an "
        .. "upgrade, a coin marks the choice with the highest vendor price." })
    arrows:check("worldMarkers", "Arrows on loot, rolls and merchants",
      { tooltip = "The same bag verdict on loot slots, need/greed rolls and merchant buttons." })
    arrows:header("WHERE ON THE ITEM")
    arrows:choice("bagArrowCorner", "Corner", {
      { id = "topright", label = "Top right" },
      { id = "topleft", label = "Top left" },
      { id = "bottomright", label = "Bottom right" },
      { id = "bottomleft", label = "Bottom left" },
    }, { enabledIf = arrowsOn,
      tooltip = "The corner of the item the arrow and the spec icon sit in, for when another addon's mark "
        .. "(a junk coin, an item level) already uses one. Baganator places its corner marks itself: pick the "
        .. "same corner in its Icon Corners settings. Quest reward arrows keep their own place." })
    arrows:slider("bagArrowX", "Horizontal nudge", -20, 20, 1,
      { enabledIf = arrowsOn, suffix = " px", tooltip = "Pixels right (+) or left (-) of the corner." })
    arrows:slider("bagArrowY", "Vertical nudge", -20, 20, 1,
      { enabledIf = arrowsOn, suffix = " px", tooltip = "Pixels up (+) or down (-) from the corner." })
    arrows:slider("bagArrowScale", "Arrow size", 50, 150, 5,
      { enabledIf = arrowsOn, suffix = "%", tooltip = "The size of the arrow, the spec icon and the +N cue." })
    arrows:check("bagNativeUp", "Use the game's own upgrade arrow in Blizzard's bags",
      { enabledIf = function(s) return s.bagMarkers end,
        tooltip = "Blizzard's bag buttons have an upgrade arrow of their own, in a place the game chose. "
          .. "Checked: an upgrade lights that one. Unchecked: this addon's arrow is drawn instead, in the "
          .. "corner chosen above. Other bag addons always get this addon's arrow." })

    -- Help: the legend, how the ratings come about, when an arrow shows, and the probe.
    local help = addTab("Help")
    help:header("WHAT THE ICONS STAND FOR")
    local words = {}
    for _, kind in ipairs({ "armor", "ap", "crit", "hit", "haste", "expertise", "dodge", "parry", "block", "blockvalue", "defense",
      "health", "mana", "spellcrit", "regen", "hpregen", "healing", "spellpower" }) do
      words[#words + 1] = icon(ICONS[kind], 12) .. " " .. BIT.L(WORTH_WORDS[kind])
    end
    help:text(table.concat(words, "    "))
    help:text(BIT.L("Under each difference: what the stats give this character -- the game's own numbers, "
      .. "worked out as its character sheet works them out. Green is up, red is down."))
    help:text(BIT.L("Armor is 2 per Agility and mana regeneration a quarter of Spirit, as measured on Forever. "
      .. "Health regeneration from Spirit is the character sheet's own number (standing, out of combat), taken "
      .. "per point of Spirit: it assumes the two are proportional. "
      .. "In combat the game may hide these numbers; then the line is left out."))
    help:header("HIT AND EXPERTISE CAPS")
    help:text(BIT.L("Hit and expertise stop mattering at a cap: spell hit at 17%, melee and ranged hit at 8%, expertise "
      .. "at 6.5% (the simulator's own caps for each spec). The ratings count them only up to the cap, from the hit and "
      .. "expertise your character has now, so an item whose hit you no longer need is not rated for it, and one "
      .. "that takes you across the cap is rated for the part below it."))
    help:header("EFFECTS, SETS AND CONSUMABLES")
    help:text(BIT.L("Beside its stats, an item can have an effect (a trinket's use, a weapon's proc) and a set bonus. "
      .. "Those that give stats are counted at the share of the time they are up: 280 attack power for 20 s every "
      .. "120 s counts as 17% of it. A proc by chance per hit is an estimate (one eligible hit every two seconds)."))
    help:text(BIT.L("Damage, healing and absorb effects and stacking effects are not stats and are not rated: the "
      .. "tooltip says so. Under an elixir, flask, food, potion or scroll with stats the lines are what its buff is "
      .. "worth, as a share of what your gear is worth."), true)
    help:header("HOW EACH SPEC RATES THE ITEM")
    help:text(BIT.L("Each spec of your class rates the item against what you wear: \"25% better dmg spec\" "
      .. "means its stats are worth a quarter more to that spec."))
    help:text(BIT.L("Specs to rate (Tooltip tab) narrows this to the specs you play: Automatic follows your talent "
      .. "tree, Manual lets you tick damage, tank and healer, or single specs. It also decides the arrows and the spec icon."))
    help:text(BIT.L("A tank has two numbers: for survival (less damage taken) and for threat gen. (holding aggro)."))
    help:text(BIT.L("With nothing worth comparing, or a change past the cap: \">300% ...\", at most triple."))
    help:text(BIT.L("Each healer spec (druid Restoration, priest Holy, paladin Holy, shaman Restoration) is "
      .. "rated by one shared healer model, and its line is marked \"(approx.)\": "
      .. "an approximate item score, not a measured healing gain."))
    help:text(BIT.L("Its weights are the simulator repo's EP presets for a Holy priest, the mean of raid and "
      .. "single-target healing (tools/data/healer_weights.json): 1 x +Healing, 1 x Spell Power, 0.325 x Intellect, "
      .. "0.275 x Spirit, 0.6 x MP5, 0.265 x Crit and 0.49 x Haste. Every other stat counts for nothing to it."))
    help:text(BIT.L("The other ratings use ForeverSim's stat weights, measured on a level 60 build of each spec "
      .. "with its own talents, gear and buffs: below 60 they are an estimate."), true)
    help:text(BIT.L("A weapon's damage per second counts as the simulator weighs it for the spec: main hand, "
      .. "off hand and ranged slot apart."), true)
    help:text(BIT.L("Not counted: what a hunter's pet gets from your stats, weapon skill, and Spirit for the "
      .. "specs the simulator does not weigh it for."), true)
    help:header("ARROWS ON BAG ITEMS")
    help:text(BIT.L("On the game's own bags and the Baganator bag grid: green up when at least one spec's score "
      .. "is outright better and none of it worse."))
    help:text(BIT.L("Red down only when every replacement path is strictly worse for every spec. "
      .. "Mixed, equal or unknown: no arrow."))
    help:text(BIT.L("Always against what you wear in that slot, never a BiS verdict."))
    help:text(BIT.L("Stats the simulator does not model are compared conservatively by the raw differences, "
      .. "with no spec icon; the healer's approximate score gets a ~ icon."))
    help:text(BIT.L("While the client hides stats (in combat) or the item's data has not arrived, no arrow is shown."))
    -- The probe row: what /upt probe records.
    help:header("DIAGNOSTICS")
    local probeRow = CreateFrame("Frame", nil, help.content)
    probeRow:SetHeight(24)
    local count -- declared before the button so its OnClick sees the local
    local function showCount()
      local global = type(BIT.GlobalDB) == "function" and BIT.GlobalDB() or BIT.DB()
      local probes = global.probes
      count:SetText(string.format(BIT.L("%d recorded so far"), type(probes) == "table" and #probes or 0))
    end
    local probeButton = UI.Button(probeRow, BIT.L("Record the probe"), 170, function()
      M.Probe()
      showCount() -- the counter refreshes on the click, not only when the tab is shown
    end)
    probeButton:SetPoint("LEFT", 0, 0)
    count = probeRow:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    count:SetPoint("LEFT", probeButton, "RIGHT", 10, 0)
    help:place(probeRow, 30)

    for _, tab in ipairs(tabs) do tab:finish() end

    -- "Reset this tab": the open tab's own settings back to their defaults; the appearance is not touched.
    resetButton = BIT.Looks.ResetButton(area, function()
      if not active then return end
      for _, key in ipairs(active.keys) do apply(key, DEFAULTS[key], true) end
      if type(M.RefreshBags) == "function" then M.RefreshBags(true) end
      refreshControls()
      renderPreview()
    end)
    resetButton:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT", -10, 10)

    selectTab(tabs[1])
    parent:SetScript("OnShow", function()
      -- re-asserted here too: whatever re-showed a content in between, one tab at a time
      selectTab(active or tabs[1])
      showCount()
      refreshControls()
      renderPreview()
    end)
    -- drawn once here too: the preview is already there the moment the tab is built
    showCount()
    refreshControls()
    renderPreview()
  end,
})
BIT.tabWords.stats = "StatsInfo"
