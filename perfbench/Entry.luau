--[[
	run-in-roblox entry for the FastCast2 perf benchmark.

	Starts Run mode so the PerfBench server script executes, then waits until
	it signals completion.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

if not RunService:IsRunning() then
	RunService:Run()
end

local deadline = os.clock() + 300
while not ReplicatedStorage:GetAttribute("PerfBenchDone") and os.clock() < deadline do
	task.wait(0.5)
end

print("PERFBENCH_ENTRY_DONE")
