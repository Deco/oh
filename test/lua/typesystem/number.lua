local T = require("test.helpers")
local N = T.Number
local Object = T.Object

local any = T.Any()

local all_numbers = T.Number()

local _32_to_52 = T.Number(32)
_32_to_52:Max(T.Number(52))

local _42 = T.Number(42)

test("a literal number should be contained within all numbers", function()
    assert(_42:SubsetOf(all_numbers))
end)

test("all numbers should not be contained within a literal number", function()
    assert(not all_numbers:SubsetOf(_42))
end)

test("42 should be contained within any", function()
    assert(_42:SubsetOf(any))
end)

test("any should be contained within 42", function()
    assert(any:SubsetOf(_42))
end)

test("42 should be contained within 32..52", function()
    assert(_42:SubsetOf(_32_to_52))
end)

test("32..52 should not be contained within 42", function()
    assert(not _32_to_52:SubsetOf(_42))
end)
