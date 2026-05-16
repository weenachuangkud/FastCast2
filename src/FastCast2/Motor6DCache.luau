--[[
	- Author : Mawin CK
	- Date : 2026
	

	Motor6D Pool for efficient projectile movement using Transform mode.
	NOTE:
	I'm sorry for stealing some code bro shoutout to DrSinek, 
	I just wanted to make it more efficient and I didn't want to rewrite the whole thing
]]

-- Services
local HTTPS = game:GetService("HttpService")

local GROWTH_RATE = 2
local INITIAL_POOL_SIZE = 128

local Motor6DCache = {}
Motor6DCache.__index = Motor6DCache
Motor6DCache.__type = "Motor6DCache"

function Motor6DCache.new()
	local self = setmetatable({}, Motor6DCache)

	-- Folder
	local Motor6DFolder = Instance.new("Folder")
	Motor6DFolder.Parent = workspace
	Motor6DFolder.Name = "Motor6D" .. tostring(HTTPS:GenerateGUID())

	-- Motor6DAnchor
	local Motor6DAnchor: BasePart = Instance.new("Part")
	Motor6DAnchor.Name = "FastCastMotor6DAnchor"
	Motor6DAnchor.Transparency = 1
	Motor6DAnchor.CanCollide = false
	Motor6DAnchor.CanQuery = false
	Motor6DAnchor.CanTouch = false
	Motor6DAnchor.Anchored = true
	Motor6DAnchor.CFrame = CFrame.identity
	Motor6DAnchor.Parent = Motor6DFolder

	self.Motor6DFolder = Motor6DFolder
	self.Motor6DAnchor = Motor6DAnchor
	self.FreeMotor6Ds = {}
	self.PoolSize = 0

	self:GrowPool(INITIAL_POOL_SIZE)
	return self
end

function Motor6DCache:GrowPool(target: number)
	local growth = target - self.PoolSize
	for i = 1, growth do
		local motor6d = Instance.new("Motor6D")
		motor6d.Name = "FastCastMotor6D"
		table.insert(self.FreeMotor6Ds, motor6d)
	end
	self.PoolSize = target
end

function Motor6DCache:Get(): Motor6D
	if #self.FreeMotor6Ds == 0 then
		self:GrowPool(self.PoolSize * GROWTH_RATE)
	end
	return table.remove(self.FreeMotor6Ds) :: Motor6D
end

function Motor6DCache:Return(motor6d: Motor6D)
	motor6d.Part0 = nil
	motor6d.Part1 = nil
	motor6d.Parent = nil
	motor6d.Transform = CFrame.identity
	table.insert(self.FreeMotor6Ds, motor6d)
end

function Motor6DCache:Connect(projectilePart: BasePart?): Motor6D?
	if not projectilePart then return nil end

	projectilePart.Anchored = false

	local motor6d = self:Get()
	motor6d.Transform = projectilePart.CFrame
	motor6d.Part0 = self.Motor6DAnchor
	motor6d.Part1 = projectilePart
	motor6d.Parent = self.Motor6DAnchor

	return motor6d
end

function Motor6DCache:Disconnect(motor6d: Motor6D?)
	if motor6d then
		self:Return(motor6d)
	end
end

function Motor6DCache:Destroy()
	self.Motor6DFolder:Destroy()
	self.FreeMotor6Ds = {}
	self.PoolSize = 0
end

return Motor6DCache