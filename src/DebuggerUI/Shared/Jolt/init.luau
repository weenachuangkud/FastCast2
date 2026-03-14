--!strict
local Jolt = {}

local RunService = game:GetService("RunService")

local IS_SERVER = RunService:IsServer()
local IS_CLIENT = RunService:IsClient()

local Client = require("@self/Client")
local Server = require("@self/Server")

export type Server<Args... = (...any), Out... = (...any)> = {
	Fire: (self: Server<Args..., Out...>, player: Player, Args...) -> (),
	FireUnreliable: (self: Server<Args..., Out...>, player: Player, Args...) -> (),
	FireAll: (self: Server<Args..., Out...>, Args...) -> (),
	FireAllUnreliable: (self: Server<Args..., Out...>, Args...) -> (),
	Connect: (self: Server<Args..., Out...>, callback: (player: Player, Args...) -> ()) -> { Disconnect: () -> () },
	Once: (self: Server<Args..., Out...>, callback: (player: Player, Args...) -> ()) -> (),
	Wait: (self: Server<Args..., Out...>) -> (Player, Args...),
	OnInvoke: ((player: Player, Args...) -> Out...)?,
}

export type Client<Args... = (...any), Out... = (...any)> = {
	Fire: (self: Client<Args..., Out...>, Args...) -> (),
	FireUnreliable: (self: Client<Args..., Out...>, Args...) -> (),
	Invoke: (self: Client<Args..., Out...>, Args...) -> Out...,
	Connect: (self: Client<Args..., Out...>, callback: (Args...) -> ()) -> { Disconnect: () -> () },
	Once: (self: Client<Args..., Out...>, callback: (Args...) -> ()) -> (),
	Wait: (self: Client<Args..., Out...>) -> Args...,
}

function Jolt.Server<Args..., Out...>(name: string): Server<Args..., Out...>
	if not IS_SERVER then
		error("Jolt.Server can only be called on the server.")
	end

	return Server.new(name) :: any
end

function Jolt.Client<Args..., Out...>(name: string): Client<Args..., Out...>
	if not IS_CLIENT then
		error("Jolt.Client can only be called on the client.")
	end

	return Client.new(name) :: any
end

return Jolt