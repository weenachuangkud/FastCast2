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

-- Mozilla Public License 2.0 (files originally from FastCast)

--[[
	- Modified by: Mawin CK 
	- Date : 2025
]]

-- Verison : 0.0.4

--[=[
	@class FastCast

	FastCast is the root class of the module and offers the surface level methods required to make it work. This is the object returned from `require(FastCast)`.
]=]


-- Services
local HTTPService = game:GetService("HttpService")

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

-- Local functions

local function DestroySignal(signal : Signal.Signal)
	if type(signal) == "table" then
		signal:Destroy()
	else
		signal = nil
	end
end

--[=[
	Creates a new FastCastBehavior, which contains information necessary to Fire the cast properly.
	
	@return FastCastBehavior
]=]
function FastCast.newBehavior() : TypeDef.FastCastBehavior
	return DefaultConfigs.FastCastBehavior :: TypeDef.FastCastBehavior
end

local DEFAULT_FASTCAST_BEHAVIOR = FastCast.newBehavior()

--[=[
	:::warning

	You must [initialize](FastCast#Init) the Caster before using it. Failing to do so will result in nothing happening when attempting to fire!

	:::
	Contructs a new Caster object.
	@function new
	@within FastCast
	@return Caster
]=]
function FastCast.new() : TypeDef.Caster
	return setmetatable({
		LengthChanged = Signal.new(),
		RayHit = Signal.new(),
		RayPierced = Signal.new(),
		CastTerminating = Signal.new(),
		CastFire = Signal.new(),
		WorldRoot = workspace,
		Dispatcher = nil,
		AlreadyInit = false
	} :: any, FastCast) :: TypeDef.Caster
end

--[=[
	Initializes the Caster with the given parameters. This is required before firing using Raycasts in the Caster or nothing will happen!
	@method Init
	@within FastCast

	@param numWorkers number -- The number of worker VMs to create for this Caster. Must be greater than 1.
	@param newParent Folder -- The Folder in which to place the FastCastVMs Folder
	@param newName string -- The name to give the FastCastVMs Folder containing worker scripts.
	@param ContainerParent Folder -- The parent Folder in which to place the worker VM Containers.
	@param VMContainerName Folder -- The name to give to the Containers housing each worker VM.
	@param VMname string -- The name to give each worker VM.
	@param useBulkMoveTo boolean -- Whether to enable BulkMoveTo for the [CosmeticBulletObjects](TypeDefinitions#CastRayInfo)
	@param useObjectCache boolean -- Whether to use ObjectCache for the [Caster](TypeDefinitions#Caster)
	@param Template BasePart | Model -- The template object to use for the ObjectCache (if enabled)
	@param CacheSize number -- The size of the ObjectCache (if enabled)
	@param CacheHolder Instance -- The Instance in which to place cached objects (if enabled)
]=]
function FastCast:Init(
	numWorkers : number, 
	newParent : Folder, 
	newName : string,
	ContainerParent : Folder,
	VMContainerName : string,
	VMname : string,
	
	useBulkMoveTo : boolean,

	useObjectCache : boolean,
	Template : BasePart | Model,
	CacheSize : number,
	CacheHolder : Instance
)
	if self.AlreadyInit then
		 warn("Cannot Init more than 1") 
		 return 
	end
	assert(numWorkers > 1, "numWorker must be more than 1")

	local DispatcherClone = DispatcherModule:Clone()
	DispatcherClone.Parent = newParent
	DispatcherClone.Name = newName or "FastCastVMs"

	local newDispatcher : Dispatcher.Dispatcher = require(DispatcherClone) :: Dispatcher.Dispatcher

	newDispatcher.Init(ContainerParent,VMContainerName, VMname)
	--[[local data = {
		useBulkMoveTo = useBulkMoveTo,
		useObjectCache = useObjectCache,
		Template = Template,
		CacheSize = CacheSize,
		CacheHolder = CacheHolder
	}]]
	self.ObjectCache = useObjectCache and ObjectCache.new(Template, CacheSize, CacheHolder) :: any
	
	local data = {
		useBulkMoveTo = useBulkMoveTo,
		useObjectCache = useObjectCache,
		CacheHolder = CacheHolder
	}
	self.Dispatcher = newDispatcher.new(numWorkers, data, function(signalName : string, ...)
		local f = self[signalName]
		if not f then return end

		if type(f) == "function" then
			f(...)
		else
			f:Fire(...)
		end
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
	
	local Dispatcher = self.Dispatcher

	repeat task.wait() until #Dispatcher.Threads == numWorkers
	--print("STARTED CONNECTING")

	for i, v in Dispatcher.Threads do
		-- Please dont change this to FindFirstChild, or else diddy will oil you up
		local BindableObjectCache : BindableFunction = v:WaitForChild("ActiveCastObjectCache") :: BindableFunction
		if BindableObjectCache then
			--print("CONNECTED")
			BindableObjectCache.OnInvoke = function(v : CFrame)
				--print("INVOKED")
				return self.ObjectCache:GetPart(v)
			end -- OH MY GOD
		end -- KEEP GOING
	end -- OH YES DADDY
end

--[=[
	Raycasts the Caster with the specified parameters.
	@method RaycastFire
	@within FastCast

	@param origin Vector3 -- The origin of the raycast.
	@param direction Vector3 -- The direction of the raycast.
	@param velocity Vector3 | number -- The velocity of the raycast.
	@param BehaviorData FastCastBehavior? -- The behavior data for the raycast.
	@return string -- The ActiveCast ID of the fired raycast.
]=]
function FastCast:RaycastFire(origin: Vector3, direction: Vector3, velocity: Vector3 | number, BehaviorData: TypeDef.FastCastBehavior?)
	if not self.AlreadyInit then error("Please Init caster") end
	if BehaviorData == nil then BehaviorData = DEFAULT_FASTCAST_BEHAVIOR end
	local ActiveCastID = HTTPService:GenerateGUID(false)

	-- BABE RAYCAST!!!!!
	self.Dispatcher:Dispatch("Raycast", origin, direction, velocity, BehaviorData, ActiveCastID)
	return ActiveCastID
end

--[=[
	Blockcasts the Caster with the specified parameters.
	@method BlockcastFire
	@within FastCast

	@param origin Vector3 -- The origin of the blockcast.
	@param Size Vector3 -- The size of the blockcast.
	@param direction Vector3 -- The direction of the blockcast.
	@param velocity Vector3 | number -- The velocity of the raycast.
	@param BehaviorData FastCastBehavior? -- The behavior data for the raycast.
	@return string -- The ActiveCast ID of the fired raycast.
]=]
function FastCast:BlockcastFire(origin : Vector3, Size : Vector3, direction : Vector3, velocity : Vector3 | number, BehaviorData: TypeDef.FastCastBehavior?)
	if not self.AlreadyInit then error("Please Init caster") end
	if BehaviorData == nil then BehaviorData = DEFAULT_FASTCAST_BEHAVIOR end
	local ActiveCastID = HTTPService:GenerateGUID(false)

	self.Dispatcher:Dispatch("Blockcast", origin, Size, direction, velocity, BehaviorData, ActiveCastID)
	return ActiveCastID
end

--[=[
	Calls a function safely.
	@method SafeCall
	@within FastCast
	@private

	@param f (any)
	@return any -- The result of the function call.
]=]
function FastCast:SafeCall(f : (...any) -> (...any), ...)
	-- am i tripping
	if f then
		f(...)
	end
end

--[=[
	Sets whether BulkMoveTo is enabled for this Caster.
	@method SetBulkMoveEnabled
	@within FastCast

	@param enabled boolean
]=]
function FastCast:SetBulkMoveEnabled(enabled : boolean)
	if not self.AlreadyInit or not self.Dispatcher then
		warn("Caster not initialized", self)
	end

	self.Dispatcher:DispatchAll("BindBulkMoveTo", enabled)
	--[[local Dispatcher = self.Dispatcher
	for Index, Thread in Dispatcher.Threads do
		Thread:SendMessage("BindBulkMoveTo", enabled)
	end]]
end

--[=[
	Sets whether ObjectCache is enabled for this Caster.
	It is recommended to interface with this via [`FastCast:Init()`](FastCast#Init) instead.
	@method SetObjectCacheEnabled
	@within FastCast

	@param enabled boolean
]=]
function FastCast:SetObjectCacheEnabled(enabled : boolean, Template : BasePart | Model, CacheSize : number, CacheHolder : Instance)
	local Dispatcher = self.Dispatcher
	
	if enabled then
		self.ObjectCache = ObjectCache.new(Template, CacheSize, CacheHolder)
		Dispatcher:DispatchAll("BindObjectCache", enabled)
		
		for i, v in Dispatcher.Threads do
			-- Please dont change this to FindFirstChild, or else diddy will oil you up
			local BindableObjectCache : BindableFunction = v:WaitForChild("ActiveCastObjectCache") :: BindableFunction
			if BindableObjectCache then
				--print("CONNECTED")
				BindableObjectCache.OnInvoke = function(v : CFrame)
					--print("INVOKED")
					return self.ObjectCache:GetPart(v)
				end -- OH MY GOD
			end -- KEEP GOING
		end -- OH YES DADDY
		
	else
		Dispatcher:DispatchAll("BindObjectCache", enabled)
		if self.ObjectCache then
			self.ObjectCache:Destroy()
		end
		
		if self.ObjectCacheConnection then
			self.ObjectCacheConnection.OnInvoke = nil
		end
	end
	--[[for Index, Thread in Dispatcher.Threads do
		Thread:SendMessage("BindObjectCache", enabled)
	end]]
end


--[[function FastCast:SetVisualizeCasts(bool : boolean)
	Configs.VisualizeCasts = bool
end]]

--[=[
	:::warning

	Don't call this method if you didn't enable ObjectCache in [FastCast:Init()](FastCast#Init) or via [FastCast:SetObjectCacheEnabled()](FastCast#SetObjectCacheEnabled). Doing so will result in an error.

	:::
	Returns a part to the `ObjectCache` for reuse.
	@method ReturnObject
	@within FastCast

	@param obj Instance -- The object to return to the cache.
]=]
function FastCast:ReturnObject(obj : Instance)
	self.ObjectCache:ReturnPart(obj)
end

--[=[
	Destroy's a Caster, cleaning up all resources used by it.
	@method Destroy
	@within FastCast
]=]
function FastCast:Destroy()
	if self.ObjectCache then
		self.ObjectCache:Destroy()
	end
	if self.ObjectCacheConnection then
		self.ObjectCacheConnection.OnInvoke = nil
	end
	
	-- I'm making sure that everything is destroyed here lmao
	DestroySignal(self.LengthChanged)
	DestroySignal(self.RayHit)
	DestroySignal(self.RayPierced)
	DestroySignal(self.CastTerminating)
	DestroySignal(self.CastFire)
	
	self.Dispatcher:Destroy()
	setmetatable(self, nil)
end

return FastCast
