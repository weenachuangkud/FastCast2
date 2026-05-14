-- Services
local RS = game:GetService("RunService")
local Rep = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local RepFirst = game:GetService("ReplicatedFirst")

-- Requires
local FastCast = require(Rep:WaitForChild("FastCast2"))

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
CastParams.FilterDescendantsInstances = {}
CastParams.FilterType = Enum.RaycastFilterType.Exclude
CastParams.IgnoreWater = true

-- Behavior
local castBehavior = FastCast.newBehavior()
castBehavior.MaxDistance = 999999999
castBehavior.RaycastParams = CastParams
castBehavior.HighFidelityBehavior = 1
castBehavior.HighFidelitySegmentSize = 1
castBehavior.Acceleration = Vector3.new(0, 0, 0)
castBehavior.AutoIgnoreContainer = true
castBehavior.CosmeticBulletContainer = ProjectileContainer
castBehavior.CosmeticBulletTemplate = ProjectileTemplate

-- Parallel Caster
local Caster = FastCast.newParallel()
Caster:Init(
	4,              -- numWorkers
	RepFirst,       -- newParent
	"CastVMs",      -- newName
	RepFirst,       -- ContainerParent
	"CastVMContainer", -- VMContainerName
	"CastVM"       -- VMname
)

local activeCasts = {}

Caster.CastFire = function(cast)
	table.insert(activeCasts, cast)
end

-- Functions
local function summary()
	print(string.format("Delta: %.2f ms", 1000 / currentFps))
	print(string.format("Average FPS: %.2f", averageFps))
	print(string.format("Max FPS: %.2f", maxFps))
	print(string.format("Min FPS: %.2f", minFps))
end

-- Benchmark
local isBenchmarking = false
local AMOUNT = 50
local BENCH_TIME = 5

UIS.InputBegan:Connect(function(input, gp)
	if gp then return end
	if isBenchmarking then return end
	if input.KeyCode == Enum.KeyCode.P then
		isBenchmarking = true
		print("=== PARALLEL MODE BENCHMARK ===")
		print(string.format("Firing %d casts...", AMOUNT))

		for i = 1, AMOUNT do
			Caster:RaycastFire(
				Vector3.new(
					math.random(-1, 1) * 5000,
					math.random(-1, 1) * 5000,
					math.random(-1, 1) * 5000
				),
				Vector3.new(
					math.random(-1, 1) * 5000,
					math.random(-1, 1) * 5000,
					math.random(-1, 1) * 5000
				),
				35,
				castBehavior
			)
		end

		print("=== CREATION COMPLETE ===")
		summary()

		task.wait(BENCH_TIME)

		print("=== SIMULATION COMPLETE ===")
		summary()

		print("=== CLEANUP ===")
		for i = #activeCasts, 1, -1 do
			FastCast.TerminateCast(activeCasts[i])
		end
		activeCasts = {}

		print("=== DONE ===")
		summary()
		isBenchmarking = false
	end
end)

print("Press P to start Parallel benchmark")