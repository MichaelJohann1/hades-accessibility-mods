--[[
Mod: AccessibleMirror
Author: Accessibility Layer
Version: 10

Provides screen reader accessibility for the Mirror of Night (MetaUpgrade) screen
and shares the CreateMetaUpgradeEntry wrapper with the Pact of Punishment (ShrineUpgrade).
- Speaks upgrade name, description, current level, cost, and affordability
- Uses component-name-filtered OnMouseOver handlers (same pattern as native MetaUpgrades.lua)
- Also uses a BackingTooltip ID map for invisible hover targets (no native lookup exists)
- Wraps HandleMetaUpgradeInput for post-purchase speech feedback
- Re-builds ID map after UpdateButtonStates (button destruction/recreation)
- Detects locked upgrades and speaks Chthonic Key cost to unlock
- Hardcoded descriptions since GetDisplayName can't resolve _ShortTotal localization keys
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
    -- Strip stray +/- UI indicator characters that remain after icon removal
    text = text:gsub("^%s*[%+%-%%]+%s*$", "")  -- entire string is just +/-/% chars
    text = text:gsub("%s+[%+%-%%]+%s*$", "")    -- trailing +/-/% at end
    text = text:gsub("^%s*[%+%-%%]+%s+", "")    -- leading +/-/% at start
    text = text:gsub("  +", " ")
    text = text:gsub("^%s+", "")
    text = text:gsub("%s+$", "")
    return text
end

-- Flavor text for Mirror of Night upgrades (lore descriptions, appended to navigation speech)
MirrorFlavorText = {
    BackstabMetaUpgrade = "The darkness itself serves as your weapon, dealing more damage when you strike foes from behind.",
    FirstStrikeMetaUpgrade = "Your first strike against an undamaged foe burns with greater intensity.",
    DoorHealMetaUpgrade = "The underworld sustains you, restoring a small amount of health each time you enter a new chamber.",
    DarknessHealMetaUpgrade = "The Darkness you collect heals your wounds, converting a portion into restored health.",
    ExtraChanceMetaUpgrade = "Defy death itself, returning from the brink when your life would otherwise end.",
    ExtraChanceReplenishMetaUpgrade = "Your stubborn will to survive restores you once in every chamber, though for less health.",
    StaminaMetaUpgrade = "Your reflexes sharpen, letting you chain additional dashes together before needing to recover.",
    PerfectDashMetaUpgrade = "Perfectly-timed dashes reward you with a surge of power and the ability to dodge attacks.",
    StoredAmmoVulnerabilityMetaUpgrade = "Your Cast ammo embedded in foes weakens them, causing your attacks to deal more damage.",
    StoredAmmoSlowMetaUpgrade = "Your Cast ammo embedded in foes saps their strength, slowing their movement and reducing their damage.",
    AmmoMetaUpgrade = "Your Cast is empowered with additional ammo, letting you lodge more bloodstones in your foes.",
    ReloadAmmoMetaUpgrade = "Your Cast ammo regenerates on its own, but you can no longer pick it up from foes.",
    MoneyMetaUpgrade = "You begin each escape attempt with a stash of Obols, giving you a head start at Charon's shop.",
    InterestMetaUpgrade = "Your wealth grows as you progress, earning interest on your Obols when you clear each region.",
    HealthMetaUpgrade = "Your resilience increases, permanently adding to your maximum health.",
    HighHealthDamageMetaUpgrade = "While your health is high, your confidence translates into greater damage against foes.",
    VulnerabilityEffectBonusMetaUpgrade = "Foes suffering from multiple Status Curses take significantly more damage from all sources.",
    GodEnhancementMetaUpgrade = "The more Olympians who have blessed you, the stronger you become in their combined favor.",
    RareBoonDropMetaUpgrade = "The Olympians look upon you with favor, increasing the chance their Boons will be Rare.",
    RunProgressRewardMetaUpgrade = "Your foresight guides you toward more valuable rewards in each chamber.",
    EpicBoonDropMetaUpgrade = "The gods take pride in your progress, increasing the chance their Boons will be Epic.",
    DuoRarityBoonDropMetaUpgrade = "The gods have entrusted you with a greater chance of receiving their most powerful combined blessings.",
    RerollMetaUpgrade = "You can alter fate itself, re-rolling the reward offered in the next chamber.",
    RerollPanelMetaUpgrade = "You can persuade fate to change its mind, re-rolling Boon and Well of Charon choices.",
}

-- Flavor text for Pact of Punishment conditions (lore descriptions)
PactFlavorText = {
    EnemyDamageShrineUpgrade = "Your enemies grow stronger, dealing more damage with every strike against you.",
    HealingReductionShrineUpgrade = "Wounds linger longer, as healing effects throughout the underworld are diminished.",
    ShopPricesShrineUpgrade = "Charon grows greedier, raising prices at his shop and the Wells of Charon.",
    EnemyCountShrineUpgrade = "More foes are summoned to stand in your way during standard encounters.",
    BossDifficultyShrineUpgrade = "The bosses of the underworld unleash devastating new abilities against you.",
    EnemyHealthShrineUpgrade = "Your foes have been training, gaining additional health to withstand your attacks.",
    EnemyEliteShrineUpgrade = "Armored foes gain powerful new abilities, making them far more dangerous.",
    MinibossCountShrineUpgrade = "An additional mini-boss appears in encounters, adding to the chaos.",
    ForceSellShrineUpgrade = "You must surrender one of your Boons to pass between each region of the underworld.",
    EnemySpeedShrineUpgrade = "Your enemies work faster, moving and attacking at an accelerated pace.",
    TrapDamageShrineUpgrade = "Traps and magma throughout the underworld deal dramatically more damage.",
    MetaUpgradeStrikeThroughShrineUpgrade = "Your Mirror of Night talents are systematically disabled, one by one.",
    EnemyShieldShrineUpgrade = "Each foe carries a protective shield that absorbs the first hit it receives.",
    ReducedLootChoicesShrineUpgrade = "Bureaucracy reduces your choices when selecting Boons, Well items, and Chaos rewards.",
    BiomeSpeedShrineUpgrade = "Time is running out to clear each region, and lingering brings harm.",
    NoInvulnerabilityShrineUpgrade = "You lose all brief invulnerability after taking damage, leaving you exposed.",
}

-- Hardcoded display names for Mirror of Night + Pact of Punishment upgrades
-- (GetDisplayName doesn't resolve MetaUpgrade keys — the engine resolves them
-- only during CreateTextBox rendering, not through the Lua GetDisplayName function)
MetaUpgradeDisplayNames = {
    BackstabMetaUpgrade = "Shadow Presence",
    FirstStrikeMetaUpgrade = "Fiery Presence",
    DoorHealMetaUpgrade = "Chthonic Vitality",
    DarknessHealMetaUpgrade = "Dark Regeneration",
    ExtraChanceMetaUpgrade = "Death Defiance",
    ExtraChanceReplenishMetaUpgrade = "Stubborn Defiance",
    StaminaMetaUpgrade = "Greater Reflex",
    PerfectDashMetaUpgrade = "Ruthless Reflex",
    StoredAmmoVulnerabilityMetaUpgrade = "Boiling Blood",
    StoredAmmoSlowMetaUpgrade = "Abyssal Blood",
    AmmoMetaUpgrade = "Infernal Soul",
    ReloadAmmoMetaUpgrade = "Stygian Soul",
    MoneyMetaUpgrade = "Deep Pockets",
    InterestMetaUpgrade = "Golden Touch",
    HealthMetaUpgrade = "Thick Skin",
    HighHealthDamageMetaUpgrade = "High Confidence",
    VulnerabilityEffectBonusMetaUpgrade = "Privileged Status",
    GodEnhancementMetaUpgrade = "Family Favorite",
    RareBoonDropMetaUpgrade = "Olympian Favor",
    RunProgressRewardMetaUpgrade = "Dark Foresight",
    EpicBoonDropMetaUpgrade = "Gods' Pride",
    DuoRarityBoonDropMetaUpgrade = "Gods' Legacy",
    RerollMetaUpgrade = "Fated Authority",
    RerollPanelMetaUpgrade = "Fated Persuasion",
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

-- Hardcoded descriptions for upgrades (sourced from Hades Wiki)
-- GetDisplayName cannot resolve _ShortTotal localization keys (they use CreateTextBoxWithFormat
-- variable substitution via LuaKey/LuaValue which only works at render time)
-- These are the per-level descriptions that change with upgrade level
MetaUpgradeDescriptions = {
    -- Mirror of Night upgrades (12 pairs = 24 total)
    -- Pair order matches MetaUpgradeOrder in MetaUpgradeData.lua
    -- Descriptions sourced from Hades Wiki (exact wording)
    -- Pair 1: Shadow Presence / Fiery Presence
    BackstabMetaUpgrade = {
        base = "Attack and Special gain +%d%% damage per rank when striking foes from behind",
        perLevel = 10, -- +10% per rank, 5 ranks, 50% max
    },
    FirstStrikeMetaUpgrade = {
        base = "Attack and Special gain +%d%% damage per rank when striking undamaged foes",
        perLevel = 10, -- +10% per rank, 5 ranks, 50% max
    },
    -- Pair 2: Chthonic Vitality / Dark Regeneration
    DoorHealMetaUpgrade = {
        base = "Each rank restores %d health when you exit each chamber",
        perLevel = 1, -- +1 per rank, 3 ranks, 3 max
    },
    DarknessHealMetaUpgrade = {
        base = "Each rank makes +%d%% of any Darkness you collect restore your health by that much",
        perLevel = 30, -- 30% per rank, 2 ranks, 60% max
    },
    -- Pair 3: Death Defiance / Stubborn Defiance
    ExtraChanceMetaUpgrade = {
        text = "Each rank restores you for 50%% health one time when your Life Total is depleted. Uses per escape attempt: %d",
        usesLevel = true, -- 3 ranks = 3 uses
    },
    ExtraChanceReplenishMetaUpgrade = {
        text = "This restores you to 30%% health one time per chamber when your Life Total is depleted",
        static = true,
    },
    -- Pair 4: Greater Reflex / Ruthless Reflex
    StaminaMetaUpgrade = {
        text = "Each rank lets you chain +1 Dash before briefly recovering",
        static = true,
    },
    PerfectDashMetaUpgrade = {
        text = "If you Dash just before getting hit, gain +50%% damage and dodge chance for 2 seconds",
        static = true,
    },
    -- Pair 5: Boiling Blood / Abyssal Blood
    StoredAmmoVulnerabilityMetaUpgrade = {
        base = "Each rank gives you +%d%% Attack and Special damage to foes with cast ammo in them",
        perLevel = 10, -- +10% per rank, 5 ranks, 50% max
    },
    StoredAmmoSlowMetaUpgrade = {
        base = "Each rank reduces foes' speed and damage by -%d%% while they have cast ammo in them",
        perLevel = 6, -- -6% per rank, 5 ranks, -30% max
    },
    -- Pair 6: Infernal Soul / Stygian Soul
    AmmoMetaUpgrade = {
        base = "Each rank gives you +%d for your Cast",
        perLevel = 1, -- +1 per rank, 2 ranks
    },
    ReloadAmmoMetaUpgrade = {
        text = "Your cast regenerates, but no longer drops. Each rank makes this 1 second faster",
        static = true,
    },
    -- Pair 7: Deep Pockets / Golden Touch
    MoneyMetaUpgrade = {
        base = "Each rank grants you %d obols at the start of each escape from the House of Hades",
        perLevel = 10, -- +10 per rank, 10 ranks, 100 max
    },
    InterestMetaUpgrade = {
        base = "Each rank grants you +%d%% of your total obols each time you clear an Underworld region",
        perLevel = 5, -- +5% per rank, 3 ranks, 15% max
    },
    -- Pair 8: Thick Skin / High Confidence
    HealthMetaUpgrade = {
        base = "Each rank adds +%d to your Life Total",
        perLevel = 5, -- +5 per rank, 10 ranks, 50 max
    },
    HighHealthDamageMetaUpgrade = {
        base = "Each rank gives you +%d%% damage while you have 80%% or greater health",
        perLevel = 5, -- +5% per rank, 5 ranks, 25% max
    },
    -- Pair 9: Privileged Status / Family Favorite
    VulnerabilityEffectBonusMetaUpgrade = {
        base = "Each rank gives you +%d%% damage vs. foes afflicted by at least two Status Curse effects",
        perLevel = 20, -- +20% per rank, 2 ranks, 40% max
    },
    GodEnhancementMetaUpgrade = {
        base = "Each rank gives you +%d%% damage for each different Olympian whose Boons you have",
        perLevel = 2.5, -- custom format needed
        formatFunc = true,
    },
    -- Pair 10: Olympian Favor / Dark Foresight
    RareBoonDropMetaUpgrade = {
        base = "Each rank adds a +%d%% bonus chance for a Boon to be Rare",
        perLevel = 1, -- +1% per rank, 40 ranks, 40% max
    },
    RunProgressRewardMetaUpgrade = {
        base = "Each rank gives you +%d%% greater chance for high-value rewards (Boons, Hammers, Obol and Poms)",
        perLevel = 2, -- +2% per rank, 10 ranks, 20% max
    },
    -- Pair 11: Gods' Pride / Gods' Legacy
    EpicBoonDropMetaUpgrade = {
        base = "Each rank adds a +%d%% bonus chance for a Boon to be Epic",
        perLevel = 1, -- +1% per rank, 20 ranks, 20% max
    },
    DuoRarityBoonDropMetaUpgrade = {
        base = "Each rank gives you +%d%% greater chance for a Boon to be Legendary or a Duo (if possible)",
        perLevel = 1, -- +1% per rank, 10 ranks, 10% max
    },
    -- Pair 12: Fated Authority / Fated Persuasion
    RerollMetaUpgrade = {
        base = "Each rank gives you %d dice, used to randomly alter the reward for the next chamber",
        perLevel = 1,
    },
    RerollPanelMetaUpgrade = {
        base = "Each rank gives you %d dice, used to randomly alter Boon and Well of Charon choices",
        perLevel = 1,
    },
    -- Pact of Punishment upgrades (16 conditions)
    EnemyDamageShrineUpgrade = {
        base = "Foes deal %d%% more damage",
        perLevel = 20, -- 5 ranks: 20/40/60/80/100
    },
    HealingReductionShrineUpgrade = {
        base = "All healing effects are reduced by %d%%",
        perLevel = 25, -- 4 ranks: 25/50/75/100
    },
    ShopPricesShrineUpgrade = {
        base = "Prices at the Well of Charon and Charon's shop are %d%% higher",
        perLevel = 40, -- 2 ranks: 40/80
    },
    EnemyCountShrineUpgrade = {
        base = "%d%% more foes appear in standard encounters",
        perLevel = 20, -- 3 ranks: 20/40/60
    },
    BossDifficultyShrineUpgrade = {
        text = "Boss encounters become more dangerous with new abilities and mechanics per rank",
        static = true, -- 4 ranks, each adds specific boss changes
    },
    EnemyHealthShrineUpgrade = {
        base = "Foes have %d%% more Health",
        perLevel = 15, -- 2 ranks: 15/30
    },
    EnemyEliteShrineUpgrade = {
        text = "Armored foes gain 1 additional ability per rank",
        static = true, -- 2 ranks
    },
    MinibossCountShrineUpgrade = {
        text = "You encounter 1 additional mini-boss per encounter",
        static = true, -- 1 rank
    },
    ForceSellShrineUpgrade = {
        text = "You must purge 1 Boon to unlock the exit to each Underworld region",
        static = true, -- 1 rank
    },
    EnemySpeedShrineUpgrade = {
        base = "Foes move and attack %d%% faster",
        perLevel = 20, -- 2 ranks: 20/40
    },
    TrapDamageShrineUpgrade = {
        text = "All Traps and Magma deal 400%% more damage",
        static = true, -- 1 rank
    },
    MetaUpgradeStrikeThroughShrineUpgrade = {
        text = "Disables your last unlocked Mirror of Night talent per rank",
        static = true, -- 4 ranks
    },
    EnemyShieldShrineUpgrade = {
        text = "Each foe has a damage-absorbing shield blocking the first hit per rank",
        static = true, -- 2 ranks
    },
    ReducedLootChoicesShrineUpgrade = {
        text = "Your choices are reduced by 1 when picking Boons, items at the Well, and rewards from Chaos",
        static = true, -- 2 ranks
    },
    BiomeSpeedShrineUpgrade = {
        base = "You have %d minutes to clear each Underworld region, or else you take damage",
        perLevel = -2, -- 3 ranks: 9/7/5 minutes
        baseValue = 11, -- 11 + (-2 * rank) = 9/7/5
    },
    NoInvulnerabilityShrineUpgrade = {
        text = "You no longer have any brief period of invulnerability after taking damage",
        static = true, -- 1 rank
    },
}

-- Pair lookup: maps each Mirror upgrade to its alternate in the same pair
-- Built from MetaUpgradeOrder (12 pairs x 2 = 24 entries)
local MetaUpgradePairs = {
    BackstabMetaUpgrade = "FirstStrikeMetaUpgrade",
    FirstStrikeMetaUpgrade = "BackstabMetaUpgrade",
    DoorHealMetaUpgrade = "DarknessHealMetaUpgrade",
    DarknessHealMetaUpgrade = "DoorHealMetaUpgrade",
    ExtraChanceMetaUpgrade = "ExtraChanceReplenishMetaUpgrade",
    ExtraChanceReplenishMetaUpgrade = "ExtraChanceMetaUpgrade",
    StaminaMetaUpgrade = "PerfectDashMetaUpgrade",
    PerfectDashMetaUpgrade = "StaminaMetaUpgrade",
    StoredAmmoVulnerabilityMetaUpgrade = "StoredAmmoSlowMetaUpgrade",
    StoredAmmoSlowMetaUpgrade = "StoredAmmoVulnerabilityMetaUpgrade",
    AmmoMetaUpgrade = "ReloadAmmoMetaUpgrade",
    ReloadAmmoMetaUpgrade = "AmmoMetaUpgrade",
    MoneyMetaUpgrade = "InterestMetaUpgrade",
    InterestMetaUpgrade = "MoneyMetaUpgrade",
    HealthMetaUpgrade = "HighHealthDamageMetaUpgrade",
    HighHealthDamageMetaUpgrade = "HealthMetaUpgrade",
    VulnerabilityEffectBonusMetaUpgrade = "GodEnhancementMetaUpgrade",
    GodEnhancementMetaUpgrade = "VulnerabilityEffectBonusMetaUpgrade",
    RareBoonDropMetaUpgrade = "RunProgressRewardMetaUpgrade",
    RunProgressRewardMetaUpgrade = "RareBoonDropMetaUpgrade",
    EpicBoonDropMetaUpgrade = "DuoRarityBoonDropMetaUpgrade",
    DuoRarityBoonDropMetaUpgrade = "EpicBoonDropMetaUpgrade",
    RerollMetaUpgrade = "RerollPanelMetaUpgrade",
    RerollPanelMetaUpgrade = "RerollMetaUpgrade",
}

-- Map of BackingTooltip component ID -> upgradeData
-- Only needed for invisible hover targets since they have no .Data property
-- Arrow buttons can use FindMetaUpgradeButton (game function) which returns .Data
local BackingTooltipMap = {}

-- Safe helper to get a display name with fallback
local function SafeGetDisplayName(key)
    if not key or key == "" then return "" end
    -- Check hardcoded names first
    if MetaUpgradeDisplayNames[key] then
        return MetaUpgradeDisplayNames[key]
    end
    -- Try engine GetDisplayName
    local ok, result = pcall(GetDisplayName, { Text = key })
    if ok and result and result ~= "" and result ~= key then
        return StripFormatting(result)
    end
    return ""
end

-- Get a hardcoded description for an upgrade at the current level
local function GetUpgradeDescription(upgradeData, numUpgrades)
    if not upgradeData or not upgradeData.Name then return nil end
    local desc = MetaUpgradeDescriptions[upgradeData.Name]
    if not desc then return nil end

    -- Wrap in pcall so a bad format string never crashes the game
    local ok, result = pcall(function()
        if desc.static then
            return (desc.text or ""):gsub("%%%%", "%%")
        elseif desc.usesLevel then
            local fmt = desc.text or desc.base
            if not fmt then return nil end
            return string.format(fmt, numUpgrades)
        elseif desc.base and desc.perLevel then
            local value
            if desc.baseValue then
                -- For upgrades with a starting value modified per rank (e.g. Tight Deadline: 11 + (-2 * rank))
                value = desc.baseValue + (numUpgrades * desc.perLevel)
                if numUpgrades <= 0 then
                    value = desc.baseValue + desc.perLevel -- show what rank 1 would give
                end
            else
                value = numUpgrades * desc.perLevel
                if value <= 0 then
                    value = desc.perLevel -- show what 1 level would give
                end
            end
            -- Handle fractional values (e.g. Family Favorite 2.5% per level)
            if desc.formatFunc then
                if value == math.floor(value) then
                    return string.format(desc.base, value)
                else
                    return string.format(desc.base:gsub("%%d", "%.1f"), value)
                end
            end
            return string.format(desc.base, value)
        end
        return nil
    end)
    if ok then return result end
    return nil
end

-- Build speech text for a given upgrade (global so AccessiblePact can call it)
function BuildUpgradeSpeech(upgradeData, resourceName, handleType)
    if not upgradeData or not upgradeData.Name then
        return nil
    end

    -- Get display name for the upgrade
    local displayName = SafeGetDisplayName(upgradeData.Name)
    if displayName == "" then
        displayName = upgradeData.Name
    end

    -- Build readable speech: name + level + cost + description + affordability
    local numUpgrades = 0
    if GetNumMetaUpgrades then
        local ok, val = pcall(GetNumMetaUpgrades, upgradeData.Name)
        if ok and val then numUpgrades = val end
    end
    local speech = displayName

    -- Check if this upgrade is locked (needs Chthonic Keys to unlock)
    local isLocked = false
    if GameState and GameState.MetaUpgradesUnlocked then
        if GameState.MetaUpgradesUnlocked[upgradeData.Name] == nil or
           GameState.MetaUpgradesUnlocked[upgradeData.Name] == false then
            -- Check if this upgrade appears in the selected list
            -- (Pact upgrades use ShrineUpgradeOrder, not MetaUpgradesSelected)
            local isPact = resourceName == "ShrinePoints" or IsScreenOpen("ShrineUpgrade")
            if not isPact then
                isLocked = true
            end
        end
    end

    if isLocked then
        speech = speech .. ", " .. UIStrings.Locked
        -- Try to determine the unlock cost
        if upgradeData.UnlockCost then
            local costLabel = UIStrings.ChthonicKeys
            if upgradeData.ResourceName == "SuperLockKeys" then
                costLabel = UIStrings.TitanBlood
            end
            speech = speech .. ", " .. string.format(UIStrings.UnlockCostFmt, upgradeData.UnlockCost, costLabel)
            if HasResource and upgradeData.ResourceName then
                if not HasResource(upgradeData.ResourceName, upgradeData.UnlockCost) then
                    speech = speech .. ", " .. UIStrings.CannotAfford
                end
            end
        end
        -- Add description even for locked upgrades
        local desc = GetUpgradeDescription(upgradeData, 0)
        if desc then
            speech = speech .. ". " .. desc
        end
        return speech
    end

    -- Determine resource label and whether this is the Pact
    local resourceLabel = UIStrings.Darkness
    local isPact = resourceName == "ShrinePoints" or IsScreenOpen("ShrineUpgrade")
    if isPact then
        resourceLabel = UIStrings.Heat
        resourceName = "ShrinePoints"
    else
        resourceName = resourceName or "MetaPoints"
    end

    -- Refresh cost/refund data FIRST (before level display, to detect max via cost)
    if GetMetaUpgradePurchasePrice then
        local ok, val = pcall(GetMetaUpgradePurchasePrice, upgradeData)
        if ok and val then upgradeData.NextCost = val end
    end
    if GetMetaUpgradeRefundPrice then
        local ok, val = pcall(GetMetaUpgradeRefundPrice, upgradeData)
        if ok and val then upgradeData.NextRefund = val end
    end

    -- Check if max level (try MaxInvestment first, then global MetaUpgradeData, then cost fallback)
    local maxInvestment = upgradeData.MaxInvestment
    if not maxInvestment and MetaUpgradeData and MetaUpgradeData[upgradeData.Name] then
        maxInvestment = MetaUpgradeData[upgradeData.Name].MaxInvestment
    end
    local isMaxLevel = maxInvestment and numUpgrades >= maxInvestment
    -- Fallback: if MaxInvestment not found, detect max via next cost being nil/0
    if not isMaxLevel and not maxInvestment and handleType == "Add" then
        if not upgradeData.NextCost or upgradeData.NextCost <= 0 then
            isMaxLevel = true
        end
    end

    -- When handleType == "Add" and not at max, show the NEXT level (what you're buying)
    -- The cost shown is for the next level, so the level number and description should match
    local descLevel = numUpgrades
    if handleType == "Add" and not isMaxLevel then
        local nextLevel = numUpgrades + 1
        speech = speech .. ", " .. string.format(UIStrings.LevelFmt, nextLevel)
        descLevel = nextLevel
    elseif numUpgrades > 0 then
        speech = speech .. ", " .. string.format(UIStrings.LevelFmt, numUpgrades)
    end

    -- Show cost/refund and affordability
    if isPact then
        -- Pact: "Adds Heat" only on right arrow, "Removes Heat" only on left arrow
        -- When browsing (no handleType), just show level — no add/remove
        if handleType == "Add" then
            if upgradeData.NextCost and upgradeData.NextCost > 0 and not isMaxLevel then
                speech = speech .. ", " .. string.format(UIStrings.AddHeatFmt, upgradeData.NextCost)
            end
        elseif handleType == "Remove" then
            if numUpgrades > 0 and upgradeData.NextRefund and upgradeData.NextRefund > 0 then
                speech = speech .. ", " .. string.format(UIStrings.RemoveHeatFmt, upgradeData.NextRefund)
            end
        end
    else
        -- Mirror: upgrades cost Darkness
        if handleType == "Add" then
            if upgradeData.NextCost and not isMaxLevel then
                speech = speech .. ", Cost: " .. upgradeData.NextCost .. " " .. resourceLabel
                if not HasResource(resourceName, upgradeData.NextCost) then
                    speech = speech .. ", " .. UIStrings.CannotAfford
                end
            end
        elseif handleType == "Remove" then
            if upgradeData.NextRefund then
                speech = speech .. ", Refund: " .. upgradeData.NextRefund .. " " .. resourceLabel
            end
        else
            -- No HandleType (e.g. BackingTooltip, generic hover)
            if upgradeData.NextCost and not isMaxLevel then
                speech = speech .. ", Cost: " .. upgradeData.NextCost .. " " .. resourceLabel
                if not HasResource(resourceName, upgradeData.NextCost) then
                    speech = speech .. ", " .. UIStrings.CannotAfford
                end
            end
        end
    end

    if isMaxLevel then
        speech = speech .. ", Max Level"
    end

    -- Add description of what this upgrade does
    -- First try hardcoded descriptions (reliable)
    -- Use descLevel so "Add" shows the next level's description (matches the cost shown)
    local desc = GetUpgradeDescription(upgradeData, descLevel)
    if desc then
        speech = speech .. ". " .. desc
    else
        -- Fallback: try engine GetMetaUpgradeShortTotalText + GetDisplayName
        if GetMetaUpgradeShortTotalText then
            local ok, descKey = pcall(GetMetaUpgradeShortTotalText, upgradeData)
            if ok and descKey and descKey ~= "" then
                -- Try the NoIcon variant first for cleaner screen reader output
                local noIconKey = descKey:gsub("_ShortTotal$", "_ShortTotalNoIcon")
                local descText = SafeGetDisplayName(noIconKey)
                if descText == "" then
                    descText = SafeGetDisplayName(descKey)
                end
                -- Only append if we have meaningful text (not just stray +/-/% artifacts)
                if descText ~= "" and (descText:find("%a") or descText:find("%d")) then
                    speech = speech .. ". " .. descText
                end
            end
        end
    end

    -- Append flavor text (lore description) for this upgrade
    local flavor = MirrorFlavorText[upgradeData.Name] or PactFlavorText[upgradeData.Name]
    if flavor then
        speech = speech .. ". " .. flavor
    end

    return speech
end

-- Helper: speak upgrade from a button component (arrow buttons have .Data, .HandleType, .ResourceName)
local function SpeakFromButton(button)
    if not button or not button.Data then
        return
    end
    local speech = BuildUpgradeSpeech(button.Data, button.ResourceName, button.HandleType)
    if speech then
        TolkSilence()
        TolkSpeak(speech)
    end
end

-- Helper: speak upgrade from a BackingTooltip ID lookup
local function SpeakFromTooltipId(compId)
    local upgradeData = BackingTooltipMap[compId]
    if not upgradeData then
        return
    end
    local screen = ScreenAnchors.LevelUpScreen or ScreenAnchors.ShrineScreen
    local resourceName = screen and screen.ResourceName or nil
    local speech = BuildUpgradeSpeech(upgradeData, resourceName, nil)
    if speech then
        TolkSilence()
        TolkSpeak(speech)
    end
end

-- Register BackingTooltip IDs for a single upgrade row
local function RegisterTooltipId(components, k, upgradeData)
    local tooltipKey = "BackingTooltip" .. k
    if components[tooltipKey] and components[tooltipKey].Id then
        BackingTooltipMap[components[tooltipKey].Id] = upgradeData
    end
end

-- Suppress counter for first auto-hover when Mirror/Pact screen opens
-- (prevents the opening announcement from being interrupted)
-- Set to a small number on screen open; each OnMouseOver decrements it.
-- Once it reaches 0, speech resumes normally.
suppressMirrorHoverCount = 0

-- OnMouseOver for RIGHT arrow buttons (increase level)
-- Filter matches the same component names the native code uses
OnMouseOver{ "LevelUpArrowRight LevelUpArrowRightDisabled",
    function(triggerArgs)
        if not AccessibilityEnabled or not AccessibilityEnabled() then
            return
        end
        if suppressMirrorHoverCount > 0 then
            suppressMirrorHoverCount = suppressMirrorHoverCount - 1
            return
        end
        if not triggerArgs.triggeredById then
            return
        end
        -- FindMetaUpgradeButton is a native game function that searches screen.Components by Id
        local button = FindMetaUpgradeButton(triggerArgs.triggeredById)
        if button then
            SpeakFromButton(button)
        end
    end
}

-- OnMouseOver for LEFT arrow buttons (decrease level)
OnMouseOver{ "LevelUpArrowLeft LevelUpArrowLeftDisabled",
    function(triggerArgs)
        if not AccessibilityEnabled or not AccessibilityEnabled() then
            return
        end
        if suppressMirrorHoverCount > 0 then
            suppressMirrorHoverCount = suppressMirrorHoverCount - 1
            return
        end
        if not triggerArgs.triggeredById then
            return
        end
        local button = FindMetaUpgradeButton(triggerArgs.triggeredById)
        if button then
            SpeakFromButton(button)
        end
    end
}

-- OnMouseOver for upgrade plus buttons (level up)
OnMouseOver{ "LevelUpPlus LevelUpPlusDisabled",
    function(triggerArgs)
        if not AccessibilityEnabled or not AccessibilityEnabled() then
            return
        end
        if suppressMirrorHoverCount > 0 then
            suppressMirrorHoverCount = suppressMirrorHoverCount - 1
            return
        end
        if not triggerArgs.triggeredById then
            return
        end
        local button = FindMetaUpgradeButton(triggerArgs.triggeredById)
        if button then
            SpeakFromButton(button)
        end
    end
}

-- OnMouseOver for exchange/swap button (switch between paired talents)
-- Speaks the ALTERNATE talent you would switch TO, not the current one
OnMouseOver{ "ExchangeMetaupgrade",
    function(triggerArgs)
        if not AccessibilityEnabled or not AccessibilityEnabled() then
            return
        end
        if suppressMirrorHoverCount > 0 then
            suppressMirrorHoverCount = suppressMirrorHoverCount - 1
            return
        end
        if not triggerArgs.triggeredById then
            return
        end
        local button = FindMetaUpgradeButton(triggerArgs.triggeredById)
        if not button then
            return
        end
        -- Exchange button has .Name directly (not .Data.Name like arrow buttons)
        local currentName = button.Name or (button.Data and button.Data.Name)
        if not currentName then
            return
        end
        -- Look up the alternate talent in this pair
        local altName = MetaUpgradePairs[currentName]
        if not altName then
            return
        end
        local altDisplayName = MetaUpgradeDisplayNames[altName] or altName
        local altUpgradeData = MetaUpgradeData and MetaUpgradeData[altName]
        local speech = string.format(UIStrings.SwitchToFmt, altDisplayName)
        -- Get the alternate's saved level
        if GameState and GameState.MetaUpgradeState and GameState.MetaUpgradeState[altName] then
            local altLevel = GameState.MetaUpgradeState[altName]
            if altLevel > 0 then
                speech = speech .. ", " .. string.format(UIStrings.LevelFmt, altLevel)
            end
        end
        -- Add alternate's description
        if altUpgradeData then
            local altLevel = 0
            if GameState and GameState.MetaUpgradeState then
                altLevel = GameState.MetaUpgradeState[altName] or 0
            end
            local desc = GetUpgradeDescription(altUpgradeData, altLevel)
            if desc then
                speech = speech .. ". " .. desc
            end
        end
        -- Add alternate's flavor text
        local flavor = MirrorFlavorText[altName]
        if flavor then
            speech = speech .. ". " .. flavor
        end
        TolkSilence()
        TolkSpeak(speech)
    end
}

-- OnMouseOver for the Mirror refund/reset button (costs 1 Chthonic Key to reset all upgrades)
OnMouseOver{ "ButtonRefund",
    function(triggerArgs)
        if not AccessibilityEnabled or not AccessibilityEnabled() then
            return
        end
        if suppressMirrorHoverCount > 0 then
            suppressMirrorHoverCount = suppressMirrorHoverCount - 1
            return
        end
        local screen = ScreenAnchors.LevelUpScreen
        if not screen or not screen.Components then return end
        local button = screen.Components.RefundButton
        if button and button.Cost then
            local speech = "Reset all Mirror upgrades, " .. button.Cost .. " Chthonic Key"
            if not HasResource("LockKeys", button.Cost) then
                speech = speech .. ", " .. UIStrings.CannotAfford
            end
            TolkSilence()
            TolkSpeak(speech)
        end
    end
}

-- OnMouseOver for invisible hover targets (BackingTooltip)
-- These have no .Data property, so we use our own BackingTooltipMap
OnMouseOver{ "MetaUpgradeInvisibleHoverTarget",
    function(triggerArgs)
        if not AccessibilityEnabled or not AccessibilityEnabled() then
            return
        end
        if suppressMirrorHoverCount > 0 then
            suppressMirrorHoverCount = suppressMirrorHoverCount - 1
            return
        end
        if not triggerArgs.triggeredById then
            return
        end
        SpeakFromTooltipId(triggerArgs.triggeredById)
    end
}

-- OnMouseOver for the unlock panel button (Chthonic Keys unlock)
OnMouseOver{ "ButtonMetaUpgradeUnlockPanel",
    function(triggerArgs)
        if not AccessibilityEnabled or not AccessibilityEnabled() then
            return
        end
        -- The unlock panel button has .Cost set on it
        local screen = ScreenAnchors.LevelUpScreen or ScreenAnchors.ShrineScreen
        if not screen or not screen.Components then return end
        local button = screen.Components.UnlockNextPanelButton
        if button and button.Cost then
            local speech = "Unlock next set of Mirror upgrades, " .. button.Cost .. " Chthonic Keys"
            if not HasResource("LockKeys", button.Cost) then
                speech = speech .. ", " .. UIStrings.CannotAfford
            end
            TolkSilence()
            TolkSpeak(speech)
        end
    end
}

-- Suppress counter for Pact confirm button (to avoid interrupting heat announcement)
-- Global so AccessiblePact can set it from OpenShrineUpgradeMenu wrapper
suppressConfirmHoverCount = 0

-- OnMouseOver for the Pact "Start Run" confirm button
OnMouseOver{ "ShrineUpgradeMenuConfirm",
    function(triggerArgs)
        if not AccessibilityEnabled or not AccessibilityEnabled() then
            return
        end
        -- Skip the first hover after screen open so the heat announcement isn't interrupted
        if suppressConfirmHoverCount > 0 then
            suppressConfirmHoverCount = suppressConfirmHoverCount - 1
            return
        end
        local screen = ScreenAnchors.ShrineScreen
        if not screen or not screen.Components then return end
        local speech = "Start Run with current Heat"
        -- Check if blocked (heat too high for current weapon)
        if GameState and GameState.Flags and GameState.Flags.HardMode then
            local currentPoints = GetTotalSpentShrinePoints and GetTotalSpentShrinePoints() or 0
            local maxPoints = GetMaximumAllocatableShrinePoints and GetMaximumAllocatableShrinePoints() or 0
            if currentPoints > maxPoints then
                speech = "Blocked, Heat too high"
            end
        end
        TolkSilence()
        TolkSpeak(speech)
    end
}

-- OnMouseOver for the Pact info button
OnMouseOver{ "ShrineUpgradeMenuInfo",
    function(triggerArgs)
        if not AccessibilityEnabled or not AccessibilityEnabled() then
            return
        end
        TolkSilence()
        TolkSpeak(UIStrings.PactInfo)
    end
}

-- Wrap ShowShrineInfo to speak the Pact explanation (AnnouncementScreen text is suppressed
-- because ShrineUpgrade is still open when the announcement displays)
ModUtil.WrapBaseFunction("ShowShrineInfo", function(baseFunc, screen, button)
    if AccessibilityEnabled and AccessibilityEnabled() then
        TolkSilence()
        local speech = "The Pact of Punishment. "
        if GameState and GameState.Flags and GameState.Flags.HardMode then
            speech = speech .. "Hell Mode: certain Conditions are not optional. "
        end
        speech = speech .. "The Pact can make escaping more difficult via various Conditions. "
            .. "Each Condition you accept adds some Heat to your Heat Gauge. "
            .. "While your Heat Gauge is full, you can earn valuable Bounties. "
            .. "You earn one Bounty the first time you vanquish the boss of each Underworld region while your Heat Gauge is full. "
            .. "Once you successfully escape, you can earn more Bounties if you turn up the Heat. "
            .. "You can earn Bounties for each weapon. How much Heat you need is per weapon as well. "
            .. "If things get too hot, try switching weapons."
        TolkSpeak(speech)
    end
    baseFunc(screen, button)
end)

-- Wrap CreateMetaUpgradeEntry to register BackingTooltip IDs in our map
-- Arrow buttons don't need registration — FindMetaUpgradeButton handles them
ModUtil.WrapBaseFunction("CreateMetaUpgradeEntry", function(baseFunc, args)
    baseFunc(args)
    RegisterTooltipId(args.Components, args.Index, args.Data)
end)

-- Wrap UpdateButtonStates to re-register BackingTooltip IDs after button recreation
-- CreateArrowButton DESTROYS and RECREATES components, getting new IDs
-- BackingTooltip also gets recreated in CreateTooltipTarget
ModUtil.WrapBaseFunction("UpdateButtonStates", function(baseFunc, screen)
    baseFunc(screen)

    if not screen or not screen.Components then
        return
    end

    local components = screen.Components

    -- Clear old tooltip entries (IDs changed due to destruction/recreation)
    BackingTooltipMap = {}

    -- Re-register BackingTooltip IDs for all upgrade rows
    if IsScreenOpen("ShrineUpgrade") and ShrineUpgradeOrder then
        for k, upgradeName in ipairs(ShrineUpgradeOrder) do
            local upgradeData = MetaUpgradeData[upgradeName]
            if upgradeData then
                RegisterTooltipId(components, k, upgradeData)
            end
        end
    elseif GameState and GameState.MetaUpgradesSelected then
        for k, upgradeName in ipairs(GameState.MetaUpgradesSelected) do
            local upgradeData = MetaUpgradeData[upgradeName]
            if upgradeData then
                RegisterTooltipId(components, k, upgradeData)
            end
        end
    end
end)

-- Wrap HandleMetaUpgradeInput to speak the updated state after Left/Right purchase
-- This fires when the user presses A/Enter on an arrow button to change upgrade level
ModUtil.WrapBaseFunction("HandleMetaUpgradeInput", function(baseFunc, screen, button)
    baseFunc(screen, button)
    _Log("[WRAP] HandleMetaUpgradeInput: " .. (button and button.Data and button.Data.Name or "unknown"))

    if not AccessibilityEnabled or not AccessibilityEnabled() then
        return
    end
    if not button or not button.Data then
        return
    end

    local upgradeData = button.Data
    local resourceName = nil
    if screen then
        resourceName = screen.ResourceName
    end

    -- Speak the updated state after the purchase/refund
    -- Pass the original handleType so "Add" shows the next purchasable level
    -- BuildUpgradeSpeech caps at MaxInvestment, so it won't go beyond max
    local handleType = button.HandleType or nil
    local speech = BuildUpgradeSpeech(upgradeData, resourceName, handleType)
    if speech then
        TolkSilence()
        TolkSpeak(speech)
    end
    -- Suppress the OnMouseOver that fires when UpdateButtonStates recreates buttons
    suppressMirrorHoverCount = 1
end)

-- Wrap SwapMetaupgrade to announce the newly active talent after pressing the exchange button
-- button.Index = pair position (1-12), button.Name = upgrade name BEFORE swap
ModUtil.WrapBaseFunction("SwapMetaupgrade", function(baseFunc, screen, button)
    baseFunc(screen, button)
    _Log("[WRAP] SwapMetaupgrade: " .. (button and button.Name or "unknown") .. " index=" .. (button and button.Index or "?"))

    if not AccessibilityEnabled or not AccessibilityEnabled() then
        return
    end
    if not button or not button.Index then
        return
    end

    -- After baseFunc, GameState.MetaUpgradesSelected[button.Index] has the NEW upgrade name
    local newName = nil
    if GameState and GameState.MetaUpgradesSelected then
        newName = GameState.MetaUpgradesSelected[button.Index]
    end
    if not newName then
        return
    end

    local displayName = MetaUpgradeDisplayNames[newName] or newName
    local speech = string.format(UIStrings.SwitchedToFmt, displayName)

    -- Get the new talent's current level
    local newLevel = 0
    if GameState and GameState.MetaUpgradeState and GameState.MetaUpgradeState[newName] then
        newLevel = GameState.MetaUpgradeState[newName]
    end
    if newLevel > 0 then
        speech = speech .. ", " .. string.format(UIStrings.LevelFmt, newLevel)
    end

    -- Add description
    local newUpgradeData = MetaUpgradeData and MetaUpgradeData[newName]
    if newUpgradeData then
        local desc = GetUpgradeDescription(newUpgradeData, newLevel)
        if desc then
            speech = speech .. ". " .. desc
        end
    end

    -- Add flavor text
    local flavor = MirrorFlavorText[newName]
    if flavor then
        speech = speech .. ". " .. flavor
    end

    TolkSilence()
    TolkSpeak(speech)
end)

-- Speak when the MetaUpgrade (Mirror of Night) screen opens
ModUtil.WrapBaseFunction("OpenMetaUpgradeMenu", function(baseFunc, args)
    _Log("[SCREEN-OPEN] Mirror of Night (OpenMetaUpgradeMenu)")
    if AccessibilityEnabled and AccessibilityEnabled() then
        local darkness = 0
        local keys = 0
        if GameState and GameState.Resources then
            darkness = GameState.Resources.MetaPoints or 0
            keys = GameState.Resources.LockKeys or 0
        end
        local openSpeech = UIStrings.MirrorOfNight

        -- Include flavor text
        local flavorOk, flavor = pcall(GetDisplayName, { Text = "MetaUpgradeMenu_Flavor" })
        if flavorOk and flavor and flavor ~= "" and flavor ~= "MetaUpgradeMenu_Flavor" then
            openSpeech = openSpeech .. ". " .. StripFormatting(flavor)
        else
            openSpeech = openSpeech .. ". Within the Infinite Dark, Everything"
        end

        openSpeech = openSpeech .. ". " .. darkness .. " " .. UIStrings.Darkness .. ", " .. keys .. " " .. UIStrings.ChthonicKeys

        -- Combine with first upgrade name + level
        if GameState and GameState.MetaUpgradesSelected then
            local firstName = GameState.MetaUpgradesSelected[1]
            if firstName then
                local displayName = MetaUpgradeDisplayNames[firstName] or firstName
                local level = 0
                if GetNumMetaUpgrades then
                    local ok, val = pcall(GetNumMetaUpgrades, firstName)
                    if ok and val then level = val end
                end
                if level > 0 then
                    openSpeech = openSpeech .. ", " .. displayName .. ", " .. string.format(UIStrings.LevelFmt, level)
                else
                    openSpeech = openSpeech .. ", " .. displayName
                end
            end
        end

        TolkSilence()
        TolkSpeak(openSpeech)
        suppressMirrorHoverCount = 1
    end
    baseFunc(args)
end)
