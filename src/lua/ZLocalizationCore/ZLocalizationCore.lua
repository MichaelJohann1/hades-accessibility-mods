-- ZLocalizationCore.lua
-- Localization infrastructure for Hades accessibility mods.
-- Loaded LAST (Z prefix ensures alphabetical ordering after all other mods).
-- Provides backup/restore/overlay functions for language switching.
-- Language files are loaded externally by C++ from x64/languages/<code>.lua.

-- All tables that language files can override.
-- These must be GLOBAL in their respective mods.
_LocalizableTables = {
    -- AccessibleBoons.lua
    "BoonDisplayNames",
    "GodBoonDescriptions",
    "HammerDescriptions",
    "ChaosBlessingDescriptions",
    "ChaosCurseDescriptions",
    "GodDisplayNames",
    "GodFlavorText",
    "SlotDescriptions",
    "DuoBoonGods",
    -- AccessibleMirror.lua
    "MetaUpgradeDisplayNames",
    "MetaUpgradeDescriptions",
    "MirrorFlavorText",
    "PactFlavorText",
    -- AccessibleContractor.lua
    "ContractorItemNames",
    "ContractorItemDescriptions",
    "MusicTrackDisplayNames",
    -- AccessibleKeepsakes.lua
    "KeepsakeDescriptions",
    -- AccessibleQuestLog.lua
    "QuestDescriptions",
    -- AccessibleWell.lua
    "WellItemNames",
    "WellItemDescriptions",
    -- AccessibleNotifications.lua
    "LocationDisplayNames",
    "NPCDisplayNames",
    "FishDisplayNames",
    "ObjectiveDescriptions",
    "WeaponDisplayNames",
    "KeepsakeDisplayNames",
    "ChoiceDisplayNames",
    "ResourceDisplayNames",
    "KeepsakeGiftNames",
    -- AccessibleTraitTray.lua
    "AspectDisplayNames",
    -- AccessiblePool.lua (uses globals from AccessibleBoons)
    -- AccessibleMusicPlayer.lua
    "TrackDisplayNames",
    -- UI strings table
    "UIStrings",
}

-- English backup storage (populated by _BackupEnglishTables)
_EnglishBackup = {}

-- UI strings table: all inline English text used in TolkSpeak calls.
-- Language files override entries in this table.
UIStrings = {
    -- Screen/menu names
    RewardMenu = "Reward Menu",
    DoorMenu = "Door Menu",
    StoreMenu = "Store Menu",
    ResourceInfo = "Resource Info",
    Relationships = "Relationships",
    MirrorOfNight = "Mirror of Night",
    PactOfPunishment = "Pact of Punishment",
    HouseContractor = "House Contractor",
    FatedList = "Fated List of Minor Prophecies",
    RunTracker = "Run Tracker",
    KeepsakeDisplayCase = "Keepsake Display Case",
    WellOfCharon = "Well of Charon",
    WretchedBroker = "Wretched Broker",
    BoonInventory = "Boon Inventory",
    PoolOfPurging = "Pool of Purging",
    PactInfo = "Pact Info",
    BoonInfo = "Boon Info",
    MusicPlayer = "Music Player",
    WeaponAspects = "Weapon Aspects",
    BoonTray = "Boon Tray",
    Codex = "Codex",
    RunHistory = "Run History",
    RunClear = "Run Clear",
    ScryingPool = "Scrying Pool",

    -- Rarity
    Common = "Common",
    Rare = "Rare",
    Epic = "Epic",
    Heroic = "Heroic",
    Legendary = "Legendary",
    Duo = "Duo",

    -- Status/labels
    Locked = "Locked",
    CannotAfford = "Cannot Afford",
    Equipped = "Equipped",
    Acquired = "Acquired",
    Purchased = "Purchased",
    Sold = "Sold",
    Blocked = "Blocked",
    Active = "Active",
    MaxLevel = "Max Level",
    MaxRank = "Max Rank",
    Free = "Free",
    SoldOut = "Sold Out",
    NotUnlocked = "Not Unlocked",
    UnknownAspect = "Unknown Aspect",
    RequirementsNotMet = "Locked, requirements not met",
    Cleared = "Cleared",
    Died = "Died",
    CurrentRun = "Current Run",

    -- Resources
    Darkness = "Darkness",
    Gemstones = "Gemstones",
    ChthonicKeys = "Chthonic Keys",
    Obols = "Obols",
    Nectar = "Nectar",
    Ambrosia = "Ambrosia",
    TitanBlood = "Titan Blood",
    Diamonds = "Diamonds",
    Health = "Health",
    MaxHealth = "Max Health",
    Healing = "Healing",

    -- Navigation/actions
    Close = "Close",
    Reroll = "Reroll",
    Page = "Page",
    Of = "of",
    Level = "Level",
    Chamber = "Chamber",
    Heat = "Heat",
    To = "to",
    Category = "category",

    -- Combat/health
    DeathDefiance = "Death Defiance",
    LuckyTooth = "Lucky Tooth",
    Killed = "Killed",
    Armor = "armor",
    ArmorBroken = "Armor broken",

    -- Boon info
    AttackBoon = "Attack boon",
    SpecialBoon = "Special boon",
    CastBoon = "Cast boon",
    DashBoon = "Dash boon",
    CallBoon = "Call boon",
    Replaces = "Replaces",

    -- Notifications
    GodModeEnabled = "God Mode enabled",
    GodModeDisabled = "God Mode disabled",
    PercentDamageResistance = "percent damage resistance",
    SubtitlesOn = "Subtitles on",
    SubtitlesOff = "Subtitles off",
    Gained = "Gained",
    NewKeepsakeFrom = "New Keepsake from",
    EquippedKeepsake = "Equipped keepsake",
    EquippedWeapon = "Equipped weapon",
    Caught = "Caught",
    NowPlayingStatus = "Now Playing",
    PausedStatus = "Paused",

    -- Quest status
    InProgress = "In Progress",
    ReadyToCollect = "Ready to Collect",
    Completed = "Completed",

    -- Contractor
    WorkOrders = "Work Orders",
    Available = "available",

    -- Format strings (word order may differ per language)
    -- %s placeholders for dynamic values
    MirrorOpenFmt = "Mirror of Night, %s Darkness, %s Chthonic Keys",
    PactOpenFmt = "Pact of Punishment, %s of %s Heat",
    StartRunFmt = "Start Run with %s Heat",
    HealthFmt = "%s health",
    HealedFmt = "Healed %s, %s health",
    LostHealthFmt = "Lost %s health, %s remaining",
    LevelFmt = "Level %s",
    ChamberFmt = "Chamber %s",
    PageFmt = "Page %s of %s",
    GainedFmt = "Gained %s %s",
    AcquiredFmt = "Acquired: %s",
    SoldFmt = "Sold %s for %s Obols",
    EquippedFmt = "Equipped %s",
    CaughtFmt = "Caught: %s",
    DeathDefianceFmt = "Death Defiance! %s remaining",
    LuckyToothFmt = "Lucky Tooth!",
    NowPlayingFmt = "Now Playing: %s",
    PausedFmt = "Paused: %s",
    ResumedFmt = "Resumed: %s",
    UnlockCostFmt = "%s %s to unlock",
    FatedPersuasionFmt = "Fated Persuasion, Reroll %s",
    AddHeatFmt = "Adds %s Heat",
    RemoveHeatFmt = "Removes %s Heat",
    SwitchToFmt = "Switch to %s",
    SwitchedToFmt = "Switched to %s",
    LockedKeyCostFmt = "Locked, %s Chthonic Keys to unlock",
    ChaosGateHealthFmt = "Chaos Gate (%s Health)",
    InfernalGateHealthFmt = "Infernal Gate (%s Health)",
    MoreEncountersFmt = "%s more %s to next entry",
    EncountersRemainingFmt = "%s encounters remaining",
    WeaponUnlockCostFmt = "%s Chthonic Keys to unlock",
    TitanBloodAvailableFmt = "%s Titan Blood available",
    ObolsAvailableFmt = "%s Obols available",
    GemsAvailableFmt = "%s Gemstones available",
    DarknessAvailableFmt = "%s Darkness available",
    SurviveForFmt = "Survive for %s seconds",
    CostHealthFmt = "Costs %s Health",
    SellForFmt = "Sell for %s Obols",
    BoonsToSellFmt = "%s boons available to sell",
    RunOfFmt = "Run %s of %s",
    DiedInFmt = "Died in %s",
    GodModeFmt = "God Mode %s%%",
    TimeFmt = "Time: %s",
    WeaponFmt = "Weapon: %s",
    KeepsakeFmt = "Keepsake: %s",
    CompanionFmt = "Companion: %s",
    BoonCountFmt = "%s Boons",
    HeatLabelFmt = "Heat: %s",
    DarknessLabelFmt = "Darkness: %s",
    ClearTimeFmt = "Clear Time: %s",
    RecordTimeFmt = "Record Time: %s",
    RecordHeatFmt = "Record Heat: %s",
    WeaponClearsFmt = "Weapon: %s, %s total clears",
    TotalClearsFmt = "Total Clears: %s",
    ClearStreakFmt = "Clear Streak: %s",
    NewTimeRecord = "New Time Record!",
    NewHeatRecord = "New Heat Record!",
    NewStreakRecord = "New Streak Record!",
    EntryOfFmt = "Entry %s of %s",
    FullyDiscovered = "Fully discovered",
    ContinueStory = "Continue the story to discover more",
    TitanBloodUpgradeFmt = "%s Titan Blood to upgrade",
    TitanBloodUnlockFmt = "%s Titan Blood to unlock",
    UpgradeAspectFmt = "Upgrade %s. %s Titan Blood",
    UnlockAspectFmt = "Unlock %s. %s Titan Blood",
    AspectFmt = "Aspect %s",
    CategoryFmt = "%s category",
    WeaponAspectsOpenFmt = "Weapon Aspects, %s. %s Titan Blood available. Up and Down to browse aspects, press to equip or upgrade.",
    MusicPlayerOpenFmt = "Music Player. %s of %s tracks unlocked. Up and Down to browse, press to play or pause.",
    RunHistoryOpenFmt = "Run History. %s past runs. Left and Right to browse.",
    BoonTrayFmt = "Boon Tray, %s %s",
    EscapeAttemptsFmt = "%s escape attempts",
    FoesVanquishedFmt = "%s foes vanquished",
    UsedTimesFmt = "used %s times",
    NumClearsFmt = "%s clears",
    BestTimeFmt = "Best %sm %ss",

    -- Damage feedback mode names
    DamageFeedbackOff = "Damage feedback off",
    DamageFeedbackAudible = "Damage feedback audible healthbars",
    DamageFeedbackDealt = "Damage feedback damage dealt",
    DamageFeedbackCombined = "Damage feedback combined",

    -- Encounter/challenge types
    InfernalTroveChallenge = "Infernal Trove challenge",
    ErebusChallenge = "Erebus challenge, clear without taking damage",
    ThanatosChallenge = "Thanatos challenge, compete for kills",
    MovingPlatforms = "Moving platforms",
    TightDeadline = "Tight Deadline",
    TimeExpired = "Time expired! Taking damage, leave now",
    Encounters = "encounters",
    Kills = "kills",
    Uses = "uses",
    Catches = "catches",
    Gifts = "gifts",

    -- Chaos boons
    Curse = "Curse",
    Blessing = "Blessing",
    CurseLasts = "Curse lasts %s encounters",

    -- Boon info
    PreviouslyAcquired = "Previously acquired",
    NotYetAcquired = "Not yet acquired",
    UpToFmt = "up to %s",

    -- Reroll
    Remaining = "remaining",
    CostFmt = "Cost: %s",

    -- Quest reward
    RewardFmt = "Reward: %s %s",

    -- Misc
    Boons = "Boons",
    WellItems = "Well items",
    Boon = "Boon",
    Charge = "charge",
    Charges = "charges",
    DoorToX = "Door to %s",
    PathToGarden = "Path to Garden",
    EscapeWindow = "Escape Window (Pact of Punishment)",
    ExaminePoint = "Examine Point",
    LockedKeepsake = "Locked keepsake",
    LockedCompanion = "Locked companion",
    NoEarlierRuns = "No earlier runs",
    NoLaterRuns = "No later runs",
    UpDownBrowse = "Up and Down to browse",
}

-- Back up all current (English) table values.
-- Called once after all mods are loaded, before any language overlay.
function _BackupEnglishTables()
    _EnglishBackup = {}
    for _, name in ipairs(_LocalizableTables) do
        if _G[name] and type(_G[name]) == "table" then
            _EnglishBackup[name] = {}
            for k, v in pairs(_G[name]) do
                _EnglishBackup[name][k] = v
            end
        end
    end
end

-- Restore all tables to their English values from backup.
function _RestoreEnglish()
    for name, backup in pairs(_EnglishBackup) do
        if _G[name] and type(_G[name]) == "table" then
            -- Clear current entries that were added by a language file
            -- (in case the language file had keys not in English)
            -- Then restore from backup
            for k, _ in pairs(_G[name]) do
                if backup[k] == nil then
                    _G[name][k] = nil
                end
            end
            for k, v in pairs(backup) do
                _G[name][k] = v
            end
        end
    end
end

-- Apply language data from a language file.
-- langData is a table of { tableName = { key = value, ... }, ... }.
-- Restores English first, then overlays the new language.
-- Missing entries in the language file keep their English values.
function _ApplyLanguageData(langData)
    if not langData or type(langData) ~= "table" then return end
    _RestoreEnglish()
    for tableName, entries in pairs(langData) do
        if _G[tableName] and type(_G[tableName]) == "table" and type(entries) == "table" then
            for k, v in pairs(entries) do
                _G[tableName][k] = v
            end
        end
    end
end

-- Default language
if not _CurrentLanguage then
    _CurrentLanguage = "en"
end

local function _Log(msg)
    if LogEvent then LogEvent("[LOCALIZATION] " .. msg) end
end

_Log("LocalizationCore loaded. Language: " .. tostring(_CurrentLanguage))
