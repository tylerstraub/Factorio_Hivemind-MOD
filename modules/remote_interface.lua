-- modules/remote_interface.lua
-- Centralized remote interface registration for Hivemind
-- Exposes storage and event data for RCON and inter-mod access

local storage = require("modules.storage")
local logging = require("modules.logging")

local M = {}

--- Returns all attack events after the given tick
-- @param tick [number]: Only events after this tick are returned
-- @return [string]: JSON string of attack events keyed by tick
local function get_attack_events_after(tick)
  logging.info("[remote_interface] get_attack_events_after called with tick=" .. tostring(tick))
  local result = storage.get_events_after(tick)
  local json = helpers.table_to_json(result)
  logging.info("[remote_interface] get_attack_events_after result: " .. json)
  if rcon then rcon.print(json) end
  return json
end

--- Clears all attack events (use with caution)
-- @return [string]: JSON status string
local function clear_attack_events()
  logging.info("[remote_interface] clear_attack_events called, clearing all events")
  storage.clear_events()
  if rcon then rcon.print('{"status":"cleared"}') end
  return '{"status":"cleared"}'
end

--- Returns a snapshot of all storage tables (extend as needed)
-- @return [string]: JSON string of storage tables
local function get_storage_snapshot()
  logging.info("[remote_interface] get_storage_snapshot called")
  local snapshot = {
    attack_events = storage.get_events_after(0),
    -- Add more storage tables here as needed
  }
  local json = helpers.table_to_json(snapshot)
  logging.info("[remote_interface] get_storage_snapshot result: " .. json)
  if rcon then rcon.print(json) end
  return json
end

--- Registers the remote interface for Hivemind
function M.register()
  remote.add_interface("hivemind", {
    get_attack_events_after = get_attack_events_after,
    clear_attack_events = clear_attack_events,
    get_storage_snapshot = get_storage_snapshot,
    -- Add more exported functions here as the mod grows
  })
  logging.info("[remote_interface] Registered 'hivemind' remote interface.")
end

return M
