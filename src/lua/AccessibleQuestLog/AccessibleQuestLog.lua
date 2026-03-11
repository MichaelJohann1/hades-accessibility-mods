--[[
Mod: AccessibleQuestLog
Author: Accessibility Layer
Version: 2

Provides screen reader accessibility for the Fated List of Minor Prophecies (QuestLog) screen.
- Speaks quest name, description, status, and reward when cursor moves over quest entries
- Hardcoded descriptions from Hades Wiki (engine uses UseDescription=true which Lua can't access)
- Speaks "Fated List" when screen opens
- Speaks page info when scrolling
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

-- Resource name mapping for readable reward output
local resourceNames = {
    ["Gems"] = "Gemstones",
    ["SuperGems"] = "Diamonds",
    ["LockKeys"] = "Chthonic Keys",
    ["SuperLockKeys"] = "Titan Blood",
    ["MetaPoints"] = "Darkness",
    ["GiftPoints"] = "Nectar",
    ["SuperGiftPoints"] = "Ambrosia",
}

-- Hardcoded quest descriptions from Hades Wiki
-- (Engine uses UseDescription=true which resolves at render time, not accessible from Lua)
QuestDescriptions = {
    FirstClear = "The son of the god of the dead shall someday break free from the realm in which he was born",
    MeetOlympians = "The son of the god of the dead shall someday meet some of the rulers of Olympus",
    MeetChthonicGods = "The son of the god of the dead shall someday meet the rulers of the Underworld",
    EpilogueSetUp = "The son of the god of the dead shall someday inspire Queen Persephone to develop a plan that might settle the score between the House of Hades and Olympus",
    OlympianReunion = "The son of the god of the dead shall someday deliver Queen Persephone's personalized invitations to each Olympian, so they might gather for a significant announcement",
    NyxChaosReunion = "The son of the god of the dead shall make certain attempts to aid our Mother Night, who through course of time has grown far apart from Chaos, her parent and origin of all things",
    OrpheusRelease = "The son of the god of the dead shall someday commute a master musician's sentence to solitary confinement in Tartarus",
    OrpheusEurydiceReunion = "The son of the god of the dead shall make certain attempts to aid a master musician who once failed to whisk his deceased wife from the Underworld",
    SisyphusLiberation = "The son of the god of the dead shall make certain attempts to aid the shade of a crafty king, forced to toil eternally, hefting his boulder in Tartarus",
    AchillesPatroclusReunion_A = "The son of the god of the dead shall make certain attempts to aid a great hero who gave up his exalted place in the Underworld for the one he loves",
    AchillesPatroclusReunion_B = "The son of the god of the dead shall make certain attempts to aid a great hero who gave up his exalted place in the Underworld for the one he loves",
    AchillesPatroclusReunion_C = "The son of the god of the dead shall make certain attempts to aid a great hero who gave up his exalted place in the Underworld for the one he loves",
    DusaLoungeRenovation = "The son of the god of the dead shall make certain attempts to aid a tireless gorgon, assigned to bring part of the House to the height of splendor",
    AthenaUpgrades = "The son of the god of the dead shall someday earn various Boons of Athena",
    ZeusUpgrades = "The son of the god of the dead shall someday earn various Boons of Zeus",
    PoseidonUpgrades = "The son of the god of the dead shall someday earn various Boons of Poseidon",
    AphroditeUpgrades = "The son of the god of the dead shall someday earn various Boons of Aphrodite",
    AresUpgrades = "The son of the god of the dead shall someday earn various Boons of Ares",
    ArtemisUpgrades = "The son of the god of the dead shall someday earn various Boons of Artemis",
    DionysusUpgrades = "The son of the god of the dead shall someday earn various Boons of Dionysus",
    HermesUpgrades = "The son of the god of the dead shall someday earn various Boons of Hermes",
    DemeterUpgrades = "The son of the god of the dead shall someday earn various Boons of Demeter",
    LegendaryUpgrades = "The son of the god of the dead shall someday earn various Legendary Boons offered by the Olympians",
    SynergyUpgrades = "The son of the god of the dead shall someday earn various Duo Boons offered by pairs of Olympians",
    ChaosBlessings = "The son of the god of the dead shall someday earn various Blessings offered by Primordial Chaos",
    ChaosCurses = "The son of the god of the dead shall someday suffer various Curses inflicted by Primordial Chaos",
    WeaponUnlocks = "The son of the god of the dead shall someday acquire each of the ancient weapons once used to slay the Titans",
    SwordHammerUpgrades = "The son of the god of the dead shall someday acquire each of the Daedalus enchantments for Stygius",
    BowHammerUpgrades = "The son of the god of the dead shall someday acquire each of the Daedalus enchantments for Coronacht",
    ShieldHammerUpgrades = "The son of the god of the dead shall someday acquire each of the Daedalus enchantments for Aegis",
    SpearHammerUpgrades = "The son of the god of the dead shall someday acquire each of the Daedalus enchantments for Varatha",
    FistHammerUpgrades = "The son of the god of the dead shall someday acquire each of the Daedalus enchantments for Malphon",
    GunHammerUpgrades = "The son of the god of the dead shall someday acquire each of the Daedalus enchantments for Exagryph",
    ArthurAspectEscape = "The Stygian Blade shall someday rise from the Underworld in a form it shall assume again in the hands of a mighty king, whose tale is yet to be spun",
    GuanYuAspectEscape = "The Eternal Spear shall someday rise from the Underworld in a form it shall assume again in the hands of a peerless warrior, whose tale is yet to be spun",
    RamaAspectEscape = "The Heart-Seeking Bow shall someday rise from the Underworld in a form it assumed in the hands of a divine archer, whose deeds shall forever be remembered",
    BeowulfAspectEscape = "The Shield of Chaos shall someday rise from the Underworld in a form it shall assume again in the hands of a monster-hunting hero, whose tale is yet to be spun",
    GilgameshAspectEscape = "The Twin Fists of Malphon shall someday rise from the Underworld in a form it assumed in the hands of a mighty god-king, whose deeds shall forever be remembered",
    LuciferAspectEscape = "The Adamant Rail shall someday rise from the Underworld in a form it assumed in the hands of a rebellious servant, who railed against his all-powerful lord",
    WeaponClears = "The son of the god of the dead shall someday break free from the realm in which he was born using each of the Infernal Arms",
    WeaponAspects = "The son of the god of the dead shall someday harness the ancient Aspects of the Infernal Arms",
    PactUpgrades = "The son of the god of the dead shall someday break free from the realm in which he was born while under the many Conditions of the Pact of Punishment",
    EliteAttributeKills = "The son of the god of the dead shall someday slay foes with each of the Perks from the Pact of Punishment's 'Benefits Package' Condition",
    MiniBossKills = "The son of the god of the dead shall someday slay various armored Wardens guarding key Underworld chambers",
    CosmeticsSmall = "The son of the god of the dead shall someday employ the House Contractor to perform various renovation services",
    CodexSmall = "The son of the god of the dead shall someday reveal a portion of the Underworld Codex entrusted to him",
    WellShopItems = "The son of the god of the dead shall someday purchase each of the various goods sometimes offered in the Well of Charon",
    MirrorUpgrades = "The son of the god of the dead shall someday break free from the realm in which he was born while influenced by all the many Talents revealed in him by the Mirror of Night",
    KeepsakesQuest = "The son of the god of the dead shall someday equip various Keepsakes from those who would be closer to him",
    PoseidonFish = "The son of the god of the dead shall someday catch a significant number of river-dwelling denizens, including an unusually rare species, impressing Lord Poseidon",
    MusicLessons = "The son of the god of the dead shall someday learn to perform music halfway decently through the teachings of a solemn master of the art",
    SkellyTrueDeath = "A stationary animated skeleton shall someday be slain by the blade Stygius, in the fully awakened Aspect of the Prince of the Underworld",
    SkellyTrueDeath_B = "A stationary animated skeleton shall someday be slain by the blade Stygius, in the fully awakened Aspect of the Prince of the Underworld",
    ChaosKeepsakeEscape = "The son of the god of the dead shall someday overcome his own father while in possession of a gift from our primordial originator, Chaos",
    PoseidonBeatTheseus = "The son of the god of the dead shall someday overcome the Hero of Athens under the effect of Pact's 'Extreme Measures' Condition, until the spurned god of the sea is aware",
    AresEarnKills = "The son of the god of the dead shall someday single-handedly vanquish entire legions of the dead, such that even the god of war cannot help but be impressed",
    HermesBeatCharon = "The son of the god of the dead shall someday overcome the Stygian Boatman in two successive battles against him, at the urging of the god of swiftness",
    SkellyPrize = "The son of the god of the dead shall someday earn a magnificent tribute after breaking free from the realm in which he was born, despite the Pact of Punishment.",
}

-- Pending open speech — first MouseOverQuest combines it with first quest
_questLogOpenSpeech = nil

-- Wrap MouseOverQuest to add speech (the game already sets OnMouseOverFunctionName on quest buttons)
ModUtil.WrapBaseFunction("MouseOverQuest", function(baseFunc, button)
    baseFunc(button)

    if not AccessibilityEnabled or not AccessibilityEnabled() or not button then
        return
    end

    local questData = button.Data
    if not questData or not questData.Name then
        return
    end

    -- Get display name for the quest
    local displayName = GetDisplayName({ Text = questData.Name })
    if not displayName or displayName == "" then
        displayName = questData.Name
    end
    displayName = StripFormatting(displayName)

    local speech = displayName

    -- Add description from hardcoded table
    if questData.Name and QuestDescriptions[questData.Name] then
        speech = speech .. ". " .. QuestDescriptions[questData.Name]
    end

    -- Add status
    if GameState and GameState.QuestStatus then
        local status = GameState.QuestStatus[questData.Name]
        if status == "CashedOut" then
            speech = speech .. ", " .. UIStrings.Completed
        elseif IsGameStateEligible and IsGameStateEligible(CurrentRun, questData, questData.CompleteGameStateRequirements) then
            speech = speech .. ", " .. UIStrings.ReadyToCollect
        else
            speech = speech .. ", " .. UIStrings.InProgress
        end
    end

    -- Add reward info
    if questData.RewardResourceName and questData.RewardResourceAmount then
        local resName = resourceNames[questData.RewardResourceName] or questData.RewardResourceName
        speech = speech .. ", Reward: " .. questData.RewardResourceAmount .. " " .. resName
    end

    if _questLogOpenSpeech then
        speech = _questLogOpenSpeech .. ", " .. speech
        _questLogOpenSpeech = nil
    end
    TolkSilence()
    TolkSpeak(speech)
end)

-- Speak when the QuestLog screen opens
ModUtil.WrapBaseFunction("OpenQuestLogScreen", function(baseFunc, args)
    _Log("[SCREEN-OPEN] Fated List (OpenQuestLogScreen)")
    if AccessibilityEnabled and AccessibilityEnabled() then
        _questLogOpenSpeech = UIStrings.FatedList
    end
    return baseFunc(args)
end)

-- Speak page info when scrolling
ModUtil.WrapBaseFunction("QuestLogScrollUp", function(baseFunc, screen, button)
    baseFunc(screen, button)
    if AccessibilityEnabled and AccessibilityEnabled() and screen then
        local page = math.floor(screen.ScrollOffset / screen.ItemsPerPage) + 1
        local totalPages = math.ceil(screen.NumItems / screen.ItemsPerPage)
        TolkSpeak(string.format(UIStrings.PageFmt, page, totalPages))
    end
end)

ModUtil.WrapBaseFunction("QuestLogScrollDown", function(baseFunc, screen, button)
    baseFunc(screen, button)
    if AccessibilityEnabled and AccessibilityEnabled() and screen then
        local page = math.floor(screen.ScrollOffset / screen.ItemsPerPage) + 1
        local totalPages = math.ceil(screen.NumItems / screen.ItemsPerPage)
        TolkSpeak(string.format(UIStrings.PageFmt, page, totalPages))
    end
end)
