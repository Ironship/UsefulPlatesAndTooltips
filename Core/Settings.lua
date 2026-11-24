-- UsefulPlatesAndTooltips: the settings window (/upt). One tab per module, in the order the modules'
-- files load. Each module tab starts with Enable.
-- The module's own settings are built the first time the tab is shown while it runs, and
-- also the moment Enable is ticked while it is still off (a waker fills defaults only;
-- gameplay still starts at the next /reload). Opening a tab that is off does not wake it.
-- Copyright (c) 2026 Ironship. GPL-3.0-or-later, see LICENSE.
--
-- The window is made of plain frames (no secure templates, no protected calls), so it opens in
-- combat too.

local _, BIT = ...

local WHITE = "Interface\\Buttons\\WHITE8X8"
local HEADER_HEIGHT = 40
local TAB_HEIGHT = 26
local SWITCH_HEIGHT = 54
local MARGIN = 10
local SCROLL_BAR_WIDTH = 16
local DEFAULT_TAB = { width = 640, height = 360 }
local MAX_CONTENT_HEIGHT = 560 -- the window stays bounded; taller tabs scroll inside it

local SHORT_LABEL = {
  SpellDamageInfo = "Spells",
  CastPrediction = "Cast",
  DoTInfo = "DoTs",
  StatsInfo = "Stats",
  ResourceDing = "Points",
  Range = "Range",
  ShieldsInfo = "Shields",
  HealPrediction = "Heals",
  HunterRangeFinder = "Hunter",
  TriggerGlow = "Glow",
}

-- The hub's tab order: the prediction modules and the bar overlays first, then the item/number helpers, the tool page last.
-- A module that is not listed (a new one) follows in load order, before the tool pages.
local HUB_ORDER = {
  "SpellDamageInfo", "CastPrediction", "DoTInfo", "HealPrediction", "ShieldsInfo", "TriggerGlow",
  "StatsInfo", "ResourceDing", "Range", "HunterRangeFinder",
}

-- One name per module: the tab label is also the name in "Enable ...", the reset question and the tab tooltip.
local function pageName(name, tab)
  return BIT.L(SHORT_LABEL[name] or (tab and tab.title) or name)
end
BIT.ModuleDisplayName = function(name)
  return pageName(name, BIT.tabs and BIT.tabs[name])
end
BIT.HubModuleOrder = function()
  local list, seen = {}, {}
  for _, name in ipairs(HUB_ORDER) do
    local tab = BIT.tabs[name]
    if tab and not tab.plain then list[#list + 1] = name; seen[name] = true end
  end
  for _, name in ipairs(BIT.order) do
    local tab = BIT.tabs[name]
    if not seen[name] and tab and not tab.plain then list[#list + 1] = name; seen[name] = true end
  end
  return list
end

local function hubOrder()
  local list, seen = {}, {}
  for _, name in ipairs(HUB_ORDER) do
    if BIT.tabs[name] then list[#list + 1] = name; seen[name] = true end
  end
  local tools = {}
  for _, name in ipairs(BIT.order) do
    if not seen[name] then
      if BIT.tabs[name] and BIT.tabs[name].plain then tools[#tools + 1] = name else list[#list + 1] = name end
      seen[name] = true
    end
  end
  for _, name in ipairs(tools) do list[#list + 1] = name end
  return list
end

local window
local tabButtons, pages = {}, {}
local parkedPages = {} -- retain one off page and one prepared page per module
local current
local tabRows = 1

---------------------------------------------------------------------------------------------
-- Widgets shared by the modules of the core (StatsInfo, Range)
---------------------------------------------------------------------------------------------

local UI = BIT.UI or {} -- Appearance.lua (loaded before this file) may have added members
BIT.UI = UI

-- Native Blizzard frame/buttons, black inset surfaces, gold headings and white text.
local TEX_DIR = "Interface\\AddOns\\UsefulPlatesAndTooltips\\Core\\Textures\\"
UI.MEDIA = {
  rounded = TEX_DIR .. "Rounded",
  border1 = TEX_DIR .. "RoundedBorder1",
  border2 = TEX_DIR .. "RoundedBorder2",
}
UI.COLOR = {
  edge = { 0.35, 0.35, 0.35, 1 },
  text = { 1, 1, 1, 1 },
  muted = { 0.63, 0.63, 0.63, 1 },
  heading = { 1, 0.82, 0, 1 },
  track = { 0.08, 0.08, 0.08, 1 },
  divider = { 1, 0.82, 0, 0.18 },
}

-- Black inset panels, matching the game's tooltip/settings furniture.
function UI.Backdrop(frame, shade, alpha, thick)
  if type(frame) ~= "table" then return end
  if type(frame.SetBackdrop) == "function" then
    frame:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16,
      edgeSize = thick and 16 or 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    frame:SetBackdropColor(0, 0, 0, alpha or 1)
    frame:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
  end
end

-- Keep UIPanelButtonTemplate's native art and its own hover/pressed/disabled states.
function UI.SkinButton(button, opts)
  if type(button) ~= "table" then return button end
  button:SetNormalFontObject("GameFontNormal")
  button:SetHighlightFontObject("GameFontHighlight")
  button:SetDisabledFontObject("GameFontDisable")
  return button
end

-- The track and thumb of a slider in the theme. The track is the rounded art stretched (a few
-- pixels tall, so its corners shrink with it; no slicing needed at this size).
function UI.SkinSlider(slider, thickness, vertical)
  if type(slider) ~= "table" then return slider end
  local track = slider.skinTrack
  if type(track) ~= "table" then
    track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetTexture(UI.MEDIA.rounded)
    slider.skinTrack = track
  end
  local size = thickness or 6
  track:ClearAllPoints()
  if vertical then
    track:SetPoint("TOP", 0, 0)
    track:SetPoint("BOTTOM", 0, 0)
    track:SetWidth(size)
  else
    track:SetPoint("LEFT", 0, 0)
    track:SetPoint("RIGHT", 0, 0)
    track:SetHeight(size)
  end
  local c = UI.COLOR.track
  track:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
  local thumb = type(slider.GetThumbTexture) == "function" and slider:GetThumbTexture() or nil
  if type(thumb) == "table" and type(thumb.SetVertexColor) == "function" then
    pcall(thumb.SetVertexColor, thumb, 1, 1, 1, 1)
  end
  return slider
end

-- The same checkbox art as the game's own options.
function UI.SkinCheck(box)
  if type(box) ~= "table" then return box end
  box:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
  box:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
  box:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
  box:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
  return box
end

-- A rounded hover wash for custom menu rows and choice buttons.
function UI.RoundHighlight(frame, color)
  if type(frame) ~= "table" then return end
  local c = color or { 1, 1, 1, 0.10 }
  local tex = frame:CreateTexture(nil, "HIGHLIGHT")
  tex:SetTexture(UI.MEDIA.rounded)
  if type(tex.SetTextureSliceMargins) == "function" and type(Enum) == "table" and Enum.UITextureSliceMode then
    pcall(tex.SetTextureSliceMargins, tex, 5, 5, 5, 5)
    pcall(tex.SetTextureSliceMode, tex, Enum.UITextureSliceMode.Stretched)
  end
  tex:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
  tex:SetAllPoints()
  return tex
end

-- A rounded 1px or 2px outline on an existing frame (palette swatches, gamepad focus).
function UI.RoundBorder(frame, color, layer, thick)
  if type(frame) ~= "table" then return end
  local c = color or UI.COLOR.edge
  local tex = frame:CreateTexture(nil, layer or "OVERLAY")
  tex:SetTexture(thick and UI.MEDIA.border2 or UI.MEDIA.border1)
  if type(tex.SetTextureSliceMargins) == "function" and type(Enum) == "table" and Enum.UITextureSliceMode then
    pcall(tex.SetTextureSliceMargins, tex, 5, 5, 5, 5)
    pcall(tex.SetTextureSliceMode, tex, Enum.UITextureSliceMode.Stretched)
  end
  tex:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
  tex:SetAllPoints()
  return tex
end

-- One single-line text input style across every tab: dark tooltip backdrop, small highlight font.
function UI.EditBox(parent, width, height)
  local box = CreateFrame("EditBox", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  box:SetSize(width or 160, height or 22)
  UI.Backdrop(box, 0.13)
  box:SetFontObject("GameFontHighlightSmall")
  box:SetTextInsets(6, 6, 0, 0)
  box:SetAutoFocus(false)
  return box
end

-- Standard two-column module tab geometry shared by every module in the /upt hub.
UI.TAB_WIDTH = 840
UI.TAB_HEIGHT = 560
UI.TAB_TOP = 44
UI.PREVIEW_WIDTH = 290

-- Consistent "Live preview" (or "Settings") title and gold divider rule at y = -34.
function UI.PreviewHeader(pane, text, side)
  local title = pane:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOPLEFT", pane, "TOPLEFT", side or 12, -12)
  title:SetText(BIT.L(text or "Live preview"))
  local rule = pane:CreateTexture(nil, "ARTWORK")
  local d = UI.COLOR.divider
  rule:SetColorTexture(d[1], d[2], d[3], d[4])
  rule:SetHeight(1)
  rule:SetPoint("TOPLEFT", pane, "TOPLEFT", 8, -34)
  rule:SetPoint("TOPRIGHT", pane, "TOPRIGHT", -8, -34)
  return title, rule
end

-- Consistent bottom preview hint pinned to the card floor with a subtle gold divider rule above it.
function UI.PreviewHint(pane, text, side)
  local pad = side or 12
  local hint = pane:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hint:SetPoint("BOTTOMLEFT", pane, "BOTTOMLEFT", pad, 12)
  hint:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -pad, 12)
  hint:SetJustifyH("LEFT")
  if text and text ~= "" then hint:SetText(BIT.L(text)) end
  local rule = pane:CreateTexture(nil, "ARTWORK")
  local d = UI.COLOR.divider
  rule:SetColorTexture(d[1], d[2], d[3], d[4])
  rule:SetHeight(1)
  rule:SetPoint("BOTTOMLEFT", hint, "TOPLEFT", 0, 8)
  rule:SetPoint("RIGHT", pane, "RIGHT", -pad, 0)
  return hint, rule
end

-- Consistent top-strip summary text above the two columns of a module tab.
function UI.TabSummary(parent, text, rightAnchor)
  local note = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  note:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, -6)
  if rightAnchor then
    note:SetPoint("RIGHT", rightAnchor, "LEFT", -12, 0)
  else
    note:SetPoint("RIGHT", parent, "RIGHT", -12, 0)
  end
  note:SetJustifyH("LEFT")
  if text and text ~= "" then note:SetText(text) end
  return note
end

-- A drop-down button matching BIT.Looks.Rows.Choice: left-aligned highlight text and right-aligned gold "v".
function UI.DropdownButton(parent, width, onClick)
  local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  button:SetSize(width or 200, 22)
  UI.SkinButton(button)
  local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  label:SetPoint("LEFT", 8, 0)
  label:SetPoint("RIGHT", -20, 0)
  label:SetJustifyH("LEFT")
  label:SetWordWrap(false)
  local arrow = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  arrow:SetPoint("RIGHT", -8, 0)
  arrow:SetText("v")
  button.label, button.arrow = label, arrow
  function button:SetLabel(text) label:SetText(text or "") end
  if onClick then button:SetScript("OnClick", onClick) end
  return button
end

-- The selected top tab lifts its native label and upper rim out of the content.
function UI.SkinTabButton(button, label, onClick)
  if type(button) ~= "table" or type(label) ~= "table" then return button end
  button.selectedTextY, button.deselectedTextY = -10, -6
  if not button.uptRaisedTab then
    for _, key in ipairs({ "LeftActive", "MiddleActive", "RightActive" }) do
      local texture = button[key]
      if type(texture) == "table" then texture:SetHeight(texture:GetHeight() + 3) end
    end
    button.uptRaisedTab = true
  end
  if type(onClick) == "function" then button:SetScript("OnClick", onClick) end
  local function paint(selected, hover)
    local C = UI.COLOR
    if selected and type(PanelTemplates_SelectTab) == "function" then PanelTemplates_SelectTab(button)
    elseif not selected and type(PanelTemplates_DeselectTab) == "function" then PanelTemplates_DeselectTab(button) end
    if type(label.SetTextColor) == "function" then
      local color = (selected or hover) and C.text or C.heading
      label:SetTextColor(color[1], color[2], color[3])
    end
  end
  button.tabPaint = paint
  button:HookScript("OnEnter", function() paint(button.tabOn, true) end)
  button:HookScript("OnLeave", function() paint(button.tabOn, false) end)
  paint(false, false)
  return button
end

function UI.TabSelected(button, selected)
  if type(button) ~= "table" or type(button.tabPaint) ~= "function" then return end
  button.tabOn = selected and true or false
  pcall(button.tabPaint, button.tabOn, false)
end

function UI.Button(parent, text, width, onClick)
  local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  button:SetSize(width, 22)
  button:SetText(text)
  button:SetScript("OnClick", onClick)
  return UI.SkinButton(button)
end

-- Auto-sized panel button: widens when a translation exceeds minWidth instead of clipping text.
function UI.FitButton(parent, text, minWidth, onClick)
  local button = UI.Button(parent, text, minWidth or 80, onClick)
  local fs = type(button.GetFontString) == "function" and button:GetFontString() or nil
  local w = fs and type(fs.GetStringWidth) == "function" and fs:GetStringWidth() or 0
  if type(w) == "number" then button:SetWidth(math.max(minWidth or 80, math.ceil(w) + 20)) end
  return button
end

-- True while Blizzard's native Gamepad UI is active (C_InputInterfaceStyle, not C_GamePad).
-- Opening Blizzard-managed frames (StaticPopup, ColorPickerFrame) from addon code in Gamepad Mode
-- taints FrameControlsManager / InputBindingManager and later blocks SetPreferredGamepadInteractTarget.
function UI.IsGamepadMode()
  return type(C_InputInterfaceStyle) == "table" and type(Enum) == "table"
    and type(Enum.InputDeviceInterfaceType) == "table"
    and type(C_InputInterfaceStyle.GetCurrentStyle) == "function"
    and C_InputInterfaceStyle.GetCurrentStyle() == Enum.InputDeviceInterfaceType.Gamepad
    or false
end

-- Escape closes an addon frame without inserting into Blizzard's UISpecialFrames (which taints
-- CloseSpecialWindows() for Blizzard panels closed in the same pass). Out of combat only:
-- SetPropagateKeyboardInput is protected in combat, so keyboard capture turns off while fighting.
function UI.CloseOnEscape(frame, onEscape)
  if type(frame) ~= "table" or type(frame.EnableKeyboard) ~= "function" then return end
  local function inCombat() return type(InCombatLockdown) == "function" and InCombatLockdown() == true end
  local function syncKeys()
    if inCombat() then
      pcall(frame.EnableKeyboard, frame, false)
    elseif frame:IsShown() then
      pcall(frame.EnableKeyboard, frame, true)
      if type(frame.SetPropagateKeyboardInput) == "function" then
        pcall(frame.SetPropagateKeyboardInput, frame, true)
      end
    end
  end
  frame:HookScript("OnShow", syncKeys)
  frame:HookScript("OnHide", function()
    if not inCombat() then pcall(frame.EnableKeyboard, frame, false) end
  end)
  frame:HookScript("OnKeyDown", function(self, key)
    if inCombat() then return end
    if key == "ESCAPE" then
      if type(GetCurrentKeyBoardFocus) == "function" and GetCurrentKeyBoardFocus() then
        if type(self.SetPropagateKeyboardInput) == "function" then self:SetPropagateKeyboardInput(true) end
        return
      end
      if type(self.SetPropagateKeyboardInput) == "function" then self:SetPropagateKeyboardInput(false) end
      if type(onEscape) == "function" then onEscape(self) else self:Hide() end
    elseif type(self.SetPropagateKeyboardInput) == "function" then
      self:SetPropagateKeyboardInput(true)
    end
  end)
  local watcher = CreateFrame("Frame", nil, frame)
  pcall(watcher.RegisterEvent, watcher, "PLAYER_REGEN_DISABLED")
  pcall(watcher.RegisterEvent, watcher, "PLAYER_REGEN_ENABLED")
  watcher:SetScript("OnEvent", syncKeys)
  syncKeys()
end

-- Taint-free modal confirmation dialog matching /upt's style: avoids Blizzard's StaticPopup_Show,
-- whose GamepadPopupHandler hooks taint FrameControlsManager and InputBindingManager in Gamepad Mode.
local confirmDialog
function UI.Confirm(title, message, acceptLabel, onAccept)
  if not confirmDialog then
    local catcher = CreateFrame("Button", nil, UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("FULLSCREEN_DIALOG")
    catcher:SetFrameLevel(100)
    local shade = catcher:CreateTexture(nil, "BACKGROUND")
    shade:SetAllPoints()
    shade:SetColorTexture(0, 0, 0, 0.45)
    catcher:Hide()

    local box = CreateFrame("Frame", "UsefulPlatesAndTooltipsConfirm", catcher, BackdropTemplateMixin and "BackdropTemplate" or nil)
    box:SetSize(380, 140)
    box:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
    box:SetFrameStrata("FULLSCREEN_DIALOG")
    box:SetFrameLevel(105)
    box:EnableMouse(true)
    box:SetClampedToScreen(true)
    UI.Backdrop(box, 0.06, 0.98, true)

    local heading = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    heading:SetPoint("TOPLEFT", 16, -14)
    heading:SetPoint("RIGHT", -16, 0)
    heading:SetJustifyH("LEFT")
    heading:SetTextColor(UI.COLOR.heading[1], UI.COLOR.heading[2], UI.COLOR.heading[3])

    local rule = box:CreateTexture(nil, "ARTWORK")
    local d = UI.COLOR.divider
    rule:SetColorTexture(d[1], d[2], d[3], d[4])
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", 12, -34)
    rule:SetPoint("TOPRIGHT", -12, -34)

    local body = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    body:SetPoint("TOPLEFT", 16, -44)
    body:SetWidth(348)
    body:SetJustifyH("LEFT")
    body:SetWordWrap(true)

    local function dismiss()
      box.pendingAccept = nil
      box:Hide()
      catcher:Hide()
    end
    catcher:SetScript("OnClick", dismiss)

    local cancelBtn = UI.FitButton(box, CANCEL or BIT.L("Cancel"), 92, dismiss)
    cancelBtn:SetPoint("BOTTOMRIGHT", -14, 14)

    local acceptBtn = UI.FitButton(box, OKAY or BIT.L("Confirm"), 100, function()
      local fn = box.pendingAccept
      dismiss()
      if type(fn) == "function" then fn() end
    end)
    acceptBtn:SetPoint("RIGHT", cancelBtn, "LEFT", -8, 0)

    UI.CloseOnEscape(box, dismiss)
    if BIT.GamePadUI then
      BIT.GamePadUI.Attach(box, function(self, key)
        if key == "PAD2" then dismiss(); return true end
        if key == "PADLSHOULDER" or key == "PADRSHOULDER" then return true end
        return BIT.GamePadUI.Navigate(self, key)
      end)
    end

    confirmDialog = {
      catcher = catcher, box = box, heading = heading, body = body,
      acceptBtn = acceptBtn, cancelBtn = cancelBtn, dismiss = dismiss,
    }
  end
  local dlg = confirmDialog
  dlg.heading:SetText(title or "DoesItDiePlus")
  dlg.body:SetText(message or "")
  local acceptText = acceptLabel or OKAY or BIT.L("Confirm")
  dlg.acceptBtn:SetText(acceptText)
  local fs = type(dlg.acceptBtn.GetFontString) == "function" and dlg.acceptBtn:GetFontString() or nil
  local w = fs and type(fs.GetStringWidth) == "function" and fs:GetStringWidth() or 0
  dlg.acceptBtn:SetWidth(math.max(96, (type(w) == "number" and math.ceil(w) or 0) + 22))
  local bodyH = type(dlg.body.GetStringHeight) == "function" and dlg.body:GetStringHeight() or 36
  dlg.box:SetHeight(math.max(126, 44 + (type(bodyH) == "number" and math.ceil(bodyH) or 36) + 52))
  dlg.box.pendingAccept = onAccept
  dlg.catcher:Show()
  dlg.box:Show()
  return dlg.box
end

-- Native WoW dialog chrome (ButtonFrameTemplate, no portrait/inset) with BackdropTemplate fallback.
function UI.NativeWindow(name, title, width, height)
  local okTpl, frame = pcall(CreateFrame, "Frame", name, UIParent, "ButtonFrameTemplate")
  local nativeChrome = okTpl and type(frame) == "table"
  if not nativeChrome then
    frame = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    UI.Backdrop(frame, 0.06, 0.97)
  else
    if type(ButtonFrameTemplate_HidePortrait) == "function" then ButtonFrameTemplate_HidePortrait(frame) end
    if type(frame.Inset) == "table" then frame.Inset:Hide() end
  end
  frame:Hide()
  frame:SetSize(width, height)
  frame:SetFrameStrata("DIALOG")
  frame:SetToplevel(true)
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  local close = frame.CloseButton
  if nativeChrome and (type(frame.SetTitle) == "function" or type(frame.TitleText) == "table") then
    if type(frame.SetTitle) == "function" then frame:SetTitle(title) else frame.TitleText:SetText(title) end
    if type(close) == "table" then close:SetScript("OnClick", function() frame:Hide() end) end
  else
    local heading = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", 16, -16)
    heading:SetText(title)
    heading:SetTextColor(UI.COLOR.heading[1], UI.COLOR.heading[2], UI.COLOR.heading[3])
    frame.titleText = heading
    if type(close) ~= "table" then
      close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
      close:SetPoint("TOPRIGHT", -6, -10)
      frame.CloseButton = close
    end
  end
  return frame, nativeChrome, close
end

-- Native list rows participate in SettingsPanel's gamepad focus; canvas controls do not.
function UI.RegisterSettingsLauncher(title, tooltip, onClick)
  if type(Settings) ~= "table" or type(Settings.RegisterVerticalLayoutCategory) ~= "function"
      or type(Settings.RegisterInitializer) ~= "function"
      or type(Settings.RegisterAddOnCategory) ~= "function"
      or type(CreateSettingsButtonInitializer) ~= "function" then return false end
  local category = Settings.RegisterVerticalLayoutCategory(title)
  -- addSearchTags false: with true, the Blizzard function writes the row's searchTags while it runs
  -- under this addon's taint, and the settings search (SettingsPanel:FindInitializersMatchingSearchText)
  -- reads them for every category: the rest of that search ran tainted by us, so the Social tab's
  -- C_Discord.IsUserOAuthed() was refused as a forbidden action (issue #72, the Discord button then
  -- read "sign in"). Blizzard's own launcher buttons pass false for the same reason.
  local initializer = CreateSettingsButtonInitializer(title, BIT.L("Open settings"), onClick, tooltip, false)
  Settings.RegisterInitializer(category, initializer)
  Settings.RegisterAddOnCategory(category)
  return true
end

-- A check box with its label to the right. get() and set(value) read and write the setting. The label and the tooltip are
-- English texts (BIT.L translates them); `translated` says the label is shown as it is (it was composed from a template).
function UI.Check(parent, labelText, get, set, tooltip, translated)
  local box = CreateFrame("CheckButton", nil, parent)
  box:SetSize(24, 24)
  box:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
  box:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
  box:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
  box:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
  UI.SkinCheck(box)
  local shown = translated and labelText or BIT.L(labelText)
  box.label = box:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  box.label:SetPoint("LEFT", box, "RIGHT", 4, 0)
  box.label:SetText(shown)
  if tooltip then
    box:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(shown, 1, 0.82, 0)
      GameTooltip:AddLine(BIT.L(tooltip), 1, 1, 1, true)
      GameTooltip:Show()
    end)
    box:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end
  function box:Refresh() self:SetChecked(get() and true or false) end
  box:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
  box:Refresh()
  return box
end

---------------------------------------------------------------------------------------------
-- Column layout helpers shared by the module tabs
---------------------------------------------------------------------------------------------

-- A width for a sub-tab button that keeps the art of its neighbours from overlapping (the
-- art needs about 64 px whatever the label is).
UI.TAB_GAP = 4
function UI.TabWidth(text)
  local w = type(text) == "table" and type(text.GetStringWidth) == "function" and text:GetStringWidth() or 48
  if type(w) ~= "number" then w = 48 end
  return math.max(64, math.ceil(w) + 20)
end

-- Grow a row to fit its wrapped label. The label is centred vertically in the row, so a
-- two-line label no longer runs into the rows above and below it.
function UI.FitRow(row, minHeight)
  local label = type(row) == "table" and row.label or nil
  if type(label) ~= "table" or type(label.GetStringHeight) ~= "function" then return end
  local h = label:GetStringHeight()
  if type(h) ~= "number" then return end
  row:SetHeight(math.max(minHeight or 26, math.ceil(h) + 8))
end

-- A section header: small gold caps and a hairline to the column's right edge. It is a frame,
-- so a column can anchor it on both sides and the rule has a right end.
function UI.Header(parent, text)
  local row = CreateFrame("Frame", nil, parent)
  row:SetHeight(20)
  row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  row.label:SetPoint("LEFT", 0, 0)
  row.label:SetText(BIT.L(text))
  local heading = UI.COLOR.heading
  row.label:SetTextColor(heading[1], heading[2], heading[3])
  local rule = row:CreateTexture(nil, "ARTWORK")
  local c = UI.COLOR.divider
  rule:SetColorTexture(c[1], c[2], c[3], c[4])
  rule:SetHeight(1)
  rule:SetPoint("LEFT", row.label, "RIGHT", 8, 0)
  rule:SetPoint("RIGHT", row, "RIGHT", 0, 0)
  return row
end

-- A wrapped muted paragraph of a fixed width. Its height is measured, so the next row can be
-- placed below it instead of at a guessed offset.
function UI.Note(parent, text, width)
  local row = CreateFrame("Frame", nil, parent)
  row.text = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  row.text:SetPoint("TOPLEFT", 0, 0)
  row.text:SetWidth(width)
  row.text:SetJustifyH("LEFT")
  row.text:SetWordWrap(true)
  row.text:SetText(BIT.L(text))
  local h = row.text:GetStringHeight()
  row:SetSize(width, math.max(14, type(h) == "number" and math.ceil(h) or 14))
  return row
end

-- Place a row in a column of its parent, inset 6 on both sides, and return the next y. A check
-- box keeps its own size (its label runs to its right): stretching it across the column would
-- stretch its art and push the label out of view. Every other row spans the column.
function UI.PlaceRow(row, y, height)
  local parent = row:GetParent()
  row:ClearAllPoints()
  row:SetPoint("TOPLEFT", parent, "TOPLEFT", 6, -y)
  if not (type(row.IsObjectType) == "function" and row:IsObjectType("CheckButton")) then
    row:SetPoint("RIGHT", parent, "RIGHT", -6, 0)
  end
  return y + (height or 26)
end

-- A vertically scrolling column. The holder is what a tab shows and hides; the rows go in
-- holder.content, and holder:Fit(height) sets how tall they are. The slider and the wheel move
-- the same offset, and the slider hides while everything fits.
function UI.ScrollColumn(parent)
  local holder = CreateFrame("Frame", nil, parent)
  local scroll = CreateFrame("ScrollFrame", nil, holder)
  scroll:SetPoint("TOPLEFT", 0, 0)
  scroll:SetPoint("BOTTOMRIGHT", -SCROLL_BAR_WIDTH + 2, 0)
  scroll:EnableMouseWheel(true)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(1, 1)
  scroll:SetScrollChild(content)

  local bar = CreateFrame("Slider", nil, holder)
  bar:SetOrientation("VERTICAL")
  bar:SetWidth(12)
  bar:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, 0)
  bar:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 0, 0)
  bar:SetMinMaxValues(0, 1)
  bar:SetValue(1)
  bar:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Vertical")
  UI.SkinSlider(bar, 6, true)

  local function offset()
    local v = scroll:GetVerticalScroll()
    return type(v) == "number" and v or 0
  end
  local function maxScroll()
    return math.max(0, (content:GetHeight() or 0) - (scroll:GetHeight() or 0))
  end
  local function sync()
    local max = maxScroll()
    bar._sync = true
    bar:SetMinMaxValues(0, math.max(max, 0.001))
    bar:SetShown(max > 0)
    if offset() > max then scroll:SetVerticalScroll(max) end
    bar:SetValue(max - math.min(offset(), max))
    bar._sync = false
  end
  local function fitWidth()
    local w = type(scroll.GetWidth) == "function" and scroll:GetWidth() or 0
    if type(w) == "number" and w > 0 then content:SetWidth(w) end
  end
  scroll:SetScript("OnMouseWheel", function(_, delta)
    scroll:SetVerticalScroll(math.min(math.max(offset() - (delta or 0) * 24, 0), maxScroll()))
    sync()
  end)
  scroll:SetScript("OnSizeChanged", function(_, width)
    if type(width) == "number" and width > 0 then content:SetWidth(width) else fitWidth() end
    sync()
  end)
  holder:SetScript("OnShow", function()
    fitWidth()
    sync()
  end)
  bar:SetScript("OnValueChanged", function(_, value)
    if bar._sync or type(value) ~= "number" then return end
    local max = maxScroll()
    scroll:SetVerticalScroll(math.min(math.max(max - value, 0), max))
  end)
  holder.scroll, holder.content, holder.bar = scroll, content, bar
  scroll.syncScroll = sync
  function holder:Fit(height)
    fitWidth()
    content:SetHeight(math.max(1, height))
    sync()
  end
  return holder
end

---------------------------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------------------------

local function tabSize()
  local w, h = DEFAULT_TAB.width, DEFAULT_TAB.height
  for _, name in ipairs(BIT.order) do
    local tab = BIT.tabs[name]
    if tab then
      w = math.max(w, tab.width or 0)
      h = math.max(h, tab.height or 0)
    end
  end
  h = math.min(h, MAX_CONTENT_HEIGHT)
  return w, h
end

local STATE_TEXT = {
  on = "Running.",
  off = "Switched off.",
}

local function stateText(name)
  local state = BIT.state[name]
  local wanted = BIT.IsSwitchedOn(name)
  if (state == "on") ~= wanted then
    return BIT.L(wanted and "Switched on after a reload of the interface." or "Switched off after a reload of the interface.")
  end
  return STATE_TEXT[state] and BIT.L(STATE_TEXT[state]) or ""
end

local function refreshSwitch(page)
  if not page.switch then return end
  page.switch:Refresh()
  page.stateLine:SetText(stateText(page.name))
  local pending = (BIT.state[page.name] == "on") ~= BIT.IsSwitchedOn(page.name)
  page.reload:SetShown(pending)
  if page.resetModule then
    page.resetModule:ClearAllPoints()
    if pending then
      page.resetModule:SetPoint("RIGHT", page.reload, "LEFT", -8, 0)
    else
      page.resetModule:SetPoint("TOPRIGHT", -10, -7)
    end
  end
end

local function playerClass()
  if type(UnitClass) ~= "function" then return nil end
  return select(2, UnitClass("player"))
end

local function tabTextColor(name, on)
  local irrelevant = name == "HunterRangeFinder" and playerClass() ~= "HUNTER"
  if on then
    if irrelevant then return 0.62, 0.62, 0.48 end
    return 1, 1, 1
  end
  if irrelevant then return 0.42, 0.42, 0.38 end
  return UI.COLOR.heading[1], UI.COLOR.heading[2], UI.COLOR.heading[3]
end

-- A vertical slider on the scroll frame's right. The thumb at the top is the start of the
-- content (WoW's vertical slider keeps its minimum at the bottom, so the value is inverted).
-- Hidden while the content fits. Mouse wheel and the slider move the same offset.
local function attachScroll(page, topOffset)
  local scroll = CreateFrame("ScrollFrame", nil, page)
  scroll:SetPoint("TOPLEFT", 0, -topOffset)
  scroll:SetPoint("BOTTOMRIGHT", -SCROLL_BAR_WIDTH, 0)
  scroll:EnableMouseWheel(true)
  local content = CreateFrame("Frame", nil, scroll)
  local function contentWidth()
    local w = 0
    if type(scroll.GetWidth) == "function" then w = scroll:GetWidth() or 0 end
    if type(w) ~= "number" or w <= 1 then
      w = (window:GetWidth() or 200) - 2 * MARGIN - SCROLL_BAR_WIDTH
    end
    return math.max(1, w)
  end
  content:SetWidth(contentWidth())
  scroll:SetScrollChild(content)

  local bar = CreateFrame("Slider", nil, page)
  bar:SetOrientation("VERTICAL")
  bar:SetWidth(12)
  bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 2, 0)
  bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 2, 0)
  bar:SetMinMaxValues(0, 1)
  bar:SetValue(1)
  if type(bar.SetThumbTexture) == "function" then
    bar:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Vertical")
  end
  UI.SkinSlider(bar, 6, true)

  local function scrollOffset()
    if type(scroll.GetVerticalScroll) ~= "function" then return 0 end
    local v = scroll:GetVerticalScroll()
    if type(v) ~= "number" then return 0 end
    return v
  end
  local function maxScroll()
    return math.max(0, (content:GetHeight() or 0) - (scroll:GetHeight() or 0))
  end
  local function syncBar()
    local max = maxScroll()
    bar._sync = true
    bar:SetMinMaxValues(0, math.max(max, 0.001))
    if max <= 0 then bar:Hide() else bar:Show() end
    if scrollOffset() > max and type(scroll.SetVerticalScroll) == "function" then
      scroll:SetVerticalScroll(max)
    end
    bar:SetValue(max - math.min(scrollOffset(), max))
    bar._sync = false
  end
  local function setScroll(at)
    local max = maxScroll()
    at = math.min(math.max(at or 0, 0), max)
    if type(scroll.SetVerticalScroll) == "function" then scroll:SetVerticalScroll(at) end
    syncBar()
  end
  scroll:SetScript("OnMouseWheel", function(_, delta)
    setScroll(scrollOffset() - (delta or 0) * 24)
  end)
  content:SetScript("OnSizeChanged", function() syncBar() end)
  scroll:SetScript("OnSizeChanged", function(_, width)
    if type(width) == "number" and width > 0 then content:SetWidth(width) end
    syncBar()
  end)
  bar:SetScript("OnValueChanged", function(_, value)
    if bar._sync or type(value) ~= "number" then return end
    local max = maxScroll()
    if type(scroll.SetVerticalScroll) == "function" then
      scroll:SetVerticalScroll(math.min(math.max(max - value, 0), max))
    end
  end)
  page.scroll, page.content, page.scrollBar = scroll, content, bar
  page.syncScroll = syncBar
  scroll.syncScroll = syncBar
  return content
end

local function headerBottom()
  return HEADER_HEIGHT + TAB_HEIGHT * tabRows
end

-- Anchor points a saved window position may name; anything else (or a non-finite offset)
-- must never reach Frame:SetPoint -- a corrupt shared SavedVariables would break /upt.
local WINDOW_POINTS = { TOPLEFT = true, TOP = true, TOPRIGHT = true, LEFT = true, CENTER = true,
  RIGHT = true, BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true }

local function savedWindowPoint()
  local getDB = type(BIT.GlobalDB) == "function" and BIT.GlobalDB or BIT.DB
  if type(getDB) ~= "function" then return nil end
  local saved = getDB()
  local p = type(saved) == "table" and saved.window or nil
  if type(p) ~= "table" or type(p.point) ~= "string" or not WINDOW_POINTS[p.point] then return nil end
  if type(p.x) ~= "number" or type(p.y) ~= "number" then return nil end
  if p.x ~= p.x or p.y ~= p.y or p.x == math.huge or p.x == -math.huge
      or p.y == math.huge or p.y == -math.huge then return nil end
  if type(p.relativePoint) == "string" and not WINDOW_POINTS[p.relativePoint] then p.relativePoint = nil end
  return p
end

local function applyWindowPoint()
  window:ClearAllPoints()
  local p = savedWindowPoint()
  if not p then
    window:SetPoint("CENTER")
    return
  end
  window:SetPoint(p.point, UIParent, p.relativePoint or p.point, p.x, p.y)
end

local function rememberWindowPoint()
  if type(window.GetPoint) ~= "function" then return end
  local point, _, relativePoint, x, y = window:GetPoint(1)
  if type(point) ~= "string" or type(x) ~= "number" or type(y) ~= "number" then return end
  local getDB = type(BIT.GlobalDB) == "function" and BIT.GlobalDB or BIT.DB
  if type(getDB) ~= "function" then return end
  getDB().window = {
    point = point,
    relativePoint = type(relativePoint) == "string" and relativePoint or point,
    x = x,
    y = y,
  }
end

local selectTab

local MODULE_STORES = {
  SpellDamageInfo = "UsefulPlatesAndTooltips_SpellDamageInfoDB",
  DoTInfo = "UsefulPlatesAndTooltips_DoTInfoDB",
  ResourceDing = "UsefulPlatesAndTooltips_ResourceDingDB",
}

local function copyDefault(value)
  if type(value) ~= "table" then return value end
  local copy = {}
  for key, entry in pairs(value) do copy[key] = copyDefault(entry) end
  return copy
end

local function resetModule(name)
  local tab, module = BIT.tabs[name], BIT.modules[name]
  local defaults = tab and (tab.defaults or (module and (module.DEFAULTS or module.defaults)))
  if type(defaults) ~= "table" then
    BIT.Say(string.format(BIT.L("Cannot reset %s: defaults are unavailable."), name))
    return
  end
  if type(ReloadUI) ~= "function" then
    BIT.Say(BIT.L("Cannot reset settings: reloading the interface is unavailable."))
    return
  end
  local storeName = MODULE_STORES[name]
  local store
  if storeName then
    store = (type(BIT.PortedDB) == "function" and BIT.PortedDB(name)) or _G[storeName]
  else
    store = BIT.DB().modules[name]
  end
  if store ~= nil and type(store) ~= "table" then
    BIT.Say(string.format(BIT.L("Cannot reset %s: its settings are invalid."), name))
    return
  end
  if store == nil then
    store = {}
    if storeName then _G[storeName] = store else BIT.DB().modules[name] = store end
  end
  if BIT.Style and BIT.Style.Reset then
    local ok, err = pcall(BIT.Style.Reset, name)
    if not ok then
      BIT.Say(string.format(BIT.L("Cannot reset %s appearance: %s"), name, tostring(err)))
      return
    end
  end
  for key, value in pairs(defaults) do store[key] = copyDefault(value) end
  if name == "ResourceDing" then
    store.manaLevels, store.manaPercent = nil, nil
  elseif name == "CastPrediction" then
    store.talentForce, store.auraForce = {}, {}
  elseif name == "HunterRangeFinder" then
    store.plateScheme = 2
  end
  ReloadUI()
end

local function confirmResetModule(name)
  local tab = BIT.tabs[name]
  local label = pageName(name, tab)
  local text = string.format(
    BIT.L("Reset all settings for %s? The interface will reload. Module enable state, learned data and shared settings are kept."),
    label)
  UI.Confirm(label, text, BIT.L("Reset module"), function() resetModule(name) end)
end

local function buildPage(name)
  local tab = BIT.tabs[name] or {}
  local page = CreateFrame("Frame", nil, window)
  page:SetPoint("TOPLEFT", MARGIN, -headerBottom())
  page:SetPoint("BOTTOMRIGHT", -MARGIN, MARGIN + (window.gamepadPadding or 0))
  page:Hide()
  page.name = name

  -- A plain tab (Debug) is a tool page, not a part: no Enable box, and it is always built.
  if not tab.plain then
  page.switch = UI.Check(page, string.format(BIT.L("Enable %s"), pageName(name, tab)),
    function() return BIT.IsSwitchedOn(name) end,
    function(v)
      BIT.SetSwitchedOn(name, v)
      -- Still running: the page stays, and only the pending-reload line changes.
      -- Ticked on while off: wake defaults and build the real settings.
      -- Ticked off while not running: back to the off note. Gameplay waits for /reload.
      if BIT.IsRunning(name) then
        refreshSwitch(page)
        return
      end
      if v then
        BIT.Wake(name)
      elseif BIT.woke then
        BIT.woke[name] = nil
      end
      page:Hide()
      pages[name], parkedPages[name] = parkedPages[name], page
      selectTab(name)
    end, tab.summary, true)
  page.switch:SetPoint("TOPLEFT", 10, -6)
  page.stateLine = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  page.stateLine:SetPoint("TOPLEFT", 38, -30)
  page.stateLine:SetPoint("TOPRIGHT", -160, -30)
  page.stateLine:SetHeight(16)
  page.stateLine:SetJustifyH("LEFT")
  page.reload = UI.Button(page, BIT.L("Reload UI"), 100, function()
    if type(ReloadUI) == "function" then ReloadUI() end
  end)
  page.reload:SetWidth(math.max(100, math.ceil(page.reload:GetFontString():GetStringWidth() or 0) + 24))
  page.reload:SetPoint("TOPRIGHT", -10, -7)
  page.resetModule = UI.Button(page, BIT.L("Reset module"), 120, function() confirmResetModule(name) end)
  page.resetModule:SetWidth(math.max(120, math.ceil(page.resetModule:GetFontString():GetStringWidth() or 0) + 24))
  page.resetModule:SetPoint("TOPRIGHT", -10, -7)
  local switchRule = page:CreateTexture(nil, "ARTWORK")
  local sd = UI.COLOR.divider
  switchRule:SetColorTexture(sd[1], sd[2], sd[3], sd[4])
  switchRule:SetHeight(1)
  switchRule:SetPoint("TOPLEFT", 10, -(SWITCH_HEIGHT - 2))
  switchRule:SetPoint("TOPRIGHT", -10, -(SWITCH_HEIGHT - 2))
  end

  local content = attachScroll(page, tab.plain and 0 or SWITCH_HEIGHT)

  local viewport = page.scroll:GetHeight()
  local function layoutContent()
    local needed = math.max(tab.height or DEFAULT_TAB.height, page.offNote and 0 or content:GetHeight())
    if page.appearance then
      needed = math.max(needed, 74 + page.appearance:GetHeight())
    end
    content:SetHeight(math.max(needed, viewport))
    if page.syncScroll then page.syncScroll() end
  end

  local showLive = (tab.plain or BIT.IsRunning(name) or (BIT.woke and BIT.woke[name])) and type(tab.build) == "function"
  if showLive then
    content:SetHeight(tab.height or DEFAULT_TAB.height)
    local ok, err = pcall(tab.build, content)
    if not ok then
      BIT.Say("the " .. name .. " settings could not be built: " .. tostring(err))
    end
  else
    local note = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    note:SetPoint("TOPLEFT", 8, -8)
    note:SetPoint("RIGHT", -8, 0)
    note:SetJustifyH("LEFT")
    if tab.usesStyle then
      note:SetText((tab.summary and (BIT.L(tab.summary) .. "\n\n") or "")
        .. BIT.L("Its settings are here while it runs; its appearance and a sample preview are below"
        .. " -- they need no module runtime. Tick Enable to open the settings before the next reload."))
      page.offNote = note
      page.appearance = BIT.UI.Appearance(content, name, tab.capabilities, function()
        if page.layoutOffPage then page.layoutOffPage() end
      end, tab.legacy)
      local function layoutOffPage()
        local top = math.max(74, (note:GetStringHeight() or 54) + 20)
        page.appearance:SetPoint("TOPLEFT", 8, -top)
        content:SetHeight(math.max(viewport, top + page.appearance:GetHeight() + 12))
        if page.syncScroll then page.syncScroll() end
      end
      page.appearance.onLayout = layoutOffPage
      page.layoutOffPage = layoutOffPage
      layoutOffPage()
    else
      note:SetText((tab.summary and (BIT.L(tab.summary) .. "\n\n") or "")
        .. BIT.L("This module is switched off. Tick Enable above to open its settings and live preview before the next reload."))
      page.offNote = note
      local function layoutOffPage()
        local top = math.max(74, (note:GetStringHeight() or 54) + 20)
        content:SetHeight(math.max(viewport, top + 12))
        if page.syncScroll then page.syncScroll() end
      end
      page.layoutOffPage = layoutOffPage
      layoutOffPage()
    end
  end

  if page.layoutOffPage then page.layoutOffPage() else layoutContent() end
  refreshSwitch(page)
  return page
end

selectTab = function(name)
  if not pages[name] then pages[name] = buildPage(name) end
  for n, page in pairs(pages) do page:SetShown(n == name) end
  for _, button in ipairs(tabButtons) do
    local on = button.name == name
    local r, g, b = tabTextColor(button.name, on)
    UI.TabSelected(button, on)
    button.text:SetTextColor(r, g, b)
  end
  current = name
  if BIT.GamePadUI then BIT.GamePadUI.Clear() end
  local page = pages[name]
  refreshSwitch(page)
  if type(window.refreshGamePadHints) == "function" then window.refreshGamePadHints() end
end

local function addTabButton(name, label, tipTitle, tipBody, extraTip)
  local button = CreateFrame("Button", nil, window, "PanelTopTabButtonTemplate")
  button.name = name
  button:SetText(label)
  button.text = button:GetFontString()
  local width = UI.TabWidth(button.text)
  button:SetSize(width, TAB_HEIGHT - 2)
  button:SetScript("OnClick", function() selectTab(name) end)
  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(tipTitle or label, 1, 0.82, 0)
    if tipBody and tipBody ~= "" then GameTooltip:AddLine(tipBody, 1, 1, 1, true) end
    if extraTip then GameTooltip:AddLine(extraTip, 0.8, 0.8, 0.6, true) end
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function() GameTooltip:Hide() end)
  UI.SkinTabButton(button, button.text)
  tabButtons[#tabButtons + 1] = button
  return button
end

local function layoutTabs()
  local maxW = (window:GetWidth() or 400) - MARGIN
  local x = MARGIN
  local row = 0
  for _, button in ipairs(tabButtons) do
    local width = button:GetWidth() or 64
    if x > MARGIN and x + width > maxW then
      x = MARGIN
      row = row + 1
    end
    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", x, -(HEADER_HEIGHT + row * TAB_HEIGHT))
    x = x + width + 4
  end
  tabRows = row + 1
end

local function createWindow()
  local w, h = tabSize()
  window = CreateFrame("Frame", "UsefulPlatesAndTooltipsSettings", UIParent, "ButtonFrameTemplate")
  if type(ButtonFrameTemplate_HidePortrait) == "function" then ButtonFrameTemplate_HidePortrait(window) end
  if type(window.Inset) == "table" then window.Inset:Hide() end
  window:Hide()
  window:SetSize(w + 2 * MARGIN, HEADER_HEIGHT + TAB_HEIGHT + SWITCH_HEIGHT + h + MARGIN)
  window:SetFrameStrata("DIALOG")
  window:SetToplevel(true)
  window:SetClampedToScreen(true)
  window:EnableMouse(true)
  window:SetMovable(true)
  window:RegisterForDrag("LeftButton")
  window:SetScript("OnDragStart", window.StartMoving)
  window:SetScript("OnDragStop", function(self)
    if type(self.StopMovingOrSizing) == "function" then self:StopMovingOrSizing() end
    rememberWindowPoint()
  end)
  applyWindowPoint()
  UI.CloseOnEscape(window, function(self)
    if BIT.Looks and type(BIT.Looks.IsPickListShown) == "function" and BIT.Looks.IsPickListShown() then
      BIT.Looks.ClosePickList()
      return
    end
    self:Hide()
  end)

  window:SetTitle("DoesItDiePlus")
  local close = window.CloseButton
  if type(close) ~= "table" then
    close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)
  end
  close:SetScript("OnClick", function() window:Hide() end)

  -- Active profile badge on the left of the title bar; clicking opens the Profiles tab.
  if BIT.Profiles and BIT.tabs.Profiles then
    local function truncateUtf8(str, maxChars)
      local chars, i, n = 0, 1, #str
      while i <= n do
        chars = chars + 1
        if chars > maxChars then return str:sub(1, i - 1) .. "..." end
        local b = str:byte(i)
        if b < 128 then i = i + 1
        elseif b < 224 then i = i + 2
        elseif b < 240 then i = i + 3
        else i = i + 4 end
      end
      return str
    end
    local function profileDisplay(name)
      return name == BIT.Profiles.DEFAULT and BIT.L("Default (shared)") or name
    end
    local function profileButtonText()
      local active = BIT.Profiles.Active()
      local shown = active == BIT.Profiles.DEFAULT and BIT.L("Default") or active
      shown = truncateUtf8(shown, 15)
      local suffix = BIT.Profiles.PendingReload() and " *" or ""
      return string.format(BIT.L("Profile: %s"), shown) .. suffix
    end
    local profileBtn = UI.Button(window, "", 165, function()
      selectTab("Profiles")
    end)
    profileBtn:SetHeight(20)
    profileBtn:SetPoint("TOPLEFT", window, "TOPLEFT", 10, -4)
    profileBtn:SetText(profileButtonText())
    profileBtn:HookScript("OnEnter", function(self)
      if not GameTooltip then return end
      GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
      GameTooltip:SetText(BIT.L("Profiles"), 1, 0.82, 0)
      GameTooltip:AddLine(string.format(BIT.L("Active profile: %s"), profileDisplay(BIT.Profiles.Active())), 1, 1, 1, true)
      if BIT.Profiles.Selected() ~= BIT.Profiles.Active() then
        GameTooltip:AddLine(string.format(BIT.L("After reload: %s"), profileDisplay(BIT.Profiles.Selected())), 1, 0.82, 0.2, true)
      elseif BIT.Profiles.PendingReload() then
        GameTooltip:AddLine(BIT.L("Changes take effect after a reload of the interface."), 1, 0.82, 0.2, true)
      end
      GameTooltip:AddLine(BIT.L("Click to manage character profiles and enabled modules."), 0.85, 0.85, 0.85, true)
      GameTooltip:Show()
    end)
    profileBtn:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    window.profileButton = profileBtn
    window.refreshProfileButton = function() profileBtn:SetText(profileButtonText()) end
  end

  -- Global art style selector (Stylized 2D / Pixel Art / Classic): updates HUD and open previews live.
  if BIT.Art and BIT.Looks and BIT.Looks.PickList then
    local function artButtonText()
      return string.format(BIT.L("Style: %s"), BIT.Art.Label())
    end
    local artBtn = UI.DropdownButton(window, 152, function(self)
      BIT.Looks.PickList(self, BIT.Art.List(), BIT.Art.Get(), function(id)
        BIT.Art.Set(id)
        self:SetLabel(artButtonText())
      end)
    end)
    artBtn:SetHeight(20)
    if window.profileButton then
      artBtn:SetPoint("LEFT", window.profileButton, "RIGHT", 6, 0)
    else
      artBtn:SetPoint("TOPLEFT", window, "TOPLEFT", 10, -4)
    end
    artBtn:SetLabel(artButtonText())
    artBtn:HookScript("OnEnter", function(self)
      if not GameTooltip then return end
      GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
      GameTooltip:SetText(BIT.L("Art style"), 1, 0.82, 0)
      GameTooltip:AddLine(BIT.L("Switches Soul Shards, combo orbs, range marks, upgrade arrows and markers between Stylized 2D, Pixel Art and Classic. Takes effect at once."), 0.9, 0.9, 0.9, true)
      GameTooltip:Show()
    end)
    artBtn:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    window.artButton = artBtn
    window.refreshArtButton = function() artBtn:SetLabel(artButtonText()) end
    BIT.Art.Subscribe(function()
      if window and window.refreshArtButton then window.refreshArtButton() end
    end)
  end

  -- The language of the settings, tooltips and chat lines. Its own label is not translated on purpose: whoever lands in a
  -- language they cannot read must still find it. The change applies after a reload, offered next to it.
  local language = UI.DropdownButton(window, 156, function(self)
    local Looks = BIT.Looks
    if not (Looks and Looks.PickList) then return end
    Looks.PickList(self, BIT.LanguageList(), BIT.LanguageChoice(), function(id)
      BIT.SetLanguage(id)
      self:SetLabel("Language: " .. BIT.LanguageLabel())
      window.languageReload:Show()
    end)
  end)
  language:SetHeight(20)
  language:SetPoint("TOPRIGHT", close, "TOPLEFT", -4, -3)
  language:SetLabel("Language: " .. BIT.LanguageLabel())
  language:HookScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetText("Language", 1, 1, 1)
    GameTooltip:AddLine(BIT.L("The language of the settings, tooltips and chat lines of this addon. It changes after a "
      .. "reload. Auto follows the game's language."), 0.9, 0.9, 0.9, true)
    GameTooltip:Show()
  end)
  language:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  window.languageButton = language
  local reload = UI.Button(window, "Reload UI", 100, function()
    if type(ReloadUI) == "function" then ReloadUI() end
  end)
  reload:SetHeight(20)
  reload:SetPoint("TOPRIGHT", language, "TOPLEFT", -4, 0)
  reload:Hide()
  window.languageReload = reload

  for _, name in ipairs(hubOrder()) do
    local tab = BIT.tabs[name] or {}
    local extra
    if name == "HunterRangeFinder" and playerClass() ~= "HUNTER" then
      extra = BIT.L("Hunter only. Settings are here for an alt.")
    end
    addTabButton(name, pageName(name, tab), pageName(name, tab), BIT.L(tab.summary), extra)
  end
  layoutTabs()
  local tabRule = window:CreateTexture(nil, "ARTWORK")
  local td = UI.COLOR.divider
  tabRule:SetColorTexture(td[1], td[2], td[3], td[4])
  tabRule:SetHeight(1)
  tabRule:SetPoint("TOPLEFT", MARGIN, -(headerBottom() - 1))
  tabRule:SetPoint("TOPRIGHT", -MARGIN, -(headerBottom() - 1))
  window.baseHeight = HEADER_HEIGHT + TAB_HEIGHT * tabRows + SWITCH_HEIGHT + h + MARGIN
  -- The gamepad hint line below the pages adds to the window instead of taking from the pages,
  -- so a controller does not cut the bottom of every tab.
  window.fit = function(extra)
    window:SetHeight(window.baseHeight + (extra or 0))
    window:SetScale(math.min(1, (UIParent:GetWidth() - 24) / window:GetWidth(),
      (UIParent:GetHeight() - 24) / window:GetHeight()))
  end
  window.fit(0)

  if BIT.GamePadUI then
    local pad = BIT.GamePadUI
    local hint = window:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("BOTTOMLEFT", 12, 3)
    hint:SetPoint("BOTTOMRIGHT", -12, 3)
    hint:SetJustifyH("LEFT")
    local function refreshHints()
      local enabled = C_GamePad and C_GamePad.IsEnabled and C_GamePad.IsEnabled()
        or GetCVarBool and GetCVarBool("GamePadEnable")
      hint:SetText(enabled and (pad.Hint() .. " · " .. string.format(BIT.L("%s/%s: tabs"),
        pad.Key("PADLSHOULDER"), pad.Key("PADRSHOULDER"))) or "")
      hint:SetWordWrap(true)
      local padding = enabled and math.max(32, hint:GetStringHeight() + 8) or 0
      window.gamepadPadding = padding
      window.fit(padding)
      for _, page in pairs(pages) do page:SetPoint("BOTTOMRIGHT", -MARGIN, MARGIN + padding) end
    end
    window.refreshGamePadHints = refreshHints
    local events = CreateFrame("Frame", nil, window)
    for _, event in ipairs({ "UPDATE_BINDINGS", "CVAR_UPDATE", "GAME_PAD_ACTIVE_CHANGED", "GAME_PAD_CONFIGS_CHANGED" }) do
      pcall(events.RegisterEvent, events, event)
    end
    events:SetScript("OnEvent", refreshHints)
    window:HookScript("OnShow", refreshHints)
    pad.Attach(window, function(self, key)
      if key == "PAD2" then
        if BIT.Looks and type(BIT.Looks.IsPickListShown) == "function" and BIT.Looks.IsPickListShown() then
          BIT.Looks.ClosePickList()
        else
          self:Hide()
        end
        return true
      end
      if key == "PADLSHOULDER" or key == "PADRSHOULDER" then
        local index, order = 1, hubOrder()
        for i, name in ipairs(order) do if name == current then index = i end end
        selectTab(order[(index - 1 + (key == "PADLSHOULDER" and -1 or 1)) % #order + 1])
        return true
      end
      return pad.Navigate(self, key)
    end)
  end

  window:HookScript("OnShow", function()
    if current and pages[current] then
      refreshSwitch(pages[current])
    end
    if type(window.refreshProfileButton) == "function" then window.refreshProfileButton() end
    if type(window.refreshArtButton) == "function" then window.refreshArtButton() end
  end)
end

-- Keeps the header profile badge and every already-built module tab's Enable switch in sync
-- after changes made on the Profiles tab.
function BIT.RefreshSettingsChrome()
  if not window then return end
  if type(window.refreshProfileButton) == "function" then window.refreshProfileButton() end
  for _, page in pairs(pages) do refreshSwitch(page) end
end

-- Opens the window, on a module's tab when name is given; a second call without a name closes it.
-- A second call with the SAME tab name closes it too (the README's "type it again to hide").
function BIT.OpenSettings(name)
  if not window then createWindow() end
  if name and BIT.tabs[name] then
    if window:IsShown() and current == name then
      window:Hide()
      return
    end
    selectTab(name)
    window:Show()
    return
  end
  if window:IsShown() then
    window:Hide()
    return
  end
  selectTab(current or hubOrder()[1])
  window:Show()
end

---------------------------------------------------------------------------------------------
-- /upt, and a page in Options > AddOns
---------------------------------------------------------------------------------------------

BIT.commands = {} -- word -> function(rest), from the modules (/upt probe)

function BIT.RegisterCommand(word, fn) BIT.commands[word] = fn end

BINDING_HEADER_USEFULPLATESANDTOOLTIPS = "DoesItDiePlus"
BINDING_NAME_USEFULPLATESANDTOOLTIPS_SETTINGS = "Open settings"
function UsefulPlatesAndTooltips_ToggleSettings() BIT.OpenSettings() end

BIT.RegisterCommand("art", function(rest)
  if not BIT.Art then return end
  local choice = type(rest) == "string" and rest:match("^%s*(%S+)") or nil
  choice = choice and choice:lower() or nil
  if choice == "2d" or choice == "3d" or choice == "pixel" or choice == "classic" then
    BIT.Art.Set(choice)
    BIT.Say(string.format(BIT.L("Art style: %s."), BIT.Art.Label()))
    return
  end
  BIT.Say(string.format(BIT.L("Art style: %s. /upt art 2d | pixel | classic"), BIT.Art.Label()))
end)

-- Short names for the tabs: /upt sdi, /upt did, /upt stats, /upt ding, /upt range
BIT.tabWords = {}

local function slash(msg)
  msg = type(msg) == "string" and msg or ""
  local word, rest = msg:match("^%s*(%S*)%s*(.-)%s*$")
  word = (word or ""):lower()
  if word == "" then BIT.OpenSettings() return end
  if BIT.commands[word] then BIT.commands[word](rest) return end
  for _, name in ipairs(BIT.order) do
    if word == name:lower() or BIT.tabWords[word] == name then BIT.OpenSettings(name) return end
  end
  BIT.Say(string.format(BIT.L("/upt opens the settings; /upt <part> opens a part's tab (%s); /upt probe records what StatsInfo can read; /upt lang sets the language."),
    table.concat(BIT.order, ", ")))
end

SLASH_USEFULPLATESANDTOOLTIPS1 = "/upt"
SLASH_USEFULPLATESANDTOOLTIPS2 = "/usefulplates"
if type(SlashCmdList) == "table" then SlashCmdList.USEFULPLATESANDTOOLTIPS = slash end

local function registerOptionsPage()
  local function openSettings()
    -- Keep Blizzard's panel open so its native gamepad binding teardown stays native, and defer
    -- opening our window to the next frame so frame creation never runs inside SettingsPanel's click.
    local function show()
      if not (window and window:IsShown()) then BIT.OpenSettings() end
    end
    if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
      C_Timer.After(0, show)
    else
      show()
    end
  end
  if UI.RegisterSettingsLauncher("DoesItDiePlus",
      BIT.L("Open the settings window. You can also type /upt."), openSettings) then return end
  local panel = CreateFrame("Frame")
  local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("DoesItDiePlus")
  local text = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
  text:SetText(BIT.L("The settings have their own window. You can also type /upt."))
  local open = UI.Button(panel, BIT.L("Open settings"), 180, openSettings)
  open:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -14)
  if type(Settings) == "table" and type(Settings.RegisterCanvasLayoutCategory) == "function"
    and type(Settings.RegisterAddOnCategory) == "function" then
    Settings.RegisterAddOnCategory(Settings.RegisterCanvasLayoutCategory(panel, "DoesItDiePlus"))
  elseif type(InterfaceOptions_AddCategory) == "function" then
    panel.name = "DoesItDiePlus"
    InterfaceOptions_AddCategory(panel)
  end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self)
  BINDING_NAME_USEFULPLATESANDTOOLTIPS_SETTINGS = BIT.L("Open settings") -- the saved language is known only from ADDON_LOADED on
  local ok, err = pcall(registerOptionsPage)
  if not ok then BIT.Say("Options > AddOns page not added (" .. tostring(err) .. "); /upt still opens the settings.") end
  self:UnregisterAllEvents()
end)
