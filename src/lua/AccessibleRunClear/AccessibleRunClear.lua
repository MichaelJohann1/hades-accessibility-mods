--[[
Mod: AccessibleRunClear
Author: Accessibility Layer
Version: 2

Provides screen reader accessibility for the Run Clear (Victory) Screen.
- Wraps ShowRunClearScreen to speak run completion stats
- Reads: clear time, record time, heat level, record heat, weapon stats,
  total clears, clear streak, new records, and contextual clear message
- Replicates the game's RunClearMessageData selection logic to find the
  contextual message (e.g. "The First of Many?", "Perfect Clear", etc.)
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

-- Weapon display names (internal -> display)
local WeaponDisplayNames = {
    SwordWeapon = "Stygian Blade",
    SpearWeapon = "Eternal Spear",
    BowWeapon = "Heart-Seeking Bow",
    ShieldWeapon = "Shield of Chaos",
    FistWeapon = "Twin Fists",
    GunWeapon = "Adamant Rail",
}

-- ============================================================
-- Run Clear Message display names (from HelpText.en.sjson)
-- These are the contextual accolades shown on the victory screen.
-- The game uses message.Name as a localization key.
-- StripFormatting removes {!Icons.RunClearStar} tags.
-- ============================================================
local ClearMessageDisplayNames = {
    ClearNumOne = "The First of Many?",
    ClearNumTen = "Tenth Time's a Charm",
    ClearNumFifty = "The Big Five-Oh",
    ClearNumOneHundred = "Happy Centennial",
    ClearNumTwoFifty = "Quarter Century",
    ClearNumFiveHundred = "Five Hundred Patricides",
    ClearNearDeath = "(Close Call, Though)",
    ClearFullHealth = "Perfect Clear",
    ClearTimeFast = "Swiftness of Hermes",
    ClearTimeVeryFast = "Hermes Would Be Jealous",
    ClearTimeSlow = "Slow and Steady",
    ClearMoneyNone = "Poor as a Pauper",
    ClearMoneyHigh = "Swimming in Cash",
    ClearMetaPointsInvestedNone = "100% Darkness-Free",
    ClearNoOlympianBoons = "100% Olympian-Free",
    ClearAllStoryRooms = "Made Friends Along the Way",
    ClearAllReprieveRooms = "Fountain Finder Award",
    ClearAllShopRooms = "Big Shopping Trip, Too",
    ClearRequiredTraitsZeus = "Disciple of Zeus",
    ClearRequiredTraitsPoseidon = "Disciple of Poseidon",
    ClearRequiredTraitsAthena = "Disciple of Athena",
    ClearRequiredTraitsAres = "Disciple of Ares",
    ClearRequiredTraitsArtemis = "Disciple of Artemis",
    ClearRequiredTraitsAphrodite = "Disciple of Aphrodite",
    ClearRequiredTraitsDionysus = "Disciple of Dionysus",
    ClearRequiredTraitsHermes = "Disciple of Hermes",
    ClearRequiredTraitsDemeter = "Disciple of Demeter",
    ClearRequiredTraitsChaos = "Scion of Chaos",
    ClearHighMaxHealth = "Minotaur's Toughness",
    ClearChallengeSwitches = "Trove Taker",
    ClearDevotionEncounters = "Favored & Envied",
    ClearShrineChallengeEncounters = "Erebus Gatekeeper",
    ClearMiniBossEncounters = "Middle-Management Cutter",
    ClearWeaponsFiredWrath = "Olympus Caller",
    ClearWeaponsFiredRanged = "Master Caster",
    ClearSynergyTraits = "Duo Digger",
    ClearLegendaryTraits = "Pride of Olympus",
    ClearFishCaught = "Fisher King",
    ClearConsecutiveLow = "Triathlete",
    ClearConsecutiveHigh = "Decathlete",
    ClearHealItems = "Souvla Snacker",
    ClearStackUpgrades = "Pom-Powered",
    ClearGiftDrops = "Nose for Nectar",
    ClearLockKeyDrops = "Chthonic Keymaster",
    ClearConsolationPrizes = "Onion Eater",
    ClearManyLastStands = "Death Defier",
    ClearShutDownThanatos = "Robbed Thanatos",
    ClearManyTraitsSold = "Boon Purger",
}

-- ============================================================
-- Select the contextual run clear message
-- Replicates the game's logic from RunClearScreen.lua:337-354
-- ============================================================
local function SelectRunClearMessage()
    if not GameData or not GameData.RunClearMessageData then return nil end
    if not CurrentRun then return nil end
    if not IsGameStateEligible then return nil end

    local priorityEligibleMessages = {}
    local eligibleMessages = {}

    for name, message in pairs(GameData.RunClearMessageData) do
        if message.GameStateRequirements then
            local ok, eligible = pcall(IsGameStateEligible, CurrentRun, message.GameStateRequirements)
            if ok and eligible then
                -- Store the name on the message for lookup
                local entry = { Name = name, Priority = message.Priority }
                if message.Priority then
                    priorityEligibleMessages[#priorityEligibleMessages + 1] = entry
                else
                    eligibleMessages[#eligibleMessages + 1] = entry
                end
            end
        end
    end

    local selected = nil
    if #priorityEligibleMessages > 0 then
        selected = priorityEligibleMessages[math.random(#priorityEligibleMessages)]
    elseif #eligibleMessages > 0 then
        selected = eligibleMessages[math.random(#eligibleMessages)]
    end

    if selected then
        -- Try hardcoded name first, then GetDisplayName as fallback
        local displayName = ClearMessageDisplayNames[selected.Name] or ""
        if displayName == "" then
            displayName = SafeGetDisplayName(selected.Name)
        end
        if displayName == "" then
            displayName = selected.Name
        end
        return displayName
    end

    return nil
end

-- ============================================================
-- Wrap ShowRunClearScreen to speak all stats
-- ============================================================
ModUtil.WrapBaseFunction("ShowRunClearScreen", function(baseFunc)
    _Log("[SCREEN-OPEN] Run Clear (ShowRunClearScreen)")
    -- Collect stats BEFORE calling base function (which blocks in HandleScreenInput)
    if not AccessibilityEnabled or not AccessibilityEnabled() then
        baseFunc()
        return
    end

    local parts = {}
    parts[#parts + 1] = UIStrings.RunClear .. "!"

    -- Contextual clear message (e.g. "The First of Many?", "Perfect Clear")
    local clearMessage = SelectRunClearMessage()
    if clearMessage then
        parts[#parts + 1] = clearMessage
    end

    -- Current clear time
    if CurrentRun and CurrentRun.GameplayTime then
        local ok, timeStr = pcall(GetTimerString, CurrentRun.GameplayTime, 2)
        if ok and timeStr then
            parts[#parts + 1] = string.format(UIStrings.ClearTimeFmt, timeStr)
        end
    end

    -- Record clear time
    local recordTime = nil
    if GetFastestRunClearTime then
        local ok, rt = pcall(GetFastestRunClearTime, CurrentRun)
        if ok and rt then
            recordTime = rt
            local ok2, timeStr = pcall(GetTimerString, rt, 2)
            if ok2 and timeStr then
                parts[#parts + 1] = string.format(UIStrings.RecordTimeFmt, timeStr)
            end
        end
    end

    -- Check if new time record
    if CurrentRun and CurrentRun.GameplayTime and recordTime then
        if CurrentRun.GameplayTime <= recordTime then
            parts[#parts + 1] = UIStrings.NewTimeRecord
        end
    end

    -- Heat (Shrine Points)
    if CurrentRun and CurrentRun.ShrinePointsCache then
        parts[#parts + 1] = string.format(UIStrings.HeatLabelFmt, CurrentRun.ShrinePointsCache)
    end

    -- Record heat
    local prevRecordHeat = 0
    if GetHighestShrinePointRunClear then
        local ok, rh = pcall(GetHighestShrinePointRunClear)
        if ok and rh then
            prevRecordHeat = rh
            parts[#parts + 1] = string.format(UIStrings.RecordHeatFmt, math.max(CurrentRun.ShrinePointsCache or 0, rh))
        end
    end

    -- Check if new heat record
    if CurrentRun and CurrentRun.ShrinePointsCache and CurrentRun.ShrinePointsCache > prevRecordHeat then
        parts[#parts + 1] = UIStrings.NewHeatRecord
    end

    -- Weapon stats summary
    if WeaponSets and WeaponSets.HeroMeleeWeapons then
        for _, weaponName in ipairs(WeaponSets.HeroMeleeWeapons) do
            local isCurrentWeapon = CurrentRun and CurrentRun.Hero and CurrentRun.Hero.Weapons and CurrentRun.Hero.Weapons[weaponName]
            if isCurrentWeapon then
                local displayName = WeaponDisplayNames[weaponName] or weaponName
                local clears = 0
                if GetNumRunsClearedWithWeapon then
                    local ok, c = pcall(GetNumRunsClearedWithWeapon, weaponName)
                    if ok and c then clears = c end
                end
                parts[#parts + 1] = string.format(UIStrings.WeaponClearsFmt, displayName, clears)
            end
        end
    end

    -- Total clears
    if GameState and GameState.TimesCleared then
        parts[#parts + 1] = string.format(UIStrings.TotalClearsFmt, GameState.TimesCleared)
    end

    -- Clear streak
    if GameState and GameState.ConsecutiveClears then
        parts[#parts + 1] = string.format(UIStrings.ClearStreakFmt, GameState.ConsecutiveClears)
        if GameState.ConsecutiveClearsRecord and GameState.ConsecutiveClears >= GameState.ConsecutiveClearsRecord then
            parts[#parts + 1] = UIStrings.NewStreakRecord
        end
    end

    -- Speak all stats as one message
    local speech = ""
    for i, part in ipairs(parts) do
        if i == 1 then
            speech = part
        else
            speech = speech .. ". " .. part
        end
    end

    TolkSilence()
    TolkSpeak(speech)

    baseFunc()
end)
