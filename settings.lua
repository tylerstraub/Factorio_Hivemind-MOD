-- settings.lua: Runtime settings for Hivemind (now in seconds)
-- All settings are now runtime-global. Admins can change these at runtime and changes take effect immediately.

local runtime_settings = {
  {
    type = "int-setting",
    name = "hivemind_chat_retention_seconds",
    setting_type = "runtime-global",
    default_value = 60, -- 1 minute
    minimum_value = 1,
    maximum_value = 60 * 60, -- 1 hour
    order = "a[chat]-a[retention]",
    localised_name = "Chat retention time (seconds)",
    localised_description = "How many seconds chat messages are kept."
  },
  {
    type = "int-setting",
    name = "hivemind_chat_max_messages",
    setting_type = "runtime-global",
    default_value = 5,
    minimum_value = 1,
    maximum_value = 100,
    order = "a[chat]-b[max_messages]",
    localised_name = "Max chat messages",
    localised_description = "Maximum number of chat messages to retain."
  },
  {
    type = "int-setting",
    name = "hivemind_event_retention_seconds",
    setting_type = "runtime-global",
    default_value = 60, -- 1 minute
    minimum_value = 1,
    maximum_value = 60 * 60, -- 1 hour
    order = "b[event]-a[retention]",
    localised_name = "Event retention time (seconds)",
    localised_description = "How many seconds event history is kept."
  },
  {
    type = "int-setting",
    name = "hivemind_event_max_groups",
    setting_type = "runtime-global",
    default_value = 5,
    minimum_value = 1,
    maximum_value = 100,
    order = "b[event]-b[max_groups]",
    localised_name = "Max event groups",
    localised_description = "Maximum number of event groups to retain."
  },
  {
    type = "int-setting",
    name = "hivemind_export_interval_seconds",
    setting_type = "runtime-global",
    default_value = 5, -- 5 seconds
    minimum_value = 1,
    maximum_value = 60 * 60, -- 1 hour
    order = "c[export]-a[interval]",
    localised_name = "Export interval (seconds)",
    localised_description = "Interval between exports in seconds."
  },
  {
    type = "bool-setting",
    name = "hivemind_enable_profiling_log",
    setting_type = "runtime-global",
    default_value = false,
    order = "z[debug]-a[profiling]",
    localised_name = "Enable Hivemind profiling logs",
    localised_description = "If enabled, logs detailed timing information for each export tick to the Factorio log. Useful for debugging performance issues."
  }
}

data:extend(runtime_settings)
