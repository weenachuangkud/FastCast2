-- Services
local UIS = game:GetService("UserInputService")
local Rep = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Modules
local FastCast2 = Rep:WaitForChild("FastCast2")

-- Requires
local FastCastTypes = require(FastCast2:WaitForChild("TypeDefinitions"))
local Jolt = require(Rep:WaitForChild("Jolt"))

-- Variables
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

local Head: BasePart = character:WaitForChild("Head")

local mouse = player:GetMouse()

local debounce = false
local debounce_time = 0.01

local connection: RBXScriptConnection = nil

-- Events
local ServerProjectile = Jolt.Client("ServerProjectile") :: Jolt.Client<Vector3, Vector3, number>

-- Module

local module = {}

function module.Start()
	connection = UIS.InputBegan:Connect(function(Input: InputObject, gp: boolean)
		if gp then return end
		if debounce then return end

		if Input.UserInputType == Enum.UserInputType.MouseButton1 then
			debounce = true

			local Origin = Head.Position
			local Direction = (mouse.Hit.Position - Origin).Unit

			ServerProjectile:Fire(Origin, Direction)

			task.wait(debounce_time)
			debounce = false
		end
	end)
end

function module.Update(newCaster: FastCastTypes.Caster, newVelocity: number, newBehavior: FastCastTypes.Behavior)
	
end

function module.Stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	debounce = false
end

return module
