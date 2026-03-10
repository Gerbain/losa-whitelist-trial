Config = {}

-- Your Discord server invite link
Config.DiscordLink = "https://discord.gg/YOURCODE"

-- The Discord role ID required to play (right-click role in Discord → Copy ID)
Config.RequiredRoleId = "ROLE_ID_HERE"

-- Your Discord Bot Token (keep this secret, never share)
-- Create a bot at https://discord.com/developers/applications
Config.BotToken = "BOT_TOKEN_HERE"

-- Your Discord Guild/Server ID (right-click your server → Copy ID)
Config.GuildId = "GUILD_ID_HERE"

-- How often (in seconds) to re-check the player's Discord roles once the gate is active
Config.CheckInterval = 30

-- How long (in MINUTES) a player can freely play before the gate kicks in
-- Players WITH the role are never locked regardless of this timer
Config.TrialDuration = 30

-- Small delay (seconds) on first join before doing the initial silent role check
Config.InitialCheckDelay = 8

-- Webhook URL for logging (optional, leave empty to disable)
Config.LogWebhook = ""

-- Your server name (shown in the NUI overlay)
Config.ServerName = "YOUR SERVER NAME"

-- Messages shown in the NUI overlay
Config.NUIMessage    = "Your free trial has ended. Join our Discord to keep playing!"
Config.NUISubMessage = "Get the Member role and hit re-check — you'll be unlocked instantly."

-- Which events to log to the webhook (set to false to disable specific ones)
Config.Logs = {
    trial_started = true,   -- player spawns and trial begins
    trial_expired = true,   -- trial time runs out, gate shown
    verified      = true,   -- player has the role and is let in
    recheck       = true,   -- player clicks the re-check button
    no_discord    = true,   -- player has no Discord linked to FiveM
    not_in_guild  = true,   -- player not in your Discord server
    no_role       = true,   -- trial expired, player has no role
    disconnected  = false,  -- player leaves (can be spammy, off by default)
}
