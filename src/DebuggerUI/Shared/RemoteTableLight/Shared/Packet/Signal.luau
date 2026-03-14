--!strict


-- Requires
local Task = require(script.Parent.Task)


-- Types
export type Signal<A... = ()> = {
	Type:					"Signal",
	Previous:				Connection<A...>,
	Next:					Connection<A...>,
	Fire:					(self: Signal<A...>, A...) -> (),
	Connect:				(self: Signal<A...>, func: (A...) -> ()) -> Connection<A...>,
	Once:					(self: Signal<A...>, func: (A...) -> ()) -> Connection<A...>,
	Wait:					(self: Signal<A...>) -> A...,
}

export type Connection<A... = ()> = {
	Type:					"Connection",
	Previous:				Connection<A...>,
	Next:					Connection<A...>,
	Once:					boolean,
	Function:				(player: Player, A...) -> (),
	Thread:					thread,
	Disconnect:				(self: Connection<A...>) -> (),
}


-- Varables
local Signal = {}			:: Signal<...any>
local Connection = {}		:: Connection<...any>


-- Constructor
local function Constructor<A...>()
	local signal = (setmetatable({}, Signal) :: any) :: Signal<A...>
	signal.Previous = signal :: any
	signal.Next = signal :: any
	return signal
end


-- Signal
Signal["__index"] = Signal
Signal.Type = "Signal"

function Signal:Connect(func)
	local connection = (setmetatable({}, Connection) :: any) :: Connection
	connection.Previous = self.Previous
	connection.Next = self :: any
	connection.Once = false
	connection.Function = func
	self.Previous.Next = connection
	self.Previous = connection
	return connection
end

function Signal:Once(func)
	local connection = (setmetatable({}, Connection) :: any) :: Connection
	connection.Previous = self.Previous
	connection.Next = self :: any
	connection.Once = true
	connection.Function = func
	self.Previous.Next = connection
	self.Previous = connection
	return connection
end

function Signal:Wait()
	local connection = (setmetatable({}, Connection) :: any) :: Connection
	connection.Previous = self.Previous
	connection.Next = self :: any
	connection.Once = true
	connection.Thread = coroutine.running()
	self.Previous.Next = connection
	self.Previous = connection
	return coroutine.yield()
end

function Signal:Fire(...)
	local connection = self.Next
	while connection.Type == "Connection" do
		if connection.Function then Task:Defer(connection.Function, ...) else task.defer(connection.Thread, ...) end
		if connection.Once then connection.Previous.Next = connection.Next connection.Next.Previous = connection.Previous end
		connection = connection.Next
	end
end


-- Connection
Connection["__index"] = Connection
Connection.Type = "Connection"

function Connection:Disconnect()
	self.Previous.Next = self.Next
	self.Next.Previous = self.Previous
end


return Constructor