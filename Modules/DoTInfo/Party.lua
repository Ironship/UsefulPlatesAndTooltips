-- UsefulPlatesAndTooltips module DoTInfo: Party DoTs (ported from DoesItDie PR #37 + #51 by Joe Greive, MIT;
-- see LICENSE-DoesItDie.txt).
--
-- Shares DoT estimates with party/raid members who run DoesItDie or UsefulPlatesAndTooltips with
-- "Share DoTs with party" enabled, so the marker, nameplates, focus frame and kill icon count everyone's DoTs.
--
-- Wire protocol uses the shared prefix "DoesItDie" (version 1) for full cross-addon compatibility:
--   M;1;<guid>;<dots>  my DoTs on that mob, replacing what I sent before; dots = spellID:school:damage:nextTickIn:
--                      ticksLeft:interval, comma-separated; empty = none left
--   H;1;q / H;1;a      hello query / answer. Nothing is sent until a peer answers.
-- Open world only, creature GUID keys only, token-bucket throttled, and restricted to PARTY/RAID/INSTANCE_CHAT
-- messages from current group members. Forever only.

local _, BIT = ...
local ns = BIT.Module("DoTInfo")

local PREFIX = "DoesItDie"
local VERSION = 1
local MAX_BYTES = 255
local TICK_SECONDS = 0.2
local REFRESH_SECONDS = 6
local BUCKET_SIZE, BUCKET_RATE = 6, 1
local THROTTLE_BACKOFF = 1
local REFUSED_PAUSE = 5
local ANSWER_GAP = 5
local HELLO_RETRY = 20
local EXPIRY_TOLERANCE = 1
local TICK_TOLERANCE = 0.05

local wipe = wipe or function(t) for k in pairs(t) do t[k] = nil end return t end

local party = { remote = {}, peers = {} }
ns.party = party

local sent = {}
local pending = {}
local answeredAt = {}
local tokens, tokensAt = BUCKET_SIZE, nil
local pausedUntil = 0
local wasEnabled = false
local helloAt = -math.huge
local prefixRegistered = false

local function isSecret(v)
    if type(issecretvalue) ~= "function" then return false end
    local ok, r = pcall(issecretvalue, v)
    return ok and r == true
end

local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, r, r2 = pcall(fn, ...)
    if ok and not isSecret(r) then return r, r2 end
end

local function trace(msg)
    if ns.trace then ns.trace(msg) end
end

local function enabled()
    return not ns.off and not ns.Retail and ns.db ~= nil and ns.db.partyDots == true
end

local function isGuid(key)
    return type(key) == "string" and not isSecret(key) and key:match("^%a+%-%d+%-") ~= nil
end

local function baseName(name)
    if type(name) ~= "string" or isSecret(name) then return nil end
    return name:match("^[^%-%s]+")
end

local function myName()
    return baseName(call(UnitName, "player"))
end

local function formatNumber(v)
    if v == math.floor(v) then return string.format("%d", v) end
    return (string.format("%.1f", v):gsub("%.0$", ""))
end

local function finite(v)
    return type(v) == "number" and not isSecret(v) and v == v and v ~= math.huge and v ~= -math.huge
end

---------------------------------------------------------------------------
-- Codec
---------------------------------------------------------------------------

function party.encode(guid, dots)
    local msg = "M;" .. VERSION .. ";" .. guid .. ";"
    local first = true
    for _, d in ipairs(dots) do
        if finite(d.spellID) and finite(d.school) and finite(d.damage) and finite(d.nextTickIn)
            and finite(d.ticksLeft) and finite(d.interval) then
            local item = string.format("%d:%d:%d:%s:%d:%s", d.spellID, d.school, math.floor(d.damage + 0.5),
                formatNumber(math.max(0, d.nextTickIn)), d.ticksLeft, formatNumber(d.interval))
            local candidate = msg .. (first and "" or ",") .. item
            if #candidate > MAX_BYTES then break end
            msg, first = candidate, false
        end
    end
    return msg
end

function party.decode(msg)
    if isSecret(msg) or type(msg) ~= "string" then return nil, "not a string" end
    local kind, version, rest = msg:match("^(%a);(%d+);?(.*)$")
    if not kind or tonumber(version) ~= VERSION then return nil, "not ours or another version" end
    if kind == "H" then return "H", { query = rest == "q" } end
    if kind ~= "M" then return nil, "unknown kind" end
    local guid, list = rest:match("^([^;]+);(.*)$")
    if not isGuid(guid) then return nil, "bad mob key" end
    local dots = {}
    for item in list:gmatch("[^,]+") do
        local a, b, c, d, e, f = item:match("^(%d+):(%d+):(%d+):([%d%.]+):(%d+):([%d%.]+)$")
        local dot = { spellID = tonumber(a), school = tonumber(b), damage = tonumber(c), nextTickIn = tonumber(d),
            ticksLeft = tonumber(e), interval = tonumber(f) }
        if not (dot.spellID and dot.school and dot.damage and dot.nextTickIn and dot.ticksLeft and dot.interval)
            or dot.ticksLeft < 1 or dot.interval <= 0 then
            return nil, "bad dot"
        end
        dots[#dots + 1] = dot
    end
    return "M", { guid = guid, dots = dots }
end

---------------------------------------------------------------------------
-- Receiving
---------------------------------------------------------------------------

local function ticksLeftAt(d, now)
    if now < d.nextTickAt then return d.ticksLeft end
    return math.max(0, d.ticksLeft - (math.floor((now - d.nextTickAt) / d.interval) + 1))
end

local function store(sender, guid, dots, now)
    local mobs = party.remote[sender]
    if #dots == 0 then
        if mobs then mobs[guid] = nil end
        return
    end
    if not mobs then
        mobs = {}
        party.remote[sender] = mobs
    end
    local list = {}
    for _, d in ipairs(dots) do
        local nextTickAt = now + d.nextTickIn
        list[#list + 1] = { spellID = d.spellID, school = d.school, perTick = d.damage / d.ticksLeft,
            ticksLeft = d.ticksLeft, interval = d.interval, nextTickAt = nextTickAt, receivedAt = now,
            expiresAt = nextTickAt + (d.ticksLeft - 1) * d.interval }
    end
    mobs[guid] = list
end

-- Adds party members' DoTs on the mob behind `key` to `list` (Core.lua dotBreakdown calls this).
function party.addRemote(key, list)
    if not enabled() or not isGuid(key) then return end
    local now = GetTime()
    for sender, mobs in pairs(party.remote) do
        local dots = mobs[key]
        if dots then
            local any = false
            for _, d in ipairs(dots) do
                local left = ticksLeftAt(d, now)
                if left > 0 then
                    any = true
                    local name = C_Spell and call(C_Spell.GetSpellName, d.spellID)
                    list[#list + 1] = { name = name or ("Spell " .. d.spellID), spellID = d.spellID,
                        school = d.school, appliedAt = d.receivedAt, expiresAt = d.expiresAt,
                        damage = d.perTick * left, remote = true, sender = sender,
                        segmentOrder = { rank = 4, appliedAt = d.receivedAt } }
                end
            end
            if not any then mobs[key] = nil end
        end
    end
end

local function forgetAll()
    wipe(party.remote)
    wipe(party.peers)
    wipe(sent)
    wipe(pending)
end

---------------------------------------------------------------------------
-- Sending
---------------------------------------------------------------------------

local function channel()
    return call(IsInRaid) == true and "RAID" or "PARTY"
end

local function refill(now)
    if tokensAt then tokens = math.min(BUCKET_SIZE, tokens + (now - tokensAt) * BUCKET_RATE) end
    tokensAt = now
end

local function ensurePrefix()
    if prefixRegistered or not (C_ChatInfo and type(C_ChatInfo.RegisterAddonMessagePrefix) == "function") then
        return
    end
    prefixRegistered = pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
end

local function send(msg, now)
    if not (C_ChatInfo and type(C_ChatInfo.SendAddonMessage) == "function") then return false end
    ensurePrefix()
    refill(now)
    if now < pausedUntil or tokens < 1 then return false end
    tokens = tokens - 1
    local ok, result = pcall(C_ChatInfo.SendAddonMessage, PREFIX, msg, channel())
    if ok and (result == nil or result == 0 or result == true) then return true end
    if ok and result == 3 then
        tokens, pausedUntil = 0, now + THROTTLE_BACKOFF
    else
        pausedUntil = now + REFUSED_PAUSE
    end
    trace("PARTY send refused (" .. tostring(ok and result or "error") .. "): " .. msg:sub(1, 60))
    return false
end

local function canSend()
    if call(IsInGroup) ~= true then return false end
    if call(IsInInstance) == true then return false end
    if call(IsEncounterInProgress) == true then return false end
    return true
end

local function outgoing(list, now)
    local dots, shape = {}, {}
    for _, d in ipairs(list or {}) do
        if finite(d.nextTickAt) and finite(d.expiresAt) and finite(d.interval) and d.interval > 0
            and finite(d.damage) and d.damage > 0 and d.nextTickAt <= d.expiresAt + d.interval / 2 then
            local ticksLeft = math.floor((d.expiresAt - d.nextTickAt) / d.interval + 0.5) + 1
            dots[#dots + 1] = { spellID = d.spellID, school = d.school, damage = d.damage,
                nextTickIn = d.nextTickAt - now, ticksLeft = ticksLeft, interval = d.interval }
            shape[d.spellID] = { expiresAt = d.expiresAt, perTick = d.damage / ticksLeft }
        end
    end
    return dots, shape
end

local function changed(shape, last)
    for spellID, s in pairs(shape) do
        local l = last[spellID]
        if not l or math.abs(s.expiresAt - l.expiresAt) > EXPIRY_TOLERANCE
            or math.abs(s.perTick - l.perTick) > math.max(1, l.perTick * TICK_TOLERANCE) then
            return true
        end
    end
    for spellID in pairs(last) do
        if not shape[spellID] then return true end
    end
    return false
end

local function sendHello(query, now)
    local ok = send("H;" .. VERSION .. ";" .. (query and "q" or "a"), now)
    if ok and query then helloAt = now end
    return ok
end

local function senderTick(now)
    local own = ns.ownDots and ns.ownDots() or {}
    local current = {}
    for key, list in pairs(own) do
        if isGuid(key) then
            local dots, shape = outgoing(list, now)
            if #dots > 0 then
                current[key] = { dots = dots, shape = shape }
                local last = sent[key]
                if not last or changed(shape, last.shape) or now - last.at >= REFRESH_SECONDS then
                    pending[key] = true
                end
            end
        end
    end
    for key in pairs(sent) do
        if not current[key] then pending[key] = true end
    end
    for key in pairs(pending) do
        local c = current[key]
        local msg = party.encode(key, c and c.dots or {})
        if not send(msg, now) then break end
        pending[key] = nil
        sent[key] = c and { shape = c.shape, at = now } or nil
        trace("PARTY send " .. msg)
    end
end

local function tick(now)
    local on = enabled()
    if on ~= wasEnabled then
        wasEnabled = on
        forgetAll()
        helloAt = -math.huge
        if on then ensurePrefix() end
    end
    if not on or not canSend() then return end
    if next(party.peers) == nil then
        if now - helloAt >= HELLO_RETRY then sendHello(true, now) end
        return
    end
    senderTick(now)
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local function groupNames()
    local names = {}
    local raid = call(IsInRaid) == true
    for i = 1, raid and 40 or 4 do
        local name = baseName(call(UnitName, (raid and "raid" or "party") .. i))
        if name then names[name] = true end
    end
    return names
end

-- Only group channels from current group members are accepted (DoesItDie PR #51).
local GROUP_CHANNELS = { PARTY = true, RAID = true, INSTANCE_CHAT = true }

local function onMessage(prefix, text, chan, sender)
    if isSecret(prefix) or prefix ~= PREFIX or not enabled() then return end
    if isSecret(chan) or not GROUP_CHANNELS[chan] then return end
    local who = baseName(sender)
    if not who or who == myName() or not groupNames()[who] then return end
    local kind, payload = party.decode(text)
    if not kind then return end
    local now = GetTime()
    party.peers[who] = true
    if kind == "H" then
        if payload.query and now - (answeredAt[who] or -math.huge) >= ANSWER_GAP and canSend() then
            answeredAt[who] = now
            sendHello(false, now)
        end
    else
        store(who, payload.guid, payload.dots, now)
        trace(string.format("PARTY recv from %s: %s", who, text))
    end
end

local function onRoster()
    if call(IsInGroup) ~= true then
        forgetAll()
        return
    end
    local names = groupNames()
    for who in pairs(party.peers) do
        if not names[who] then party.peers[who] = nil end
    end
    for who in pairs(party.remote) do
        if not names[who] then party.remote[who] = nil end
    end
    if next(party.peers) == nil then helloAt = -math.huge end
end

party._onMessage = onMessage
party._onRoster = onRoster
party._tick = tick

local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:SetScript("OnEvent", function(self, event, ...)
    if ns.off or ns.Retail then
        self:UnregisterAllEvents()
        self:SetScript("OnUpdate", nil)
        return
    end
    if event == "CHAT_MSG_ADDON" then
        onMessage(...)
    else
        onRoster()
    end
end)
local elapsedSince = 0
frame:SetScript("OnUpdate", function(self, elapsed)
    if ns.off or ns.Retail then
        self:UnregisterAllEvents()
        self:SetScript("OnUpdate", nil)
        return
    end
    elapsedSince = elapsedSince + elapsed
    if elapsedSince < TICK_SECONDS - 0.001 then return end
    elapsedSince = 0
    tick(GetTime())
end)
if BIT.Perf then
    BIT.Perf.Watch(frame, "OnEvent", "DoTInfo.party")
    BIT.Perf.Watch(frame, "OnUpdate", "DoTInfo.party")
end
