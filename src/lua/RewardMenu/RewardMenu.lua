--[[
Mod: RewardMenu
Author: hllf & JLove
Version: 30

Intended as an accessibility mod. Places all interactable rewards, NPCs, and other relevant items in a menu, allowing the player to select one and be teleported to it.
Use the mod importer to import this mod.
--]]

local function _Log(msg) if LogEvent then LogEvent(msg) end end

local _rewardMenuOpen = false

-- MoveDown handler — opens reward menu during runs (requires TraitTrayScreen open first)
OnControlPressed{ "MoveDown", function(triggerArgs)
    if not AccessibilityEnabled or not AccessibilityEnabled() then
        return
    end
    if IsScreenOpen("TraitTrayScreen") then
        local rewardsTable = {}
        local curMap = GetMapName({})
        local ok, result
        if string.find(curMap, "RoomPreRun") then
            local weapons = (MapState and MapState.WeaponKits) or {}
            ok, result = pcall(ProcessTable, weapons)
        else
            ok, result = pcall(ProcessTable, ActivatedObjects or {})
        end
        if ok then
            rewardsTable = result
        end
        if rewardsTable and TableLength(rewardsTable) > 0 then
            CloseAdvancedTooltipScreen()
            OpenRewardMenu(rewardsTable)
        end
    end
end}

-- AdvancedTooltip (B/Select) handler — opens reward menu in house areas directly
-- In the courtyard and during runs, MoveDown + TraitTrayScreen is used instead
-- IMPORTANT: Codex check MUST come before DeathArea check — Codex can be opened
-- from any room. Do NOT call AttemptOpenCodexBoonInfo here — the native
-- UIScripts.lua handler already does that. OnControlPressed handlers stack,
-- so calling it from multiple handlers creates duplicate BoonInfoScreens.
OnControlPressed{ "AdvancedTooltip", function(triggerArgs)
    if not AccessibilityEnabled or not AccessibilityEnabled() then return end
    -- When Codex is open, let the native handler open boon info
    if IsScreenOpen("Codex") then
        return
    end
    local curMap = GetMapName({})
    -- Only in house areas (main hall, bedroom, office) or surface (Greece) — NOT courtyard or run rooms
    if curMap:find("DeathArea", 1, true) ~= 1 and curMap:find("E_", 1, true) ~= 1 then
        return
    end
    if _rewardMenuOpen then return end
    local rewardsTable = {}
    local ok, result = pcall(ProcessTable, ActivatedObjects or {})
    if ok then
        rewardsTable = result
    end
    if rewardsTable and TableLength(rewardsTable) > 0 then
        OpenRewardMenu(rewardsTable)
    end
end}

local nameToPreviewName = {
    -- Resources
    ["RoomRewardMetaPoint"] = "Darkness",
    ["RoomRewardMetaPointRunProgress"] = "Darkness (Pitch-Black)",
    ["MetaPoints"] = "Darkness",
    ["Gem"] = "Gemstones",
    ["GemRunProgress"] = "Gemstones (Brilliant)",
    ["Gems"] = "Gemstones",
    ["LockKey"] = "Chthonic Key",
    ["LockKeyRunProgress"] = "Chthonic Key (Fated)",
    ["Gift"] = "Nectar",
    ["GiftRunProgress"] = "Nectar (Vintage)",
    ["SuperLockKey"] = "Titan Blood",
    ["SuperGem"] = "Diamond",
    ["SuperGift"] = "Ambrosia",
    ["RoomRewardMoney"] = "Charon's Obol",
    ["Money"] = "Charon's Obol",
    -- Run items
    ["RoomRewardMaxHealth"] = "Centaur Heart",
    ["StackUpgrade"] = "Pom of Power",
    ["WeaponUpgrade"] = "Daedalus Hammer",
    ["CerberusKey"] = "Satyr Sack",
    -- Boon providers
    ["ZeusUpgrade"] = "Zeus",
    ["PoseidonUpgrade"] = "Poseidon",
    ["AthenaUpgrade"] = "Athena",
    ["AphroditeUpgrade"] = "Aphrodite",
    ["AresUpgrade"] = "Ares",
    ["ArtemisUpgrade"] = "Artemis",
    ["DionysusUpgrade"] = "Dionysus",
    ["DemeterUpgrade"] = "Demeter",
    ["TrialUpgrade"] = "Chaos Gate",
    ["HermesUpgrade"] = "Hermes",
    -- Fountains
    ["HealthFountain"] = "Fountain",
    ["HealthFountainAsphodel"] = "Fountain",
    ["HealthFountainElysium"] = "Fountain",
    ["HealthFountainStyx"] = "Fountain",
    -- Weapons (Infernal Arms)
    ["SwordWeapon"] = "Stygian Blade",
    ["BowWeapon"] = "Heart-Seeking Bow",
    ["SpearWeapon"] = "Eternal Spear",
    ["GunWeapon"] = "Adamant Rail",
    ["FistWeapon"] = "Twin Fists of Malphon",
    ["ShieldWeapon"] = "Shield of Chaos",
    -- NPCs (Chthonic)
    ["NPC_Achilles_01"] = "Achilles",
    ["NPC_Nyx_01"] = "Nyx",
    ["NPC_Nyx_Field_01"] = "Nyx",
    ["NPC_Hypnos_01"] = "Hypnos",
    ["NPC_Dusa_01"] = "Dusa",
    ["NPC_Orpheus_01"] = "Orpheus",
    ["NPC_Megaera_01"] = "Megaera",
    ["NPC_Thanatos_01"] = "Thanatos",
    ["NPC_Hades_01"] = "Hades",
    ["NPC_Cerberus_01"] = "Cerberus",
    ["NPC_Cerberus_Field_01"] = "Cerberus",
    ["NPC_Persephone_Home_01"] = "Persephone",
    ["NPC_Persephone_01"] = "Persephone",
    ["NPC_Sisyphus_01"] = "Sisyphus",
    ["NPC_Eurydice_01"] = "Eurydice",
    ["NPC_Patroclus_01"] = "Patroclus",
    ["NPC_Skelly_01"] = "Skelly",
    ["NPC_Charon_01"] = "Charon",
    ["NPC_FurySister_01"] = "Megaera",
    ["NPC_FurySister_02"] = "Alecto",
    ["NPC_FurySister_03"] = "Tisiphone",
    -- Enemies/Bosses
    ["NPC_Asterius_01"] = "Asterius",
    ["NPC_Theseus_01"] = "Theseus",
}

function ProcessTable(objects)
    local table = InitializeObjectList(objects)
    if CurrentRun and CurrentRun.CurrentRoom and not CurrentRun.CurrentRoom.ExitsUnlocked and not (TableLength(ActivatedObjects) > 0) then
        table = AddCure(table)
    end
    table = AddFood(table)
    table = AddObols(table)
    table = AddDarkness(table)
    table = AddGemstones(table)
    table = AddNectar(table)
    table = AddDiamonds(table)
    table = AddUrns(table)
    table = AddFishingPoint(table)
    table = AddGiftRack(table)
    if CurrentRun and CurrentRun.CurrentRoom and CurrentRun.CurrentRoom.ExitsUnlocked then
        table = AddTrove(table)
        table = AddWell(table)
        table = AddPool(table)
    end
    -- Chaos Gate removed from RewardMenu — only in DoorMenu
    table = AddSkelly(table)
    table = AddEscapeDoor(table)
    table = AddNPCs(table)
    table = AddHouseContractor(table)
    table = AddWretchedBroker(table)
    table = AddHeadChef(table)
    table = AddSackOfObols(table)
    table = AddMirrorOfNight(table)
    table = AddFatedList(table)
    table = AddBed(table)
    table = AddRunTracker(table)
    table = AddRunHistory(table)
    table = AddMusicPlayer(table)
    table = AddLyre(table)
    table = AddScryingPool(table)
    table = AddSeedController(table)
    table = AddOfficeInteractions(table)
    table = AddRoomDoors(table)
    table = AddExaminePoints(table)
    return table
end

function InitializeObjectList(objects)
    local initTable = CollapseTableOrderedByKeys(objects) or {}
    local copy = {}
    for i, v in ipairs(initTable) do
        table.insert(copy, {["ObjectId"] = v.ObjectId, ["Name"] = v.Name})
    end
    return copy
end

function AddCure(objects)
    local NV = GetIdsByType({Name = "PoisonCureFountainStyx" })
    if TableLength(NV) == 0 then
        return objects
    end
    local copy = ShallowCopyTable(objects)
    for ID = #NV, 1, -1 do
        if IsUseable({ Id = NV[ID] }) then
            local cure = {
                ["ObjectId"] = NV[ID],
                ["Name"] = "Mandragora Curing Pool",
            }
            if not ObjectAlreadyPresent(cure, copy) then
                copy = TableInsertAtBeginning(copy, cure)
            end
        end
    end
    return  copy
end

function AddFood(objects)
    local NV = CombineTablesIPairs(GetIdsByType({Name = "HealDropMinor" }), GetIdsByType({Name = "RoomRewardHealDrop" }))
    if TableLength(NV) == 0 then
        return objects
    end
    local copy = ShallowCopyTable(objects)
    NV = GetIdsByType({Name = "HealDropMinor" })
    if TableLength(NV) > 0 then
        for ID = 1, #NV do
            if IsUseable({ Id = NV[ID] }) then
                local food = {
                    ["ObjectId"] = NV[ID],
                    ["Name"] = "Food (Dropped)",
                }
                if not ObjectAlreadyPresent(food, copy) then
                    table.insert(copy, food)
                end
            end
        end
    end
    NV = GetIdsByType({Name = "RoomRewardHealDrop" })
    if TableLength(NV) > 0 then
        for ID = 1, #NV do
            if IsUseable({ Id = NV[ID] }) then
                local food = {
                    ["ObjectId"] = NV[ID],
                    ["Name"] = "Food",
                }
                if not ObjectAlreadyPresent(food, copy) then
                    table.insert(copy, food)
                end
            end
        end
    end
    return  copy
    end

function AddObols(objects)
    local NV = CombineTablesIPairs(GetIdsByType({Name = "RoomRewardMoneyDrop" }), GetIdsByType({Name = "MinorMoneyDrop" }))
    if TableLength(NV) == 0 then
        return objects
    end
    local copy = ShallowCopyTable(objects)
    for ID = 1, #NV do
        if IsUseable({ Id = NV[ID] }) then
            local obols = {
                ["ObjectId"] = NV[ID],
                ["Name"] = "Obols",
            }
            if not ObjectAlreadyPresent(obols, copy) then
                table.insert(copy, obols)
            end
        end
    end
    return  copy
    end

function AddDarkness(objects)
    local NV = CombineTablesIPairs(GetIdsByType({Name = "RoomRewardMetaPointDrop" }), GetIdsByType({Name = "RoomRewardMetaPointDropRunProgress" }))
    if TableLength(NV) == 0 then
        return objects
    end
    local copy = ShallowCopyTable(objects)
    for ID = 1, #NV do
        if IsUseable({ Id = NV[ID] }) then
            local darkness = {
                ["ObjectId"] = NV[ID],
                ["Name"] = "Darkness",
            }
            if not ObjectAlreadyPresent(darkness, copy) then
                table.insert(copy, darkness)
            end
        end
    end
    return  copy
    end

function AddGemstones(objects)
    local NV = CombineTablesIPairs(GetIdsByType({Name = "GemDrop" }), GetIdsByType({Name = "GemDropRunProgress" }))
    if TableLength(NV) == 0 then
        return objects
    end
    local copy = ShallowCopyTable(objects)
    for ID = 1, #NV do
        if IsUseable({ Id = NV[ID] }) then
            local gem = {
                ["ObjectId"] = NV[ID],
                ["Name"] = "Gemstones",
            }
            if not ObjectAlreadyPresent(gem, copy) then
                table.insert(copy, gem)
            end
        end
    end
    return  copy
    end

function AddNectar(objects)
    local NV = CombineTablesIPairs(GetIdsByType({Name = "GiftDrop" }), GetIdsByType({Name = "GiftDropRunProgress" }))
    if TableLength(NV) == 0 then
        return objects
    end
    local copy = ShallowCopyTable(objects)
    for ID = 1, #NV do
        if IsUseable({ Id = NV[ID] }) then
            local nectar = {
                ["ObjectId"] = NV[ID],
                ["Name"] = "Nectar",
            }
            if not ObjectAlreadyPresent(nectar, copy) then
                table.insert(copy, nectar)
            end
        end
    end
    return  copy
    end

function AddDiamonds(objects)
    local NV = GetIdsByType({Name = "SuperGemDrop" })
    if TableLength(NV) == 0 then
        return objects
    end
    local copy = ShallowCopyTable(objects)
    for ID = 1, #NV do
        if IsUseable({ Id = NV[ID] }) then
            local diamond = {
                ["ObjectId"] = NV[ID],
                ["Name"] = "Diamond",
            }
            if not ObjectAlreadyPresent(diamond, copy) then
                table.insert(copy, diamond)
            end
        end
    end
    return  copy
    end

function AddUrns(objects)
    if CurrentRun and IsCombatEncounterActive( CurrentRun ) then
        return objects
    end
    local urns = CollapseTableOrderedByKeys(ActiveEnemies)
    if TableLength(urns) == 0 then
        return objects
    end
    local copy = ShallowCopyTable(objects)
    for i = 1, #urns do
        if urns[i].Name == "Breakable" and urns[i].MoneyDropOnDeath and urns[i].MoneyDropOnDeath.Chance > 0 then
            local urn = {
                ["ObjectId"] = urns[i].ObjectId,
                ["Name"] = "Breakable Urn (Obols)",
            }
            if not ObjectAlreadyPresent(urn, copy) then
                table.insert(copy, urn)
            end
        end
    end
    return  copy
    end

function AddFishingPoint(objects)
    if not CurrentRun or not CurrentRun.CurrentRoom then
        return objects
    end
    if not (CurrentRun.CurrentRoom.ForceFishing and CurrentRun.CurrentRoom.FishingPointId and IsUseable({ Id = CurrentRun.CurrentRoom.FishingPointId })) then
        return objects
    end
    local canFishInEncounter = true
    if CurrentRun.CurrentRoom.Encounter and CurrentRun.CurrentRoom.Encounter.BlockFishingBeforeStart and not CurrentRun.CurrentRoom.Encounter.Completed then
        canFishInEncounter = false
    end
    if IsCombatEncounterActive(CurrentRun) or not canFishInEncounter then
        return objects
    end
    local copy = ShallowCopyTable(objects)
    local fish = {
        ["ObjectId"] = CurrentRun.CurrentRoom.FishingPointId,
        ["Name"] = "Fishing Point",
    }
    if not ObjectAlreadyPresent(fish, copy) then
        table.insert(copy, fish)
    end
    return copy
end

function AddGiftRack(objects)
local NV = GetIdsByType({Name = "GiftRack" })
if TableLength(NV) == 0 then
return objects
end
local ID = NV[1]
if not IsUseable({ Id = NV[1] }) then
return objects
end
local copy = ShallowCopyTable(objects)
local rack = {
["ObjectId"] = NV[1],
["Name"] = "Keepsake Display Case",
}
if not ObjectAlreadyPresent(rack, copy) then
table.insert(copy, rack)
end
return  copy
	end

function AddTrove(objects)
if not (CurrentRun.CurrentRoom.ChallengeSwitch and IsUseable({ Id = CurrentRun.CurrentRoom.ChallengeSwitch.ObjectId })) then
return objects
end
local NV = CurrentRun.CurrentRoom.ChallengeSwitch.ObjectId
local copy = ShallowCopyTable(objects)
	local switch = {
	["ObjectId"] = CurrentRun.CurrentRoom.ChallengeSwitch.ObjectId,
	["Name"] = "Infernal Trove (" .. (nameToPreviewName[CurrentRun.CurrentRoom.ChallengeSwitch.RewardType] or CurrentRun.CurrentRoom.ChallengeSwitch.RewardType) .. ")",
}
if not ObjectAlreadyPresent(switch, copy) then
table.insert(copy, switch)
end
return  copy
	end
	
function AddWell(objects)
if not (CurrentRun.CurrentRoom.WellShop and IsUseable({ Id = CurrentRun.CurrentRoom.WellShop.ObjectId })) then
return objects
end
local NV = CurrentRun.CurrentRoom.WellShop.ObjectId
local copy = ShallowCopyTable(objects)
local well = {
["ObjectId"] = CurrentRun.CurrentRoom.WellShop.ObjectId,
["Name"] = "Well of Charon",
}
if not ObjectAlreadyPresent(well, copy) then
table.insert(copy, well)
end
return  copy
	end

function AddPool(objects)
if not (CurrentRun.CurrentRoom.SellTraitShop and IsUseable({ Id = CurrentRun.CurrentRoom.SellTraitShop.ObjectId })) then
return objects
end
local NV = CurrentRun.CurrentRoom.SellTraitShop.ObjectId
local copy = ShallowCopyTable(objects)
local pool = {
["ObjectId"] = CurrentRun.CurrentRoom.SellTraitShop.ObjectId,
["Name"] = "Pool of Purging",
}
if not ObjectAlreadyPresent(pool, copy) then
table.insert(copy, pool)
end
return  copy
	end

function AddChaosGate(objects)
    if not CurrentRun or not CurrentRun.CurrentRoom then
        return objects
    end
    -- SecretDoor = Chaos Gate (health cost door on the ground)
    local NV = GetIdsByType({Name = "SecretDoor"})
    if TableLength(NV) > 0 then
        local copy = ShallowCopyTable(objects)
        for i = 1, #NV do
            local healthCost = ""
            -- Try to find the health cost from OfferedExitDoors
            if OfferedExitDoors then
                for _, door in pairs(OfferedExitDoors) do
                    if door.ObjectId == NV[i] and door.HealthCost then
                        healthCost = " (" .. door.HealthCost .. " Health)"
                    end
                end
            end
            local gate = {
                ["ObjectId"] = NV[i],
                ["Name"] = "Chaos Gate" .. healthCost,
            }
            if not ObjectAlreadyPresent(gate, copy) then
                table.insert(copy, gate)
            end
        end
        return copy
    end
    -- ShrinePointDoor = Infernal Gate (Pact heat cost door)
    NV = GetIdsByType({Name = "ShrinePointDoor"})
    if TableLength(NV) > 0 then
        local copy = ShallowCopyTable(objects)
        for i = 1, #NV do
            local gate = {
                ["ObjectId"] = NV[i],
                ["Name"] = "Infernal Gate",
            }
            if not ObjectAlreadyPresent(gate, copy) then
                table.insert(copy, gate)
            end
        end
        return copy
    end
    return objects
end

function AddSkelly(objects)
if not string.find(GetMapName({}), "RoomPreRun") then
return objects
end
local NV = GetIdsByType({Name = "TrainingMelee" })
if TableLength(NV) == 0 then
return objects
end
local ID = NV[1]
if not (ActiveEnemies[NV[1]] and not ActiveEnemies[NV[1]].IsDead) then
return objects
end
local copy = ShallowCopyTable(objects)
local skelly = {
["ObjectId"] = NV[1],
["Name"] = "Skelly",
}
if not ObjectAlreadyPresent(skelly, copy) then
copy = TableInsertAtBeginning(copy, skelly)
end
return  copy
	end

function AddEscapeDoor(objects)
if not string.find(GetMapName({}), "RoomPreRun") then
return objects
end
local NV = GetIdsByType({Name = "NewRunDoor" })
if TableLength(NV) == 0 then
return objects
end
local ID = NV[1]
if not IsUseable({ Id = NV[1] }) then
return objects
end
local copy = ShallowCopyTable(objects)
local window = {
["ObjectId"] = NV[1],
["Name"] = "Escape Window",
}
if not ObjectAlreadyPresent(window, copy) then
table.insert(copy, window)
end
return  copy
	end

function AddNPCs(objects)
    if CurrentRun and IsCombatEncounterActive( CurrentRun ) then
        return objects
    end
    local npcs = CollapseTableOrderedByKeys(ActiveEnemies)
    if TableLength(npcs) == 0 then
        return objects
    end
    local copy = ShallowCopyTable(objects)
    for i = 1, #npcs do
        local skip = false
        if IsUseable({ Id = npcs[i].ObjectId }) then
            local npc = {
                ["ObjectId"] = npcs[i].ObjectId,
                ["Name"] = nameToPreviewName[npcs[i].Name] or npcs[i].Name,
            }
            if npcs[i].Name == "NPC_Hades_01" and GetMapName({}) == "DeathArea" then --Hades in house
                if ActiveEnemies[555686] then --Hades is in garden
                    npc["ObjectId"] = 555686
                elseif GetDistance({ Id = npc["ObjectId"], DestinationId = 422028 }) < 100 then --Hades on his throne
                    npc["DestinationOffsetY"] = 150
                end
            elseif npcs[i].Name == "NPC_Cerberus_01" and GetMapName({}) == "DeathArea" and GetDistance({ Id = npc["ObjectId"], DestinationId = 422028 }) > 500 then --Cerberus not present in house
                skip = true
            elseif npcs[i].Name == "NPC_Cerberus_Field_01" and TableLength(OfferedExitDoors) == 1 and CollapseTable(OfferedExitDoors)[1].Room.Name:find("D_Boss", 1, true) == 1 and GetDistance({ Id = npc["ObjectId"], DestinationId = 551569 }) == 0 then --Cerberus in Styx after having been given satyr sack
                skip = true
            end
            if not ObjectAlreadyPresent(npc, copy) and not skip then
                table.insert(copy, npc)
            end
        end
    end
    return  copy
    end

function AddHouseContractor(objects)
if GetMapName({}) ~= "DeathArea" or (GameState and GameState.Flags and GameState.Flags.InFlashback) then
return objects
end
local NV = {210158}
if TableLength(NV) == 0 then
return objects
end
local ID = NV[1]
if not IsUseable({ Id = NV[1] }) then
return objects
end
local copy = ShallowCopyTable(objects)
local contractor = {
["ObjectId"] = NV[1],
["Name"] = "House Contractor",
["DestinationOffsetY"] = 25,
}
if not ObjectAlreadyPresent(contractor, copy) then
table.insert(copy, contractor)
end
return  copy
	end

function AddWretchedBroker(objects)
if GetMapName({}) ~= "DeathArea" or (GameState and GameState.Flags and GameState.Flags.InFlashback) then
return objects
end
local NV = {423390}
if TableLength(NV) == 0 then
return objects
end
local ID = NV[1]
if not IsUseable({ Id = NV[1] }) then
return objects
end
local copy = ShallowCopyTable(objects)
local broker = {
["ObjectId"] = NV[1],
["Name"] = "Wretched Broker",
["DestinationOffsetX"] = -225,
["DestinationOffsetY"] = -100
}
if not ObjectAlreadyPresent(broker, copy) then
table.insert(copy, broker)
end
return  copy
	end

function AddHeadChef(objects)
if GetMapName({}) ~= "DeathArea" or (GameState and GameState.Flags and GameState.Flags.InFlashback) then
return objects
end
local NV = {423399}
if TableLength(NV) == 0 then
return objects
end
local ID = NV[1]
if not IsUseable({ Id = NV[1] }) then
return objects
end
local copy = ShallowCopyTable(objects)
local chef = {
["ObjectId"] = NV[1],
["Name"] = "Head Chef",
}
if not ObjectAlreadyPresent(chef, copy) then
table.insert(copy, chef)
end
return  copy
	end

function AddSackOfObols(objects)
local curMap = GetMapName({})
if not string.find(curMap, "Shop") and not string.find(curMap, "PreBoss") and not string.find(curMap, "D_Hub") then
return objects
end
if not (CurrentRun and CurrentRun.CurrentRoom and CurrentRun.CurrentRoom.Store and CurrentRun.CurrentRoom.Store.SpawnedStoreItems) then
return objects
end
local NV = {}
for k, v in pairs(CurrentRun.CurrentRoom.Store.SpawnedStoreItems) do
if v.Name == "ForbiddenShopItem" then
table.insert(NV, v.ObjectId)
end
end
if TableLength(NV) == 0 then
return objects
end
local ID = NV[1]
if not IsUseable({ Id = NV[1] }) then
return objects
end
local copy = ShallowCopyTable(objects)
local sack = {
["ObjectId"] = NV[1],
["Name"] = "Sack of Obols (Elite)",
}
if not ObjectAlreadyPresent(sack, copy) then
table.insert(copy, sack)
end
return  copy
	end

function AddMirrorOfNight(objects)
    local curMap = GetMapName({})
    -- Mirror is in the bedroom but visible/accessible from DeathArea too
    if curMap:find("DeathArea", 1, true) ~= 1 then
        return objects
    end
    local NV = GetIdsByType({Name = "MetaUpgradeScreen"})
    if TableLength(NV) == 0 then
        return objects
    end
    if not IsUseable({ Id = NV[1] }) then
        return objects
    end
    local copy = ShallowCopyTable(objects)
    local mirror = {
        ["ObjectId"] = NV[1],
        ["Name"] = "Mirror of Night",
    }
    if not ObjectAlreadyPresent(mirror, copy) then
        table.insert(copy, mirror)
    end
    return copy
end

-- NOTE: AddPactOfPunishment removed — ShrineUpgradeViewer has no instances in any room.
-- The Pact of Punishment menu opens through the Escape Window in the courtyard (RoomPreRun).
-- Interact with the Escape Window to open the Pact before starting a run.

function AddFatedList(objects)
    -- Fated List scroll (QuestLog) — object 421158, only exists in DeathAreaBedroom.
    -- Requires "QuestLog" cosmetic purchased from House Contractor.
    local curMap = GetMapName({})
    if curMap ~= "DeathAreaBedroom" then
        return objects
    end
    local questLogId = 421158
    if not IsUseable({ Id = questLogId }) then
        return objects
    end
    local copy = ShallowCopyTable(objects)
    local fatedList = {
        ["ObjectId"] = questLogId,
        ["Name"] = "Fated List of Minor Prophecies",
    }
    if not ObjectAlreadyPresent(fatedList, copy) then
        table.insert(copy, fatedList)
    end
    return copy
end

function AddBed(objects)
    -- Zagreus's Bed — only in DeathAreaBedroom.
    -- Default bed is type "HouseBed01" (object 310036).
    -- If cosmetic HouseBed01a purchased, default is deactivated and replaced by "HouseBed01a".
    -- Using the bed triggers flashback cutscenes (when available) or idle dialogue.
    local curMap = GetMapName({})
    if curMap ~= "DeathAreaBedroom" then
        return objects
    end
    -- Check both default and cosmetic-upgraded bed types
    local bedId = nil
    local ids = GetIdsByType({Name = "HouseBed01"})
    if ids and #ids > 0 then
        for _, id in ipairs(ids) do
            if IsUseable({ Id = id }) then
                bedId = id
                break
            end
        end
    end
    if not bedId then
        ids = GetIdsByType({Name = "HouseBed01a"})
        if ids and #ids > 0 then
            for _, id in ipairs(ids) do
                if IsUseable({ Id = id }) then
                    bedId = id
                    break
                end
            end
        end
    end
    if not bedId then
        return objects
    end
    local copy = ShallowCopyTable(objects)
    local bed = {
        ["ObjectId"] = bedId,
        ["Name"] = "Bed",
    }
    if not ObjectAlreadyPresent(bed, copy) then
        table.insert(copy, bed)
    end
    return copy
end

function AddRunTracker(objects)
    -- Run Tracker / Permanent Record (GameStats) — object 488699, in DeathAreaOffice.
    -- Accessible after purchasing OfficeDoorUnlockItem (Administrative Privilege) from Contractor.
    local curMap = GetMapName({})
    if curMap ~= "DeathAreaOffice" then
        return objects
    end
    local copy = ShallowCopyTable(objects)
    local tracker = {
        ["ObjectId"] = 488699,
        ["Name"] = "Permanent Record (Run Tracker)",
    }
    if not ObjectAlreadyPresent(tracker, copy) then
        table.insert(copy, tracker)
    end
    return copy
end

function AddRunHistory(objects)
    -- Run History — object 488633, in DeathAreaOffice.
    -- Accessible after purchasing OfficeDoorUnlockItem (Administrative Privilege) from Contractor.
    local curMap = GetMapName({})
    if curMap ~= "DeathAreaOffice" then
        return objects
    end
    -- Only show if there's at least one completed run
    if not GameState or not GameState.RunHistory or #GameState.RunHistory == 0 then
        return objects
    end
    local copy = ShallowCopyTable(objects)
    local history = {
        ["ObjectId"] = 488633,
        ["Name"] = "Run History",
    }
    if not ObjectAlreadyPresent(history, copy) then
        table.insert(copy, history)
    end
    return copy
end

function AddMusicPlayer(objects)
    -- Music Player — object 424035, only in DeathArea.
    -- Requires Cosmetic_MusicPlayer purchased from House Contractor.
    local curMap = GetMapName({})
    if curMap ~= "DeathArea" then
        return objects
    end
    local musicPlayerId = 424035
    if not IsUseable({ Id = musicPlayerId }) then
        return objects
    end
    local copy = ShallowCopyTable(objects)
    local player = {
        ["ObjectId"] = musicPlayerId,
        ["Name"] = "Music Player",
    }
    if not ObjectAlreadyPresent(player, copy) then
        table.insert(copy, player)
    end
    return copy
end

function AddLyre(objects)
    -- Orpheus's Lyre — object 426208, only in DeathAreaBedroom.
    -- Requires HouseLyre01 cosmetic purchased from House Contractor ("Court Musician's Sentence" quest line).
    -- Interacting plays the lyre: sound quality improves with practice + Orpheus story progress.
    local curMap = GetMapName({})
    if curMap ~= "DeathAreaBedroom" then
        return objects
    end
    if not GameState or not GameState.Cosmetics or not GameState.Cosmetics.HouseLyre01 then
        return objects
    end
    local lyreId = 426208
    if not IsUseable({ Id = lyreId }) then
        return objects
    end
    local copy = ShallowCopyTable(objects)
    local lyre = {
        ["ObjectId"] = lyreId,
        ["Name"] = "Orpheus's Lyre",
    }
    if not ObjectAlreadyPresent(lyre, copy) then
        table.insert(copy, lyre)
    end
    return copy
end

function AddScryingPool(objects)
    -- Scrying Pool — object 390197, only in DeathAreaBedroom.
    -- Requires HouseWaterBowl01 cosmetic purchased from House Contractor.
    -- Interacting shows run attempts count and total enemy kills.
    local curMap = GetMapName({})
    if curMap ~= "DeathAreaBedroom" then
        return objects
    end
    if not GameState or not GameState.Cosmetics or not GameState.Cosmetics.HouseWaterBowl01 then
        return objects
    end
    local poolId = 390197
    if not IsUseable({ Id = poolId }) then
        return objects
    end
    local copy = ShallowCopyTable(objects)
    local pool = {
        ["ObjectId"] = poolId,
        ["Name"] = "Scrying Pool",
    }
    if not ObjectAlreadyPresent(pool, copy) then
        table.insert(copy, pool)
    end
    return copy
end

function AddSeedController(objects)
    -- Seed Controller — object 487568, only in RoomPreRun (courtyard).
    -- Requires SeedController cosmetic purchased from House Contractor.
    local curMap = GetMapName({})
    if curMap ~= "RoomPreRun" then
        return objects
    end
    -- Check if the SeedController cosmetic has been purchased from the Contractor
    if not GameState or not GameState.Cosmetics or not GameState.Cosmetics.SeedController then
        return objects
    end
    local copy = ShallowCopyTable(objects)
    local seed = {
        ["ObjectId"] = seedControllerId,
        ["Name"] = "Seed Controller",
    }
    if not ObjectAlreadyPresent(seed, copy) then
        table.insert(copy, seed)
    end
    return copy
end

function AddOfficeInteractions(objects)
    -- Repeatable interactions in DeathAreaOffice (water cooler, posters, Eldest Sigil).
    -- These are always available (not one-time) unlike the examine/inspect points.
    local curMap = GetMapName({})
    if curMap ~= "DeathAreaOffice" then
        return objects
    end
    local copy = ShallowCopyTable(objects)
    -- Water Cooler (repeatable, 3s cooldown)
    local waterCoolerId = 488624
    if IsUseable({ Id = waterCoolerId }) then
        local wc = {
            ["ObjectId"] = waterCoolerId,
            ["Name"] = "Water Cooler",
        }
        if not ObjectAlreadyPresent(wc, copy) then
            table.insert(copy, wc)
        end
    end
    -- Office Posters (repeatable, 8s cooldown, both disable together)
    local poster1Id = 488047
    if IsUseable({ Id = poster1Id }) then
        local p1 = {
            ["ObjectId"] = poster1Id,
            ["Name"] = "Office Poster",
        }
        if not ObjectAlreadyPresent(p1, copy) then
            table.insert(copy, p1)
        end
    end
    local poster2Id = 488611
    if IsUseable({ Id = poster2Id }) then
        local p2 = {
            ["ObjectId"] = poster2Id,
            ["Name"] = "Office Poster",
        }
        if not ObjectAlreadyPresent(p2, copy) then
            table.insert(copy, p2)
        end
    end
    -- Eldest Sigil / Teleporter inspect point (487903)
    -- The sigil object (487882) has no UseText so IsUseable returns false.
    -- Use the inspect point instead — it has UseText = "UseExamineMisc".
    local sigilInspectId = 487903
    if IsUseable({ Id = sigilInspectId }) then
        local sigil = {
            ["ObjectId"] = sigilInspectId,
            ["Name"] = "Eldest Sigil (Teleporter)",
        }
        if not ObjectAlreadyPresent(sigil, copy) then
            table.insert(copy, sigil)
        end
    end
    return copy
end

-- NOTE: AddCourtyard removed -- TrainingMelee (Skelly) only exists in RoomPreRun,
-- not in DeathArea. Cannot teleport between different game rooms.
-- The courtyard is accessible by walking right from the house.
-- Use MoveDown in the courtyard's TraitTrayScreen to open its reward menu.

function AddRoomDoors(objects)
    local curMap = GetMapName({})
    local copy = ShallowCopyTable(objects)

    if curMap == "DeathArea" then
        -- Door from main hall to Zagreus's bedroom
        local door = {
            ["ObjectId"] = 391697,
            ["Name"] = "Door to Bedroom",
            ["RoomDoor"] = true,
            ["DoorArgs"] = { Name = "DeathAreaBedroom", HeroStartPoint = 40009, HeroEndPoint = 40012, CheckBinkSetChange = true },
        }
        if not ObjectAlreadyPresent(door, copy) then
            table.insert(copy, door)
        end
        -- Door from main hall to admin office (requires OfficeDoorUnlockItem cosmetic)
        -- Object 427199 is activated when the cosmetic is purchased; 427213 is the locked version
        local officeDoorId = 427199
        if IsUseable({ Id = officeDoorId }) then
            local officeDoor = {
                ["ObjectId"] = officeDoorId,
                ["Name"] = "Door to Admin Office",
                ["RoomDoor"] = true,
                ["DoorArgs"] = { Name = "DeathAreaOffice" },
            }
            if not ObjectAlreadyPresent(officeDoor, copy) then
                table.insert(copy, officeDoor)
            end
        end
    elseif curMap == "DeathAreaOffice" then
        -- Door from admin office back to main hall
        local hallDoor = {
            ["ObjectId"] = 487886,
            ["Name"] = "Door to Main Hall",
            ["RoomDoor"] = true,
            ["DoorArgs"] = { Name = "DeathArea", HeroStartPoint = 427202, HeroEndPoint = 427201 },
        }
        if not ObjectAlreadyPresent(hallDoor, copy) then
            table.insert(copy, hallDoor)
        end
    elseif curMap == "DeathAreaBedroom" then
        -- Door back to the main hall
        local hallDoor = {
            ["ObjectId"] = 420896,
            ["Name"] = "Door to Main Hall",
            ["RoomDoor"] = true,
            ["DoorArgs"] = { Name = "DeathArea", HeroStartPoint = 390004, HeroEndPoint = 390002, CheckBinkSetChange = true },
        }
        if not ObjectAlreadyPresent(hallDoor, copy) then
            table.insert(copy, hallDoor)
        end
        -- Door to the courtyard (pre-run area)
        local courtyardDoor = {
            ["ObjectId"] = 420897,
            ["Name"] = "Door to Courtyard",
            ["RoomDoor"] = true,
            ["DoorArgs"] = { Name = "RoomPreRun", HeroStartPoint = 40009, HeroEndPoint = 40012, CheckBinkSetChange = true },
        }
        if not ObjectAlreadyPresent(courtyardDoor, copy) then
            table.insert(copy, courtyardDoor)
        end
    elseif curMap == "RoomPreRun" then
        -- Door back to Zagreus's bedroom
        local bedroomDoor = {
            ["ObjectId"] = 421119,
            ["Name"] = "Door to Bedroom",
            ["RoomDoor"] = true,
            ["DoorArgs"] = { Name = "DeathAreaBedroom", HeroStartPoint = 390514, HeroEndPoint = 390515 },
        }
        if not ObjectAlreadyPresent(bedroomDoor, copy) then
            table.insert(copy, bedroomDoor)
        end
    elseif curMap == "E_Intro" then
        -- Exit to Persephone's garden (auto-activates on approach)
        local gardenExit = {
            ["ObjectId"] = 552607,
            ["Name"] = "Path to Garden",
        }
        if not ObjectAlreadyPresent(gardenExit, copy) then
            table.insert(copy, gardenExit)
        end
    end

    return copy
end

function AddExaminePoints(objects)
    local copy = ShallowCopyTable(objects)
    local pointNum = 0

    -- Collect inspect points from all available sources
    local inspectSources = {}
    -- House rooms use CurrentDeathAreaRoom
    if CurrentDeathAreaRoom and CurrentDeathAreaRoom.InspectPoints then
        table.insert(inspectSources, CurrentDeathAreaRoom.InspectPoints)
    end
    -- Run rooms (and some house sub-rooms) use CurrentRun.CurrentRoom
    if CurrentRun and CurrentRun.CurrentRoom and CurrentRun.CurrentRoom.InspectPoints then
        -- Avoid duplicating if it's the same table
        local isDuplicate = false
        if CurrentDeathAreaRoom and CurrentDeathAreaRoom.InspectPoints == CurrentRun.CurrentRoom.InspectPoints then
            isDuplicate = true
        end
        if not isDuplicate then
            table.insert(inspectSources, CurrentRun.CurrentRoom.InspectPoints)
        end
    end

    for _, inspectPoints in ipairs(inspectSources) do
        for id, inspectData in pairs(inspectPoints) do
            if IsUseable({ Id = id }) then
                pointNum = pointNum + 1
                local pointName = "Examine Point " .. pointNum
                -- Try to get a display name from the inspect data
                if inspectData and inspectData.InteractTextLineSets then
                    for setName, _ in pairs(inspectData.InteractTextLineSets) do
                        -- Use the first text line set name as a hint
                        local cleanName = setName:gsub("_", " ")
                        if cleanName and cleanName ~= "" then
                            pointName = cleanName
                        end
                        break
                    end
                end
                local point = {
                    ["ObjectId"] = id,
                    ["Name"] = pointName,
                }
                if not ObjectAlreadyPresent(point, copy) then
                    table.insert(copy, point)
                end
            end
        end
    end
    return copy
end

function ObjectAlreadyPresent(object, objects)
    found = false
    for k, v in ipairs(objects) do
        if object.ObjectId == v.ObjectId then
            found = true
        end
    end
    if CurrentRun and CurrentRun.CurrentRoom and CurrentRun.CurrentRoom.Store and NumUseableObjects(CurrentRun.CurrentRoom.Store.SpawnedStoreItems) > 0 then
        for k, v in pairs(CurrentRun.CurrentRoom.Store.SpawnedStoreItems) do
            if object.ObjectId == v.ObjectId and v.Name ~= "ForbiddenShopItem" then
                found = true
            end
        end
    end
    return found
end

function TableInsertAtBeginning(baseTable, insertValue)
    if baseTable == nil or insertValue == nil then
        return
    end
    local returnTable = {}
    table.insert(returnTable, insertValue)
    for k, v in ipairs(baseTable) do
        table.insert(returnTable, v)
    end
    return returnTable
end

function GetWeaponDisplayConditions(name)
    if not WeaponSets or not WeaponSets.HeroMeleeWeapons then return "" end
    local found = false
    for k, weaponName in ipairs( WeaponSets.HeroMeleeWeapons ) do
        if name == weaponName then
            found = true
        end
    end
    if not found then
        return ""
    end
    if not CurrentRun or not CurrentRun.Hero or not CurrentRun.Hero.Weapons then return "" end
    if CurrentRun.Hero.Weapons[name] ~= nil then
        if IsWeaponUnused(name) then
            return " (Equipped, Dark Thirst)"
        else
            return " (Equipped)"
        end
    else
        if IsWeaponUnused(name) then
            return " (Dark Thirst)"
        else
            return ""
        end
    end
end

function OpenRewardMenu(rewards)
local screen = { Components = {} }
screen.Name = "BlindAccessibilityRewardMenu"

-- Guard: don't open if bridge isn't ready (prevents silent invisible menu)
if not AccessibilityEnabled or not AccessibilityEnabled() then
return
end

-- Use local tracking variable instead of IsScreenOpen (which has false positives on some save slots)
if _rewardMenuOpen then
return
end
_rewardMenuOpen = true
_Log("[MENU-OPEN] RewardMenu (BlindAccessibilityRewardMenu)")
OnScreenOpened({ Flag = screen.Name, PersistCombatUI = false })
HideCombatUI()
FreezePlayerUnit()
EnableShopGamepadCursor()

PlaySound({ Name = "/SFX/Menu Sounds/ContractorMenuOpen" })
local components = screen.Components

components.ShopBackgroundDim = CreateScreenComponent({ Name = "rectangle01", Group = "Menu_UI" })
-- Close button moved off-screen (Cancel hotkey still works for closing)
components.CloseButton = CreateScreenComponent({ Name = "ButtonClose", Group = "Menu_UI_Backing", Scale = 0.7 })
Attach({ Id = components.CloseButton.Id, DestinationId = components.ShopBackgroundDim.Id, OffsetX = -5000, OffsetY = -5000 })
components.CloseButton.OnPressedFunctionName = "CloseRewardMenu"
components.CloseButton.ControlHotkey = "Cancel"

SetScale({ Id = components.ShopBackgroundDim.Id, Fraction = 4 })
SetColor({ Id = components.ShopBackgroundDim.Id, Color = {0, 0, 0, 1} })

CreateRewardButtons(screen, rewards)

-- TeleportCursor to first button and speak screen name + first item
if screen.FirstButtonId then
    TeleportCursor({ DestinationId = screen.FirstButtonId })
    if AccessibilityEnabled and AccessibilityEnabled() and screen.FirstSpeechText then
        TolkSilence()
        TolkSpeak(UIStrings.RewardMenu .. ", " .. screen.FirstSpeechText)
    end
end

screen.KeepOpen = true
HandleScreenInput( screen )

end

-- Weapon descriptions for Infernal Arms (from Hades Wiki)
local weaponDescriptions = {
    ["SwordWeapon"] = "Stygius, the Stygian Blade. Close-range melee weapon with a 3-hit combo and a wide Nova Special. Unlocked by default",
    ["BowWeapon"] = "Coronacht, the Heart-Seeking Bow. Ranged weapon with charged Attack and a volley Special. Unlocked for 1 Chthonic Key",
    ["ShieldWeapon"] = "Aegis, the Shield of Chaos. Melee weapon with a Bull Rush charge and throwable Special that returns. Unlocked for 3 Chthonic Keys",
    ["SpearWeapon"] = "Varatha, the Eternal Spear. Long-range melee weapon with a thrown Special and Spin Attack. Unlocked for 4 Chthonic Keys",
    ["FistWeapon"] = "Malphon, the Twin Fists. Fastest melee weapon with rapid combo hits and a rising uppercut Special. Unlocked for 8 Chthonic Keys",
    ["GunWeapon"] = "Exagryph, the Adamant Rail. Ranged automatic weapon with ammo and a grenade-launcher Special. Unlocked for 8 Chthonic Keys",
}

function CreateRewardButtons(screen, rewards)
    local xPos = 960
    local startY = 235
    local yIncrement = 55
    local curY = startY
    local components = screen.Components
    local curMap = GetMapName({})
    if not string.find(curMap, "RoomPreRun") and curMap:find("DeathArea", 1, true) ~= 1 and curMap:find("E_", 1, true) ~= 1 then
        components.statsTextBacking = CreateScreenComponent({
            Name = "BlankObstacle",
            Group = "Menu_UI_Rewards",
            Scale = 1,
            X = xPos,
            Y = curY
        })
        local healthText = "Health: " .. (CurrentRun.Hero.Health or 0) .. "/" .. (CurrentRun.Hero.MaxHealth or 0)
        CreateTextBox({
            Id = components.statsTextBacking.Id,
            Text = healthText,
            FontSize = 24,
            Width = 360,
            OffsetX = 0,
            OffsetY = 0,
            Color = Color.White,
            Font = "AlegreyaSansSCLight",
            Group = "Menu_UI_Rewards",
            ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 2},
            Justification = "Left",
        })
        curY = curY + yIncrement
        local obolText = "Charon's Obol: " .. ((CurrentRun or {Money = 0}).Money or 0)
        CreateTextBox({
            Id = components.statsTextBacking.Id,
            Text = obolText,
            FontSize = 24,
            Width = 360,
            OffsetX = 0,
            OffsetY = yIncrement,
            Color = Color.White,
            Font = "AlegreyaSansSCLight",
            Group = "Menu_UI_Rewards",
            ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 2},
            Justification = "Left",
        })
        curY = curY + yIncrement
    end
    for k, reward in pairs(rewards) do
        local displayText = reward.Name
        local buttonKey = "RewardMenuButton" .. k
        components[buttonKey] = CreateScreenComponent({
            Name = "MarketSlot",
            Group = "Menu_UI_Rewards",
            Scale = 0.8,
            X = xPos,
            Y = curY
        })
        components[buttonKey].index = k
        components[buttonKey].reward = reward
        components[buttonKey].OnPressedFunctionName = "GoToReward"
        components[buttonKey].OnMouseOverFunctionName = "OnRewardItemMouseOver"
        if reward.Args ~= nil and reward.Args.ForceLootName then
            displayText = reward.Args.ForceLootName:gsub("Upgrade", ""):gsub("Drop", "")
        end
        displayText = nameToPreviewName[displayText:gsub("Drop", ""):gsub("StoreReward", "")] or displayText
        displayText = (displayText .. GetWeaponDisplayConditions(reward.Name)) or displayText
        components[buttonKey].displayText = displayText
        -- Build full speech text (includes weapon description if applicable)
        local speechText = displayText
        if reward.Name and weaponDescriptions[reward.Name] then
            speechText = speechText .. ". " .. weaponDescriptions[reward.Name]
        end
        components[buttonKey].speechText = speechText
        AttachLua({ Id = components[buttonKey].Id, Table = components[buttonKey] })
        CreateTextBox({
            Id = components[buttonKey].Id,
            Text = displayText,
            FontSize = 24,
            Width = 720,
            OffsetX = -320,
            OffsetY = 0,
            Color = Color.White,
            Font = "AlegreyaSansSCLight",
            Group = "Menu_UI_Rewards",
            ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 2},
            Justification = "Left",
        })
        if not screen.FirstButtonId then
            screen.FirstButtonId = components[buttonKey].Id
            screen.FirstSpeechText = speechText
        end
        curY = curY + yIncrement
    end
end

function OnRewardItemMouseOver(button)
    if not AccessibilityEnabled or not AccessibilityEnabled() or not button then return end
    local speech = button.speechText or button.displayText or "Unknown"
    _Log("[NAV] RewardMenu item: " .. speech)
    TolkSilence()
    TolkSpeak(speech)
end

function GoToReward(screen, button)
_Log("[ACTION] GoToReward: " .. (button and button.displayText or "Unknown"))
PlaySound({ Name = "/SFX/Menu Sounds/ContractorItemPurchase" })
CloseRewardMenu(screen, button)
local RewardID = nil
RewardID = button.reward.ObjectId
destinationOffsetX = button.reward.DestinationOffsetX or 0
destinationOffsetY = button.reward.DestinationOffsetY or 0
if RewardID  ~= nil then
Teleport({ Id = CurrentRun.Hero.ObjectId, DestinationId = RewardID, OffsetX = destinationOffsetX, OffsetY = destinationOffsetY})
end
end

function CloseRewardMenu( screen, button )
_Log("[MENU-CLOSE] RewardMenu (BlindAccessibilityRewardMenu)")
PlaySound({ Name = "/SFX/Menu Sounds/ContractorMenuClose" })
CloseScreen( GetAllIds( screen.Components ) )
ShowCombatUI()
UnfreezePlayerUnit()
screen.KeepOpen = false
_rewardMenuOpen = false
OnScreenClosed({ Flag = screen.Name })
end

ModUtil.WrapBaseFunction("ExitNPCPresentation", function(baseFunc, source, args)

	AddInputBlock({ Name = "NPCExit" })
	wait( args.InitialWaitTime or 0 )

	FadeOut({ Color = Color.Black, Duration = args.FadeOutTime or 0.5 })

	PlaySound({ Name = args.InitialExitSound or "/EmptyCue", Delay = 0.7 })

	wait( (args.FadeOutTime or 0.5) + 0.3 )

	if args.DeleteId ~= nil then
		Destroy({ Id = args.DeleteId })
	end

	PlaySound({ Name = args.FootstepSound or "/Leftovers/SFX/FootstepsConcreteMedium" })
	PlaySound({ Name = args.FootstepSound or "/Leftovers/SFX/FootstepsConcreteMedium", Delay = 0.3 })
	PlaySound({ Name = args.MoveSound or "/SFX/Enemy Sounds/Megaera/MegaeraWingFlap", Delay = 0.4 })
	PlaySound({ Name = args.FootstepSound or "/Leftovers/SFX/FootstepsConcreteMedium", Delay = 0.6 })
	PlaySound({ Name = args.FootstepSound or "/Leftovers/SFX/FootstepsConcreteMedium", Delay = 0.9 })
	PlaySound({ Name = args.MoveSound or "/SFX/Enemy Sounds/Megaera/MegaeraWingFlap", Delay = 1.0 })
	if args.UseAdditionalFootstepSounds then
		PlaySound({ Name = args.FootstepSound or "/Leftovers/SFX/FootstepsConcreteMedium", Delay = 1.2 })
		PlaySound({ Name = args.FootstepSound or "/Leftovers/SFX/FootstepsConcreteMedium", Delay = 1.5 })
	end

	if args.UseThanatosExitSound then
		thread( PlayVoiceLines, GlobalVoiceLines.ThanatosSpecialExitVoiceLines, true )
		PlaySound({ Name = "/Leftovers/SFX/BeaconTeleportSFX2", Delay = 2.2 })
	end

	LockCamera({ Id = CurrentRun.Hero.ObjectId })
	Teleport({ Id = args.ObjectId or source.ObjectId, DestinationId = args.TeleportToId })
	-- Function modification by hllf: Insert next line
	UseableOff({ Id = args.ObjectId or source.ObjectId })
	if args.AltObjectId ~= nil then
		Teleport({ Id = args.AltObjectId, DestinationId = args.TeleportToId })
		-- Function modification by hllf: Insert next line
		UseableOff({ Id = args.AltObjectId })
	end

	wait( args.FullFadeTime or 1.5 )

	thread( PlayVoiceLines, HeroVoiceLines[args.HeroVoiceLines] )

	FadeIn({ Duration = args.FadeInTime or 1.0 })

	RemoveInputBlock({ Name = "NPCExit" })

	PlaySound({ Name = args.EndSound or "/EmptyCue", Delay = 0.3 })

	if args.EndUnlockText ~= nil then
		thread( DisplayUnlockText, {
			TitleText = args.EndUnlockText.."_Title",
			SubtitleText = args.EndUnlockText.."_Subtitle",
			AnimationName = args.AnimationName or "LocationTextBGGeneric",
			AnimationOutName = args.AnimationOutName or "LocationTextBGGenericOut",
			FontScale = args.FontScale or 1.0,
			SubtitleData = { LuaKey = "TempTextData", LuaValue = { Name = CurrentRun.CurrentRoom.EndUnlockText }},
			Delay = 0.6,
		})
	elseif args.EndUnlockTextTable ~= nil then
		local text = GetRandomValue( args.EndUnlockTextTable )
		thread( DisplayUnlockText, {
			TitleText = text.."_Title",
			SubtitleText = text.."_Subtitle",
			AnimationName = args.AnimationName or "LocationTextBGGeneric",
			AnimationOutName = args.AnimationOutName or "LocationTextBGGenericOut",
			FontScale = args.FontScale or 1.0,
			SubtitleData = { LuaKey = "TempTextData", LuaValue = { Name = CurrentRun.CurrentRoom.EndUnlockText }},
			Delay = 0.6,
		})
	end

end)
