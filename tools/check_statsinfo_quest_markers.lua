local textureAvailable = true
local function widget()
  local w = { shown = false }
  function w:CreateTexture()
    local t = { shown = false }
    function t:SetTexture(value)
      if textureAvailable then self.texture = value end
    end
    function t:GetTexture() return self.texture end
    function t:SetTexCoord(...) self.texCoord = { ... } end
    function t:SetVertexColor(...) self.vertexColor = { ... } end
    function t:SetSize(width, height) self.width, self.height = width, height end
    function t:ClearAllPoints() end
    function t:SetPoint(...) end
    function t:SetDrawLayer(...) end
    function t:SetParent(...) end
    function t:Show() self.shown = true end
    function t:Hide() self.shown = false end
    return t
  end
  function w:RegisterEvent() end
  function w:UnregisterEvent() end
  function w:UnregisterAllEvents() end
  function w:SetScript() end
  return w
end

local ns = {}
local BIT = {
  name = "Test",
  Module = function() return ns end,
  IsRunning = function() return true end,
  IsSwitchedOn = function() return true end,
}
CreateFrame = function() return widget() end
issecretvalue = function() return false end
C_Timer = { After = function() end }
local rewards = {
  { link = "item:101", percent = 34, price = 100, upgrade = true },
  { link = "item:102", percent = 86, price = 500, upgrade = true },
  { link = "item:103", percent = 10, price = 1000, upgrade = false },
}
GetNumQuestChoices = function() return #rewards end
GetNumQuestRewards = function() return 0 end
GetQuestItemInfo = function(_, index)
  local reward = rewards[index]
  return "Reward " .. index, nil, 1, 1, true, index, reward.link
end
QuestInfoFrame = { rewardsFrame = {} }
local buttons = {}
QuestInfo_GetRewardButton = function(_, index)
  buttons[index] = buttons[index] or widget()
  return buttons[index]
end
ns.settings = { questMarkers = true }
ns.CanEquipItem = function() return true end
ns.BagVerdictState = function(link)
  for _, reward in ipairs(rewards) do
    if reward.link == link then
      return "ok", { verdict = reward.upgrade and "up" or "down" }
    end
  end
end
ns.BestUpgradePercent = function(link)
  for _, reward in ipairs(rewards) do
    if reward.link == link then return reward.percent end
  end
end
C_Item = { GetItemInfo = function(link)
  for _, reward in ipairs(rewards) do
    if reward.link == link then return nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, reward.price end
  end
end }

assert(loadfile("Modules/StatsInfo/QuestMarkers.lua"))("UsefulPlatesAndTooltips", BIT)
local selected, best = ns._selectUpgradeRewards({
  { upgrade = true, bestPercent = 34 },
  { upgrade = true, bestPercent = 86 },
  { upgrade = false, bestPercent = 200 },
})
assert(#selected == 2 and best == selected[2], "all upgrades must be listed; highest positive rating wins")
local none, noBest = ns._selectUpgradeRewards({ { upgrade = false, bestPercent = 500 } })
assert(#none == 0 and noBest == nil, "no upgrades must not select a best reward")

ns.EnableQuestMarkers()
ns.UpdateQuestRewards()
local overlays = ns._questOverlays
assert(overlays[1].arrow.shown and not overlays[1].bestArrow.shown,
  "the lower-rated upgrade must show one arrow")
assert(overlays[2].arrow.shown and overlays[2].bestArrow.shown,
  "the highest-rated upgrade must show the overlapping second arrow")
assert(not overlays[3], "a non-upgrade must not get an arrow")

rewards[1].percent = 95
ns.UpdateQuestRewards()
assert(overlays[1].bestArrow.shown and not overlays[2].bestArrow.shown,
  "the double arrow must move when the best rating changes")

for _, reward in ipairs(rewards) do reward.upgrade = false end
ns.UpdateQuestRewards()
assert(overlays[1].mode == nil and overlays[2].mode == nil and overlays[3].mode == "coin",
  "when no item upgrades, only the most valuable choice gets the fallback coin")

for _, reward in ipairs(rewards) do reward.upgrade = true end
rewards[1].percent = 34
textureAvailable = false
assert(loadfile("Modules/StatsInfo/QuestMarkers.lua"))("UsefulPlatesAndTooltips", BIT)
ns.EnableQuestMarkers()
ns.UpdateQuestRewards()
overlays = ns._questOverlays
assert(#overlays[1].pieces == 4 and overlays[1].pieces[1].shown,
  "the primitive fallback must keep the single-arrow upgrade visible")
assert(#overlays[2].pieces == 4 and #overlays[2].bestPieces == 4
    and overlays[2].pieces[1].shown and overlays[2].bestPieces[1].shown,
  "the primitive fallback must show both arrows on the best upgrade")

print("StatsInfo quest-reward selection, marker visibility and refresh checks passed.")
