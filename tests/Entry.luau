--[[
	run-in-roblox entry script.

	Starts the simulation (which boots the server harness in
	ServerScriptService), waits for its JSON report, and re-emits it with a
	stable sentinel so the Lune orchestrator can parse it from stdout.

	The report is picked up either from the ReplicatedStorage attribute the
	harness sets or, as a fallback, from the sentinel the harness prints.
]]

local HttpService = game:GetService("HttpService")
local LogService = game:GetService("LogService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RESULT_ATTRIBUTE = "FastCast2TestResults"
local SENTINEL = "FASTCAST_SUITE_RESULTS"
local TIMEOUT_SECONDS = 600

local function extract(message: string): string?
	local start = string.find(message, SENTINEL, 1, true)
	if not start then
		return nil
	end

	local candidate = string.gsub(string.sub(message, start + #SENTINEL), "^%s+", "")

	-- Ignore log-relayed copies that were truncated in transit.
	local ok = pcall(HttpService.JSONDecode, HttpService, candidate)
	if not ok then
		return nil
	end

	return candidate
end

if not RunService:IsRunning() then
	RunService:Run()
end

local encoded = ReplicatedStorage:GetAttribute(RESULT_ATTRIBUTE)

local attributeConnection = ReplicatedStorage:GetAttributeChangedSignal(RESULT_ATTRIBUTE):Connect(function()
	if encoded == nil then
		encoded = ReplicatedStorage:GetAttribute(RESULT_ATTRIBUTE)
	end
end)

local logConnection = LogService.MessageOut:Connect(function(message)
	if encoded == nil then
		encoded = extract(message)
	end
end)

local deadline = os.clock() + TIMEOUT_SECONDS
while encoded == nil and os.clock() < deadline do
	task.wait(0.25)
	encoded = encoded or ReplicatedStorage:GetAttribute(RESULT_ATTRIBUTE)
end

attributeConnection:Disconnect()
logConnection:Disconnect()

assert(encoded ~= nil, "Timed out waiting for the FastCast2 test harness")

print(SENTINEL .. " " .. encoded)
