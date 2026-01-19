--[[
	- Author : Mawin CK
	- Date : 2025
	-- Verison : 0.0.3
]]

--!strict

--[=[

@class FastCastEnums
Enums for FastCast2.

]=]

local Enums = {}


--[=[

How High-Fidelity the cast simulation should be.
@type HighFidelityBehavior {Default, Automatic, Always}
@within FastCastEnums

]=]
Enums.HighFidelityBehavior = {
	Default = 1,
	Automatic = 2,
	Always = 3
}

return Enums
