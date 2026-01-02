--[[
	- Author : Mawin_CK
	- Date : 2025
	-- Verison : 0.0.3
]]

--!strict

-- Requires

local FastCastEnums = require(script.Parent:WaitForChild("FastCastEnums"))

-- Defaults

local Defaults = {}

---> Configs

Defaults.VisualizationFolderName = "FastCastVisualizationObjects"

-- Behavior

Defaults.FastCastBehavior = {
	RaycastParams = nil,
	Acceleration = Vector3.new(),
	MaxDistance = 1000,
	CanPierceFunction = nil,
	HighFidelityBehavior = FastCastEnums.HighFidelityBehavior.Default,
	HighFidelitySegmentSize = 0.5,
	CosmeticBulletTemplate = nil,
	CosmeticBulletProvider = nil,
	CosmeticBulletContainer = nil,
	UseLengthChanged = true,
	AutoIgnoreContainer = true,
	SimulateAfterPhysic = true,
	AutomaticPerformance = true,
	AdaptivePerformance = {
		HighFidelitySegmentSizeIncrease = 0.5,
		LowerHighFidelityBehavior = true
	}
}

return Defaults
