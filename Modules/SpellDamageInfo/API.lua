-- UsefulPlatesAndTooltips: the public SpellDamageInfo API. See API.md.
local _, BIT = ...
local ns = BIT.Module("SpellDamageInfo")
local api = { API_VERSION = 1 }

-- Draw SpellDamageInfo's number on a button of your own. `button` is a frame; `button.action` is the action slot it shows
-- (set it again when the slot changes; the numbers follow at the next refresh). Returns true when the button was taken.
function api.RegisterButton(button)
    return ns.RegisterButton(button) == true
end

-- Stops drawing on the button and hides its numbers.
function api.UnregisterButton(button)
    ns.UnregisterButton(button)
end

-- Asks for the numbers to be worked out again (for example after you changed `button.action`).
-- Pass a registered button to update it on the current frame without waiting for the coalesced timer.
function api.Refresh(button)
    if button and ns.RefreshButton then
        if ns.RefreshButton(button) then return end
    end
    if ns.Refresh then ns.Refresh() end
end

-- Immediately redraws a single registered button (no coalescing delay).
function api.RefreshButton(button)
    return ns.RefreshButton and ns.RefreshButton(button) == true or false
end

BIT.API.Register("SpellDamageInfo", api, { module = "SpellDamageInfo" })
