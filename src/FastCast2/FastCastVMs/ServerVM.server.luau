--[[
	- Author : Mawin CK
	- Date : 11/03/2025
]]

-- Modules

-- REPLACE WITH ACTUAL PATH (Just use ObjectValue lol)
--local Rep = game:GetService("ReplicatedStorage")
--local FastCast2Module = Rep:WaitForChild("FastCast2")

local FastCast2Module = script:WaitForChild("FastCast2").Value


local TypeDefinitions = require(FastCast2Module:WaitForChild("TypeDefinitions"))
--local SharedCasters = require(FastCast2Module:WaitForChild("SharedCasters"))

--local parent = script.Parent
--local bindableEvent = parent:WaitForChild("Output")

local BaseCast = require(FastCast2Module:WaitForChild("BaseCast"))

-- Variables
local actor = script:GetActor()
if actor == nil then 
	error("The script must placed inside of actor")
end

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
	behavior : TypeDefinitions.FastCastBehavior
)
	--print(behavior)
	--print(SharedCasters[casterID])
	--StoredCasts[casterID][ID] = ActiveCast.new(bindableEvent, origin, direction, velocity, behavior)

	BaseCast:Raycast(origin, direction, velocity, behavior)
end)

--[[actor:BindToMessage("Blockcast", function(
	casterID : string,
	caster : TypeDefinitions.ActiveBlockCast,
	ID : string,
	origin : Vector3,
	size : Vector3,
	direction : Vector3 | number,
	velocity : Vector3,
	behavior : TypeDefinitions.FastCastBehavior?
)
	StoredCasts[casterID][ID] = ActiveBlockcast.new(caster, origin, size, direction, velocity, behavior)
end)]]

actor:BindToMessage(
	"SetFastCastEventsModule",
	function(moduleScript: ModuleScript?)
		BaseCast:SetFastCastEventsModule(moduleScript)
	end
)

actor:BindToMessage("Blockcast", function(
	origin : Vector3,
	size : Vector3,
	direction : Vector3,
	velocity : Vector3 | number,
	behavior : TypeDefinitions.FastCastBehavior
)
	--print(behavior)
	--print(SharedCasters[casterID])
	--StoredCasts[casterID][ID] = ActiveCast.new(bindableEvent, origin, direction, velocity, behavior)

	BaseCast:Blockcast(origin, size, direction, velocity, behavior)
end)

actor:BindToMessage("Spherecast", function(
	origin : Vector3,
	radius : number,
	direction : Vector3,
	velocity : Vector3 | number,
	behavior : TypeDefinitions.FastCastBehavior
)
	BaseCast:SphereCast(origin, radius, direction, velocity, behavior)
end)

actor:BindToMessage("BindBulkMoveTo", function(bool : boolean)
	BaseCast:BindBulkMoveTo(bool)
end)

actor:BindToMessage("BindObjectCache", function(bool : boolean)
	BaseCast:BindObjectCache(bool)
end)

-- CleanUp

actor:BindToMessage("Destroy", function()
	BaseCast:Destroy()
	script.Parent:Destroy()
end)
