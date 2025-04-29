-- modules/storage.lua
-- Persistent storage helpers for Factorio 2.0+

local logging = require("modules.logging")
local storage = {}

-- Helper to reference the Factorio persistent storage table
local function get_storage()
  -- In Factorio 2.0+, 'storage' is the persistent table
  _G.storage = _G.storage or {}
  return _G.storage
end

--- Initialize the storage module.
function storage.init()
  local s = get_storage()
  s.attack_events = s.attack_events or {}
end

--- Prune events older than (current_tick - retention_ticks)
function storage.prune_events(current_tick, retention_ticks)
  local s = get_storage()
  if not s.attack_events then return end
  local cutoff = current_tick - retention_ticks
  local removed = 0
  for t in pairs(s.attack_events) do
    if t < cutoff then
      s.attack_events[t] = nil
      removed = removed + 1
    end
  end
  if removed > 0 then
    logging.info("Pruned " .. removed .. " attack event ticks older than tick " .. cutoff .. " (retention=" .. retention_ticks .. ")")
  end
end

--- Store group attack decision events (tick, group_id, surface, force, position, command, target, size, event_name)
function storage.store_event(tick, event)
  local s = get_storage()
  s.attack_events = s.attack_events or {}
  s.attack_events[tick] = s.attack_events[tick] or {}
  table.insert(s.attack_events[tick], {
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
  local s = get_storage()
  local result = {}
  if not s.attack_events then return result end
  for t, events in pairs(s.attack_events) do
    if t > tick then
      result[t] = events
    end
  end
  return result
end

--- Clear all stored events.
function storage.clear_events()
  local s = get_storage()
  s.attack_events = {}
end

return storage
