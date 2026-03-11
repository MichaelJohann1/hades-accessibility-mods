--[[
Mod: AccessibleWeaponUpgrade
Author: Accessibility Layer
Version: 1

Provides screen reader accessibility for the Weapon Upgrade Screen (weapon aspects).
- Wraps ShowWeaponUpgradeScreen to speak screen name + weapon + Titan Blood count
- Uses component-name-filtered OnMouseOver for PurchaseButton slots (BoonSlot1-4)
- Speaks aspect name + level + equipped status + cost + affordability + description
- Speaks upgrade confirmation after HandleUpgradeWeaponUpgradeSelection
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
-- Weapon display names (internal weapon name -> display name)
-- ============================================================
local WeaponDisplayNames = {
    SwordWeapon = "Stygian Blade",
    SpearWeapon = "Eternal Spear",
    BowWeapon = "Heart-Seeking Bow",
    ShieldWeapon = "Shield of Chaos",
    FistWeapon = "Twin Fists of Malphon",
    GunWeapon = "Adamant Rail",
}

-- ============================================================
-- Aspect display names (internal trait name -> display name)
-- ============================================================
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

-- ============================================================
-- Aspect descriptions (hardcoded because UseDescription=true)
-- ============================================================
local AspectDescriptions = {
    -- Stygian Blade
    SwordBaseUpgradeTrait = "Your Attack moves are faster and deal more damage per level.",
    SwordCriticalParryTrait = "After you Dash, your next Attack within 2 seconds deals +50% Critical damage, scaling with level.",
    DislodgeAmmoTrait = "Your Special dislodges Bloodstones from foes, dealing damage to them per level.",
    SwordConsecrationTrait = "You have Hallowed Ground around you, which reduces damage and slows foes. Your Attack and Special are replaced with slower, more powerful strikes.",
    -- Eternal Spear
    SpearBaseUpgradeTrait = "Your Dash-Strike deals more damage per level.",
    SpearTeleportTrait = "Your Special is replaced with a teleporting rush. After you Special, you can recall and rush to your previous position.",
    SpearWeaveTrait = "Your Spin Attack hits a wider area and deals bonus damage per level. Charging the Spin activates it in a wider range.",
    SpearSpinTravel = "Your Attack is replaced with a wide, slower sweep. You have -70% Health, but your Attack and Spin Attack restore Health per hit.",
    -- Heart-Seeking Bow
    BowBaseUpgradeTrait = "Your Attack is faster and deals more damage per level.",
    BowMarkHomingTrait = "Your Special seeks the foe most recently struck by your Attack.",
    BowLoadAmmoTrait = "Your Cast loads Bloodstones into your next Attack, which fires them at foes.",
    BowBondTrait = "Your Attack chains to nearby foes, dealing 10% reduced damage per bounce, increasing with level.",
    -- Shield of Chaos
    ShieldBaseUpgradeTrait = "Your Attack deals more damage per level.",
    ShieldRushBonusProjectileTrait = "During your Bull Rush, you shoot a projectile that deals damage per level.",
    ShieldTwoShieldTrait = "Your Special throws a second shield that deals 15 base damage.",
    ShieldLoadAmmoTrait = "Your Cast loads Bloodstones into your next Special, which fires them. You take +10% damage from all sources.",
    -- Twin Fists
    FistBaseUpgradeTrait = "Each of your Dash-Strikes hits twice and deals more damage per level.",
    FistVacuumTrait = "Your Special pulls foes closer and deals more damage per level.",
    FistWeaveTrait = "After landing a Special, your next Attack in the combo deals +40% damage, scaling with level.",
    FistDetonateTrait = "Your Dash-Upper deals more damage per level and creates a Maim effect on foes. Maimed foes take additional damage after a short delay.",
    -- Adamant Rail
    GunBaseUpgradeTrait = "Your Attack fires faster and deals more damage per level.",
    GunGrenadeSelfEmpowerTrait = "Your Attack and Special each deal +5% more damage for each enemy they hit for 4 seconds, scaling with level.",
    GunManualReloadTrait = "Your Attack is replaced with a single powerful shot. Reload manually to increase damage of your next shot by +50%, scaling with level.",
    GunLoadedGrenadeTrait = "Your Special becomes a stationary beam of Hellfire that deals damage to foes, scaling with level. Your Attack channels a large Hellfire ray.",

    -- Base aspect unequipped descriptions
    SwordWeapon_Unequipped = "The base aspect. Equip to enable upgrades.",
    SpearWeapon_Unequipped = "The base aspect. Equip to enable upgrades.",
    BowWeapon_Unequipped = "The base aspect. Equip to enable upgrades.",
    ShieldWeapon_Unequipped = "The base aspect. Equip to enable upgrades.",
    FistWeapon_Unequipped = "The base aspect. Equip to enable upgrades.",
    GunWeapon_Unequipped = "The base aspect. Equip to enable upgrades.",
}

-- ============================================================
-- Build speech for a weapon aspect
-- ============================================================
local function BuildAspectSpeech(weaponName, itemIndex)
    if not weaponName or not itemIndex then return "" end
    if not WeaponUpgradeData or not WeaponUpgradeData[weaponName] then return "" end

    local itemData = WeaponUpgradeData[weaponName][itemIndex]
    if not itemData then return "" end

    local parts = {}

    -- Aspect name
    local aspectName = ""
    local traitName = itemData.TraitName or itemData.RequiredInvestmentTraitName
    if traitName then
        aspectName = AspectDisplayNames[traitName] or SafeGetDisplayName(traitName) or traitName
    end

    -- Check if locked (not yet revealed)
    local isBuyDisabled = IsBuyWeaponUpgradeDisabled and IsBuyWeaponUpgradeDisabled(weaponName, itemIndex)
    local isUpgradeDisabled = IsUpgradeWeaponUpgradeDisabled and IsUpgradeWeaponUpgradeDisabled(weaponName, itemIndex)

    if isBuyDisabled and isUpgradeDisabled then
        parts[#parts + 1] = UIStrings.UnknownAspect .. ", " .. UIStrings.Locked
        return parts[1]
    end

    -- Check if revealed but not met requirements (hidden aspect)
    if isBuyDisabled then
        local lockedName = itemData.LockedUpgradeId or "UnknownUpgrade"
        parts[#parts + 1] = UIStrings.UnknownAspect
        parts[#parts + 1] = UIStrings.RequirementsNotMet
        return parts[1] .. ". " .. parts[2]
    end

    if aspectName ~= "" then
        parts[#parts + 1] = aspectName
    else
        parts[#parts + 1] = string.format(UIStrings.AspectFmt, itemIndex)
    end

    -- Equipped status
    local isEquipped = IsWeaponUpgradeEquipped and IsWeaponUpgradeEquipped(weaponName, itemIndex)
    if isEquipped then
        parts[#parts + 1] = UIStrings.Equipped
    end

    -- Level
    local level = GetWeaponUpgradeLevel and GetWeaponUpgradeLevel(weaponName, itemIndex) or 0
    local isUnlocked = IsWeaponUpgradeUnlocked and IsWeaponUpgradeUnlocked(weaponName, itemIndex)
    local isMaxed = IsWeaponUpgradeMaxed and IsWeaponUpgradeMaxed(weaponName, itemIndex)

    if not isUnlocked then
        parts[#parts + 1] = UIStrings.NotUnlocked
    elseif isMaxed then
        parts[#parts + 1] = string.format(UIStrings.LevelFmt, 5) .. ", " .. UIStrings.MaxLevel
    elseif level > 0 then
        parts[#parts + 1] = string.format(UIStrings.LevelFmt, level)
    end

    -- Cost to upgrade
    local canUpgrade = CanUpgradeWeaponUpgrade and CanUpgradeWeaponUpgrade(weaponName, itemIndex)
    if canUpgrade then
        local cost = GetNextWeaponUpgradeKeyCost and GetNextWeaponUpgradeKeyCost(weaponName, itemIndex) or 0
        if cost > 0 then
            parts[#parts + 1] = string.format(UIStrings.TitanBloodUpgradeFmt, cost)
            local canAfford = HasResource and HasResource("SuperLockKeys", cost)
            if not canAfford then
                parts[#parts + 1] = UIStrings.CannotAfford
            end
        end
    elseif not isUnlocked and not isBuyDisabled then
        local cost = GetNextWeaponUpgradeKeyCost and GetNextWeaponUpgradeKeyCost(weaponName, itemIndex) or 0
        if cost > 0 then
            parts[#parts + 1] = string.format(UIStrings.TitanBloodUnlockFmt, cost)
            local canAfford = HasResource and HasResource("SuperLockKeys", cost)
            if not canAfford then
                parts[#parts + 1] = UIStrings.CannotAfford
            end
        end
    end

    -- Description
    local descKey = traitName
    if descKey and AspectDescriptions[descKey] then
        parts[#parts + 1] = AspectDescriptions[descKey]
    end

    -- Join with separator
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
-- Track which weapon is being shown (set by ShowWeaponUpgradeScreen wrapper)
-- ============================================================
local _currentUpgradeWeapon = nil

-- ============================================================
-- OnMouseOver handler for weapon aspect slots
-- Component names: BoonSlot1_WeaponSelect through BoonSlot4_WeaponSelect
-- ============================================================
OnMouseOver{ "BoonSlot1_WeaponSelect BoonSlot2_WeaponSelect BoonSlot3_WeaponSelect BoonSlot4_WeaponSelect",
    function(triggerArgs)
        if not AccessibilityEnabled or not AccessibilityEnabled() then return end
        if not IsScreenOpen("WeaponUpgradeScreen") then return end
        if not triggerArgs or not triggerArgs.triggeredById then return end
        if not ScreenAnchors.WeaponUpgradeScreen or not ScreenAnchors.WeaponUpgradeScreen.Components then return end

        local weaponName = _currentUpgradeWeapon
        if not weaponName then return end

        -- Find which item index this component belongs to
        local components = ScreenAnchors.WeaponUpgradeScreen.Components
        local itemIndex = nil
        for i = 1, 4 do
            local key = "PurchaseButton" .. i
            if components[key] and components[key].Id == triggerArgs.triggeredById then
                itemIndex = i
                break
            end
        end
        if not itemIndex then return end

        local speech = BuildAspectSpeech(weaponName, itemIndex)
        if speech ~= "" then
            TolkSilence()
            TolkSpeak(speech)
        end
    end
}

-- ============================================================
-- OnMouseOver handler for upgrade arrows (WeaponLevelUpArrowRight, WeaponUnlockRight)
-- ============================================================
OnMouseOver{ "WeaponLevelUpArrowRight WeaponUnlockRight",
    function(triggerArgs)
        if not AccessibilityEnabled or not AccessibilityEnabled() then return end
        if not IsScreenOpen("WeaponUpgradeScreen") then return end
        if not triggerArgs or not triggerArgs.triggeredById then return end
        if not ScreenAnchors.WeaponUpgradeScreen or not ScreenAnchors.WeaponUpgradeScreen.Components then return end

        local weaponName = _currentUpgradeWeapon
        if not weaponName then return end

        -- Find which upgrade button this is
        local components = ScreenAnchors.WeaponUpgradeScreen.Components
        local itemIndex = nil
        for i = 1, 4 do
            local key = "PurchaseButton" .. i .. "Upgrade"
            if components[key] and components[key].Id == triggerArgs.triggeredById then
                itemIndex = i
                break
            end
        end
        if not itemIndex then return end

        local isUnlocked = IsWeaponUpgradeUnlocked and IsWeaponUpgradeUnlocked(weaponName, itemIndex)
        local traitName = WeaponUpgradeData[weaponName][itemIndex].TraitName or WeaponUpgradeData[weaponName][itemIndex].RequiredInvestmentTraitName
        local aspectName = (traitName and AspectDisplayNames[traitName]) or string.format(UIStrings.AspectFmt, itemIndex)
        local cost = GetNextWeaponUpgradeKeyCost and GetNextWeaponUpgradeKeyCost(weaponName, itemIndex) or 0
        local canAfford = HasResource and HasResource("SuperLockKeys", cost)

        local speech = ""
        if isUnlocked then
            speech = string.format(UIStrings.UpgradeAspectFmt, aspectName, cost)
        else
            speech = string.format(UIStrings.UnlockAspectFmt, aspectName, cost)
        end
        if not canAfford then
            speech = speech .. ", " .. UIStrings.CannotAfford
        end

        TolkSilence()
        TolkSpeak(speech)
    end
}

-- ============================================================
-- Wrap ShowWeaponUpgradeScreen to announce screen + weapon
-- ============================================================
ModUtil.WrapBaseFunction("ShowWeaponUpgradeScreen", function(baseFunc, args)
    _Log("[SCREEN-OPEN] Weapon Upgrade (ShowWeaponUpgradeScreen) weapon=" .. tostring(args and args.WeaponName or "nil"))
    local weaponName = args and args.WeaponName or "Unknown"
    _currentUpgradeWeapon = weaponName

    if AccessibilityEnabled and AccessibilityEnabled() then
        local displayName = WeaponDisplayNames[weaponName] or weaponName
        local titanBlood = 0
        if GameState and GameState.Resources and GameState.Resources.SuperLockKeys then
            titanBlood = GameState.Resources.SuperLockKeys
        end
        TolkSilence()
        TolkSpeak(string.format(UIStrings.WeaponAspectsOpenFmt, displayName, titanBlood))
    end

    baseFunc(args)
end)

-- ============================================================
-- Wrap HandleUpgradeWeaponUpgradeSelection to speak result
-- ============================================================
ModUtil.WrapBaseFunction("HandleUpgradeWeaponUpgradeSelection", function(baseFunc, screen, button)
    baseFunc(screen, button)

    if not AccessibilityEnabled or not AccessibilityEnabled() then return end
    if not button then return end

    local weaponName = button.WeaponName
    local itemIndex = button.Index
    if not weaponName or not itemIndex then return end

    -- After the base function, speak updated state
    wait(0.1)
    local speech = BuildAspectSpeech(weaponName, itemIndex)
    if speech ~= "" then
        TolkSilence()
        TolkSpeak(speech)
    end
end)

-- ============================================================
-- Wrap HandleWeaponUpgradeSelection to speak equip result
-- ============================================================
ModUtil.WrapBaseFunction("HandleWeaponUpgradeSelection", function(baseFunc, screen, button)
    local prevEquipped = GetEquippedWeaponTraitIndex and GetEquippedWeaponTraitIndex(button.WeaponName)
    baseFunc(screen, button)

    if not AccessibilityEnabled or not AccessibilityEnabled() then return end
    if not button then return end

    local weaponName = button.WeaponName
    local itemIndex = button.Index
    if not weaponName or not itemIndex then return end

    local nowEquipped = GetEquippedWeaponTraitIndex and GetEquippedWeaponTraitIndex(weaponName)
    if nowEquipped ~= prevEquipped and nowEquipped == itemIndex then
        local traitName = WeaponUpgradeData[weaponName][itemIndex].TraitName or WeaponUpgradeData[weaponName][itemIndex].RequiredInvestmentTraitName
        local aspectName = (traitName and AspectDisplayNames[traitName]) or string.format(UIStrings.AspectFmt, itemIndex)
        TolkSilence()
        TolkSpeak(string.format(UIStrings.EquippedFmt, aspectName))
    end
end)
