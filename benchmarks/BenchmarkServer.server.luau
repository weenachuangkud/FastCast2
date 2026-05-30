--[[
	- Author Mawin CK
	- Date: 2026
]]

--[[
	Interactive server benchmark.
	Type single letters in chat to control the benchmark (e.g. "p" to start).
	Type "h" for the full list of commands.
]]

-- Services
local RS = game:GetService("RunService")
local Rep = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

-- Settings (mutable via interactive controls)
local numWorkers = 4
local Instanced = false
local MovementMode = "BulkMoveTo"
local UseObjectCache = false
local ProjectileAmount = 500
local VisualizeCasts = false
local VELOCITY = 6

-- Requires
local FastCast = require(Rep:WaitForChild("FastCast2"))
local FastCastEnums = require(Rep:WaitForChild("FastCast2"):WaitForChild("FastCastEnums"))

-- Variables
local ProjectileContainer = Instance.new("Folder")
ProjectileContainer.Name = "FastCast2PJ_Parallel"
ProjectileContainer.Parent = workspace
local ProjectileTemplate = Instance.new("Part")
ProjectileTemplate.Name = "Projectile"
ProjectileTemplate.Parent = Rep
ProjectileTemplate.Size = Vector3.new(1,1,1)
ProjectileTemplate.CanCollide = false
ProjectileTemplate.Anchored = true
ProjectileTemplate.CanQuery = false
ProjectileTemplate.CanTouch = false
ProjectileTemplate.Position = Vector3.new(1,1,1)
ProjectileTemplate.Massless = true

-- FPS tracking
local startTime = tick()
local updateRate = 0.5
local fpsTable = {}
local averageFps = 0
local maxFps = 0
local minFps = math.huge
local currentFps = 0

RS.Heartbeat:Connect(function(dt: number)
	local fps = 1/dt
	currentFps = fps
	if fps > maxFps then
		maxFps = fps
	end
	if fps < minFps then
		minFps = fps
	end
	table.insert(fpsTable, fps)

	if tick() >= startTime + updateRate then
		local totalFps = 0
		for _, vFps in fpsTable do
			totalFps += vFps
		end
		averageFps = totalFps / #fpsTable
		fpsTable = {}
		startTime = tick()
	end
end)

-- CastParams
local CastParams = RaycastParams.new()
CastParams.FilterType = Enum.RaycastFilterType.Exclude
CastParams.IgnoreWater = true

-- Behavior
local castBehavior = FastCast.newBehavior()
castBehavior.MaxDistance = 999999999
castBehavior.RaycastParams = CastParams
castBehavior.HighFidelityBehavior = FastCastEnums.HighFidelityBehavior.Default
castBehavior.HighFidelitySegmentSize = 1
castBehavior.Acceleration = Vector3.new(0, 0, 0)
castBehavior.AutoIgnoreContainer = true
castBehavior.CosmeticBulletContainer = ProjectileContainer
castBehavior.CosmeticBulletTemplate = Instanced and ProjectileTemplate or nil
castBehavior.VisualizeCasts = VisualizeCasts

-- Caster
local Caster = nil
local activeCasts = {}

local function setupCaster()
	if Caster then
		Caster:Destroy()
	end

	Caster = FastCast.newParallel()
	Caster:Init(
		numWorkers,
		SSS,
		"CastVMs",
		SSS,
		"CastVMContainer",
		"CastVM",
		MovementMode
	)

	Caster.CastFire = function(cast)
		table.insert(activeCasts, cast)
	end

	if UseObjectCache then
		Caster:SetObjectCacheEnabled(
			true,
			ProjectileTemplate,
			ProjectileAmount,
			ProjectileContainer
		)
	end

	activeCasts = {}
end

-- Functions
local function summary()
	print(string.format("Delta: %.2f ms", 1000 / currentFps))
	print(string.format("Average FPS: %.2f", averageFps))
	print(string.format("Max FPS: %.2f", maxFps))
	print(string.format("Min FPS: %.2f", minFps))
end

local IsBenchmarking = false
local BENCH_TIME = 6

local function runBenchmark()
	if IsBenchmarking then
		return
	end

	IsBenchmarking = true

	print("=== PARALLEL MODE BENCHMARK ===")

	if Instanced and UseObjectCache then
		print("ObjectCache Enabled")
	else
		print("ObjectCache Disabled")
	end

	if VisualizeCasts then
		print("VisualizeCasts: Enabled")
	else
		print("VisualizeCasts: Disabled")
	end

	local current = castBehavior.HighFidelityBehavior
	if current == FastCastEnums.HighFidelityBehavior.Default then
		print("HighFidelityBehavior: Default")
	elseif current == FastCastEnums.HighFidelityBehavior.Automatic then
		print("HighFidelityBehavior: Automatic")
	else
		print("HighFidelityBehavior: Always")
	end

	if Caster.MovementMode == "BulkMoveTo" then
		print("MovementMode: BulkMoveTo")
	else
		print("MovementMode: Motor6D")
	end

	local mode = Instanced and "Instanced" or "Instanceless"
	print(mode)

	print("numWorkers: ", numWorkers)

	print(string.format("Firing %d projectiles...", ProjectileAmount))

	for _ = 1, ProjectileAmount do
		Caster:RaycastFire(
			Vector3.new(
				math.random(-100, 100),
				math.random(0, 100),
				math.random(-100, 100)
			),
			Vector3.new(
				math.random() * 2 - 1,
				math.random() * 2 - 1,
				math.random() * 2 - 1
			),
			VELOCITY,
			castBehavior
		)
	end

	task.wait()

	print("=== CREATION COMPLETE ===")
	summary()

	task.wait(BENCH_TIME)

	print("=== SIMULATION COMPLETE ===")
	summary()

	print("=== CLEANUP ===")
	for i = #activeCasts, 1, -1 do
		FastCast:TerminateCast(activeCasts[i])
	end
	activeCasts = {}

	task.wait(2.5)

	print("=== DONE ===")
	summary()

	IsBenchmarking = false
end

-- Interactive controls via Chat
local IsReconfiguring = false

local function onChatMessage(_, message)
	local msg = message:lower()

	if msg == "p" then
		if IsReconfiguring then
			return
		end
		runBenchmark()

	elseif msg == "l" then
		if IsBenchmarking then
			return
		end
		ProjectileAmount += 500
		print(string.format("ProjectileAmount: %d", ProjectileAmount))

	elseif msg == "k" then
		if IsBenchmarking then
			return
		end
		ProjectileAmount = math.max(0, ProjectileAmount - 500)
		print(string.format("ProjectileAmount: %d", ProjectileAmount))

	elseif msg == "u" then
		if IsBenchmarking then
			return
		end
		Instanced = not Instanced
		castBehavior.CosmeticBulletTemplate = Instanced and ProjectileTemplate or nil
		print(string.format("CosmeticBulletTemplate: %s", tostring(Instanced)))

	elseif msg == "j" then
		if IsReconfiguring then
			return
		end
		if IsBenchmarking then
			return
		end

		if Caster.MovementMode == "BulkMoveTo" then
			Caster:SetMovementModeEnabled(true, "Motor6D")
			print("MovementMode: Motor6D")
		else
			Caster:SetMovementModeEnabled(true, "BulkMoveTo")
			print("MovementMode: BulkMoveTo")
		end

	elseif msg == "y" then
		if IsReconfiguring then
			return
		end
		if IsBenchmarking then
			return
		end

		if UseObjectCache then
			Caster:SetObjectCacheEnabled(false)
			UseObjectCache = false
			print("ObjectCache: Disabled")
		else
			Caster:SetObjectCacheEnabled(
				true,
				ProjectileTemplate,
				ProjectileAmount,
				ProjectileContainer
			)
			UseObjectCache = true
			print("ObjectCache Enabled")
		end

	elseif msg == "v" then
		if IsBenchmarking then
			return
		end

		VisualizeCasts = not VisualizeCasts
		castBehavior.VisualizeCasts = VisualizeCasts
		if VisualizeCasts then
			print("VisualizeCasts: Enabled")
		else
			print("VisualizeCasts: Disabled")
		end

	elseif msg == "x" then
		if IsBenchmarking then
			return
		end

		local current = castBehavior.HighFidelityBehavior
		if current == FastCastEnums.HighFidelityBehavior.Default then
			castBehavior.HighFidelityBehavior = FastCastEnums.HighFidelityBehavior.Automatic
			print("HighFidelityBehavior: Automatic")
		elseif current == FastCastEnums.HighFidelityBehavior.Automatic then
			castBehavior.HighFidelityBehavior = FastCastEnums.HighFidelityBehavior.Always
			print("HighFidelityBehavior: Always")
		else
			castBehavior.HighFidelityBehavior = FastCastEnums.HighFidelityBehavior.Default
			print("HighFidelityBehavior: Default")
		end

	elseif msg == ">" or msg == "." then
		if IsBenchmarking then
			return
		end

		castBehavior.HighFidelitySegmentSize += 0.05
		print(string.format("HighFidelitySegmentSize: %.2f", castBehavior.HighFidelitySegmentSize))

	elseif msg == "<" or msg == "," then
		if IsBenchmarking then
			return
		end

		castBehavior.HighFidelitySegmentSize = math.max(0.05, castBehavior.HighFidelitySegmentSize - 0.05)
		print(string.format("HighFidelitySegmentSize: %.2f", castBehavior.HighFidelitySegmentSize))

	elseif msg == "]" then
		if IsReconfiguring then
			return
		end
		if IsBenchmarking then
			return
		end

		IsReconfiguring = true
		numWorkers += 1
		setupCaster()
		print("numWorkers: ", numWorkers)
		task.wait(0.05)
		IsReconfiguring = false

	elseif msg == "[" then
		if IsReconfiguring then
			return
		end
		if IsBenchmarking then
			return
		end
		if numWorkers <= 2 then
			return
		end

		IsReconfiguring = true
		numWorkers -= 1
		setupCaster()
		print("numWorkers: ", numWorkers)
		task.wait(0.05)
		IsReconfiguring = false

	elseif msg == "h" then
		print("Type in chat to control the benchmark:")
		print("p - Start benchmark")
		print("l - Increase projectile amount by 500")
		print("k - Decrease projectile amount by 500")
		print("u - Toggle Instanced/Instanceless")
		print("j - Toggle BulkMoveTo/Motor6D")
		print("y - Toggle ObjectCache")
		print("v - Toggle VisualizeCasts")
		print("x - Cycle HighFidelityBehavior")
		print("> - Increase HighFidelitySegmentSize")
		print("< - Decrease HighFidelitySegmentSize")
		print("] - Increment numWorkers")
		print("[ - Decrement numWorkers")
		print("h - Show this help")
	end
end

Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(message)
		onChatMessage(player, message)
	end)
end)

-- Initial setup
setupCaster()

print("=== FastCast2 Server Benchmark ===")
print("Type 'p' in chat to start benchmark")
print("Type 'h' in chat to show all commands")