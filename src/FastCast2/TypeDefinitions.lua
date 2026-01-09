--[[
	- Author : Mawin CK
	- Date : 2025
	-- Verison : 0.0.4
]]

--!strict

-- Requires
local Dispatcher = require(script.Parent:WaitForChild("FastCastVMs"))

-- Represents the function to determine piercing.
export type CanPierceFunction = (ActiveCast, RaycastResult, Vector3) -> boolean

export type OnRayHitFunction = (ActiveCast, RaycastResult, segmentVelocity : Vector3, cosmeticBulletObject : Instance?) -> ()
export type OnRayPierceFunction = (ActiveCast, RaycastResult, segmentVelocity : Vector3, cosmeticBulletObject : Instance?) -> ()
export type OnLengthChangedFunction = (
	ActiveCast, 
	lastPoint : Vector3, 
	rayDir : Vector3, 
	rayDisplacement : number, 
	segmentVelocity : Vector3, 
	cosmeticBulletObject : Instance?
) -> ()
export type OnCastTerminatingFunction = (ActiveCast) -> ()
export type OnCastFireFunction = (ActiveCast, Origin : Vector3, Direction : Vector3, Velocity : Vector3, behavior : FastCastBehavior) -> ()

-- Represents any table.
export type GenericTable = {[any]: any}

-- Represents a Caster :: https://etithespirit.github.io/FastCastAPIDocs/fastcast-objects/caster/
export type Caster = {
	WorldRoot: WorldRoot,
	LengthChanged: RBXScriptSignal,
	RayHit: RBXScriptSignal,
	RayPierced: RBXScriptSignal,
	CastTerminating: RBXScriptSignal,
	CastFire: RBXScriptSignal,
	Dispatcher : Dispatcher.Dispatcher,
	AlreadyInit : boolean,
	--id : string,
	
	Init : (
		Caster, 
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
	) -> (),
	
	-- CastFire
	
	RaycastFire: (Caster, Origin : Vector3, Direction : Vector3, Velocity : Vector3 | number, Behavior : FastCastBehavior) -> string,
	BlockcastFire: (Caster, Origin : Vector3, Size : Vector3, Direction : Vector3, Velocity : Vector3 | number, Behavior : FastCastBehavior) -> string,
	
	-- Utility ig
	
	SetBulkMoveEnabled : (enabled : boolean) -> (),
	SetObjectCacheEnabled : (enabled : boolean, Template : BasePart | Model, CacheSize : number, CacheHolder : Instance) -> (),

	SetVisualizeCasts : (bool : boolean) -> (),
	
	ReturnObject : (obj : Instance) -> (),
	
	Destroy : (Caster) -> ()
}

-- Settings
export type VisualizeCastSettings = {
	-- Segment
	Debug_SegmentColor: Color3,
	Debug_SegmentTransparency: number,
	Debug_SegmentSize: number,
	
	-- Hit
	Debug_HitColor: Color3,
	Debug_HitTransparency : number,
	Debug_HitSize : number,
	
	-- Raypierce
	Debug_RayPierceColor: Color3,
	Debug_RayPierceTransparency : number,
	Debug_RayPierceSize : number,
	
	-- Lifetime
	Debug_RayLifetime: number,
	Debug_HitLifetime: number
}

export type AdaptivePerformance = {
	HighFidelitySegmentSizeIncrease : number,
	LowerHighFidelityBehavior : boolean
}

-- Represents a FastCastBehavior :: https://etithespirit.github.io/FastCastAPIDocs/fastcast-objects/fcbehavior/
export type FastCastBehavior = {
	RaycastParams: RaycastParams?,
	MaxDistance: number,
	Acceleration: Vector3,
	HighFidelityBehavior: number,
	HighFidelitySegmentSize: number,
	CosmeticBulletTemplate: Instance?,
	--CosmeticBulletProvider: any, -- any ObjectPool Library Class(Unused)
	CosmeticBulletContainer: Instance?,
	AutoIgnoreContainer: boolean,
	CanPierceFunction: CanPierceFunction?,
	UseLengthChanged : boolean,
	SimulateAfterPhysic : boolean,
	
	-- Performance
	AutomaticPerformance : boolean,
	AdaptivePerformance : AdaptivePerformance,
	
	VisualizeCasts : boolean,
	VisualizeCastSettings : VisualizeCastSettings
}

-- Represents a CastTrajectory :: https://etithespirit.github.io/FastCastAPIDocs/fastcast-objects/casttrajectory/
export type CastTrajectory = {
	StartTime: number,
	EndTime: number,
	Origin: Vector3,
	InitialVelocity: Vector3,
	Acceleration: Vector3
}

-- Represents a CastStateInfo :: https://etithespirit.github.io/FastCastAPIDocs/fastcast-objects/caststateinfo/
export type CastStateInfo = {
	UpdateConnection: RBXScriptSignal,
	HighFidelityBehavior: number,
	HighFidelitySegmentSize: number,
	Paused: boolean,
	TotalRuntime: number,
	DistanceCovered: number,
	IsActivelySimulatingPierce: boolean,
	IsActivelyResimulating: boolean,
	CancelHighResCast: boolean,
	Trajectories: {[number]: CastTrajectory},
	UseLengthChanged : boolean,
	VisualizeCasts : boolean,
	VisualizeCastSettings : VisualizeCastSettings
}


-- Represents a CastRayInfo :: https://etithespirit.github.io/FastCastAPIDocs/fastcast-objects/castrayinfo/
export type CastRayInfo = {
	Parameters: RaycastParams,
	WorldRoot: WorldRoot,
	MaxDistance: number,
	CosmeticBulletObject: Instance?,
	CanPierceCallback: CanPierceFunction
}

--[[export type EventDefinition = {
	OnLengthChanged : OnLengthChangedFunction,
	OnRayHit : OnRayHitFunction,
	OnRayPierce : OnRayPierceFunction,
	OnCastTerminating : OnCastTerminatingFunction?
}]]

-- Represents an ActiveCast :: https://etithespirit.github.io/FastCastAPIDocs/fastcast-objects/activecast/
export type ActiveCast = {
	--Definition : {[string] : (...any) -> (...any)},
	Caster : BaseCastData,
	StateInfo: CastStateInfo,
	RayInfo: CastRayInfo,
	UserData: {[any]: any},
	
	
	SetVelocity : (ActiveCast, velocity : Vector3) -> (),
	SetAcceleration : (ActiveCast, acceleration: Vector3) -> (),
	
	GetVelocity : (ActiveCast) -> Vector3,
	GetAcceleration : (ActiveCast) -> Vector3,
	GetPosition : (ActiveCast) -> Vector3,
	
	AddVelocity : (ActiveCast, velocity: Vector3) -> (),
	AddAcceleration : (ActiveCast, acceleration: Vector3) -> (),
	AddPosition : (ActiveCast, position: Vector3) -> (),
	
	Pause : (ActiveCast) -> (),
	Resume : (ActiveCast) -> (),
	
	DestroyObject : (ActiveCast, obj : Instance) -> (),
	
	Destroy : (ActiveCast) -> (),
	Terminate : (ActiveCast) -> (),
	
	CFrame : CFrame,
	ID : string
}

-- BlockCast Mods
export type BlockCastRayInfo = {
	Parameters : RaycastParams,
	WorldRoot : WorldRoot,
	MaxDistance : number,
	CosmeticBulletObject : Instance?,
	CanPierceCallback: CanPierceFunction,
	Size : Vector3
}

export type ActiveBlockCast = {
	Caster : BaseCastData,
	StateInfo : CastStateInfo,
	RayInfo : BlockCastRayInfo,
	UserData : {[any] : any},
	
	SetVelocity : (ActiveCast, velocity : Vector3) -> (),
	SetAcceleration : (ActiveCast, acceleration: Vector3) -> (),

	GetVelocity : (ActiveCast) -> Vector3,
	GetAcceleration : (ActiveCast) -> Vector3,
	GetPosition : (ActiveCast) -> Vector3,

	AddVelocity : (ActiveCast, velocity: Vector3) -> (),
	AddAcceleration : (ActiveCast, acceleration: Vector3) -> (),
	AddPosition : (ActiveCast, position: Vector3) -> (),

	Pause : (ActiveCast) -> (),
	Resume : (ActiveCast) -> (),
	
	DestroyObject : (ActiveCast, obj : Instance) -> (),

	Destroy : (ActiveCast) -> (),
	Terminate : (ActiveCast) -> (),
	
	CFrame : CFrame,
	ID : string
}

-- BaseCast Mods

export type BaseCast = {
	Actives : {
		ActiveCast | ActiveBlockCast
	},
	Output : BindableEvent,
	ActiveCastCleaner : BindableEvent,
	ObjectCache : BindableFunction?,
	CacheHolder : any?
}

export type BaseCastData = {
	Output : BindableEvent,
	ActiveCastCleaner : BindableEvent,
	ObjectCache : BindableFunction?,
	CacheHolder : any?
}

return {}
