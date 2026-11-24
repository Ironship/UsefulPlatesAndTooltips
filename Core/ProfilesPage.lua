-- UsefulPlatesAndTooltips: the Profiles page of the settings window (/upt profile).
-- Lets each character use either the shared Default profile, its own character profile,
-- or any named profile, and toggle which modules run in the active profile from one place.
-- Copyright (c) 2026 Ironship. GPL-3.0-or-later, see LICENSE.

local _, BIT = ...
if not BIT or not BIT.RegisterTab or not BIT.Profiles then return end

local Profiles = BIT.Profiles
local ROW = 26

local function tell(text)
  if BIT.Say then BIT.Say(text) end
end

local function reloadNow(fallbackMessage)
  if BIT.UI and type(BIT.UI.RequestReload) == "function" then
    return BIT.UI.RequestReload(fallbackMessage)
  end
  if fallbackMessage then tell(fallbackMessage) end
  return false
end

local function labelForProfile(name)
  if name == Profiles.DEFAULT then return BIT.L("Default (shared)") end
  return name
end

local function fitButton(btn, minW)
  local fs = btn and type(btn.GetFontString) == "function" and btn:GetFontString() or nil
  local w = fs and type(fs.GetStringWidth) == "function" and fs:GetStringWidth() or 0
  btn:SetWidth(math.max(minW or 72, math.ceil(w) + 22))
  return btn
end

local function confirmPopup(key, text, buttonText, onAccept)
  if BIT.UI and type(BIT.UI.Confirm) == "function" then
    BIT.UI.Confirm(BIT.L("Profiles"), text, buttonText, onAccept)
    return
  end
  onAccept()
end

local function anyModulePending()
  if type(BIT.HubModuleOrder) ~= "function" then return false end
  for _, name in ipairs(BIT.HubModuleOrder()) do
    if (BIT.state[name] == "on") ~= BIT.IsSwitchedOn(name) then return true end
  end
  return false
end

local function build(content)
  local UI = BIT.UI
  local Looks = BIT.Looks
  local Rows = Looks and Looks.Rows
  local y = 8
  local refreshAll

  local note = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  note:SetPoint("TOPLEFT", 10, -y)
  note:SetPoint("RIGHT", -10, 0)
  note:SetJustifyH("LEFT")
  note:SetText(BIT.L("Profiles save which modules are enabled and all module settings (appearance, frames and options). "
    .. "Learned combat data and language are kept across profiles. Switching profiles reloads the interface."))
  y = y + math.max(28, (note:GetStringHeight() or 24) + 10)

  -- Status summary: character + active profile + pending reload button
  local statusBox = CreateFrame("Frame", nil, content, BackdropTemplateMixin and "BackdropTemplate" or nil)
  statusBox:SetPoint("TOPLEFT", 10, -y)
  statusBox:SetPoint("RIGHT", -10, 0)
  statusBox:SetHeight(54)
  UI.Backdrop(statusBox, 0.09)

  local statusReload = fitButton(UI.Button(statusBox, BIT.L("Reload UI"), 110, reloadNow), 100)
  statusReload:SetPoint("RIGHT", -10, 0)
  statusReload:Hide()

  local charLine = statusBox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  charLine:SetPoint("TOPLEFT", 10, -8)
  charLine:SetPoint("RIGHT", statusReload, "LEFT", -8, 0)
  charLine:SetJustifyH("LEFT")

  local activeLine = statusBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  activeLine:SetPoint("TOPLEFT", 10, -28)
  activeLine:SetPoint("RIGHT", statusReload, "LEFT", -8, 0)
  activeLine:SetJustifyH("LEFT")
  y = y + 62

  local card = CreateFrame("Frame", nil, content, BackdropTemplateMixin and "BackdropTemplate" or nil)
  card:SetPoint("TOPLEFT", 10, -y)
  card:SetPoint("RIGHT", -10, 0)
  UI.Backdrop(card, 0.09)
  local cardTop = y
  local cy = 10

  -------------------------------------------------------------------------------------------
  -- Section 1: This character
  -------------------------------------------------------------------------------------------
  local h1 = UI.Header(card, "THIS CHARACTER")
  cy = UI.PlaceRow(h1, cy, 24)

  local activeRow = Rows.Row(card, "Active profile", {
    tooltip = "Which profile this character uses. Default is shared across characters; choose this character's "
      .. "name or create a named profile for separate settings and enabled modules.",
  })
  local activeBtn = UI.DropdownButton(activeRow, activeRow.layout.control + 20, function(self)
    if not (Looks and Looks.PickList) then return end
    local charKey = Profiles.CharacterKey()
    local list = {}
    local seenChar = false
    for _, name in ipairs(Profiles.List()) do
      if name == charKey then seenChar = true end
      list[#list + 1] = { id = name, label = labelForProfile(name), literal = true }
    end
    if charKey and not seenChar then
      table.insert(list, 2, {
        id = charKey,
        label = string.format(BIT.L("%s (new character profile)"), charKey),
        literal = true,
      })
    end
    Looks.PickList(self, list, Profiles.Selected(), function(chosen)
      if chosen == Profiles.Selected() then return end
      if chosen == Profiles.Active() then
        local ok = Profiles.Use(chosen)
        if ok and not Profiles.PendingReload() then
          refreshAll()
          return
        end
      end
      local isNew = not Profiles.Exists(chosen)
      local prompt = isNew
        and string.format(BIT.L("Create a separate profile for %s (copying current settings) and reload the interface?"), chosen)
        or string.format(BIT.L("Switch this character to profile \"%s\" and reload the interface?"), labelForProfile(chosen))
      confirmPopup("UPT_SWITCH_PROFILE", prompt, BIT.L("Switch & reload"), function()
        local ok, info = Profiles.Use(chosen, { create = true, copyFromCurrent = true })
        if not ok then
          tell(string.format(BIT.L("Could not switch profile (%s)."), tostring(info)))
          return
        end
        refreshAll()
        reloadNow(string.format(BIT.L("Selected profile \"%s\". Use /reload to apply."), labelForProfile(chosen)))
      end)
    end)
  end)
  activeBtn:SetPoint("LEFT", activeRow, "LEFT", activeRow.layout.label, 0)
  activeRow:SetPoint("TOPLEFT", 0, -cy)
  cy = cy + ROW + 2

  -- One-click shortcut between shared Default and this character's own profile.
  local quickRow = CreateFrame("Frame", nil, card)
  quickRow:SetHeight(26)
  local quickBtn = UI.Button(quickRow, "", 280, function()
    local charKey = Profiles.CharacterKey()
    if not charKey then return end
    if Profiles.Selected() == charKey then
      if Profiles.Active() == Profiles.DEFAULT then
        local ok = Profiles.Use(Profiles.DEFAULT)
        if ok and not Profiles.PendingReload() then refreshAll() return end
      end
      confirmPopup("UPT_USE_DEFAULT_PROFILE",
        string.format(BIT.L("Switch %s back to the shared Default profile and reload the interface?"), charKey),
        BIT.L("Switch & reload"), function()
          Profiles.Use(Profiles.DEFAULT)
          refreshAll()
          reloadNow(BIT.L("Selected the shared Default profile. Use /reload to apply."))
        end)
    else
      if Profiles.Active() == charKey then
        local ok = Profiles.Use(charKey)
        if ok and not Profiles.PendingReload() then refreshAll() return end
      end
      local exists = Profiles.Exists(charKey)
      local prompt = exists
        and string.format(BIT.L("Switch %s to its own profile \"%s\" and reload the interface?"), charKey, charKey)
        or string.format(BIT.L("Create a separate profile for %s (copying current settings) and reload the interface?"), charKey)
      confirmPopup("UPT_USE_CHAR_PROFILE", prompt, BIT.L("Switch & reload"), function()
        Profiles.Use(charKey, { create = true, copyFromCurrent = true })
        refreshAll()
        reloadNow(string.format(BIT.L("Selected profile \"%s\". Use /reload to apply."), charKey))
      end)
    end
  end)
  quickBtn:SetPoint("LEFT", quickRow, "LEFT", activeRow.layout.label - 6, 0)
  cy = UI.PlaceRow(quickRow, cy, 32)

  -- Global art style selector (Stylized 2D / Pixel Art / Classic): reachable via Gamepad and synced live with header & /upt art.
  local artBtn
  if BIT.Art and Looks and Looks.PickList then
    local artRow = Rows.Row(card, "Art style", {
      tooltip = "Switches Soul Shards, combo orbs, range marks, upgrade arrows and markers between Stylized 2D, Pixel Art and Classic. Takes effect at once.",
    })
    artBtn = UI.DropdownButton(artRow, activeRow.layout.control + 20, function(self)
      Looks.PickList(self, BIT.Art.List(), BIT.Art.Get(), function(id)
        BIT.Art.Set(id)
        self:SetLabel(BIT.Art.Label())
      end)
    end)
    artBtn:SetPoint("LEFT", artRow, "LEFT", artRow.layout.label, 0)
    artBtn:SetLabel(BIT.Art.Label())
    artRow:SetPoint("TOPLEFT", 0, -cy)
    cy = cy + ROW + 6
    BIT.Art.Subscribe(function()
      if artBtn then artBtn:SetLabel(BIT.Art.Label()) end
    end)
  end

  -------------------------------------------------------------------------------------------
  -- Section 2: Modules in this profile (quick toggle checklist)
  -------------------------------------------------------------------------------------------
  local h2 = UI.Header(card, "MODULES IN THIS PROFILE")
  cy = UI.PlaceRow(h2, cy, 24)

  local modHintRow = CreateFrame("Frame", nil, card)
  modHintRow:SetHeight(16)
  local modHint = modHintRow:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  modHint:SetPoint("LEFT", 0, 0)
  modHint:SetPoint("RIGHT", 0, 0)
  modHint:SetJustifyH("LEFT")
  cy = UI.PlaceRow(modHintRow, cy, 18)

  local modBar = CreateFrame("Frame", nil, card)
  modBar:SetHeight(24)
  local enableAll = fitButton(UI.Button(modBar, BIT.L("Enable all"), 92, function()
    for _, modName in ipairs(BIT.HubModuleOrder()) do BIT.SetSwitchedOn(modName, true) end
    if BIT.RefreshSettingsChrome then BIT.RefreshSettingsChrome() end
    refreshAll()
  end), 92)
  enableAll:SetPoint("LEFT", 0, 0)

  local disableAll = fitButton(UI.Button(modBar, BIT.L("Disable all"), 92, function()
    for _, modName in ipairs(BIT.HubModuleOrder()) do BIT.SetSwitchedOn(modName, false) end
    if BIT.RefreshSettingsChrome then BIT.RefreshSettingsChrome() end
    refreshAll()
  end), 92)
  disableAll:SetPoint("LEFT", enableAll, "RIGHT", 6, 0)

  local modReload = fitButton(UI.Button(modBar, BIT.L("Reload UI"), 96, reloadNow), 96)
  modReload:SetPoint("RIGHT", 0, 0)
  modReload:Hide()
  cy = UI.PlaceRow(modBar, cy, 28)

  local modNames = type(BIT.HubModuleOrder) == "function" and BIT.HubModuleOrder() or {}
  local modChecks = {}
  local cols = 2
  local colW = 260
  local gridRows = math.ceil(#modNames / cols)
  local grid = CreateFrame("Frame", nil, card)
  grid:SetHeight(math.max(26, gridRows * 26))
  for i, modName in ipairs(modNames) do
    local col = (i - 1) % cols
    local row = math.floor((i - 1) / cols)
    local tab = BIT.tabs[modName] or {}
    local label = type(BIT.ModuleDisplayName) == "function" and BIT.ModuleDisplayName(modName) or modName
    local box = UI.Check(grid, label,
      function() return BIT.IsSwitchedOn(modName) end,
      function(v)
        BIT.SetSwitchedOn(modName, v)
        if BIT.RefreshSettingsChrome then BIT.RefreshSettingsChrome() end
        refreshAll()
      end, tab.summary, true)
    box:SetPoint("TOPLEFT", col * colW, -row * 26)
    modChecks[#modChecks + 1] = { name = modName, box = box }
  end
  cy = UI.PlaceRow(grid, cy, grid:GetHeight() + 10)

  -------------------------------------------------------------------------------------------
  -- Section 3: Manage profiles (new, copy from, delete, reset)
  -------------------------------------------------------------------------------------------
  local h3 = UI.Header(card, "MANAGE PROFILES")
  cy = UI.PlaceRow(h3, cy, 24)

  -- New named profile
  local newRow = Rows.Row(card, "New profile", {
    tooltip = "Create a named profile (e.g. Healer, Tank, Alt) and switch this character to it.",
  })
  local newBox = UI.EditBox(newRow, 160, 22)
  newBox:SetPoint("LEFT", newRow, "LEFT", newRow.layout.label, 0)
  newBox:SetMaxLetters(48)
  newBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  newBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

  local function createAndSwitch(copyCurrent)
    local raw = Profiles.SanitizeName(newBox:GetText())
    if not raw then
      tell(BIT.L("Enter a profile name first."))
      return
    end
    if Profiles.Exists(raw) then
      tell(string.format(BIT.L("A profile named \"%s\" already exists."), raw))
      return
    end
    local prompt = copyCurrent
      and string.format(BIT.L("Create profile \"%s\" (copying current settings), switch this character to it and reload?"), raw)
      or string.format(BIT.L("Create blank profile \"%s\" (defaults), switch this character to it and reload?"), raw)
    confirmPopup("UPT_CREATE_PROFILE", prompt, BIT.L("Create & reload"), function()
      local ok, err = Profiles.Use(raw, { create = true, copyFromCurrent = copyCurrent })
      if not ok then
        tell(string.format(BIT.L("Could not create profile (%s)."), tostring(err)))
        return
      end
      newBox:SetText("")
      refreshAll()
      reloadNow(string.format(BIT.L("Selected profile \"%s\". Use /reload to apply."), raw))
    end)
  end

  local copyCreateBtn = fitButton(UI.Button(newRow, BIT.L("Copy current"), 100, function() createAndSwitch(true) end), 100)
  copyCreateBtn:SetPoint("LEFT", newBox, "RIGHT", 6, 0)
  local blankCreateBtn = fitButton(UI.Button(newRow, BIT.L("Blank"), 68, function() createAndSwitch(false) end), 68)
  blankCreateBtn:SetPoint("LEFT", copyCreateBtn, "RIGHT", 6, 0)
  newRow:SetPoint("TOPLEFT", 0, -cy)
  cy = cy + ROW + 2

  -- Copy settings from another profile into the selected profile
  local copySource
  local copyRow = Rows.Row(card, "Copy settings from", {
    tooltip = "Overwrite this profile's settings with a copy from another profile (keeps learned combat data).",
  })
  local copyPickBtn = UI.DropdownButton(copyRow, 200, function(self)
    if not (Looks and Looks.PickList) then return end
    local selected = Profiles.Selected()
    local list = {}
    for _, name in ipairs(Profiles.List()) do
      if name ~= selected then list[#list + 1] = { id = name, label = labelForProfile(name), literal = true } end
    end
    if #list == 0 then return end
    Looks.PickList(self, list, copySource, function(chosen)
      copySource = chosen
      refreshAll()
    end)
  end)
  copyPickBtn:SetPoint("LEFT", copyRow, "LEFT", copyRow.layout.label, 0)
  local copyDoBtn = fitButton(UI.Button(copyRow, BIT.L("Copy"), 72, function()
    if not copySource or not Profiles.Exists(copySource) or copySource == Profiles.Selected() then return end
    confirmPopup("UPT_COPY_PROFILE",
      string.format(BIT.L("Copy all settings from \"%s\" into \"%s\" and reload the interface? Learned combat data is kept."),
        labelForProfile(copySource), labelForProfile(Profiles.Selected())),
      BIT.L("Copy & reload"), function()
        local ok, err = Profiles.CopyFrom(copySource)
        if not ok then
          tell(string.format(BIT.L("Could not copy profile (%s)."), tostring(err)))
          return
        end
        refreshAll()
        reloadNow(string.format(BIT.L("Copied settings from \"%s\" into \"%s\". Use /reload to apply."),
          labelForProfile(copySource), labelForProfile(Profiles.Selected())))
      end)
  end), 72)
  copyDoBtn:SetPoint("LEFT", copyPickBtn, "RIGHT", 6, 0)
  copyRow:SetPoint("TOPLEFT", 0, -cy)
  cy = cy + ROW + 2

  -- Delete an unused profile
  local deleteTarget
  local delRow = Rows.Row(card, "Delete profile", {
    tooltip = "Remove a profile that is not currently in use. Default cannot be deleted.",
  })
  local delPickBtn = UI.DropdownButton(delRow, 200, function(self)
    if not (Looks and Looks.PickList) then return end
    local active, selected = Profiles.Active(), Profiles.Selected()
    local list = {}
    for _, name in ipairs(Profiles.List()) do
      if name ~= Profiles.DEFAULT and name ~= active and name ~= selected then
        list[#list + 1] = { id = name, label = name, literal = true }
      end
    end
    if #list == 0 then return end
    Looks.PickList(self, list, deleteTarget, function(chosen)
      deleteTarget = chosen
      refreshAll()
    end)
  end)
  delPickBtn:SetPoint("LEFT", delRow, "LEFT", delRow.layout.label, 0)
  local delDoBtn = fitButton(UI.Button(delRow, BIT.L("Delete"), 72, function()
    if not deleteTarget or not Profiles.Exists(deleteTarget) then return end
    local victim = deleteTarget
    confirmPopup("UPT_DELETE_PROFILE",
      string.format(BIT.L("Delete profile \"%s\"? Any character using it will fall back to Default."), victim),
      BIT.L("Delete"), function()
        local ok, err = Profiles.Delete(victim)
        if ok then
          deleteTarget = nil
          tell(string.format(BIT.L("Deleted profile \"%s\"."), victim))
          refreshAll()
        else
          tell(string.format(BIT.L("Could not delete profile (%s)."), tostring(err)))
        end
      end)
  end), 72)
  delDoBtn:SetPoint("LEFT", delPickBtn, "RIGHT", 6, 0)
  delRow:SetPoint("TOPLEFT", 0, -cy)
  cy = cy + ROW + 10

  -- Reset current profile
  local resetBtn = Looks.ResetButton(card, function()
    local target = Profiles.Selected()
    confirmPopup("UPT_RESET_PROFILE",
      string.format(BIT.L("Reset all settings in profile \"%s\" to defaults and reload? Learned combat data is kept."),
        labelForProfile(target)),
      BIT.L("Reset profile"), function()
        Profiles.Reset(target)
        if target == Profiles.Active() and BIT.Art and type(BIT.Art.Set) == "function" then
          BIT.Art.Set("2d")
        end
        refreshAll()
        reloadNow(string.format(BIT.L("Profile \"%s\" reset to defaults. Type /reload to apply."), labelForProfile(target)))
      end)
  end, 160)
  resetBtn:SetText(BIT.L("Reset profile"))
  fitButton(resetBtn, 160)
  resetBtn:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -10, 10)
  card:SetHeight(cy + 34)
  y = cardTop + card:GetHeight()

  refreshAll = function()
    local charKey = Profiles.CharacterKey()
    local active = Profiles.Active()
    local selected = Profiles.Selected()
    local pendingProfile = Profiles.PendingReload()
    local pendingMods = anyModulePending()

    charLine:SetText(string.format(BIT.L("Character: %s"), charKey or BIT.L("Unknown")))
    if active ~= selected then
      activeLine:SetText(string.format(BIT.L("Active: %s  ->  After reload: %s"),
        labelForProfile(active), labelForProfile(selected)))
    else
      activeLine:SetText(string.format(BIT.L("Active profile: %s"), labelForProfile(active)))
    end
    statusReload:SetShown(pendingProfile or pendingMods)

    activeBtn:SetLabel(labelForProfile(selected))
    if artBtn and BIT.Art then artBtn:SetLabel(BIT.Art.Label()) end
    if charKey then
      quickBtn:Show()
      if selected == charKey then
        quickBtn:SetText(BIT.L("Switch back to Default (shared)"))
      elseif Profiles.Exists(charKey) then
        quickBtn:SetText(string.format(BIT.L("Use %s's profile"), charKey))
      else
        quickBtn:SetText(BIT.L("Use separate profile for this character"))
      end
      fitButton(quickBtn, 240)
    else
      quickBtn:Hide()
    end

    modHint:SetText(pendingProfile
      and BIT.L("Reload UI to edit the newly selected profile.")
      or (pendingMods and BIT.L("Changes take effect after a reload of the interface.")
        or BIT.L("Tick which modules run in this profile.")))
    modReload:SetShown(pendingMods or pendingProfile)
    grid:SetAlpha(pendingProfile and 0.45 or 1)
    enableAll:SetEnabled(not pendingProfile)
    disableAll:SetEnabled(not pendingProfile)
    for _, entry in ipairs(modChecks) do
      entry.box:Refresh()
      entry.box:EnableMouse(not pendingProfile)
      if type(entry.box.SetEnabled) == "function" then entry.box:SetEnabled(not pendingProfile) end
    end

    -- Refresh Copy-from picker
    local copyCandidates = {}
    for _, name in ipairs(Profiles.List()) do
      if name ~= selected then copyCandidates[#copyCandidates + 1] = name end
    end
    if not copySource or copySource == selected or not Profiles.Exists(copySource) then
      copySource = copyCandidates[1]
    end
    local hasCopy = copySource ~= nil
    copyPickBtn:SetLabel(hasCopy and labelForProfile(copySource) or BIT.L("(no other profiles)"))
    copyPickBtn:SetEnabled(hasCopy)
    copyDoBtn:SetEnabled(hasCopy)

    -- Refresh Delete picker
    local delCandidates = {}
    for _, name in ipairs(Profiles.List()) do
      if name ~= Profiles.DEFAULT and name ~= active and name ~= selected then
        delCandidates[#delCandidates + 1] = name
      end
    end
    if not deleteTarget or deleteTarget == Profiles.DEFAULT or deleteTarget == active
        or deleteTarget == selected or not Profiles.Exists(deleteTarget) then
      deleteTarget = delCandidates[1]
    end
    local hasDel = deleteTarget ~= nil
    delPickBtn:SetLabel(hasDel and deleteTarget or BIT.L("(none to delete)"))
    delPickBtn:SetEnabled(hasDel)
    delDoBtn:SetEnabled(hasDel)

    if BIT.RefreshSettingsChrome then BIT.RefreshSettingsChrome() end
  end

  content:SetScript("OnShow", refreshAll)
  refreshAll()
  content:SetHeight(y + 12)
end

-- /upt profile [list|char|default|use <name>|new <name>|copy <name>|delete <name>]
if BIT.RegisterCommand then
  BIT.RegisterCommand("profile", function(rest)
    local sub, arg = (rest or ""):match("^%s*(%S*)%s*(.-)%s*$")
    sub = (sub or ""):lower()
    if sub == "" then
      if BIT.OpenSettings then BIT.OpenSettings("Profiles") end
      return
    end
    if sub == "list" then
      local active, selected = Profiles.Active(), Profiles.Selected()
      local parts = {}
      for _, name in ipairs(Profiles.List()) do
        local tag = (name == active and " [active]" or "") .. (name ~= active and name == selected and " [after reload]" or "")
        parts[#parts + 1] = name .. tag
      end
      tell(string.format(BIT.L("Profiles: %s"), table.concat(parts, ", ")))
      return
    elseif sub == "char" then
      local charKey = Profiles.CharacterKey()
      if not charKey then tell(BIT.L("Character name is unavailable.")) return end
      local ok, created = Profiles.Use(charKey, { create = true, copyFromCurrent = true })
      if ok then
        tell(string.format(BIT.L(created
          and "Created and selected profile \"%s\" (copied from current). Use /reload to apply."
          or "Selected profile \"%s\". Use /reload to apply."), charKey))
        if BIT.RefreshSettingsChrome then BIT.RefreshSettingsChrome() end
      end
      return
    elseif sub == "default" then
      Profiles.Use(Profiles.DEFAULT)
      tell(BIT.L("Selected the shared Default profile. Use /reload to apply."))
      if BIT.RefreshSettingsChrome then BIT.RefreshSettingsChrome() end
      return
    elseif sub == "use" and arg ~= "" then
      local ok, err = Profiles.Use(arg)
      if ok then
        tell(string.format(BIT.L("Selected profile \"%s\". Use /reload to apply."), Profiles.Selected()))
        if BIT.RefreshSettingsChrome then BIT.RefreshSettingsChrome() end
      else
        tell(string.format(BIT.L("Could not switch profile (%s)."), tostring(err)))
      end
      return
    elseif sub == "new" and arg ~= "" then
      local clean = Profiles.SanitizeName(arg)
      if not clean then
        tell(BIT.L("Enter a profile name first."))
        return
      end
      if Profiles.Exists(clean) then
        tell(string.format(BIT.L("A profile named \"%s\" already exists."), clean))
        return
      end
      local ok, err = Profiles.Use(clean, { create = true, copyFromCurrent = true })
      if ok then
        tell(string.format(BIT.L("Created and selected profile \"%s\" (copied from current). Use /reload to apply."), Profiles.Selected()))
        if BIT.RefreshSettingsChrome then BIT.RefreshSettingsChrome() end
      else
        tell(string.format(BIT.L("Could not create profile (%s)."), tostring(err)))
      end
      return
    elseif sub == "copy" and arg ~= "" then
      local clean = Profiles.SanitizeName(arg)
      local ok, err = Profiles.CopyFrom(arg)
      if ok then
        tell(string.format(BIT.L("Copied settings from \"%s\" into \"%s\". Use /reload to apply."), clean or arg, Profiles.Selected()))
        if BIT.RefreshSettingsChrome then BIT.RefreshSettingsChrome() end
      else
        tell(string.format(BIT.L("Could not copy profile (%s)."), tostring(err)))
      end
      return
    elseif sub == "delete" and arg ~= "" then
      local clean = Profiles.SanitizeName(arg)
      local ok, err = Profiles.Delete(arg)
      if ok then
        tell(string.format(BIT.L("Deleted profile \"%s\"."), clean or arg))
        if BIT.RefreshSettingsChrome then BIT.RefreshSettingsChrome() end
      else
        tell(string.format(BIT.L("Could not delete profile (%s)."), tostring(err)))
      end
      return
    end
    tell(BIT.L("/upt profile opens Profiles; /upt profile list|char|default|use <name>|new <name>|copy <name>|delete <name>"))
  end)
end

BIT.RegisterTab("Profiles", {
  title = "Profiles",
  summary = "Separate settings and enabled modules per character, or shared across characters.",
  plain = true,
  build = build,
})
