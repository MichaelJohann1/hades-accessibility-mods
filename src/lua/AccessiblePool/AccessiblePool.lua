--[[
Mod: AccessiblePool
Author: Accessibility Layer
Version: 3

Provides screen reader accessibility for the Purging Pool (Sell Trait Menu).
- Uses component-name-filtered OnMouseOver for SellSlot1-3 buttons
- Speaks god name + trait name + rarity + sell value (Obols) on cursor navigation
- Filters out zero computed values
- Wraps OpenSellTraitMenu to speak screen name
- Wraps CreateSellButtons to label the Reroll button
- Wraps HandleSellChoiceSelection to speak sell confirmation
--]]

local function _Log(msg) if LogEvent then LogEvent(msg) end end

-- Strip Hades text formatting tags for clean screen reader output
local function StripFormatting(text)
    if not text then return "" end
    text = text:gsub("{#[^}]*}", "")
    text = text:gsub("{!Icons%.HealthRestore_Small_Tooltip}", " Healing")
    text = text:gsub("{!Icons%.HealthRestore_Small}", " Healing")
    text = text:gsub("{!Icons%.HealthRestoreHome}", " Healing")
    text = text:gsub("{!Icons%.HealthRestore}", " Healing")
    text = text:gsub("{!Icons%.Health_Small_Tooltip}", " Health")
    text = text:gsub("{!Icons%.Health_Small}", " Health")
    text = text:gsub("{!Icons%.HealthUp_Small}", " Max Health")
    text = text:gsub("{!Icons%.HealthUp}", " Max Health")
    text = text:gsub("{!Icons%.HealthDown_Small}", " Health")
    text = text:gsub("{!Icons%.HealthHome_Small}", " Health")
    text = text:gsub("{!Icons%.HealthHome}", " Health")
    text = text:gsub("{!Icons%.Health}", " Health")
    text = text:gsub("{![^}]*}", "")
    text = text:gsub("{$[^}]*}", "")
    text = text:gsub("{[^}]*}", "")
    text = text:gsub("@%S+", "")
    text = text:gsub("\\n", " ")
    text = text:gsub("\n", " ")
    text = text:gsub("  +", " ")
    text = text:gsub("^%s+", "")
    text = text:gsub("%s+$", "")
    return text
end

-- Safe wrapper for GetDisplayName
local function SafeGetDisplayName(key)
    if not key or key == "" then return "" end
    local ok, result = pcall(GetDisplayName, { Text = key })
    if ok and result and result ~= "" then
        return StripFormatting(result)
    end
    return ""
end

-- Compute actual current values for a trait on the hero using the game's own processing.
-- Uses GetProcessedTraitData with FakeStackNum=1 to get OldTotal (= current values).
local function GetTraitCurrentValues(traitName)
    if not traitName or traitName == "" then return "" end
    if not CurrentRun or not CurrentRun.Hero or not CurrentRun.Hero.Traits then return "" end
    if not GetProcessedTraitData or not SetTraitTextData then return "" end

    local ok, valStr, structParts = pcall(function()
        -- Find the hero's actual trait instance for RarityMultiplier
        local heroTrait = nil
        for _, t in ipairs(CurrentRun.Hero.Traits) do
            if t.Name == traitName then
                heroTrait = t
                break
            end
        end
        if not heroTrait then return nil end

        local tooltipData = GetProcessedTraitData({
            Unit = CurrentRun.Hero,
            TraitName = traitName,
            FakeStackNum = 1,
            RarityMultiplier = heroTrait.RarityMultiplier or 1,
        })
        SetTraitTextData(tooltipData)

        -- OldTotal contains the current values (before the fake +1 level)
        if not tooltipData.OldTotal then return nil end

        local extractData = nil
        if GetExtractData then
            extractData = GetExtractData(tooltipData)
        end

        local parts = {}
        local structuredParts = {}
        for i, val in ipairs(tooltipData.OldTotal) do
            if type(val) == "number" then
                local isPercent = false
                if extractData and extractData[i] and extractData[i].Format then
                    local fmt = extractData[i].Format
                    if fmt == "Percent" or fmt == "PercentDelta" or fmt == "NegativePercentDelta"
                        or fmt == "PercentOfBase" or fmt == "PercentHeal" then
                        isPercent = true
                    end
                end
                local rounded = math.floor(val + 0.5)
                if rounded ~= 0 then
                    local display = _FormatBoonValue and _FormatBoonValue(val, isPercent)
                        or (tostring(rounded) .. (isPercent and "%" or ""))
                    parts[#parts + 1] = display
                    structuredParts[#structuredParts + 1] = { display = display }
                end
            end
        end

        if #parts > 0 then
            local result = ""
            for i, part in ipairs(parts) do
                if i > 1 then result = result .. ", " end
                result = result .. part
            end
            return result, structuredParts
        end
        return nil, nil
    end)

    if ok and valStr then
        return valStr, structParts
    end
    return "", nil
end

-- ============================================================
-- God name mapping for boon traits (same as AccessibleTraitTray)
-- ============================================================
local BoonTraitToGod = {
    -- Zeus (non-obvious names)
    RetaliateWeaponTrait = "Zeus",
    SuperGenerationTrait = "Zeus",
    OnWrathDamageBuffTrait = "Zeus",
    PerfectDashBoltTrait = "Zeus",
    -- Poseidon (non-obvious names)
    SlipperyTrait = "Poseidon",
    SlamExplosionTrait = "Poseidon",
    BonusCollisionTrait = "Poseidon",
    BossDamageTrait = "Poseidon",
    RoomRewardBonusTrait = "Poseidon",
    RandomMinorLootDrop = "Poseidon",
    DefensiveSuperGenerationTrait = "Poseidon",
    EncounterStartOffenseBuffTrait = "Poseidon",
    DoubleCollisionTrait = "Poseidon",
    FishingTrait = "Poseidon",
    -- Athena (non-obvious names)
    EnemyDamageTrait = "Athena",
    TrapDamageTrait = "Athena",
    PreloadSuperGenerationTrait = "Athena",
    LastStandHealTrait = "Athena",
    LastStandDurationTrait = "Athena",
    LastStandHealDrop = "Athena",
    LastStandDurationDrop = "Athena",
    ShieldHitTrait = "Athena",
    -- Ares (non-obvious names)
    IncreasedDamageTrait = "Ares",
    OnEnemyDeathDamageInstanceBuffTrait = "Ares",
    LastStandDamageBonusTrait = "Ares",
    -- Aphrodite (non-obvious names)
    ProximityArmorTrait = "Aphrodite",
    HealthRewardBonusTrait = "Aphrodite",
    CharmTrait = "Aphrodite",
    -- Artemis (non-obvious names)
    CritBonusTrait = "Artemis",
    CriticalBufferMultiplierTrait = "Artemis",
    CriticalSuperGenerationTrait = "Artemis",
    CritVulnerabilityTrait = "Artemis",
    MoreAmmoTrait = "Artemis",
    -- Dionysus (non-obvious names)
    DoorHealTrait = "Dionysus",
    LowHealthDefenseTrait = "Dionysus",
    FountainDamageBonusTrait = "Dionysus",
    DionysusGiftDrop = "Dionysus",
    DionysusComboVulnerability = "Dionysus",
    -- Hermes (non-obvious names)
    BonusDashTrait = "Hermes",
    AmmoReclaimTrait = "Hermes",
    RapidCastTrait = "Hermes",
    RushSpeedBoostTrait = "Hermes",
    MoveSpeedTrait = "Hermes",
    RushRallyTrait = "Hermes",
    DodgeChanceTrait = "Hermes",
    AmmoReloadTrait = "Hermes",
    RegeneratingSuperTrait = "Hermes",
    ChamberGoldTrait = "Hermes",
    SpeedDamageTrait = "Hermes",
    MagnetismTrait = "Hermes",
    UnstoredAmmoDamageTrait = "Hermes",
    -- Demeter (non-obvious names)
    HealingPotencyTrait = "Demeter",
    HealingPotencyDrop = "Demeter",
    HarvestBoonDrop = "Demeter",
    FallbackMoneyDrop = "Demeter",
    CastNovaTrait = "Demeter",
    ZeroAmmoBonusTrait = "Demeter",
    MaximumChillBlast = "Demeter",
    MaximumChillBonusSlow = "Demeter",
    InstantChillKill = "Demeter",
    -- Duo Boons (both gods)
    ImpactBoltTrait = "Zeus, Poseidon",
    ReboundingAthenaCastTrait = "Zeus, Athena",
    AutoRetaliateTrait = "Zeus, Ares",
    RegeneratingCappedSuperTrait = "Zeus, Aphrodite",
    AmmoBoltTrait = "Zeus, Artemis",
    LightningCloudTrait = "Zeus, Dionysus",
    JoltDurationTrait = "Zeus, Demeter",
    StatusImmunityTrait = "Poseidon, Athena",
    PoseidonAresProjectileTrait = "Poseidon, Ares",
    ImprovedPomTrait = "Poseidon, Aphrodite",
    ArtemisBonusProjectileTrait = "Poseidon, Artemis",
    RaritySuperBoost = "Poseidon, Demeter",
    BlizzardOrbTrait = "Demeter, Poseidon",
    TriggerCurseTrait = "Athena, Ares",
    SlowProjectileTrait = "Athena, Aphrodite",
    ArtemisReflectBuffTrait = "Athena, Artemis",
    DionysusNullifyProjectileTrait = "Athena, Dionysus",
    CastBackstabTrait = "Athena, Demeter",
    NoLastStandRegenerationTrait = "Athena, Demeter",
    CurseSickTrait = "Ares, Aphrodite",
    AresHomingTrait = "Ares, Artemis",
    PoisonTickRateTrait = "Ares, Dionysus",
    StationaryRiftTrait = "Ares, Demeter",
    HeartsickCritDamageTrait = "Aphrodite, Artemis",
    DionysusAphroditeStackIncreaseTrait = "Aphrodite, Dionysus",
    SelfLaserTrait = "Aphrodite, Demeter",
    PoisonCritVulnerabilityTrait = "Artemis, Dionysus",
    HomingLaserTrait = "Artemis, Demeter",
    IceStrikeArrayTrait = "Dionysus, Demeter",
}

-- Resolve the god name for a trait, using prefix matching + static lookup
local function GetGodForTrait(traitName)
    if not traitName then return nil end
    if BoonTraitToGod[traitName] then
        return BoonTraitToGod[traitName]
    end
    if traitName:find("^Zeus") then return "Zeus" end
    if traitName:find("^Poseidon") then return "Poseidon" end
    if traitName:find("^Athena") then return "Athena" end
    if traitName:find("^Ares") then return "Ares" end
    if traitName:find("^Aphrodite") then return "Aphrodite" end
    if traitName:find("^Artemis") then return "Artemis" end
    if traitName:find("^Dionysus") then return "Dionysus" end
    if traitName:find("^Hermes") then return "Hermes" end
    if traitName:find("^Demeter") then return "Demeter" end
    return nil
end

-- Boon display names (reuse from AccessibleBoons if loaded, or define local subset)
local SellTraitDisplayNames = {
    -- Zeus
    ZeusWeaponTrait = "Lightning Strike",
    ZeusSecondaryTrait = "Thunder Flourish",
    ZeusRangedTrait = "Electric Shot",
    ZeusRushTrait = "Thunder Dash",
    ZeusShoutTrait = "Lightning Bolt",
    RetaliateWeaponTrait = "Heaven's Vengeance",
    SuperGenerationTrait = "Billowing Strength",
    OnWrathDamageBuffTrait = "Clouded Judgment",
    ZeusChargedBoltTrait = "Double Strike",
    ZeusLightningDebuff = "Static Discharge",
    ZeusSpeedBlessingTrait = "Lightning Phalanx",
    ImmolationTrait = "Splitting Bolt",
    -- Poseidon
    PoseidonWeaponTrait = "Tempest Strike",
    PoseidonSecondaryTrait = "Tempest Flourish",
    PoseidonRangedTrait = "Flood Shot",
    PoseidonRushTrait = "Tidal Dash",
    PoseidonShoutTrait = "Poseidon's Aid",
    EncounterStartOffenseBuffTrait = "Hydraulic Might",
    RoomRewardBonusTrait = "Ocean's Bounty",
    BonusCollisionTrait = "Breaking Wave",
    SlamExplosionTrait = "Typhoon's Fury",
    SecondWaveTrait = "Second Wave",
    RandomMinorLootDrop = "Sunken Treasure",
    -- Athena
    AthenaWeaponTrait = "Divine Strike",
    AthenaSecondaryTrait = "Divine Flourish",
    AthenaRangedTrait = "Phalanx Shot",
    AthenaRushTrait = "Divine Dash",
    AthenaShoutTrait = "Athena's Aid",
    TrapDamageTrait = "Bronze Skin",
    EnemyDamageTrait = "Holy Shield",
    AthenaBackstabDebuffTrait = "Blinding Flash",
    LastStandDurationTrait = "Deathless Stand",
    LastStandHealTrait = "Last Stand",
    PreloadSuperGenerationTrait = "Proud Bearing",
    -- Ares
    AresWeaponTrait = "Curse of Agony",
    AresSecondaryTrait = "Curse of Pain",
    AresRangedTrait = "Slicing Shot",
    AresRushTrait = "Blade Dash",
    AresShoutTrait = "Ares' Aid",
    IncreasedDamageTrait = "Urge to Kill",
    AresAOETrait = "Blade Rift",
    AresLongCurseTrait = "Curse of Vengeance",
    AresLoadCurseTrait = "Engulfing Vortex",
    AresRetaliateTrait = "Curse of Vengeance",
    -- Aphrodite
    AphroditeWeaponTrait = "Heartbreak Strike",
    AphroditeSecondaryTrait = "Heartbreak Flourish",
    AphroditeRangedTrait = "Crush Shot",
    AphroditeRushTrait = "Passion Dash",
    AphroditeShoutTrait = "Aphrodite's Aid",
    AphroditeDeathTrait = "Dying Lament",
    AphroditeRetaliateTrait = "Wave of Despair",
    ProximityArmorTrait = "Different League",
    CharmTrait = "Life Affirmation",
    AphroditeMaxHealthTrait = "Life Affirmation",
    -- Artemis
    ArtemisWeaponTrait = "Deadly Strike",
    ArtemisSecondaryTrait = "Deadly Flourish",
    ArtemisRangedTrait = "True Shot",
    ArtemisShoutTrait = "Artemis' Aid",
    CritBonusTrait = "Pressure Points",
    CritVulnerabilityTrait = "Support Fire",
    ArtemisSupportingFireTrait = "Support Fire",
    ArtemisAmmoExitTrait = "Exit Wounds",
    ArtemisAmmoBoostTrait = "Fully Loaded",
    CriticalBufferMultiplierTrait = "Hunter's Mark",
    -- Dionysus
    DionysusWeaponTrait = "Drunken Strike",
    DionysusSecondaryTrait = "Drunken Flourish",
    DionysusRangedTrait = "Trippy Shot",
    DionysusRushTrait = "Drunken Dash",
    DionysusShoutTrait = "Dionysus' Aid",
    DionysusSlowTrait = "Numbing Sensation",
    DionysusComboVulnerabilityTrait = "Peer Pressure",
    DionysusGiftTrait = "Premium Vintage",
    DoorHealTrait = "After Party",
    DionysusDefenseTrait = "Strong Drink",
    -- Hermes
    HermesWeaponTrait = "Swift Strike",
    HermesSecondaryTrait = "Swift Flourish",
    HermesRushTrait = "Greatest Reflex",
    SpeedDamageTrait = "Rush Delivery",
    HermesShoutDodge = "Second Wind",
    DodgeChanceTrait = "Hyper Sprint",
    MoveSpeedTrait = "Quick Recovery",
    RapidCastTrait = "Quick Favor",
    AmmoReloadTrait = "Auto Reload",
    BonusDashTrait = "Greatest Reflex",
    -- Demeter
    DemeterWeaponTrait = "Frost Strike",
    DemeterSecondaryTrait = "Frost Flourish",
    DemeterRangedTrait = "Crystal Beam",
    DemeterRushTrait = "Mistral Dash",
    DemeterShoutTrait = "Demeter's Aid",
    HealingPotencyTrait = "Nourished Soul",
    ZeroAmmoBonusTrait = "Ravenous Will",
    MaximumChillBlast = "Killing Freeze",
    MaximumChillBonusSlow = "Arctic Blast",
    DemeterRangedBonusTrait = "Glacial Glare",
}

-- Suppress counter for first auto-hover when Pool opens
suppressSellHoverCount = 0

-- ============================================================
-- OnMouseOver handler for sell trait slots
-- ============================================================
OnMouseOver{ "SellSlot1 SellSlot2 SellSlot3",
    function(triggerArgs)
        if not AccessibilityEnabled or not AccessibilityEnabled() then return end
        if suppressSellHoverCount > 0 then
            suppressSellHoverCount = suppressSellHoverCount - 1
            return
        end
        if not IsScreenOpen("SellTraitMenu") then return end
        if not triggerArgs or not triggerArgs.triggeredById then return end
        if not ScreenAnchors.SellTraitScreen or not ScreenAnchors.SellTraitScreen.Components then return end

        local components = ScreenAnchors.SellTraitScreen.Components
        -- Find which purchase button this is
        local buttonKey = nil
        local button = nil
        for i = 1, 3 do
            local key = "PurchaseButton" .. i
            if components[key] and components[key].Id == triggerArgs.triggeredById then
                buttonKey = key
                button = components[key]
                break
            end
        end
        if not button then return end

        local parts = {}

        -- Trait name
        local traitName = button.UpgradeName or ""
        local displayName = SellTraitDisplayNames[traitName] or ""
        if displayName == "" then
            displayName = SafeGetDisplayName(traitName)
        end
        if displayName == "" then
            -- Try BoonDisplayNames from AccessibleBoons if loaded
            if BoonDisplayNames and BoonDisplayNames[traitName] then
                displayName = BoonDisplayNames[traitName]
            end
        end
        if displayName == "" then
            displayName = traitName
        end

        -- Add god name prefix
        local godName = GetGodForTrait(traitName)
        if godName then
            parts[#parts + 1] = godName .. " - " .. displayName
        else
            parts[#parts + 1] = displayName
        end

        -- Rarity
        local rarity = button.Rarity
        if rarity and rarity ~= "" then
            parts[#parts + 1] = rarity
        end

        -- Description (from shared global tables) + actual computed values (substituted)
        local desc = ""
        if traitName ~= "" then
            if GodBoonDescriptions and GodBoonDescriptions[traitName] then
                desc = GodBoonDescriptions[traitName]
            elseif HammerDescriptions and HammerDescriptions[traitName] then
                desc = HammerDescriptions[traitName]
            elseif ChaosBlessingDescriptions and ChaosBlessingDescriptions[traitName] then
                desc = ChaosBlessingDescriptions[traitName]
            end
        end
        local descText = desc ~= "" and StripFormatting(desc) or ""
        local currentVals, valParts = GetTraitCurrentValues(traitName)
        if descText ~= "" and valParts and #valParts > 0 and _SubstituteDescriptionValues then
            local substituted, numReplaced = _SubstituteDescriptionValues(descText, valParts)
            if numReplaced > 0 then
                parts[#parts + 1] = substituted
            else
                parts[#parts + 1] = descText
                if currentVals ~= "" then parts[#parts + 1] = currentVals end
            end
        elseif descText ~= "" then
            parts[#parts + 1] = descText
            if currentVals ~= "" then parts[#parts + 1] = currentVals end
        elseif currentVals ~= "" then
            parts[#parts + 1] = currentVals
        end

        -- Sell value
        local value = button.Value or 0
        if value > 0 then
            parts[#parts + 1] = string.format(UIStrings.SellForFmt, value)
        end

        -- Build speech
        local speech = ""
        for i, part in ipairs(parts) do
            if i == 1 then
                speech = part
            else
                speech = speech .. ", " .. part
            end
        end

        if speech ~= "" then
            TolkSilence()
            TolkSpeak(speech)
        end
    end
}

-- Purging Pool flavor text (hardcoded from HelpText.en.sjson)
-- Game randomly picks one of these 3 via GetRandomValue in SellTraitScripts.lua
local SellTraitFlavorTexts = {
    "One can free oneself from even the most compelling influences.",
    "The will of the Olympians is tenuous, at best, within the Underworld.",
    "The gift of the gods is worth a tidy sum in the land of the dead.",
}

-- ============================================================
-- Wrap OpenSellTraitMenu — set flag so CreateSellButtons can build speech
-- (baseFunc blocks; CreateTextBox captures flavor text during baseFunc)
-- ============================================================
_sellTraitOpening = false

ModUtil.WrapBaseFunction("OpenSellTraitMenu", function(baseFunc)
    _Log("[SCREEN-OPEN] Purging Pool (OpenSellTraitMenu)")
    if AccessibilityEnabled and AccessibilityEnabled() then
        _sellTraitOpening = true
    end
    baseFunc()
    _sellTraitOpening = false
end)

-- ============================================================
-- Wrap CreateSellButtons to label the Reroll button and speak open announcement
-- (runs after CreateTextBox has captured the flavor text via _capturedFlavorText)
-- ============================================================
ModUtil.WrapBaseFunction("CreateSellButtons", function(baseFunc)
    baseFunc()

    if not AccessibilityEnabled or not AccessibilityEnabled() then return end
    if not ScreenAnchors.SellTraitScreen or not ScreenAnchors.SellTraitScreen.Components then return end

    local components = ScreenAnchors.SellTraitScreen.Components
    local rerollPanel = components["RerollPanel"]
    if rerollPanel and rerollPanel.Id then
        rerollPanel.OnMouseOverFunctionName = "AccessibleSellRerollMouseOver"
        AttachLua({ Id = rerollPanel.Id, Table = rerollPanel })
    end

    -- Speak open announcement with correct (captured) flavor text + first item
    if _sellTraitOpening then
        local numOptions = 0
        if CurrentRun and CurrentRun.CurrentRoom and CurrentRun.CurrentRoom.SellOptions then
            for _ in pairs(CurrentRun.CurrentRoom.SellOptions) do
                numOptions = numOptions + 1
            end
        end

        local speech = UIStrings.PoolOfPurging
        -- Use the exact flavor text the game displayed (captured by AccessibleBoons' CreateTextBox wrapper)
        if _capturedFlavorText and _capturedFlavorText ~= "" then
            speech = speech .. ". " .. _capturedFlavorText
            _capturedFlavorText = nil
        end
        if numOptions > 0 then
            speech = speech .. ". " .. string.format(UIStrings.BoonsToSellFmt, numOptions)
        else
            speech = speech .. ". " .. UIStrings.SoldOut
        end

        -- Combine with first sell item
        local firstButton = components["PurchaseButton1"]
        if firstButton then
            local traitName = firstButton.UpgradeName or ""
            local displayName = SellTraitDisplayNames[traitName] or ""
            if displayName == "" then displayName = SafeGetDisplayName(traitName) end
            if displayName == "" and BoonDisplayNames and BoonDisplayNames[traitName] then
                displayName = BoonDisplayNames[traitName]
            end
            if displayName == "" then displayName = traitName end
            if displayName ~= "" then
                -- Add god name prefix
                local godName = GetGodForTrait(traitName)
                if godName then
                    speech = speech .. ", " .. godName .. " - " .. displayName
                else
                    speech = speech .. ", " .. displayName
                end
                local rarity = firstButton.Rarity
                if rarity and rarity ~= "" then
                    speech = speech .. ", " .. rarity
                end
                -- Description + actual rarity-scaled values (substituted)
                local desc = ""
                if traitName ~= "" then
                    if GodBoonDescriptions and GodBoonDescriptions[traitName] then
                        desc = GodBoonDescriptions[traitName]
                    elseif HammerDescriptions and HammerDescriptions[traitName] then
                        desc = HammerDescriptions[traitName]
                    elseif ChaosBlessingDescriptions and ChaosBlessingDescriptions[traitName] then
                        desc = ChaosBlessingDescriptions[traitName]
                    end
                end
                local descText = desc ~= "" and StripFormatting(desc) or ""
                local currentVals, valParts = GetTraitCurrentValues(traitName)
                if descText ~= "" and valParts and #valParts > 0 and _SubstituteDescriptionValues then
                    local substituted, numReplaced = _SubstituteDescriptionValues(descText, valParts)
                    if numReplaced > 0 then
                        speech = speech .. ". " .. substituted
                    else
                        speech = speech .. ". " .. descText
                        if currentVals ~= "" then speech = speech .. ". " .. currentVals end
                    end
                elseif descText ~= "" then
                    speech = speech .. ". " .. descText
                    if currentVals ~= "" then speech = speech .. ". " .. currentVals end
                elseif currentVals ~= "" then
                    speech = speech .. ". " .. currentVals
                end
                local value = firstButton.Value or 0
                if value > 0 then
                    speech = speech .. ", " .. string.format(UIStrings.SellForFmt, value)
                end
            end
        end

        TolkSilence()
        TolkSpeak(speech)
        suppressSellHoverCount = 1
        _sellTraitOpening = false
    end
end)

-- Reroll button handler
function AccessibleSellRerollMouseOver(button)
    if not AccessibilityEnabled or not AccessibilityEnabled() then return end
    local speech = string.format(UIStrings.FatedPersuasionFmt, UIStrings.PoolOfPurging)
    if button and button.Cost then
        if button.Cost < 0 then
            speech = speech .. ", " .. UIStrings.Blocked
        else
            speech = speech .. ", " .. string.format(UIStrings.CostFmt, button.Cost)
            if button.Cost == 1 then
                speech = speech .. " " .. UIStrings.Charge
            else
                speech = speech .. " " .. UIStrings.Charges
            end
        end
    end
    if CurrentRun and CurrentRun.NumRerolls then
        speech = speech .. ", " .. CurrentRun.NumRerolls .. " " .. UIStrings.Remaining
    end
    TolkSilence()
    TolkSpeak(speech)
end

-- ============================================================
-- Wrap HandleSellChoiceSelection to speak sell confirmation
-- ============================================================
ModUtil.WrapBaseFunction("HandleSellChoiceSelection", function(baseFunc, screen, button)
    local traitName = button and button.UpgradeName or ""
    local value = button and button.Value or 0
    local displayName = SellTraitDisplayNames[traitName] or ""
    if displayName == "" then
        displayName = SafeGetDisplayName(traitName)
    end
    if displayName == "" and BoonDisplayNames and BoonDisplayNames[traitName] then
        displayName = BoonDisplayNames[traitName]
    end
    if displayName == "" then
        displayName = traitName
    end

    baseFunc(screen, button)

    if AccessibilityEnabled and AccessibilityEnabled() then
        local godName = GetGodForTrait(traitName)
        local soldName = displayName
        if godName then
            soldName = godName .. " - " .. displayName
        end
        TolkSilence()
        TolkSpeak(string.format(UIStrings.SoldFmt, soldName, value))
    end
end)
