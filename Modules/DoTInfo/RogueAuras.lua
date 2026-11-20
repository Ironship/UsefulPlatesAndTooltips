-- Blizzard owns these aura icons, timers and stacks; Lua never reads their combat state.
local _, BIT = ...
local ns = BIT.Module("DoTInfo")
-- Retail keeps these hooks on ns.Retail; WoW: Forever (no ns.Retail) uses ns.RogueNative, which draws the damage of
-- Deadly Poison and of the proc/trap DoTs whose start Lua can only guess (Deep Wound, Ignite, Righteous Judgement,
-- Immolation Trap, Wyvern Sting).
-- Forever refuses addon code every read of an enemy's auras in combat (GetUnitAuras, GetAuraDataByIndex and
-- GetUnitAuraInstanceIDs all throw "Auras cannot be accessed when secret while tainted"), so the native aura
-- container is the only way to show the poison there.
local forever = ns.Retail == nil
local R = ns.Retail or {}
if forever then ns.RogueNative = R end

local SIZE, GAP, MAX_PLATES = 18, 2, 40
local AURA_REFRESH_INTERVAL = 0.25
local spellIDs = forever and {
    [2818] = true, [2819] = true, [11353] = true, [11354] = true, [25349] = true, -- Deadly Poison I-V
} or {
    [703] = true, [1943] = true, -- Garrote, Rupture (including Crimson Tempest copies)
    [2818] = true, [383414] = true, -- Deadly Poison, Amplifying Poison stacks
    [385627] = true, [360194] = true, -- Kingsbane, Deathmark
    [381628] = true, [394021] = true, -- Internal Bleeding, Mutilated Flesh
}
-- Forever's Deadly Poison stacks to five; the damage bar is five stacks wide and fills with the stacks it has.
local MAX_STACKS = 5
local COATINGS = { 25351, 11356, 11355, 2824, 2823 } -- the poison spells, highest rank first
local targetEntry, byPlate, activeUnits, failedHosts = nil, {}, {}, {}
local started, events = false, nil

local function secret(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

local function ask(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, value = pcall(fn, ...)
    if ok and not secret(value) then return value end
end

local function usable(object)
    if secret(object) or object == nil then return false end
    local ok, forbidden = pcall(function() return object.IsForbidden and object:IsForbidden() end)
    return ok and not secret(forbidden) and not forbidden
end

local function healthBar(parent, onPlate)
    if not usable(parent) then return end
    local ok, bar = pcall(function()
        if onPlate then
            return BIT.Plate.HealthBar(parent)
        end
        local main = parent.TargetFrameContent and parent.TargetFrameContent.TargetFrameContentMain
        return (main and main.HealthBarsContainer and main.HealthBarsContainer.HealthBar)
            or (main and main.HealthBar) or TargetFrameHealthBar or parent.healthbar
    end)
    if ok and usable(bar) then return bar end
end

local function initialize(button)
    button:SetSize(SIZE, SIZE)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(button)
    local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    cooldown:SetAllPoints(button)
    cooldown:SetDrawEdge(false)
    cooldown:SetHideCountdownNumbers(true)
    local duration = button:CreateFontString(nil, "OVERLAY")
    duration:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    duration:SetPoint("BOTTOM", button, "BOTTOM", 0, 0)
    local count = button:CreateFontString(nil, "OVERLAY")
    count:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    count:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
    -- Every binding immediately updates its display, so style regions before registering them.
    button:SetIcon(icon)
    button:SetDurationCooldown(cooldown)
    button:SetDurationText(duration)
    button:SetApplicationCount(count)
end

local function known(id)
    return ask(IsSpellKnown, id) == true or ask(IsPlayerSpell, id) == true
end

-- The damage over time of a spell as SpellDamageInfo reads it (description plus your stats): the rank you cast last,
-- else the highest rank you know. `castIDs` is an array of the spell's rank ids, lowest first.
local function dotTotal(castIDs)
    local sdi = BIT.modules and BIT.modules.SpellDamageInfo
    if type(sdi) ~= "table" or type(sdi.Compute) ~= "function" then return nil end
    local id = ns.ProcDots and ns.ProcDots.LastCastOf and ns.ProcDots.LastCastOf(castIDs)
    if not id then
        for index = #castIDs, 1, -1 do
            if known(castIDs[index]) then id = castIDs[index]; break end
        end
    end
    if not id then return nil end
    local ok, view = pcall(sdi.Compute, id, false)
    local dot = ok and type(view) == "table" and not view.finisher and type(view.dot) == "table" and tonumber(view.dot.total)
    return dot and dot > 0 and dot or nil
end

local function poisonAmount()
    local coating = 2823
    if forever then
        for _, id in ipairs(COATINGS) do
            if known(id) then coating = id; break end
        end
    end
    local desc = ask(C_Spell and C_Spell.GetSpellDescription, coating)
    -- One application's damage over the whole duration; Forever's stacks are read natively (the bar below).
    local total
    if desc then
        if forever then total = ns.ParseRogueAura and ns.ParseRogueAura(2818, desc, { poison = true, stacked = true })
        else total = R.Parse(2818, desc) end
    end
    if type(total) == "number" and total > 0 and total < math.huge then return total end
end

-- One native damage segment per spell: the aura that proves the DoT is on the mob (its real start, time left and
-- stacks are drawn by Blizzard's container, Lua never reads them) and the damage Lua puts on it from the spell
-- description and your stats (spec.size, the whole effect for one application). `luaName` is the name of the plain
-- DoT Lua may also draw for it (then the native segment steps aside), `covers` the ProcDots guess it replaces.
local function procSize(kind)
    local procs = ns.ProcDots
    return procs and procs.NativeSize and procs.NativeSize(kind) or nil
end

local SPECS
if forever then
    SPECS = {
        ROGUE = { { key = "poison", slot = "deadlyDamage", label = "POISON", ids = spellIDs, school = 8, stacked = true,
            familyID = 2818, nameID = 2818, fallback = "Deadly Poison", size = poisonAmount } },
        WARRIOR = { { key = "deepWounds", slot = "deepWounds", label = "DEEP WOUNDS", ids = { [412609] = true },
            school = 1, luaName = "Deep Wounds", verified = true, nameID = 412609, fallback = "Deep Wounds", setting = "procDots",
            size = function() return procSize("proc") end } },
        MAGE = {
            { key = "ignite", slot = "ignite", label = "IGNITE", ids = { [412538] = true }, school = 4,
                luaName = "Ignite", verified = true, nameID = 412538, fallback = "Ignite", setting = "procDots",
                size = function() return procSize("proc") end },
            -- Lua ignores the area spells (ns.IGNORED_SPELLS): every mob the pillar burns shows its own segment.
            { key = "flamestrike", slot = "flamestrike", label = "FLAMESTRIKE", school = 4, nameID = 2120,
                fallback = "Flamestrike", ids = { [2120] = true, [2121] = true, [8422] = true, [8423] = true,
                    [10215] = true, [10216] = true },
                castIDs = { 2120, 2121, 8422, 8423, 10215, 10216 },
                size = function() return dotTotal({ 2120, 2121, 8422, 8423, 10215, 10216 }) end },
        },
        PALADIN = { { key = "judgement", slot = "judgement", label = "JUDGEMENT", ids = { [440675] = true }, school = 2,
            luaName = "Righteous Judgement", verified = true, nameID = 440675, fallback = "Righteous Judgement", setting = "procDots",
            size = function() return procSize("proc") end } },
        -- Devouring Contagion (talent): a mob that dies with your Devouring Plague on it passes it to nearby enemies for the
        -- time it had left. No cast of yours starts that copy, so the plain DoT (cast events) never sees it; the aura does.
        -- The segment steps aside wherever the plain DoT of the same spell is drawn (nativeTotal).
        PRIEST = { { key = "plague", slot = "plague", label = "DEVOURING PLAGUE", school = 32, luaName = "Devouring Plague",
            nameID = 2944, fallback = "Devouring Plague",
            ids = { [2944] = true, [19276] = true, [19277] = true, [19278] = true, [19279] = true, [19280] = true },
            castIDs = { 2944, 19276, 19277, 19278, 19279, 19280 },
            size = function() return dotTotal({ 2944, 19276, 19277, 19278, 19279, 19280 }) end } },
        HUNTER = {
            { key = "trap", slot = "trap", label = "TRAP", ids = { [13797] = true, [14298] = true, [14299] = true,
                [14300] = true, [14301] = true }, school = 4, covers = "nativeTraps", nameID = 13797,
                fallback = "Immolation Trap", setting = "procDots", size = function() return procSize("trap") end },
            { key = "explosive", slot = "explosive", label = "EXPLOSIVE TRAP", school = 4, nameID = 13812,
                fallback = "Explosive Trap", ids = { [13812] = true, [14314] = true, [14315] = true },
                castIDs = { 13813, 14316, 14317 }, size = function() return dotTotal({ 13813, 14316, 14317 }) end },
            { key = "wyvern", slot = "wyvern", label = "WYVERN", ids = { [24336] = true }, school = 8,
                covers = "nativeDelayed", nameID = 24336, fallback = "Wyvern Sting", setting = "procDots",
                size = function() return procSize("delayed") end },
        },
    }
else
    SPECS = { ROGUE = { { key = "poison", slot = "deadlyDamage", label = "POISON", ids = { [2818] = true }, school = 8,
        familyID = 2818, nameID = 2818, fallback = "Deadly Poison", size = poisonAmount } } }
end
local activeSpecs = {}
local lastErrors = {} -- [label] = the last setup/update error text, for /upt native
local LANE_GAP, LANE_HEIGHT = 2, 6 -- diagnostic row under the bar (nativeShowAll)

-- Aura-gated plain segments on nameplates (nativeGateReplace): Nameplates.lua tells, per plate, where each plain DoT
-- segment is (its offset and damage on the health scale); a twin of the spell's native segment is drawn there, sized by
-- Lua and shown by the game only while the aura is on the mob, and the plain segment of that DoT is hidden.
local plans = setmetatable({}, { __mode = "k" }) -- [plate] = { items = { [DoT name] = { offset, damage } }, at, reverse }
local function gateReplace()
    return forever and ns.db ~= nil and ns.db.nativeGateReplace == true and ns.db.nativeDots ~= false
end
local function wantGeneric()
    return forever and ns.db ~= nil and (ns.db.nativeAllDots == true or ns.db.nativeGateReplace == true)
end
-- Only the spells that put the aura on the target themselves (NativeAuraIDs.lua) can have a segment of their own.
local function allowedID(id)
    local verified = ns.NativeAuraIDs
    return verified ~= nil and verified[id] == true
end

-- Experimental (setting nativeAllDots, Forever): a segment for every DoT in your spellbook that SpellDamageInfo can
-- size, wherever Lua has no DoT of its own on that mob (the plain segment of the same name always wins).
local GENERIC_MAX = 14
local generic, combined
local genericMs, genericBuilds, genericExamined = nil, 0, 0
local clock = debugprofilestop or function() return GetTime() * 1000 end

local function spellbookIDs()
    local ids, seen = {}, {}
    local function add(id)
        if not secret(id) and type(id) == "number" and not seen[id] then seen[id] = true; ids[#ids + 1] = id end
    end
    if C_SpellBook and type(C_SpellBook.GetNumSpellBookSkillLines) == "function" then
        local bank = (type(Enum) == "table" and type(Enum.SpellBookSpellBank) == "table" and Enum.SpellBookSpellBank.Player) or 0
        local lines = ask(C_SpellBook.GetNumSpellBookSkillLines)
        for line = 1, type(lines) == "number" and lines or 0 do
            local info = ask(C_SpellBook.GetSpellBookSkillLineInfo, line)
            if type(info) == "table" and type(info.itemIndexOffset) == "number" and type(info.numSpellBookItems) == "number" then
                for index = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
                    local item = ask(C_SpellBook.GetSpellBookItemInfo, index, bank)
                    if type(item) == "table" then add(item.spellID) end
                end
            end
        end
    elseif type(GetNumSpellTabs) == "function" and type(GetSpellTabInfo) == "function"
        and type(GetSpellBookItemInfo) == "function" then
        local tabs = ask(GetNumSpellTabs)
        for tab = 1, type(tabs) == "number" and tabs or 0 do
            local ok, _, _, offset, count = pcall(GetSpellTabInfo, tab)
            if ok and type(offset) == "number" and type(count) == "number" then
                for index = offset + 1, offset + count do
                    local okItem, kind, id = pcall(GetSpellBookItemInfo, index, "spell")
                    if okItem and kind == "SPELL" then add(id) end
                end
            end
        end
    end
    return ids
end

-- Building the list reads the description of every spell in the book (first reads are parsed): about 0.4 ms each,
-- so a whole book in one frame is a visible hitch (5.5 ms for 15 spells measured in game). It is done in slices of
-- GENERIC_SLICE_MS, one per frame, and the finished list replaces the old one in one step.
local GENERIC_SLICE_MS = 1.0
local building, rebuildGeneric, lastAdvance = nil, false, nil
local genericMaxSlice = 0
-- SPELLS_CHANGED also arrives when nothing in the book changed (a warlock's pet summoned, for one: three builds in a
-- session were seen); the list is only rebuilt when the spells in the book are not the same ones as last time.
local lastBookSig, genericSkipped = nil, 0

local function bookSignature(book)
    local sum, squares = 0, 0
    for _, id in ipairs(book) do
        sum = sum + id
        squares = (squares + id * id) % 2147483647
    end
    return #book .. ":" .. sum .. ":" .. squares
end
local genericSizes = {} -- how many spells each build of the every-DoT list read, for /upt native

local function startGenericBuild()
    local covered = {}
    for _, spec in ipairs(activeSpecs) do
        for id in pairs(spec.ids) do covered[id] = true end
        for _, id in ipairs(spec.castIDs or {}) do covered[id] = true end
        covered[ask(C_Spell and C_Spell.GetSpellName, spec.nameID) or spec.fallback] = true
    end
    building = { sdi = BIT.modules and BIT.modules.SpellDamageInfo, index = 1, list = {}, groups = {}, ms = 0,
        covered = covered }
end

local function finishGenericBuild()
    local specs = {}
    for _, group in ipairs(building.list) do
        if #specs >= GENERIC_MAX then break end
        table.sort(group.castIDs)
        specs[#specs + 1] = { key = "g" .. group.castIDs[1], slot = "g" .. group.castIDs[1], label = group.name:upper(),
            ids = group.ids, school = group.school, luaName = group.name, nameID = group.castIDs[1],
            fallback = group.name, generic = true, size = function() return dotTotal(group.castIDs) end }
    end
    generic, combined = specs, nil
    lastBookSig = building.sig
    genericSizes[#genericSizes + 1] = #building.book
    if #genericSizes > 8 then table.remove(genericSizes, 1) end
    genericMs, genericBuilds = building.ms, genericBuilds + 1
    building = nil
end

-- One slice per frame at most, however often the aura update runs.
local function advanceGeneric()
    local now = GetTime()
    if lastAdvance == now then return end
    lastAdvance = now
    if not building and generic and rebuildGeneric then
        rebuildGeneric = false
        local book = spellbookIDs()
        local sig = bookSignature(book)
        if sig == lastBookSig then
            genericSkipped = genericSkipped + 1
            return
        end
        startGenericBuild()
        building.book, building.sig = book, sig
        genericExamined = #book
    elseif not building and not generic then
        startGenericBuild()
    end
    local b = building
    if not b then return end
    local t0 = clock()
    if not b.book then
        b.book = spellbookIDs()
        b.sig = bookSignature(b.book)
        genericExamined = #b.book
    end
    if type(b.sdi) ~= "table" or type(b.sdi.Compute) ~= "function" then b.index = #b.book + 1 end
    local ignored = ns.IGNORED_SPELLS or {}
    while b.index <= #b.book do
        local id = b.book[b.index]
        b.index = b.index + 1
        local name = ask(C_Spell and C_Spell.GetSpellName, id)
        if type(name) == "string" and not b.covered[id] and not b.covered[name] and not ignored[name]
            and not (ns.TRAP_DOTS and ns.TRAP_DOTS[name]) and not (ns.DELAYED_DOTS and ns.DELAYED_DOTS[name])
            and allowedID(id) then
            local ok, view = pcall(b.sdi.Compute, id, false)
            local dot = ok and type(view) == "table" and not view.finisher and type(view.dot) == "table"
                and tonumber(view.dot.total)
            if dot and dot > 0 then
                local group = b.groups[name]
                if not group then
                    group = { name = name, ids = {}, castIDs = {}, school = type(view.school) == "number" and view.school or 1 }
                    b.groups[name] = group
                    b.list[#b.list + 1] = group
                end
                group.ids[id] = true
                group.castIDs[#group.castIDs + 1] = id
            end
        end
        if clock() - t0 >= GENERIC_SLICE_MS then break end
    end
    local spent = clock() - t0
    b.ms = b.ms + spent
    if spent > genericMaxSlice then genericMaxSlice = spent end
    if b.index > #b.book then finishGenericBuild() end
end

-- The segments to update now: the fixed ones, plus the generic ones once their list is built and the setting is on.
local function currentSpecs(allDots)
    if not forever or not allDots or not generic then return activeSpecs end
    if not combined then
        combined = {}
        for _, spec in ipairs(activeSpecs) do combined[#combined + 1] = spec end
        for _, spec in ipairs(generic) do combined[#combined + 1] = spec end
    end
    return combined
end

local function poisonAppearance(entry, spec)
    local config, parts = {}, {}
    local onPlate = entry.onPlate
    for _, key in ipairs({ "fillTexture", "fillColor", "fillOpacity", "dotColors", "outlineStyle",
        "dashLength", "outlineThickness", "outlineColor", "outlineOpacity", "segmentDividers",
        "pulseOutline", "showGlow", "glowSize", "showShine", "shineInterval", "scrollStripes", "labelSize", "labelColor" }) do
        local setting = onPlate and key ~= "segmentDividers" and key ~= "labelSize" and key ~= "labelColor"
            and ("plate" .. key:sub(1, 1):upper() .. key:sub(2)) or key
        config[key] = ns.db[setting]
        if config[key] == nil and ns.DEFAULTS then config[key] = ns.DEFAULTS[setting] end
        parts[#parts + 1] = tostring(config[key])
    end
    config.onPlate = onPlate
    config.name = ask(C_Spell and C_Spell.GetSpellName, spec.nameID) or spec.fallback
    config.school = spec.school
    config.stacksText = spec.stacked == true and ns.db.nativeStacks == true
    parts[#parts + 1] = tostring(config.stacksText)
    -- Diagnostic (nativeShowAll): the native segment is white and half transparent, so it can be told from the plain one of the
    -- same DoT, which is drawn in the DoT's own colour.
    if forever and ns.db.nativeShowAll == true then
        config.dotColors, config.fillColor, config.fillOpacity = "single", "white", 55
    end
    parts[#parts + 1] = tostring(forever and ns.db.nativeShowAll == true)
    -- In place the twin looks like the plain segment; with the diagnostic option on as well it is cyan and the plain
    -- segment stays, to see where the twin is drawn and whether its fill shows.
    local probing = forever and ns.db.nativeShowAll == true
    if spec.gated and (not gateReplace() or probing) then config.dotColors, config.fillColor, config.fillOpacity = "single", "cyan", 70 end
    config.fillAbove = forever and spec.gated == true and gateReplace()
    parts[#parts + 1] = tostring(spec.gated == true) .. tostring(gateReplace()) .. tostring(probing) .. tostring(config.fillAbove)
    return config, table.concat(parts, "|")
end

-- Lays a native segment's geometry bar over the bar the player sees: the HealthBar frame, or, where that is taller
-- (Blizzard's Camelot frames: 3 above and 2 below its container), the container's top and bottom, as the plain markers
-- do. A segment over the whole frame stuck out above and below the bar and made its outline flicker. Retail keeps its
-- own placement. Returns the inset used, to be looked at again later.
local function fitToBar(entry, geometry)
    local top, bottom = 0, 0
    if forever and BIT.Plate and BIT.Plate.BarInset then top, bottom = BIT.Plate.BarInset(entry.bar) end
    geometry:ClearAllPoints()
    if top == 0 and bottom == 0 then
        geometry:SetAllPoints(entry.bar)
    else
        geometry:SetPoint("TOPLEFT", entry.bar, "TOPLEFT", 0, -top)
        geometry:SetPoint("BOTTOMRIGHT", entry.bar, "BOTTOMRIGHT", 0, bottom)
    end
    return top, bottom
end

local function createNativeDamage(entry, spec, config, signature)
    local property = Enum and Enum.DurationTextBindingProperty
    local direction = Enum and Enum.StatusBarTimerDirection
    if type(entry.container.AddAuraSlot) ~= "function" or not property or not direction
        or type(property.RemainingPercent) ~= "number" or type(direction.RemainingTime) ~= "number"
        or not C_StringUtil or type(C_StringUtil.CreateNumericRuleFormatter) ~= "function" then
        if ns.TraceRogueAura then ns.TraceRogueAura("NATIVE " .. spec.label .. " duration formatting unavailable") end
        return
    end
    local scale, base, container, formatter, initialized, initializerError, lane
    local ok, err = pcall(function()
        -- This plain HP scale stays outside restricted aura buttons. Its fill supplies native geometry.
        for _, key in ipairs({ spec.key .. "Scale", spec.key .. "Base" }) do
            if not entry[key] then
                local bar = CreateFrame("StatusBar", nil, entry.parent, "DisableUntrustedLayoutScriptsTemplate")
                bar:SetAllPoints(entry.bar)
                bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
                bar:SetStatusBarColor(0, 0, 0, 0)
                bar:SetMinMaxValues(0, 1)
                bar:SetValue(0)
                entry[key] = bar
            end
        end
        scale, base = entry[spec.key .. "Scale"], entry[spec.key .. "Base"]
        -- Diagnostic (nativeShowAll): the native segment gets its own thin row under the bar and starts at its left edge, so
        -- its length can be compared by eye with the plain segment of the same DoT on the bar.
        local insetTop, insetBottom = 0, 0
        lane = forever and ((spec.gated == true and not gateReplace()) or (not spec.gated and ns.db.nativeShowAll == true))
        local rowTop = -(LANE_GAP + (spec.gated and 1 or 0) * (LANE_HEIGHT + LANE_GAP))
        if forever then -- Retail's bars are only ever placed when they are made
            for _, geometry in ipairs({ scale, base }) do
                if lane then
                    geometry:ClearAllPoints()
                    geometry:SetPoint("TOPLEFT", entry.bar, "BOTTOMLEFT", 0, rowTop)
                    geometry:SetPoint("BOTTOMRIGHT", entry.bar, "BOTTOMRIGHT", 0, rowTop - LANE_HEIGHT)
                else insetTop, insetBottom = fitToBar(entry, geometry) end
            end
        end
        container = CreateFrame("AuraContainer", nil, entry.parent, "CustomAuraContainerTemplate")
        container:SetSize(1, 1)
        container:SetPoint("BOTTOMLEFT", entry.bar, "TOPLEFT", 0, 4)
        if forever then
            -- The segment's frames are made right below, as children of this one: it gets the strata and the level it will
            -- keep first, or they stay at the plate's own level, under its health bar, and a segment drawn over the bar
            -- (an in-place twin) is covered by it. A row under the bar was never covered, which is why only twins showed it.
            local barStrata, barLevel = ask(entry.bar.GetFrameStrata, entry.bar), ask(entry.bar.GetFrameLevel, entry.bar)
            if type(barStrata) == "string" then container:SetFrameStrata(barStrata) end
            container:SetFrameLevel(type(barLevel) == "number" and barLevel + (spec.gated and gateReplace() and 10 or 5) or 200)
        end
        formatter = C_StringUtil.CreateNumericRuleFormatter()
        formatter:SetBreakpoints({ { threshold = 0, format = "" } })
        container:AddAuraSlot(spec.slot, "HARMFUL|PLAYER", {
            candidateFilters = { includeSpellIDs = spec.ids },
            initializeFrame = function(button)
                -- The native factory swallows callback errors, so retain setup failure explicitly.
                initialized, initializerError = pcall(function()
                    button:SetPoint("TOPLEFT", base:GetStatusBarTexture(), "TOPRIGHT")
                    button:SetPoint("BOTTOMRIGHT", scale:GetStatusBarTexture(), "BOTTOMRIGHT")
                    local clip = CreateFrame("Frame", nil, button, "DisableUntrustedLayoutScriptsTemplate")
                    local padding = (config.glowSize or 0) + (config.outlineThickness or 1)
                    local frame = forever and base or entry.bar -- Forever: the fitted bar (the lane, or the visible bar)
                    clip:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, padding)
                    clip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, -padding)
                    clip:SetClipsChildren(true)
                    local timer = CreateFrame("StatusBar", nil, clip, "DisableUntrustedLayoutScriptsTemplate")
                    local stacks
                    if spec.stacked then
                        -- An invisible bar that fills with the stacks; the timer is as wide as that fill, so what it
                        -- draws is stacks x one application x the time left, without Lua reading either.
                        stacks = CreateFrame("StatusBar", nil, clip, "DisableUntrustedLayoutScriptsTemplate")
                        stacks:SetAllPoints(button)
                        stacks:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
                        stacks:SetStatusBarColor(0, 0, 0, 0)
                        stacks:SetMinMaxValues(0, MAX_STACKS)
                        stacks:SetValue(0)
                        timer:SetPoint("TOPLEFT", button, "TOPLEFT")
                        timer:SetPoint("BOTTOMRIGHT", stacks:GetStatusBarTexture(), "BOTTOMRIGHT")
                    else timer:SetAllPoints(button) end
                    timer:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
                    timer:SetStatusBarColor(0.2, 1, 0.2, 0.9)
                    if ns.stylePoisonSegment then ns.stylePoisonSegment(timer, entry.bar, config) end
                    if spec.gated then
                        -- Experiment: no native timer. The segment is as long as the scale bar says (the plain DoT's
                        -- remaining damage, from Lua) and is shown only while the aura is there: the game shows and
                        -- hides the button, the addon never reads the aura.
                        timer:SetMinMaxValues(0, 1)
                        timer:SetValue(1)
                    else
                    local label = button:CreateFontString(nil, "OVERLAY")
                    label:SetFont("Fonts\\FRIZQT__.TTF", config.labelSize or 11, "OUTLINE")
                    if ns.colorOf then label:SetTextColor(ns.colorOf(config.labelColor)) else label:SetTextColor(0.2, 1, 0.2) end
                    label:SetPoint("BOTTOMRIGHT", entry.bar, "TOPRIGHT", -2, 2)
                    button:SetDurationText(label, { textFormat = {
                        formatString = "{}", components = {
                            { property = property.RemainingPercent, formatter = formatter },
                        },
                    } })
                    button:SetDurationBar(timer, { direction = direction.RemainingTime })
                    if stacks then button:SetApplicationBar(stacks, { minApplications = 0, maxApplications = MAX_STACKS }) end
                    end
                    if config.stacksText then
                        -- The game fills this with the stack count; Lua never reads it.
                        local count = button:CreateFontString(nil, "OVERLAY")
                        count:SetFont("Fonts\\FRIZQT__.TTF", config.labelSize or 11, "OUTLINE")
                        count:SetTextColor(1, 1, 1)
                        count:SetPoint("BOTTOMLEFT", entry.bar, "TOPLEFT", 2, 2)
                        button:SetApplicationCount(count)
                    end
                end)
                -- Native visibility, timers and formatted damage stay inside the restricted button.
            end,
        })
        assert(initialized, initializerError or "native initializer did not run")
    end)
    if not ok then
        if scale then pcall(scale.Hide, scale) end
        if container then pcall(container.SetEnabled, container, false); pcall(container.Hide, container) end
        if ns.TraceRogueAura then
            local text = type(err) == "string" and not secret(err) and err or "restricted"
            lastErrors[spec.label] = "setup: " .. text
            ns.TraceRogueAura("NATIVE " .. spec.label .. " setup failed: " .. text)
        end
        return
    end
    if ns.TraceRogueAura then ns.TraceRogueAura("NATIVE " .. spec.label .. " damage display ready") end
    return { container = container, scale = scale, base = base, formatter = formatter, signature = signature, spec = spec, lane = lane,
        insetTop = insetTop, insetBottom = insetBottom }
end

local function updateNativeOffset(entry, unit, enabled, damage)
    if damage.failed then return end
    if damage.spec.gated and gateReplace() then
        local record = plans[entry.parent]
        local item = enabled and record and not record.reverse and GetTime() - record.at < 0.5
            and record.items[damage.spec.luaName]
        local offset, total = 0, 0
        if item and item.damage > 0 then offset, total = item.offset, item.damage end
        if offset ~= damage.offset or total ~= damage.offsetTotal then
            damage.base:SetValue(offset)
            damage.scale:SetValue(damage.width and total or offset + total)
            damage.offset, damage.offsetTotal, damage.total = offset, total, total
        end
        return
    end
    local offset = enabled and not damage.lane and ns.nativePoisonBase and ns.nativePoisonBase(unit, entry.parent, entry.bar) or 0
    if offset ~= damage.offset or damage.total ~= damage.offsetTotal then
        damage.base:SetValue(offset)
        damage.scale:SetValue(damage.width and (damage.total or 0) or offset + (damage.total or 0))
        damage.offset, damage.offsetTotal = offset, damage.total
    end
end

local function updatePoisonOffset(entry, unit, enabled)
    if not entry or not entry.natives then return end
    for _, damage in pairs(entry.natives) do
        -- Called from Core's frame update, outside any pcall of ours: an error here would reach the player's error
        -- window every frame. The segment is switched off for good instead and the reason kept for /upt native.
        local ok, err = pcall(updateNativeOffset, entry, unit, enabled, damage)
        if not ok then
            damage.failed = true
            pcall(damage.container.Hide, damage.container)
            local text = type(err) == "string" and not secret(err) and err or "restricted"
            lastErrors[damage.spec.label] = "offset: " .. text
            if ns.TraceRogueAura then ns.TraceRogueAura("NATIVE " .. damage.spec.label .. " offset failed: " .. text) end
        end
    end
end

-- What one application of the effect does over its whole duration, or nil when the segment has nothing to show.
local function nativeTotal(unit, spec, enabled, entries, entry)
    if not enabled then return nil end
    if spec.gated then
        if gateReplace() then
            -- In place of the plain segment: its length comes from the plan the nameplate has just drawn with.
            local record = entry and plans[entry.parent]
            local item = record and not record.reverse and GetTime() - record.at < 0.5 and record.items[spec.luaName]
            return item and item.damage > 0 and item.damage or nil
        end
        -- The remaining damage of the plain DoT of the same name (it drops tick by tick); nothing when there is none.
        entries = entries or (ns.dotBreakdownForUnit and ns.dotBreakdownForUnit(unit))
        for _, effect in ipairs(entries or {}) do
            if effect.name == spec.luaName and type(effect.damage) == "number" and effect.damage > 0 then
                return effect.damage
            end
        end
        return nil
    end
    if spec.setting and ns.db[spec.setting] == false then return nil end
    local total
    if forever then
        -- Description and stats change slowly; the segment asks every refresh for every plate.
        local now = GetTime()
        local cached = spec.cached
        if not cached or now - cached.at >= 1 then
            cached = { at = now, value = spec.size and spec.size() }
            spec.cached = cached
        end
        total = cached.value
    else total = spec.size and spec.size() end
    if type(total) ~= "number" or total ~= total or total <= 0 or total >= math.huge then return nil end
    if spec.stacked then total = total * MAX_STACKS end -- the bar's full width; no number: the stacks are hidden
    -- Diagnostic switch (nativeShowAll): draw the native segment even where the plain DoT of the same name is shown.
    if forever and ns.db.nativeShowAll == true then return total end
    entries = entries or (ns.dotBreakdownForUnit and ns.dotBreakdownForUnit(unit))
    if entries then
        for _, effect in ipairs(entries) do
            -- Already drawn by the plain DoT segments.
            if (spec.familyID and effect.familyID == spec.familyID) or (spec.luaName and effect.name == spec.luaName)
                or (spec.luaName and spec.ids and spec.ids[effect.spellID]) then
                return nil
            end
        end
    end
    return total
end

local function updateNativeDamage(entry, unit, enabled, spec, entries)
    local config, signature = poisonAppearance(entry, spec)
    if enabled and signature ~= entry.signatures[spec.key] and not (ask(InCombatLockdown) == true
        and ask(entry.parent.IsProtected, entry.parent) == true) then
        -- Restricted descendants cannot be restyled; replace only the poison slot, not the aura icons.
        local old = entry.natives[spec.key]
        local replacement = createNativeDamage(entry, spec, config, signature)
        if replacement then
            if old then pcall(old.container.SetEnabled, old.container, false); pcall(old.container.Hide, old.container) end
            entry.natives[spec.key] = replacement
            if spec.gated and spec.luaName then
                entry.gated = entry.gated or {}
                entry.gated[spec.luaName] = replacement
            end
        end
        entry.signatures[spec.key] = signature
    end
    local damage = entry.natives[spec.key]
    if not damage or damage.failed then return end
    local total = nativeTotal(unit, spec, enabled, entries, entry)
    local label = not spec.stacked and not spec.gated and ns.db and ns.db.showLabel == true
    if total ~= damage.total or label ~= damage.label then
        damage.formatter:SetBreakpoints({ total and label and {
            -- Duration text supplies 0..100 percent, unlike the timer bar's 0..1 fraction.
            threshold = 0, format = "~%.0f", components = { { div = 100 / total, step = 1 } },
        } or { threshold = 0, format = "" } })
        damage.total, damage.label = total, label
    end
    if enabled then
        local maximum = UnitHealthMax(unit)
        damage.scale:SetMinMaxValues(0, maximum)
        damage.base:SetMinMaxValues(0, maximum)
        if forever and not damage.lane and BIT.Plate and BIT.Plate.BarInset then
            -- The frame may not have been laid out when the segment was made: the inset is asked again (cached 1 s).
            local top, bottom = BIT.Plate.BarInset(entry.bar)
            if top ~= damage.insetTop or bottom ~= damage.insetBottom then
                damage.insetTop, damage.insetBottom = fitToBar(entry, damage.base)
                if not damage.width then damage.scale:SetAllPoints(damage.base) end
            end
        end
        local width = ask(entry.bar.GetWidth, entry.bar)
        local barScale = ask(entry.bar.GetEffectiveScale, entry.bar)
        local ownScale = ask(damage.scale.GetEffectiveScale, damage.scale)
        if type(width) == "number" and width > 0 and width < math.huge
            and type(barScale) == "number" and barScale > 0 and barScale < math.huge
            and type(ownScale) == "number" and ownScale > 0 and ownScale < math.huge then width = width * barScale / ownScale
        else width = nil end
        if width and (width ~= width or width >= math.huge) then width = nil end
        if width ~= damage.width then
            damage.scale:ClearAllPoints()
            if width then
                -- Translate a full HP-sized scale; clip the resulting countdown only at the HP bar's edge.
                damage.scale:SetPoint("TOPLEFT", damage.base:GetStatusBarTexture(), "TOPRIGHT")
                damage.scale:SetPoint("BOTTOMLEFT", damage.base:GetStatusBarTexture(), "BOTTOMRIGHT")
                damage.scale:SetWidth(width)
            else damage.scale:SetAllPoints((forever or damage.lane) and damage.base or entry.bar) end
            damage.width, damage.offset = width, nil
        end
    end
    updateNativeOffset(entry, unit, enabled, damage)
    -- shortcut: hidden full-bar geometry or poison above max HP clips early; replace when native uncapped sizing is available.
end

local function create(parent, bar, onPlate)
    if failedHosts[parent] == bar then return end
    if ask(InCombatLockdown) == true and ask(parent.IsProtected, parent) == true then return end
    local container
    local ok = pcall(function()
        container = CreateFrame("AuraContainer", nil, parent, "CustomAuraContainerTemplate")
        assert(type(container.AddAuraGroup) == "function" and type(container.SetUnit) == "function"
            and type(container.SetEnabled) == "function" and type(container.UpdateAllAuras) == "function")
        container:SetSize(1, 1)
        container:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 0, 4)
        local strata = ask(bar.GetFrameStrata, bar)
        if type(strata) == "string" then container:SetFrameStrata(strata) end
        local level = ask(bar.GetFrameLevel, bar)
        container:SetFrameLevel(type(level) == "number" and level + 5 or 200)
        -- Forever draws only the damage segments: the icons would crowd the unit frames and plates.
        if not forever then
            container:AddAuraGroup("rogue", "HARMFUL|PLAYER", {
                candidateFilters = { includeSpellIDs = spellIDs },
                initializeFrame = initialize,
                maxFrameCount = 8,
                layout = { elementWidth = SIZE, elementHeight = SIZE, elementSpacing = GAP },
            })
        end
    end)
    if not ok then
        -- A failed initializer must not allocate another batch on every shared refresh.
        failedHosts[parent] = bar
        if usable(container) then
            pcall(container.SetEnabled, container, false)
            pcall(container.Hide, container)
        end
        return
    end
    local entry = { container = container, parent = parent, bar = bar, onPlate = onPlate, natives = {}, signatures = {} }
    return entry
end

local function displayContainer(entry, state, unit, enabled, refresh)
    local container = state.container
    if not usable(container) then return end
    -- Nameplate addons re-level health bars while active; keep native projections above them.
    local level, strata = ask(entry.bar.GetFrameLevel, entry.bar), ask(entry.bar.GetFrameStrata, entry.bar)
    level = type(level) == "number" and level + ((forever and state.spec and state.spec.gated and gateReplace()) and 10 or 5) or 200
    if forever and state.spec and state.spec.gated and gateReplace() and ns.db.nativeShowAll == true then
        level, strata = level + 40, "HIGH" -- probing: above whatever else the plate draws
    end
    if level ~= state.level and pcall(container.SetFrameLevel, container, level) then state.level = level end
    if type(strata) == "string" and strata ~= state.strata
        and pcall(container.SetFrameStrata, container, strata) then state.strata = strata end
    if enabled and state.unit ~= unit then
        if not pcall(container.SetUnit, container, unit) then return end
        state.unit = unit
    end
    if state.enabled ~= enabled then
        if not pcall(container.SetEnabled, container, enabled) then return end
        state.enabled = enabled
    end
    local now = GetTime()
    -- Recheck native aura state for late procs and missed incremental updates; keep its real expiry.
    if enabled and (refresh == true or refresh == unit or (refresh == false
        and (not state.refreshedAt or now - state.refreshedAt >= AURA_REFRESH_INTERVAL))) then
        pcall(container.UpdateAllAuras, container)
        state.refreshedAt = now
    end
    -- A protected parent can defer visibility changes until combat ends; disabling still clears auras.
    if state.shown ~= enabled then
        if ask(InCombatLockdown) == true and (ask(container.IsProtected, container) == true
            or ask(entry.parent.IsProtected, entry.parent) == true) then return end
        local method = enabled and container.Show or container.Hide
        if pcall(method, container) then state.shown = enabled end
    end
end

-- Forever: every UNIT_AURA of the target or a plate runs the whole update for every entry. Looks, sizes and the list of
-- plain DoTs are looked at about ten times a second per entry however many events arrive (right away when the unit,
-- the switch or a forced refresh changes); only the native refresh below follows each event.
local HEAVY_INTERVAL = 0.09

-- The experiment's second row for a spec whose plain DoT the addon draws (it needs the DoT's name to find it).
local function gatedTwin(spec)
    if not spec.luaName or not (spec.generic or spec.verified) then return nil end
    local twin = spec.twin
    if not twin then
        twin = {}
        for key, value in pairs(spec) do twin[key] = value end
        twin.key, twin.slot, twin.label = spec.key .. "G", spec.slot .. "G", spec.label .. " (GATE)"
        twin.gated, twin.twin, twin.stacked, twin.size, twin.covers = true, nil, nil, nil, nil
        spec.twin = twin
    end
    return twin
end
local NO_SPECS = {}

local function display(entry, unit, enabled, refresh)
    if not entry then return end
    if forever and ns.db and ns.db.nativeDots == false then enabled = false end
    local allDots = wantGeneric()
    local now = GetTime()
    local heavy = not forever or refresh == true or not entry.heavyAt or now - entry.heavyAt >= HEAVY_INTERVAL
        or entry.heavyEnabled ~= enabled or entry.heavyUnit ~= unit
    local entries
    if heavy then
        entry.heavyAt, entry.heavyEnabled, entry.heavyUnit = now, enabled, unit
        if forever and enabled and ns.dotBreakdownForUnit then entries = ns.dotBreakdownForUnit(unit) end
    end
    for _, spec in ipairs(heavy and currentSpecs(allDots) or NO_SPECS) do
        local ok, err = pcall(updateNativeDamage, entry, unit, enabled, spec, entries)
        if not ok then
            local broken = entry.natives[spec.key]
            if broken then
                broken.failed = true
                pcall(broken.container.Hide, broken.container)
            end
        end
        if not ok and not entry.poisonError then
            entry.poisonError = true
            if ns.TraceRogueAura then
                local text = type(err) == "string" and not secret(err) and err or "restricted"
                lastErrors[spec.label] = "update: " .. text
                ns.TraceRogueAura("NATIVE " .. spec.label .. " update failed: " .. text)
            end
        end
    end
    local replace = gateReplace()
    local laneGate = forever and ns.db and ns.db.nativeGate == true and not replace
    local gate = laneGate or (replace and entry.onPlate == true)
    if heavy and gate then
        for _, spec in ipairs(currentSpecs(allDots)) do
            local twin = gatedTwin(spec)
            if twin and not pcall(updateNativeDamage, entry, unit, enabled, twin, entries) then
                local broken = entry.natives[twin.key]
                if broken then
                    broken.failed = true
                    pcall(broken.container.Hide, broken.container)
                end
            end
        end
    end
    displayContainer(entry, entry, unit, enabled, refresh)
    for _, damage in pairs(entry.natives) do
        -- Generic segments go dark with their setting, the gated row with its own; the container stays for when it is
        -- switched on again.
        displayContainer(entry, damage, unit, enabled and not damage.failed
            and (not damage.spec.generic or allDots) and (not damage.spec.gated or gate), refresh)
    end
end

local function hostile(unit)
    return ask(UnitExists, unit) == true and ask(UnitCanAttack, "player", unit) == true
end

local function update(refresh)
    if not started or not ns.db then return end
    if wantGeneric() then advanceGeneric() end
    -- The master switch (nativeDots) also hands traps and Wyvern Sting back to the old rhythm guess in ProcDots.
    local nativeOn = not forever or ns.db.nativeDots ~= false
    if forever and ns.ProcDots then
        for _, spec in ipairs(activeSpecs) do
            if spec.covers then ns.ProcDots[spec.covers] = nativeOn end
        end
    end
    local markers = ns.db.showMarkers ~= false and nativeOn
    local targetHost, targetBar
    if BIT.Plate and BIT.Plate.UnitFrame then targetHost, targetBar = BIT.Plate.UnitFrame("target")
    else targetHost, targetBar = TargetFrame, healthBar(TargetFrame, false) end
    if targetEntry and (targetEntry.parent ~= targetHost or targetEntry.bar ~= targetBar) then
        display(targetEntry, nil, false)
        targetEntry = nil
    end
    if markers and ns.db.targetMarkers ~= false and targetHost and targetBar and hostile("target") then
        targetEntry = targetEntry or create(targetHost, targetBar, false)
        display(targetEntry, "target", true, refresh)
    else
        display(targetEntry, nil, false)
    end
    local current = {}
    for unit in pairs(activeUnits) do
        local plate = ask(C_NamePlate and C_NamePlate.GetNamePlateForUnit, unit)
        local bar = healthBar(plate, true)
        if bar then
            local entry = byPlate[plate]
            if entry and entry.bar ~= bar then display(entry, nil, false); entry = nil end
            local enabled = markers and ns.db.nameplateMode ~= "off" and hostile(unit)
            if enabled and not entry then entry = create(plate, bar, true); byPlate[plate] = entry end
            if entry then
                current[entry] = true
                display(entry, unit, enabled, refresh)
            end
        end
    end
    for _, entry in pairs(byPlate) do
        if not current[entry] then display(entry, nil, false) end
    end
end

local lateTry
function R.UpdateRogueAuras()
    if not started and wantGeneric() then
        local now = GetTime()
        if not lateTry or now - lateTry >= 5 then
            lateTry = now
            R.StartRogueAuras()
        end
    end
    update(false)
end

-- Follow plain marker animation/ticks immediately, without resampling any native aura state.
function R.UpdatePoisonOffset(parent)
    local entry = targetEntry and (parent == TargetFrame or parent == targetEntry.parent) and targetEntry or byPlate[parent]
    if entry then updatePoisonOffset(entry, entry.unit, entry.enabled) end
end

-- Nameplates.lua: where each plain DoT segment of this plate is, on the health scale, as it has just been drawn.
function R.SetPlan(plate, items, reverse)
    local record = plans[plate]
    if not record then
        record = {}
        plans[plate] = record
    end
    record.items, record.at, record.reverse = items, GetTime(), reverse == true
end

-- Whether the plain segment of this DoT on this plate may stay hidden: only when its aura-gated twin exists, did not
-- fail and is shown by the game right now. Until then (and whenever anything is off) the plain segment keeps drawing.
function R.Covers(plate, name)
    if not gateReplace() or ns.db.nativeShowAll == true then return false end
    local record = plans[plate]
    if not record or record.reverse then return false end
    local entry = byPlate[plate]
    local damage = entry and entry.gated and entry.gated[name]
    return damage ~= nil and not damage.failed and damage.enabled == true and damage.shown == true
end

local function seedPlates()
    wipe(activeUnits)
    for i = 1, MAX_PLATES do
        local token = "nameplate" .. i
        if ask(UnitExists, token) == true then activeUnits[token] = true end
    end
end

function R.StartRogueAuras()
    if started or ns.off or not ns.db then return end
    local ok, _, class = pcall(UnitClass, "player")
    if not ok or secret(class) or type(class) ~= "string" then return end
    -- A class with no fixed segment (warlock, priest, druid, shaman) only has the every-DoT layer.
    if not SPECS[class] and not wantGeneric() then return end
    if not C_XMLUtil or type(C_XMLUtil.GetTemplateInfo) ~= "function" then return end
    if not events then
        events = CreateFrame("Frame")
        for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "NAME_PLATE_UNIT_ADDED",
            "NAME_PLATE_UNIT_REMOVED", "UNIT_FACTION", "UNIT_AURA", "PLAYER_REGEN_ENABLED", "ADDON_LOADED" }) do
            events:RegisterEvent(event)
        end
        if forever then events:RegisterEvent("SPELLS_CHANGED") end
        events:SetScript("OnEvent", function(_, event, unit)
            if event == "SPELLS_CHANGED" then rebuildGeneric = true; return end
            if event == "ADDON_LOADED" and (secret(unit) or unit ~= "Blizzard_AuraContainer") then return end
            if not started then
                if event ~= "PLAYER_ENTERING_WORLD" and event ~= "PLAYER_REGEN_ENABLED"
                    and event ~= "ADDON_LOADED" then return end
                R.StartRogueAuras()
                if not started then return end
            end
            if event == "UNIT_AURA" then
                if secret(unit) or type(unit) ~= "string"
                    or (unit ~= "target" and not activeUnits[unit]) then return end
                update(unit) -- Request a native refresh for this token without inspecting aura data.
                return
            end
            if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_REGEN_ENABLED" then wipe(failedHosts) end
            if event == "PLAYER_ENTERING_WORLD" then
                display(targetEntry, nil, false)
                for _, entry in pairs(byPlate) do display(entry, nil, false) end
                seedPlates()
            elseif event == "NAME_PLATE_UNIT_ADDED" or event == "NAME_PLATE_UNIT_REMOVED" then
                if secret(unit) or type(unit) ~= "string" or not unit:match("^nameplate%d+$") then return end
                activeUnits[unit] = event == "NAME_PLATE_UNIT_ADDED" and true or nil
            end
            update(true)
        end)
    end
    if C_AddOns and ask(C_AddOns.IsAddOnLoaded, "Blizzard_AuraContainer") ~= true then
        if type(C_AddOns.LoadAddOn) == "function" then pcall(C_AddOns.LoadAddOn, "Blizzard_AuraContainer") end
    end
    if ask(C_XMLUtil.GetTemplateInfo, "CustomAuraContainerTemplate") == nil then return end
    started = true
    activeSpecs = SPECS[class] or {}
    -- The segment now draws what ProcDots would only guess from hits: it stops arming those guesses.
    for _, spec in ipairs(activeSpecs) do
        if spec.covers and ns.ProcDots then ns.ProcDots[spec.covers] = true end
    end
    seedPlates()
    update(false)
end

-- /upt native: what the native segments are doing, one printout for a report.
local function describe()
    local lines = {}
    local function add(text) lines[#lines + 1] = text end
    local db = ns.db or {}
    local ok, _, class = pcall(UnitClass, "player")
    add(string.format("native segments (%s): started %s, master %s, every DoT %s, stack text %s, shown next to plain %s, gate %s, gate in place %s, class %s",
        forever and "Forever" or "Retail", tostring(started), tostring(db.nativeDots ~= false),
        tostring(db.nativeAllDots == true), tostring(db.nativeStacks == true), tostring(db.nativeShowAll == true),
        tostring(db.nativeGate == true), tostring(db.nativeGateReplace == true),
        tostring(ok and not secret(class) and class or "?")))
    for _, spec in ipairs(currentSpecs(wantGeneric())) do
        local good, size = pcall(function() return spec.size and spec.size() end)
        add(string.format("  %s%s: size %s", spec.label, spec.generic and " (every DoT)" or "",
            good and type(size) == "number" and string.format("%.0f", size) or "none"))
    end
    local plates, containers = 0, 0
    for _, entry in pairs(byPlate) do
        plates = plates + 1
        for _ in pairs(entry.natives) do containers = containers + 1 end
    end
    if targetEntry then
        for _, damage in pairs(targetEntry.natives) do
            if damage.spec.gated then
                add(string.format("  gate %s: plain size %s", damage.spec.label,
                    damage.total and string.format("%.0f", damage.total) or "none"))
            end
        end
    end
    -- Numbers for a look at the twins that draw nameplate segments in place of the plain ones (nativeGateReplace).
    local function number(value)
        return type(value) == "number" and string.format("%.1f", value) or "none"
    end
    local listed = 0
    for plate, entry in pairs(byPlate) do
        if listed >= 2 then break end
        local record = plans[plate]
        local planned = 0
        if record then
            for _, item in pairs(record.items) do if item.damage > 0 then planned = planned + 1 end end
        end
        local hasTwin = false
        for _, damage in pairs(entry.natives) do
            if damage.spec.gated then
                hasTwin = true
                add(string.format("  plate %s twin %s: offset %s total %s width %s | shown %s enabled %s failed %s | covers %s",
                    tostring(entry.unit or "?"), damage.spec.label, number(damage.offset), number(damage.total),
                    number(damage.width), tostring(damage.shown),
                    tostring(damage.enabled), tostring(damage.failed), tostring(R.Covers(plate, damage.spec.luaName))))
            end
        end
        if hasTwin or record then
            add(string.format("  plate %s plan: %d DoT(s) drawn, age %s s, reverse %s", tostring(entry.unit or "?"), planned,
                record and number(GetTime() - record.at) or "none", tostring(record and record.reverse)))
            listed = listed + 1
        end
    end
    local onTarget, failed = 0, 0
    if targetEntry then for _ in pairs(targetEntry.natives) do onTarget = onTarget + 1 end end
    for _ in pairs(failedHosts) do failed = failed + 1 end
    add(string.format("  target frame: %d segment(s); nameplates: %d with segments (%d containers); failed hosts: %d",
        onTarget, plates, containers, failed))
    local broken = 0
    for _, entry in pairs(byPlate) do
        for _, damage in pairs(entry.natives) do if damage.failed then broken = broken + 1 end end
    end
    if targetEntry then
        for _, damage in pairs(targetEntry.natives) do if damage.failed then broken = broken + 1 end end
    end
    if broken > 0 then add("  switched off after an error: " .. broken .. " segment(s)") end
    if building and building.book then
        add(string.format("  every-DoT list: building, %d of %d spellbook spells done, %.1f ms so far",
            building.index - 1, #building.book, building.ms))
    end
    if genericMs then
        add(string.format("  every-DoT list: %.1f ms in all (largest slice %.1f ms) from %d spellbook spells (built %d time(s), %d skipped as unchanged)",
            genericMs, genericMaxSlice, genericExamined, genericBuilds, genericSkipped))
        add("  spells read by each build: " .. table.concat(genericSizes, ", "))
    end
    for label, text in pairs(lastErrors) do add("  last error " .. label .. " - " .. text) end
    return lines
end

if BIT.RegisterCommand and BIT.Say then
    BIT.RegisterCommand("native", function()
        for _, line in ipairs(describe()) do BIT.Say(line) end
    end)
end
