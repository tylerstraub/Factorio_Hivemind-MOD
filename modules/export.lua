-- modules/export.lua
local Export = {}

-- Configurable heartbeat interval
Export.INTERVAL = 600 -- ticks between exports (~10 seconds)

local Util = require("__my-export-mod__/modules/util")
local Chat = require("__my-export-mod__/modules/chat")

function Export.on_tick(event)
    -- first, prune any stale chat entries
    Chat.prune(event.tick)

    -- compute top-level elapsed time
    local game_time = Util.tick_to_time(event.tick)

    -- gather state
    local players, forces, surfaces = game.connected_players, game.forces, game.surfaces

    -- build player list
    local player_names = {}
    for _, p in pairs(players) do table.insert(player_names, p.name) end

    -- gather force research info
    local forces_info = {}
    for _, f in pairs(forces) do
        local q = f.research_queue or {}
        forces_info[f.name] = { current = q[1], queued = #q }
    end

    -- gather surface pollution
    local pollution = {}
    for sname, surf in pairs(surfaces) do
        pollution[sname] = surf.get_pollution({ 0, 0 })
    end

    -- build chat output (sans raw tick)
    local chat_out = {}
    for _, msg in ipairs(storage.chat_messages or {}) do
        table.insert(chat_out, {
            game_time = msg.game_time,
            player    = msg.player,
            message   = msg.message
        })
    end

    -- assemble full export
    local data        = {
        tick           = event.tick,
        game_time      = game_time,
        total_players  = #players,
        total_forces   = #forces,
        total_surfaces = #surfaces,
        player_names   = player_names,
        forces         = forces_info,
        pollution      = pollution,
        chat           = chat_out
    }

    -- serialize & write out
    local json_min    = helpers.table_to_json(data)
    local json_pretty = Util.pretty_json(json_min)
    helpers.write_file("export.json", json_pretty, false)
end

return Export
