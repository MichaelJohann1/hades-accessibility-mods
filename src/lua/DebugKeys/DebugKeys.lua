--[[
Mod: DebugKeys
Author: Accessibility Layer
Version: 3

Handles debug key spawning during development/testing.
The C++ DLL (debug.cpp) detects key presses and sets Lua global flags.
This mod polls those flags every 0.1 seconds and executes the corresponding actions.

Key mapping (set by C++ CheckDebugKeys):
  F1-F9:  Spawn god boons (Zeus, Poseidon, Athena, Ares, Aphrodite, Artemis, Dionysus, Hermes, Demeter)
  F10:    Spawn Daedalus Hammer
  F11:    Spawn Pom of Power
  F12:    Spawn Well of Charon
  1:      Spawn Chaos Gate door
  2:      Spawn NPC story room door
  3:      Open Weapon Upgrade screen
  4:      Open Sell Trait (Purging Pool) screen
  5:      Open Run Clear screen
  6:      Max Adamant Rail + 1B health + 1M resources + enemy HP to 1 (works in house for resources)
  7:      Enable flashback 1 (sets AllowFlashback flag, use bed to trigger)
  8:      Enable flashback 2 (sets AllowFlashback + Flashback_Mother_01 prereq, use bed to trigger)
  9:      Spawn fishing point in current room
  0:      Spawn healing fountain
--]]

-- God boon spawn config: flag name -> loot name
local _DebugGodSpawns = {
    { flag = "_DebugSpawnZeus",      name = "ZeusUpgrade" },
    { flag = "_DebugSpawnPoseidon",  name = "PoseidonUpgrade" },
    { flag = "_DebugSpawnAthena",    name = "AthenaUpgrade" },
    { flag = "_DebugSpawnAres",      name = "AresUpgrade" },
    { flag = "_DebugSpawnAphrodite", name = "AphroditeUpgrade" },
    { flag = "_DebugSpawnArtemis",   name = "ArtemisUpgrade" },
    { flag = "_DebugSpawnDionysus",  name = "DionysusUpgrade" },
    { flag = "_DebugSpawnHermes",    name = "HermesUpgrade" },
    { flag = "_DebugSpawnDemeter",   name = "DemeterUpgrade" },
}

thread(function()
    while true do
        if CurrentRun and CurrentRun.CurrentRoom then
            -- F1-F9: God boons
            for _, entry in ipairs(_DebugGodSpawns) do
                if _G[entry.flag] then
                    _G[entry.flag] = nil
                    CreateLoot({ Name = entry.name, SpawnPoint = CurrentRun.Hero.ObjectId })
                end
            end

            -- F10: Daedalus Hammer
            if _DebugSpawnHammer then
                _DebugSpawnHammer = nil
                CreateWeaponLoot()
            end

            -- F11: Pom of Power
            if _DebugSpawnPom then
                _DebugSpawnPom = nil
                CreateStackLoot()
            end

            -- F12: Well of Charon
            if _DebugSpawnStore then
                _DebugSpawnStore = nil
                AddMoney(9000, "GrantUpgrade")
                CurrentRun.CurrentRoom.Store = FillInShopOptions({ StoreData = StoreData.RoomShop, RoomName = CurrentRun.CurrentRoom.Name })
                StartUpStore()
            end

            -- Number key 1: Chaos Gate door (spawn door leading to Chaos room)
            if _DebugSpawnChaos then
                _DebugSpawnChaos = nil
                local spawnMsg = "Chaos Gate error"
                pcall(function()
                    -- Determine biome-appropriate Chaos room
                    local curMap = GetMapName({}) or ""
                    local roomName = "RoomSecret01"
                    if curMap:find("^B_") then roomName = "RoomSecret02"
                    elseif curMap:find("^C_") then roomName = "RoomSecret03" end

                    local roomData = RoomData[roomName]
                    if not roomData then
                        spawnMsg = "No room data for " .. roomName
                        return
                    end

                    -- Create the Chaos room
                    local room = CreateRoom(roomData, { SkipChooseReward = true, SkipChooseEncounter = true })
                    room.ChosenRewardType = "TrialUpgrade"
                    room.ForceLootName = "TrialUpgrade"

                    -- Try to find an existing inactive SecretDoor first
                    local doorId = nil
                    local inactiveDoors = GetInactiveIds({ Name = "SecretDoor" })
                    if inactiveDoors and #inactiveDoors > 0 then
                        doorId = inactiveDoors[1]
                        Activate({ Id = doorId })
                    end

                    -- If no existing door, spawn one near player
                    if not doorId then
                        doorId = SpawnObstacle({
                            Name = "SecretDoor",
                            Group = "Standing",
                            DestinationId = CurrentRun.Hero.ObjectId,
                            OffsetX = 200,
                        })
                    end

                    if doorId and doorId > 0 then
                        -- Build door table from SecretDoor data
                        local door = {}
                        if ObstacleData and ObstacleData.SecretDoor then
                            door = DeepCopyTable(ObstacleData.SecretDoor)
                        end
                        door.ObjectId = doorId
                        door.Room = room
                        door.ReadyToUse = true
                        door.HealthCost = 20

                        -- Register and make interactive
                        OfferedExitDoors[doorId] = door
                        AddToGroup({ Id = doorId, Name = "ExitDoors" })
                        pcall(RefreshUseButton, doorId, door)
                        pcall(CreateDoorRewardPreview, door)
                        pcall(function()
                            SetAnimation({ DestinationId = doorId, Name = "SecretDoor_Revealed" })
                        end)
                        UseableOn({ Id = doorId })
                        spawnMsg = "Chaos Gate door spawned"
                    else
                        spawnMsg = "Failed to create door obstacle"
                    end
                end)
                if AccessibilityEnabled and AccessibilityEnabled() then
                    TolkSpeak(spawnMsg)
                end
            end

            -- Number key 2: NPC room door (spawn door leading to story NPC room)
            if _DebugSpawnNPC then
                _DebugSpawnNPC = nil
                local spawnMsg = "NPC door error"
                pcall(function()
                    -- Determine biome-appropriate story room
                    local curMap = GetMapName({}) or ""
                    local roomName = "A_Story01"
                    local npcName = "Sisyphus"
                    if curMap:find("^B_") then
                        roomName = "B_Story01"
                        npcName = "Eurydice"
                    elseif curMap:find("^C_") then
                        roomName = "C_Story01"
                        npcName = "Patroclus"
                    end

                    local roomData = RoomData[roomName]
                    if not roomData then
                        spawnMsg = "No room data for " .. roomName
                        return
                    end

                    -- Create the NPC story room
                    local room = CreateRoom(roomData, { SkipChooseReward = true, SkipChooseEncounter = true })
                    room.ChosenRewardType = "Story"

                    -- Try to find an existing inactive ExitDoor first
                    local doorId = nil
                    local inactiveDoors = GetInactiveIds({ Name = "ExitDoor" })
                    if inactiveDoors and #inactiveDoors > 0 then
                        -- Use the LAST inactive door (least likely to conflict with normal doors)
                        doorId = inactiveDoors[#inactiveDoors]
                        Activate({ Id = doorId })
                    end

                    -- If no existing door, spawn one near player
                    if not doorId then
                        doorId = SpawnObstacle({
                            Name = "ExitDoor",
                            Group = "Standing",
                            DestinationId = CurrentRun.Hero.ObjectId,
                            OffsetX = -200,
                        })
                    end

                    if doorId and doorId > 0 then
                        -- Build door table from ExitDoor data
                        local door = {}
                        if ObstacleData and ObstacleData.ExitDoor then
                            door = DeepCopyTable(ObstacleData.ExitDoor)
                        end
                        door.ObjectId = doorId
                        door.Room = room
                        door.ReadyToUse = true

                        -- Register and make interactive
                        OfferedExitDoors[doorId] = door
                        AddToGroup({ Id = doorId, Name = "ExitDoors" })
                        pcall(RefreshUseButton, doorId, door)
                        pcall(CreateDoorRewardPreview, door)
                        pcall(function()
                            SetAnimation({ DestinationId = doorId, Name = "DoorExitLight" })
                        end)
                        UseableOn({ Id = doorId })
                        spawnMsg = "Door to " .. npcName .. " spawned"
                    else
                        spawnMsg = "Failed to create door obstacle"
                    end
                end)
                if AccessibilityEnabled and AccessibilityEnabled() then
                    TolkSpeak(spawnMsg)
                end
            end

            -- Number key 3: Weapon Upgrade screen
            if _DebugOpenWeaponUpgrade then
                _DebugOpenWeaponUpgrade = nil
                local weapon = GetEquippedWeapon and GetEquippedWeapon() or "SwordWeapon"
                if ShowWeaponUpgradeScreen then
                    ShowWeaponUpgradeScreen({ WeaponName = weapon })
                end
            end

            -- Number key 4: Sell Trait (Purging Pool) screen
            if _DebugOpenSellTrait then
                _DebugOpenSellTrait = nil
                if GenerateSellTraitShop and OpenSellTraitMenu then
                    GenerateSellTraitShop(CurrentRun, CurrentRun.CurrentRoom)
                    OpenSellTraitMenu()
                end
            end

            -- Number key 5: Run Clear screen
            if _DebugOpenRunClear then
                _DebugOpenRunClear = nil
                if ShowRunClearScreen then
                    ShowRunClearScreen()
                end
            end

        end

        -- Number key 6: Max Rail + 1B health + 1M resources including Obols (works in house too)
        if _DebugMaxGun then
            _DebugMaxGun = nil
            local spawnMsg = ""
            -- Grant 1M of each resource (works in house — GameState exists everywhere)
            pcall(function()
                if GameState and GameState.Resources then
                    local resources = {"MetaPoints", "Gems", "LockKeys", "GiftPoints", "SuperGems", "SuperGiftPoints", "SuperLockKeys", "Money"}
                    for _, res in ipairs(resources) do
                        GameState.Resources[res] = (GameState.Resources[res] or 0) + 1000000
                    end
                    spawnMsg = "Granted 1 million of each resource"
                end
            end)
            -- In-run: 1B health, max Adamant Rail + Aspect of Lucifer, set enemy HP to 1
            if CurrentRun and CurrentRun.CurrentRoom then
                -- 1 billion health
                CurrentRun.Hero.MaxHealth = 1000000000
                CurrentRun.Hero.Health = 1000000000
                -- Unlock and max Adamant Rail + Aspect of Lucifer
                pcall(function()
                    if GameState then
                        if not GameState.WeaponUnlocks then GameState.WeaponUnlocks = {} end
                        if type(GameState.WeaponUnlocks.GunWeapon) ~= "table" then
                            GameState.WeaponUnlocks.GunWeapon = {}
                        end
                        GameState.WeaponUnlocks.GunWeapon[1] = 5
                        GameState.WeaponUnlocks.GunWeapon[4] = 5
                        if not GameState.LastWeaponUpgradeData then GameState.LastWeaponUpgradeData = {} end
                        GameState.LastWeaponUpgradeData.GunWeapon = { Index = 4 }
                    end
                end)
                pcall(function()
                    if EquipPlayerWeapon and WeaponData and WeaponData.GunWeapon then
                        EquipPlayerWeapon(WeaponData.GunWeapon)
                    end
                end)
                spawnMsg = spawnMsg .. ", Adamant Rail maxed, 1 billion health"
            end
            if AccessibilityEnabled and AccessibilityEnabled() then
                TolkSpeak(spawnMsg)
            end
        end

        -- Number key 7: Enable flashback 1 (set AllowFlashback flag, then use bed)
        if _DebugFlashback then
            _DebugFlashback = nil
            local spawnMsg = "Flashback error"
            pcall(function()
                local curMap = GetMapName({}) or ""
                if curMap ~= "DeathAreaBedroom" then
                    spawnMsg = "Go to the bedroom first"
                    return
                end
                if not GameState or not GameState.Flags then
                    spawnMsg = "GameState not ready"
                    return
                end
                -- Set AllowFlashback flag (normally set by death presentation after meeting requirements)
                GameState.Flags.AllowFlashback = true
                -- Ensure HadesFirstMeeting is set (required by BedPrompt objective)
                if not GameState.TextLinesRecord then
                    GameState.TextLinesRecord = {}
                end
                GameState.TextLinesRecord["HadesFirstMeeting"] = true
                -- Clear Flashback_Mother_01 record to allow replay (PlayOnce = true blocks it otherwise)
                GameState.TextLinesRecord["Flashback_Mother_01"] = nil
                -- Also clear from CurrentRun text records if present
                if CurrentRun and CurrentRun.TextLinesRecord then
                    CurrentRun.TextLinesRecord["Flashback_Mother_01"] = nil
                end
                -- Make the default bed (hardcoded ID 310036) useable
                -- The bed is always object 310036 in DeathAreaBedroom (from DeathLoopData)
                pcall(UseableOn, { Id = 310036 })
                -- Also try the fancy bed (555810) if it exists
                pcall(UseableOn, { Id = 555810 })
                -- Re-trigger the BedPrompt objective (normally checked at room entry)
                pcall(CheckObjectiveSet, "BedPrompt")
                spawnMsg = "Flashback 1 enabled, use the bed"
            end)
            if AccessibilityEnabled and AccessibilityEnabled() then
                TolkSpeak(spawnMsg)
            end
        end

        -- Number key 8: Enable flashback 2 (requires Flashback_Mother_01 prereq)
        if _DebugFlashback2 then
            _DebugFlashback2 = nil
            local spawnMsg = "Flashback error"
            pcall(function()
                local curMap = GetMapName({}) or ""
                if curMap ~= "DeathAreaBedroom" then
                    spawnMsg = "Go to the bedroom first"
                    return
                end
                if not GameState or not GameState.Flags then
                    spawnMsg = "GameState not ready"
                    return
                end
                GameState.Flags.AllowFlashback = true
                if not GameState.TextLinesRecord then
                    GameState.TextLinesRecord = {}
                end
                GameState.TextLinesRecord["HadesFirstMeeting"] = true
                -- Flashback 2 requires Flashback_Mother_01 to have been seen
                GameState.TextLinesRecord["Flashback_Mother_01"] = true
                -- Clear Flashback_DayNightJob_01 record to allow replay (PlayOnce = true blocks it otherwise)
                GameState.TextLinesRecord["Flashback_DayNightJob_01"] = nil
                if CurrentRun and CurrentRun.TextLinesRecord then
                    CurrentRun.TextLinesRecord["Flashback_DayNightJob_01"] = nil
                end
                -- Make the default bed (hardcoded ID 310036) useable
                pcall(UseableOn, { Id = 310036 })
                pcall(UseableOn, { Id = 555810 })
                -- Re-trigger the BedPrompt objective
                pcall(CheckObjectiveSet, "BedPrompt")
                spawnMsg = "Flashback 2 enabled, use the bed"
            end)
            if AccessibilityEnabled and AccessibilityEnabled() then
                TolkSpeak(spawnMsg)
            end
        end

        -- Number key 9: Spawn fishing point in current room
        if _DebugSpawnFish then
            _DebugSpawnFish = nil
            local spawnMsg = "Fishing point error"
            pcall(function()
                if not CurrentRun or not CurrentRun.CurrentRoom then
                    spawnMsg = "Not in a run"
                    return
                end

                -- Check if room already has a fishing point active
                if CurrentRun.CurrentRoom.FishingPointId then
                    spawnMsg = "Room already has a fishing point"
                    return
                end

                -- Find inactive fishing points in the room
                local fishingPoints = GetInactiveIdsByType({ Name = "FishingPoint" })
                if not fishingPoints or #fishingPoints == 0 then
                    spawnMsg = "No fishing point locations in this room"
                    return
                end

                -- Activate a random fishing point
                local fishId = GetRandomValue(fishingPoints)
                Activate({ Id = fishId })
                CurrentRun.CurrentRoom.FishingPointId = fishId
                CurrentRun.CurrentRoom.ForceFishing = true

                -- Play the activation animation + sound
                SetAnimation({ Name = "FishingPointActive", DestinationId = fishId })
                PlaySound({ Name = "/Leftovers/SFX/AnnouncementPing7", Id = fishId })

                -- Make it useable
                UseableOn({ Id = fishId })

                spawnMsg = "Fishing point spawned"
            end)
            if AccessibilityEnabled and AccessibilityEnabled() then
                TolkSpeak(spawnMsg)
            end
        end

        -- Number key 0: Spawn healing fountain
        if _DebugSpawnFountain then
            _DebugSpawnFountain = nil
            local spawnMsg = "Fountain error"
            pcall(function()
                if not CurrentRun or not CurrentRun.CurrentRoom then
                    spawnMsg = "Not in a run"
                    return
                end

                -- Pick biome-appropriate fountain type
                local curMap = GetMapName({}) or ""
                local fountainType = "HealthFountain"
                if curMap:find("^B_") then
                    fountainType = "HealthFountainAsphodel"
                elseif curMap:find("^C_") then
                    fountainType = "HealthFountainElysium"
                elseif curMap:find("Styx") then
                    fountainType = "HealthFountainStyx"
                end

                -- Try to find an inactive fountain already in the room
                local fountainId = nil
                local inactives = GetInactiveIdsByType({ Name = fountainType })
                if inactives and #inactives > 0 then
                    fountainId = inactives[1]
                    Activate({ Id = fountainId })
                end

                -- If none found, try spawning one near the player
                if not fountainId then
                    fountainId = SpawnObstacle({
                        Name = fountainType,
                        Group = "Standing",
                        DestinationId = CurrentRun.Hero.ObjectId,
                        OffsetX = 150,
                    })
                end

                if fountainId and fountainId > 0 then
                    UseableOn({ Id = fountainId })
                    SetAnimation({ Name = "HealthFountainActive", DestinationId = fountainId })
                    PlaySound({ Name = "/Leftovers/SFX/AnnouncementPing7", Id = fountainId })
                    spawnMsg = "Healing fountain spawned"
                else
                    spawnMsg = "Failed to spawn fountain"
                end
            end)
            if AccessibilityEnabled and AccessibilityEnabled() then
                TolkSpeak(spawnMsg)
            end
        end
        wait(0.1)
    end
end)
