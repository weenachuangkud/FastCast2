# Benchmarks

Interactive benchmarking tools for FastCast2. Two scripts for comparing performance across serial and parallel modes with real-time parameter tuning.

## BenchmarkClient -- Client-side benchmark

**Type**: LocalScript (runs in StarterPlayerScripts or ReplicatedFirst)

Fires projectiles and tracks FPS using keyboard controls. Supports both serial and parallel casting modes.

### Controls

| Key | Action |
|-----|--------|
| P | Start benchmark |
| L | Increase projectile count by 500 |
| K | Decrease projectile count by 500 (floor 0) |
| U | Toggle Instanced / Instanceless |
| J | Toggle BulkMoveTo / Motor6D |
| Y | Toggle ObjectCache |
| V | Toggle VisualizeCasts |
| R | Cycle Raycast / Blockcast / Spherecast |
| X | Cycle HighFidelityBehavior (Default > Automatic > Always) |
| > | Increase HighFidelitySegmentSize by 0.05 |
| < | Decrease HighFidelitySegmentSize by 0.05 (floor 0.05) |
| B | Switch serial / parallel caster |
| [ | Decrement numWorkers (floor 2, parallel only) |
| ] | Increment numWorkers (parallel only) |
| I | Show benchmark info |
| H | Show controls |

> Note: `[` decrements and `]` increments (bigger key = more workers).

### Settings

Edit at the top of the file:

```lua
local Config = {
    Parallel = true,          -- true = parallel, false = serial
    NumWorkers = 4,           -- number of VM workers (parallel only)
    ProjectileAmount = 500,   -- projectiles per benchmark run
    CastType = "Raycast",     -- Raycast, Blockcast, or Spherecast
    Instanced = true,         -- use cosmetic bullet instances
    VisualizeCasts = false,   -- show cast ray visualization
    BenchmarkDuration = 6,    -- seconds to simulate after creation
    MovementMode = "BulkMoveTo",
    ObjectCacheEnabled = false,
}
```

---

## BenchmarkServer -- Server-side benchmark

**Type**: Script (runs in ServerScriptService)

Same benchmark logic as the client, but runs on the server. Controlled via chat messages instead of keyboard input (since UserInputService is client-only).

### Chat Commands

Type the letter in chat:

| Command | Action |
|---------|--------|
| p | Start benchmark |
| l | Increase projectile count by 500 |
| k | Decrease projectile count by 500 (floor 0) |
| u | Toggle Instanced / Instanceless |
| j | Toggle BulkMoveTo / Motor6D |
| y | Toggle ObjectCache |
| v | Toggle VisualizeCasts |
| r | Cycle Raycast / Blockcast / Spherecast |
| x | Cycle HighFidelityBehavior |
| > | Increase HighFidelitySegmentSize by 0.05 |
| < | Decrease HighFidelitySegmentSize by 0.05 |
| [ | Decrement numWorkers (floor 2) |
| ] | Increment numWorkers |
| i | Show benchmark info |
| h | Show commands |

### Settings

Edit at the top of the file:

```lua
local Config = {
    NumWorkers = 4,
    Instanced = false,
    MovementMode = "BulkMoveTo",
    ObjectCacheEnabled = false,
    ProjectileAmount = 500,
    CastType = "Raycast",
    VisualizeCasts = false,
    Velocity = 6,
}
```

---

## Benchmark Output

Both scripts print the same format after each run:

```
=== MODE BENCHMARK ===
ObjectCache Disabled
VisualizeCasts: Disabled
HighFidelityBehavior: Default
MovementMode: BulkMoveTo
CastType: Raycast
Instanceless
numWorkers:    4
Firing 500 projectiles...
=== CREATION COMPLETE ===
Elapsed: xx.xx ms
Throughput: xx.xx projectiles/s
=== SIMULATION COMPLETE ===
Frames sampled: xxx
Average frame time: xx.xx ms (xx.xx FPS)
P50 / P95 / P99: xx.xx / xx.xx / xx.xx ms
FPS range: xx.xx - xx.xx
=== CLEANUP ===
Elapsed: xx.xx ms
Throughput: xx.xx projectiles/s
=== DONE ===
```

- **Elapsed / throughput** measure synchronous projectile creation and cleanup work.
- **Average frame time** is calculated from every heartbeat during the simulation window; FPS is derived from that average.
- **P50 / P95 / P99** expose frame-time spikes that an FPS average can hide (lower is better).
- Each run uses the same random seed, so different modes and settings receive identical projectile origins and directions.

## Quick Start

1. Run `rojo serve benchmarks.project.json` from the repository root.
2. Connect an empty Studio place with the Rojo plugin.
3. Play in Studio -- press P on the client or type p in chat on the server.

The benchmark project mounts FastCast2 in `ReplicatedStorage`, the client benchmark in `ReplicatedFirst`, and the server benchmark in `ServerScriptService`. You can also insert either script manually in those locations if you do not use Rojo.

For useful comparisons, change one setting at a time and run each configuration several times. In particular, compare all three cast types in serial and parallel modes with visualization disabled; Studio rendering, open windows, and plugins can otherwise add significant noise.

## Automated suite

The repeatable six-case matrix (Serial/Parallel x Raycast/Blockcast/Spherecast)
now lives with the rest of the automated tests. It builds a Rojo place, runs it
in Studio with `run-in-roblox`, prints a Markdown results table, and uploads the
report to [paste.shellworks.dev](https://paste.shellworks.dev). See
[`tests/README.md`](../tests/README.md) for prerequisites and usage; run it with
`npm test` or `lune run tests/run.luau`.

