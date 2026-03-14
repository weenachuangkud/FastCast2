--!strict


-- Requires
local Signal = require(script.Signal)
local Task = require(script.Task)
local Types = require(script.Types)


-- Types
export type Packet<A... = (), B... = ()> = {
	Type:					"Packet",
	Id:						number,
	Name:					string,
	Reads:					{() -> any},
	Writes:					{(any) -> ()},
	ResponseTimeout:		number,
	ResponseTimeoutValue:	any,
	ResponseReads:			{() -> any},
	ResponseWrites:			{(any) -> ()},
	OnServerEvent:			Signal.Signal<(Player, A...)>,
	OnClientEvent:			Signal.Signal<A...>,
	OnServerInvoke:			nil | (player: Player, A...) -> B...,
	OnClientInvoke:			nil | (A...) -> B...,
	Response:				(self: Packet<A..., B...>, B...) -> Packet<A..., B...>,
	Fire:					(self: Packet<A..., B...>, A...) -> B...,
	FireClient:				(self: Packet<A..., B...>, player: Player, A...) -> B...,
	Serialize:				(self: Packet<A..., B...>, A...) -> (buffer, {Instance}?),
	Deserialize:			(self: Packet<A..., B...>, serializeBuffer: buffer, instances: {Instance}?) -> A...,
	DeserializeReturnOffset:(self: Packet<A..., B...>, serializeBuffer: buffer, offset: number?) -> (number, {any})
}


-- Varables
local ParametersToFunctions, TableToFunctions, ReadParameters, WriteParameters, Timeout
local RunService = game:GetService("RunService")
local PlayersService = game:GetService("Players")
local reads, writes, Import, Export, Truncate, Ended = Types.Reads, Types.Writes, Types.Import, Types.Export, Types.Truncate, Types.Ended
local ReadU8, WriteU8, ReadU16, WriteU16 = reads.NumberU8, writes.NumberU8, reads.NumberU16, writes.NumberU16
local Packet = {}			:: Packet<...any, ...any>
local packets = {}			:: {[string | number]: Packet<...any, ...any>}
local playerCursors			: {[Player]: Types.Cursor}
local playerThreads			: {[Player]: {[number]: {Yielded: thread, Timeout: thread}, Index: number}}
local threads				: {[number]: {Yielded: thread, Timeout: thread}, Index: number}
local remoteEvent			: RemoteEvent
local packetCounter			: number
local cursor = {Buffer = buffer.create(128), BufferLength = 128, BufferOffset = 0, Instances = {}, InstancesOffset = 0}


-- Constructor
local function Constructor<A..., B...>(_, name: string, ...: A...)
	local packet = packets[name] :: Packet<A..., B...>
	if packet then return packet end
	local packet = (setmetatable({}, Packet) :: any) :: Packet<A..., B...>
	packet.Name = name
	if RunService:IsServer() then
		packet.Id = packetCounter
		packet.OnServerEvent = Signal() :: Signal.Signal<(Player, A...)>
		remoteEvent:SetAttribute(name, packetCounter)
		packets[packetCounter] = packet
		packetCounter += 1
	else
		packet.Id = remoteEvent:GetAttribute(name)
		packet.OnClientEvent = Signal() :: Signal.Signal<A...>
		if packet.Id then packets[packet.Id] = packet end
	end
	packet.Reads, packet.Writes = ParametersToFunctions(table.pack(...))
	packets[packet.Name] = packet
	return packet
end


-- Packet
Packet["__index"] = Packet
Packet.Type = "Packet"

function Packet:Response(...)
	self.ResponseTimeout = self.ResponseTimeout or 10
	self.ResponseReads, self.ResponseWrites = ParametersToFunctions(table.pack(...))
	return self
end

function Packet:Fire(...)
	if self.ResponseReads then
		if RunService:IsServer() then error("You must use FireClient(player)", 2) end
		local responseThread
		for i = 1, 128 do
			responseThread = threads[threads.Index]
			if responseThread then threads.Index = (threads.Index + 1) % 128 else break end
		end
		if responseThread then error("Cannot have more than 128 yielded threads", 2) end
		Import(cursor)
		WriteU8(self.Id)
		WriteU8(threads.Index)
		threads[threads.Index] = {Yielded = coroutine.running(), Timeout = Task:Delay(self.ResponseTimeout, Timeout, threads, threads.Index, self.ResponseTimeoutValue)}
		threads.Index = (threads.Index + 1) % 128
		WriteParameters(self.Writes, {...})
		cursor = Export()
		return coroutine.yield()
	else
		Import(cursor)
		WriteU8(self.Id)
		WriteParameters(self.Writes, {...})
		cursor = Export()
	end
end

function Packet:FireClient(player, ...)
	if player.Parent == nil then return end
	if self.ResponseReads then
		local threads = playerThreads[player]
		if threads == nil then threads = {Index = 0} playerThreads[player] = threads end
		local responseThread
		for i = 1, 128 do
			responseThread = threads[threads.Index]
			if responseThread then threads.Index = (threads.Index + 1) % 128 else break end
		end
		if responseThread then error("Cannot have more than 128 yielded threads", 2) return end
		Import(playerCursors[player] or {Buffer = buffer.create(128), BufferLength = 128, BufferOffset = 0, Instances = {}, InstancesOffset = 0})
		WriteU8(self.Id)
		WriteU8(threads.Index)
		threads[threads.Index] = {Yielded = coroutine.running(), Timeout = Task:Delay(self.ResponseTimeout, Timeout, threads, threads.Index, self.ResponseTimeoutValue)}
		threads.Index = (threads.Index + 1) % 128
		WriteParameters(self.Writes, {...})
		playerCursors[player] = Export()
		return coroutine.yield()
	else
		Import(playerCursors[player] or {Buffer = buffer.create(128), BufferLength = 128, BufferOffset = 0, Instances = {}, InstancesOffset = 0})
		WriteU8(self.Id)
		WriteParameters(self.Writes, {...})
		playerCursors[player] = Export()
	end
end

function Packet:Serialize(...)
	Import({Buffer = buffer.create(128), BufferLength = 128, BufferOffset = 0, Instances = {}, InstancesOffset = 0})
	WriteParameters(self.Writes, {...})
	return Truncate()
end

function Packet:Deserialize(serializeBuffer, instances)
	Import({Buffer = serializeBuffer, BufferLength = buffer.len(serializeBuffer), BufferOffset = 0, Instances = instances or {}, InstancesOffset = 0})
	return ReadParameters(self.Reads)
end

function Packet:DeserializeReturnOffset(serializeBuffer, offset)
	Import({Buffer = serializeBuffer, BufferLength = buffer.len(serializeBuffer), BufferOffset = offset or 0, Instances = {}, InstancesOffset = 0})
	local values = table.create(#self.Reads)
	for index, func in self.Reads do values[index] = func() end
	return Export().BufferOffset, values
end


-- Functions
function ParametersToFunctions(parameters: {any})
	local readFunctions, writeFunctions = table.create(#parameters), table.create(#parameters)
	for index, parameter in ipairs(parameters) do
		if type(parameter) == "table" then
			readFunctions[index], writeFunctions[index] = TableToFunctions(parameter)
		else
			readFunctions[index], writeFunctions[index] = reads[parameter], writes[parameter]
		end
	end
	return readFunctions, writeFunctions
end

function TableToFunctions(parameters: {any})
	if #parameters == 1 then
		local parameter = parameters[1]
		local ReadFunction, WriteFunction
		if type(parameter) == "table" then
			ReadFunction, WriteFunction = TableToFunctions(parameter)
		else
			ReadFunction, WriteFunction = reads[parameter], writes[parameter]
		end
		local Read = function()
			local length = ReadU16()
			local values = table.create(length)
			for index = 1, length do values[index] = ReadFunction() end
			return values
		end
		local Write = function(values: {any})
			WriteU16(#values)
			for index, value in values do WriteFunction(value) end
		end
		return Read, Write
	else
		local keys = {} for key, value in parameters do table.insert(keys, key) end table.sort(keys)
		local readFunctions, writeFunctions = table.create(#keys), table.create(#keys)
		for index, key in keys do
			local parameter = parameters[key]
			if type(parameter) == "table" then 
				readFunctions[index], writeFunctions[index] = TableToFunctions(parameter)
			else
				readFunctions[index], writeFunctions[index] = reads[parameter], writes[parameter]
			end
		end
		local Read = function()
			local values = {}
			for index, ReadFunction in readFunctions do values[keys[index]] = ReadFunction() end
			return values
		end
		local Write = function(values: {[any]: any})
			for index, WriteFunction in writeFunctions do WriteFunction(values[keys[index]]) end
		end
		return Read, Write
	end
end

function ReadParameters(reads: {() -> any})
	local values = table.create(#reads)
	for index, func in reads do values[index] = func() end
	return table.unpack(values)
end

function WriteParameters(writes: {(any) -> ()}, values: {any})
	for index, func in writes do func(values[index]) end
end

function Timeout(threads: {[number]: {Yielded: thread, Timeout: thread}, Index: number}, threadIndex: number, value: any)
	local responseThreads = threads[threadIndex]
	task.defer(responseThreads.Yielded, value)
	threads[threadIndex] = nil
end


-- Initialize
if RunService:IsServer() then
	playerCursors = {}
	playerThreads = {}
	packetCounter = 0
	remoteEvent = Instance.new("RemoteEvent", script)

	local playerBytes = {}

	local thread = task.spawn(function()
		while true do
			coroutine.yield()
			if cursor.BufferOffset > 0 then
				local truncatedBuffer = buffer.create(cursor.BufferOffset)
				buffer.copy(truncatedBuffer, 0, cursor.Buffer, 0, cursor.BufferOffset)
				if cursor.InstancesOffset == 0 then
					remoteEvent:FireAllClients(truncatedBuffer)
				else
					remoteEvent:FireAllClients(truncatedBuffer, cursor.Instances)
					cursor.InstancesOffset = 0
					table.clear(cursor.Instances)
				end
				cursor.BufferOffset = 0
			end
			for player, cursor in playerCursors do
				local truncatedBuffer = buffer.create(cursor.BufferOffset)
				buffer.copy(truncatedBuffer, 0, cursor.Buffer, 0, cursor.BufferOffset)
				if cursor.InstancesOffset == 0 then
					remoteEvent:FireClient(player, truncatedBuffer)
				else
					remoteEvent:FireClient(player, truncatedBuffer, cursor.Instances)
				end
			end
			table.clear(playerCursors)
			table.clear(playerBytes)
		end
	end)

	local respond = function(packet: Packet, player: Player, threadIndex: number, ...)
		if packet.OnServerInvoke == nil then if RunService:IsStudio() then warn("OnServerInvoke not found for packet:", packet.Name, "discarding event:", ...) end return end
		local values = {packet.OnServerInvoke(player, ...)}
		if player.Parent == nil then return end
		Import(playerCursors[player] or {Buffer = buffer.create(128), BufferLength = 128, BufferOffset = 0, Instances = {}, InstancesOffset = 0})
		WriteU8(packet.Id)
		WriteU8(threadIndex + 128)
		WriteParameters(packet.ResponseWrites, values)
		playerCursors[player] = Export()
	end
	
	local onServerEvent = function(player: Player, receivedBuffer: buffer, instances: {Instance}?)
		local bytes = (playerBytes[player] or 0) + math.max(buffer.len(receivedBuffer), 800)
		if bytes > 8_000 then if RunService:IsStudio() then warn(player.Name, "is exceeding the data/rate limit; some events may be dropped") end return end
		playerBytes[player] = bytes
		Import({Buffer = receivedBuffer, BufferLength = buffer.len(receivedBuffer), BufferOffset = 0, Instances = instances or {}, InstancesOffset = 0})
		while Ended() == false do
			local packet = packets[ReadU8()]
			if packet.ResponseReads then
				local threadIndex = ReadU8()
				if threadIndex < 128 then
					Task:Defer(respond, packet, player, threadIndex, ReadParameters(packet.Reads))
				else
					threadIndex -= 128
					local responseThreads = playerThreads[player][threadIndex]
					if responseThreads then
						task.cancel(responseThreads.Timeout)
						task.defer(responseThreads.Yielded, ReadParameters(packet.ResponseReads))
						playerThreads[player][threadIndex] = nil
					elseif RunService:IsStudio() then
						warn("Response thread not found for packet:", packet.Name, "discarding response:", ReadParameters(packet.ResponseReads))
					else
						ReadParameters(packet.ResponseReads)
					end
				end
			else
				packet.OnServerEvent:Fire(player, ReadParameters(packet.Reads))
			end
		end
	end

	remoteEvent.OnServerEvent:Connect(function(player: Player, ...)
		local success, errorMessage: string? = pcall(onServerEvent, player, ...)
		if errorMessage and RunService:IsStudio() then warn(player.Name, errorMessage) end
	end)

	PlayersService.PlayerRemoving:Connect(function(player)
		playerCursors[player] = nil
		playerThreads[player] = nil
		playerBytes[player] = nil
	end)

	RunService.Heartbeat:Connect(function(deltaTime) task.defer(thread) end)
else
	threads = {Index = 0}
	remoteEvent = script:WaitForChild("RemoteEvent")
	local totalTime = 0

	local thread = task.spawn(function()
		while true do
			coroutine.yield()
			if cursor.BufferOffset > 0 then
				local truncatedBuffer = buffer.create(cursor.BufferOffset)
				buffer.copy(truncatedBuffer, 0, cursor.Buffer, 0, cursor.BufferOffset)
				if cursor.InstancesOffset == 0 then
					remoteEvent:FireServer(truncatedBuffer)
				else
					remoteEvent:FireServer(truncatedBuffer, cursor.Instances)
					cursor.InstancesOffset = 0
					table.clear(cursor.Instances)
				end
				cursor.BufferOffset = 0
			end
		end
	end)

	local respond = function(packet: Packet, threadIndex: number, ...)
		if packet.OnClientInvoke == nil then warn("OnClientInvoke not found for packet:", packet.Name, "discarding event:", ...) return end
		local values = {packet.OnClientInvoke(...)}
		Import(cursor)
		WriteU8(packet.Id)
		WriteU8(threadIndex + 128)
		WriteParameters(packet.ResponseWrites, values)
		cursor = Export()
	end

	remoteEvent.OnClientEvent:Connect(function(receivedBuffer: buffer, instances: {Instance}?)
		Import({Buffer = receivedBuffer, BufferLength = buffer.len(receivedBuffer), BufferOffset = 0, Instances = instances or {}, InstancesOffset = 0})
		while Ended() == false do
			local packet = packets[ReadU8()]
			if packet.ResponseReads then
				local threadIndex = ReadU8()
				if threadIndex < 128 then
					Task:Defer(respond, packet, threadIndex, ReadParameters(packet.Reads))
				else
					threadIndex -= 128
					local responseThreads = threads[threadIndex]
					if responseThreads then
						task.cancel(responseThreads.Timeout)
						task.defer(responseThreads.Yielded, ReadParameters(packet.ResponseReads))
						threads[threadIndex] = nil
					else
						warn("Response thread not found for packet:", packet.Name, "discarding response:", ReadParameters(packet.ResponseReads))
					end
				end
			else
				packet.OnClientEvent:Fire(ReadParameters(packet.Reads))
			end
		end
	end)

	remoteEvent.AttributeChanged:Connect(function(name)
		local packet = packets[name]
		if packet then
			if packet.Id then packets[packet.Id] = nil end
			packet.Id = remoteEvent:GetAttribute(name)
			if packet.Id then packets[packet.Id] = packet end
		end
	end)

	RunService.Heartbeat:Connect(function(deltaTime)
		totalTime += deltaTime
		if totalTime > 0.016666666666666666 then
			totalTime %= 0.016666666666666666
			task.defer(thread)
		end
	end)
end


return setmetatable(Types.Types, {__call = Constructor})