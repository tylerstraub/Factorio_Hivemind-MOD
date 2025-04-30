-- control.lua
-- Main entry point for Hivemind mod: orchestrates module initialization, registration, and lifecycle hooks.

local storage = require("modules.storage")
local event_listener = require("modules.event_listener")
local commands_module = require("modules.commands")
local logging = require("modules.logging")
local remote_interface = require("modules.remote_interface")
remote_interface.register()  -- Ensure remote interface is registered at load time

--- Initialize all modules and register event handlers/commands
--  SAFE: Only call from server-only hooks (on_init, on_configuration_changed)
--  - Initializes persistent storage
--  - Registers state-mutating event handlers
--  - Registers commands
--  NEVER call from script.on_load (would desync multiplayer)
--  All registration must be deterministic: see modules/event_listener.lua and SAFETY.md
local function initialize()
  logging.info("Hivemind mod initializing (on_init/config change)")
  storage.init()
  event_listener.register()
  commands_module.register()
end

--  SAFE: Called ONCE, server-only, when a new save is created or mod is added
--  - Safe to initialize persistent state and register event handlers/commands
script.on_init(function()
  initialize()
end)

--  SAFE: Called on every peer (server and all clients) when the mod loads
--  - Only re-register event handlers and commands (NO persistent state mutation!)
--  - Mutating storage here will desync multiplayer
--  - Registration order for event handlers and commands MUST be deterministic across all peers.
script.on_load(function()
  logging.info("Hivemind mod loading (on_load)")
  event_listener.register()    -- Ensure event handlers are re-registered on all peers (deterministic order)
  commands_module.register()
end)

--  SAFE: Called on server when mods or versions change
--  - Safe to migrate/init persistent state and re-register event handlers/commands
script.on_configuration_changed(function()
  initialize()
end)