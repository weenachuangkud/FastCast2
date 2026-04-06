-- Services
local RS = game:GetService("RunService")
local Rep = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local RepFirst = game:GetService("ReplicatedFirst")

-- Requires
local FastCastM = require(Rep:WaitForChild("FastCast2"))

-- Variables
local ProjectileContainer = Instance.new("Folder")
ProjectileContainer.Name = "FastCast2PJ"
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

-- FPS rs 
local start = tick()
local updateRate = 0.5
local fpsTable = {}
local averageFps = 0
local maxFps = 0
local minFps = 0
local delta = 0

RS.Heartbeat:Connect(function(dt: number)
    local fps = 1/dt -- NOTE: You can math.floor this
    if fps > maxFps then
       maxFps = fps
    end
    
    if fps < minFps then
       minFps = fps
    end
    
    delta = fps
    table.insert(fpsTable, fps)
    
    if tick() >= start + updateRate then
       local totalFps = 0
       for _, vFps in fpsTable do 
           totalFps += vFps
       end
       
       averageFps = totalFps / #fpsTable
       fpsTable = {}
       start = tick()
    end
end)

-- CastParams
local CastParams = RaycastParams.new()
CastParams.FilterDescendantsInstances = {character}
CastParams.FilterType = Enum.RaycastFilterType.Exclude
CastParams.IgnoreWater = true

-- Behavior
local castBehavior = FastCastM.newBehavior()
castBehavior.MaxDistance = 999999999
castBehavior.RaycastParams = CastParams
castBehavior.HighFidelityBehavior = 1
castBehavior.HighFidelitySegmentSize = 1
castBehavior.Acceleration = Vector3.new(0, 0, 0)
castBehavior.AutoIgnoreContainer = true
castBehavior.CosmeticBulletContainer = ProjectileContainer
castBehavior.CosmeticBulletTemplate = ProjectileTemplate
for i, v in castBehavior.FastCastEventsConfig do
    v = false
end
 
for i, v in castBehavior.FastCastEventsModuleConfig do
    v = false
end 
castBehavior.FastCastEventsConfig.UseCastFire = true


-- Caster
local activeCasts = {}
local Caster = FastCastM.new()
Caster:Init(
	4,
	RepFirst,
	"CastVMs",
	RepFirst,
	"CastVMContainer",
	"CastVM",
	true
)
Caster.CastFire = function(cast)
    table.insert(activeCasts, cast)
end

-- Functions
local function summary()
   print("Delta: " .. tostring(delta))
   print("Average fps: " .. tostring(averageFps))
   print("Max fps: " .. tostring(maxFps))
   print("Min fps: " .. tostring(minFps))
end

-- Benchmark
local isBenchmarking = false
local AMOUNT = 5000
local BENCH_TIME = 5
local VEC = 35

UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if isBenchmarking then return end
    if input.KeyCode == Enum.KeyCode.E then
       isBenchmarking = true
       for i = 1, AMOUNT do
           Caster:RaycastFire(
             Vector3.new(
               math.random(-1, 1)
               5000
               math.random(-1, 1)
             ),
             Vector3.new(
               math.random(-1, 1)
               5000,
               math.random(-1, 1)
             ),
             VEC,
             castBehavior
           )
        end
        print("Creating activeCasts")
        print("--------------------")
        summary()
        print("--------------------")
        task.wait(BENCH_TIME)
        print("Simulate")
        print("--------------------")
        summary()
        print("--------------------")
        for i, v in activeCasts do
            FastCastM:TerminateCast(v)
        end
        print("DESTROY")
        print("--------------------")
        summary()
        print("--------------------")
        isBenchmarking = false
    end
end)
