--!strict
local Remotes = {}

local instance_new = Instance.new

local RELIABLE_NAME = "Jolt_Reliable"
local UNRELIABLE_NAME = "Jolt_Unreliable"

export type RemoteGroup = {
	Reliable: RemoteEvent,
	Unreliable: UnreliableRemoteEvent,
}

local _cachedGroup: RemoteGroup? = nil

function Remotes.Get(): RemoteGroup
	if _cachedGroup then
		return _cachedGroup
	end

	local reliable = script:WaitForChild(RELIABLE_NAME)
	local unreliable = script:WaitForChild(UNRELIABLE_NAME)

	if not reliable or not unreliable then
		error("Jolt remotes not found. Ensure Jolt is initialized on the server.")
	end

	_cachedGroup = {
		Reliable = reliable :: RemoteEvent,
		Unreliable = unreliable :: UnreliableRemoteEvent,
	}
	return _cachedGroup :: RemoteGroup
end

function Remotes.Create(): RemoteGroup
	if _cachedGroup then
		return _cachedGroup
	end

	local reliable = script:FindFirstChild(RELIABLE_NAME)
	local unreliable = script:FindFirstChild(UNRELIABLE_NAME)

	if not reliable then
		reliable = instance_new("RemoteEvent")
		reliable.Name = RELIABLE_NAME
		reliable.Parent = script
	end

	if not unreliable then
		unreliable = instance_new("UnreliableRemoteEvent")
		unreliable.Name = UNRELIABLE_NAME
		unreliable.Parent = script
	end

	_cachedGroup = {
		Reliable = reliable :: RemoteEvent,
		Unreliable = unreliable :: UnreliableRemoteEvent,
	}
	return _cachedGroup :: RemoteGroup
end

return Remotes