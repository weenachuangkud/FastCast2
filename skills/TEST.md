# FastCast2 Test Plan

## Four Configurations

Every test scenario should run across all relevant configurations:

| Label | Script Type | RunService Event | Caster Kind | Worker |
|-------|-------------|------------------|-------------|--------|
| SerialServer | `Script` | `Heartbeat` | `FastCast.new()` | Main thread |
| SerialClient | `LocalScript` | `PreSimulation` | `FastCast.new()` | Main thread |
| ParallelServer | `Script` | `Heartbeat:ConnectParallel` | `FastCast.newParallel()` | Actor VM (ServerVM) |
| ParallelClient | `LocalScript` | `PreSimulation:ConnectParallel` | `FastCast.newParallel()` | Actor VM (ClientVM) |

**Core simulation** is identical across all four — only event delivery differs (direct call vs Output BindableEvent). Each test should verify the same behavioral assertions regardless of config.

---

## Recommended Runner Structure

```lua
local UnitTest = {
    -- Key: test name, Value: function + list of configs to run on
    ["Basic raycast fires Hit"] = {
        fn = function(caster) ... end,
        configs = { "SerialServer", "SerialClient", "ParallelServer", "ParallelClient" },
    },
    -- ...
}

-- Filter + loop
local function run(configLabel)
    local PASS, FAIL = 0, 0
    for name, entry in UnitTest do
        if table.find(entry.configs, configLabel) then
            local ok, err = xpcall(entry.fn, debug.traceback, makeCaster(configLabel))
            if ok then PASS += 1 else FAIL += 1 end
        end
    end
    print(("%s: %d passed, %d failed"):format(configLabel, PASS, FAIL))
end
```

This avoids copying scenarios 4× and lets you run one config at a time in Studio.

---

## Test Scenarios

### 1. Construction & Init

| # | Name | Configs | What to assert |
|---|------|---------|----------------|
| 1 | `new` returns serial caster | All | returned table has __index = FastCastSerial |
| 2 | `newParallel` returns parallel caster | All | returned table has __index = FastCastParallel |
| 3 | Serial Init accepts "BulkMoveTo" | SrvS, CliS | AlreadyInit = true, no errors |
| 4 | Serial Init accepts "Motor6D" | SrvS, CliS | Same |
| 5 | Parallel Init creates actors | SrvP, CliP | Dispatcher exists, N actors created |
| 6 | Double Init warns + idempotent | All | warn() fires, second call no-ops |
| 7 | Fire before Init errors | All | error raised, cast not dispatched |

### 2. Fire Methods (3 cast types)

| # | Name | Configs | What to assert |
|---|------|---------|----------------|
| 8 | RaycastFire → CastFire fires | All | CastFire callback invoked with (cast, origin, dir, vel, behavior) |
| 9 | BlockcastFire → CastFire fires | All | Same, CastVariant has Size |
| 10 | SpherecastFire → CastFire fires | All | Same, CastVariant has Radius |
| 11 | Raycast → Hit on collision | All | Hit fires with RaycastResult.Instance = hit part |
| 12 | Blockcast → Hit | All | Same |
| 13 | Spherecast → Hit | All | Same |

### 3. Event Suppression (FastCastEventsConfig)

| # | Name | Configs | What to assert |
|---|------|---------|----------------|
| 14 | UseCastFire=false suppresses CastFire | All | CastFire callback never called |
| 15 | UseHit=false suppresses Hit | All | Hit callback never called |
| 16 | UseLengthChanged=true fires LengthChanged | All | LengthChanged callback invoked each frame |
| 17 | UseLengthChanged=false (default) suppresses it | All | LengthChanged not called |
| 18 | UsePierced=false suppresses Pierced | All | Pierced not called even when CanPierce returns true |
| 19 | UseCanPierce=false skips CanPierce check | All | CanPierce not called, treated as non-pierceable |
| 20 | UseCastTerminating=false suppresses final callback | All | CastTerminating not called (cast still terminates) |

### 4. CanPierce

| # | Name | Configs | What to assert |
|---|------|---------|----------------|
| 21 | CanPierce=nil → Hit fires, no Pierced | All | Normal hit behavior |
| 22 | CanPierce returns false → Hit fires | All | Hit invoked, Pierced not invoked |
| 23 | CanPierce returns true → Pierced N times, then Hit | All | 2+ pierces through walls, final Hit on floor, CastTerminating fires |

### 5. Cast Trajectory Utilities

| # | Name | Configs | What to assert |
|---|------|---------|----------------|
| 24 | GetVelocityCast returns initial velocity | All | matches direction * speed |
| 25 | SetVelocityCast changes velocity mid-flight | All | new velocity = returned by GetVelocityCast |
| 26 | AddVelocityCast adds to velocity | All | returned vel = old vel + added |
| 27 | GetPositionCast returns current position | All | matches trajectory.Position |
| 28 | SetPositionCast teleports cast | All | new pos = returned by GetPositionCast |
| 29 | AddPositionCast offsets cast | All | new pos = old pos + offset |
| 30 | GetAccelerationCast returns acceleration | All | matches behavior.Acceleration |
| 31 | SetAccelerationCast changes acceleration | All | new accel = returned |
| 32 | AddAccelerationCast adds to acceleration | All | returned accel = old + added |

### 6. TerminateCast

| # | Name | Configs | What to assert |
|---|------|---------|----------------|
| 33 | TerminateCast fires CastTerminating | All | callback invoked |
| 34 | Double TerminateCast no-ops | All | second call does not error |
| 35 | TerminateCast preserves StateInfo/RayInfo for reads | All | GetPositionCast/GetVelocityCast work after termination |

### 7. Destroy

| # | Name | Configs | What to assert |
|---|------|---------|----------------|
| 36 | Destroy nils events and removes metatable | All | events ~= nil before, nil after; getmetatable returns nil |
| 37 | Double Destroy no-ops | All | second call does not error |
| 38 | Using caster after Destroy errors | All | method call errors (no __index) |

### 8. Movement Modes

| # | Name | Configs | What to assert |
|---|------|---------|----------------|
| 39 | BulkMoveTo moves cosmetic part each frame | All | part.CFrame changes each heartbeat |
| 40 | Motor6D attaches cosmetic part via Transform | All | motor6D.Transform changes each heartbeat |
| 41 | Toggle mode mid-flight | All | switch works, cast continues |

### 9. ObjectCache

| # | Name | Configs | What to assert |
|---|------|---------|----------------|
| 42 | Cache enabled → cosmetic part from cache pool | All | part is already parented, not freshly cloned |
| 43 | SetObjectCacheEnabled(true) with Template | All | ObjectCacheInstance created |
| 44 | SetObjectCacheEnabled(false) disables cache | All | falls back to direct Clone |

### 10. CosmeticBullet & AutoIgnoreContainer

| # | Name | Configs | What to assert |
|---|------|---------|----------------|
| 45 | Template set → part cloned, properties correct | All | part exists, CanTouch/CanCollide/CanQuery = false |
| 46 | No template → no cosmetic part | All | CosmeticBulletObject is nil |
| 47 | AutoIgnoreContainer=true adds container to filter | All | FilterDescendantsInstances includes container |
| 48 | AutoIgnoreContainer=false does not | All | FilterDescendantsInstances excludes container |

### 11. Behavior Properties

| # | Name | Configs | What to assert |
|---|------|---------|----------------|
| 49 | Acceleration modifies trajectory | All | cast curves, position/velocity reflects acceleration |
| 50 | MaxDistance fires Hit at limit | All | cast reaches MaxDistance, Hit fires, CastTerminating fires |
| 51 | Velocity as number → direction * number | All | actual velocity = direction.Unit * number |
| 52 | newBehavior returns independent copy | All | modifying copy does not change defaults |
| 53 | RaycastParams cloned, not shared | All | `~=` (or rawequal for reference) |
| 54 | Nil Behavior auto-fills defaults | All | all fields have default values |

### 12. HighFidelityBehavior

| # | Name | Configs | What to assert |
|---|------|---------|----------------|
| 55 | Default: single segment per frame | All | no subdivision |
| 56 | Automatic: sub-segments on hit | All | after hit detected, sub-segments fire, accurate hit |
| 57 | Always: every frame subdivided | All | all segments fired, Hit fires at exact contact point |

### 13. Edge Cases

| # | Name | Configs | What to assert |
|---|------|---------|----------------|
| 58 | Zero velocity cast | All | cast does not move; Hit fires at origin? (document behavior) |
| 59 | Zero MaxDistance | All | cast terminates immediately / fires Hit at origin |
| 60 | FilterDescendantsInstances prevents self-hit | All | filtered parts are ignored |
| 61 | Multiple simultaneous casts | All | each cast has independent state |
| 62 | Events set after Init via __newindex | All | forwarded to simulation, fire on next cast |
| 63 | UserData survives lifecycle | All | cast.UserData accessible in all callbacks |

### 14. Parallel-Specific

| # | Name | Configs | What to assert |
|---|------|---------|----------------|
| 64 | Multiple workers process casts round-robin | SrvP, CliP | casts distributed across actors, no conflicts |
| 65 | SetFastCastEventsModule invokes module | SrvP, CliP | module functions called (non-parallel-compatible) |
| 66 | SyncChangesToCast after SetVelocityCast | SrvP, CliP | changes reflected in simulation output |

### 15. Serial-Specific

| # | Name | Configs | What to assert |
|---|------|---------|----------------|
| 67 | Events stored directly on caster, functional post-Init | SrvS, CliS | events fire normally, cleared on Destroy |

---

## Frequently Failing Patterns (from real debugging)

These are the bugs we've already fixed — regression-test them:

| Bug | Root cause | Fix location |
|-----|------------|-------------|
| **Double Destroy errors** | `Destroy` referenced via `__index` after `setmetatable(nil)` | `init.luau:572-590` stash no-op before removing metatable |
| **ActivesRef nil in serial pierce** | uses module-level `ActivesRef` instead of `self.ActivesRef` | `SerialSimulation.luau:603,671` |
| **RaycastParams `~=` compares by value** | `RaycastParams` has `__eq`, use `rawequal` for identity check | `pipelineTest: rawequal(castParams, behaviorParams)` |
| **TerminateCast clears fields needed for post-completion reads** | `for k,_ in cast do cast[k]=nil end` destroys everything | `SerialSimulation.luau:128-150` preserve StateInfo/RayInfo/ID/CFrame/Caster/Type/CastVariant/UserData |
| **CanPierce=true never fires Hit** | Parametric trajectory not reset after pierce — next frame starts from origin trajectory position, skipping objects | `SerialSimulation.luau:736-738` reset Origin/Position/StartTime to hit point |

---

## What NOT to Test

| Feature | Reason |
|---------|--------|
| VisualizeCasts / VisualizeCastSettings | Visual-only, hard to assert deterministically |
| Exact frame timing | `task.wait(0.1)` is approximate |
| Motor6D visual movement | Requires RenderStepped, visual assertion only |
| Network replication | Out of scope — FastCast doesn't handle networking |
| HighFidelity=Always with many segments | Slow, limited value |

---

## Notes

- **Floor part** (tests/pipelineTest.server.luau line ~51): Persistent `floor` at (0, -0.5, 0) shared by all server tests. Client test has its own at same position.
- **waitFrames(N)**: `task.wait(0.1)` × N — at speed 500, cast travels ~50 studs/frame.
- **CanPierce signature**: `(cast, result: RaycastResult, segmentVelocity, cosmeticBullet?) -> boolean`. Use `result.Instance` to identify hit parts.
- **Trajectory reset after pierce**: `casts_Trajectory[id].Origin = point`, `.Position = point`, `.StartTime = casts_TotalRunTime[id]` — required to prevent teleport-skip.
