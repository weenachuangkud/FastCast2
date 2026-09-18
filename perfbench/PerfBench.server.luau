--[[
	FastCast2 A/B performance benchmark.

	Runs in Studio via run-in-roblox. Fires N raycasts, samples server
	Heartbeat frame times, and prints one PERFBENCH_RESULT line per case so the
	orchestrator can diff fixed-step (BindToSimulation) vs per-frame stepping.

	The simulation mode is baked into src/Config.luau at build time; this
	script only reports whatever `Config.SimulationMode` currently is.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local FastCast = require(ReplicatedStorage:WaitForChild("FastCast2"))
local FastCastConfig = require(ReplicatedStorage.FastCast2:WaitForChild("Config"))

local SENTINEL = "PERFBENCH_RESULT"
local SAMPLE_SECONDS = 5
local WORKERS = 4
local COUNTS = { 6000 }
local CAST_MODES = { "Parallel", "Serial" }
local INSTANCED = { true }
local MOVEMENT = { true, false }

local cosmeticContainer = Instance.new("Folder")
cosmeticContainer.Name = "PerfBenchCosmetics"
cosmeticContainer.Parent = workspace

local cosmeticTemplate = Instance.new("Part")
cosmeticTemplate.Name = "PerfBenchProjectile"
cosmeticTemplate.Size = Vector3.one
cosmeticTemplate.Anchored = true
cosmeticTemplate.CanCollide = false
cosmeticTemplate.CanQuery = false
cosmeticTemplate.CanTouch = false
cosmeticTemplate.Massless = true
cosmeticTemplate.Parent = ReplicatedStorage

local frameTimes: { number } = {}
local measuring = false

RunService.Heartbeat:Connect(function(deltaTime)
	if measuring and deltaTime > 0 then
		table.insert(frameTimes, deltaTime * 1000)
	end
end)

local function summarize(): (number, number, number, number)
	if #frameTimes == 0 then
		return 0, 0, 0, 0
	end

	local sorted = table.clone(frameTimes)
	table.sort(sorted)

	local total = 0
	for _, value in frameTimes do
		total += value
	end

	local average = total / #frameTimes
	local function percentile(fraction: number): number
		return sorted[math.max(1, math.ceil(#sorted * fraction))]
	end

	return average, percentile(0.50), percentile(0.95), percentile(0.99)
end

local behavior = FastCast.newBehavior()
behavior.MaxDistance = 1e9
behavior.Acceleration = Vector3.zero
behavior.AutoIgnoreContainer = true
behavior.HighFidelitySegmentSize = 1

local caseIndex = 0

local function runCase(castMode: string, projectileCount: number, instanced: boolean, movement: boolean)
	caseIndex += 1
	local suffix = tostring(caseIndex)

	behavior.CosmeticBulletTemplate = if instanced then cosmeticTemplate else nil
	behavior.CosmeticBulletContainer = if instanced then cosmeticContainer else nil

	local caster
	if castMode == "Parallel" then
		caster = FastCast.newParallel()
		caster:Init(
			WORKERS,
			"BulkMoveTo"
		)
	else
		caster = FastCast.new()
		caster:Init("BulkMoveTo")
	end

	caster:SetMovementModeEnabled(movement, "BulkMoveTo")

	local random = Random.new(2026)
	local creationStarted = os.clock()

	for _ = 1, projectileCount do
		local origin = Vector3.new(
			random:NextInteger(-100, 100),
			random:NextInteger(0, 100),
			random:NextInteger(-100, 100)
		)
		local direction = Vector3.new(
			random:NextNumber(-1, 1),
			random:NextNumber(-1, 1),
			random:NextNumber(-1, 1)
		)
		direction = if direction.Magnitude == 0 then Vector3.xAxis else direction.Unit

		caster:RaycastFire(origin, direction, 6, behavior)
	end

	local creationMs = (os.clock() - creationStarted) * 1000

	-- Let parallel workers create their casts before sampling.
	task.wait()
	table.clear(frameTimes)
	measuring = true
	task.wait(SAMPLE_SECONDS)
	measuring = false

	local average, p50, p95, p99 = summarize()

	local cleanupStarted = os.clock()
	caster:Destroy()
	local cleanupMs = (os.clock() - cleanupStarted) * 1000

	print(string.format(
		"%s %s|%s|%d|instanced=%s|movement=%s|create=%.1f|avg=%.2f|p50=%.2f|p95=%.2f|p99=%.2f|cleanup=%.1f",
		SENTINEL,
		FastCastConfig.SimulationMode,
		castMode,
		projectileCount,
		tostring(instanced),
		tostring(movement),
		creationMs,
		average,
		p50,
		p95,
		p99,
		cleanupMs
	))

	task.wait(2)
end

task.spawn(function()
	task.wait(2)
	print(string.format("[perfbench] mode=%s", FastCastConfig.SimulationMode))

	for _, castMode in CAST_MODES do
		for _, projectileCount in COUNTS do
			for _, instanced in INSTANCED do
				for _, movement in MOVEMENT do
					local ok, err = pcall(runCase, castMode, projectileCount, instanced, movement)
					if not ok then
						print(string.format(
							"%s %s|%s|%d|instanced=%s|movement=%s|ERROR|%s",
							SENTINEL,
							FastCastConfig.SimulationMode,
							castMode,
							projectileCount,
							tostring(instanced),
							tostring(movement),
							tostring(err)
						))
					end
				end
			end
		end
	end

	print("[perfbench] done")
	ReplicatedStorage:SetAttribute("PerfBenchDone", true)
	print(SENTINEL .. " DONE")
end)
