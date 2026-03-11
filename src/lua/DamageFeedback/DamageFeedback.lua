--[[
Mod: DamageFeedback
Version: 2

Provides damage dealt feedback in 4 modes:
  0 = Off (no feedback)
  1 = Audible Healthbars (synthesized tone: pitch maps to enemy remaining health/armor %)
  2 = Damage Dealt (speech: reads damage amount and armor/health)
  3 = Combined (both tones AND speech)

Armor has a separate noisy tone (white noise mixed in) to distinguish from health.
Only real enemies get tones — breakable objects (pots, urns) are filtered out.

Toggle: Shift+\ (pipe) on keyboard, L3 on controller.
State set by C++ via _DamageFeedbackMode global (persisted to disk).
--]]

-- Nil-safety: bridge may not be registered yet
if not AccessibilityEnabled or not AccessibilityEnabled() then return end

local _lastDamageTime = 0
local COOLDOWN = 0.060 -- ~60ms between feedback events to prevent flooding

-- Track max armor per enemy (no MaxHealthBuffer field on victims)
local _enemyMaxArmor = {}

local function _Log(msg)
    if LogEvent then
        LogEvent("[DAMAGE-FB] " .. msg)
    end
end

_Log("DamageFeedback mod loading")

ModUtil.WrapBaseFunction("DamageEnemy", function(baseFunc, victim, triggerArgs)
    -- Guard: mode off
    if not _DamageFeedbackMode or _DamageFeedbackMode == 0 then
        return baseFunc(victim, triggerArgs)
    end

    -- Guard: only player-caused damage
    if not triggerArgs or not CurrentRun or not CurrentRun.Hero then
        return baseFunc(victim, triggerArgs)
    end
    if triggerArgs.AttackerTable ~= CurrentRun.Hero then
        return baseFunc(victim, triggerArgs)
    end

    -- Guard: victim must have health
    if not victim or not victim.Health or not victim.MaxHealth then
        return baseFunc(victim, triggerArgs)
    end

    -- Guard: skip breakable objects (pots, urns, etc.) — only real enemies
    if victim.GenusName == "Breakable" then
        return baseFunc(victim, triggerArgs)
    end

    -- Capture pre-damage state
    local prevHealth = victim.Health or 0
    local prevArmor = victim.HealthBuffer or 0
    local maxHealth = victim.MaxHealth or 1

    -- Call original damage function
    local result = baseFunc(victim, triggerArgs)

    -- Compute post-damage state
    local newHealth = victim.Health or 0
    local newArmor = victim.HealthBuffer or 0
    local armorDamage = prevArmor - newArmor
    local healthDamage = prevHealth - newHealth
    local armorBroke = (prevArmor > 0 and newArmor <= 0)
    local killed = (newHealth <= 0 and prevHealth > 0)

    -- Skip if no damage was actually dealt
    if armorDamage <= 0 and healthDamage <= 0 then
        return result
    end

    -- Cooldown: prevent flooding from rapid multi-hit attacks
    -- Kill events ALWAYS bypass cooldown — they must never be suppressed
    local now = _worldTime or 0
    if not killed and now - _lastDamageTime < COOLDOWN then
        return result
    end
    if killed then
        _Log("KILL: prevH=" .. prevHealth .. " newH=" .. newHealth
             .. " dt=" .. string.format("%.4f", now - _lastDamageTime)
             .. " boss=" .. tostring(victim.IsBoss or false)
             .. " id=" .. tostring(victim.ObjectId))
    end
    _lastDamageTime = now

    -- Audible Healthbars (mode 1 or 3) — separate pcall so tone errors don't block speech
    if _DamageFeedbackMode == 1 or _DamageFeedbackMode == 3 then
        local tok, terr = pcall(function()
            if killed then
                -- Kill confirmation: distinct low tone, longer duration
                DamageBeep(110, 120)
            elseif armorDamage > 0 and newArmor > 0 then
                -- Armor damage: noisy tone based on armor remaining %
                local eid = victim.ObjectId
                if eid then
                    if not _enemyMaxArmor[eid] then
                        _enemyMaxArmor[eid] = prevArmor
                    end
                    local maxArmor = _enemyMaxArmor[eid]
                    local armorPercent = newArmor / math.max(maxArmor, 1)
                    armorPercent = math.max(0, math.min(1, armorPercent))
                    local minFreq = 220
                    local maxFreq = 880
                    local freq = math.floor(minFreq * (maxFreq / minFreq) ^ armorPercent)
                    DamageBeepArmor(freq, 80)
                end
            elseif armorBroke then
                -- Armor just broke: noisy low tone confirmation
                DamageBeepArmor(110, 120)
            else
                -- Health damage: clean tone based on health remaining %
                local healthPercent = newHealth / math.max(maxHealth, 1)
                healthPercent = math.max(0, math.min(1, healthPercent))
                local minFreq = 220
                local maxFreq = 880
                local freq = math.floor(minFreq * (maxFreq / minFreq) ^ healthPercent)
                DamageBeep(freq, 80)
            end
        end)
        if not tok then
            _Log("Tone error: " .. tostring(terr) .. " killed=" .. tostring(killed))
        end
    end

    -- Damage Dealt speech (mode 2 or 3) — separate pcall from tones
    if _DamageFeedbackMode == 2 or _DamageFeedbackMode == 3 then
        local sok, serr = pcall(function()
            local parts = {}

            if armorBroke then
                parts[#parts + 1] = UIStrings.ArmorBroken
            end

            if armorDamage > 0 and not armorBroke then
                parts[#parts + 1] = tostring(math.floor(armorDamage)) .. " " .. UIStrings.Armor
            end

            if healthDamage > 0 then
                parts[#parts + 1] = tostring(math.floor(healthDamage)) .. " " .. UIStrings.Health
            end

            if killed then
                parts[#parts + 1] = UIStrings.Killed
            end

            if #parts > 0 then
                local speech = parts[1]
                for i = 2, #parts do
                    speech = speech .. ", " .. parts[i]
                end
                TolkSilence()
                TolkSpeak(speech)
            end
        end)
        if not sok then
            _Log("Speech error: " .. tostring(serr) .. " killed=" .. tostring(killed))
        end
    end

    -- Clean up max armor tracking for killed enemies
    if killed and victim.ObjectId then
        _enemyMaxArmor[victim.ObjectId] = nil
    end

    -- Encounter completion sound: check if no required-kill enemies remain
    -- After baseFunc (DamageEnemy) returns, Kill() has already removed the dead enemy
    -- from RequiredKillEnemies. If the table is now empty, the encounter is cleared.
    if killed and _DamageFeedbackMode and _DamageFeedbackMode > 0 then
        pcall(function()
            if RequiredKillEnemies then
                local hasRemaining = false
                for _ in pairs(RequiredKillEnemies) do
                    hasRemaining = true
                    break
                end
                if not hasRemaining then
                    PlaySound({ Name = "/SFX/Menu Sounds/GodBoonInteract" })
                    _Log("Encounter clear sound played")
                end
            end
        end)
    end

    return result
end)

_Log("DamageFeedback mod loaded")
