--[[
Mod: AccessibleRunHistory
Author: Accessibility Layer
Version: 1

Provides screen reader accessibility for the Run History Screen.
- Wraps ShowRunHistoryScreen to announce screen name + total runs
- Wraps RunHistoryPrevRun/RunHistoryNextRun to speak run stats on navigation
- Reads: run number, result (cleared or death biome), time, weapon, aspect,
  keepsake, companion, boon count, heat level, darkness invested, clear message
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

-- Weapon display names
local WeaponDisplayNames = {
    SwordWeapon = "Stygian Blade",
    SpearWeapon = "Eternal Spear",
    BowWeapon = "Heart-Seeking Bow",
    ShieldWeapon = "Shield of Chaos",
    FistWeapon = "Twin Fists",
    GunWeapon = "Adamant Rail",
}

-- Aspect display names (trait name -> display name)
local AspectDisplayNames = {
    -- Stygian Blade
    SwordBaseUpgradeTrait = "Aspect of Zagreus",
    SwordCriticalParryTrait = "Aspect of Nemesis",
    DislodgeAmmoTrait = "Aspect of Poseidon",
    SwordConsecrationTrait = "Aspect of Arthur",
    -- Eternal Spear
    SpearBaseUpgradeTrait = "Aspect of Zagreus",
    SpearTeleportTrait = "Aspect of Achilles",
    SpearWeaveTrait = "Aspect of Hades",
    SpearSpinTravel = "Aspect of Guan Yu",
    -- Heart-Seeking Bow
    BowBaseUpgradeTrait = "Aspect of Zagreus",
    BowMarkHomingTrait = "Aspect of Chiron",
    BowLoadAmmoTrait = "Aspect of Hera",
    BowBondTrait = "Aspect of Rama",
    -- Shield of Chaos
    ShieldBaseUpgradeTrait = "Aspect of Zagreus",
    ShieldRushBonusProjectileTrait = "Aspect of Chaos",
    ShieldTwoShieldTrait = "Aspect of Zeus",
    ShieldLoadAmmoTrait = "Aspect of Beowulf",
    -- Twin Fists
    FistBaseUpgradeTrait = "Aspect of Zagreus",
    FistVacuumTrait = "Aspect of Talos",
    FistWeaveTrait = "Aspect of Demeter",
    FistDetonateTrait = "Aspect of Gilgamesh",
    -- Adamant Rail
    GunBaseUpgradeTrait = "Aspect of Zagreus",
    GunGrenadeSelfEmpowerTrait = "Aspect of Eris",
    GunManualReloadTrait = "Aspect of Hestia",
    GunLoadedGrenadeTrait = "Aspect of Lucifer",
}

-- Clear message display names (reused from AccessibleRunClear)
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
-- Get biome name from room name prefix
-- ============================================================
local function GetBiomeName(roomName)
    if not roomName then return "Unknown" end
    if roomName:match("^A_") then return "Tartarus"
    elseif roomName:match("^B_") then return "Asphodel"
    elseif roomName:match("^C_") then return "Elysium"
    elseif roomName:match("^D_") then return "Temple of Styx"
    else return roomName end
end

-- ============================================================
-- Get result text for a run
-- ============================================================
local function GetRunResult(run)
    if run.Cleared then
        return UIStrings.Cleared
    end

    -- Try to resolve death location
    local roomName = run.EndingRoomName
    if not roomName then return UIStrings.Died end

    -- Try the game's ResultText localization key
    if RoomData and RoomData[roomName] and RoomData[roomName].ResultText then
        local resolved = SafeGetDisplayName(RoomData[roomName].ResultText)
        if resolved ~= "" then
            return resolved
        end
    end

    -- Fall back to biome name
    return string.format(UIStrings.DiedInFmt, GetBiomeName(roomName))
end

-- ============================================================
-- Get weapon name from run data
-- ============================================================
local function GetRunWeapon(run)
    if not run.WeaponsCache then return nil end
    if not WeaponSets or not WeaponSets.HeroMeleeWeapons then return nil end

    for _, weaponName in ipairs(WeaponSets.HeroMeleeWeapons) do
        if run.WeaponsCache[weaponName] then
            return WeaponDisplayNames[weaponName] or weaponName
        end
    end
    return nil
end

-- ============================================================
-- Get aspect name from run data
-- ============================================================
local function GetRunAspect(run)
    if not run.TraitCache then return nil end

    for traitName, count in pairs(run.TraitCache) do
        local traitData = TraitData and TraitData[traitName]
        if traitData and traitData.IsWeaponEnchantment then
            -- Try hardcoded name
            if AspectDisplayNames[traitName] then
                return AspectDisplayNames[traitName]
            end
            -- Try GetDisplayName
            local resolved = SafeGetDisplayName(traitName)
            if resolved ~= "" and resolved ~= traitName then
                return resolved
            end
            return traitName
        end
    end
    return nil
end

-- ============================================================
-- Get keepsake name from run data
-- ============================================================
local function GetRunKeepsake(run)
    local keepsakeName = run.EndingKeepsakeName
    if not keepsakeName and run.TraitCache then
        for traitName, count in pairs(run.TraitCache) do
            local traitData = TraitData and TraitData[traitName]
            if traitData and traitData.Slot == "Keepsake" then
                keepsakeName = traitName
                break
            end
        end
    end
    if not keepsakeName then return nil end

    -- Try InRackTitle
    local traitData = TraitData and TraitData[keepsakeName]
    if traitData and traitData.InRackTitle then
        local resolved = SafeGetDisplayName(traitData.InRackTitle)
        if resolved ~= "" then return resolved end
    end

    -- Try GetDisplayName
    local resolved = SafeGetDisplayName(keepsakeName)
    if resolved ~= "" and resolved ~= keepsakeName then return resolved end

    return keepsakeName
end

-- ============================================================
-- Get companion (assist) name from run data
-- ============================================================
local function GetRunCompanion(run)
    if not run.TraitCache then return nil end

    for traitName, count in pairs(run.TraitCache) do
        local traitData = TraitData and TraitData[traitName]
        if traitData and traitData.Slot == "Assist" then
            local resolved = SafeGetDisplayName(traitName)
            if resolved ~= "" and resolved ~= traitName then return resolved end
            return traitName
        end
    end
    return nil
end

-- ============================================================
-- Count boons (non-keepsake, non-assist, non-aspect traits)
-- ============================================================
local function GetRunBoonCount(run)
    if not run.TraitCache then return 0 end
    local count = 0
    for traitName, traitCount in pairs(run.TraitCache) do
        local traitData = TraitData and TraitData[traitName]
        if traitData and traitData.Icon and not traitData.IsWeaponEnchantment
           and traitData.Slot ~= "Keepsake" and traitData.Slot ~= "Assist" then
            count = count + 1
        end
    end
    return count
end

-- ============================================================
-- Build speech for a single run
-- ============================================================
local function BuildRunSpeech(run, index)
    if not run then return "No run data" end

    local parts = {}

    -- Run number
    local totalRuns = 0
    if GameState and GameState.RunHistory then
        totalRuns = #GameState.RunHistory
    end
    if index and index <= totalRuns then
        parts[#parts + 1] = string.format(UIStrings.RunOfFmt, index, totalRuns)
    elseif index then
        parts[#parts + 1] = UIStrings.CurrentRun
    end

    -- Result
    parts[#parts + 1] = GetRunResult(run)

    -- Clear message
    if run.RunClearMessage and run.RunClearMessage.Name then
        local msgName = ClearMessageDisplayNames[run.RunClearMessage.Name]
        if not msgName or msgName == "" then
            msgName = SafeGetDisplayName(run.RunClearMessage.Name)
        end
        if msgName and msgName ~= "" then
            parts[#parts + 1] = msgName
        end
    end

    -- Easy Mode level
    if run.EasyModeLevel then
        parts[#parts + 1] = string.format(UIStrings.GodModeFmt, run.EasyModeLevel)
    end

    -- Time
    if run.GameplayTime then
        local ok, timeStr = pcall(GetTimerString, run.GameplayTime, 2)
        if ok and timeStr then
            parts[#parts + 1] = string.format(UIStrings.TimeFmt, timeStr)
        end
    end

    -- Weapon
    local weapon = GetRunWeapon(run)
    if weapon then
        parts[#parts + 1] = string.format(UIStrings.WeaponFmt, weapon)
    end

    -- Aspect
    local aspect = GetRunAspect(run)
    if aspect then
        parts[#parts + 1] = aspect
    end

    -- Keepsake
    local keepsake = GetRunKeepsake(run)
    if keepsake then
        parts[#parts + 1] = string.format(UIStrings.KeepsakeFmt, keepsake)
    end

    -- Companion
    local companion = GetRunCompanion(run)
    if companion then
        parts[#parts + 1] = string.format(UIStrings.CompanionFmt, companion)
    end

    -- Boon count
    local boonCount = GetRunBoonCount(run)
    if boonCount > 0 then
        parts[#parts + 1] = string.format(UIStrings.BoonCountFmt, boonCount)
    end

    -- Heat (Shrine Points)
    if run.ShrinePointsCache and run.ShrinePointsCache > 0 then
        parts[#parts + 1] = string.format(UIStrings.HeatLabelFmt, run.ShrinePointsCache)
    end

    -- Darkness invested (Meta Points)
    if run.MetaPointsCache and run.MetaPointsCache > 0 then
        parts[#parts + 1] = string.format(UIStrings.DarknessLabelFmt, run.MetaPointsCache)
    end

    -- Build speech
    local speech = ""
    for i, part in ipairs(parts) do
        if i == 1 then
            speech = part
        else
            speech = speech .. ". " .. part
        end
    end
    return speech
end

-- ============================================================
-- Wrap ShowRunHistoryScreen to announce screen + initial run
-- ============================================================
ModUtil.WrapBaseFunction("ShowRunHistoryScreen", function(baseFunc)
    _Log("[SCREEN-OPEN] Run History (ShowRunHistoryScreen)")
    if AccessibilityEnabled and AccessibilityEnabled() then
        local totalRuns = 0
        if GameState and GameState.RunHistory then
            totalRuns = #GameState.RunHistory
        end

        -- Build initial run speech (screen starts at most recent / current run)
        local initialIndex = totalRuns + 1
        local initialRun = CurrentRun
        if totalRuns > 0 and not initialRun then
            initialRun = GameState.RunHistory[totalRuns]
            initialIndex = totalRuns
        end

        local speech = string.format(UIStrings.RunHistoryOpenFmt, totalRuns)
        if initialRun then
            speech = speech .. " " .. BuildRunSpeech(initialRun, initialIndex)
        end

        TolkSilence()
        TolkSpeak(speech)
    end

    baseFunc()
end)

-- ============================================================
-- Wrap RunHistoryPrevRun to speak run stats on navigation
-- ============================================================
ModUtil.WrapBaseFunction("RunHistoryPrevRun", function(baseFunc, screen, button)
    local prevIndex = screen.RunIndex

    baseFunc(screen, button)

    if not AccessibilityEnabled or not AccessibilityEnabled() then return end

    -- Check if navigation actually happened
    if screen.RunIndex == prevIndex then
        TolkSilence()
        TolkSpeak(UIStrings.NoEarlierRuns)
        return
    end

    local run = GameState.RunHistory[screen.RunIndex] or CurrentRun
    local speech = BuildRunSpeech(run, screen.RunIndex)
    TolkSilence()
    TolkSpeak(speech)
end)

-- ============================================================
-- Wrap RunHistoryNextRun to speak run stats on navigation
-- ============================================================
ModUtil.WrapBaseFunction("RunHistoryNextRun", function(baseFunc, screen, button)
    local prevIndex = screen.RunIndex

    baseFunc(screen, button)

    if not AccessibilityEnabled or not AccessibilityEnabled() then return end

    -- Check if navigation actually happened
    if screen.RunIndex == prevIndex then
        TolkSilence()
        TolkSpeak(UIStrings.NoLaterRuns)
        return
    end

    local run = GameState.RunHistory[screen.RunIndex] or CurrentRun
    local speech = BuildRunSpeech(run, screen.RunIndex)
    TolkSilence()
    TolkSpeak(speech)
end)
