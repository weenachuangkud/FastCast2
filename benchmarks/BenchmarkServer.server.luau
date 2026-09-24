--[[
	FastCast2 Server Benchmark
	Author: Mawin CK
	Date: 2026

	Interactive server benchmark.
	Type single letters in chat to control the benchmark.

	Commands:
		p  - Start benchmark
		l  - +500 projectiles
		k  - -500 projectiles
		u  - Toggle Instanced / Instanceless
		j  - Toggle BulkMoveTo / Motor6D
		y  - Toggle ObjectCache
		v  - Toggle Cast Visualization
		r  - Cycle cast type
		x  - Cycle HighFidelityBehavior
		>  - Increase HighFidelitySegmentSize
		<  - Decrease HighFidelitySegmentSize
		]  - Increase workers
		[  - Decrease workers
		i  - Show benchmark information
		h  - Show help
]]

--// Services

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

--// Configuration

local Config = {
	NumWorkers = 4,

	Instanced = false,
	MovementMode = "BulkMoveTo",
	ObjectCacheEnabled = false,
	ProjectileAmount = 500,
	VisualizeCasts = false,
	CastType = "Raycast",
	RandomSeed = 2026,
	BlockcastSize = Vector3.one,
	SpherecastRadius = 0.5,

	Velocity = 6,

	BenchmarkDuration = 6,

	ProjectileStep = 500,

	WorkerStep = 1,
	MinWorkers = 2,

	SegmentSizeStep = 0.05,
	MinSegmentSize = 0.05,
}

--// Constants
local NUM_WORKERS_CHANGE_COOLDOWN = 4.5
local BENCHMARK_COOLDOWN = 2.5

--// Modules

local FastCastModule = ReplicatedStorage:WaitForChild("FastCast2")

local FastCast = require(FastCastModule)
local FastCastEnums = require(
	FastCastModule:WaitForChild("FastCastEnums")
)

local BenchmarkPackets = require(
	ReplicatedStorage:WaitForChild("BenchmarkPackets")
)

--// Projectile Objects

local ProjectileContainer = Instance.new("Folder")
ProjectileContainer.Name = "FastCast2PJ_Parallel"
ProjectileContainer.Parent = workspace

local ProjectileTemplate = Instance.new("Part")
ProjectileTemplate.Name = "Projectile"
ProjectileTemplate.Size = Vector3.one
ProjectileTemplate.Position = Vector3.one

ProjectileTemplate.Anchored = true
ProjectileTemplate.CanCollide = false
ProjectileTemplate.CanQuery = false
ProjectileTemplate.CanTouch = false
ProjectileTemplate.Massless = true

ProjectileTemplate.Parent = ReplicatedStorage

--// Raycast Parameters

local CastParams = RaycastParams.new()
CastParams.FilterType = Enum.RaycastFilterType.Exclude
CastParams.IgnoreWater = true

--// Cast Behavior

local CastBehavior = FastCast.newBehavior()

CastBehavior.MaxDistance = 1e9
CastBehavior.RaycastParams = CastParams

CastBehavior.HighFidelityBehavior =
	FastCastEnums.HighFidelityBehavior.Default

CastBehavior.HighFidelitySegmentSize = 1
CastBehavior.Acceleration = Vector3.zero

CastBehavior.AutoIgnoreContainer = true

CastBehavior.CosmeticBulletContainer = ProjectileContainer
CastBehavior.CosmeticBulletTemplate =
	Config.Instanced and ProjectileTemplate or nil

CastBehavior.VisualizeCasts = Config.VisualizeCasts

--// State

local Caster
local ActiveCasts = {}

local IsBenchmarking = false
local IsReconfiguring = false

--// Frame Statistics

local FrameTimes = {}
local IsMeasuringFrames = false

RunService.Heartbeat:Connect(function(dt)
	if IsMeasuringFrames and dt > 0 then
		FrameTimes[#FrameTimes + 1] = dt * 1000
	end
end)

--// Utility

local function getHighFidelityName()
	local behavior = CastBehavior.HighFidelityBehavior

	if behavior == FastCastEnums.HighFidelityBehavior.Default then
		return "Default"
	elseif behavior == FastCastEnums.HighFidelityBehavior.Automatic then
		return "Automatic"
	else
		return "Always"
	end
end

local function getObjectCacheState()
	if not Caster then
		return false
	end

	if Caster.ObjectCacheEnabled then
		return true
	end

	if Caster.BaseCast and Caster.BaseCast.ObjectCacheInstance then
		return true
	end

	return false
end

local function getModeName()
	return Config.Instanced and "Instanced" or "Instanceless"
end

local function printSection(title)
	print(("=== %s ==="):format(title))
end

--// Cast Tracking

local function onCastFire(cast)
	ActiveCasts[#ActiveCasts + 1] = cast
end

--// Caster Creation

local function createCaster()
	local caster = FastCast.newParallel()

	caster:Init(
		Config.NumWorkers,
		Config.MovementMode
	)

	caster.CastFire = onCastFire

	return caster
end

local function applyObjectCache()
	if not Caster then
		return
	end

	if not Config.ObjectCacheEnabled then
		Caster:SetObjectCacheEnabled(false)
		return
	end

	Caster:SetObjectCacheEnabled(
		true,
		ProjectileTemplate,
		Config.ProjectileAmount,
		ProjectileContainer
	)
end

--// Cast Cleanup

local function terminateActiveCasts()
	for i = #ActiveCasts, 1, -1 do
		local cast = ActiveCasts[i]

		if cast then
			FastCast:TerminateCast(cast)
		end

		ActiveCasts[i] = nil
	end

	table.clear(ActiveCasts)
end


local function destroyCaster()
	if not Caster then
		return
	end

	terminateActiveCasts()

	Caster:Destroy()
	Caster = nil

	table.clear(ActiveCasts)
end

local function rebuildCaster()
	destroyCaster()

	Caster = createCaster()
	applyObjectCache()
end

--// Benchmark Information

local function printBenchmarkInfo()
	printSection("PARALLEL MODE BENCHMARK")

	print(("ProjectileAmount: %d"):format(
		Config.ProjectileAmount
		))

	print(("Velocity: %.2f"):format(
		Config.Velocity
		))

	print(("CastType: %s"):format(Config.CastType))

	print(("ObjectCache: %s"):format(
		getObjectCacheState() and "Enabled" or "Disabled"
		))

	print(("VisualizeCasts: %s"):format(
		CastBehavior.VisualizeCasts and "Enabled" or "Disabled"
		))

	print(("HighFidelityBehavior: %s"):format(
		getHighFidelityName()
		))

	print(("HighFidelitySegmentSize: %.2f"):format(
		CastBehavior.HighFidelitySegmentSize
		))

	print(("MovementMode: %s"):format(
		Config.MovementMode
		))

	print(("Mode: %s"):format(
		getModeName()
		))

	print(("numWorkers: %d"):format(
		Config.NumWorkers
		))
end

--// Benchmark Output

local function percentile(sortedValues, fraction)
	if #sortedValues == 0 then
		return 0
	end

	local index = math.max(1, math.ceil(#sortedValues * fraction))
	return sortedValues[index]
end

local function printFrameStats()
	if #FrameTimes == 0 then
		print("No frames sampled.")
		return
	end

	local sorted = table.clone(FrameTimes)
	table.sort(sorted)

	local total = 0
	for _, frameTime in FrameTimes do
		total += frameTime
	end

	local average = total / #FrameTimes
	local slowest = sorted[#sorted]
	local fastest = sorted[1]

	print(("Frames sampled: %d"):format(#FrameTimes))
	print(("Average frame time: %.2f ms (%.2f FPS)"):format(average, 1000 / average))
	print(("P50 / P95 / P99: %.2f / %.2f / %.2f ms"):format(
		percentile(sorted, 0.50),
		percentile(sorted, 0.95),
		percentile(sorted, 0.99)
	))
	print(("FPS range: %.2f - %.2f"):format(1000 / slowest, 1000 / fastest))
end

local function printOperationStats(elapsed, operationCount)
	local elapsedMilliseconds = elapsed * 1000
	local throughput = elapsed > 0 and operationCount / elapsed or 0

	print(("Elapsed: %.2f ms"):format(elapsedMilliseconds))
	print(("Throughput: %.2f projectiles/s"):format(throughput))
end

--// Projectile Generation

local function fireProjectile(random)
	local origin = Vector3.new(
		random:NextInteger(-100, 100),
		random:NextInteger(0, 100),
		random:NextInteger(-100, 100)
	)
	local direction = Vector3.new(
		random:NextNumber(-1, 1),
		random:NextNumber(-1, 1),
		random:NextNumber(-1, 1)
	)

	if direction.Magnitude == 0 then
		direction = Vector3.xAxis
	else
		direction = direction.Unit
	end

	if Config.CastType == "Blockcast" then
		Caster:BlockcastFire(origin, Config.BlockcastSize, direction, Config.Velocity, CastBehavior)
	elseif Config.CastType == "Spherecast" then
		Caster:SpherecastFire(origin, Config.SpherecastRadius, direction, Config.Velocity, CastBehavior)
	else
		Caster:RaycastFire(origin, direction, Config.Velocity, CastBehavior)
	end
end

local function fireProjectiles()
	local random = Random.new(Config.RandomSeed)

	for _ = 1, Config.ProjectileAmount do
		task.spawn(fireProjectile, random)
	end
end

--// Benchmark

local function runBenchmark()
	if IsBenchmarking or IsReconfiguring then
		return
	end

	IsBenchmarking = true
	IsMeasuringFrames = false

	local success, err = xpcall(function()

		printSection("BENCHMARK START")
		printBenchmarkInfo()

		print(("Firing %d projectiles..."):format(
			Config.ProjectileAmount
			))

		--// Creation
		local creationStarted = os.clock()

		fireProjectiles()

		local creationElapsed = os.clock() - creationStarted

		-- Let Parallel FastCast begin processing.
		task.wait()

		printSection("CREATION COMPLETE")
		printOperationStats(
			creationElapsed,
			Config.ProjectileAmount
		)

		--// Simulation
		table.clear(FrameTimes)

		IsMeasuringFrames = true

		task.wait(Config.BenchmarkDuration)

		IsMeasuringFrames = false

		printSection("SIMULATION COMPLETE")
		printFrameStats()

		--// Cleanup
		printSection("CLEANUP")

		local cleanupStarted = os.clock()

		terminateActiveCasts()

		local cleanupElapsed = os.clock() - cleanupStarted

		printOperationStats(
			cleanupElapsed,
			Config.ProjectileAmount
		)

		-- Give FastCast2's parallel workers time to finish
		-- processing the terminated casts.
		task.wait(BENCHMARK_COOLDOWN)

		--// IMPORTANT
		-- Destroy the old parallel caster and create a
		-- completely fresh one for the next benchmark.
		print("Rebuilding FastCast caster...")

		rebuildCaster()

		print("FastCast caster rebuilt.")

		printSection("DONE")

	end, debug.traceback)

	-- Always restore benchmark state.
	IsMeasuringFrames = false
	IsBenchmarking = false

	if not success then
		warn("FastCast2 benchmark failed:")
		warn(err)

		-- Recover the caster if something failed during
		-- the benchmark.
		pcall(function()
			rebuildCaster()
		end)

		print("FastCast caster recovered.")
	end

	print("Benchmark ready. Type 'p' to run again.")
end


local function cycleCastType()
	if Config.CastType == "Raycast" then
		Config.CastType = "Blockcast"
	elseif Config.CastType == "Blockcast" then
		Config.CastType = "Spherecast"
	else
		Config.CastType = "Raycast"
	end

	print(("CastType: %s"):format(Config.CastType))
end

--// Configuration

local function setInstanced(enabled)
	Config.Instanced = enabled

	CastBehavior.CosmeticBulletTemplate =
		enabled and ProjectileTemplate or nil
end

local function toggleInstancing()
	setInstanced(not Config.Instanced)

	print(("Instanced: %s"):format(
		Config.Instanced and "Enabled" or "Disabled"
		))
end

local function toggleMovementMode()
	if Config.MovementMode == "BulkMoveTo" then
		Config.MovementMode = "Motor6D"
	else
		Config.MovementMode = "BulkMoveTo"
	end

	if Caster then
		Caster:SetMovementModeEnabled(
			true,
			Config.MovementMode
		)
	end

	print(("MovementMode: %s"):format(
		Config.MovementMode
		))
end

local function toggleObjectCache()
	Config.ObjectCacheEnabled =
		not Config.ObjectCacheEnabled

	applyObjectCache()

	print(("ObjectCache: %s"):format(
		Config.ObjectCacheEnabled
			and "Enabled"
			or "Disabled"
		))
end

local function toggleVisualization()
	Config.VisualizeCasts =
		not Config.VisualizeCasts

	CastBehavior.VisualizeCasts =
		Config.VisualizeCasts

	print(("VisualizeCasts: %s"):format(
		Config.VisualizeCasts
			and "Enabled"
			or "Disabled"
		))
end

local function cycleHighFidelity()
	local current = CastBehavior.HighFidelityBehavior

	if current == FastCastEnums.HighFidelityBehavior.Default then

		CastBehavior.HighFidelityBehavior =
			FastCastEnums.HighFidelityBehavior.Automatic

	elseif current == FastCastEnums.HighFidelityBehavior.Automatic then

		CastBehavior.HighFidelityBehavior =
			FastCastEnums.HighFidelityBehavior.Always

	else

		CastBehavior.HighFidelityBehavior =
			FastCastEnums.HighFidelityBehavior.Default

	end

	print(("HighFidelityBehavior: %s"):format(
		getHighFidelityName()
		))
end

local function changeSegmentSize(amount)
	CastBehavior.HighFidelitySegmentSize = math.max(
		Config.MinSegmentSize,
		CastBehavior.HighFidelitySegmentSize + amount
	)

	print(("HighFidelitySegmentSize: %.2f"):format(
		CastBehavior.HighFidelitySegmentSize
		))
end

local function changeProjectileAmount(amount)
	Config.ProjectileAmount = math.max(
		0,
		Config.ProjectileAmount + amount
	)

	print(("ProjectileAmount: %d"):format(
		Config.ProjectileAmount
		))
end

--// Worker Configuration

local function changeWorkerCount(amount)
	if IsBenchmarking or IsReconfiguring then
		return
	end

	local newCount = math.max(
		Config.MinWorkers,
		Config.NumWorkers + amount
	)

	if newCount == Config.NumWorkers then
		return
	end

	IsReconfiguring = true

	Config.NumWorkers = newCount

	rebuildCaster()

	print(("numWorkers: %d"):format(
		Config.NumWorkers
		))

	task.wait(NUM_WORKERS_CHANGE_COOLDOWN)

	IsReconfiguring = false
end

--// Help

local function showHelp()
	printSection("FastCast2 Server Benchmark Keys")

	print("Type these commands in chat:")

	print("p - Start benchmark")
	print("l - Increase projectile amount by 500")
	print("k - Decrease projectile amount by 500")
	print("u - Toggle Instanced / Instanceless")
	print("j - Toggle BulkMoveTo / Motor6D")
	print("y - Toggle ObjectCache")
	print("v - Toggle VisualizeCasts")
	print("r - Cycle Raycast / Blockcast / Spherecast")
	print("x - Cycle HighFidelityBehavior")
	print("> - Increase HighFidelitySegmentSize")
	print("< - Decrease HighFidelitySegmentSize")
	print("] - Increment numWorkers")
	print("[ - Decrement numWorkers")
	print("i - Show benchmark information")
	print("h - Show this help")
end

--// Command Handlers

local Commands = {
	p = runBenchmark,

	l = function()
		if not IsBenchmarking then
			changeProjectileAmount(Config.ProjectileStep)
		end
	end,

	k = function()
		if not IsBenchmarking then
			changeProjectileAmount(-Config.ProjectileStep)
		end
	end,

	u = function()
		if not IsBenchmarking then
			toggleInstancing()
		end
	end,

	j = function()
		if not IsBenchmarking and not IsReconfiguring then
			toggleMovementMode()
		end
	end,

	y = function()
		if not IsBenchmarking and not IsReconfiguring then
			toggleObjectCache()
		end
	end,

	v = function()
		if not IsBenchmarking then
			toggleVisualization()
		end
	end,

	r = function()
		if not IsBenchmarking then
			cycleCastType()
		end
	end,

	x = function()
		if not IsBenchmarking then
			cycleHighFidelity()
		end
	end,

	[">"] = function()
		if not IsBenchmarking then
			changeSegmentSize(Config.SegmentSizeStep)
		end
	end,

	["."] = function()
		if not IsBenchmarking then
			changeSegmentSize(Config.SegmentSizeStep)
		end
	end,

	["<"] = function()
		if not IsBenchmarking then
			changeSegmentSize(-Config.SegmentSizeStep)
		end
	end,

	[","] = function()
		if not IsBenchmarking then
			changeSegmentSize(-Config.SegmentSizeStep)
		end
	end,

	["["] = function()
		changeWorkerCount(-Config.WorkerStep)
	end,

	["]"] = function()
		changeWorkerCount(Config.WorkerStep)
	end,

	i = function()
		if not IsBenchmarking then
			printBenchmarkInfo()
		end
	end,

	h = showHelp,
}


--// Input Handling

-- Maps Enum.KeyCode names (sent by the client) to Commands keys.
local KeyNameToCommand = {
	P = "p",
	L = "l",
	K = "k",
	U = "u",
	J = "j",
	Y = "y",
	V = "v",
	X = "x",
	R = "r",
	I = "i",
	H = "h",

	Period = ">",
	Comma = "<",
	LeftBracket = "[",
	RightBracket = "]",
}

local function runCommand(command)
	local handler = Commands[command]

	if handler then
		handler()
	end
end

--// ByteNet (client key input)

BenchmarkPackets.Input.listen(function(keyName)
	if typeof(keyName) ~= "string" then
		return
	end

	-- The server benchmark is parallel-only, so B has no effect here.
	if keyName == "B" then
		print("Serial / Parallel toggle isn't available on the server (Parallel only).")
		return
	end

	local command = KeyNameToCommand[keyName]

	if command then
		runCommand(command)
	end
end)

--// Initialization

rebuildCaster()

showHelp()
printBenchmarkInfo()
