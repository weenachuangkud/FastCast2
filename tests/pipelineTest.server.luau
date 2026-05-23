--[[
	- Author: Mawin CK
]]

--[[
	FastCast2 Pipeline Test — Server-side

	Traces the actual source to test real behavior — not assumptions.
	Each scenario documents what it tests, why, and which lines of code it covers.

	Drop into ServerScriptService; runs automatically on server start.
--]]

print("Testing starting")

task.wait(5)

local FastCast = require(game:GetService("ReplicatedStorage"):WaitForChild("FastCast2"))
local RunService = game:GetService("RunService")

if not RunService:IsServer() then
	warn("Please run this script as server sided")
	return
end

-- ─── Test infrastructure ───

local PASS = 0
local FAIL = 0

local function test(name, fn)
	local ok, err = xpcall(fn, debug.traceback)
	if ok then
		PASS += 1
		print(("[PASS] %s"):format(name))
	else
		FAIL += 1
		warn(("[FAIL] %s: %s"):format(name, tostring(err)))
	end
	task.wait(0.05)
end