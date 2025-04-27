-- modules/chat.lua
local Chat           = {}

-- Configurable retention settings
Chat.RETENTION_TICKS = 1 * 60 * 60 -- ~1 minute
Chat.MAX_MESSAGES    = 5

local Util           = require("__my-export-mod__/modules/util")

function Chat.init()
    storage.chat_messages = {}
end

function Chat.on_chat(event)
    storage.chat_messages = storage.chat_messages or {}
    local msgs            = storage.chat_messages
    local player          = game.get_player(event.player_index)
    local name            = (player and player.name) or "Unknown"

    -- build entry with raw tick (for pruning) + human time
    table.insert(msgs, {
        tick      = event.tick,
        game_time = Util.tick_to_time(event.tick),
        player    = name,
        message   = event.message
    })

    -- prune immediately on new chat
    Chat.prune(event.tick)
end

function Chat.prune(current_tick)
    storage.chat_messages = storage.chat_messages or {}
    local msgs            = storage.chat_messages
    local cutoff          = current_tick - Chat.RETENTION_TICKS
    local i               = 1

    -- prune by age
    while i <= #msgs and msgs[i].tick < cutoff do
        table.remove(msgs, i)
    end

    -- prune by count
    while #msgs > Chat.MAX_MESSAGES do
        table.remove(msgs, 1)
    end

    storage.chat_messages = msgs
end

return Chat
