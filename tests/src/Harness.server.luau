--[[
	FastCast2 test harness (server).

	Runs the functional suite and the benchmark matrix, then publishes the
	combined JSON report to a ReplicatedStorage attribute so the run-in-roblox
	entry script can forward it to the Lune orchestrator.
]]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

if not RunService:IsRunning() then
	return
end

local RESULT_ATTRIBUTE = "FastCast2TestResults"

local function ensureTestSignal()
	if ReplicatedStorage:FindFirstChild("FastCast2TestSignal") == nil then
		local signal = Instance.new("BindableEvent")
		signal.Name = "FastCast2TestSignal"
		signal.Parent = ReplicatedStorage
	end
end

-- Safety net: a failing test may abort before its own teardown, so scrub any
-- test arenas and worker containers between cases to keep them isolated.
local function cleanupLeftovers()
	for _, child in workspace:GetChildren() do
		if string.match(child.Name, "^FastCast2TestArena") then
			child:Destroy()
		end
	end

	for _, child in ServerScriptService:GetChildren() do
		if
			string.match(child.Name, "^FastCast2TestContainers%d")
			or string.match(child.Name, "^FastCast2TestVMs%d")
		then
			child:Destroy()
		end
	end
end

local function runSuite()
	local Framework = require(script.Parent.Framework)
	local FunctionalTests = require(script.Parent.FunctionalTests)
	local Benchmarks = require(script.Parent.Benchmarks)

	ensureTestSignal()

	local tests = Framework.run(FunctionalTests(), cleanupLeftovers)

	local benchmarks = {}
	local benchmarkError = nil
	local benchmarkOk, benchmarkResult = pcall(function()
		return Benchmarks.run()
	end)

	if benchmarkOk then
		benchmarks = benchmarkResult
	else
		benchmarkError = tostring(benchmarkResult)
		warn("[FastCast2] benchmark run failed: " .. benchmarkError)
	end

	return {
		generatedAt = os.date("%Y-%m-%d %H:%M:%S"),
		runContext = if RunService:IsStudio() then "studio" else "game",
		tests = tests,
		benchmarks = benchmarks,
		benchmarkError = benchmarkError,
	}
end

local ok, result = pcall(runSuite)

local payload
if ok then
	payload = result
else
	warn("[FastCast2] suite crashed: " .. tostring(result))
	payload = {
		generatedAt = os.date("%Y-%m-%d %H:%M:%S"),
		runContext = if RunService:IsStudio() then "studio" else "game",
		tests = { passed = 0, failed = 0, total = 0, durationMs = 0, groups = {} },
		benchmarks = {},
		error = tostring(result),
	}
end

local encoded = HttpService:JSONEncode(payload)
ReplicatedStorage:SetAttribute(RESULT_ATTRIBUTE, encoded)

if payload.error then
	warn("[FastCast2] published results with errors")
else
	print(string.format(
		"[FastCast2] suite complete: %d passed, %d failed, %d benchmark case(s)",
		payload.tests.passed,
		payload.tests.failed,
		#payload.benchmarks
	))
end

-- Also emit the sentinel directly so the runner can find it even if the
-- entry script's relay is unavailable.
print("FASTCAST_SUITE_RESULTS " .. encoded)
