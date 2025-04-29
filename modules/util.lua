-- modules/util.lua
local Util = {}

-- Pretty-print a minified JSON string
function Util.pretty_json(json_str)
    local indent, indent_str, result = 0, "  ", {}
    local in_string, escape_next     = false, false
    for i = 1, #json_str do
        local ch = json_str:sub(i, i)
        if escape_next then
            escape_next = false
            table.insert(result, ch)
        elseif ch == "\\" and in_string then
            escape_next = true
            table.insert(result, ch)
        elseif ch == '"' then
            in_string = not in_string
            table.insert(result, ch)
        elseif not in_string then
            if ch == "{" or ch == "[" then
                table.insert(result, ch .. "\n")
                indent = indent + 1
                table.insert(result, indent_str:rep(indent))
            elseif ch == "}" or ch == "]" then
                table.insert(result, "\n")
                indent = indent - 1
                table.insert(result, indent_str:rep(indent) .. ch)
            elseif ch == "," then
                table.insert(result, ch .. "\n" .. indent_str:rep(indent))
            elseif ch == ":" then
                table.insert(result, ch .. " ")
            elseif not (ch == " " or ch == "\n" or ch == "\t") then
                table.insert(result, ch)
            end
        else
            table.insert(result, ch)
        end
    end
    return table.concat(result)
end

-- Convert a tick count to HH:MM:SS since map start
function Util.tick_to_time(tick)
    local secs = math.floor(tick / 60) -- 60 ticks = 1 sec
    local hh   = math.floor(secs / 3600)
    local mm   = math.floor((secs % 3600) / 60)
    local ss   = secs % 60
    return string.format("%02d:%02d:%02d", hh, mm, ss)
end

-- Find the nearest chart tag (map label) to a given position for a force/surface
function Util.find_nearest_chart_tag(surface, force, position)
    -- Always use the player force for map tags
    local tags = game.forces["player"].find_chart_tags(surface)
    if not tags or #tags == 0 then return nil end
    local nearest_tag = nil
    local nearest_dist = math.huge
    for _, tag in ipairs(tags) do
        if tag.position and tag.text then
            local dx = tag.position.x - position.x
            local dy = tag.position.y - position.y
            local dist = dx * dx + dy * dy -- squared distance
            if dist < nearest_dist then
                nearest_dist = dist
                nearest_tag = tag
            end
        end
    end
    return nearest_tag
end

-- Profiling helpers
function Util.create_profiler()
    return game.create_profiler and game.create_profiler() or nil
end

function Util.profile_section(profiler, logs, section)
    if profiler then
        -- Use empty string as first element for direct concat (Factorio log expects LocalisedString)
        table.insert(logs, {"", string.format("%-15s", section) .. " = ", profiler})
        profiler:reset()
    end
end

function Util.log_profiling_if_enabled(logs, profiler, total_profiler)
    local profiling_setting = settings.global["hivemind_enable_profiling_log"]
    local profiling_enabled = profiling_setting and profiling_setting.value
    if profiling_enabled and profiler then
        log("--- Hivemind Profiling ---")
        for _, msg in ipairs(logs) do
            log(msg)
        end
        if total_profiler then
            log({"", "TOTAL          = ", total_profiler})
        end
        log("-------------------------")
    end
end

return Util
