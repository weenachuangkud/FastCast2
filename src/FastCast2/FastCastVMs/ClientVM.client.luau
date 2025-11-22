--[[
	- Author : Mawin CK
	- Date : 11/03/2025
]]

-- Services
local Rep = game:GetService("ReplicatedStorage")

-- Modules

local GunEngine = Rep:WaitForChild("Gun_Engine")
local Modules = GunEngine:WaitForChild("Modules")
local Libraries = Modules:WaitForChild("Libraries")

local FastCast2Module = Libraries:WaitForChild("FastCast2")

-- Requires

local ActiveCast = require(FastCast2Module:WaitForChild("ActiveCast"))
local ActiveBlockcast = require(FastCast2Module:WaitForChild("ActiveBlockcast"))

local TypeDef = require(FastCast2Module:WaitForChild("TypeDefinitions"))
--local SharedCasters = require(FastCast2Module:WaitForChild("SharedCasters"))

--local parent = script.Parent
--local bindableEvent = parent:WaitForChild("Output")

local BaseCast = require(FastCast2Module:WaitForChild("BaseCast"))

-- Variables
local actor = script:GetActor()
if actor == nil then error("The script must placed inside of actor") end

-- Listeners

actor:BindToMessage("Init", function(Data : any?)
	BaseCast = BaseCast.Init(
		script.Parent:WaitForChild("Output"), 
		Data
	)
end)

actor:BindToMessage("Raycast", function(
	origin : Vector3,
	direction : Vector3,
	velocity : Vector3 | number,
	behavior : TypeDef.FastCastBehavior
)
	--print(behavior)
	--print(SharedCasters[casterID])
	--StoredCasts[casterID][ID] = ActiveCast.new(bindableEvent, origin, direction, velocity, behavior)

	BaseCast:Raycast(origin, direction, velocity, behavior)
end)

--[[actor:BindToMessage("Blockcast", function(
	casterID : string,
	caster : TypeDef.ActiveBlockCast,
	ID : string,
	origin : Vector3,
	size : Vector3,
	direction : Vector3 | number,
	velocity : Vector3,
	behavior : TypeDef.FastCastBehavior?
)
	StoredCasts[casterID][ID] = ActiveBlockcast.new(caster, origin, size, direction, velocity, behavior)
end)]]

actor:BindToMessage("Blockcast", function(
	origin : Vector3,
	size : Vector3,
	direction : Vector3,
	velocity : Vector3 | number,
	behavior : TypeDef.FastCastBehavior
)
	--print(behavior)
	--print(SharedCasters[casterID])
	--StoredCasts[casterID][ID] = ActiveCast.new(bindableEvent, origin, direction, velocity, behavior)

	BaseCast:Blockcast(origin, size, direction, velocity, behavior)
end)

actor:BindToMessage("Destroy", function()
	BaseCast:Destroy()
	script.Parent:Destroy()
end)
