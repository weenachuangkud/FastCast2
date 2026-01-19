--[[
	- Author : Mawin CK
	- Date : 2025
	-- Verison : 0.0.4
]]

--[=[
	@class TypeDefinitions
	@tag Types

	Type definitions for strict-typing.
]=]
--!strict

local Dispatcher = require(script.Parent:WaitForChild("FastCastVMs"))

--[=[
	@type CanPierceFunction (ActiveCast, RaycastResult, Vector3) -> boolean
	@within TypeDefinitions

	Callback used to decide whether a cast should pierce and continue after a hit.
]=]
export type CanPierceFunction = (ActiveCast, RaycastResult, Vector3) -> boolean

--[=[
	@type OnRayHitFunction (ActiveCast, RaycastResult, Vector3, Instance?) -> ()
	@within TypeDefinitions

	Callback fired when the cast hits something (non-piercing).
]=]
export type OnRayHitFunction = (ActiveCast, RaycastResult, segmentVelocity : Vector3, cosmeticBulletObject : Instance?) -> ()

--[=[
	@type OnRayPierceFunction (ActiveCast, RaycastResult, Vector3, Instance?) -> ()
	@within TypeDefinitions

	Callback fired when the cast pierces something.
]=]
export type OnRayPierceFunction = (ActiveCast, RaycastResult, segmentVelocity : Vector3, cosmeticBulletObject : Instance?) -> ()

--[=[
	@type OnLengthChangedFunction (ActiveCast, Vector3, Vector3, number, Vector3, Instance?) -> ()
	@within TypeDefinitions

	Callback fired when the cast's length changes as it updates.
]=]
export type OnLengthChangedFunction = (
	ActiveCast,
	lastPoint : Vector3,
	rayDir : Vector3,
	rayDisplacement : number,
	segmentVelocity : Vector3,
	cosmeticBulletObject : Instance?
) -> ()

--[=[
	@type OnCastTerminatingFunction (ActiveCast) -> ()
	@within TypeDefinitions

	Callback fired right as an ActiveCast is terminating.
]=]
export type OnCastTerminatingFunction = (ActiveCast) -> ()

--[=[
	@type OnCastFireFunction (ActiveCast, Vector3, Vector3, Vector3, FastCastBehavior) -> ()
	@within TypeDefinitions

	Callback fired when a cast is initially fired.
]=]
export type OnCastFireFunction = (ActiveCast, Origin : Vector3, Direction : Vector3, Velocity : Vector3, behavior : FastCastBehavior) -> ()

--[=[
	@type GenericTable {[any]: any}
	@within TypeDefinitions

	Represents any table.
]=]
export type GenericTable = {[any]: any}

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

	RaycastFire: (Caster, Origin : Vector3, Direction : Vector3, Velocity : Vector3 | number, Behavior : FastCastBehavior) -> string,
	BlockcastFire: (Caster, Origin : Vector3, Size : Vector3, Direction : Vector3, Velocity : Vector3 | number, Behavior : FastCastBehavior) -> string,

	SetBulkMoveEnabled : (enabled : boolean) -> (),
	SetObjectCacheEnabled : (enabled : boolean, Template : BasePart | Model, CacheSize : number, CacheHolder : Instance) -> (),

	SetVisualizeCasts : (bool : boolean) -> (),

	ReturnObject : (obj : Instance) -> (),

	Destroy : (Caster) -> ()
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
	Debug_HitTransparency : number,
	Debug_HitSize : number,

	Debug_RayPierceColor: Color3,
	Debug_RayPierceTransparency : number,
	Debug_RayPierceSize : number,

	Debug_RayLifetime: number,
	Debug_HitLifetime: number
}

--[=[
	@type AdaptivePerformance { HighFidelitySegmentSizeIncrease: number, LowerHighFidelityBehavior: boolean }
	@within TypeDefinitions

	Adaptive performance config used when AutomaticPerformance is enabled.
]=]
export type AdaptivePerformance = {
	HighFidelitySegmentSizeIncrease : number,
	LowerHighFidelityBehavior : boolean
}

--[=[
	@type FastCastBehavior { RaycastParams: RaycastParams?, MaxDistance: number, Acceleration: Vector3, HighFidelityBehavior: number, HighFidelitySegmentSize: number, CosmeticBulletTemplate: Instance?, CosmeticBulletContainer: Instance?, AutoIgnoreContainer: boolean, CanPierceFunction: CanPierceFunction?, UseLengthChanged: boolean, SimulateAfterPhysic: boolean, AutomaticPerformance: boolean, AdaptivePerformance: AdaptivePerformance, VisualizeCasts: boolean, VisualizeCastSettings: VisualizeCastSettings }
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
	CanPierceFunction: CanPierceFunction?,
	UseLengthChanged : boolean,
	SimulateAfterPhysic : boolean,

	AutomaticPerformance : boolean,
	AdaptivePerformance : AdaptivePerformance,

	VisualizeCasts : boolean,
	VisualizeCastSettings : VisualizeCastSettings
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
	Acceleration: Vector3
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
	Trajectories: {[number]: CastTrajectory},
	UseLengthChanged : boolean,
	VisualizeCasts : boolean,
	VisualizeCastSettings : VisualizeCastSettings
}

--[=[
	@type CastRayInfo { Parameters: RaycastParams, WorldRoot: WorldRoot, MaxDistance: number, CosmeticBulletObject: Instance?, CanPierceCallback: CanPierceFunction }
	@within TypeDefinitions

	Represents ray info for an ActiveCast.
]=]
export type CastRayInfo = {
	Parameters: RaycastParams,
	WorldRoot: WorldRoot,
	MaxDistance: number,
	CosmeticBulletObject: Instance?,
	CanPierceCallback: CanPierceFunction
}

--[=[
	@type ActiveCast { Caster: BaseCastData, StateInfo: CastStateInfo, RayInfo: CastRayInfo, UserData: {[any]: any}, SetVelocity: (ActiveCast, Vector3) -> (), SetAcceleration: (ActiveCast, Vector3) -> (), GetVelocity: (ActiveCast) -> Vector3, GetAcceleration: (ActiveCast) -> Vector3, GetPosition: (ActiveCast) -> Vector3, AddVelocity: (ActiveCast, Vector3) -> (), AddAcceleration: (ActiveCast, Vector3) -> (), AddPosition: (ActiveCast, Vector3) -> (), Pause: (ActiveCast) -> (), Resume: (ActiveCast) -> (), DestroyObject: (ActiveCast, Instance) -> (), Destroy: (ActiveCast) -> (), Terminate: (ActiveCast) -> (), CFrame: CFrame, ID: string }
	@within TypeDefinitions

	Represents an ActiveCast instance.
]=]
export type ActiveCast = {
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

--[=[
	@type BlockCastRayInfo { Parameters: RaycastParams, WorldRoot: WorldRoot, MaxDistance: number, CosmeticBulletObject: Instance?, CanPierceCallback: CanPierceFunction, Size: Vector3 }
	@within TypeDefinitions

	Ray info for block-cast variants.
]=]
export type BlockCastRayInfo = {
	Parameters : RaycastParams,
	WorldRoot : WorldRoot,
	MaxDistance : number,
	CosmeticBulletObject : Instance?,
	CanPierceCallback: CanPierceFunction,
	Size : Vector3
}

--[=[
	@type ActiveBlockCast { Caster: BaseCastData, StateInfo: CastStateInfo, RayInfo: BlockCastRayInfo, UserData: {[any]: any}, SetVelocity: (ActiveCast, Vector3) -> (), SetAcceleration: (ActiveCast, Vector3) -> (), GetVelocity: (ActiveCast) -> Vector3, GetAcceleration: (ActiveCast) -> Vector3, GetPosition: (ActiveCast) -> Vector3, AddVelocity: (ActiveCast, Vector3) -> (), AddAcceleration: (ActiveCast, Vector3) -> (), AddPosition: (ActiveCast, Vector3) -> (), Pause: (ActiveCast) -> (), Resume: (ActiveCast) -> (), DestroyObject: (ActiveCast, Instance) -> (), Destroy: (ActiveCast) -> (), Terminate: (ActiveCast) -> (), CFrame: CFrame, ID: string }
	@within TypeDefinitions

	Represents an active block-cast instance.
]=]
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

--[=[
	@type BaseCast { Actives: { ActiveCast | ActiveBlockCast }, Output: BindableEvent, ActiveCastCleaner: BindableEvent, ObjectCache: BindableFunction?, CacheHolder: any? }
	@within TypeDefinitions

	Internal base cast object state.
]=]
export type BaseCast = {
	Actives : {
		ActiveCast | ActiveBlockCast
	},
	Output : BindableEvent,
	ActiveCastCleaner : BindableEvent,
	ObjectCache : BindableFunction?,
	CacheHolder : any?
}

--[=[
	@type BaseCastData { Output: BindableEvent, ActiveCastCleaner: BindableEvent, ObjectCache: BindableFunction?, CacheHolder: any? }
	@within TypeDefinitions

	Data stored on the caster that ActiveCasts reference.
]=]
export type BaseCastData = {
	Output : BindableEvent,
	ActiveCastCleaner : BindableEvent,
	ObjectCache : BindableFunction?,
	CacheHolder : any?
}

return {}
