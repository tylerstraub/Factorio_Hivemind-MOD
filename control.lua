-- control.lua

local MOD_NAME = "__my-export-mod__"
local Chat     = require(MOD_NAME .. "/modules/chat")
local Event    = require(MOD_NAME .. "/modules/event")
local Export   = require(MOD_NAME .. "/modules/export")

-- Safely initialize modules that expose an init() function
local function safe_init(mod)
    if mod and type(mod.init) == "function" then
        mod.init()
    end
end

-- Register all handlers in one place
local function register_handlers()
    -- Chat messages
    script.on_event(defines.events.on_console_chat, Chat.on_chat)

    -- Export tick
    script.on_nth_tick(Export.INTERVAL, Export.on_tick)

    -- All other events from Event.events table
    for event_id, handler in pairs(Event.events or {}) do
        script.on_event(event_id, handler)
    end
end

-- On mod init (new game or first load)
script.on_init(function()
    safe_init(Chat)
    safe_init(Event)
    register_handlers()
end)

-- When loading a saved game or after mod configuration changes,
-- re-register handlers (script.on_event handlers aren’t persisted)
script.on_configuration_changed(function()
    safe_init(Chat)
    safe_init(Event)
    register_handlers()
end)

script.on_load(function()
    register_handlers()
end)
