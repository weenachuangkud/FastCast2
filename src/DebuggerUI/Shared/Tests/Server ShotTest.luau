--!strict
-- Services
local UserInputService = game:GetService("UserInputService")
local Rep = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Modules
local FastCast2 = Rep:WaitForChild("FastCast2")
local FastCastTypes = require(FastCast2:WaitForChild("TypeDefinitions"))
local Jolt = require(Rep:WaitForChild("Jolt"))

-- ============================================================
-- Constants
-- ============================================================

local DEBOUNCE_TIME = 0.01

-- ============================================================
-- State
-- ============================================================

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local Head = character:WaitForChild("Head") :: BasePart
local mouse = player:GetMouse()

-- Kept as a module-level variable so Update() can refresh it
local currentVelocity: number = 50

local debounce = false
local connection: RBXScriptConnection? = nil

-- ============================================================
-- Jolt Events
-- ============================================================

local ServerProjectile = Jolt.Client("ServerProjectile") :: Jolt.Client<Vector3, Vector3, number>

-- ============================================================
-- Module
-- ============================================================

local module = {}

function module.Start(
	_intCountEvent: any, -- unused for server shots; server tracks its own count
	_caster: FastCastTypes.Caster,
	newVelocity: number,
	_behavior: FastCastTypes.FastCastBehavior
)
	currentVelocity = newVelocity

	connection = UserInputService.InputBegan:Connect(function(input: InputObject, gp: boolean)
		if gp or debounce then return end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			debounce = true

			local origin = Head.Position
			local direction = (mouse.Hit.Position - origin).Unit

			-- Pass velocity so server uses the same speed as the client expects
			ServerProjectile:Fire(origin, direction, currentVelocity)

			task.delay(DEBOUNCE_TIME, function()
				debounce = false
			end)
		end
	end)
end

function module.Update(
	_caster: FastCastTypes.Caster,
	newVelocity: number,
	_behavior: FastCastTypes.FastCastBehavior
)
	currentVelocity = newVelocity
end

function module.Stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	debounce = false
end

return module
