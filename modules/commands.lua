-- modules/commands.lua
-- Registers and implements custom commands for Hivemind

local storage = require("modules.storage")
local logging = require("modules.logging")
local commands_module = {}

--- Register all custom commands
function commands_module.register()
  -- Remove commands before re-adding to prevent duplicate registration errors
  commands.remove_command("get_attack_events")
  commands.remove_command("drop_attack_events")

  logging.info("Registering /get_attack_events command")
  commands.add_command("get_attack_events", "Get attack events after a tick.", function(cmd)
    local tick = tonumber(cmd.parameter) or 0
    local events = storage.get_events_after(tick)
    -- Use the built-in helpers.table_to_json function for serialization (Factorio 2.0+)
    local json = helpers.table_to_json(events)
    logging.info("/get_attack_events called by " .. (cmd.player_index and ("player " .. cmd.player_index) or "server") .. ", tick=" .. tick)
    logging.info("/get_attack_events data returned: " .. json)
    if cmd.player_index then
      game.players[cmd.player_index].print(json)
    else
      game.print(json)
    end
  end)

  logging.info("Registering /drop_attack_events command")
  commands.add_command("drop_attack_events", "Delete all stored attack events (debug only)", function(cmd)
    storage.clear_events() -- Actually clear the attack_events table
    logging.info("All attack event data dropped via /drop_attack_events command")
    if cmd.player_index then
      game.players[cmd.player_index].print("All attack event data dropped.")
    else
      game.print("All attack event data dropped.")
    end
  end)
end

return commands_module
