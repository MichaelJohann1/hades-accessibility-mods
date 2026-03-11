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
-- Level-dependent entries use { text = "format with %s", values = {"rank1", "rank2", "rank3"} }
-- Plain string entries have no level variation (companions)
KeepsakeDescriptions = {
    MaxHealthKeepsakeTrait = { text = "Gain +%s max Health. From Cerberus", values = {"25", "38", "50"} },
    DirectionalArmorTrait = "Take -10% damage from the front, but take 10% from the back",
    BackstabAlphaStrikeTrait = "Deal +10% damage striking undamaged foes; also striking foes from behind",
    PerfectClearDamageBonusTrait = "Gain bonus damage each time you clear an Encounter without taking damage. Bonus Damage: +1%",
    ShopDurationTrait = "Items from the Well of Charon have durations increased by +4 Encounters",
    BonusMoneyTrait = "Receive 100 Obols to spend as you please (once per escape attempt)",
    LowHealthDamageTrait = "Deal +20% damage while at +20% or less",
    DistanceDamageTrait = "Deal +10% damage to distant foes",
    LifeOnUrnTrait = "Broken urns have a 3% chance to contain items",
    ReincarnationTrait = "Automatically restore up to 50 when your Life Total is depleted (once per escape attempt)",
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
    VanillaTrait = "Your Attack, Special, and Cast each deal +50% damage while not empowered by a Boon",
    ShieldBossTrait = "In the final encounter in each Underworld region, take 0 damage the first 1 times foes hit you",
    ShieldAfterHitTrait = { text = "After taking damage, become impervious for %s seconds. Refreshes after 7 seconds. From Patroclus", values = {"1", "1.25", "1.5"} },
    ChamberStackTrait = "After every 6 Encounters, gain +1 Lv. (a random Boon grows stronger)",
    HadesShoutKeepsake = "Your Call becomes Hades' Aid, which briefly makes you Invisible; your God Gauge starts +100% full",
    FuryAssistTrait = "Summon Megaera to deal damage in an area near the closest foe",
    AchillesPatroclusAssistTrait = "Summon Achilles to deal damage to multiple foes one after another",
    ThanatosAssistTrait = "Summon Thanatos to deal damage in a large area after a brief delay",
    SisyphusAssistTrait = "Summon Sisyphus to deal damage in an area and drop healing items, Darkness, and Obols",
    SkellyAssistTrait = "Your Summon creates a distraction with 1, provoking your foes to attack it until it dies",
    DusaAssistTrait = "Your Summon joins you for 30 Sec, repeatedly firing shots that petrify foes and deal 70 damage",
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

    -- Add keepsake description from hardcoded table (level-aware)
    if traitData.Name and KeepsakeDescriptions[traitData.Name] then
        local desc = KeepsakeDescriptions[traitData.Name]
        if type(desc) == "table" then
            -- Level-dependent description: pick value for current rank
            local level = 1
            if GetKeepsakeLevel then
                local ok, lvl = pcall(GetKeepsakeLevel, traitData.Name)
                if ok and lvl and lvl > 0 then
                    level = lvl
                end
            end
            local value = desc.values[level] or desc.values[1]
            speech = speech .. ". " .. string.format(desc.text, value)
        else
            -- Plain string description (companions)
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

-- Speak when the AwardMenu screen opens
ModUtil.WrapBaseFunction("ShowAwardMenu", function(baseFunc)
    _Log("[SCREEN-OPEN] Keepsake Display Case (ShowAwardMenu)")
    if AccessibilityEnabled and AccessibilityEnabled() then
        _keepsakeOpenSpeech = UIStrings.KeepsakeDisplayCase
    end
    return baseFunc()
end)
