-- control.lua

-- require our modules
local Chat   = require("__my-export-mod__/modules/chat")
local Export = require("__my-export-mod__/modules/export")

-- wire up lifecycle
script.on_init(function()
    Chat.init()
end)

script.on_event(defines.events.on_console_chat, function(event)
    Chat.on_chat(event)
end)

script.on_nth_tick(Export.INTERVAL, function(event)
    Export.on_tick(event)
end)
