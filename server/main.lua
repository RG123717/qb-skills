-- server/main.lua

local QBCore = exports['qb-core']:GetCoreObject()

-- Ensure QBCore is loaded
Citizen.CreateThread(function()
    while QBCore == nil do
        TriggerEvent('QBCore:GetObject', function(obj) QBCore = obj end)
        Citizen.Wait(200)
    end
end)

QBCore.Functions.CreateCallback("qb-skills:getPlayerSkills", function(source, cb)
    local src = source

    Citizen.CreateThread(function()
        local Player = QBCore.Functions.GetPlayer(src)

        while Player == nil or Player.PlayerData == nil or Player.PlayerData.citizenid == nil do
            Citizen.Wait(500)
            Player = QBCore.Functions.GetPlayer(src)
        end

        local playerId = Player.PlayerData.citizenid

        -- Fetch player skills from the database
        exports.ghmattimysql:execute("SELECT skills FROM players_skills WHERE citizenid=@citizenid", {
            ["@citizenid"] = playerId
        }, function(result)
            if result and result[1] then
                local skills = json.decode(result[1].skills)
                cb(skills)
            else
                -- If no skills data exists for the player, create a default skills table
                local defaultSkills = {
                    health = 1,
                    speed = 1,
                    driving = 1
                }
                exports.ghmattimysql:execute("INSERT INTO players_skills (citizenid, skills) VALUES (@citizenid, @skills)", {
                    ["@citizenid"] = playerId,
                    ["@skills"] = json.encode(defaultSkills)
                })
                cb(defaultSkills)
            end
        end)
    end)
end)

RegisterServerEvent("qb-skills:updateSkill")
AddEventHandler("qb-skills:updateSkill", function(skill, level)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local playerId = Player.PlayerData.citizenid

    -- Fetch current player skills
    QBCore.Functions.TriggerCallback("qb-skills:getPlayerSkills", function(skills)
        -- Update the skill
        skills[skill] = level

        -- Update the skill in the database
        exports.ghmattimysql:execute("UPDATE players_skills SET skills=@skills WHERE citizenid=@citizenid", {
            ["@citizenid"] = playerId,
            ["@skills"] = json.encode(skills)
        })
    end, src)
end)
