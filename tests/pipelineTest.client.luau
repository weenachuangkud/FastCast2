--[[
	FastCast2 Pipeline Test — Client-side (parallel caster).

	Requires ReplicatedFirst to be available for VM storage.
	Tests Init, fire, events, terminate, sync, pierce, and lifecycle.

	Drop into StarterPlayerScripts or similar; runs automatically.
--]]

print("Testing starting")

task.wait(5)

local FastCast = require(game:GetService("ReplicatedStorage"):WaitForChild("FastCast2"))
local RunService = game:GetService("RunService")
local RepFirst = game:GetService("ReplicatedFirst")

if not RunService:IsClient() then
	return
end

-- ─── Helpers ───

local function waitFrames(n)
	for _ = 1, n or 5 do
		task.wait(0.1)
	end
end

-- Create a floor for casts to hit
local floor = Instance.new("Part")
floor.Name = "ParallelTestFloor"
floor.Anchored = true
floor.Size = Vector3.new(100, 1, 100)
floor.Position = Vector3.new(0, -0.5, 0)
floor.CanCollide = true
floor.CanQuery = true
floor.Parent = workspace

local testRunId = 0

-- Each test gets its own VM names to avoid cross-test contamination
local function makeVMNames()
	testRunId += 1
	return {
		vmFolderName = "VMs_" .. testRunId,
		vmContainerFolderName = "VMContainers_" .. testRunId,
		vmTemplateName = "VMTemplate_" .. testRunId,
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

-- Create a fresh parallel caster with independent VM names
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

-- ─── Scenarios ───

print(string.rep("=", 60))
print("FastCast2 Client (Parallel) Pipeline Test")
print(string.rep("=", 60))

-- 1. Init + basic fire
test("Parallel Init + RaycastFire + events fire", function()
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

	assert(events.CastFire == true, "CastFire did not fire")
	assert(events.Hit == true, "Hit did not fire")
	assert(events.CastTerminating == true, "CastTerminating did not fire")

	c:Destroy()
	cleanupVMNames({ vn.vmFolderName, vn.vmContainerFolderName })
end)

-- 2. Events set after Init fire
test("Events set after Init fire (parallel dispatcher callback)", function()
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
test("TerminateCast fires CastTerminating in parallel", function()
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

-- 5. GetVelocityCast / SetVelocityCast
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
		assert(newVel.Y < 0, "SetVelocityCast did not change velocity")
		FastCast:TerminateCast(castRef)
	end

	c:Destroy()
	cleanupVMNames({ vn.vmFolderName, vn.vmContainerFolderName })
end)

-- 6. GetPositionCast / SetPositionCast
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
		assert((newPos - Vector3.new(500, 500, 500)).Magnitude < 0.001, "SetPositionCast did not change position")
		FastCast:TerminateCast(castRef)
	end

	c:Destroy()
	cleanupVMNames({ vn.vmFolderName, vn.vmContainerFolderName })
end)

-- 7. SyncChangesToCast
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
		local ok, _ = pcall(function()
			c:SyncChangesToCast(castRef)
		end)
		assert(ok, "SyncChangesToCast errored")
		FastCast:TerminateCast(castRef)
	end

	c:Destroy()
	cleanupVMNames({ vn.vmFolderName, vn.vmContainerFolderName })
end)

-- 8. CanPierce (parallel) — no module → Hit path
test("No CanPierce module → Hit fires (parallel default)", function()
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

-- 9. Destroy (parallel)
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

-- 10. Double Destroy
test("Double Destroy no error (parallel)", function()
	local vn = makeVMNames()
	local c = newParallelCaster(vn)
	c:Destroy()
	c:Destroy()
	cleanupVMNames({ vn.vmFolderName, vn.vmContainerFolderName })
end)

-- 11. Fire before Init errors
test("Fire before Init errors (parallel)", function()
	local c = FastCast.newParallel()
	local ok = pcall(function()
		c:RaycastFire(Vector3.new(0, 10, 0), Vector3.new(0, -1, 0), 100)
	end)
	assert(not ok, "Fire before Init should error")
end)

-- 12. Double Init warns
test("Double Init warns (parallel)", function()
	local vn = makeVMNames()
	local c = newParallelCaster(vn)
	c:Init(
		2, RepFirst, vn.vmFolderName,
		RepFirst, vn.vmContainerFolderName, vn.vmTemplateName,
		"BulkMoveTo"
	)
	c:Destroy()
	cleanupVMNames({ vn.vmFolderName, vn.vmContainerFolderName })
end)

-- 13. Behavior cloning in parallel context
test("newBehavior deep copy (parallel context)", function()
	local b1 = FastCast.newBehavior()
	local b2 = FastCast.newBehavior()
	b1.MaxDistance = 999
	assert(b2.MaxDistance == 1000, "newBehavior not deep-copied")
end)

-- 14. VisualizeCastSettings stored on cast
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

-- 15. RaycastParams is cloned at fire time
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
		assert(not rawequal(castParams, origParams), "Cast params reference the same object as behavior params")
		assert(castParams.CollisionGroup == "TestGroup", "Cast params did not copy CollisionGroup")
		FastCast:TerminateCast(castRef)
	end

	c:Destroy()
	cleanupVMNames({ vn.vmFolderName, vn.vmContainerFolderName })
end)

-- 16. Cosmetic bullet
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
		assert(castRef.RayInfo.CosmeticBulletObject ~= nil, "CosmeticBulletObject not created")
		assert(castRef.RayInfo.CosmeticBulletObject ~= template, "CosmeticBulletObject is template, not clone")
		FastCast:TerminateCast(castRef)
	end

	template:Destroy()
	container:Destroy()
	c:Destroy()
	cleanupVMNames({ vn.vmFolderName, vn.vmContainerFolderName })
end)

-- 17. AutoIgnoreContainer
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

-- 18. Nil Behavior auto-defaults
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

-- 19. FastCastEventsConfig disables events
test("FastCastEventsConfig disables events (parallel)", function()
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

	assert(not anyFired, "Events fired despite FastCastEventsConfig disabling them (parallel)")

	c:Destroy()
	cleanupVMNames({ vn.vmFolderName, vn.vmContainerFolderName })
end)

-- 20. HighFidelityBehavior = Always
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

	assert(events.CastFire == true, "CastFire did not fire (Always, parallel)")
	assert(events.Hit == true, "Hit did not fire (Always, parallel)")
	assert(events.CastTerminating == true, "CastTerminating did not fire (Always, parallel)")

	c:Destroy()
	cleanupVMNames({ vn.vmFolderName, vn.vmContainerFolderName })
end)

-- 21. Velocity as number
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
	if type(lastVel) == "number" then
		assert(lastVel == 100, "Velocity number changed: " .. tostring(lastVel))
	end

	c:Destroy()
	cleanupVMNames({ vn.vmFolderName, vn.vmContainerFolderName })
end)

-- 22. SetMovementMode
test("SetMovementMode dispatches to VMs (parallel)", function()
	local vn = makeVMNames()
	local c = newParallelCaster(vn)

	local ok, _ = pcall(function()
		c:SetMovementMode("Motor6D", false)
	end)
	assert(ok, "SetMovementMode errored")
	assert(c.MovementMode == "Motor6D", "MovementMode not updated on caster")

	c:Destroy()
	cleanupVMNames({ vn.vmFolderName, vn.vmContainerFolderName })
end)

-- 23. SetMovementMode before Init warns
test("SetMovementMode before Init warns (parallel)", function()
	local c = FastCast.newParallel()
	local ok = pcall(function()
		c:SetMovementMode("BulkMoveTo", true)
	end)
	assert(ok, "SetMovementMode before Init errored")
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
