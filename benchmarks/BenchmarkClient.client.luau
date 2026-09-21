--[[
	FastCast2 Client Benchmark
	Author: Mawin CK
	Date: 2026

	Controls:
		P       Benchmark
		L       +500 projectiles
		K       -500 projectiles
		U       Toggle Instanced / Instanceless
		J       Toggle BulkMoveTo / Motor6D
		Y       Toggle ObjectCache
		V       Toggle Cast Visualization
		X       Cycle HighFidelityBehavior
		>       Increase HighFidelitySegmentSize
		<       Decrease HighFidelitySegmentSize
		B       Toggle Serial / Parallel
		R       Cycle cast type
		[       Decrease workers
		]       Increase workers
		I       Show benchmark information
		H       Show controls
]]

--// Services

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

--// Configuration

local Config = {
	Parallel = true,
	NumWorkers = 4,

	ProjectileAmount = 500,
	Velocity = 6,
	CastType = "Raycast",
	RandomSeed = 2026,
	BlockcastSize = Vector3.one,
	SpherecastRadius = 0.5,

	Instanced = true,
	ObjectCacheEnabled = false,
	VisualizeCasts = false,

	BenchmarkDuration = 6,

	MovementMode = "BulkMoveTo",

	HighFidelitySegmentSizeStep = 0.05,
	MinHighFidelitySegmentSize = 0.05,

	MinWorkers = 2,
	ProjectileStep = 500,
}

--// Constants
local NUM_WORKERS_CHANGE_COOLDOWN = 4.5
local MODE_CHANGE_COOLDOWN = 2.5
local BENCHMARK_COOLDOWN = 2.5

--// Modules

local FastCastModule = ReplicatedStorage:WaitForChild("FastCast2")

local FastCast = require(FastCastModule)
local FastCastEnums = require(
	FastCastModule:WaitForChild("FastCastEnums")
)

--// Objects

local ProjectileContainer = Instance.new("Folder")
ProjectileContainer.Name = "FastCast2PJ"
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
CastBehavior.HighFidelityBehavior =
	FastCastEnums.HighFidelityBehavior.Default

CastBehavior.HighFidelitySegmentSize = 1
CastBehavior.Acceleration = Vector3.zero

CastBehavior.AutoIgnoreContainer = true

CastBehavior.CosmeticBulletContainer = ProjectileContainer
CastBehavior.CosmeticBulletTemplate = ProjectileTemplate

CastBehavior.VisualizeCasts = Config.VisualizeCasts
CastBehavior.RaycastParams = CastParams

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

local function getMode()
	return Config.Parallel and "PARALLEL" or "SERIAL"
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

local function printSeparator(title)
	print(("=== %s ==="):format(title))
end

--// Caster

local function onCastFire(cast)
	ActiveCasts[#ActiveCasts + 1] = cast
end

local function createCaster()
	local newCaster

	if Config.Parallel then
		newCaster = FastCast.newParallel()

		newCaster:Init(
			Config.NumWorkers,
			Config.MovementMode
		)
	else
		newCaster = FastCast.new()

		newCaster:Init(Config.MovementMode)
	end

	newCaster.CastFire = onCastFire

	return newCaster
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

local function destroyCaster()
	if Caster then
		Caster:Destroy()
		Caster = nil
	end

	table.clear(ActiveCasts)
end

local function rebuildCaster()
	destroyCaster()

	Caster = createCaster()
	applyObjectCache()
end

-- Create initial caster.
Caster = createCaster()
applyObjectCache()

--// Benchmark Information

local function printBenchmarkInfo()
	printSeparator(("%s MODE BENCHMARK"):format(getMode()))

	print(("Projectiles: %d"):format(Config.ProjectileAmount))
	print(("Velocity: %.2f"):format(Config.Velocity))
	print(("CastType: %s"):format(Config.CastType))

	print(
		"ObjectCache: %s",
		getObjectCacheState() and "Enabled" or "Disabled"
	)

	print(
		"Instanced: %s",
		Config.Instanced and "Enabled" or "Disabled"
	)

	print(
		"VisualizeCasts: %s",
		CastBehavior.VisualizeCasts and "Enabled" or "Disabled"
	)

	print(("HighFidelityBehavior: %s"):format(getHighFidelityName()))

	print(
		("HighFidelitySegmentSize: %.2f"):format(
			CastBehavior.HighFidelitySegmentSize
		)
	)

	print(("MovementMode: %s"):format(Config.MovementMode))

	print(("Mode: %s"):format(getMode()))

	if Config.Parallel then
		print(("numWorkers: %d"):format(Config.NumWorkers))
	end
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

--// Cleanup

local function cleanupCasts()
	for i = #ActiveCasts, 1, -1 do
		local cast = ActiveCasts[i]

		if cast then
			FastCast:TerminateCast(cast)
		end

		ActiveCasts[i] = nil
	end
end


--// Benchmark

local function benchmark()
	if IsBenchmarking or IsReconfiguring then
		return
	end

	IsBenchmarking = true

	print("=== BENCHMARK STARTED ===")

	local success, err = xpcall(function()

		printBenchmarkInfo()
		print(("Firing %d projectiles..."):format(Config.ProjectileAmount))

		-- Fire
		local creationStarted = os.clock()

		fireProjectiles()

		local creationElapsed = os.clock() - creationStarted

		task.wait()

		printSeparator("CREATION COMPLETE")
		printOperationStats(
			creationElapsed,
			Config.ProjectileAmount
		)

		-- Measure frames
		table.clear(FrameTimes)

		IsMeasuringFrames = true

		task.wait(Config.BenchmarkDuration)

		IsMeasuringFrames = false

		printSeparator("SIMULATION COMPLETE")
		printFrameStats()

		-- Cleanup
		printSeparator("CLEANUP")

		local cleanupStarted = os.clock()

		cleanupCasts()

		local cleanupElapsed = os.clock() - cleanupStarted

		printOperationStats(
			cleanupElapsed,
			Config.ProjectileAmount
		)

		-- Clear our references
		table.clear(ActiveCasts)

		-- Wait for FastCast to settle
		task.wait(BENCHMARK_COOLDOWN)

		-- IMPORTANT:
		-- Destroy the old caster and create a fresh one.
		print("Rebuilding caster...")

		rebuildCaster()

		print("Caster rebuilt.")

		printSeparator("DONE")

	end, debug.traceback)

	-- Always reset benchmark state
	IsMeasuringFrames = false
	IsBenchmarking = false

	if not success then
		warn("Benchmark error:")
		warn(err)

		-- Also recover from an error by creating a fresh caster
		task.defer(function()
			rebuildCaster()
			print("Caster recovered after benchmark error.")
		end)
	end

	print("IsBenchmarking =", IsBenchmarking)
	print("=== BENCHMARK READY ===")
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

--// Configuration Changes

local function toggleInstancing()
	Config.Instanced = not Config.Instanced

	CastBehavior.CosmeticBulletTemplate =
		Config.Instanced and ProjectileTemplate or nil

	print(
		("CosmeticBulletTemplate: %s"):format(
			Config.Instanced and "Enabled" or "Disabled"
		)
	)
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

	print(("MovementMode: %s"):format(Config.MovementMode))
end

local function toggleObjectCache()
	Config.ObjectCacheEnabled = not Config.ObjectCacheEnabled

	applyObjectCache()

	print(
		("ObjectCache: %s"):format(
			Config.ObjectCacheEnabled and "Enabled" or "Disabled"
		)
	)
end

local function toggleVisualization()
	CastBehavior.VisualizeCasts =
		not CastBehavior.VisualizeCasts

	print(
		("VisualizeCasts: %s"):format(
			CastBehavior.VisualizeCasts and "Enabled" or "Disabled"
		)
	)
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

	print(
		("HighFidelityBehavior: %s"):format(
			getHighFidelityName()
		)
	)
end

local function changeSegmentSize(amount)
	CastBehavior.HighFidelitySegmentSize = math.max(
		Config.MinHighFidelitySegmentSize,
		CastBehavior.HighFidelitySegmentSize + amount
	)

	print(
		("HighFidelitySegmentSize: %.2f"):format(
			CastBehavior.HighFidelitySegmentSize
		)
	)
end

local function changeProjectileAmount(amount)
	Config.ProjectileAmount = math.max(
		0,
		Config.ProjectileAmount + amount
	)

	print(
		("ProjectileAmount: %d"):format(
			Config.ProjectileAmount
		)
	)
end

--// Mode Switching

local function switchMode()
	if IsBenchmarking or IsReconfiguring then
		return
	end

	IsReconfiguring = true

	Config.Parallel = not Config.Parallel

	rebuildCaster()

	print(("Switched to %s."):format(getMode()))

	task.wait(MODE_CHANGE_COOLDOWN)

	IsReconfiguring = false

	print("Done!")
end

local function changeWorkerCount(amount)
	if IsBenchmarking or IsReconfiguring then
		return
	end

	if not Config.Parallel then
		print("Worker count only applies to Parallel mode.")
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

	print(("numWorkers: %d"):format(Config.NumWorkers))

	task.wait(NUM_WORKERS_CHANGE_COOLDOWN)

	IsReconfiguring = false
end

--// Controls

local function showControls()
	printSeparator("FastCast2 Client Benchmark Keys")

	print("P  - Benchmark")
	print("L  - Increase projectile amount by 500")
	print("K  - Decrease projectile amount by 500")
	print("U  - Toggle Instanced / Instanceless")
	print("J  - Toggle BulkMoveTo / Motor6D")
	print("Y  - Toggle ObjectCache")
	print("V  - Toggle VisualizeCasts")
	print("X  - Cycle HighFidelityBehavior")
	print(">  - Increase HighFidelitySegmentSize")
	print("<  - Decrease HighFidelitySegmentSize")
	print("B  - Toggle Serial / Parallel")
	print("R  - Cycle Raycast / Blockcast / Spherecast")
	print("[  - Decrease numWorkers")
	print("]  - Increase numWorkers")
	print("I  - Show benchmark info")
	print("H  - Show controls")
end

--// Keybind Table

local Keybinds = {
	[Enum.KeyCode.P] = benchmark,

	[Enum.KeyCode.L] = function()
		if not IsBenchmarking then
			changeProjectileAmount(Config.ProjectileStep)
		end
	end,

	[Enum.KeyCode.K] = function()
		if not IsBenchmarking then
			changeProjectileAmount(-Config.ProjectileStep)
		end
	end,

	[Enum.KeyCode.U] = function()
		if not IsBenchmarking then
			toggleInstancing()
		end
	end,

	[Enum.KeyCode.J] = function()
		if not IsBenchmarking and not IsReconfiguring then
			toggleMovementMode()
		end
	end,

	[Enum.KeyCode.Y] = function()
		if not IsBenchmarking and not IsReconfiguring then
			toggleObjectCache()
		end
	end,

	[Enum.KeyCode.V] = function()
		if not IsBenchmarking then
			toggleVisualization()
		end
	end,

	[Enum.KeyCode.X] = function()
		if not IsBenchmarking then
			cycleHighFidelity()
		end
	end,

	[Enum.KeyCode.B] = switchMode,

	[Enum.KeyCode.R] = function()
		if not IsBenchmarking then
			cycleCastType()
		end
	end,

	[Enum.KeyCode.LeftBracket] = function()
		changeWorkerCount(-1)
	end,

	[Enum.KeyCode.RightBracket] = function()
		changeWorkerCount(1)
	end,

	[Enum.KeyCode.Period] = function()
		if not IsBenchmarking then
			changeSegmentSize(
				Config.HighFidelitySegmentSizeStep
			)
		end
	end,

	[Enum.KeyCode.Comma] = function()
		if not IsBenchmarking then
			changeSegmentSize(
				-Config.HighFidelitySegmentSizeStep
			)
		end
	end,

	[Enum.KeyCode.H] = showControls,

	[Enum.KeyCode.I] = function()
		if not IsBenchmarking then
			printBenchmarkInfo()
		end
	end,
}

--// Input

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	local callback = Keybinds[input.KeyCode]

	if callback then
		callback()
	end
end)

--// Startup

showControls()
printBenchmarkInfo()
