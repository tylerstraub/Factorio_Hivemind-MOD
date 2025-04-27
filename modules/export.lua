-- modules/export.lua
local Export    = {}

-- Configurable heartbeat interval (ticks between exports)
Export.INTERVAL = 600 -- ~10 seconds

local Util      = require("__my-export-mod__/modules/util")
local Chat      = require("__my-export-mod__/modules/chat")
local Event     = require("__my-export-mod__/modules/event")

-- Summarize unit-died / player-died and collect enemy-attack events
local function summarize_events(raw_events)
    local losses = { player = {}, enemy = {} }
    local attacks = {}

    for _, ev in ipairs(raw_events) do
        if ev.type == "unit-died" or ev.type == "player-died" then
            local is_player = (ev.type == "player-died")
            local bucket    = is_player and losses.player or losses.enemy
            local key       = (is_player and ev.data.player or ev.data.unit)
                .. "|" .. (ev.data.cause or "unknown")
            if not bucket[key] then
                bucket[key] = {
                    type       = ev.type,
                    unit       = ev.data.unit,
                    player     = ev.data.player,
                    cause      = ev.data.cause,
                    count      = 0,
                    first_time = ev.game_time,
                    last_time  = ev.game_time
                }
            end
            local entry     = bucket[key]
            entry.count     = entry.count + 1
            entry.last_time = ev.game_time
        elseif ev.type == "enemy-attack" then
            -- keep each attack wave entry
            table.insert(attacks, {
                type       = ev.type,
                surface    = ev.data.surface,
                position   = ev.data.position,
                size       = ev.data.size,
                first_time = ev.game_time
            })
        end
    end

    -- flatten into arrays
    local out = {
        player_losses = {},
        enemy_losses  = {},
        enemy_attacks = attacks
    }
    for _, v in pairs(losses.player) do table.insert(out.player_losses, v) end
    for _, v in pairs(losses.enemy) do table.insert(out.enemy_losses, v) end

    return out
end

function Export.on_tick(event)
    local tick      = event.tick
    local game_time = Util.tick_to_time(tick)

    -- prune old events
    Event.prune(tick)

    local surface               = game.surfaces["nauvis"]
    local evolution             = game.forces["enemy"].get_evolution_factor(surface)
    local pollution             = surface.get_pollution({ 0, 0 })

    -- Player turret counts
    local player_turrets        = {
        bullet    = surface.count_entities_filtered { type = "ammo-turret", force = "player" },
        laser     = surface.count_entities_filtered { type = "electric-turret", force = "player" },
        flame     = surface.count_entities_filtered { type = "fluid-turret", force = "player" },
        artillery = surface.count_entities_filtered { type = "artillery-turret", force = "player" }
    }
    player_turrets.total        = player_turrets.bullet
        + player_turrets.laser
        + player_turrets.flame
        + player_turrets.artillery

    local player_research_queue = #game.forces["player"].research_queue

    -- Enemy entity counts
    local enemy_counts          = {
        spawners = surface.count_entities_filtered { type = "unit-spawner", force = "enemy" },
        worms    = {
            small    = surface.count_entities_filtered { name = "small-worm-turret", force = "enemy" },
            medium   = surface.count_entities_filtered { name = "medium-worm-turret", force = "enemy" },
            big      = surface.count_entities_filtered { name = "big-worm-turret", force = "enemy" },
            behemoth = surface.count_entities_filtered { name = "behemoth-worm-turret", force = "enemy" }
        },
        biters   = {
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
    local function sum(t)
        local s = 0
        for _, v in pairs(t) do s = s + v end
        return s
    end
    enemy_counts.worms.total    = sum(enemy_counts.worms)
    enemy_counts.biters.total   = sum(enemy_counts.biters)
    enemy_counts.spitters.total = sum(enemy_counts.spitters)

    -- Summarize & clear events
    local raw_events            = storage.events or {}
    local event_summary         = summarize_events(raw_events)
    storage.events              = {}

    -- Chat output
    local chat_out              = {}
    for _, msg in ipairs(storage.chat_messages or {}) do
        table.insert(chat_out, {
            game_time = msg.game_time,
            player    = msg.player,
            message   = msg.message
        })
    end

    -- Player advancement
    local force = game.forces["player"]
    local total_tech, researched = 0, 0
    for _, tech in pairs(force.technologies) do
        total_tech = total_tech + 1
        if tech.researched then researched = researched + 1 end
    end
    local advancement = {
        research_queue          = player_research_queue,
        researched_technologies = researched,
        total_technologies      = total_tech,
        current_research        = force.current_research and force.current_research.name or nil,
        research_progress       = force.research_progress,
        rockets_launched        = force.rockets_launched,
        satellites_launched     = (prototypes.item["satellite"] and force.get_item_launched("satellite")) or 0,
        kills                   = (function()
            local ks, sum = force.get_kill_count_statistics(surface), 0
            for _, c in pairs(ks.input_counts) do sum = sum + c end
            return sum
        end)(),
        items_produced          = (function()
            local ps, sum = force.get_item_production_statistics(surface), 0
            for _, c in pairs(ps.input_counts) do sum = sum + c end
            return sum
        end)(),
        crafting_speed_mod      = force.manual_crafting_speed_modifier,
        lab_speed_mod           = force.laboratory_speed_modifier
    }

    -- Final export
    local data        = {
        tick             = tick,
        game_time        = game_time,
        evolution_factor = evolution,
        pollution        = pollution,
        player           = {
            turrets     = player_turrets,
            advancement = advancement
        },
        enemy            = enemy_counts,
        event_summary    = event_summary,
        chat             = chat_out
    }

    -- Serialize, pretty-print, and write out
    local json_min    = helpers.table_to_json(data)
    local json_pretty = Util.pretty_json(json_min)
    helpers.write_file("export.json", json_pretty, false)
end

return Export
