-- modules/logging.lua
-- Centralized logging for Hivemind mod (Factorio 2.0+)

local logging = {}

-- Usage: logging.info("message")
function logging.info(msg)
  if settings.global["hivemind_enable_logging"] and settings.global["hivemind_enable_logging"].value then
    log("[Hivemind] " .. tostring(msg))
  end
end

-- Optionally, add more log levels (e.g., warn, error) here

return logging
