-- Run from the repository root: lune run tests/hotpaths/run.luau [baseline-directory]
-- The optional directory contains the pre-change SerialSimulation.luau.
-- Hooks are injected into disposable build copies, never the public API.
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local build = "build/hotpaths"
fs.writeDir(build)
local modules = { ["$path"] = "../../src" }
local function instrument(name, path, simulation)
	local source = fs.readFile(path)
	local peek = if string.find(source, "local eventMetadata", 1, true)
		then "local o = (i-1)*EVENT_STRIDE; return buffer.readf64(eventMetadata,o), buffer.readu8(eventMetadata,o+8), argsPool[i]"
		else "local e = queuedEvents[i]; return e[1], e[2], e[3]"
	local hooks = simulation
		.. [[._Test = {
		Step = UpdateCasts,
		Queue = QueueEvent,
		Flush = FireQueuedEvents,
		Reset = function() ResetPools(); queuedEventsCount = 0 end,
		Peek = function(i) ]]
		.. peek
		.. [[ end,
	}
	return ]]
		.. simulation
	local result, replacements = string.gsub(source, "return " .. simulation .. "%s*$", function()
		return hooks
	end)
	assert(replacements == 1, "simulation return not found")
	fs.writeFile(build .. "/" .. name .. ".luau", result)
	modules[name] = { ["$path"] = name .. ".luau" }
end
instrument("Optimized", "src/SerialSimulation.luau", "SerialSimulation")
instrument("Parallel", "src/ParallelSimulation.luau", "ParallelSimulation")
if process.args[1] then
	instrument("Baseline", process.args[1] .. "/SerialSimulation.luau", "SerialSimulation")
end
fs.writeFile(
	build .. "/default.project.json",
	serde.encode("json", {
		name = "FastCastHotPaths",
		tree = {
			["$className"] = "DataModel",
			ReplicatedStorage = { Modules = modules },
			ServerScriptService = { HotPaths = { ["$path"] = "../../tests/hotpaths/Harness.server.luau" } },
		},
	})
)
local function run(command, args)
	local result = process.exec(command, args)
	local output = result.stdout .. "\n" .. result.stderr
	print(output)
	-- Studio plugins can make run-in-roblox exit nonzero even when the
	-- isolated harness succeeds. Its explicit sentinel is authoritative,
	-- as in tests/run.luau; missing or failing sentinels still fail below.
	if not result.ok and not (command == "run-in-roblox" and string.find(output, "HOTPATH_PASS", 1, true)) then
		warn(result.stderr)
		process.exit(1)
	end
	return output
end
run("rojo", { "build", build .. "/default.project.json", "-o", build .. "/test.rbxlx" })
local output = run("run-in-roblox", { "--place", build .. "/test.rbxlx", "--script", "tests/hotpaths/Entry.luau" })
if not string.find(output, "HOTPATH_PASS", 1, true) then
	warn("hot path tests failed or timed out")
	process.exit(1)
end
