--[[
	FastCast2 test runner.

	The single command that:
	  1. builds the test place with rojo,
	  2. runs it inside Roblox Studio with run-in-roblox,
	  3. renders the functional-test summary and benchmark table as Markdown,
	  4. uploads that report to paste.shellworks.dev and prints the URL.

	Usage (from the repository root):
	  lune run tests/run.luau
	  npm test

	Flags:
	  --no-upload   Skip the paste.shellworks.dev upload.
	  --keep        Keep the built place in ./build.
]]

local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")
local serde = require("@lune/serde")

local SENTINEL = "FASTCAST_SUITE_RESULTS"
local PASTE_ENDPOINT = "https://paste.shellworks.dev/api/pastes"

-- Resolve the repository root from this file's location rather than the cwd,
-- so the runner works from anywhere.
local function resolveRoot(): string
	local source = string.gsub(debug.info(1, "s"), "\\", "/")
	local scriptDir = string.match(source, "^(.*)/[^/]+$") or "."
	local base = string.match(scriptDir, "([^/]+)$") or scriptDir

	if base == "tests" then
		return string.match(scriptDir, "^(.*)/tests$") or "."
	end

	return scriptDir
end

local ROOT = resolveRoot()
local PROJECT_FILE = ROOT .. "/tests.project.json"
local BUILD_DIR = ROOT .. "/build"
local PLACE_FILE = BUILD_DIR .. "/FastCast2Tests.rbxlx"
local ENTRY_FILE = ROOT .. "/tests/Entry.luau"

local flags: { [string]: any } = {}
for _, value in process.args do
	local key, raw = string.match(value, "^%-%-([%w%-]+)=?(.*)$")
	if key then
		flags[key] = if raw ~= "" then raw else true
	end
end

local function fail(message: string)
	warn("[run] " .. message)
	process.exit(1)
end

local function run(program: string, args: { string })
	local ok, result = pcall(function()
		return process.exec(program, args, { cwd = ROOT })
	end)

	if not ok then
		return nil, tostring(result)
	end

	return result, nil
end

local function formatMs(value: any): string
	if type(value) ~= "number" then
		return "n/a"
	end
	return string.format("%.2f ms", value)
end

local function benchmarkTable(rows: { any }): string
	local lines = {
		"| Mode | Cast | Create | Avg frame | P95 | P99 | Cleanup |",
		"| --- | --- | --- | --- | --- | --- | --- |",
	}

	for _, row in rows do
		table.insert(
			lines,
			string.format(
				"| %s | %s | %s | %s | %s | %s | %s |",
				row.mode,
				row.castType,
				formatMs(row.creationMs),
				formatMs(row.averageFrameMs),
				formatMs(row.p95FrameMs),
				formatMs(row.p99FrameMs),
				formatMs(row.cleanupMs)
			)
		)
	end

	return table.concat(lines, "\n")
end

local function testSection(tests: any): string
	local lines = {
		string.format(
			"**%d passed, %d failed** (%d total, %.1f ms)",
			tests.passed or 0,
			tests.failed or 0,
			tests.total or 0,
			tests.durationMs or 0
		),
	}

	if (tests.failed or 0) > 0 then
		table.insert(lines, "")
		table.insert(lines, "| Group | Case | Error |")
		table.insert(lines, "| --- | --- | --- |")

		for _, group in tests.groups or {} do
			for _, case in group.cases or {} do
				if case.status ~= "passed" then
					local message = string.gsub(case.error or "unknown error", "|", "\\|")
					message = string.gsub(message, "[\r\n]+", " ")
					table.insert(
						lines,
						string.format("| %s | %s | %s |", group.name, case.name, message)
					)
				end
			end
		end
	end

	return table.concat(lines, "\n")
end

local function buildMarkdown(payload: any): string
	local tests = payload.tests or { passed = 0, failed = 0, total = 0, durationMs = 0, groups = {} }
	local benchmarks = payload.benchmarks or {}

	local parts = {
		"# FastCast2 test report",
		"",
		"Generated: " .. (payload.generatedAt or "unknown"),
		"Context: " .. (payload.runContext or "unknown"),
		"",
		"## Functional tests",
		"",
		testSection(tests),
		"",
		"## Benchmarks",
		"",
		benchmarkTable(benchmarks),
	}

	if payload.benchmarkError then
		table.insert(parts, "")
		table.insert(parts, "```")
		table.insert(parts, tostring(payload.benchmarkError))
		table.insert(parts, "```")
	end

	if payload.error then
		table.insert(parts, "")
		table.insert(parts, "## Harness error")
		table.insert(parts, "")
		table.insert(parts, "```")
		table.insert(parts, tostring(payload.error))
		table.insert(parts, "```")
	end

	return table.concat(parts, "\n") .. "\n"
end

local function parseResults(output: string): any?
	for line in string.gmatch(output, "[^\r\n]+") do
		local start = string.find(line, SENTINEL, 1, true)
		if start then
			local json = string.gsub(string.sub(line, start + #SENTINEL), "^%s+", "")
			local ok, decoded = pcall(serde.decode, "json", json)
			if ok and decoded then
				return decoded
			end
		end
	end

	return nil
end

local function upload(markdown: string): (string?, string?)
	local ok, response = pcall(function()
		return net.request({
			url = PASTE_ENDPOINT,
			method = "POST",
			headers = { ["Content-Type"] = "application/json" },
			body = serde.encode("json", {
				content = markdown,
				title = "FastCast2 test report",
				language = "markdown",
				visibility = "unlisted",
				expires_in = "2w",
			}),
		})
	end)

	if not ok then
		return nil, tostring(response)
	end

	if response.statusCode < 200 or response.statusCode >= 300 then
		return nil, string.format("HTTP %d: %s", response.statusCode, response.body)
	end

	local decoded = serde.decode("json", response.body)
	return decoded.url, nil
end

-- 1. Validate the project layout -------------------------------------------------
if not fs.isFile(PROJECT_FILE) then
	fail("could not find tests.project.json at " .. PROJECT_FILE)
end

if not fs.isFile(ENTRY_FILE) then
	fail("could not find tests/Entry.luau at " .. ENTRY_FILE)
end

-- 2. Build the place -------------------------------------------------------------
print("[run] building test place with rojo...")
if not fs.isDir(BUILD_DIR) then
	fs.writeDir(BUILD_DIR)
end

local buildResult, buildError = run("rojo", { "build", "tests.project.json", "-o", PLACE_FILE })
if not buildResult then
	fail(
		"could not run rojo (" .. buildError .. "). Install it with `rokit install` or `cargo install rojo`."
	)
end

if not buildResult.ok then
	fail("rojo build failed:\n" .. buildResult.stdout .. buildResult.stderr)
end

-- 3. Run the suite in Studio -----------------------------------------------------
print("[run] launching Roblox Studio with run-in-roblox (this can take a minute)...")

local runResult, runError = run(
	"run-in-roblox",
	{ "--place", PLACE_FILE, "--script", ENTRY_FILE }
)

if not runResult then
	fail(
		"could not run run-in-roblox ("
			.. runError
			.. "). Install it with `rokit install` or `cargo install run-in-roblox`, and make sure Roblox Studio is signed in."
	)
end

local output = (runResult.stdout or "") .. "\n" .. (runResult.stderr or "")
local payload = parseResults(output)

if not payload then
	fail(
		"no " .. SENTINEL .. " record found in run-in-roblox output.\n"
			.. string.format("run-in-roblox exited with code %s.\n", tostring(runResult.code))
			.. "---- captured output (tail) ----\n"
			.. string.sub(output, -4000)
	)
end

-- 4. Report ----------------------------------------------------------------------
local markdown = buildMarkdown(payload)
local tests = payload.tests or { passed = 0, failed = 0, total = 0, durationMs = 0, groups = {} }

print("")
print(benchmarkTable(payload.benchmarks or {}))
print("")
print(string.format("Tests: %d passed, %d failed", tests.passed or 0, tests.failed or 0))

if (tests.failed or 0) > 0 then
	for _, group in tests.groups or {} do
		for _, case in group.cases or {} do
			if case.status ~= "passed" then
				print(string.format("FAIL %s / %s: %s", group.name, case.name, case.error or "unknown error"))
			end
		end
	end
end

if payload.error then
	print("Harness error: " .. tostring(payload.error))
end

if payload.benchmarkError then
	print("Benchmark error: " .. tostring(payload.benchmarkError))
end

if flags["no-upload"] then
	print("Upload: skipped (--no-upload)")
else
	print("[run] uploading report to " .. PASTE_ENDPOINT .. "...")
	local url, uploadError = upload(markdown)
	if url then
		print("Report: " .. url)
	else
		warn("[run] upload failed: " .. tostring(uploadError))
	end
end

if not flags.keep then
	pcall(function()
		fs.removeDir(BUILD_DIR)
	end)
end

if payload.error or (tests.failed or 0) > 0 then
	process.exit(1)
end

print("OK")
