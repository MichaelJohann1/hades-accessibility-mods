--[[
Mod: DoorMenu
Author: hllf & JLove
Version: 29

Intended as an accessibility mod. Places all doors in a menu, allowing the player to select a door and be teleported to it.
Use the mod importer to import this mod.
--]]

local function _Log(msg) if LogEvent then LogEvent(msg) end end

OnControlPressed{ "MoveLeft", function(triggerArgs)
    if not AccessibilityEnabled or not AccessibilityEnabled() then return end
    if not OfferedExitDoors or TableLength(OfferedExitDoors) == 0 then
        return
    elseif TableLength(OfferedExitDoors) == 1 and string.find(GetMapName({}), "D_Hub") then
        finalBossDoor = CollapseTable(OfferedExitDoors)[1]
        if finalBossDoor and finalBossDoor.Room and finalBossDoor.Room.Name and finalBossDoor.Room.Name:find("D_Boss", 1, true) == 1 and GetDistance({ Id = 547487, DestinationId = 551569 }) ~= 0 then
            return
        end
    end
    if CurrentRun and CurrentRun.CurrentRoom and CurrentRun.CurrentRoom.ExitsUnlocked and IsScreenOpen("TraitTrayScreen") then
        CloseAdvancedTooltipScreen()
        OpenAssesDoorShowerMenu(CollapseTable(OfferedExitDoors))
    end
end}

local _doorMenuOpen = false
local _doorJustOpened = false

function OpenAssesDoorShowerMenu(doors)
    local curMap = GetMapName({})
    local screen = { Components = {} }
	screen.Name = "BlindAccesibilityDoorMenu"

	if _doorMenuOpen then
		return
	end
	_doorMenuOpen = true
    _Log("[MENU-OPEN] DoorMenu (BlindAccesibilityDoorMenu)")
    OnScreenOpened({ Flag = screen.Name, PersistCombatUI = false })
    --HideCombatUI()
	FreezePlayerUnit()
    EnableShopGamepadCursor()

	PlaySound({ Name = "/SFX/Menu Sounds/ContractorMenuOpen" })
	local components = screen.Components

	components.ShopBackgroundDim = CreateScreenComponent({ Name = "rectangle01", Group = "Asses_UI" })

	-- Close button moved off-screen (Cancel hotkey still works for closing)
	components.CloseButton = CreateScreenComponent({ Name = "ButtonClose", Group = "Asses_UI_Backing", Scale = 0.7 })
	Attach({ Id = components.CloseButton.Id, DestinationId = components.ShopBackgroundDim.Id, OffsetX = -5000, OffsetY = -5000 })
	components.CloseButton.OnPressedFunctionName = "CloseAssesDoorShowerScreen"
	components.CloseButton.ControlHotkey = "Cancel"

	SetScale({ Id = components.ShopBackgroundDim.Id, Fraction = 4 })
	SetColor({ Id = components.ShopBackgroundDim.Id, Color = {0, 0, 0, 1} })


    CreateAssesDoorButtons(screen, doors)

    -- TeleportCursor to first button and speak screen name + first item as one string
    if screen.FirstButtonId then
        _doorJustOpened = true
        TeleportCursor({ DestinationId = screen.FirstButtonId })
        if AccessibilityEnabled and AccessibilityEnabled() and screen.FirstSpeechText then
            TolkSilence()
            TolkSpeak(UIStrings.DoorMenu .. ", " .. screen.FirstSpeechText)
        end
    end

	screen.KeepOpen = true
	HandleScreenInput( screen )

end
local nameToPreviewName = {
    ["HermesUpgrade"] = "Hermes",
    ["HermesUpgrade (Infernal Gate)"] = "Hermes (Infernal Gate)",
    ["RoomRewardMetaPoint"] = "Darkness",
    ["Gem"] = "Gemstones",
    ["LockKey"] = "Chthonic Key",
    ["Gift"] = "Nectar",
    ["RoomRewardMaxHealth"] = "Centaur Heart",
    ["RoomRewardMaxHealth (Infernal Gate)"] = "Centaur Heart (Infernal Gate)",
    ["StackUpgrade"] = "Pom of Power",
    ["StackUpgrade (Infernal Gate)"] = "pom of Power (Infernal Gate)",
    ["WeaponUpgrade"] = "Daedalus Hammer",
    ["RoomRewardMoney"] = "Obols",
    ["RoomRewardMoney (Infernal Gate)"] = "Obols (Infernal Gate)",
    ["SuperLockKey"] = "Titan Blood",
    ["Shop"] = "Charon's Shop",
    ["SuperGem"] = "Diamond",
 	["SuperGift"] = "Ambrosia",
    ["Story"] = "NPC Room",
    ["TrialUpgrade"] = "Chaos Gate",
    ["TrialUpgrade (Infernal Gate)"] = "Chaos Gate (Infernal Gate)",
}
function CreateAssesDoorButtons(screen, doors)
    local xPos = 960
    local startY = 435
    local yIncrement = 75
    local curY = startY
    local components = screen.Components
    components.statsTextBacking = CreateScreenComponent({ 
        Name = "BlankObstacle", 
        Group = "Asses_UI",
        Scale = 1, 
        X = xPos,
        Y = curY
    })
    CreateTextBox({
        Id = components.statsTextBacking.Id,
        Text = "Health: " .. ((CurrentRun and CurrentRun.Hero and CurrentRun.Hero.Health) or 0) .. "/" .. ((CurrentRun and CurrentRun.Hero and CurrentRun.Hero.MaxHealth) or 0),
        FontSize = 24,
        Width = 360,
        OffsetX = 0,
        OffsetY = 0,
        Color = Color.White,
        Font = "AlegreyaSansSCLight",
        Group = "Asses_UI",
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
        Group = "Asses_UI",
        ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 2},
        Justification = "Left",
    })
    curY = curY + yIncrement
    for k, door in pairs(doors) do
        if not door.Room then
            -- Skip doors without Room data (e.g. partially constructed debug doors)
        else
        local showDoor = true
        if string.find(GetMapName({}), "D_Hub") then
            if door.Room.Name:find("D_Boss", 1, true) == 1 and GetDistance({ Id = 547487, DestinationId = 551569 }) ~= 0 then
                showDoor = false
            end
        end
        if showDoor then
            local displayText = ""
            if door.Room.ChosenRewardType == "Devotion" then
                displayText = displayText .. getDoorSound(door, false) .. " "
                displayText = displayText .. getDoorSound(door, true)
            else
                displayText = displayText .. getDoorSound(door, false)
            end
            displayText = nameToPreviewName[displayText] or displayText
            local args = {RoomData = door.Room}
            local rewardOverrides = args.RoomData.RewardOverrides or {}
            local encounterData = args.RoomData.Encounter or {}
            local previewIcon = rewardOverrides.RewardPreviewIcon or encounterData.RewardPreviewIcon or args.RoomData.RewardPreviewIcon
            if previewIcon ~= nil and string.find(previewIcon, "Elite") then
                if previewIcon == "RoomElitePreview4" then
                    displayText = displayText .. " (Boss)"
                elseif previewIcon == "RoomElitePreview2" then
                    displayText = displayText .. " (Mini-Boss)"
                elseif previewIcon == "RoomElitePreview3" then
                    if not string.find(displayText, "(Infernal Gate)")  then
                        displayText = displayText .. " (Infernal Gate)"
                    end
                else
                    displayText = displayText .. " (Elite)"
                end
            end
            local buttonKey = "AssesResourceMenuButton" .. k .. displayText
    
            components[buttonKey] = 
            CreateScreenComponent({ 
                Name = "MarketSlot", 
                Group = "Asses_UI",
                Scale = 0.8, 
                X = xPos,
                Y = curY
            })
            components[buttonKey].OnPressedFunctionName = "AssesDoorMenuSoundSet"
            components[buttonKey].OnMouseOverFunctionName = "OnDoorItemMouseOver"
            components[buttonKey].displayText = displayText
            components[buttonKey].door = door
            AttachLua({ Id = components[buttonKey].Id, Table = components[buttonKey] })

            CreateTextBox({
                Id =components[buttonKey].Id,
                Text = displayText,
                FontSize = 24,
                Width = 720,
                OffsetX = -90,
                OffsetY = 0,
                Color = Color.White,
                Font = "AlegreyaSansSCLight",
                Group="Asses_UI",
                ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 2},
                Justification = "Left",
            })
            if not screen.FirstButtonId then
                screen.FirstButtonId = components[buttonKey].Id
                screen.FirstSpeechText = displayText
            end
            curY = curY + yIncrement
        end
        end -- end of door.Room nil check
    end
end

function OnDoorItemMouseOver(button)
    if not AccessibilityEnabled or not AccessibilityEnabled() or not button then return end
    if _doorJustOpened then _doorJustOpened = false return end
    local speech = button.displayText or "Unknown"
    _Log("[NAV] DoorMenu item: " .. speech)
    TolkSilence()
    TolkSpeak(speech)
end

function CloseAssesDoorShowerScreen( screen, button )
	_Log("[MENU-CLOSE] DoorMenu (BlindAccesibilityDoorMenu)")
	PlaySound({ Name = "/SFX/Menu Sounds/ContractorMenuClose" })
	CloseScreen( GetAllIds( screen.Components ) )
    ShowCombatUI()
	UnfreezePlayerUnit()
	screen.KeepOpen = false
	_doorMenuOpen = false
	OnScreenClosed({ Flag = screen.Name })
end

function AssesDoorMenuSoundSet(screen, button)
    PlaySound({ Name = "/SFX/Menu Sounds/ContractorItemPurchase" })
    CloseAssesDoorShowerScreen(screen, button)
    doDefaultSound(button.door)
end

function doDefaultSound(door)
    Teleport({ Id = CurrentRun.Hero.ObjectId, DestinationId = door.ObjectId })
end

function getDoorSound(door, devotionSlot)
    local room = door.Room
    if not room then return "Unknown" end
    if room.Name == "FinalBossExitDoor" or room.Name == "E_Intro" then
        return "Greece"
    elseif room.NextRoomSet and room.Name:find("D_Boss", 1, true) ~= 1 then
        return "Stairway"
    elseif room.Name:find("_Intro", 1, true) ~= nil then
        return "Next Biome"
    elseif HasHeroTraitValue("HiddenRoomReward") then
        return "Enshrouded"
    elseif room.ChosenRewardType == nil then
        return "Enshrouded"
    elseif room.ChosenRewardType == "Boon" and room.ForceLootName then
        if LootData[room.ForceLootName].DoorIcon ~= nil then
            local godName = LootData[room.ForceLootName].DoorIcon:sub(11, -1)
            godName = godName:gsub("Isometric", "")
            godName = godName:gsub("Base", "Zeus")
if door.Name == "ShrinePointDoor" then
godName = godName .. " (Infernal Gate)"
end
            return godName
        end
    elseif room.ChosenRewardType == "Devotion" then
        local devotionLootName = room.Encounter.LootAName
        if devotionSlot == true then
            devotionLootName = room.Encounter.LootBName
        end
        devotionLootName = devotionLootName:gsub("Progress", ""):gsub("Drop", ""):gsub("Run", ""):gsub("Upgrade", "")
        return devotionLootName
    else
        local resourceName =  room.ChosenRewardType:gsub("Progress", ""):gsub("Drop", ""):gsub("Run", "")
if door.Name == "ShrinePointDoor" then
resourceName  = resourceName .. " (Infernal Gate)"
end
        return resourceName
    end
end

