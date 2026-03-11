--[[
Mod: AccessibleMusicPlayer
Author: Accessibility Layer
Version: 1

Provides screen reader accessibility for the Music Player (Jukebox) Screen.
- Adds OnMouseOverFunctionName to music track data for cursor navigation speech
- Speaks track name + play/pause status on cursor hover
- Wraps OpenMusicPlayerScreen to announce screen name + unlocked track count
- Wraps HandleTrackButtonInput to announce play/pause/track change
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
-- Track display names (internal path -> friendly name)
-- From the Hades Original Soundtrack
-- ============================================================
TrackDisplayNames = {
    ["/Music/MusicPlayer/MainThemeMusicPlayer"] = "No Escape",
    ["/Music/MusicPlayer/MusicExploration4MusicPlayer"] = "The House of Hades",
    ["/Music/MusicPlayer/HadesThemeMusicPlayer"] = "Death and I",
    ["/Music/MusicPlayer/MusicHadesResetMusicPlayer"] = "Out of Tartarus",
    ["/Music/MusicPlayer/MusicHadesReset2MusicPlayer"] = "The Painful Way",
    ["/Music/MusicPlayer/MusicHadesReset3MusicPlayer"] = "Mouth of Styx",
    ["/Music/MusicPlayer/MusicTartarus4MusicPlayer"] = "Scourge of the Furies",
    ["/Music/MusicPlayer/MusicAsphodel1MusicPlayer"] = "Through Asphodel",
    ["/Music/MusicPlayer/MusicAsphodel2MusicPlayer"] = "River of Flame",
    ["/Music/MusicPlayer/MusicAsphodel3MusicPlayer"] = "Field of Souls",
    ["/Music/MusicPlayer/MusicElysium1MusicPlayer"] = "The King and the Bull",
    ["/Music/MusicPlayer/MusicElysium2MusicPlayer"] = "The Exalted",
    ["/Music/MusicPlayer/MusicElysium3MusicPlayer"] = "Rage of the Myrmidons",
    ["/Music/MusicPlayer/MusicStyx1MusicPlayer"] = "Gates of Hell",
    ["/Music/MusicPlayer/ChaosThemeMusicPlayer"] = "Primordial Chaos",
    ["/Music/MusicPlayer/ThanatosThemeMusicPlayer"] = "Last Words",
    ["/Music/MusicPlayer/MusicExploration1MusicPlayer"] = "Wretched Shades",
    ["/Music/MusicPlayer/MusicExploration2MusicPlayer"] = "The Bloodless",
    ["/Music/MusicPlayer/MusicExploration3MusicPlayer"] = "From Olympus",
    ["/Music/MusicPlayer/CharonShopThemeMusicPlayer"] = "Final Expense",
    ["/Music/MusicPlayer/CharonFightThemeMusicPlayer"] = "Final Expense (Payback Mix)",
    ["/Music/MusicPlayer/EurydiceSong1MusicPlayer"] = "Good Riddance",
    ["/Music/MusicPlayer/OrpheusSong1MusicPlayer"] = "Lament of Orpheus",
    ["/Music/MusicPlayer/OrpheusSong2MusicPlayer"] = "Hymn to Zagreus",
    ["/Music/MusicPlayer/BossFightMusicMusicPlayer"] = "God of the Dead",
    ["/Music/MusicPlayer/TheUnseenOnesMusicPlayer"] = "The Unseen Ones",
    ["/Music/MusicPlayer/PersephoneThemeMusicPlayer"] = "On the Coast",
    ["/Music/MusicPlayer/EndThemeMusicPlayer"] = "In the Blood",
}

-- ============================================================
-- Get a friendly track name from a track path
-- ============================================================
local function GetFriendlyTrackName(trackPath)
    if not trackPath then return "Unknown Track" end

    -- Try hardcoded name first
    if TrackDisplayNames[trackPath] then
        return TrackDisplayNames[trackPath]
    end

    -- Try GetDisplayName with slash-stripped key (game's localization)
    local locKey = string.gsub(trackPath, "/", "")
    local resolved = SafeGetDisplayName(locKey)
    if resolved ~= "" and resolved ~= locKey then
        return resolved
    end

    -- Extract clean name from path as fallback
    local name = trackPath:match("/([^/]+)$") or trackPath
    name = name:gsub("MusicPlayer$", "")
    -- CamelCase to spaces
    name = name:gsub("(%l)(%u)", "%1 %2")
    name = name:gsub("(%d)(%u)", "%1 %2")
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    return name
end

-- ============================================================
-- Set OnMouseOverFunctionName on all music track data entries
-- These tables get AttachLua'd to PlayButton components by the game
-- ============================================================
if MusicPlayerTrackOrderData and MusicPlayerTrackData then
    for _, trackName in ipairs(MusicPlayerTrackOrderData) do
        local trackData = MusicPlayerTrackData[trackName]
        if trackData then
            trackData.OnMouseOverFunctionName = "AccessibleMusicTrackMouseOver"
        end
    end
end

-- ============================================================
-- Global handler for music track mouse-over
-- Called by UIScripts global handler when cursor moves to a PlayButton
-- Receives the trackData table (linked via AttachLua) as argument
-- ============================================================
function AccessibleMusicTrackMouseOver(button)
    if not AccessibilityEnabled or not AccessibilityEnabled() then return end
    if not IsScreenOpen("MusicPlayer") then return end
    if not button then return end

    local trackName = button.Name
    if not trackName then return end

    local parts = {}

    -- Track name
    local displayName = GetFriendlyTrackName(trackName)
    parts[#parts + 1] = displayName

    -- Currently playing status
    if MusicName == trackName then
        if MusicPlayerTrackPaused then
            parts[#parts + 1] = UIStrings.PausedStatus
        else
            parts[#parts + 1] = UIStrings.NowPlayingStatus
        end
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

-- ============================================================
-- Wrap OpenMusicPlayerScreen to announce screen name + track count
-- ============================================================
ModUtil.WrapBaseFunction("OpenMusicPlayerScreen", function(baseFunc, args)
    _Log("[SCREEN-OPEN] Music Player (OpenMusicPlayerScreen)")
    if AccessibilityEnabled and AccessibilityEnabled() then
        local unlockedCount = 0
        local totalCount = 0
        if MusicPlayerTrackOrderData and MusicPlayerTrackData then
            totalCount = #MusicPlayerTrackOrderData
            for _, trackName in ipairs(MusicPlayerTrackOrderData) do
                local trackData = MusicPlayerTrackData[trackName]
                if trackData and GameState and GameState.Cosmetics and GameState.Cosmetics[trackData.Name] then
                    unlockedCount = unlockedCount + 1
                end
            end
        end
        TolkSilence()
        TolkSpeak(string.format(UIStrings.MusicPlayerOpenFmt, unlockedCount, totalCount))
    end

    baseFunc(args)
end)

-- ============================================================
-- Wrap HandleTrackButtonInput to announce play/pause/track change
-- ============================================================
ModUtil.WrapBaseFunction("HandleTrackButtonInput", function(baseFunc, screen, button)
    -- Capture state before action
    local prevMusic = MusicName
    local prevPaused = MusicPlayerTrackPaused

    baseFunc(screen, button)

    if not AccessibilityEnabled or not AccessibilityEnabled() then return end
    if not button or not button.Data then return end

    local trackName = button.Data.Name
    if not trackName then return end
    local displayName = GetFriendlyTrackName(trackName)

    TolkSilence()
    if MusicPlayerTrackPaused then
        TolkSpeak(string.format(UIStrings.PausedFmt, displayName))
    elseif prevMusic == trackName and prevPaused then
        TolkSpeak(string.format(UIStrings.ResumedFmt, displayName))
    else
        TolkSpeak(string.format(UIStrings.NowPlayingFmt, displayName))
    end
end)
