-- control.lua
log("[Hivemind] control.lua loaded")

---@class HivemindStorage
---@field last_export_interval integer?
local MOD_NAME = "__Hivemind__"
local Chat     = require(MOD_NAME .. "/modules/chat")
local Event    = require(MOD_NAME .. "/modules/event")
local Export   = require(MOD_NAME .. "/modules/export")

-- Use a storage table for linter cleanness
local function get_storage()
    global = global or {}
    return global
end
local storage = get_storage()

-- Safely initialize modules that expose an init() function
local function safe_init(mod)
    if mod and type(mod.init) == "function" then
        mod.init()
    end
end

-- Register all handlers in one place
local function register_handlers()
    local storage = get_storage()
    -- Chat messages
    script.on_event(defines.events.on_console_chat, Chat.on_chat)

    -- Export tick (register after settings are available)
    register_nth_tick_handler()

    -- All other events from Event.events table
    for event_id, handler in pairs(Event.events or {}) do
        script.on_event(event_id, handler)
    end
end

-- Register only event handlers (no global or storage access, and NO nth-tick handler)
local function register_event_handlers_only()
    -- Chat messages
    script.on_event(defines.events.on_console_chat, Chat.on_chat)
    -- All other events from Event.events table
    for event_id, handler in pairs(Event.events or {}) do
        script.on_event(event_id, handler)
    end
end

-- Register nth-tick handler for export interval
function register_nth_tick_handler()
    log("[Hivemind] register_nth_tick_handler() called")
    local storage = get_storage()
    -- Unregister previous handler if exists
    if storage.last_export_interval then
        log("[Hivemind] Unregistering previous handler at " .. tostring(storage.last_export_interval))
        script.on_nth_tick(storage.last_export_interval, nil)
    end
    local interval = Export.get_interval()
    log("[Hivemind] Calculated interval: " .. tostring(interval))
    if type(interval) ~= "number" or interval < 1 then
        interval = 60 -- fallback default
        log("[Hivemind] Interval fallback to 60")
    end
    script.on_nth_tick(interval, Export.on_tick)
    storage.last_export_interval = interval
    log("[Hivemind] Registered nth-tick handler for interval: " .. tostring(interval) .. " ticks (" .. tostring(interval/60) .. " seconds)")
end

local function log_hivemind_settings()
    local function safe_val(tbl, key)
        local v = tbl[key]
        if v and v.value ~= nil then return v.value else return tostring(v) end
    end
    log("[Hivemind] SETTINGS DUMP START")
    log("[Hivemind] export_interval_seconds: " .. tostring(safe_val(settings.global, "hivemind_export_interval_seconds")))
    log("[Hivemind] chat_retention_seconds: " .. tostring(safe_val(settings.global, "hivemind_chat_retention_seconds")))
    log("[Hivemind] chat_max_messages: " .. tostring(safe_val(settings.global, "hivemind_chat_max_messages")))
    log("[Hivemind] event_retention_seconds: " .. tostring(safe_val(settings.global, "hivemind_event_retention_seconds")))
    log("[Hivemind] event_max_groups: " .. tostring(safe_val(settings.global, "hivemind_event_max_groups")))
    log("[Hivemind] SETTINGS DUMP END")
end

script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
    -- Only handle our own settings
    if string.find(event.setting, "^hivemind_") then
        log("[Hivemind] Setting changed: " .. event.setting .. ", reloading relevant handlers.")
        log_hivemind_settings()
        -- Always re-register nth-tick handler in case interval changed
        register_nth_tick_handler()
    end
end)

-- On mod init (new game or first load)
script.on_init(function()
    log("[Hivemind] on_init fired")
    log_hivemind_settings()
    local storage = get_storage()
    safe_init(Chat)
    safe_init(Event)
    storage.last_export_interval = nil
    register_nth_tick_handler()
    register_handlers()
end)

-- When loading a saved game or after mod configuration changes,
-- re-register handlers (script.on_event handlers aren’t persisted)
script.on_configuration_changed(function()
    log("[Hivemind] on_configuration_changed fired")
    log_hivemind_settings()
    local storage = get_storage()
    safe_init(Chat)
    safe_init(Event)
    storage.last_export_interval = nil
    register_nth_tick_handler()
    register_handlers()
end)

script.on_load(function()
    local storage = get_storage()
    register_event_handlers_only()
end)
