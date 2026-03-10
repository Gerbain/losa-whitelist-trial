# losa-whitelist-trial

> Give players a free trial on your FiveM server — lock them out after X minutes until they grab a role in your Discord.

Instead of a traditional whitelist, players can join and play freely for a configurable amount of time. Once the trial expires, they're shown an overlay prompting them to join your Discord and grab a role. The moment they do, they're unlocked instantly — no reconnect needed.

---

## Features

- ⏱️ **Configurable trial duration** — let players try your server before requiring Discord
- 🔒 **Auto-lock** — freezes the player and phases them through vehicles/players when trial expires
- 🎨 **Clean NUI overlay** — shows steps, a copyable Discord link, and a re-check button
- ✅ **Instant unlock** — no reconnect required, role is detected in real time
- 📋 **Discord webhook logging** — logs trial starts, expirations, verifications, and more
- 🔧 **Fully configurable** — trial time, messages, log toggles, all in one config file

---

## Requirements

- A FiveM server
- A Discord bot with the **Server Members Intent** enabled
- Players must have Discord linked in their FiveM account settings

---

## Installation

1. Download and drop the `losa-whitelist-trial` folder into your `resources/` directory
2. Add `ensure losa-whitelist-trial` to your `server.cfg`
3. Copy `config.example.lua` to `config.lua` and fill in your values (see below)
4. Restart your server

---

## Configuration

```lua
Config.DiscordLink    = "https://discord.gg/YOURCODE"   -- Your invite link
Config.RequiredRoleId = "ROLE_ID_HERE"                  -- Role ID needed to play
Config.BotToken       = "BOT_TOKEN_HERE"                -- Your Discord bot token
Config.GuildId        = "GUILD_ID_HERE"                 -- Your Discord server ID
Config.TrialDuration  = 30                              -- Free trial in minutes
Config.CheckInterval  = 30                              -- Re-check interval in seconds
Config.LogWebhook     = ""                              -- Discord webhook URL (optional)
Config.ServerName     = "YOUR SERVER NAME"              -- Shown in the NUI overlay
```

### Getting the required IDs

| Value | How to get it |
|---|---|
| `RequiredRoleId` | Discord → Server Settings → Roles → Right-click role → Copy ID |
| `GuildId` | Right-click your Discord server icon → Copy Server ID |
| `BotToken` | [Discord Developer Portal](https://discord.com/developers/applications) → Your App → Bot → Token |

### Bot setup

1. Go to the [Discord Developer Portal](https://discord.com/developers/applications)
2. Create a new application and add a Bot
3. Under **Privileged Gateway Intents**, enable **Server Members Intent**
4. Invite the bot to your server with the `bot` scope

---

## Webhook Logs

Set `Config.LogWebhook` to a Discord webhook URL to enable logging. Each event type can be toggled individually:

| Event | Description | Default |
|---|---|---|
| `trial_started` | Player spawns, trial begins | ✅ on |
| `trial_expired` | Trial time up, gate shown | ✅ on |
| `verified` | Player has role, let in | ✅ on |
| `recheck` | Player clicked re-check | ✅ on |
| `no_discord` | No Discord linked to FiveM | ✅ on |
| `not_in_guild` | Not in your Discord server | ✅ on |
| `no_role` | Trial expired, no role found | ✅ on |
| `disconnected` | Player left the server | ❌ off |

---

## How it works

1. Player joins and spawns into the world
2. A silent background role check runs — players who already have the role are never bothered
3. After `TrialDuration` minutes, if the player still doesn't have the role, the gate activates
4. The player is frozen in place, made invisible, and shown the NUI overlay
5. They join Discord, get the role, click **Re-check**
6. The role is verified and they're instantly unlocked

---

## License

MIT
