--[[
Mod: GodGaugeSounds
Author: hllf
Version: 27

Intended as an accessibility mod. Provides audible cues as the god gauge charges up and reaches full power.
Use the mod importer to import this mod.
--]]

godGaugePips = 0
ModUtil.WrapBaseFunction("UpdateSuperMeterUIReal", function(baseFunc)
    local ret = baseFunc()
    if ScreenAnchors.SuperMeterIcon == nil then
        return ret
    end
    local oldPips = godGaugePips
    local newPips = 0
    local maxPips = math.ceil(CurrentRun.Hero.SuperMeterLimit / CurrentRun.Hero.SuperCost)
    local godGaugePoints = CurrentRun.Hero.SuperMeter or 0
    for i = 1, maxPips do
        local fillPercent = 0
        if godGaugePoints > (i - 1) * CurrentRun.Hero.SuperCost then
            if CurrentRun.Hero.SuperMeterLimit < CurrentRun.Hero.SuperCost * i and i == maxPips then
                fillPercent = math.min(1, (godGaugePoints - (i - 1) * CurrentRun.Hero.SuperCost) / (CurrentRun.Hero.SuperMeterLimit % CurrentRun.Hero.SuperCost))
            else
                fillPercent = math.min(1, (godGaugePoints - (i - 1) * CurrentRun.Hero.SuperCost) / CurrentRun.Hero.SuperCost)
            end
        end
        if fillPercent == 1 then
            newPips = newPips + 1
        end
    end
    godGaugePips = newPips
    if newPips > oldPips then
        thread(function()
            if newPips == maxPips then
                for i = 1, 5 do
                    PlaySound({ Name = "/SFX/WrathEndingWarning" })
                    wait(0.05)
                end
            else
                for i = 1, newPips do
                    PlaySound({ Name = "/Leftovers/SFX/FieldReviveSFX" })
                    wait(0.4)
                end
            end
        end)
    end
    return ret
end)
