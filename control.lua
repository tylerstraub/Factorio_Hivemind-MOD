-- control.lua
-- Main entry point for Hivemind mod: orchestrates module initialization, registration, and lifecycle hooks.

local storage = require("modules.storage")
local event_listener = require("modules.event_listener")
local commands_module = require("modules.commands")
local logging = require("modules.logging")

--- Initialize all modules and register event handlers/commands
local function initialize()
  logging.info("Hivemind mod initializing (on_init/config change)")
  storage.init()
  event_listener.register()
  commands_module.register()
end

script.on_init(function()
  initialize()
end)

script.on_load(function()
  logging.info("Hivemind mod loading (on_load)")
  -- Only registration is needed on load; do not re-init storage
  event_listener.register()
  commands_module.register()
end)

script.on_configuration_changed(function()
  initialize()
end)