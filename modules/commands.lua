-- modules/commands.lua
-- Registers and implements custom commands for Hivemind

local storage = require("modules.storage")
local logging = require("modules.logging")
local event_listener = require("modules.event_listener")
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
      desc = "Get attack events after a tick.",
      admin_only = true,
      handler = function(cmd)
        local tick = tonumber(cmd.parameter) or 0
        local events = storage.get_events_after(tick)
        local json = helpers.table_to_json(events)
        logging.info("/hm_get_events called by " .. (cmd.player_index and ("player " .. cmd.player_index) or "server") .. ", tick=" .. tick)
        logging.info("/hm_get_events data returned: " .. json)
        if cmd.player_index then
          game.players[cmd.player_index].print(json)
        else
          game.print(json)
        end
      end
    },
    {
      name = "hm_drop_events",
      desc = "Delete all stored attack events (debug only)",
      admin_only = true,
      handler = function(cmd)
        storage.clear_events()
        logging.info("/hm_drop_events called by " .. (cmd.player_index and ("player " .. cmd.player_index) or "server"))
        logging.info("All attack event data dropped via /hm_drop_events command")
        if cmd.player_index then
          game.players[cmd.player_index].print("All attack event data dropped.")
        else
          game.print("All attack event data dropped.")
        end
      end
    },
    {
      name = "hm_reload_listeners",
      desc = "Reload all Hivemind event listeners (admin only)",
      admin_only = true,
      handler = function(cmd)
        event_listener.register()
        logging.info("/hm_reload_listeners called by " .. (cmd.player_index and ("player " .. cmd.player_index) or "server"))
        logging.info("[Hivemind] Event listeners reloaded via /hm_reload_listeners command.")
        if cmd.player_index then
          game.players[cmd.player_index].print("[Hivemind] Event listeners reloaded.")
        else
          game.print("[Hivemind] Event listeners reloaded.")
        end
      end
    },
    {
      name = "hm_list_listeners",
      desc = "List all active Hivemind event listeners (admin only)",
      admin_only = true,
      handler = function(cmd)
        local handlers = event_listener.handlers
        local lines = {"[Hivemind] Active registered listeners:"}
        for event_id, _ in pairs(handlers) do
          local event_name = event_id_to_name[event_id] or "(unknown)"
          table.insert(lines, "- " .. event_name .. " (ID: " .. tostring(event_id) .. ")")
        end
        local msg = table.concat(lines, "\n")
        logging.info("/hm_list_listeners called by " .. (cmd.player_index and ("player " .. cmd.player_index) or "server"))
        logging.info("[Hivemind] Listeners reported: " .. msg)
        if cmd.player_index then
          game.players[cmd.player_index].print(msg)
        else
          game.print(msg)
        end
      end
    },
  }

  for _, def in ipairs(command_defs) do
    register_command(def.name, def.desc, def.handler, def.admin_only)
  end
end

return commands_module
