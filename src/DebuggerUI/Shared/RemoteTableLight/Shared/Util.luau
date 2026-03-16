--!strict
--!optimize 2

export type Id = number
export type Key = string | number
export type Path = string
export type Table = any
export type Token = number
export type TokenName = string

local Util = {}

local SEPERATOR = string.char(31)

local function DeepCopy<T>(target: T): T
	if type(target) == "table" then
		local copy = {}
		for key, value in target do
			copy[DeepCopy(key)] = DeepCopy(value)
		end
		return copy :: any
	else
		return target
	end
end

local function SanitizeForAttributeName(str)
	return (str:gsub("[^%w]", "_"))
end

local function ToPathString(path_list: {Key}): string
	return table.concat(path_list, SEPERATOR)
end

local function AppendPath(path: Path, key: Key): string
	if path == "" then
		return `{key}`
	else
		return `{path}{SEPERATOR}{key}`
	end
end

local function IsValidKeyType(value: any): boolean
	local type_ = typeof(value)
	return type_ == "string" or type_ == "number"
end

local function IsValidValueType(value: any): boolean
	return typeof(value) ~= "Instance"
end

@native
local function GetTableId(tbl: any): number
	return tonumber(tostring(tbl):sub(8)) :: number
end

@native
local function SwapRemove<V>(tbl: {V}, pos: number?): V?
	local len = #tbl
	if len == 0 or (pos and pos > len) then
		return nil
	end
	
	local pos = pos or len
	local value = tbl[pos]
	tbl[pos] = tbl[len]
	tbl[len] = nil
	return value
end

@native
local function ExpandBuffer(target: buffer): buffer
	local target_len = buffer.len(target)
	if target_len == 0 then
		target_len = 1
	end
	local expanded = buffer.create(target_len * 2) -- growth rate
	buffer.copy(expanded, 0, target)
	return expanded
end

@native
local function BufferWriteU8(target: buffer, offset: number, value: number): (buffer, number)
	local final_offset = offset + 1
	while final_offset > buffer.len(target) do
		target = ExpandBuffer(target)
	end
	buffer.writeu8(target, offset, value)
	return target, final_offset
end

@native
local function BufferWriteU16(target: buffer, offset: number, value: number): (buffer, number)
	local final_offset = offset + 2
	while final_offset > buffer.len(target) do
		target = ExpandBuffer(target)
	end
	buffer.writeu16(target, offset, value)
	return target, final_offset
end

@native
local function BufferAppend(target: buffer, offset: number, source: buffer): (buffer, number)
	local final_offset = buffer.len(source) + offset
	while final_offset > buffer.len(target) do
		target = ExpandBuffer(target)
	end
	buffer.copy(target, offset, source)
	return target, final_offset
end

@native
local function BufferTruncate(target: buffer, offset: number): buffer
	local truncated = buffer.create(offset)
	buffer.copy(truncated, 0, target, 0, offset)
	return truncated
end

Util.OpCodes = {"NewRemoteTable", "DestroyRemoteTable", "NewTable", "Set", "Insert", "InsertAt", "Remove", "SwapRemove", "Clear"}
Util.OpCodeLookup = {} :: {[string]: number}
for index, event in Util.OpCodes do
	Util.OpCodeLookup[event] = index
end
table.freeze(Util.OpCodes)
table.freeze(Util.OpCodeLookup)

Util.DeepCopy = DeepCopy
Util.SanitizeForAttributeName = SanitizeForAttributeName
Util.ToPathString = ToPathString
Util.AppendPath = AppendPath
Util.IsValidKeyType = IsValidKeyType
Util.IsValidValueType = IsValidValueType
Util.GetTableId = GetTableId
Util.SwapRemove = SwapRemove
Util.ExpandBuffer = ExpandBuffer
Util.BufferWriteU8 = BufferWriteU8
Util.BufferWriteU16 = BufferWriteU16
Util.BufferAppend = BufferAppend
Util.BufferTruncate = BufferTruncate

return Util