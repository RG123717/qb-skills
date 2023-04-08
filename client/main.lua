-- client/main.lua
local QBCore = exports['qb-core']:GetCoreObject()
local playerSkills = {}

-- Example skills

local skillList = {
    health = {
        name = "Health",
        levels = 5,
        effects = {
            {-50}, -- Level 1: 50% less health (weaker)
            {0}, -- Level 2: Default health
            {50}, -- Level 3: 50% more health
            {100}, -- Level 4: 100% more health
            {150}, -- Level 5: 150% more health
        }
    },
    speed = {
        name = "Running Speed",
        levels = 5,
        effects = {
            {0.5}, -- Level 1: 50% slower (weaker)
            {1}, -- Level 2: Default speed
            {1.5}, -- Level 3: 50% faster
            {2}, -- Level 4: 100% faster
            {2.5}, -- Level 5: 150% faster
        }
    },
    driving = {
        name = "Driving",
        levels = 5,
        effects = {
            {0.8}, -- Level 1: 20% worse grip and acceleration (weaker)
            {1}, -- Level 2: Default grip and acceleration
            {1.2}, -- Level 3: 20% better grip and acceleration
            {1.4}, -- Level 4: 40% better grip and acceleration
            {1.6}, -- Level 5: 60% better grip and acceleration
        }
    }
}


-- Fetch the player's skills on spawn
AddEventHandler("playerSpawned", function()
    QBCore.Functions.TriggerCallback("qb-skills:getPlayerSkills", function(skills)
        playerSkills = skills
        ApplySkillEffects(playerSkills)
    end)
end)

-- Function to apply skill effects on the client-side
function ApplySkillEffects(skills)
    local playerPed = PlayerPedId()

    -- Apply health effect
    local healthBonus = skillList.health.effects[skills.health][1]
    local newMaxHealth = 200 + healthBonus
    SetEntityMaxHealth(playerPed, newMaxHealth)
    SetEntityHealth(playerPed, newMaxHealth)

    -- Apply running speed effect
    local speedMultiplier = skillList.speed.effects[skills.speed][1]
    SetRunSprintMultiplierForPlayer(PlayerId(), speedMultiplier)

    -- Apply driving skill effect (handled in a separate function)
    ApplyDrivingSkillEffect(skills.driving)
end



function ApplyDrivingSkillEffect(level)
    local drivingMultiplier = skillList.driving.effects[level][1]

    -- Apply the driving skill effect when the player enters a vehicle
    Citizen.CreateThread(function()
        local playerPed = PlayerPedId()

        while true do
            Citizen.Wait(0)

            if IsPedInAnyVehicle(playerPed, false) then
                local vehicle = GetVehiclePedIsIn(playerPed, false)

                -- Increase grip and acceleration based on the driving skill level
                local currentTractionCurveMax = GetVehicleHandlingFloat(vehicle, "CHandlingData", "TRACTION_CURVE_MAX")
                local currentInitialDriveForce = GetVehicleHandlingFloat(vehicle, "CHandlingData", "INITIAL_DRIVE_FORCE")
                local newTractionCurveMax = currentTractionCurveMax * drivingMultiplier
                local newInitialDriveForce = currentInitialDriveForce * drivingMultiplier

                -- Update the handling properties of the vehicle
                SetVehicleHandlingFloat(vehicle, "CHandlingData", "TRACTION_CURVE_MAX", newTractionCurveMax)
                SetVehicleHandlingFloat(vehicle, "CHandlingData", "INITIAL_DRIVE_FORCE", newInitialDriveForce)
            end
        end
    end)
end


-- Function to handle skill tree UI interactions and communicate with the server
function UpdateSkill(skill, level)
    -- Update the local playerSkills table
    playerSkills[skill] = level

    -- Notify the server of the updated skill
    TriggerServerEvent("qb-skills:updateSkill", skill, level)

    -- Apply the updated skill effect
    ApplySkillEffects(playerSkills)
end

-- Basic UI for the skill tree (for demonstration purposes)
RegisterCommand("showSkillTree", function()
    print("Skill tree:")
    for skillKey, skillData in pairs(skillList) do
        print(string.format("%s (Levels: %d)", skillData.name, skillData.levels))
        print("  Effects:")
        for i, effect in ipairs(skillData.effects) do
            print(string.format("    Level %d: %+d", i, effect[1]))
        end
        print("")
    end
    print("Type /upgradeSkill [skill] [level] to upgrade a skill")
end, false)

RegisterCommand("upgradeSkill", function(source, args)
    local skill = args[1]
    local level = tonumber(args[2])

    if skillList[skill] and level >= 1 and level <= skillList[skill].levels then
        UpdateSkill(skill, level)
        print(string.format("Upgraded %s to level %d", skillList[skill].name, level))
    else
        print("Invalid skill or level. Type /showSkillTree to view the skill tree.")
    end
end, false)

