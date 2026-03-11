--[[
Mod: AccessiblePact
Author: Accessibility Layer
Version: 5

Provides screen reader accessibility for the Pact of Punishment (ShrineUpgrade) screen.
- Speaks screen name + flavor text + heat + first item as one combined string
- Upgrade navigation is handled by AccessibleMirror's global OnMouseOver handler
  (both screens share CreateMetaUpgradeEntry, so component IDs are registered in the map)
- Suppresses AccessibleMirror's first OnMouseOver via suppressMirrorHoverCount
  to prevent the first item from being spoken twice
--]]

local function _Log(msg) if LogEvent then LogEvent(msg) end end

-- Pact condition display names (same as MetaUpgradeDisplayNames in AccessibleMirror)
local PactDisplayNames = {
    EnemyDamageShrineUpgrade = "Hard Labor",
    HealingReductionShrineUpgrade = "Lasting Consequences",
    ShopPricesShrineUpgrade = "Convenience Fee",
    EnemyCountShrineUpgrade = "Jury Summons",
    BossDifficultyShrineUpgrade = "Extreme Measures",
    EnemyHealthShrineUpgrade = "Calisthenics Program",
    EnemyEliteShrineUpgrade = "Benefits Package",
    MinibossCountShrineUpgrade = "Middle Management",
    ForceSellShrineUpgrade = "Underworld Customs",
    EnemySpeedShrineUpgrade = "Forced Overtime",
    TrapDamageShrineUpgrade = "Heightened Security",
    MetaUpgradeStrikeThroughShrineUpgrade = "Routine Inspection",
    EnemyShieldShrineUpgrade = "Damage Control",
    ReducedLootChoicesShrineUpgrade = "Approval Process",
    BiomeSpeedShrineUpgrade = "Tight Deadline",
    NoInvulnerabilityShrineUpgrade = "Personal Liability",
}

-- Speak when the Pact of Punishment (ShrineUpgrade) screen opens
ModUtil.WrapBaseFunction("OpenShrineUpgradeMenu", function(baseFunc, args)
    _Log("[SCREEN-OPEN] Pact of Punishment (OpenShrineUpgradeMenu)")
    if AccessibilityEnabled and AccessibilityEnabled() then
        local totalHeat = 0
        local maxHeat = 0

        if GetTotalSpentShrinePoints then
            local ok, val = pcall(GetTotalSpentShrinePoints)
            if ok and val then totalHeat = val end
        end

        if GetMaximumPossibleShrinePoints then
            local ok, val = pcall(GetMaximumPossibleShrinePoints)
            if ok and val then maxHeat = val end
        end

        local openSpeech = UIStrings.PactOfPunishment

        -- Include flavor text
        if GetDisplayName then
            local flavorOk, flavor = pcall(GetDisplayName, { Text = "ShrineMenu_Flavor" })
            if flavorOk and flavor and flavor ~= "" and flavor ~= "ShrineMenu_Flavor" then
                flavor = flavor:gsub("{#[^}]*}", ""):gsub("{![^}]*}", ""):gsub("{$[^}]*}", ""):gsub("{[^}]*}", ""):gsub("@%S+", ""):gsub("  +", " "):gsub("^%s+", ""):gsub("%s+$", "")
                if flavor ~= "" then
                    openSpeech = openSpeech .. ". " .. flavor
                end
            else
                openSpeech = openSpeech .. ". Infernal Contract Valid for Eternity in the Underworld of Hades"
            end
        end

        openSpeech = openSpeech .. ". " .. string.format(UIStrings.PactOpenFmt, totalHeat, maxHeat)

        -- Append confirm button text (cursor lands on confirm button when Pact opens)
        openSpeech = openSpeech .. ". " .. string.format(UIStrings.StartRunFmt, totalHeat)

        -- Suppress the confirm button auto-hover (we already announced it above)
        if suppressConfirmHoverCount ~= nil then
            suppressConfirmHoverCount = 1
        end
        -- Do NOT suppress upgrade item hovers — the cursor lands on the confirm
        -- button, not an upgrade, so suppressMirrorHoverCount would eat the first
        -- navigation scroll instead of the intended auto-hover

        TolkSilence()
        TolkSpeak(openSpeech)
    end
    baseFunc(args)
end)
