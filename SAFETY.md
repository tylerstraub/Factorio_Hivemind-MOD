## 1. `script.on_init`  
> **Fires once, on the dedicated server, when**  
> - A brand-new save is created, or  
> - Your mod is **first added** to a save that didn’t previously include it.  
>  
> **Use it (server-only) to:**  
> - Initialize your persistent state (`storage` tables).  
> - Register all game-state event listeners (`script.on_event`) that mutate `storage`.  
> - Register your slash commands/remote interfaces.  
>  
> ```lua
> script.on_init(function()
>   storage.init()              -- set up storage tables
>   event_listener.register()   -- server-only game logic hooks
>   commands.register()         -- server-only commands/interfaces
> end)
> ```  
> 

---

## 2. `script.on_configuration_changed`  
> **Fires on the dedicated server when**  
> - Mods or mod versions change (including your mod being added or upgraded mid-game).  
>  
> **Use it (server-only) to:**  
> - Migrate or extend your `storage` for new features.  
> - Re-register any new event listeners.  
> - Re-register commands/interfaces if your API surface changed.  
>  
> ```lua
> script.on_configuration_changed(function(event)
>   local change = event.mod_changes and event.mod_changes["Hivemind"]
>   if change then
>     storage.init()            -- migrate or init new data
>     event_listener.register() -- re-wire updated listeners
>     commands.register()
>   end
> end)
> ```  
> 

---

## 3. `script.on_load`  
> **Fires on every peer** (dedicated server at startup **and** every client as it joins)  
>  
> **Use it (server + client) only for:**  
> 1. **Re-registering event handlers** (so clients get the same `script.on_event` hooks).  
> 2. **Restoring metatables** on data in `storage`.  
> 3. **Re-registering commands/remote interfaces** if needed for client usage.  
>  
> **Never** mutate `storage` or perform server-only setup here—doing so on clients will desynchronize world state.  
>  
> ```lua
> script.on_load(function()
>   event_listener.register()   -- re-attach the same event handlers
>   commands.register()         -- re-expose commands & interfaces
> end)
> ```  
> 

---

## 4. `script.on_event` & `script.on_nth_tick`  
> **Runs on the peer that hosts the simulation** (the dedicated server) and between server & clients for input-only events.  
>  
> - **State-mutating handlers** (e.g. tracking `on_unit_group_finished_gathering`) must run **only on the server** to avoid world-state divergence.  
> - **Client-only handlers** (e.g. purely UI) can run on clients via conditional checks in your handler.  

---

## 5. Bringing it all together for a dedicated server  
```lua
-- control.lua
local storage        = require("modules.storage")
local event_listener = require("modules.event_listener")
local commands       = require("modules.commands")
local logging        = require("modules.logging")

-- 1) Server-only init and migrations:
script.on_init(function()
  logging.info("[Hivemind] on_init: server startup or new-mod")
  storage.init()              -- server-only persistent state
  event_listener.register()   -- server-only event hooks
  commands.register()         -- server-only commands & interfaces
end)

script.on_configuration_changed(function(event)
  local change = event.mod_changes and event.mod_changes["Hivemind"]
  if change then
    logging.info("[Hivemind] on_configuration_changed: mod added/updated")
    storage.init()
    event_listener.register()
    commands.register()
  end
end)

-- 2) Always re-wire handlers on load (server + clients):
script.on_load(function()
  logging.info("[Hivemind] on_load: wiring handlers (all peers)")
  event_listener.register()   -- so clients, too, get the same on_event callbacks
  commands.register()         -- so client UIs can invoke your commands/interfaces
end)
```

### Why this prevents desyncs
- **Server-only state writes** live in `on_init`/`on_configuration_changed`—clients never execute those, so `storage` stays identical.  
- **Handler wiring** in `on_load` runs everywhere, keeping client event hooks in sync without touching state.  
- **Client joins** see no unexpected mutations, and the CRC checks pass every time.

---

### Additional dedicated-server tips
- **RCON commands** can trigger server-only migrations live:  
  ```lua
  commands.add_command("hivemind-migrate", "Apply migrations", function(cmd)
    if not cmd.player_index then
      storage.init(); event_listener.register()
      commands.register()
      print("Hivemind: migrated")
    end
  end)
  ```
- **Do not** call `storage.init()` or `event_listener.register()` in `on_load` except in code paths guarded by `if not game.is_multiplayer() or game.is_server()`—but since clients cannot host events, it’s simpler to confine those calls entirely to the server hooks.

By following this pattern—**server-only init** and **peer-wide handler wiring**—your dedicated server and its connecting clients will stay perfectly in sync.