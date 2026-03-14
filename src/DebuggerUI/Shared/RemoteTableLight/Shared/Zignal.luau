--!strict

export type Connection<A...> = {
	Connected:				boolean,
	Disconnect:				(self: Connection<A...>) -> (),
	_function:				(A...) -> (),
	_next:					Connection<A...>?,
	_previous:				Connection<A...>,
}

export type Signal<A...> = {
	new: 					() -> Signal<A...>,
	Fire: 					(self: Signal<A...>, A...) -> (),
	Wait:					(self: Signal<A...>) -> A...,
	Once:					(self: Signal<A...>, func: (A...) -> ()) -> Connection<A...>,
	Connect: 				(self: Signal<A...>, func: (A...) -> ()) -> Connection<A...>,
	DisconnectAll: 			(self: Signal<A...>) -> (),
	_next:					Connection<A...>?,
}

local threads: {thread} = {}

local function Call<A...>(func: (A...) -> (), thread: thread, ...: A...): ()
	func(...) 
	table.insert(threads, thread)
end

local function Yield(): ()
	while true do Call(coroutine.yield()) end
end

local Signal, Connection = {}, {}
Signal.__index, Connection.__index = Signal, Connection

local function Disconnect<A...>(self: Connection<A...>): ()
	if self.Connected then self.Connected = false else return end
	local next, previous = self._next, self._previous
	if next then next._previous = previous end
	previous._next = next
end

local function New<A...>(): Signal<A...>
	return (setmetatable({}, Signal) :: any) :: Signal<A...>
end

local function Fire<A...>(self: Signal<A...>, ...: A...): ()
	local link = self._next
	while link do
		local length, thread = #threads, nil
		if length == 0 then
			thread = coroutine.create(Yield)
			coroutine.resume(thread)
		else
			thread = threads[length]
			threads[length] = nil
		end
		task.spawn(thread, link._function, thread, ...)
		link = link._next
	end
end

local function Connect<A...>(self: Signal<A...>, func: (A...) -> ()): Connection<A...>
	local next = self._next
	local link = {Connected = true, _previous = self, _function = func, _next = next} :: any
	if next ~= nil then next._previous = link end
	self._next = link
	return setmetatable(link, Connection) :: Connection<A...>
end

local function Once<A...>(self: Signal<A...>, func: (A...) -> ()): Connection<A...>
	local connection
	connection = Connect(self, function(...)
		Disconnect(connection)
		func(...)
	end)
	return connection
end

local function Wait<A...>(self: Signal<A...>): A...
	local thread, connection = coroutine.running(), nil
	connection = Connect(self, function(...)
		Disconnect(connection)
		if coroutine.status(thread) == "suspended" then task.spawn(thread, ...) end
	end)
	return coroutine.yield()
end

local function DisconnectAll<A...>(self: Signal<A...>): ()
	local link = self._next
	while link do
		link.Connected = false
		link = link._next
	end
	self._next = nil
end

Signal.new = New
Signal.Fire = Fire
Signal.Wait = Wait
Signal.Once = Once
Signal.Connect = Connect
Signal.DisconnectAll = DisconnectAll
Connection.Disconnect = Disconnect

return Signal