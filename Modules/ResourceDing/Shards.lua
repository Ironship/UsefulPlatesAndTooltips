-- UsefulPlatesAndTooltips module ResourceDing: adapted from ResourceDing/Shards.lua at 540b462.
-- Maintained directly in this module.
-- Classic/Forever Soul Shards are bag items; Retail Soul Shards are player power.
--
-- One sound when the readable whole-shard count rises, and purple diamonds
-- under the target's nameplate. Loading, spending shards and switching targets
-- stay quiet. An unreadable Retail count clears the baseline and hides the row.

local _, BIT = ...
-- Inside UsefulPlatesAndTooltips its own namespace; loaded on its own, the addon's table as before.
local Addon = BIT.Module and BIT.Module("ResourceDing") or BIT

local SOUL_SHARD = 6265
local WHITE = "Interface\\Buttons\\WHITE8X8"
local TEX_DIR = "Interface\\AddOns\\UsefulPlatesAndTooltips\\Modules\\ResourceDing\\Textures\\"
local SHARD_GEM = TEX_DIR .. "ShardGem"
local SHARD_BEZEL = TEX_DIR .. "ShardBezel"
local SHARD_GLOW = TEX_DIR .. "ShardGlow"
local MAX_DIAMONDS = 10
local QUIET_AFTER_WORLD = 3 -- seconds to let the post-loading count settle

local count, lastMaximum, quietUntil = nil, nil, 0
local row, more
local diamonds = {}

local function shardOpacity(style)
  if type(style) == "table" and type(style.opacity) == "number" then return style.opacity end
  if BIT and BIT.Style and type(BIT.Style.Resolve) == "function" then
    local ok, resolved = pcall(BIT.Style.Resolve, "ResourceDing")
    if ok and type(resolved) == "table" and type(resolved.opacity) == "number" then return resolved.opacity end
  end
  return 1
end

local function shardArtStyle()
  return BIT and BIT.Art and type(BIT.Art.Get) == "function" and BIT.Art.Get() or "2d"
end

local function applyShardArt(shard)
  local style = shardArtStyle()
  if shard._artStyle == style then return end
  shard._artStyle = style
  local art = BIT and BIT.Art
  local gemTex = art and art.Texture("shardGem") or SHARD_GEM
  local bezelTex = art and art.Texture("shardBezel") or (style ~= "classic" and SHARD_BEZEL or nil)
  local glowTex = art and art.Texture("shardGlow") or (style ~= "classic" and SHARD_GLOW or nil)
  if shard.gem then
    shard.gem:SetTexture(gemTex or WHITE)
    if style == "classic" then
      pcall(shard.gem.SetRotation, shard.gem, math.pi / 4)
    else
      pcall(shard.gem.SetRotation, shard.gem, 0)
    end
  end
  if shard.bezel then
    if bezelTex then
      shard.bezel:SetTexture(bezelTex)
      shard.bezel:Show()
    else
      shard.bezel:Hide()
    end
  end
  if shard.glow then
    if glowTex then
      shard.glow:SetTexture(glowTex)
      shard._hasGlow = true
    else
      shard.glow:Hide()
      shard._hasGlow = false
    end
  end
end

-- Shared Soul Shard crystal widget (live nameplate HUD + Settings live preview):
-- follows BIT.Art (Stylized 2D faceted amethyst crystal, crisp 16-bit Pixel Art crystal, or Classic diamond).
function Addon.CreateShard(parent)
  local shard = CreateFrame("Frame", nil, parent)
  shard.glow = shard:CreateTexture(nil, "BACKGROUND", nil, -1)
  shard.glow:SetPoint("CENTER", shard, "CENTER")
  shard.glow:Hide()
  shard.gem = shard:CreateTexture(nil, "ARTWORK", nil, 0)
  shard.gem:SetAllPoints(shard)
  shard.bezel = shard:CreateTexture(nil, "OVERLAY", nil, 1)
  shard.bezel:SetAllPoints(shard)
  applyShardArt(shard)
  return shard
end

function Addon.LayoutShard(shard, size)
  if type(shard) ~= "table" then return end
  shard:SetSize(size, size)
  if shard.glow then
    shard.glow:SetSize(size * 2.0, size * 2.0)
    shard.glow:ClearAllPoints()
    shard.glow:SetPoint("CENTER", shard, "CENTER")
  end
end

function Addon.PaintShard(shard, style, isNewest)
  if type(shard) ~= "table" then return end
  applyShardArt(shard)
  local alpha = shardOpacity(style)
  local classic = shardArtStyle() == "classic"
  if shard.gem then
    if classic then
      shard.gem:SetVertexColor(0.68, 0.30, 0.96, alpha)
    else
      shard.gem:SetVertexColor(1, 1, 1, alpha)
    end
  end
  if shard.bezel and shard.bezel:IsShown() then shard.bezel:SetVertexColor(1, 1, 1, alpha) end
  if shard.glow then
    shard.glow:SetVertexColor(1, 1, 1, alpha)
    shard.glow:SetShown(shard._hasGlow and isNewest == true)
  end
end

function Addon.ShardStep(size)
  return math.max(size, size + math.floor(size / 10))
end

local function isSecret(v) return type(issecretvalue) == "function" and issecretvalue(v) or false end

local function plain(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, v = pcall(fn, ...)
  if not ok or isSecret(v) then return nil end
  return v
end

local function forWarlock()
  local _, class = UnitClass("player")
  return class == "WARLOCK"
end

local function shardCount()
  if not Addon.IsClassic() then
    local resource, current, maximum = Addon.GetResourceState()
    if not resource or current == nil or maximum <= 0 then return nil end
    -- Fractional progress is not another usable shard.
    return math.max(0, math.floor(math.min(current, maximum))), maximum
  end
  local n = plain(C_Item and C_Item.GetItemCount, SOUL_SHARD)
  if n == nil then n = plain(GetItemCount, SOUL_SHARD) end
  return type(n) == "number" and n or nil, nil
end

local function targetPlate()
  if plain(UnitExists, "target") ~= true then return nil end
  if plain(UnitCanAttack, "player", "target") == false then return nil end
  if plain(UnitIsDeadOrGhost, "target") == true then return nil end
  local plate = plain(C_NamePlate and C_NamePlate.GetNamePlateForUnit, "target")
  if type(plate) ~= "table" then return nil end
  if type(plate.IsForbidden) == "function" and plate:IsForbidden() then return nil end
  return plate
end

local function healthBarOf(plate)
  if type(BIT.Plate) == "table" and type(BIT.Plate.HealthBar) == "function" then
    return BIT.Plate.HealthBar(plate)
  end
  local unitFrame = type(plate.UnitFrame) == "table" and plate.UnitFrame or nil
  local container = unitFrame and type(unitFrame.HealthBarsContainer) == "table"
    and unitFrame.HealthBarsContainer or nil
  local bar = unitFrame and (unitFrame.healthBar or unitFrame.HealthBar
    or (container and (container.healthBar or container.HealthBar))) or nil
  return type(bar) == "table" and bar or plate
end

local function hide()
  if not row then return end
  row:Hide()
  if row:GetParent() ~= UIParent then row:SetParent(UIParent) end
end

function Addon.RefreshShards()
  if not Addon.db then return end
  if not (Addon.db.enabled and Addon.db.shardDiamonds and forWarlock()) or not count or count <= 0 then return hide() end
  local plate = targetPlate()
  if not plate then return hide() end
  if not row then
    row = CreateFrame("Frame", nil, UIParent)
    more = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    local font = (type(GameFontHighlightSmall) == "table" and type(GameFontHighlightSmall.GetFont) == "function"
      and GameFontHighlightSmall:GetFont()) or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    pcall(more.SetFont, more, font, 10, "OUTLINE")
  end
  local size = tonumber(Addon.db.dotSize) or 14
  if size ~= size then size = 14 end
  if size < 8 then size = 8 elseif size > 24 then size = 24 end
  local shown = math.min(count, MAX_DIAMONDS)
  local step = Addon.ShardStep(size)
  local style
  if BIT and BIT.Style and type(BIT.Style.Resolve) == "function" then
    local ok, resolved = pcall(BIT.Style.Resolve, "ResourceDing")
    if ok and type(resolved) == "table" then style = resolved end
  end
  for i = 1, MAX_DIAMONDS do
    local d = diamonds[i]
    if i <= shown then
      if not d then
        d = Addon.CreateShard(row)
        diamonds[i] = d
      end
      Addon.LayoutShard(d, size)
      Addon.PaintShard(d, style, i == shown)
      d:ClearAllPoints()
      d:SetPoint("LEFT", row, "LEFT", (i - 1) * step, 0)
      d:Show()
    elseif d then
      d:Hide()
    end
  end
  local span = shown > 0 and ((shown - 1) * step + size) or size
  more:SetText(count > MAX_DIAMONDS and ("+" .. (count - MAX_DIAMONDS)) or "")
  more:ClearAllPoints()
  more:SetPoint("LEFT", row, "LEFT", span + 4, 0)
  row:SetSize(span, size)
  row:SetParent(plate)
  row:ClearAllPoints()
  local shardOffset = tonumber(Addon.db.shardOffset) or -60
  if shardOffset ~= shardOffset then shardOffset = -60 end
  if shardOffset < -80 then shardOffset = -80 elseif shardOffset > 30 then shardOffset = 30 end
  local healthBar = healthBarOf(plate)
  if not healthBar then row:Hide(); return end
  row:SetPoint("TOP", healthBar, "BOTTOM", 0, -shardOffset)
  row:Show()
end

function Addon.CheckShards(silent)
  if not (Addon.db and forWarlock()) then return end
  local n, maximum = shardCount()
  if n == nil then
    -- An unreadable interval proves no gain and must not leave stale diamonds.
    count, lastMaximum = nil, nil
    Addon.RefreshShards()
    return
  end
  local before = count
  if lastMaximum ~= maximum then before = nil end
  count, lastMaximum = n, maximum
  local canSound = Addon.IsClassic() or not Addon.db.combatOnly or plain(UnitAffectingCombat, "player") == true
  if not silent and before and n > before and Addon.db.enabled and Addon.db.shards
      and canSound and GetTime() >= quietUntil then
    Addon.PlaySoundKey(Addon.db.sound)
  end
  Addon.RefreshShards()
end

function Addon.ResetShards()
  count, lastMaximum = nil, nil
  Addon.CheckShards(true)
end

local started = false
local function start()
  if started or not forWarlock() then return end
  started = true
  local events = CreateFrame("Frame")
  for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED",
    "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED" }) do
    pcall(events.RegisterEvent, events, event)
  end
  if Addon.IsClassic() then
    pcall(events.RegisterEvent, events, "BAG_UPDATE")
    pcall(events.RegisterEvent, events, "BAG_UPDATE_DELAYED")
  else
    for _, event in ipairs({ "UNIT_POWER_UPDATE", "UNIT_POWER_FREQUENT" }) do
      pcall(events.RegisterUnitEvent, events, event, "player")
    end
  end
  events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
      quietUntil = GetTime() + QUIET_AFTER_WORLD
      Addon.ResetShards()
    elseif event == "BAG_UPDATE" or event == "BAG_UPDATE_DELAYED"
        or event == "UNIT_POWER_UPDATE" or event == "UNIT_POWER_FREQUENT" then
      Addon.CheckShards()
    else
      Addon.RefreshShards()
    end
  end)
  if BIT and BIT.Style and type(BIT.Style.Subscribe) == "function" then
    BIT.Style.Subscribe("ResourceDing", Addon.RefreshShards)
  end
  if BIT and BIT.Art and type(BIT.Art.Subscribe) == "function" then
    BIT.Art.Subscribe(Addon.RefreshShards)
  end
  quietUntil = GetTime() + QUIET_AFTER_WORLD
  Addon.CheckShards()
end

Addon.starters = Addon.starters or {}
table.insert(Addon.starters, start)
