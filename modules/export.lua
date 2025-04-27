-- modules/export.lua
local Export = {}

-- Configurable heartbeat interval (ticks between exports)
Export.INTERVAL = 600 -- ~10 seconds

local Util = require("__my-export-mod__/modules/util")
local Chat = require("__my-export-mod__/modules/chat")

function Export.on_tick(event)
    local tick      = event.tick
    local game_time = Util.tick_to_time(tick)

    Chat.prune(tick)

    local surface = game.surfaces["nauvis"]

    -- Enemy metrics
    local evolution = game.forces["enemy"].get_evolution_factor(surface) --
    local pollution = surface.get_pollution({ 0, 0 })                    --

    -- Player turret counts
    local player_turrets = {
        bullet    = surface.count_entities_filtered { type = "ammo-turret", force = "player" },    --
        laser     = surface.count_entities_filtered { type = "electric-turret", force = "player" }, --
        flame     = surface.count_entities_filtered { type = "fluid-turret", force = "player" },   --
        artillery = surface.count_entities_filtered { type = "artillery-turret", force = "player" } --
    }
    player_turrets.total = player_turrets.bullet + player_turrets.laser + player_turrets.flame + player_turrets
    .artillery

    local player_research_queue = #game.forces["player"].research_queue --

    -- Enemy entity counts
    local enemy_counts = {
        spawners = surface.count_entities_filtered { type = "unit-spawner", force = "enemy" },

        worms = {
            small    = surface.count_entities_filtered { name = "small-worm-turret", force = "enemy" },
            medium   = surface.count_entities_filtered { name = "medium-worm-turret", force = "enemy" },
            big      = surface.count_entities_filtered { name = "big-worm-turret", force = "enemy" },
            behemoth = surface.count_entities_filtered { name = "behemoth-worm-turret", force = "enemy" }
        },

        biters = {
            small    = surface.count_entities_filtered { name = "small-biter", force = "enemy" },
            medium   = surface.count_entities_filtered { name = "medium-biter", force = "enemy" },
            big      = surface.count_entities_filtered { name = "big-biter", force = "enemy" },
            behemoth = surface.count_entities_filtered { name = "behemoth-biter", force = "enemy" }
        },

        spitters = {
            small    = surface.count_entities_filtered { name = "small-spitter", force = "enemy" },
            medium   = surface.count_entities_filtered { name = "medium-spitter", force = "enemy" },
            big      = surface.count_entities_filtered { name = "big-spitter", force = "enemy" },
            behemoth = surface.count_entities_filtered { name = "behemoth-spitter", force = "enemy" }
        }
    }

    -- Add totals inside each category
    local sum = 0
    for _, v in pairs(enemy_counts.worms) do sum = sum + v end
    enemy_counts.worms.total = sum
    sum = 0
    for _, v in pairs(enemy_counts.biters) do sum = sum + v end
    enemy_counts.biters.total = sum
    sum = 0
    for _, v in pairs(enemy_counts.spitters) do sum = sum + v end
    enemy_counts.spitters.total = sum

    -- Build chat history
    local chat_out = {}
    for _, msg in ipairs(storage.chat_messages or {}) do
        table.insert(chat_out, {
            game_time = msg.game_time,
            player    = msg.player,
            message   = msg.message
        })
    end --

    -- Player advancement indicators
    local force = game.forces["player"]
    local total_tech, researched = 0, 0
    for _, tech in pairs(force.technologies) do
        total_tech = total_tech + 1
        if tech.researched then researched = researched + 1 end                               --
    end
    local current_research    = force.current_research and force.current_research.name or nil --
    local research_progress   = force.research_progress                                       --
    local rockets_launched    = force.rockets_launched                                        --

    local satellites_launched = 0
    if prototypes.item["satellite"] then
        satellites_launched = force.get_item_launched("satellite") --
    end

    local kill_stats = force.get_kill_count_statistics(surface)                               --
    local kills      = 0
    for _, cnt in pairs(kill_stats.input_counts) do kills = kills + cnt end                   --

    local prod_stats     = force.get_item_production_statistics(surface)                      --
    local items_produced = 0
    for _, cnt in pairs(prod_stats.input_counts) do items_produced = items_produced + cnt end --

    local crafting_speed_mod = force.manual_crafting_speed_modifier                           --
    local lab_speed_mod      = force.laboratory_speed_modifier                                --

    -- Assemble final export
    local data               = {
        tick             = tick,
        game_time        = game_time,
        evolution_factor = evolution,
        pollution        = pollution,
        player           = {
            turrets     = player_turrets,
            advancement = {
                research_queue          = player_research_queue,
                researched_technologies = researched,
                total_technologies      = total_tech,
                current_research        = current_research,
                research_progress       = research_progress,
                rockets_launched        = rockets_launched,
                satellites_launched     = satellites_launched,
                kills                   = kills,
                items_produced          = items_produced,
                crafting_speed_mod      = crafting_speed_mod,
                lab_speed_mod           = lab_speed_mod
            }
        },
        enemy            = {
            spawners = enemy_counts.spawners,
            worms    = enemy_counts.worms,
            biters   = enemy_counts.biters,
            spitters = enemy_counts.spitters
        },
        chat             = chat_out
    }

    -- Serialize, pretty-print, and write out
    local json_min           = helpers.table_to_json(data)
    local json_pretty        = Util.pretty_json(json_min)
    helpers.write_file("export.json", json_pretty, false)
end

return Export
