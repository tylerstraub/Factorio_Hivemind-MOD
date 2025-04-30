# Hivemind Mod: Developer Log & Technical Reference

## Purpose
This document is a living developer log and technical reference for the Hivemind Factorio mod (v2.0+). It captures design intentions, architectural decisions, performance constraints, and lessons learned as development progresses. It is **not** an end-user guide, but a resource for current and future developers to understand the rationale behind every major component and pattern.

---

## Multiplayer & Dedicated Server Safety (2025-04-29 Update)

> **IMPORTANT:** As of Factorio 2.0+, all event handler and command registration must be done in a deterministic order on all peers (server and clients). Non-deterministic registration (e.g., using `pairs` over a table) will cause multiplayer join failures or desyncs.
>
> - **Always** use arrays + `ipairs`, or collect and sort keys before iterating with `pairs` for registration.
> - This requirement applies to both `script.on_event` and `commands.add_command`.
> - See `SAFETY.md` for full rationale and examples.

### Example: Deterministic Registration
```lua
-- BAD:
for event_id, handler in pairs(handlers) do
  script.on_event(event_id, handler)
end

-- GOOD:
local event_ids = {}
for event_id in pairs(handlers) do table.insert(event_ids, event_id) end
table.sort(event_ids)
for _, event_id in ipairs(event_ids) do
  script.on_event(event_id, handlers[event_id])
end
```

### Why This Matters
- Factorio 2.0+ will reject multiplayer join if event/command registration order is not identical between all peers.
- This is stricter than previous Factorio versions and must be followed for all multiplayer/dedicated server mods.

---

## Project Goals
- **Efficient, safe, and lossless export of system events and stateful data** for external consumption (via RCON and other automated tools).
- **Zero impact on Factorio's synchronous game loop:** All data collection, storage, and export must avoid stutters and maintain 60 UPS.
- **Configurable and robust data retention:** Support high-frequency event logging with bounded memory usage.
- **Extensible event architecture:** Designed to accommodate new event types and export needs with minimal refactoring.

---

## Key Design Principles
- **Single-threaded Safety:**
  - All logic must be safe to run in Factorio's single game thread. No operation should block or delay the simulation.
  - Avoid large table traversals or complex computation in per-tick/event handlers.
- **Persistent State:**
  - All persistent state is stored directly in the Factorio 2.0+ `storage` table (never `global`, which is undefined in Factorio 2.0+).
  - Storage helpers (see `modules/storage.lua`) encapsulate all access and mutation, referencing the `storage` table directly. This ensures multiplayer and dedicated server safety.
  - **Do not mutate persistent state in `on_load`.** All initialization and mutation occurs in `on_init`, `on_configuration_changed`, or event handlers, per Factorio best practices.
  - **Do not require or import the `helpers` module.** Use the global `helpers` object provided by Factorio for all serialization (e.g., `helpers.table_to_json`).
- **Dynamic Configuration:**
  - All runtime-global settings (e.g., event retention) are read live from `settings.global`.
  - Never cache settings; always re-read to support live tuning.
- **Minimal Logging Overhead:**
  - Logging is controlled by a runtime setting. Only essential state changes, command invocations, and pruning actions are logged.
  - Logs are output to the Factorio console (not to disk).
- **Safe Command Registration:**
  - Custom commands are always removed before registration to prevent duplicate errors during load/save cycles.
- **Profiling and Performance Monitoring:**
  - Use Factorio's built-in profiler and tick timing to validate performance (see `RCON.md` for profiling patterns).

---

## Module Overview
- **control.lua**: Entrypoint; manages mod lifecycle, module initialization, and command/event registration.
- **modules/storage.lua**: Persistent storage helpers; handles all event storage, pruning, and retrieval. All persistent data is stored directly in the Factorio `storage` table, ensuring compatibility with multiplayer and dedicated servers.
- **modules/event_listener.lua**: Registers and handles relevant game events (e.g., enemy group attack decisions, chat messages). Prunes old events and logs new ones.
- **modules/commands.lua**: Registers and implements custom commands for data export and management.
- **modules/logging.lua**: Centralized logging utility, controlled by a runtime setting.
- **modules/remote_interface.lua**: Centralized registration of the `hivemind` remote interface. Exposes storage and event data for RCON, console, and inter-mod access. All exported remote functions are logged, and all data serialization uses the global `helpers.table_to_json` (never require or import helpers). Now also exposes chat message data, clearing functions, and supports full storage snapshots for export and integration testing.
  - **Note:** All remote interface functions for storage tables (e.g., `get_attack_events_after`, `clear_attack_events`) are now generated automatically from a central list in `modules/remote_interface.lua`. To expose a new event type, simply add its table name to the `STORAGE_TABLES` list. The remote interface and all documentation examples will remain valid and up to date.
- **settings.lua**: Declares all runtime-global settings for logging and retention. Now includes separate retention settings for attack events and chat messages.
- **locale/en/config.cfg**: Localization for settings and UI. Now includes chat message retention settings.

---

## Event Storage & Commands

### Event Storage
- **Event Types:** The mod tracks and stores multiple event types:
  - **Attack events** (from `on_unit_group_finished_gathering`)
  - **Chat messages** (from `on_console_chat`)
  - (Architecture is extensible for additional event types such as research, pollution, etc.)
- **Storage:**
  - **Attack events** are stored in `storage.attack_events` as a table keyed by game tick. Each event contains:
    - `tick`: Game tick when the event occurred
    - `group_id`: Unique ID of the enemy unit group
    - (Additional fields may be added as needed)
  - **Chat messages** are stored in `storage.chat_messages` as a table keyed by game tick. Each message contains:
    - `tick`: Game tick when the message was sent
    - `player`: Player name (if available)
    - `player_index`: Player index (if available)
    - `message`: The chat message
    - `event_name`: The event ID (`defines.events.on_console_chat`)
- **Retention/Pruning:**
  - Old events and messages are pruned automatically **when new events are stored** (not on every tick).
  - The retention window (in ticks) is configurable via mod settings (see below).
  - Pruning ensures memory usage remains bounded.

### Commands
The following custom commands are available for interacting with stored events:

#### `/hm_get_events <tick>`
- **Description:** Prints a summary of all stored events (by type and count) that occurred after the specified tick. This includes attack events, chat messages, and any other tracked event types.
- **Parameter:** `tick` (optional, defaults to 0) — Only events with `tick > <tick>` are summarized.
- **Usage Example:** `/hm_get_events 10000`
- **Output Example:**
  ```
  [Hivemind] Event summary after tick 10000:
  - on_unit_group_finished_gathering: 5
  - on_console_chat: 1
  ```
  If no events are stored after the specified tick:
  ```
  [Hivemind] No events stored after tick 10000.
  ```
- **Admin Status:** Admin-only.
- **Logging Status:** Command invocation and output are logged.

#### `/hm_drop_events`
- **Description:** Removes all stored events (attack events, chat messages, and any future event types) from persistent storage.
- **Usage Example:** `/hm_drop_events`
- **Output:** Confirmation message indicating all event data has been dropped.
- **Admin Status:** Admin-only.
- **Logging Status:** Command invocation and output are logged.

#### `/hm_reload_listeners`
- **Description:** Reloads all Hivemind event listeners. Useful for maintenance or debugging; safe to call at any time.
- **Usage Example:** `/hm_reload_listeners`
- **Output:** Confirmation message.
- **Admin Status:** Admin-only.
- **Logging Status:** Command invocation and output are logged.

#### `/hm_list_listeners`
- **Description:** Lists all active Hivemind event listeners with their event names and IDs. This reflects the mod's internal handler table, not Factorio's runtime event registry.
- **Usage Example:** `/hm_list_listeners`
- **Output Example:**
  ```
  [Hivemind] Active registered listeners:
  - on_unit_group_finished_gathering (ID: 156)
  - on_console_chat (ID: 83)
  ```
- **Admin Status:** Admin-only.
- **Logging Status:** Command invocation and output are logged.

### Mod Settings (Runtime-Global)
- `hivemind_attack_event_retention_ticks`: Number of ticks to retain attack events (default: 36000, i.e., 10 minutes at 60 UPS)
- `hivemind_chat_message_retention_ticks`: Number of ticks to retain chat messages (default: 36000)
- `hivemind_enable_logging`: Enables or disables verbose logging of event and command activity
- These settings can be changed in the mod settings GUI at runtime.

---

## Remote Interfaces & RCON Access

### Remote Interface: `hivemind`
- The mod defines a remote interface named `hivemind` (see `modules/remote_interface.lua`).
- **Registration:** The interface is registered at the top-level of `control.lua` to guarantee availability for RCON, console, and other mods, per Factorio 2.0+ requirements.
- **Functions:**
  - `get_attack_events_after(tick)`: Returns all attack events after the given tick as a JSON string, bucketed by tick.
  - `get_chat_messages_after(tick)`: Returns all chat messages after the given tick as a JSON string, bucketed by tick.
  - `clear_attack_events()`: Clears all stored attack events.
  - `clear_chat_messages()`: Clears all stored chat messages.
  - `get_storage_snapshot(tick)`: Returns a single JSON object containing all tracked storage tables (attack events, chat messages, etc.) after the given tick. Useful for integration tests and bulk export.
  - All results are logged and serialized with `helpers.table_to_json`, and sent to RCON with `rcon.print`.
  - **Note:** If new storage tables are added to the mod, corresponding `get_<table>_after` and `clear_<table>` functions will be available automatically via the remote interface, with no further code changes required.
- **Usage Example (RCON/Console):**
  ```
  /c remote.call("hivemind", "get_attack_events_after", 1000)
  /c remote.call("hivemind", "get_chat_messages_after", 1000)
  /c remote.call("hivemind", "get_storage_snapshot", 1000)
  /c remote.call("hivemind", "clear_attack_events")
  /c remote.call("hivemind", "clear_chat_messages")
  ```
- **Retention Settings:**
  - `hivemind_attack_event_retention_ticks`: Number of ticks to retain attack events (default: 36000)
  - `hivemind_chat_message_retention_ticks`: Number of ticks to retain chat messages (default: 36000)
- **Localization:**
  - Settings and descriptions are localized in `locale/en/config.cfg`.

---

## Multiplayer & Dedicated Server Compatibility
- All persistent state is handled directly via the Factorio 2.0+ `storage` table, never a module-local variable or the legacy `global` table.
- Event listeners that mutate persistent state are only registered in host-only entry points (`on_init`, `on_configuration_changed`), never in `on_load`.
- Commands and remote interfaces are registered on all peers, including in `on_load`, per Factorio multiplayer best practices.
- The mod is now fully compatible with multiplayer and dedicated servers, with no risk of state desynchronization.

---

## Migration Notes
- **Factorio 2.0+ Migration:** All persistent data previously stored in `global` must be migrated to the new `storage` table. Any mutation of persistent state in `on_load` is now forbidden and will cause errors or desyncs.
- See the [Persistent Storage Table Migration Guide](https://lua-api.factorio.com/2.0.45/auxiliary/storage.html) for details.

---

## Performance Constraints & Targets
- **Event Handling:**
  - Event handlers (e.g., `on_unit_group_finished_gathering`) must execute in under 1 ms per event, even under heavy load.
  - All table traversals (e.g., pruning) are optimized to avoid full scans each tick.
- **Pruning:**
  - Pruning is triggered only when new events or chat messages are stored, not on every tick.
  - Retention window is user-configurable (default: 10 minutes at 60 UPS) for both event types.
- **Export:**
  - Data export via commands is on-demand and does not block the simulation.
- **Memory Usage:**
  - All event data is pruned by age; no unbounded growth.
- **RCON Safety:**
  - All RCON and remote export tools must use `/silent-command` and `rcon.print` to avoid spamming player consoles (see `RCON.md`).

---

## Logging & Debugging
- **What is logged:**
  - Mod lifecycle events (init, load, config change)
  - Event listener registration
  - Command registration and invocation
  - Attack event and chat message captures (with details)
  - Pruning actions (count of events removed)
  - Data drops via commands
- **How to enable logging:**
  - Set `hivemind_enable_logging` to `true` in runtime-global settings.
- **Where logs go:**
  - Factorio console (not to file). For persistent logs, use RCON or external tools.

---

## Extending the Mod
- **Adding New Event Types:**
  - Register new handlers in `event_listener.lua`, following the pattern for attack events.
  - Ensure all new event data is stored directly via the `storage` table and pruned appropriately.
- **Adding Export Commands:**
  - Define new commands in `commands.lua`.
  - Always remove commands before re-registering.
- **Profiling New Features:**
  - Use the patterns in `RCON.md` to measure tick and ms cost of new handlers.

---

## Lessons Learned
- **Never use `global` for persistent state in Factorio 2.0+.**
- **Always re-read settings at runtime.**
- **Batch or defer heavy work.**
- **Profile early and often.**
- **Design for bounded memory.**

---

## References
- [Factorio Modding API Docs](https://lua-api.factorio.com/2.0.45/)
- [Persistent Storage Table Migration Guide](https://lua-api.factorio.com/2.0.45/auxiliary/storage.html)
- [RCON.md](RCON.md) — Profiling, remote command, and export patterns
- [REFACTOR.md](REFACTOR.md) — Technical patterns and lessons

---

## TODO / Open Questions
- [x] Add support for chat message storage and remote interface functions.
- [ ] Add support for additional system event types (e.g., research, pollution)
- [ ] Implement periodic summarization/export hooks
- [ ] Evaluate memory and tick cost under extreme event rates
- [ ] Document all new design decisions here as development continues

---

*This README should be updated with every major technical, architectural, or performance-related change to ensure continuity and clarity for all developers working on Hivemind.*