--[[
	FastCast2 functional tests.

	These cover the checklist in TESTS.md: initialization, the three cast
	variants, every public event, movement modes, cast manipulation,
	high-fidelity behavior, and trajectory updates.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FastCast = require(ReplicatedStorage:WaitForChild("FastCast2"))
local FastCastEnums = require(ReplicatedStorage.FastCast2:WaitForChild("FastCastEnums"))

local Framework = require(script.Parent.Framework)

local CAST_TYPES = { "Raycast", "Blockcast", "Spherecast" }
local HIT_TIMEOUT = 5

local arenaCounter = 0
local runtimeInitialized = false

local function initializeRuntime()
	if runtimeInitialized then
		return
	end

	FastCast.Init("BulkMoveTo")
	runtimeInitialized = true
end

local function createArena(expect: any): Folder
	arenaCounter += 1
	local arena = Instance.new("Folder")
	arena.Name = "FastCast2TestArena" .. arenaCounter
	arena.Parent = workspace
	expect.cleanup(function()
		if arena.Parent then
			arena:Destroy()
		end
	end)
	return arena
end

local function createWall(parent: Instance, position: Vector3, size: Vector3): Part
	local wall = Instance.new("Part")
	wall.Name = "Wall"
	wall.Anchored = true
	wall.CanCollide = true
	wall.CanQuery = true
	wall.Size = size
	wall.Position = position
	wall.Parent = parent
	return wall
end

local function newCaster(expect: any): any
	local caster = FastCast.new()
	expect.cleanup(function()
		caster:Destroy()
	end)
	return caster
end

local function createContainer(parent: Instance): Folder
	local container = Instance.new("Folder")
	container.Name = "Projectiles"
	container.Parent = parent
	return container
end

local function makeBehavior(container: Instance): any
	local behavior = FastCast.newBehavior()
	behavior.MaxDistance = 1e6
	behavior.Acceleration = Vector3.zero
	behavior.CosmeticBulletContainer = container

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	params.FilterDescendantsInstances = { container }
	behavior.RaycastParams = params

	return behavior
end

local function fire(caster: any, castType: string, origin: Vector3, direction: Vector3, velocity: number, behavior: any)
	if castType == "Blockcast" then
		caster:BlockcastFire(origin, Vector3.one, direction, velocity, behavior)
	elseif castType == "Spherecast" then
		caster:SpherecastFire(origin, 0.5, direction, velocity, behavior)
	else
		caster:RaycastFire(origin, direction, velocity, behavior)
	end
end

-- Retry a boolean-returning attempt a bounded number of times. The callback
-- owns any per-attempt timeout and cleanup, so this helper can be reused by
-- tests with different asynchronous conditions.
local function retry(attempts: number, delayBetweenAttempts: number, runAttempt: (number) -> boolean): boolean
	for attempt = 1, attempts do
		if runAttempt(attempt) then
			return true
		end

		if attempt < attempts then
			task.wait(delayBetweenAttempts)
		end
	end

	return false
end

local function registerSerialCastTypes(test: (string, any) -> ())
	for _, castType in CAST_TYPES do
		test("Serial " .. castType .. " reaches a wall", function(expect)
			local arena = createArena(expect)
			local wall = createWall(arena, Vector3.new(0, 0, -12), Vector3.new(50, 50, 2))
			local container = createContainer(arena)
			local behavior = makeBehavior(container)

			local hitInstance = nil
			local terminated = false
			local castData = nil
			behavior.MaxLifetime = 3
			behavior.HighFidelitySegmentSize = 0.25
			behavior.UserData = { TestTag = castType }

			local caster = newCaster(expect)
			caster.CastFire = function(cast)
				castData = cast
			end
			caster.Hit = function(_, result)
				hitInstance = result.Instance
			end
			caster.CastTerminating = function()
				terminated = true
			end
			initializeRuntime()

			fire(caster, castType, Vector3.new(0, 0, 0), Vector3.new(0, 0, -1), 120, behavior)

			expect.truthy(castData, castType .. " did not expose its cast through CastFire")
			expect.equal(castData.Type, FastCast.CastType[castType], castType .. " cast type was wrong")
			expect.equal(type(castData.ID), "number", castType .. " cast ID was not numeric")
			expect.equal(castData.CasterId, caster.CasterId, castType .. " CasterId was wrong")
			expect.equal(castData.CFrame.Position, Vector3.zero, castType .. " initial CFrame was wrong")
			expect.equal(castData.StateInfo.Trajectory.Origin, Vector3.zero, castType .. " trajectory origin was wrong")
			expect.equal(
				castData.StateInfo.Trajectory.InitialVelocity,
				Vector3.new(0, 0, -120),
				castType .. " initial velocity was wrong"
			)
			expect.equal(castData.StateInfo.Trajectory.Acceleration, behavior.Acceleration, castType .. " acceleration was wrong")
			expect.equal(castData.StateInfo.MaxLifetime, behavior.MaxLifetime, castType .. " MaxLifetime was not copied")
			expect.equal(castData.StateInfo.HighFidelitySegmentSize, 0.25, castType .. " segment size was not copied")
			expect.equal(castData.UserData.TestTag, castType, castType .. " UserData was not copied")
			expect.equal(castData.RayInfo.WorldRoot, workspace, castType .. " WorldRoot was wrong")
			expect.equal(castData.RayInfo.MaxDistance, behavior.MaxDistance, castType .. " MaxDistance was wrong")
			expect.equal(typeof(castData.RayInfo.Parameters), "RaycastParams", castType .. " RaycastParams was missing")
			if castType == "Blockcast" then
				expect.equal(castData.RayInfo.Size, Vector3.one, "Blockcast size was not exposed")
			elseif castType == "Spherecast" then
				expect.equal(castData.RayInfo.Radius, 0.5, "Spherecast radius was not exposed")
			end

			expect.truthy(
				Framework.waitFor(function()
					return hitInstance ~= nil
				end, HIT_TIMEOUT),
				castType .. " never registered a hit"
			)
			expect.equal(hitInstance, wall, castType .. " hit the wrong instance")
			expect.truthy(
				Framework.waitFor(function()
					return terminated
				end, HIT_TIMEOUT),
				castType .. " never terminated after the hit"
			)

			caster:Destroy()
			arena:Destroy()
		end)
	end
end

return function()
	return {
		Framework.describe("FastCastBehavior", function(test)
			test("newBehavior returns the documented defaults", function(expect)
				local behavior = FastCast.newBehavior()
				local events = behavior.FastCastEventsConfig

				expect.equal(behavior.MaxDistance, 1000, "MaxDistance default changed")
				expect.equal(behavior.MaxLifetime, nil, "MaxLifetime should be unlimited by default")
				expect.equal(behavior.MaxPiercesPerStep, 1, "MaxPiercesPerStep default changed")
				expect.near(behavior.Acceleration, Vector3.zero, 1e-6, "Acceleration default changed")
				expect.equal(
					behavior.HighFidelityBehavior,
					FastCastEnums.HighFidelityBehavior.Default,
					"HighFidelityBehavior default changed"
				)
				expect.equal(behavior.HighFidelitySegmentSize, 0.5, "HighFidelitySegmentSize default changed")
				expect.equal(behavior.CosmeticBulletTemplate, nil, "CosmeticBulletTemplate default changed")
				expect.equal(behavior.CosmeticBulletContainer, nil, "CosmeticBulletContainer default changed")
				expect.equal(behavior.AutoIgnoreContainer, true, "AutoIgnoreContainer default changed")
				expect.equal(behavior.CloneTemplate, true, "CloneTemplate should be enabled by default")
				expect.equal(behavior.VisualizeCasts, false, "VisualizeCasts should be disabled by default")
				expect.equal(type(behavior.VisualizeCastSettings), "table", "visualization settings are missing")
				expect.equal(events.UseLengthChanged, false, "LengthChanged should be opt-in")
				expect.equal(events.UseHit, true, "Hit should be enabled by default")
				expect.equal(events.UsePierced, true, "Pierced should be enabled by default")
				expect.equal(events.UseCastTerminating, true, "CastTerminating should be enabled by default")
				expect.equal(events.UseCanPierce, true, "CanPierce should be enabled by default")
				expect.equal(events.UseCastFire, true, "CastFire should be enabled by default")
				expect.equal(events.UseOnStep, false, "OnStep should be opt-in")
			end)

			test("newBehavior returns independent nested configuration", function(expect)
				local first = FastCast.newBehavior()
				local second = FastCast.newBehavior()

				first.FastCastEventsConfig.UseHit = false
				first.VisualizeCastSettings.Debug_SegmentSize = 99

				expect.equal(second.FastCastEventsConfig.UseHit, true, "event config was shared between behaviors")
				expect.truthy(
					second.VisualizeCastSettings.Debug_SegmentSize ~= 99,
					"visualization settings were shared between behaviors"
				)
			end)
		end),

		Framework.describe("FastCastSignal", function(test)
			test("Once, Wait, and DisconnectAll behave as expected", function(expect)
				local caster = newCaster(expect)
				local signal = caster.Hit
				local onceValue = nil
				local waitValue = nil
				local disconnectedCount = 0

				signal:Once(function(value)
					onceValue = value
				end)
				signal:Fire("first")
				signal:Fire("second")
				expect.equal(onceValue, "first", "Once listener fired more than once or missed the first value")

				task.spawn(function()
					waitValue = signal:Wait()
				end)
				task.wait()
				signal:Fire("waited")
				expect.truthy(
					Framework.waitFor(function()
						return waitValue ~= nil
					end, HIT_TIMEOUT),
					"Wait did not resume when the signal fired"
				)
				expect.equal(waitValue, "waited", "Wait returned the wrong value")

				signal:Connect(function()
					disconnectedCount += 1
				end)
				signal:DisconnectAll()
				signal:Fire("after disconnect")
				expect.equal(disconnectedCount, 0, "DisconnectAll left a listener connected")
				caster:Destroy()
			end)
		end),

		Framework.describe("FastCastSerial", function(test)
			test("initializes and destroys", function(expect)
				local caster = newCaster(expect)
				initializeRuntime()

				expect.equal(type(caster.CasterId), "number", "caster did not receive a numeric ID")

				caster:Destroy()
				expect.equal(getmetatable(caster), nil, "destroy did not clear the metatable")
			end)

			test("Stop pauses simulation and Init resumes it", function(expect)
				local arena = createArena(expect)
				local wall = createWall(arena, Vector3.new(0, 0, -12), Vector3.new(50, 50, 2))
				local container = createContainer(arena)
				local behavior = makeBehavior(container)
				local hitInstance = nil

				local caster = newCaster(expect)
				caster.Hit = function(_, result)
					hitInstance = result.Instance
				end
				initializeRuntime()

				FastCast.Stop()
				task.wait(0.1)
				fire(caster, "Raycast", Vector3.zero, Vector3.new(0, 0, -1), 120, behavior)
				task.wait(0.1)
				expect.equal(hitInstance, nil, "cast advanced while simulation was stopped")

				FastCast.Init()
				expect.truthy(
					Framework.waitFor(function()
						return hitInstance ~= nil
					end, HIT_TIMEOUT),
					"cast did not resume after Init"
				)
				expect.equal(hitInstance, wall, "resumed cast hit the wrong instance")

				caster:Destroy()
				arena:Destroy()
			end)

			test("RaycastFire fires CastFire synchronously", function(expect)
				local arena = createArena(expect)
				local container = createContainer(arena)
				local behavior = makeBehavior(container)

				local firedCast = nil
				local caster = newCaster(expect)
				caster.CastFire = function(cast)
					firedCast = cast
				end
				initializeRuntime()

				fire(caster, "Raycast", Vector3.new(0, 0, 0), Vector3.new(0, 0, -1), 60, behavior)

				expect.truthy(firedCast, "CastFire did not run")
				expect.equal(firedCast.Type, FastCastEnums.CastType.Raycast, "wrong cast type")
				expect.equal(firedCast.CFrame.Position, Vector3.new(0, 0, 0), "cast origin is wrong")

				FastCast:TerminateCast(firedCast)
				caster:Destroy()
				arena:Destroy()
			end)

			registerSerialCastTypes(test)

			test("event callbacks assigned after Init still fire", function(expect)
				local arena = createArena(expect)
				local wall = createWall(arena, Vector3.new(0, 0, -12), Vector3.new(50, 50, 2))
				local container = createContainer(arena)
				local behavior = makeBehavior(container)

				local caster = newCaster(expect)
				initializeRuntime()

				local hitInstance = nil
				caster.Hit = function(_, result)
					hitInstance = result.Instance
				end

				fire(caster, "Raycast", Vector3.new(0, 0, 0), Vector3.new(0, 0, -1), 120, behavior)

				expect.truthy(
					Framework.waitFor(function()
						return hitInstance ~= nil
					end, HIT_TIMEOUT),
					"Hit callback assigned after Init never fired"
				)
				expect.equal(hitInstance, wall, "Hit callback fired for the wrong instance")

				caster:Destroy()
				arena:Destroy()
			end)

			test("events are Signals that support multiple listeners and Disconnect", function(expect)
				local arena = createArena(expect)
				local wall = createWall(arena, Vector3.new(0, 0, -12), Vector3.new(50, 50, 2))
				local container = createContainer(arena)
				local behavior = makeBehavior(container)

				local firstCount = 0
				local secondCount = 0

				local caster = newCaster(expect)
				local firstConnection = caster.Hit:Connect(function(_, result)
					if result.Instance == wall then
						firstCount += 1
					end
				end)
				caster.Hit:Connect(function(_, result)
					if result.Instance == wall then
						secondCount += 1
					end
				end)
				initializeRuntime()

				-- A disconnected listener must not receive the event.
				firstConnection:Disconnect()

				fire(caster, "Raycast", Vector3.new(0, 0, 0), Vector3.new(0, 0, -1), 120, behavior)

				expect.truthy(
					Framework.waitFor(function()
						return secondCount > 0
					end, HIT_TIMEOUT),
					"connected Signal listener never fired"
				)
				expect.equal(firstCount, 0, "disconnected Signal listener still fired")

				caster:Destroy()
				arena:Destroy()
			end)

			test("Active casts expose and update PreviousPosition", function(expect)
				local arena = createArena(expect)
				local container = createContainer(arena)
				local behavior = makeBehavior(container)
				local origin = Vector3.new(0, 1000, 0)

				local caster = newCaster(expect)
				initializeRuntime()

				local cast = caster:RaycastFire(origin, Vector3.xAxis, 60, behavior)
				expect.equal(cast.PreviousPosition, origin, "PreviousPosition should start at the cast origin")

				expect.truthy(
					Framework.waitFor(function()
						return cast.PreviousPosition.X > origin.X
					end, HIT_TIMEOUT),
					"PreviousPosition did not advance with the simulated cast"
				)

				FastCast:TerminateCast(cast)
				caster:Destroy()
				arena:Destroy()
			end)

			test("MaxPiercesPerStep checks multiple hits in one movement segment", function(expect)
				local arena = createArena(expect)
				local container = createContainer(arena)
				local firstWall = createWall(arena, Vector3.new(0, 0, -5), Vector3.new(50, 50, 1))
				local secondWall = createWall(arena, Vector3.new(0, 0, -10), Vector3.new(50, 50, 1))
				local finalWall = createWall(arena, Vector3.new(0, 0, -15), Vector3.new(50, 50, 1))
				local behavior = makeBehavior(container)
				behavior.MaxPiercesPerStep = 3
				behavior.HighFidelityBehavior = FastCastEnums.HighFidelityBehavior.Default
				behavior.FastCastEventsConfig.UseOnStep = true

				local stepCount = 0
				local piercedSteps = {}
				local hitInstance = nil
				local hitStep = nil
				local caster = newCaster(expect)
				caster.OnStep = function()
					stepCount += 1
				end
				caster.CanPierce = function(_, result)
					return result.Instance == firstWall or result.Instance == secondWall
				end
				caster.Pierced = function()
					table.insert(piercedSteps, stepCount)
				end
				caster.Hit = function(_, result)
					hitInstance = result.Instance
					hitStep = stepCount
				end
				initializeRuntime()

				caster:RaycastFire(Vector3.zero, Vector3.new(0, 0, -1), 6000, behavior)

				expect.truthy(
					Framework.waitFor(function()
						return hitInstance ~= nil
					end, HIT_TIMEOUT),
					"MaxPiercesPerStep did not continue to the final wall"
				)
				expect.equal(#piercedSteps, 2, "expected exactly two pierce events")
				expect.equal(hitInstance, finalWall, "cast stopped at the wrong wall")
				expect.equal(piercedSteps[1], piercedSteps[2], "pierces occurred in different simulation steps")
				expect.equal(hitStep, piercedSteps[1], "final hit occurred in a different simulation step")

				caster:Destroy()
				arena:Destroy()
			end)

			test("Pierced and CanPierce run when a cast is allowed through", function(expect)
				local arena = createArena(expect)
				local container = createContainer(arena)
				local behavior = makeBehavior(container)
				behavior.MaxDistance = 80

				createWall(arena, Vector3.new(0, 0, -20), Vector3.new(50, 50, 2))

				local piercedCount = 0
				local terminated = false

				local caster = newCaster(expect)
				caster.CanPierce = function()
					return true
				end
				caster.Pierced = function()
					piercedCount += 1
				end
				caster.CastTerminating = function()
					terminated = true
				end
				initializeRuntime()

				fire(caster, "Raycast", Vector3.new(0, 0, 0), Vector3.new(0, 0, -1), 120, behavior)

				expect.truthy(
					Framework.waitFor(function()
						return terminated
					end, HIT_TIMEOUT),
					"cast never terminated"
				)
				expect.greaterThan(piercedCount, 0, "the cast never pierced the wall")

				caster:Destroy()
				arena:Destroy()
			end)

			test("LengthChanged runs when enabled", function(expect)
				local arena = createArena(expect)
				local container = createContainer(arena)
				local behavior = makeBehavior(container)
				behavior.FastCastEventsConfig.UseLengthChanged = true

				local lengthChanges = 0
				local caster = newCaster(expect)
				caster.LengthChanged = function()
					lengthChanges += 1
				end
				initializeRuntime()

				fire(caster, "Raycast", Vector3.new(0, 0, 0), Vector3.new(0, 0, -1), 120, behavior)
				Framework.waitFor(function()
					return lengthChanges > 0
				end, HIT_TIMEOUT)

				expect.greaterThan(lengthChanges, 0, "LengthChanged never fired")

				caster:Destroy()
				arena:Destroy()
			end)

			test("fire methods return their active cast", function(expect)
				local arena = createArena(expect)
				local container = createContainer(arena)
				local behavior = makeBehavior(container)
				local caster = newCaster(expect)
				initializeRuntime()

				local cast = caster:RaycastFire(Vector3.zero, Vector3.new(0, 0, -1), 60, behavior)
				expect.truthy(cast, "RaycastFire did not return a cast")
				expect.equal(cast.Type, FastCastEnums.CastType.Raycast, "RaycastFire returned the wrong cast")

				FastCast:TerminateCast(cast)
				caster:Destroy()
				arena:Destroy()
			end)

			test("SetVelocity and SetAcceleration preserve cast position and runtime", function(expect)
				local arena = createArena(expect)
				local container = createContainer(arena)
				local behavior = makeBehavior(container)
				local caster = newCaster(expect)
				initializeRuntime()

				local cast = caster:RaycastFire(Vector3.zero, Vector3.new(0, 0, -1), 60, behavior)
				local runtime = cast.StateInfo.TotalRuntime
				local position = FastCast:GetPositionCast(cast)

				FastCast:SetVelocity(cast, Vector3.new(10, 0, 0))
				expect.equal(FastCast:GetPositionCast(cast), position, "SetVelocity changed the current position")
				expect.equal(cast.StateInfo.TotalRuntime, runtime, "SetVelocity changed runtime")
				expect.equal(FastCast:GetVelocityCast(cast), Vector3.new(10, 0, 0), "SetVelocity did not set velocity")

				FastCast:SetAcceleration(cast, Vector3.new(0, -workspace.Gravity, 0))
				expect.equal(FastCast:GetPositionCast(cast), position, "SetAcceleration changed the current position")
				expect.equal(cast.StateInfo.TotalRuntime, runtime, "SetAcceleration changed runtime")
				expect.equal(FastCast:GetAccelerationCast(cast), Vector3.new(0, -workspace.Gravity, 0), "SetAcceleration did not set acceleration")

				FastCast:TerminateCast(cast)
				caster:Destroy()
				arena:Destroy()
			end)

			test("OnStep can redirect a cast before movement", function(expect)
				local arena = createArena(expect)
				local wall = createWall(arena, Vector3.new(0, 0, -12), Vector3.new(50, 50, 2))
				local container = createContainer(arena)
				local behavior = makeBehavior(container)
				behavior.FastCastEventsConfig.UseOnStep = true

				local hitInstance = nil
				local stepCount = 0
				local caster = newCaster(expect)
				caster.OnStep = function(cast, deltaTime)
					stepCount += 1
					if stepCount == 1 then
						expect.greaterThan(deltaTime, 0, "OnStep deltaTime must be positive")
						FastCast:SetVelocityCast(cast, Vector3.new(0, 0, -120))
					end
				end
				caster.Hit = function(_, result)
					hitInstance = result.Instance
				end
				initializeRuntime()

				-- Start along +Y; OnStep redirects the cast toward the wall on -Z.
				fire(caster, "Raycast", Vector3.zero, Vector3.new(0, 1, 0), 120, behavior)

				expect.truthy(
					Framework.waitFor(function()
						return hitInstance ~= nil
					end, HIT_TIMEOUT),
					"OnStep trajectory change did not affect movement"
				)
				expect.equal(hitInstance, wall, "OnStep-directed cast hit the wrong instance")
				expect.greaterThan(stepCount, 0, "OnStep never fired")

				caster:Destroy()
				arena:Destroy()
			end)

			test("paused casts freeze runtime and resume without catching up", function(expect)
				local arena = createArena(expect)
				local container = createContainer(arena)
				local behavior = makeBehavior(container)
				behavior.FastCastEventsConfig.UseOnStep = true
				behavior.FastCastEventsConfig.UseLengthChanged = true

				local firedCast = nil
				local stepCount = 0
				local lengthChangedCount = 0
				local terminated = false

				local caster = newCaster(expect)
				caster.CastFire = function(cast)
					firedCast = cast
				end
				caster.OnStep = function()
					stepCount += 1
				end
				caster.LengthChanged = function()
					lengthChangedCount += 1
				end
				caster.CastTerminating = function()
					terminated = true
				end
				initializeRuntime()

				fire(caster, "Raycast", Vector3.zero, Vector3.new(0, 0, -1), 120, behavior)
				expect.truthy(firedCast, "CastFire did not provide the active cast")

				local cast = firedCast :: any
				FastCast:PauseCast(cast)
				local pausedPosition = FastCast:GetPositionCast(cast)
				local pausedRuntime = cast.StateInfo.TotalRuntime

				task.wait(0.15)
				expect.equal(cast.StateInfo.IsPaused, true, "cast did not enter paused state")
				expect.equal(FastCast:GetPositionCast(cast), pausedPosition, "paused cast position changed")
				expect.equal(cast.StateInfo.TotalRuntime, pausedRuntime, "paused cast runtime advanced")
				expect.equal(stepCount, 0, "OnStep fired while cast was paused")
				expect.equal(lengthChangedCount, 0, "LengthChanged fired while cast was paused")

				FastCast:ResumeCast(cast)
				expect.truthy(
					Framework.waitFor(function()
						return stepCount > 0 and FastCast:GetPositionCast(cast) ~= pausedPosition
					end, HIT_TIMEOUT),
					"cast did not resume moving"
				)
				expect.equal(cast.StateInfo.IsPaused, false, "cast remained paused after ResumeCast")

				FastCast:PauseCast(cast)
				FastCast:TerminateCast(cast)
				expect.truthy(
					Framework.waitFor(function()
						return terminated
					end, HIT_TIMEOUT),
					"terminating a paused cast did not fire CastTerminating"
				)

				-- The termination event clears the cast table. Reusing the stale
				-- reference must not enqueue an event with a missing cast ID.
				FastCast:TerminateCast(cast)

				caster:Destroy()
				arena:Destroy()
			end)

			test("MaxLifetime expires casts at simulation update boundaries", function(expect)
				local arena = createArena(expect)
				local container = createContainer(arena)
				local behavior = makeBehavior(container)
				behavior.MaxLifetime = 0.1
				behavior.FastCastEventsConfig.UseOnStep = true

				local firedCast = nil
				local stepCount = 0
				local terminated = false
				local terminatedRuntime = nil
				local caster = newCaster(expect)
				caster.CastFire = function(cast)
					firedCast = cast
				end
				caster.OnStep = function()
					stepCount += 1
				end
				caster.CastTerminating = function(cast)
					terminatedRuntime = cast.StateInfo.TotalRuntime
					terminated = true
				end
				initializeRuntime()

				fire(caster, "Raycast", Vector3.zero, Vector3.new(0, 0, -1), 120, behavior)
				expect.truthy(firedCast, "CastFire did not provide the active cast")
				expect.truthy(
					Framework.waitFor(function()
						return terminated
					end, HIT_TIMEOUT),
					"cast did not terminate when MaxLifetime expired"
				)
				expect.truthy(
					terminatedRuntime ~= nil and terminatedRuntime >= behavior.MaxLifetime,
					"cast expired before reaching MaxLifetime"
				)
				expect.truthy(stepCount > 0, "cast never simulated before expiration")
				caster:Destroy()
				arena:Destroy()
			end)

			test("MaxLifetime zero terminates without simulating", function(expect)
				local arena = createArena(expect)
				local container = createContainer(arena)
				local behavior = makeBehavior(container)
				behavior.MaxLifetime = 0
				behavior.FastCastEventsConfig.UseOnStep = true

				local firedCast = nil
				local stepCount = 0
				local terminated = false
				local caster = newCaster(expect)
				caster.CastFire = function(cast)
					firedCast = cast
				end
				caster.OnStep = function()
					stepCount += 1
				end
				caster.CastTerminating = function()
					terminated = true
				end
				initializeRuntime()

				fire(caster, "Raycast", Vector3.zero, Vector3.new(0, 0, -1), 120, behavior)
				expect.truthy(firedCast, "CastFire did not provide the active cast")
				expect.truthy(
					Framework.waitFor(function()
						return terminated
					end, HIT_TIMEOUT),
					"zero-lifetime cast did not terminate"
				)
				expect.equal(stepCount, 0, "zero-lifetime cast fired OnStep")
				caster:Destroy()
				arena:Destroy()
			end)

			test("movement mode is configured on the shared FastCast runtime", function(expect)
				local caster = newCaster(expect)
				initializeRuntime()

				FastCast.SetMovementModeEnabled(true, "Motor6D")
				expect.equal(caster.MovementMode, nil, "movement mode should not be stored per caster")

				FastCast.SetMovementModeEnabled(true, "BulkMoveTo")
				expect.equal(caster.MovementMode, nil, "switching the shared movement mode should not add per-caster state")

				caster:Destroy()
			end)

			test("cast velocity, acceleration and position can be manipulated", function(expect)
				local arena = createArena(expect)
				local container = createContainer(arena)
				local behavior = makeBehavior(container)

				local firedCast = nil
				local caster = newCaster(expect)
				caster.CastFire = function(cast)
					firedCast = cast
				end
				initializeRuntime()

				fire(caster, "Raycast", Vector3.new(0, 0, 0), Vector3.new(0, 1, 0), 60, behavior)
				expect.truthy(firedCast, "CastFire did not run")

				local cast = firedCast :: any
				FastCast:SetVelocityCast(cast, Vector3.new(0, 0, -100))
				expect.near(FastCast:GetVelocityCast(cast), Vector3.new(0, 0, -100), 1e-3, "velocity was not set")

				FastCast:AddVelocityCast(cast, Vector3.new(10, 0, 0))
				expect.near(FastCast:GetVelocityCast(cast), Vector3.new(10, 0, -100), 1e-3, "velocity was not added")

				FastCast:SetAccelerationCast(cast, Vector3.new(0, -10, 0))
				expect.near(FastCast:GetAccelerationCast(cast), Vector3.new(0, -10, 0), 1e-3, "acceleration was not set")

				FastCast:AddAccelerationCast(cast, Vector3.new(0, -5, 0))
				expect.near(FastCast:GetAccelerationCast(cast), Vector3.new(0, -15, 0), 1e-3, "acceleration was not added")

				FastCast:SetPositionCast(cast, Vector3.new(5, 5, 5))
				expect.near(FastCast:GetPositionCast(cast), Vector3.new(5, 5, 5), 1e-3, "position was not set")

				FastCast:AddPositionCast(cast, Vector3.new(1, 0, 0))
				expect.near(FastCast:GetPositionCast(cast), Vector3.new(6, 5, 5), 1e-3, "position was not added")

				FastCast:TerminateCast(cast)
				caster:Destroy()
				arena:Destroy()
			end)


			test("RaycastParams filters the first wall and hits the next", function(expect)
				local MAX_ATTEMPTS = 3
				local hitInstance = nil
				local targetWall = nil

				initializeRuntime()

				local didHit = retry(MAX_ATTEMPTS, 0.1, function()
					-- Recreate the setup on each attempt so retries don't reuse a
					-- destroyed wall, caster, or filter configuration.
					local arena = createArena(expect)
					local excludedWall = createWall(arena, Vector3.new(0, 0, -5), Vector3.new(50, 50, 2))
					local wall = createWall(arena, Vector3.new(0, 0, -12), Vector3.new(50, 50, 2))
					local container = createContainer(arena)
					local behavior = makeBehavior(container)
					local params = RaycastParams.new()
					params.FilterType = Enum.RaycastFilterType.Exclude
					params.FilterDescendantsInstances = { container, excludedWall }
					behavior.RaycastParams = params

					-- Check the geometry/filter independently before testing FastCast.
					local directResult = workspace:Raycast(
						Vector3.zero,
						Vector3.new(0, 0, -20),
						params
					)
					if not directResult or directResult.Instance ~= wall then
						arena:Destroy()
						return false
					end

					hitInstance = nil
					local caster = newCaster(expect)
					caster.Hit = function(_, result)
						hitInstance = result.Instance
					end
					fire(caster, "Raycast", Vector3.zero, Vector3.new(0, 0, -1), 120, behavior)

					local attemptHit = Framework.waitFor(function()
						return hitInstance ~= nil
					end, HIT_TIMEOUT)
					local hitExpectedWall = attemptHit and hitInstance == wall

					caster:Destroy()
					arena:Destroy()

					if hitExpectedWall then
						targetWall = wall
					end
					return hitExpectedWall
				end)

				expect.truthy(didHit, "filtered raycast never hit the target wall after " .. MAX_ATTEMPTS .. " attempts")
			end)

			test("MaxDistance terminates a cast without reporting a hit", function(expect)
				local arena = createArena(expect)
				local container = createContainer(arena)
				local behavior = makeBehavior(container)
				behavior.MaxDistance = 15

				local hitCount = 0
				local terminationCount = 0
				local caster = newCaster(expect)
				caster.Hit = function()
					hitCount += 1
				end
				caster.CastTerminating = function()
					terminationCount += 1
				end
				initializeRuntime()
				fire(caster, "Raycast", Vector3.new(0, 100, 0), Vector3.yAxis, 120, behavior)

				expect.truthy(
					Framework.waitFor(function()
						return terminationCount > 0
					end, HIT_TIMEOUT),
					"MaxDistance did not terminate the cast"
				)
				expect.equal(hitCount, 0, "MaxDistance termination incorrectly reported a hit")
				expect.equal(terminationCount, 1, "MaxDistance termination fired more than once")

				caster:Destroy()
				arena:Destroy()
			end)

			test("cosmetic template is cloned into its container and ignored by its own cast", function(expect)
				local arena = createArena(expect)
				local wall = createWall(arena, Vector3.new(0, 0, -12), Vector3.new(50, 50, 2))
				local container = createContainer(arena)
				local template = Instance.new("Part")
				template.Name = "ProjectileTemplate"
				template.Anchored = true
				template.CanCollide = false
				template.CanQuery = true
				template.Size = Vector3.one
				template.Position = Vector3.new(1000, 1000, 1000)
				template.Parent = arena

				local behavior = makeBehavior(container)
				behavior.CosmeticBulletTemplate = template
				behavior.CosmeticBulletContainer = container
				behavior.RaycastParams = RaycastParams.new()
				behavior.RaycastParams.FilterType = Enum.RaycastFilterType.Exclude
				behavior.RaycastParams.FilterDescendantsInstances = {}
				behavior.AutoIgnoreContainer = true
				behavior.CloneTemplate = true

				local castData = nil
				local cosmetic = nil
				local hitInstance = nil
				local caster = newCaster(expect)
				caster.CastFire = function(cast)
					castData = cast
					cosmetic = cast.RayInfo.CosmeticBulletObject
				end
				caster.Hit = function(_, result)
					hitInstance = result.Instance
				end
				initializeRuntime()
				fire(caster, "Raycast", Vector3.zero, Vector3.new(0, 0, -1), 120, behavior)

				expect.truthy(cosmetic, "cast did not create a cosmetic projectile")
				expect.truthy(cosmetic ~= template, "CloneTemplate did not clone the template")
				expect.equal(cosmetic.Parent, container, "cloned cosmetic was parented to the wrong container")
				expect.equal(template.Parent, arena, "cloning changed the original template's parent")
				expect.truthy(
					table.find(castData.RayInfo.Parameters.FilterDescendantsInstances, container) ~= nil,
					"AutoIgnoreContainer did not add the cosmetic container to the raycast filter"
				)
				expect.truthy(
					Framework.waitFor(function()
						return hitInstance ~= nil
					end, HIT_TIMEOUT),
					"cast hit its own cosmetic instead of reaching the wall"
				)
				expect.equal(hitInstance, wall, "cast hit the wrong instance")
				expect.truthy(cosmetic.Parent ~= nil, "FastCast unexpectedly cleaned up the cosmetic")
				cosmetic:Destroy()
				template:Destroy()
				caster:Destroy()
				arena:Destroy()
			end)

			test("CloneTemplate false uses the supplied cosmetic instance", function(expect)
				local arena = createArena(expect)
				local container = createContainer(arena)
				local template = Instance.new("Part")
				template.Anchored = true
				template.CanCollide = false
				template.Parent = arena

				local behavior = makeBehavior(container)
				behavior.CosmeticBulletTemplate = template
				behavior.CosmeticBulletContainer = container
				behavior.CloneTemplate = false

				local castData = nil
				local caster = newCaster(expect)
				caster.CastFire = function(cast)
					castData = cast
				end
				initializeRuntime()
				fire(caster, "Raycast", Vector3.zero, Vector3.yAxis, 60, behavior)

				expect.truthy(castData, "CastFire did not expose the active cast")
				expect.equal(castData.RayInfo.CosmeticBulletObject, template, "CloneTemplate=false did not use the original instance")
				expect.equal(template.Parent, container, "original cosmetic was not parented to the configured container")

				FastCast:TerminateCast(castData)
				template:Destroy()
				caster:Destroy()
				arena:Destroy()
			end)

			test("event configuration can disable all callback channels", function(expect)
				local arena = createArena(expect)
				createWall(arena, Vector3.new(0, 0, -12), Vector3.new(50, 50, 2))
				local container = createContainer(arena)
				local behavior = makeBehavior(container)
				behavior.FastCastEventsConfig = {
					UseLengthChanged = false,
					UseHit = false,
					UsePierced = false,
					UseCastTerminating = false,
					UseCanPierce = false,
					UseCastFire = false,
					UseOnStep = false,
				}

				local callbackCount = 0
				local caster = newCaster(expect)
				caster.CastFire = function() callbackCount += 1 end
				caster.LengthChanged = function() callbackCount += 1 end
				caster.Hit = function() callbackCount += 1 end
				caster.Pierced = function() callbackCount += 1 end
				caster.CastTerminating = function() callbackCount += 1 end
				caster.OnStep = function() callbackCount += 1 end
				caster.CanPierce = function()
					callbackCount += 1
					return true
				end

				initializeRuntime()
				fire(caster, "Raycast", Vector3.zero, Vector3.new(0, 0, -1), 120, behavior)
				task.wait(0.5)
				expect.equal(callbackCount, 0, "a disabled event callback still ran")

				caster:Destroy()
				arena:Destroy()
			end)

			test("HighFidelity modes all resolve hits", function(expect)
				local modes = {
					{ Name = "Default", Value = FastCastEnums.HighFidelityBehavior.Default, SegmentSize = 0.5 },
					{ Name = "Automatic", Value = FastCastEnums.HighFidelityBehavior.Automatic, SegmentSize = 0.25 },
					{ Name = "Always", Value = FastCastEnums.HighFidelityBehavior.Always, SegmentSize = 1 },
				}
				local MAX_ATTEMPTS = 3
				local ATTEMPT_TIMEOUT = 1.5

				initializeRuntime()

				for _, mode in modes do
					local successfulWall = nil
					local hitInstance = nil
					local didHit = retry(
						MAX_ATTEMPTS,
						0.1,
						function()
							-- Fresh geometry and caster keep retries independent.
							local arena = createArena(expect)
							local wall = createWall(arena, Vector3.new(0, 0, -12), Vector3.new(50, 50, 2))
							local container = createContainer(arena)
							local behavior = makeBehavior(container)
							behavior.HighFidelityBehavior = mode.Value
							behavior.HighFidelitySegmentSize = mode.SegmentSize
							behavior.MaxLifetime = 3

							hitInstance = nil
							local caster = newCaster(expect)
							caster.Hit = function(_, result)
								hitInstance = result.Instance
							end

							fire(caster, "Raycast", Vector3.zero, Vector3.new(0, 0, -1), 120, behavior)
							local didHit = Framework.waitFor(function()
								return hitInstance ~= nil
							end, ATTEMPT_TIMEOUT)

							caster:Destroy()
							arena:Destroy()

							if didHit then
								successfulWall = wall
							end
							return didHit
						end
					)

					expect.truthy(
						didHit,
						mode.Name .. " high-fidelity mode did not hit the wall after " .. MAX_ATTEMPTS .. " attempts"
					)
					if didHit then
						expect.equal(hitInstance, successfulWall, mode.Name .. " high-fidelity mode hit the wrong instance")
					end
				end
			end)
		end),

	}
end
