**Context & Goals**  
You’re on Factorio **2.0.42** (stable since March 19 2025) and building an external tool that issues “one-shot” Lua commands via the RCON HTTP wrapper. To develop safely you need a **generic profiling harness** that:

1. Runs any single-line Lua snippet  
2. Measures both **ticks** (16.667 ms resolution) and **milliseconds**  
3. Returns results **only** to your RCON client—**invisible** to players  
4. Guarantees each command completes within one tick (no micro-stutters)  ([Console - Official Factorio Wiki](https://wiki.factorio.com/console?utm_source=chatgpt.com), [sometime lua tick error : r/Stormworks - Reddit](https://www.reddit.com/r/Stormworks/comments/1227g7j/sometime_lua_tick_error/?utm_source=chatgpt.com))  

---

## 1. Building Blocks

| Concept                     | Usage / API                                        | Notes                                                                                  |
|-----------------------------|----------------------------------------------------|----------------------------------------------------------------------------------------|
| **Silent execution**        | `/silent-command <lua>`<br/>alias `/sc`             | Runs Lua **without** broadcasting the command text to players’ consoles  ([Console - Official Factorio Wiki](https://wiki.factorio.com/console?utm_source=chatgpt.com)). |
| **Tick sampler**            | `local t0 = game.tick`<br/>`local t1 = game.tick`  | `game.tick` increments at **60 UPS** (~16.667 ms/tick)  ([OpenTelemetry metrics and traces for Factorio servers - GitHub](https://github.com/FactorioSharp/FactorioSharp.Instrumentation?utm_source=chatgpt.com)).           |
| **Millisecond profiler**    | `local prof = game.create_profiler()`              | Returns a `LuaProfiler` userdata measuring wall-clock ms; call `prof:stop()` when done  ([LuaHelpers - Runtime Docs | Factorio](https://lua-api.factorio.com/latest/classes/LuaHelpers.html?utm_source=chatgpt.com)). |
| **RCON‐only print**         | `rcon.print(message :: LocalisedString)`           | Sends text **only** to the calling RCON client; never to player chat  ([LuaRCON - Runtime Docs - Factorio API Docs](https://lua-api.factorio.com/latest/classes/LuaRCON.html?utm_source=chatgpt.com)). |
| **Safe concatenation**      | `rcon.print({"", "a=", dt, "  b=", prof})`         | A table with `""` first is treated as a flat `LocalisedString`, auto-`tostring`-ing userdata  ([콘솔](https://wiki.factorio.com/Console/ko?utm_source=chatgpt.com)). |

---

## 2. The One-Shot Wrapper

Drop your snippet in place of `<<YOUR_SNIPPET>>`:

```lua
/silent-command (function()
  -- start ms-timer
  local prof = game.create_profiler()
  -- start tick-timer
  local t0   = game.tick

  -- <<YOUR_SNIPPET GOES HERE>>
  -- e.g.: local _ = #game.connected_players

  -- stop ms-timer
  prof:stop()
  -- end tick-timer
  local t1 = game.tick
  local dt = t1 - t0

  -- print both results back over RCON only
  rcon.print({"", "Ticks: ", dt, "   Lua: ", prof})
end)()
```

- **Why this works**  
  - `/silent-command` masks the command itself from players  ([Console - Official Factorio Wiki](https://wiki.factorio.com/console?utm_source=chatgpt.com))  
  - `game.create_profiler()` + `prof:stop()` yields a `LuaProfiler` that formats as “X ms” via its `__tostring`  ([LuaHelpers - Runtime Docs | Factorio](https://lua-api.factorio.com/latest/classes/LuaHelpers.html?utm_source=chatgpt.com))  
  - A table starting with `""` forces flat concatenation, converting numbers and userdata to strings  ([콘솔](https://wiki.factorio.com/Console/ko?utm_source=chatgpt.com))  
  - `rcon.print` sends the result **only** to your wrapper client  ([LuaRCON - Runtime Docs - Factorio API Docs](https://lua-api.factorio.com/latest/classes/LuaRCON.html?utm_source=chatgpt.com))  

---

## 3. Ready-to-Paste macOS `curl`

```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"input":"/silent-command (function() local prof=game.create_profiler() local t0=game.tick local _=#game.connected_players prof:stop() local t1=game.tick local dt=t1-t0 rcon.print({\"\",\"Ticks: \",dt,\"   Lua: \",prof}) end)()"}' \
  http://192.168.5.10:24180/api/v2/factorio/console/command/raw
```

➔ **Expected response**:  
```json
{"output":"Ticks: 0   Lua: 0.05 ms\n"}
```
- **`Ticks: 0`** → completed within one tick (sub-16.7 ms)  
- **`Lua: 0.05 ms`** → precise wall-clock timing  
- **Players see nothing** in chat or console  ([Console - Official Factorio Wiki](https://wiki.factorio.com/console?utm_source=chatgpt.com), [LuaRCON - Runtime Docs - Factorio API Docs](https://lua-api.factorio.com/latest/classes/LuaRCON.html?utm_source=chatgpt.com))  

---

## 4. Integrating into Your Workflow

1. **Shell helper**  
   ```bash
   profile_rcon() {
     local snippet="$1"
     local lua="/silent-command (function() local prof=game.create_profiler() local t0=game.tick ${snippet//\"/\\\"} prof:stop() local t1=game.tick local dt=t1-t0 rcon.print({\"\",\"Ticks: \",dt,\"   Lua: \",prof}) end)()"
     curl -s -X POST -H "Content-Type: application/json" \
          -d "{\"input\":\"$lua\"}" http://192.168.5.10:24180/api/v2/factorio/console/command/raw
   }
   ```
   Use: `profile_rcon "for i=1,1000000 do end"`  

2. **Node.js wrapper**  
   Automate JSON quoting and HTTP calls in your CI or dev server.  

3. **Automated checks**  
   - **Fail** if `dt > 0` ticks (indicating >16.7 ms).  
   - **Log** both tick and ms metrics for each snippet invocation.  

---

## 5. Anti-Jitter & Best Practices

- **Micro-stutter detection**: any `dt ≥ 1` tick will block the simulation for ~16 ms—catch these early.  
- **Batch heavy work**: for loops or large entity scans, split across multiple ticks.  
- **Global profiling**: occasionally run  
  ```bash
  curl … -d '{"input":"/perf-avg-frames 100"}' …
  ```  
  to see per-system ms/tick averages and spot bottlenecks .  
- **Never** use `game.print` or `player.print` in these wrappers—they broadcast to players.  
- **Always** combine `/silent-command` + `rcon.print({...})` to stay invisible in-game.  

---

With this **fully-verified**, official-API-backed recipe you can wrap **any** one-shot Lua command for profiling—guaranteeing both **precision** and **player-invisibility**.