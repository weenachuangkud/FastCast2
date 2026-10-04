# Simulation hot paths

Run from the repository root with the toolchain on PATH:

```sh
npm run test:hotpaths
# Optional A/B benchmark against a saved, pre-change simulation module:
lune run tests/hotpaths/run.luau path/to/baseline-directory
```

The baseline directory must contain `SerialSimulation.luau`. Save that file
before making changes to compare against the exact workspace state. Both
versions use the current Config and dependencies. Nothing is uploaded.

The runner builds an isolated Studio place under `build/hotpaths`. It injects
private test hooks into disposable copies of the actual simulation modules;
the shipped modules gain no test API. The ordinary functional suite remains
`npm test -- --no-upload`.

Regression checks cover both queues crossing several buffer growth boundaries,
IDs above 32 bits, nil holes and reuse with shorter payloads, event dispatch
after active-list removal, accelerated trajectories, midpoint position and
orientation, zero/vertical movement, and tiny motion at large coordinates.
It also checks 96 real collisions per cast type with randomized timestep
lengths and starting positions.

The optional benchmark directly times serial simulation steps with 6,000
headless, accelerated raycasts in an empty world, using sparse IDs above 2^40.
It includes real workspace raycast calls and public-state writeback, excludes
creation and cosmetic movement, and compares LengthChanged off/on. Each
variant gets 20 warmup steps, followed by nine alternating-order samples of
60 steps at dt=1/60. Reported times are the median of those per-step averages,
not frame intervals or per-frame tail latency. It does not measure parallel
scheduler throughput, collision-heavy workloads, or SwiftCast.

Local Studio run on 2026-09-17, against the workspace snapshot immediately
before this optimization pass (including its existing performance edits):

| LengthChanged | Before ms/step | After ms/step | Time reduction |
| --- | ---: | ---: | ---: |
| Off | 13.3614 | 11.3702 | 14.9% |
| On | 15.9684 | 12.9217 | 19.1% |

These are one-machine measurements, not universal speed guarantees. Existing
Heartbeat benchmarks remained around the 60 FPS cap in both versions.
The final full-suite run passed all 19 tests. One intermediate run timed out
on the serial spherecast wall test; that failure did not reproduce in the
final run or the 288 deterministic collision checks. Its cause remains
unresolved.

The implementation stores event metadata in nine bytes per capacity slot
(f64 ID and u8 event kind), removing one three-field table per queued event
and the two arrays of references to those tables. Argument tables remain
pooled because they contain Roblox values. Capacity doubles at growth
boundaries and is reused thereafter. Five direct argument assignments avoid
sparse-table length ambiguity and vararg copy loops.

Ballistic displacement uses `(v0 + a*(t0+t1)/2)*(t1-t0)`, algebraically equal
to subtracting the two trajectory positions, without rounding large world
coordinates before subtraction. Each moving cast builds one midpoint
`CFrame.lookAlong` instead of constructing and multiplying two CFrames.
Floating-point results can differ slightly from the previous implementation;
the large-origin test specifically verifies the improved displacement.
