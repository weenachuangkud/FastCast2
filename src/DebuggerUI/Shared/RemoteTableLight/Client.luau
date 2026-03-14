--!strict
--!optimize 2

if game:GetService("RunService"):IsServer() then
	error("Can't require client module from server.")
end

local Client = {}

local Shared = script.Parent.Shared
local Util = require(Shared.Util)
local Signal = require(Shared.Zignal)
local Packets = require(Shared.Packets)
local PromiseLight = require(Shared.PromiseLight)
local TokenRegistry = require(Shared.TokenRegistry)

local OpCodes = Util.OpCodes
local AppendPath = Util.AppendPath
local ToPathString = Util.ToPathString

type Id = Util.Id
type Key = Util.Key
type Path = Util.Path
type Table = Util.Table
type Token = Util.Token
type TokenName = Util.TokenName

type SignalType = "ChildAdded" | "ChildRemoved" | "Changed"

type SignalGroup = {
	Changed: Signal.Signal<any, any>?,
	ChildAdded: Signal.Signal<Key, any>?,
	ChildRemoved: Signal.Signal<Key, any>?,
}
local DataSignals = {} :: {[Token]: {[Path]: SignalGroup}}

local VALID_SIGNAL_TYPES = {
	Changed = true,
	ChildAdded = true,
	ChildRemoved = true,
}

local TableById = {} :: {[Id]: Table}
local IdByTable = {} :: {[Table]: Id}
local PathByTable = {} :: {[Table]: Path}
local RemoteTables = {} :: {[Token]: Table}
local TableReadyPromises = {} :: {[TokenName]: PromiseLight.PromiseLight<any>}

local function TriggerSignal(signal_type: SignalType, token: Token, path: Path, ...: any)
	local signals = DataSignals[token][path]
	if not signals then return end
	
	local signal = signals[signal_type]
	if signal then
		task.defer(signal.Fire, signal, ...)
	end
end

local function UnregisterValue(token: Token, parent: any, key: Key)
	local value = parent[key]
	if typeof(value) ~= "table" then return end
	
	-- Unregister the value
	local id = IdByTable[value]
	IdByTable[value] = nil
	TableById[id] = nil
	PathByTable[value] = nil
	
	local parent_path = PathByTable[parent]
	TriggerSignal("ChildRemoved", token, parent_path, value, key)
	
	for k, v in value do
		UnregisterValue(token, value, k)
	end
end

local function NewRemoteTable(token: Token, id: Id, write_end: boolean)
	if write_end then
		local root = RemoteTables[token]
		local token_name = TokenRegistry.GetTokenName(token)
		local promise = TableReadyPromises[token_name]
		promise:Resolve("Success", root)
	else
		local root = {}
		RemoteTables[token] = root

		-- Register root
		IdByTable[root] = id
		TableById[id] = root
		PathByTable[root] = ""
		DataSignals[token] = {}
	end
end

local function DestroyRemoteTable(token: Token)
	for path, signals in DataSignals[token] do
		if signals.Changed then
			signals.Changed:DisconnectAll()
		end
		if signals.ChildAdded then
			signals.ChildAdded:DisconnectAll()
		end
		if signals.ChildRemoved then
			signals.ChildRemoved:DisconnectAll()
		end
	end
	
	local root = RemoteTables[token]
	for k, v in root do
		UnregisterValue(token, root, k)
	end
	
	DataSignals[token] = nil
	RemoteTables[token] = nil
end

local function NewTable(token: Token, id: Id, key: Key, assigned_id: Id)
	local parent = TableById[id]
	local parent_path = PathByTable[parent]
	UnregisterValue(token, parent, key)
	
	local new_table = {}
	TriggerSignal("ChildAdded", token, parent_path, new_table, key)
	
	-- Register new table
	local new_table_path = AppendPath(parent_path, key)
	IdByTable[new_table] = assigned_id
	TableById[assigned_id] = new_table
	PathByTable[new_table] = new_table_path
	
	local previous_value = parent[key]
	parent[key] = new_table
	TriggerSignal("Changed", token, new_table_path, new_table, previous_value)
end

local function Set(token: Token, id: Id, key: Key, value: any)
	local parent = TableById[id]
	local parent_path = PathByTable[parent]
	UnregisterValue(token, parent, key)
	
	local value_path = AppendPath(parent_path, key)
	local previous_value = parent[key]
	parent[key] = value
	TriggerSignal("Changed", token, value_path, value, previous_value)
	
	if previous_value ~= nil then
		TriggerSignal("ChildRemoved", token, parent_path, previous_value, key)
	end
	
	if value ~= nil then
		TriggerSignal("ChildAdded", token, parent_path, value, key)
	end
end

local function Insert(token: Token, id: Id, value: any)
	local parent = TableById[id]
	local parent_path = PathByTable[parent]
	
	table.insert(parent, value)
	TriggerSignal("ChildAdded", token, parent_path, value, #parent)
end

local function InsertAt(token: Token, id: Id, index: number, value: any)
	local parent = TableById[id]
	local parent_path = PathByTable[parent]

	table.insert(parent, index, value)
	TriggerSignal("ChildAdded", token, parent_path, value, index)
end

local function Remove(token: Token, id: Id, index: number)
	local parent = TableById[id]
	local parent_path = PathByTable[parent]

	local value = table.remove(parent, index)
	TriggerSignal("ChildRemoved", token, parent_path, value, index)
end

local function SwapRemove(token: Token, id: Id, index: number)
	local parent = TableById[id]
	local parent_path = PathByTable[parent]

	local value = Util.SwapRemove(parent, index)
	TriggerSignal("ChildRemoved", token, parent_path, value, index)
end

local function Clear(token: Token, id: Id, index: number)
	local parent = TableById[id]
	local parent_path = PathByTable[parent]
	
	for k, v in parent do
		TriggerSignal("ChildRemoved", token, parent_path, v, k)
	end
	table.clear(parent)
end

local EventFunctions = {
	NewRemoteTable = NewRemoteTable,
	DestroyRemoteTable = DestroyRemoteTable,
	NewTable = NewTable,
	Set = Set,
	Insert = Insert,
	InsertAt = InsertAt,
	Remove = Remove,
	SwapRemove = SwapRemove,
	Clear = Clear,
} :: {[string]: (Token, ...any) -> ()}

Packets.SendEventStream.OnClientEvent:Connect(function(package: buffer)
	local package_len = buffer.len(package)
	local offset = 0
	
	-- Token header
	local token = buffer.readu16(package, offset)
	offset += 2
	
	local deserialized
	while offset < package_len do
		local op_code = buffer.readu8(package, offset)
		offset += 1
		
		local event = OpCodes[op_code]
		
		offset, deserialized = Packets[event]:DeserializeReturnOffset(package, offset)
		EventFunctions[event](token, table.unpack(deserialized))
	end
end)

--[[
	Checks if a remote table with a specific token is ready
	@param token_name: String alias of the token
	@return boolean
]]
function Client.IsRemoteTableReady(token_name: TokenName): boolean
	if not TokenRegistry.IsTokenRegistered(token_name) then return false end
	local token = TokenRegistry.GetToken(token_name)
	return RemoteTables[token] ~= nil
end


--[[
	Returns the table if available, waits for it if not.
	@param token_name: String alias of the token
	@param timeout: Timeout in seconds. Returns nil after timing out
	@return data: Ready-only replicated table.
]]
function Client.WaitForTable(token_name: TokenName, timeout: number?): any
	local token_name = Util.SanitizeForAttributeName(token_name)
	local token = TokenRegistry.WaitForToken(token_name, timeout)
	if not token then return nil end
	if RemoteTables[token] then return RemoteTables[token] end

	local promise = TableReadyPromises[token_name]
	if promise then return select(2, promise:Await()) end

	local promise = PromiseLight.new(timeout)
	TableReadyPromises[token_name] = promise
	
	promise.PreResolve = function(status, token)
		if status == "Timeout" then
			warn("[RemoteTableLight]: WaitForTable timed out.")
		elseif status == "Cancel" then
			warn("[RemoteTableLight]: Token unregistered before connection.")
		end
		TableReadyPromises[token_name] = nil
	end

	Packets.ConnectionRequest:Fire(token)

	return select(2, promise:Await())
end

--[[
	Gets the apropriate data signal
	@param token_name: String alias of the token
	@param signal_type: "Changed" | "ChildAdded" | "ChildRemoved"
	@param path_list: A string array representing the desired path
	@return Signal: Signal that fires (new, old) data or (value, key) for child signals
]]
function Client.GetSignal(token_name: TokenName, signal_type: SignalType, path_list: {Key}): Signal.Signal<any, any>
	assert(type(path_list)=="table", "Path list must be a table.")
	assert(VALID_SIGNAL_TYPES[signal_type], "Not a valid signal type.")
	Client.WaitForTable(token_name)
	
	local token = TokenRegistry.GetToken(token_name)
	local path_string = ToPathString(path_list)
	local signals = DataSignals[token][path_string]
	if not signals then
		signals = {}
		DataSignals[token][path_string] = signals
	end
	
	local signal = signals[signal_type]
	if not signal then
		signal = Signal.new()
		signals[signal_type] = signal
	end
	
	return signal
end

--[[
	Cleans up the specified signal
	@param token_name: String alias of the token
	@param signal_type: "Changed" | "ChildAdded" | "ChildRemoved"
	@param path_list: A string array representing the desired path
]]
function Client.DestroySignal(token_name: TokenName, signal_type: SignalType, path_list: {Key})
	assert(type(path_list)=="table", "Path list must be a table.")
	assert(VALID_SIGNAL_TYPES[signal_type], "Not a valid signal type.")
	if not Client.IsRemoteTableReady(token_name) then return end
	
	local token = TokenRegistry.GetToken(token_name)
	local path_string = ToPathString(path_list)
	local signals = DataSignals[token][path_string]
	if not signals then return end
	
	if signals[signal_type] then
		signals[signal_type]:Destroy()
		signals[signal_type] = nil
	end
end

return Client