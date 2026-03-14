--!strict

local TokenRegistry = {}

local IsServer = game:GetService("RunService"):IsServer()
local IsClient = game:GetService("RunService"):IsClient()

local TokenRemote: RemoteEvent
if IsServer then
	TokenRemote = Instance.new("RemoteEvent")
	TokenRemote.Name = "TokenRemote"
	TokenRemote.Parent = script
else
	TokenRemote = script:WaitForChild("TokenRemote")
end

local Shared = script.Parent
local Util = require(Shared.Util)
local Signal = require(Shared.Zignal)
local Packets = require(Shared.Packets)
local PromiseLight = require(Shared.PromiseLight)

local SanitizeForAttributeName = Util.SanitizeForAttributeName

type Token = Util.Token
type TokenName = string

local MAX_IDS = 2^16 - 1
local TokenNames = {} :: {[Token]: TokenName}
local TokenLookup = {} :: {[TokenName]: Token}
local TokenPromises = {} :: {[TokenName]: PromiseLight.PromiseLight<Token>}

local function FindFirstGap(tbl: any)
	local gap_index = 0
	for i, _ in ipairs(tbl) do
		gap_index = i
	end
	gap_index += 1
	assert(gap_index <= MAX_IDS, "Max RemoteTable count has been exceeded: 65535")
	return gap_index
end

local function Register(name: TokenName, token: Token?): Token
	local name = SanitizeForAttributeName(name)
	local token = token or FindFirstGap(TokenNames)
	TokenNames[token] = name
	TokenLookup[name] = token

	local promise = TokenPromises[name]
	if promise then
		promise:Resolve("Success", token)
	end

	if IsServer then
		script:SetAttribute(name, token)
		TokenRemote:FireAllClients("A", name, token)
	end
	return token
end

local function Unregister(name: TokenName)
	local name = SanitizeForAttributeName(name)
	local token = TokenLookup[name]
	if token then
		TokenLookup[name] = nil
	end

	local promise = TokenPromises[name]
	if promise then
		promise:Cancel()
	end

	if IsServer then
		script:SetAttribute(name, nil)
		TokenRemote:FireAllClients("R", name)
	end
end

function TokenRegistry.IsTokenRegistered(name: TokenName): boolean
	local name = SanitizeForAttributeName(name)
	return script:GetAttribute(name) ~= nil
end

function TokenRegistry.GetToken(name: TokenName): Token
	local name = SanitizeForAttributeName(name)
	if IsServer then
		return TokenLookup[name]
	else
		return script:GetAttribute(name)
	end
end

function TokenRegistry.GetTokenName(token: Token): TokenName
	return TokenNames[token]
end

function TokenRegistry.WaitForToken(name: TokenName, timeout: number?): Token
	local name = SanitizeForAttributeName(name)
	if script:GetAttribute(name) ~= nil then
		return script:GetAttribute(name)
	end

	local promise = TokenPromises[name]
	if promise then return select(2, promise:Await()) end

	local promise = PromiseLight.new(timeout) :: any
	TokenPromises[name] = promise
	promise.PreResolve = function()
		TokenPromises[name] = nil
	end

	return select(2, promise:Await())
end

TokenRegistry.Register = Register
TokenRegistry.Unregister = Unregister

if IsClient then
	for token_name, token in script:GetAttributes() do
		Register(token_name, token)
	end
	TokenRemote.OnClientEvent:Connect(function(command: "A" | "R", token_name: TokenName, token: Token)
		if command == "A" then Register(token_name, token) end
		if command == "R" then Unregister(token_name) end
	end)
end

return TokenRegistry