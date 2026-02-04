--!strict

--[[
	- Author : Mawin CK
	- Date : 2025
	-- Verison : 0.0.6
]]

--[=[
	@class TypeDefinitions
	@tag Types

	Type definitions for strict-typing.
]=]

local Dispatcher = require(script.Parent:WaitForChild("FastCastVMs"))

type vaildcast = ActiveCastCompement | ActiveBlockcastCompement

--[=[
	@type CanPierceFunction (ActiveCast, RaycastResult, Vector3, Instance?) -> boolean
	@within TypeDefinitions

	Callback used to decide whether a cast should pierce and continue after a hit.
]=]
export type CanPierceFunction = (
	ActiveCastCompement,
	RaycastResult,
	segmentVelocity: Vector3,
	cosmeticBulletObject: Instance?
) -> boolean

--[=[
	@type FastCastEventsModule ModuleScript
	@within TypeDefinitions

	A table of callback functions (events/hooks) used by ActiveCast.
	These functions are invoked by ActiveCast during a lifecycle, (e.g. length updates, pierce checks).
]=]
export type FastCastEventsModule = ModuleScript

--[=[
	@type OnRayHitFunction (ActiveCast, RaycastResult, Vector3, Instance?) -> ()
	@within TypeDefinitions

	Callback fired when the cast hits something (non-piercing).
]=]
export type OnRayHitFunction = (
	ActiveCastCompement,
	RaycastResult,
	segmentVelocity: Vector3,
	cosmeticBulletObject: Instance?
) -> ()

--[=[
	@type OnRayPierceFunction (ActiveCast, RaycastResult, Vector3, Instance?) -> ()
	@within TypeDefinitions

	Callback fired when the cast pierces something.
]=]
export type OnRayPierceFunction = (
	ActiveCastCompement,
	RaycastResult,
	segmentVelocity: Vector3,
	cosmeticBulletObject: Instance?
) -> ()

--[=[
	@type OnLengthChangedFunction (ActiveCast, Vector3, Vector3, number, Vector3, Instance?) -> ()
	@within TypeDefinitions

	Callback fired when the cast's length changes as it updates.
]=]
export type OnLengthChangedFunction = (
	ActiveCastCompement,
	lastPoint: Vector3,
	rayDir: Vector3,
	rayDisplacement: number,
	segmentVelocity: Vector3,
	cosmeticBulletObject: Instance?
) -> ()

--[=[
	@type OnCastTerminatingFunction (ActiveCast) -> ()
	@within TypeDefinitions

	Callback fired right as an ActiveCast is terminating.
]=]
export type OnCastTerminatingFunction = (ActiveCastCompement) -> ()

--[=[
	@type OnCastFireFunction (ActiveCastCompement, Vector3, Vector3, Vector3, FastCastBehavior) -> ()
	@within TypeDefinitions

	Callback fired when a cast is initially fired.
]=]
export type OnCastFireFunction = (
	ActiveCastCompement,
	Origin: Vector3,
	Direction: Vector3,
	Velocity: Vector3,
	behavior: FastCastBehavior
) -> ()

--[=[
	@type Caster { WorldRoot: WorldRoot, LengthChanged: RBXScriptSignal, RayHit: RBXScriptSignal, RayPierced: RBXScriptSignal, CastTerminating: RBXScriptSignal, CastFire: RBXScriptSignal, Dispatcher: Dispatcher.Dispatcher, AlreadyInit: boolean, Init: (Caster, number, Folder, string, Folder, string, string, boolean, boolean, BasePart | Model, number, Instance) -> (), RaycastFire: (Caster, Vector3, Vector3, Vector3 | number, FastCastBehavior) -> string, BlockcastFire: (Caster, Vector3, Vector3, Vector3, Vector3 | number, FastCastBehavior) -> string, SetBulkMoveEnabled: (boolean) -> (), SetObjectCacheEnabled: (boolean, BasePart | Model, number, Instance) -> (), SetVisualizeCasts: (boolean) -> (), ReturnObject: (Instance) -> (), Destroy: (Caster) -> () }
	@within TypeDefinitions

	Represents a Caster.
]=]
export type Caster = {
	WorldRoot: WorldRoot,
	LengthChanged: RBXScriptSignal,
	RayHit: RBXScriptSignal,
	RayPierced: RBXScriptSignal,
	CastTerminating: RBXScriptSignal,
	CastFire: RBXScriptSignal,
	Dispatcher: Dispatcher.Dispatcher,
	AlreadyInit: boolean,
	--id : string,

	Init: (
		self: Caster,
		numWorkers: number,
		newParent: Folder,
		newName: string,
		ContainerParent: Folder,
		VMContainerName: string,
		VMname: string,
		useBulkMoveTo: boolean,
		useObjectCache: boolean,
		Template: BasePart | Model,
		CacheSize: number,
		CacheHolder: Instance
	) -> (),

	RaycastFire: (
		Caster,
		Origin: Vector3,
		Direction: Vector3,
		Velocity: Vector3 | number,
		Behavior: FastCastBehavior
	) -> string,
	BlockcastFire: (
		self: Caster,
		Origin: Vector3,
		Size: Vector3,
		Direction: Vector3,
		Velocity: Vector3 | number,
		Behavior: FastCastBehavior
	) -> string,

	SetBulkMoveEnabled: (self: Caster, enabled: boolean) -> (),
	SetObjectCacheEnabled: (
		self: Caster,
		enabled: boolean,
		Template: BasePart | Model,
		CacheSize: number,
		CacheHolder: Instance
	) -> (),
	
	SetFastCastEventsModule: (self: Caster, moduleScript: ModuleScript) -> (),
	

	SetVisualizeCasts: (self: Caster, bool: boolean) -> (),

	ReturnObject: (self: Caster, obj: Instance) -> (),
	
	AddVelocityCast: (cast: vaildcast, velocity: Vector3) -> (),
	SetVelocityCast: (cast: vaildcast, velocity: Vector3) -> (),
	GetVelocityCast: (cast: vaildcast, velocity: Vector3) -> Vector3,
	
	AddAccelerationCast: (cast: vaildcast) -> Vector3,
	GetAccelerationCast: (cast: vaildcast) -> Vector3,
	SetAccelerationCast: (cast: vaildcast, acceleration: Vector3) -> (),
	
	GetPositionCast: (cast: vaildcast, Position: Vector3) -> Vector3,
	AddPositionCast: (cast: vaildcast, Position: Vector3) -> (),
	
	ResumeCast: (cast: vaildcast) -> (),
	PauseCast: (cast: vaildcast) -> (),
	
	SyncChangesToCast: (cast: vaildcast) -> (),
	
	TerminateCast: (cast: vaildcast) -> (),
	
	Destroy: (Caster) -> ()
}

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
	@type AdaptivePerformance { HighFidelitySegmentSizeIncrease: number, LowerHighFidelityBehavior: boolean }
	@within TypeDefinitions

	Adaptive performance config used when AutomaticPerformance is enabled.
]=]
export type AdaptivePerformance = {
	HighFidelitySegmentSizeIncrease: number,
	LowerHighFidelityBehavior: boolean,
}

export type FastCastEventsModuleConfig = {
	UseLengthChanged: boolean,
	UseRayHit: boolean,
	UseRayPierced: boolean,
	UseCastTerminating: boolean,
	UseCanRayPierce: boolean,
	UseCastFire: boolean
}

export type FastCastEventsConfig = {
	UseLengthChanged: boolean,
	UseRayHit: boolean,
	UseRayPierced: boolean,
	UseCastTerminating: boolean,
	UseCastFire: boolean
}

--[=[
	@type FastCastBehavior { RaycastParams: RaycastParams?, MaxDistance: number, Acceleration: Vector3, HighFidelityBehavior: number, HighFidelitySegmentSize: number, CosmeticBulletTemplate: Instance?, CosmeticBulletContainer: Instance?, AutoIgnoreContainer: boolean, UseLengthChanged: boolean, UseBetterLengthChanged: boolean, SimulateAfterPhysic: boolean, AutomaticPerformance: boolean, AdaptivePerformance: AdaptivePerformance, VisualizeCasts: boolean, VisualizeCastSettings: VisualizeCastSettings }
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

	AutomaticPerformance: boolean,
	AdaptivePerformance: AdaptivePerformance,

	VisualizeCasts: boolean,
	VisualizeCastSettings: VisualizeCastSettings,
	
	FastCastEventsModuleConfig: FastCastEventsModuleConfig,

	FastCastEventsConfig: FastCastEventsConfig
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
	@type CastStateInfo { UpdateConnection: RBXScriptSignal, HighFidelityBehavior: number, HighFidelitySegmentSize: number, Paused: boolean, TotalRuntime: number, DistanceCovered: number, IsActivelySimulatingPierce: boolean, IsActivelyResimulating: boolean, CancelHighResCast: boolean, Trajectories: {[number]: CastTrajectory}, UseLengthChanged: boolean, VisualizeCasts: boolean, VisualizeCastSettings: VisualizeCastSettings }
	@within TypeDefinitions

	Represents cast state tracking data.
]=]
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
	Trajectories: { [number]: CastTrajectory },
	UseLengthChanged: boolean,
	VisualizeCasts: boolean,
	VisualizeCastSettings: VisualizeCastSettings,
	
	FastCastEventsConfig: {
		UseLengthChanged: boolean,
		UseRayHit: boolean,
		UseRayPierced: boolean,
		UseCastTerminating: boolean,
	},
	
	FastCastEventsModuleConfig: {
		UseLengthChanged: boolean,
		UseRayHit: boolean,
		UseRayPierced: boolean,
		UseCastTerminating: boolean,
		UseCanRayPierce: boolean,
	}
}

--[=[
	@type CastRayInfo { Parameters: RaycastParams, WorldRoot: WorldRoot, MaxDistance: number, CosmeticBulletObject: Instance?, CanPierceModule: ModuleScript? }
	@within TypeDefinitions

	Represents ray info for an ActiveCastCompement.
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
	--CanPierceModule: CanPierceModule?,
	Size: Vector3,
}

--[=[
	@type BaseCast { Actives: { ActiveCastCompement | ActiveBlockCast }, Output: BindableEvent, ActiveCastCompementCleaner: BindableEvent, ObjectCache: BindableFunction?, CacheHolder: any? }
	@within TypeDefinitions

	Internal base cast object state.
]=]
export type BaseCast = {
	Actives: { ActiveCastCompement | ActiveBlockcastCompement },
	Output: BindableEvent,
	ActiveCastCleaner: BindableEvent,
	ObjectCache: BindableFunction?,
	CacheHolder: any?,
}

--[=[
	@type BaseCastData { Output: BindableEvent, ActiveCastCleaner: BindableEvent, ObjectCache: BindableFunction?, CacheHolder: any? }
	@within TypeDefinitions

	Data stored on the caster that ActiveCasts reference.
]=]
export type BaseCastData = {
	Output: BindableEvent,
	ActiveCastCleaner: BindableEvent,
	ObjectCache: BindableFunction?,
	CacheHolder: any?,
	SyncChange : BindableEvent
}

-- ECS

export type ActiveCastCompement = {
	Caster: BaseCastData,
	StateInfo: CastStateInfo,
	RayInfo: CastRayInfo,
	UserData: { [any]: any },
	
	Type : "Raycast",
	CFrame: CFrame,
	ID: number | string
}

export type ActiveBlockcastCompement = {
	Caster: BaseCastData,
	StateInfo: CastStateInfo,
	RayInfo: CastRayInfo,
	UserData: { [any]: any },
	
	Type : "Blockcast",
	CFrame: CFrame,
	ID: number | string
}

return {}
