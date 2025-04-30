-- modules/command_handlers.lua
-- Dedicated command handler functions for Hivemind custom commands

local storage = require("modules.storage")
local logging = require("modules.logging")
local event_listener = require("modules.event_listener")

local handlers = {}

function handlers.get_events(cmd, event_id_to_name)
  local tick = tonumber(cmd.parameter) or 0
  local events = storage.get_items_after("attack_events", tick)
  local chat_messages = storage.get_items_after("chat_messages", tick)
  local counts = {}
  for _, bucket in pairs(events) do
    for _, event in ipairs(bucket) do
      local name = event.event_name
      if name then
        if event_id_to_name[name] then
          name = event_id_to_name[name]
        end
        counts[name] = (counts[name] or 0) + 1
      else
        counts["unknown"] = (counts["unknown"] or 0) + 1
      end
    end
  end
  if chat_messages and type(chat_messages) == "table" then
    local chat_count = 0
    for _, bucket in pairs(chat_messages) do
      chat_count = chat_count + #bucket
    end
    if chat_count > 0 then
      counts["on_console_chat"] = chat_count
    end
  end
  local lines = {"[Hivemind] Event summary after tick " .. tick .. ":"}
  local event_count = 0
  for event_name, count in pairs(counts) do
    table.insert(lines, "- " .. event_name .. ": " .. count)
    event_count = event_count + count
  end
  if event_count == 0 then
    lines = {"[Hivemind] No events stored after tick " .. tick .. "."}
  end
  local output = table.concat(lines, "\n")
  logging.info("/hm_get_events called by " .. (cmd.player_index and ("player " .. cmd.player_index) or "server") .. ", tick=" .. tick)
  logging.info("/hm_get_events summary returned: " .. output)
  if cmd.player_index then
    game.players[cmd.player_index].print(output)
  else
    game.print(output)
  end
end

function handlers.drop_events(cmd)
  storage.clear_table("attack_events")
  storage.clear_table("chat_messages")
  logging.info("/hm_drop_events called by " .. (cmd.player_index and ("player " .. cmd.player_index) or "server"))
  logging.info("All event data dropped via /hm_drop_events command")
  if cmd.player_index then
    game.players[cmd.player_index].print("All event data dropped.")
  else
    game.print("All event data dropped.")
  end
end

function handlers.list_listeners(cmd)
  local build_event_id_to_name = function()
    local t = {}
    for k, v in pairs(defines.events) do
      t[v] = k
    end
    return t
  end
  local event_id_to_name = build_event_id_to_name()
  local handlers_tbl = event_listener.handlers
  local lines = {"[Hivemind] Active registered listeners:"}
  for event_id, _ in pairs(handlers_tbl) do
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

function handlers.reload_listeners(cmd)
  event_listener.register()
  logging.info("/hm_reload_listeners called by " .. (cmd.player_index and ("player " .. cmd.player_index) or "server"))
  logging.info("[Hivemind] Event listeners reloaded via /hm_reload_listeners command.")
  if cmd.player_index then
    game.players[cmd.player_index].print("[Hivemind] Event listeners reloaded.")
  else
    game.print("[Hivemind] Event listeners reloaded.")
  end
end

return handlers
