--[[
	Written by Eti the Spirit (18406183)
	
		The latest patch notes can be located here (and do note, the version at the top of this script might be outdated. I have a thing for forgetting to change it):
		>	https://etithespirit.github.io/FastCastAPIDocs/changelog
		
		*** If anything is broken, please don't hesitate to message me! ***
		
		YOU CAN FIND IMPORTANT USAGE INFORMATION HERE: https://etithespirit.github.io/FastCastAPIDocs
		YOU CAN FIND IMPORTANT USAGE INFORMATION HERE: https://etithespirit.github.io/FastCastAPIDocs
		YOU CAN FIND IMPORTANT USAGE INFORMATION HERE: https://etithespirit.github.io/FastCastAPIDocs
		
		YOU SHOULD ONLY CREATE ONE CASTER PER GUN.
		YOU SHOULD >>>NEVER<<< CREATE A NEW CASTER EVERY TIME THE GUN NEEDS TO BE FIRED.
		
		A caster (created with FastCast.new()) represents a "gun".
		When you consider a gun, you think of stats like accuracy, bullet speed, etc. This is the info a caster stores. 
	
	--
	
	This is a library used to create hitscan-based guns that simulate projectile physics.
	
	This means:
		- You don't have to worry about bullet lag / jittering
		- You don't have to worry about keeping bullets at a low speed due to physics being finnicky between clients
		- You don't have to worry about misfires in bullet's Touched event (e.g. where it may going so fast that it doesn't register)
		
	Hitscan-based guns are commonly seen in the form of laser beams, among other things. Hitscan simply raycasts out to a target
	and says whether it hit or not.
	
	Unfortunately, while reliable in terms of saying if something got hit or not, this method alone cannot be used if you wish
	to implement bullet travel time into a weapon. As a result of that, I made this library - an excellent remedy to this dilemma.
	
	FastCast is intended to be require()'d once in a script, as you can create as many casters as you need with FastCast.new()
	This is generally handy since you can store settings and information in these casters, and even send them out to other scripts via events
	for use.
	
	Remember -- A "Caster" represents an entire gun (or whatever is launching your projectiles), *NOT* the individual bullets.
	Make the caster once, then use the caster to fire your bullets. Do not make a caster for each bullet.
--]]

--[[
	- Author : Mawin CK
	- Date : 2025
]]

--!strict

-- Services
--local HTTPS = game:GetService("HttpService")

-- Modules
--local BaseCast = script:WaitForChild("BaseCast")

-- Requires
local Signal = require(script:WaitForChild("Signal"))
local TypeDef = require(script:WaitForChild("TypeDefinitions"))
local DefaultConfigs = require(script:WaitForChild("DefaultConfigs"))
local Configs = require(script:WaitForChild("Configs"))
local ActiveCast = require(script:WaitForChild("ActiveCast"))
local ObjectCache = require(script:WaitForChild("ObjectCache"))

--local SharedCasters = require(script:WaitForChild("SharedCasters"))


local DispatcherModule = script:WaitForChild("FastCastVMs")
local Dispatcher = require(DispatcherModule)

-- Types
type vaildcast = TypeDef.ActiveCast | TypeDef.ActiveBlockCast

-- FastCast

local FastCast = {}

--[[
If true, verbose debug logging will be used, 
	printing detailed information about what's going on during processing to the output.
]]

FastCast.__index = FastCast
FastCast.__type = "FastCast"

--[[
	<p>
	<strong>Creates a new FastCastBehavior, which contains information necessary to Fire the cast properly.</strong>
	
	@return FastCastBehavior
	
	<strong>Which Contains : </strong>
		- Parallel = true,
		- RaycastParams = nil,
		- Acceleration = Vector3.new(),
		- MaxDistance = 1000,
		- CanPierceFunction = nil,
		- HighFidelityBehavior = TypeDef.HighFidelityBehavior.Default,
		- HighFidelitySegmentSize = 0.5,
		- CosmeticBulletTemplate = nil,
		- CosmeticBulletProvider = nil,
		- CosmeticBulletContainer = nil,
		- AutoIgnoreContainer = true
	
	</p>
]]
function FastCast.newBehavior() : TypeDef.FastCastBehavior
	return DefaultConfigs.FastCastBehavior
end

local DEFAULT_FASTCAST_BEHAVIOR = FastCast.newBehavior()

--[[
	<strong>Construct a new Caster instance</strong>, 
	which represents an entire gun or other projectile launching system
	
	<strong>RBXScriptSignal</strong> : 
		<p>- LengthChanged(
		casterThatFired : ActiveCast | ActiveBlockcast, 
		lastPoint : Vector3, 
		rayDir : Vector3, 
		displacement : number, 
		segmentVelocity : Vector3, 
		cosmeticBulletObject : Instance
		)
		<strong>Fires whenever the total length of the casted line changes.</strong>
		
		- RayHit(
		casterThatFired : ActiveCast | ActiveBlockcast, 
		result : RaycastResult, 
		segmentVelocity : Vector3, 
		cosmeticBulletObject : Instance
		)
		<strong>Fires when a raycast hits part.</strong>
		
		- RayPierced(
		casterThatFired : ActiveCast | ActiveBlockcast, 
		result : RaycastResult, 
		segmentVelocity : Vector3, 
		cosmeticBulletObject : Instance
		)
		<strong>Fires when a raycast pierces a part.</strong>
		
		- CastTerminating(casterThatFired : ActiveCast | ActiveBlockcast)
		<strong>Fires when the cast is cancelled by the user.</strong>
		</p>
		
	@return Caster
]]
function FastCast.new() : TypeDef.Caster
	return setmetatable({
		LengthChanged = Signal.new(),
		RayHit = Signal.new(),
		RayPierced = Signal.new(),
		CastTerminating = Signal.new(),
		WorldRoot = workspace,
		Dispatcher = nil,
		AlreadyInit = false,
		
		--id = HTTPS:GenerateGUID(false)
	} :: any, FastCast) :: TypeDef.Caster
end

function FastCast:Init(
	numWorkers : number, 
	newParent : Folder, 
	newName : string,
	ContainerParent : Folder,
	VMContainerName : string,
	VMname : string,
	
	useObjectCache : boolean,
	Template : BasePart | Model,
	CacheSize : number,
	CacheHolder : Instance
)
	if self.AlreadyInit then warn("Cannot Init more than 1") return end
	assert(numWorkers > 1, "numWorker must be more than 1")
	
	local DispatcherClone = DispatcherModule:Clone()
	DispatcherClone.Parent = newParent
	DispatcherClone.Name = newName or "FastCastVMs"
	
	local newDispatcher : Dispatcher.Dispatcher = require(DispatcherClone) :: Dispatcher.Dispatcher
	
	newDispatcher.Init(ContainerParent,VMContainerName, VMname)
	local data = {
		useObjectCache = useObjectCache,
		Template = Template,
		CacheSize = CacheSize,
		CacheHolder = CacheHolder
	}
	self.ObjectCache = useObjectCache and ObjectCache.new(Template, CacheSize, CacheHolder) :: any
	local data = {
		useObjectCache = useObjectCache,
		CacheHolder = CacheHolder
	}
	self.Dispatcher = newDispatcher.new(numWorkers, data, function(signalName : string, ...)
		self[signalName]:Fire(...)
	end)
	
	-- Idk who tf write this
	--[[if not shared.SharedCasters then
		shared.SharedCasters = {}
	end
	
	if not shared.SharedCasters[self.id] then
		shared.SharedCasters[self.id] = {}
		print("SET ID CASTER")
	end]]
	--print(self.Dispatcher)
	self.AlreadyInit = true
	
	if not useObjectCache then return end
	
	repeat task.wait() until #self.Dispatcher.Threads == numWorkers
	
	for i, v in self.Dispatcher.Threads do
		local BindableObjectCache : BindableFunction = v:FindFirstChild("ActiveCastObjectCache") :: BindableFunction
		if BindableObjectCache then
			--print("CONNECTED")
			BindableObjectCache.OnInvoke = function(v : CFrame)
				return self.ObjectCache:GetPart(v)
			end
		end
	end
end

function FastCast:RaycastFire(origin: Vector3, direction: Vector3, velocity: Vector3 | number, BehaviorData: TypeDef.FastCastBehavior?)-- : string
	if not self.AlreadyInit then error("Please Init caster") end
	if BehaviorData == nil then BehaviorData = DEFAULT_FASTCAST_BEHAVIOR end
	
	--local ActiveCastID = HTTPS:GenerateGUID(false)
	--self.Dispatcher:Dispatch("Raycast", self.id, ActiveCastID, origin, direction, velocity, BehaviorData)
	--local newActiveCast : TypeDef.ActiveCast = ActiveCast.new(self, origin, direction, velocity, BehaviorData :: TypeDef.FastCastBehavior) 
	--return newActiveCast

	-- BABE RAYCAST!!!!!
	self.Dispatcher:Dispatch("Raycast", origin, direction, velocity, BehaviorData)
	--return ActiveCastID
end

function FastCast:BlockcastFire(origin : Vector3, Size : Vector3, direction : Vector3, velocity : Vector3 | number, BehaviorData: TypeDef.FastCastBehavior?)
	if not self.AlreadyInit then error("Please Init caster") end
	if BehaviorData == nil then BehaviorData = DEFAULT_FASTCAST_BEHAVIOR end
	
	self.Dispatcher:Dispatch("Blockcast", origin, Size, direction, velocity, BehaviorData)
end

function FastCast:SafeCall(f : (...any) -> (...any), ...)
	if f then
		f(...)
	end
end

function FastCast:SetVisualizeCasts(bool : boolean)
	Configs.VisualizeCasts = bool
end

function FastCast:ReturnObject(obj : Instance)
	self.ObjectCache:ReturnPart(obj)
end

function FastCast:Destroy()
	self.ObjectCache:Destroy()
	self.Dispatcher:Destroy()
	setmetatable(self, nil)
end

return FastCast
