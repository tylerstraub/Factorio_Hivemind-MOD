-- modules/event.lua
local Event           = {}

-- Configurable retention settings
Event.RETENTION_TICKS = 60 * 60 -- ~1 minute
Event.MAX_GROUPS      = 5 -- Now we limit by group, not individual event

local Util            = require("__my-export-mod__/modules/util")

function Event.init()
    storage.event_groups = {}
end

-- Helper: returns a grouping key for an event
local group_key = function(event_type, event_data)
    -- Group by type and cause (for deaths), or by type and surface/position (for attacks)
    if event_type == "unit-died" or event_type == "player-died" then
        return event_type .. "|" .. (event_data.player or event_data.unit or "unknown") .. "|" .. (event_data.cause or "unknown")
    elseif event_type == "enemy-attack" then
        return event_type .. "|" .. (event_data.surface or "unknown") .. "|" .. (event_data.position and (event_data.position.x .. "," .. event_data.position.y) or "unknown")
    else
        return event_type
    end
end

function Event.record(event_type, event_data)
    storage.event_groups = storage.event_groups or {}
    local groups = storage.event_groups
    local tick = game.tick
    local gkey = group_key(event_type, event_data)
    if not groups[gkey] then
        groups[gkey] = {
            type = event_type,
            key = gkey,
            first_tick = tick,
            last_tick = tick,
            events = {}
        }
    end
    local group = groups[gkey]
    group.last_tick = tick
    table.insert(group.events, {
        tick      = tick,
        game_time = Util.tick_to_time(tick),
        type      = event_type,
        data      = event_data
    })
end

function Event.prune(current_tick)
    storage.event_groups = storage.event_groups or {}
    local groups = storage.event_groups
    local cutoff = current_tick - Event.RETENTION_TICKS
    -- Remove groups by age ONLY
    for key, group in pairs(groups) do
        if group.last_tick < cutoff then
            groups[key] = nil
        end
    end
    -- Remove oldest groups if over limit
    local group_list = {}
    for key, group in pairs(groups) do
        table.insert(group_list, group)
    end
    table.sort(group_list, function(a, b) return a.first_tick < b.first_tick end)
    while #group_list > Event.MAX_GROUPS do
        groups[group_list[1].key] = nil
        table.remove(group_list, 1)
    end
    storage.event_groups = groups
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

-- Helper to get all groups
function Event.get_groups()
    storage.event_groups = storage.event_groups or {}
    local out = {}
    for _, group in pairs(storage.event_groups) do
        table.insert(out, group)
    end
    return out
end

-- Register events
Event.events = {
    [defines.events.on_unit_group_finished_gathering] = Event.on_enemy_attack,
    [defines.events.on_entity_died]                   = Event.on_unit_died,
    [defines.events.on_player_died]                   = Event.on_player_died
}

return Event
