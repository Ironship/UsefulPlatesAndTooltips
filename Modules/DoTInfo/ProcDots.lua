-- UsefulPlatesAndTooltips module DoTInfo: damage over time that no cast of yours puts on the target (WoW: Forever).
--
--   * Traps. Immolation Trap only arms when placed: the trap, not you, casts the DoT when an enemy walks in, so no
--     cast event says when or on whom. The DoT starts on the mob that takes the first plausible unmatched tick of
--     its school while the trap is armed. After Does It Die's springTrap (Joe Greive, MIT; see
--     LICENSE-DoesItDie.txt).
--   * Ignite (mage) and Deep Wounds (warrior). A critical hit lights them, and the client reports who was hit but
--     not who hit, so a crit counts as yours when you cast at that mob a moment before (or, for Deep Wounds, swing at
--     it while alone). The player is assumed to have the talent when their class can have it; when the talent tree
--     can be read and says no points, nothing is shown. Ignite pays 8% a point of the fire crit that lit it over 4 s
--     in two ticks (40% at 5 of 5); Deep Wounds 20% a point of the main hand's average weapon damage over 12 s in four
--     ticks (60% at 3 of 3). A crit on a running one rolls what it still owed into the new one (the beta client's
--     numbers, ElliotWood/Forever sim). Both start "waiting" for their first tick when the setting says so: the
--     attribution of a crit is a guess, the first tick proves it.
--
-- Everything here is Forever only (Retail has no readable source for a hit).
local _, BIT = ...
local ns = BIT.Module("DoTInfo")

local P = {}
ns.ProcDots = P

local CAST_WINDOW = 3     -- seconds after a cast of yours at a mob in which its crit may be yours (projectiles)
local PENDING_WINDOW = 0.3 -- a crit can arrive just before the cast event that explains it
local FIRE_BITS = 4
local PHYSICAL = 1

local SPECS = {
    MAGE = { name = "Ignite", spellID = 412538, talentID = 11119, maxRank = 5, perRank = 0.08, duration = 4,
        interval = 2, school = 4, basis = "hit" },
    WARRIOR = { name = "Deep Wounds", spellID = 412609, talentID = 12834, maxRank = 3, perRank = 0.20, duration = 12,
        interval = 3, school = PHYSICAL, basis = "weapon", autoAttack = true },
}

local armed          -- an armed trap: { spellID, name, total, school, duration, interval, placedAt, expiresAt }
local recent = {}    -- [mob key] = when you last cast at it
local lastCast       -- { key, at }
local pending        -- an unattributed crit, kept for a moment: { key, unit, amount, school, at }

local function isSecret(v)
    if type(issecretvalue) ~= "function" then return false end
    local ok, r = pcall(issecretvalue, v)
    return ok and r or false
end

local function I() return ns.Internals end

local function enabled()
    local internals = I()
    local settings = internals and internals.getDb()
    return settings ~= nil and settings.procDots ~= false
end

local function db() return I().getDb() end

local function trace(msg) I().trace(msg) end

local playerClass
local function spec()
    if not playerClass and type(UnitClass) == "function" then
        local ok, _, token = pcall(UnitClass, "player")
        if ok and not isSecret(token) and type(token) == "string" then playerClass = token end
    end
    local s = playerClass and SPECS[playerClass]
    if s and enabled() then return s end
end

-- The talent's rank: what the talent tree says (CastPrediction's reader, by spell id, which works even with that
-- module switched off); when the tree cannot be read, or does not list the talent, the maximum is assumed. A tree
-- that answers "no points" is believed.
local function rankOf(s)
    local cast = BIT.modules and BIT.modules.CastPrediction
    local talents = type(cast) == "table" and cast.Talents
    if type(talents) == "table" and type(talents.NodeRank) == "function" then
        local ok, rank = pcall(talents.NodeRank, { s.talentID }, s.name)
        if ok and type(rank) == "number" and rank >= 0 then return math.min(rank, s.maxRank) end
    end
    return s.maxRank
end

local function fireSchool(school)
    if bit and bit.band then return bit.band(school, FIRE_BITS) ~= 0 end
    return school == FIRE_BITS or school == FIRE_BITS + 16
end

local function schoolMatches(s, school)
    if s.school == FIRE_BITS then return fireSchool(school) end
    return school == s.school
end

---------------------------------------------------------------------------------------------
-- Ticks of a DoT this file starts: the same bookkeeping a matched tick gets in Core.lua
---------------------------------------------------------------------------------------------

local function recordTick(dot, amount, isCrit, index, now)
    local internals = I()
    dot.ticksSeen = dot.ticksSeen + 1
    dot.lastTickAmount, dot.lastTickShape, dot.lastTickCrit = amount, 1, isCrit
    dot.offBeatCandidate = nil
    if not isCrit and amount > 0 then
        dot.tickSum = dot.tickSum + amount
        dot.normalTicks = dot.normalTicks + 1
        internals.saveLearnedTick(dot)
    end
    return internals.anchorTick(dot, index, now)
end

---------------------------------------------------------------------------------------------
-- Traps
---------------------------------------------------------------------------------------------

-- Placing a trap: arms it (a new Fire trap replaces the armed one; Explosive Trap does too, see NoteCast).
-- Returns true when the cast was a trap and is handled.
function P.ArmTrap(spellID, name, desc, total, school, duration, statedInterval)
    if not I() or not ns.TRAP_DOTS[name] then return false end
    if not enabled() then return true end -- switched off: the cast is still not a DoT on the target
    local now = GetTime()
    local interval = statedInterval or 3
    local lifetime = type(desc) == "string" and not isSecret(desc) and tonumber(desc:match("[Tt]rap will exist for (%d+) min"))
    armed = { spellID = spellID, name = name, total = total, school = school, duration = duration,
        interval = interval, placedAt = now, expiresAt = now + (lifetime or 1) * 60 }
    local learned = db().ticks[spellID]
    trace(string.format("TRAP %s (id %d) armed: %.0f dmg over %ss, school %d, per-tick %s", name, spellID, total,
        duration, school, learned and ("learned " .. learned) or "from description"))
    return true
end

-- An armed trap's first tick: an unmatched hit of its school and a plausible size on any mob, at least one tick
-- after the trap was placed. Without a learned size the description's share is only a rough guide (it leaves out
-- attack power), so the range is wide. If the trapped mob's first tick went unseen (not the target, focus or a
-- visible nameplate), a later tick is taken for the first and the estimate runs high for that trap.
local function springTrap(key, unit, amount, school, isCrit, now)
    local trap = armed
    if not trap or school ~= trap.school then return false end
    if now > trap.expiresAt + trap.interval + 0.45 then armed = nil return false end
    if now < trap.placedAt + trap.interval - 0.45 then return false end
    local internals = I()
    local dot = internals.newDot(trap.spellID, trap.spellID, trap.name, trap.total, trap.school, trap.duration,
        trap.interval, now - trap.interval)
    if db().ticks[trap.spellID] then
        if not internals.plausibleTickAmount(dot, amount, isCrit, 1) then return false end
    else
        local share = trap.total / dot.totalTicks
        local low, high = share * 0.5, share * 2.5
        if isCrit then low, high = low * 1.3, high * 2.3 end
        if amount < low or amount > high then return false end
    end
    armed = nil
    internals.dotsByTarget[key] = internals.dotsByTarget[key] or {}
    internals.dotsByTarget[key][trap.name] = dot
    local tickIndex = recordTick(dot, amount, isCrit, 1, now)
    trace(string.format("TRAP %s sprung on %s: first tick %d%s %.1fs after placing (tick %d/%d)", trap.name, unit,
        amount, isCrit and " CRIT" or "", now - trap.placedAt, tickIndex, dot.totalTicks))
    return true
end

---------------------------------------------------------------------------------------------
-- Ignite and Deep Wounds
---------------------------------------------------------------------------------------------

local function mainHandAverage()
    local sdi = BIT.modules and BIT.modules.SpellDamageInfo
    if type(sdi) == "table" and type(sdi.MainHandAverage) == "function" then
        local ok, value = pcall(sdi.MainHandAverage)
        if ok and type(value) == "number" and value > 0 then return value end
    end
end

-- Starts the DoT a crit lights (or rolls what the running one still owed into a new one).
local function light(s, key, amount, now)
    local internals = I()
    local rank = rankOf(s)
    if rank <= 0 then return false end
    local share = s.perRank * rank
    local base
    if s.basis == "hit" then
        base = amount * share
    else
        local weapon = mainHandAverage()
        if not weapon then
            trace(string.format("PROC %s: crit of %d on %s but the weapon damage is unreadable", s.name, amount, key))
            return false
        end
        base = weapon * share
    end
    local dots = internals.dotsByTarget[key]
    if not dots then
        dots = {}
        internals.dotsByTarget[key] = dots
    end
    local old = dots[s.name]
    local owed = old and internals.remainingDamage(old) or 0
    local dot = internals.newDot(s.spellID, nil, s.name, owed + base, s.school, s.duration, s.interval, now)
    dot.unsure = true -- the crit's owner is a guess until the first tick lands
    dot.procDot = true
    dot.segmentOrder = old and old.segmentOrder
    dots[s.name] = dot
    trace(string.format("PROC %s on %s: %.0f%% (rank %d) of %s -> %.0f dmg over %ss%s", s.name, key, share * 100, rank,
        s.basis == "hit" and ("a crit of " .. amount) or "the main hand's average", owed + base, s.duration,
        owed > 0 and string.format(", %.0f still owed rolled in", owed) or ""))
    return true
end

-- Whether a crit of this school on this mob may be yours.
local function mine(s, key, unit, now)
    local at = key and recent[key]
    if at and now - at <= CAST_WINDOW then return true end
    local internals = I()
    local targetKey = internals.unitKey("target")
    if lastCast and now - lastCast.at <= CAST_WINDOW and (lastCast.key == nil or lastCast.key == key)
        and targetKey and targetKey == key then
        return true
    end
    -- Auto attacks have no cast event: alone, a physical crit on the target you are swinging at is yours.
    if s.autoAttack and targetKey and targetKey == key and type(IsCurrentSpell) == "function"
        and type(IsInGroup) == "function" then
        local okA, attacking = pcall(IsCurrentSpell, 6603)
        local okG, grouped = pcall(IsInGroup)
        if okA and okG and not isSecret(attacking) and not isSecret(grouped) and attacking and not grouped then
            return true
        end
    end
    return false
end

---------------------------------------------------------------------------------------------
-- Hooks called by Core.lua
---------------------------------------------------------------------------------------------

-- Every cast of yours at a mob (key may be nil). A new Fire trap, Explosive Trap included, replaces the armed one.
function P.NoteCast(key, spellID, name, desc)
    if not I() then return end
    local now = GetTime()
    if armed and (ns.FIRE_TRAPS[name] or (type(desc) == "string" and not isSecret(desc) and desc:find("Fire trap"))) then
        armed = nil
        trace("TRAP disarmed by " .. tostring(name) .. " (only one Fire trap can be active)")
    end
    -- A cast with no readable recipient counts only when it deals damage: a self-buff must not open the window.
    if key or (type(desc) == "string" and not isSecret(desc) and desc:find("[Dd]amage")) then
        lastCast = { key = key, at = now }
    end
    for old, at in pairs(recent) do
        if now - at > 30 then recent[old] = nil end
    end
    if key then recent[key] = now end
    -- A crit that arrived a moment before this cast event.
    if pending and now - pending.at <= PENDING_WINDOW then
        local p = pending
        pending = nil
        local s = spec()
        if s and schoolMatches(s, p.school) and (key == nil or key == p.key) then light(s, p.key, p.amount, now) end
    end
end

-- Whether a hit of this kind could start something here, so Core.lua keeps it even where no DoT runs.
function P.Wants(isCrit, school)
    if not I() then return false end
    if armed and school == armed.school then return true end
    if isCrit and enabled() then
        local s = spec()
        return s ~= nil and schoolMatches(s, school)
    end
    return false
end

-- A hit no DoT claimed. Returns true when it started one (the display then flashes).
function P.OnUnmatchedHit(key, unit, amount, school, isCrit, now)
    if not I() then return false end
    if armed and springTrap(key, unit, amount, school, isCrit, now) then return true end
    if not isCrit then return false end
    local s = spec()
    if not s or not schoolMatches(s, school) then return false end
    if mine(s, key, unit, now) then return light(s, key, amount, now) end
    pending = { key = key, unit = unit, amount = amount, school = school, at = now }
    return false
end

function P.Reset()
    armed, lastCast, pending = nil, nil, nil
    recent = {}
end
