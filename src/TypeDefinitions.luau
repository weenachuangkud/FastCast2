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

local Signal = require(script.Parent:WaitForChild("Signal"))

--[=[
	@type vaildcast ActiveCastData | ActiveBlockcastData | ActiveSpherecastData
	@within TypeDefinitions

	A type that can be either an ActiveCast or an ActiveBlockcast.
]=]
type vaildcast = ActiveCastData | ActiveBlockcastData | ActiveSpherecastData

--[=[
	@type FastCastSignalEvents { CanPierce: CanPierceFunction, Hit: Signal.Signal<OnHitFunction>, Pierced: Signal.Signal<OnPiercedFunction>, LengthChanged: Signal.Signal<OnLengthChangedFunction>, CastTerminating: Signal.Signal<OnCastTerminatingFunction>, CastFire: Signal.Signal<OnCastFireFunction> }
	@within TypeDefinitions

	The Signal-based event table used internally by SerialSimulation. Each event
	is a Signal so any number of listeners can connect to it.
]=]
export type FastCastSignalEvents = {
	CanPierce: CanPierceFunction,
	Hit: Signal.Signal<OnHitFunction>,
	Pierced: Signal.Signal<OnPiercedFunction>,
	LengthChanged: Signal.Signal<OnLengthChangedFunction>,
	CastTerminating: Signal.Signal<OnCastTerminatingFunction>,
	CastFire: Signal.Signal<OnCastFireFunction>
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
	@type CasterSerial { WorldRoot: WorldRoot, LengthChanged: Signal.Signal<OnLengthChangedFunction>, Hit: Signal.Signal<OnHitFunction>, CanPierce: CanPierceFunction?, Pierced: Signal.Signal<OnPiercedFunction>, CastTerminating: Signal.Signal<OnCastTerminatingFunction>, CastFire: Signal.Signal<OnCastFireFunction>, AlreadyInit: boolean?, MovementMode: "BulkMoveTo" | "Motor6D"?, Init: (self: CasterSerial, movementMode: "BulkMoveTo" | "Motor6D"?) -> (), RaycastFire: (self: CasterSerial, Origin: Vector3, Direction: Vector3, Velocity: Vector3 | number, Behavior: FastCastBehavior?) -> (), BlockcastFire: (self: CasterSerial, Origin: Vector3, Size: Vector3, Direction: Vector3, Velocity: Vector3 | number, Behavior: FastCastBehavior?) -> (), SpherecastFire: (self: CasterSerial, Origin: Vector3, Radius: number, Direction: Vector3, Velocity: Vector3 | number, Behavior: FastCastBehavior?) -> (), SetMovementModeEnabled: (self: CasterSerial, enabled: boolean, mode: "BulkMoveTo" | "Motor6D") -> (), Destroy: (self: CasterSerial) -> () }
	@within TypeDefinitions

	Represents the serial caster exposed by FastCast.new().
]=]
export type CasterSerial = {
	WorldRoot: WorldRoot,
	LengthChanged: Signal.Signal<OnLengthChangedFunction> | OnLengthChangedFunction,
	Hit: Signal.Signal<OnHitFunction> | OnHitFunction,
	CanPierce: CanPierceFunction?,
	Pierced: Signal.Signal<OnPiercedFunction> | OnPiercedFunction,
	CastTerminating: Signal.Signal<OnCastTerminatingFunction> | OnCastTerminatingFunction,
	CastFire: Signal.Signal<OnCastFireFunction> | OnCastFireFunction,

	AlreadyInit: boolean?,
	MovementMode: ("BulkMoveTo" | "Motor6D")?,

	Init: (
		self: CasterSerial,
		movementMode: ("BulkMoveTo" | "Motor6D")?
	) -> (),

	RaycastFire: (
		self: CasterSerial,
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

	SetMovementModeEnabled: (
		self: CasterSerial,
		enabled: boolean,
		mode: "BulkMoveTo" | "Motor6D"
	) -> (),

	Destroy: (self: CasterSerial) -> ()
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
	@type FastCastBehavior { RaycastParams: RaycastParams?,	MaxDistance: number,	Acceleration: Vector3,	HighFidelityBehavior: number,	HighFidelitySegmentSize: number,	CosmeticBulletTemplate: Instance?,	CosmeticBulletContainer: Instance?,	AutoIgnoreContainer: boolean,	MovementMethod: "BulkMoveTo" | "Transform",		VisualizeCasts: boolean, 	VisualizeCastSettings: VisualizeCastSettings,   CloneTemplate: boolean,    FastCastEventsConfig: FastCastEventsConfig,	UserData: any }
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

		VisualizeCasts: boolean, 
	VisualizeCastSettings: VisualizeCastSettings,

	CloneTemplate: boolean,

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
	@type CastStateInfo { HighFidelityBehavior: number,	HighFidelitySegmentSize: number,	TotalRuntime: number,	DistanceCovered: number,	IsActivelySimulatingPierce: boolean,	IsActivelyResimulating: boolean,	CancelHighResCast: boolean,	Trajectory: CastTrajectory,	VisualizeCasts: boolean, 	VisualizeCastSettings: VisualizeCastSettings,	FastCastEventsConfig: FastCastEventsConfig,	}
	@within TypeDefinitions

	Represents cast state tracking data.
]=]
export type CastStateInfo = {
	HighFidelityBehavior: number,
	HighFidelitySegmentSize: number,
	TotalRuntime: number,
	DistanceCovered: number,
	IsActivelySimulatingPierce: boolean,
	IsActivelyResimulating: boolean,
	CancelHighResCast: boolean,
	Trajectory: CastTrajectory,
	VisualizeCasts: boolean,  -- I don't use this anymore
	VisualizeCastSettings: VisualizeCastSettings,

	FastCastEventsConfig: FastCastEventsConfig,

	}

--[=[
	@type CastRayInfo { Parameters: RaycastParams, WorldRoot: WorldRoot, MaxDistance: number, CosmeticBulletObject: Instance?, }
	@within TypeDefinitions

	Ray info for ray-cast variants.
]=]
export type CastRayInfo = {
	Parameters: RaycastParams,
	WorldRoot: WorldRoot,
	MaxDistance: number,
	CosmeticBulletObject: Instance?,
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
	@type BaseCastData {[string]: any}
	@within TypeDefinitions

	Internal serial cast backend reference stored on an active cast.
]=]
export type BaseCastData = { [string]: any }

--[=[
	@type ActiveCastData { Caster: BaseCastData, StateInfo: CastStateInfo, RayInfo: CastRayInfo, UserData: { [any]: any }, _Destroying: boolean, _TerminationQueued: boolean, Type : "Raycast", CFrame: CFrame, ID: number }
	@within TypeDefinitions	
	
	Represents an active cast data.
]=]
export type ActiveCastData = {
	Caster: BaseCastData,
	StateInfo: CastStateInfo,
	RayInfo: CastRayInfo,
	UserData: { [any]: any },

	_Destroying: boolean,
	_TerminationQueued: boolean,
	Type : "Raycast",
	CFrame: CFrame,
	ID: number
}

--[=[
	@type ActiveCastData { Caster: BaseCastData, StateInfo: CastStateInfo, RayInfo: BlockCastRayInfo, UserData: { [any]: any }, _Destroying: boolean, Type : "Blockcast", CFrame: CFrame, ID: number }
	@within TypeDefinitions	
	
	Represents an active block cast data.
]=]
export type ActiveBlockcastData = {
	Caster: BaseCastData,
	StateInfo: CastStateInfo,
	RayInfo: BlockCastRayInfo,
	UserData: { [any]: any },

	_Destroying: boolean,
	Type : "Blockcast",
	CFrame: CFrame,
	ID: number
}

--[=[
	@type ActiveCastData { Caster: BaseCastData, StateInfo: CastStateInfo, RayInfo: SphereCastRayInfo, UserData: { [any]: any }, _Destroying: boolean, Type : "Spherecast", CFrame: CFrame, ID: number }
	@within TypeDefinitions	
	
	Represents an active sphere cast data.
]=]
export type ActiveSpherecastData = {
	Caster: BaseCastData,
	StateInfo: CastStateInfo,
	RayInfo: SphereCastRayInfo,
	UserData: { [any]: any },

	_Destroying: boolean,
	Type : "Spherecast",
	CFrame: CFrame,
	ID: number
}

return {}
