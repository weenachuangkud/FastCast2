--[[
	Author: Darwin (darwin@shellworks.dev)
	Date: 18/09/2026

	Signal - a lightweight, synchronous event dispatcher.

	FastCast2 uses this instead of `BindableEvent` for Caster events. It has no
	Instance overhead and, unlike a `BindableEvent`, supports any number of
	independent listeners plus explicit `Disconnect`/`Reconnect`.

	This is a pure-Luau object and therefore cannot cross an Actor boundary; the
	parallel worker VMs still use a `BindableEvent` as the transport and simply
	`Fire` the Caster's signals on the main thread.
]]

-- Types

export type Connection = {
	Connected: boolean,

	Disconnect: (self: Connection) -> (),
	Reconnect: (self: Connection) -> (),
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, callback: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, callback: (T...) -> ()) -> Connection,
	Wait: (self: Signal<T...>) -> T...,
	Fire: (self: Signal<T...>, T...) -> (),
	DisconnectAll: (self: Signal<T...>) -> (),
	Destroy: (self: Signal<T...>) -> (),
}

-- Connection

local Connection = {}
Connection.__index = Connection
Connection.__type = "Connection"

local function disconnect(self)
	if not self.Connected then
		return
	end

	self.Connected = false

	local signal = self._signal
	if signal == nil then
		return
	end

	local prev = self._prev
	local next = self._next

	if prev then
		prev._next = next
	elseif signal._head == self then
		signal._head = next
	end

	if next then
		next._prev = prev
	end
end

local function reconnect(self)
	if self.Connected then
		return
	end

	local signal = self._signal
	if signal == nil then
		return
	end

	self.Connected = true

	local head = signal._head
	self._next = head
	self._prev = nil

	if head then
		head._prev = self
	end

	signal._head = self
end

Connection.Disconnect = disconnect
Connection.Reconnect = reconnect

-- Signal

local Signal = {}
Signal.__index = Signal
Signal.__type = "Signal"

function Signal.new()
	return setmetatable({ _head = nil, _destroyed = false }, Signal)
end

function Signal.is(value: any): boolean
	return type(value) == "table" and getmetatable(value) == Signal
end

function Signal:Connect(callback)
	assert(type(callback) == "function", "Signal:Connect expects a function")

	local connection = setmetatable({
		Connected = true,
		_signal = self,
		_fn = callback,
		_prev = nil,
		_next = self._head,
	}, Connection)

	local head = self._head
	if head then
		head._prev = connection
	end
	self._head = connection

	return connection
end

function Signal:Once(callback)
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		callback(...)
	end)
	return connection
end

function Signal:Wait()
	local thread = coroutine.running()
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function Signal:Fire(...)
	if self._destroyed then
		return
	end

	local connection = self._head
	while connection do
		-- Capture the next link before firing so a listener that disconnects
		-- itself (or another listener) cannot break traversal.
		local nextConnection = connection._next
		if connection.Connected then
			connection._fn(...)
		end
		connection = nextConnection
	end
end

function Signal:DisconnectAll()
	local connection = self._head
	while connection do
		local nextConnection = connection._next
		connection:Disconnect()
		connection = nextConnection
	end
	self._head = nil
end

function Signal:Destroy()
	self._destroyed = true
	self:DisconnectAll()
end

--[[
	Wrap an `RBXScriptSignal` so it can be used like a Signal. Useful when
	building APIs that mix Roblox signals with FastCast2 signals.
]]
function Signal.wrap(rbxSignal)
	local signal = Signal.new()
	signal._rbxConnection = rbxSignal:Connect(function(...)
		signal:Fire(...)
	end)
	return signal
end

return Signal
