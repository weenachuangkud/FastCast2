--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
assert(RunService:IsServer(), "Unable to require server module from client.")

local Server = {}

local Shared = script.Parent.Shared
local Util = require(Shared.Util)
local Packets = require(Shared.Packets)
local TokenRegistry = require(Shared.TokenRegistry)

local DeepCopy = Util.DeepCopy
local BufferAppend = Util.BufferAppend
local UtilGetTableId = Util.GetTableId
local BufferWriteU8 = Util.BufferWriteU8
local BufferWriteU16 = Util.BufferWriteU16
local BufferTruncate = Util.BufferTruncate
local IsValidValueType = Util.IsValidValueType

type Id = Util.Id
type Key = Util.Key
type Table = Util.Table
type Token = Util.Token
type TokenName = Util.TokenName
type ListenerTable = {[Player]: boolean}

local SET_OPCODE = Util.OpCodeLookup["Set"]
local NEW_TABLE_OPCODE = Util.OpCodeLookup["NewTable"]
local NEW_REMOTE_TABLE_OPCODE = Util.OpCodeLookup["NewRemoteTable"]
local DESTROY_REMOTE_TABLE_OPCODE = Util.OpCodeLookup["DestroyRemoteTable"]

local SetTablePacket = Packets.Set
local NewTablePacket = Packets.NewTable
local NewRemoteTablePacket = Packets.NewRemoteTable
local DestroyRemoteTablePacket = Packets.DestroyRemoteTable

local SendEventStream = Packets.SendEventStream

local ClientTokens = {} :: {[Player]: {[Token]: boolean}}
local RemoteTables = {} :: {[Token]: {
	Data: any,
	Listeners: {[Player]: "Connected" | "Disconnected"},
}}

local TokenLinks = {} :: {[Table]: Token | false}
local ChangedTables = {} :: {[Token]: boolean}
local TableEventStream = {} :: {[Token]: {Offset: number, Buffer: buffer}}

local function ResetRemoteTableBuffer(token: Token)
	local event_stream = TableEventStream[token]
	local event_offset = 0
	local event_buffer = event_stream.Buffer
	
	event_buffer, event_offset = BufferWriteU16(event_buffer, event_offset, token)
	event_stream.Buffer = event_buffer
	event_stream.Offset = event_offset
end

local function DispatchRemoteTableEventStream(token: Token)
	local event_stream = TableEventStream[token]
	local package = BufferTruncate(event_stream.Buffer, event_stream.Offset)
	for listener, state in RemoteTables[token].Listeners do
		if state ~= "Connected" then continue end
		SendEventStream:FireClient(listener, package)
	end
	ResetRemoteTableBuffer(token)
	ChangedTables[token] = nil
end

local function PushEvent(token: Token, event: string, ...: any)
	ChangedTables[token] = true
	local op_code = Util.OpCodeLookup[event]
	local event_stream = TableEventStream[token]
	local event_buffer = event_stream.Buffer
	local event_offset = event_stream.Offset
	
	local packet = Packets[event] :: any
	local event_package = packet:Serialize(...)

	event_buffer, event_offset = BufferWriteU8(event_buffer, event_offset, op_code)
	event_buffer, event_offset = BufferAppend(event_buffer, event_offset, event_package)
	
	event_stream.Buffer = event_buffer
	event_stream.Offset = event_offset
end

local function SetReplicationInfo(token: number, tbl: any, info: any)
	if typeof(info) == "table" then
		for k, current_info in info do
			local current_tbl = tbl[k]
			TokenLinks[tbl] = token
			SetReplicationInfo(token, current_tbl, current_info)
		end
	else
		assert(typeof(info)=="boolean", "Non-boolean value in selective replication data.")
		TokenLinks[tbl] = if info == false then false else token
	end
end

local function RegisterValue(token: number, parent: any, key: any, value: any)
	if not TokenLinks[parent] then return end
	if typeof(value) == "table" then
		if TokenLinks[value] == false then return end
		TokenLinks[value] = token
		
		PushEvent(token, "NewTable", UtilGetTableId(parent), key, UtilGetTableId(value))
		
		for k, v in value do
			RegisterValue(token, value, k, v)
		end
	else
		PushEvent(token, "Set", UtilGetTableId(parent), key, value)
	end
end

local function UnregisterValue(token: number, value: any)
	if value == nil or not TokenLinks[value] then return end
	if typeof(value) == "table" then
		TokenLinks[value] = nil
		for k, v in value do
			UnregisterValue(token, v)
		end
	end
end

local function GetSnapshotStream(stream: buffer, offset: number, token: number, parent: any, key: any, value: any): (buffer, number)
	if not TokenLinks[parent] then return stream, offset end
	if typeof(value) == "table" then
		if TokenLinks[value] == false then return stream, offset end
		TokenLinks[value] = token
		
		local event_package = NewTablePacket:Serialize(UtilGetTableId(parent), key, UtilGetTableId(value))
		stream, offset = BufferWriteU8(stream, offset, NEW_TABLE_OPCODE)
		stream, offset = BufferAppend(stream, offset, event_package)
		for k, v in value do
			stream, offset = GetSnapshotStream(stream, offset, token, value, k, v)
		end
	else
		local event_package = SetTablePacket:Serialize(UtilGetTableId(parent), key, value)
		stream, offset = BufferWriteU8(stream, offset, SET_OPCODE)
		stream, offset = BufferAppend(stream, offset, event_package)
	end
	return stream, offset
end

local function GetRootSnapshotStream(token: number): buffer
	local root = RemoteTables[token].Data
	local root_id = UtilGetTableId(root)
	local stream = buffer.create(128)
	local offset = 0
	
	-- Token header
	stream, offset = BufferWriteU16(stream, offset, token)
	
	-- Sync write start
	local event_package = NewRemoteTablePacket:Serialize(root_id, false)
	stream, offset = BufferWriteU8(stream, offset, NEW_REMOTE_TABLE_OPCODE)
	stream, offset = BufferAppend(stream, offset, event_package)
	
	for k, v in root do
		stream, offset = GetSnapshotStream(stream, offset, token, root, k, v)
	end
	
	-- Sync write end
	local event_package = NewRemoteTablePacket:Serialize(root_id, true)
	stream, offset = BufferWriteU8(stream, offset, NEW_REMOTE_TABLE_OPCODE)
	stream, offset = BufferAppend(stream, offset, event_package)
	
	return BufferTruncate(stream, offset)
end

local function GetClientTokens(client: Player): {[Token]: boolean}
	local client_tokens = ClientTokens[client]
	if client_tokens then return client_tokens end
	
	local client_tokens = {}
	ClientTokens[client] = client_tokens
	return client_tokens
end

local function ConnectClient(token: Token, client: Player)
	local remote_table = RemoteTables[token]
	if not remote_table then return end
	
	local state = remote_table.Listeners[client]
	if not state or state ~= "Disconnected" then return end
	
	remote_table.Listeners[client] = "Connected"
	Packets.SendEventStream:FireClient(client, GetRootSnapshotStream(token))
end

local function DisconnectClient(token: Token, client: Player)
	local remote_table = RemoteTables[token]
	if not remote_table then return end
	
	local state = remote_table.Listeners[client]
	if not state or state ~= "Connected" then return end
	
	remote_table.Listeners[client] = "Disconnected"
	
	local stream = buffer.create(128)
	local offset = 0
	
	-- Token header
	stream, offset = BufferWriteU16(stream, offset, token)
	
	local event_package = DestroyRemoteTablePacket:Serialize(token)
	stream, offset = BufferWriteU8(stream, offset, DESTROY_REMOTE_TABLE_OPCODE)
	stream, offset = BufferAppend(stream, offset, event_package)
	Packets.SendEventStream:FireClient(client, BufferTruncate(stream, offset))
end

local function AddClient(token: Token, client: Player)
	local remote_table = RemoteTables[token]
	assert(remote_table, "[RemoteTable]: AddClient failed. RemoteTable does not exist.")
	local state = remote_table.Listeners[client]
	if state then return end
	
	remote_table.Listeners[client] = "Disconnected"
	local client_tokens = GetClientTokens(client)
	client_tokens[token] = true
end

local function RemoveClient(token: Token, client: Player)
	local remote_table = RemoteTables[token]
	assert(remote_table, "[RemoteTable]: RemoveClient failed. RemoteTable does not exist.")
	local state = remote_table.Listeners[client]
	if not state then return end
	
	if state == "Connected" then
		DisconnectClient(token, client)
	end
	
	remote_table.Listeners[client] = nil
	local client_tokens = GetClientTokens(client)
	client_tokens[token] = nil
end

function Server.Set(parent: any, key: Key, value: any)
	assert(IsValidValueType(value), "Value can not be an Instance.")
	local token = TokenLinks[parent] :: number
	local previous_value = parent[key]
	if value == previous_value then return end
	
	UnregisterValue(token, previous_value)
	RegisterValue(token, parent, key, value)
	parent[key] = value
end

function Server.Increment(parent: any, key: Key, value: number)
	if value == 0 then return end
	local token = TokenLinks[parent] :: number

	parent[key] += value
	RegisterValue(token, parent, key, parent[key])
end

function Server.Insert<V>(tbl: {V}, value: V)
	assert(IsValidValueType(value), "Value can not be an Instance.")

	table.insert(tbl, value)

	local token = TokenLinks[tbl] :: number
	if token then
		PushEvent(token, "Insert", UtilGetTableId(tbl), value)
	end
end

function Server.InsertAt<V>(tbl: {V}, pos: number?, value: V)
	local pos = pos or #tbl + 1
	assert(typeof(pos) == "number", "Index must be a number.")
	assert(IsValidValueType(value), "Value can not be an Instance.")

	table.insert(tbl, pos, value)

	local token = TokenLinks[tbl] :: number
	if token then
		PushEvent(token, "InsertAt", UtilGetTableId(tbl), pos, value)
	end
end

function Server.Remove<V>(tbl: {V}, pos: number?): V?
	local pos = pos or #tbl
	assert(typeof(pos) == "number", "Index must be a number.")
	local removed = table.remove(tbl, pos)
	if removed == nil then return nil end
	
	local token = TokenLinks[tbl] :: number
	if token then
		PushEvent(token, "Remove", UtilGetTableId(tbl), pos)
	end
	return removed
end

function Server.SwapRemove<V>(tbl: {V}, pos: number?): V?
	local pos = pos or #tbl
	assert(typeof(pos) == "number", "Index must be a number.")
	local removed = Util.SwapRemove(tbl, pos)
	if removed == nil then return nil end
	
	local token = TokenLinks[tbl] :: number
	if token then
		PushEvent(token, "SwapRemove", UtilGetTableId(tbl), pos)
	end
	return removed
end

function Server.Clear(tbl: any)
	table.clear(tbl)
	local token = TokenLinks[tbl]
	if token then
		PushEvent(token :: number, "Clear", UtilGetTableId(tbl))
	end
end

function Server.Create<T>(token_name: string, template: T, selective_replication: any): T
	assert(not TokenRegistry.IsTokenRegistered(token_name), "RemoteTable with this id already exists.")
	local token = TokenRegistry.Register(token_name)
	local root = DeepCopy(template) :: any
	TableEventStream[token] = {
		Buffer = buffer.create(128),
		Offset = 0,
	}
	RemoteTables[token] = {
		Data = root,
		Listeners = {},
	}
	TokenLinks[root] = token
	if not selective_replication then
		selective_replication = {}
	end
	for k, v in root :: any do
		if selective_replication[k] == nil and typeof(root[k]) == "table" then
			selective_replication[k] = true
		end
	end
	SetReplicationInfo(token, root, selective_replication)
	for k, v in root :: any do
		RegisterValue(token, root, k, v)
	end
	ResetRemoteTableBuffer(token)
	return root
end

function Server.Get(token_name: string): any?
	if not TokenRegistry.IsTokenRegistered(token_name) then return nil end
	
	local token = TokenRegistry.GetToken(token_name)
	if not token then return nil end
	
	local remote_table = RemoteTables[token]
	if not remote_table then return nil end
	
	return remote_table.Data
end

function Server.Destroy<T>(token_name: string)
	if not TokenRegistry.IsTokenRegistered(token_name) then return end
	
	local token = TokenRegistry.GetToken(token_name)
	local remote_table = RemoteTables[token]
	local root = remote_table.Data
	
	PushEvent(token, "DestroyRemoteTable", token)
	DispatchRemoteTableEventStream(token)
	
	for client, state in remote_table.Listeners do
		RemoveClient(token, client)
	end
	
	UnregisterValue(token, root)
	
	RemoteTables[token] = nil
	
	TokenLinks[root] = nil
	ChangedTables[token] = nil
	TableEventStream[token] = nil
	
	TokenRegistry.Unregister(token_name)
end

function Server.AddClient(token_name: TokenName, clients: Player | {Player})
	assert(TokenRegistry.IsTokenRegistered(token_name), "Token not registered.")
	local token = TokenRegistry.GetToken(token_name)
	if typeof(clients) == "table" then
		for _, client in clients do
			AddClient(token, client)
		end
	else
		AddClient(token, clients)
	end
end

function Server.RemoveClient(token_name: TokenName, clients: Player | {Player})
	assert(TokenRegistry.IsTokenRegistered(token_name), "Token not registered.")
	local token = TokenRegistry.GetToken(token_name)
	if typeof(clients) == "table" then
		for _, client in clients do
			RemoveClient(token, client)
		end
	else
		RemoveClient(token, clients)
	end
end

local DispatchLoop = task.spawn(function()
	while true do
		coroutine.yield()
		for token, changed in ChangedTables do
			if not changed then continue end
			DispatchRemoteTableEventStream(token)
		end
	end
end)
RunService.Heartbeat:Connect(function() task.defer(DispatchLoop) end)

Packets.ConnectionRequest.OnServerEvent:Connect(function(client: Player, token: number)
	ConnectClient(token, client)
end)

Players.PlayerRemoving:Connect(function(client: Player, reason: Enum.PlayerExitReason)
	local tokens = GetClientTokens(client)
	if not tokens then return end
	
	for token, _ in tokens do
		RemoveClient(token, client)
	end
	ClientTokens[client] = nil
end)

return Server