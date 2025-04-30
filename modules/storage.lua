-- modules/storage.lua
-- Persistent storage helpers for Factorio 2.0+

local logging = require("modules.logging")
local M = {}

--- Initialize the storage table on first-ever load
function M.init()
  storage.attack_events = storage.attack_events or {}
  storage.chat_messages = storage.chat_messages or {}
end

-- === Generalized Helpers ===
local function prune_table(table_name, current_tick, retention_ticks, log_label)
  local tbl = storage[table_name]
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
      .. " " .. log_label .. " ticks older than tick "
      .. cutoff .. " (retention=" .. retention_ticks .. ")"
    )
  end
end

local function store_item(table_name, tick, item)
  storage[table_name] = storage[table_name] or {}
  local bucket = storage[table_name][tick] or {}
  table.insert(bucket, item)
  storage[table_name][tick] = bucket
end

local function get_items_after(table_name, tick)
  local out = {}
  for t, items in pairs(storage[table_name] or {}) do
    if t > tick then out[t] = items end
  end
  return out
end

local function clear_table(table_name)
  storage[table_name] = {}
end

-- Export only the generic helpers and init
M.prune_table = prune_table
M.store_item = store_item
M.get_items_after = get_items_after
M.clear_table = clear_table

return M
