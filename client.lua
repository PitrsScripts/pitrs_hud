local showHud = true
local isTalking = false
local proximity = 'normal'
local currentStamina = 100
local safeStamina = 100

local micModes = {"whisper", "normal", "shouting"}
local currentMicModeIndex = 2

local lastArmorValue = 0
local lastHealthValue = 0 
local lastArmorUpdate = 0
local updateInterval = 1000 
local Framework = nil
local QBCore = nil

CreateThread(function()
    if GetResourceState('es_extended') == 'started' then
        Framework = 'ESX'
    elseif GetResourceState('qb-core') == 'started' then
        Framework = 'QBCore'
        QBCore = exports['qb-core']:GetCoreObject()
    end
end)

local function initVoiceHUD()
    proximity = "normal" -- Výchozí režim
    updateVoiceHUD()
    TriggerEvent('pma-voice:setTalkingMode', 'normal')
end


-- ===========================
-- == STATUS AND NUI UPDATE ==
-- ===========================

CreateThread(function()
    while true do
        Wait(500)

        local playerPed = PlayerPedId()
        local playerId = PlayerId()

        local isShiftHeld = IsControlPressed(0, 21)
        local speed = GetEntitySpeed(playerPed)
        local isSprinting = isShiftHeld and speed > 1.5

        if isSprinting then
            safeStamina = math.max(0, safeStamina - 5)
        else
            safeStamina = math.min(100, safeStamina + 1)
        end

        currentStamina = safeStamina

        local health = GetEntityHealth(playerPed) - 100
        local armor = GetPedArmour(playerPed)
        local oxygen = GetPlayerUnderwaterTimeRemaining(PlayerId()) * 10

        local coords = GetEntityCoords(playerPed)
        local streetHash, crossingHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z, Citizen.ResultAsInteger(), Citizen.ResultAsInteger())
        local streetName = GetStreetNameFromHashKey(streetHash)
        local zoneName = GetNameOfZone(coords.x, coords.y, coords.z)

        if Framework == 'ESX' then
            TriggerEvent('esx_status:getStatus', 'hunger', function(hunger)
                TriggerEvent('esx_status:getStatus', 'thirst', function(thirst)
                    SendNUIMessage({
                        action = "update",
                        health = health,
                        armor = armor,
                        hunger = hunger.getPercent(),
                        thirst = thirst.getPercent(),
                        stamina = currentStamina,
                        oxygen = math.floor(oxygen),
                    })
                    SendNUIMessage({
                        action = "updateLocation",
                        street = streetName,
                        area = zoneName
                    })
                end)
            end)
        elseif Framework == 'QBCore' then
    local PlayerData = QBCore.Functions.GetPlayerData()
    local isDead = PlayerData.metadata and PlayerData.metadata["isdead"]

    local health = isDead and 0 or (GetEntityHealth(playerPed) - 100)
    local hunger = PlayerData.metadata and PlayerData.metadata["hunger"] or 100
    local thirst = PlayerData.metadata and PlayerData.metadata["thirst"] or 100

    SendNUIMessage({
        action = "update",
        health = health,
        armor = armor,
        hunger = hunger,
        thirst = thirst,
        stamina = currentStamina,
        oxygen = math.floor(oxygen),
    })

    SendNUIMessage({
        action = "updateLocation",
        street = streetName,
        area = zoneName
    })
        end
    end
end)

-- PAUSEMENU 
CreateThread(function()
    local lastPauseState = false

    while true do
        Wait(250)

        local isPaused = IsPauseMenuActive()
        if isPaused ~= lastPauseState then
            lastPauseState = isPaused
            SendNUIMessage({
                action = "toggle",
                show = not isPaused
            })
        end
    end
end)


-- PLAYER ID
CreateThread(function()
    while true do
        Wait(2000)
        local serverId = GetPlayerServerId(PlayerId())

        SendNUIMessage({
            action = "setPlayerId",
            id = serverId
        })
    end
end)


-- PMA VOICE
RegisterNetEvent('pma-voice:setTalkingMode', function(mode)
    proximity = mode
    updateVoiceHUD()
end)

RegisterNetEvent('pma-voice:talking', function(talking)
    isTalking = talking
    updateVoiceHUD()
end)

CreateThread(function()
    while true do
        Wait(100)
        local talking = NetworkIsPlayerTalking(PlayerId())
        if talking ~= isTalking then
            isTalking = talking
            updateVoiceHUD()
        end
    end
end)

function updateVoiceHUD()
    SendNUIMessage({
        action = "voice",
        talking = isTalking,
        mode = proximity
    })
end

-- Microphone 
local function changeMicMode()
    currentMicModeIndex = currentMicModeIndex + 1
    if currentMicModeIndex > #micModes then
        currentMicModeIndex = 1
    end

    local newMicMode = micModes[currentMicModeIndex]

    if lib and lib.notify then
        lib.notify({
            title = 'Microphone mode',
            description = 'You are now speaking in mode: ' .. newMicMode,
            type = 'success'
        })
    end

    proximity = newMicMode
    updateVoiceHUD()
end

RegisterCommand('toggleMicMode', function()
    changeMicMode()
end, false)

RegisterKeyMapping('toggleMicMode', 'Microphone mode', 'keyboard', 'F11')

-- Toggle HUD
RegisterCommand("hud", function()
    showHud = not showHud
    SendNUIMessage({ action = "toggle", show = showHud })
end)

-- Minimap
local _DisplayRadar = DisplayRadar
DisplayRadar = function() end

function SetMinimapPosition()
    local defaultAspectRatio = 1920 / 1080
    local resolutionX, resolutionY = GetActiveScreenResolution()
    local aspectRatio = resolutionX / resolutionY
    local minimapXOffset, minimapYOffset = 0, 0
    if aspectRatio > defaultAspectRatio then
        local aspectDifference = defaultAspectRatio - aspectRatio
        minimapXOffset = aspectDifference / 3.6
    end

    local yOffsetAdjust = -0.01  
    local xOffsetAdjust = 0.01   

    SetMinimapComponentPosition(
        "minimap",
        "L",
        "B",
        (-0.0045 + minimapXOffset) + xOffsetAdjust,
        (-0.022 + yOffsetAdjust) + minimapYOffset,
        0.150,
        0.188888
    )

    SetMinimapComponentPosition(
        "minimap_mask",
        "L",
        "B",
        (0.020 + minimapXOffset) + xOffsetAdjust,
        (0.050 + yOffsetAdjust) + minimapYOffset,
        0.111,
        0.159
    )

    SetMinimapComponentPosition(
        "minimap_blur",
        "L",
        "B",
        (-0.03 + minimapXOffset) + xOffsetAdjust,
        (-0.0005 + yOffsetAdjust) + minimapYOffset,
        0.266,
        0.237
    )
end

CreateThread(function()
    while true do
        Wait(300)
        local playerPed = PlayerPedId()
        _DisplayRadar(IsPedInAnyVehicle(playerPed))
    end
end)

CreateThread(function()
    RequestScaleformMovie("minimap")
    SetRadarBigmapEnabled(false, false)
    Wait(0)
    SetRadarBigmapEnabled(false, false)
    SetMinimapPosition()
end)

Citizen.CreateThread(function()
    local minimap = RequestScaleformMovie("minimap")
    SetRadarBigmapEnabled(false, false)
    Wait(0)
    SetRadarBigmapEnabled(false, false)
    while true do
        Wait(100)
        BeginScaleformMovieMethod(minimap, "SETUP_HEALTH_ARMOUR")
        ScaleformMovieMethodAddParamInt(3)
        EndScaleformMovieMethod()
    end
end)

-- Armor and Health sync
RegisterNetEvent("QBCore:Client:OnPlayerLoaded", function()
    Wait(500)
    TriggerServerEvent('pitrs_hud:server:LoadArmorAndHealth')
    SetMinimapPosition()
    hudReady = true
    initVoiceHUD() 
end)

AddEventHandler('playerSpawned', function()
    Wait(1000)
    TriggerServerEvent('pitrs_hud:server:LoadArmorAndHealth')
    SetMinimapPosition()
    hudReady = true
    initVoiceHUD() 
end)

RegisterNetEvent('pitrs_hud:client:UpdateArmorAndHealth')
AddEventHandler('pitrs_hud:client:UpdateArmorAndHealth', function(armorValue, healthValue)
    local ped = PlayerPedId()
    SetPedArmour(ped, armorValue or 0)
    if healthValue and healthValue > 0 then
        SetEntityHealth(ped, healthValue + 100) 
    end
    lastArmorValue = armorValue or 0
    lastHealthValue = healthValue or 0 
end)

CreateThread(function()
    while true do
        Wait(500)
        local currentTime = GetGameTimer()
        if currentTime - lastArmorUpdate >= updateInterval then
            local playerPed = PlayerPedId()
            local currentArmor = GetPedArmour(playerPed)
            local currentHealth = GetEntityHealth(playerPed) - 100

            if currentArmor ~= lastArmorValue then
                TriggerServerEvent('pitrs_hud:server:UpdateArmor', currentArmor)
                lastArmorValue = currentArmor
            end
            if currentHealth ~= lastHealthValue then
                TriggerServerEvent('pitrs_hud:server:UpdateHealth', currentHealth)
                lastHealthValue = currentHealth
            end

            lastArmorUpdate = currentTime
        end
    end
end)

CreateThread(function()
    while true do
        Wait(500) 
        local ped = PlayerPedId()
        local inVehicle = IsPedInAnyVehicle(ped, false)
        SendNUIMessage({
            action = "toggleVehicleHud",
            show = inVehicle
        })
    end
end)

CreateThread(function()
    local directions = {
        [0]   = "North",
        [45]  = "Northeast",
        [90]  = "East",
        [135] = "Southeast",
        [180] = "South",
        [225] = "Southwest",
        [270] = "West",
        [315] = "Northwest",
        [360] = "North"
    }

    local function getDirectionFromHeading(heading)
        heading = heading % 360
        local closestAngle = 0
        local smallestDiff = 360

        for angle, name in pairs(directions) do
            local diff = math.abs(heading - angle)
            if diff > 180 then diff = 360 - diff end
            if diff < smallestDiff then
                smallestDiff = diff
                closestAngle = angle
            end
        end

        return directions[closestAngle]
    end

    while true do
        Wait(200)

        local playerPed = PlayerPedId()
        local heading = GetEntityHeading(playerPed)
        local directionName = getDirectionFromHeading(heading)

        SendNUIMessage({
            action = "updateCompassDirection",
            direction = directionName
        })
    end
end)


AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        local ped = PlayerPedId()
        local health = GetEntityHealth(ped) - 100
        local armor = GetPedArmour(ped)
        TriggerServerEvent('pitrs_hud:server:SaveHealthArmor', health, armor)
    end
end)






