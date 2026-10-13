-- UPT_HoverProbe: which addon does what while an item tooltip is up.
-- /hp starts a 10 second capture. After it prints a summary, /reload saves
-- UPT_HoverProbeDB with per-second buckets, per-addon counts, per-tooltip counts and
-- raw traceback samples. Temporary diagnostic build: remove the folder afterwards.
local ADDON = ...

local f = CreateFrame("Frame")
local capturing, endsAt, nextBucket = false, 0, 0
local buckets = {}
local lineBy, setBy, clearBy = {}, {}, {}
local addByTooltip, clearByTooltip = {}, {}
local counters = { addline = 0, setitem = 0, clear = 0, cleared = 0, itemstats = 0, hyperlink = 0, iteminfo = 0 }
local minFps, wrapped = nil, false
local samples = { addline = {}, setitem = {}, clear = {}, itemstats = {} }

local function firstForeignFrame(start)
  local ok, s = pcall(debugstack, start or 2, 16, 1)
  if not ok or type(s) ~= "string" then return "?", nil end
  for line in s:gmatch("[^\n]+") do
    if not line:find("UPT_HoverProbe", 1, true) then
      local addon = line:match("AddOns\\([^\\]+)\\") or line:match("AddOns/([^/]+)/")
      if addon then return addon, s end
      if line:find("Blizzard", 1, true) then return "Blizzard", s end
    end
  end
  return "?", s
end

local function nameOf(self)
  if type(self) ~= "table" or type(self.GetName) ~= "function" then return "?" end
  local ok, n = pcall(self.GetName, self)
  return ok and type(n) == "string" and n or "?"
end

local function tally(tbl, key)
  tbl[key] = (tbl[key] or 0) + 1
end

local function wrap(object, name, kind)
  if type(object) ~= "table" or type(object[name]) ~= "function" then return end
  local orig = object[name]
  object[name] = function(self, ...)
    if capturing then
      counters[kind] = (counters[kind] or 0) + 1
      local addon, stack = firstForeignFrame(2)
      local tooltip = nameOf(self)
      if kind == "addline" then tally(lineBy, addon) tally(addByTooltip, tooltip)
      elseif kind == "setitem" then tally(setBy, addon)
      elseif kind == "clear" then tally(clearBy, addon) tally(clearByTooltip, tooltip) end
      local list = samples[kind]
      if list and #list < 8 then
        local arg1 = ...
        list[#list + 1] = {
          at = date("%H:%M:%S"),
          by = addon,
          tooltip = tooltip,
          arg = type(arg1) == "string" and arg1:sub(1, 80) or type(arg1),
          stack = stack and stack:sub(1, 1000) or nil,
        }
      end
    end
    return orig(self, ...)
  end
end

local function setup()
  if wrapped then return end
  wrapped = true
  local names = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "ShoppingTooltip3" }
  for _, global in ipairs(names) do
    local tooltip = _G[global]
    if type(tooltip) == "table" then
      for _, method in ipairs({ "AddLine", "AddDoubleLine" }) do wrap(tooltip, method, "addline") end
      for _, method in ipairs({ "SetItem", "SetBagItem", "SetInventoryItem", "SetInventoryItemByID",
          "SetHyperlink", "SetAction", "SetAuctionItem", "SetAuctionSellItem", "SetMerchantItem",
          "SetLootItem", "SetLootRollItem", "SetQuestItem", "SetQuestLogItem", "SetTradeSkillItem",
          "SetCraftItem", "SetCraftSpell" }) do
        wrap(tooltip, method, "setitem")
      end
      wrap(tooltip, "ClearLines", "clear")
    end
  end
  if type(GameTooltip) == "table" and type(GameTooltip.HookScript) == "function" then
    pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipCleared", function()
      if capturing then counters.cleared = counters.cleared + 1 end
    end)
  end
  if type(C_Item) == "table" and type(C_Item.GetItemStats) == "function" then
    local orig = C_Item.GetItemStats
    C_Item.GetItemStats = function(...)
      if capturing then
        counters.itemstats = counters.itemstats + 1
        if #samples.itemstats < 8 then
          local addon, stack = firstForeignFrame(2)
          samples.itemstats[#samples.itemstats + 1] = { by = addon, stack = stack and stack:sub(1, 1000) }
        end
      end
      return orig(...)
    end
  end
  for _, api in ipairs({ { C_Item, "GetItemInfo" }, { _G, "GetItemInfo" } }) do
    local holder, method = api[1], api[2]
    if type(holder) == "table" and type(holder[method]) == "function" then
      local orig = holder[method]
      holder[method] = function(...)
        if capturing then counters.iteminfo = counters.iteminfo + 1 end
        return orig(...)
      end
    end
  end
  if type(C_TooltipInfo) == "table" and type(C_TooltipInfo.GetHyperlink) == "function" then
    local orig = C_TooltipInfo.GetHyperlink
    C_TooltipInfo.GetHyperlink = function(...)
      if capturing then counters.hyperlink = counters.hyperlink + 1 end
      return orig(...)
    end
  end
end

local function topList(tbl, n)
  local out = {}
  for key, count in pairs(tbl) do out[#out + 1] = { key, count } end
  table.sort(out, function(a, b) return a[2] > b[2] end)
  local text = {}
  for i = 1, math.min(#out, n or 10) do text[#text + 1] = out[i][1] .. " x" .. out[i][2] end
  return table.concat(text, ", ")
end

local function finish()
  capturing = false
  UPT_HoverProbeDB = {
    at = date("%Y-%m-%d %H:%M:%S"),
    seconds = #buckets,
    minFps = minFps,
    buckets = buckets,
    linesBy = lineBy,
    setsBy = setBy,
    clearsBy = clearBy,
    addByTooltip = addByTooltip,
    clearByTooltip = clearByTooltip,
    samples = samples,
  }
  print("|cff66bbffHoverProbe|r done: min fps " .. tostring(minFps and math.floor(minFps)))
  print("|cff66bbffHoverProbe|r lines: " .. topList(lineBy, 8))
  print("|cff66bbffHoverProbe|r lines per tooltip: " .. topList(addByTooltip, 5))
  print("|cff66bbffHoverProbe|r clears: " .. topList(clearBy, 5) .. " | per tooltip: " .. topList(clearByTooltip, 5))
  print("|cff66bbffHoverProbe|r now /reload so the agent can read UPT_HoverProbeDB.")
end

f:SetScript("OnUpdate", function()
  if not capturing then return end
  local fps = type(GetFramerate) == "function" and GetFramerate() or nil
  if type(fps) == "number" and (not minFps or fps < minFps) then minFps = fps end
  local now = GetTime()
  if now < nextBucket then return end
  nextBucket = now + 1
  buckets[#buckets + 1] = {
    fps = fps,
    addline = counters.addline,
    setitem = counters.setitem,
    clear = counters.clear,
    cleared = counters.cleared,
    itemstats = counters.itemstats,
    iteminfo = counters.iteminfo,
    hyperlink = counters.hyperlink,
  }
  for k in pairs(counters) do counters[k] = 0 end
  if now >= endsAt then finish() end
end)

SLASH_UPT_HOVERPROBE1 = "/hp"
SlashCmdList.UPT_HOVERPROBE = function()
  setup()
  capturing = true
  buckets, lineBy, setBy, clearBy = {}, {}, {}, {}
  addByTooltip, clearByTooltip = {}, {}
  samples = { addline = {}, setitem = {}, clear = {}, itemstats = {} }
  for k in pairs(counters) do counters[k] = 0 end
  minFps = nil
  endsAt = GetTime() + 10
  nextBucket = GetTime() + 1
  print("|cff66bbffHoverProbe|r capturing 10 s -- hover items now (keep the tooltip up).")
end

f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, _, name)
  if name == ADDON then
    setup()
    print("|cff66bbffHoverProbe|r ready. Hover items and type /hp; after the summary, /reload to save.")
  end
end)
