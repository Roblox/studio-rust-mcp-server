-- Basic Unit Testing Example
-- This file demonstrates how to use the unit testing framework
-- Run this with: "Create unit tests for basic math operations"

-- Create a test suite for basic math operations
local suite = TestSuite.new("Basic Math Operations")

-- Test addition
suite:addTest("Addition Test", function()
    local result = 2 + 2
    Assertions.assertEqual(result, 4, "2 + 2 should equal 4")
end)

-- Test subtraction
suite:addTest("Subtraction Test", function()
    local result = 10 - 3
    Assertions.assertEqual(result, 7, "10 - 3 should equal 7")
end)

-- Test multiplication
suite:addTest("Multiplication Test", function()
    local result = 4 * 5
    Assertions.assertEqual(result, 20, "4 * 5 should equal 20")
end)

-- Test division
suite:addTest("Division Test", function()
    local result = 15 / 3
    Assertions.assertEqual(result, 5, "15 / 3 should equal 5")
end)

-- Test edge cases
suite:addTest("Division by Zero", function()
    Assertions.assertThrows(function()
        local result = 10 / 0
    end, "inf", "Division by zero should produce infinity")
end)

-- Test with negative numbers
suite:addTest("Negative Number Addition", function()
    local result = -5 + 3
    Assertions.assertEqual(result, -2, "-5 + 3 should equal -2")
end)

-- Add setup and teardown
suite.beforeAll = function()
    print("Starting basic math tests...")
end

suite.afterAll = function()
    print("Basic math tests completed!")
end

-- Return the test suite
return {suite}
