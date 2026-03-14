--!strict
local Client = {}
Client.__index = Client

local Buffers = require("./Utils/Buffers")
local Remotes = require("./Utils/Remotes")
local Bridge = require("./Bridge")

local PACKET_EVENT = 1
local PACKET_REQUEST = 2
local PACKET_RESPONSE = 3
local REQUEST_TIMEOUT = 60

local task_spawn = task.spawn
local task_delay = task.delay
local task_cancel = task.cancel
local coroutine_running = coroutine.running
local coroutine_yield = coroutine.yield
local table_unpack = table.unpack

local GlobalInitialized = false
type Listener = {
	__type: "Connect",
	Callback: (...any) -> (),
} | {
	__type: "Once",
	Callback: (...any) -> (),
} | {
	__type: "Wait",
	Thread: thread,
}
local Listeners = {} :: {[string]: {Listener}}
local Requests = {} :: {[string]: {[number]: {thread: thread, timer: thread}}}
local RequestIdCounters = {} :: {[string]: number}

local reliable: RemoteEvent
local unreliable: UnreliableRemoteEvent

local function Initialize()
	if GlobalInitialized then return end
	GlobalInitialized = true

	Bridge.Initialize()
	local group = Remotes.Get()
	reliable = group.Reliable
	unreliable = group.Unreliable

	local function dispatch(id: string, args: {any}, count: number)
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
						task_spawn(listener.Callback, table_unpack(args, 2, count))
					elseif listener.__type == "Once" then
						task_spawn(listener.Callback, table_unpack(args, 2, count))
						table.remove(listeners, i)
					elseif listener.__type == "Wait" then
						task_spawn(listener.Thread, table_unpack(args, 2, count))
						table.remove(listeners, i)
					end
				end
			end
		elseif type == PACKET_RESPONSE then
			local reqId = args[2]
			local ok = args[3] == true or args[3] == 1

			local channelRequests = Requests[id]
			if channelRequests then
				local req = channelRequests[reqId]
				if req then
					channelRequests[reqId] = nil
					task_cancel(req.timer)
					task_spawn(req.thread, ok, table_unpack(args, 4, count))
				end
			end
		end
	end

	local function onEvent(b: buffer, i: {Instance})
		local r = Buffers.CreateReader(b, i)

		while r.cursor < r.len do
			local id = Buffers.ReadString(r)

			local type, argCount = Buffers.ReadPacketHeader(r)

			local args = table.create(argCount + 1)
			args[1] = type
			for k = 1, argCount do
				args[k + 1] = Buffers.ReadAny(r)
			end

			dispatch(id, args, argCount + 1)
		end

		Buffers.FreeReader(r)
	end

	reliable.OnClientEvent:Connect(onEvent)
	unreliable.OnClientEvent:Connect(onEvent)
end

function Client.new(name: string)
	if not GlobalInitialized then
		Initialize()
	end

	local self = setmetatable({}, Client)
	self._id = name

	if not Requests[self._id] then
		Requests[self._id] = {}
		RequestIdCounters[self._id] = 0
	end

	return self
end

function Client:Connect(callback: (...any) -> ())
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

function Client:Once(callback: (...any) -> ())
	if not Listeners[self._id] then
		Listeners[self._id] = {}
	end

	table.insert(Listeners[self._id], ({
		__type = "Once",
		Callback = callback,
	} :: Listener))
end

function Client:Wait()
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

local function Send(self: any, reliable: boolean, packetType: number, ...: any)
	local id = self._id
	local w = Bridge.Writer(reliable)

	Buffers.WriteString(w, id)

	local n = select("#", ...)
	Buffers.WritePacketHeader(w, packetType, n)

	for i = 1, n do
		Buffers.WriteAny(w, select(i, ...))
	end
end

function Client:Fire(...: any)
	Send(self, true, PACKET_EVENT, ...)
end

function Client:FireUnreliable(...: any)
	Send(self, false, PACKET_EVENT, ...)
end

function Client:Invoke(...: any)
	local id = RequestIdCounters[self._id]
	RequestIdCounters[self._id] += 1

	Send(self, true, PACKET_REQUEST, id, ...)

	local thread = coroutine_running()
	local timer = task_delay(REQUEST_TIMEOUT, function()
		if Requests[self._id][id] and Requests[self._id][id].thread == thread then
			Requests[self._id][id] = nil
			task_spawn(thread, false, "Request timed out")
		end
	end)

	Requests[self._id][id] = {thread = thread, timer = timer}

	local results = {coroutine_yield()}
	local success = results[1]

	if not success then
		error(tostring(results[2]))
	end

	return table_unpack(results, 2)
end

return Client