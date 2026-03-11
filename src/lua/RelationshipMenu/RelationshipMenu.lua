--[[
Mod: RelationshipMenu
Author: hllf
Version: 26

Intended as an accessibility mod. Places Zagreus's relationship status with other NPCs and other related information in a menu.
Use the mod importer to import this mod.
--]]

local function _Log(msg) if LogEvent then LogEvent(msg) end end

OnControlPressed{ "Gift", function(triggerArgs)
    if not AccessibilityEnabled or not AccessibilityEnabled() then return end
    -- Open from the Codex with Gift button (RT/R2 trigger), then close Codex and show relationships
    if IsScreenOpen("Codex") and GameState.Gift ~= nil and NumNPCWithHearts() > 0 then
        wait(0.1)
        CloseCodexScreen()
        OpenRelationshipMenu()
    end
end}

local _relationshipMenuOpen = false

function OpenRelationshipMenu(usee)
    local screen = { Components = {} }
    screen.Name = "BlindAccessibilityRelationshipMenu"
    if _relationshipMenuOpen then
        return
    end
    _relationshipMenuOpen = true
    _Log("[MENU-OPEN] RelationshipMenu (BlindAccessibilityRelationshipMenu)")
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
    components.CloseButton.OnPressedFunctionName = "CloseRelationshipScreen"
    components.CloseButton.ControlHotkey = "Cancel"
    SetScale({ Id = components.ShopBackgroundDim.Id, Fraction = 4 })
    SetColor({ Id = components.ShopBackgroundDim.Id, Color = {0, 0, 0, 1} })
    CreateRelationshipText(screen)

    -- TeleportCursor to first button and speak screen name + first item
    if screen.FirstButtonId then
        TeleportCursor({ DestinationId = screen.FirstButtonId })
        if AccessibilityEnabled and AccessibilityEnabled() and screen.FirstSpeechText then
            TolkSilence()
            TolkSpeak(UIStrings.Relationships .. ", " .. screen.FirstSpeechText)
        end
    end

    screen.KeepOpen = true
    HandleScreenInput( screen )
end

local giftNPCNames = {
    {["key"] = "NPC_Cerberus_01", ["value"] = "Cerberus"},
    {["key"] = "NPC_Achilles_01", ["value"] = "Achilles"},
    {["key"] = "NPC_Nyx_01", ["value"] = "Nyx"},
    {["key"] = "NPC_Thanatos_01", ["value"] = "Thanatos"},
    {["key"] = "NPC_Charon_01", ["value"] = "Charon"},
    {["key"] = "NPC_Hypnos_01", ["value"] = "Hypnos"},
    {["key"] = "NPC_FurySister_01", ["value"] = "Meg"},
    {["key"] = "NPC_Orpheus_01", ["value"] = "Orpheus"},
    {["key"] = "NPC_Dusa_01", ["value"] = "Dusa"},
    {["key"] = "NPC_Skelly_01", ["value"] = "Skelly"},
    {["key"] = "ZeusUpgrade", ["value"] = "Zeus"},
    {["key"] = "PoseidonUpgrade", ["value"] = "Poseidon"},
    {["key"] = "AthenaUpgrade", ["value"] = "Athena"},
    {["key"] = "AphroditeUpgrade", ["value"] = "Aphrodite"},
    {["key"] = "AresUpgrade", ["value"] = "Ares"},
    {["key"] = "ArtemisUpgrade", ["value"] = "Artemis"},
    {["key"] = "DionysusUpgrade", ["value"] = "Dionysus"},
    {["key"] = "HermesUpgrade", ["value"] = "Hermes"},
    {["key"] = "DemeterUpgrade", ["value"] = "Demeter"},
    {["key"] = "TrialUpgrade", ["value"] = "Chaos"},
    {["key"] = "NPC_Sisyphus_01", ["value"] = "Sisyphus"},
    {["key"] = "NPC_Eurydice_01", ["value"] = "Eurydice"},
    {["key"] = "NPC_Patroclus_01", ["value"] = "Patroclus"},
    {["key"] = "NPC_Persephone_Home_01", ["value"] = "Persephone"},
    {["key"] = "NPC_Hades_01", ["value"] = "Hades"},
}

function NumNPCWithHearts()
    num = 0
    for k, v in pairs(giftNPCNames) do
        if GetGiftLevel(v["key"]) > 0 and GetMaxGiftLevel(v["key"]) > 0 then
            num = num + 1
        end
    end
    return num
end

function OnRelationshipItemMouseOver(button)
    if not AccessibilityEnabled or not AccessibilityEnabled() or not button then return end
    local speech = button.displayText or "Unknown"
    _Log("[NAV] RelationshipMenu item: " .. speech)
    TolkSilence()
    TolkSpeak(speech)
end

function CreateRelationshipText(screen)
    local startY = 300
    local yIncrement = 55
    local curY = startY
    local components = screen.Components
    local itemIndex = 0

    -- Helper to create one navigable line
    local function addLine(displayText)
        itemIndex = itemIndex + 1
        local key = "RelationshipItem" .. itemIndex
        components[key] = CreateScreenComponent({
            Name = "MarketSlot",
            Group = "Asses_UI",
            Scale = 0.8,
            X = 960,
            Y = curY
        })
        components[key].displayText = displayText
        components[key].OnMouseOverFunctionName = "OnRelationshipItemMouseOver"
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

    for k, v in pairs(giftNPCNames) do
        npcName = v["key"]
        displayName = v["value"]
        numHearts = GetGiftLevel(npcName)
        maxHearts = GetMaxGiftLevel(npcName)
        if numHearts > 0 and maxHearts > 0 then
            requiredResourceAmount = GetNextGiftResourceQuantity(npcName)
            if requiredResourceAmount == 1 then
                requiredResource = "nectar"
                if GiftData[npcName][numHearts + 1] and GiftData[npcName][numHearts + 1].RequiredResource == "SuperGiftPoints" then
                    requiredResource = "ambrosia"
                end
            else
                requiredResource = requiredResourceAmount .. " nectar"
                if GiftData[npcName][numHearts + 1] and GiftData[npcName][numHearts + 1].RequiredResource == "SuperGiftPoints" then
                    requiredResource = requiredResourceAmount .. " ambrosia"
                end
            end
            completelyUnlocked = IsGiftBarCompletelyUnlocked( npcName )
            lockedLevel = GetLockedLevel(npcName)
            displayText = displayName .. ": " .. numHearts
            if completelyUnlocked then
                displayText = displayText .. "/" .. maxHearts
            end
            displayText = displayText .. " heart"
            if (completelyUnlocked and maxHearts > 1) or numHearts > 1 then
                displayText = displayText .. "s"
            end
            if not completelyUnlocked and numHearts == lockedLevel - 1 then
                displayText = displayText .. ", locked"
            end
            if completelyUnlocked then
                if numHearts == maxHearts then
                    displayText = displayText .. ", forged bond"
                else
                    displayText = displayText .. ", requires " .. requiredResource
                end
            end
            addLine(displayText)
        end
    end

end

function CloseRelationshipScreen( screen, button )
    _Log("[MENU-CLOSE] RelationshipMenu (BlindAccessibilityRelationshipMenu)")
    PlaySound({ Name = "/SFX/Menu Sounds/ContractorMenuClose" })
    CloseScreen( GetAllIds( screen.Components ) )
    UnfreezePlayerUnit()
    screen.KeepOpen = false
    _relationshipMenuOpen = false
    OnScreenClosed({ Flag = screen.Name })
end
