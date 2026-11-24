-- UsefulPlatesAndTooltips: the Frames page of the settings window. Where another unit frame addon's bars are (Core/Frames.lua):
-- one page for every part that draws on a health bar, instead of rows inside the DoTs tab. A plain tool page, so it is
-- there even when DoTInfo is switched off.
-- Copyright (c) 2026 Ironship. GPL-3.0-or-later, see LICENSE.

local _, BIT = ...
if not BIT or not BIT.RegisterTab or not BIT.Frames then return end

local Frames = BIT.Frames
local ROW = 26

-- key: the Frames setting. kind: "bar" or "anchor" (what the Pick button looks for).
local ROWS = {
  { key = "target", label = "Target health bar", kind = "bar", tooltip = "For unit frame addons that replace "
    .. "Blizzard's target frame (ElvUI, Shadowed Unit Frames, ...). Target something, click Pick, then click "
    .. "its health bar; or type the frame's name (/fstack shows it), like ElvUF_Target.Health. For a bar that "
    .. "drains the other way, see Fill direction on the Marker tab. Empty: Blizzard's, or EllesmereUI's or "
    .. "X-Perl's when it shows its own. Shared with ShieldsInfo "
    .. "and HealPrediction. Plater replaces nameplates, not the screen target frame; its nameplate marker is "
    .. "handled separately." },
  { key = "icon", label = "Kill icon spot", kind = "anchor", tooltip = "Where the kill icon is centered (e.g. the "
    .. "custom frame's portrait). Empty: Blizzard's portrait, or EllesmereUI's; with a custom health bar and no spot "
    .. "the icon sits on that bar. Fine-tune with the offsets on the Kill icon tab." },
  { key = "focus", label = "Focus health bar", kind = "bar", tooltip = "The same for the focus frame. Empty: "
    .. "Blizzard's, or EllesmereUI's when it shows its own." },
  { key = "plate", label = "Nameplate health bar", kind = "bar", noPick = true, tooltip = "Most nameplate addons' "
    .. "bars are found automatically (Plater, EllesmereUI, Platynator, ...). If the marker does not show on "
    .. "yours, type the keys from Blizzard's nameplate to its bar, like unitFrame.healthBar. /dotinfo plates "
    .. "logs what each plate uses. Empty: automatic." },
}

local function tell(text) if BIT.Say then BIT.Say(text) end end

local function frameRow(parent, spec)
  local UI = BIT.UI
  local row = BIT.Looks.Rows.Row(parent, spec.label, { tooltip = spec.tooltip })
  local box = UI.EditBox(row, row.layout.control, 22)
  box:SetPoint("LEFT", row, "LEFT", row.layout.label, 0)
  local function save(value) Frames.Set(spec.key, value) end
  box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  box:SetScript("OnEscapePressed", function(self)
    self:SetText(Frames.Get(spec.key))
    self:ClearFocus()
  end)
  box:SetScript("OnEditFocusLost", function(self)
    if strtrim(self:GetText() or "") ~= Frames.Get(spec.key) then save(self:GetText()) end
  end)
  local pickWidth = spec.noPick and 0 or 58
  box:SetWidth(row.layout.control - pickWidth)
  if not spec.noPick then
    local pick = UI.Button(row, BIT.L("Pick"), 52, function()
      tell(spec.kind == "bar"
        and BIT.L("Click the health bar (you may need to move this window). Right-click cancels.")
        or BIT.L("Click where the kill icon should go (you may need to move this window). Right-click cancels."))
      Frames.StartPick(spec.kind, function(path)
        box:SetText(path)
        save(path)
        tell(string.format(BIT.L("Picked %s."), path))
      end)
    end)
    pick:SetPoint("LEFT", box, "RIGHT", 6, 0)
    box:SetWidth(row.layout.control - 52 - 6)
  end
  function row:Refresh()
    if not box:HasFocus() then box:SetText(Frames.Get(spec.key)) end
  end
  row:Refresh()
  row:SetScript("OnShow", function(self) self:Refresh() end)
  return row
end

local function build(content)
  local UI = BIT.UI
  local y = -8
  local note = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  note:SetPoint("TOPLEFT", 10, y)
  note:SetPoint("RIGHT", -10, 0)
  note:SetJustifyH("LEFT")
  note:SetText(BIT.L("Only for another unit frame addon (ElvUI, Shadowed Unit Frames, ...) or custom nameplates: tell the "
    .. "addon where its health bars are. Empty rows are automatic. The markers of DoTs, Cast, Shields and Heals use these."))
  y = y - math.max(30, (note:GetStringHeight() or 24) + 12)

  local card = CreateFrame("Frame", nil, content, BackdropTemplateMixin and "BackdropTemplate" or nil)
  card:SetPoint("TOPLEFT", 10, y)
  card:SetPoint("RIGHT", -10, 0)
  UI.Backdrop(card, 0.09)

  local cy = 10
  local head = UI.Header(card, "FRAMES")
  head:SetPoint("TOPLEFT", 10, -cy)
  head:SetPoint("RIGHT", -10, 0)
  cy = cy + 26

  local rows = {}
  for _, spec in ipairs(ROWS) do
    local row = frameRow(card, spec)
    row:SetPoint("TOPLEFT", card, "TOPLEFT", 4, -cy)
    rows[#rows + 1] = row
    cy = cy + ROW
  end
  cy = cy + 10

  -- Back to automatic: a path typed or picked wrong (a frame that is not the health bar) puts the markers in the wrong place.
  local reset = BIT.Looks.ResetButton(card, function()
    local cleared = Frames.Reset()
    for _, row in ipairs(rows) do row:Refresh() end
    tell(cleared > 0 and string.format(BIT.L("Frames reset: %d paths cleared, the addon finds the frames by itself again."), cleared)
      or BIT.L("Frames: no path was set, the addon already finds the frames by itself."))
  end, 140)
  reset:SetText(BIT.L("Reset frames"))
  reset:SetWidth(math.max(140, math.ceil(reset:GetFontString():GetStringWidth() or 0) + 24))
  reset:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -10, 10)
  card:SetHeight(cy + 34)

  content:SetHeight(-y + card:GetHeight() + 12)
end

BIT.RegisterTab("Frames", {
  title = "Frames",
  summary = "Where another unit frame addon's health bars are, for every marker the addon draws.",
  plain = true,
  build = build,
})
