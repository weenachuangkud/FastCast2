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
local Parallel = true          -- true = parallel, false = serial
local numWorkers = 4           -- number of VM workers (parallel only)
local ProjectileAmount = 500   -- projectiles per benchmark run
local Instanced = true         -- use cosmetic bullet instances
local VisualizeCasts = false   -- show cast ray visualization
local BENCH_TIME = 6           -- seconds to simulate after creation
local MovementMode = "BulkMoveTo"
local ObjectCacheEnabled = false
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
local numWorkers = 4
local Instanced = false
local MovementMode = "BulkMoveTo"
local UseObjectCache = false
local ProjectileAmount = 500
local VisualizeCasts = false
local VELOCITY = 6
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
Instanceless
numWorkers:    4
Firing 500 projectiles...
=== CREATION COMPLETE ===
Delta: xx.xx ms
Average FPS: xx.xx
Max FPS: xx.xx
Min FPS: xx.xx
=== SIMULATION COMPLETE ===
...
=== DONE ===
Delta: xx.xx ms
Average FPS: xx.xx
Max FPS: xx.xx
Min FPS: xx.xx
```

- **Delta**: Frame time in milliseconds (lower is better)
- **FPS** values are collected per-frame and averaged over 0.5s windows
- `maxFps`/`minFps` reset at the start of each benchmark run

## Quick Start

1. Insert BenchmarkClient into ReplicatedFirst (or StarterPlayerScripts)
2. Insert BenchmarkServer into ServerScriptService
3. Play in Studio -- press P on the client or type p in chat on the server