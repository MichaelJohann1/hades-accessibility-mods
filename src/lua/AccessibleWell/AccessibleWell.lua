--[[
Mod: AccessibleWell
Author: Accessibility Layer
Version: 1

Provides screen reader accessibility for the Well of Charon shop screen ("Store").
- Wraps CreateStoreButtons to add OnMouseOverFunctionName + AttachLua to PurchaseButtons
- Speaks item name + description + cost + duration + affordability on cursor navigation
- Hardcoded item names and descriptions (UseDescription=true resolves at C++ render time)
- Speaks "Well of Charon" on screen open
- Labels the Reroll button
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

-- ============================================================
-- Well of Charon item display names
-- Keys are internal trait/consumable names from StoreData.RoomShop
-- ============================================================
WellItemNames = {
    TemporaryImprovedWeaponTrait = "Cyclops Jerky",
    TemporaryImprovedSecondaryTrait = "Chimaera Jerky",
    TemporaryImprovedRangedTrait = "Braid of Atlas",
    TemporaryMoreAmmoTrait = "Prometheus Stone",
    TemporaryMoveSpeedTrait = "Ignited Ichor",
    TemporaryBoonRarityTrait = "Yarn of Ariadne",
    TemporaryArmorDamageTrait = "Nail of Talos",
    TemporaryAlphaStrikeTrait = "Eris Bangle",
    TemporaryBackstabTrait = "Nemesis Crest",
    TemporaryImprovedTrapDamageTrait = "Stygian Shard",
    TemporaryPreloadSuperGenerationTrait = "Aether Net",
    TemporaryForcedSecretDoorTrait = "Light of Ixion",
    TemporaryForcedChallengeSwitchTrait = "Trove Tracker",
    TemporaryForcedFishingPointTrait = "Skeletal Lure",
    TemporaryBlockExplodingChariotsTrait = "Flame Wheels Release",
    TemporaryDoorHealTrait = "HydraLite",
    TemporaryWeaponLifeOnKillTrait = "Eye of Lamia",
    TemporaryLastStandHealTrait = "Touch of Styx",
    HealDropRange = "Life Essence",
    EmptyMaxHealthDrop = "Centaur Soul",
    DamageSelfDrop = "Price of Midas",
    LastStandDrop = "Kiss of Styx",
    MetaDropRange = "Tinge of Erebus",
    GemDropRange = "Gaea's Treasure",
    KeepsakeChargeDrop = "Night Spindle",
    RandomStoreItem = "Fateful Twist",
}

-- ============================================================
-- Well of Charon item descriptions (sourced from Hades Wiki)
-- ============================================================
WellItemDescriptions = {
    TemporaryImprovedWeaponTrait = "Passive: Your Attack deals +30% damage. Duration: 6 Encounter(s)",
    TemporaryImprovedSecondaryTrait = "Passive: Your Special deals +40% damage. Duration: 6 Encounter(s)",
    TemporaryImprovedRangedTrait = "Passive: Your Cast deals +50% damage. Duration: 6 Encounter(s)",
    TemporaryMoreAmmoTrait = "Gain 1 additional Bloodstone for your Cast. Lasts 6 encounters.",
    TemporaryMoveSpeedTrait = "Gain 20% move speed. Lasts 8 encounters.",
    TemporaryBoonRarityTrait = "Passive: The next Boon you find has upgraded Rarity",
    TemporaryArmorDamageTrait = "Passive: You deal +50% damage to Armor. Duration: 6 Encounter(s)",
    TemporaryAlphaStrikeTrait = "Passive: You deal +50% damage striking undamaged foes. Duration: 6 Encounter(s)",
    TemporaryBackstabTrait = "Passive: You deal +50% damage striking foes from behind. Duration: 6 Encounter(s)",
    TemporaryImprovedTrapDamageTrait = "Passive: Traps deal +500% damage to your foes. Duration: 6 Encounter(s)",
    TemporaryPreloadSuperGenerationTrait = "Passive: You start Encounter(s) with your God Gauge 15% full. Duration: 6 Encounter(s)",
    TemporaryForcedSecretDoorTrait = "Passive: Ensure a Chaos Gate will spawn ahead (where possible)",
    TemporaryForcedChallengeSwitchTrait = "Passive: Ensure an Infernal Trove will spawn ahead (where possible)",
    TemporaryForcedFishingPointTrait = "Passive: Ensure a Fishing Point will spawn ahead (where possible)",
    TemporaryBlockExplodingChariotsTrait = "Passive: Prevent Flame Wheel foes from appearing in Encounters. Duration: 10 Encounters",
    TemporaryDoorHealTrait = "Passive: Restore 10% Health when you enter a chamber. Duration: 3 Chambers",
    TemporaryWeaponLifeOnKillTrait = "Passive: Slain foes have a 15% chance to drop items. Duration: 3 Encounter(s)",
    TemporaryLastStandHealTrait = "Passive: Stubborn Defiance restores 10% more than usual. Duration: 15 Encounter(s)",
    HealDropRange = "Instant: Restore 21 to 39 percent of Max Health",
    EmptyMaxHealthDrop = "Instant: Gain 25 Max Health without restoring Health",
    DamageSelfDrop = "Instant: Gain Obols at the cost of Health",
    LastStandDrop = "Instant: Replenish 1 use of Death Defiance",
    MetaDropRange = "Instant: Gain 20 to 30 Darkness",
    GemDropRange = "Instant: Gain 10 to 15 Gemstones",
    KeepsakeChargeDrop = "Instant: Gain +1 use of your Chthonic Companion's Summon",
    RandomStoreItem = "Instant: Gain a random item offered from the Well of Charon",
}

-- Suppress counter for first auto-hover when Well opens
suppressWellHoverCount = 0

-- Pending open speech — first item handler combines it with first item
_wellOpenSpeech = nil

-- Mouse over handler for Well of Charon purchase buttons
function AccessibleWellItemMouseOver(button)
    if not AccessibilityEnabled or not AccessibilityEnabled() or not button then
        return
    end

    if suppressWellHoverCount > 0 then
        suppressWellHoverCount = suppressWellHoverCount - 1
        if not _wellOpenSpeech then return end
    end

    local upgradeData = button.Data
    if not upgradeData then
        -- Even without Data, still consume pending open speech
        if _wellOpenSpeech then
            TolkSilence()
            TolkSpeak(_wellOpenSpeech)
            _wellOpenSpeech = nil
        end
        return
    end

    local speech = ""

    -- Get item name — try hardcoded first, then GetTraitTooltipTitle, then GetDisplayName
    local itemName = ""
    if upgradeData.Name then
        itemName = WellItemNames[upgradeData.Name] or ""
    end
    if itemName == "" and GetTraitTooltipTitle and upgradeData then
        local ok, titleKey = pcall(GetTraitTooltipTitle, upgradeData)
        if ok and titleKey and titleKey ~= "" then
            local titleText = SafeGetDisplayName(titleKey)
            if titleText ~= "" then
                itemName = titleText
            end
        end
    end
    if itemName == "" and upgradeData.Name then
        itemName = SafeGetDisplayName(upgradeData.Name)
    end
    if itemName == "" and upgradeData.Name then
        itemName = upgradeData.Name
    end
    speech = itemName

    -- Get description from hardcoded table
    local desc = ""
    if upgradeData.Name then
        desc = WellItemDescriptions[upgradeData.Name] or ""
    end
    if desc ~= "" then
        speech = speech .. ". " .. desc
    end

    -- Add cost (cost may be on button directly or on button.Data)
    local itemCost = button.Cost or (upgradeData and upgradeData.Cost) or 0
    local healthCost = button.HealthCost or (upgradeData and upgradeData.HealthCost) or 0
    if itemCost > 0 then
        speech = speech .. ". " .. itemCost .. " " .. UIStrings.Obols
    elseif healthCost > 0 then
        speech = speech .. ". " .. string.format(UIStrings.CostHealthFmt, healthCost)
    end

    -- Check affordability
    if itemCost > 0 then
        local currentMoney = 0
        if CurrentRun and CurrentRun.Money then
            currentMoney = CurrentRun.Money
        end
        if currentMoney < itemCost then
            speech = speech .. ", " .. UIStrings.CannotAfford
        end
    end

    -- Sold out check
    if button.SoldOut or (upgradeData and upgradeData.SoldOut) then
        speech = speech .. ", " .. UIStrings.SoldOut
    end

    if speech ~= "" then
        if _wellOpenSpeech then
            speech = _wellOpenSpeech .. ", " .. speech
            _wellOpenSpeech = nil
        end
        TolkSilence()
        TolkSpeak(speech)
    end
end

-- Mouse over handler for the Reroll button in Well of Charon
function AccessibleWellRerollMouseOver(button)
    if not AccessibilityEnabled or not AccessibilityEnabled() then
        return
    end
    local speech = string.format(UIStrings.FatedPersuasionFmt, UIStrings.WellItems)
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

-- Wrap CreateStoreButtons to add accessibility to Well of Charon
ModUtil.WrapBaseFunction("CreateStoreButtons", function(baseFunc)
    baseFunc()

    if not AccessibilityEnabled or not AccessibilityEnabled() then
        return
    end

    -- Access the store screen
    local store = nil
    if CurrentRun and CurrentRun.CurrentRoom and CurrentRun.CurrentRoom.Store then
        store = CurrentRun.CurrentRoom.Store
    end
    if not store or not store.Screen or not store.Screen.Components then
        return
    end

    local components = store.Screen.Components
    local storeOptions = store.StoreOptions
    if not storeOptions then return end

    local firstButtonId = nil

    for itemIndex = 1, #storeOptions do
        local purchaseKey = "PurchaseButton" .. itemIndex
        local comp = components[purchaseKey]
        if comp and comp.Id then
            -- Store cost and health cost on button for the handler
            local upgradeData = storeOptions[itemIndex]
            if upgradeData then
                -- Cost info is calculated in CreateStoreButtons — read from component
                -- The cost is stored on comp.Cost or computed from upgradeData
                if not comp.Cost and upgradeData.Cost then
                    comp.Cost = upgradeData.Cost
                end
                if not comp.HealthCost and upgradeData.HealthCost then
                    comp.HealthCost = upgradeData.HealthCost
                end
            end

            comp.OnMouseOverFunctionName = "AccessibleWellItemMouseOver"
            AttachLua({ Id = comp.Id, Table = comp })

            if not firstButtonId then
                firstButtonId = comp.Id
            end
        end
    end

    -- Label the Reroll button if present
    local rerollPanel = components["RerollPanel"]
    if rerollPanel and rerollPanel.Id then
        rerollPanel.OnMouseOverFunctionName = "AccessibleWellRerollMouseOver"
        AttachLua({ Id = rerollPanel.Id, Table = rerollPanel })
    end

    -- Build open speech with captured flavor text (CreateTextBox already fired during baseFunc)
    if _wellOpening then
        local currentMoney = 0
        if CurrentRun and CurrentRun.Money then
            currentMoney = CurrentRun.Money
        end
        local speech = "Well of Charon, " .. currentMoney .. " Obols available"
        if _capturedFlavorText and _capturedFlavorText ~= "" then
            speech = speech .. ". " .. _capturedFlavorText
            _capturedFlavorText = nil
        end
        _wellOpenSpeech = speech
        _wellOpening = false
    end

    -- Suppress the first OnMouseOver so initial cursor doesn't interrupt flavor text
    suppressWellHoverCount = 1
end)

-- ============================================================
-- Announce what was received from Fateful Twist (RandomStoreItem)
-- and other consumable purchases.
-- AwardRandomStoreItem picks a random trait or consumable and
-- grants it. We set a flag so AccessibleNotifications' AddTraitToHero
-- wrapper doesn't suppress the "Acquired:" speech (it normally
-- suppresses when Store screen is open).
-- ============================================================
_wellAwardingRandomItem = false

ModUtil.WrapBaseFunction("AwardRandomStoreItem", function(baseFunc, consumableItem, useFunctionArgs, user)
    _wellAwardingRandomItem = true
    baseFunc(consumableItem, useFunctionArgs, user)
    _wellAwardingRandomItem = false
end)

-- ============================================================
-- Wrap PurchaseConsumableItem to announce consumable effects
-- (heal amount, max health gain, resource gains, etc.)
-- This fires when the player picks up/uses a consumable drop.
-- ============================================================
ModUtil.WrapBaseFunction("PurchaseConsumableItem", function(baseFunc, currentRun, consumableItem, args)
    -- Only announce during Store purchases (Well of Charon / Charon shop)
    -- Regular room pickups are already handled by AccessibleNotifications wrappers
    if not IsScreenOpen or not IsScreenOpen("Store") then
        baseFunc(currentRun, consumableItem, args)
        return
    end

    -- Record health before purchase for heal tracking
    local healthBefore = 0
    local maxHealthBefore = 0
    if CurrentRun and CurrentRun.Hero then
        healthBefore = CurrentRun.Hero.Health or 0
        maxHealthBefore = CurrentRun.Hero.MaxHealth or 0
    end

    baseFunc(currentRun, consumableItem, args)

    if not AccessibilityEnabled or not AccessibilityEnabled() then
        return
    end

    if not consumableItem then return end

    local itemName = consumableItem.Name or ""
    local displayName = WellItemNames[itemName] or ""

    -- Check what changed
    local healthAfter = 0
    local maxHealthAfter = 0
    if CurrentRun and CurrentRun.Hero then
        healthAfter = CurrentRun.Hero.Health or 0
        maxHealthAfter = CurrentRun.Hero.MaxHealth or 0
    end

    local speech = ""

    -- Max health increase (Centaur Soul)
    local maxHealthGain = maxHealthAfter - maxHealthBefore
    if maxHealthGain > 0 then
        if displayName ~= "" then
            speech = displayName .. ": +" .. tostring(math.floor(maxHealthGain)) .. " Max Health"
        else
            speech = "+" .. tostring(math.floor(maxHealthGain)) .. " Max Health"
        end
    end

    -- Healing (Life Essence)
    local healAmount = healthAfter - healthBefore
    if healAmount > 0 and maxHealthGain == 0 then
        if displayName ~= "" then
            speech = displayName .. ": Healed " .. tostring(math.floor(healAmount)) .. ", " .. tostring(math.floor(healthAfter)) .. " Health"
        else
            speech = "Healed " .. tostring(math.floor(healAmount)) .. ", " .. tostring(math.floor(healthAfter)) .. " Health"
        end
    end

    -- Health cost (Price of Midas — health goes down, but obols go up)
    if healAmount < 0 then
        local cost = math.abs(math.floor(healAmount))
        if displayName ~= "" then
            speech = displayName .. ": Lost " .. tostring(cost) .. " Health"
        else
            speech = "Lost " .. tostring(cost) .. " Health"
        end
    end

    -- Resource gains (Gems, Darkness) are handled by AccessibleNotifications AddResource wrapper
    -- Obol gains (Price of Midas payout) are handled by AccessibleNotifications AddMoney wrapper

    if speech ~= "" then
        local queueSpeak = TolkSpeakQueue or TolkSpeak
        queueSpeak(speech)
    end
end)

-- Well of Charon flavor text (hardcoded from HelpText.en.sjson)
-- Game randomly picks one of these 3 via GetRandomValue in StoreScripts.lua:539
local WellFlavorTexts = {
    "The riches of the Underworld sometimes rise up from the suffocating dark.",
    "The five rivers flowing through the Underworld imbue the dead's detritus with great power.",
    "A sample of the Stygian boatman's infinite collection is available to those prepared to pay.",
}

-- Wrap ShowStoreScreen — set flag so CreateStoreButtons wrapper can build speech
-- (baseFunc blocks in HandleScreenInput; CreateTextBox captures flavor text during baseFunc)
_wellOpening = false

ModUtil.WrapBaseFunction("ShowStoreScreen", function(baseFunc)
    _Log("[SCREEN-OPEN] Well of Charon (ShowStoreScreen)")
    if AccessibilityEnabled and AccessibilityEnabled() then
        _wellOpening = true
    end
    baseFunc()
    _wellOpening = false
end)
