--[[
	FastCastEventsModule used by the parallel tests.

	It is required inside each worker Actor VM and forwards every event to a
	BindableEvent in ReplicatedStorage so the main thread can observe it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local signal = ReplicatedStorage:WaitForChild("FastCast2TestSignal") :: BindableEvent

local function forward(name: string)
	return function(...)
		signal:Fire(name, ...)
	end
end

return {
	CastFire = forward("CastFire"),
	Hit = forward("Hit"),
	Pierced = forward("Pierced"),
	LengthChanged = forward("LengthChanged"),
	CastTerminating = forward("CastTerminating"),
	CanPierce = function()
		return false
	end,
}
