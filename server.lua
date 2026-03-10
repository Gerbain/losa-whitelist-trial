local verifiedPlayers = {}
local trialExpired    = {}
local playerSpawned   = {}

-- -----------------------------------------------------------------------
-- Webhook logger
-- -----------------------------------------------------------------------
local function SendLog(webhook, embed)
    if not webhook or webhook == "" then return end
    PerformHttpRequest(webhook, function() end, "POST",
        json.encode({ embeds = { embed } }),
        { ["Content-Type"] = "application/json" }
    )
end

local function Log(event, playerName, discordId, extra)
    local name = playerName or "Unknown"
    local mention = discordId and ("<@%s>"):format(discordId) or "No Discord linked"

    local embeds = {
        trial_started = {
            title       = "🕐 Trial Started",
            description = ("**%s** (%s) joined and started their %d minute free trial."):format(name, mention, Config.TrialDuration),
            color       = 5793266  -- blue
        },
        trial_expired = {
            title       = "⏰ Trial Expired",
            description = ("**%s** (%s) trial has ended. Gate is now active."):format(name, mention),
            color       = 16098851  -- orange
        },
        verified = {
            title       = "✅ Player Verified",
            description = ("**%s** (%s) has the required role and was let in."):format(name, mention),
            color       = 3066993  -- green
        },
        recheck = {
            title       = "🔄 Re-check Requested",
            description = ("**%s** (%s) clicked the re-check button."):format(name, mention),
            color       = 10181046  -- purple
        },
        no_discord = {
            title       = "⚠️ No Discord Linked",
            description = ("**%s** has no Discord account linked to FiveM."):format(name),
            color       = 16776960  -- yellow
        },
        not_in_guild = {
            title       = "❌ Not in Discord Server",
            description = ("**%s** (%s) is not a member of the Discord server."):format(name, mention),
            color       = 15158332  -- red
        },
        no_role = {
            title       = "🔒 Gate Active — No Role",
            description = ("**%s** (%s) trial expired and does not have the required role."):format(name, mention),
            color       = 15158332  -- red
        },
        disconnected = {
            title       = "👋 Player Left",
            description = ("**%s** (%s) disconnected. Status: %s"):format(name, mention, extra or "unknown"),
            color       = 9807270  -- grey
        }
    }

    if Config.Logs and Config.Logs[event] == false then return end
    local embed = embeds[event]
    if embed then
        embed.footer     = { text = "fivem-trial-gate" }
        embed.timestamp  = os.date("!%Y-%m-%dT%H:%M:%SZ")
        SendLog(Config.LogWebhook, embed)
    end
end

-- -----------------------------------------------------------------------
-- Discord API role check
-- -----------------------------------------------------------------------
local function CheckDiscordRole(source, forceShow)
    if not GetPlayerName(source) then return end

    local identifiers = GetPlayerIdentifiers(source)
    local discordId   = nil

    for _, v in ipairs(identifiers) do
        if string.sub(v, 1, 8) == "discord:" then
            discordId = string.sub(v, 9)
            break
        end
    end

    local name = GetPlayerName(source)

    if not discordId then
        verifiedPlayers[source] = false
        Log("no_discord", name, nil)
        if (trialExpired[source] or forceShow) and playerSpawned[source] then
            TriggerClientEvent('discord_gate:showUI', source, false,
                "No Discord account linked to FiveM. Open FiveM Settings → Account and link your Discord.")
        end
        return
    end

    PerformHttpRequest(
        ("https://discord.com/api/v10/guilds/%s/members/%s"):format(Config.GuildId, discordId),
        function(statusCode, response, headers)
            if not GetPlayerName(source) then return end

            if statusCode == 200 then
                local data = json.decode(response)
                local hasRole = false

                if data and data.roles then
                    for _, roleId in ipairs(data.roles) do
                        if roleId == Config.RequiredRoleId then
                            hasRole = true
                            break
                        end
                    end
                end

                if hasRole then
                    verifiedPlayers[source] = true
                    TriggerClientEvent('discord_gate:hideUI', source)
                    Log("verified", name, discordId)
                else
                    verifiedPlayers[source] = false
                    if (trialExpired[source] or forceShow) and playerSpawned[source] then
                        TriggerClientEvent('discord_gate:showUI', source, true, nil)
                        -- Only log "no role" once when trial first expires, not every re-check
                        if forceShow and not trialExpired[source] then
                            Log("no_role", name, discordId)
                        elseif trialExpired[source] and not verifiedPlayers[source .. "_logged"] then
                            verifiedPlayers[source .. "_logged"] = true
                            Log("no_role", name, discordId)
                        end
                    end
                end

            elseif statusCode == 404 then
                verifiedPlayers[source] = false
                Log("not_in_guild", name, discordId)
                if (trialExpired[source] or forceShow) and playerSpawned[source] then
                    TriggerClientEvent('discord_gate:showUI', source, false,
                        "You're not in our Discord server yet.")
                end
            else
                print(("[discord_gate] Discord API error %s for %s"):format(
                    tostring(statusCode), name or "unknown"))
            end
        end,
        "GET", "",
        {
            ["Authorization"] = "Bot " .. Config.BotToken,
            ["Content-Type"]  = "application/json"
        }
    )
end

-- -----------------------------------------------------------------------
-- Player spawned into world
-- -----------------------------------------------------------------------
RegisterNetEvent('discord_gate:playerReady', function()
    local src = source
    playerSpawned[src] = true

    CreateThread(function()
        -- Small delay then silent check + log trial started
        Wait(Config.InitialCheckDelay * 1000)
        if not GetPlayerName(src) then return end

        -- Get discord ID for the log
        local discordId = nil
        for _, v in ipairs(GetPlayerIdentifiers(src)) do
            if string.sub(v, 1, 8) == "discord:" then
                discordId = string.sub(v, 9)
                break
            end
        end

        Log("trial_started", GetPlayerName(src), discordId)
        CheckDiscordRole(src, false)

        -- Wait out the trial
        Wait(Config.TrialDuration * 60 * 1000)
        if not GetPlayerName(src) then return end

        trialExpired[src] = true

        if verifiedPlayers[src] ~= true then
            Log("trial_expired", GetPlayerName(src), discordId)
            CheckDiscordRole(src, true)
        end

        while GetPlayerName(src) do
            Wait(Config.CheckInterval * 1000)
            if not GetPlayerName(src) then break end

            if verifiedPlayers[src] ~= true then
                CheckDiscordRole(src, true)
            else
                break
            end
        end
    end)
end)

-- -----------------------------------------------------------------------
-- Manual recheck
-- -----------------------------------------------------------------------
RegisterNetEvent('discord_gate:recheck', function()
    local src = source
    local name = GetPlayerName(src)
    local discordId = nil
    for _, v in ipairs(GetPlayerIdentifiers(src)) do
        if string.sub(v, 1, 8) == "discord:" then
            discordId = string.sub(v, 9)
            break
        end
    end

    Log("recheck", name, discordId)
    TriggerClientEvent('discord_gate:checking', src)
    Wait(2000)
    CheckDiscordRole(src, true)
end)

-- -----------------------------------------------------------------------
-- Disconnect
-- -----------------------------------------------------------------------
AddEventHandler('playerDropped', function()
    local src = source
    local name = GetPlayerName(src) or "Unknown"
    local discordId = nil
    for _, v in ipairs(GetPlayerIdentifiers(src)) do
        if string.sub(v, 1, 8) == "discord:" then
            discordId = string.sub(v, 9)
            break
        end
    end

    local status = "never spawned"
    if playerSpawned[src] then
        if verifiedPlayers[src] == true then
            status = "verified member"
        elseif trialExpired[src] then
            status = "trial expired / locked"
        else
            status = "left during trial"
        end
    end

    Log("disconnected", name, discordId, status)

    verifiedPlayers[src] = nil
    verifiedPlayers[src .. "_logged"] = nil
    trialExpired[src]    = nil
    playerSpawned[src]   = nil
end)

-- -----------------------------------------------------------------------
-- Staff sync — sends trial player ped IDs to admins only
-- -----------------------------------------------------------------------
local function SyncTrialPlayers()
    local trialList = {}
    for _, playerId in ipairs(GetPlayers()) do
        local src = tonumber(playerId)
        if playerSpawned[src] and verifiedPlayers[src] ~= true then
            table.insert(trialList, src)
        end
    end

    for _, playerId in ipairs(GetPlayers()) do
        local src = tonumber(playerId)
        if IsPlayerAceAllowed(src, "discord_gate.staff") then
            TriggerClientEvent('discord_gate:trialPlayers', src, trialList)
        end
    end
end

-- Re-sync every 10 seconds to catch changes
CreateThread(function()
    while true do
        Wait(10000)
        SyncTrialPlayers()
    end
end)

-- Also sync immediately when a player's status changes
RegisterNetEvent('discord_gate:requestSync', function()
    local src = source
    if IsPlayerAceAllowed(src, "discord_gate.staff") then
        local trialList = {}
        for _, playerId in ipairs(GetPlayers()) do
            local id = tonumber(playerId)
            if playerSpawned[id] and verifiedPlayers[id] ~= true then
                table.insert(trialList, id)
            end
        end
        TriggerClientEvent('discord_gate:trialPlayers', src, trialList)
    end
end)
