--[[
	- Author : Mawin CK
	- Date : 11/03/2025
]]

-- Modules

-- REPLACE WITH ACTUAL PATH (Just use ObjectValue lol)
--local Rep = game:GetService("ReplicatedStorage")
--local FastCast2Module = Rep:WaitForChild("FastCast2")

local FastCast2Module: ModuleScript = script:WaitForChild("FastCast2", 10).Value :: ModuleScript


-- Requires
local BaseCastParallel = require(FastCast2Module:WaitForChild("BaseCastParallel"))

-- Variables
local actor = script:GetActor()
if actor == nil then
	error("The script must placed inside of actor")
end

local BaseCast = nil

-- Listeners

actor:BindToMessage("Init", function(Data: any?)
	BaseCast = BaseCastParallel.Init(script.Parent:WaitForChild("Output"), Data)
end)

actor:BindToMessage("Raycast", function(
	origin: Vector3,
	direction: Vector3,
	velocity: Vector3 | number,
	behavior: any
)
	warn(("[DEBUG] VM RECV Raycast: behavior=%s, behavior.RaycastParams=%s"):format(tostring(behavior), tostring(behavior and behavior.RaycastParams)))

	BaseCast:Raycast(origin, direction, velocity, behavior)
end)

actor:BindToMessage(
	"SetFastCastEventsModule",
	function(moduleScript: ModuleScript?)
		BaseCast:SetFastCastEventsModule(moduleScript)
	end
)

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

actor:BindToMessage("Blockcast", function(
	origin: Vector3,
	size: Vector3,
	direction: Vector3,
	velocity: Vector3 | number,
	behavior: any
)
	BaseCast:Blockcast(origin, size, direction, velocity, behavior)
end)

actor:BindToMessage("Spherecast", function(
	origin : Vector3,
	radius : number,
	direction : Vector3,
	velocity : Vector3 | number,
	behavior :any
)
	BaseCast:Spherecast(origin, radius, direction, velocity, behavior)
end)

actor:BindToMessage("SetMovementMode", function(mode: "BulkMoveTo" | "Motor6D", enabled: boolean)
	BaseCast:SetMovementMode(mode, enabled)
end)

-- CleanUp

actor:BindToMessage("Destroy", function()
	BaseCast:Destroy()
	script.Parent:Destroy()
end)
