-- The Debug tab: the diagnostic slash commands of every part as buttons, so nobody has to
-- remember them. A button runs the command exactly as if it had been typed; the answer comes
-- in the chat window. Commands of parts this package does not ship are left out.
-- Copyright (c) 2026 Ironship. GPL-3.0-or-later, see LICENSE.

local _, BIT = ...
if not BIT or not BIT.RegisterTab then return end

-- { command as typed, what it does }. "/upt <word> ..." goes to BIT.commands, the others to
-- the part's own slash command.
local SECTIONS = {
  { title = "Spell numbers (SpellDamageInfo)", rows = {
    { "/sdi status", "Print the current settings." },
    { "/sdi buttons", "Print what the number on each action button was made from." },
    { "/sdi where", "Read the frame under the mouse 4 seconds after the click." },
    { "/sdi misses", "List the spells on your bars that give no number." },
    { "/sdi misses clear", "Empty that list." },
    { "/sdi dump", "Save your spellbook's descriptions and how they were read." },
    { "/sdi dump all", "The same for every rank of every class. Takes up to a minute." },
    { "/sdi dump items", "Save the use texts of the items in your bags and on your bars." },
  } },
  { title = "DoTs (DoTInfo)", rows = {
    { "/dotinfo debug", "Switch the event trace in the chat window on or off." },
    { "/dotinfo check", "Check how your spells' descriptions are read." },
    { "/dotinfo ticks", "Open the tick viewer." },
    { "/dotinfo plates", "Print what can be read from the nameplates on screen." },
    { "/dotinfo skull", "Show the kill icon on the target portrait for 5 seconds." },
  } },
  { title = "Cast prediction", rows = {
    { "/upt castprobe", "Print what the prediction can read right now." },
    { "/upt castpred census", "Print the talents the prediction knows about." },
  } },
  { title = "Heal prediction", rows = {
    { "/upt healprobe", "Print what the incoming-heal reading returns right now." },
    { "/upt healdebug target", "Print the heal-over-time reading for your target." },
  } },
  { title = "Stats and bag arrows (StatsInfo)", rows = {
    { "/upt probe", "Record what StatsInfo can read about your character." },
    { "/upt bagprobe", "Print whether the bag arrows are wired up." },
  } },
  { title = "Points and sounds (ResourceDing)", rows = {
    { "/rding probe", "Print what the full-bar decision rests on right now." },
    { "/rding test", "Play the selected sound." },
  } },
  { title = "Range", rows = {
    { "/upt rangecheck", "Print the range reading for your target." },
    { "/upt hunterprobe", "Print the hunter range ladder's readings." },
  } },
  { title = "Frames and API", rows = {
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

local function build(content)
  local UI = BIT.UI
  local y = -8
  local note = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  note:SetPoint("TOPLEFT", 8, y)
  note:SetPoint("RIGHT", -8, 0)
  note:SetJustifyH("LEFT")
  note:SetText(BIT.L("Each button runs the command written on it; the answer comes in the chat window. "
    .. "What the dump commands save is written to disk at logout or with Reload UI."))
  y = y - math.max(30, (note:GetStringHeight() or 24) + 8)
  local reload = UI.Button(content, BIT.L("Reload UI"), BUTTON_WIDTH, function()
    if type(ReloadUI) == "function" then ReloadUI() end
  end)
  reload:SetPoint("TOPLEFT", 8, y)
  y = y - ROW - 4

  for _, section in ipairs(SECTIONS) do
    local rows = {}
    for _, row in ipairs(section.rows) do
      if handler(row[1]) then rows[#rows + 1] = row end
    end
    if #rows > 0 then
      local heading = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      heading:SetPoint("TOPLEFT", 8, y - 6)
      heading:SetText(BIT.L(section.title))
      y = y - HEADING
      for _, row in ipairs(rows) do
        local command = row[1]
        local button = UI.Button(content, command, BUTTON_WIDTH, function() run(command) end)
        button:SetPoint("TOPLEFT", 8, y)
        local text = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        text:SetPoint("LEFT", button, "RIGHT", 10, 0)
        -- a width, not a second anchor: LEFT and RIGHT on two frames would disagree on the height
        text:SetWidth(math.max(60, (content:GetWidth() or 600) - BUTTON_WIDTH - 26))
        text:SetJustifyH("LEFT")
        text:SetWordWrap(false)
        text:SetText(BIT.L(row[2]))
        y = y - ROW
      end
    end
  end
  content:SetHeight(-y + 12)
end

-- Loaded last, so the tab is the last one. plain: a tool page, not a part that can be switched
-- off, so it has no Enable box (Core/Settings.lua).
BIT.RegisterTab("Debug", {
  title = "Debug",
  summary = "The diagnostic commands of every part, as buttons.",
  plain = true,
  build = build,
})
