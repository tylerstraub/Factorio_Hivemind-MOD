-- modules/commands.lua
-- Registers and implements custom commands for Hivemind

local storage = require("modules.storage")
local logging = require("modules.logging")
local event_listener = require("modules.event_listener")
local command_handlers = require("modules.command_handlers")
local commands_module = {}

local function is_admin(cmd)
  return not cmd.player_index or (game.players[cmd.player_index] and game.players[cmd.player_index].admin)
end

local function admin_wrapper(handler, command_name)
  return function(cmd)
    if cmd.player_index and not is_admin(cmd) then
      game.players[cmd.player_index].print("[Hivemind] Only server admins may run /" .. command_name .. ".")
      return
    end
    handler(cmd)
  end
end

local function register_command(name, desc, handler, admin_only)
  commands.remove_command(name)
  logging.info("Registering /" .. name .. " command")
  if admin_only then
    commands.add_command(name, desc, admin_wrapper(handler, name))
  else
    commands.add_command(name, desc, handler)
  end
end

-- Build a reverse lookup of event_id -> event_name
local function build_event_id_to_name()
  local t = {}
  for k, v in pairs(defines.events) do
    t[v] = k
  end
  return t
end

--- Register all custom commands
function commands_module.register()
  local event_id_to_name = build_event_id_to_name()
  local command_defs = {
    {
      name = "hm_get_events",
      desc = "Get a summary of all stored events after a tick (by type).",
      admin_only = true,
      handler = function(cmd)
        command_handlers.get_events(cmd, event_id_to_name)
      end
    },
    {
      name = "hm_drop_events",
      desc = "Delete all stored events (debug only)",
      admin_only = true,
      handler = command_handlers.drop_events
    },
    {
      name = "hm_list_listeners",
      desc = "List all active Hivemind event listeners (admin only)",
      admin_only = true,
      handler = command_handlers.list_listeners
    },
    {
      name = "hm_reload_listeners",
      desc = "Reload all Hivemind event listeners (admin only)",
      admin_only = true,
      handler = command_handlers.reload_listeners
    },
  }

  for _, def in ipairs(command_defs) do
    register_command(def.name, def.desc, def.handler, def.admin_only)
  end
end

return commands_module
