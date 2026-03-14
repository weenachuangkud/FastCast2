--!strict
--!optimize 2

local Signal = require(script.Parent.Zignal)

local PromiseLight = {}
PromiseLight.__index = PromiseLight

export type Status = "Success" | "Timeout" | "Cancel"
type Callback<A...> = (Status, A...) -> ()
type self<A...> = {
	Resolved: boolean,
	Destroyed: boolean,
	PreResolve: Callback<A...>?,
	PostResolve: Callback<A...>?,
	_Timeout: number?,
	_TimeoutThread: thread?,
	_OutputSignal: Signal.Signal<(Status, A...)>,
}
export type PromiseLight<A...> = typeof(setmetatable({} :: self<A...>, PromiseLight))

function PromiseLight.new<A...>(timeout: number?): PromiseLight<A...>
	local self = setmetatable({}, PromiseLight) :: PromiseLight<A...>
	self.Resolved = false
	self.Destroyed = false
	self._OutputSignal = Signal.new()
	if timeout then
		self._Timeout = timeout
		local timeout_thread = task.delay(self._Timeout, function()
			self.Resolve(self :: any, "Timeout")
		end)
		self._TimeoutThread = timeout_thread
	end
	return self
end

-- Resolves with given arguments and status
function PromiseLight.Resolve<A...>(self: PromiseLight<A...>, status: Status, ...: A...)
	if self.Destroyed then warn("Can not resolve a destroyed PromiseLight.") return end
	if self.Resolved then warn("Can not resolve a resolved PromiseLight.") return end
	self.Resolved = true
	if self.PreResolve then
		self.PreResolve(status, ...)
	end
	if self._TimeoutThread then
		if coroutine.status(self._TimeoutThread) == "suspended" then
			task.cancel(self._TimeoutThread)
		end
		self._TimeoutThread = nil
	end
	self._OutputSignal:Fire(status, ...)
	if self.PostResolve then
		self.PostResolve(status, ...)
	end
	self.Destroy(self :: any)
end

-- Awaits the resolvement
function PromiseLight.Await<A...>(self: PromiseLight<A...>): (Status, A...)
	assert(not self.Destroyed, "Can not await a destroyed PromiseLight.")
	return self._OutputSignal:Wait()
end

-- Hooks a callback to run on resolvement
function PromiseLight.OnResolve<A...>(self: PromiseLight<A...>, callback: Callback<A...>)
	assert(not self.Destroyed, "Can not hook a callback to a destroyed PromiseLight.")
	self._OutputSignal:Connect(callback)
end

-- Resolves with "Cancel" status
function PromiseLight.Cancel<A...>(self: PromiseLight<A...>)
	assert(not self.Destroyed, "Can not cancel a destroyed PromiseLight.")
	if self.Resolved then return end
	self.Resolve(self :: any, "Cancel")
end

-- Resolves with "Cancel" if not resolved and destroys the class
function PromiseLight.Destroy<A...>(self: PromiseLight<A...>)
	if self.Destroyed then return end
	if not self.Resolved then
		self.Cancel(self :: any)
	end
	self.Destroyed = true
	self._OutputSignal:DisconnectAll()
	self._OutputSignal = nil :: any
end

return PromiseLight