-- modules/event.lua
local Event           = {}

-- Configurable retention settings
Event.RETENTION_TICKS = 60 * 60 -- ~1 minute
Event.MAX_EVENTS      = 5

local Util            = require("__my-export-mod__/modules/util")

function Event.init()
    storage.events = {}
end

function Event.record(event_type, event_data)
    storage.events = storage.events or {}
    local events = storage.events
    table.insert(events, {
        tick      = game.tick,
        game_time = Util.tick_to_time(game.tick),
        type      = event_type,
        data      = event_data
    })
    Event.prune(game.tick)
end

function Event.prune(current_tick)
    storage.events = storage.events or {}
    local events = storage.events
    local cutoff = current_tick - Event.RETENTION_TICKS
    local i = 1
    while i <= #events and events[i].tick < cutoff do
        table.remove(events, i)
    end
    while #events > Event.MAX_EVENTS do
        table.remove(events, 1)
    end
    storage.events = events
end

-- Handler for enemy-attack
function Event.on_enemy_attack(event)
    local group = event.group
    if group.force.name ~= "enemy" then return end
    Event.record("enemy-attack", {
        force    = group.force.name,
        surface  = group.surface.name,
        position = group.position,
        size     = #group.members
    })
end

-- Handler for unit deaths
function Event.on_unit_died(event)
    local entity = event.entity
    if not (entity and entity.valid and entity.type == "unit") then return end
    local cause = event.cause
    Event.record("unit-died", {
        unit        = entity.name,
        unit_force  = entity.force and entity.force.name or nil,
        cause       = cause and cause.name or nil,
        cause_force = (cause and cause.force) and cause.force.name or nil,
        position    = entity.position,
        surface     = entity.surface.name
    })
end

-- Handler for player deaths
function Event.on_player_died(event)
    local player = game.get_player(event.player_index)
    if not (player and player.valid) then return end
    local cause = event.cause
    Event.record("player-died", {
        player      = player.name,
        cause       = cause and cause.name or nil,
        cause_force = (cause and cause.force) and cause.force.name or nil,
        surface     = player.surface and player.surface.name or nil
    })
end

-- Register events
Event.events = {
    [defines.events.on_unit_group_finished_gathering] = Event.on_enemy_attack,
    [defines.events.on_entity_died]                   = Event.on_unit_died,
    [defines.events.on_player_died]                   = Event.on_player_died
}

return Event
