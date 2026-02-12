--!strict

--[[
	- Author : Mawin CK
	- Date : 2025
	-- Verison : 0.0.7
]]

--[=[
	@class TypeDefinitions
	@tag Types

	Type definitions for strict-typing.
]=]

local Dispatcher = require(script.Parent:WaitForChild("FastCastVMs"))

--[=[
	@type vaildcast ActiveCastCompement | ActiveBlockcastCompement
	@within TypeDefinitions

	A type that can be either an ActiveCast or an ActiveBlockcast.
]=]
type vaildcast = ActiveCastCompement | ActiveBlockcastCompement

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
	@type CanPierceFunction (ActiveCastCompement, RaycastResult, Vector3, Instance?) -> boolean
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
	@type OnHitFunction (ActiveCastCompement, RaycastResult, Vector3, Instance?) -> ()
	@within TypeDefinitions

	Callback fired when the cast hits something (non-piercing).
]=]
export type OnHitFunction = (
	ActiveCastCompement,
	RaycastResult,
	segmentVelocity: Vector3,
	cosmeticBulletObject: Instance?
) -> ()

--[=[
	@type OnPierceFunction (ActiveCastCompement, RaycastResult, Vector3, Instance?) -> ()
	@within TypeDefinitions

	Callback fired when the cast pierces something.
]=]
export type OnPiercedFunction = (
	ActiveCastCompement,
	RaycastResult,
	segmentVelocity: Vector3,
	cosmeticBulletObject: Instance?
) -> ()

--[=[
	@type OnLengthChangedFunction (ActiveCastCompement, Vector3, Vector3, number, Vector3, Instance?) -> ()
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
	@type OnCastTerminatingFunction (ActiveCastCompement) -> ()
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
	@type ObjectCache { GetPart: (ObjectCache, PartCFrame: CFrame) -> BasePart, ReturnPart: (ObjectCache, Part: BasePart) -> (), Update: (ObjectCache) -> (), ExpandCache: (ObjectCache, Amount: number) -> (), SetExpandAmount: (ObjectCache, Amount: number) -> (), IsInUse: (ObjectCache, Object: BasePart) -> boolean, Destroy: (ObjectCache) -> () }
	@within TypeDefinitions

	Represents a ObjectCache object.
]=]
export type ObjectCache = {
	GetPart: (ObjectCache, PartCFrame: CFrame) -> BasePart,
	ReturnPart: (ObjectCache, Part: BasePart) -> (),
	Update: (ObjectCache) -> (),
	ExpandCache: (ObjectCache, Amount: number) -> (),
	SetExpandAmount: (ObjectCache, Amount: number) -> (),
	IsInUse: (ObjectCache, Object: BasePart) -> boolean,
	Destroy: (ObjectCache) -> ()
}

--[=[
	@type Caster { WorldRoot: WorldRoot, LengthChanged: RBXScriptSignal, Hit: RBXScriptSignal, Pierced: RBXScriptSignal, CastTerminating: RBXScriptSignal, CastFire: RBXScriptSignal, Dispatcher: Dispatcher.Dispatcher, ObjectCache: ObjectCache, AlreadyInit: boolean, ObjectCacheEnabled: boolean, BulkMoveEnabled: boolean, FastCastEventsModule: FastCastEventsModule, Init: ( self: Caster, numWorkers: number, newParent: Folder, newName: string, ContainerParent: Folder, VMContainerName: string, VMname: string, useBulkMoveTo: boolean, FastCastEventsModule: ModuleScript, useObjectCache: boolean, Template: BasePart | Model, CacheSize: number, CacheHolder: Instance ) -> (), RaycastFire: ( Caster, Origin: Vector3, Direction: Vector3, Velocity: Vector3 | number, Behavior: FastCastBehavior ) -> (), BlockcastFire: ( self: Caster, Origin: Vector3, Size: Vector3, Direction: Vector3, Velocity: Vector3 | number, Behavior: FastCastBehavio ) -> (), SetBulkMoveEnabled: (self: Caster, enabled: boolean) -> (), SetObjectCacheEnabled: ( self: Caster, enabled: boolean, Template: BasePart | Model, CacheSize: number, CacheHolder: Instance ) -> (), SetFastCastEventsModule: (self: Caster, moduleScript: ModuleScript) -> (), AddVelocityCast: (Caster, cast: vaildcast, velocity: Vector3) -> (), SetVelocityCast: (Caster, cast: vaildcast, velocity: Vector3) -> (), GetVelocityCast: (Caster, cast: vaildcast, velocity: Vector3) -> Vector3, AddAccelerationCast: (Caster, cast: vaildcast) -> Vector3, GetAccelerationCast: (Caster, cast: vaildcast) -> Vector3, SetAccelerationCast: (Caster, cast: vaildcast, acceleration: Vector3) -> (), GetPositionCast: (Caster, cast: vaildcast, Position: Vector3) -> Vector3, AddPositionCast: (Caster, cast: vaildcast, Position: Vector3) -> (), ResumeCast: (Caster, cast: vaildcast) -> (), PauseCast: (Caster, cast: vaildcast) -> (), SyncChangesToCast: (Caster, cast: vaildcast) -> (), TerminateCast: (Caster, cast: vaildcast) -> (), Destroy: (Caster) -> () }
	
	@within TypeDefinitions

	Represents a Caster.
]=]
export type Caster = {
	WorldRoot: WorldRoot,
	LengthChanged: RBXScriptSignal,
	Hit: RBXScriptSignal,
	Pierced: RBXScriptSignal,
	CastTerminating: RBXScriptSignal,
	CastFire: RBXScriptSignal,
	Dispatcher: Dispatcher.Dispatcher,
	ObjectCache: ObjectCache,
	
	AlreadyInit: boolean,
	ObjectCacheEnabled: boolean,
	BulkMoveEnabled: boolean,
	FastCastEventsModule: FastCastEventsModule,

	Init: (
		self: Caster,
		numWorkers: number,
		newParent: Folder,
		newName: string,
		ContainerParent: Folder,
		VMContainerName: string,
		VMname: string,
		useBulkMoveTo: boolean,
		FastCastEventsModule: ModuleScript,
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
	
	AddVelocityCast: (Caster, cast: vaildcast, velocity: Vector3) -> (),
	SetVelocityCast: (Caster, cast: vaildcast, velocity: Vector3) -> (),
	GetVelocityCast: (Caster, cast: vaildcast, velocity: Vector3) -> Vector3,
	
	AddAccelerationCast: (Caster, cast: vaildcast) -> Vector3,
	GetAccelerationCast: (Caster, cast: vaildcast) -> Vector3,
	SetAccelerationCast: (Caster, cast: vaildcast, acceleration: Vector3) -> (),
	
	GetPositionCast: (Caster, cast: vaildcast, Position: Vector3) -> Vector3,
	AddPositionCast: (Caster, cast: vaildcast, Position: Vector3) -> (),
	
	ResumeCast: (Caster, cast: vaildcast) -> (),
	PauseCast: (Caster, cast: vaildcast) -> (),
	
	SyncChangesToCast: (Caster, cast: vaildcast) -> (),
	
	TerminateCast: (Caster, cast: vaildcast) -> (),
	
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
	UseCastFire: boolean
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

	AutomaticPerformance: boolean,
	AdaptivePerformance: AdaptivePerformance,

	VisualizeCasts: boolean,
	VisualizeCastSettings: VisualizeCastSettings,
	
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
	@type CastStateInfo { UpdateConnection: RBXScriptSignal, HighFidelityBehavior: number, HighFidelitySegmentSize: number, Paused: boolean, TotalRuntime: number, DistanceCovered: number, IsActivelySimulatingPierce: boolean, IsActivelyResimulating: boolean, CancelHighResCast: boolean, Trajectories: { [number]: CastTrajectory }, VisualizeCasts: boolean, VisualizeCastSettings: VisualizeCastSettings, FastCastEventsConfig: FastCastEventsConfig, FastCastEventsModuleConfig: FastCastEventsModuleConfig }
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
	VisualizeCasts: boolean,
	VisualizeCastSettings: VisualizeCastSettings,
	
	FastCastEventsConfig: FastCastEventsConfig,
	
	FastCastEventsModuleConfig: FastCastEventsModuleConfig
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

--[=[
	@type ActiveCastCompement {Caster: BaseCastData,StateInfo: CastStateInfo,RayInfo: CastRayInfo,UserData: { [any]: any }, Type : "Raycast",CFrame: CFrame,ID: number}
	@within TypeDefinitions	
	
	Represents an active cast data.
]=]
export type ActiveCastCompement = {
	Caster: BaseCastData,
	StateInfo: CastStateInfo,
	RayInfo: CastRayInfo,
	UserData: { [any]: any },
	
	Type : "Raycast",
	CFrame: CFrame,
	ID: number | string
}

--[=[
	@type ActiveCastCompement { Caster: BaseCastData, StateInfo: CastStateInfo, RayInfo: CastRayInfo, UserData: { [any]: any }, Type : "Raycast", CFrame: CFrame, ID: number }
	@within TypeDefinitions	
	
	Represents an active block cast data.
]=]
export type ActiveBlockcastCompement = {
	Caster: BaseCastData,
	StateInfo: CastStateInfo,
	RayInfo: BlockCastRayInfo,
	UserData: { [any]: any },
	
	Type : "Blockcast",
	CFrame: CFrame,
	ID: number | string
}

return {}
