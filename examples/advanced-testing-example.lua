-- Advanced Testing Example
-- This demonstrates module reloading, mocking, and TDD workflows

-- Create test suites for different scenarios
local mathSuite = TestSuite.new("Advanced Math Tests")
local mockSuite = TestSuite.new("Mocking Framework Tests")
local reloadSuite = TestSuite.new("Module Reloading Tests")

-- Advanced Math Tests
mathSuite:addTest("Complex Calculation", function()
    local result = (2 + 3) * (4 - 1) / 3
    Assertions.assertEqual(result, 5, "Complex calculation should equal 5")
end)

mathSuite:addTest("Power Operation", function()
    local result = 2 ^ 3
    Assertions.assertEqual(result, 8, "2^3 should equal 8")
end)

-- Mocking Framework Tests
mockSuite:addTest("DataStore Mock", function()
    local mockDataStore = MockFramework.createMock()
    
    -- Set up mock return values
    mockDataStore:setReturnValue("GetAsync", {
        coins = 100,
        level = 5,
        experience = 1250
    })
    
    -- Test the mock
    local playerData = mockDataStore.GetAsync("player123")
    Assertions.assertNotNil(playerData, "Mock should return player data")
    Assertions.assertEqual(playerData.coins, 100, "Mock should return correct coins")
    Assertions.assertEqual(playerData.level, 5, "Mock should return correct level")
    
    -- Test mock calls
    local calls = mockDataStore:getCalls("GetAsync")
    Assertions.assertEqual(#calls, 1, "GetAsync should be called once")
    Assertions.assertEqual(calls[1].args[1], "player123", "Should call with correct player ID")
end)

mockSuite:addTest("Players Service Mock", function()
    local mockPlayers = MockFramework.createMock()
    
    mockPlayers:setReturnValue("GetPlayerByUserId", {
        Name = "TestPlayer",
        UserId = 123,
        DisplayName = "Test Display Name"
    })
    
    local player = mockPlayers.GetPlayerByUserId(123)
    Assertions.assertNotNil(player, "Mock should return a player")
    Assertions.assertEqual(player.Name, "TestPlayer", "Player name should match")
    Assertions.assertEqual(player.UserId, 123, "Player ID should match")
end)

-- Module Reloading Tests
local testModuleCode = [[
local TestModule = {}
local state = {
    count = 0,
    name = "Initial"
}

function TestModule.increment()
    state.count = state.count + 1
    return state.count
end

function TestModule.getCount()
    return state.count
end

function TestModule.getName()
    return state.name
end

function TestModule.setName(newName)
    state.name = newName
end

function TestModule.reset()
    state.count = 0
    state.name = "Initial"
end

return TestModule
]]

local moduleScript = nil

reloadSuite.beforeAll = function()
    -- Create a reloadable module
    moduleScript = ModuleReloader.createReloadableModule(testModuleCode, "TestModule")
end

reloadSuite.afterAll = function()
    -- Clean up the module
    if moduleScript and moduleScript.Parent then
        ModuleReloader.cleanupModule(moduleScript.Parent)
    end
end

reloadSuite:addTest("Module Initial State", function()
    local TestModule = require(moduleScript)
    Assertions.assertEqual(TestModule.getCount(), 0, "Module should start with count 0")
    Assertions.assertEqual(TestModule.getName(), "Initial", "Module should start with initial name")
end)

reloadSuite:addTest("Module Functionality", function()
    local TestModule = require(moduleScript)
    
    TestModule.increment()
    TestModule.increment()
    Assertions.assertEqual(TestModule.getCount(), 2, "Count should be 2 after two increments")
    
    TestModule.setName("Modified")
    Assertions.assertEqual(TestModule.getName(), "Modified", "Name should be modified")
end)

reloadSuite:addTest("Module Reload Test", function()
    -- Test current state
    local TestModule1 = require(moduleScript)
    TestModule1.increment()
    TestModule1.setName("Before Reload")
    Assertions.assertEqual(TestModule1.getCount(), 3, "Count should be 3 before reload")
    Assertions.assertEqual(TestModule1.getName(), "Before Reload", "Name should be set before reload")
    
    -- Reload with new code
    local newModuleCode = [[
local TestModule = {}
local state = {
    count = 0,
    name = "Reloaded"
}

function TestModule.increment()
    state.count = state.count + 2  -- Changed from +1 to +2
    return state.count
end

function TestModule.getCount()
    return state.count
end

function TestModule.getName()
    return state.name
end

function TestModule.setName(newName)
    state.name = newName
end

function TestModule.reset()
    state.count = 0
    state.name = "Reloaded"
end

return TestModule
]]
    
    -- Reload the module
    moduleScript = ModuleReloader.reloadModule(moduleScript, newModuleCode)
    
    -- Test the reloaded module
    local TestModule2 = require(moduleScript)
    Assertions.assertEqual(TestModule2.getCount(), 0, "Reloaded module should start fresh")
    Assertions.assertEqual(TestModule2.getName(), "Reloaded", "Reloaded module should have new default name")
    
    local result = TestModule2.increment()
    Assertions.assertEqual(result, 2, "Reloaded module should increment by 2")
    Assertions.assertEqual(TestModule2.getCount(), 2, "Count should be 2")
end)

-- Return all test suites
return {mathSuite, mockSuite, reloadSuite}
