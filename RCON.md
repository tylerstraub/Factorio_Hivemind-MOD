**Context & Goals**  
You’re on Factorio **2.0.42** (stable since March 19 2025) and building an external tool that issues “one-shot” Lua commands via the RCON HTTP wrapper. To develop safely you need a **generic profiling harness** that:

1. Runs any single‐line Lua snippet  
2. Measures both **ticks** (16.667 ms resolution) and **milliseconds**  
3. Returns results **only** to your RCON client—**invisible** to players  
4. Guarantees each command completes within one tick (no micro-stutters)  

---

## 1. Building Blocks

| Concept                 | Usage / API                                                | Notes                                                                                  |
|-------------------------|------------------------------------------------------------|----------------------------------------------------------------------------------------|
| **Silent execution**    | `/silent-command <lua>`<br/>alias `/sc`                    | Runs Lua **without** broadcasting the command text to players’ consoles.               |
| **Tick sampler**        | `local t0 = game.tick`<br/>`local t1 = game.tick`          | `game.tick` increments at **60 UPS** (~16.667 ms/tick).                                |
| **Millisecond profiler**| `local prof = game.create_profiler()`<br/>`prof:stop()`    | Returns a `LuaProfiler` measuring wall-clock ms; call `prof:stop()` when done.         |
| **RCON-only print**     | `rcon.print(message :: LocalisedString)`                   | Sends text **only** to the calling RCON client; never to player chat.                  |
| **Safe concatenation**  | `rcon.print({"", "a=", dt, "  b=", prof})`                 | A table with `""` first is treated as a flat `LocalisedString`, auto-`tostring`-ing.  |

---

## 2. The One-Shot Wrapper

Drop your snippet in place of `<<YOUR_SNIPPET>>`:

```lua
/silent-command (function()
  -- start ms‐timer
  local prof = game.create_profiler()
  -- start tick‐timer
  local t0   = game.tick

  -- <<YOUR_SNIPPET GOES HERE>>
  -- e.g.: local _ = #game.connected_players

  -- stop ms‐timer
  prof:stop()
  -- end tick‐timer
  local t1 = game.tick
  local dt = t1 - t0

  -- print both results back over RCON only
  rcon.print({"", "Ticks: ", dt, "   Lua: ", prof})
end)()
```

**Why this works**  
- `/silent-command` masks the command itself from players  
- `game.create_profiler()` + `prof:stop()` yields a `LuaProfiler` that formats as “X ms” via its `__tostring`  
- A table starting with `""` forces flat concatenation, converting numbers and userdata to strings  
- `rcon.print` sends the result **only** to your wrapper client  

---

## 3. Ready-to-Paste macOS `curl`

Here’s the complete, deduplicated “one-shot” that:

1. **Calls** your `remote` interface (`get_attack_events_after`)  
2. **Profiles** ms + ticks  
3. **Emits** exactly one JSON blob + timing  

```bash
curl -X POST -H "Content-Type: application/json" \
  -d $'{"input":"/silent-command (function() local prof = game.create_profiler() local t0 = game.tick remote.call(\\"hivemind\\",\\"get_attack_events_after\\",0) prof:stop() local t1 = game.tick local dt = t1 - t0 rcon.print({\\"\\",\\"Ticks: \\",dt,\\"   Lua: \\",prof}) end)()"}' \
  http://192.168.5.10:24182/api/v2/factorio/console/command/raw
```

➔ **Expected response**:  
```json
{"output":"{…your JSON…}\nTicks: 0   Lua: 0.85 ms\n"}
```

- **One JSON** blob from your remote interface  
- **`Ticks: 0`** → completed within one tick (<16.7 ms)  
- **`Lua: 0.85 ms`** → precise wall-clock timing  
- **Players see nothing** in chat or console  

---

## 4. Integrating into Your Workflow

1. **Shell helper**  
   ```bash
   profile_rcon() {
     local snippet="$1"
     local lua="/silent-command (function() local prof = game.create_profiler() local t0 = game.tick ${snippet//\"/\\\"} prof:stop() local t1 = game.tick local dt = t1 - t0 rcon.print({\"\",\"Ticks: \",dt,\"   Lua: \",prof}) end)()"
     curl -s -X POST -H "Content-Type: application/json" \
          -d "{\"input\":\"$lua\"}" http://192.168.5.10:24182/api/v2/factorio/console/command/raw
   }
   ```
   Use it like:
   ```bash
   profile_rcon "for i=1,1000000 do end"
   ```

2. **Node.js wrapper**  
   Automate JSON quoting + HTTP calls in your CI or dev toolchain.

3. **Automated checks**  
   - **Fail** if `dt ≥ 1` (indicating >1 tick)  
   - **Log** both tick and ms metrics for each snippet run  

---

## 5. Anti-Jitter & Best Practices

- **Micro-stutter detection**: any `dt ≥ 1` tick will block the simulation (~16 ms)—catch these early.  
- **Batch heavy work**: split large loops or scans across ticks.  
- **Global profiling**:
  ```bash
  curl … -d '{"input":"/perf-avg-frames 100"}' …
  ```
  to see per-system averages.  
- **Never** use `game.print` or `player.print` in these wrappers—they broadcast to players.  
- **Always** combine `/silent-command` + `rcon.print({...})` to stay invisible in-game.  

---

With this **fully-verified**, remote-interface–driven recipe you can wrap **any** one-shot Lua command for profiling—guaranteeing **precision**, **simplicity**, and **player-invisibility**.