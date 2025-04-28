-- settings.lua: Startup settings for Hivemind (now in seconds)

local startup_settings = {
  {
    type = "int-setting",
    name = "hivemind_chat_retention_seconds",
    setting_type = "startup",
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
    setting_type = "startup",
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
    setting_type = "startup",
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
    setting_type = "startup",
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
    setting_type = "startup",
    default_value = 1, -- 1 second
    minimum_value = 1,
    maximum_value = 60 * 60, -- 1 hour
    order = "c[export]-a[interval]",
    localised_name = "Export interval (seconds)",
    localised_description = "Interval between exports in seconds."
  }
}

data:extend(startup_settings)
