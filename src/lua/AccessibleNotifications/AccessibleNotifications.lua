--[[
Mod: AccessibleNotifications
Author: Accessibility Layer
Version: 8

Speaks on-screen notifications that aren't handled by other accessibility mods:
- Subtitle reading (toggled by backslash key, off by default; speaks "Speaker: text")
- Dialog choices (NPC benefit selections: Sisyphus, Eurydice, Patroclus)
- Room/location names (biome transitions + special rooms only)
- Health: says current health number on every hit (e.g. "49 health")
- Health gained: says heal amount + current health
- Death Defiance proc announcements
- Boon/trait acquisition (skipped in house/courtyard to avoid spam)
- Keepsake equip announcements
- Weapon equip announcements
- Weapon tutorial objectives (how to use each weapon)
- Keepsake gift received (when NPC gives keepsake after Nectar)
- Fish catch notifications (speaks fish name when caught)
- Survival challenge duration (seconds to survive)
- Infernal Trove + Erebus challenge announcements
- Resource pickup announcements (Darkness, Gemstones, Chthonic Keys, Nectar,
  Ambrosia, Titan Blood, Diamonds, Obols)
- God Mode toggle announcements
--]]

local function _Log(msg) if LogEvent then LogEvent(msg) end end

-- Subtitle toggle (off by default, toggled by backslash key in C++)
if _SubtitleReadingEnabled == nil then
    _SubtitleReadingEnabled = false
end

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

local function SafeGetDisplayName(key)
    if not key or key == "" then return "" end
    local ok, result = pcall(GetDisplayName, { Text = key })
    if ok and result and result ~= "" and result ~= key then
        return StripFormatting(result)
    end
    return ""
end

-- Hardcoded NPC dialog choice display names (GetDisplayName can't always resolve these)
ChoiceDisplayNames = {
    -- Sisyphus choices
    ["ChoiceText_Healing"] = "Health Restoration",
    ["ChoiceText_Darkness"] = "Darkness",
    ["ChoiceText_Money"] = "Obols",
    -- Patroclus choices
    ["ChoiceText_BuffExtraChance"] = "Restore Death Defiance",
    ["ChoiceText_BuffExtraChanceReplenish"] = "Restore Death Defiance",
    ["ChoiceText_BuffHealing"] = "Healing after each Encounter",
    ["ChoiceText_BuffWeapon"] = "Temporary Weapon Buff",
    -- Eurydice choices
    ["ChoiceText_BuffSlottedBoonRarity"] = "Upgrade a random Boon to a higher rarity",
    ["ChoiceText_BuffMegaPom"] = "Level up several random Boons",
    ["ChoiceText_BuffFutureBoonRarity"] = "Next Boon has improved rarity",
}

-- Location display names (fallbacks when GetDisplayName can't resolve)
LocationDisplayNames = {
    ["Location_Tartarus"] = "Tartarus",
    ["Location_Asphodel"] = "Asphodel",
    ["Location_Elysium"] = "Elysium",
    ["Location_Styx"] = "Temple of Styx",
    ["Location_Home"] = "House of Hades",
    ["DeathMessage"] = "Death",
    ["OutroDeathMessageAlt"] = "Death",
    ["DevotionMessage"] = "Trial of the Gods",
    ["BiomeClearedMessage"] = "Biome Cleared",
    ["ThanatosMessage"] = "Thanatos",
    ["Location_Surface"] = "The Surface",
}

-- Weapon display names for equip announcements
WeaponDisplayNames = {
    ["SwordWeapon"] = "Stygian Blade",
    ["BowWeapon"] = "Heart-Seeking Bow",
    ["SpearWeapon"] = "Eternal Spear",
    ["ShieldWeapon"] = "Shield of Chaos",
    ["FistWeapon"] = "Twin Fists of Malphon",
    ["GunWeapon"] = "Adamant Rail",
}

-- Keepsake display names for equip announcements
KeepsakeDisplayNames = {
    ["CerberusKeepsake"] = "Old Spiked Collar",
    ["AchillesKeepsake"] = "Myrmidon Bracer",
    ["NyxKeepsake"] = "Black Shawl",
    ["ThanatosKeepsake"] = "Pierced Butterfly",
    ["ChronKeepsake"] = "Bone Hourglass",
    ["HypnosKeepsake"] = "Chthonic Coin Purse",
    ["MegKeepsake"] = "Skull Earring",
    ["OrpheusKeepsake"] = "Distant Memory",
    ["DusaKeepsake"] = "Harpy Feather Duster",
    ["SkellyKeepsake"] = "Lucky Tooth",
    ["SisyphusKeepsake"] = "Shattered Shackle",
    ["EurydiceKeepsake"] = "Evergreen Acorn",
    ["PatroclusKeepsake"] = "Broken Spearpoint",
    ["ZeusKeepsake"] = "Thunder Signet",
    ["PoseidonKeepsake"] = "Conch Shell",
    ["AthenaKeepsake"] = "Owl Pendant",
    ["AresKeepsake"] = "Blood-Filled Vial",
    ["AphroditeKeepsake"] = "Eternal Rose",
    ["ArtemisKeepsake"] = "Adamant Arrowhead",
    ["DionysusKeepsake"] = "Overflowing Cup",
    ["HermesKeepsake"] = "Lambent Plume",
    ["DemeterKeepsake"] = "Frostbitten Horn",
    ["ChaosKeepsake"] = "Cosmic Egg",
    ["HadesKeepsake"] = "Sigil of the Dead",
    ["ReincarnationTrait"] = "Lucky Tooth",
    -- Companions
    ["FurySummonTrait"] = "Battie",
    ["AntosSummonTrait"] = "Rib",
    ["NpcSummonTrait_Thanatos"] = "Mort",
    ["NpcSummonTrait_Sisyphus"] = "Shady",
    ["NpcSummonTrait_Achilles"] = "Antos",
    ["NpcSummonTrait_Dusa"] = "Fidi",
}

-- Hardcoded weapon tutorial objective descriptions
-- The game uses {A2} = Attack, {A3} = Special, {RL} = Reload input symbols
ObjectiveDescriptions = {
    -- Sword (Stygian Blade)
    ["SwordWeapon"] = "Press Attack to Strike",
    ["SwordParry"] = "Press Special to Nova Smash",
    ["SwordWeaponDash"] = "Press Attack while Dashing to Blink Strike",
    -- Sword (Aspect of Arthur)
    ["SwordWeaponArthur"] = "Press Attack for Heavy Slash",
    ["ConsecrationField"] = "Press Special to create Hallowed Ground",
    -- Spear (Eternal Spear)
    ["SpearWeapon"] = "Press Attack to Strike",
    ["SpearWeaponSpin"] = "Hold then Release Attack to Spin Attack",
    ["SpearWeaponThrow"] = "Press Special to Skewer and Recall",
    ["SpearWeaponDash"] = "Press Attack while Dashing to Blink Strike",
    ["SpearWeaponThrowTeleport"] = "Hold Special to Skewer and Raging Rush",
    ["SpearThrowRegularRetrieve"] = "After Throwing, Press Attack to Recall",
    ["SpearWeaponThrowSingle"] = "Press Special for Crackling Skewer",
    ["SpearWeaponSpinRanged"] = "Hold then Release Attack for Serpent Slash",
    -- Shield (Shield of Chaos)
    ["ShieldWeapon"] = "Press Attack to Bash",
    ["ShieldWeaponRush"] = "Hold Attack to Defend, Release to Bull Rush",
    ["ShieldThrow"] = "Press Special to Throw",
    ["ShieldWeaponDash"] = "Press Attack while Dashing to Blink Strike",
    ["ShieldGrind"] = "Press Special to Throw and Recall",
    ["ShieldRushAndThrow"] = "Bull Rush, then Special to Multi-Throw",
    -- Shield (Aspect of Beowulf)
    ["BeowulfAttack"] = "Press Attack for Dragon Rush",
    ["BeowulfSpecial"] = "Press Special to load Cast into shield",
    ["BeowulfTackle"] = "Hold Attack to Defend, Release to tackle",
    -- Bow (Heart-Seeking Bow)
    ["BowWeapon"] = "Hold Attack to Fire",
    ["BowSplitShot"] = "Press Special to Volley Fire",
    ["PerfectCharge"] = "Release Attack while Flashing to Power Shot",
    ["BowWeaponDash"] = "Press Attack while Dashing to Blink Strike",
    ["LoadAmmoApplicator"] = "Hold Special to load Cast into arrow",
    -- Gun (Adamant Rail)
    ["GunWeapon"] = "Hold Attack to Fire",
    ["GunWeaponManualReload"] = "Press Reload to Reload",
    ["GunGrenadeToss"] = "Hold then Release Special to Bombard",
    ["GunWeaponDash"] = "Press Attack while Dashing to Blink Strike",
    ["ManualReload"] = "Press Reload to Reload",
    ["GunEmpower"] = "Reload after emptying clip for bonus damage",
    ["GunGrenadeLucifer"] = "Hold then Release Special for Hellfire",
    ["GunGrenadeLuciferBlast"] = "Detonate Hellfire with Attack",
    ["GunWeaponActiveReload"] = "Press Reload while flashing for Empowered Shot",
    -- Fists (Twin Fists)
    ["FistWeapon"] = "Hold Attack to Pummel",
    ["FistWeaponSpecial"] = "Press Special for Rising Cutter",
    ["FistWeaponDash"] = "Press Attack while Dashing to Dash Strike",
    ["FistWeaponSpecialDash"] = "Press Special while Dashing to Dash Upper",
    ["FistWeaponFistWeave"] = "Land 5 Strikes then Press Special for Giga Cutter",
    ["FistSpecialVacuum"] = "Hold Special to Vacuum",
    -- Fists (Aspect of Gilgamesh)
    ["FistWeaponGilgamesh"] = "Press Attack for Maim Strike",
    ["RushWeaponGilgamesh"] = "Dash for Dash Strike with Maim",
    ["FistDetonationWeapon"] = "Special to Detonate Maim",
    -- General
    ["EXMove"] = "Press Attack and Special together for EX Move",
    ["SuperMove"] = "Press the Call button for Aid",
    ["BuildSuper"] = "Build your God Gauge to use Aid",
    ["ModifiedRush"] = "Dash with special ability active",
    ["ModifiedRanged"] = "Cast with special ability active",
}

-- Keepsake internal names to display names (for gift received notifications)
-- These map TraitData keys to friendly keepsake names
KeepsakeGiftNames = {
    -- God keepsakes
    ["ZeusKeepsake"] = "Thunder Signet",
    ["PoseidonKeepsake"] = "Conch Shell",
    ["AthenaKeepsake"] = "Owl Pendant",
    ["AresKeepsake"] = "Blood-Filled Vial",
    ["AphroditeKeepsake"] = "Eternal Rose",
    ["ArtemisKeepsake"] = "Adamant Arrowhead",
    ["DionysusKeepsake"] = "Overflowing Cup",
    ["HermesKeepsake"] = "Lambent Plume",
    ["DemeterKeepsake"] = "Frostbitten Horn",
    ["ChaosKeepsake"] = "Cosmic Egg",
    -- House keepsakes
    ["MaxHealthKeepsakeTrait"] = "Old Spiked Collar",
    ["DirectionalArmorTrait"] = "Broken Spearpoint",
    ["ReincarnationTrait"] = "Lucky Tooth",
    ["CerberusKeepsake"] = "Old Spiked Collar",
    ["AchillesKeepsake"] = "Myrmidon Bracer",
    ["NyxKeepsake"] = "Black Shawl",
    ["ThanatosKeepsake"] = "Pierced Butterfly",
    ["ChronKeepsake"] = "Bone Hourglass",
    ["HypnosKeepsake"] = "Chthonic Coin Purse",
    ["MegKeepsake"] = "Skull Earring",
    ["OrpheusKeepsake"] = "Distant Memory",
    ["DusaKeepsake"] = "Harpy Feather Duster",
    ["SkellyKeepsake"] = "Lucky Tooth",
    ["SisyphusKeepsake"] = "Shattered Shackle",
    ["EurydiceKeepsake"] = "Evergreen Acorn",
    ["PatroclusKeepsake"] = "Broken Spearpoint",
    ["HadesKeepsake"] = "Sigil of the Dead",
    -- Companions
    ["FurySummonTrait"] = "Battie",
    ["AntosSummonTrait"] = "Rib",
    ["NpcSummonTrait_Thanatos"] = "Mort",
    ["NpcSummonTrait_Sisyphus"] = "Shady",
    ["NpcSummonTrait_Achilles"] = "Antos",
    ["NpcSummonTrait_Dusa"] = "Fidi",
}

-- NPC display names for keepsake gift and subtitle speaker announcements
NPCDisplayNames = {
    -- Main characters
    ["CharProtag"] = "Zagreus",
    ["PlayerUnit"] = "Zagreus",
    ["PlayerUnit_Intro"] = "Zagreus",
    -- House NPCs
    ["NPC_Hades_01"] = "Hades",
    ["NPC_Cerberus_01"] = "Cerberus",
    ["NPC_Achilles_01"] = "Achilles",
    ["NPC_Achilles_Story_01"] = "Achilles",
    ["NPC_Nyx_01"] = "Nyx",
    ["NPC_Thanatos_01"] = "Thanatos",
    ["NPC_Charon_01"] = "Charon",
    ["NPC_Hypnos_01"] = "Hypnos",
    ["NPC_Megaera_01"] = "Megaera",
    ["NPC_Orpheus_01"] = "Orpheus",
    ["NPC_Dusa_01"] = "Dusa",
    ["NPC_Skelly_01"] = "Skelly",
    ["SkellyBackstory"] = "Skelly",
    -- Run NPCs
    ["NPC_Sisyphus_01"] = "Sisyphus",
    ["NPC_Eurydice_01"] = "Eurydice",
    ["NPC_Patroclus_01"] = "Patroclus",
    ["NPC_Patroclus_Unnamed_01"] = "Patroclus",
    ["NPC_Bouldy_01"] = "Bouldy",
    -- Persephone
    ["NPC_Persephone_01"] = "Persephone",
    ["NPC_Persephone_Home_01"] = "Persephone",
    ["NPC_Persephone_Unnamed_01"] = "Persephone",
    -- Fury Sisters
    ["NPC_FurySister_01"] = "Megaera",
    ["NPC_FurySister_02"] = "Alecto",
    ["NPC_FurySister_03"] = "Tisiphone",
    -- Bosses / Enemies
    ["NPC_Theseus_01"] = "Theseus",
    ["Theseus"] = "Theseus",
    ["NPC_Asterius_01"] = "Asterius",
    ["Asterius"] = "Asterius",
    -- Chaos
    ["NPC_Chaos_01"] = "Chaos",
    ["Chaos"] = "Chaos",
}

-- Fish internal names to display names (from voice line comments in FishingData.lua)
FishDisplayNames = {
    -- Tartarus (rivers of blood)
    ["Fish_Tartarus_Common_01"] = "Hellfish",
    ["Fish_Tartarus_Rare_01"] = "Knucklehead",
    ["Fish_Tartarus_Legendary_01"] = "Scyllascion",
    -- Asphodel (lava rivers)
    ["Fish_Asphodel_Common_01"] = "Slavug",
    ["Fish_Asphodel_Rare_01"] = "Chrustacean",
    ["Fish_Asphodel_Legendary_01"] = "Flameater",
    -- Elysium (clear streams)
    ["Fish_Elysium_Common_01"] = "Chlam",
    ["Fish_Elysium_Rare_01"] = "Charp",
    ["Fish_Elysium_Legendary_01"] = "Seamare",
    -- Temple of Styx (poisonous pools)
    ["Fish_Styx_Common_01"] = "Gupp",
    ["Fish_Styx_Rare_01"] = "Scuffer",
    ["Fish_Styx_Legendary_01"] = "Stonewhal",
    -- Chaos (void pools)
    ["Fish_Chaos_Common_01"] = "Mati",
    ["Fish_Chaos_Rare_01"] = "Projelly",
    ["Fish_Chaos_Legendary_01"] = "Voidskate",
    -- Surface (Greece)
    ["Fish_Surface_Common_01"] = "Trout",
    ["Fish_Surface_Rare_01"] = "Bass",
    ["Fish_Surface_Legendary_01"] = "Sturgeon",
}

-- Fish rarity from internal name
local function GetFishRarity(fishName)
    if not fishName then return "" end
    if fishName:find("Legendary") then return "Legendary"
    elseif fishName:find("Rare") then return "Rare"
    elseif fishName:find("Common") then return "Common"
    end
    return ""
end

--------------------------------------------------------------
-- 1) Dialog / Subtitle Reading + Dialog Choices
--------------------------------------------------------------
-- DisplayTextLine handles:
--   a) Subtitle reading (when _SubtitleReadingEnabled, toggled by backslash key)
--   b) Dialog choices (NPC benefit selections: Sisyphus, Eurydice, Patroclus)
-- C++ Wrap_DisplayTextLine is a pass-through; this Lua wrapper handles all speech.
-- IMPORTANT: baseFunc BLOCKS until the player advances or selects a choice.
-- We must speak BEFORE calling baseFunc.

function OnDialogChoiceMouseOver(button)
    if not AccessibilityEnabled or not AccessibilityEnabled() then return end
    if not button or not button.choiceSpeech then return end
    TolkSilence()
    TolkSpeak(button.choiceSpeech)
end

ModUtil.WrapBaseFunction("DisplayTextLine", function(baseFunc, screen, source, line, parentLine)
    if not AccessibilityEnabled or not AccessibilityEnabled() then
        return baseFunc(screen, source, line, parentLine)
    end

    -- Subtitle reading (toggled by backslash key, off by default)
    if _SubtitleReadingEnabled and line and line.Text and not line.Choices then
        local ok, err = pcall(function()
            local displayText = ""

            -- Try translated text via dialogue ID from Cue field.
            -- Dialogue text in Lua data is always English; non-English translations
            -- are in _*Data.{lang}.sjson files loaded by the engine, keyed by the
            -- Cue ID (e.g. "/VO/Hades_0088" -> "Hades_0088"). GetDisplayName
            -- resolves these IDs to translated text when the game runs non-English.
            if line.Cue and line.Cue ~= "" then
                local dialogueId = line.Cue:gsub("^/VO/", "")
                if dialogueId ~= "" then
                    displayText = SafeGetDisplayName(dialogueId)
                end
            end

            -- Fall back to raw line.Text (works for English, or if Cue is missing)
            if displayText == "" then
                displayText = SafeGetDisplayName(line.Text)
            end
            if displayText == "" then
                displayText = StripFormatting(line.Text or "")
            end

            if displayText ~= "" then
                -- Get speaker name (same as Narrative.lua line 470)
                local speakerKey = ""
                if line.Speaker then
                    speakerKey = line.Speaker
                elseif source then
                    speakerKey = source.Speaker or source.Name or ""
                end
                local speakerName = NPCDisplayNames[speakerKey] or SafeGetDisplayName(speakerKey)
                if speakerName == "" and speakerKey ~= "" then
                    speakerName = speakerKey
                end

                -- Build speech: "Speaker: text"
                local speech = ""
                if speakerName ~= "" then
                    speech = speakerName .. ": " .. displayText
                else
                    speech = displayText
                end

                TolkSpeak(speech)
                _Log("[SUBTITLE] " .. speech)
            end
        end)
        if not ok then
            _Log("[SUBTITLE] Error: " .. tostring(err))
        end
    end

    -- Dialog choices (NPC benefit selections — always active regardless of subtitle toggle)
    if line and line.Choices then
        local choiceTexts = {}
        local eligibleChoices = {}
        for k, choice in ipairs(line.Choices) do
            if IsTextLineEligible(CurrentRun, choice, line, line) then
                local choiceKey = choice.ChoiceText
                local displayName = ""
                if choiceKey then
                    displayName = ChoiceDisplayNames[choiceKey] or SafeGetDisplayName(choiceKey)
                    if displayName == "" then
                        displayName = choiceKey
                    end
                end
                local descKey = choice.ChoiceDescription
                local desc = ""
                if descKey then
                    desc = SafeGetDisplayName(descKey)
                end
                local choiceSpeech = displayName
                if desc ~= "" then
                    choiceSpeech = choiceSpeech .. ", " .. desc
                end
                local n = #choiceTexts + 1
                choiceTexts[n] = choiceSpeech
                eligibleChoices[n] = choiceSpeech
            end
        end

        -- Spawn thread to add OnMouseOver to choice buttons after baseFunc creates them.
        -- baseFunc creates buttons then yields at waitUntil, so our thread runs concurrently.
        -- IMPORTANT: GetIdsByType does NOT return buttons in visual order.
        -- Must sort by Y position (same approach as TraitTrayScripts.lua:544-554).
        thread(function()
            wait(0.3)
            local ids = GetIdsByType({Name = "ButtonDialogueChoice"})
            if ids and #ids > 0 then
                -- Sort by Y position so ids[1] = topmost button = first choice
                table.sort(ids, function(a, b)
                    local ok1, locA = pcall(GetLocation, { Id = a })
                    local ok2, locB = pcall(GetLocation, { Id = b })
                    local yA = (ok1 and locA and locA.Y) or 0
                    local yB = (ok2 and locB and locB.Y) or 0
                    return yA < yB
                end)
                for i, id in ipairs(ids) do
                    local choiceText = eligibleChoices[i] or ("Choice " .. tostring(i))
                    local buttonTable = { Id = id, choiceSpeech = choiceText }
                    buttonTable.OnMouseOverFunctionName = "OnDialogChoiceMouseOver"
                    AttachLua({ Id = id, Table = buttonTable })
                end
            end
        end)

        -- Speak choices
        if #choiceTexts > 0 then
            local fullSpeech = "Choose: "
            for i, ct in ipairs(choiceTexts) do
                if i > 1 then
                    fullSpeech = fullSpeech .. ". "
                end
                fullSpeech = fullSpeech .. ct
            end
            TolkSpeak(fullSpeech)
        end
    end

    -- baseFunc blocks here until the player advances dialog or selects a choice
    return baseFunc(screen, source, line, parentLine)
end)

--------------------------------------------------------------
-- 2) Room/Location Names
-- Only announces biome transitions + special events (Trial of the Gods,
-- Thanatos, Biome Cleared, Death, House). Does NOT announce every chamber.
--------------------------------------------------------------
-- Texts that should be announced (biome transitions + special events)
local AnnouncedLocationTexts = {
    ["Location_Tartarus"] = true,
    ["Location_Asphodel"] = true,
    ["Location_Elysium"] = true,
    ["Location_Styx"] = true,
    ["Location_Home"] = true,
    ["DeathMessage"] = true,
    ["OutroDeathMessageAlt"] = true,
    ["DevotionMessage"] = true,
    ["BiomeClearedMessage"] = true,
    ["ThanatosMessage"] = true,
    ["Location_Surface"] = true,
}

ModUtil.WrapBaseFunction("DisplayLocationText", function(baseFunc, eventSource, args)
    _Log("[ROOM] DisplayLocationText: " .. tostring(args and args.Text or "nil"))
    if not AccessibilityEnabled or not AccessibilityEnabled() then
        return baseFunc(eventSource, args)
    end

    if args and args.Text and AnnouncedLocationTexts[args.Text] then
        local locationName = LocationDisplayNames[args.Text] or SafeGetDisplayName(args.Text)
        if locationName == "" then
            locationName = args.Text
        end

        -- Add chamber number only for biome transitions (not house/death)
        local chamberInfo = ""
        local isHouseOrDeath = (args.Text == "Location_Home" or args.Text == "DeathMessage" or args.Text == "OutroDeathMessageAlt")
        if not isHouseOrDeath and CurrentRun and CurrentRun.RunDepthCache then
            chamberInfo = ", Chamber " .. tostring(CurrentRun.RunDepthCache)
        end

        local queueSpeak = TolkSpeakQueue or TolkSpeak
        queueSpeak(locationName .. chamberInfo)
    end

    return baseFunc(eventSource, args)
end)

--------------------------------------------------------------
-- 3) Health Lost (simple current health on every hit)
--------------------------------------------------------------
ModUtil.WrapBaseFunction("DamageHero", function(baseFunc, victim, triggerArgs)
    _Log("[COMBAT] DamageHero fired")
    -- Call base first so damage is applied
    local result = baseFunc(victim, triggerArgs)

    if not AccessibilityEnabled or not AccessibilityEnabled() then
        return result
    end

    if not triggerArgs or not triggerArgs.DamageAmount or triggerArgs.DamageAmount <= 0 then
        return result
    end
    if triggerArgs.Silent then
        return result
    end

    if not CurrentRun or not CurrentRun.Hero then
        return result
    end

    local currentHealth = math.floor(CurrentRun.Hero.Health or 0)
    TolkSilence()
    TolkSpeak(string.format(UIStrings.HealthFmt, tostring(currentHealth)))

    return result
end)

--------------------------------------------------------------
-- 3b) Health Sacrificed (Chaos Gate entry, etc.)
-- SacrificeHealth applies damage with Silent=true, which skips
-- the DamageHero wrapper above. We wrap SacrificeHealth directly
-- to announce the health cost.
--------------------------------------------------------------
ModUtil.WrapBaseFunction("SacrificeHealth", function(baseFunc, args)
    local result = baseFunc(args)

    if not AccessibilityEnabled or not AccessibilityEnabled() then
        return result
    end

    if result and result > 0 then
        local currentHealth = 0
        if CurrentRun and CurrentRun.Hero then
            currentHealth = math.floor(CurrentRun.Hero.Health or 0)
        end
        TolkSilence()
        TolkSpeak(string.format(UIStrings.LostHealthFmt, tostring(math.floor(result)), tostring(currentHealth)))
    end

    return result
end)

--------------------------------------------------------------
-- 4) Health Gained
--------------------------------------------------------------
ModUtil.WrapBaseFunction("OnPlayerHealed", function(baseFunc, args)
    if not AccessibilityEnabled or not AccessibilityEnabled() then
        return baseFunc(args)
    end

    local result = baseFunc(args)

    if args and args.ActualHealAmount and args.ActualHealAmount > 0 then
        local amount = math.floor(args.ActualHealAmount)
        if CurrentRun and CurrentRun.Hero then
            local currentHealth = math.floor(CurrentRun.Hero.Health or 0)
            local maxHealth = math.floor(CurrentRun.Hero.MaxHealth or 1)
            -- Only announce significant heals (>= 10 HP or >= 10% max)
            if amount >= 10 or amount >= maxHealth * 0.10 then
                TolkSilence()
                TolkSpeak(string.format(UIStrings.HealedFmt, tostring(amount), tostring(currentHealth)))
            end
        end
    end

    return result
end)

--------------------------------------------------------------
-- 5) Death Defiance Proc
--------------------------------------------------------------
ModUtil.WrapBaseFunction("CheckLastStand", function(baseFunc, victim, triggerArgs)
    _Log("[COMBAT] CheckLastStand (Death Defiance check)")
    if not AccessibilityEnabled or not AccessibilityEnabled() then
        return baseFunc(victim, triggerArgs)
    end

    -- Check if we have last stands BEFORE calling base (which consumes one)
    local hadLastStand = HasLastStand(victim)

    -- Peek at which last stand will be consumed (table.remove pops from end)
    local nextStandName = nil
    if hadLastStand and victim and victim.LastStands then
        local lastIndex = #victim.LastStands
        if lastIndex > 0 and victim.LastStands[lastIndex] then
            nextStandName = victim.LastStands[lastIndex].Name
        end
    end

    local result = baseFunc(victim, triggerArgs)

    -- If result is true, a last stand was used
    if result and hadLastStand then
        local remaining = GetNumLastStands(victim) or 0
        local speech
        if nextStandName == "ReincarnationTrait" then
            speech = UIStrings.LuckyToothFmt .. " " .. tostring(remaining) .. " " .. UIStrings.Remaining
        else
            speech = string.format(UIStrings.DeathDefianceFmt, tostring(remaining))
        end
        local queueSpeak = TolkSpeakQueue or TolkSpeak
        queueSpeak(speech)
    end

    return result
end)

--------------------------------------------------------------
-- 6) Boon/Trait Acquisition
--------------------------------------------------------------
-- Flag set by OnGiftPointsAdded wrapper to distinguish Premium Vintage
-- max health gains from actual Centaur Heart pickups
local _premiumVintageHealthGain = false

-- Note: AccessibleBoons already speaks during boon SELECTION.
-- This wrapper speaks when a boon is actually ADDED to the hero
-- (e.g., from NPC gifts, chaos blessings activating, etc.)
-- We skip if a boon selection screen is open (AccessibleBoons handles that).
ModUtil.WrapBaseFunction("AddTraitToHero", function(baseFunc, args)
    local result = baseFunc(args)
    _Log("[ITEM] AddTraitToHero: " .. tostring(args and args.TraitName or "nil"))

    if not AccessibilityEnabled or not AccessibilityEnabled() then
        return result
    end

    -- Don't speak if boon selection screen is open (AccessibleBoons handles it)
    -- Exception: _wellAwardingRandomItem flag means Fateful Twist is granting a random item
    if IsScreenOpen and (IsScreenOpen("BoonMenu") or (IsScreenOpen("Store") and not _wellAwardingRandomItem)) then
        return result
    end

    -- Don't speak in house/courtyard rooms (traits get re-equipped on entry)
    local mapName = ""
    local ok, mn = pcall(GetMapName, {})
    if ok and mn then mapName = mn end
    if mapName:find("DeathArea") or mapName == "RoomPreRun" then
        return result
    end

    -- Get trait name from args.TraitName or args.TraitData.Name
    -- (Centaur Hearts use AddTraitToHero({ TraitData = ... }) without TraitName)
    local traitName = nil
    if args then
        traitName = args.TraitName
        if not traitName and args.TraitData and args.TraitData.Name then
            traitName = args.TraitData.Name
        end
    end

    if traitName then
        -- Skip God Mode trait (added every run start for God Mode players)
        if traitName == "GodModeTrait" then
            return result
        end

        -- Special handling for Centaur Heart (max health increase)
        -- RoomRewardMaxHealthTrait is also used by Darkness run-progress drops (+5 HP)
        -- and Premium Vintage (Dionysus boon) nectar health restoration (+20-35 HP)
        -- Only announce as "Centaur Heart" for real hearts (not from Premium Vintage or small drops)
        if traitName == "RoomRewardMaxHealthTrait" or traitName == "RoomRewardEmptyMaxHealthTrait" then
            local changeVal = 0
            if args.TraitData and args.TraitData.PropertyChanges and args.TraitData.PropertyChanges[1] then
                changeVal = args.TraitData.PropertyChanges[1].ChangeValue or 0
            end
            local queueSpeak = TolkSpeakQueue or TolkSpeak
            if _premiumVintageHealthGain then
                -- Premium Vintage (Dionysus boon) nectar health restoration
                if changeVal > 0 then
                    queueSpeak("+" .. tostring(math.floor(changeVal)) .. " " .. UIStrings.MaxHealth .. " (Premium Vintage)")
                end
            elseif changeVal >= 20 then
                queueSpeak(string.format(UIStrings.AcquiredFmt, "Centaur Heart") .. ", +" .. tostring(math.floor(changeVal)) .. " " .. UIStrings.MaxHealth)
            elseif changeVal > 0 then
                queueSpeak("+" .. tostring(math.floor(changeVal)) .. " " .. UIStrings.MaxHealth)
            end
            return result
        end

        -- Try to get a display name
        local displayName = SafeGetDisplayName(traitName)
        if displayName == "" then
            -- Try the trait data
            local traitData = TraitData and TraitData[traitName]
            if traitData and traitData.InRackTitle then
                displayName = SafeGetDisplayName(traitData.InRackTitle)
            end
            if displayName == "" and traitData and traitData.Name then
                displayName = traitData.Name
            end
            if displayName == "" then
                displayName = traitName
            end
        end

        local rarity = ""
        if args.Rarity then
            rarity = " (" .. tostring(args.Rarity) .. ")"
        end

        local queueSpeak = TolkSpeakQueue or TolkSpeak
        queueSpeak(string.format(UIStrings.AcquiredFmt, displayName) .. rarity)
    end

    return result
end)

--------------------------------------------------------------
-- 7) Keepsake Equip
--------------------------------------------------------------
ModUtil.WrapBaseFunction("EquipKeepsake", function(baseFunc, heroUnit, traitName, args)
    local result = baseFunc(heroUnit, traitName, args)
    _Log("[ITEM] EquipKeepsake: " .. tostring(traitName))

    if not AccessibilityEnabled or not AccessibilityEnabled() then
        return result
    end

    -- Don't speak in house/courtyard (keepsakes re-equip on room entry)
    local mapName = ""
    local ok2, mn = pcall(GetMapName, {})
    if ok2 and mn then mapName = mn end
    if mapName:find("DeathArea") or mapName == "RoomPreRun" then
        return result
    end

    traitName = traitName or GameState.LastAwardTrait
    if traitName then
        local displayName = KeepsakeDisplayNames[traitName] or SafeGetDisplayName(traitName) or traitName
        local level = ""
        local ok, lvl = pcall(GetKeepsakeLevel, traitName)
        if ok and lvl then
            level = ", " .. string.format(UIStrings.LevelFmt, tostring(lvl))
        end
        local queueSpeak = TolkSpeakQueue or TolkSpeak
        queueSpeak(UIStrings.EquippedKeepsake .. ": " .. displayName .. level)
    end

    return result
end)

--------------------------------------------------------------
-- 8) Weapon Equip (picking up at courtyard)
-- Combined with tutorial objectives into one speech string:
-- "Equipped weapon: [name], [how to use objectives]"
--------------------------------------------------------------
-- Store last equipped weapon speech so ShowObjectiveSet can append
_lastWeaponEquipSpeech = ""

ModUtil.WrapBaseFunction("EquipPlayerWeapon", function(baseFunc, weaponData, args)
    local result = baseFunc(weaponData, args)
    _Log("[ITEM] EquipPlayerWeapon: " .. tostring(weaponData and weaponData.Name or "nil"))

    if not AccessibilityEnabled or not AccessibilityEnabled() then
        return result
    end

    -- Don't speak in house (weapons re-equip on room entry)
    local mapName = ""
    local ok, mn = pcall(GetMapName, {})
    if ok and mn then mapName = mn end
    if mapName:find("DeathArea") then
        return result
    end

    if weaponData and weaponData.Name then
        local displayName = WeaponDisplayNames[weaponData.Name] or weaponData.Name
        _lastWeaponEquipSpeech = UIStrings.EquippedWeapon .. ": " .. displayName
    end

    return result
end)

--------------------------------------------------------------
-- 9) Weapon Tutorial Objectives
--------------------------------------------------------------
-- When you pick up a weapon at the courtyard, ShowObjectiveSet fires with
-- the weapon's tutorial set (e.g. SwordTutorial). We combine objectives
-- with the weapon equip speech into a single announcement.
ModUtil.WrapBaseFunction("ShowObjectiveSet", function(baseFunc, objectiveSetName)
    local result = baseFunc(objectiveSetName)

    if not AccessibilityEnabled or not AccessibilityEnabled() then
        return result
    end

    local objectiveSetData = ObjectiveSetData and ObjectiveSetData[objectiveSetName]
    if not objectiveSetData or not objectiveSetData.Objectives then
        return result
    end

    -- Read the current objective index
    local objIndex = objectiveSetData.ObjectiveIndex or 1
    local objectives = objectiveSetData.Objectives[objIndex]
    if not objectives then
        return result
    end

    -- Build speech from all objectives in this set
    local parts = {}
    for _, objName in ipairs(objectives) do
        local desc = ObjectiveDescriptions[objName]
        if not desc then
            -- Try to resolve from ObjectiveData
            local objData = ObjectiveData and ObjectiveData[objName]
            if objData and objData.Description then
                desc = SafeGetDisplayName(objData.Description)
                if desc ~= "" then
                    -- Replace input symbols with readable text
                    desc = desc:gsub("{A2}", "Attack")
                    desc = desc:gsub("{A3}", "Special")
                    desc = desc:gsub("{RL}", "Reload")
                    desc = StripFormatting(desc)
                end
            end
        end
        if desc and desc ~= "" then
            local n = #parts + 1
            parts[n] = desc
        end
    end

    if #parts > 0 then
        local objSpeech = ""
        for i, p in ipairs(parts) do
            if i > 1 then
                objSpeech = objSpeech .. ". "
            end
            objSpeech = objSpeech .. p
        end

        -- Combine with weapon equip speech if available
        local queueSpeak = TolkSpeakQueue or TolkSpeak
        if _lastWeaponEquipSpeech ~= "" then
            queueSpeak(_lastWeaponEquipSpeech .. ", " .. objSpeech)
            _lastWeaponEquipSpeech = ""
        else
            queueSpeak(objSpeech)
        end
    elseif _lastWeaponEquipSpeech ~= "" then
        -- No objectives but weapon was equipped — speak weapon alone
        local queueSpeak = TolkSpeakQueue or TolkSpeak
        queueSpeak(_lastWeaponEquipSpeech)
        _lastWeaponEquipSpeech = ""
    end

    return result
end)

--------------------------------------------------------------
-- 10) Keepsake Gift Received (NPC gives keepsake after Nectar)
--------------------------------------------------------------
ModUtil.WrapBaseFunction("PlayerReceivedGiftPresentation", function(baseFunc, npc, giftName)
    if not AccessibilityEnabled or not AccessibilityEnabled() then
        return baseFunc(npc, giftName)
    end

    -- Build speech: "New Keepsake from [NPC]: [Keepsake Name]"
    local npcName = ""
    if npc and npc.Name then
        npcName = NPCDisplayNames[npc.Name] or SafeGetDisplayName(npc.Name)
        if npcName == "" then
            npcName = npc.Name
        end
    end

    local keepsakeName = ""
    if giftName then
        keepsakeName = KeepsakeGiftNames[giftName] or KeepsakeDisplayNames[giftName] or SafeGetDisplayName(giftName)
        if keepsakeName == "" then
            keepsakeName = giftName
        end
    end

    local speech = UIStrings.NewKeepsakeFrom
    if npcName ~= "" then
        speech = speech .. " " .. npcName
    end
    if keepsakeName ~= "" then
        speech = speech .. ": " .. keepsakeName
    end

    local queueSpeak = TolkSpeakQueue or TolkSpeak
    queueSpeak(speech)

    return baseFunc(npc, giftName)
end)

--------------------------------------------------------------
-- 11) Weapon/Item Unlock Presentation (general unlock text)
--------------------------------------------------------------
-- DisplayUnlockText is used for keepsake gifts (handled above),
-- weapon unlocks, and other unlockables. We wrap it as a catch-all
-- for any unlock text not caught by specific wrappers above.
ModUtil.WrapBaseFunction("DisplayUnlockText", function(baseFunc, args)
    if not AccessibilityEnabled or not AccessibilityEnabled() then
        return baseFunc(args)
    end

    -- Don't speak if PlayerReceivedGiftPresentation already handled it
    if args and args.TitleText == "NewTraitUnlocked_Title" then
        -- Already spoken by PlayerReceivedGiftPresentation wrapper
        return baseFunc(args)
    end

    -- For other unlock texts (weapon unlocked, etc.)
    if args and args.TitleText then
        local title = SafeGetDisplayName(args.TitleText)
        if title == "" then
            title = args.TitleText
        end
        local subtitle = ""
        if args.SubtitleText then
            subtitle = SafeGetDisplayName(args.SubtitleText)
        end
        local speech = title
        if subtitle ~= "" then
            speech = speech .. ": " .. subtitle
        end
        local queueSpeak = TolkSpeakQueue or TolkSpeak
        queueSpeak(speech)
    end

    return baseFunc(args)
end)

--------------------------------------------------------------
-- 12) Fish Catch Notifications
--------------------------------------------------------------
-- RecordFish is called in FishingEndPresentation after a successful catch.
-- fishName is the internal key like "Fish_Tartarus_Common_01".
ModUtil.WrapBaseFunction("RecordFish", function(baseFunc, fishName)
    _Log("[ITEM] RecordFish: " .. tostring(fishName))
    local result = baseFunc(fishName)

    if not AccessibilityEnabled or not AccessibilityEnabled() then
        return result
    end

    if fishName then
        local displayName = FishDisplayNames[fishName] or fishName
        local rarity = GetFishRarity(fishName)
        local speech = string.format(UIStrings.CaughtFmt, displayName)
        if rarity ~= "" then
            speech = speech .. " (" .. rarity .. ")"
        end
        local queueSpeak = TolkSpeakQueue or TolkSpeak
        queueSpeak(speech)
    end

    return result
end)

--------------------------------------------------------------
-- 13) Survival Challenge Duration
--------------------------------------------------------------
-- SurvivalEncounterStartPresentation fires when a survival challenge begins.
-- The encounter's TimeLimit tells how many seconds to survive.
ModUtil.WrapBaseFunction("SurvivalEncounterStartPresentation", function(baseFunc, eventSource, tollTimes, colorGrade, colorFx, playerGlobalVoiceLines, opponentGlobalVoiceLines)
    _Log("[COMBAT] SurvivalEncounterStartPresentation")
    if AccessibilityEnabled and AccessibilityEnabled() then
        local timeLimit = nil
        if eventSource and eventSource.TimeLimit then
            timeLimit = eventSource.TimeLimit
        end
        if timeLimit then
            local queueSpeak = TolkSpeakQueue or TolkSpeak
            queueSpeak(string.format(UIStrings.SurviveForFmt, tostring(math.floor(timeLimit))))
        end
    end

    return baseFunc(eventSource, tollTimes, colorGrade, colorFx, playerGlobalVoiceLines, opponentGlobalVoiceLines)
end)

--------------------------------------------------------------
-- 14) Infernal Trove Challenge
--------------------------------------------------------------
-- ChallengeEncounterStartPresentation fires when an Infernal Trove is activated.
-- The challenge has a time limit and enemies to kill.
ModUtil.WrapBaseFunction("ChallengeEncounterStartPresentation", function(baseFunc, eventSource)
    if AccessibilityEnabled and AccessibilityEnabled() then
        local speech = UIStrings.InfernalTroveChallenge
        if eventSource and eventSource.TimeLimit then
            speech = speech .. ", " .. tostring(math.floor(eventSource.TimeLimit)) .. " seconds"
        end
        local queueSpeak = TolkSpeakQueue or TolkSpeak
        queueSpeak(speech)
    end

    return baseFunc(eventSource)
end)

--------------------------------------------------------------
-- 15) Erebus (Perfect Clear) Challenge
--------------------------------------------------------------
-- PerfectClearEncounterStartPresentation fires in Erebus rooms.
-- You must clear the room without taking any damage.
ModUtil.WrapBaseFunction("PerfectClearEncounterStartPresentation", function(baseFunc, eventSource)
    if AccessibilityEnabled and AccessibilityEnabled() then
        local queueSpeak = TolkSpeakQueue or TolkSpeak
        queueSpeak(UIStrings.ErebusChallenge)
    end

    return baseFunc(eventSource)
end)

--------------------------------------------------------------
-- 17) Thanatos Encounter (kill competition)
--------------------------------------------------------------
-- ThanatosEncounterStartPresentation fires when Thanatos appears.
-- You compete to get more kills than him. Winner gets a Centaur Heart.
ModUtil.WrapBaseFunction("ThanatosEncounterStartPresentation", function(baseFunc, eventSource)
    if AccessibilityEnabled and AccessibilityEnabled() then
        local queueSpeak = TolkSpeakQueue or TolkSpeak
        queueSpeak(UIStrings.ThanatosChallenge)
    end

    return baseFunc(eventSource)
end)

--------------------------------------------------------------
-- 18) Wrapping Encounter (Asphodel moving platforms)
--------------------------------------------------------------
-- WrappingEncounterStartPresentation fires in Asphodel rooms
-- with scrolling/moving boat platforms.
ModUtil.WrapBaseFunction("WrappingEncounterStartPresentation", function(baseFunc, eventSource)
    if AccessibilityEnabled and AccessibilityEnabled() then
        local queueSpeak = TolkSpeakQueue or TolkSpeak
        queueSpeak(UIStrings.MovingPlatforms)
    end

    return baseFunc(eventSource)
end)

--------------------------------------------------------------
-- 19) Pact Tight Deadline Timer
--------------------------------------------------------------
-- BiomeSpeedShrineUpgrade adds a per-biome time limit.
-- Level 1 = 9 minutes, Level 2 = 7 minutes, Level 3 = 5 minutes.
-- When time expires, player takes 5 damage every second (Silent=true bypasses DamageHero).
-- BiomeDamagePresentation fires each damage tick after timer expires.

local _biomeTimerExpiredAnnounced = false
local _biomeTimerActive = false
local _biomeDamageTickCount = 0

-- Format seconds into readable time string
local function FormatTimeRemaining(seconds)
    if seconds >= 120 then
        local mins = math.floor(seconds / 60)
        return tostring(mins) .. " minutes"
    elseif seconds >= 60 then
        local mins = math.floor(seconds / 60)
        local secs = math.floor(seconds % 60)
        if secs > 0 then
            return "1 minute " .. tostring(secs) .. " seconds"
        else
            return "1 minute"
        end
    else
        return tostring(math.floor(seconds)) .. " seconds"
    end
end

-- Timer monitoring thread: announces time milestones
local function BiomeTimerMonitorThread()
    if not AccessibilityEnabled or not AccessibilityEnabled() then return end
    if not CurrentRun or not CurrentRun.BiomeTime then return end

    local queueSpeak = TolkSpeakQueue or TolkSpeak

    -- Fixed milestone thresholds in seconds (descending order)
    local allMilestones = { 300, 180, 120, 60, 30, 10 }

    -- Only keep milestones below current time (skip already-passed ones)
    local startTime = CurrentRun.BiomeTime
    local milestones = {}
    for _, threshold in ipairs(allMilestones) do
        if threshold < startTime then
            milestones[#milestones + 1] = threshold
        end
    end

    if #milestones == 0 then return end

    local nextMilestoneIdx = 1

    while _biomeTimerActive do
        wait(1.0)
        if not _biomeTimerActive then break end
        if not CurrentRun or not CurrentRun.BiomeTime then break end

        local timeLeft = CurrentRun.BiomeTime
        if timeLeft <= 0 then break end
        if nextMilestoneIdx > #milestones then break end

        local threshold = milestones[nextMilestoneIdx]
        if timeLeft <= threshold + 1 then
            nextMilestoneIdx = nextMilestoneIdx + 1
            queueSpeak(FormatTimeRemaining(threshold) .. " " .. UIStrings.Remaining)
        end
    end
end

ModUtil.WrapBaseFunction("DisplayLocationText", function(baseFunc, eventSource, args)
    if args and args.Text then
        local isBiomeTransition = (args.Text == "Location_Tartarus" or args.Text == "Location_Asphodel"
            or args.Text == "Location_Elysium" or args.Text == "Location_Styx")
        if isBiomeTransition then
            _biomeTimerExpiredAnnounced = false
            _biomeTimerActive = false
            _biomeDamageTickCount = 0

            if AccessibilityEnabled and AccessibilityEnabled() and GetNumMetaUpgrades then
                local pactLevel = 0
                local ok, lvl = pcall(GetNumMetaUpgrades, "BiomeSpeedShrineUpgrade")
                if ok and lvl then pactLevel = lvl end
                if pactLevel > 0 then
                    -- Read the total time now (before countdown eats into it),
                    -- but delay speech so it doesn't overlap the biome announcement
                    local totalTime = nil
                    local totalTimeLimits = { 0, 540, 420, 300 } -- level 0/1/2/3 in seconds
                    if pactLevel >= 1 and pactLevel <= 3 then
                        totalTime = totalTimeLimits[pactLevel + 1]
                    end
                    thread(function()
                        wait(1.5)
                        local queueSpeak = TolkSpeakQueue or TolkSpeak
                        if totalTime and totalTime > 0 then
                            queueSpeak(UIStrings.TightDeadline .. ": " .. FormatTimeRemaining(totalTime))
                        elseif CurrentRun and CurrentRun.BiomeTime and CurrentRun.BiomeTime > 0 then
                            queueSpeak(UIStrings.TightDeadline .. ": " .. FormatTimeRemaining(CurrentRun.BiomeTime))
                        end
                    end)
                    -- Start timer monitoring thread
                    _biomeTimerActive = true
                    thread(BiomeTimerMonitorThread)
                end
            end
        end
    end

    return baseFunc(eventSource, args)
end)

-- Announce when timer expires + health on each damage tick
ModUtil.WrapBaseFunction("BiomeDamagePresentation", function(baseFunc, damageAmount)
    if AccessibilityEnabled and AccessibilityEnabled() then
        local queueSpeak = TolkSpeakQueue or TolkSpeak
        _biomeTimerActive = false

        if not _biomeTimerExpiredAnnounced then
            _biomeTimerExpiredAnnounced = true
            _biomeDamageTickCount = 0
            queueSpeak(UIStrings.TimeExpired)
        end

        -- Announce health every 3 ticks (every 3 seconds) to avoid flooding
        _biomeDamageTickCount = _biomeDamageTickCount + 1
        if _biomeDamageTickCount % 3 == 0 then
            local currentHealth = 0
            local maxHealth = 0
            if CurrentRun and CurrentRun.Hero then
                currentHealth = CurrentRun.Hero.Health or 0
                maxHealth = CurrentRun.Hero.MaxHealth or 0
            end
            currentHealth = math.floor(currentHealth)
            maxHealth = math.floor(maxHealth)
            if currentHealth > 0 then
                queueSpeak(tostring(currentHealth) .. " " .. UIStrings.Of .. " " .. tostring(maxHealth) .. " " .. UIStrings.Health)
            end
        end
    end

    return baseFunc(damageAmount)
end)

--------------------------------------------------------------
-- Room transition (pass-through, resets per-room state)
--------------------------------------------------------------
ModUtil.WrapBaseFunction("StartRoomPresentation", function(baseFunc, currentRun, currentRoom, metaPointsAwarded)
    local roomName = currentRoom and currentRoom.Name or "unknown"
    local depth = currentRun and currentRun.RunDepthCache or 0
    _Log("[ROOM] StartRoomPresentation: " .. roomName .. " (depth=" .. tostring(depth) .. ")")
    return baseFunc(currentRun, currentRoom, metaPointsAwarded)
end)

--------------------------------------------------------------
-- 16) Resource Pickup Announcements
-- Wraps AddResource (Darkness, Gemstones, Chthonic Keys, Nectar,
-- Ambrosia, Titan Blood, Diamonds) and AddMoney (Obols) to
-- announce pickups via TolkSpeak.
-- Uses a batching system: accumulates all resource gains within
-- a 0.3s window, then speaks the totals as one string
-- (e.g. "+15 Darkness, +10 Gemstones" instead of separate calls).
--------------------------------------------------------------
ResourceDisplayNames = {
    ["MetaPoints"] = "Darkness",
    ["Gems"] = "Gemstones",
    ["LockKeys"] = "Chthonic Keys",
    ["GiftPoints"] = "Nectar",
    ["SuperGiftPoints"] = "Ambrosia",
    ["SuperLockKeys"] = "Titan Blood",
    ["SuperGems"] = "Diamonds",
}

-- Batching system: accumulate resource gains and speak after a short delay
local _resourceBatch = {}       -- { resourceKey = amount, ... }
local _resourceBatchActive = false  -- whether a flush thread is running
local _resourceBatchDelay = 0.3     -- seconds to wait before flushing

-- Ordered list for consistent speech output
local _resourceOrder = { "MetaPoints", "Gems", "LockKeys", "GiftPoints", "SuperGiftPoints", "SuperLockKeys", "SuperGems", "Obols" }

local function FlushResourceBatch()
    wait(_resourceBatchDelay)
    -- Build combined speech string
    local parts = {}
    for _, key in ipairs(_resourceOrder) do
        local amount = _resourceBatch[key]
        if amount and amount > 0 then
            local displayName = ResourceDisplayNames[key] or key
            parts[#parts + 1] = "+" .. tostring(amount) .. " " .. displayName
        end
    end
    _resourceBatch = {}
    _resourceBatchActive = false
    if #parts > 0 and AccessibilityEnabled and AccessibilityEnabled() then
        local speech = ""
        for i, part in ipairs(parts) do
            if i > 1 then speech = speech .. ", " end
            speech = speech .. part
        end
        local queueSpeak = TolkSpeakQueue or TolkSpeak
        queueSpeak(speech)
    end
end

local function BatchResource(key, amount)
    _resourceBatch[key] = (_resourceBatch[key] or 0) + math.floor(amount + 0.5)
    if not _resourceBatchActive then
        _resourceBatchActive = true
        thread(FlushResourceBatch)
    end
end

ModUtil.WrapBaseFunction("AddResource", function(baseFunc, name, amount, source, args)
    local result = baseFunc(name, amount, source, args)
    _Log("[ITEM] AddResource: " .. tostring(name) .. " x" .. tostring(amount))

    if not AccessibilityEnabled or not AccessibilityEnabled() then
        return result
    end

    if not name or not amount or amount == 0 then
        return result
    end

    -- Skip silent resource additions (e.g. internal bookkeeping)
    if args and args.Silent then
        return result
    end

    BatchResource(name, amount)

    return result
end)

ModUtil.WrapBaseFunction("AddMoney", function(baseFunc, amount, source)
    -- Record money before base function (BlockMoney trait can zero the amount)
    local moneyBefore = 0
    if CurrentRun then
        moneyBefore = CurrentRun.Money or 0
    end

    local result = baseFunc(amount, source)

    if not AccessibilityEnabled or not AccessibilityEnabled() then
        return result
    end

    -- Check actual delta (handles BlockMoney trait zeroing the amount)
    local moneyAfter = 0
    if CurrentRun then
        moneyAfter = CurrentRun.Money or 0
    end
    local actualGain = math.floor(moneyAfter - moneyBefore + 0.5)
    if actualGain > 0 then
        BatchResource("Obols", actualGain)
    end

    return result
end)

-- God Mode toggle announcements
ModUtil.WrapBaseFunction("EasyModeEnabledPresentation", function(baseFunc)
    _Log("[WRAP] EasyModeEnabledPresentation (God Mode toggled ON)")
    local result = baseFunc()
    if not AccessibilityEnabled or not AccessibilityEnabled() then
        return result
    end
    local resistance = 20
    if GameState and GameState.EasyModeLevel and CalcEasyModeMultiplier then
        local ok, mult = pcall(CalcEasyModeMultiplier, GameState.EasyModeLevel)
        if ok and mult then
            resistance = math.floor((1.0 - mult) * 100 + 0.5)
        end
    end
    local queueSpeak = TolkSpeakQueue or TolkSpeak
    queueSpeak(UIStrings.GodModeEnabled .. ", " .. tostring(resistance) .. " " .. UIStrings.PercentDamageResistance)
    return result
end)

ModUtil.WrapBaseFunction("EasyModeDisabledPresentation", function(baseFunc)
    local result = baseFunc()
    if not AccessibilityEnabled or not AccessibilityEnabled() then
        return result
    end
    local queueSpeak = TolkSpeakQueue or TolkSpeak
    queueSpeak(UIStrings.GodModeDisabled)
    return result
end)

--------------------------------------------------------------
-- Premium Vintage (Dionysus boon) nectar health restoration
--------------------------------------------------------------
-- When nectar is picked up with Premium Vintage (GiftHealthTrait) equipped,
-- OnGiftPointsAdded calls AddMaxHealth which adds RoomRewardMaxHealthTrait.
-- Without this flag, AddTraitToHero would announce it as "Centaur Heart"
-- since the health gain (20-35) exceeds the 20 threshold.
ModUtil.WrapBaseFunction("OnGiftPointsAdded", function(baseFunc, name, amount, source, args)
    _Log("[WRAP] OnGiftPointsAdded: " .. tostring(name) .. " amount=" .. tostring(amount))
    _premiumVintageHealthGain = true
    local result = baseFunc(name, amount, source, args)
    _premiumVintageHealthGain = false
    return result
end)

