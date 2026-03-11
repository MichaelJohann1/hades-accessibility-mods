--[[
Mod: AccessibleContractor
Author: Accessibility Layer
Version: 9

Provides screen reader accessibility for the House Contractor (GhostAdmin) screen.
- Speaks item name and cost when cursor moves over items
- Press Special (Y button on controller / Right Click on keyboard) to hear item description
- Speaks category name when switching categories
- Uses hardcoded display names and descriptions for items
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

-- Hardcoded display names for common contractor items
-- (GetDisplayName doesn't resolve these localization keys)
ContractorItemNames = {
    QuestLog = "Fated List of Minor Prophecies",
    CodexBoonList = "Codex Index",
    HealthFountainHeal1 = "Underworld Fountains, Purified",
    HealthFountainHeal2 = "Underworld Fountains, Holy",
    TartarusReprieve = "Fountain Chamber, Tartarus",
    AsphodelReprieve = "Fountain Chamber, Asphodel",
    ElysiumReprieve = "Fountain Chamber, Elysium",
    AsphodelStory = "Asphodel Riverside Terrace",
    ElysiumStory = "Elysium Honor Grotto",
    ChallengeSwitches1 = "Plunder, Lesser",
    ChallengeSwitches2 = "Plunder, Greater",
    ChallengeSwitches3 = "Plunder, Superior",
    GhostAdminDesk = "Contractor's Desk, Deluxe",
    BreakableValue1 = "Urns of Wealth, Lesser",
    BreakableValue2 = "Urns of Wealth, Greater",
    BreakableValue3 = "Urns of Wealth, Superior",
    PostBossGiftRack = "Keepsake Collection, Regional",
    FishingUnlockItem = "Rod of Fishing",
    OrpheusUnlockItem = "Court Musician's Sentence",
    OfficeDoorUnlockItem = "Administrative Privilege",
    RoomRewardMetaPointDropRunProgress = "Darkness, Pitch-Black",
    GemDropRunProgress = "Gemstones, Brilliant",
    LockKeyDropRunProgress = "Chthonic Keys, Fated",
    GiftDropRunProgress = "Nectar, Vintage",
    UnusedWeaponBonusAddGems = "Darker Thirst",
    BossAddGems = "Vanquisher's Keep",
    ShrinePointGates = "Gateways, Erebus",
    HadesEMFight = "Extremer Measures",
    SisyphusQuestItem = "Knave-King's Sentence",
    OrpheusEurydiceQuestItem = "Singer's Gamble",
    AchillesPatroclusQuestItem = "Hero's Sacrifice",
    NyxQuestItem = "Eldest Sigil Restoration",
    Cosmetic_MusicPlayer = "Court Music Stand",
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
    Cosmetic_UISkinDefault = "Theme, Princely",
    Cosmetic_UISkinArtemis = "Theme, Woodland",
    Cosmetic_UISkinChthonic = "Theme, Chthonic",
    Cosmetic_UISkinHades = "Theme, Deathly",
    Cosmetic_UISkinHeat = "Theme, Infernal",
    Cosmetic_UISkinStone = "Theme, Stygian",
    Cosmetic_UISkinLove = "Theme, Lovely",
    Cosmetic_UISkinChaos = "Theme, Infinite",
    Cosmetic_UISkinOrphic = "Theme, Sonorous",
    Cosmetic_UISkinBlood = "Theme, Bloodstone",
    Cosmetic_DrapesBlue = "Drapery, Azure",
    Cosmetic_DrapesGreen = "Drapery, Olive",
    Cosmetic_DrapesGrey = "Drapery, Bone",
    Cosmetic_DrapesRed = "Drapery, Crimson",
    Cosmetic_SouthHallTrimGrey = "Trim, Ash Gray",
    Cosmetic_SouthHallTrimPurple = "Trim, Chthonic Purple",
    Cosmetic_SouthHallTrimRed = "Trim, Blood-Red",
    Cosmetic_SouthHallTrimBrown = "Trim, Burnished Gold",
    Cosmetic_SouthHallFlowers = "Flower Vase, Lilac",
    Cosmetic_SouthHallFlowersA = "Flower Vase, Rose",
    Cosmetic_SouthHallMosaic = "Mosaic, Chthonic",
    Cosmetic_SouthHallMosaicB = "Mosaic, Minoan",
    Cosmetic_SouthHallFountain = "Fountain, East Wing",
    Cosmetic_SkullFloorTiles = "Tiling, Skull",
    Cosmetic_LaurelsBlue = "Laurels, Cobalt",
    Cosmetic_LaurelsSkulls = "Laurels, Deathly",
    Cosmetic_LaurelsRed = "Laurels, Crimson",
    Cosmetic_HouseCandles01 = "Lighting, Dual Stick",
    Cosmetic_HouseCandles02 = "Lighting, Wax Pillar",
    Cosmetic_HousePillars = "Columns, Divine",
    Cosmetic_HousePillarsA = "Columns, Ominous",
    Cosmetic_HousePillarsB = "Columns, Jeweled",
    Cosmetic_WallWeaponSword = "Decorative Arms, Xiphos",
    Cosmetic_WallWeaponAxe = "Decorative Arms, Labrys",
    Cosmetic_WallWeaponBident = "Decorative Arms, Bident",
    Cosmetic_MainHallBones = "Bonework, Ominous",
    Cosmetic_MainHallCenterpieceA = "Insignia, Fated Order",
    Cosmetic_MainHallCouch = "Chaise, Divine",
    Cosmetic_MainHallFireplace = "Fireplace, Infernal",
    Cosmetic_MainHallFireplaceA = "Fireplace, Nocturnal",
    Cosmetic_MainHallFlowers = "Petals, Scattered",
    Cosmetic_MainHallPetalFlyers = "Petals, Ever-Falling",
    Cosmetic_MainHallPetals = "Petals, Shade-Strewn",
    Cosmetic_MainHallSarcophagi = "Tombs, Royal",
    Cosmetic_MainHallThroneA = "Throne, Hell-Hound",
    Cosmetic_MainHallTikiTorches = "Flames, Promethean",
    Cosmetic_MainHallTowels = "Towel Rack, Stygian",
    Cosmetic_CharonPillars = "Treasures, Boatman's",
    Cosmetic_NorthHallMirror = "Mirror, Guardpost",
    Cosmetic_NorthHallCouch = "Seating, Luxurious",
    Cosmetic_NorthHallRug = "Rug, Earthy",
    Cosmetic_NorthHallRugA = "Rug, Elysian",
    Cosmetic_NorthHallRugB = "Rug, Chthonic",
    Cosmetic_NorthHallRugC = "Rug, Sanguine",
    Cosmetic_NorthHallPaintingZagreus = "Painting, Prince",
    Cosmetic_NorthHallPaintingHades = "Painting, God of the Dead",
    Cosmetic_NorthHallPaintingFury = "Painting, Fury Sisters",
    Cosmetic_NorthHallPaintingMysteryWoman = "Painting, Night",
    Cosmetic_NorthHallPaintingMysteryGirl = "Portrait, Princess",
    Cosmetic_NorthHallPaintingTots = "Portrait, Cerberus",
    Cosmetic_NorthHallPaintingTheseus = "Portrait, Exalted Hero",
    Cosmetic_NorthHallPaintingTartarus = "Landscape, Tartarus",
    Cosmetic_NorthHallPaintingAsphodel = "Landscape, Asphodel",
    Cosmetic_NorthHallPaintingElysium = "Landscape, Elysium",
    Cosmetic_NorthHallPedestalMechanism = "Contraption, Intricate",
    Cosmetic_NorthHallPedestalBust = "Sculpture, Bloodless",
    Cosmetic_NorthHallPedestalSphere = "Sphere, Constellation",
    Cosmetic_NorthHallPedestalHammer = "Tool, Builder's",
    Cosmetic_NorthHallPedestalArtifact = "Artifact, Extraordinary",
    Cosmetic_NorthHallSundial = "Sundial, Imported",
    Cosmetic_NorthHallPedestalA = "Pedestals, Gilded",
    Cosmetic_NorthHallFountain = "Fountain, West Hall",
    Cosmetic_NorthHallWarriorStatue = "Sculpture, Heroic",
    Cosmetic_NorthHallBust = "Bust, Old Man",
    CosmeticAchillesRug = "Rug, Guardpost",
    Cosmetic_ThanatosCouch = "Recliner, Deathlike",
    Cosmetic_ThanatosChair = "Chair, Deathlike",
    Cosmetic_ThanatosRug = "Rug, Deathlike",
    Cosmetic_ThanatosTable = "Table, Deathlike",
    Cosmetic_ThanatosBrazier = "Flames, Deathlike",
    HousePoster01 = "Wall-Scroll, Achilles",
    HousePoster02 = "Wall-Scroll, Aphrodite",
    HousePoster05 = "Wall-Scroll, Dionysus",
    HouseDagger01 = "Arms, Assorted",
    HouseWaterBowl01 = "Pool, Scrying",
    HouseLyre01 = "Lyre, Splendid",
    HouseBed01a = "Bedding, Chthonic",
    HouseCouch02A = "Recliner, Fancy",
    HouseRug03B = "Rug, Stately",
    HouseWeights01 = "Weights, Massive",
    HouseGamingTable01 = "Table, Entertainment",
    Cosmetic_CerberusBed = "Bedding, Quilted",
    Cosmetic_CerberusBedA = "Bedding, Fancy",
    Cosmetic_CerberusBall = "Plaything, Round",
    Cosmetic_CerberusToy = "Plaything, Plush",
    Cosmetic_ClearFur = "Service, Deep Cleaning",
    Cosmetic_ClearScratches = "Service, Detailing",
    Cosmetic_LoungeRug = "Rug, Earthy",
    Cosmetic_SeatCushions = "Seating, Covered",
    Cosmetic_LoungeChairsA = "Seating, Olive",
    Cosmetic_LoungeAdditionalSeating = "Seating, Red Hide",
    Cosmetic_LoungeTablesA = "Tables, Serpentine",
    Cosmetic_LoungeRugA = "Rug, Elysian",
    Cosmetic_LoungeRugB = "Rug, Chthonic",
    Cosmetic_LoungeRugC = "Rug, Sanguine",
    Cosmetic_LoungeBrokerRug = "Rug, Welcome",
    Cosmetic_LoungePaintingSkelly = "Painting, Skeletal",
    Cosmetic_LoungeFireplace = "Fireplace, Burial",
    Cosmetic_BatCage = "Bat Cage, All-Seeing",
    Cosmetic_Aquarium = "Aquarium, Cubical",
    Cosmetic_LoungeShortcut = "Shortcut, Great Hall",
    Cosmetic_LoungeDiscoBall = "Prism-Sphere, Revolving",
    Cosmetic_LoungeDiscoBallA = "Prism-Sphere, Revolting",
    Cosmetic_LoungeLiquor = "Shelf, Vintage",
    Cosmetic_KitchenIsland = "Kitchenette, Expanded",
    Cosmetic_KitchenStoveCauldron = "Cauldron, Fiery",
    Cosmetic_KitchenStoveFlame = "Fire Pit, Wood-Burning",
    Cosmetic_LoungeClayOven = "Oven, Kitchenette",
    Cosmetic_SpiceRack = "Spice Rack, Kitchenette",
    Cosmetic_Knives = "Cutlery, Kitchenette",
    Cosmetic_LoungeTreatJar = "Jar, Treat-Filled",
    Cosmetic_HangingFood = "Meats, Cured",
    Cosmetic_LoungeCakeDisplay = "Delicacy, Ambrosial",
}

-- Hardcoded descriptions for contractor items (sourced from Hades Wiki)
ContractorItemDescriptions = {
    QuestLog = "Special Item: Make the Fates' prophecies come to pass, and be rewarded",
    CodexBoonList = "Special Item: Update the Codex with a handy list of Boons for each Olympian",
    HealthFountainHeal1 = "Underworld Renovation: Fountains provide +10% more Healing than usual",
    HealthFountainHeal2 = "Underworld Renovation: Fountains provide +20% more Healing than usual",
    TartarusReprieve = "Added Chamber: Restores some Health amid the gloom",
    AsphodelReprieve = "Added Chamber: Restores some Health amid the searing heat",
    ElysiumReprieve = "Added Chamber: Restores some Health amid the lush environs",
    AsphodelStory = "Added Chamber: Confines a shade who once nearly escaped",
    ElysiumStory = "Added Chamber: Confines a shade fated to perish in a great war",
    ChallengeSwitches1 = "Underworld Renovation: Chambers may contain an Infernal Trove",
    ChallengeSwitches2 = "Underworld Renovation: Each Infernal Trove contains more",
    ChallengeSwitches3 = "Underworld Renovation: Each Infernal Trove contains even more",
    GhostAdminDesk = "Special Item: Give the House Contractor a break (and new jobs..)",
    BreakableValue1 = "Underworld Renovation: Chambers may contain urns with 5 Obols",
    BreakableValue2 = "Underworld Renovation: Chambers may contain urns with 10 Obols",
    BreakableValue3 = "Underworld Renovation: Chambers may contain urns with 15 Obols",
    PostBossGiftRack = "Underworld Renovation: Switch Keepsakes between Underworld regions",
    FishingUnlockItem = "Special Item: Scoop creatures from the Underworld's rivers.",
    OrpheusUnlockItem = "Sealed Document: Free Orpheus from solitary confinement",
    OfficeDoorUnlockItem = "Special Item: (Re)gain entry to the administrative chamber",
    RoomRewardMetaPointDropRunProgress = "Underworld Renovation: Claiming chamber rewards gives you +5",
    GemDropRunProgress = "Underworld Renovation: Claiming chamber rewards gives you +20 Obols",
    LockKeyDropRunProgress = "Underworld Renovation: Claiming chamber rewards gives you +1",
    GiftDropRunProgress = "Underworld Renovation: Claiming chamber rewards gives you +1 Lv",
    UnusedWeaponBonusAddGems = "Underworld Renovation: Your weapons' Dark Thirst also gives +20%",
    BossAddGems = "Underworld Renovation: Awards after vanquishing Underworld Bosses",
    ShrinePointGates = "Underworld Renovation: Chambers may contain an Erebus Gate",
    HadesEMFight = "Pact Stipulation: Unlocks the final rank of Extreme Measures.. if you dare",
    SisyphusQuestItem = "Sealed Document: Free Sisyphus of an eternity of hard labor",
    OrpheusEurydiceQuestItem = "Sealed Document: Permit Orpheus to be with his muse again",
    AchillesPatroclusQuestItem = "Sealed Document: Allow Achilles to return to Elysium",
    NyxQuestItem = "House Repair: Aid Nyx by imbuing the Sigil in the administrative chamber",
    Cosmetic_MusicPlayer = "Special Item: Authorizes playback of music pieces from the vault",
    Cosmetic_UISkinDefault = "Decorative Theme: Evokes the clean utility of the House of Hades",
    Cosmetic_UISkinHeat = "Decorative Theme: Evokes infernal might and unbearable heat",
    Cosmetic_UISkinOrphic = "Decorative Theme: Evokes soaring harmonies and inspiration",
    Cosmetic_UISkinStone = "Decorative Theme: Evokes the grim stoicism of the Underworld",
    Cosmetic_UISkinLove = "Decorative Theme: Evokes certain descriptions of joy and levity",
    Cosmetic_UISkinArtemis = "Decorative Theme: Evokes greenery found only on the surface",
    Cosmetic_UISkinChthonic = "Decorative Theme: Evokes night, darkness, and the Underworld",
    Cosmetic_UISkinHades = "Decorative Theme: Evokes the sheer opulence of Hades' domain",
    Cosmetic_UISkinChaos = "Decorative Theme: Evokes the abyssal profundity of Chaos",
    Cosmetic_UISkinBlood = "Decorative Theme: Evokes rage, anger, and bloodshed",
    Cosmetic_DrapesBlue = "House Decor: Gives the drapery a hue reminiscent of the sea",
    Cosmetic_DrapesGreen = "House Decor: Gives the drapery a hue similar to a small, bitter fruit",
    Cosmetic_DrapesGrey = "House Decor: Gives the drapery a look reminiscent of decay",
    Cosmetic_DrapesRed = "House Decor: Restores the original drapery color",
    Cosmetic_SouthHallTrimGrey = "House Decor: Embellishes the East Wing flooring in gray",
    Cosmetic_SouthHallTrimPurple = "House Decor: Embellishes the East Wing flooring in purple",
    Cosmetic_SouthHallTrimRed = "House Decor: Embellishes the East Wing flooring in red",
    Cosmetic_SouthHallTrimBrown = "House Decor: Embellishes the East Wing flooring in gold",
    Cosmetic_SouthHallFlowers = "House Decor: Adds a splash of color to the East Wing of the House",
    Cosmetic_SouthHallFlowersA = "House Decor: Adds a bit of mystique to the East Wing of the House",
    Cosmetic_SouthHallMosaic = "House Decor: Gives the Prince's chambers a homely atmosphere",
    Cosmetic_SouthHallMosaicB = "House Decor: Gives the Prince's chambers an exotic atmosphere",
    Cosmetic_SouthHallFountain = "House Decor: Enhances atmosphere in an otherwise-dismal corner",
    Cosmetic_SkullFloorTiles = "House Decor: Gives the East Wing a sense of foreboding",
    Cosmetic_LaurelsBlue = "House Decor: Decorate the East Wing walls in blue",
    Cosmetic_LaurelsSkulls = "House Decor: Decorate the East Wing walls in bone",
    Cosmetic_LaurelsRed = "House Decor: Decorate the East Wing walls in red",
    Cosmetic_HouseCandles01 = "House Decor: Illuminates the pillar-tops with slender candlesticks",
    Cosmetic_HouseCandles02 = "House Decor: Illuminates the pillar-tops with long-burning flames",
    Cosmetic_HousePillars = "House Decor: Makes the columns similar to those on Olympus",
    Cosmetic_HousePillarsA = "House Decor: Sets bone-laced columns to support the House",
    Cosmetic_HousePillarsB = "House Decor: Sets gem-encrusted columns to support the House",
    Cosmetic_WallWeaponSword = "House Decor: Accents the East Wing walls with double-edged swords",
    Cosmetic_WallWeaponAxe = "House Decor: Accents the East Wing walls with twin-bladed axes",
    Cosmetic_WallWeaponBident = "House Decor: Accents the East Wing walls with two-pronged spears",
    Cosmetic_MainHallBones = "House Decor: Unnerves shades waiting for something in the House",
    Cosmetic_MainHallCenterpieceA = "House Decor: Adorns the Great Hall with the Master's mark",
    Cosmetic_MainHallCouch = "House Decor: Deepens the oblivion of sleep",
    Cosmetic_MainHallFireplace = "House Decor: Adds a hellish flame-wall by the Pool of Styx",
    Cosmetic_MainHallFireplaceA = "House Decor: Adds a resplendent flame-wall by the Pool of Styx",
    Cosmetic_MainHallFlowers = "House Decor: Enhances the ambiance near the Pool of Styx",
    Cosmetic_MainHallPetalFlyers = "House Decor: Adds drama while rising defiantly from the Pool of Styx",
    Cosmetic_MainHallPetals = "House Decor: Adorns the area about the Pool of Styx",
    Cosmetic_MainHallSarcophagi = "House Decor: Exposes sarcophagi of ancient kings slain in war",
    Cosmetic_MainHallThroneA = "House Decor: Alters the Great Throne with a hound motif",
    Cosmetic_MainHallTikiTorches = "House Decor: Gives off an infernal glow near the Pool of Styx",
    Cosmetic_MainHallTowels = "House Decor: Dries those who enter the House the painful way",
    Cosmetic_CharonPillars = "House Decor: Sets solid-gold sculptures near the Pool of Styx",
    Cosmetic_NorthHallMirror = "House Decor: Makes the path across the House look twice as long",
    Cosmetic_NorthHallCouch = "House Decor: Enhances the viewing area near the West Hall",
    Cosmetic_NorthHallRug = "House Decor: Adds a touch of grit to the West Hall",
    Cosmetic_NorthHallRugA = "House Decor: Adds some regal flair to the West Hall",
    Cosmetic_NorthHallRugB = "House Decor: Adds a touch of comfort to the West Hall",
    Cosmetic_NorthHallRugC = "House Decor: Adds a touch of melancholy to the West Hall",
    CosmeticAchillesRug = "House Decor: Adds supple flooring at the East Wing intersection",
    Cosmetic_NorthHallPaintingZagreus = "House Decor: Depicts the likeness of the son of the god of the dead",
    Cosmetic_NorthHallPaintingHades = "House Decor: Depicts the likeness of Lord Hades himself",
    Cosmetic_NorthHallPaintingFury = "House Decor: Depicts the Erinyes in a rare simultaneous appearance",
    Cosmetic_NorthHallPaintingMysteryWoman = "House Decor: Depicts the likeness of Nyx, Night Incarnate",
    Cosmetic_NorthHallPaintingMysteryGirl = "House Decor: Depicts the likeness of a Cretan princess",
    Cosmetic_NorthHallPaintingTots = "House Decor: Depicts the three-headed monster in his prime",
    Cosmetic_NorthHallPaintingTheseus = "House Decor: Depicts the likeness of the champion of Elysium",
    Cosmetic_NorthHallPaintingTartarus = "House Decor: Depicts the lowest reaches of the Underworld",
    Cosmetic_NorthHallPaintingAsphodel = "House Decor: Depicts the fiery River Phlegethon",
    Cosmetic_NorthHallPaintingElysium = "House Decor: Depicts the fields reserved for the greatest souls",
    Cosmetic_NorthHallPedestalMechanism = "House Decor: Supposedly measures infinitesimal distances",
    Cosmetic_NorthHallPedestalBust = "House Decor: Looks fearsome without attacking on sight",
    Cosmetic_NorthHallPedestalSphere = "House Decor: Hewed from inflammable material",
    Cosmetic_NorthHallSundial = "House Decor: Tells time using Helios' flaming chariot (not included)",
    Cosmetic_NorthHallPedestalA = "House Decor: Makes display-pedestals display-worthy themselves",
    Cosmetic_NorthHallFountain = "House Decor: Bubbles ceaselessly, soothing those within earshot",
    Cosmetic_NorthHallWarriorStatue = "House Decor: Impresses, even inspires onlookers",
    Cosmetic_ThanatosCouch = "House Decor: Adds plush comfort near the southwest balcony",
    Cosmetic_ThanatosChair = "House Decor: Adds seating near the southwest balcony",
    Cosmetic_ThanatosRug = "House Decor: Adds melancholy flooring near the southwest balcony",
    Cosmetic_ThanatosTable = "House Decor: Adds a small utility space near the southwest balcony",
    Cosmetic_ThanatosBrazier = "House Decor: Adds moody lighting near the southwest balcony",
    HousePoster01 = "Bedroom Decor: Features a likeness of the greatest of the Greeks",
    HousePoster02 = "Bedroom Decor: Features the goddess of love and beauty herself",
    HousePoster05 = "Bedroom Decor: Features the jubilant and carefree god of wine",
    HouseDagger01 = "Bedroom Decor: Showcases broken weapons from a historic siege",
    HouseWaterBowl01 = "Bedroom Decor: Contains faint traces of the past if you look closely",
    HouseLyre01 = "Bedroom Decor: Creates beautiful music, if you know how.",
    HouseBed01a = "Bedroom Decor: Updates the bedchamber's namesake with a deathly motif",
    HouseCouch02A = "Bedroom Decor: Seats one or more individuals (if they can sit)",
    HouseRug03B = "Bedroom Decor: Gives more of a grown-up look to any bedchamber",
    HouseWeights01 = "Bedroom Decor: Remains firmly rooted, no matter one's strength",
    HouseGamingTable01 = "Bedroom Decor: Contains a variety of frankly unplayable games",
    Cosmetic_CerberusBed = "House Decor: Provides elegant comfort for large hounds",
    Cosmetic_CerberusBedA = "House Decor: Provides luxurious comfort for large hounds",
    Cosmetic_CerberusBall = "House Decor: Enjoyed by some hounds with one or more heads",
    Cosmetic_CerberusToy = "House Decor: Chewed by some hounds with one or more heads",
    Cosmetic_ClearFur = "House Repair: Gets rid of the huge clumps of fur shed by Cerberus",
    Cosmetic_ClearScratches = "House Repair: Repairs the unsightly damage dealt by Cerberus",
    Cosmetic_LoungeRug = "House Decor: Adds a touch of grit to the lounge",
    Cosmetic_SeatCushions = "House Decor: Cushions the posterior while waiting eternally",
    Cosmetic_LoungeChairsA = "House Decor: Installs green sitting-stools in the lounge",
    Cosmetic_LoungeAdditionalSeating = "House Decor: Provides more places to sit and while away the time",
    Cosmetic_LoungeTablesA = "House Decor: Sets up lounge tables with a snake-like theme",
    Cosmetic_LoungeRugA = "House Decor: Adds some regal flair to the lounge",
    Cosmetic_LoungeRugB = "House Decor: Adds a touch of comfort to the lounge",
    Cosmetic_LoungeRugC = "House Decor: Adds a touch of melancholy to the lounge",
    Cosmetic_LoungeBrokerRug = "House Decor: Softens the surface leading to the lounge",
    Cosmetic_LoungePaintingSkelly = "House Decor: Depicts a skeleton enjoying the afterlife",
    Cosmetic_LoungeFireplace = "House Decor: Sets a flame-wall for all to see in the lounge",
    Cosmetic_BatCage = "House Decor: Houses an obedient colony of surveillance-bats",
    Cosmetic_Aquarium = "House Decor: For river denizens transplanted from the Underworld",
    Cosmetic_LoungeShortcut = "House Decor: Adds a discreet, new western entrance to the lounge",
    Cosmetic_LoungeDiscoBall = "House Decor: Reflects light in a vividly hypnotic pattern",
    Cosmetic_LoungeDiscoBallA = "House Decor: Reflects light in a frankly upsetting pattern",
    Cosmetic_LoungeLiquor = "House Decor: Reinforces the long-depleted honor bar",
    Cosmetic_KitchenIsland = "House Decor: Makes the kitchen appear to serve superior cuisine",
    Cosmetic_KitchenStoveCauldron = "House Decor: Conversation-starter for shades milling in the lounge",
    Cosmetic_KitchenStoveFlame = "House Decor: Gives the lounge a sense of homely decency",
    Cosmetic_LoungeClayOven = "House Decor: Cooks various foods to perfection (or anything really)",
    Cosmetic_SpiceRack = "House Decor: Seasons dishes so even the dead can taste them",
    Cosmetic_Knives = "House Decor: Slices through pomegranates with disturbing ease",
    Cosmetic_LoungeTreatJar = "House Decor: Contains unappetizing bits of sustenance",
    Cosmetic_HangingFood = "House Decor: Displays meats cured of the curse of the living",
    Cosmetic_LoungeCakeDisplay = "House Decor: Preserves a rare treat for a truly special occasion",
}

-- Resource name mapping for readable output
local resourceNames = {
    ["Gems"] = "Gemstones",
    ["SuperGems"] = "Diamonds",
    ["LockKeys"] = "Chthonic Keys",
    ["SuperLockKeys"] = "Titan Blood",
    ["MetaPoints"] = "Darkness",
    ["GiftPoints"] = "Nectar",
    ["SuperGiftPoints"] = "Ambrosia",
    ["Nectar"] = "Nectar",
}

-- Safe helper to get a display name with fallback
local function SafeGetDisplayName(key)
    if not key or key == "" then return "" end
    -- Check hardcoded names first
    if ContractorItemNames[key] then
        return ContractorItemNames[key]
    end
    -- Try engine GetDisplayName
    local ok, result = pcall(GetDisplayName, { Text = key })
    if ok and result and result ~= "" and result ~= key then
        return StripFormatting(result)
    end
    return ""
end

-- Suppress counter for first auto-focused item after category switch / screen open
-- (prevents the category/open announcement from being interrupted)
suppressContractorHoverCount = 0

-- Wrap the existing MouseOverGhostAdminItem to add speech
ModUtil.WrapBaseFunction("MouseOverGhostAdminItem", function(baseFunc, button)
    baseFunc(button)

    if not AccessibilityEnabled or not AccessibilityEnabled() or not button then
        return
    end

    if suppressContractorHoverCount > 0 then
        suppressContractorHoverCount = suppressContractorHoverCount - 1
        return
    end

    local displayName = nil

    -- Check button.Data.Name against hardcoded names first (e.g. music track paths)
    if button.Data and button.Data.Name and ContractorItemNames[button.Data.Name] then
        displayName = ContractorItemNames[button.Data.Name]
    end

    -- Try DisplayName field (set by game code)
    if (not displayName or displayName == "") and button.DisplayName and button.DisplayName ~= "" then
        displayName = SafeGetDisplayName(button.DisplayName)
        if displayName == "" then
            displayName = button.DisplayName
        end
    end

    -- Fallback: try button.Data.Name
    if (not displayName or displayName == "") and button.Data and button.Data.Name then
        displayName = SafeGetDisplayName(button.Data.Name)
        if displayName == "" then
            displayName = button.Data.Name
        end
    end

    if not displayName or displayName == "" then
        return
    end

    displayName = StripFormatting(displayName)
    local speech = displayName

    -- Add cost info for unpurchased items
    if button.Data then
        if button.Data.ResourceCost and not button.Free then
            local resName = resourceNames[button.Data.ResourceName] or button.Data.ResourceName or ""
            if GameState and GameState.CosmeticsAdded and GameState.CosmeticsAdded[button.Data.Name] then
                -- Already purchased
                if button.Data.Removable then
                    if GameState.Cosmetics and GameState.Cosmetics[button.Data.Name] then
                        speech = speech .. ", Active, Removable"
                    else
                        speech = speech .. ", Purchased, Can Re-Add"
                    end
                else
                    speech = speech .. ", Purchased"
                end
            else
                speech = speech .. ", " .. button.Data.ResourceCost .. " " .. resName
                -- Check if affordable
                if not HasResource(button.Data.ResourceName, button.Data.ResourceCost) then
                    speech = speech .. ", " .. UIStrings.CannotAfford
                end
            end
        elseif button.Free then
            speech = speech .. ", " .. UIStrings.Free
        end

        -- Add description
        local itemName = button.Data.Name
        if itemName and ContractorItemDescriptions[itemName] then
            speech = speech .. ". " .. ContractorItemDescriptions[itemName]
        end
    end

    TolkSilence()
    TolkSpeak(speech)
end)

-- Speak category name + first item name when switching categories
ModUtil.WrapBaseFunction("DisplayCosmetics", function(baseFunc, screen, slotName)
    _Log("[WRAP] DisplayCosmetics category: " .. tostring(slotName))
    baseFunc(screen, slotName)

    -- Fix: Add OnMouseOverFunctionName + AttachLua to ALL PurchaseButton components
    -- The base game only sets this on AVAILABLE (unpurchased) items.
    -- Purchased items don't get OnMouseOverFunctionName, so in endgame saves where
    -- most items are purchased, the accessibility mod can't read them.
    if AccessibilityEnabled and AccessibilityEnabled() and screen and screen.Components then
        local components = screen.Components
        for i = 1, screen.NumItems or 0 do
            local key = "PurchaseButton" .. i
            local comp = components[key]
            if comp and comp.Id and not comp.OnMouseOverFunctionName then
                comp.OnMouseOverFunctionName = "MouseOverGhostAdminItem"
                AttachLua({ Id = comp.Id, Table = comp })
            end
        end
    end

    if AccessibilityEnabled and AccessibilityEnabled() and slotName then
        local displayName = SafeGetDisplayName(slotName)
        if displayName == "" then
            displayName = slotName
        end
        local speech = string.format(UIStrings.CategoryFmt, displayName)
        -- Get first item name to combine with category name
        if screen and screen.Components then
            local firstComp = screen.Components["PurchaseButton1"]
            if firstComp then
                local firstName = nil
                if firstComp.DisplayName and firstComp.DisplayName ~= "" then
                    firstName = SafeGetDisplayName(firstComp.DisplayName)
                    if firstName == "" then firstName = firstComp.DisplayName end
                end
                if (not firstName or firstName == "") and firstComp.Data and firstComp.Data.Name then
                    firstName = SafeGetDisplayName(firstComp.Data.Name)
                    if firstName == "" then firstName = firstComp.Data.Name end
                end
                if firstName and firstName ~= "" then
                    firstName = StripFormatting(firstName)
                    speech = speech .. ", " .. firstName
                end
            end
        end
        -- Prepend open speech if this is the first category after screen open
        if _contractorOpenSpeech then
            speech = _contractorOpenSpeech .. ", " .. speech
            _contractorOpenSpeech = nil
        end
        TolkSilence()
        TolkSpeak(speech)
        -- Suppress the first auto-focused item so category announcement isn't interrupted
        suppressContractorHoverCount = 1
    end
end)

-- Store open speech text; DisplayCosmetics will combine it with category + first item
_contractorOpenSpeech = nil

-- Speak when the House Contractor screen opens
ModUtil.WrapBaseFunction("OpenGhostAdminScreen", function(baseFunc, defaultCategory)
    _Log("[SCREEN-OPEN] House Contractor (OpenGhostAdminScreen)")
    if AccessibilityEnabled and AccessibilityEnabled() then
        local openText = UIStrings.HouseContractor
        if GameState and GameState.Resources and GameState.Resources.Gems then
            openText = openText .. ", " .. string.format(UIStrings.GemsAvailableFmt, GameState.Resources.Gems)
        end
        _contractorOpenSpeech = openText
    end
    return baseFunc(defaultCategory)
end)
