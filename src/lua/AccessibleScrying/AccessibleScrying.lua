--[[
Mod: AccessibleScrying
Author: Accessibility Layer
Version: 2

Provides screen reader accessibility for the Scrying Pool (HouseWaterBowl01) in the bedroom.
- Wraps UseWaterBowl to speak run attempts and enemy kills via TolkSpeak
- Speech is BEFORE baseFunc because DisplayCosmeticInfo has ~3 seconds of wait() calls
- The native function uses DisplayCosmeticInfo which creates a temporary speech bubble
  that auto-fades after 3 seconds — no close needed, just walk away.
--]]

local function _Log(msg) if LogEvent then LogEvent(msg) end end

-- Wrap UseWaterBowl to speak the scrying pool info
ModUtil.WrapBaseFunction("UseWaterBowl", function(baseFunc, usee, args)
    _Log("[SCREEN-OPEN] Scrying Pool (UseWaterBowl)")
    -- Capture the data before calling base (base has a cooldown check)
    local numRuns = nil
    local numKills = nil
    pcall(function()
        numRuns = 1 + TableLength(GameState.RunHistory)
        numKills = GameState.TotalRequiredEnemyKills
    end)

    -- Speak BEFORE base — baseFunc calls DisplayCosmeticInfo which blocks for ~3 seconds
    if AccessibilityEnabled and AccessibilityEnabled() and numRuns then
        local parts = { UIStrings.ScryingPool }

        parts[#parts + 1] = string.format(UIStrings.EscapeAttemptsFmt, numRuns)
        if numKills and numKills > 0 then
            parts[#parts + 1] = string.format(UIStrings.FoesVanquishedFmt, numKills)
        end

        local speech = ""
        for i, part in ipairs(parts) do
            if i == 1 then
                speech = part
            else
                speech = speech .. ", " .. part
            end
        end

        TolkSilence()
        TolkSpeak(speech)
    end

    baseFunc(usee, args)
end)
