--[[
Mod: ResourceMenu
Author: hllf & JLove
Version: 27

Intended as an accessibility mod. Places game resources and other related information in a menu.
Use the mod importer to import this mod.
--]]

local function _Log(msg) if LogEvent then LogEvent(msg) end end

-- Navigation: same approach as AccessibleBroker (simple OnMouseOver + TolkSpeak).
-- No FreeFormSelect config overrides, no boundary threads.

OnControlPressed{ "MoveUp", function(triggerArgs)
    if not AccessibilityEnabled or not AccessibilityEnabled() then return end
    if IsScreenOpen("TraitTrayScreen") then
        CloseAdvancedTooltipScreen()
        OpenAssesResourceShowerMenu()
    end
end}

OnControlPressed{ "Attack3", function(triggerArgs)
    if not AccessibilityEnabled or not AccessibilityEnabled() then return end
    local curMap = GetMapName({})
    if curMap:find("DeathArea", 1, true) == 1 or curMap:find("E_", 1, true) == 1 then
        OpenAssesResourceShowerMenu()
    end
end}

OnControlPressed{ "AdvancedTooltip", function(triggerArgs)
    if not AccessibilityEnabled or not AccessibilityEnabled() then return end
    -- When Codex is open, let the native UIScripts.lua handler open boon info.
    -- Do NOT call AttemptOpenCodexBoonInfo — handlers stack, so duplicating
    -- the call creates duplicate BoonInfoScreens.
    if IsScreenOpen("Codex") then
        return
    end
    local curMap = GetMapName({})
    if curMap:find("DeathArea", 1, true) == 1 or curMap:find("E_", 1, true) == 1 then
        return
    end
    if ( not IsInputAllowed({}) and not GameState.WaitingForChoice ) or ( CurrentDeathAreaRoom ~= nil and CurrentDeathAreaRoom.ShowResourceUIOnly ) then
        return
    end
    if ( CurrentRun ~= nil and CurrentRun.Hero ~= nil and ( IsEmpty( CurrentRun.Hero.Traits ) and GetTotalSpentMetaPoints() == 0 ) ) then
        if ScreenAnchors.TraitTrayScreen ~= nil and ScreenAnchors.TraitTrayScreen.CanClose then
            CloseAdvancedTooltipScreen()
        else
            ShowDepthCounter()
            ShowAdvancedTooltip( { AutoPin = false, } )
        end
    end
end}

local _resourceMenuOpen = false

function OpenAssesResourceShowerMenu(usee)
	local screen = { Components = {} }
	screen.Name = "BlindAccesibilityResourceMenu"

	if _resourceMenuOpen then
		return
	end
	_resourceMenuOpen = true
    _Log("[MENU-OPEN] ResourceMenu (BlindAccesibilityResourceMenu)")
    OnScreenOpened({ Flag = screen.Name, PersistCombatUI = false })
    HideCombatUI()
	FreezePlayerUnit()
	EnableShopGamepadCursor()

	PlaySound({ Name = "/SFX/Menu Sounds/ContractorMenuOpen" })
	local components = screen.Components

	components.ShopBackgroundDim = CreateScreenComponent({ Name = "rectangle01", Group = "Asses_UI" })

	-- Close button moved off-screen (Cancel hotkey still works for closing)
	components.CloseButton = CreateScreenComponent({ Name = "ButtonClose", Group = "Asses_UI_Backing", Scale = 0.7 })
	Attach({ Id = components.CloseButton.Id, DestinationId = components.ShopBackgroundDim.Id, OffsetX = -5000, OffsetY = -5000 })
	components.CloseButton.OnPressedFunctionName = "CloseAssesResourceShowerScreen"
	components.CloseButton.ControlHotkey = "Cancel"

	SetScale({ Id = components.ShopBackgroundDim.Id, Fraction = 4 })
	SetColor({ Id = components.ShopBackgroundDim.Id, Color = {0, 0, 0, 1} })

    CreateAssesResourceText(screen)

    -- TeleportCursor to first button and speak screen name + first item
    if screen.FirstButtonId then
        TeleportCursor({ DestinationId = screen.FirstButtonId })
        if AccessibilityEnabled and AccessibilityEnabled() and screen.FirstSpeechText then
            TolkSilence()
            TolkSpeak(UIStrings.ResourceInfo .. ", " .. screen.FirstSpeechText)
        end
    end

	screen.KeepOpen = true
	HandleScreenInput( screen )

end

local keepsakeTraitToName = {
    ["MaxHealthKeepsakeTrait"] = "Cerberus's Old Spiked Collar",
    ["DirectionalArmorTrait"] = "Achilles's Myrmidon Bracer",
    ["BackstabAlphaStrikeTrait"] = "Nyx's Black Shawl",
    ["PerfectClearDamageBonusTrait"] = "Thanatos's Pierced Butterfly",
    ["ShopDurationTrait"] = "Charon's Bone Hourglass",
    ["BonusMoneyTrait"] = "Hypnos's Chthonic Coin Purse",
    ["LowHealthDamageTrait"] = "Meg's Skull Earring",
    ["DistanceDamageTrait"] = "Orpheus's Distant Memory",
    ["LifeOnUrnTrait"] = "Dusa's Harpy Feather Duster",
    ["ReincarnationTrait"] = "Skelly's Lucky Tooth",
    ["ForceZeusBoonTrait"] = "Zeus's Thunder Signet",
    ["ForcePoseidonBoonTrait"] = "Poseidon's Conch Shell",
    ["ForceAthenaBoonTrait"] = "Athena's Owl Pendant",
    ["ForceAphroditeBoonTrait"] = "Aphrodite's Eternal Rose",
    ["ForceAresBoonTrait"] = "Ares's Blood-Filled Vial",
    ["ForceArtemisBoonTrait"] = "Artemis's Adamant Arrowhead",
    ["ForceDionysusBoonTrait"] = "Dionysus's Overflowing Cup",
    ["FastClearDodgeBonusTrait"] = "Hermes's Lambent Plume",
    ["ForceDemeterBoonTrait"] = "Demeter's Frostbitten Horn",
    ["ChaosBoonTrait"] = "Chaos's Cosmic Egg",
    ["VanillaTrait"] = "Sisyphus's Shattered Shackle",
    ["ShieldBossTrait"] = "Eurydice's Evergreen Acorn",
    ["ShieldAfterHitTrait"] = "Patroclus's Broken Spearpoint",
    ["ChamberStackTrait"] = "Persephone's Pom Blossom",
    ["HadesShoutKeepsake"] = "Hades's Sigil of the Dead",
    ["FuryAssistTrait"] = "Battie",
    ["ThanatosAssistTrait"] = "Mort",
    ["SkellyAssistTrait"] = "Rib",
    ["SisyphusAssistTrait"] = "Shady",
    ["DusaAssistTrait"] = "Fidi",
    ["AchillesPatroclusAssistTrait"] = "Antos",
}

function OnResourceItemMouseOver(button)
    if not AccessibilityEnabled or not AccessibilityEnabled() or not button then return end
    local speech = button.displayText or "Unknown"
    _Log("[NAV] ResourceMenu item: " .. speech)
    TolkSilence()
    TolkSpeak(speech)
end

function CreateAssesResourceText(screen)
    local startY = 300
    local yIncrement = 55
    local curY = startY
    local components = screen.Components
    local itemIndex = 0

    local codeToDisplayName = {
        {["key"] = "MetaPoints", ["value"] = "Darkness"},
        {["key"] = "Gems", ["value"] = "Gemstones"},
        {["key"] = "LockKeys", ["value"] = "Chthonic Keys"},
        {["key"] = "GiftPoints", ["value"] = "Nectar"},
        {["key"] = "SuperGems", ["value"] = "Diamonds"},
        {["key"] = "SuperGiftPoints", ["value"] = "Ambrosia"},
        {["key"] = "SuperLockKeys", ["value"] = "Titan Blood"},
    }
    local nameToWeaponDisplayInfo = {
        SwordWeapon = {
            Name = "Stygian Blade",
            Aspect = {"Zagreus", "Nemesis", "Poseidon", "Arthur"}
        },
        BowWeapon = {
            Name = "Heart-Seeking Bow",
            Aspect = {"Zagreus", "Chiron", "Hera", "Rama"}
        },
        SpearWeapon = {
            Name = "Eternal Spear",
            Aspect = {"Zagreus", "Achilles", "Hades", "Guan Yu"}
        },
        GunWeapon = {
            Name = "Adamant Rail",
            Aspect = {"Zagreus", "Eris", "Hestia", "Lucifer"}
        },
        FistWeapon = {
            Name = "Twin Fists",
            Aspect = {"Zagreus", "Talos", "Demeter", "Gilgamesh"}
        },
        ShieldWeapon = {
            Name = "Shield of Chaos",
            Aspect = {"Zagreus", "Chaos", "Zeus", "Beowulf"}
        },
    }

    -- Helper to create one navigable line
    local function addLine(displayText)
        itemIndex = itemIndex + 1
        local key = "ResourceItem" .. itemIndex
        components[key] = CreateScreenComponent({
            Name = "MarketSlot",
            Group = "Asses_UI",
            Scale = 0.8,
            X = 960,
            Y = curY
        })
        components[key].displayText = displayText
        components[key].OnMouseOverFunctionName = "OnResourceItemMouseOver"
        AttachLua({ Id = components[key].Id, Table = components[key] })
        CreateTextBox({
            Id = components[key].Id,
            Text = displayText,
            FontSize = 24,
            Width = 720,
            OffsetX = -320,
            OffsetY = 0,
            Color = Color.White,
            Font = "AlegreyaSansSCLight",
            Group = "Asses_UI",
            ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 2},
            Justification = "Left",
        })
        if not screen.FirstButtonId then
            screen.FirstButtonId = components[key].Id
            screen.FirstSpeechText = displayText
        end
        curY = curY + yIncrement
    end

    local curMap = GetMapName({})
    local isRun = not string.find(curMap, "RoomPreRun") and curMap:find("DeathArea", 1, true) ~= 1 and curMap:find("E_", 1, true) ~= 1

    if isRun then
        addLine("Chamber: " .. GetRunDepth( CurrentRun ))
    end

    addLine("Health: " .. (CurrentRun.Hero.Health or 0) .. "/" .. (CurrentRun.Hero.MaxHealth or 0))

    if not string.find(curMap, "RoomPreRun") and curMap:find("DeathArea", 1, true) ~= 1 then
        addLine("Death Defiances: " .. (#CurrentRun.Hero.LastStands or 0))
        if GetNumMetaUpgrades( "RerollMetaUpgrade" ) + GetNumMetaUpgrades("RerollPanelMetaUpgrade") > 0 then
            addLine("Fated Rerolls: " .. (CurrentRun.NumRerolls or 0))
        end
        addLine("Obols: " .. ((CurrentRun or {Money = 0}).Money or 0))
    end
    if GameState.LastAwardTrait ~= nil and HeroHasTrait(GameState.LastAwardTrait) then
        addLine("Keepsake: " .. (keepsakeTraitToName[GameState.LastAwardTrait] or GameState.LastAwardTrait))
        local levelText
        if IsKeepsakeMaxed(GameState.LastAwardTrait) then
            levelText = GetKeepsakeLevel(GameState.LastAwardTrait) .. " (maxed)"
        else
            levelText = GetKeepsakeLevel(GameState.LastAwardTrait) .. " (" .. GetKeepsakeChambersToNextLevel(GameState.LastAwardTrait) .. " encounters to next level)"
        end
        addLine("Keepsake Level: " .. levelText)
    end
    if GameState.LastAssistTrait ~= nil and HeroHasTrait(GameState.LastAssistTrait) then
        local remainingUses = 0
        for i, traitData in pairs( CurrentRun.Hero.Traits ) do
            if traitData.AddAssist and traitData.RemainingUses ~= nil then
                remainingUses = traitData.RemainingUses
            end
        end
        addLine("Companion: " .. (keepsakeTraitToName[GameState.LastAssistTrait] or GameState.LastAssistTrait) .. " (Level " .. GetKeepsakeLevel(GameState.LastAssistTrait) .. ", Uses " .. remainingUses .. ")")
    end
    if GetEquippedWeapon() ~= nil then
        local weapon = GetEquippedWeapon()
        local weaponAspect = GetEquippedWeaponTraitIndex(weapon)
        local weaponAspectLevel = GetWeaponUpgradeLevel(weapon, weaponAspect)
        weaponAspect = nameToWeaponDisplayInfo[weapon].Aspect[weaponAspect]
        weapon = nameToWeaponDisplayInfo[weapon].Name
        addLine("Weapon: " .. weapon .. ", Aspect: " .. weaponAspect .. ", Level: " .. weaponAspectLevel)
    end
    for kKey,vValue in pairs(codeToDisplayName) do
        k = vValue["key"]
        v = vValue["value"]
        addLine(v .. ": " .. (GameState.Resources[k] or 0))
    end

end

function CloseAssesResourceShowerScreen( screen, button )
	_Log("[MENU-CLOSE] ResourceMenu (BlindAccesibilityResourceMenu)")
	PlaySound({ Name = "/SFX/Menu Sounds/ContractorMenuClose" })
	CloseScreen( GetAllIds( screen.Components ) )

	UnfreezePlayerUnit()
	screen.KeepOpen = false
	_resourceMenuOpen = false
	OnScreenClosed({ Flag = screen.Name })
end

-- Global: silence speech when ANY screen closes (covers all custom + native menus)
ModUtil.WrapBaseFunction("OnScreenClosed", function(baseFunc, args)
    if TolkSilence then TolkSilence() end
    return baseFunc(args)
end)