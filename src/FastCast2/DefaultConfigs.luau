--[[
	- Author : Mawin_CK
	- Date : 2025
	-- Verison : 0.0.4
]]

--!strict

-- Requires

local FastCastEnums = require(script.Parent:WaitForChild("FastCastEnums"))

-- Defaults

local Defaults = {}

-- Configs

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
	
	-- Performance
	AutomaticPerformance = true,
	AdaptivePerformance = {
		HighFidelitySegmentSizeIncrease = 0.5,
		LowerHighFidelityBehavior = true
	},
	
	-- Debug
	VisualizeCasts = false,
	VisualizeCastSettings = {
		-- Segment
		Debug_SegmentColor = Color3.new(),
		Debug_SegmentTransparency = 0.75,
		Debug_SegmentSize = 0.10,
		
		-- Hit
		Debug_HitColor = Color3.new(0.2, 1, 0.5),
		Debug_HitTransparency = 0.5,
		Debug_HitSize = 0.25,
		
		-- Raypierce 
		Debug_RayPierceColor = Color3.new(1, 0.2, 0.2),
		Debug_RayPierceTransparency = 0.25,
		Debug_RayPierceSize = 0.4,
		
		-- Lifetime
		Debug_RayLifetime = 1, 
		Debug_HitLifetime = 1
	}
}

return Defaults
