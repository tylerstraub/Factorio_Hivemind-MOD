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
  local result = storage.get_items_after("attack_events", tick)
  local json = helpers.table_to_json(result)
  logging.info("[remote_interface] get_attack_events_after result: " .. json)
  if rcon then rcon.print(json) end
  return json
end

--- Clears all attack events (use with caution)
-- @return [string]: JSON status string
local function clear_attack_events()
  logging.info("[remote_interface] clear_attack_events called, clearing all events")
  storage.clear_table("attack_events")
  if rcon then rcon.print('{"status":"cleared"}') end
  return '{"status":"cleared"}'
end

--- Returns all chat messages after the given tick
-- @param tick [number]: Only messages after this tick are returned
-- @return [string]: JSON string of chat messages keyed by tick
local function get_chat_messages_after(tick)
  logging.info("[remote_interface] get_chat_messages_after called with tick=" .. tostring(tick))
  local result = storage.get_items_after("chat_messages", tick)
  local json = helpers.table_to_json(result)
  logging.info("[remote_interface] get_chat_messages_after result: " .. json)
  if rcon then rcon.print(json) end
  return json
end

--- Clears all chat messages (use with caution)
-- @return [string]: JSON status string
local function clear_chat_messages()
  logging.info("[remote_interface] clear_chat_messages called, clearing all chat messages")
  storage.clear_table("chat_messages")
  if rcon then rcon.print('{"status":"cleared"}') end
  return '{"status":"cleared"}'
end

--- Returns a snapshot of all storage tables after the given tick (extend as needed)
-- @param tick [number]: Only items after this tick are returned for each table (default 0)
-- @return [string]: JSON string of storage tables
local function get_storage_snapshot(tick)
  tick = tonumber(tick) or 0
  logging.info("[remote_interface] get_storage_snapshot called with tick=" .. tostring(tick))
  local snapshot = {
    attack_events = storage.get_items_after("attack_events", tick),
    chat_messages = storage.get_items_after("chat_messages", tick),
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
    get_chat_messages_after = get_chat_messages_after,
    clear_chat_messages = clear_chat_messages,
    -- Add more exported functions here as the mod grows
  })
  logging.info("[remote_interface] Registered 'hivemind' remote interface.")
end

return M
