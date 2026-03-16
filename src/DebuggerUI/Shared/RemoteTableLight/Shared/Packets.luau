--!strict
local NS = "__REMOTE_TABLE__"
local Packet = require(script.Parent.Packet)
local Token = Packet.NumberU16
local TokenName = Packet.String
local TableId = Packet.NumberF64
local Key = Packet.Any
local Value = Packet.Any
local EventStream = Packet.BufferLong
local WriteStart = Packet.Boolean8

local SendEventStreamRemote: RemoteEvent
local IsServer = game:GetService("RunService"):IsServer()
if IsServer then
	SendEventStreamRemote = Instance.new("RemoteEvent")
	SendEventStreamRemote.Name = "SendEventStreamRemote"
	SendEventStreamRemote.Parent = script
else
	SendEventStreamRemote = script:WaitForChild("SendEventStreamRemote")
end
return {
	ConnectionRequest = Packet(NS.."Request", Token),
	
	SendEventStream = SendEventStreamRemote,
	NewRemoteTable = Packet(NS.."NewRemoteTable", TableId, WriteStart),
	DestroyRemoteTable = Packet(NS.."DestroyRemoteTable", TableId),
	NewTable = Packet(NS.."NewTable", TableId, Key, TableId),
	Set = Packet(NS.."Set", TableId, Key, Value),
	Insert = Packet(NS.."Insert", TableId, Value),
	InsertAt = Packet(NS.."InsertAt", TableId, Key, Value),
	Remove = Packet(NS.."Remove", TableId, Key),
	SwapRemove = Packet(NS.."SwapRemove", TableId, Key),
	Clear = Packet(NS.."Clear", TableId),
}