-- modules/remote_interface.lua
-- Centralized remote interface registration for Hivemind
-- Exposes storage and event data for RCON and inter-mod access

local storage = require("modules.storage")
local logging = require("modules.logging")

local M = {}

-- List of storage tables to export via remote interface
local STORAGE_TABLES = {"attack_events", "chat_messages"}

-- Helper: DRY getter for events/messages after tick
local function get_items_after(table_name, tick)
  logging.info("[remote_interface] get_" .. table_name .. "_after called with tick=" .. tostring(tick))
  local result = storage.get_items_after(table_name, tick)
  local json = helpers.table_to_json(result)
  logging.info("[remote_interface] get_" .. table_name .. "_after result: " .. json)
  if rcon then rcon.print(json) end
  return json
end

-- Helper: DRY clearer for tables
local function clear_items(table_name)
  logging.info("[remote_interface] clear_" .. table_name .. " called, clearing all items")
  storage.clear_table(table_name)
  if rcon then rcon.print('{"status":"cleared"}') end
  return '{"status":"cleared"}'
end

-- Returns a snapshot of all storage tables after the given tick
local function get_storage_snapshot(tick)
  tick = tonumber(tick) or 0
  logging.info("[remote_interface] get_storage_snapshot called with tick=" .. tostring(tick))
  local snapshot = {}
  for _, table_name in ipairs(STORAGE_TABLES) do
    snapshot[table_name] = storage.get_items_after(table_name, tick)
  end
  local json = helpers.table_to_json(snapshot)
  logging.info("[remote_interface] get_storage_snapshot result: " .. json)
  if rcon then rcon.print(json) end
  return json
end

--- Registers the remote interface for Hivemind
function M.register()
  -- Build the interface table deterministically
  local interface = {
    get_storage_snapshot = get_storage_snapshot,
  }
  -- Add getter/clearer for each storage table (sorted order for multiplayer safety)
  table.sort(STORAGE_TABLES)
  for _, table_name in ipairs(STORAGE_TABLES) do
    interface["get_" .. table_name .. "_after"] = function(tick) return get_items_after(table_name, tick) end
    interface["clear_" .. table_name] = function() return clear_items(table_name) end
  end
  remote.add_interface("hivemind", interface)
  logging.info("[remote_interface] Registered 'hivemind' remote interface.")
end

return M
