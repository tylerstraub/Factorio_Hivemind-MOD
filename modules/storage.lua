-- modules/storage.lua
-- Persistent storage helpers for Factorio 2.0+

local logging = require("modules.logging")
local M = {}

--- Initialize the storage table on first-ever load
function M.init()
  storage.attack_events = storage.attack_events or {}
end

function M.prune_events(current_tick, retention_ticks)
  local tbl = storage.attack_events
  if not tbl then return end
  local cutoff, removed = current_tick - retention_ticks, 0
  for t in pairs(tbl) do
    if t < cutoff then
      tbl[t] = nil
      removed = removed + 1
    end
  end
  if removed > 0 then
    logging.info(
      "Pruned " .. removed
      .. " attack event ticks older than tick "
      .. cutoff .. " (retention=" .. retention_ticks .. ")"
    )
  end
end

function M.store_event(tick, event)
  storage.attack_events = storage.attack_events or {}
  local bucket = storage.attack_events[tick] or {}
  table.insert(bucket, {
    tick      = event.tick,
    group_id  = event.group_id,
    surface   = event.surface,
    force     = event.force,
    position  = event.position,
    command   = event.command,
    target    = event.target,
    size      = event.size,
    event_name= event.event_name,
  })
  storage.attack_events[tick] = bucket
end

function M.get_events_after(tick)
  local out = {}
  for t, events in pairs(storage.attack_events or {}) do
    if t > tick then out[t] = events end
  end
  return out
end

function M.clear_events()
  storage.attack_events = {}
end

return M
