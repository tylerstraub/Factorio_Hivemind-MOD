# Hivemind Mod: REFACTOR.md

## Purpose
This document summarizes the essential technical patterns, working Factorio API interactions, and lessons learned from the current (pre-refactor) implementation of the Hivemind mod. It is intended as a future reference for scalable, performant reimplementation.

---

## 1. Working Factorio Engine Interactions

### a. Event Handling
- **Registration:**
  - Use `script.on_event(defines.events.<event>, handler)` to register event handlers.
  - Dynamic registration via iteration over a handlers table (e.g. `for event_id, handler in pairs(Event.events) do ...`).
  - Use `script.on_nth_tick(interval, handler)` for periodic actions (e.g. regular data export).
- **Settings Change:**
  - Listen for `defines.events.on_runtime_mod_setting_changed` to respond to runtime setting changes, and re-register handlers as needed.

### b. Global State Management
- Use the global table (`global`) for persistent mod state across ticks and saves.
- Encapsulate access via a helper (e.g. `get_storage()`), and store all mod data under a dedicated table (e.g. `storage`).

### c. Runtime Settings
- Retrieve runtime-global settings via `settings.global["setting_name"].value`.
- All settings are live and can be changed at runtime; handlers should re-read settings as needed.

### d. Game Data Retrieval
- **Players:** `game.get_player(event.player_index)`
- **Tick/Time:** `event.tick` (current tick), convert to HH:MM:SS via utility
- **Surface:** `game.surfaces["nauvis"]` (or other surface names)
- **Entity Counts:** `surface.count_entities_filtered{type=..., force=...}`
- **Research:** `game.forces["player"].research_queue`, `researched_technologies`, `current_research`
- **Pollution:** `surface.get_pollution({x, y})`
- **Map Tags:** `game.forces["player"].find_chart_tags(surface)`

### e. Chat/Event Recording
- **Chat:** Listen for `on_console_chat`, store messages with tick and player name, prune by age and count.
- **Events:** Group by type and context (e.g. deaths, attacks), store with tick and relevant data, prune by age and group count.

### f. Profiling
- Use `game.create_profiler()` and custom logging for performance profiling, enabled by a runtime setting.

---

## 2. Proven Code Patterns

### a. Modularization
- Separate modules for chat, event, export, and utility logic.
- Each module exposes an `init()` for safe initialization.

### b. Safe Initialization
- Check for `init()` in each module and call during `script.on_init`.
- Always (re-)initialize global storage tables to avoid nil errors.

### c. Pruning Data
- Prune chat messages and event groups both by age (tick cutoff) and by count (max messages/groups).
- Use current tick and settings-driven retention intervals.

### d. Export Logic
- Summarize event groups for efficient export.
- Gather all relevant state in a single periodic handler (`on_nth_tick`).
- Output to JSON (external NodeJS service integration is out-of-scope for Factorio script).

---

## 3. Lessons Learned / Pitfalls

- **Single-threaded Limitations:**
  - All logic runs synchronously in the game loop. Avoid heavy computation or large table traversals per tick.
  - Prune and summarize data in the most efficient way possible.
- **Dynamic Settings:**
  - All settings can change at runtime; always re-read settings instead of caching.
- **Global Table:**
  - Avoid polluting the global namespace; always use a dedicated storage table.
- **Event Handler Management:**
  - Unregister previous nth-tick handlers before registering new ones to prevent handler leaks.
- **Profiling:**
  - Use Factorio's profiler and logs to measure tick cost of each section.
- **Export Frequency:**
  - Export interval should be configurable and default to a safe value if misconfigured.

---

## 4. Example: Working Patterns

```lua
-- Registering an event handler
game.on_event(defines.events.on_console_chat, function(event)
  -- ...
end)

-- Accessing runtime-global settings
local interval = settings.global["hivemind_export_interval_seconds"].value

-- Counting entities
local count = surface.count_entities_filtered{type="unit", force="enemy"}

-- Accessing global state
storage = global or {}

-- Profiling
local profiler = game.create_profiler()
profiler:reset()
log("Section took: " .. profiler)
```

---

## 5. To Revisit in Refactor
- All logic that touches the game state or global table
- All event handler registration and deregistration
- Data pruning and summarization logic
- Export tick handler and all code that runs on every tick
- Any code that could scale poorly as game state grows

---

## 6. References
- [Factorio Modding API Docs](https://lua-api.factorio.com/latest/)
- [Current Hivemind README](README.md)

---

This document is a technical snapshot for future reference before a full system rework.
