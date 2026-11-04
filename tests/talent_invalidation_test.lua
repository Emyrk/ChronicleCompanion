GetBuildInfo = function()
    return "1.18.1", "7272", ""
end

strfind = string.find
strlen = string.len
strlower = string.lower

Chronicle = {
    DebugPrint = function() end,
    Print = function() end,
}
StaticPopupDialogs = {}

local now = 100
local requests = {}
local fileWrites = {}
local purgeUnitsCount = 0
local zoneWriteCount = 0
local raidCaptureCount = 0

GetTime = function()
    return now
end

time = function()
    return 1234567890
end

UnitName = function(unit)
    if unit == "player" then return "Recorder" end
    if unit == "raid1" then return "Alice" end
    return nil
end

UnitIsUnit = function(left, right)
    if left == right then return 1 end
    return nil
end

UnitIsConnected = function()
    return true
end

UnitAffectingCombat = function()
    return false
end

UnitExists = function(unit)
    if unit == "raid1" then return true, "0xALICE" end
    return nil
end

GetNumRaidMembers = function()
    return 1
end

GetNumPartyMembers = function()
    return 0
end

GetRealZoneText = function()
    return "Onyxia's Lair"
end

GetNumSavedInstances = function()
    return 0
end

SendAddonMessage = function(prefix, message, channel)
    table.insert(requests, { prefix = prefix, message = message, channel = channel })
end

ChronicleFile = {
    ReadFile = function()
        return "old log"
    end,
    WriteFile = function(self, filename, contents)
        table.insert(fileWrites, { filename = filename, contents = contents })
    end,
}

ChronicleCompanionDB = {
    advancedLog = {
        autoEnableInRaid = true,
        autoEnableInDungeon = true,
        showLogReminder = false,
        enabled = true,
    },
}
ChronicleCompanionCharDB = { lastInstanceIds = { ["onyxia's lair"] = 42 } }

dofile("util.lua")
dofile("advancedlogging/core.lua")
dofile("advancedlogging/talents.lua")

ChronicleLog.enabled = true
ChronicleLog.GetLogFilename = function()
    return "Chronicle_Recorder.txt"
end
ChronicleLog.FinishPendingFlush = function() end
ChronicleLog.PurgeUnits = function()
    purgeUnitsCount = purgeUnitsCount + 1
end
ChronicleLog.WriteZoneInfo = function()
    zoneWriteCount = zoneWriteCount + 1
end
ChronicleLog.RefreshOptionsPanel = function() end
ChronicleLog.Write5 = function() end
ChronicleLog.WriteCombatantInfo = function() end
ChronicleLog.IsInInstance = function()
    return true, "raid"
end
ChronicleLog.ScheduleRaidGroupCapture = function()
    raidCaptureCount = raidCaptureCount + 1
end

dofile("advancedlogging/config.lua")

local function assertEqual(actual, expected, message)
    if actual ~= expected then
        error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

local function completeInspection()
    for tree = 1, 3 do
        ChronicleLog:HandleTalentAddonMessage(
            "INSTalentTabInfo;" .. tree .. ";Tree" .. tree .. ";4;10",
            "Alice"
        )
        for talent = 1, 4 do
            ChronicleLog:HandleTalentAddonMessage(
                "INSTalentInfo;" .. tree .. ";" .. talent .. ";Talent;1;1;1;5;1",
                "Alice"
            )
        end
    end
    ChronicleLog:HandleTalentAddonMessage("INSTalentEND", "Alice")
    assert(ChronicleLog:GetCachedTalents("Alice") ~= "", "completed inspection should populate talent cache")
end

local function requestInspection(expectedCount, message)
    ChronicleLog:QueueTalentInspection("raid1")
    ChronicleLog:ProcessTalentQueue()
    assertEqual(table.getn(requests), expectedCount, message)
end

requestInspection(1, "initial inspection should be requested")
completeInspection()
requestInspection(1, "recent talent data should suppress duplicate inspection")

local archivedFile = ChronicleLog:ArchiveLogs("mc")
assertEqual(archivedFile, "Chronicle_Recorder_mc_1234567890.txt", "archive filename")
assertEqual(ChronicleLog:GetCachedTalents("Alice"), "", "archive should clear cached talents")
assertEqual(purgeUnitsCount, 1, "archive should purge logged units")
assertEqual(zoneWriteCount, 1, "archive should write fresh zone info")
assertEqual(raidCaptureCount, 1, "archive should schedule a fresh raid snapshot")
assertEqual(table.getn(fileWrites), 2, "archive should write backup and clear current file")
requestInspection(2, "archive should make the player immediately eligible for reinspection")
completeInspection()

ChronicleLog:DeleteLogs()
assertEqual(ChronicleLog:GetCachedTalents("Alice"), "", "delete should clear cached talents")
assertEqual(raidCaptureCount, 2, "delete should schedule a fresh raid snapshot")
requestInspection(3, "delete should make the player immediately eligible for reinspection")
completeInspection()

ChronicleLog:ZONE_CHANGED_NEW_AREA()
assertEqual(ChronicleLog:GetCachedTalents("Alice"), "", "enabled zone change should clear cached talents")
assertEqual(purgeUnitsCount, 3, "archive, delete, and zone change should each purge logged units")
assertEqual(raidCaptureCount, 3, "archive, delete, and zone change should schedule fresh raid snapshots")
requestInspection(4, "zone change should make the player immediately eligible for reinspection")

print("talent invalidation tests passed")
