--[[
	- Author : Mawin_CK
	- Date : 2025
	
]]

--!strict

-- Requires

local TypeDefinitions = require(script.Parent.TypeDefinitions)
local FastCastEnums = require(script.Parent:WaitForChild("FastCastEnums"))

-- Defaults

local Defaults = {}

Defaults.VisualizationFolderName = "FastCastVisualizationObjects"

-- Behavior

Defaults.FastCastBehavior = {
	RaycastParams = nil,
	Acceleration = Vector3.new(),
	MaxDistance = 1000,
	HighFidelityBehavior = FastCastEnums.HighFidelityBehavior.Default,
	HighFidelitySegmentSize = 0.5,

	MovementMethod = "BulkMoveTo", -- "BulkMoveTo" or "Transform"

	CosmeticBulletTemplate = nil,
	CosmeticBulletContainer = nil,

	AutoIgnoreContainer = true,

	FastCastEventsModuleConfig = {
		UseLengthChanged = false,
		UseHit = true,
		UsePierced = true,
		UseCastTerminating = true,
		UseCanPierce = true,
		UseCastFire = true
	},

	FastCastEventsConfig = {
		UseLengthChanged = false,
		UseHit = true,
		UsePierced = true,
		UseCastTerminating = true,
		UseCastFire = true
	}
} :: TypeDefinitions.FastCastBehavior

return Defaults
