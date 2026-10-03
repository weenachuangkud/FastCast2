--!native
--!optimize 2
local storage = game:GetService("ReplicatedStorage")
local modules = storage.Modules
local Signal = require(modules.Signal)

local function near(a, b, tolerance)
	assert((a - b).Magnitude <= tolerance, tostring(a) .. " ~= " .. tostring(b))
end

-- Simulation events are Signals; wrap plain handler functions so the harness
-- stays readable.
local function makeEvents(handlers: { [string]: ((...any) -> ())? }): { [string]: any }
	local events = {}
	for name, handler in handlers do
		local signal = Signal.new()
		if handler then
			signal:Connect(handler)
		end
		events[name] = signal
	end
	return events
end

local function queueTests(simulation)
	local hooks = simulation._Test
	-- Cross several growth boundaries; f64 IDs must survive beyond u32.
	for i = 1, 2057 do
		hooks.Queue(2 ^ 40 + i, i % 4 + 1, i, nil, Vector3.one, nil, "tail")
	end
	for i = 1, 2057 do
		local id, kind, args = hooks.Peek(i)
		assert(id == 2 ^ 40 + i and kind == i % 4 + 1, "event metadata corrupted during growth")
		assert(
			args[1] == i and args[2] == nil and args[3] == Vector3.one and args[5] == "tail",
			"event payload corrupted"
		)
	end
	hooks.Reset()
	for i = 1, 2057 do
		hooks.Queue(i, 4)
	end
	for i = 1, 2057 do
		local id, kind, args = hooks.Peek(i)
		assert(id == i and kind == 4 and next(args) == nil, "stale event arguments")
	end
	hooks.Reset()
end

local function setup(simulation, count, events, world, origin, velocity, acceleration)
	local actives = {}
	local base = {
		_TerminateCast = function(id)
			actives[id] = nil
		end,
	}
	simulation.Init(base, actives, events)
	for i = 1, count do
		local cast = {
			ID = 2 ^ 40 + i,
			StateInfo = {
				TotalRuntime = 0,
				HighFidelityBehavior = 0,
				HighFidelitySegmentSize = 1,
				FastCastEventsConfig = {
					UseLengthChanged = events.LengthChanged ~= nil,
					UseHit = events.Hit ~= nil,
				},
				Trajectory = { Origin = origin, InitialVelocity = velocity, Acceleration = acceleration, StartTime = 0 },
			},
			RayInfo = { WorldRoot = world, MaxDistance = 1e30, Parameters = RaycastParams.new() },
			CastVariant = { CastType = require(modules.FastCastEnums).CastType.Raycast },
		}
		actives[cast.ID] = cast
		simulation.Register(cast)
	end
	return actives
end

local function fresh(name)
	local clone = modules[name]:Clone()
	clone.Parent = modules
	return require(clone)
end

local function correctness()
	queueTests(fresh("Optimized"))
	queueTests(fresh("Parallel"))
	local sim = fresh("Optimized")
	local origin, velocity, acceleration = Vector3.new(10, 20, 30), Vector3.new(80, 90, -100), Vector3.new(0, -196.2, 0)
	local observedOrigin, observedDirection, observedVelocity
	local callbacks = 0
	local actives = setup(sim, 600, makeEvents({
		LengthChanged = function(_, _, _, _, v)
			callbacks += 1
			observedVelocity = v
		end,
	}), {
		Raycast = function(_, o, d)
			observedOrigin, observedDirection = o, d
		end,
	}, origin, velocity, acceleration)
	local elapsed = 0
	for _, dt in { 0, 1 / 240, 1 / 60, 0.1, 0.5 } do
		sim._Test.Step(dt)
		if dt > 0 then
			near(observedOrigin, origin + velocity * elapsed + acceleration * (elapsed * elapsed * 0.5), 0.0001)
			near(observedDirection, (velocity + acceleration * (elapsed + dt * 0.5)) * dt, 0.0001)
			near(observedVelocity, velocity + acceleration * (elapsed + dt), 0.0001)
			local reference = CFrame.new(observedOrigin, observedOrigin + observedDirection)
				* CFrame.new(0, 0, -observedDirection.Magnitude / 2)
			local cast = actives[2 ^ 40 + 1]
			near(cast.CFrame.Position, reference.Position, 0.0001)
			near(cast.CFrame.LookVector, reference.LookVector, 0.0001)
			near(cast.CFrame.RightVector, reference.RightVector, 0.0001)
			near(cast.CFrame.UpVector, reference.UpVector, 0.0001)
		end
		elapsed += dt
	end
	assert(callbacks == 2400, "event growth/order lost callbacks")
	-- Dense active-list swap after removal must not mix event IDs or state.
	sim.Unregister(2 ^ 40 + 1)
	actives[2 ^ 40 + 1] = nil
	sim._Test.Step(1 / 60)
	assert(callbacks == 2999, "swap removal lost or duplicated events")
	-- Tiny motion at a large origin must retain a finite direction.
	local far = fresh("Optimized")
	local direction
	local casts = setup(far, 1, {}, {
		Raycast = function(_, _, d)
			direction = d
		end,
	}, Vector3.new(1e8, 1e8, 1e8), Vector3.new(1, 0, 0), Vector3.zero)
	far._Test.Step(1 / 60)
	near(direction, Vector3.new(1 / 60, 0, 0), 1e-7)
	near(casts[2 ^ 40 + 1].CFrame.LookVector, Vector3.xAxis, 1e-6)
	-- Vertical directions use the engine's lookAlong fallback basis.
	for _, v in { Vector3.yAxis, -Vector3.yAxis, Vector3.zero } do
		local vertical = fresh("Optimized")
		local c = setup(vertical, 1, {}, { Raycast = function() end }, Vector3.zero, v, Vector3.zero)
		vertical._Test.Step(1)
		local cf = c[2 ^ 40 + 1].CFrame
		assert(cf.Position.X == cf.Position.X and cf.LookVector.X == cf.LookVector.X, "non-finite CFrame")
		if v ~= Vector3.zero then
			near(cf.LookVector, v, 1e-6)
		end
	end
end

local function collisionTests()
	local wall = Instance.new("Part")
	wall.Anchored = true
	wall.Size = Vector3.new(50, 50, 2)
	wall.Position = Vector3.new(0, 10000, -40)
	wall.Parent = workspace
	task.wait()
	for _, kind in { "Raycast", "Blockcast", "Spherecast" } do
		local sim = fresh("Optimized")
		local hits = 0
		local casts = setup(sim, 96, makeEvents({
			Hit = function(_, result)
				assert(result.Instance == wall, "wrong collision target")
				hits += 1
			end,
		}), workspace, Vector3.new(0, 10000, 0), Vector3.new(0, 0, -120), Vector3.zero)
		local random = Random.new(42)
		for _, cast in casts do
			cast.StateInfo.Trajectory.Origin += Vector3.new(0, 0, random:NextNumber(-5, 5))
			cast.CastVariant.CastType = require(modules.FastCastEnums).CastType[kind]
			cast.CastVariant.Size = Vector3.one
			cast.CastVariant.Radius = 0.5
			cast.RayInfo.Parameters.FilterType = Enum.RaycastFilterType.Include
			cast.RayInfo.Parameters.FilterDescendantsInstances = { wall }
		end
		for _ = 1, 60 do
			sim._Test.Step(random:NextNumber(1 / 240, 1 / 20))
		end
		assert(hits == 96, kind .. " missed collisions: " .. hits .. "/96")
	end
	wall:Destroy()
end

local function benchmark()
	if not modules:FindFirstChild("Baseline") then
		return
	end
	for _, withEvents in { false, true } do
		local variants = {}
		for _, name in { "Baseline", "Optimized" } do
			local sim = fresh(name)
			setup(
				sim,
				6000,
				if withEvents then makeEvents({ LengthChanged = function() end }) else makeEvents({}),
				workspace,
				Vector3.new(0, 100000, 0),
				Vector3.new(100, 10, -50),
				Vector3.new(0, -10, 0)
			)
			for _ = 1, 20 do
				sim._Test.Step(1 / 60)
			end
			variants[name] = { sim = sim, samples = {} }
		end
		for round = 1, 9 do
			-- Alternate order to reduce warmup / thermal bias.
			for _, name in if round % 2 == 0 then { "Optimized", "Baseline" } else { "Baseline", "Optimized" } do
				local variant = variants[name]
				local started = os.clock()
				for _ = 1, 60 do
					variant.sim._Test.Step(1 / 60)
				end
				table.insert(variant.samples, (os.clock() - started) * 1000 / 60)
			end
			task.wait()
		end
		for name, variant in variants do
			table.sort(variant.samples)
			print(
				string.format(
					"HOTPATH_BENCH %s events=%s casts=6000 median_step_ms=%.4f min=%.4f max=%.4f",
					name,
					tostring(withEvents),
					variant.samples[5],
					variant.samples[1],
					variant.samples[9]
				)
			)
		end
	end
end

local ok, err = xpcall(function()
	correctness()
	collisionTests()
	benchmark()
end, debug.traceback)
storage:SetAttribute("HotPathResult", if ok then "HOTPATH_PASS" else "HOTPATH_FAIL " .. tostring(err))
