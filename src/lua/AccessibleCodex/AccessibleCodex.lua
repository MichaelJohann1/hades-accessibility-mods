--[[
Mod: AccessibleCodex
Author: Accessibility Layer
Version: 3

Provides screen reader accessibility for the Codex screen.
- Speaks current chapter (tab) name when switching tabs
- Speaks entry name and CURRENT level description when selecting an entry
  (only the most recently unlocked portion, not all levels concatenated)
- Shows encounters/conversations/kills remaining to next unlock level
- Strips formatting tags for clean screen reader output
- Adds mouse over handlers to entry/tab buttons for cursor navigation
--]]

local function _Log(msg) if LogEvent then LogEvent(msg) end end

-- Strip Hades text formatting tags for clean screen reader output
-- Removes {#ColorCode}, {!Icon}, {$KeyBind}, and other {...} tags
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

-- Map CodexUnlockTypes to human-readable action descriptions
local UnlockTypeDescriptions = {
    Interact = "encounters",
    Slay = "kills",
    SlayAlt = "kills",
    Boon = "boons received",
    Wield = "uses",
    Collect = "collected",
    Unseal = "chambers cleared",
    Fish = "catches",
    Enter = "visits",
    Summon = "summons",
    Mystery = "encounters",
}

-- Build unlock progress text for a codex entry
-- Shows: current level, encounters to next level, or "Fully discovered"
local function GetUnlockProgressText(chapterName, entryName, entryData)
    if not entryData or not entryData.Entries then
        return ""
    end

    local totalPortions = #entryData.Entries
    if totalPortions <= 1 then
        return ""
    end

    local chapterStatus = CodexStatus[chapterName]
    local currentAmount = 0
    if chapterStatus and chapterStatus[entryName] and chapterStatus[entryName].Amount then
        currentAmount = chapterStatus[entryName].Amount
    end

    -- Count unlocked portions and find the next locked threshold
    local unlockedCount = 0
    local cumulativeThreshold = 0
    local nextThresholdRemaining = nil
    local nextPortionHasGameReq = false
    local nextCustomText = nil

    if chapterStatus and chapterStatus[entryName] then
        for index, portion in ipairs(entryData.Entries) do
            local isUnlocked = false
            if chapterStatus[entryName][index] and
               type(chapterStatus[entryName][index]) == "table" and
               chapterStatus[entryName][index].Unlocked then
                isUnlocked = true
            elseif portion.UnlockGameStateRequirements and
                   IsGameStateEligible(CurrentRun, portion.UnlockGameStateRequirements) then
                isUnlocked = true
            end

            if isUnlocked then
                unlockedCount = unlockedCount + 1
                if portion.UnlockThreshold then
                    cumulativeThreshold = cumulativeThreshold + portion.UnlockThreshold
                end
            else
                -- This is the next locked portion
                if portion.UnlockThreshold then
                    local needed = cumulativeThreshold + portion.UnlockThreshold
                    nextThresholdRemaining = needed - currentAmount
                    if nextThresholdRemaining < 1 then
                        nextThresholdRemaining = 1
                    end
                elseif portion.UnlockGameStateRequirements then
                    nextPortionHasGameReq = true
                    if portion.CustomUnlockText then
                        nextCustomText = portion.CustomUnlockText
                    end
                end
                break
            end
        end
    end

    -- Build progress text
    local parts = {}
    parts[#parts + 1] = string.format(UIStrings.EntryOfFmt, unlockedCount, totalPortions)

    if unlockedCount >= totalPortions then
        parts[#parts + 1] = UIStrings.FullyDiscovered
    elseif nextThresholdRemaining then
        -- Get the unlock type for this entry (entry-specific or chapter-wide)
        local unlockType = nil
        if entryData.UnlockType then
            unlockType = entryData.UnlockType
        elseif Codex[chapterName] and Codex[chapterName].UnlockType then
            unlockType = Codex[chapterName].UnlockType
        end
        local actionDesc = UnlockTypeDescriptions[unlockType] or "encounters"
        parts[#parts + 1] = string.format(UIStrings.MoreEncountersFmt, nextThresholdRemaining, actionDesc)
    elseif nextPortionHasGameReq then
        if nextCustomText then
            local customText = StripFormatting(GetDisplayName({ Text = nextCustomText }) or "")
            if customText ~= "" then
                parts[#parts + 1] = customText
            else
                parts[#parts + 1] = UIStrings.ContinueStory
            end
        else
            parts[#parts + 1] = UIStrings.ContinueStory
        end
    end

    -- Build string manually (avoid table.concat -- ModUtil v2.10.0 bug)
    local result = ""
    for i, part in ipairs(parts) do
        if i > 1 then
            result = result .. ". " .. part
        else
            result = part
        end
    end
    return result
end

-- Suppress counter for first auto-focused entry after tab switch
-- (prevents the tab announcement from being interrupted)
suppressCodexEntryHoverCount = 0

-- When a chapter opens, speak its name and add mouse over handlers to entry buttons
ModUtil.WrapBaseFunction("CodexOpenChapter", function(baseFunc, screen, button, args)
    _Log("[SCREEN-OPEN] Codex chapter opened (CodexOpenChapter)")
    baseFunc(screen, button, args)

    if not AccessibilityEnabled or not AccessibilityEnabled() or not button then
        return
    end

    -- Add OnMouseOverFunctionName to each entry button in this chapter
    if button.ChapterName and Codex[button.ChapterName] then
        local sortedCategory = GetSortedCodexSubcategory(button.ChapterName)
        for i, entryName in ipairs(sortedCategory) do
            local entryComp = screen.Components[entryName]
            if entryComp then
                entryComp.OnMouseOverFunctionName = "AccessibleCodexEntryMouseOver"
                AttachLua({ Id = entryComp.Id, Table = entryComp })
            end
        end
    end

    -- Speak the chapter name + first entry name in one call
    if button.ChapterData and button.ChapterData.TitleText then
        local chapterDisplayName = GetDisplayName({ Text = button.ChapterData.TitleText })
        if chapterDisplayName then
            chapterDisplayName = StripFormatting(chapterDisplayName)
            local speech = chapterDisplayName
            -- Get first entry name to combine with chapter name
            if button.ChapterName and Codex[button.ChapterName] then
                local sortedCategory = GetSortedCodexSubcategory(button.ChapterName)
                if sortedCategory and #sortedCategory > 0 then
                    local firstEntryName = GetDisplayName({ Text = sortedCategory[1] })
                    if firstEntryName and firstEntryName ~= "" then
                        firstEntryName = StripFormatting(firstEntryName)
                        if firstEntryName ~= "" then
                            speech = speech .. ", " .. firstEntryName
                        end
                    end
                end
            end
            TolkSilence()
            TolkSpeak(speech)
            -- Suppress the first auto-focused entry so tab announcement isn't interrupted
            suppressCodexEntryHoverCount = 1
        end
    end
end)

-- When an entry is opened (selected/pressed), speak "EntryName: description" + progress
-- Only reads the MOST RECENTLY unlocked portion (matching game behavior), not all levels
ModUtil.WrapBaseFunction("CodexOpenEntry", function(baseFunc, screen, button)
    baseFunc(screen, button)

    if not AccessibilityEnabled or not AccessibilityEnabled() or not button or not button.EntryName or not button.ChapterName then
        return
    end

    local entryDisplayName = GetDisplayName({ Text = button.EntryName })
    if not entryDisplayName or entryDisplayName == "" then
        return
    end
    entryDisplayName = StripFormatting(entryDisplayName)

    -- Find the LAST unlocked portion's text (game only shows the most recent)
    local chapterStatus = CodexStatus[button.ChapterName]
    local description = ""
    if chapterStatus and chapterStatus[button.EntryName] and button.EntryData and button.EntryData.Entries then
        for index, unlockPortion in ipairs(button.EntryData.Entries) do
            local isUnlocked = false
            if chapterStatus[button.EntryName][index] and
               type(chapterStatus[button.EntryName][index]) == "table" and
               chapterStatus[button.EntryName][index].Unlocked then
                isUnlocked = true
            elseif unlockPortion.UnlockGameStateRequirements and
                   IsGameStateEligible(CurrentRun, unlockPortion.UnlockGameStateRequirements) then
                isUnlocked = true
            end

            if isUnlocked then
                -- Overwrite with each unlocked portion — only the LAST one remains
                local portionText = GetDisplayName({ Text = unlockPortion.HelpTextId or unlockPortion.Text })
                if portionText and portionText ~= "" then
                    portionText = StripFormatting(portionText)
                    if portionText ~= "" then
                        description = portionText
                    end
                end
            end
        end
    end

    -- Get unlock progress (includes encounters/conversations to next level)
    local progressText = GetUnlockProgressText(button.ChapterName, button.EntryName, button.EntryData)

    -- Build full speech
    TolkSilence()
    local speech = entryDisplayName
    if description ~= "" then
        speech = speech .. ": " .. description
    end
    if progressText ~= "" then
        speech = speech .. ". " .. progressText
    end
    TolkSpeak(speech)
end)

-- When cursor highlights an entry button, speak the entry name
function AccessibleCodexEntryMouseOver(button)
    if not AccessibilityEnabled or not AccessibilityEnabled() or not button or not button.EntryName then
        return
    end

    if suppressCodexEntryHoverCount > 0 then
        suppressCodexEntryHoverCount = suppressCodexEntryHoverCount - 1
        return
    end

    local entryDisplayName = GetDisplayName({ Text = button.EntryName })
    if entryDisplayName and entryDisplayName ~= "" then
        entryDisplayName = StripFormatting(entryDisplayName)
        TolkSilence()
        TolkSpeak(entryDisplayName)
    end
end

-- Add mouse over handlers to chapter tab buttons when chapters are updated
ModUtil.WrapBaseFunction("CodexUpdateChapters", function(baseFunc, screen)
    baseFunc(screen)

    if not AccessibilityEnabled or not AccessibilityEnabled() then
        return
    end

    -- Add mouse over handlers to chapter tab buttons
    local sortedCodex = GetSortedCodex(Codex)
    for index, chapterName in ipairs(sortedCodex) do
        local comp = screen.Components[chapterName]
        if comp then
            comp.OnMouseOverFunctionName = "AccessibleCodexChapterMouseOver"
            AttachLua({ Id = comp.Id, Table = comp })
        end
    end

    -- Re-enable "Gift" control so RelationshipMenu can use RT/R2 trigger in Codex
    -- FreezePlayerUnit disables Gift, but we need it for the relationship menu shortcut
    ToggleControl({ Names = { "Gift" }, Enabled = true })
end)

-- When cursor highlights a chapter tab, speak the chapter name
function AccessibleCodexChapterMouseOver(button)
    if not AccessibilityEnabled or not AccessibilityEnabled() or not button or not button.ChapterData then
        return
    end

    local chapterDisplayName = GetDisplayName({ Text = button.ChapterData.TitleText })
    if chapterDisplayName and chapterDisplayName ~= "" then
        chapterDisplayName = StripFormatting(chapterDisplayName)
        TolkSilence()
        TolkSpeak(chapterDisplayName)
    end
end
