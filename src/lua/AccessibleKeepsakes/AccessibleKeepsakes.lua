--[[
Mod: AccessibleKeepsakes
Author: Accessibility Layer
Version: 5

Provides screen reader accessibility for the Keepsake Display Case (AwardMenu) screen.
- Speaks keepsake name, level, equipped status, progress, and description when cursor moves between keepsakes
- Locked keepsakes just say "Locked keepsake" (matches native game hiding info until unlocked)
- Hardcoded descriptions from Hades Wiki (GetTraitTooltip returns keys GetDisplayName can't resolve)
- Registers a global OnMouseOver handler for RadioButton components (same pattern as native game)
- Also handles locked legendary keepsakes (LegendaryKeepsakeLockedButton)
- Uses ScreenAnchors.AwardMenuScreen[triggeredById] lookup (native game pattern)
- Announces screen name on open
--]]

local function _Log(msg) if LogEvent then LogEvent(msg) end end

-- UIStrings is populated by ZLocalizationCore. If a stale or partial localization
-- table is ever active (e.g. an old DLL left in memory, or a load-order edge case),
-- a missing key must not turn a string.format/concatenation into a crash — which
-- pops Hades' bug reporter. Fall back to the English default instead.
local function US(key, fallback)
    local v = UIStrings and UIStrings[key]
    if v == nil then return fallback end
    return v
end

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
    if ok and result and result ~= "" and result ~= key then
        return StripFormatting(result)
    end
    return ""
end

-- Hardcoded keepsake descriptions from Hades Wiki
-- (GetTraitTooltip returns localization keys that GetDisplayName cannot resolve)
-- Level-dependent keepsakes use { text = "format with %s", values = {"rank1", "rank2", "rank3"} }
-- Companions use { field = "<extracted field>", template = "...%s...", fallback = "..." } so the
--   per-level value the game shows (TooltipDamage/Health/Duration) is read live from trait data.
-- Plain string entries have no level variation.
--
-- Companion descriptions live in this LOCAL upvalue (closed over by BuildKeepsakeSpeech)
-- so they cannot be reverted by a stale/clobbered global KeepsakeDescriptions — a runtime
-- bug (session 61) where the global ends up holding old companion strings even though this
-- file defines the new tables. The same entries are mirrored into the global below for
-- cross-mod access (AccessibleTraitTray).
local CompanionDescriptions = {
    FuryAssistTrait = {
        field = "TooltipDamage",
        template = "Your Companion deals %s damage in an area near your closest foe, then continually down the line",
        fallback = "Your Companion deals damage in an area near your closest foe, then continually down the line",
    },
    AchillesPatroclusAssistTrait = {
        field = "TooltipDamage",
        template = "Your Companion deals %s damage to 2 foes one after another",
        fallback = "Your Companion deals damage to 2 foes one after another",
    },
    ThanatosAssistTrait = {
        field = "TooltipDamage",
        template = "Your Companion deals %s damage in an area in front of you, after a brief delay",
        fallback = "Your Companion deals damage in an area in front of you, after a brief delay",
    },
    SisyphusAssistTrait = {
        field = "TooltipDamage",
        template = "Your Companion deals %s damage in an area, and drops some Health, Darkness, and Obols",
        fallback = "Your Companion deals damage in an area, and drops some Health, Darkness, and Obols",
    },
    SkellyAssistTrait = {
        field = "TooltipHealth",
        template = "Your Companion creates a distraction with %s Health, provoking your foes to attack it until it dies",
        fallback = "Your Companion creates a distraction, provoking your foes to attack it until it dies",
    },
    DusaAssistTrait = {
        field = "TooltipDuration",
        template = "Your Companion joins you for %s seconds, repeatedly firing shots that petrify foes and deal 70 damage",
        fallback = "Your Companion joins you, repeatedly firing shots that petrify foes and deal 70 damage",
    },
}

KeepsakeDescriptions = {
    MaxHealthKeepsakeTrait = { text = "Gain +%s max Health. From Cerberus", values = {"25", "38", "50"} },
    DirectionalArmorTrait = { text = "Take -%s%% damage from the front, but take 10%% from the back", values = {"10", "15", "20"} },
    BackstabAlphaStrikeTrait = { text = "Deal +%s%% damage striking undamaged foes; also striking foes from behind", values = {"10", "15", "20"} },
    PerfectClearDamageBonusTrait = "Gain bonus damage each time you clear an Encounter without taking damage. Bonus Damage: +1%",
    ShopDurationTrait = { text = "Items from the Well of Charon have durations increased by +%s Encounters", values = {"4", "6", "8"} },
    BonusMoneyTrait = { text = "Receive %s Obols to spend as you please (once per escape attempt)", values = {"100", "125", "150"} },
    LowHealthDamageTrait = "Deal +20% damage while at 35% Health or less",
    DistanceDamageTrait = { text = "Deal +%s%% damage to distant foes", values = {"10", "20", "30"} },
    LifeOnUrnTrait = "Broken urns have a 3% chance to contain items",
    ReincarnationTrait = { text = "Automatically restore up to %s Health when your Life Total is depleted (once per escape attempt)", values = {"50", "75", "100"} },
    ForceZeusBoonTrait = "The next Boon you find will be from Zeus. His blessings have 10% chance to be Rare or better",
    ForcePoseidonBoonTrait = "The next Boon you find will be from Poseidon. His blessings have 10% chance to be Rare or better",
    ForceAthenaBoonTrait = "The next Boon you find will be from Athena. Her blessings have 10% chance to be Rare or better",
    ForceAphroditeBoonTrait = "The next Boon you find will be from Aphrodite. Her blessings have 10% chance to be Rare or better",
    ForceAresBoonTrait = "The next Boon you find will be from Ares. His blessings have 10% chance to be Rare or better",
    ForceArtemisBoonTrait = "The next Boon you find will be from Artemis. Her blessings have 10% chance to be Rare or better",
    ForceDionysusBoonTrait = "The next Boon you find will be from Dionysus. His blessings have 10% chance to be Rare or better",
    FastClearDodgeBonusTrait = "Gain greater Dodge chance and move speed each time you quickly clear an Encounter. Dodge Chance & Move Speed: 1%",
    ForceDemeterBoonTrait = "The next Boon you find will be from Demeter. Her blessings have 10% chance to be Rare or better",
    ChaosBoonTrait = "Enter Chaos Gates without losing. Blessings from Chaos have 20% chance to be Rare or better",
    VanillaTrait = { text = "Your Attack, Special, and Cast each deal +%s%% damage while not empowered by a Boon", values = {"50", "75", "100"} },
    ShieldBossTrait = { text = "In the final encounter in each Underworld region, take 0 damage the first %s times foes hit you", values = {"3", "4", "5"} },
    ShieldAfterHitTrait = { text = "After taking damage, become impervious for %s seconds. Refreshes after 7 seconds. From Patroclus", values = {"1", "1.25", "1.5"} },
    ChamberStackTrait = { text = "After every %s Encounters, gain +1 Lv. (a random Boon grows stronger)", values = {"6", "5", "4"} },
    HadesShoutKeepsake = { text = "Your Call becomes Hades' Aid, which briefly makes you Invisible; your God Gauge starts %s%% full", values = {"10", "20", "30"} },
    -- Companions: damage/health/duration scale with level (Common 1x -> Legendary 5x).
    -- Wording mirrors the game's own tooltips; %s is filled from the live extracted field.
    FuryAssistTrait = {
        field = "TooltipDamage",
        template = "Your Companion deals %s damage in an area near your closest foe, then continually down the line",
        fallback = "Your Companion deals damage in an area near your closest foe, then continually down the line",
    },
    AchillesPatroclusAssistTrait = {
        field = "TooltipDamage",
        template = "Your Companion deals %s damage to 2 foes one after another",
        fallback = "Your Companion deals damage to 2 foes one after another",
    },
    ThanatosAssistTrait = {
        field = "TooltipDamage",
        template = "Your Companion deals %s damage in an area in front of you, after a brief delay",
        fallback = "Your Companion deals damage in an area in front of you, after a brief delay",
    },
    SisyphusAssistTrait = {
        field = "TooltipDamage",
        template = "Your Companion deals %s damage in an area, and drops some Health, Darkness, and Obols",
        fallback = "Your Companion deals damage in an area, and drops some Health, Darkness, and Obols",
    },
    SkellyAssistTrait = {
        field = "TooltipHealth",
        template = "Your Companion creates a distraction with %s Health, provoking your foes to attack it until it dies",
        fallback = "Your Companion creates a distraction, provoking your foes to attack it until it dies",
    },
    DusaAssistTrait = {
        field = "TooltipDuration",
        template = "Your Companion joins you for %s seconds, repeatedly firing shots that petrify foes and deal 70 damage",
        fallback = "Your Companion joins you, repeatedly firing shots that petrify foes and deal 70 damage",
    },
}

-- Map keepsake trait names to the NPC who gives them
local KeepsakeOriginNPC = {
    MaxHealthKeepsakeTrait = "Cerberus",
    DirectionalArmorTrait = "Achilles",
    BackstabAlphaStrikeTrait = "Nyx",
    PerfectClearDamageBonusTrait = "Thanatos",
    ShopDurationTrait = "Charon",
    BonusMoneyTrait = "Hypnos",
    LowHealthDamageTrait = "Megaera",
    DistanceDamageTrait = "Orpheus",
    LifeOnUrnTrait = "Dusa",
    ReincarnationTrait = "Skelly",
    ForceZeusBoonTrait = "Zeus",
    ForcePoseidonBoonTrait = "Poseidon",
    ForceAthenaBoonTrait = "Athena",
    ForceAphroditeBoonTrait = "Aphrodite",
    ForceAresBoonTrait = "Ares",
    ForceArtemisBoonTrait = "Artemis",
    ForceDionysusBoonTrait = "Dionysus",
    FastClearDodgeBonusTrait = "Hermes",
    ForceDemeterBoonTrait = "Demeter",
    ChaosBoonTrait = "Chaos",
    VanillaTrait = "Sisyphus",
    ShieldBossTrait = "Eurydice",
    ShieldAfterHitTrait = "Patroclus",
    ChamberStackTrait = "Persephone",
    HadesShoutKeepsake = "Hades",
    -- Companions
    FuryAssistTrait = "Megaera",
    AchillesPatroclusAssistTrait = "Achilles and Patroclus",
    ThanatosAssistTrait = "Thanatos",
    SisyphusAssistTrait = "Sisyphus",
    SkellyAssistTrait = "Skelly",
    DusaAssistTrait = "Dusa",
}

-- Build speech text for a keepsake button
local function BuildKeepsakeSpeech(button)
    if not button then return nil end

    -- Check for locked keepsake via Data.Unlocked
    -- The game populates TraitData on ALL keepsakes (even locked ones),
    -- so we must check button.Data.Unlocked instead of checking for nil TraitData
    if button.Data and button.Data.Unlocked == false then
        return UIStrings.LockedKeepsake
    end

    -- Unavailable slot
    if button.Unavailable then
        return "Empty keepsake slot"
    end

    local traitData = button.TraitData
    if not traitData then
        return UIStrings.LockedKeepsake
    end

    -- Get keepsake name
    local displayName = nil
    if traitData.InRackTitle then
        displayName = SafeGetDisplayName(traitData.InRackTitle)
    end
    if (not displayName or displayName == "") and traitData.Name then
        displayName = SafeGetDisplayName(traitData.Name)
    end
    if not displayName or displayName == "" then
        displayName = traitData.Name or "Unknown Keepsake"
    end

    local speech = displayName

    -- Add who the keepsake is from
    if traitData.Name and KeepsakeOriginNPC[traitData.Name] then
        speech = speech .. ", from " .. KeepsakeOriginNPC[traitData.Name]
    end

    -- Add level info
    if GetKeepsakeLevel and traitData.Name then
        local ok, level = pcall(GetKeepsakeLevel, traitData.Name)
        if ok and level and level > 0 then
            speech = speech .. ", " .. string.format(UIStrings.LevelFmt, level)
        end
    end

    -- Check if equipped
    if GameState then
        if GameState.LastAwardTrait == traitData.Name then
            speech = speech .. ", " .. UIStrings.Equipped
        elseif GameState.LastAssistTrait and button.Data and GameState.LastAssistTrait == button.Data.Gift then
            speech = speech .. ", " .. UIStrings.Equipped
        end
    end

    -- Check if blocked (can't swap this run)
    if button.Blocked then
        speech = speech .. ", " .. UIStrings.Blocked
    end

    -- Check if maxed or show progress
    if IsKeepsakeMaxed and traitData.Name then
        local ok, maxed = pcall(IsKeepsakeMaxed, traitData.Name)
        if ok and maxed then
            speech = speech .. ", " .. UIStrings.MaxLevel
        elseif GetKeepsakeChambersToNextLevel then
            local ok2, chambersNeeded = pcall(GetKeepsakeChambersToNextLevel, traitData.Name)
            if ok2 and chambersNeeded and chambersNeeded > 0 then
                speech = speech .. ", " .. chambersNeeded .. " chambers to next level"
            end
        end
    end

    -- Add slot type (Keepsake vs Companion/Assist)
    if traitData.Slot == "Assist" then
        speech = speech .. ", Companion"
    end

    -- Add keepsake description. Companions read from the LOCAL CompanionDescriptions
    -- (a clobber-proof upvalue); all other keepsakes from the global table. A runtime
    -- bug (session 61) can revert the global's companion entries to old strings, so the
    -- local copy is the source of truth for companions.
    local descSource = KeepsakeDescriptions
    if traitData.Slot == "Assist" and CompanionDescriptions[traitData.Name] then
        descSource = CompanionDescriptions
    end
    if traitData.Name and descSource[traitData.Name] then
        local desc = descSource[traitData.Name]
        if type(desc) == "table" and desc.values then
            -- Level-dependent keepsake: pick value for current rank
            local level = 1
            if GetKeepsakeLevel then
                local ok, lvl = pcall(GetKeepsakeLevel, traitData.Name)
                if ok and lvl and lvl > 0 then
                    level = lvl
                end
            end
            local value = desc.values[level] or desc.values[1]
            speech = speech .. ". " .. string.format(desc.text, value)
        elseif type(desc) == "table" and desc.template then
            -- Companion: substitute the live per-level value. Only the four
            -- PropertyChange companions (Battie/Mort/Shady/Antos) have rarity-scaled
            -- damage, so their extracted TooltipDamage (the BASE) is multiplied by the
            -- level (Common 1x -> Legendary 5x = the level number). Rib's decoy Health
            -- and Fidi's duration/damage come from FIXED summon units (SkellyAssist /
            -- DusaAssist spawn fixed enemies, no rarity scaling), so they show unscaled.
            local value = desc.field and traitData[desc.field]
            local n = tonumber(value)
            if n and desc.field == "TooltipDamage" then
                local lvl = 1
                if GetKeepsakeLevel then
                    local ok, l = pcall(GetKeepsakeLevel, traitData.Name)
                    if ok and l and l > 0 then lvl = l end
                end
                value = math.floor(n * lvl + 0.5)
            end
            if value ~= nil then
                speech = speech .. ". " .. string.format(desc.template, tostring(value))
            elseif desc.fallback then
                speech = speech .. ". " .. desc.fallback
            end
        elseif type(desc) == "string" then
            -- Plain string description
            speech = speech .. ". " .. desc
        end
    end

    return speech
end

-- Register a global OnMouseOver handler for RadioButton components
-- This fires alongside the native handler (Hades supports multiple handlers per event type)
-- Pending open speech — first OnMouseOver combines it with first keepsake
_keepsakeOpenSpeech = nil

OnMouseOver{ "RadioButton",
    function(triggerArgs)
        if not AccessibilityEnabled or not AccessibilityEnabled() then
            return
        end
        if not triggerArgs or not triggerArgs.triggeredById then
            return
        end
        if not IsScreenOpen("AwardMenu") then
            return
        end
        if not ScreenAnchors or not ScreenAnchors.AwardMenuScreen then
            return
        end
        local button = ScreenAnchors.AwardMenuScreen[triggerArgs.triggeredById]
        if not button then
            return
        end

        local speech = BuildKeepsakeSpeech(button)
        if speech and speech ~= "" then
            if _keepsakeOpenSpeech then
                speech = _keepsakeOpenSpeech .. ", " .. speech
                _keepsakeOpenSpeech = nil
            end
            TolkSilence()
            TolkSpeak(speech)
        end
    end
}

-- Also handle locked legendary keepsakes (LegendaryKeepsakeLockedButton type)
OnMouseOver{ "LegendaryKeepsakeLockedButton",
    function(triggerArgs)
        if not AccessibilityEnabled or not AccessibilityEnabled() then
            return
        end
        if not triggerArgs or not triggerArgs.triggeredById then
            return
        end
        if not IsScreenOpen("AwardMenu") then
            return
        end
        if not ScreenAnchors or not ScreenAnchors.AwardMenuScreen then
            return
        end
        local button = ScreenAnchors.AwardMenuScreen[triggerArgs.triggeredById]
        if button then
            -- Locked legendary keepsake — check if it has data
            local speech = UIStrings.LockedCompanion
            if button.Data and button.Data.NPC then
                local npcName = SafeGetDisplayName(button.Data.NPC)
                if npcName ~= "" then
                    speech = UIStrings.LockedCompanion .. " from " .. npcName
                end
            end
            TolkSilence()
            TolkSpeak(speech)
        else
            TolkSilence()
            TolkSpeak(UIStrings.LockedCompanion)
        end
    end
}

-- Companion upgrade buttons (spend Ambrosia to raise a Companion's level).
-- The native game leaves these silent for screen readers, so announce the
-- target level and Ambrosia cost. button.GiftName / button.ParentButton are
-- set by CreateKeepsakeIcon (AwardMenuScripts.lua).
OnMouseOver{ "AssistUpgradeButton",
    function(triggerArgs)
        if not AccessibilityEnabled or not AccessibilityEnabled() then
            return
        end
        if not triggerArgs or not triggerArgs.triggeredById then
            return
        end
        if not IsScreenOpen("AwardMenu") then
            return
        end
        if not ScreenAnchors or not ScreenAnchors.AwardMenuScreen then
            return
        end
        local button = ScreenAnchors.AwardMenuScreen[triggerArgs.triggeredById]
        if not button or not button.GiftName then
            return
        end
        local giftName = button.GiftName

        -- Resolve the Companion's display name (Battie, Mort, etc.)
        local traitData = button.ParentButton and button.ParentButton.TraitData
        local displayName = nil
        if traitData then
            if traitData.InRackTitle then
                displayName = SafeGetDisplayName(traitData.InRackTitle)
            end
            if (not displayName or displayName == "") and traitData.Name then
                displayName = SafeGetDisplayName(traitData.Name)
            end
        end
        if not displayName or displayName == "" then
            displayName = giftName
        end

        local speech
        local maxed = false
        if IsKeepsakeMaxed then
            local ok, m = pcall(IsKeepsakeMaxed, giftName)
            if ok then maxed = m end
        end

        if maxed then
            speech = string.format(US("CompanionMaxed", "%s, maximum level"), displayName)
        else
            -- Current Companion level is 1-5; the upgrade moves it to level + 1.
            local level = 1
            if GetAssistKeepsakeLevel then
                local ok, lvl = pcall(GetAssistKeepsakeLevel, giftName)
                if ok and lvl then level = lvl end
            end
            local cost = nil
            if GetAssistKeepsakeUpgradeCost then
                local ok, c = pcall(GetAssistKeepsakeUpgradeCost, giftName)
                if ok then cost = c end
            end
            if cost then
                speech = string.format(US("UpgradeCompanion", "Upgrade %s to Level %s, costs %s Ambrosia"), displayName, level + 1, cost)
                -- Flag when the player can't afford the upgrade.
                local affordable = true
                if HasResource then
                    local ok, has = pcall(HasResource, "SuperGiftPoints", cost)
                    if ok then affordable = has end
                end
                if not affordable then
                    speech = speech .. ", " .. US("NotEnoughAmbrosia", "not enough Ambrosia")
                end
                -- A Companion must be equipped before it can be upgraded; otherwise
                -- the first press just equips it (UpgradeAssistKeepsake in
                -- AwardMenuScripts.lua returns early when it isn't the equipped one).
                if not (GameState and GameState.LastAssistTrait == giftName) then
                    speech = speech .. ", " .. US("EquipFirstToUpgrade", "equip this Companion first to upgrade")
                end
            else
                speech = displayName
            end
        end

        if speech and speech ~= "" then
            TolkSilence()
            TolkSpeak(speech)
        end
    end
}

-- Speak when the AwardMenu screen opens
ModUtil.WrapBaseFunction("ShowAwardMenu", function(baseFunc)
    _Log("[SCREEN-OPEN] Keepsake Display Case (ShowAwardMenu)")
    if AccessibilityEnabled and AccessibilityEnabled() then
        _keepsakeOpenSpeech = UIStrings.KeepsakeDisplayCase
    end
    return baseFunc()
end)
