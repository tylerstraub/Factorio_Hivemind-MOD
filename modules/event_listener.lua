-- modules/event_listener.lua
-- Handles registration and processing of relevant game events for Hivemind

local storage = require("modules.storage")
local logging = require("modules.logging")
local event_listener = {}

--- List of attack-related events to listen for
event_listener.attack_events = {
  defines.events.on_unit_group_finished_gathering,
}

--- Register all relevant event handlers
function event_listener.register()
  for _, event_id in ipairs(event_listener.attack_events) do
    script.on_event(event_id, event_listener.on_attack_event)
  end
  logging.info("Registered enemy group attack decision event listener (on_unit_group_finished_gathering)")
end

--- Handler for enemy group attack decision events
function event_listener.on_attack_event(event)
  local group = event.group
  if group and group.valid and group.force and group.force.name == "enemy" then
    -- Prune old events before storing new one
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
end

return event_listener
