-- modules/chat.lua
local Chat           = {}

function Chat.get_retention_ticks()
    local seconds = settings.global["hivemind_chat_retention_seconds"] and settings.global["hivemind_chat_retention_seconds"].value or 60
    return seconds * 60
end
function Chat.get_max_messages()
    return settings.global["hivemind_chat_max_messages"] and settings.global["hivemind_chat_max_messages"].value or 5
end

local Util           = require("__Hivemind__/modules/util")

function Chat.init()
    storage.chat_messages = {}
end

function Chat.on_chat(event)
    storage.chat_messages = storage.chat_messages or {}
    local msgs            = storage.chat_messages
    local player          = game.get_player(event.player_index)
    local name            = (player and player.name) or "Unknown"

    -- Build entry with raw tick (for pruning) + human time
    table.insert(msgs, {
        tick      = event.tick,
        game_time = Util.tick_to_time(event.tick),
        player    = name,
        message   = event.message
    })

    -- Prune immediately on new chat
    Chat.prune(event.tick)
end

function Chat.prune(current_tick)
    storage.chat_messages = storage.chat_messages or {}
    local msgs            = storage.chat_messages
    local cutoff          = current_tick - Chat.get_retention_ticks()
    local i               = 1

    -- Prune by age
    while i <= #msgs and msgs[i].tick < cutoff do
        table.remove(msgs, i)
    end

    -- Prune by count
    while #msgs > Chat.get_max_messages() do
        table.remove(msgs, 1)
    end

    storage.chat_messages = msgs
end

-- Event registration
Chat.events = {
    [defines.events.on_console_chat] = Chat.on_chat
}

return Chat
