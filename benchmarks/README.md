# Benchmarks

Interactive tools for measuring the serial FastCast2 implementation with real-time parameter tuning.

## BenchmarkClient -- Client-side benchmark

**Type**: LocalScript (runs in StarterPlayerScripts or ReplicatedFirst)

Fires projectiles and tracks frame-time statistics using keyboard controls.

### Controls

| Key | Action |
|-----|--------|
| P | Start benchmark |
| N | Toggle input mode between Client and Server |
| L | Increase projectile count by 500 |
| K | Decrease projectile count by 500 (floor 0) |
| U | Toggle Instanced / Instanceless |
| J | Toggle BulkMoveTo / Motor6D |
| V | Toggle VisualizeCasts |
| R | Cycle Raycast / Blockcast / Spherecast |
| X | Cycle HighFidelityBehavior (Default > Automatic > Always) |
| > | Increase HighFidelitySegmentSize by 0.05 |
| < | Decrease HighFidelitySegmentSize by 0.05 (floor 0.05) |
| I | Show benchmark info |
| H | Show controls |


### Settings

Edit at the top of the file:

```lua
local Config = {
    ProjectileAmount = 500,   -- projectiles per benchmark run
    CastType = "Raycast",     -- Raycast, Blockcast, or Spherecast
    Instanced = true,         -- use cosmetic bullet instances
    VisualizeCasts = false,   -- show cast ray visualization
    BenchmarkDuration = 6,    -- seconds to simulate after creation
    MovementMode = "BulkMoveTo",
}
```

---

## BenchmarkServer -- Server-side benchmark

**Type**: Script (runs in ServerScriptService)

Same benchmark logic as the client, but runs on the server. It receives key commands from the client benchmark through ByteNet; it does not read chat messages.

To control the server benchmark, press N in the client benchmark to switch the input mode to **Server**, then use the same keys listed above.

### Server command keys

| Key | Action |
|---------|--------|
| p | Start benchmark |
| l | Increase projectile count by 500 |
| k | Decrease projectile count by 500 (floor 0) |
| u | Toggle Instanced / Instanceless |
| j | Toggle BulkMoveTo / Motor6D |
| v | Toggle VisualizeCasts |
| r | Cycle Raycast / Blockcast / Spherecast |
| x | Cycle HighFidelityBehavior |
| > | Increase HighFidelitySegmentSize by 0.05 |
| < | Decrease HighFidelitySegmentSize by 0.05 |
| i | Show benchmark info |
| h | Show commands |

### Settings

Edit at the top of the file:

```lua
local Config = {
    Instanced = false,
    MovementMode = "BulkMoveTo",
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
=== SERIAL MODE BENCHMARK ===
VisualizeCasts: Disabled
HighFidelityBehavior: Default
MovementMode: BulkMoveTo
CastType: Raycast
Instanceless
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

- **Creation elapsed / throughput** measure synchronous cast creation.
- **Cleanup elapsed / throughput** include termination requests, simulation dispatch, and the CastTerminating callbacks that destroy cosmetic projectile instances.
- **Average frame time** is calculated from every heartbeat during the simulation window; FPS is derived from that average.
- **P50 / P95 / P99** expose frame-time spikes that an FPS average can hide (lower is better).
- Each run uses the same random seed for repeatable projectile origins and directions.

## Quick Start

1. Run `rojo serve benchmarks.project.json` from the repository root.
2. Connect an empty Studio place with the Rojo plugin.
3. Play in Studio -- press P for the client benchmark. Press N to switch to Server input mode, then press P to run the server benchmark.

The benchmark project mounts FastCast2 in `ReplicatedStorage`, the client benchmark in `ReplicatedFirst`, and the server benchmark in `ServerScriptService`. You can also insert either script manually in those locations if you do not use Rojo.

For useful comparisons, change one setting at a time and run each configuration several times. In particular, compare all three cast types in this serial implementation with visualization disabled; Studio rendering, open windows, and plugins can otherwise add significant noise.

## Automated suite

The repeatable three-case matrix (Serial x Raycast/Blockcast/Spherecast)
now lives with the rest of the automated tests. It builds a Rojo place, runs it
in Studio with `run-in-roblox`, prints a Markdown results table, and uploads the
report to [paste.shellworks.dev](https://paste.shellworks.dev). See
[`tests/README.md`](../tests/README.md) for prerequisites and usage; run it with
`npm test` or `lune run tests/run.luau`.

