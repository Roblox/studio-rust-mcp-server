# Unit Testing Framework for Roblox Studio

## Overview

The studio-rust-mcp-server now includes a comprehensive unit testing framework that solves the module reloading problem mentioned in [GitHub Issue #30](https://github.com/Roblox/studio-rust-mcp-server/issues/30). This framework enables Test-Driven Development (TDD) workflows in Roblox Studio by providing:

- **Module Reloading**: Reload modules during testing to simulate fresh state
- **Mocking Framework**: Create mocks for isolated testing
- **Assertion Library**: Comprehensive assertion methods
- **Test Suites**: Organize tests with setup/teardown hooks
- **Timeout Support**: Prevent hanging tests
- **Detailed Reporting**: Track test execution and results

## Quick Start

### Basic Test Example

```lua
-- Create a test suite
local suite = TestSuite.new("Basic Math Tests")

-- Add individual tests
suite:addTest("Addition Test", function()
    local result = 2 + 2
    Assertions.assertEqual(result, 4, "2 + 2 should equal 4")
end)

suite:addTest("Subtraction Test", function()
    local result = 5 - 3
    Assertions.assertEqual(result, 2, "5 - 3 should equal 2")
end)

-- Return the test suite
return {suite}
```

### Running Tests

Use the `run_tests` tool with your test code:

```
"Run these unit tests: [paste your test code here]"
```

## API Reference

### TestSuite

The `TestSuite` class organizes related tests with setup and teardown hooks.

#### Constructor
```lua
local suite = TestSuite.new("Suite Name")
```

#### Methods
- `suite:addTest(name, testFunction, timeout?)` - Add a test case
- `suite:run()` - Execute all tests in the suite

#### Properties
- `suite.beforeAll` - Function called once before all tests
- `suite.afterAll` - Function called once after all tests
- `suite.beforeEach` - Function called before each test
- `suite.afterEach` - Function called after each test

### Assertions

Comprehensive assertion library for test validation.

#### Equality Assertions
```lua
Assertions.assertEqual(actual, expected, message?)
Assertions.assertNotEqual(actual, expected, message?)
```

#### Boolean Assertions
```lua
Assertions.assertTrue(condition, message?)
Assertions.assertFalse(condition, message?)
```

#### Nil Assertions
```lua
Assertions.assertNil(value, message?)
Assertions.assertNotNil(value, message?)
```

#### Type Assertions
```lua
Assertions.assertType(value, expectedType, message?)
```

#### Error Assertions
```lua
Assertions.assertThrows(func, expectedError?, message?)
```

#### Collection Assertions
```lua
Assertions.assertContains(table, value, message?)
```

### Mocking Framework

Create mocks for isolated testing of components.

#### Creating Mocks
```lua
local mock = MockFramework.createMock()
local mockWithOriginal = MockFramework.createMock(originalTable)
```

#### Mock Methods
```lua
mock:setReturnValue(functionName, ...) -- Set return values
mock:getCalls(functionName?) -- Get call history
mock:reset() -- Reset call history and return values
```

#### Mock Example
```lua
local mockDataStore = MockFramework.createMock()
mockDataStore:setReturnValue("GetAsync", {coins = 100, level = 5})

local playerData = mockDataStore.GetAsync("player123")
Assertions.assertEqual(playerData.coins, 100)

local calls = mockDataStore:getCalls("GetAsync")
Assertions.assertEqual(#calls, 1)
```

### Module Reloader

Reload modules during testing to simulate fresh state.

#### Creating Reloadable Modules
```lua
local moduleScript = ModuleReloader.createReloadableModule(moduleCode, moduleName)
```

#### Reloading Modules
```lua
moduleScript = ModuleReloader.reloadModule(moduleScript, newCode)
```

#### Cleanup
```lua
ModuleReloader.cleanupModule(moduleContainer)
```

## Test-Driven Development (TDD) Workflow

### 1. Red Phase - Write Failing Tests

```lua
local suite = TestSuite.new("Calculator Tests")

suite:addTest("Calculator Addition", function()
    local calculator = require(script.Parent.Calculator)
    local result = calculator.add(2, 3)
    Assertions.assertEqual(result, 5, "Calculator should add 2 + 3 = 5")
end)

return {suite}
```

### 2. Green Phase - Write Minimal Code

```lua
-- Calculator module
local Calculator = {}

function Calculator.add(a, b)
    return a + b
end

return Calculator
```

### 3. Refactor Phase - Improve Code

```lua
-- Enhanced Calculator module
local Calculator = {}

function Calculator.add(a, b)
    if type(a) ~= "number" or type(b) ~= "number" then
        error("Arguments must be numbers")
    end
    return a + b
end

return Calculator
```

## Advanced Examples

### Testing with Module Reloading

```lua
local suite = TestSuite.new("Module Reloading Tests")

local testModuleCode = [[
local TestModule = {}
local callCount = 0

function TestModule.increment()
    callCount = callCount + 1
    return callCount
end

return TestModule
]]

local moduleScript = nil

suite.beforeAll = function()
    moduleScript = ModuleReloader.createReloadableModule(testModuleCode, "TestModule")
end

suite.afterAll = function()
    ModuleReloader.cleanupModule(moduleScript.Parent)
end

suite:addTest("Module Reload Test", function()
    local TestModule = require(moduleScript)
    TestModule.increment()
    TestModule.increment()
    Assertions.assertEqual(TestModule.getCount(), 2)
    
    -- Reload with new code
    local newCode = [[
    local TestModule = {}
    local callCount = 0
    
    function TestModule.increment()
        callCount = callCount + 2  -- Changed from +1 to +2
        return callCount
    end
    
    function TestModule.getCount()
        return callCount
    end
    
    return TestModule
    ]]
    
    moduleScript = ModuleReloader.reloadModule(moduleScript, newCode)
    
    local TestModule2 = require(moduleScript)
    local result = TestModule2.increment()
    Assertions.assertEqual(result, 2, "Should increment by 2 after reload")
end)

return {suite}
```

### Mocking Game Services

```lua
local suite = TestSuite.new("Game Service Tests")

suite:addTest("Players Service Mock", function()
    local mockPlayers = MockFramework.createMock()
    mockPlayers:setReturnValue("GetPlayerByUserId", {
        Name = "TestPlayer",
        UserId = 123
    })
    
    local player = mockPlayers.GetPlayerByUserId(123)
    Assertions.assertNotNil(player)
    Assertions.assertEqual(player.Name, "TestPlayer")
    
    local calls = mockPlayers:getCalls("GetPlayerByUserId")
    Assertions.assertEqual(#calls, 1)
    Assertions.assertEqual(calls[1].args[1], 123)
end)

return {suite}
```

### Testing with Timeouts

```lua
local suite = TestSuite.new("Timeout Tests")

suite:addTest("Quick Test", function()
    local result = 1 + 1
    Assertions.assertEqual(result, 2)
end, 1) -- 1 second timeout

suite:addTest("Slow Test", function()
    wait(0.5) -- Simulate slow operation
    local result = 2 * 2
    Assertions.assertEqual(result, 4)
end, 2) -- 2 second timeout

return {suite}
```

## Best Practices

### 1. Organize Tests by Functionality
```lua
local mathSuite = TestSuite.new("Math Functions")
local uiSuite = TestSuite.new("UI Components")
local dataSuite = TestSuite.new("Data Management")

return {mathSuite, uiSuite, dataSuite}
```

### 2. Use Descriptive Test Names
```lua
-- Good
suite:addTest("Calculator should add two positive numbers correctly", function()
    -- test code
end)

-- Bad
suite:addTest("Test 1", function()
    -- test code
end)
```

### 3. Mock External Dependencies
```lua
suite:addTest("Data Store Integration", function()
    local mockDataStore = MockFramework.createMock()
    mockDataStore:setReturnValue("GetAsync", mockData)
    
    -- Test your code with the mock
end)
```

### 4. Use Setup and Teardown Appropriately
```lua
suite.beforeEach = function()
    -- Reset state before each test
    testData = {}
end

suite.afterEach = function()
    -- Clean up after each test
    testData = nil
end
```

### 5. Test Edge Cases
```lua
suite:addTest("Division by zero should throw error", function()
    local calculator = require(script.Parent.Calculator)
    Assertions.assertThrows(function()
        calculator.divide(10, 0)
    end, "Division by zero")
end)
```

## Integration with AI Assistants

The unit testing framework integrates seamlessly with AI assistants:

### Claude Desktop
```
"Create unit tests for a player inventory system that handles adding and removing items"
```

### Cursor
```
"Write failing tests for a new chat system, then implement the code to make them pass"
```

### ChatGPT
```
"Show me examples of unit testing with module reloading in Roblox Studio"
```

## Troubleshooting

### Common Issues

1. **Tests not running**: Ensure you return a table of TestSuites
2. **Module not reloading**: Use ModuleReloader.createReloadableModule() for test modules
3. **Mocks not working**: Check that you're setting return values before calling mock functions
4. **Tests timing out**: Increase timeout values or optimize test performance

### Debug Tips

- Use `print()` statements in tests to debug issues
- Check the test output for detailed error messages
- Use `mock:getCalls()` to verify mock function calls
- Use `Assertions.assertThrows()` to test error conditions

## Conclusion

This unit testing framework solves the module reloading problem mentioned in GitHub Issue #30 by providing:

- **Module Reloading**: Fresh module state for each test
- **Comprehensive Testing**: Full TDD workflow support
- **AI Integration**: Seamless integration with AI assistants
- **Production Ready**: Robust error handling and reporting

The framework enables true Test-Driven Development workflows in Roblox Studio, making it possible to write, test, and refactor code iteratively with AI assistance.
