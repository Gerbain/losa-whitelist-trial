local isLocked = false

-- Tell the server we've actually spawned into the world (not just char select)
AddEventHandler('playerSpawned', function()
    TriggerServerEvent('discord_gate:playerReady')
end)

-- Show the gate UI
RegisterNetEvent('discord_gate:showUI', function(inGuild, customMessage)
    isLocked = true

    SetNuiFocus(true, true)

    SendNUIMessage({
        action      = "show",
        discordLink = Config.DiscordLink,
        serverName  = Config.ServerName,
        message     = customMessage or Config.NUIMessage,
        subMessage  = Config.NUISubMessage,
        inGuild     = inGuild
    })

    local ped = PlayerPedId()
    SetEntityVisible(ped, false, false)
    SetEntityInvincible(ped, true)
    SetLocalPlayerInvisibleLocally(true)
    SetEntityCollision(ped, false, false)
    FreezeEntityPosition(ped, true)

    CreateThread(function()
        while isLocked do
            local ped = PlayerPedId()
            FreezeEntityPosition(ped, true)
            DisableAllControlActions(0)
            Wait(0)
        end
    end)
end)

-- Hide the gate UI
RegisterNetEvent('discord_gate:hideUI', function()
    if not isLocked then return end
    isLocked = false

    SetNuiFocus(false, false)
    SendNUIMessage({ action = "hide" })

    local ped = PlayerPedId()
    SetEntityVisible(ped, true, true)
    SetEntityInvincible(ped, false)
    SetLocalPlayerInvisibleLocally(false)
    SetEntityCollision(ped, true, true)
    FreezeEntityPosition(ped, false)
end)

RegisterNetEvent('discord_gate:checking', function()
    SendNUIMessage({ action = "checking" })
end)

RegisterNUICallback('recheck', function(data, cb)
    TriggerServerEvent('discord_gate:recheck')
    cb('ok')
end)

RegisterNUICallback('copyLink', function(data, cb)
    cb('ok')
end)

AddEventHandler('baseevents:onPlayerDied', function()
    if isLocked then
        CreateThread(function()
            Wait(500)
            local ped = PlayerPedId()
            SetEntityCollision(ped, false, false)
            FreezeEntityPosition(ped, true)
        end)
    end
end)

-- -----------------------------------------------------------------------
-- Staff: draw emoji marker above trial players' heads
-- -----------------------------------------------------------------------
local trialPlayerIds = {}
local isStaff = false

-- Check if we're staff on spawn
AddEventHandler('playerSpawned', function()
    TriggerServerEvent('discord_gate:requestSync')
end)

-- Receive updated trial list from server
RegisterNetEvent('discord_gate:trialPlayers', function(list)
    isStaff = true
    trialPlayerIds = {}
    for _, serverId in ipairs(list) do
        trialPlayerIds[serverId] = true
    end
end)

-- Draw loop — only runs if we received a staff sync
CreateThread(function()
    while true do
        Wait(0)
        if not isStaff or not Config.StaffMarkers then
            Wait(5000)
        else
            for _, playerId in ipairs(GetActivePlayers()) do
                local serverId = GetPlayerServerId(playerId)
                if trialPlayerIds[serverId] and serverId ~= GetPlayerServerId(PlayerId()) then
                    local ped = GetPlayerPed(playerId)
                    if DoesEntityExist(ped) and not IsEntityDead(ped) then
                        local pos = GetEntityCoords(ped)
                        -- Draw above their head
                        DrawMarker(
                            2,              -- type: chevron pointing down
                            pos.x, pos.y, pos.z + 2.2,
                            0.0, 0.0, 0.0,  -- direction
                            0.0, 180.0, 0.0, -- rotation (flip chevron to point down)
                            0.4, 0.4, 0.4,  -- scale
                            255, 165, 0, 180, -- orange, semi-transparent
                            false, true, 2, false, nil, nil, false
                        )

                        -- Draw "TRIAL" text above the marker
                        local camCoords = GetGameplayCamCoords()
                        local dist = #(camCoords - pos)
                        if dist < 20.0 then
                            SetTextScale(0.0, 0.35)
                            SetTextFont(4)
                            SetTextColour(255, 165, 0, 255)
                            SetTextOutline()
                            SetTextEntry("STRING")
                            AddTextComponentString("⏳ TRIAL")
                            SetTextJustification(0)
                            local x, y = World3dToScreen2d(pos.x, pos.y, pos.z + 2.75)
                            if x and y then
                                DrawText(x, y)
                            end
                        end
                    end
                end
            end
        end
    end
end)
