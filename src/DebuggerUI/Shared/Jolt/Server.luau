--!strict
local Server = {}
Server.__index = Server

local Buffers = require("./Utils/Buffers")
local Remotes = require("./Utils/Remotes")
local Bridge = require("./Bridge")

local PACKET_EVENT = 1
local PACKET_REQUEST = 2
local PACKET_RESPONSE = 3

local task_spawn = task.spawn
local table_remove = table.remove
local table_unpack = table.unpack

local GlobalInitialized = false
type Listener = {
	__type: "Connect",
	Callback: (Player, ...any) -> (),
} | {
	__type: "Once",
	Callback: (Player, ...any) -> (),
} | {
	__type: "Wait",
	Thread: thread,
}
local Listeners = {} :: {[string]: {Listener}}
local InvokeHandlers = {} :: {[string]: (Player, ...any) -> ...any}

local reliable: RemoteEvent
local unreliable: UnreliableRemoteEvent

local function Initialize()
	if GlobalInitialized then return end
	GlobalInitialized = true

	Bridge.Initialize()
	local group = Remotes.Get()
	reliable = group.Reliable
	unreliable = group.Unreliable

	local function dispatch(player: Player, id: string, args: {any}, count: number)
		local type = args[1]
		if type == PACKET_EVENT then
			local listeners = Listeners[id]
			if not listeners then
				return
			end

			for i = #listeners, 1, -1 do
				local listener = listeners[i]
				if listener then
					if listener.__type == "Connect" then
						task_spawn(listener.Callback, player, table_unpack(args, 2, count))
					elseif listener.__type == "Once" then
						task_spawn(listener.Callback, player, table_unpack(args, 2, count))
						table.remove(listeners, i)
					elseif listener.__type == "Wait" then
						task_spawn(listener.Thread, player, table_unpack(args, 2, count))
						table.remove(listeners, i)
					end
				end
			end
		elseif type == PACKET_REQUEST then
			local reqId = args[2]
			local handler = InvokeHandlers[id]
			if handler then
				task_spawn(function()
					local results = {pcall(handler, player, table_unpack(args, 3, count))}
					local ok = results[1]
					table_remove(results, 1)

					local w = Bridge.Writer(true, player)
					Buffers.WriteString(w, id)

					local n = #results + 2
					Buffers.WritePacketHeader(w, PACKET_RESPONSE, n)

					Buffers.WriteAny(w, reqId)
					Buffers.WriteAny(w, ok)

					for _, v in ipairs(results) do
						Buffers.WriteAny(w, v)
					end
				end)
			end
		end
	end

	local function onEvent(player: Player, b: buffer, i: {Instance})
		local r = Buffers.CreateReader(b, i)

		while r.cursor < r.len do
			local id = Buffers.ReadString(r)

			local type, argCount = Buffers.ReadPacketHeader(r)

			local args = table.create(argCount + 1)
			args[1] = type
			for k = 1, argCount do
				args[k + 1] = Buffers.ReadAny(r)
			end

			dispatch(player, id, args, argCount + 1)
		end

		Buffers.FreeReader(r)
	end

	reliable.OnServerEvent:Connect(onEvent)
	unreliable.OnServerEvent:Connect(onEvent)
end

function Server.new(name: string)
	if not GlobalInitialized then
		Initialize()
	end

	local self = setmetatable({}, Server)
	self._id = name

	return self
end

function Server:Connect(callback: (Player, ...any) -> ())
	if not Listeners[self._id] then
		Listeners[self._id] = {}
	end

	local newListener: Listener = {
		__type = "Connect",
		Callback = callback,
	}
	table.insert(Listeners[self._id], newListener)

	return {
		Disconnect = function()
			if not Listeners[self._id] then
				return
			end
			for i, listener in ipairs(Listeners[self._id]) do
				if listener == newListener then
					table.remove(Listeners[self._id], i)
					break
				end
			end
		end,
	}
end

function Server:Once(callback: (Player, ...any) -> ())
	if not Listeners[self._id] then
		Listeners[self._id] = {}
	end

	table.insert(Listeners[self._id], ({
		__type = "Once",
		Callback = callback,
	} :: Listener))
end

function Server:Wait()
	if not Listeners[self._id] then
		Listeners[self._id] = {}
	end

	local thread = coroutine.running()
	table.insert(Listeners[self._id], ({
		__type = "Wait",
		Thread = thread,
	} :: Listener))

	return coroutine.yield()
end

local function Send(self: any, reliable: boolean, player: Player?, packetType: number, ...: any)
	local id = self._id
	local w = Bridge.Writer(reliable, player)

	Buffers.WriteString(w, id)

	local n = select("#", ...)
	Buffers.WritePacketHeader(w, packetType, n)

	for i = 1, n do
		Buffers.WriteAny(w, select(i, ...))
	end
end

function Server:Fire(player: Player, ...: any)
	Send(self, true, player, PACKET_EVENT, ...)
end

function Server:FireUnreliable(player: Player, ...: any)
	Send(self, false, player, PACKET_EVENT, ...)
end

function Server:FireAll(...: any)
	Send(self, true, nil, PACKET_EVENT, ...)
end

function Server:FireAllUnreliable(...: any)
	Send(self, false, nil, PACKET_EVENT, ...)
end

function Server:__newindex(k, v)
	if k == "OnInvoke" then
		InvokeHandlers[self._id] = v
	else
		rawset(self, k, v)
	end
end

return Server