-- UsefulPlatesAndTooltips module DoTInfo: /dotinfo check. Reads every spell in the player's spellbook the way a
-- cast would be read and says which descriptions look like damage over time (a number and a time in seconds)
-- yet give no DoT. Meant for clients in a language nobody has tried yet: the player pastes the output in an issue.

local _, BIT = ...
local ns = BIT.Module("DoTInfo")

local function plain(v)
    if type(issecretvalue) == "function" and issecretvalue(v) then return nil end
    return v
end

local function spellbookIDs()
    local ids, seen = {}, {}
    local function add(id)
        id = plain(id)
        if type(id) == "number" and not seen[id] then seen[id] = true; ids[#ids + 1] = id end
    end
    if C_SpellBook and type(C_SpellBook.GetNumSpellBookSkillLines) == "function" then
        local bank = (type(Enum) == "table" and type(Enum.SpellBookSpellBank) == "table" and Enum.SpellBookSpellBank.Player) or 0
        local okN, n = pcall(C_SpellBook.GetNumSpellBookSkillLines)
        n = okN and plain(n) or 0
        for line = 1, type(n) == "number" and n or 0 do
            local ok, info = pcall(C_SpellBook.GetSpellBookSkillLineInfo, line)
            if ok and type(info) == "table" and type(info.itemIndexOffset) == "number" and type(info.numSpellBookItems) == "number" then
                for i = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
                    local ok2, item = pcall(C_SpellBook.GetSpellBookItemInfo, i, bank)
                    if ok2 and type(item) == "table" then add(item.spellID) end
                end
            end
        end
    elseif type(GetNumSpellTabs) == "function" and type(GetSpellTabInfo) == "function" and type(GetSpellBookItemInfo) == "function" then
        local okN, tabs = pcall(GetNumSpellTabs)
        for tab = 1, (okN and type(tabs) == "number" and tabs or 0) do
            local ok, _, _, offset, count = pcall(GetSpellTabInfo, tab)
            if ok and type(offset) == "number" and type(count) == "number" then
                for i = offset + 1, offset + count do
                    local ok2, kind, id = pcall(GetSpellBookItemInfo, i, "spell")
                    if ok2 and kind == "SPELL" then add(id) end
                end
            end
        end
    end
    return ids
end

-- A digit followed by a time unit in the languages the parsers cover (seconds: sec, Sek, seg, s, 초, 秒).
local function mentionsSeconds(desc)
    return desc:find("%d+%.?%d*%s*[Ss]ec") or desc:find("%d+%.?%d*%s*Sek") or desc:find("%d+%.?%d*%s*seg")
        or desc:find("%d+%.?%d*%s*s%f[%A]") or desc:find("%d%s*초") or desc:find("%d%s*秒")
end

function ns.CheckSpellbook(trace)
    local ids = spellbookIDs()
    if #ids == 0 then print("DoTInfo check: the spellbook could not be read.") return end
    local read, unread, waiting = {}, {}, 0
    for _, id in ipairs(ids) do
        local okN, name, desc = pcall(function()
            local n = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id) or (GetSpellInfo and GetSpellInfo(id))
            local d = ((C_Spell and C_Spell.GetSpellDescription) or GetSpellDescription)(id)
            return n, d
        end)
        name, desc = okN and plain(name) or nil, okN and plain(desc) or nil
        if ns.Retail and not ns.Retail.SpellID(id) then
            -- Retail reads only its own list of spells
        elseif type(name) == "string" and type(desc) == "string" and desc ~= "" then
            local ok, total, school, duration = pcall(ns.ReadSpellText, id, desc)
            if ok and total then
                read[#read + 1] = string.format("%s (%d over %ss)", name, total, tostring(duration))
            elseif ok and school ~= true and mentionsSeconds(desc) and desc:find("%d") then
                -- (nil, true) is the ignore list answer (Rain of Fire, Mind Flay ...): left out on purpose.
                unread[#unread + 1] = { id = id, name = name, desc = desc }
            end
        else
            waiting = waiting + 1
        end
    end
    local locale = (GetLocale and GetLocale()) or "?"
    print(string.format("DoTInfo check (%s): %d spells, %d read as a DoT, %d mention seconds but give no DoT%s.", locale,
        #ids, #read, #unread, waiting > 0 and (", " .. waiting .. " texts not loaded yet, run it again") or ""))
    if #read > 0 then print("Read: " .. table.concat(read, ", ")) end
    trace(string.format("CHECK %s: %d spells, %d read, %d unread", locale, #ids, #read, #unread))
    for i, entry in ipairs(unread) do
        trace(string.format("CHECK NOT READ %s (id %d): %s", entry.name, entry.id, entry.desc))
        if i <= 12 then print(string.format("  not read: %s (id %d)", entry.name, entry.id)) end
    end
    if #unread > 0 then
        print("The full texts are in the saved log (SavedVariables, key log) after /reload; paste them in an issue if a DoT is among them.")
    end
end
