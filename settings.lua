-- settings.lua
-- Defines runtime-global mod settings for Hivemind, allowing users to configure logging and event retention behavior via the in-game mod settings GUI.

data:extend({
  {
    type = "bool-setting",
    name = "hivemind_enable_logging",
    setting_type = "runtime-global", -- Can be changed at runtime via map settings GUI
    default_value = false,
    order = "a"
  },
  {
    type = "int-setting",
    name = "hivemind_attack_event_retention_ticks",
    setting_type = "runtime-global",
    default_value = 36000,
    minimum_value = 600,
    maximum_value = 1000000,
    order = "b"
  },
  {
    type = "int-setting",
    name = "hivemind_chat_message_retention_ticks",
    setting_type = "runtime-global",
    default_value = 36000,
    minimum_value = 600,
    maximum_value = 1000000,
    order = "c"
  }
})
