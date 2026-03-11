--[[
Mod: AccessibleBoons
Author: Accessibility Layer
Version: 13

Provides screen reader accessibility for the Boon selection screen (UpgradeChoice/BoonMenu).
- Speaks boon name, rarity, god name, slot, and DESCRIPTION when cursor moves between options
- Handles god boons, hammer (weapon) upgrades, Chaos boons, and consumables
- Includes hardcoded descriptions for ALL god boons (9 gods, ~130 boons) from Hades Wiki
- Includes hardcoded Daedalus Hammer descriptions for all 6 weapons (82 upgrades)
- Logs screen open, navigation, and boon selection events via LogEvent
- Includes Chaos blessing and curse descriptions
- God flavor text spoken when boon selection opens (e.g. "Zeus, God of Thunder...")
- Labels the Reroll (Fated Persuasion) button
- Adds OnMouseOverFunctionName + AttachLua to PurchaseButton1-5
- Speaks god flavor text + first boon on menu open
- Pom of Power: shows god name, actual level, and computed per-level values (old to new)
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

-- Safe wrapper for GetDisplayName — returns empty string on failure
local function SafeGetDisplayName(key)
    if not key or key == "" then return "" end
    local ok, result = pcall(GetDisplayName, { Text = key })
    if ok and result and result ~= "" then
        return StripFormatting(result)
    end
    return ""
end

-- Global helper: format a numeric boon value, preserving decimals when significant
function _FormatBoonValue(val, isPercent)
    local rounded = math.floor(val + 0.5)
    local display
    if math.abs(val - rounded) >= 0.05 then
        display = string.format("%.1f", val)
    else
        display = tostring(rounded)
    end
    if isPercent then display = display .. "%" end
    return display
end

-- Global helper: substitute computed rarity-scaled values into a hardcoded description
-- Replaces numbers in the description sequentially with computed values
-- Returns (modifiedDesc, numReplacements)
function _SubstituteDescriptionValues(desc, computedParts)
    if not desc or desc == "" or not computedParts or #computedParts == 0 then
        return desc, 0
    end
    local idx = 0
    local result = desc:gsub("(%d+%.?%d*)(%%?)", function(numStr, pctSign)
        idx = idx + 1
        if idx <= #computedParts then
            return computedParts[idx].display
        end
        return numStr .. pctSign
    end)
    return result, idx
end

-- Map god upgrade names to display names
GodDisplayNames = {
    ZeusUpgrade = "Zeus",
    PoseidonUpgrade = "Poseidon",
    AthenaUpgrade = "Athena",
    AphroditeUpgrade = "Aphrodite",
    AresUpgrade = "Ares",
    ArtemisUpgrade = "Artemis",
    DionysusUpgrade = "Dionysus",
    HermesUpgrade = "Hermes",
    DemeterUpgrade = "Demeter",
    TrialUpgrade = "Chaos",
    WeaponUpgrade = "Daedalus Hammer",
}

-- Duo boon god pairs — maps trait name to "God1, God2" for proper duo boon speech
DuoBoonGods = {
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

-- Map trait internal names to their actual display names
-- Needed because GetTraitTooltipTitle returns localization keys that GetDisplayName cannot resolve
BoonDisplayNames = {
    -- Zeus (14)
    ZeusWeaponTrait = "Lightning Strike",
    ZeusSecondaryTrait = "Thunder Flourish",
    ZeusRangedTrait = "Electric Shot",
    ZeusRushTrait = "Thunder Dash",
    ZeusShoutTrait = "Zeus' Aid",
    ZeusBoltAoETrait = "High Voltage",
    ZeusBonusBounceTrait = "Storm Lightning",
    ZeusBonusBoltTrait = "Double Strike",
    ZeusLightningDebuff = "Static Discharge",
    RetaliateWeaponTrait = "Heaven's Vengeance",
    SuperGenerationTrait = "Clouded Judgment",
    OnWrathDamageBuffTrait = "Billowing Strength",
    ZeusChargedBoltTrait = "Splitting Bolt",
    PerfectDashBoltTrait = "Lightning Reflexes",
    -- Poseidon (16)
    PoseidonWeaponTrait = "Tempest Strike",
    PoseidonSecondaryTrait = "Tempest Flourish",
    PoseidonRangedTrait = "Flood Shot",
    PoseidonRushTrait = "Tidal Dash",
    PoseidonShoutTrait = "Poseidon's Aid",
    SlipperyTrait = "Razor Shoals",
    SlamExplosionTrait = "Breaking Wave",
    BonusCollisionTrait = "Typhoon's Fury",
    BossDamageTrait = "Wave Pounding",
    RoomRewardBonusTrait = "Ocean's Bounty",
    RandomMinorLootDrop = "Sunken Treasure",
    PoseidonShoutDurationTrait = "Rip Current",
    DefensiveSuperGenerationTrait = "Boiling Point",
    EncounterStartOffenseBuffTrait = "Hydraulic Might",
    DoubleCollisionTrait = "Second Wave",
    FishingTrait = "Huge Catch",
    -- Athena (14)
    AthenaWeaponTrait = "Divine Strike",
    AthenaSecondaryTrait = "Divine Flourish",
    AthenaRangedTrait = "Phalanx Shot",
    AthenaRushTrait = "Divine Dash",
    AthenaShoutTrait = "Athena's Aid",
    EnemyDamageTrait = "Bronze Skin",
    AthenaBackstabDebuffTrait = "Blinding Flash",
    AthenaRetaliateTrait = "Holy Shield",
    AthenaShieldTrait = "Brilliant Riposte",
    TrapDamageTrait = "Sure Footing",
    PreloadSuperGenerationTrait = "Proud Bearing",
    LastStandHealTrait = "Last Stand",
    LastStandDurationTrait = "Deathless Stand",
    LastStandHealDrop = "Last Stand",
    LastStandDurationDrop = "Deathless Stand",
    ShieldHitTrait = "Divine Protection",
    -- Ares (14)
    AresWeaponTrait = "Curse of Agony",
    AresSecondaryTrait = "Curse of Pain",
    AresRangedTrait = "Slicing Shot",
    AresRushTrait = "Blade Dash",
    AresShoutTrait = "Ares' Aid",
    IncreasedDamageTrait = "Urge to Kill",
    AresAoETrait = "Black Metal",
    AresDragTrait = "Engulfing Vortex",
    AresLoadCurseTrait = "Dire Misfortune",
    AresLongCurseTrait = "Impending Doom",
    OnEnemyDeathDamageInstanceBuffTrait = "Battle Rage",
    AresRetaliateTrait = "Curse of Vengeance",
    LastStandDamageBonusTrait = "Blood Frenzy",
    AresCursedRiftTrait = "Vicious Cycle",
    -- Aphrodite (14)
    AphroditeWeaponTrait = "Heartbreak Strike",
    AphroditeSecondaryTrait = "Heartbreak Flourish",
    AphroditeRangedTrait = "Crush Shot",
    AphroditeRushTrait = "Passion Dash",
    AphroditeShoutTrait = "Aphrodite's Aid",
    AphroditeDurationTrait = "Empty Inside",
    AphroditePotencyTrait = "Broken Resolve",
    AphroditeRangedBonusTrait = "Blown Kiss",
    AphroditeWeakenTrait = "Sweet Surrender",
    AphroditeRetaliateTrait = "Wave of Despair",
    AphroditeDeathTrait = "Dying Lament",
    ProximityArmorTrait = "Different League",
    HealthRewardBonusTrait = "Life Affirmation",
    CharmTrait = "Unhealthy Fixation",
    -- Artemis (13)
    ArtemisWeaponTrait = "Deadly Strike",
    ArtemisSecondaryTrait = "Deadly Flourish",
    ArtemisRangedTrait = "True Shot",
    ArtemisRushTrait = "Hunter Dash",
    ArtemisShoutTrait = "Artemis' Aid",
    ArtemisCriticalTrait = "Clean Kill",
    CritBonusTrait = "Pressure Points",
    CriticalBufferMultiplierTrait = "Hide Breaker",
    ArtemisAmmoExitTrait = "Exit Wounds",
    CriticalSuperGenerationTrait = "Hunter Instinct",
    ArtemisSupportingFireTrait = "Support Fire",
    CritVulnerabilityTrait = "Hunter's Mark",
    MoreAmmoTrait = "Fully Loaded",
    -- Dionysus (14)
    DionysusWeaponTrait = "Drunken Strike",
    DionysusSecondaryTrait = "Drunken Flourish",
    DionysusRushTrait = "Drunken Dash",
    DionysusRangedTrait = "Trippy Shot",
    DionysusShoutTrait = "Dionysus' Aid",
    DionysusSlowTrait = "Numbing Sensation",
    DionysusSpreadTrait = "Peer Pressure",
    DionysusDefenseTrait = "High Tolerance",
    DionysusPoisonPowerTrait = "Bad Influence",
    DoorHealTrait = "After Party",
    LowHealthDefenseTrait = "Positive Outlook",
    DionysusGiftDrop = "Premium Vintage",
    FountainDamageBonusTrait = "Strong Drink",
    DionysusComboVulnerability = "Black Out",
    DionysusAoETrait = "Bad Medicine",
    -- Duo Boons (28)
    ImpactBoltTrait = "Sea Storm",
    ReboundingAthenaCastTrait = "Lightning Phalanx",
    AutoRetaliateTrait = "Vengeful Mood",
    LightningCloudTrait = "Scintillating Feast",
    AmmoBoltTrait = "Lightning Rod",
    RegeneratingCappedSuperTrait = "Smoldering Air",
    JoltDurationTrait = "Cold Fusion",
    StatusImmunityTrait = "Unshakable Mettle",
    PoseidonAresProjectileTrait = "Curse of Drowning",
    ArtemisBonusProjectileTrait = "Mirage Shot",
    RaritySuperBoost = "Exclusive Access",
    BlizzardOrbTrait = "Blizzard Shot",
    ImprovedPomTrait = "Sweet Nectar",
    CastBackstabTrait = "Parting Shot",
    ArtemisReflectBuffTrait = "Deadly Reversal",
    TriggerCurseTrait = "Merciful End",
    SlowProjectileTrait = "Calculated Risk",
    NoLastStandRegenerationTrait = "Stubborn Roots",
    CurseSickTrait = "Curse of Longing",
    AresHomingTrait = "Hunting Blades",
    PoisonTickRateTrait = "Curse of Nausea",
    StationaryRiftTrait = "Freezing Vortex",
    HeartsickCritDamageTrait = "Heart Rend",
    DionysusAphroditeStackIncreaseTrait = "Low Tolerance",
    SelfLaserTrait = "Cold Embrace",
    PoisonCritVulnerabilityTrait = "Splitting Headache",
    HomingLaserTrait = "Crystal Clarity",
    IceStrikeArrayTrait = "Ice Wine",
    DionysusNullifyProjectileTrait = "Smoke Screen",
    -- Hermes (16)
    HermesWeaponTrait = "Swift Strike",
    HermesSecondaryTrait = "Swift Flourish",
    BonusDashTrait = "Greatest Reflex",
    AmmoReclaimTrait = "Quick Reload",
    RapidCastTrait = "Flurry Cast",
    RushSpeedBoostTrait = "Hyper Sprint",
    MoveSpeedTrait = "Greater Haste",
    RushRallyTrait = "Quick Recovery",
    DodgeChanceTrait = "Greater Evasion",
    HermesShoutDodge = "Second Wind",
    AmmoReloadTrait = "Auto Reload",
    RegeneratingSuperTrait = "Quick Favor",
    ChamberGoldTrait = "Side Hustle",
    SpeedDamageTrait = "Rush Delivery",
    MagnetismTrait = "Greater Recall",
    UnstoredAmmoDamageTrait = "Bad News",
    -- Demeter (14)
    DemeterWeaponTrait = "Frost Strike",
    DemeterSecondaryTrait = "Frost Flourish",
    DemeterRangedTrait = "Crystal Beam",
    DemeterRushTrait = "Mistral Dash",
    DemeterShoutTrait = "Demeter's Aid",
    HealingPotencyTrait = "Nourished Soul",
    HealingPotencyDrop = "Nourished Soul",
    HarvestBoonDrop = "Rare Crop",
    FallbackMoneyDrop = "Spare Wealth",
    CastNovaTrait = "Snow Burst",
    ZeroAmmoBonusTrait = "Ravenous Will",
    MaximumChillBlast = "Arctic Blast",
    MaximumChillBonusSlow = "Killing Freeze",
    DemeterRangedBonusTrait = "Glacial Glare",
    DemeterRetaliateTrait = "Frozen Touch",
    InstantChillKill = "Winter Harvest",
}

-- God flavor text fallbacks (used only if CreateTextBox capture fails)
-- Sourced from HelpText.en.sjson (the game's actual localization file)
GodFlavorText = {
    ZeusUpgrade = "Zeus. The lord and master of all Olympus, and the heavens themselves.",
    PoseidonUpgrade = "Poseidon. The seas and all the surface of the earth bend to his every whim.",
    AthenaUpgrade = "Athena. Behold, the peerless defenses of the gray-eyed goddess.",
    AphroditeUpgrade = "Aphrodite. The most radiant of the Olympians holds mortal beings in her thrall.",
    AresUpgrade = "Ares. Some call him death to men, such is his murderous intent.",
    ArtemisUpgrade = "Artemis. The virgin goddess of the hunt has never known an equal.",
    DionysusUpgrade = "Dionysus. It turns out that the simpler things in life have a commanding influence.",
    HermesUpgrade = "Hermes. No mortal has ever approached the surpassing swiftness of the messenger of the gods.",
    DemeterUpgrade = "Demeter. The cycle of the seasons brings death and renewal, on the whims of a mighty goddess.",
    TrialUpgrade = "Chaos. Before the world existed, there was nothing but a vast and conscious void, which still remains.",
    WeaponUpgrade = "Daedalus Hammer. The master artisan discarded his own tools once his fell work for Hades was complete.",
    StackUpgrade = "Pom of Power. A taste of but a single pomegranate seed holds power in the Underworld.",
    StackUpgradeRare = "Enhanced Pom of Power. A taste of but a single pomegranate seed holds power in the Underworld.",
    HarvestBoonDrop = "Chaos Harvest. The primordial void offers additional blessings from its vast expanse.",
}

-- Capture the exact flavor text the game chose via CreateTextBox interception
-- The game calls CreateTextBox with a _FlavorText key BEFORE CreateBoonLootButtons,
-- so by the time our CreateBoonLootButtons wrapper runs, this will hold the game's exact choice
_capturedFlavorText = nil

ModUtil.WrapBaseFunction("CreateTextBox", function(baseFunc, args)
    if args and args.Text and type(args.Text) == "string" then
        if args.Text:find("_FlavorText", 1, true) then
            -- Resolve the localization key to actual display text right now
            local ok, displayText = pcall(GetDisplayName, { Text = args.Text })
            if ok and displayText and displayText ~= "" then
                displayText = StripFormatting(displayText)
                if displayText ~= "" then
                    _capturedFlavorText = displayText
                end
            end
        end
    end
    return baseFunc(args)
end)

-- Map slot names to readable descriptions
SlotDescriptions = {
    Melee = "Attack boon",
    Secondary = "Special boon",
    Ranged = "Cast boon",
    Rush = "Dash boon",
    Shout = "Call boon",
}

-- ============================================================
-- Daedalus Hammer upgrade descriptions (all 6 weapons, 82 upgrades)
-- Keys are REAL trait names from LootData.lua/TraitData.lua
-- Descriptions sourced from Hades Wiki
-- ============================================================
HammerDescriptions = {
    SwordHealthBufferDamageTrait = "Your Attack deals +300% damage to Armor",
    SwordCriticalTrait = "Your Thrust deals +200% damage and has a +200% Critical chance",
    SwordCursedLifeStealTrait = "Your Attack restores 2 per hit, but you have -60%",
    SwordBlinkTrait = "Your Special makes you lunge ahead, then become Sturdy for -30% Sec",
    SwordDoubleDashAttackTrait = "Your Dash-Strike hits twice and deals +20% damage",
    SwordSecondaryDoubleAttackTrait = "Your Special hits twice, but no longer knocks foes away",
    SwordTwoComboTrait = "Hold Attack to strike rapidly, dealing 25 base damage per hit",
    SwordGoldDamageTrait = "Your Attack deals bonus damage equal to 5% of your current Obols",
    SwordThrustWaveTrait = "Your Attack fires a wave that pierces foes, dealing 30 damage",
    SwordBackstabTrait = "Your Attack deals +200% damage striking foes from behind",
    SwordSecondaryAreaDamageTrait = "Your Special hits a wider area and deals +20% damage",
    SwordHeavySecondStrikeTrait = "Your Attack is replaced with a big chop that deals 90 base damage",
    SwordConsecrationBoostTrait = "Your Holy Excalibur aura is 45% larger and makes foes 10% slower",
    BowDoubleShotTrait = "Your Attack fires 2 shots side-by-side, but has reduced range",
    BowLongRangeDamageTrait = "Your Attack deals +200% damage to distant foes",
    BowSlowChargeDamageTrait = "Your Attack deals +300% damage in an area, but charges up slower",
    BowTapFireTrait = "Hold Attack to shoot rapidly, but you cannot Power Shot",
    BowPenetrationTrait = "Your Special pierces foes and deals +400% damage to Armor",
    BowPowerShotTrait = "Your Power Shot is easier to execute and deals +150% damage",
    BowSecondaryBarrageTrait = "Your Special shoots 4 additional shots",
    BowTripleShotTrait = "Your Attack fires 3 shots in a spread pattern",
    BowSecondaryFocusedFireTrait = "Hold Special for up to 250% base damage with reduced minimum range",
    BowChainShotTrait = "Your Attack bounces to up to 3 foes, dealing +15% damage for each",
    BowCloseAttackTrait = "Your Attack deals +150% damage to nearby foes",
    BowConsecutiveBarrageTrait = "Your Special deals +3 base damage for each consecutive hit to a foe",
    BowBondBoostTrait = "Your Celestial Sharanga Attack creates a Blast Wave around you",
    SpearReachAttack = "Your Attack has more range and deals +40% damage to distant foes",
    SpearThrowBounce = "Your Special bounces to up to 7 foes, dealing +30% damage for each",
    SpearThrowPenetrate = "Your Special deals +400% damage to Armor",
    SpearThrowCritical = "Your Special deals +50% damage; 50% Critical chance on recovery",
    SpearThrowExplode = "Your Special is replaced with a shot that deals 50 damage in an area",
    SpearSpinDamageRadius = "Your Spin Attack deals +125% damage and hits a larger area",
    SpearSpinChargeLevelTime = "Your Spin Attack charges up and recovers much faster",
    SpearAutoAttack = "Hold Attack to strike rapidly, but you cannot Spin Attack",
    SpearThrowElectiveCharge = "Hold Special to charge your skewer for up to +200% base damage",
    SpearDashMultiStrike = "Your Dash-Strike hits 3 times, but your dash has -25% range",
    SpearSpinChargeAreaDamageTrait = "Charging your Spin Attack makes you Sturdy and pulses 40 damage",
    SpearAttackPhalanxTrait = "Your Attack strikes 3 times in a spread pattern",
    SpearSpinTravelDurationTrait = "Your Frost Fair Blade Spin Attack travels for 80% longer",
    ShieldThrowFastTrait = "Your Special can strike up to 4 additional foes before returning",
    ShieldChargeSpeedTrait = "Your Bull Rush charges up faster",
    ShieldBashDamageTrait = "Your Attack hits twice, but does not knock foes away",
    ShieldDashAOETrait = "Your Dash-Strike deals +50% damage in a larger area",
    ShieldThrowCatchExplode = "Your Special deals 50 damage to nearby foes when you catch it",
    ShieldPerfectRushTrait = "Your Bull Rush gains a Power Rush that deals +500% damage",
    ShieldChargeHealthBufferTrait = "Your Bull Rush deals +400% damage to Armor",
    ShieldRushProjectileTrait = "Your Bull Rush instead fires a piercing shot that deals 80 base damage",
    ShieldThrowElectiveCharge = "Hold Special to charge your throw for up to +200% base damage",
    ShieldThrowEmpowerTrait = "After your Special hits, your next 2 Attacks deal +80% damage",
    ShieldThrowRushTrait = "During your Dash, your Special is faster and deals +200% damage",
    ShieldBlockEmpowerTrait = "After blocking a foe, gain +20% damage and move speed for 10 seconds",
    ShieldLoadAmmoBoostTrait = "After using your Naegling's Board Cast, you are Sturdy for 30% Sec",
    GunMinigunTrait = "Your Attack is faster and more accurate, and you gain +6 ammo capacity",
    GunChainShotTrait = "Your Attack bounces to 1 additional nearby foe",
    GunShotgunTrait = "Your Attack becomes a short spread that deals 40 base damage, lose 6 ammo capacity",
    GunExplodingSecondaryTrait = "Your Attack deals damage in an area and briefly slows foes",
    GunInfiniteAmmoTrait = "Your Attack is a 3-round burst; you never have to Reload",
    GunArmorPenerationTrait = "Your Attack pierces foes and deals +50% damage to Armor",
    GunHomingBulletTrait = "Your Attack seeks the nearest foe and deals +10% damage",
    GunGrenadeFastTrait = "You can use your Special 3 times in rapid succession",
    GunGrenadeDropTrait = "Your Special is replaced with a rocket that deals 80 base damage",
    GunSlowGrenade = "Foes targeted by your Special move slower and take +30% damage",
    GunHeavyBulletTrait = "Your Attack deals damage in an area and briefly slows foes",
    GunGrenadeClusterTrait = "Your Special fires a spread of 5 bombs, but each deals -30% damage",
    GunLoadedGrenadeBoostTrait = "Your Igneus Eden beam ramps up damage to foes faster",
    GunLoadedGrenadeLaserTrait = "Your Igneus Eden beam fires 50% faster with 15% more range",
    GunLoadedGrenadeWideTrait = "Your Igneus Eden fires 3 beams in a spread pattern",
    GunLoadedGrenadeInfiniteAmmoTrait = "Your Igneus Eden Attack has ∞, but its damage no longer ramps",
    GunLoadedGrenadeSpeedTrait = "Your Igneus Eden Special radiates +250% damage in a larger area",
    FistDashAttackHealthBufferTrait = "Your Dash-Strike pierces foes and deals +900% damage to Armor",
    FistAttackFinisherTrait = "Your Dash-Strike deals +60% damage; added to Attack sequence",
    FistReachAttackTrait = "Your Attack has more range and deals +10% damage",
    FistKillTrait = "Whenever your Special slays foes, restore 2%",
    FistConsecutiveAttackTrait = "Your Attack deals +5 base damage for each uninterrupted hit to a foe",
    FistDoubleDashSpecialTrait = "Your Dash-Upper deals +100% damage in an area",
    FistChargeSpecialTrait = "Hold Special for longer range and up to +100% base damage",
    FistTeleportSpecialTrait = "Your Special becomes an advancing kick that also deals 40 base damage twice",
    FistSpecialLandTrait = "After using your Special, deal 90 damage in an area where you land",
    FistSpecialFireballTrait = "Your Special becomes a charged ranged attack that deals 50 base damage",
    FistHeavyAttackTrait = "Your Attack becomes a slower 3-hit sequence, each dealing 40 base damage",
    FistAttackDefenseTrait = "While using your Attack or Special, you are Sturdy",
    FistDetonateBoostTrait = "Maim-afflicted foes take +25% damage and move 30% slower",
}

-- ============================================================
-- Chaos Blessing descriptions (what the blessing grants after curse expires)
-- Keys are REAL trait names from LootData.lua
-- ============================================================
ChaosBlessingDescriptions = {
    ChaosBlessingMoneyTrait = "Afterward, any Obols you find is worth +30%",
    ChaosBlessingBackstabTrait = "Afterward, you deal +60% damage striking foes from behind",
    ChaosBlessingAlphaStrikeTrait = "Afterward, you deal +30% damage striking undamaged foes",
    ChaosBlessingMetapointTrait = "Afterward, any Darkness you find is worth +50%",
    ChaosBlessingBoonRarityTrait = "Afterward, Boons have 11% chance to be Rare or better",
    ChaosBlessingSecondaryTrait = "Afterward, your Special deals +30% damage",
    ChaosBlessingAmmoTrait = "Afterward, gain +1 Bloodstones",
    ChaosBlessingDashAttackTrait = "Afterward, your Dash-Strike deals +40% damage",
    ChaosBlessingRangedTrait = "Afterward, your Cast deals +30% damage",
    ChaosBlessingMaxHealthTrait = "Afterward, gain +30 Max Health",
    ChaosBlessingMeleeTrait = "Afterward, your Attack deals +30% damage",
    ChaosBlessingExtraChanceTrait = "Afterward, gain +1 use of Death Defiance (this escape attempt)",
}

-- Chaos Curse descriptions (the penalty during the curse duration)
-- Keys are REAL trait names from LootData.lua
ChaosCurseDescriptions = {
    ChaosCurseTrapDamageTrait = "Take 300% more damage from traps",
    ChaosCurseCastAttackTrait = "Each Cast deals 3 self-damage",
    ChaosCurseHealthTrait = "Your max Health is reduced by 25",
    ChaosCurseDeathWeaponTrait = "Slain foes toss bombs at you",
    ChaosCurseHiddenRoomReward = "Chamber rewards are hidden",
    ChaosCurseDamageTrait = "Take 20% more damage from all sources",
    ChaosCurseSecondaryAttackTrait = "Each Special deals 3 self-damage",
    ChaosCurseDashRangeTrait = "Your Dash range is reduced by 20%",
    ChaosCursePrimaryAttackTrait = "Each Attack deals 3 self-damage",
    ChaosCurseNoMoneyTrait = "Cannot earn Obols",
    ChaosCurseSpawnTrait = "Face 30% more foes in encounters",
    ChaosCurseAmmoUseDelayTrait = "Cannot collect Cast ammo for 10 seconds",
    ChaosCurseMoveSpeedTrait = "Your movement speed is reduced by 40%",
}

-- ============================================================
-- God Boon descriptions (all 9 Olympian gods)
-- Keys are REAL trait names from TraitData.lua
-- Descriptions sourced from Hades Fextralife Wiki
-- ============================================================
GodBoonDescriptions = {
    ZeusWeaponTrait = "Your Attack emits chain-lightning when you damage a foe, dealing 10 lightning damage",
    ZeusSecondaryTrait = "Your Special causes a lightning bolt to strike nearby foes, dealing 30 lightning damage",
    ZeusRangedTrait = "Your Cast is a burst of chain-lightning that bounces between foes, dealing 60 damage",
    ZeusRushTrait = "Your Dash causes a lightning bolt to strike nearby foes, dealing 10 lightning damage",
    ZeusShoutTrait = "Your Call makes lightning strike nearby foes repeatedly for 1.5 Sec, dealing 50 damage per bolt",
    ZeusBoltAoETrait = "Your lightning bolt effects deal damage in a 60% larger area",
    ZeusBonusBounceTrait = "Your chain-lightning effects bounce 2 more times before expiring",
    ZeusBonusBoltTrait = "Your lightning bolt effects have a 25% chance to strike twice",
    ZeusLightningDebuff = "Your lightning effects also make foes Jolted, dealing 60 damage on their next attack",
    RetaliateWeaponTrait = "After you take damage, your foe is struck by lightning for 80 damage",
    SuperGenerationTrait = "Your God Gauge charges 10% faster when you deal or take damage",
    OnWrathDamageBuffTrait = "After using Call, you deal 20% more damage for 15 Sec",
    ZeusChargedBoltTrait = "All your lightning effects create an additional burst dealing 40 lightning damage",
    PerfectDashBoltTrait = "After you Dash just before getting hit, a bolt strikes nearby foes for 20 damage",
    PoseidonWeaponTrait = "Your Attack deals 30% more damage and knocks foes away",
    PoseidonSecondaryTrait = "Your Special deals 70% more damage and knocks foes away",
    PoseidonRangedTrait = "Your Cast deals 60 damage in an area and knocks foes away",
    PoseidonRushTrait = "Your Dash deals 35 damage in an area and knocks foes away",
    PoseidonShoutTrait = "Your Call makes you surge into foes for 250 damage while Impervious for 1.2 Sec",
    SlipperyTrait = "Using knock-away effects also Rupture foes for 10 damage",
    SlamExplosionTrait = "Slamming foes into walls or corners creates a watery blast dealing 200% more slam damage",
    BonusCollisionTrait = "You deal more damage when slamming foes into barriers",
    BossDamageTrait = "Your boons with Knock-Away effects deal 20% bonus damage to bosses",
    RoomRewardBonusTrait = "Any Gemstone, Darkness or Obols chamber rewards are worth 50% more",
    RandomMinorLootDrop = "Gain a random assortment of Gems, Darkness, Obols, and Health Restore",
    PoseidonShoutDurationTrait = "Your Call pulls in foes and the effect lasts 1 Sec longer",
    DefensiveSuperGenerationTrait = "Your God Gauge charges 40% faster when you take damage",
    EncounterStartOffenseBuffTrait = "Your Attack and Special are 50% stronger the first 10 Sec in Encounters",
    DoubleCollisionTrait = "Your Boons with knock-away effects shove foes multiple times. Bonus Knock-Away Effects: +1",
    FishingTrait = "You have a greater chance to find a Fishing Point in each Chamber. Fish Spawn Chance: +20%",
    AthenaWeaponTrait = "Your Attack is 40% stronger, and can Deflect",
    AthenaSecondaryTrait = "Your Special is 60% stronger, and can Deflect",
    AthenaRangedTrait = "Your Cast deals 85 damage in a small area, and can Deflect",
    AthenaRushTrait = "Your Dash deals 10 damage and can Deflect",
    AthenaShoutTrait = "Your Call makes you Invulnerable for 1.5 Sec and Deflect all attacks",
    EnemyDamageTrait = "Resist 5% damage from foes' attacks",
    AthenaBackstabDebuffTrait = "Your abilities that can Deflect also make foes Exposed for 5 Sec, taking 50% more backstab damage",
    AthenaRetaliateTrait = "After you take damage, deal 30 damage to nearby foes and briefly Deflect",
    AthenaShieldTrait = "When you Deflect attacks, they deal 80% more damage",
    TrapDamageTrait = "Resist 60% damage from Traps",
    PreloadSuperGenerationTrait = "You begin each Encounter with your God Gauge 20% full",
    LastStandHealTrait = "Extra Chance restores more Health than usual. Replenish 1 use. Bonus Restoration: 10%",
    LastStandDurationTrait = "Extra Chance makes you Invulnerable longer. Replenish 1 use. Effect Duration: 2 Sec.",
    LastStandHealDrop = "Extra Chance restores more Health than usual. Replenish 1 use. Bonus Restoration: 10%",
    LastStandDurationDrop = "Extra Chance makes you Invulnerable longer. Replenish 1 use. Effect Duration: 2 Sec.",
    ShieldHitTrait = "You have a barrier that negates incoming damage, with a 20 Sec cooldown",
    AresWeaponTrait = "Your Attack inflicts Doom dealing 50 damage",
    AresSecondaryTrait = "Your Special inflicts Doom dealing 60 damage",
    AresRangedTrait = "Your Cast sends a Blade Rift hurling ahead, dealing 20 damage per hit",
    AresRushTrait = "Your Dash creates a Blade Rift where you started, dealing 10 damage per hit",
    AresShoutTrait = "Your Call turns you into an Impervious Blade Rift for 1.2 Sec, dealing 30 damage per hit",
    IncreasedDamageTrait = "Your Attack, Special, and Cast deal 10% more damage",
    AresAoETrait = "Your Blade Rift powers deal damage in a 20% wider area",
    AresDragTrait = "Your Blade Rift effects last 0.2 Sec longer and pull foes in",
    AresLoadCurseTrait = "Your Doom effects deal 10 bonus damage when applied multiple times",
    AresLongCurseTrait = "Your Doom effects deal 60% more damage, after +0.5 Sec",
    OnEnemyDeathDamageInstanceBuffTrait = "After slaying a foe, your next Attack or Special deals 100% more damage",
    AresRetaliateTrait = "After you take damage, inflict Doom on surrounding foes dealing 100 damage",
    LastStandDamageBonusTrait = "After using Death Defiance, deal 15% more damage that encounter",
    AresCursedRiftTrait = "Your Blade Rift effects deal 2 more damage for each consecutive hit",
    AphroditeWeaponTrait = "Your Attack deals 50% more damage and inflicts Weak",
    AphroditeSecondaryTrait = "Your Special deals 80% more damage and inflicts Weak",
    AphroditeRangedTrait = "Your Cast is a wide, short-range blast dealing 90 damage that inflicts Weak",
    AphroditeRushTrait = "Your Dash deals 20 damage where you end up, inflicting Weak",
    AphroditeShoutTrait = "Your Call fires a seeking projectile that Charms foes for 5 Sec",
    AphroditeDurationTrait = "Your Weak effects last 5 Sec longer",
    AphroditePotencyTrait = "Weak-afflicted foes take 10% more damage",
    AphroditeRangedBonusTrait = "Your Cast shoots farther and deals 50% more damage against undamaged foes",
    AphroditeWeakenTrait = "Weak-afflicted foes are also 10% more susceptible to damage",
    AphroditeRetaliateTrait = "After you take damage, deal 50 damage to nearby foes and inflict Weak",
    AphroditeDeathTrait = "When foes are slain, they deal 40 damage to nearby foes and inflict Weak",
    ProximityArmorTrait = "Resist 10% damage from nearby foes' attacks",
    HealthRewardBonusTrait = "Any Health chamber rewards are 30% more effective",
    CharmTrait = "Your Weak effects also have a 15% chance to Charm foes",
    ArtemisWeaponTrait = "Your Attack is 20% stronger, with a chance to deal Critical damage",
    ArtemisSecondaryTrait = "Your Special is 40% stronger, with a chance to deal Critical damage",
    ArtemisRangedTrait = "Your Cast seeks foes dealing 70 damage, with a chance to deal Critical damage",
    ArtemisRushTrait = "Your Dash-Strike deals 50% more damage",
    ArtemisShoutTrait = "Your Call fires a seeking arrow dealing 100 damage with a Critical chance",
    ArtemisCriticalTrait = "Your Critical strikes deal 15% more damage",
    CritBonusTrait = "Any damage you deal has a 2% chance to be Critical",
    CriticalBufferMultiplierTrait = "Your Critical effects deal 200% more damage to Armor",
    ArtemisAmmoExitTrait = "Your foes take 100 damage when your Cast stuck in them is dislodged",
    CriticalSuperGenerationTrait = "Your God Gauge charges 0.25% faster when you deal Critical damage",
    ArtemisSupportingFireTrait = "After you hit with an Attack, Cast or Special, fire a seeking arrow dealing 10 damage",
    CritVulnerabilityTrait = "After you deal Critical damage to a foe, a foe near it is Marked with 30% bonus Critical chance",
    MoreAmmoTrait = "Gain 2 extra ammo for your Cast",
    DionysusWeaponTrait = "Your Attack inflicts Hangover dealing 4 damage per tick",
    DionysusSecondaryTrait = "Your Special inflicts Hangover dealing 5 damage per tick",
    DionysusRushTrait = "Your Dash inflicts foes near you with Hangover dealing 2 damage per tick",
    DionysusRangedTrait = "Your Cast lobs a projectile that bursts into Festive Fog dealing 100 damage",
    DionysusShoutTrait = "Your Call inflicts Hangover dealing 15 damage per tick to foes around you for 1.5 Sec",
    DionysusSlowTrait = "Your Hangover effects also make foes 15% slower",
    DionysusSpreadTrait = "Hangover-afflicted foes contaminate other nearby foes every 4 Sec with Hangover",
    DionysusDefenseTrait = "Take 10% less damage while standing in Festive Fog",
    DionysusPoisonPowerTrait = "Deal 50% more damage while 3 foes are Hangover-afflicted",
    DoorHealTrait = "If your Health is low after Encounters, restore it to the threshold. Life Threshold: 50%",
    LowHealthDefenseTrait = "Take 10% less damage while at 40% Health or below",
    DionysusGiftDrop = "Gain Health when you pick up Nectar. Receive 1 Nectar now. Nectar Life Gain: +20 Health",
    FountainDamageBonusTrait = "Using a Fountain restores all Health and gives you 3% bonus damage",
    DionysusComboVulnerability = "Hangover-afflicted foes take 60% bonus damage in Festive Fog",
    HermesWeaponTrait = "Your Attack is faster. Attack Speed: 30%",
    HermesSecondaryTrait = "Your Special is faster. Special Speed: 10%",
    BonusDashTrait = "You can Dash 1 more time in a row",
    AmmoReclaimTrait = "Foes drop Cast Ammo stuck in them within 5 Sec",
    RapidCastTrait = "Your Cast is 20% faster and fully automatic",
    RushSpeedBoostTrait = "After you Dash, become Sturdy and run faster for 0.5 Sec",
    MoveSpeedTrait = "You move 20% faster",
    RushRallyTrait = "After you take damage, quickly Dash to recover 30% of Health that was lost",
    DodgeChanceTrait = "You have a 10% bigger chance to Dodge",
    HermesShoutDodge = "After using Call, gain 30% Dodge chance and move speed for 6 Sec",
    AmmoReloadTrait = "Your Cast Ammo regenerates every 2.75 Sec",
    RegeneratingSuperTrait = "Your God Gauge charges up automatically. Auto Gauge Gain: +1% (every 1 Sec.)",
    ChamberGoldTrait = "Each time you enter a Chamber, gain 10 Obols",
    SpeedDamageTrait = "You deal bonus damage based on any bonus move speed. Bonus Damage From Bonus Speed: 50%",
    MagnetismTrait = "Your Bloodstones return to you automatically. Bloodstone Return Delay: 0 Sec",
    UnstoredAmmoDamageTrait = "Your Cast deals bonus damage to foes without Bloodstones in them. First-Shot Damage: +50%",
    DemeterWeaponTrait = "Your Attack is 40% stronger and inflicts Chill",
    DemeterSecondaryTrait = "Your Special is 60% stronger and inflicts Chill",
    DemeterRangedTrait = "Your Cast drops a crystal that fires a beam dealing 8 damage every 0.2 Sec for 5 Sec",
    DemeterRushTrait = "Your Dash shoots a gust ahead dealing 15 damage that inflicts Chill",
    DemeterShoutTrait = "Your Call creates a winter vortex for 5 Sec, dealing 10 damage every 0.25 Sec and inflicting Chill",
    HealingPotencyTrait = "Any Health Restore effects are more potent. Restore some Health now. Bonus Restoration: 30%",
    HealingPotencyDrop = "Any Health Restore effects are more potent. Restore some Health now. Bonus Restoration: 30%",
    HarvestBoonDrop = "Your God Boons become Common, then gain Rarity every 3 Encounters. Random God Boons Affected: 1",
    FallbackMoneyDrop = "Gain Obols to spend as desired",
    CastNovaTrait = "Whenever you Cast, deal 40 damage to nearby foes and inflict Chill",
    ZeroAmmoBonusTrait = "While you have no Cast, take less damage and deal 10% more",
    MaximumChillBlast = "Applying 10 stacks of Chill causes a blast dealing 80 damage, clearing the effect",
    MaximumChillBonusSlow = "Applying Chill to all enemies causes them to Slow by 10% and Decay",
    DemeterRangedBonusTrait = "Your Cast fires 2 Sec longer and inflicts Chill",
    DemeterRetaliateTrait = "After you take damage, deal 10 damage and completely Chill your foe",
    InstantChillKill = "Chill-afflicted foes shatter at 10%, inflicting Chill nearby. Shatter Area Damage: 50",
    DionysusAoETrait = "Your Hangover effects deal bonus damage",
    -- Duo Boons (28)
    ImpactBoltTrait = "Your knock-away effects also cause lightning strikes",
    ReboundingAthenaCastTrait = "Your Phalanx Shot Cast bounces between nearby foes",
    AutoRetaliateTrait = "Your Revenge effects sometimes activate without taking damage",
    LightningCloudTrait = "Your Festive Fog effects also deal lightning damage periodically",
    AmmoBoltTrait = "Your collectible Cast Ammo strike nearby foes with lightning periodically",
    RegeneratingCappedSuperTrait = "Your God Gauge charges up automatically, but is capped at 25 percent",
    JoltDurationTrait = "Your Jolted effects do not expire when foes attack",
    StatusImmunityTrait = "You cannot be stunned, and resist some damage from Bosses",
    PoseidonAresProjectileTrait = "Your Flood Shot becomes a pulse that damages foes around you",
    ArtemisBonusProjectileTrait = "Your Cast fires a second projectile, dealing reduced damage",
    RaritySuperBoost = "Any boons you find have at least Epic rarity",
    BlizzardOrbTrait = "Your Cast moves slowly, piercing foes and firing shards around it",
    ImprovedPomTrait = "Any Poms of Power you find are more potent",
    CastBackstabTrait = "Your Cast gains any bonuses you have for striking foes from behind",
    ArtemisReflectBuffTrait = "After you Deflect, briefly gain a chance to deal Critical damage",
    TriggerCurseTrait = "Your abilities that can Deflect immediately activate Doom effects",
    SlowProjectileTrait = "Your foes' ranged-attack projectiles are slower",
    NoLastStandRegenerationTrait = "If you have no Death Defiance, your Health slowly recovers",
    CurseSickTrait = "Your Doom effects continuously strike Weak foes",
    AresHomingTrait = "Your Cast creates a Blade Rift that seeks the nearest foe",
    PoisonTickRateTrait = "Your Hangover effects deal damage faster",
    StationaryRiftTrait = "Your Cast inflicts Chill, but your Blade Rift is smaller and moves slower",
    HeartsickCritDamageTrait = "Your Critical effects deal even more damage to Weak foes",
    DionysusAphroditeStackIncreaseTrait = "Your Hangover effects can stack more times against Weak foes",
    SelfLaserTrait = "Your Cast crystal fires its beam directly at you for longer, dealing bonus damage",
    PoisonCritVulnerabilityTrait = "Hangover-afflicted foes are more likely to take Critical damage",
    HomingLaserTrait = "Your Cast beam is stronger and tracks foes more effectively",
    IceStrikeArrayTrait = "Your Cast blasts an area with freezing Festive Fog that inflicts Chill",
    DionysusNullifyProjectileTrait = "Your Festive Fog blocks most foes' ranged attacks, but is smaller",
    DionysusComboVulnerability = "Hangover-afflicted foes take bonus damage in your Festive Fog",
}

-- Try to get boon description via GetTraitTooltip (game function with variable substitution)
local function SafeGetTraitDescription(traitData)
    if not traitData then return "" end
    if GetTraitTooltip then
        local ok, descKey = pcall(GetTraitTooltip, traitData, {})
        if ok and descKey and descKey ~= "" then
            local descText = SafeGetDisplayName(descKey)
            if descText ~= "" then
                return descText
            end
        end
    end
    return ""
end

-- Build speech for a standard boon/trait or hammer upgrade
local function BuildTraitSpeech(button)
    local upgradeData = button.Data
    local speech = ""

    -- Get god/source name
    -- For duo boons, show both gods (e.g. "Zeus, Demeter")
    local godName = ""
    if upgradeData.IsDuoBoon and upgradeData.Name and DuoBoonGods[upgradeData.Name] then
        godName = DuoBoonGods[upgradeData.Name]
    else
        godName = GodDisplayNames[button.UpgradeName] or ""
    end
    -- For Pom of Power, UpgradeName is "StackUpgrade" which has no god name entry
    -- Try to get god name from the trait data instead
    if godName == "" and upgradeData.God then
        godName = upgradeData.God
    end
    -- Fallback: use game's GetLootSourceName to find which god owns this trait
    if godName == "" and upgradeData.Name and GetLootSourceName then
        local ok, lootSource = pcall(GetLootSourceName, upgradeData.Name)
        if ok and lootSource and lootSource ~= false then
            godName = GodDisplayNames[lootSource] or lootSource
        end
    end
    if godName ~= "" then
        speech = godName .. " - "
    end

    -- Get boon name — try hardcoded table first (GetTraitTooltipTitle returns unresolvable keys)
    local boonName = ""
    if upgradeData.Name then
        boonName = BoonDisplayNames[upgradeData.Name] or ""
    end
    -- Fallback: try GetTraitTooltipTitle → GetDisplayName (works for some traits)
    if boonName == "" and GetTraitTooltipTitle then
        local ok, titleKey = pcall(GetTraitTooltipTitle, upgradeData)
        if ok and titleKey and titleKey ~= "" then
            local titleText = SafeGetDisplayName(titleKey)
            if titleText ~= "" then
                boonName = titleText
            end
        end
    end
    -- Last fallback: try GetDisplayName on the trait Name itself
    if boonName == "" and upgradeData.Name then
        local dn = SafeGetDisplayName(upgradeData.Name)
        if dn ~= "" then
            boonName = dn
        else
            boonName = upgradeData.Name
        end
    end
    speech = speech .. boonName

    -- Check if this is a Pom of Power level-up (need to know before rarity lookup)
    -- Note: OldLevel/NewLevel are set on tooltipData in UpgradeChoice.lua, NOT on button.Data (upgradeData)
    -- So we detect Pom via button.LootData.StackOnly and compute levels ourselves
    local isPom = button.LootData and button.LootData.StackOnly

    -- Add rarity
    -- For Pom of Power, upgradeData.Rarity is the base/template rarity (usually "Common"),
    -- not the actual rarity of the player's equipped trait. Look up the real rarity from hero traits.
    local rarity = upgradeData.Rarity
    if isPom and upgradeData.Name and CurrentRun and CurrentRun.Hero then
        -- Use TraitDictionary (game's own fast lookup) first
        local found = false
        if CurrentRun.Hero.TraitDictionary and CurrentRun.Hero.TraitDictionary[upgradeData.Name] then
            local heroTraits = CurrentRun.Hero.TraitDictionary[upgradeData.Name]
            if heroTraits[1] and heroTraits[1].Rarity then
                rarity = heroTraits[1].Rarity
                found = true
            end
        end
        -- Fallback: iterate all hero traits with pairs (handles gaps ipairs would miss)
        if not found and CurrentRun.Hero.Traits then
            for _, heroTrait in pairs(CurrentRun.Hero.Traits) do
                if heroTrait.Name == upgradeData.Name and heroTrait.Rarity then
                    rarity = heroTrait.Rarity
                    break
                end
            end
        end
    end
    if rarity and rarity ~= "" then
        speech = speech .. ", " .. rarity
    end

    -- Add slot info (what this boon affects)
    if upgradeData.Slot then
        local slotDesc = SlotDescriptions[upgradeData.Slot]
        if slotDesc then
            speech = speech .. ", " .. slotDesc
        end
    end
    local pomStackNum = isPom and (button.LootData.StackNum or 1) or nil
    local pomOldLevel = nil
    local pomNewLevel = nil

    if isPom and CurrentRun and CurrentRun.Hero and GetTraitCount then
        local ok, traitCount = pcall(GetTraitCount, CurrentRun.Hero, upgradeData)
        if ok and traitCount then
            pomOldLevel = traitCount
            pomNewLevel = traitCount + pomStackNum
            speech = speech .. ", " .. string.format(UIStrings.LevelFmt, pomOldLevel) .. " " .. UIStrings.To .. " " .. string.format(UIStrings.LevelFmt, pomNewLevel)
        end
    elseif upgradeData.OldLevel and upgradeData.NewLevel then
        -- Fallback: in case future game updates put OldLevel/NewLevel on button.Data
        speech = speech .. ", " .. string.format(UIStrings.LevelFmt, upgradeData.OldLevel) .. " " .. UIStrings.To .. " " .. string.format(UIStrings.LevelFmt, upgradeData.NewLevel)
    end

    -- Check if this is an exchange (replaces existing boon)
    if upgradeData.TraitToReplace then
        local replaceName = SafeGetDisplayName(upgradeData.TraitToReplace)
        if replaceName ~= "" then
            speech = speech .. ". " .. UIStrings.Replaces .. " " .. replaceName
        end
    end

    -- Check for Duo boon indicator
    if upgradeData.IsDuoBoon then
        speech = speech .. ", " .. UIStrings.Duo
    end

    -- Add description — try hardcoded tables first, then game's GetTraitTooltip
    local desc = ""
    if button.UpgradeName == "WeaponUpgrade" and upgradeData.Name then
        -- Daedalus Hammer: use hardcoded description
        desc = HammerDescriptions[upgradeData.Name] or ""
    end
    if desc == "" and upgradeData.Name then
        -- God boons: use hardcoded description from wiki
        desc = GodBoonDescriptions[upgradeData.Name] or ""
    end
    if desc == "" then
        -- Fallback: try game's GetTraitTooltip (may not resolve for most boons)
        desc = SafeGetTraitDescription(upgradeData)
    end
    -- For non-Pom boons: compute actual rarity-scaled values and substitute into description
    if not isPom and upgradeData.Name and upgradeData.Rarity and desc ~= "" then
        local ok2, modifiedDesc = pcall(function()
            -- Look up rarity multiplier directly from TraitData.RarityLevels
            local rarityMult = nil
            if TraitData and TraitData[upgradeData.Name] then
                local td = TraitData[upgradeData.Name]
                if td.RarityLevels and td.RarityLevels[upgradeData.Rarity] then
                    local rd = td.RarityLevels[upgradeData.Rarity]
                    if rd.Multiplier then
                        rarityMult = rd.Multiplier
                    elseif rd.MinMultiplier and rd.MaxMultiplier then
                        rarityMult = (rd.MinMultiplier + rd.MaxMultiplier) / 2
                    end
                end
            end

            if not rarityMult then
                return nil
            end

            local tooltipData = GetProcessedTraitData({
                Unit = CurrentRun.Hero,
                TraitName = upgradeData.Name,
                FakeStackNum = 1,
                Rarity = upgradeData.Rarity,
                RarityMultiplier = rarityMult,
            })
            SetTraitTextData(tooltipData)

            -- Use NewTotal for new boons (OldTotal=0 since hero doesn't have trait yet)
            -- NewTotal contains the actual rarity-scaled values the boon WOULD give
            local valueArray = tooltipData.NewTotal or tooltipData.OldTotal
            if not valueArray then
                return nil
            end

            local extractData = nil
            if GetExtractData then
                extractData = GetExtractData(tooltipData)
            end

            local computedParts = {}
            for i, val in ipairs(valueArray) do
                if type(val) == "number" then
                    local isPercent = false
                    if extractData and extractData[i] and extractData[i].Format then
                        local fmt = extractData[i].Format
                        if fmt == "Percent" or fmt == "PercentDelta" or fmt == "NegativePercentDelta"
                            or fmt == "PercentOfBase" or fmt == "PercentHeal" then
                            isPercent = true
                        end
                    end
                    if math.floor(val + 0.5) ~= 0 then
                        local display = _FormatBoonValue(val, isPercent)
                        computedParts[#computedParts + 1] = { display = display }
                    end
                end
            end

            if #computedParts > 0 then
                local substituted, numReplaced = _SubstituteDescriptionValues(desc, computedParts)
                if numReplaced > 0 then
                    return substituted
                else
                    -- Description has no numbers to replace — append values after
                    local valStr = ""
                    for i, part in ipairs(computedParts) do
                        if i > 1 then valStr = valStr .. ", " end
                        valStr = valStr .. part.display
                    end
                    return desc .. ". " .. valStr
                end
            end
            return nil
        end)
        if ok2 and modifiedDesc then
            speech = speech .. ". " .. modifiedDesc
        else
            -- Fallback: use hardcoded description as-is if computation failed
            speech = speech .. ". " .. desc
        end
    elseif desc ~= "" then
        speech = speech .. ". " .. desc
    end

    -- For Pom of Power: compute actual per-level values using game's own processing
    if isPom and pomOldLevel and upgradeData.Name then
        local ok, valueStr = pcall(function()
            -- Use hero's actual RarityMultiplier (not the template/base one from upgradeData)
            local actualRarityMult = upgradeData.RarityMultiplier
            if CurrentRun and CurrentRun.Hero and CurrentRun.Hero.TraitDictionary
                    and CurrentRun.Hero.TraitDictionary[upgradeData.Name] then
                local ht = CurrentRun.Hero.TraitDictionary[upgradeData.Name]
                if ht[1] and ht[1].RarityMultiplier then
                    actualRarityMult = ht[1].RarityMultiplier
                end
            end
            -- Call the game's GetProcessedTraitData with FakeStackNum to get Pom-processed values
            local tooltipData = GetProcessedTraitData({
                Unit = CurrentRun.Hero,
                TraitName = upgradeData.Name,
                FakeStackNum = pomStackNum,
                RarityMultiplier = actualRarityMult
            })
            SetTraitTextData(tooltipData)

            if tooltipData.OldTotal and tooltipData.NewTotal then
                -- Get extract data to determine format (percent vs absolute)
                local extractData = GetExtractData(tooltipData)
                local parts = {}
                local maxIdx = 0
                for i, _ in ipairs(tooltipData.OldTotal) do
                    if i > maxIdx then maxIdx = i end
                end
                for i, _ in ipairs(tooltipData.NewTotal) do
                    if i > maxIdx then maxIdx = i end
                end
                for i = 1, maxIdx do
                    local oldVal = tooltipData.OldTotal[i]
                    local newVal = tooltipData.NewTotal[i]
                    if oldVal and newVal and type(oldVal) == "number" and type(newVal) == "number" then
                        -- Determine if this is a percentage value from the Format field
                        local isPercent = false
                        if extractData and extractData[i] and extractData[i].Format then
                            local fmt = extractData[i].Format
                            if fmt == "Percent" or fmt == "PercentDelta" or fmt == "NegativePercentDelta"
                                or fmt == "PercentOfBase" or fmt == "PercentHeal" then
                                isPercent = true
                            end
                        end
                        local suffix = isPercent and "%" or ""
                        -- Round to nearest integer for clean speech
                        local oldStr = tostring(math.floor(oldVal + 0.5))
                        local newStr = tostring(math.floor(newVal + 0.5))
                        parts[#parts + 1] = oldStr .. suffix .. " to " .. newStr .. suffix
                    end
                end
                if #parts > 0 then
                    -- Manual concat (avoid table.concat — ModUtil v2.10.0 bug)
                    local result = ""
                    for i, part in ipairs(parts) do
                        if i > 1 then result = result .. ", " end
                        result = result .. part
                    end
                    return result
                end
            end
            return nil
        end)
        if ok and valueStr then
            speech = speech .. ". " .. valueStr
        end
    end

    return speech
end

-- Build speech for a Chaos boon (TransformingTrait = curse + blessing combo)
local function BuildChaosSpeech(button)
    local upgradeData = button.Data
    local speech = "Chaos - "

    -- Get the combo name — try hardcoded table first, then GetTraitTooltipTitle
    local comboName = ""
    if upgradeData.Name then
        comboName = BoonDisplayNames[upgradeData.Name] or ""
    end
    if comboName == "" and GetTraitTooltipTitle then
        local ok, titleResult = pcall(GetTraitTooltipTitle, upgradeData)
        if ok and titleResult and titleResult ~= "" then
            local resolved = SafeGetDisplayName(titleResult)
            if resolved ~= "" then
                comboName = resolved
            end
        end
    end
    if comboName == "" and upgradeData.Name then
        local dn = SafeGetDisplayName(upgradeData.Name)
        if dn ~= "" then
            comboName = dn
        else
            comboName = upgradeData.Name
        end
    end
    speech = speech .. comboName

    -- Add rarity if present
    if upgradeData.Rarity and upgradeData.Rarity ~= "" then
        speech = speech .. ", " .. upgradeData.Rarity
    end

    -- Add curse info
    if upgradeData.RemainingUses then
        local uses = upgradeData.RemainingUses
        speech = speech .. ". " .. string.format(UIStrings.CurseLasts, uses)
    end

    -- Add curse description from the trait's curse data
    if upgradeData.Name then
        local curseDesc = ChaosCurseDescriptions[upgradeData.Name]
        if curseDesc then
            speech = speech .. ". " .. UIStrings.Curse .. ": " .. curseDesc
        end
    end

    -- Add blessing description from OnExpire data
    if upgradeData.OnExpire and upgradeData.OnExpire.TraitData then
        local blessingData = upgradeData.OnExpire.TraitData
        local blessingName = blessingData.Name or ""
        local blessingDesc = ChaosBlessingDescriptions[blessingName]
        if blessingDesc then
            speech = speech .. ". " .. UIStrings.Blessing .. ": " .. blessingDesc
        else
            -- Try GetTraitTooltip on the blessing data
            local desc = SafeGetTraitDescription(blessingData)
            if desc ~= "" then
                speech = speech .. ". Blessing: " .. desc
            end
        end
    end

    return speech
end

-- Build speech for a consumable item
local function BuildConsumableSpeech(button)
    local upgradeData = button.Data
    local speech = ""

    -- Get consumable name — try hardcoded table first
    if upgradeData.Name then
        speech = BoonDisplayNames[upgradeData.Name] or ""
        if speech == "" then
            local dn = SafeGetDisplayName(upgradeData.Name)
            if dn ~= "" then
                speech = dn
            else
                speech = upgradeData.Name
            end
        end
    end

    -- Add rarity
    if upgradeData.Rarity and upgradeData.Rarity ~= "" then
        speech = speech .. ", " .. upgradeData.Rarity
    end

    -- Add description — try hardcoded GodBoonDescriptions first, then game's GetTraitTooltip
    local desc = ""
    if upgradeData.Name then
        desc = GodBoonDescriptions[upgradeData.Name] or ""
    end
    if desc == "" then
        desc = SafeGetTraitDescription(upgradeData)
    end
    if desc ~= "" then
        speech = speech .. ". " .. desc
    end

    return speech
end

-- Main speech builder — dispatches based on button type
local function BuildBoonSpeech(button)
    if not button or not button.Data then
        return nil
    end

    local buttonType = button.Type

    if buttonType == "TransformingTrait" then
        return BuildChaosSpeech(button)
    elseif buttonType == "Consumable" then
        return BuildConsumableSpeech(button)
    else
        -- "Trait" type covers both god boons and hammer upgrades
        return BuildTraitSpeech(button)
    end
end

-- Mouse over handler for boon selection buttons
-- Suppress counter for first auto-hover when boon selection opens
-- (prevents god flavor text from being interrupted)
suppressBoonHoverCount = 0

function AccessibleBoonMouseOver(button)
    if not AccessibilityEnabled or not AccessibilityEnabled() or not button then
        return
    end

    if suppressBoonHoverCount > 0 then
        suppressBoonHoverCount = suppressBoonHoverCount - 1
        return
    end

    local speech = BuildBoonSpeech(button)
    if speech and speech ~= "" then
        _Log("[NAV] BoonMenu item: " .. speech)
        TolkSilence()
        TolkSpeak(speech)
    end
end

-- Wrap CreateBoonLootButtons to add OnMouseOverFunctionName + AttachLua
ModUtil.WrapBaseFunction("CreateBoonLootButtons", function(baseFunc, lootData, reroll)
    baseFunc(lootData, reroll)

    if not AccessibilityEnabled or not AccessibilityEnabled() then
        return
    end

    _Log("[SCREEN-OPEN] BoonMenu (CreateBoonLootButtons fired, reroll=" .. tostring(reroll) .. ")")

    -- Access the screen components via the current loot screen
    local screen = nil
    if ScreenAnchors and ScreenAnchors.ChoiceScreen then
        screen = ScreenAnchors.ChoiceScreen
    end

    if not screen or not screen.Components then
        return
    end

    local components = screen.Components
    local firstButton = nil
    local boonCount = 0

    -- Add OnMouseOverFunctionName to PurchaseButton1 through PurchaseButton5
    for i = 1, 5 do
        local key = "PurchaseButton" .. i
        local comp = components[key]
        if comp and comp.Id then
            comp.OnMouseOverFunctionName = "AccessibleBoonMouseOver"
            AttachLua({ Id = comp.Id, Table = comp })
            boonCount = boonCount + 1
            if not firstButton then
                firstButton = comp
            end
        end
    end

    -- Label the Reroll (Fated Persuasion) button if it exists
    local rerollPanel = components["RerollPanel"]
    if rerollPanel and rerollPanel.Id then
        rerollPanel.OnMouseOverFunctionName = "AccessibleRerollMouseOver"
        AttachLua({ Id = rerollPanel.Id, Table = rerollPanel })
    end

    -- Speak god flavor text on open
    -- Suppress the next few OnMouseOver events so initial cursor placement doesn't interrupt
    suppressBoonHoverCount = 1
    TolkSilence()
    -- Read the flavor text that the game already chose and displayed via CreateTextBox
    -- Our CreateTextBox wrapper captured it into _capturedFlavorText
    local godFlavor = nil
    if lootData and lootData.Name then
        local godName = GodDisplayNames[lootData.Name] or ""
        -- Use the captured flavor text (exact same text the game displayed)
        if _capturedFlavorText and _capturedFlavorText ~= "" then
            if godName ~= "" then
                godFlavor = godName .. ". " .. _capturedFlavorText
            else
                godFlavor = _capturedFlavorText
            end
        end
        -- Fallback to hardcoded table if capture failed
        if not godFlavor then
            godFlavor = GodFlavorText[lootData.Name]
        end
        -- Clear captured text for next boon screen
        _capturedFlavorText = nil
    end
    -- Combine flavor text + first boon into one TolkSpeak call for all menus
    if firstButton then
        local boonSpeech = BuildBoonSpeech(firstButton)
        local combined = ""
        if godFlavor then
            combined = godFlavor
        end
        if boonSpeech and boonSpeech ~= "" then
            if combined ~= "" then
                combined = combined .. ". " .. boonSpeech
            else
                combined = boonSpeech
            end
        end
        if combined ~= "" and AccessibilityEnabled and AccessibilityEnabled() then
            TolkSpeak(combined)
        end
    elseif godFlavor then
        TolkSpeak(godFlavor)
    end
end)

-- Mouse over handler for the Reroll (Fated Persuasion) button
function AccessibleRerollMouseOver(button)
    if not AccessibilityEnabled or not AccessibilityEnabled() or not button then
        return
    end
    local speech = string.format(UIStrings.FatedPersuasionFmt, UIStrings.Boons)
    if button.Cost then
        if button.Cost < 0 then
            speech = speech .. ", " .. UIStrings.Blocked
        else
            speech = speech .. ", " .. string.format(UIStrings.CostFmt, button.Cost)
        end
    end
    -- Show remaining reroll charges
    if CurrentRun and CurrentRun.NumRerolls then
        speech = speech .. ", " .. CurrentRun.NumRerolls .. " " .. UIStrings.Remaining
    end
    TolkSilence()
    TolkSpeak(speech)
end
