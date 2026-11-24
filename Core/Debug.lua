-- The Debug tab: the diagnostic slash commands of every part as buttons, so nobody has to
-- remember them. A button runs the command exactly as if it had been typed; the answer comes
-- in the chat window. Commands of parts this package does not ship are left out.
-- Copyright (c) 2026 Ironship. GPL-3.0-or-later, see LICENSE.

local _, BIT = ...
if not BIT or not BIT.RegisterTab then return end

-- { command as typed, what it does }. "/upt <word> ..." goes to BIT.commands, the others to
-- the part's own slash command.
local SECTIONS = {
  { title = "SPELL NUMBERS (SPELLDAMAGEINFO)", rows = {
    { "/sdi status", "Print the current settings." },
    { "/sdi buttons", "Print what the number on each action button was made from." },
    { "/sdi where", "Read the frame under the mouse 4 seconds after the click." },
    { "/sdi misses", "List the spells on your bars that give no number." },
    { "/sdi misses clear", "Empty that list." },
    { "/sdi dump", "Save your spellbook's descriptions and how they were read." },
    { "/sdi dump all", "The same for every rank of every class. Takes up to a minute." },
    { "/sdi dump items", "Save the use texts of the items in your bags and on your bars." },
  } },
  { title = "DOTS (DOTINFO)", rows = {
    { "/dotinfo debug", "Switch the event trace in the chat window on or off." },
    { "/dotinfo check", "Check how your spells' descriptions are read." },
    { "/dotinfo ticks", "Open the tick viewer." },
    { "/dotinfo plates", "Print what can be read from the nameplates on screen." },
    { "/dotinfo skull", "Show the kill icon on the target portrait for 5 seconds." },
    { "/dotinfo exec", "Show what execute/finisher is watched and test its icon for 5 seconds." },
  } },
  { title = "CAST PREDICTION", rows = {
    { "/upt castprobe", "Print what the prediction can read right now." },
    { "/upt castpred census", "Print the talents the prediction knows about." },
  } },
  { title = "HEAL PREDICTION", rows = {
    { "/upt healprobe", "Print what the incoming-heal reading returns right now." },
    { "/upt healdebug target", "Print the heal-over-time reading for your target." },
  } },
  { title = "STATS AND BAG ARROWS (STATSINFO)", rows = {
    { "/upt probe", "Record what StatsInfo can read about your character." },
    { "/upt bagprobe", "Print whether the bag arrows are wired up." },
  } },
  { title = "POINTS AND SOUNDS (RESOURCEDING)", rows = {
    { "/rding probe", "Print what the full-bar decision rests on right now." },
    { "/rding test", "Play the selected sound." },
  } },
  { title = "RANGE", rows = {
    { "/upt rangecheck", "Print the range reading for your target." },
    { "/upt hunterprobe", "Print the hunter range ladder's readings." },
  } },
  { title = "PERFORMANCE", rows = {
    { "/upt perf", "Print which parts of the addon used the most CPU time this session." },
    { "/upt perf slow", "Print the slowest single calls, with the memory each allocated." },
    { "/upt perf reset", "Start the counters over." },
  } },
  { title = "FRAMES AND API", rows = {
    { "/upt frame", "Print which unit frames the markers are drawn on." },
    { "/upt api", "Print the addon API version and its parts." },
  } },
}

local SLASH_KEYS = { ["/sdi"] = "SPELLDAMAGEINFO", ["/dotinfo"] = "BITDOTINFO", ["/rding"] = "RESOURCEDING" }

-- The function behind a typed command and the text it gets, or nil when this package has none.
local function handler(command)
  local slash, rest = command:match("^(%S+)%s*(.-)$")
  if slash == "/upt" then
    local word, args = rest:match("^(%S+)%s*(.-)$")
    local fn = word and BIT.commands and BIT.commands[word]
    if type(fn) == "function" then return fn, args end
    return nil
  end
  local key = SLASH_KEYS[slash]
  local fn = key and type(SlashCmdList) == "table" and SlashCmdList[key]
  if type(fn) == "function" then return fn, rest end
  return nil
end

local function run(command)
  local fn, args = handler(command)
  if not fn then return end
  BIT.Say(command)
  local ok, err = pcall(fn, args)
  if not ok then BIT.Say(command .. ": " .. tostring(err)) end
end

local BUTTON_WIDTH, ROW, HEADING = 170, 26, 28

-- The box of stack traces (Core/Trace.lua): Lua errors and blocked protected actions that name
-- this addon, newest first. An edit box, so the text can be marked and copied into a report;
-- typing into it is undone. Returns the y below the box.
local TRACE_HEIGHT = 170
local function buildTraces(content, y)
  local Trace = BIT.Trace
  if type(Trace) ~= "table" then return y end
  local UI = BIT.UI
  local header = UI.Header(content, "")
  header:SetPoint("TOPLEFT", 10, y - 4)
  local clear = UI.Button(content, BIT.L("Clear"), 80, function() Trace.Clear() end)
  clear:SetPoint("TOPRIGHT", -10, y - 2)
  -- raises a real Lua error on purpose: it must show up in the box below (and in the game's
  -- own error window, when that is switched on)
  local test = UI.Button(content, BIT.L("Test"), 80, function()
    error("trace test: this error was raised on purpose by the Debug tab")
  end)
  test:SetPoint("RIGHT", clear, "LEFT", -6, 0)
  header:SetPoint("RIGHT", test, "LEFT", -10, 0)
  local heading = header.label
  y = y - HEADING

  local box = CreateFrame("Frame", nil, content, BackdropTemplateMixin and "BackdropTemplate" or nil)
  box:SetPoint("TOPLEFT", 10, y)
  box:SetPoint("RIGHT", -10, 0)
  box:SetHeight(TRACE_HEIGHT)
  UI.Backdrop(box, 0.09)
  local col = UI.ScrollColumn(box)
  col:SetPoint("TOPLEFT", 6, -6)
  col:SetPoint("BOTTOMRIGHT", -6, 6)
  local scroll = col.scroll
  local edit = CreateFrame("EditBox", nil, col.content)
  edit:SetPoint("TOPLEFT", 0, 0)
  edit:SetMultiLine(true)
  edit:SetAutoFocus(false)
  edit:SetFontObject("GameFontHighlightSmall")
  edit:SetWidth(math.max(60, (content:GetWidth() or 600) - 44))
  if type(edit.EnableMouseWheel) == "function" then edit:EnableMouseWheel(false) end

  local shown = ""
  local function fitEdit()
    local h = edit:GetHeight()
    col:Fit(math.max(TRACE_HEIGHT - 12, type(h) == "number" and h + 8 or TRACE_HEIGHT - 12))
  end
  local function refresh()
    local n = #Trace.entries
    heading:SetText(string.format(BIT.L("Errors and blocked actions of this addon (%d)"), n))
    shown = n > 0 and Trace.Text()
      or BIT.L("Nothing caught since the last reload. Lua errors and \"blocked action\" reports that name this addon appear here with their stack.")
    edit:SetText(shown)
    edit:SetCursorPosition(0)
    scroll:SetVerticalScroll(0)
    fitEdit()
  end
  edit:SetScript("OnTextChanged", function(self, userInput)
    if userInput then self:SetText(shown) end
    fitEdit()
  end)
  edit:SetScript("OnSizeChanged", fitEdit)
  edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  scroll:HookScript("OnSizeChanged", function(_, width)
    if type(width) == "number" and width > 0 then
      edit:SetWidth(width)
      fitEdit()
    end
  end)
  -- a click anywhere in the box puts the cursor in the text, so Ctrl+A / Ctrl+C work
  box:EnableMouse(true)
  box:SetScript("OnMouseDown", function() edit:SetFocus() end)
  Trace.OnChange(refresh)
  refresh()
  return y - TRACE_HEIGHT - 8
end

local function build(content)
  local UI = BIT.UI
  local y = -8
  local note = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  note:SetPoint("TOPLEFT", 10, y)
  note:SetPoint("RIGHT", -10, 0)
  note:SetJustifyH("LEFT")
  note:SetText(BIT.L("Each button runs the command written on it; the answer comes in the chat window. "
    .. "What the dump commands save is written to disk at logout or with Reload UI."))
  y = y - math.max(30, (note:GetStringHeight() or 24) + 8)
  local reload = UI.Button(content, BIT.L("Reload UI"), BUTTON_WIDTH, function()
    if type(ReloadUI) == "function" then ReloadUI() end
  end)
  reload:SetPoint("TOPLEFT", 10, y)
  y = y - ROW - 4
  y = buildTraces(content, y)

  local cmdCard = CreateFrame("Frame", nil, content, BackdropTemplateMixin and "BackdropTemplate" or nil)
  cmdCard:SetPoint("TOPLEFT", 10, y)
  cmdCard:SetPoint("RIGHT", -10, 0)
  UI.Backdrop(cmdCard, 0.09)
  local cy = -10

  for _, section in ipairs(SECTIONS) do
    local rows = {}
    for _, row in ipairs(section.rows) do
      if handler(row[1]) then rows[#rows + 1] = row end
    end
    if #rows > 0 then
      local heading = UI.Header(cmdCard, section.title)
      heading:SetPoint("TOPLEFT", 10, cy - 2)
      heading:SetPoint("RIGHT", cmdCard, "RIGHT", -10, 0)
      cy = cy - HEADING
      for _, row in ipairs(rows) do
        local command = row[1]
        local button = UI.Button(cmdCard, command, BUTTON_WIDTH, function() run(command) end)
        button:SetPoint("TOPLEFT", 10, cy)
        local text = cmdCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        text:SetPoint("LEFT", button, "RIGHT", 10, 0)
        -- a width, not a second anchor: LEFT and RIGHT on two frames would disagree on the height
        text:SetWidth(math.max(60, (content:GetWidth() or 600) - BUTTON_WIDTH - 48))
        text:SetJustifyH("LEFT")
        text:SetWordWrap(false)
        text:SetText(BIT.L(row[2]))
        cy = cy - ROW
      end
      cy = cy - 4
    end
  end
  cmdCard:SetHeight(-cy + 8)
  content:SetHeight(-y + cmdCard:GetHeight() + 12)
end

-- Loaded last, so the tab is the last one. plain: a tool page, not a part that can be switched
-- off, so it has no Enable box (Core/Settings.lua).
BIT.RegisterTab("Debug", {
  title = "Debug",
  summary = "The diagnostic commands of every part, as buttons.",
  plain = true,
  build = build,
})
