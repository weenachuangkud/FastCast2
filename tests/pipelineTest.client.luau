--[[
	FastCast2 Pipeline Test — Client-side (parallel caster).

	Tests rely on the actual source flow:
	- BaseCastParallel (module-level state, per-VM)
	- ParallelSimulation (module-level SoA, ConnectParallel)
	- Dispatcher callback → self[signalName](...) in init.luau:258-267

	Drop into StarterPlayerScripts; runs automatically.
--]]

local FastCast = require(game:GetService("ReplicatedStorage"):WaitForChild("FastCast2"))
local RunService = game:GetService("RunService")
local RepFirst = game:GetService("ReplicatedFirst")

if not RunService:IsClient() then
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
	for _ = 1, n or 5 do
		task.wait(0.1)
	end
end

-- Floor for casts to hit
local floor = Instance.new("Part")
floor.Name = "ParallelTestFloor"
floor.Anchored = true
floor.Size = Vector3.new(100, 1, 100)
floor.Position = Vector3.new(0, -0.5, 0)
floor.CanCollide = true
floor.CanQuery = true
floor.Parent = workspace

local testRunId = 0

local function makeVMNames()
	testRunId += 1
	return {
		vmFolderName = "PTestVMs_" .. testRunId,
		vmContainerFolderName = "PTestContainers_" .. testRunId,
		vmTemplateName = "PTestTemplate_" .. testRunId,
	}
end

local function cleanupVMNames(names)
	for _, name in ipairs(names) do
		local obj = RepFirst:FindFirstChild(name)
		if obj then
			obj:Destroy()
		end
	end
end

local function newParallelCaster(vmNames)
	local caster = FastCast.newParallel()
	caster:Init(
		2,
		RepFirst, vmNames.vmFolderName,
		RepFirst, vmNames.vmContainerFolderName,
		vmNames.vmTemplateName,
		"BulkMoveTo"
	)
	return caster
end

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
print("FastCast2 Client (Parallel) Pipeline Test")
print(string.rep("=", 60))

-- 1. Init + basic fire + all events
--    init.luau:258-267: Dispatcher callback calls self[signalName](...)
--    BaseCastParallel:180-182: CastFire via Output:Fire("CastFire", ...)
--    ParallelSimulation: FireQueuedEvents (line 380-391) fires Hit via Output:Fire
--    ParallelSimulation TerminateCast (line 142-157): fires CastTerminating via Output:Fire
test("Init + RaycastFire + CastFire/Hit/CastTerminating fire", function()
	local vn = makeVMNames()
	local c = newParallelCaster(vn)

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
	waitFrames(8)

	assert(events.CastFire, "CastFire did not fire")
	assert(events.Hit, "Hit did not fire")
	assert(events.CastTerminating, "CastTerminating did not fire")

	c:Destroy()
	cleanupVMNames({ vn.vmFolderName, vn.vmContainerFolderName })
end)

-- 2. Events set after Init (parallel uses Dispatcher callback, not __newindex)
--    init.luau:258-267: callback checks self[signalName], calls if function
test("Events set after Init fire via Dispatcher callback", function()
	local vn = makeVMNames()
	local c = newParallelCaster(vn)

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
	waitFrames(8)

	assert(fireFired, "CastFire set after Init did not fire")
	assert(hitFired, "Hit set after Init did not fire")
	assert(termFired, "CastTerminating set after Init did not fire")

	c:Destroy()
	cleanupVMNames({ vn.vmFolderName, vn.vmContainerFolderName })
end)

-- 3. FastCast:TerminateCast parallel path
--    init.luau:774-779: detects caster.Output, fires Output:Fire("CastTerminating") if UseCastTerminating,
--    then ActiveCastCleaner:Fire(cast.ID)
test("FastCast:TerminateCast fires CastTerminating in parallel", function()
	local vn = makeVMNames()
	local c = newParallelCaster(vn)

	local castRef = nil
	local termFired = false
	c.CastFire = function(cast)
		castRef = cast
	end
	c.CastTerminating = function()
		termFired = true
	end
	c.Hit = function() end

	fire(c, Vector3.new(0, 50, 0), Vector3.new(0, 0, 1), 500)
	waitFrames(3)

	if castRef then
		FastCast:TerminateCast(castRef)
		waitFrames(2)
		assert(termFired, "CastTerminating did not fire after TerminateCast (parallel)")
	end

	c:Destroy()
	cleanupVMNames({ vn.vmFolderName, vn.vmContainerFolderName })
end)

-- 4. Double TerminateCast
--    init.luau:770: early return when cast.Caster is nil
test("Double TerminateCast no error (parallel)", function()
	local vn = makeVMNames()
	local c = newParallelCaster(vn)

	local castRef = nil
	c.CastFire = function(cast)
		castRef = cast
	end
	c.Hit = function() end
	c.CastTerminating = function() end

	fire(c, Vector3.new(0, 10, 0), Vector3.new(0, -1, 0), 100)
	waitFrames(2)

	if castRef then
		FastCast:TerminateCast(castRef)
		FastCast:TerminateCast(castRef)
	end

	c:Destroy()
	cleanupVMNames({ vn.vmFolderName, vn.vmContainerFolderName })
end)

-- 5. PauseCast: StateInfo.Paused = true → UpdateCasts skips
test("PauseCast prevents hit in parallel", function()
	local vn = makeVMNames()
	local c = newParallelCaster(vn)

	local castRef = nil
	local hitFired = false
	c.CastFire = function(cast)
		castRef = cast
	end
	c.Hit = function()
		hitFired = true
	end
	c.CastTerminating = function() end

	fire(c, Vector3.new(0, 10, 0), Vector3.new(0, -1, 0), 50)
	waitFrames(2)

	if castRef then
		FastCast:PauseCast(castRef, true)
		waitFrames(5)
		assert(not hitFired, "Hit fired while paused (parallel)")
		FastCast:TerminateCast(castRef)
	end

	c:Destroy()
	cleanupVMNames({ vn.vmFolderName, vn.vmContainerFolderName })
end)

-- 6. Resume after pause
test("Resumed cast after pause hits", function()
	local vn = makeVMNames()
	local c = newParallelCaster(vn)

	local castRef = nil
	local hitFired = false
	c.CastFire = function(cast)
		castRef = cast
	end
	c.Hit = function()
		hitFired = true
	end
	c.CastTerminating = function() end

	fire(c, Vector3.new(0, 10, 0), Vector3.new(0, -1, 0), 50)
	waitFrames(2)

	if castRef then
		FastCast:PauseCast(castRef, true)
		waitFrames(3)
		FastCast:PauseCast(castRef, false)
		waitFrames(5)
		assert(hitFired, "Hit did not fire after resume (parallel)")
		if castRef.Caster then
			FastCast:TerminateCast(castRef)
		end
	end

	c:Destroy()
	cleanupVMNames({ vn.vmFolderName, vn.vmContainerFolderName })
end)

-- 7. GetVelocityCast / SetVelocityCast (same API as serial, uses ModifyTransformation)
test("GetVelocityCast and SetVelocityCast (parallel)", function()
	local vn = makeVMNames()
	local c = newParallelCaster(vn)

	local castRef = nil
	c.CastFire = function(cast)
		castRef = cast
	end
	c.Hit = function() end
	c.CastTerminating = function() end

	fire(c, Vector3.new(0, 10, 0), Vector3.new(0, -1, 0), 100)
	waitFrames(2)

	if castRef then
		local vel = FastCast:GetVelocityCast(castRef)
		assert(vel ~= nil, "GetVelocityCast returned nil")

		FastCast:SetVelocityCast(castRef, Vector3.new(0, -200, 0))
		local newVel = FastCast:GetVelocityCast(castRef)
		assert(newVel.Y == -200,
			"SetVelocityCast after ModifyTransformation: expected Y=-200, got " .. tostring(newVel.Y))
		FastCast:TerminateCast(castRef)
	end

	c:Destroy()
	cleanupVMNames({ vn.vmFolderName, vn.vmContainerFolderName })
end)

-- 8. GetPositionCast / SetPositionCast
test("GetPositionCast and SetPositionCast (parallel)", function()
	local vn = makeVMNames()
	local c = newParallelCaster(vn)

	local castRef = nil
	c.CastFire = function(cast)
		castRef = cast
	end
	c.Hit = function() end
	c.CastTerminating = function() end

	fire(c, Vector3.new(0, 10, 0), Vector3.new(0, -1, 0), 100)
	waitFrames(2)

	if castRef then
		local pos = FastCast:GetPositionCast(castRef)
		assert(pos ~= nil, "GetPositionCast returned nil")

		FastCast:SetPositionCast(castRef, Vector3.new(500, 500, 500))
		local newPos = FastCast:GetPositionCast(castRef)
		assert((newPos - Vector3.new(500, 500, 500)).Magnitude < 0.001,
			"SetPositionCast did not change position")
		FastCast:TerminateCast(castRef)
	end

	c:Destroy()
	cleanupVMNames({ vn.vmFolderName, vn.vmContainerFolderName })
end)

-- 9. SyncChangesToCast — fires SyncChange BindableEvent
--    init.luau:753-757: cast.Caster.SyncChange:Fire(cast)
--    BaseCastParallel:110-135: SyncChanges handler merges trajectory/state from main thread cast into VM's copy
test("SyncChangesToCast fires without error", function()
	local vn = makeVMNames()
	local c = newParallelCaster(vn)

	local castRef = nil
	c.CastFire = function(cast)
		castRef = cast
	end
	c.Hit = function() end
	c.CastTerminating = function() end

	fire(c, Vector3.new(0, 10, 0), Vector3.new(0, -1, 0), 100)
	waitFrames(2)

	if castRef then
		FastCast:SetVelocityCast(castRef, Vector3.new(100, 0, 0))
		local ok, err = pcall(function()
			c:SyncChangesToCast(castRef)
		end)
		assert(ok, "SyncChangesToCast errored: " .. tostring(err))
		FastCast:TerminateCast(castRef)
	end

	c:Destroy()
	cleanupVMNames({ vn.vmFolderName, vn.vmContainerFolderName })
end)

-- 10. No FastCastEventsModule → CanPierce is nil → Hit fires (not Pierced)
--     ParallelSimulation:642-647: canPierceCheckfn = FastCastEventsModule.CanPierce or nil
--     Without module, FastCastEvents is nil → CanPierceCheckfn is nil → Hit path
test("No FastCastEventsModule → Hit fires (CanPierce is nil)", function()
	local vn = makeVMNames()
	local c = newParallelCaster(vn)

	local wall = Instance.new("Part")
	wall.Anchored = true
	wall.Size = Vector3.new(10, 0.2, 10)
	wall.Position = Vector3.new(0, 7, 0)
	wall.CanCollide = true
	wall.CanQuery = true
	wall.Parent = workspace

	local hitFired = false
	local piercedFired = false
	c.CastFire = function() end
	c.Hit = function()
		hitFired = true
	end
	c.Pierced = function()
		piercedFired = true
	end
	c.CastTerminating = function() end

	local b = defaultBehavior()
	fire(c, Vector3.new(0, 15, 0), Vector3.new(0, -1, 0), 500, b)
	waitFrames(6)

	assert(hitFired, "Hit did not fire (parallel, no CanPierce module)")
	assert(not piercedFired, "Pierced fired without CanPierce module")

	wall:Destroy()
	c:Destroy()
	cleanupVMNames({ vn.vmFolderName, vn.vmContainerFolderName })
end)

-- 11. Destroy (parallel): nils events, destroys Dispatcher → sends "Destroy" to all VMs
--     init.luau:583-592
test("Destroy nils events and dispatcher (parallel)", function()
	local vn = makeVMNames()
	local c = newParallelCaster(vn)
	c:Destroy()

	assert(c.CastFire == nil, "CastFire not nil after Destroy")
	assert(c.Hit == nil, "Hit not nil after Destroy")
	assert(c.Pierced == nil, "Pierced not nil after Destroy")
	assert(c.CastTerminating == nil, "CastTerminating not nil after Destroy")
	assert(c.LengthChanged == nil, "LengthChanged not nil after Destroy")
	assert(getmetatable(c) == nil, "Metatable not removed after Destroy")

	cleanupVMNames({ vn.vmFolderName, vn.vmContainerFolderName })
end)

-- 12. Double Destroy
test("Double Destroy no error (parallel)", function()
	local vn = makeVMNames()
	local c = newParallelCaster(vn)
	c:Destroy()
	c:Destroy()
	cleanupVMNames({ vn.vmFolderName, vn.vmContainerFolderName })
end)

-- 13. Fire before Init errors (init.luau:312-314)
test("Fire before Init errors (parallel)", function()
	local c = FastCast.newParallel()
	local ok, err = pcall(function()
		c:RaycastFire(Vector3.new(0, 10, 0), Vector3.new(0, -1, 0), 100)
	end)
	assert(not ok, "Fire before Init should error")
	assert(tostring(err):find("Init") ~= nil, "Error message should mention Init")
end)

-- 14. Double Init warns
test("Double Init warns (parallel)", function()
	local vn = makeVMNames()
	local c = newParallelCaster(vn)
	-- Second Init should warn and return early
	local ok, err = pcall(function()
		c:Init(
			2, RepFirst, vn.vmFolderName,
			RepFirst, vn.vmContainerFolderName, vn.vmTemplateName,
			"BulkMoveTo"
		)
	end)
	assert(ok, "Second Init errored: " .. tostring(err))
	c:Destroy()
	cleanupVMNames({ vn.vmFolderName, vn.vmContainerFolderName })
end)

-- 15. newBehavior deep copy
test("newBehavior deep copy (parallel context)", function()
	local b1 = FastCast.newBehavior()
	local b2 = FastCast.newBehavior()
	b1.MaxDistance = 999
	assert(b2.MaxDistance == 1000, "newBehavior not deep-copied")
end)

-- 16. VisualizeCastSettings stored on cast
--     ActiveCast.luau:81: cast.StateInfo.VisualizeCastSettings = behavior.VisualizeCastSettings
test("VisualizeCastSettings stored on cast (parallel)", function()
	local vn = makeVMNames()
	local c = newParallelCaster(vn)

	local castRef = nil
	c.CastFire = function(cast)
		castRef = cast
	end
	c.Hit = function() end
	c.CastTerminating = function() end

	local b = defaultBehavior()
	b.VisualizeCasts = true
	b.VisualizeCastSettings.Debug_HitColor = Color3.fromRGB(255, 0, 255)
	fire(c, Vector3.new(0, 10, 0), Vector3.new(0, -1, 0), 100, b)
	waitFrames(3)

	if castRef then
		assert(castRef.StateInfo.VisualizeCastSettings ~= nil,
			"VisualizeCastSettings not stored on cast")
		FastCast:TerminateCast(castRef)
	end

	c:Destroy()
	cleanupVMNames({ vn.vmFolderName, vn.vmContainerFolderName })
end)

-- 17. RaycastParams cloned at fire time (ActiveCast.luau:85)
test("RaycastParams cloned at fire time (parallel)", function()
	local vn = makeVMNames()
	local c = newParallelCaster(vn)

	local origParams = RaycastParams.new()
	origParams.CollisionGroup = "TestGroup"

	local castRef = nil
	c.CastFire = function(cast)
		castRef = cast
	end
	c.Hit = function() end
	c.CastTerminating = function() end

	local b = defaultBehavior()
	b.RaycastParams = origParams
	fire(c, Vector3.new(0, 10, 0), Vector3.new(0, -1, 0), 100, b)
	waitFrames(2)

	if castRef then
		local castParams = castRef.RayInfo.Parameters
		assert(castParams ~= origParams,
			"Cast params reference the same object as behavior params")
		assert(castParams.CollisionGroup == "TestGroup",
			"Cast params did not copy CollisionGroup")
		FastCast:TerminateCast(castRef)
	end

	c:Destroy()
	cleanupVMNames({ vn.vmFolderName, vn.vmContainerFolderName })
end)

-- 18. Cosmetic bullet: template cloned, parented to container (ActiveCast.luau:124-131)
test("Cosmetic bullet created (parallel)", function()
	local vn = makeVMNames()
	local c = newParallelCaster(vn)

	local template = Instance.new("Part")
	template.Name = "ParCosmetic"
	template.Anchored = true
	template.Size = Vector3.new(0.5, 0.5, 0.5)
	template.CanCollide = false
	template.CanQuery = false
	template.CanTouch = false
	template.Parent = workspace

	local container = Instance.new("Folder")
	container.Name = "ParCosmeticContainer"
	container.Parent = workspace

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
	waitFrames(3)

	if castRef then
		local bullet = castRef.RayInfo.CosmeticBulletObject
		assert(bullet ~= nil, "CosmeticBulletObject not created")
		assert(bullet ~= template, "CosmeticBulletObject is template, not clone")
		FastCast:TerminateCast(castRef)
	end

	template:Destroy()
	container:Destroy()
	c:Destroy()
	cleanupVMNames({ vn.vmFolderName, vn.vmContainerFolderName })
end)

-- 19. AutoIgnoreContainer (ActiveCast.luau:138-144)
test("AutoIgnoreContainer adds container to filter (parallel)", function()
	local vn = makeVMNames()
	local c = newParallelCaster(vn)

	local template = Instance.new("Part")
	template.Name = "ParCosmeticAI"
	template.Anchored = true
	template.Size = Vector3.new(0.5, 0.5, 0.5)
	template.CanCollide = false
	template.CanQuery = false
	template.CanTouch = false
	template.Parent = workspace

	local container = Instance.new("Folder")
	container.Name = "ParCosmeticContainerAI"
	container.Parent = workspace

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
	waitFrames(2)

	if castRef then
		local filter = castRef.RayInfo.Parameters.FilterDescendantsInstances
		local found = false
		for _, inst in filter do
			if inst == container then
				found = true
				break
			end
		end
		assert(found, "Container not in filter despite AutoIgnoreContainer=true")
		FastCast:TerminateCast(castRef)
	end

	template:Destroy()
	container:Destroy()
	c:Destroy()
	cleanupVMNames({ vn.vmFolderName, vn.vmContainerFolderName })
end)

-- 20. Nil Behavior auto-defaults (init.luau:315-317)
test("Nil Behavior auto-defaults (parallel)", function()
	local vn = makeVMNames()
	local c = newParallelCaster(vn)

	local hitFired = false
	c.CastFire = function() end
	c.Hit = function()
		hitFired = true
	end
	c.CastTerminating = function() end

	c:RaycastFire(Vector3.new(0, 10, 0), Vector3.new(0, -1, 0), 100, nil)
	waitFrames(6)

	assert(hitFired, "Hit did not fire with nil Behavior (parallel)")

	c:Destroy()
	cleanupVMNames({ vn.vmFolderName, vn.vmContainerFolderName })
end)

-- 21. FastCastEventsConfig disables events
--     BaseCastParallel:180-182: CastFire gated by UseCastFire
--     ParallelSimulation FireQueuedEvents: Hit gated by UseHit (line 385)
--     ParallelSimulation TerminateCast (line 144): CastTerminating gated by UseCastTerminating
--     All event types in parallel respect the config flags.
test("FastCastEventsConfig disables event dispatch (parallel)", function()
	local vn = makeVMNames()
	local c = newParallelCaster(vn)

	local anyFired = false
	c.CastFire = function()
		anyFired = true
	end
	c.Hit = function()
		anyFired = true
	end
	c.CastTerminating = function()
		anyFired = true
	end
	c.Pierced = function()
		anyFired = true
	end

	local b = FastCast.newBehavior()
	b.FastCastEventsConfig.UseHit = false
	b.FastCastEventsConfig.UseCastTerminating = false
	b.FastCastEventsConfig.UseCastFire = false
	b.FastCastEventsConfig.UseLengthChanged = false
	b.FastCastEventsConfig.UsePierced = false
	b.RaycastParams = RaycastParams.new()
	b.MaxDistance = 500

	fire(c, Vector3.new(0, 10, 0), Vector3.new(0, -1, 0), 100, b)
	waitFrames(6)

	assert(not anyFired,
		"Events fired despite FastCastEventsConfig disabling them (parallel)")
	-- Note: In parallel, TerminateCast (line 144) gates on UseCastTerminating,
	-- so the event callback won't be called. The cast still gets cleaned up
	-- by ActiveCastCleaner:Fire(cast.ID) which runs unconditionally.

	c:Destroy()
	cleanupVMNames({ vn.vmFolderName, vn.vmContainerFolderName })
end)

-- 22. HighFidelityBehavior.Always (3) — parallel path
--     ParallelSimulation:799-891: Always branch subdivides, calls SimluateCast per segment
test("HighFidelity = Always fires all events (parallel)", function()
	local vn = makeVMNames()
	local c = newParallelCaster(vn)

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

	local b = defaultBehavior()
	b.HighFidelityBehavior = FastCast.HighFidelityBehavior.Always
	fire(c, Vector3.new(0, 10, 0), Vector3.new(0, -1, 0), 100, b)
	waitFrames(8)

	assert(events.CastFire, "CastFire did not fire (Always, parallel)")
	assert(events.Hit, "Hit did not fire (Always, parallel)")
	assert(events.CastTerminating, "CastTerminating did not fire (Always, parallel)")

	c:Destroy()
	cleanupVMNames({ vn.vmFolderName, vn.vmContainerFolderName })
end)

-- 23. SetMovementMode dispatches to VMs (init.luau:385-393)
--     Self.MovementMode set synchronously; VMs receive async
test("SetMovementMode (parallel)", function()
	local vn = makeVMNames()
	local c = newParallelCaster(vn)

	local ok, err = pcall(function()
		c:SetMovementMode("Motor6D", false)
	end)
	assert(ok, "SetMovementMode errored: " .. tostring(err))
	assert(c.MovementMode == "Motor6D",
		"MovementMode not updated on caster; got " .. tostring(c.MovementMode))

	c:Destroy()
	cleanupVMNames({ vn.vmFolderName, vn.vmContainerFolderName })
end)

-- 24. SetMovementMode before Init warns (no error)
test("SetMovementMode before Init warns (parallel)", function()
	local c = FastCast.newParallel()
	local ok, err = pcall(function()
		c:SetMovementMode("BulkMoveTo", true)
	end)
	assert(ok, "SetMovementMode before Init should warn, not error: " .. tostring(err))
end)

-- 25. Velocity as number → ActiveCast.luau:68 converts number → direction * velocity
test("Velocity as number (parallel)", function()
	local vn = makeVMNames()
	local c = newParallelCaster(vn)

	local lastVel = nil
	c.CastFire = function(_, _, _, velocity)
		lastVel = velocity
	end
	c.Hit = function() end
	c.CastTerminating = function() end

	fire(c, Vector3.new(0, 10, 0), Vector3.new(0, -1, 0), 100)
	waitFrames(3)

	assert(lastVel ~= nil, "CastFire did not fire, velocity not captured")
	-- velocity is passed as-is to CastFire callback (the number 100)
	assert(lastVel == 100,
		"Velocity number changed; expected 100, got " .. tostring(lastVel))

	c:Destroy()
	cleanupVMNames({ vn.vmFolderName, vn.vmContainerFolderName })
end)

-- 26. LengthChanged event: enabled by default? No — UseLengthChanged=false by default.
--     ParallelSimulation:628 queues LengthChanged; FireQueuedEvents:372 gates on UseLengthChanged
test("LengthChanged fires when UseLengthChanged=true (parallel)", function()
	local vn = makeVMNames()
	local c = newParallelCaster(vn)

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
	waitFrames(6)

	assert(lcFired, "LengthChanged did not fire (UseLengthChanged=true, parallel)")

	c:Destroy()
	cleanupVMNames({ vn.vmFolderName, vn.vmContainerFolderName })
end)

-- ─── Summary ───

print(string.rep("=", 60))
print(("Client (parallel) pipeline: %d passed, %d failed"):format(PASS, FAIL))
print(string.rep("=", 60))

if FAIL > 0 then
	warn("[FASTCAST2 CLIENT] Some tests failed — review warnings above")
else
	print("[FASTCAST2 CLIENT] ALL TESTS PASSED")
end
