-- modules/export.lua
local Export = {}

-- Configurable heartbeat interval (ticks between exports)
Export.INTERVAL = 600 -- 600 ticks = ~10 seconds

local Util = require("__my-export-mod__/modules/util")
local Chat = require("__my-export-mod__/modules/chat")

function Export.on_tick(event)
    local tick      = event.tick
    local game_time = Util.tick_to_time(tick)

    -- Prune stale chat entries before exporting
    Chat.prune(tick)

    -- Grab the main surface
    local surface = game.surfaces["nauvis"]

    -- Evolution factor of the alien force (defaults to “nauvis”)
    local evolution = game.forces["enemy"].get_evolution_factor(surface)

    -- Pollution at the origin chunk on nauvis
    local pollution = surface.get_pollution({ 0, 0 })

    -- Count of alien spawners on nauvis
    local spawner_count = surface.count_entities_filtered {
        type  = "unit-spawner",
        force = "enemy"
    }

    -- Count all player turrets by type: bullet, laser, flame, artillery
    local turret_count =
        surface.count_entities_filtered { type = "ammo-turret", force = "player" } +
        surface.count_entities_filtered { type = "electric-turret", force = "player" } +
        surface.count_entities_filtered { type = "fluid-turret", force = "player" } +
        surface.count_entities_filtered { type = "artillery-turret", force = "player" }

    -- Number of technologies the player has queued
    local research_queue_length = #game.forces["player"].research_queue

    -- Build trimmed chat array (omit raw tick)
    local chat_out = {}
    for _, msg in ipairs(storage.chat_messages or {}) do
        table.insert(chat_out, {
            game_time = msg.game_time,
            player    = msg.player,
            message   = msg.message
        })
    end

    -- Assemble export table
    local data        = {
        tick                  = tick,
        game_time             = game_time,
        evolution_factor      = evolution,
        pollution             = pollution,
        spawner_count         = spawner_count,
        turret_count          = turret_count,
        research_queue_length = research_queue_length,
        chat                  = chat_out
    }

    -- Serialize, pretty-print, and write out
    local json_min    = helpers.table_to_json(data)
    local json_pretty = Util.pretty_json(json_min)
    helpers.write_file("export.json", json_pretty, false)
end

return Export
