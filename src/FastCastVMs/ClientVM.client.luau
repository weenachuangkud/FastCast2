--[[
	- Author : Mawin CK
	- Date : 11/03/2025
]]

-- Modules

-- Variables
local actor = script:GetActor()
if actor == nil then
	error("The script must placed inside of actor")
end

local BaseCastParallel = nil
local BaseCast = nil

-- Listeners

actor:BindToMessage("Init", function(Data: any?)
	BaseCastParallel = require(Data.FastCastModule:WaitForChild("BaseCastParallel"))
	BaseCast = BaseCastParallel.Init(
		script.Parent:WaitForChild("Output"), 
		Data
	)
end)

actor:BindToMessage("Raycast", function(
	origin: Vector3,
	direction: Vector3,
	velocity: Vector3 | number,
	behavior: any
)
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

actor:BindToMessage("SetMovementModeEnabled", function(mode: "BulkMoveTo" | "Motor6D", enabled: boolean)
	BaseCast:SetMovementModeEnabled(enabled, mode)
end)

actor:BindToMessage("BindObjectCache", function(
	enabled: boolean,
	Template: BasePart?,
	CacheSize: number?,
	CacheHolder: Instance?
)
	BaseCast:BindObjectCache(enabled, Template, CacheSize, CacheHolder)
end)

-- CleanUp

actor:BindToMessage("Destroy", function()
	BaseCast:Destroy()
	script.Parent:Destroy()
end)
