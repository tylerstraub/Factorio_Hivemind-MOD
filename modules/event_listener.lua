-- modules/event_listener.lua
-- Handles registration and processing of relevant game events for Hivemind

local storage = require("modules.storage")
local logging = require("modules.logging")
local event_listener = {}

-- Central registry for all event types and their handlers
-- IMPORTANT: Registration order must be deterministic for multiplayer safety.
-- Always use arrays + ipairs, or sort keys before iterating with pairs.
-- Example: [defines.events.on_built_entity] = event_listener.on_built_event,
event_listener.handlers = {
  [defines.events.on_unit_group_finished_gathering] = function(event)
    local group = event.group
    if group and group.valid and group.force and group.force.name == "enemy" then
      local retention = settings.global["hivemind_attack_event_retention_ticks"] and settings.global["hivemind_attack_event_retention_ticks"].value or 36000
      storage.prune_events(event.tick, retention)
      local cmd = group.command
      local cmd_type = cmd and cmd.type
      local target_pos = cmd and cmd.destination
      local data = {
        tick = event.tick,
        group_id = group.unique_id,
        surface = group.surface and group.surface.name,
        force = group.force and group.force.name,
        position = group.position,
        command = cmd_type,
        target = target_pos,
        size = #group.members,
        event_name = event.name,
      }
      storage.store_event(event.tick, data)
      logging.info("Enemy group attack decision: tick=" .. event.tick .. ", group=" .. tostring(group.unique_id) .. ", command=" .. tostring(cmd_type) .. ", target=" .. (target_pos and ("{"..target_pos.x..","..target_pos.y.."}") or "nil") .. ", size=" .. tostring(data.size))
    end
  end,
  [defines.events.on_console_chat] = function(event)
    local player = nil
    if event.player_index then
      local p = game.get_player(event.player_index)
      if p then player = p.name end
    end
    local retention = settings.global["hivemind_chat_message_retention_ticks"] and settings.global["hivemind_chat_message_retention_ticks"].value or 36000
    storage.prune_chat_messages(event.tick, retention)
    local chat = {
      tick = event.tick,
      player = player,
      player_index = event.player_index,
      message = event.message,
      event_name = event.name,
    }
    storage.store_chat_message(event.tick, chat)
    logging.info("Chat message captured: tick=" .. tostring(event.tick) .. ", player=" .. tostring(player) .. ", message=" .. tostring(event.message))
  end,
}

--- Register all relevant event handlers (modular)
function event_listener.register()
  -- Register handlers in deterministic (sorted) order for multiplayer safety
  -- DO NOT use pairs() directly for registration; always sort keys first.
  local event_ids = {}
  for event_id in pairs(event_listener.handlers) do
    table.insert(event_ids, event_id)
  end
  table.sort(event_ids)
  for _, event_id in ipairs(event_ids) do
    script.on_event(event_id, event_listener.handlers[event_id])
  end
  logging.info("All event listeners registered.")
end

return event_listener
