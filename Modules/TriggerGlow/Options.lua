-- UsefulPlatesAndTooltips module TriggerGlow: the settings tab (/upt glow) with a live sample of the glow.
-- Copyright (c) 2026 Ironship. GPL-3.0-or-later, see LICENSE.
local _, BIT = ...

local ns = BIT.Module("TriggerGlow")

local WINDOW_WIDTH, WINDOW_HEIGHT = 840, 500
local PREVIEW_WIDTH = 290
local COL_HEIGHT = 440
local ROW_HEIGHT = 26
local SIDE = 12

local window
local controls = {}
local panel

local function db() return ns._settings() end

local function refreshControls()
  for _, control in ipairs(controls) do
    if control.Refresh then control:Refresh() end
  end
end

local function changed()
  refreshControls()
  if ns.Apply then ns.Apply() end
end

---------------------------------------------------------------------------------------------
-- Row builders (the shared ones from Core/LookRows.lua, as every module's tab uses)
---------------------------------------------------------------------------------------------

local tabKeys
local function note(key)
  if tabKeys and key then tabKeys[#tabKeys + 1] = key end
end

local function place(row, y, height)
  table.insert(controls, row)
  return BIT.UI.PlaceRow(row, y, row.standard and row:GetHeight() or height or ROW_HEIGHT)
end

local function value(key)
  local v = db()[key]
  if v == nil and ns._defaults then v = ns._defaults()[key] end
  return v
end

local function checkRow(parent, labelText, key, tooltip, enabledIf)
  note(key)
  return BIT.Looks.Rows.Check(parent, labelText, function() return value(key) end, function(v)
    db()[key] = v
    changed()
  end, { tooltip = tooltip, settings = db, enabledIf = enabledIf })
end

-- One spell's own switch: settings.spells[key] = false switches it off.
local function spellRow(parent, rule)
  note("spells")
  return BIT.Looks.Rows.Check(parent, rule.label, function()
    local spells = db().spells
    return type(spells) ~= "table" or spells[rule.key] ~= false
  end, function(v)
    if type(db().spells) ~= "table" then db().spells = {} end
    db().spells[rule.key] = v and true or false
    changed()
  end, { tooltip = rule.note, settings = db })
end

local function sliderRow(parent, labelText, key, min, max, step, suffix, tooltip, enabledIf)
  note(key)
  return BIT.Looks.Rows.Slider(parent, labelText, min, max, step, function() return value(key) end, function(v)
    db()[key] = v
    changed()
  end, { tooltip = tooltip, settings = db, suffix = suffix, enabledIf = enabledIf })
end

local function choiceRow(parent, labelText, key, list, tooltip)
  note(key)
  return BIT.Looks.Rows.Choice(parent, labelText, list, function() return value(key) end, function(id)
    db()[key] = id
    changed()
  end, { tooltip = tooltip, settings = db })
end

local function buttonRow(parent, labelText, buttonText, onClick, tooltip)
  return BIT.Looks.Rows.Button(parent, labelText, buttonText, function()
    onClick()
    refreshControls()
  end, { tooltip = tooltip, settings = db })
end

local function section(parent, y, text)
  if y > 0 then y = y + 8 end
  return place(BIT.UI.Header(parent, text), y, 28)
end

local NOTE_WIDTH = 470
local function noteRow(parent, y, text)
  local row = BIT.UI.Note(parent, text, NOTE_WIDTH)
  return place(row, y + 4, row:GetHeight() + 10)
end

local function colorList()
  return BIT.Looks.ColorList({ { id = "native", label = "Blizzard gold (no tint)", rgb = { 1, 0.82, 0.3 } } })
end

local STYLES = {
  { id = "blizzard", label = "Blizzard proc glow" },
  { id = "border", label = "Pulsing border" },
}

local BASES = {
  { id = "min", label = "Low end of the damage range" },
  { id = "avg", label = "Middle of the damage range" },
}

---------------------------------------------------------------------------------------------
-- The right column
---------------------------------------------------------------------------------------------

local function buildSettings(parent)
  local y = section(parent, 0, "WHICH SPELLS")
  y = place(checkRow(parent, "Execute-type spells", "hp",
    "Execute and Hammer of Wrath glow while your target is at or below the share of health set below. "
    .. "A hidden health value in a fight is no problem: the client compares it itself."), y)
  y = place(checkRow(parent, "Heal for a low-health friend", "heal",
    "Divine Grace glows while your friendly target (not you) is below the share of health set below."), y)
  y = place(checkRow(parent, "Reactive spells", "reactive",
    "Overpower, Revenge, Mongoose Bite, Counterattack and Victory Rush glow while the game says they can be cast."), y)
  for _, rule in ipairs(ns.RULES) do
    y = place(spellRow(parent, rule), y)
  end

  y = section(parent, y, "LETHAL DAMAGE")
  y = place(checkRow(parent, "Glow when a spell would kill", "kill",
    "Any spell on your bars whose direct damage is priced (the same estimate as the kill icon on the target "
    .. "frame, so CastPrediction must be on) glows while the target's health is at or below that damage. "
    .. "The comparison is made by the client, which hides the health from addons. Shadow Word: Death and every "
    .. "other damage spell get it this way."), y)
  y = place(choiceRow(parent, "Damage counted", "killBasis", BASES,
    "The low end is what the spell is certain to deal, so a glow never lies; the middle glows a little earlier."), y)
  y = place(checkRow(parent, "Only once the target is hurt", "killSkipTrivial",
    "The client hides the target's health and maximum health, so a weak enemy that any spell kills outright "
    .. "cannot be told from the percent alone. With this on, no glow while the target is at full health "
    .. "(on a weak enemy it glows from the first hit); off, a spell that kills glows even on a fresh target."), y)

  y = section(parent, y, "THE WINDOW")
  y = place(sliderRow(parent, "Execute window", "executePct", 5, 60, 1, "%",
    "The glow starts when the enemy target is at or below this share of its health. 20% is what Execute and "
    .. "Hammer of Wrath allow."), y, 40)
  y = place(sliderRow(parent, "Friend heal window", "healPct", 10, 90, 1, "%",
    "Divine Grace glows while a friendly target is below this share of its health (the spell itself needs 50%)."), y, 40)
  y = place(checkRow(parent, "Only when it can be cast", "needResources",
    "Also ask the game whether the spell is castable now, so a glow means enough rage or mana as well. "
    .. "Off, the glow shows as soon as the target is in the window, so you can save the rage for it."), y)
  y = place(checkRow(parent, "Only in combat", "combatOnly",
    "No glow while you are out of combat."), y)

  y = section(parent, y, "THE GLOW")
  y = place(choiceRow(parent, "Style", "style", STYLES,
    "Blizzard proc glow is the animation the game draws for a proc. The pulsing border is a plain frame, "
    .. "for a client or a bar addon where the proc animation does not show."), y)
  y = place(choiceRow(parent, "Execute-type color", "hpColor", colorList(),
    "Tints the glow of Execute and Hammer of Wrath. Blizzard gold is the animation as the game draws it; "
    .. "other colors tint that gold."), y)
  y = place(choiceRow(parent, "Heal color", "healColor", colorList(), "Tints the glow of Divine Grace."), y)
  y = place(choiceRow(parent, "Reactive color", "reactiveColor", colorList(),
    "Tints the glow of Overpower, Revenge, Mongoose Bite, Counterattack and Victory Rush."), y)
  y = place(choiceRow(parent, "Lethal damage color", "killColor", colorList(),
    "Tints the glow of a spell that would kill the target. On a spell that also has its own window "
    .. "(Execute) that spell's color is used."), y)
  y = place(sliderRow(parent, "Glow size", "size", 100, 250, 5, "%",
    "How big the glow is against the button. Blizzard's proc glow is 140%."), y, 40)
  y = place(sliderRow(parent, "Opacity", "opacity", 10, 100, 5, "%", nil), y, 40)

  y = section(parent, y, "TRY IT")
  y = place(buttonRow(parent, "Test on my bars", "Glow 6 s", function()
    ns.Test(6)
  end, "Every button that holds one of the spells glows for six seconds, whatever your target is, so the "
    .. "look can be judged without waiting for a low-health enemy."), y)
  y = place(buttonRow(parent, "What the game says", "Print", function()
    for _, line in ipairs(ns.Probe()) do print(line) end
  end, "Prints, for every button that holds one of the spells, what the client answers right now (castable, "
    .. "the health curve, the glow's state), and the same to /upt glowprobe."), y)
  y = place(checkRow(parent, "Debug lines in chat", "debug",
    "Echo when a glow starts and stops, and what the module found on the bars. The last lines are kept in "
    .. "the saved settings either way."), y)
  y = noteRow(parent, y, "Needs no setup: put one of the spells on a bar. Shadow Word: Death has no health "
    .. "condition in this build, so it has no window. An experimental module; /upt glowprobe prints what it sees.")
  return y
end

---------------------------------------------------------------------------------------------
-- The preview pane: one mock button per kind, glowing with its own color
---------------------------------------------------------------------------------------------

local sampleButtons = {}

local SAMPLES = {
  { group = "hp", icon = 5308, fallback = "Interface\\Icons\\INV_Sword_48", label = "Execute-type" },
  { group = "heal", icon = 1277370, fallback = "Interface\\Icons\\Spell_Holy_PowerWordShield", label = "Heal" },
  { group = "reactive", icon = 7384, fallback = "Interface\\Icons\\Ability_MeleeDamage", label = "Reactive" },
  { group = "kill", icon = 133, fallback = "Interface\\Icons\\Spell_Fire_FlameBolt", label = "Lethal" },
}

local function iconFor(sample)
  if type(C_Spell) == "table" and type(C_Spell.GetSpellTexture) == "function" then
    local ok, tex = pcall(C_Spell.GetSpellTexture, sample.icon)
    if ok and tex and not (type(issecretvalue) == "function" and issecretvalue(tex)) then return tex end
  end
  return sample.fallback
end

local function refreshSample()
  for _, s in ipairs(sampleButtons) do
    ns.SampleGlow(s.frame, s.group, s.on, nil)
  end
end
ns.RefreshSample = refreshSample

local function buildPreview(pane)
  pane:SetSize(PREVIEW_WIDTH, COL_HEIGHT)
  BIT.UI.Backdrop(pane, 0.09)

  local title = pane:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOPLEFT", SIDE, -12)
  title:SetText(BIT.L("Live preview"))
  local rule = pane:CreateTexture(nil, "ARTWORK")
  rule:SetColorTexture(unpack(BIT.UI.COLOR.divider))
  rule:SetHeight(1)
  rule:SetPoint("TOPLEFT", 8, -34)
  rule:SetPoint("TOPRIGHT", -8, -34)

  wipe(sampleButtons)
  local slot = (PREVIEW_WIDTH - 2 * SIDE) / #SAMPLES
  for i, sample in ipairs(SAMPLES) do
    local f = CreateFrame("Frame", nil, pane)
    f:SetSize(44, 44)
    f:SetPoint("TOP", pane, "TOPLEFT", SIDE + slot * (i - 0.5), -88)
    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture(iconFor(sample))
    local cap = pane:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cap:SetPoint("TOP", f, "BOTTOM", 0, -32)
    cap:SetText(BIT.L(sample.label))
    sampleButtons[#sampleButtons + 1] = { frame = f, group = sample.group, on = true }
  end

  local hint = pane:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hint:SetPoint("TOPLEFT", SIDE, -190)
  hint:SetWidth(PREVIEW_WIDTH - 2 * SIDE)
  hint:SetJustifyH("LEFT")
  hint:SetText(BIT.L("The four buttons show the style, color, size and opacity as set. The glow on your action "
    .. "bars appears only while the spell's condition holds. \"Test on my bars\" shows it on the real buttons."))

  pane.title = title
  pane.hint = hint
  pane.Refresh = refreshSample
  refreshSample()
end

local function renderPreview(sample, style)
  BIT.Style.ApplyText(sample.title, style, "text")
  BIT.Style.ApplyText(sample.label, style, "text")
end

---------------------------------------------------------------------------------------------
-- The tab
---------------------------------------------------------------------------------------------

if BIT.RegisterTab then
  BIT.RegisterTab("TriggerGlow", {
    title = "Trigger glow",
    summary = "A glow on the action bar button of a spell whose moment has come: Execute and Hammer of Wrath at "
      .. "low target health, Divine Grace for a hurt friend, Overpower, Revenge and the other reactive spells "
      .. "when the game says they can be cast (experimental).",
    width = WINDOW_WIDTH, height = WINDOW_HEIGHT,
    build = function(parent)
      if window == parent then return end
      window = parent
      controls = {}
      local note1 = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      note1:SetPoint("TOPLEFT", 12, -6)
      note1:SetPoint("RIGHT", -12, 0)
      note1:SetJustifyH("LEFT")
      note1:SetText(BIT.L("Glows the button of a spell while it is the right moment to use it. The target's health "
        .. "may be hidden in a fight; the client's own comparison is used then."))
      local pane = CreateFrame("Frame", nil, parent, "BackdropTemplate")
      pane:SetPoint("TOPLEFT", 10, -46)
      buildPreview(pane)
      panel = pane
      local area = CreateFrame("Frame", nil, parent, "BackdropTemplate")
      area:SetPoint("TOPLEFT", pane, "TOPRIGHT", 10, 0)
      area:SetSize(WINDOW_WIDTH - PREVIEW_WIDTH - 30, COL_HEIGHT)
      BIT.UI.Backdrop(area, 0.09)
      local divider = area:CreateTexture(nil, "ARTWORK")
      divider:SetColorTexture(unpack(BIT.UI.COLOR.divider))
      divider:SetHeight(1)
      divider:SetPoint("TOPLEFT", 8, -34)
      divider:SetPoint("TOPRIGHT", -8, -34)
      local column = BIT.UI.ScrollColumn(area)
      column:SetPoint("TOPLEFT", area, "TOPLEFT", 6, -42)
      column:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT", -6, 40)
      tabKeys = {}
      column:Fit((buildSettings(column.content) or 0) + 12)
      local keys = tabKeys
      tabKeys = nil
      local reset = BIT.Looks.ResetButton(area, function()
        for _, key in ipairs(keys) do
          local default = ns._defaults()[key]
          if type(default) == "table" then default = {} end
          db()[key] = default
        end
        changed()
      end)
      reset:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT", -10, 10)
      refreshControls()
      refreshSample()
    end,
    buildPreview = function(pane)
      local sample = CreateFrame("Frame", nil, pane)
      sample:SetSize(PREVIEW_WIDTH, 90)
      sample.title = sample:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      sample.title:SetPoint("TOPLEFT", 12, -8)
      sample.title:SetText(BIT.L("TriggerGlow sample"))
      sample.label = sample:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      sample.label:SetPoint("TOPLEFT", 12, -34)
      sample.label:SetText(BIT.L("A glow on an action button"))
      return sample
    end,
    previewRender = renderPreview,
    capabilities = { roles = { "text" }, shapes = false, geometry = false, border = false,
      font = true, scale = false, opacity = true },
  })
  BIT.tabWords.glow, BIT.tabWords.triggerglow = "TriggerGlow", "TriggerGlow"
end

ns.openOptions = function()
  if BIT.OpenSettings then BIT.OpenSettings("TriggerGlow") end
end
