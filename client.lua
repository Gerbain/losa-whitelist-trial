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
