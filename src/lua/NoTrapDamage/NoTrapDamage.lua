--[[
Mod: NoTrapDamage
Author: hllf & JLove
Version: 26

Intended as an accessibility mod. Prevents Zagreus from taking damage from traps and standing magma.
Use the mod importer to import this mod.
--]]

OnAnyLoad{
    function(triggerArgs)
        for k,v in pairs(UnitSetData.Enemies) do
            if v.DamageType == "Neutral" then
                if v.OutgoingDamageModifiers == nil then
                    v.OutgoingDamageModifiers = {
                        {
                            PlayerMultiplier = 0
                        }
                    }
                end
                v["OutgoingDamageModifiers"][1].PlayerMultiplier = 0
            end
        end
    end
}
