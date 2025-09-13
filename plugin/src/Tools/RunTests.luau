local Main = script:FindFirstAncestor("MCPStudioPlugin")
local Types = require(Main.Types)

local ServerStorage = game:GetService("ServerStorage")

-- Test result structure
local TestResult = {}
TestResult.__index = TestResult

function TestResult.new(testName: string, success: boolean, message: string?, duration: number?)
	return setmetatable({
		testName = testName,
		success = success,
		message = message or "",
		duration = duration or 0,
		timestamp = os.time(),
	}, TestResult)
end

function TestResult:__tostring(): string
	local status = if self.success then "PASS" else "FAIL"
	return string.format("[%s] %s - %s (%.3fs)", status, self.testName, self.message, self.duration)
end

-- Test suite structure
local TestSuite = {}
TestSuite.__index = TestSuite

function TestSuite.new(suiteName: string)
	return setmetatable({
		name = suiteName,
		tests = {},
		beforeAll = nil,
		afterAll = nil,
		beforeEach = nil,
		afterEach = nil,
	}, TestSuite)
end

function TestSuite:addTest(testName: string, testFunction: () -> (), timeout: number?)
	table.insert(self.tests, {
		name = testName,
		func = testFunction,
		timeout = timeout or 5,
	})
end

function TestSuite:run(): { TestResult }
	local results = {}

	-- Run beforeAll if exists
	if self.beforeAll then
		local success, err = pcall(self.beforeAll)
		if not success then
			table.insert(results, TestResult.new("beforeAll", false, "beforeAll failed: " .. tostring(err)))
			return results
		end
	end

	-- Run each test
	for _, test in self.tests do
		local startTime = tick()

		-- Run beforeEach if exists
		local shouldSkip = false
		if self.beforeEach then
			local success, err = pcall(self.beforeEach)
			if not success then
				table.insert(
					results,
					TestResult.new(test.name, false, "beforeEach failed: " .. tostring(err), tick() - startTime)
				)
				shouldSkip = true
			end
		end

		-- Run the actual test only if beforeEach didn't fail
		if not shouldSkip then
			local success, err = pcall(function()
				-- Set up timeout
				local testThread = coroutine.create(test.func)
				local completed = false

				spawn(function()
					local success, err = coroutine.resume(testThread)
					completed = true
					if not success then
						error(err)
					end
				end)

				-- Wait for completion or timeout
				local startWait = tick()
				while not completed and (tick() - startWait) < test.timeout do
					wait(0.1)
				end

				if not completed then
					error("Test timed out after " .. test.timeout .. " seconds")
				end
			end)

			local duration = tick() - startTime

			-- Run afterEach if exists
			if self.afterEach then
				pcall(self.afterEach)
			end

			table.insert(
				results,
				TestResult.new(test.name, success, success and "Test passed" or tostring(err), duration)
			)
		end
	end

	-- Run afterAll if exists
	if self.afterAll then
		pcall(self.afterAll)
	end

	return results
end

-- Mock framework
local MockFramework = {}

function MockFramework.createMock(originalTable: { [any]: any }?)
	local mock = {}
	local calls = {}
	local returnValues = {}

	local function createMockFunction(name: string)
		return function(...)
			local args = table.pack(...)
			table.insert(calls, {
				name = name,
				args = args,
				timestamp = os.time(),
			})

			-- Check if we have a predefined return value
			if returnValues[name] then
				return table.unpack(returnValues[name])
			end

			-- If original function exists, call it
			if originalTable and originalTable[name] and type(originalTable[name]) == "function" then
				return originalTable[name](...)
			end

			return nil
		end
	end

	-- Create proxy table
	local proxy = setmetatable({}, {
		__index = function(_, key)
			if mock[key] then
				return mock[key]
			end
			return createMockFunction(tostring(key))
		end,
		__newindex = function(_, key, value)
			mock[key] = value
		end,
	})

	-- Add mock methods
	function proxy:setReturnValue(name: string, ...)
		returnValues[name] = table.pack(...)
	end

	function proxy:getCalls(name: string?)
		if name then
			local filtered = {}
			for _, call in calls do
				if call.name == name then
					table.insert(filtered, call)
				end
			end
			return filtered
		end
		return calls
	end

	function proxy:reset()
		calls = {}
		returnValues = {}
	end

	return proxy
end

-- Assertion framework
local Assertions = {}

function Assertions.assertEqual(actual: any, expected: any, message: string?)
	if actual ~= expected then
		error(message or string.format("Expected %s, got %s", tostring(expected), tostring(actual)))
	end
end

function Assertions.assertNotEqual(actual: any, expected: any, message: string?)
	if actual == expected then
		error(message or string.format("Expected %s to not equal %s", tostring(actual), tostring(expected)))
	end
end

function Assertions.assertTrue(condition: boolean, message: string?)
	if not condition then
		error(message or "Expected condition to be true")
	end
end

function Assertions.assertFalse(condition: boolean, message: string?)
	if condition then
		error(message or "Expected condition to be false")
	end
end

function Assertions.assertNil(value: any, message: string?)
	if value ~= nil then
		error(message or string.format("Expected nil, got %s", tostring(value)))
	end
end

function Assertions.assertNotNil(value: any, message: string?)
	if value == nil then
		error(message or "Expected non-nil value")
	end
end

function Assertions.assertType(value: any, expectedType: string, message: string?)
	local actualType = type(value)
	if actualType ~= expectedType then
		error(message or string.format("Expected type %s, got %s", expectedType, actualType))
	end
end

function Assertions.assertThrows(func: () -> (), expectedError: string?, message: string?)
	local success, err = pcall(func)
	if success then
		error(message or "Expected function to throw an error")
	end
	if expectedError and not string.find(tostring(err), expectedError) then
		error(message or string.format("Expected error containing '%s', got '%s'", expectedError, tostring(err)))
	end
end

function Assertions.assertContains(table: { any }, value: any, message: string?)
	for _, v in table do
		if v == value then
			return
		end
	end
	error(message or string.format("Expected table to contain %s", tostring(value)))
end

-- Module reloader for testing
local ModuleReloader = {}

function ModuleReloader.createReloadableModule(moduleCode: string, moduleName: string): any
	local moduleContainer = Instance.new("Folder")
	moduleContainer.Name = moduleName .. "_TestContainer"
	moduleContainer.Parent = ServerStorage

	local moduleScript = Instance.new("ModuleScript")
	moduleScript.Name = moduleName
	moduleScript.Source = moduleCode
	moduleScript.Parent = moduleContainer

	return moduleScript
end

function ModuleReloader.reloadModule(moduleScript: Instance, newCode: string)
	moduleScript.Source = newCode
	-- Clear the require cache by creating a new instance
	local parent = moduleScript.Parent
	local name = moduleScript.Name
	moduleScript:Destroy()

	local newModule = Instance.new("ModuleScript")
	newModule.Name = name
	newModule.Source = newCode
	newModule.Parent = parent

	return newModule
end

function ModuleReloader.cleanupModule(moduleContainer: Instance)
	moduleContainer:Destroy()
end

-- Test runner
local TestRunner = {}

function TestRunner.runTests(testSuites: { TestSuite }): { TestResult }
	local allResults = {}
	local totalTests = 0
	local passedTests = 0
	local failedTests = 0

	for _, suite in testSuites do
		print("Running test suite: " .. suite.name)
		local suiteResults = suite:run()

		for _, result in suiteResults do
			table.insert(allResults, result)
			totalTests += 1
			if result.success then
				passedTests += 1
			else
				failedTests += 1
			end
		end
	end

	-- Print summary
	print("\n=== TEST SUMMARY ===")
	print(string.format("Total tests: %d", totalTests))
	print(string.format("Passed: %d", passedTests))
	print(string.format("Failed: %d", failedTests))
	print(string.format("Success rate: %.1f%%", totalTests > 0 and (passedTests / totalTests) * 100 or 0))

	return allResults
end

-- Main test execution function
local function runTestsWithOutput(testCode: string): string
	local output = ""

	local function addToOutput(header: string, ...)
		local strResults = table.pack(...)
		local strTable = {}
		for _, arg in strResults do
			table.insert(strTable, tostring(arg))
		end
		output ..= header .. " " .. table.concat(strTable, "\t") .. "\n"
	end

	local function executeTests()
		-- Create a test environment with all testing utilities
		local testEnv = {
			TestSuite = TestSuite,
			TestResult = TestResult,
			MockFramework = MockFramework,
			Assertions = Assertions,
			ModuleReloader = ModuleReloader,
			TestRunner = TestRunner,
			print = function(...)
				addToOutput("[TEST OUTPUT]", ...)
			end,
			warn = function(...)
				addToOutput("[TEST WARNING]", ...)
			end,
			error = function(...)
				addToOutput("[TEST ERROR]", ...)
			end,
		}

		-- Load and execute the test code
		local chunk = loadstring(testCode)
		if not chunk then
			error("Failed to load test code")
		end

		-- Set the test environment
		setfenv(chunk, testEnv)

		-- Execute the tests
		local testSuites = chunk()

		if type(testSuites) ~= "table" then
			error("Test code must return a table of TestSuites")
		end

		-- Run the tests
		local results = TestRunner.runTests(testSuites)

		-- Add detailed results to output
		addToOutput("[TEST RESULTS]", "")
		for _, result in results do
			addToOutput("", tostring(result))
		end

		return results
	end

	local ok, errorMessage = pcall(executeTests)
	if not ok then
		addToOutput("[UNEXPECTED ERROR]", errorMessage)
	end

	return output
end

local function handleRunTests(args: Types.ToolArgs): string?
	if not args["RunTests"] then
		return nil
	end

	local runTestsArgs: Types.RunTestsArgs = args["RunTests"]
	if type(runTestsArgs.testCode) ~= "string" then
		error("Missing testCode in RunTests")
	end

	return runTestsWithOutput(runTestsArgs.testCode)
end

return handleRunTests :: Types.ToolFunction