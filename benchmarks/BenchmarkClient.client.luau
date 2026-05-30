--[[
	- Author: Mawin CK
	- Date: 2026
]]

--[[
	I never wrote this to be readable
	But who cares.
]]

-- Services
local Rep = game:GetService("ReplicatedStorage")
local RepFirst = game:GetService("ReplicatedFirst")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("RunService")

-- Settings
local Path = Rep
local Parallel = true
local numWorkers = 4
local ProjectileAmount = 500
local Instanced = true
local VisualizeCasts = false
local BENCH_TIME = 6
local MovementMode = "BulkMoveTo"
local ObjectCacheEnabled = false
local VMName = "CastVMs"
local VMContainerName = "CastVMContainer"
local VMTemplateName = "CastVM"

local VELOCITY = 6

-- Modules
local FastCastM = Path:WaitForChild("FastCast2")

-- Requires
local FastCast = require(FastCastM)
local FastCastEnums = require(FastCastM:WaitForChild("FastCastEnums"))

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

-- castParams, Idk I just put this for a reason
local castParams = RaycastParams.new()
castParams.FilterType = Enum.RaycastFilterType.Exclude
castParams.IgnoreWater = true


-- Behavior
local castBehavior = FastCast.newBehavior()
castBehavior.MaxDistance = 999999999
castBehavior.HighFidelityBehavior = FastCastEnums.HighFidelityBehavior.Default
castBehavior.HighFidelitySegmentSize = 1
castBehavior.Acceleration = Vector3.new(0, 0, 0)
castBehavior.AutoIgnoreContainer = true
castBehavior.CosmeticBulletContainer = ProjectileContainer
castBehavior.CosmeticBulletTemplate = Instanced and ProjectileTemplate or nil
castBehavior.VisualizeCasts = VisualizeCasts
castBehavior.RaycastParams = castParams

-- Caster
local Caster = nil
if Parallel then
	Caster = FastCast.newParallel()
	Caster:Init(
		numWorkers,
		RepFirst,
		VMName,
		RepFirst,
		VMContainerName,
		VMTemplateName,
		MovementMode
	)
else
	Caster = FastCast.new()
	Caster:Init(
		MovementMode
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

local IsBenchmarking = false
local IsReconfiguring = false
local MODE = Parallel and "PARALLEL" or "SERIAL"

local function printBenchmarkInfo()
	print(string.format("=== %s MODE BENCHMARK ===", MODE))

	local isObjCache = false
	if Caster.BaseCast and Caster.BaseCast.ObjectCacheInstance then
		isObjCache = true
	end

	if Caster.ObjectCacheEnabled then
		isObjCache = true
	end

	if Instanced and isObjCache then
		print("ObjectCache Enabled")
	else
		print("ObjectCache Disabled")
	end

	if VisualizeCasts then
		print("VisualizeCasts: Enabled")
	else
		print("VisualizeCasts: Disabled")
	end

	local currentHF = castBehavior.HighFidelityBehavior
	if currentHF == FastCastEnums.HighFidelityBehavior.Default then
		print("HighFidelityBehavior: Default")
	elseif currentHF == FastCastEnums.HighFidelityBehavior.Automatic then
		print("HighFidelityBehavior: Automatic")
	else
		print("HighFidelityBehavior: Always")
	end

	print(string.format("HighFidelitySegmentSize: %.2f", castBehavior.HighFidelitySegmentSize))

	if Caster.MovementMode == "BulkMoveTo" then
		print("MovementMode: BulkMoveTo")
	else
		print("MovementMode: Motor6D")
	end

	local modeLabel = Instanced and "Instanced" or "Instanceless"
	print(modeLabel)

	if Parallel then
		print("numWorkers: ", numWorkers)
	end
end

-- UIS

UIS.InputBegan:Connect(function(input, gp)
	if gp then
		return
	end

	if input.KeyCode == Enum.KeyCode.P then
		if IsReconfiguring then
			return
		end
		
		if IsBenchmarking then
			return
		end
		
		IsBenchmarking = true

		maxFps = 0
		minFps = math.huge

		print(string.format("=== %s MODE BENCHMARK ===", MODE))
		local IsObjCache = false
		if Caster.BaseCast and Caster.BaseCast.ObjectCacheInstance then
			IsObjCache = true
		end

		if Caster.ObjectCacheEnabled then
			IsObjCache = true
		end
		
		if Instanced and IsObjCache then
			print("ObjectCache Enabled")
		else
			print("ObjectCache Disabled")
		end

		if VisualizeCasts then
			print("VisualizeCasts: Enabled")
		else
			print("VisualizeCasts: Disabled")
		end

		local currentHF = castBehavior.HighFidelityBehavior
		if currentHF == FastCastEnums.HighFidelityBehavior.Default then
			print("HighFidelityBehavior: Default")
		elseif currentHF == FastCastEnums.HighFidelityBehavior.Automatic then
			print("HighFidelityBehavior: Automatic")
		else
			print("HighFidelityBehavior: Always")
		end

		print(string.format("HighFidelitySegmentSize: %.2f", castBehavior.HighFidelitySegmentSize))

		if Caster.MovementMode == "BulkMoveTo" then
			print("MovementMode: BulkMoveTo")
		else
			print("MovementMode: Motor6D")
		end

		local modeLabel = Instanced and "Instanced" or "Instanceless"

		print(modeLabel)

		if Parallel then
			print("numWorkers: ", numWorkers)
		end

		print(string.format("Firing %d projectiles...", ProjectileAmount))

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
		
	elseif input.KeyCode == Enum.KeyCode.L then
		
		if IsBenchmarking then
			return
		end
		
		ProjectileAmount += 500
		print(string.format("ProjectileAmount: %d", ProjectileAmount))

	elseif input.KeyCode == Enum.KeyCode.K then
		
		if IsBenchmarking then
			return
		end
		
		ProjectileAmount = math.max(0, ProjectileAmount - 500)
		print(string.format("ProjectileAmount: %d", ProjectileAmount))

	elseif input.KeyCode == Enum.KeyCode.U then
		
		if IsBenchmarking then
			return
		end
		
		Instanced = not Instanced
		castBehavior.CosmeticBulletTemplate = Instanced and ProjectileTemplate or nil
		print(string.format("CosmeticBulletTemplate: %s", tostring(Instanced)))

	elseif input.KeyCode == Enum.KeyCode.J then
		
		if IsReconfiguring then
			return
		end
		
		if IsBenchmarking then
			return
		end
		
		if Caster.MovementMode == "BulkMoveTo" then
			Caster:SetMovementModeEnabled(true, "Motor6D")
			MovementMode = "Motor6D"
			print("MovementMode: Motor6D")
		else
			Caster:SetMovementModeEnabled(true, "BulkMoveTo")
			MovementMode = "BulkMoveTo"
			print("MovementMode: BulkMoveTo")
		end
		
	elseif input.KeyCode == Enum.KeyCode.Y then
		
		if IsReconfiguring then
			return
		end
		
		if IsBenchmarking then
			return
		end
		
		if Parallel then
			if Caster.ObjectCacheEnabled then
				Caster:SetObjectCacheEnabled(false)
				ObjectCacheEnabled = false
				print("ObjectCache: Disabled")
			else
				Caster:SetObjectCacheEnabled(
					true,
					ProjectileTemplate,
					ProjectileAmount,
					ProjectileContainer
				)
				ObjectCacheEnabled = true
				print("ObjectCache Enabled")
			end
		else
			if Caster.BaseCast and Caster.BaseCast.ObjectCacheInstance then
				Caster:SetObjectCacheEnabled(false)
				ObjectCacheEnabled = false
				print("ObjectCache: Disabled")
			else
				Caster:SetObjectCacheEnabled(
					true,
					ProjectileTemplate,
					ProjectileAmount,
					ProjectileContainer
				)
				ObjectCacheEnabled = true
				print("ObjectCache Enabled")
			end
		end
		
	elseif input.KeyCode == Enum.KeyCode.V then
		
		if IsBenchmarking then
			return
		end
		
		castBehavior.VisualizeCasts = not castBehavior.VisualizeCasts
		if castBehavior.VisualizeCasts then
			print("VisualizeCasts: Enabled")
		else
			print("VisualizeCasts: Disabled")
		end
		
	elseif input.KeyCode == Enum.KeyCode.X then
		
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
		
	elseif input.KeyCode == Enum.KeyCode.B then
		
		if IsReconfiguring then
			return
		end
		
		if IsBenchmarking then
			return
		end
		
		IsReconfiguring = true
		
		Parallel = not Parallel
		if Parallel then
			Caster:Destroy()
			
			Caster = FastCast.newParallel()
			Caster:Init(
				numWorkers,
				RepFirst,
				VMName,
				RepFirst,
				VMContainerName,
				VMTemplateName,
				MovementMode
			)
			Caster.CastFire = function(cast)
				table.insert(activeCasts, cast)
			end

			if ObjectCacheEnabled then
				Caster:SetObjectCacheEnabled(
					true,
					ProjectileTemplate,
					ProjectileAmount,
					ProjectileContainer
				)
			end

			print("Switched to Parallel..")

			MODE = "PARALLEL"
		else
			Caster:Destroy()
			
			Caster = FastCast.new()
			Caster:Init(
				MovementMode
			)
			Caster.CastFire = function(cast)
				table.insert(activeCasts, cast)
			end

			if ObjectCacheEnabled then
				Caster:SetObjectCacheEnabled(
					true,
					ProjectileTemplate,
					ProjectileAmount,
					ProjectileContainer
				)
			end

			print("Switched to Serial..")

			MODE = "SERIAL"
		end
		
		activeCasts = {}

		task.wait(2.5)
		IsReconfiguring = false
		print("Done!")

	elseif input.KeyCode == Enum.KeyCode.RightBracket then
		if IsBenchmarking then 
			return
		end
		
		if IsReconfiguring then
			return
		end

		IsReconfiguring = true
		
		numWorkers += 1

		if Parallel then
			Caster:Destroy()
			
			Caster = FastCast.newParallel()
			Caster:Init(
				numWorkers,
				RepFirst,
				VMName,
				RepFirst,
				VMContainerName,
				VMTemplateName,
				MovementMode
			)
			Caster.CastFire = function(cast)
				table.insert(activeCasts, cast)
			end

			if ObjectCacheEnabled then
				Caster:SetObjectCacheEnabled(
					true,
					ProjectileTemplate,
					ProjectileAmount,
					ProjectileContainer
				)
			end
		end

		print("numWorkers: ", numWorkers)

		task.wait(0.05)

		IsReconfiguring = false
	elseif input.KeyCode == Enum.KeyCode.LeftBracket then
		
		if IsBenchmarking then
			return
		end

		if IsReconfiguring then
			return
		end

		if numWorkers <= 2 then
			return
		end

		numWorkers -= 1

		if Parallel then
			Caster:Destroy()
			
			Caster = FastCast.newParallel()
			Caster:Init(
				numWorkers,
				RepFirst,
				VMName,
				RepFirst,
				VMContainerName,
				VMTemplateName,
				MovementMode
			)
			Caster.CastFire = function(cast)
				table.insert(activeCasts, cast)
			end

			if ObjectCacheEnabled then
				Caster:SetObjectCacheEnabled(
					true,
					ProjectileTemplate,
					ProjectileAmount,
					ProjectileContainer
				)
			end
		end

		print("numWorkers: ", numWorkers)

		task.wait(0.05)

		IsReconfiguring = false

	elseif input.KeyCode == Enum.KeyCode.Period then
		
		if IsBenchmarking then
			return
		end
		
		castBehavior.HighFidelitySegmentSize += 0.05
		print(string.format("HighFidelitySegmentSize: %.2f", castBehavior.HighFidelitySegmentSize))
		
	elseif input.KeyCode == Enum.KeyCode.Comma then
		
		if IsBenchmarking then
			return
		end
		
		castBehavior.HighFidelitySegmentSize = math.max(0.05, castBehavior.HighFidelitySegmentSize - 0.05)
		print(string.format("HighFidelitySegmentSize: %.2f", castBehavior.HighFidelitySegmentSize))
		
	elseif input.KeyCode == Enum.KeyCode.H then
		print("=== FastCast2 Client Benchmark Keys ===")
		print("Press P to benchmark")
		print("Press L to increase projectile amount by 500")
		print("Press K to decrease projectile amount by 500")
		print("Press U to switch Instanced or Instanceless")
		print("Press J to switch BulkMoveTo or Motor6D")
		print("Press Y to Enable or disable ObjectCache")
		print("Press V to Enable or disable VisualizeCasts")
		print("Press X to cycle HighFidelityBehavior")
		print("Press > to increase HighFidelitySegmentSize")
		print("Press < to decrease HighFidelitySegmentSize")
		print("Press B to switch Serial or Parallel")
		print("Press [ to decrement numWorkers")
		print("Press ] to increment numWorkers")
		print("Press I to show benchmark info")
		print("Press H to show keys again")

	elseif input.KeyCode == Enum.KeyCode.I then
		printBenchmarkInfo()
	end
end)

print("=== FastCast2 Client Benchmark Keys ===")
print("Press P to benchmark")
print("Press L to increase projectile amount by 500")
print("Press K to decrease projectile amount by 500")
print("Press U to switch Instanced or Instanceless")
print("Press J to switch BulkMoveTo or Motor6D")
print("Press Y to Enable or disable ObjectCache")
print("Press V to Enable or disable VisualizeCasts")
print("Press X to cycle HighFidelityBehavior")
print("Press > to increase HighFidelitySegmentSize")
print("Press < to decrease HighFidelitySegmentSize")
print("Press B to switch Serial or Parallel")
print("Press [ to decrement numWorkers")
print("Press ] to increment numWorkers")
print("Press I to show benchmark info")
print("Press H to show keys again")

printBenchmarkInfo()