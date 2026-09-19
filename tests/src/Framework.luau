--[[
	FastCast2 test framework.

	A small, dependency-free assertion and runner library. Tests are grouped,
	run sequentially, and any raised error marks a case as failed. Tests may
	yield (task.wait), which is required for cast simulation timing.
]]

local Framework = {}

export type TestFunction = (expect: any) -> ()
export type TestCase = { name: string, fn: TestFunction }
export type TestGroup = { name: string, cases: { TestCase } }

local Assert = {}
Framework.Assert = Assert

local function describeValue(value: any): string
	if typeof(value) == "Instance" then
		return value:GetFullName()
	end
	return tostring(value)
end

--[=[
	@class Assert
	Assertion helpers passed to every test case as `expect`.
]=]

function Assert.truthy(condition: any, message: string?)
	if not condition then
		error(message or "expected value to be truthy", 2)
	end
end

function Assert.falsy(condition: any, message: string?)
	if condition then
		error(message or "expected value to be falsy", 2)
	end
end

function Assert.equal(actual: any, expected: any, message: string?)
	if actual ~= expected then
		error(
			string.format(
				"%s (expected %s, got %s)",
				message or "values are not equal",
				describeValue(expected),
				describeValue(actual)
			),
			2
		)
	end
end

function Assert.notEqual(actual: any, expected: any, message: string?)
	if actual == expected then
		error(
			string.format(
				"%s (did not expect %s)",
				message or "values should not be equal",
				describeValue(expected)
			),
			2
		)
	end
end

function Assert.near(actual: any, expected: any, tolerance: number?, message: string?)
	tolerance = tolerance or 1e-4

	local actualType = typeof(actual)
	if actualType ~= typeof(expected) then
		error("near() expects values of the same type", 2)
	end

	local delta
	if actualType == "Vector3" then
		delta = (actual - expected).Magnitude
	elseif actualType == "number" then
		delta = math.abs(actual - expected)
	else
		error("near() only supports numbers and Vector3", 2)
	end

	if delta > tolerance then
		error(
			string.format(
				"%s (expected %s, got %s, delta %.6f)",
				message or "values are not near",
				describeValue(expected),
				describeValue(actual),
				delta
			),
			2
		)
	end
end

function Assert.instance(value: any, className: string, message: string?)
	if typeof(value) ~= "Instance" then
		error(
			string.format(
				"%s (expected an Instance, got %s)",
				message or "value is not an Instance",
				typeof(value)
			),
			2
		)
	end

	if not value:IsA(className) then
		error(
			string.format(
				"%s (expected %s, got %s)",
				message or "instance class mismatch",
				className,
				value.ClassName
			),
			2
		)
	end
end

function Assert.greaterThan(actual: any, expected: any, message: string?)
	if typeof(actual) ~= "number" or typeof(expected) ~= "number" then
		error("greaterThan() expects numbers", 2)
	end

	if actual <= expected then
		error(
			string.format(
				"%s (expected > %s, got %s)",
				message or "value is not greater than expected",
				expected,
				actual
			),
			2
		)
	end
end

--[=[
	Builds a group of test cases.

	@param name string -- The group name.
	@param register (test: (name: string, fn: TestFunction) -> ()) -> () -- Registration callback.
	@return TestGroup
]=]
function Framework.describe(name: string, register: (test: (string, TestFunction) -> ()) -> ()): TestGroup
	local group: TestGroup = { name = name, cases = {} }

	register(function(caseName: string, fn: TestFunction)
		table.insert(group.cases, { name = caseName, fn = fn })
	end)

	return group
end

--[=[
	Returns true once `predicate` returns truthy, or false if `timeout` elapses.

	@param predicate () -> boolean
	@param timeout number? -- Seconds to wait. Defaults to 5.
	@param interval number? -- Seconds between polls. Defaults to 0.05.
	@return boolean
]=]
function Framework.waitFor(predicate: () -> boolean, timeout: number?, interval: number?): boolean
	timeout = timeout or 5
	interval = interval or 0.05
	local deadline = os.clock() + timeout

	while true do
		local ok, result = pcall(predicate)
		if ok and result then
			return true
		end

		if os.clock() >= deadline then
			return false
		end

		task.wait(interval)
	end
end

--[=[
	Runs every group and returns a JSON-serializable report. Each test gets its
	own `expect` object; resources registered through `expect.cleanup` are torn
	down after the case finishes, even when it fails.
]=]
function Framework.run(groups: { TestGroup }, afterEach: (() -> ())?)
	local report = {
		passed = 0,
		failed = 0,
		total = 0,
		durationMs = 0,
		groups = {} :: { any },
	}

	local suiteStarted = os.clock()

	for _, group in groups do
		local groupReport = {
			name = group.name,
			passed = 0,
			failed = 0,
			cases = {} :: { any },
		}

		print(string.format("[tests] %s", group.name))

		for _, case in group.cases do
			local cleanups = {}
			local expect = setmetatable({
				cleanup = function(callback: () -> ())
					table.insert(cleanups, callback)
				end,
			}, { __index = Assert })

			local caseStarted = os.clock()
			local ok, err = pcall(case.fn, expect)

			for index = #cleanups, 1, -1 do
				local cleaned, cleanupError = pcall(cleanups[index])
				if not cleaned then
					warn(string.format("  cleanup for %s failed: %s", case.name, tostring(cleanupError)))
				end
			end

			if afterEach then
				local hooked, hookError = pcall(afterEach)
				if not hooked then
					warn(string.format("  afterEach for %s failed: %s", case.name, tostring(hookError)))
				end
			end

			local durationMs = (os.clock() - caseStarted) * 1000

			local caseReport = {
				name = case.name,
				status = if ok then "passed" else "failed",
				durationMs = durationMs,
				error = if ok then nil else tostring(err),
			}

			report.total += 1
			if ok then
				report.passed += 1
				groupReport.passed += 1
				print(string.format("  ok   %s (%.1f ms)", case.name, durationMs))
			else
				report.failed += 1
				groupReport.failed += 1
				warn(string.format("  FAIL %s (%.1f ms): %s", case.name, durationMs, tostring(err)))
			end

			table.insert(groupReport.cases, caseReport)
		end

		table.insert(report.groups, groupReport)
	end

	report.durationMs = (os.clock() - suiteStarted) * 1000
	return report
end

return Framework
