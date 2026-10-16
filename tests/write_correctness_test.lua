GetBuildInfo = function()
    return "1.12.1", "5875", ""
end

dofile("advancedlogging/core.lua")

GetTime = function()
    return 2
end
ChronicleLog.timeOffset = 1000

local function resetBuffer()
    ChronicleLog.buffer = {}
    ChronicleLog.bufferSize = 0
    ChronicleLog.pendingFlush = nil
end

local function baselineLine(write)
    resetBuffer()
    write()
    assert(ChronicleLog.bufferSize == 1, "baseline should write exactly one line")
    return ChronicleLog.buffer[1]
end

local function assertEquivalent(name, baseline, fixed)
    local expected = baselineLine(baseline)
    resetBuffer()
    fixed()
    assert(ChronicleLog.bufferSize == 1, name .. " should write exactly one line")
    assert(ChronicleLog.buffer[1] == expected,
        name .. " differs: expected " .. tostring(expected) .. ", got " .. tostring(ChronicleLog.buffer[1]))
end

assertEquivalent("Write0",
    function() ChronicleLog:Write("BENCH0") end,
    function() ChronicleLog:Write0("BENCH0") end)
assertEquivalent("Write1",
    function() ChronicleLog:Write("BENCH1", "alpha") end,
    function() ChronicleLog:Write1("BENCH1", "alpha") end)
assertEquivalent("Write2",
    function() ChronicleLog:Write("BENCH2", 42, true) end,
    function() ChronicleLog:Write2("BENCH2", 42, true) end)
assertEquivalent("Write3 with middle nil",
    function() ChronicleLog:Write("BENCH", "x", nil, "z") end,
    function() ChronicleLog:Write3("BENCH", "x", nil, "z") end)
assert(ChronicleLog.buffer[1] == "1002000|BENCH|x||z", "middle nil should produce an empty field")
assertEquivalent("Write4",
    function() ChronicleLog:Write("BENCH4", "", -7, 1.25, false) end,
    function() ChronicleLog:Write4("BENCH4", "", -7, 1.25, false) end)
assertEquivalent("Write5 with trailing nil",
    function() ChronicleLog:Write("BENCH5", "a", "b", "c", "d", nil) end,
    function() ChronicleLog:Write5("BENCH5", "a", "b", "c", "d", nil) end)
assertEquivalent("Write6",
    function() ChronicleLog:Write("BENCH6", "a|b", 2, true, "", nil, "tail") end,
    function() ChronicleLog:Write6("BENCH6", "a|b", 2, true, "", nil, "tail") end)
assertEquivalent("Write7",
    function() ChronicleLog:Write("BENCH7", 1, 2, 3, 4, 5, 6, 7) end,
    function() ChronicleLog:Write7("BENCH7", 1, 2, 3, 4, 5, 6, 7) end)
assertEquivalent("Write8",
    function() ChronicleLog:Write("BENCH8", "a", "b", "c", "d", "e", "f", "g", "h") end,
    function() ChronicleLog:Write8("BENCH8", "a", "b", "c", "d", "e", "f", "g", "h") end)
assertEquivalent("Write9",
    function() ChronicleLog:Write("BENCH9", 1, "two", nil, false, 5.5, "six", "", "eight", 9) end,
    function() ChronicleLog:Write9("BENCH9", 1, "two", nil, false, 5.5, "six", "", "eight", 9) end)
assertEquivalent("Write10",
    function() ChronicleLog:Write("BENCH10", 1, 2, 3, 4, 5, 6, 7, 8, 9, 10) end,
    function() ChronicleLog:Write10("BENCH10", 1, 2, 3, 4, 5, 6, 7, 8, 9, 10) end)
assertEquivalent("Write11 with trailing nil",
    function() ChronicleLog:Write("BENCH11", 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, nil) end,
    function() ChronicleLog:Write11("BENCH11", 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, nil) end)
assertEquivalent("Write12",
    function() ChronicleLog:Write("BENCH12", "one", 2, true, nil, "five", 6.25, false, "", "nine|pipe", 10, 11, 12) end,
    function() ChronicleLog:Write12("BENCH12", "one", 2, true, nil, "five", 6.25, false, "", "nine|pipe", 10, 11, 12) end)

print("write correctness tests passed")
