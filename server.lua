local verifiedPlayers = {}
local trialExpired    = {}
local playerSpawned   = {}
local trialStarted    = {}

-- -----------------------------------------------------------------------
-- Persistent player database (JSON file)
-- Schema per discord ID:
--   { trialUsed = true, trialStart = timestamp, expired = true/false }
-- -----------------------------------------------------------------------
local DB = {}
local DB_FILE = "losa_gate_players.json"

local function SaveDB()
    SaveResourceFile(GetCurrentResourceName(), DB_FILE, json.encode(DB), -1)
end

local function LoadDB()
    local raw = LoadResourceFile(GetCurrentResourceName(), DB_FILE)
    if raw and raw ~= "" then
        local ok, data = pcall(json.decode, raw)
        if ok and data then
            DB = data
            print(("[losa-gate] Loaded player database (%d records)"):format(#(function(t) local n=0 for _ in pairs(t) do n=n+1 end return n end)(DB)))
        else
            print("[losa-gate] Failed to parse player database, starting fresh.")
            DB = {}
        end
    else
        print("[losa-gate] No player database found, starting fresh.")
        DB = {}
    end
end

-- Load on resource start
LoadDB()

local function GetDiscordId(src)
    for _, v in ipairs(GetPlayerIdentifiers(src)) do
        if string.sub(v, 1, 8) == "discord:" then
            return string.sub(v, 9)
        end
    end
    return nil
end

-- Returns true if this discord ID has already used and expired their trial
local function HasTrialExpiredBefore(discordId)
    if not discordId then return false end
    local record = DB[discordId]
    return record and record.expired == true
end

local function RecordTrialStart(discordId, playerName)
    if not discordId then return end
    if not DB[discordId] then
        DB[discordId] = {
            name       = playerName,
            trialUsed  = true,
            expired    = false,
            trialStart = os.time(),
            firstSeen  = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }
    else
        -- Update name in case it changed
        DB[discordId].name = playerName
    end
    SaveDB()
end

local function RecordTrialExpired(discordId, playerName)
    if not discordId then return end
    if not DB[discordId] then DB[discordId] = {} end
    DB[discordId].expired   = true
    DB[discordId].expiredAt = os.date("!%Y-%m-%dT%H:%M:%SZ")
    DB[discordId].name      = playerName
    SaveDB()
end

local function RecordVerified(discordId, playerName)
    if not discordId then return end
    if not DB[discordId] then DB[discordId] = {} end
    DB[discordId].verified    = true
    DB[discordId].expired     = false  -- clear lock if they got the role
    DB[discordId].verifiedAt  = os.date("!%Y-%m-%dT%H:%M:%SZ")
    DB[discordId].name        = playerName
    SaveDB()
end

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
    local name    = playerName or "Unknown"
    local mention = discordId and ("<@%s>"):format(discordId) or "No Discord linked"

    local embeds = {
        trial_started = {
            title       = "🕐 Trial Started",
            description = ("**%s** (%s) joined and started their %d minute free trial."):format(name, mention, Config.TrialDuration),
            color       = 5793266
        },
        trial_expired = {
            title       = "⏰ Trial Expired",
            description = ("**%s** (%s) trial has ended. Gate is now active."):format(name, mention),
            color       = 16098851
        },
        trial_blocked = {
            title       = "🚫 Trial Already Used",
            description = ("**%s** (%s) rejoined but their trial has already expired. Gate active immediately."):format(name, mention),
            color       = 15158332
        },
        verified = {
            title       = "✅ Player Verified",
            description = ("**%s** (%s) has the required role and was let in."):format(name, mention),
            color       = 3066993
        },
        recheck = {
            title       = "🔄 Re-check Requested",
            description = ("**%s** (%s) clicked the re-check button."):format(name, mention),
            color       = 10181046
        },
        no_discord = {
            title       = "⚠️ No Discord Linked",
            description = ("**%s** has no Discord account linked to FiveM."):format(name),
            color       = 16776960
        },
        not_in_guild = {
            title       = "❌ Not in Discord Server",
            description = ("**%s** (%s) is not a member of the Discord server."):format(name, mention),
            color       = 15158332
        },
        no_role = {
            title       = "🔒 Gate Active — No Role",
            description = ("**%s** (%s) trial expired and does not have the required role."):format(name, mention),
            color       = 15158332
        },
        disconnected = {
            title       = "👋 Player Left",
            description = ("**%s** (%s) disconnected. Status: %s"):format(name, mention, extra or "unknown"),
            color       = 9807270
        }
    }

    if Config.Logs and Config.Logs[event] == false then return end
    local embed = embeds[event]
    if embed then
        embed.footer    = { text = "fivem-trial-gate" }
        embed.timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        SendLog(Config.LogWebhook, embed)
    end
end

-- -----------------------------------------------------------------------
-- Discord API role check
-- -----------------------------------------------------------------------
local function CheckDiscordRole(source, forceShow)
    if not GetPlayerName(source) then return end

    local discordId = GetDiscordId(source)
    local name      = GetPlayerName(source)

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
                local data    = json.decode(response)
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
                    RecordVerified(discordId, name)
                else
                    verifiedPlayers[source] = false
                    if (trialExpired[source] or forceShow) and playerSpawned[source] then
                        TriggerClientEvent('discord_gate:showUI', source, true, nil)
                        if trialExpired[source] and not verifiedPlayers[source .. "_logged"] then
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
                print(("[losa-gate] Discord API error %s for %s"):format(tostring(statusCode), name or "unknown"))
            end
        end,
        "GET", "",
        { ["Authorization"] = "Bot " .. Config.BotToken, ["Content-Type"] = "application/json" }
    )
end

-- -----------------------------------------------------------------------
-- Player spawned into world
-- -----------------------------------------------------------------------
RegisterNetEvent('discord_gate:playerReady', function()
    local src = source

    if not src or src == 0 or not GetPlayerName(src) then
        print("[losa-gate] playerReady fired with invalid source: " .. tostring(src))
        return
    end

    if trialStarted[src] then
        print("[losa-gate] playerReady re-fired for " .. GetPlayerName(src) .. " (ignored)")
        return
    end

    trialStarted[src]  = true
    playerSpawned[src] = true
    print("[losa-gate] playerReady accepted for " .. GetPlayerName(src) .. " (src: " .. src .. ")")

    CreateThread(function()
        Wait(Config.InitialCheckDelay * 1000)
        if not GetPlayerName(src) then return end

        local discordId = GetDiscordId(src)
        local name      = GetPlayerName(src)

        -- Check if this player has already burned their trial in a previous session
        if HasTrialExpiredBefore(discordId) then
            print(("[losa-gate] %s has already used their trial, locking immediately"):format(name))
            trialExpired[src] = true
            Log("trial_blocked", name, discordId)
            CheckDiscordRole(src, true)

            -- Still re-check periodically in case they got the role
            while GetPlayerName(src) do
                Wait(Config.CheckInterval * 1000)
                if not GetPlayerName(src) then break end
                if verifiedPlayers[src] ~= true then
                    CheckDiscordRole(src, true)
                else
                    break
                end
            end
            return
        end

        -- Fresh trial
        RecordTrialStart(discordId, name)
        Log("trial_started", name, discordId)
        CheckDiscordRole(src, false)

        -- Wait out the trial
        Wait(Config.TrialDuration * 60 * 1000)
        if not GetPlayerName(src) then return end

        trialExpired[src] = true

        if verifiedPlayers[src] ~= true then
            Log("trial_expired", name, discordId)
            RecordTrialExpired(discordId, name)
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
    local src       = source
    local name      = GetPlayerName(src)
    local discordId = GetDiscordId(src)
    Log("recheck", name, discordId)
    TriggerClientEvent('discord_gate:checking', src)
    Wait(2000)
    CheckDiscordRole(src, true)
end)

-- -----------------------------------------------------------------------
-- Disconnect
-- -----------------------------------------------------------------------
AddEventHandler('playerDropped', function()
    local src       = source
    local name      = GetPlayerName(src) or "Unknown"
    local discordId = GetDiscordId(src)

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

    verifiedPlayers[src]               = nil
    verifiedPlayers[src .. "_logged"]  = nil
    trialExpired[src]                  = nil
    playerSpawned[src]                 = nil
    trialStarted[src]                  = nil
end)

-- -----------------------------------------------------------------------
-- Staff sync
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

CreateThread(function()
    while true do
        Wait(10000)
        SyncTrialPlayers()
    end
end)

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
