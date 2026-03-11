--[[
Mod: AccessibleGameStats
Author: Accessibility Layer
Version: 11

Provides screen reader accessibility for the Game Stats / Run Tracker screen.
- Speaks "Run Tracker" + category name when screen opens
- Left/Right changes categories, speaks category name + items
- Up/Down scrolls pages natively, reads page number + items on that page
- All speech combined into single TolkSpeak call to prevent interruption
--]]

local function _Log(msg) if LogEvent then LogEvent(msg) end end

local categoryDisplayNames = {
    ["GameStats_Weapons"] = "Weapons",
    ["GameStats_All"] = "All Boons",
    ["GameStats_Boons"] = "God Boons",
    ["GameStats_WeaponUpgrades"] = "Daedalus Upgrades",
    ["GameStats_Aspects"] = "Aspects",
    ["GameStats_Keepsakes"] = "Keepsakes",
    ["GameStats_RoomRewards"] = "Room Rewards",
}

local weaponDisplayNames = {
    ["SwordWeapon"] = "Stygian Blade",
    ["BowWeapon"] = "Heart-Seeking Bow",
    ["SpearWeapon"] = "Eternal Spear",
    ["GunWeapon"] = "Adamant Rail",
    ["FistWeapon"] = "Twin Fists",
    ["ShieldWeapon"] = "Shield of Chaos",
}

-- Build a single string with all weapon stats
local function BuildWeaponStatsString()
    if not WeaponSets or not WeaponSets.HeroMeleeWeapons then return "" end
    local parts = {}
    for _, weaponName in ipairs(WeaponSets.HeroMeleeWeapons) do
        local displayName = weaponDisplayNames[weaponName] or weaponName
        if not IsWeaponUnlocked or not IsWeaponUnlocked(weaponName) then
            parts[#parts + 1] = displayName .. " Locked"
        else
            local runs = GetNumRunsWithWeapon and GetNumRunsWithWeapon(weaponName) or 0
            local clears = GetNumRunsClearedWithWeapon and GetNumRunsClearedWithWeapon(weaponName) or 0
            local item = displayName .. " " .. runs .. " runs " .. clears .. " clears"
            local fastestTime = GetFastestRunClearTimeWithWeapon and GetFastestRunClearTimeWithWeapon(CurrentRun, weaponName)
            if fastestTime and fastestTime < 999999 then
                item = item .. " " .. string.format(UIStrings.BestTimeFmt, math.floor(fastestTime / 60), math.floor(fastestTime % 60))
            end
            local highestHeat = GetHighestShrinePointRunClearWithWeapon and GetHighestShrinePointRunClearWithWeapon(CurrentRun, weaponName)
            if highestHeat and highestHeat > 0 then
                item = item .. " " .. string.format(UIStrings.HeatLabelFmt, highestHeat)
            end
            parts[#parts + 1] = item
        end
    end
    local result = ""
    for i, p in ipairs(parts) do
        if i > 1 then result = result .. ", " end
        result = result .. p
    end
    return result
end

-- Build a single string with current page trait stats
local function BuildCurrentPageString(screen)
    if not screen or not screen.CurrentFilter then return "" end
    if screen.CurrentFilter == "GameStats_Weapons" then
        return BuildWeaponStatsString()
    end

    -- Build full sorted trait list
    local traitStats = {}
    local totalTraitCache = {}
    if CurrentRun and CurrentRun.TraitCache then
        for traitName, count in pairs(CurrentRun.TraitCache) do
            traitStats[traitName] = traitStats[traitName] or {}
            totalTraitCache[traitName] = (totalTraitCache[traitName] or 0) + 1
            if CurrentRun.Cleared then
                traitStats[traitName].NumClears = (traitStats[traitName].NumClears or 0) + 1
                if CurrentRun.GameplayTime and CurrentRun.GameplayTime < (traitStats[traitName].FastestClearTime or 999999) then
                    traitStats[traitName].FastestClearTime = CurrentRun.GameplayTime
                end
                if CurrentRun.ShrinePointsCache and CurrentRun.ShrinePointsCache > (traitStats[traitName].HighestShrinePoints or 0) then
                    traitStats[traitName].HighestShrinePoints = CurrentRun.ShrinePointsCache
                end
            end
        end
    end
    if GameState and GameState.RunHistory then
        for _, run in ipairs(GameState.RunHistory) do
            if run.TraitCache then
                for traitName, count in pairs(run.TraitCache) do
                    traitStats[traitName] = traitStats[traitName] or {}
                    totalTraitCache[traitName] = (totalTraitCache[traitName] or 0) + 1
                    if run.Cleared then
                        traitStats[traitName].NumClears = (traitStats[traitName].NumClears or 0) + 1
                        if run.GameplayTime and run.GameplayTime < (traitStats[traitName].FastestClearTime or 999999) then
                            traitStats[traitName].FastestClearTime = run.GameplayTime
                        end
                        if run.ShrinePointsCache and run.ShrinePointsCache > (traitStats[traitName].HighestShrinePoints or 0) then
                            traitStats[traitName].HighestShrinePoints = run.ShrinePointsCache
                        end
                    end
                end
            end
        end
    end

    local sortedTraits = {}
    for traitName, count in pairs(totalTraitCache) do
        if PassesTraitFilter(screen.CurrentFilter, traitName) then
            sortedTraits[#sortedTraits + 1] = { Name = traitName, Count = count }
        end
    end
    table.sort(sortedTraits, function(a, b)
        if a.Count ~= b.Count then return a.Count > b.Count end
        return a.Name < b.Name
    end)

    local itemsPerPage = GetLocalizedValue and GetLocalizedValue(screen.ItemsPerPage, screen.LangItemsPerPage) or screen.ItemsPerPage or 15
    local offset = screen.ScrollOffset or 0
    local totalItems = #sortedTraits
    local totalPages = math.max(1, math.ceil(totalItems / itemsPerPage))
    local pageNum = math.floor(offset / itemsPerPage) + 1

    local result = string.format(UIStrings.PageFmt, pageNum, totalPages)

    local startIdx = offset + 1
    local endIdx = math.min(offset + itemsPerPage, totalItems)
    for i = startIdx, endIdx do
        local entry = sortedTraits[i]
        if entry then
            local displayName = GetDisplayName({ Text = entry.Name })
            if not displayName or displayName == "" or displayName == entry.Name then
                displayName = entry.Name
            end
            local item = displayName .. " " .. string.format(UIStrings.UsedTimesFmt, entry.Count)
            local stats = traitStats[entry.Name]
            if stats then
                if stats.NumClears then
                    item = item .. " " .. string.format(UIStrings.NumClearsFmt, stats.NumClears)
                end
                if stats.FastestClearTime and stats.FastestClearTime < 999999 then
                    item = item .. " " .. string.format(UIStrings.BestTimeFmt, math.floor(stats.FastestClearTime / 60), math.floor(stats.FastestClearTime % 60))
                end
                if stats.HighestShrinePoints and stats.HighestShrinePoints > 0 then
                    item = item .. " " .. string.format(UIStrings.HeatLabelFmt, stats.HighestShrinePoints)
                end
            end
            result = result .. ", " .. item
        end
    end

    return result
end

-- Screen open (baseFunc blocks in HandleScreenInput)
ModUtil.WrapBaseFunction("ShowGameStatsScreen", function(baseFunc)
    _Log("[SCREEN-OPEN] Run Tracker (ShowGameStatsScreen)")
    if AccessibilityEnabled and AccessibilityEnabled() then
        TolkSilence()
        thread(function()
            wait(0.2)
            local weaponStr = BuildWeaponStatsString()
            local catName = categoryDisplayNames["GameStats_Weapons"] or "Weapons"
            TolkSpeak(UIStrings.RunTracker .. ", " .. string.format(UIStrings.CategoryFmt, catName) .. ", " .. weaponStr)
        end)
    end
    return baseFunc()
end)

-- Category changes (Left/Right)
ModUtil.WrapBaseFunction("GameStatsSelectCategory", function(baseFunc, screen, button)
    baseFunc(screen, button)
    if not AccessibilityEnabled or not AccessibilityEnabled() or not screen then return end
    local catName = categoryDisplayNames[screen.CurrentFilter] or screen.CurrentFilter
    TolkSilence()
    TolkSpeak(string.format(UIStrings.CategoryFmt, catName) .. ", " .. BuildCurrentPageString(screen))
end)

ModUtil.WrapBaseFunction("GameStatsNextCategory", function(baseFunc, screen, button)
    baseFunc(screen, button)
    if not AccessibilityEnabled or not AccessibilityEnabled() or not screen then return end
    local catName = categoryDisplayNames[screen.CurrentFilter] or screen.CurrentFilter
    TolkSilence()
    TolkSpeak(string.format(UIStrings.CategoryFmt, catName) .. ", " .. BuildCurrentPageString(screen))
end)

ModUtil.WrapBaseFunction("GameStatsPrevCategory", function(baseFunc, screen, button)
    baseFunc(screen, button)
    if not AccessibilityEnabled or not AccessibilityEnabled() or not screen then return end
    local catName = categoryDisplayNames[screen.CurrentFilter] or screen.CurrentFilter
    TolkSilence()
    TolkSpeak(string.format(UIStrings.CategoryFmt, catName) .. ", " .. BuildCurrentPageString(screen))
end)

-- Page scroll (Up/Down) — native behavior + read items on new page
ModUtil.WrapBaseFunction("GameStatsScrollUp", function(baseFunc, screen, button)
    baseFunc(screen, button)
    if not AccessibilityEnabled or not AccessibilityEnabled() or not screen then return end
    TolkSilence()
    TolkSpeak(BuildCurrentPageString(screen))
end)

ModUtil.WrapBaseFunction("GameStatsScrollDown", function(baseFunc, screen, button)
    baseFunc(screen, button)
    if not AccessibilityEnabled or not AccessibilityEnabled() or not screen then return end
    TolkSilence()
    TolkSpeak(BuildCurrentPageString(screen))
end)
