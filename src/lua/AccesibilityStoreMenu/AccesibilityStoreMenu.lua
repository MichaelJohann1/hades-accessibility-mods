--[[
Mod: ShopMenu
Author: hllf & JLove
Version: 28

Intended as an accessibility mod. Places all shop items in a menu, allowing the player to select an item and be teleported to it.
Use the mod importer to import this mod.
--]]

local function _Log(msg) if LogEvent then LogEvent(msg) end end

OnControlPressed{"MoveRight", function(triggerArgs)
    if not AccessibilityEnabled or not AccessibilityEnabled() then return end
    local curMap = GetMapName({})
    if not string.find(curMap, "Shop") and not string.find(curMap, "PreBoss") and not string.find(curMap, "D_Hub") then
        return
    end
    if CurrentRun.CurrentRoom.Store == nil then
        return
    elseif NumUseableObjects(CurrentRun.CurrentRoom.Store.SpawnedStoreItems) == 0 then
        return
    end
    if IsScreenOpen("TraitTrayScreen") then
        CloseAdvancedTooltipScreen()
        OpenStoreMenu(CurrentRun.CurrentRoom.Store.SpawnedStoreItems)
    end
end}

function NumUseableObjects(objects)
    local count = 0
    if objects ~= nil then
        for k, object in pairs(objects) do
            if object.ObjectId ~= nil and IsUseable({Id = object.ObjectId}) and object.Name ~= "ForbiddenShopItem" then
                count = count + 1
            end
        end
    end
    return count
end

local _storeMenuOpen = false

function OpenStoreMenu(items)
    local curMap = GetMapName({})
    local screen = { Components = {} }
	screen.Name = "BlindAccesibilityStoreMenu"

	if _storeMenuOpen then
		return
	end
	_storeMenuOpen = true
    _Log("[MENU-OPEN] StoreMenu (BlindAccesibilityStoreMenu)")
    OnScreenOpened({ Flag = screen.Name, PersistCombatUI = false })
    HideCombatUI()
	FreezePlayerUnit()
    EnableShopGamepadCursor()

	PlaySound({ Name = "/SFX/Menu Sounds/ContractorMenuOpen" })
	local components = screen.Components

	components.ShopBackgroundDim = CreateScreenComponent({ Name = "rectangle01", Group = "Asses_UI_Store" })

	-- Close button moved off-screen (Cancel hotkey still works for closing)
	components.CloseButton = CreateScreenComponent({ Name = "ButtonClose", Group = "Asses_UI_Store_Backing", Scale = 0.7 })
	Attach({ Id = components.CloseButton.Id, DestinationId = components.ShopBackgroundDim.Id, OffsetX = -5000, OffsetY = -5000 })
	components.CloseButton.OnPressedFunctionName = "CloseItemScreen"
	components.CloseButton.ControlHotkey = "Cancel"

	SetScale({ Id = components.ShopBackgroundDim.Id, Fraction = 4 })
	SetColor({ Id = components.ShopBackgroundDim.Id, Color = {0, 0, 0, 1} })


    CreateItemButtons(screen, items)
	screen.KeepOpen = true
	HandleScreenInput( screen )

end

local nameToPreviewName = {
    ["HermesUpgrade"] = "Hermes",
    ["MetaPoint"] = "25 Darkness",
    ["Gem"] = "20 Gemstones",
    ["LockKey"] = "Chthonic Key",
    ["Gift"] = "Nectar",
    ["RoomRewardMaxHealth"] = "Centaur Heart",
    ["StackUpgrade"] = "Pom of Power",
    ["StackUpgradeRare"] = "Double Pom of Power",
    ["WeaponUpgrade"] = "Daedalus Hammer",
    ["ChaosWeaponUpgrade"] = "Anvil of Fates",
    ["RoomRewardMoney"] = "Obols",
    ["SuperLockKey"] = "Titan Blood",
    ["SuperGem"] = "Diamond",
 	["SuperGift"] = "Ambrosia",
    ["BlindBoxLoot"] = "Random God Boon",
    ["RoomRewardHeal"] = "Food",
    ["RandomStack"] = "Pom Slice",
}

function OnStoreItemMouseOver(button)
    if not AccessibilityEnabled or not AccessibilityEnabled() or not button then return end
    local speech = button.displayText or "Unknown"
    _Log("[NAV] StoreMenu item: " .. speech)
    TolkSilence()
    TolkSpeak(speech)
end

function CreateItemButtons(screen, items)
    local xPos = 960
    local startY = 235
    local yIncrement = 75
    local curY = startY
    local components = screen.Components
    components.statsTextBacking = CreateScreenComponent({
        Name = "BlankObstacle",
        Group = "Asses_UI_Store",
        Scale = 1,
        X = xPos,
        Y = curY
    })
    CreateTextBox({
        Id = components.statsTextBacking.Id,
        Text = "Health: " .. (CurrentRun.Hero.Health or 0) .. "/" .. (CurrentRun.Hero.MaxHealth or 0),
        FontSize = 24,
        Width = 360,
        OffsetX = 0,
        OffsetY = 0,
        Color = Color.White,
        Font = "AlegreyaSansSCLight",
        Group = "Asses_UI_Store",
        ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 2},
        Justification = "Left",
    })
    curY = curY + yIncrement
    CreateTextBox({
        Id = components.statsTextBacking.Id,
        Text = "Obols: " .. ((CurrentRun or {Money = 0}).Money or 0),
        FontSize = 24,
        Width = 360,
        OffsetX = 0,
        OffsetY = yIncrement,
        Color = Color.White,
        Font = "AlegreyaSansSCLight",
        Group = "Asses_UI_Store",
        ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 2},
        Justification = "Left",
    })
    curY = curY + yIncrement
    for k, item in pairs(items) do
        if IsUseable({Id = item.ObjectId}) and item.Name ~= "ForbiddenShopItem" then
            local displayText = item.Name
            local buttonKey = "AssesShopMenuButton" .. k .. displayText
            components[buttonKey] =
            CreateScreenComponent({
                Name = "MarketSlot",
                Group = "Asses_UI_Store",
                Scale = 0.8,
                X = xPos,
                Y = curY
            })
            components[buttonKey].index = k
            components[buttonKey].item = item
            components[buttonKey].OnPressedFunctionName = "MoveToItem"
            components[buttonKey].OnMouseOverFunctionName = "OnStoreItemMouseOver"
            displayText = nameToPreviewName[displayText:gsub("Drop", ""):gsub("StoreReward", "")] or displayText
            components[buttonKey].displayText = displayText .. ": " .. item.Cost .. " Obols"
            AttachLua({ Id = components[buttonKey].Id, Table = components[buttonKey] })
            CreateTextBox({
                Id =components[buttonKey].Id,
                Text = displayText .. ": " .. item.Cost .. " Obols",
                FontSize = 24,
                Width = 520,
                OffsetX = -320,
                OffsetY = 0,
                Color = Color.White,
                Font = "AlegreyaSansSCLight",
                Group = "Asses_UI_Store",
                ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 2},
                Justification = "Left",
            })
            if not screen.FirstButtonId then
                screen.FirstButtonId = components[buttonKey].Id
                screen.FirstSpeechText = components[buttonKey].displayText
            end
            curY = curY + yIncrement
        end
    end
    -- TeleportCursor to first button and speak screen name + first item
    if screen.FirstButtonId then
        TeleportCursor({ DestinationId = screen.FirstButtonId })
        if AccessibilityEnabled and AccessibilityEnabled() and screen.FirstSpeechText then
            TolkSilence()
            TolkSpeak(UIStrings.StoreMenu .. ", " .. screen.FirstSpeechText)
        end
    end
end

function MoveToItem(screen, button)
PlaySound({ Name = "/SFX/Menu Sounds/ContractorItemPurchase" })
CloseItemScreen( screen, button )
local ItemID = button.item.ObjectId
if ItemID ~= nil then
Teleport({ Id = CurrentRun.Hero.ObjectId, DestinationId = ItemID})
end
end

function CloseItemScreen( screen, button )
	_Log("[MENU-CLOSE] StoreMenu (BlindAccesibilityStoreMenu)")
	PlaySound({ Name = "/SFX/Menu Sounds/ContractorMenuClose" })
	CloseScreen( GetAllIds( screen.Components ) )
    ShowCombatUI()
	UnfreezePlayerUnit()
	screen.KeepOpen = false
	_storeMenuOpen = false
	OnScreenClosed({ Flag = screen.Name })
end

ModUtil.WrapBaseFunction("CheckForbiddenShopItem", function(baseFunc, eventSource, args)
	local spawnOnId = GetClosest({ Id = CurrentRun.Hero.ObjectId, DestinationName = "ForbiddenShopItemSpawnPoint" })
	if spawnOnId == nil or spawnOnId == 0 then
		return
	end

	CurrentRun.ForbiddenShopItemOffered = true

	local consumableName = "ForbiddenShopItem"
	local playerId = GetIdsByType({ Name = "_PlayerUnit" })
	local consumableId = SpawnObstacle({ Name = consumableName, DestinationId = spawnOnId, Group = "Standing" })
	local consumable = CreateConsumableItem( consumableId, consumableName, 0 )
	if consumable.DropMoney ~= nil then
		consumable.DropMoney = round( consumable.DropMoney * GetTotalHeroTraitValue( "MoneyMultiplier", { IsMultiplier = true } ))
	end

	-- Function modification by hllf: Modify next line
	table.insert( CurrentRun.CurrentRoom.Store.SpawnedStoreItems, { ObjectId = consumableId, Cost = consumable.Cost, Name = consumableName } )
	SetObstacleProperty({ Property = "MagnetismWhileBlocked", Value = 0, DestinationId = consumableId })

	local shopIds = GetInactiveIds({ Name = "ForbiddenShop" })
	Activate({ Ids = shopIds })

end)

ModUtil.WrapBaseFunction("SpawnStoreItemInWorld", function(baseFunc, itemData, kitId)
	local spawnedItem = nil
	if itemData.Name == "StackUpgradeDrop" then
		spawnedItem = CreateStackLoot({ SpawnPoint = kitId, Cost = GetProcessedValue( ConsumableData.StackUpgradeDrop.Cost ), DoesNotBlockExit = true, SuppressSpawnSounds = true, } )
	elseif itemData.Name == "WeaponUpgradeDrop" then
		spawnedItem = CreateWeaponLoot({ SpawnPoint = kitId, Cost = itemData.Cost or GetProcessedValue( ConsumableData.WeaponUpgradeDrop.Cost ), DoesNotBlockExit = true, SuppressSpawnSounds = true, } )
	elseif itemData.Name == "HermesUpgradeDrop" then
		spawnedItem = CreateHermesLoot({ SpawnPoint = kitId, Cost = itemData.Cost or GetProcessedValue( ConsumableData.HermesUpgradeDrop.Cost ), DoesNotBlockExit = true, SuppressSpawnSounds = true, BoughtFromShop = true, AddBoostedAnimation = itemData.AddBoostedAnimation, BoonRaritiesOverride = itemData.BoonRaritiesOverride })
		spawnedItem.CanReceiveGift = false
		SetThingProperty({ Property = "SortBoundsScale", Value = 1.0, DestinationId = spawnedItem.ObjectId })
	elseif itemData.Name == "StoreTrialUpgradeDrop" then
		local args  = { BoughtFromShop = true, DoesNotBlockExit = true, Cost = GetProcessedValue( ConsumableData.StoreTrialUpgradeDrop.Cost ) }
		args.SpawnPoint = kitId
		args.DoesNotBlockExit = true
		args.SuppressSpawnSounds = true
		args.Name = "TrialUpgrade"
		spawnedItem = GiveLoot( args )
		spawnedItem.CanReceiveGift = false
		SetThingProperty({ Property = "SortBoundsScale", Value = 1.0, DestinationId = spawnedItem.ObjectId })
	elseif itemData.Name == "StackUpgradeDropRare" then
		spawnedItem = CreateStackLoot({ SpawnPoint = kitId, Cost = GetProcessedValue( ConsumableData.StackUpgradeDropRare.Cost ), DoesNotBlockExit = true, SuppressSpawnSounds = true, StackNum = 2, AddBoostedAnimation = true, })
	elseif itemData.Type == "Consumable" then
		local consumablePoint = SpawnObstacle({ Name = itemData.Name, DestinationId = kitId, Group = "Standing" })
		local upgradeData =  GetRampedConsumableData( ConsumableData[itemData.Name] )
		spawnedItem = CreateConsumableItemFromData( consumablePoint, upgradeData )
		ApplyConsumableItemResourceMultiplier( CurrentRun.CurrentRoom, spawnedItem )
		ExtractValues( CurrentRun.Hero, spawnedItem, spawnedItem )
	elseif itemData.Type == "Boon" then
		itemData.Args.SpawnPoint = kitId
		itemData.Args.DoesNotBlockExit = true
		itemData.Args.SuppressSpawnSounds = true
		itemData.Args.SuppressFlares = true
		spawnedItem = GiveLoot( itemData.Args )
		spawnedItem.CanReceiveGift = false
		SetThingProperty({ Property = "SortBoundsScale", Value = 1.0, DestinationId = spawnedItem.ObjectId })
	end
	if spawnedItem ~= nil then
		SetObstacleProperty({ Property = "MagnetismWhileBlocked", Value = 0, DestinationId = spawnedItem.ObjectId })
		spawnedItem.SpawnPointId = kitId
		spawnedItem.UseText = spawnedItem.PurchaseText or "Shop_UseText"
		-- Function modification by hllf: Insert next 4 lines
		name = itemData.Name
		if itemData.Args ~= nil and itemData.Args.ForceLootName then
			name = itemData.Args.ForceLootName:gsub("Upgrade", ""):gsub("Drop", "")
		end
		-- Function modification by hllf: Modify next line
		table.insert( CurrentRun.CurrentRoom.Store.SpawnedStoreItems, { ObjectId = spawnedItem.ObjectId, Cost = spawnedItem.Cost, Name = name } )
	end

end)
