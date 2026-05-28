--[[
	- Author Mawin CK
	- Date: 2026
]]

print("Starting benchmark in 10 seconds")
task.wait(10)

-- Services
local RS = game:GetService("RunService")
local Rep = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

-- Setting
local numWorkers = 4
local Instanced = false
-- BulkMoveTo | Motor6D
local MovementMode = "BulkMoveTo"
local UseObjectCache = false
local ProjectileAmount = 500
local BENCH_TIME = 5

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

-- Character
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

-- CastParams
local CastParams = RaycastParams.new()
CastParams.FilterDescendantsInstances = {character}
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
castBehavior.CosmeticBulletTemplate = Instanced and ProjectileTemplate or nil

-- Parallel Caster
local Caster = FastCast.newParallel()
Caster:Init(
	numWorkers,              -- numWorkers
	SSS,       -- newParent
	"CastVMs",      -- newName
	SSS,       -- ContainerParent
	"CastVMContainer", -- VMContainerName
	"CastVM",       -- VMname
	MovementMode
)

if UseObjectCache and Instanced then
	Caster:SetObjectCacheEnabled(
		true,
		ProjectileTemplate,
		ProjectileAmount,
		ProjectileContainer
	)
end

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

print("=== PARALLEL MODE BENCHMARK ===")
print(string.format("Firing %d projectiles...", ProjectileTemplate))

for _ = 1, ProjectileAmount do
	Caster:RaycastFire(
				--[[
					You can modify if you want :P
				]]
		Vector3.new(
			math.random(-100, 100),
			math.random(0, 100),
			math.random(-100, 100)
		),
		Vector3.new(
			math.random(-1, 1) * 1,
			math.random(-1, 1) * 1,
			math.random(-1, 1) * 1
		),
		6,
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

task.wait(3)

print("=== DONE ===")
summary()