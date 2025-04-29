# Hivemind Mod: Developer Log & Technical Reference

## Purpose
This document is a living developer log and technical reference for the Hivemind Factorio mod (v2.0+). It captures design intentions, architectural decisions, performance constraints, and lessons learned as development progresses. It is **not** an end-user guide, but a resource for current and future developers to understand the rationale behind every major component and pattern.

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
- **modules/event_listener.lua**: Registers and handles relevant game events (e.g., enemy group attack decisions). Prunes old events and logs new ones.
- **modules/commands.lua**: Registers and implements custom commands for data export and management.
- **modules/logging.lua**: Centralized logging utility, controlled by a runtime setting.
- **settings.lua**: Declares all runtime-global settings for logging and retention.
- **locale/en/config.cfg**: Localization for settings and UI.

---

## Attack Event Storage & Commands

### Attack Event Storage
- **Event Type:** The mod tracks and stores enemy attack group events (from `on_unit_group_finished_gathering`).
- **Storage:** Events are stored in `storage.attack_events` as a table keyed by game tick. Each event contains:
  - `tick`: Game tick when the event occurred
  - `group_id`: Unique ID of the enemy unit group
  - (Additional fields may be added as needed)
- **Retention/Pruning:**
  - Old events are pruned automatically when new events are stored.
  - The retention window (in ticks) is configurable via mod settings (see below).
  - Pruning ensures memory usage remains bounded.

### Commands
- The following custom commands are available for interacting with stored attack events:

#### `/hm_get_events <tick>`
- **Description:** Exports all attack events that occurred after the specified tick.
- **Parameter:** `tick` (optional, defaults to 0) — Only events with `tick > <tick>` are returned.
- **Usage Example:** `/hm_get_events 10000`
- **Output:** Events are printed to the console or RCON (for automated export).
- **Admin Status:** Admin-only.
- **Logging Status:** Command invocation and output are logged.

#### `/hm_drop_events`
- **Description:** Removes all stored attack events from persistent storage.
- **Usage Example:** `/hm_drop_events`
- **Output:** Confirmation message and count of events dropped.
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
  ```
- **Admin Status:** Admin-only.
- **Logging Status:** Command invocation and output are logged.

### Mod Settings (Runtime-Global)
- `hivemind_event_retention_ticks`: Number of ticks to retain attack events (default: 36000, i.e., 10 minutes at 60 UPS)
- `hivemind_enable_logging`: Enables or disables verbose logging of event and command activity
- These settings can be changed in the mod settings GUI at runtime.

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
  - Pruning is triggered only when new events are stored, not on every tick.
  - Retention window is user-configurable (default: 10 minutes at 60 UPS).
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
  - Attack event captures (with details)
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
- [ ] Add support for additional system event types (e.g., chat, research, pollution)
- [ ] Implement periodic summarization/export hooks
- [ ] Evaluate memory and tick cost under extreme event rates
- [ ] Document all new design decisions here as development continues

---

*This README should be updated with every major technical, architectural, or performance-related change to ensure continuity and clarity for all developers working on Hivemind.*