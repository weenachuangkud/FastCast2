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

local function createArena(): Folder
	arenaCounter += 1
	local arena = Instance.new("Folder")
	arena.Name = "FastCast2TestArena" .. arenaCounter
	arena.Parent = workspace
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

local function registerSerialCastTypes(test: (string, any) -> ())
	for _, castType in CAST_TYPES do
		test("Serial " .. castType .. " reaches a wall", function(expect)
			local arena = createArena()
			local wall = createWall(arena, Vector3.new(0, 0, -40), Vector3.new(50, 50, 2))
			local container = createContainer(arena)
			local behavior = makeBehavior(container)

			local hitInstance = nil
			local terminated = false

			local caster = FastCast.new()
			caster.Hit = function(_, result)
				hitInstance = result.Instance
			end
			caster.CastTerminating = function()
				terminated = true
			end
			FastCast.Init("BulkMoveTo")

			fire(caster, castType, Vector3.new(0, 0, 0), Vector3.new(0, 0, -1), 120, behavior)

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

				expect.equal(behavior.MaxDistance, 1000, "MaxDistance default changed")
				expect.near(behavior.Acceleration, Vector3.zero, 1e-6, "Acceleration default changed")
				expect.equal(
					behavior.HighFidelityBehavior,
					FastCastEnums.HighFidelityBehavior.Default,
					"HighFidelityBehavior default changed"
				)
				expect.equal(behavior.AutoIgnoreContainer, true, "AutoIgnoreContainer default changed")
				expect.equal(behavior.FastCastEventsConfig.UseOnStep, false, "UseOnStep should be opt-in")
			end)
		end),

		Framework.describe("FastCastSerial", function(test)
			test("initializes and destroys", function(expect)
				local caster = FastCast.new()
				FastCast.Init("BulkMoveTo")

				expect.equal(type(caster.CasterId), "number", "caster did not receive a numeric ID")

				caster:Destroy()
				expect.equal(getmetatable(caster), nil, "destroy did not clear the metatable")
			end)

			test("RaycastFire fires CastFire synchronously", function(expect)
				local arena = createArena()
				local container = createContainer(arena)
				local behavior = makeBehavior(container)

				local firedCast = nil
				local caster = FastCast.new()
				caster.CastFire = function(cast)
					firedCast = cast
				end
				FastCast.Init("BulkMoveTo")

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
				local arena = createArena()
				local wall = createWall(arena, Vector3.new(0, 0, -40), Vector3.new(50, 50, 2))
				local container = createContainer(arena)
				local behavior = makeBehavior(container)

				local caster = FastCast.new()
				FastCast.Init("BulkMoveTo")

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
				local arena = createArena()
				local wall = createWall(arena, Vector3.new(0, 0, -40), Vector3.new(50, 50, 2))
				local container = createContainer(arena)
				local behavior = makeBehavior(container)

				local firstCount = 0
				local secondCount = 0

				local caster = FastCast.new()
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
				FastCast.Init("BulkMoveTo")

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

			test("Pierced and CanPierce run when a cast is allowed through", function(expect)
				local arena = createArena()
				local container = createContainer(arena)
				local behavior = makeBehavior(container)
				behavior.MaxDistance = 80

				createWall(arena, Vector3.new(0, 0, -20), Vector3.new(50, 50, 2))

				local piercedCount = 0
				local terminated = false

				local caster = FastCast.new()
				caster.CanPierce = function()
					return true
				end
				caster.Pierced = function()
					piercedCount += 1
				end
				caster.CastTerminating = function()
					terminated = true
				end
				FastCast.Init("BulkMoveTo")

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
				local arena = createArena()
				local container = createContainer(arena)
				local behavior = makeBehavior(container)
				behavior.FastCastEventsConfig.UseLengthChanged = true

				local lengthChanges = 0
				local caster = FastCast.new()
				caster.LengthChanged = function()
					lengthChanges += 1
				end
				FastCast.Init("BulkMoveTo")

				fire(caster, "Raycast", Vector3.new(0, 0, 0), Vector3.new(0, 0, -1), 120, behavior)
				Framework.waitFor(function()
					return lengthChanges > 0
				end, HIT_TIMEOUT)

				expect.greaterThan(lengthChanges, 0, "LengthChanged never fired")

				caster:Destroy()
				arena:Destroy()
			end)

			test("fire methods return their active cast", function(expect)
				local arena = createArena()
				local container = createContainer(arena)
				local behavior = makeBehavior(container)
				local caster = FastCast.new()
				FastCast.Init("BulkMoveTo")

				local cast = caster:RaycastFire(Vector3.zero, Vector3.new(0, 0, -1), 60, behavior)
				expect.truthy(cast, "RaycastFire did not return a cast")
				expect.equal(cast.Type, FastCastEnums.CastType.Raycast, "RaycastFire returned the wrong cast")

				FastCast:TerminateCast(cast)
				caster:Destroy()
				arena:Destroy()
			end)

			test("SetVelocity and SetAcceleration preserve cast position and runtime", function(expect)
				local arena = createArena()
				local container = createContainer(arena)
				local behavior = makeBehavior(container)
				local caster = FastCast.new()
				FastCast.Init("BulkMoveTo")

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
				local arena = createArena()
				local wall = createWall(arena, Vector3.new(0, 0, -40), Vector3.new(50, 50, 2))
				local container = createContainer(arena)
				local behavior = makeBehavior(container)
				behavior.FastCastEventsConfig.UseOnStep = true

				local hitInstance = nil
				local stepCount = 0
				local caster = FastCast.new()
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
				FastCast.Init("BulkMoveTo")

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
				local arena = createArena()
				local container = createContainer(arena)
				local behavior = makeBehavior(container)
				behavior.FastCastEventsConfig.UseOnStep = true
				behavior.FastCastEventsConfig.UseLengthChanged = true

				local firedCast = nil
				local stepCount = 0
				local lengthChangedCount = 0
				local terminated = false

				local caster = FastCast.new()
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
				FastCast.Init("BulkMoveTo")

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
				local arena = createArena()
				local container = createContainer(arena)
				local behavior = makeBehavior(container)
				behavior.MaxLifetime = 0.1
				behavior.FastCastEventsConfig.UseOnStep = true

				local firedCast = nil
				local stepCount = 0
				local terminated = false
				local terminatedRuntime = nil
				local caster = FastCast.new()
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
				FastCast.Init("BulkMoveTo")

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
				local arena = createArena()
				local container = createContainer(arena)
				local behavior = makeBehavior(container)
				behavior.MaxLifetime = 0
				behavior.FastCastEventsConfig.UseOnStep = true

				local firedCast = nil
				local stepCount = 0
				local terminated = false
				local caster = FastCast.new()
				caster.CastFire = function(cast)
					firedCast = cast
				end
				caster.OnStep = function()
					stepCount += 1
				end
				caster.CastTerminating = function()
					terminated = true
				end
				FastCast.Init("BulkMoveTo")

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

			test("movement mode can be switched", function(expect)
				local caster = FastCast.new()
				FastCast.Init("Motor6D")

				-- FastCast.Init configures the shared simulation. The caster property
				-- is set by this caster's movement-mode method.
				caster:SetMovementModeEnabled(true, "Motor6D")
				expect.equal(caster.MovementMode, "Motor6D", "movement mode was not set to Motor6D")

				caster:SetMovementModeEnabled(true, "BulkMoveTo")
				expect.equal(caster.MovementMode, "BulkMoveTo", "movement mode was not switched")

				caster:Destroy()
			end)

			test("cast velocity, acceleration and position can be manipulated", function(expect)
				local arena = createArena()
				local container = createContainer(arena)
				local behavior = makeBehavior(container)

				local firedCast = nil
				local caster = FastCast.new()
				caster.CastFire = function(cast)
					firedCast = cast
				end
				FastCast.Init("BulkMoveTo")

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

			test("HighFidelity Always still resolves a hit", function(expect)
				local arena = createArena()
				local wall = createWall(arena, Vector3.new(0, 0, -40), Vector3.new(50, 50, 2))
				local container = createContainer(arena)
				local behavior = makeBehavior(container)
				behavior.HighFidelityBehavior = FastCastEnums.HighFidelityBehavior.Always
				behavior.HighFidelitySegmentSize = 1

				local hitInstance = nil
				local caster = FastCast.new()
				caster.Hit = function(_, result)
					hitInstance = result.Instance
				end
				FastCast.Init("BulkMoveTo")

				fire(caster, "Raycast", Vector3.new(0, 0, 0), Vector3.new(0, 0, -1), 120, behavior)

				expect.truthy(
					Framework.waitFor(function()
						return hitInstance ~= nil
					end, HIT_TIMEOUT),
					"high fidelity cast never hit the wall"
				)
				expect.equal(hitInstance, wall, "high fidelity cast hit the wrong instance")

				caster:Destroy()
				arena:Destroy()
			end)
		end),

	}
end
