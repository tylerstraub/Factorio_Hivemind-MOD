-- modules/event.lua
local Event           = {}

-- Helper functions for startup settings
function Event.get_retention_ticks()
    local seconds = settings.global["hivemind_event_retention_seconds"] and settings.global["hivemind_event_retention_seconds"].value or 60
    return seconds * 60
end
function Event.get_max_groups()
    return settings.global["hivemind_event_max_groups"] and settings.global["hivemind_event_max_groups"].value or 5
end

local Util            = require("__Hivemind__/modules/util")

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
    elseif event_type == "player-building-destroyed" then
        return event_type .. "|" .. (event_data.building or "unknown") .. "|" .. (event_data.cause_force or "unknown")
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
    local cutoff = current_tick - Event.get_retention_ticks()
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
    while #group_list > Event.get_max_groups() do
        groups[group_list[1].key] = nil
        table.remove(group_list, 1)
    end
    storage.event_groups = groups
end

-- Handler for enemy-attack
function Event.on_enemy_attack(event)
    local group = event.group
    if group.force.name ~= "enemy" then return end
    local surface = group.surface
    local force = group.force
    local position = group.position

    -- Find nearest map tag (named location)
    local nearest_tag = Util.find_nearest_chart_tag(surface, force, position)
    local nearest_location = nil
    if nearest_tag then
        if type(nearest_tag.text) == "string" then
            nearest_location = nearest_tag.text
        elseif type(nearest_tag.text) == "table" and nearest_tag.text[1] then
            nearest_location = tostring(nearest_tag.text[1])
        end
    else
    end

    Event.record("enemy-attack", {
        force    = force.name,
        surface  = surface.name,
        position = position,
        size     = #group.members,
        nearest_location = nearest_location
    })
end

-- Handler for player building deaths by enemy
function Event.on_player_building_destroyed(event)
    local entity = event.entity
    -- Only interested in player buildings (not units, vehicles, etc.)
    if not (entity and entity.valid and entity.force and entity.force.name == "player" and entity.type ~= "unit" and entity.type ~= "player") then return end
    -- Only count if killed by enemy force
    local killer_force = (event.force and event.force.name) or ((event.cause and event.cause.force) and event.cause.force.name)
    if killer_force ~= "enemy" then return end
    Event.record("player-building-destroyed", {
        building    = entity.name,
        cause       = event.cause and event.cause.name or nil,
        cause_force = killer_force,
        position    = entity.position,
        surface     = entity.surface.name
    })
end

-- Handler for unit deaths
function Event.on_unit_died(event)
    local entity = event.entity
    if not (entity and entity.valid and entity.type == "unit") then return end
    local cause = event.cause
    local cause_name = cause and cause.name or nil
    local cause_force = (cause and cause.force) and cause.force.name or nil
    local cause_player = nil
    if cause then
        if cause.type == "player" and cause.player then
            local player_obj = game.get_player(cause.player.index)
            if player_obj and player_obj.valid then
                cause_player = player_obj.name
            end
        elseif cause.type == "character" then
            for _, player in pairs(game.connected_players) do
                if player.character == cause then
                    cause_player = player.name
                    break
                end
            end
        end
    end
    Event.record("unit-died", {
        unit        = entity.name,
        unit_force  = entity.force and entity.force.name or nil,
        cause       = cause_name,
        cause_force = cause_force,
        cause_player= cause_player,
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
    [defines.events.on_entity_died]                   = function(event)
        -- Route to the correct handler based on entity type/force
        if event.entity and event.entity.valid and event.entity.force and event.entity.force.name == "player" and event.entity.type ~= "unit" and event.entity.type ~= "player" then
            Event.on_player_building_destroyed(event)
        elseif event.entity and event.entity.valid and event.entity.type == "unit" then
            Event.on_unit_died(event)
        elseif event.entity and event.entity.valid and event.entity.type == "player" then
            Event.on_player_died(event)
        end
    end,
    [defines.events.on_player_died]                   = Event.on_player_died
}

return Event
