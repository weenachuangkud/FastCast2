--!strict
-- Services
local UserInputService = game:GetService("UserInputService")
local Rep = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Modules
local FastCast2 = Rep:WaitForChild("FastCast2")
local FastCastTypes = require(FastCast2:WaitForChild("TypeDefinitions"))

-- ============================================================
-- Types
-- ============================================================

-- IntCountEvent is a Signal, not an RBXScriptConnection
type IntCountSignal = { Fire: (self: any, amount: number) -> () }

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

local currentBehavior: FastCastTypes.FastCastBehavior = nil :: any
local currentVelocity: number = 50
local currentCaster: FastCastTypes.Caster = nil :: any
local intCountEvent: IntCountSignal = nil :: any

local debounce = false
local connection: RBXScriptConnection? = nil

-- ============================================================
-- Module
-- ============================================================

local module = {}

function module.Start(
	newIntCountEvent: IntCountSignal,
	newCaster: FastCastTypes.Caster,
	newVelocity: number,
	newBehavior: FastCastTypes.FastCastBehavior
)
	currentBehavior = newBehavior
	currentVelocity = newVelocity
	currentCaster = newCaster
	intCountEvent = newIntCountEvent

	connection = UserInputService.InputBegan:Connect(function(input: InputObject, gp: boolean)
		if gp or debounce then return end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			debounce = true

			local origin = Head.Position
			local direction = (mouse.Hit.Position - origin).Unit

			currentCaster:RaycastFire(origin, direction, currentVelocity, currentBehavior)
			intCountEvent:Fire(1)

			task.delay(DEBOUNCE_TIME, function()
				debounce = false
			end)
		end
	end)
end

function module.Update(
	newCaster: FastCastTypes.Caster,
	newVelocity: number,
	newBehavior: FastCastTypes.FastCastBehavior
)
	currentCaster = newCaster
	currentVelocity = newVelocity
	currentBehavior = newBehavior
end

function module.Stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	debounce = false
end

return module
