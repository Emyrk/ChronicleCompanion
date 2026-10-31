-- Lua 5.0.3: addon-only IPC and data-loss boundary regression tests.
local files, writes, fail, frames = {}, {}, {}, {}
local now = 1000
time = function() return now end
UnitName = function() return "Tester" end
GetRealmName = function() return "Realm" end
CreateFrame = function()
    local frame = {}
    function frame:SetScript(name, callback) self[name] = callback end
    table.insert(frames, frame)
    return frame
end
StaticPopupDialogs = {}
ChronicleCompanionDB = {}
ChronicleCompanionCharDB = { lastInstanceIds = { old = true } }
Chronicle = { Print = function() end }
WriteCustomFile = function(name, content, mode)
    if fail[name] == "throw" then error("disk full") end
    if fail[name] == "false" then return false end
    if fail[name] == "ignore_clear" and content == "" then return end
    writes[name] = (writes[name] or 0) + 1
    if mode == "a" then files[name] = (files[name] or "") .. content else files[name] = content end
end
ReadCustomFile = function(name)
    if fail[name] == "read" then error("read failed") end
    if fail[name] == "corrupt" then return "corrupt" end
    return files[name]
end
CustomFileExists = function(name) return files[name] ~= nil end
ChronicleLog = { buffer = {}, bufferSize = 0 }
function ChronicleLog:GetLogFilename() return "Chronicle_Tester.txt" end
function ChronicleLog:GenerateHeader() return "HEADER" end
function ChronicleLog:ClearBuffer() self.buffer = {}; self.bufferSize = 0 end
function ChronicleLog:PurgeUnits() self.unitsPurged = true end
function ChronicleLog:PurgeTalentCache() self.talentsPurged = true end
function ChronicleLog:WriteZoneInfo() self.zoneWritten = true end
function ChronicleLog:RefreshOptionsPanel() end
function ChronicleLog:ResetRaidGroupCapture() self.raidReset = true end
function ChronicleLog:ScheduleRaidGroupCapture() self.raidScheduled = true end
ChronicleUrsol = { Reset = function(self) self.wasReset = true end }
dofile("file.lua")
dofile("advancedlogging/config.lua")
dofile("sidekick.lua")
local sk = ChronicleSidekick
sk:LoadPending()
local function reset()
    files, writes, fail = {}, {}, {}
    ChronicleLog.buffer = { "3|BUFFER" }; ChronicleLog.bufferSize = 1
    ChronicleLog.pendingFlush = { filename = "Chronicle_Tester.txt", lines = { "1|DONE", "2|PENDING" }, pos = 2, n = 2 }
    ChronicleLog.unitsPurged, ChronicleLog.talentsPurged, ChronicleLog.zoneWritten = nil, nil, nil
    ChronicleUrsol.wasReset = nil
    files["Chronicle_Tester.txt"] = "0|HEADER\n1|DONE\n"
    ChronicleCompanionDB.sidekickPending = {}; sk:LoadPending()
end

local snapshot = "SIDEKICK\t1\t0.1.0\t1000\tready\t\n"
    .. "REQUEST\told\tChronicleUpload_old.txt\tprocessing\t900\t999\tAnalyzing\n"
    .. "INSTANCE\told\t123\tMolten Core\thttps://chronicleclassic.com/instance/123\n"
    .. "INSTANCE\told\t456\tBlackwing Lair\thttps://chronicleclassic.com/instance/456\n"
local parsed = sk:ParseStatus(snapshot)
assert(parsed and parsed.requests[1].state == "processing")
assert(table.getn(parsed.requests[1].instances) == 2, "multiple instance URLs must belong to one log")
assert(parsed.requests[1].instances[1].state == nil, "instances do not have processing states")
assert(not sk:ParseStatus(string.sub(snapshot, 1, -2)), "partial status must be ignored")
assert(not sk:ParseStatus("SIDEKICK\t2\t0.1\t1000\tready\t\n"), "unknown protocol must be ignored")
assert(not sk:ParseStatus(snapshot .. "GARBAGE\n"))
assert(not sk:ParseStatus(string.gsub(snapshot, "https://", "javascript:", 1)))
files["ChronicleSidekick.status"] = snapshot; sk:Poll()
assert(sk:Ready())
files["ChronicleSidekick.status"] = "partial"; sk:Poll()
assert(sk.status.requests[1].id == "old", "malformed replacement must preserve good state")
now = 1021; assert(not sk:Ready(), "stale status must go offline")
now = 990; assert(not sk:Ready(), "future heartbeat must not be accepted")
now = 1000

reset()
local archive = sk:Archive("test")
assert(archive == "ChronicleUpload_test.txt")
assert(files[archive] == "0|HEADER\n1|DONE\n2|PENDING\n0|HEADER\n3|BUFFER\n")
assert(files["Chronicle_Tester.txt"] == "")
assert(ChronicleLog.bufferSize == 0 and ChronicleLog.pendingFlush == nil)
assert(ChronicleLog.unitsPurged and ChronicleLog.talentsPurged and ChronicleUrsol.wasReset and ChronicleLog.zoneWritten)
assert(not ChronicleCompanionCharDB.lastInstanceIds.old)
assert(ChronicleLog.raidReset and ChronicleLog.raidScheduled)
assert(sk.pending.test.filename == archive)
assert(sk:Queue(sk.pending.test, "upload"))
assert(string.find(files["ChronicleSidekick.requests"], "\n1\tupload\ttest\t1000\tChronicleUpload_test.txt\n", 1, true))
local immutable = files[archive]
fail["ChronicleSidekick.requests"] = "false"
assert(not sk:Queue(sk.pending.test, "upload"))
assert(sk.pending.test.state == "failed")
fail["ChronicleSidekick.requests"] = nil
sk.status = parsed
assert(sk:Retry("test"))
assert(files[archive] == immutable and writes[archive] == 1, "retry must never rearchive or clear new logs")

for _, failure in ipairs({ "false", "throw", "corrupt" }) do
    reset(); fail["ChronicleUpload_fail.txt"] = failure
    assert(not sk:Archive("fail"))
    assert(files["Chronicle_Tester.txt"] ~= "" and ChronicleLog.bufferSize == 1 and ChronicleLog.pendingFlush)
    assert(not ChronicleLog.unitsPurged, "archive failure must not reset tracking")
end
reset(); fail["Chronicle_Tester.txt"] = "read"
assert(not sk:Archive("fail"))
assert(not files["ChronicleUpload_fail.txt"])
reset(); fail["Chronicle_Tester.txt"] = "false"
assert(not sk:Archive("fail"))
assert(files["ChronicleUpload_fail.txt"] and not sk.pending.fail)
assert(ChronicleLog.pendingFlush and ChronicleLog.bufferSize == 1, "clear failure must retain in-memory data")
reset(); fail["Chronicle_Tester.txt"] = "ignore_clear"
assert(not sk:Archive("fail"))
assert(ChronicleLog.pendingFlush and ChronicleLog.bufferSize == 1 and not sk.pending.fail)
reset(); files["ChronicleUpload_collision.txt"] = "original"
assert(not sk:Archive("collision")); assert(files["ChronicleUpload_collision.txt"] == "original")
reset(); ChronicleLog.pendingFlush.filename = "other.txt"
assert(not sk:Archive("changed"))
reset(); ChronicleLog.pendingFlush = nil; ChronicleLog.bufferSize = 0; files["Chronicle_Tester.txt"] = nil
assert(not sk:Archive("empty"))

-- A retry must not be acknowledged by an unchanged failed snapshot.
reset()
files["ChronicleSidekick.status"] = string.gsub(snapshot, "processing", "failed")
sk:Poll()
assert(sk:Retry("old"))
assert(sk.pending.old and sk.pending.old.retryAfter == 999)
sk:Poll()
assert(sk.pending.old, "old failure must not erase an unacknowledged retry")
files["ChronicleSidekick.status"] = string.gsub(snapshot, "processing", "queued")
sk:Poll()
assert(not sk.pending.old, "durable queued acknowledgment replaces local state")

-- Full upload action archives once, appends a request, and never mutates an archive.
reset()
files["ChronicleSidekick.status"] = snapshot
assert(sk:ArchiveAndUpload())
local queued
for id, request in pairs(sk.pending) do queued = request end
assert(queued and files[queued.filename])
local snapshotBytes = files[queued.filename]
ChronicleLog.buffer = { "4|NEW_SESSION" }; ChronicleLog.bufferSize = 1
assert(files[queued.filename] == snapshotBytes)
assert(writes[queued.filename] == 1)
-- Offline upload is a no-op.
now = 1050
assert(not sk:ArchiveAndUpload())
assert(ChronicleLog.bufferSize == 1)
now = 1000

-- Background polling remains bounded, with faster refresh only for visible Sidekick.
local polls = 0
sk.Poll = function() polls = polls + 1 end
sk.IsTrayVisible = function() return false end
arg1 = 2; frames[1].OnUpdate(); assert(polls == 0)
arg1 = 8; frames[1].OnUpdate(); assert(polls == 1)
sk.IsTrayVisible = function() return true end
arg1 = 2; frames[1].OnUpdate(); assert(polls == 2)
print("sidekick_test.lua: ok")
