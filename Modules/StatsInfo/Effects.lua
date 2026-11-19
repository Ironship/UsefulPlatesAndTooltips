-- UsefulPlatesAndTooltips module StatsInfo: what an item's effects, its set and a consumable give.
-- Copyright (c) 2026 Ironship. GPL-3.0-or-later, see LICENSE.
--
-- The data is EffectData.lua (tools/make_effects.py). An item's value is not only its static stats: a trinket
-- is its use effect, a set piece its set's bonus. Here they become stats of the same kind the weights price,
-- so the ratings (tooltip, bag arrows, quest rewards) count them:
--   equip effect  the stats as they are;
--   use effect    the stats times the share of the time it is up (duration over cooldown);
--   proc          the stats times the share of the time it is up (per minute, or a chance per hit: an estimate);
--   percentages   (crit, hit, haste, dodge, parry, block) become the rating the character's level needs for that
--                 percentage, which is what the weights are in.
-- Set bonuses are counted by StatsInfo.lua, which knows what is worn; the bonus of the pieces worn is read here.
-- Damage, healing and absorb effects and stacking effects are not stats: such an item says so in its tooltip.

local _, BIT = ...
local M = BIT.Module("StatsInfo")

local EMPTY = {}

local function isSecret(v)
  if type(issecretvalue) ~= "function" then return false end
  local ok, secret = pcall(issecretvalue, v)
  return ok and secret or false
end

local function ask(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a = pcall(fn, ...)
  if not ok then return nil end
  return a
end

local function num(v) return type(v) == "number" and not isSecret(v) and v == v and v or nil end

-- The item number of a link, or nil. A rating build asks for the same few links over and over, so the
-- answers are kept (bounded: the memo starts over when it is full).
local idMemo, idCount = {}, 0
local ID_MEMO_MAX = 512
function M.ItemIDOf(link)
  if type(link) ~= "string" or isSecret(link) then return nil end
  local hit = idMemo[link]
  if hit ~= nil then return hit or nil end
  local id = link:match("item:(%d+)")
  id = id and tonumber(id) or false
  if idCount >= ID_MEMO_MAX then
    for k in pairs(idMemo) do idMemo[k] = nil end
    idCount = 0
  end
  idMemo[link] = id
  idCount = idCount + 1
  return id or nil
end
local idOf = M.ItemIDOf

local function effectsOn()
  local s = M.settings
  return not (s and s.effects == false)
end

-- The percentages an effect gives, and the rating and index (a global of the character sheet, with its number on
-- Forever as a fallback) that turns one into the other.
local PCT = {
  crit = { key = "ITEM_MOD_CRIT_RATING_SHORT", name = "CR_CRIT_MELEE", index = 9 },
  hit = { key = "ITEM_MOD_HIT_RATING_SHORT", name = "CR_HIT_MELEE", index = 6 },
  haste = { key = "ITEM_MOD_HASTE_RATING_SHORT", name = "CR_HASTE_MELEE", index = 18 },
  dodge = { key = "ITEM_MOD_DODGE_RATING_SHORT", name = "CR_DODGE", index = 3 },
  parry = { key = "ITEM_MOD_PARRY_RATING_SHORT", name = "CR_PARRY", index = 4 },
  block = { key = "ITEM_MOD_BLOCK_RATING_SHORT", name = "CR_BLOCK", index = 5 },
  expertise = { key = "ITEM_MOD_EXPERTISE_RATING_SHORT", name = "CR_EXPERTISE", index = 24 },
}

-- The percentage one point of a rating gives at this level (the game's own conversion), or nil. It moves only
-- with the level, so an answer is kept for a few seconds: a bag refresh rates a hundred items.
local PER_TTL = 5
local perMemo = {}
local function perRating(kind)
  local info = PCT[kind]
  if not info then return nil end
  local t = ask(GetTime)
  local hit = perMemo[kind]
  if hit and type(t) == "number" and t >= hit.t and (t - hit.t) <= PER_TTL then return hit.v end
  local index = type(_G[info.name]) == "number" and _G[info.name] or info.index
  local v = num(ask(GetCombatRatingBonusForCombatRatingValue, index, 1))
  if v and v > 0 then
    if type(t) == "number" then perMemo[kind] = { t = t, v = v } end
    return v
  end
  return nil
end

-- The percentage one point of a rating gives at this level, or nil ("hit", "expertise", "crit", ...).
function M.PercentPerRating(kind) return perRating(kind) end

-- What the character has now of a capped stat, in percent, worked out as the game's character sheet does
-- (Blizzard_UIPanels_Game/Camelot/PaperDollFrameStats.lua): the rating's percentage plus the modifier talents
-- and auras give; expertise is GetExpertise(), which Forever's own sheet names expertisePct. kind: "melee",
-- "ranged", "spell" (hit) or "expertise". These functions answer with secret values when the client restricts
-- unit stats (C_Secrets.ShouldUnitStatsBeSecret, in a fight): the last readable answer is kept and used then
-- (gear rarely changes in a fight), so the ratings do not change their mind in combat. nil when the client has
-- never answered: nothing is capped.
local CAP_READ = {
  melee = { "CR_HIT_MELEE", 6, "GetHitModifier" },
  ranged = { "CR_HIT_RANGED", 7, "GetRangedHitModifier" },
  spell = { "CR_HIT_SPELL", 8, "GetSpellHitModifier" },
}
local lastCap, capTime = {}, {}
local CAP_TTL = 1
-- Forgets the readings (a new character, a test).
function M.CapForget()
  for k in pairs(lastCap) do lastCap[k] = nil end
  for k in pairs(capTime) do capTime[k] = nil end
  for k in pairs(perMemo) do perMemo[k] = nil end
end
-- Makes the next read ask the client again (the gear, an aura or the level changed); the last answer stays
-- as the fallback.
function M.CapExpire()
  for k in pairs(capTime) do capTime[k] = nil end
end
function M.CapCurrent(kind)
  -- a rating build asks for the same numbers dozens of times: one answer a second (and after a gear change)
  local t = ask(GetTime)
  local at = capTime[kind]
  if at and type(t) == "number" and t >= at and (t - at) <= CAP_TTL and lastCap[kind] then return lastCap[kind] end
  local now
  if kind == "expertise" then
    now = num(ask(GetExpertise))
  else
    local read = CAP_READ[kind]
    if not read then return nil end
    local index = type(_G[read[1]]) == "number" and _G[read[1]] or read[2]
    local rating = num(ask(GetCombatRatingBonus, index))
    local modifier = num(ask(_G[read[3]]))
    if rating and modifier then now = rating + modifier end
  end
  if now then
    lastCap[kind] = now
    if type(t) == "number" then capTime[kind] = t end
  end
  return now or lastCap[kind]
end

-- Adds an entry { stats, pct } times factor to out (key -> amount).
local function addTo(out, stats, pct, factor)
  for key, v in pairs(stats or EMPTY) do out[key] = (out[key] or 0) + v * factor end
  for kind, p in pairs(pct or EMPTY) do
    local per = perRating(kind)
    if per then
      local key = PCT[kind].key
      out[key] = (out[key] or 0) + (p / per) * factor
    end
  end
end

-- A table of stats and percentages as one table of the stats the weights price (percentages become rating).
function M.ExpandStats(stats, pct)
  local out = {}
  addTo(out, stats, pct, 1)
  return out
end

-- The stats an item's effects give on average, key -> amount; a shared empty table when it has none.
function M.EffectStats(link)
  if not effectsOn() then return EMPTY end
  local id = idOf(link)
  local list = id and M.EFFECT_ITEMS and M.EFFECT_ITEMS[id]
  if not list then return EMPTY end
  local out = {}
  for _, e in ipairs(list) do addTo(out, e.stats, e.pct, e.f) end
  return out
end

-- The set an item belongs to (one whose bonus is counted), or nil.
function M.SetOf(link)
  if not effectsOn() then return nil end
  local id = idOf(link)
  return id and M.ITEM_SETS and M.ITEM_SETS[id] or nil
end

-- What the bonuses of a set give with count pieces worn, key -> amount, or nil.
function M.SetBonusStats(setId, count)
  local rows = M.SETS and M.SETS[setId]
  if not rows or not count or count <= 0 then return nil end
  local out
  for _, row in ipairs(rows) do
    if row[1] <= count then
      out = out or {}
      addTo(out, row[2], row[3], 1)
    end
  end
  return out
end

-- The pieces of each counted set that equipped(slot) names, { [setId] = pieces }.
local WORN_SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }
function M.SetCounts(equipped)
  local counts = {}
  if not M.ITEM_SETS then return counts end
  for _, slot in ipairs(WORN_SLOTS) do
    local link = equipped(slot)
    local set = link and M.SetOf(link)
    if set then counts[set] = (counts[set] or 0) + 1 end
  end
  return counts
end

M.WORN_SLOTS = WORN_SLOTS

-- Words ------------------------------------------------------------------------------------------------------

local function statName(key)
  local name = _G[key]
  if type(name) == "string" and name ~= "" then return name end
  return key
end

local function amountText(v)
  local r = math.floor(math.abs(v) + 0.5)
  return (v < 0 and "-" or "+") .. r
end

-- "+280 Attack Power, +5% haste": up to three of an entry's stats, in the client's words.
local function statsText(entry)
  local keys = {}
  for k in pairs(entry.stats or EMPTY) do keys[#keys + 1] = k end
  table.sort(keys)
  local parts = {}
  for _, k in ipairs(keys) do
    if #parts < 3 then parts[#parts + 1] = amountText(entry.stats[k]) .. " " .. statName(k) end
  end
  local kinds = {}
  for k in pairs(entry.pct or EMPTY) do kinds[#kinds + 1] = k end
  table.sort(kinds)
  for _, k in ipairs(kinds) do
    if #parts < 3 then parts[#parts + 1] = string.format("+%d%% %s", entry.pct[k], BIT.L(k)) end
  end
  return table.concat(parts, ", ")
end
M.StatsText = statsText

-- A length of time: "2 hr", "30 min", "20 sec".
function M.DurationText(seconds)
  if type(seconds) ~= "number" or seconds <= 0 then return nil end
  if seconds >= 3600 then return string.format(BIT.L("%d hr"), math.floor(seconds / 3600 + 0.5)) end
  if seconds >= 60 then return string.format(BIT.L("%d min"), math.floor(seconds / 60 + 0.5)) end
  return string.format(BIT.L("%d sec"), math.floor(seconds + 0.5))
end

-- The lines under an item's ratings that say what was counted: its effects and its set; and, when an effect is
-- no stat (damage, healing, a stack), that it is not rated. { text, ... } or an empty table.
function M.EffectNotes(link, setCounts)
  local notes = {}
  if not effectsOn() then return notes end
  local id = idOf(link)
  if not id then return notes end
  for _, e in ipairs((M.EFFECT_ITEMS and M.EFFECT_ITEMS[id]) or EMPTY) do
    local what = statsText(e)
    local share = math.floor(e.f * 100 + 0.5)
    if e.kind == "use" then
      notes[#notes + 1] = string.format(BIT.L("Use: %s for %s every %s, counted at %d%%"), what,
        M.DurationText(e.dur) or "?", M.DurationText(e.cd) or "?", share)
    elseif e.kind == "proc" then
      notes[#notes + 1] = string.format(e.approx and BIT.L("Proc: %s for %s, counted at about %d%%")
        or BIT.L("Proc: %s for %s, counted at %d%%"), what, M.DurationText(e.dur) or "?", share)
    else
      notes[#notes + 1] = string.format(BIT.L("Effect counted: %s"), what)
    end
  end
  local set = M.ITEM_SETS and M.ITEM_SETS[id]
  if set and setCounts then
    notes[#notes + 1] = string.format(BIT.L("Set bonuses are counted: %d pieces worn"), setCounts[set] or 0)
  end
  if M.EFFECT_UNRATED and M.EFFECT_UNRATED[id] then
    notes[#notes + 1] = BIT.L("Another effect of this item is not rated")
  elseif set and M.SETS_UNRATED and M.SETS_UNRATED[set] then
    notes[#notes + 1] = BIT.L("Another effect of this set is not rated")
  end
  return notes
end
