--[[
	FastCast2 automated benchmark matrix.

	Runs a fixed set of (mode x cast type) cases on the server and returns one
	record per case. Creation and cleanup throughput are measured with
	os.clock, while simulation cost is reported as Heartbeat frame-time
	percentiles.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local FastCast = require(ReplicatedStorage:WaitForChild("FastCast2"))

local Benchmarks = {}

Benchmarks.DefaultConfig = {
	projectileCount = 500,
	sampleDuration = 4,
	parallelWorkers = 4,
	randomSeed = 2026,
	velocity = 6,
	castTypes = { "Raycast", "Blockcast", "Spherecast" },
}

local frameTimes = {}
local isMeasuringFrames = false
local parallelCounter = 0

RunService.Heartbeat:Connect(function(deltaTime)
	if isMeasuringFrames and deltaTime > 0 then
		table.insert(frameTimes, deltaTime * 1000)
	end
end)

local function percentile(sortedValues: { number }, fraction: number): number
	if #sortedValues == 0 then
		return 0
	end
	return sortedValues[math.max(1, math.ceil(#sortedValues * fraction))]
end

local function summarizeFrames()
	if #frameTimes == 0 then
		return { frames = 0, averageMs = 0, p50Ms = 0, p95Ms = 0, p99Ms = 0 }
	end

	local sorted = table.clone(frameTimes)
	table.sort(sorted)

	local total = 0
	for _, frameTime in frameTimes do
		total += frameTime
	end

	return {
		frames = #frameTimes,
		averageMs = total / #frameTimes,
		p50Ms = percentile(sorted, 0.50),
		p95Ms = percentile(sorted, 0.95),
		p99Ms = percentile(sorted, 0.99),
	}
end

local function makeInput(random: Random): (Vector3, Vector3)
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

	if direction.Magnitude == 0 then
		direction = Vector3.xAxis
	else
		direction = direction.Unit
	end

	return origin, direction
end

local function fire(caster: any, castType: string, origin: Vector3, direction: Vector3, velocity: number, behavior: any)
	if castType == "Blockcast" then
		caster:BlockcastFire(origin, Vector3.one, direction, velocity, behavior)
	elseif castType == "Spherecast" then
		caster:SpherecastFire(origin, 0.5, direction, velocity, behavior)
	else
		caster:RaycastFire(origin, direction, velocity, behavior)
	end
end

local function createCaster(mode: string, config: any, activeCasts: { any }): any
	local caster

	if mode == "Parallel" then
		parallelCounter += 1
		caster = FastCast.newParallel()
		caster:Init(
			config.parallelWorkers,
			"BulkMoveTo"
		)
	else
		caster = FastCast.new()
		caster:Init("BulkMoveTo")
	end

	caster.CastFire = function(cast: any)
		table.insert(activeCasts, cast)
	end

	return caster
end

local function runCase(mode: string, castType: string, caster: any, activeCasts: { any }, config: any)
	local random = Random.new(config.randomSeed)
	local creationStarted = os.clock()

	for _ = 1, config.projectileCount do
		local origin, direction = makeInput(random)
		fire(caster, castType, origin, direction, config.velocity, config.behavior)
	end

	local creationSeconds = os.clock() - creationStarted

	-- Let parallel workers and CastFire callbacks finish before sampling.
	task.wait()
	table.clear(frameTimes)
	isMeasuringFrames = true
	task.wait(config.sampleDuration)
	isMeasuringFrames = false

	local frames = summarizeFrames()
	local activeCount = #activeCasts
	local cleanupStarted = os.clock()

	for index = #activeCasts, 1, -1 do
		FastCast:TerminateCast(activeCasts[index])
		activeCasts[index] = nil
	end

	local cleanupSeconds = os.clock() - cleanupStarted

	local result = {
		mode = mode,
		castType = castType,
		projectiles = config.projectileCount,
		activeCasts = activeCount,
		creationMs = creationSeconds * 1000,
		creationPerSecond = if creationSeconds > 0 then config.projectileCount / creationSeconds else 0,
		cleanupMs = cleanupSeconds * 1000,
		cleanupPerSecond = if cleanupSeconds > 0 then activeCount / cleanupSeconds else 0,
		frames = frames.frames,
		averageFrameMs = frames.averageMs,
		p50FrameMs = frames.p50Ms,
		p95FrameMs = frames.p95Ms,
		p99FrameMs = frames.p99Ms,
	}

	print(string.format(
		"[bench] %s/%s: create %.2f ms, avg %.2f ms, p95 %.2f ms, p99 %.2f ms, cleanup %.2f ms",
		mode,
		castType,
		result.creationMs,
		result.averageFrameMs,
		result.p95FrameMs,
		result.p99FrameMs,
		result.cleanupMs
	))

	task.wait(1)
	return result
end

--[=[
	Runs the full benchmark matrix.

	@param overrides any? -- Optional fields merged over DefaultConfig.
	@return { any } -- One record per (mode, cast type) case.
]=]
function Benchmarks.run(overrides: any?): { any }
	local config = table.clone(Benchmarks.DefaultConfig)
	for key, value in overrides or {} do
		config[key] = value
	end

	local behavior = FastCast.newBehavior()
	behavior.MaxDistance = 1e9
	behavior.Acceleration = Vector3.zero
	behavior.AutoIgnoreContainer = true
	config.behavior = behavior

	local results = {}

	for _, mode in { "Serial", "Parallel" } do
		local activeCasts = {}
		local caster = createCaster(mode, config, activeCasts)

		for _, castType in config.castTypes do
			table.insert(results, runCase(mode, castType, caster, activeCasts, config))
		end

		caster:Destroy()
		task.wait(1)
	end

	return results
end

return Benchmarks
