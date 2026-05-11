# Edge Cases Analysis - FastCast2 Implementation

## Critical Bugs Found

### 1. BaseCastSerial.luau - Double `self` reference (Lines 106, 109)

```lua
-- Line 106 - BUG
local cast = ActiveCastSerial.new(self.self.ParentCaster, castData)

-- Line 109-110 - BUG  
if self.self.Output then
    self.self.Output:Fire("CastFire", cast, Origin, Direction, Velocity, Behavior)
```

**Fix:** Should be `self.ParentCaster` and `self.Output`.

---

### 2. ActiveCastSerial.new() - Missing Event Configs

`ActiveCastSerial.new()` doesn't include these required fields:

```lua
-- Missing from StateInfo:
StateInfo = {
    -- existing fields...
    FastCastEventsConfig = {
        UseLengthChanged = true,
        UseHit = true,
        UsePierced = true,
        UseCastTerminating = true,
        UseCastFire = true
    },
    FastCastEventsModuleConfig = {
        UseLengthChanged = true,
        UseHit = true,
        UsePierced = true,
        UseCastTerminating = true,
        UseCanPierce = true,
        UseCastFire = true
    },
    Behavior = behavior  -- Required by SerialSimulation.Register()
}
```

And RayInfo missing:
```lua
RayInfo = {
    -- existing fields...
    FastCastEventsModule = nil  -- Required
}
```

---

### 3. Motor6D Not Working in Serial Mode

**Issue:** SerialSimulation.Register() checks for `MovementMethod == "Transform"` to connect Motor6D:
```lua
-- SerialSimulation.luau lines 265-269
if cast.RayInfo.MovementMethod == "Transform" then
    Motor6DPool.Initialize()
    castMotor6D[id] = Motor6DPool.Connect(id, cast.RayInfo.CosmeticBulletObject :: any)
end
```

But:
- BaseCastSerial doesn't pass `MovementMethod` in castData (uses default "BulkMoveTo")
- ActiveCastSerial.new() doesn't initialize Motor6D either

**Fix:** Ensure Motor6D pool works properly in Serial mode or remove Transform option.

---

### 4. Duplicate Function Definitions

Both simulation files define functions twice:

**ParallelSimulation.luau:**
- `DispatchEvent` - defined at lines 177-180 AND 216-219
- `DispatchAllEvents` - defined at lines 183-188 AND 222-227

**SerialSimulation.luau:**
- `QueueEvent` defined (line 173-177) but never used

---

### 5. ObjectCache Not Implemented

BaseCastSerial has `self.ObjectCache` but doesn't use it:

```lua
-- BaseCastSerial.luau lines 83-88 (instead of using ObjectCache)
local cosmeticBullet = Behavior.CosmeticBulletTemplate
if cosmeticBullet then
    cosmeticBullet = cosmeticBullet:Clone()
    cosmeticBullet.CFrame = CFrame.new(Origin, Origin + Direction)
    cosmeticBullet.Parent = Behavior.CosmeticBulletContainer
end
```

---

## Missing API Compliance (per docs/api-reference.md)

| API Method | BaseCast | BaseCastSerial | Status |
|------------|----------|----------------|--------|
| GetVelocityCast | ❌ | ❌ | Missing |
| GetAccelerationCast | ❌ | ❌ | Missing |
| GetPositionCast | ❌ | ❌ | Missing |
| SetVelocityCast | ❌ | ❌ | Missing |
| SetAccelerationCast | ❌ | ❌ | Missing |
| SetPositionCast | ❌ | ❌ | Missing |
| AddPositionCast | ❌ | ❌ | Missing |
| AddVelocityCast | ❌ | ❌ | Missing |
| AddAccelerationCast | ❌ | ❌ | Missing |
| SyncChangesToCast | ❌ | ❌ | Missing |
| SetBulkMoveEnabled | ✅ | ⚠️ Empty | BaseCast OK, BaseCastSerial stub |
| SetObjectCacheEnabled | ✅ | ⚠️ Incomplete | BaseCast OK, BaseCastSerial stub |

---

## Summary

### Must Fix (Blocking)
1. **BaseCastSerial** - Fix `self.self` → `self` references
2. **ActiveCastSerial.new()** - Add FastCastEventsConfig, FastCastEventsModuleConfig, Behavior, and FastCastEventsModule

### Should Fix
3. Motor6D initialization in ActiveCastSerial for Transform method
4. Remove duplicate function definitions
5. Implement ObjectCache in BaseCastSerial
6. Add missing cast manipulation methods (Get/Set/Add velocity/position/acceleration)

---

## Parallel vs Serial Differences

| Feature | ParallelSimulation | SerialSimulation |
|---------|-------------------|------------------|
| RunService | PreRender:ConnectParallel | Heartbeat:Connect |
| task.synchronize | Required for visualization | Not needed |
| Motor6D Pool | ✅ Working | ✅ Referenced |
| Auto-start | ✅ Line 667 | ✅ Line 652 |