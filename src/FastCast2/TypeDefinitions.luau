--!strict

--[[
	- Author : Mawin CK
	- Date : 2025
	
]]

--[=[
	@class TypeDefinitions
	@tag Types

	Type definitions for strict-typing.
]=]

local Dispatcher = require(script.Parent:WaitForChild("FastCastVMs"))

--[=[
	@type vaildcast ActiveCastData | ActiveBlockcastData | ActiveSpherecastData
	@within TypeDefinitions

	A type that can be either an ActiveCast or an ActiveBlockcast.
]=]
type vaildcast = ActiveCastData | ActiveBlockcastData | ActiveSpherecastData

--[=[
	@type FastCastEventsModule ModuleScript
	@within TypeDefinitions

	A moduleScript that will be required by ActiveCast
]=]
export type FastCastEventsModule = ModuleScript

--[=[
	@type FastCastEvents { CanPierce: CanPierceFunction, Hit: OnHitFunction, Pierced: OnPiercedFunction, LengthChanged: OnLengthChangedFunction, CastTerminating: OnCastTerminatingFunction, CastFire: OnCastFireFunction }
	@within TypeDefinitions

	A table of callback functions (events/hooks) used by ActiveCast.
	These functions are invoked by ActiveCast during a lifecycle (e.g., length updates, pierce checks).
]=]
export type FastCastEvents = {
	CanPierce: CanPierceFunction,
	Hit: OnHitFunction,
	Pierced: OnPiercedFunction,
	LengthChanged: OnLengthChangedFunction,
	CastTerminating: OnCastTerminatingFunction,
	CastFire: OnCastFireFunction
}

--[=[
	@type CanPierceFunction (cast: vaildcast, result: RaycastResult, segmentVelocity: Vector3, cosmeticBulletObject: Instance?) -> boolean
	@within TypeDefinitions

	Callback used to decide whether a cast should pierce and continue after a hit.
]=]
export type CanPierceFunction = (
	cast: vaildcast,
	result: RaycastResult,
	segmentVelocity: Vector3,
	cosmeticBulletObject: Instance?
) -> boolean

--[=[
	@type OnHitFunction (cast: vaildcast, result: RaycastResult, segmentVelocity: Vector3, cosmeticBulletObject: Instance?) -> ()
	@within TypeDefinitions

	Callback fired when the cast hits something (non-piercing).
]=]
export type OnHitFunction = (
	cast: vaildcast,
	result: RaycastResult,
	segmentVelocity: Vector3,
	cosmeticBulletObject: Instance?
) -> ()

--[=[
	@type OnPierceFunction (cast: vaildcast, result: RaycastResult, segmentVelocity: Vector3, cosmeticBulletObject: Instance?) -> ()
	@within TypeDefinitions

	Callback fired when the cast pierces something.
]=]
export type OnPiercedFunction = (
	cast: vaildcast,
	result: RaycastResult,
	segmentVelocity: Vector3,
	cosmeticBulletObject: Instance?
) -> ()

--[=[
	@type OnLengthChangedFunction (cast: vaildcast, lastPoint: Vector3, rayDir: Vector3, rayDisplacement: number, segmentVelocity: Vector3, cosmeticBulletObject: Instance?) -> ()
	@within TypeDefinitions

	Callback fired when the cast's length changes as it updates.
]=]
export type OnLengthChangedFunction = (
	cast: vaildcast,
	lastPoint: Vector3,
	rayDir: Vector3,
	rayDisplacement: number,
	segmentVelocity: Vector3,
	cosmeticBulletObject: Instance?
) -> ()

--[=[
	@type OnCastTerminatingFunction (cast: vaildcast) -> ()
	@within TypeDefinitions

	Callback fired right as an ActiveCast is terminating.
]=]
export type OnCastTerminatingFunction = (cast:  vaildcast) -> ()

--[=[
	@type OnCastFireFunction (cast: vaildcast, lastPoint: Vector3, rayDir: Vector3, segmentVelocity: Vector3, behavior: FastCastBehavior) -> ()
	@within TypeDefinitions

	Callback fired when a cast is initially fired.
]=]
export type OnCastFireFunction = (
	cast: vaildcast,
	lastPoint: Vector3,
	rayDir: Vector3,
	segmentVelocity: Vector3,
	behavior: FastCastBehavior
) -> ()

-- Debug

--[=[
	@type VisualizeCastSettings { Debug_SegmentColor: Color3, Debug_SegmentTransparency: number, Debug_SegmentSize: number, Debug_HitColor: Color3, Debug_HitTransparency: number, Debug_HitSize: number, Debug_RayPierceColor: Color3, Debug_RayPierceTransparency: number, Debug_RayPierceSize: number, Debug_RayLifetime: number, Debug_HitLifetime: number }
	@within TypeDefinitions

	Debug visualization settings for casts.
]=]
export type VisualizeCastSettings = {
	Debug_SegmentColor: Color3,
	Debug_SegmentTransparency: number,
	Debug_SegmentSize: number,

	Debug_HitColor: Color3,
	Debug_HitTransparency: number,
	Debug_HitSize: number,

	Debug_RayPierceColor: Color3,
	Debug_RayPierceTransparency: number,
	Debug_RayPierceSize: number,

	Debug_RayLifetime: number,
	Debug_HitLifetime: number,
}

--[=[
	@type CasterParallel { WorldRoot: WorldRoot,	LengthChanged: OnLengthChangedFunction,	Hit: OnHitFunction,	Pierced: OnPiercedFunction,	CastTerminating: OnCastTerminatingFunction,	CastFire: OnCastFireFunction,	Dispatcher: Dispatcher.Dispatcher,	AlreadyInit: boolean,	ObjectCacheEnabled: boolean,	MovementMode: "BulkMoveTo" | "Motor6D",	FastCastEventsModule: FastCastEventsModule,	Init: (		self: CasterParallel,		numWorkers: number,		newParent: Folder,		newName: string,		ContainerParent: Folder,		VMContainerName: string,		VMname: string,		MovementMode: "BulkMoveTo" | "Motor6D",		FastCastEventsModule: ModuleScript,		useObjectCache: boolean,		Template: BasePart | Model,		CacheSize: number,		CacheHolder: Instance	) -> (),	RaycastFire: (		CasterParallel,		Origin: Vector3,		Direction: Vector3,		Velocity: Vector3 | number,		Behavior: FastCastBehavior?	) -> (),	BlockcastFire: (		self: CasterParallel,		Origin: Vector3,		Size: Vector3,		Direction: Vector3,		Velocity: Vector3 | number,		Behavior: FastCastBehavior?	) -> (),	SpherecastFire: (		self: CasterParallel,		Origin: Vector3,		Radius: number,		Direction: Vector3,		Velocity: Vector3 | number,		Behavior: FastCastBehavior?	) -> (),	SetMovementMode: (		mode: "BulkMoveTo" | "Motor6D", 		enabled: boolean	) -> (),	SetObjectCacheEnabled: (		self: CasterParallel,		enabled: boolean,		Template: BasePart | Model,		CacheSize: number,		CacheHolder: Instance	) -> (),	SetFastCastEventsModule: (self: CasterParallel, moduleScript: ModuleScript) -> (),	AddVelocityCast: (CasterParallel, cast: vaildcast, velocity: Vector3) -> (),	SetVelocityCast: (CasterParallel, cast: vaildcast, velocity: Vector3) -> (),	GetVelocityCast: (CasterParallel, cast: vaildcast) -> Vector3,	AddAccelerationCast: (CasterParallel, cast: vaildcast, acceleration: Vector3) -> Vector3,	SetAccelerationCast: (CasterParallel, cast: vaildcast, acceleration: Vector3) -> (),	GetAccelerationCast: (CasterParallel, cast: vaildcast) -> Vector3,	AddPositionCast: (CasterParallel, cast: vaildcast, Position: Vector3) -> (),	GetPositionCast: (CasterParallel, cast: vaildcast) -> Vector3,	ResumeCast: (CasterParallel, cast: vaildcast) -> (),	PauseCast: (CasterParallel, cast: vaildcast) -> (),	SyncChangesToCast: (CasterParallel, cast: vaildcast) -> (),	TerminateCast: (CasterParallel, cast: vaildcast) -> (),	Destroy: (CasterParallel) -> () }
	
	@within TypeDefinitions

	Represents a Caster Parallel.
]=]
export type CasterParallel = {
	WorldRoot: WorldRoot,
	LengthChanged: OnLengthChangedFunction,
	Hit: OnHitFunction,
	Pierced: OnPiercedFunction,
	CastTerminating: OnCastTerminatingFunction,
	CastFire: OnCastFireFunction,
	Dispatcher: Dispatcher.Dispatcher,

	AlreadyInit: boolean,
	ObjectCacheEnabled: boolean,
	MovementMode: "BulkMoveTo" | "Motor6D",
	FastCastEventsModule: FastCastEventsModule,

	Init: (
		self: CasterParallel,
		numWorkers: number,
		newParent: Folder,
		newName: string,
		ContainerParent: Folder,
		VMContainerName: string,
		VMname: string,
		MovementMode: "BulkMoveTo" | "Motor6D",
		FastCastEventsModule: ModuleScript,
		useObjectCache: boolean,
		Template: BasePart | Model,
		CacheSize: number,
		CacheHolder: Instance
	) -> (),

	RaycastFire: (
		CasterParallel,
		Origin: Vector3,
		Direction: Vector3,
		Velocity: Vector3 | number,
		Behavior: FastCastBehavior?
	) -> (),
	BlockcastFire: (
		self: CasterParallel,
		Origin: Vector3,
		Size: Vector3,
		Direction: Vector3,
		Velocity: Vector3 | number,
		Behavior: FastCastBehavior?
	) -> (),

	SpherecastFire: (
		self: CasterParallel,
		Origin: Vector3,
		Radius: number,
		Direction: Vector3,
		Velocity: Vector3 | number,
		Behavior: FastCastBehavior?
	) -> (),

	SetMovementMode: (
		mode: "BulkMoveTo" | "Motor6D", 
		enabled: boolean
	) -> (),

	SetObjectCacheEnabled: (
		self: CasterParallel,
		enabled: boolean,
		Template: BasePart | Model,
		CacheSize: number,
		CacheHolder: Instance
	) -> (),

	SetFastCastEventsModule: (self: CasterParallel, moduleScript: ModuleScript) -> (),

	AddVelocityCast: (CasterParallel, cast: vaildcast, velocity: Vector3) -> (),
	SetVelocityCast: (CasterParallel, cast: vaildcast, velocity: Vector3) -> (),
	GetVelocityCast: (CasterParallel, cast: vaildcast) -> Vector3,

	AddAccelerationCast: (CasterParallel, cast: vaildcast, acceleration: Vector3) -> Vector3,
	SetAccelerationCast: (CasterParallel, cast: vaildcast, acceleration: Vector3) -> (),
	GetAccelerationCast: (CasterParallel, cast: vaildcast) -> Vector3,

	AddPositionCast: (CasterParallel, cast: vaildcast, Position: Vector3) -> (),
	GetPositionCast: (CasterParallel, cast: vaildcast) -> Vector3,

	ResumeCast: (CasterParallel, cast: vaildcast) -> (),
	PauseCast: (CasterParallel, cast: vaildcast) -> (),

	SyncChangesToCast: (CasterParallel, cast: vaildcast) -> (),

	TerminateCast: (CasterParallel, cast: vaildcast) -> (),

	Destroy: (CasterParallel) -> ()
}

--[=[
	@type CasterSerial { WorldRoot: WorldRoot,	LengthChanged: OnLengthChangedFunction,	Hit: OnHitFunction,	CanPierce: CanPierceFunction,	Pierced: OnPiercedFunction,	CastTerminating: OnCastTerminatingFunction,	CastFire: OnCastFireFunction,	Dispatcher: Dispatcher.Dispatcher,	AlreadyInit: boolean,	ObjectCacheEnabled: boolean,	MovementMode: "BulkMoveTo" | "Motor6D",	FastCastEventsModule: FastCastEventsModule,	Init: (		self: CasterSerial,		movementMode: "BulkMoveTo" | "Motor6D",		useObjectCache: boolean,		Template: BasePart | Model?,		CacheSize: number?,		CacheHolder: Instance?	) -> (),	RaycastFire: (		CasterSerial,		Origin: Vector3,		Direction: Vector3,		Velocity: Vector3 | number,		Behavior: FastCastBehavior?	) -> (),	BlockcastFire: (		self: CasterSerial,		Origin: Vector3,		Size: Vector3,		Direction: Vector3,		Velocity: Vector3 | number,		Behavior: FastCastBehavior?	) -> (),	SpherecastFire: (		self: CasterSerial,		Origin: Vector3,		Radius: number,		Direction: Vector3,		Velocity: Vector3 | number,		Behavior: FastCastBehavior?	) -> (),	SetMovementMode: (		mode: "BulkMoveTo" | "Motor6D", 		enabled: boolean	) -> (),	SetObjectCacheEnabled: (		self: CasterSerial,		enabled: boolean,		Template: BasePart | Model,		CacheSize: number,		CacheHolder: Instance	) -> (),	AddVelocityCast: (CasterSerial, cast: vaildcast, velocity: Vector3) -> (),	SetVelocityCast: (CasterSerial, cast: vaildcast, velocity: Vector3) -> (),	GetVelocityCast: (CasterSerial, cast: vaildcast) -> Vector3,	AddAccelerationCast: (CasterSerial, cast: vaildcast, acceleration: Vector3) -> Vector3,	SetAccelerationCast: (CasterSerial, cast: vaildcast, acceleration: Vector3) -> (),	GetAccelerationCast: (CasterSerial, cast: vaildcast) -> Vector3,	AddPositionCast: (CasterSerial, cast: vaildcast, Position: Vector3) -> (),	GetPositionCast: (CasterSerial, cast: vaildcast) -> Vector3,	ResumeCast: (CasterSerial, cast: vaildcast) -> (),	PauseCast: (CasterSerial, cast: vaildcast) -> (),	TerminateCast: (CasterSerial, cast: vaildcast) -> (),	Destroy: (CasterSerial) -> () }
	
	@within TypeDefinitions

	Represents a Caster Serial.
]=]
export type CasterSerial = {
	WorldRoot: WorldRoot,
	LengthChanged: OnLengthChangedFunction,
	Hit: OnHitFunction,
	CanPierce: CanPierceFunction,
	Pierced: OnPiercedFunction,
	CastTerminating: OnCastTerminatingFunction,
	CastFire: OnCastFireFunction,
	Dispatcher: Dispatcher.Dispatcher,

	AlreadyInit: boolean,
	ObjectCacheEnabled: boolean,
	MovementMode: "BulkMoveTo" | "Motor6D",
	FastCastEventsModule: FastCastEventsModule,

	Init: (
		self: CasterSerial,
		movementMode: "BulkMoveTo" | "Motor6D",
		useObjectCache: boolean,
		Template: BasePart | Model?,
		CacheSize: number?,
		CacheHolder: Instance?
	) -> (),

	RaycastFire: (
		CasterSerial,
		Origin: Vector3,
		Direction: Vector3,
		Velocity: Vector3 | number,
		Behavior: FastCastBehavior?
	) -> (),
	BlockcastFire: (
		self: CasterSerial,
		Origin: Vector3,
		Size: Vector3,
		Direction: Vector3,
		Velocity: Vector3 | number,
		Behavior: FastCastBehavior?
	) -> (),

	SpherecastFire: (
		self: CasterSerial,
		Origin: Vector3,
		Radius: number,
		Direction: Vector3,
		Velocity: Vector3 | number,
		Behavior: FastCastBehavior?
	) -> (),

	SetMovementMode: (
		mode: "BulkMoveTo" | "Motor6D", 
		enabled: boolean
	) -> (),

	SetObjectCacheEnabled: (
		self: CasterSerial,
		enabled: boolean,
		Template: BasePart | Model,
		CacheSize: number,
		CacheHolder: Instance
	) -> (),

	AddVelocityCast: (CasterSerial, cast: vaildcast, velocity: Vector3) -> (),
	SetVelocityCast: (CasterSerial, cast: vaildcast, velocity: Vector3) -> (),
	GetVelocityCast: (CasterSerial, cast: vaildcast) -> Vector3,

	AddAccelerationCast: (CasterSerial, cast: vaildcast, acceleration: Vector3) -> Vector3,
	SetAccelerationCast: (CasterSerial, cast: vaildcast, acceleration: Vector3) -> (),
	GetAccelerationCast: (CasterSerial, cast: vaildcast) -> Vector3,

	AddPositionCast: (CasterSerial, cast: vaildcast, Position: Vector3) -> (),
	GetPositionCast: (CasterSerial, cast: vaildcast) -> Vector3,

	ResumeCast: (CasterSerial, cast: vaildcast) -> (),
	PauseCast: (CasterSerial, cast: vaildcast) -> (),

	TerminateCast: (CasterSerial, cast: vaildcast) -> (),

	Destroy: (CasterSerial) -> ()
}

--[=[
	@type FastCastEventsModuleConfig { UseLengthChanged: boolean, UseHit: boolean, UsePierced: boolean, UseCastTerminating: boolean, UseCanPierce: boolean, UseCastFire: boolean }
	@within TypeDefinitions

	Represents a FastCastBehavior configuration.
]=]
export type FastCastEventsModuleConfig = {
	UseLengthChanged: boolean,
	UseHit: boolean,
	UsePierced: boolean,
	UseCastTerminating: boolean,
	UseCanPierce: boolean,
	UseCastFire: boolean
}

--[=[
	@type FastCastEventsConfig { UseLengthChanged: boolean, UseHit: boolean, UsePierced: boolean, UseCastTerminating: boolean, UseCastFire: boolean }
	@within TypeDefinitions

	Represents a FastCastBehavior configuration.
]=]
export type FastCastEventsConfig = {
	UseLengthChanged: boolean,
	UseHit: boolean,
	UsePierced: boolean,
	UseCastTerminating: boolean,
	UseCastFire: boolean,
	UseCanPierce: boolean
}

--[=[
	@type FastCastBehavior { RaycastParams: RaycastParams?, MaxDistance: number, Acceleration: Vector3, HighFidelityBehavior: number, HighFidelitySegmentSize: number, CosmeticBulletTemplate: Instance?, CosmeticBulletContainer: Instance?, AutoIgnoreContainer: boolean, SimulateAfterPhysic: boolean, AutomaticPerformance: boolean, AdaptivePerformance: AdaptivePerformance, VisualizeCasts: boolean, VisualizeCastSettings: VisualizeCastSettings, FastCastEventsModuleConfig: FastCastEventsModuleConfig, FastCastEventsConfig: FastCastEventsConfig, UserData: any }
	@within TypeDefinitions

	Represents a FastCastBehavior configuration.
]=]
export type FastCastBehavior = {
	RaycastParams: RaycastParams?,
	MaxDistance: number,
	Acceleration: Vector3,
	HighFidelityBehavior: number,
	HighFidelitySegmentSize: number,
	CosmeticBulletTemplate: Instance?,
	CosmeticBulletContainer: Instance?,
	AutoIgnoreContainer: boolean,

	SimulateAfterPhysic: boolean,
	MovementMethod: "BulkMoveTo" | "Transform",

	FastCastEventsModuleConfig: FastCastEventsModuleConfig,

	FastCastEventsConfig: FastCastEventsConfig,
	UserData: any
}

--[=[
	@type CastTrajectory { StartTime: number, EndTime: number, Origin: Vector3, InitialVelocity: Vector3, Acceleration: Vector3 }
	@within TypeDefinitions

	Represents a cast trajectory segment.
]=]
export type CastTrajectory = {
	StartTime: number,
	EndTime: number,
	Origin: Vector3,
	InitialVelocity: Vector3,
	Acceleration: Vector3,
}

--[=[
	@type CastStateInfo { UpdateConnection: RBXScriptSignal, HighFidelityBehavior: number, HighFidelitySegmentSize: number, Paused: boolean, TotalRuntime: number, DistanceCovered: number, IsActivelySimulatingPierce: boolean, IsActivelyResimulating: boolean, CancelHighResCast: boolean, Trajectory: CastTrajectory, VisualizeCasts: boolean, VisualizeCastSettings: VisualizeCastSettings, FastCastEventsConfig: FastCastEventsConfig, FastCastEventsModuleConfig: FastCastEventsModuleConfig }
	@within TypeDefinitions

	Represents cast state tracking data.
]=]
export type CastStateInfo = {
	UpdateConnection: RBXScriptConnection?,
	HighFidelityBehavior: number,
	HighFidelitySegmentSize: number,
	Paused: boolean,
	TotalRuntime: number,
	DistanceCovered: number,
	IsActivelySimulatingPierce: boolean,
	IsActivelyResimulating: boolean,
	CancelHighResCast: boolean,
	Trajectory: CastTrajectory,

	FastCastEventsConfig: FastCastEventsConfig,

	FastCastEventsModuleConfig: FastCastEventsModuleConfig
}

--[=[
	@type CastRayInfo { Parameters: RaycastParams, WorldRoot: WorldRoot, MaxDistance: number, CosmeticBulletObject: Instance?, FastCastEventsModule: FastCastEventsModule }
	@within TypeDefinitions

	Ray info for ray-cast variants.
]=]
export type CastRayInfo = {
	Parameters: RaycastParams,
	WorldRoot: WorldRoot,
	MaxDistance: number,
	CosmeticBulletObject: Instance?,
	FastCastEventsModule: FastCastEventsModule
}

--[=[
	@type BlockCastRayInfo { Parameters: RaycastParams, WorldRoot: WorldRoot, MaxDistance: number, CosmeticBulletObject: Instance?, CanPierceModule: ModuleScript?, Size: Vector3 }
	@within TypeDefinitions

	Ray info for block-cast variants.
]=]
export type BlockCastRayInfo = {
	Parameters: RaycastParams,
	WorldRoot: WorldRoot,
	MaxDistance: number,
	CosmeticBulletObject: Instance?,

	Size: Vector3,
}

--[=[
	@type SpherecastRayInfo { Parameters: RaycastParams, WorldRoot: WorldRoot, MaxDistance: number, CosmeticBulletObject: Instance?, CanPierceModule: ModuleScript?, Radius: number }
	@within TypeDefinitions

	Ray info for sphere-cast variants.
]=]
export type SphereCastRayInfo = {
	Parameters: RaycastParams,
	WorldRoot: WorldRoot,
	MaxDistance: number,
	CosmeticBulletObject: Instance?,

	Radius: number,
}

--[=[
	@type BaseCastData { Output: BindableEvent, ActiveCastCleaner: BindableEvent, ObjectCache: BindableFunction?, CacheHolder: any?, SyncChange : BindableEvent }
	@within TypeDefinitions

	Data stored on the caster that ActiveCasts reference.
]=]
export type BaseCastData = {
	Output: BindableEvent,
	ActiveCastCleaner: BindableEvent,
	CacheHolder: any?,
	SyncChange : BindableEvent
}

--[=[
	@type ActiveCastData {Caster: BaseCastData | { SerialSimulation: any},StateInfo: CastStateInfo,RayInfo: CastRayInfo,UserData: { [any]: any }, Type : "Raycast",CFrame: CFrame,ID: number}
	@within TypeDefinitions	
	
	Represents an active cast data.
]=]
export type ActiveCastData = {
	Caster: BaseCastData | { SerialSimulation: any},
	StateInfo: CastStateInfo,
	RayInfo: CastRayInfo,
	UserData: { [any]: any },

	Type : "Raycast",
	CFrame: CFrame,
	ID: number | string
}

--[=[
	@type ActiveCastData { Caster: BaseCastData | { SerialSimulation: any}, StateInfo: CastStateInfo, RayInfo: CastRayInfo, UserData: { [any]: any }, Type : "Blockcast", CFrame: CFrame, ID: number }
	@within TypeDefinitions	
	
	Represents an active block cast data.
]=]
export type ActiveBlockcastData = {
	Caster: BaseCastData | { SerialSimulation: any},
	StateInfo: CastStateInfo,
	RayInfo: BlockCastRayInfo,
	UserData: { [any]: any },

	Type : "Blockcast",
	CFrame: CFrame,
	ID: number | string
}

--[=[
	@type ActiveCastData { Caster: BaseCastData | { SerialSimulation: any}, StateInfo: CastStateInfo, RayInfo: CastRayInfo, UserData: { [any]: any }, Type : "Spherecast", CFrame: CFrame, ID: number }
	@within TypeDefinitions	
	
	Represents an active sphere cast data.
]=]
export type ActiveSpherecastData = {
	Caster: BaseCastData | { SerialSimulation: any},
	StateInfo: CastStateInfo,
	RayInfo: SphereCastRayInfo,
	UserData: { [any]: any },

	Type : "Spherecast",
	CFrame: CFrame,
	ID: number | string
}

return {}
