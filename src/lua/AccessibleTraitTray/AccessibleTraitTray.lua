--[[
Mod: AccessibleTraitTray
Author: Accessibility Layer
Version: 2

Provides screen reader accessibility for the TraitTrayScreen (boon inventory, B/Select during runs).
- Speaks boon name, god name, rarity, slot, level, description, and computed values
- Shows encounters remaining for Well of Charon items and Chaos curses
- Shows keepsake descriptions with level-appropriate values
- Handles god boons, hammer upgrades, Chaos blessings, keepsakes, weapon aspects, Well items
- Speaks Mirror/Pact upgrade names and levels when hovering their icons
- Announces trait count on screen open ("Boon Tray, N boons")
- Uses global tables from AccessibleBoons (BoonDisplayNames, GodBoonDescriptions, HammerDescriptions,
  ChaosBlessingDescriptions, ChaosCurseDescriptions), AccessibleWell (WellItemNames, WellItemDescriptions),
  and AccessibleKeepsakes (KeepsakeDescriptions)
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

local function SafeGetDisplayName(key)
    if not key or key == "" then return "" end
    local ok, result = pcall(GetDisplayName, { Text = key })
    if ok and result and result ~= "" then
        return StripFormatting(result)
    end
    return ""
end

-- ============================================================
-- God name mapping for boon traits
-- Maps trait names to their god(s). For duo boons, shows both gods.
-- Prefix-based traits (ZeusWeaponTrait, etc.) are handled by GetGodForTrait()
-- This table covers non-obvious trait names that don't start with a god prefix.
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
    NoLastStandRegenerationTrait = "Athena, Demeter",
}

-- Resolve the god name for a trait, using prefix matching + static lookup
local function GetGodForTrait(traitName)
    if not traitName then return nil end
    -- Check static table first (handles non-obvious names + duo boons)
    if BoonTraitToGod[traitName] then
        return BoonTraitToGod[traitName]
    end
    -- Prefix-based detection for standard god boons
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

-- ============================================================
-- Weapon Aspect display names (24 entries: 6 weapons x 4 aspects)
-- ============================================================
AspectDisplayNames = {
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

-- ============================================================
-- Keepsake display names (31 entries: 25 keepsakes + 6 companions)
-- ============================================================
local KeepsakeDisplayNames = {
    CerberusKeepsake = "Old Spiked Collar",
    AchillesKeepsake = "Myrmidon Bracer",
    NyxKeepsake = "Black Shawl",
    ThanatosKeepsake = "Pierced Butterfly",
    ChronKeepsake = "Bone Hourglass",
    HypnosKeepsake = "Chthonic Coin Purse",
    MegKeepsake = "Skull Earring",
    OrpheusKeepsake = "Distant Memory",
    DusaKeepsake = "Harpy Feather Duster",
    SkellyKeepsake = "Lucky Tooth",
    SisyphusKeepsake = "Shattered Shackle",
    EurydiceKeepsake = "Evergreen Acorn",
    PatroclusKeepsake = "Broken Spearpoint",
    ZeusKeepsake = "Thunder Signet",
    PoseidonKeepsake = "Conch Shell",
    AthenaKeepsake = "Owl Pendant",
    AresKeepsake = "Blood-Filled Vial",
    AphroditeKeepsake = "Eternal Rose",
    ArtemisKeepsake = "Adamant Arrowhead",
    DionysusKeepsake = "Overflowing Cup",
    HermesKeepsake = "Lambent Plume",
    DemeterKeepsake = "Frostbitten Horn",
    ChaosKeepsake = "Cosmic Egg",
    HadesKeepsake = "Sigil of the Dead",
    ReincarnationTrait = "Lucky Tooth",
    -- Keepsake trait names (what the hero actually has equipped)
    MaxHealthKeepsakeTrait = "Old Spiked Collar",
    DirectionalArmorTrait = "Myrmidon Bracer",
    BackstabAlphaStrikeTrait = "Black Shawl",
    PerfectClearDamageBonusTrait = "Pierced Butterfly",
    ShopDurationTrait = "Bone Hourglass",
    BonusMoneyTrait = "Chthonic Coin Purse",
    LowHealthDamageTrait = "Skull Earring",
    DistanceDamageTrait = "Distant Memory",
    LifeOnUrnTrait = "Harpy Feather Duster",
    ForceZeusBoonTrait = "Thunder Signet",
    ForcePoseidonBoonTrait = "Conch Shell",
    ForceAthenaBoonTrait = "Owl Pendant",
    ForceAresBoonTrait = "Blood-Filled Vial",
    ForceAphroditeBoonTrait = "Eternal Rose",
    ForceArtemisBoonTrait = "Adamant Arrowhead",
    ForceDionysusBoonTrait = "Overflowing Cup",
    FastClearDodgeBonusTrait = "Lambent Plume",
    ForceDemeterBoonTrait = "Frostbitten Horn",
    ChaosBoonTrait = "Cosmic Egg",
    VanillaTrait = "Shattered Shackle",
    ShieldBossTrait = "Evergreen Acorn",
    ShieldAfterHitTrait = "Broken Spearpoint",
    ChamberStackTrait = "Sigil of the Dead",
    HadesShoutKeepsake = "Sigil of the Dead",
    -- Companions
    FurySummonTrait = "Battie",
    AntosSummonTrait = "Rib",
    NpcSummonTrait_Thanatos = "Mort",
    NpcSummonTrait_Sisyphus = "Shady",
    NpcSummonTrait_Achilles = "Antos",
    NpcSummonTrait_Dusa = "Fidi",
}

-- Map keepsake trait names to the trait names used in KeepsakeDescriptions (from AccessibleKeepsakes)
-- This is needed because the trait tray shows keepsake TRAIT names (e.g. MaxHealthKeepsakeTrait)
-- but the hero's traits list may show different names
local KeepsakeTraitToDescKey = {
    MaxHealthKeepsakeTrait = "MaxHealthKeepsakeTrait",
    DirectionalArmorTrait = "DirectionalArmorTrait",
    BackstabAlphaStrikeTrait = "BackstabAlphaStrikeTrait",
    PerfectClearDamageBonusTrait = "PerfectClearDamageBonusTrait",
    ShopDurationTrait = "ShopDurationTrait",
    BonusMoneyTrait = "BonusMoneyTrait",
    LowHealthDamageTrait = "LowHealthDamageTrait",
    DistanceDamageTrait = "DistanceDamageTrait",
    LifeOnUrnTrait = "LifeOnUrnTrait",
    ReincarnationTrait = "ReincarnationTrait",
    ForceZeusBoonTrait = "ForceZeusBoonTrait",
    ForcePoseidonBoonTrait = "ForcePoseidonBoonTrait",
    ForceAthenaBoonTrait = "ForceAthenaBoonTrait",
    ForceAphroditeBoonTrait = "ForceAphroditeBoonTrait",
    ForceAresBoonTrait = "ForceAresBoonTrait",
    ForceArtemisBoonTrait = "ForceArtemisBoonTrait",
    ForceDionysusBoonTrait = "ForceDionysusBoonTrait",
    FastClearDodgeBonusTrait = "FastClearDodgeBonusTrait",
    ForceDemeterBoonTrait = "ForceDemeterBoonTrait",
    ChaosBoonTrait = "ChaosBoonTrait",
    VanillaTrait = "VanillaTrait",
    ShieldBossTrait = "ShieldBossTrait",
    ShieldAfterHitTrait = "ShieldAfterHitTrait",
    ChamberStackTrait = "ChamberStackTrait",
    HadesShoutKeepsake = "HadesShoutKeepsake",
    FuryAssistTrait = "FuryAssistTrait",
    AchillesPatroclusAssistTrait = "AchillesPatroclusAssistTrait",
    ThanatosAssistTrait = "ThanatosAssistTrait",
    SisyphusAssistTrait = "SisyphusAssistTrait",
    SkellyAssistTrait = "SkellyAssistTrait",
    DusaAssistTrait = "DusaAssistTrait",
}

-- ============================================================
-- Mirror/Pact display names (40 entries: 24 Mirror + 16 Pact)
-- ============================================================
local MetaUpgradeDisplayNames = {
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
    -- Pact of Punishment (16)
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

-- ============================================================
-- Mirror/Pact upgrade descriptions (for trait tray icon hover)
-- ============================================================
local MetaUpgradeDescriptions = {
    -- Mirror of Night upgrades (12 pairs = 24 total)
    BackstabMetaUpgrade = {
        base = "Attack and Special gain +%d%% damage per rank when striking foes from behind",
        perLevel = 10,
    },
    FirstStrikeMetaUpgrade = {
        base = "Attack and Special gain +%d%% damage per rank when striking undamaged foes",
        perLevel = 10,
    },
    DoorHealMetaUpgrade = {
        base = "Each rank restores %d health when you exit each chamber",
        perLevel = 1,
    },
    DarknessHealMetaUpgrade = {
        base = "Each rank makes +%d%% of any Darkness you collect restore your health by that much",
        perLevel = 30,
    },
    ExtraChanceMetaUpgrade = {
        text = "Each rank restores you for 50%% health one time when your Life Total is depleted. Uses per escape attempt: %d",
        usesLevel = true,
    },
    ExtraChanceReplenishMetaUpgrade = {
        text = "This restores you to 30%% health one time per chamber when your Life Total is depleted",
        static = true,
    },
    StaminaMetaUpgrade = {
        text = "Each rank lets you chain +1 Dash before briefly recovering",
        static = true,
    },
    PerfectDashMetaUpgrade = {
        text = "If you Dash just before getting hit, gain +50%% damage and dodge chance for 2 seconds",
        static = true,
    },
    StoredAmmoVulnerabilityMetaUpgrade = {
        base = "Each rank gives you +%d%% Attack and Special damage to foes with cast ammo in them",
        perLevel = 10,
    },
    StoredAmmoSlowMetaUpgrade = {
        base = "Each rank reduces foes' speed and damage by -%d%% while they have cast ammo in them",
        perLevel = 6,
    },
    AmmoMetaUpgrade = {
        base = "Each rank gives you +%d for your Cast",
        perLevel = 1,
    },
    ReloadAmmoMetaUpgrade = {
        text = "Your cast regenerates, but no longer drops. Each rank makes this 1 second faster",
        static = true,
    },
    MoneyMetaUpgrade = {
        base = "Each rank grants you %d obols at the start of each escape from the House of Hades",
        perLevel = 10,
    },
    InterestMetaUpgrade = {
        base = "Each rank grants you +%d%% of your total obols each time you clear an Underworld region",
        perLevel = 5,
    },
    HealthMetaUpgrade = {
        base = "Each rank adds +%d to your Life Total",
        perLevel = 5,
    },
    HighHealthDamageMetaUpgrade = {
        base = "Each rank gives you +%d%% damage while you have 80%% or greater health",
        perLevel = 5,
    },
    VulnerabilityEffectBonusMetaUpgrade = {
        base = "Each rank gives you +%d%% damage vs. foes afflicted by at least two Status Curse effects",
        perLevel = 20,
    },
    GodEnhancementMetaUpgrade = {
        base = "Each rank gives you +%d%% damage for each different Olympian whose Boons you have",
        perLevel = 2.5,
        formatFunc = true,
    },
    RareBoonDropMetaUpgrade = {
        base = "Each rank adds a +%d%% bonus chance for a Boon to be Rare",
        perLevel = 1,
    },
    RunProgressRewardMetaUpgrade = {
        base = "Each rank gives you +%d%% greater chance for high-value rewards (Boons, Hammers, Obol and Poms)",
        perLevel = 2,
    },
    EpicBoonDropMetaUpgrade = {
        base = "Each rank adds a +%d%% bonus chance for a Boon to be Epic",
        perLevel = 1,
    },
    DuoRarityBoonDropMetaUpgrade = {
        base = "Each rank gives you +%d%% greater chance for a Boon to be Legendary or a Duo (if possible)",
        perLevel = 1,
    },
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
        perLevel = 20,
    },
    HealingReductionShrineUpgrade = {
        base = "All healing effects are reduced by %d%%",
        perLevel = 25,
    },
    ShopPricesShrineUpgrade = {
        base = "Prices at the Well of Charon and Charon's shop are %d%% higher",
        perLevel = 40,
    },
    EnemyCountShrineUpgrade = {
        base = "%d%% more foes appear in standard encounters",
        perLevel = 20,
    },
    BossDifficultyShrineUpgrade = {
        text = "Boss encounters become more dangerous with new abilities and mechanics per rank",
        static = true,
    },
    EnemyHealthShrineUpgrade = {
        base = "Foes have %d%% more Health",
        perLevel = 15,
    },
    EnemyEliteShrineUpgrade = {
        text = "Armored foes gain 1 additional ability per rank",
        static = true,
    },
    MinibossCountShrineUpgrade = {
        text = "You encounter 1 additional mini-boss per encounter",
        static = true,
    },
    ForceSellShrineUpgrade = {
        text = "You must purge 1 Boon to unlock the exit to each Underworld region",
        static = true,
    },
    EnemySpeedShrineUpgrade = {
        base = "Foes move and attack %d%% faster",
        perLevel = 20,
    },
    TrapDamageShrineUpgrade = {
        text = "All Traps and Magma deal 400%% more damage",
        static = true,
    },
    MetaUpgradeStrikeThroughShrineUpgrade = {
        text = "Disables your last unlocked Mirror of Night talent per rank",
        static = true,
    },
    EnemyShieldShrineUpgrade = {
        text = "Each foe has a damage-absorbing shield blocking the first hit per rank",
        static = true,
    },
    ReducedLootChoicesShrineUpgrade = {
        text = "Your choices are reduced by 1 when picking Boons, items at the Well, and rewards from Chaos",
        static = true,
    },
    BiomeSpeedShrineUpgrade = {
        base = "You have %d minutes to clear each Underworld region, or else you take damage",
        perLevel = -2,
        baseValue = 11,
    },
    NoInvulnerabilityShrineUpgrade = {
        text = "You no longer have any brief period of invulnerability after taking damage",
        static = true,
    },
}

-- Get description text for a Mirror/Pact upgrade at a given level
local function GetMetaUpgradeDescription(upgradeName, level)
    local desc = MetaUpgradeDescriptions[upgradeName]
    if not desc then return nil end

    local ok, result = pcall(function()
        if desc.static then
            return (desc.text or desc.base):gsub("%%%%", "%%")
        elseif desc.usesLevel then
            return string.format(desc.text or desc.base, level)
        elseif desc.base and desc.perLevel then
            local value
            if desc.baseValue then
                value = desc.baseValue + desc.perLevel * level
            else
                value = desc.perLevel * level
            end
            if desc.formatFunc then
                -- Non-integer value (e.g. 2.5% for Family Favorite)
                if value == math.floor(value) then
                    return string.format(desc.base, value)
                else
                    return string.format(desc.base:gsub("%%d", "%.1f"), value)
                end
            else
                return string.format(desc.base, value)
            end
        end
        return desc.text or desc.base
    end)

    if ok and result then
        return result
    end
    return desc.text or desc.base
end

-- ============================================================
-- Slot display names (map internal slot names to readable names)
-- ============================================================
local SlotDisplayNames = {
    Melee = "Attack",
    Secondary = "Special",
    Ranged = "Cast",
    Rush = "Dash",
    Shout = "Call",
    Keepsake = "Keepsake",
    Assist = "Companion",
}

-- ============================================================
-- Detect if a trait is a Well of Charon temporary item
-- Well items have names starting with "Temporary" or are in WellItemNames
-- ============================================================
local function IsWellItem(traitName)
    if not traitName then return false end
    if traitName:find("^Temporary") then return true end
    if WellItemNames and WellItemNames[traitName] then return true end
    return false
end

-- ============================================================
-- Detect if a trait is a Chaos curse (transforming trait)
-- Chaos curses have names starting with "ChaosCurse"
-- ============================================================
local function IsChaosCurse(traitName)
    if not traitName then return false end
    if traitName:find("^ChaosCurse") then return true end
    return false
end

-- ============================================================
-- Detect if a trait is a Chaos blessing
-- Chaos blessings have names starting with "ChaosBlessing"
-- ============================================================
local function IsChaosBless(traitName)
    if not traitName then return false end
    if traitName:find("^ChaosBlessing") then return true end
    return false
end

-- ============================================================
-- Get the keepsake description with level-appropriate values
-- Uses the global KeepsakeDescriptions table from AccessibleKeepsakes
-- ============================================================
local function GetKeepsakeDescription(traitName)
    if not KeepsakeDescriptions then return nil end
    local desc = KeepsakeDescriptions[traitName]
    if not desc then return nil end

    -- Some descriptions are tables with level-scaled values
    if type(desc) == "table" and desc.text and desc.values then
        -- Get keepsake level (1-3)
        local level = 1
        if GetKeepsakeLevel then
            local ok, lv = pcall(GetKeepsakeLevel, traitName)
            if ok and lv and lv > 0 then
                level = lv
            end
        end
        -- Clamp to valid index
        if level > #desc.values then level = #desc.values end
        if level < 1 then level = 1 end
        return string.format(desc.text, desc.values[level])
    elseif type(desc) == "string" then
        return desc
    end
    return nil
end

-- ============================================================
-- Resolve trait name through priority chain
-- ============================================================
local function ResolveTraitName(traitName)
    if not traitName then return "Unknown" end
    -- Check BoonDisplayNames (global from AccessibleBoons)
    if BoonDisplayNames and BoonDisplayNames[traitName] then
        return BoonDisplayNames[traitName]
    end
    -- Check weapon aspects
    if AspectDisplayNames[traitName] then
        return AspectDisplayNames[traitName]
    end
    -- Check keepsakes
    if KeepsakeDisplayNames[traitName] then
        return KeepsakeDisplayNames[traitName]
    end
    -- Check Well of Charon items (global from AccessibleWell)
    if WellItemNames and WellItemNames[traitName] then
        return WellItemNames[traitName]
    end
    -- Try game's display name resolution
    local displayName = SafeGetDisplayName(traitName)
    if displayName ~= "" and displayName ~= traitName then
        return displayName
    end
    -- Fallback: clean up internal name (remove Trait suffix, add spaces before capitals)
    local cleaned = traitName:gsub("Trait$", ""):gsub("(%l)(%u)", "%1 %2")
    return cleaned
end

-- ============================================================
-- Resolve trait description from global tables
-- Priority: god boons → hammer → chaos blessing → chaos curse → well item → keepsake
-- ============================================================
local function ResolveTraitDescription(traitName)
    if not traitName then return nil end
    -- God boon descriptions (global from AccessibleBoons)
    if GodBoonDescriptions and GodBoonDescriptions[traitName] then
        return GodBoonDescriptions[traitName]
    end
    -- Hammer descriptions (global from AccessibleBoons)
    if HammerDescriptions and HammerDescriptions[traitName] then
        return HammerDescriptions[traitName]
    end
    -- Chaos blessing descriptions (global from AccessibleBoons)
    if ChaosBlessingDescriptions and ChaosBlessingDescriptions[traitName] then
        return ChaosBlessingDescriptions[traitName]
    end
    -- Chaos curse descriptions (global from AccessibleBoons)
    if ChaosCurseDescriptions and ChaosCurseDescriptions[traitName] then
        return ChaosCurseDescriptions[traitName]
    end
    -- Well of Charon item descriptions (global from AccessibleWell)
    if WellItemDescriptions and WellItemDescriptions[traitName] then
        return WellItemDescriptions[traitName]
    end
    -- Keepsake descriptions (global from AccessibleKeepsakes, level-aware)
    local keepsakeDesc = GetKeepsakeDescription(traitName)
    if keepsakeDesc then
        return keepsakeDesc
    end
    return nil
end

-- ============================================================
-- Compute actual rarity/level-scaled values for a trait on the hero
-- Uses GetProcessedTraitData with FakeStackNum=1 to get OldTotal (= current values)
-- Filters out zero values to avoid "0, 0" speech
-- ============================================================
local function GetTraitCurrentValues(traitName)
    if not traitName or traitName == "" then return nil end
    if not CurrentRun or not CurrentRun.Hero or not CurrentRun.Hero.Traits then return nil end
    if not GetProcessedTraitData or not SetTraitTextData then return nil end

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

        -- OldTotal contains the current values
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
                -- Skip zero values to avoid meaningless "0" or "0, 0" in speech
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

    if ok and valStr then return valStr, structParts end
    return nil, nil
end

-- ============================================================
-- Get encounters remaining for temporary traits (Well items, Chaos curses)
-- Reads RemainingUses from the hero's actual trait instance
-- ============================================================
local function GetEncountersRemaining(traitData)
    if not traitData then return nil end

    -- Try reading directly from the trait data object (may be the hero trait itself)
    local remaining = traitData.RemainingUses
    local usesAsRooms = traitData.UsesAsRooms

    -- Fallback: search CurrentRun.Hero.Traits by name for the live instance
    if remaining == nil and traitData.Name then
        if CurrentRun and CurrentRun.Hero and CurrentRun.Hero.Traits then
            for _, heroTrait in ipairs(CurrentRun.Hero.Traits) do
                if heroTrait.Name == traitData.Name then
                    remaining = heroTrait.RemainingUses
                    usesAsRooms = heroTrait.UsesAsRooms
                    break
                end
            end
        end
    end

    -- Handle table form {BaseMin, BaseMax, AsInt} (safety for unresolved template data)
    if type(remaining) == "table" then
        remaining = remaining.BaseMin or remaining.BaseMax
    end

    if remaining and type(remaining) == "number" and remaining > 0 then
        local unit = usesAsRooms and "chambers" or "encounters"
        if remaining == 1 then
            unit = unit:gsub("s$", "")  -- singular
        end
        return tostring(remaining) .. " " .. unit .. " remaining"
    end
    return nil
end

-- ============================================================
-- Build speech text for a trait icon
-- ============================================================
local function BuildTraitTrayItemSpeech(traitData)
    if not traitData or not traitData.Name then return nil end

    local traitName = traitData.Name

    -- Special handling for God Mode trait -- show current damage resistance
    if traitName == "GodModeTrait" then
        local resistance = 20
        if GameState and GameState.EasyModeLevel and CalcEasyModeMultiplier then
            local ok, mult = pcall(CalcEasyModeMultiplier, GameState.EasyModeLevel)
            if ok and mult then
                resistance = math.floor((1.0 - mult) * 100 + 0.5)
            end
        end
        return "God Mode, " .. tostring(resistance) .. " percent damage resistance"
    end

    local parts = {}

    -- Determine trait category early (needed for god name logic)
    local isAspect = AspectDisplayNames[traitName] ~= nil
    local isKeepsake = KeepsakeDisplayNames[traitName] ~= nil
    local isHammer = traitData.Frame == "Hammer"
    local isChaos = traitData.Frame == "Chaos"
    local isChaosCurseItem = IsChaosCurse(traitName)
    local isChaosBlessItem = IsChaosBless(traitName)
    local isWellItem = IsWellItem(traitName)
    local isCompanion = traitData.Slot == "Companion" or traitData.Slot == "Assist"
    local isDuo = traitData.IsDuoBoon

    -- God name prefix for god boons (including duo boons)
    if not isAspect and not isKeepsake and not isHammer and not isCompanion and not isWellItem and not isChaosCurseItem and not isChaosBlessItem then
        local godName = GetGodForTrait(traitName)
        -- Also try traitData.God field as fallback
        if not godName and traitData.God then
            godName = traitData.God
        end
        if godName and godName ~= "" then
            parts[#parts + 1] = godName
        end
    end

    -- Resolve display name
    local displayName = ResolveTraitName(traitName)
    parts[#parts + 1] = displayName

    -- Rarity (if applicable — skip for aspects, keepsakes, well items, chaos curses/blessings)
    if not isAspect and not isKeepsake and not isWellItem and not isChaosCurseItem and not isChaosBlessItem then
        if traitData.Rarity and traitData.Rarity ~= "" then
            parts[#parts + 1] = traitData.Rarity
        end
    end

    -- Category label
    if isAspect then
        parts[#parts + 1] = "Weapon aspect"
    elseif isKeepsake and not isCompanion then
        parts[#parts + 1] = "Keepsake"
    elseif isCompanion then
        parts[#parts + 1] = "Companion"
    elseif isHammer then
        parts[#parts + 1] = "Hammer upgrade"
    elseif isChaosCurseItem then
        parts[#parts + 1] = "Chaos curse"
    elseif isChaosBlessItem or isChaos then
        parts[#parts + 1] = "Chaos boon"
    elseif isWellItem then
        parts[#parts + 1] = "Well of Charon"
    elseif isDuo then
        parts[#parts + 1] = "Duo"
    else
        -- Slot info (Attack, Special, Cast, Dash, Call)
        if traitData.Slot then
            local slotName = SlotDisplayNames[traitData.Slot] or traitData.Slot
            parts[#parts + 1] = slotName .. " boon"
        end
    end

    -- Level (stacked traits — skip for well items, chaos curses, keepsakes)
    if not isWellItem and not isChaosCurseItem and not isKeepsake then
        local ok, traitCount = pcall(function()
            if CurrentRun and CurrentRun.Hero then
                return GetTraitCount(CurrentRun.Hero, traitData)
            end
            return 0
        end)
        if ok and traitCount and traitCount > 1 then
            parts[#parts + 1] = "Level " .. traitCount
        end
    end

    -- Keepsake level
    if isKeepsake and not isCompanion and GetKeepsakeLevel then
        local ok, level = pcall(GetKeepsakeLevel, traitName)
        if ok and level and level > 0 then
            parts[#parts + 1] = "Level " .. level
        end
    end

    -- Build speech string with parts separated by commas
    -- God name gets a dash separator: "Zeus - Lightning Strike, Common, Attack boon"
    local speech = ""
    local godNameAdded = false
    for i, part in ipairs(parts) do
        if i == 1 then
            speech = part
            -- Check if we added a god name (it's the first part if present)
            local godName = GetGodForTrait(traitName) or (traitData.God or "")
            if godName ~= "" and part == godName and not isAspect and not isKeepsake and not isHammer and not isCompanion and not isWellItem and not isChaosCurseItem and not isChaosBlessItem then
                godNameAdded = true
            end
        elseif i == 2 and godNameAdded then
            speech = speech .. " - " .. part
        else
            speech = speech .. ", " .. part
        end
    end

    -- Description + computed values (substitute rarity-scaled values into description)
    local desc = ResolveTraitDescription(traitName)
    local descText = desc and StripFormatting(desc) or nil

    -- Computed rarity/level-scaled values (e.g. "80" for damage, "30%" for effect)
    -- Skip for aspects, keepsakes, hammer upgrades, companions, well items, and chaos curses
    local values, valueParts = nil, nil
    if not isAspect and not isKeepsake and not isHammer and not isCompanion and not isWellItem and not isChaosCurseItem then
        values, valueParts = GetTraitCurrentValues(traitName)
    end

    if descText and valueParts and #valueParts > 0 and _SubstituteDescriptionValues then
        local substituted, numReplaced = _SubstituteDescriptionValues(descText, valueParts)
        if numReplaced > 0 then
            speech = speech .. ". " .. substituted
        else
            speech = speech .. ". " .. descText
            if values then speech = speech .. ". " .. values end
        end
    elseif descText then
        speech = speech .. ". " .. descText
        if values then speech = speech .. ". " .. values end
    elseif values then
        speech = speech .. ". " .. values
    end

    -- Encounters remaining (Well items and Chaos curses)
    if isWellItem or isChaosCurseItem then
        local remaining = GetEncountersRemaining(traitData)
        if remaining then
            speech = speech .. ". " .. remaining
        end
    end

    return speech
end

-- ============================================================
-- OnMouseOver handler for trait tray icons
-- ============================================================
function AccessibleTraitTrayMouseOver(button)
    if not AccessibilityEnabled or not AccessibilityEnabled() then return end
    if not button or not button.TraitData then return end

    local speech = BuildTraitTrayItemSpeech(button.TraitData)
    if speech then
        _Log("[NAV] TraitTray: " .. speech)
        TolkSilence()
        TolkSpeak(speech)
    end
end

-- ============================================================
-- OnMouseOver handler for close button
-- ============================================================
function AccessibleTraitTrayCloseMouseOver(button)
    if not AccessibilityEnabled or not AccessibilityEnabled() then return end
    _Log("[NAV] TraitTray: Close")
    TolkSilence()
    TolkSpeak(UIStrings.Close)
end

-- ============================================================
-- Wrap ShowAdvancedTooltipScreen to add accessibility to trait icons
-- NOTE: baseFunc calls HandleScreenInput() which BLOCKS (yields) until screen closes.
-- Our accessibility setup must run as a separate thread that executes while
-- HandleScreenInput is yielded, after all icons have been created.
-- ============================================================
ModUtil.WrapBaseFunction("ShowAdvancedTooltipScreen", function(baseFunc, args)
    -- Start a thread to set up accessibility AFTER icons are created
    -- The thread will run when baseFunc yields at HandleScreenInput
    thread(function()
        wait(0.1)  -- Brief delay to ensure all icons are created

        if not AccessibilityEnabled or not AccessibilityEnabled() then return end
        if not ScreenAnchors or not ScreenAnchors.TraitTrayScreen then return end

        _Log("[SCREEN-OPEN] TraitTrayScreen")

        -- Count visible traits and add OnMouseOver to each icon
        local traitCount = 0
        local icons = ScreenAnchors.TraitTrayScreen.Icons
        if icons then
            for iconId, icon in pairs(icons) do
                if icon and icon.TraitData and not icon.TraitData.Hidden then
                    traitCount = traitCount + 1
                    icon.OnMouseOverFunctionName = "AccessibleTraitTrayMouseOver"
                    AttachLua({ Id = icon.Id, Table = icon })
                end
            end
        end

        -- Add OnMouseOver to close button
        local components = ScreenAnchors.TraitTrayScreen.Components
        if components and components.CloseButton then
            components.CloseButton.OnMouseOverFunctionName = "AccessibleTraitTrayCloseMouseOver"
            AttachLua({ Id = components.CloseButton.Id, Table = components.CloseButton })
        end

        -- Announce screen open with trait count
        if traitCount > 0 then
            local countWord = traitCount == 1 and UIStrings.Boon or UIStrings.Boons
            TolkSilence()
            TolkSpeak(string.format(UIStrings.BoonTrayFmt, traitCount, countWord))
        end
    end)

    baseFunc(args)  -- This blocks until screen closes (HandleScreenInput yields)
end)

-- ============================================================
-- Wrap SetupMetaIconTrayTooltip to store upgrade name on button
-- ============================================================
ModUtil.WrapBaseFunction("SetupMetaIconTrayTooltip", function(baseFunc, button, upgradeName, upgradeData, offsetX, args)
    baseFunc(button, upgradeName, upgradeData, offsetX, args)

    if not AccessibilityEnabled or not AccessibilityEnabled() then return end

    -- Store the upgrade name on the button for later lookup
    if button then
        button._accessUpgradeName = upgradeName
    end
end)

-- ============================================================
-- Wrap MouseOverMetaIconTray to speak Mirror/Pact upgrade info
-- ============================================================
ModUtil.WrapBaseFunction("MouseOverMetaIconTray", function(baseFunc, button)
    baseFunc(button)

    if not AccessibilityEnabled or not AccessibilityEnabled() then return end
    if not button then return end

    local upgradeName = button._accessUpgradeName
    if not upgradeName then return end

    local displayName = MetaUpgradeDisplayNames[upgradeName] or SafeGetDisplayName(upgradeName) or upgradeName

    -- Get level
    local level = 0
    local ok, result = pcall(function()
        return GetNumMetaUpgrades(upgradeName)
    end)
    if ok and result then
        level = result
    end

    local speech = displayName
    if level > 0 then
        speech = speech .. ", Level " .. level
    end

    -- Add description
    local desc = GetMetaUpgradeDescription(upgradeName, level)
    if desc then
        speech = speech .. ". " .. desc
    end

    _Log("[NAV] TraitTray Meta: " .. speech)
    TolkSilence()
    TolkSpeak(speech)
end)
