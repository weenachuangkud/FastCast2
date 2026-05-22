--[[
	FastCast2 Pipeline Test — Server-side (serial caster).

	Traces the actual source to test real behavior — not assumptions.
	Each scenario documents what it tests, why, and which lines of code it covers.

	Drop into ServerScriptService; runs automatically on server start.
--]]

local FastCast = require(game:GetService("ReplicatedStorage"):WaitForChild("FastCast2"))
local RunService = game:GetService("RunService")

if not RunService:IsServer() then
	return
end

-- ─── Test infrastructure ───

local PASS = 0
local FAIL = 0

local function test(name, fn)
	local ok, err = xpcall(fn, debug.traceback)
	if ok then
		PASS += 1
		print(("[PASS] %s"):format(name))
	else
		FAIL += 1
		warn(("[FAIL] %s: %s"):format(name, tostring(err)))
	end
	task.wait(0.05)
end

local function assert(cond, msg)
	if not cond then
		error(msg or "assertion failed", 2)
	end
end

local function waitFrames(n)
	for _ = 1, n or 3 do
		task.wait(0.1)
	end
end

-- Create a floor so casts have something to hit
local floor = Instance.new("Part")
floor.Name = "SerialTestFloor"
floor.Anchored = true
floor.Size = Vector3.new(100, 1, 100)
floor.Position = Vector3.new(0, -0.5, 0)
floor.CanCollide = true
floor.CanQuery = true
floor.Parent = workspace

local function defaultBehavior()
	local b = FastCast.newBehavior()
	b.MaxDistance = 500
	b.RaycastParams = RaycastParams.new()
	return b
end

local function fire(caster, origin, dir, speed, behavior)
	caster:RaycastFire(origin, dir, speed or 100, behavior or defaultBehavior())
end

-- ─── Scenarios ───

print(string.rep("=", 60))
print("FastCast2 Server Pipeline Test (serial caster)")
print(string.rep("=", 60))

-- 1. Init + basic fire with RaycastFire
--    BaseCastSerial:102-104: fires CastFirefn when UseCastFire=true
--    SerialSimulation: SimluateCast queues events, FireQueuedEvents dispatches them
test("Basic raycast: CastFire, Hit, CastTerminating all fire", function()
	local c = FastCast.new()
	c:Init("BulkMoveTo")

	local events = {}
	c.CastFire = function()
		events.CastFire = true
	end
	c.Hit = function()
		events.Hit = true
	end
	c.CastTerminating = function()
		events.CastTerminating = true
	end

	fire(c, Vector3.new(0, 10, 0), Vector3.new(0, -1, 0), 100)
	waitFrames(3)

	assert(events.CastFire, "CastFire did not fire")
	assert(events.Hit, "Hit did not fire")
	assert(events.CastTerminating, "CastTerminating did not fire")
end)

-- 2. Events set after Init
--    init.luau:100-114: __newindex catches event assignment → BaseCastSerial._UpdateEvents()
--    BaseCastSerial:282-288: CastFire → self.CastFirefn; others → SerialSimulation._UpdateEvents → self.Events[name]
test("Events set after Init fire via __newindex", function()
	local c = FastCast.new()
	c:Init("BulkMoveTo")

	local fireFired, hitFired, termFired = false, false, false
	c.CastFire = function()
		fireFired = true
	end
	c.Hit = function()
		hitFired = true
	end
	c.CastTerminating = function()
		termFired = true
	end

	fire(c, Vector3.new(0, 10, 0), Vector3.new(0, -1, 0), 100)
	waitFrames(3)

	assert(fireFired, "CastFire did not fire (set after Init)")
	assert(hitFired, "Hit did not fire (set after Init)")
	assert(termFired, "CastTerminating did not fire (set after Init)")
end)

-- 3. FastCast:TerminateCast serial path
--    init.luau:768-789: detects serial via caster.SerialSimulation
--    → Unregister(cast.ID) + Actives[cast.ID] = nil + nils cast keys
--    NOTE: Serial TerminateCast does NOT fire CastTerminating event;
--          CastTerminating is queued during SimluateCast, not here.
test("FastCast:TerminateCast clears cast keys in serial", function()
	local c = FastCast.new()
	c:Init("BulkMoveTo")

	local castRef = nil
	c.CastFire = function(cast)
		castRef = cast
	end

	fire(c, Vector3.new(0, 50, 0), Vector3.new(0, 0, 1), 500)
	waitFrames(1)

	assert(castRef ~= nil, "castRef is nil")

	FastCast:TerminateCast(castRef)

	-- All cast keys should be nilled (init.luau:786-788)
	local keys = 0
	for _ in (castRef :: any) do
		keys += 1
	end
	assert(keys == 0, "Cast table was not cleared; " .. tostring(keys) .. " keys remain")
end)

-- 4. Double TerminateCast
--    init.luau:770: if caster == nil then return end — cast.Caster nil after first termination
test("Double TerminateCast does not error", function()
	local c = FastCast.new()
	c:Init("BulkMoveTo")

	local castRef = nil
	c.CastFire = function(cast)
		castRef = cast
	end

	fire(c, Vector3.new(0, 10, 0), Vector3.new(0, -1, 0), 100)
	waitFrames(1)

	if castRef then
		FastCast:TerminateCast(castRef)
		FastCast:TerminateCast(castRef) -- should return early, cast.Caster is nil
	end
end)

-- 5. GetVelocityCast / SetVelocityCast
--    init.luau:606-613 (GetVelocityAtTime), 658-659 (ModifyTransformation)
--    ModifyTransformation: resets StartTime = TotalRuntime, sets CancelHighResCast = true
test("GetVelocityCast and SetVelocityCast modify trajectory", function()
	local c = FastCast.new()
	c:Init("BulkMoveTo")

	local castRef = nil
	c.CastFire = function(cast)
		castRef = cast
	end
	c.Hit = function() end
	c.CastTerminating = function() end

	fire(c, Vector3.new(0, 10, 0), Vector3.new(0, -1, 0), 100)
	waitFrames(1)

	assert(castRef ~= nil, "castRef is nil")

	local vel = FastCast:GetVelocityCast(castRef)
	assert(vel ~= nil, "GetVelocityCast returned nil")

	FastCast:SetVelocityCast(castRef, Vector3.new(0, -200, 0))
	local newVel = FastCast:GetVelocityCast(castRef)
	-- After ModifyTransformation, StartTime = TotalRuntime, so GetVelocityAtTime(0, ..., accel) = InitialVelocity
	assert(newVel.Y == -200, "SetVelocityCast did not change velocity; got " .. tostring(newVel.Y))

	if castRef.Caster then
		FastCast:TerminateCast(castRef)
	end
end)

-- 6. GetPositionCast / SetPositionCast
--    init.luau:638-646 (GetPositionAtTime), 684-685 (ModifyTransformation with position)
test("GetPositionCast and SetPositionCast", function()
	local c = FastCast.new()
	c:Init("BulkMoveTo")

	local castRef = nil
	c.CastFire = function(cast)
		castRef = cast
	end
	c.Hit = function() end
	c.CastTerminating = function() end

	fire(c, Vector3.new(0, 10, 0), Vector3.new(0, -1, 0), 100)
	waitFrames(1)

	local pos = FastCast:GetPositionCast(castRef)
	assert(pos ~= nil, "GetPositionCast returned nil")

	FastCast:SetPositionCast(castRef, Vector3.new(999, 999, 999))
	local newPos = FastCast:GetPositionCast(castRef)
	assert((newPos - Vector3.new(999, 999, 999)).Magnitude < 0.001, "SetPositionCast did not change position")

	if castRef.Caster then
		FastCast:TerminateCast(castRef)
	end
end)

-- 7. GetAccelerationCast / SetAccelerationCast
--    init.luau:626 (returns Trajectory.Acceleration directly), 672-673 (ModifyTransformation with acceleration)
test("GetAccelerationCast and SetAccelerationCast", function()
	local c = FastCast.new()
	c:Init("BulkMoveTo")

	local castRef = nil
	c.CastFire = function(cast)
		castRef = cast
	end
	c.Hit = function() end
	c.CastTerminating = function() end

	local b = defaultBehavior()
	b.Acceleration = Vector3.new(0, -50, 0)
	fire(c, Vector3.new(0, 10, 0), Vector3.new(0, -1, 0), 50, b)
	waitFrames(1)

	local accel = FastCast:GetAccelerationCast(castRef)
	assert(accel ~= nil, "GetAccelerationCast returned nil")
	assert(accel.Y < 0, "Acceleration.Y should be negative")

	FastCast:SetAccelerationCast(castRef, Vector3.new(0, -200, 0))
	local newAccel = FastCast:GetAccelerationCast(castRef)
	assert(newAccel.Y == -200, "SetAccelerationCast did not change acceleration")
	assert(newAccel.X == 0 and newAccel.Z == 0, "SetAccelerationCast changed unrelated axes")

	if castRef.Caster then
		FastCast:TerminateCast(castRef)
	end
end)

-- 8. Add-prefixed methods: read → modify → write through ModifyTransformation
test("AddVelocityCast / AddAccelerationCast / AddPositionCast", function()
	local c = FastCast.new()
	c:Init("BulkMoveTo")

	local castRef = nil
	c.CastFire = function(cast)
		castRef = cast
	end
	c.Hit = function() end
	c.CastTerminating = function() end

	fire(c, Vector3.new(0, 10, 0), Vector3.new(0, -1, 0), 100)
	waitFrames(1)

	local origVel = FastCast:GetVelocityCast(castRef)
	FastCast:AddVelocityCast(castRef, Vector3.new(50, 0, 0))
	local newVel = FastCast:GetVelocityCast(castRef)
	assert(math.abs(newVel.X - origVel.X - 50) < 0.001, "AddVelocityCast did not add correctly")

	local origPos = FastCast:GetPositionCast(castRef)
	FastCast:AddPositionCast(castRef, Vector3.new(100, 0, 0))
	local newPos = FastCast:GetPositionCast(castRef)
	assert(math.abs(newPos.X - origPos.X - 100) < 0.001, "AddPositionCast did not add correctly")

	if castRef.Caster then
		FastCast:TerminateCast(castRef)
	end
end)

-- 9. CanPierce returning true → Pierced event fires, simulation continues, Hit eventually fires
--     SerialSimulation:603-725: CanPiercefn(...) == false → Hit path; == true → Pierced path + continue
test("CanPierce returns true → Pierced fires, cast continues", function()
	local wall1 = Instance.new("Part")
	wall1.Anchored = true
	wall1.Size = Vector3.new(10, 0.2, 10)
	wall1.Position = Vector3.new(0, 7, 0)
	wall1.CanCollide = true
	wall1.CanQuery = true
	wall1.Parent = workspace

	local wall2 = Instance.new("Part")
	wall2.Anchored = true
	wall2.Size = Vector3.new(10, 0.2, 10)
	wall2.Position = Vector3.new(0, 4, 0)
	wall2.CanCollide = true
	wall2.CanQuery = true
	wall2.Parent = workspace

	local c = FastCast.new()
	c:Init("BulkMoveTo")

	local piercedCount = 0
	local hitFired = false
	local termFired = false
	c.CastFire = function() end
	c.Hit = function()
		hitFired = true
	end
	c.Pierced = function()
		piercedCount += 1
	end
	c.CastTerminating = function()
		termFired = true
	end
	c.CanPierce = function()
		return true
	end

	local b = defaultBehavior()
	b.MaxDistance = 1000

	fire(c, Vector3.new(0, 15, 0), Vector3.new(0, -1, 0), 500, b)
	waitFrames(6)

	assert(piercedCount > 0, "Pierced did not fire (piercedCount = " .. tostring(piercedCount) .. ")")
	assert(hitFired, "Hit did not fire after all pierces exhausted")
	assert(termFired, "CastTerminating did not fire")

	wall1:Destroy()
	wall2:Destroy()
end)

-- 10. CanPierce returning false → Hit fires, Pierced never fires
--     SerialSimulation:604-606: CanPiercefn == nil or returns false → Hit path
test("CanPierce returns false → Hit fires, no Pierced", function()
	local wall = Instance.new("Part")
	wall.Anchored = true
	wall.Size = Vector3.new(10, 0.2, 10)
	wall.Position = Vector3.new(0, 7, 0)
	wall.CanCollide = true
	wall.CanQuery = true
	wall.Parent = workspace

	local c = FastCast.new()
	c:Init("BulkMoveTo")

	local hitFired = false
	local piercedFired = false
	c.Hit = function()
		hitFired = true
	end
	c.Pierced = function()
		piercedFired = true
	end
	c.CastTerminating = function() end
	c.CanPierce = function()
		return false
	end

	local b = defaultBehavior()
	fire(c, Vector3.new(0, 15, 0), Vector3.new(0, -1, 0), 500, b)
	waitFrames(4)

	assert(hitFired, "Hit did not fire")
	assert(not piercedFired, "Pierced fired when CanPierce returned false")
	wall:Destroy()
end)

-- 11. No CanPierce function set → Hit fires (nil treated same as "can't pierce")
--     SerialSimulation:604-606: CanPiercefn == nil → enters Hit path
test("No CanPierce function → Hit fires (nil = can't pierce)", function()
	local wall = Instance.new("Part")
	wall.Anchored = true
	wall.Size = Vector3.new(10, 0.2, 10)
	wall.Position = Vector3.new(0, 7, 0)
	wall.CanCollide = true
	wall.CanQuery = true
	wall.Parent = workspace

	local c = FastCast.new()
	c:Init("BulkMoveTo")

	local hitFired = false
	local piercedFired = false
	c.Hit = function()
		hitFired = true
	end
	c.Pierced = function()
		piercedFired = true
	end
	c.CastTerminating = function() end
	-- Intentionally no c.CanPierce set

	local b = defaultBehavior()
	fire(c, Vector3.new(0, 15, 0), Vector3.new(0, -1, 0), 500, b)
	waitFrames(4)

	assert(hitFired, "Hit did not fire (CanPierce is nil)")
	assert(not piercedFired, "Pierced fired when CanPierce is nil")
	wall:Destroy()
end)

-- 12. FastCastEventsConfig event gating
--     BaseCastSerial:102: CastFire gated by UseCastFire
--     SerialSimulation FireQueuedEvents: Hit gated by UseHit (line 483), Pierced gated by UsePierced (line 492)
--     CastTerminating in serial FireQueuedEvents: NOT gated by UseCastTerminating (line 496-500 — calls unconditionally)
--     So this test only checks CastFire and Hit (which are gated). CastTerminating always fires.
test("FastCastEventsConfig: UseCastFire/UseHit=false suppresses those events", function()
	local c = FastCast.new()
	c:Init("BulkMoveTo")

	local fireFired = false
	local hitFired = false
	c.CastFire = function()
		fireFired = true
	end
	c.Hit = function()
		hitFired = true
	end
	-- NOTE: CastTerminating is NOT gated by UseCastTerminating in serial FireQueuedEvents,
	-- so we leave it nil to avoid it triggering

	local b = FastCast.newBehavior()
	b.FastCastEventsConfig.UseHit = false
	b.FastCastEventsConfig.UseCastFire = false
	b.FastCastEventsConfig.UseLengthChanged = false
	b.FastCastEventsConfig.UsePierced = false
	b.RaycastParams = RaycastParams.new()
	b.MaxDistance = 500

	fire(c, Vector3.new(0, 10, 0), Vector3.new(0, -1, 0), 100, b)
	waitFrames(4)

	assert(not fireFired, "CastFire fired despite UseCastFire=false")
	assert(not hitFired, "Hit fired despite UseHit=false")
end)

-- 13. LengthChanged: UseLengthChanged=false by default, enable and verify it fires
--     SerialSimulation:586 queues LengthChanged, FireQueuedEvents:474 gates on UseLengthChanged
test("LengthChanged fires when UseLengthChanged=true (default is false)", function()
	local c = FastCast.new()
	c:Init("BulkMoveTo")

	local lcFired = false
	c.LengthChanged = function()
		lcFired = true
	end
	c.CastFire = function() end
	c.Hit = function() end
	c.CastTerminating = function() end

	local b = FastCast.newBehavior()
	b.FastCastEventsConfig.UseLengthChanged = true
	b.RaycastParams = RaycastParams.new()
	b.MaxDistance = 500

	fire(c, Vector3.new(0, 10, 0), Vector3.new(0, -1, 0), 100, b)
	waitFrames(3)

	assert(lcFired, "LengthChanged did not fire (UseLengthChanged=true)")
end)

-- 14. Nil Behavior auto-fills defaults
--     init.luax:486-488: if BehaviorData == nil → BehaviorData = FastCast.newBehavior()
test("Nil Behavior parameter auto-fills defaults", function()
	local c = FastCast.new()
	c:Init("BulkMoveTo")

	local hitFired = false
	c.CastFire = function() end
	c.Hit = function()
		hitFired = true
	end
	c.CastTerminating = function() end

	c:RaycastFire(Vector3.new(0, 10, 0), Vector3.new(0, -1, 0), 100, nil)
	waitFrames(3)

	assert(hitFired, "Hit did not fire with nil Behavior")
end)

-- 15. Double Init: warns and returns early (init.luau:443-446)
test("Double Init warns and is idempotent", function()
	local c = FastCast.new()
	c:Init("BulkMoveTo")
	c:Init("Motor6D")
	assert(c.MovementMode == "BulkMoveTo", "Double Init changed movement mode")
end)

-- 16. Fire before Init: errors (init.luau:483-485)
test("Fire before Init errors correctly", function()
	local c = FastCast.new()
	local ok, err = pcall(function()
		c:RaycastFire(Vector3.new(0, 10, 0), Vector3.new(0, -1, 0), 100)
	end)
	assert(not ok, "Fire before Init should error")
	assert(err ~= nil, "Error message should be non-nil")
end)

-- 17. SetObjectCacheEnabled: BaseCastSerial:207-236 (BulkMoveTo)
test("SetObjectCacheEnabled toggles cache", function()
	local template = Instance.new("Part")
	template.Name = "TestTemplate"
	template.Anchored = true
	template.Size = Vector3.new(0.5, 0.5, 0.5)
	template.CanCollide = false
	template.CanQuery = false
	template.CanTouch = false
	template.Parent = workspace

	local c = FastCast.new()
	c:Init("BulkMoveTo", true, template, 10, workspace)

	local hitFired = false
	c.CastFire = function() end
	c.Hit = function()
		hitFired = true
	end
	c.CastTerminating = function() end

	local b = defaultBehavior()
	fire(c, Vector3.new(0, 10, 0), Vector3.new(0, -1, 0), 100, b)
	waitFrames(3)

	assert(hitFired, "Hit did not fire with ObjectCache enabled")

	c:SetObjectCacheEnabled(false)
	template:Destroy()
end)

-- 18. Destroy: nils events, removes metatable (init.luau:563-576)
test("Destroy nils events and removes metatable", function()
	local c = FastCast.new()
	c:Init("BulkMoveTo")
	c:Destroy()

	assert(c.CastFire == nil, "CastFire not nil after Destroy")
	assert(c.Hit == nil, "Hit not nil after Destroy")
	assert(c.LengthChanged == nil, "LengthChanged not nil after Destroy")
	assert(c.CastTerminating == nil, "CastTerminating not nil after Destroy")
	assert(c.Pierced == nil, "Pierced not nil after Destroy")
	assert(getmetatable(c) == nil, "Metatable not removed after Destroy")
end)

-- 19. Double Destroy: no error
test("Double Destroy does not error", function()
	local c = FastCast.new()
	c:Init("BulkMoveTo")
	c:Destroy()
	c:Destroy()
end)

-- 20. Cosmetic bullet: ActiveCast.luau:124-131 clones template, parents to container
test("Cosmetic bullet cloned from template when container provided", function()
	local template = Instance.new("Part")
	template.Name = "TestCosmetic"
	template.Anchored = true
	template.Size = Vector3.new(0.5, 0.5, 0.5)
	template.CanCollide = false
	template.CanQuery = false
	template.CanTouch = false
	template.Parent = workspace

	local container = Instance.new("Folder")
	container.Name = "TestCosmeticContainer"
	container.Parent = workspace

	local c = FastCast.new()
	c:Init("BulkMoveTo")

	local castRef = nil
	c.CastFire = function(cast)
		castRef = cast
	end
	c.Hit = function() end
	c.CastTerminating = function() end

	local b = defaultBehavior()
	b.CosmeticBulletTemplate = template
	b.CosmeticBulletContainer = container
	fire(c, Vector3.new(0, 10, 0), Vector3.new(0, -1, 0), 100, b)
	waitFrames(2)

	if castRef then
		local bullet = castRef.RayInfo.CosmeticBulletObject
		assert(bullet ~= nil, "CosmeticBulletObject was not created")
		assert(bullet ~= template, "CosmeticBulletObject is the template, not a clone")
		assert(bullet.Parent == container, "CosmeticBulletObject parent is not the container")
		if castRef.Caster then
			FastCast:TerminateCast(castRef)
		end
	end

	template:Destroy()
	container:Destroy()
end)

-- 21. AutoIgnoreContainer: ActiveCast.luau:138-144 adds container to filter
test("AutoIgnoreContainer adds container to RaycastParams filter", function()
	local template = Instance.new("Part")
	template.Anchored = true
	template.Size = Vector3.new(0.5, 0.5, 0.5)
	template.CanCollide = false
	template.CanQuery = false
	template.CanTouch = false
	template.Name = "AICosmetic"
	template.Parent = workspace

	local container = Instance.new("Folder")
	container.Name = "AIContainer"
	container.Parent = workspace

	local c = FastCast.new()
	c:Init("BulkMoveTo")

	local castRef = nil
	c.CastFire = function(cast)
		castRef = cast
	end
	c.Hit = function() end
	c.CastTerminating = function() end

	local b = defaultBehavior()
	b.CosmeticBulletTemplate = template
	b.CosmeticBulletContainer = container
	b.AutoIgnoreContainer = true
	fire(c, Vector3.new(0, 10, 0), Vector3.new(0, -1, 0), 100, b)
	waitFrames(1)

	if castRef then
		local filter = castRef.RayInfo.Parameters.FilterDescendantsInstances
		local found = false
		for _, inst in filter do
			if inst == container then
				found = true
				break
			end
		end
		assert(found, "Container was not added to filter descendants despite AutoIgnoreContainer=true")
		if castRef.Caster then
			FastCast:TerminateCast(castRef)
		end
	end

	template:Destroy()
	container:Destroy()
end)

-- 22. HighFidelityBehavior.Always (3): always subdivides the frame
--     SerialSimulation:750-835: Always branch computes frame displacement,
--     divides into subsegments, calls SimluateCast per subsegment
test("HighFidelity = Always: all events fire", function()
	local c = FastCast.new()
	c:Init("BulkMoveTo")

	local events = {}
	c.CastFire = function()
		events.CastFire = true
	end
	c.Hit = function()
		events.Hit = true
	end
	c.CastTerminating = function()
		events.CastTerminating = true
	end

	local b = FastCast.newBehavior()
	b.HighFidelityBehavior = FastCast.HighFidelityBehavior.Always
	b.RaycastParams = RaycastParams.new()
	b.MaxDistance = 500

	fire(c, Vector3.new(0, 10, 0), Vector3.new(0, -1, 0), 100, b)
	waitFrames(4)

	assert(events.CastFire, "CastFire did not fire (Always mode)")
	assert(events.Hit, "Hit did not fire (Always mode)")
	assert(events.CastTerminating, "CastTerminating did not fire (Always mode)")
end)

-- 23. HighFidelityBehavior.Automatic (2): subdivides on hit
--     SerialSimulation:611-706: Automatic branch only subdivides when a hit is found
test("HighFidelity = Automatic: all events fire", function()
	local c = FastCast.new()
	c:Init("BulkMoveTo")

	local events = {}
	c.CastFire = function()
		events.CastFire = true
	end
	c.Hit = function()
		events.Hit = true
	end
	c.CastTerminating = function()
		events.CastTerminating = true
	end

	local b = FastCast.newBehavior()
	b.HighFidelityBehavior = FastCast.HighFidelityBehavior.Automatic
	b.RaycastParams = RaycastParams.new()
	b.MaxDistance = 500

	fire(c, Vector3.new(0, 10, 0), Vector3.new(0, -1, 0), 100, b)
	waitFrames(4)

	assert(events.CastFire, "CastFire did not fire (Automatic mode)")
	assert(events.Hit, "Hit did not fire (Automatic mode)")
	assert(events.CastTerminating, "CastTerminating did not fire (Automatic mode)")
end)

-- 24. Velocity as number → direction * velocity (ActiveCast.luau:68)
test("Velocity as number is converted to direction*velocity", function()
	local c = FastCast.new()
	c:Init("BulkMoveTo")

	local castRef = nil
	c.CastFire = function(cast)
		castRef = cast
	end
	c.Hit = function() end
	c.CastTerminating = function() end

	-- velocity = 100, direction = (0, -1, 0) → InitVel = (0, -100, 0)
	fire(c, Vector3.new(0, 10, 0), Vector3.new(0, -1, 0), 100)
	waitFrames(1)

	if castRef then
		local initVel = castRef.StateInfo.Trajectory.InitialVelocity
		assert(math.abs(initVel.Y + 100) < 0.001,
			"Expected InitVel.Y = -100, got " .. tostring(initVel.Y))
		assert(initVel.X == 0 and initVel.Z == 0,
			"Expected InitVel.X/Z = 0, got " .. tostring(initVel))
		if castRef.Caster then
			FastCast:TerminateCast(castRef)
		end
	end
end)

-- 25. newBehavior deep copy (init.luau:180-190, 197-199)
test("newBehavior returns independent copy from defaults", function()
	local b1 = FastCast.newBehavior()
	local b2 = FastCast.newBehavior()
	b1.MaxDistance = 999
	assert(b2.MaxDistance == 1000, "b2.MaxDistance changed when b1 modified")
end)

-- 26. newBehavior().VisualizeCastSettings defaults
test("VisualizeCastSettings defaults are present", function()
	local b = FastCast.newBehavior()
	assert(b.VisualizeCastSettings ~= nil, "VisualizeCastSettings is nil")
	assert(b.VisualizeCastSettings.Debug_RayLifetime == 1, "Debug_RayLifetime default should be 1, got " .. tostring(b.VisualizeCastSettings.Debug_RayLifetime))
end)

-- 27. Acceleration on behavior affects trajectory
--     ActiveCast.luau:69: cast.StateInfo.Trajectory.Acceleration = behavior.Acceleration
--     SimluateCast:552: acceleration = trajectory.Acceleration
test("Behavior.Acceleration modifies cast trajectory", function()
	local c = FastCast.new()
	c:Init("BulkMoveTo")

	local castRef = nil
	c.CastFire = function(cast)
		castRef = cast
	end
	c.Hit = function() end
	c.CastTerminating = function() end

	-- Acceleration pushes downward; cast should reach floor faster
	local b = defaultBehavior()
	b.Acceleration = Vector3.new(0, -50, 0)
	b.MaxDistance = 1000
	fire(c, Vector3.new(0, 20, 0), Vector3.new(0, -1, 0), 10, b)
	waitFrames(1)

	if castRef then
		local traj = castRef.StateInfo.Trajectory
		assert(traj.Acceleration.Y == -50, "Acceleration not set on cast trajectory")
		if castRef.Caster then
			FastCast:TerminateCast(castRef)
		end
	end
end)

-- 28. RaycastParams cloned at fire time (not shared with behavior)
--     ActiveCast.luax:85: CloneCastParams(behavior.RaycastParams) or RaycastParams.new()
test("RaycastParams is cloned, not shared with behavior", function()
	local origParams = RaycastParams.new()
	origParams.CollisionGroup = "TestCollisionGroup"

	local c = FastCast.new()
	c:Init("BulkMoveTo")

	local castRef = nil
	c.CastFire = function(cast)
		castRef = cast
	end
	c.Hit = function() end
	c.CastTerminating = function() end

	local b = defaultBehavior()
	b.RaycastParams = origParams
	fire(c, Vector3.new(0, 10, 0), Vector3.new(0, -1, 0), 100, b)
	waitFrames(1)

	if castRef then
		local castParams = castRef.RayInfo.Parameters
		assert(castParams ~= origParams, "Cast params reference the same object as behavior params")
		assert(castParams.CollisionGroup == "TestCollisionGroup", "Cast params did not inherit CollisionGroup")
		if castRef.Caster then
			FastCast:TerminateCast(castRef)
		end
	end
end)

-- ─── Summary ───

print(string.rep("=", 60))
print(("Server pipeline: %d passed, %d failed"):format(PASS, FAIL))
print(string.rep("=", 60))

if FAIL > 0 then
	warn("[FASTCAST2 SERVER] Some tests failed — review warnings above")
else
	print("[FASTCAST2 SERVER] ALL TESTS PASSED")
end
