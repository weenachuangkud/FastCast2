--[[
	- Author : Mawin CK
	- Date : 2025
	

	Motor6D Pool for efficient projectile movement using Transform mode.
	Like SwiftCast implementation.
]]

local GROWTH_RATE = 2
local INITIAL_POOL_SIZE = 128

local FreeMotor6Ds = {} :: { Motor6D }
local PoolSize = 0
local Initialized = false

local Motor6DAnchor: BasePart = nil

local function GrowPool(target: number)
	local growth = target - PoolSize
	for i = 1, growth do
		local motor6d = Instance.new("Motor6D")
		motor6d.Name = "FastCastMotor6D"
		table.insert(FreeMotor6Ds, motor6d)
	end
	PoolSize = target
end

local function Initialize()
	if Initialized then return end

	Motor6DAnchor = Instance.new("Part")
	Motor6DAnchor.Name = "FastCastAnchor"
	Motor6DAnchor.Transparency = 1
	Motor6DAnchor.CanCollide = false
	Motor6DAnchor.CanQuery = false
	Motor6DAnchor.CanTouch = false
	Motor6DAnchor.Anchored = true
	Motor6DAnchor.CFrame = CFrame.identity
	Motor6DAnchor.Parent = workspace

	GrowPool(INITIAL_POOL_SIZE)
	Initialized = true
end

local function Get(): Motor6D
	if #FreeMotor6Ds == 0 then
		GrowPool(PoolSize * GROWTH_RATE)
	end
	return table.remove(FreeMotor6Ds) :: Motor6D
end

local function Return(motor6d: Motor6D)
	motor6d.Part0 = nil
	motor6d.Part1 = nil
	motor6d.Parent = nil
	motor6d.Transform = CFrame.identity
	table.insert(FreeMotor6Ds, motor6d)
end

local function Connect(castID: number, projectilePart: BasePart?): Motor6D?
	if not projectilePart then return nil end

	projectilePart.Anchored = false

	local motor6d = Get()
	motor6d.Transform = projectilePart.CFrame
	motor6d.Part0 = Motor6DAnchor
	motor6d.Part1 = projectilePart
	motor6d.Parent = Motor6DAnchor

	return motor6d
end

local function Disconnect(motor6d: Motor6D?)
	if motor6d then
		Return(motor6d)
	end
end

return {
	Initialize = Initialize,
	Get = Get,
	Return = Return,
	Connect = Connect,
	Disconnect = Disconnect
}