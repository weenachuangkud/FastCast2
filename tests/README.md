# Tests

Automated FastCast2 test + benchmark suite. One command builds a Rojo place,
runs it inside Roblox Studio with `run-in-roblox`, renders the results as a
Markdown table, and uploads the report to
[paste.shellworks.dev](https://paste.shellworks.dev).

## Prerequisites

FastCast2 exercises real Roblox APIs (raycasts, `BulkMoveTo`, Actor-based
parallel VMs), so the suite runs inside Studio rather than a standalone Luau
runtime.

1. Install the toolchain (Rojo, Lune, `run-in-roblox`, Selene):
   ```sh
   rokit install
   ```
   `run-in-roblox` can also be installed with `cargo install run-in-roblox`.
2. Make sure Roblox Studio is installed and signed in. The suite opens Studio
   automatically and closes it when finished.

## Run it

```sh
npm test
# or
lune run tests/run.luau
```

Flags:

| Flag | Description |
|------|-------------|
| `--no-upload` | Skip the `paste.shellworks.dev` upload and just print the report |
| `--keep` | Keep the built place in `./build` for manual inspection |

Example: `npm test -- --no-upload`

## What runs

For focused buffer/math regressions and optional direct simulation A/B timing,
see [the hot-path runner](hotpaths/README.md) (`npm run test:hotpaths`).

- **Functional tests** (`tests/src/FunctionalTests.luau`) follow the checklist
  in [`TESTS.md`](../TESTS.md): initialization, raycast/blockcast/spherecast
  firing, every public event, ObjectCache, movement modes, cast manipulation,
  high-fidelity behavior, and the parallel-only extensions
  (`SetFastCastEventsModule`, `SyncChangesToCast`).
- **Benchmarks** (`tests/src/Benchmarks.luau`) run a fixed six-case matrix of
  Serial/Parallel x Raycast/Blockcast/Spherecast, reporting creation and
  cleanup cost plus simulation frame-time percentiles. Adjust projectile count,
  sample duration, and worker count in `Benchmarks.DefaultConfig`.

> **Note:** "Avg frame"/"P95"/"P99" are Heartbeat intervals, so they are
> bounded by Studio's frame rate (about `16.7 ms` at the default 60 FPS cap).
> Use them to compare cases within a single run, not across machines.

The console and the uploaded report both include this table:

```
| Mode | Cast | Create | Avg frame | P95 | P99 | Cleanup |
```

## How it works

```
tests/run.luau            Lune orchestrator (build -> run -> render -> upload)
tests/Entry.luau          run-in-roblox entry script (starts Run mode, relays results)
tests/src/Harness.server  Server bootstrap; runs the suite and publishes JSON
tests/src/Framework       Tiny assertion/runner library
tests/src/FunctionalTests Functional test cases
tests/src/Benchmarks      Benchmark matrix
tests/src/TestEventsModule FastCastEventsModule used by the parallel event test
```

`tests.project.json` mounts `src/` into `ReplicatedStorage` and `tests/src/`
into `ServerScriptService`, so `rojo build tests.project.json` produces the
place used by the runner.
