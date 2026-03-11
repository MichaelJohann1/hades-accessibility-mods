--[[
Mod: AccessibleBoonInfo
Author: Accessibility Layer
Version: 1

Provides screen reader accessibility for the Boon Info Screen (Codex boon detail).
- Accessed from Codex by pressing a button on a god's entry
- Wraps ShowBoonInfoScreen to announce screen name + god name
- Uses OnMouseOver handler for BoonInfoButton components to speak trait names
- Wraps BoonInfoScreenNext/Previous to announce page navigation
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

-- God loot name -> display name
local GodDisplayNames = {
    ZeusUpgrade = "Zeus",
    PoseidonUpgrade = "Poseidon",
    AthenaUpgrade = "Athena",
    AresUpgrade = "Ares",
    AphroditeUpgrade = "Aphrodite",
    ArtemisUpgrade = "Artemis",
    DionysusUpgrade = "Dionysus",
    HermesUpgrade = "Hermes",
    DemeterUpgrade = "Demeter",
    TrialUpgrade = "Chaos",
    WeaponUpgrade = "Daedalus",
}

-- ============================================================
-- Wrap the existing OnMouseOver handler for BoonInfoButton to add speech
-- The game already has an OnMouseOver handler that updates requirements.
-- We add accessibility speech on top of it.
-- ============================================================
OnMouseOver{ "BoonInfoButton",
    function(triggerArgs)
        if not AccessibilityEnabled or not AccessibilityEnabled() then return end
        if not IsScreenOpen("BoonInfoScreen") then return end
        if not triggerArgs or not triggerArgs.triggeredById then return end
        if not ScreenAnchors.BoonInfoScreen then return end

        -- Find which boon this is
        local data = nil
        for i, boonData in pairs(ScreenAnchors.BoonInfoScreen.TraitContainers) do
            if boonData.DetailsBacking and boonData.DetailsBacking.Id == triggerArgs.triggeredById then
                data = boonData
                break
            end
        end
        if not data or not data.TraitName then return end

        local parts = {}

        -- Trait name
        local traitName = data.TraitName
        local displayName = ""

        -- Try BoonDisplayNames from AccessibleBoons if loaded
        if BoonDisplayNames and BoonDisplayNames[traitName] then
            displayName = BoonDisplayNames[traitName]
        end
        if displayName == "" then
            -- Try GetTraitTooltipTitle
            if GetTraitTooltipTitle then
                local ok, titleKey = pcall(GetTraitTooltipTitle, TraitData[traitName] or { Name = traitName })
                if ok and titleKey then
                    displayName = SafeGetDisplayName(titleKey)
                end
            end
        end
        if displayName == "" then
            displayName = SafeGetDisplayName(traitName)
        end
        if displayName == "" then
            displayName = traitName
        end
        parts[#parts + 1] = displayName

        -- Rarity info
        local traitData = TraitData[traitName]
        if traitData then
            if traitData.RarityLevels then
                if traitData.RarityLevels.Legendary then
                    parts[#parts + 1] = UIStrings.Legendary
                elseif traitData.RarityLevels.Heroic then
                    parts[#parts + 1] = string.format(UIStrings.UpToFmt, UIStrings.Heroic)
                elseif traitData.RarityLevels.Epic then
                    parts[#parts + 1] = string.format(UIStrings.UpToFmt, UIStrings.Epic)
                elseif traitData.RarityLevels.Rare then
                    parts[#parts + 1] = string.format(UIStrings.UpToFmt, UIStrings.Rare)
                end
            end
        end

        -- Description from hardcoded table (AccessibleBoons global)
        if GodBoonDescriptions and GodBoonDescriptions[traitName] then
            parts[#parts + 1] = StripFormatting(GodBoonDescriptions[traitName])
        end

        -- Whether the player has used this boon before
        if GameState and GameState.TraitsTaken and GameState.TraitsTaken[traitName] then
            parts[#parts + 1] = UIStrings.PreviouslyAcquired
        else
            parts[#parts + 1] = UIStrings.NotYetAcquired
        end

        -- Build speech
        local speech = ""
        for i, part in ipairs(parts) do
            if i == 1 then
                speech = part
            else
                speech = speech .. ". " .. part
            end
        end

        if speech ~= "" then
            TolkSilence()
            TolkSpeak(speech)
        end
    end
}

-- ============================================================
-- Wrap ShowBoonInfoScreen to announce screen name + god
-- ============================================================
ModUtil.WrapBaseFunction("ShowBoonInfoScreen", function(baseFunc, lootName)
    _Log("[SCREEN-OPEN] Boon Info (ShowBoonInfoScreen) loot=" .. tostring(lootName))
    if AccessibilityEnabled and AccessibilityEnabled() then
        local godName = GodDisplayNames[lootName] or SafeGetDisplayName(lootName) or lootName
        TolkSilence()
        TolkSpeak(UIStrings.BoonInfo .. ", " .. godName .. ". " .. UIStrings.UpDownBrowse .. ".")
    end

    baseFunc(lootName)
end)

-- ============================================================
-- Wrap BoonInfoScreenNext/Previous to announce page changes
-- ============================================================
ModUtil.WrapBaseFunction("BoonInfoScreenNext", function(baseFunc, screen, button)
    baseFunc(screen, button)

    if not AccessibilityEnabled or not AccessibilityEnabled() then return end
    if not screen or not screen.StartingIndex or not screen.SortedTraitIndex then return end

    local totalTraits = #screen.SortedTraitIndex
    local numPerPage = BoonInfoScreenData and BoonInfoScreenData.NumPerPage or 4
    local currentPage = math.ceil(screen.StartingIndex / numPerPage)
    local totalPages = math.ceil(totalTraits / numPerPage)
    TolkSilence()
    TolkSpeak(string.format(UIStrings.PageFmt, currentPage, totalPages))
end)

ModUtil.WrapBaseFunction("BoonInfoScreenPrevious", function(baseFunc, screen, button)
    baseFunc(screen, button)

    if not AccessibilityEnabled or not AccessibilityEnabled() then return end
    if not screen or not screen.StartingIndex or not screen.SortedTraitIndex then return end

    local totalTraits = #screen.SortedTraitIndex
    local numPerPage = BoonInfoScreenData and BoonInfoScreenData.NumPerPage or 4
    local currentPage = math.ceil(screen.StartingIndex / numPerPage)
    local totalPages = math.ceil(totalTraits / numPerPage)
    TolkSilence()
    TolkSpeak(string.format(UIStrings.PageFmt, currentPage, totalPages))
end)
