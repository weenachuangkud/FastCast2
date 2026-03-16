-- Services
local Rep = game:GetService("ReplicatedStorage")

-- Modules

local FastCast2 = Rep:WaitForChild("FastCast2")

-- Requires
local TypeDef = require(FastCast2:WaitForChild("TypeDefinitions"))

-- Module

local module: TypeDef.FastCastEvents = {}

local debounce = false
local debounce_time = 0.2

module.LengthChanged = function()
	if not debounce then
		debounce = true
		print("OnLengthChanged Test")
		task.delay(debounce_time, function()
			debounce = false
		end)
	end
end

module.CastFire = function()
	print("CastFire!")
end

module.CastTerminating = function()
	print("CastTerminating!")
end

module.Hit = function()
	print("Hit!")
end

module.CanPierce = function(_, resultOfCast : RaycastResult)
	local CanPierce = false
	if resultOfCast.Instance:GetAttribute("CanPierce") == true then
		CanPierce = true
	end
	print(CanPierce)
	return CanPierce
end

module.Pierced = function()
	print("Pierced!")
end


return module
