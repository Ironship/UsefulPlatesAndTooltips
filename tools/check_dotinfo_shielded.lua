-- Regression check for DoTInfo ns.shielded: unknown (secret) state must not hide the kill icon.
-- Run from the repository root: lua tools/check_dotinfo_shielded.lua
local f = assert(io.open("Modules/DoTInfo/Core.lua", "rb"))
local src = f:read("*a")
f:close()
local block = assert(src:match("\n(do\nlocal protectionSpells.-\nend\nend)\n"), "ns.shielded block not found")

local SECRET = setmetatable({}, { __index = function() error("secret read") end })
local env = setmetatable({ ns = {}, trace = function() end, C_Spell = { GetSpellName = function(id)
    return id == 17 and "Power Word: Shield" or nil
end } }, { __index = _G })
env.isSecret = function(v) return v == SECRET end
assert(load(block, "shielded", "t", env))()

local function check(absorb, buffs, expected, label)
    env.UnitGetTotalAbsorbs = function() return absorb end
    env.C_UnitAuras = { GetBuffDataByIndex = function(_, i) return buffs[i] end }
    assert(env.ns.shielded("target") == expected, label)
end

check(SECRET, {}, false, "secret absorb, no buffs: icon must show")
check(SECRET, { SECRET }, false, "secret absorb and secret buff: icon must show")
check(0, { { name = SECRET, spellId = SECRET } }, false, "unreadable buff fields: icon must show")
check(500, {}, true, "readable absorb hides the icon")
check(SECRET, { SECRET, { name = "x", spellId = 17 } }, true, "known shield after an unreadable buff hides the icon")
check(0, { { name = "Power Word: Shield", spellId = SECRET } }, true, "known shield name hides the icon")
check(0, { { name = "Renew", spellId = 139 } }, false, "harmless buff keeps the icon")
print("check_dotinfo_shielded: ok")
