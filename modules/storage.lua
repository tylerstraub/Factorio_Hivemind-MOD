-- modules/storage.lua
-- Persistent storage helpers for Factorio 2.0+

local logging = require("modules.logging")
local storage = {}

--- Initialize the storage module.
function storage.init()
  storage.attack_events = storage.attack_events or {}
end

--- Prune events older than (current_tick - retention_ticks)
function storage.prune_events(current_tick, retention_ticks)
  if not storage.attack_events then return end
  local cutoff = current_tick - retention_ticks
  local removed = 0
  for t in pairs(storage.attack_events) do
    if t < cutoff then
      storage.attack_events[t] = nil
      removed = removed + 1
    end
  end
  if removed > 0 then
    logging.info("Pruned " .. removed .. " attack event ticks older than tick " .. cutoff .. " (retention=" .. retention_ticks .. ")")
  end
end

--- Store group attack decision events (tick, group_id, surface, force, position, command, target, size, event_name)
function storage.store_event(tick, event)
  storage.attack_events = storage.attack_events or {}
  storage.attack_events[tick] = storage.attack_events[tick] or {}
  table.insert(storage.attack_events[tick], {
    tick = event.tick,
    group_id = event.group_id,
    surface = event.surface,
    force = event.force,
    position = event.position,
    command = event.command,
    target = event.target,
    size = event.size,
    event_name = event.event_name,
  })
end

--- Get events after the specified tick.
function storage.get_events_after(tick)
  local result = {}
  if not storage.attack_events then return result end
  for t, events in pairs(storage.attack_events) do
    if t > tick then
      result[t] = events
    end
  end
  return result
end

--- Clear all stored events.
function storage.clear_events()
  storage.attack_events = {}
end

return storage
