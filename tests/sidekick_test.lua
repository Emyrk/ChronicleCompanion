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

local snapshot = "RPC\t1\t0.1.0\t1000\tready\t\n"
    .. "RESPONSE\told\tcombat_log.upload\tprocessing\t900\t999\tAnalyzing\n"
    .. "INSTANCE\told\t123\tMolten Core\thttps://chronicleclassic.com/instance/123\n"
    .. "INSTANCE\told\t456\tBlackwing Lair\thttps://chronicleclassic.com/instance/456\n"
local parsed = sk:ParseStatus(snapshot)
assert(parsed and parsed.requests[1].state == "processing")
assert(table.getn(parsed.requests[1].instances) == 2, "multiple instance URLs must belong to one log")
assert(parsed.requests[1].instances[1].state == nil, "instances do not have processing states")
assert(not sk:ParseStatus(string.sub(snapshot, 1, -2)), "partial status must be ignored")
assert(not sk:ParseStatus("RPC\t2\t0.1\t1000\tready\t\n"), "unknown protocol must be ignored")
assert(not sk:ParseStatus(snapshot .. "GARBAGE\n"))
assert(not sk:ParseStatus(string.gsub(snapshot, "https://", "javascript:", 1)))
files["ChronicleRPC.status"] = snapshot; sk:Poll()
assert(sk:Ready())
files["ChronicleRPC.status"] = "partial"; sk:Poll()
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
assert(sk:Queue(sk.pending.test, "request"))
assert(string.find(files["ChronicleRPC.requests"], "\n1\trequest\ttest\t1000\tcombat_log.upload\tChronicleUpload_test.txt\n", 1, true))
local immutable = files[archive]
fail["ChronicleRPC.requests"] = "false"
assert(not sk:Queue(sk.pending.test, "request"))
assert(sk.pending.test.state == "failed")
fail["ChronicleRPC.requests"] = nil
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
files["ChronicleRPC.status"] = string.gsub(snapshot, "processing", "failed")
sk:Poll()
assert(sk:Retry("old"))
assert(sk.pending.old and sk.pending.old.retryAfter == 999)
sk:Poll()
assert(sk.pending.old, "old failure must not erase an unacknowledged retry")
files["ChronicleRPC.status"] = string.gsub(snapshot, "processing", "queued")
sk:Poll()
assert(not sk.pending.old, "durable queued acknowledgment replaces local state")

-- Full upload action archives once, appends a request, and never mutates an archive.
reset()
files["ChronicleRPC.status"] = snapshot
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

-- Supplied Sidekick complete-status example is a compatibility fixture.
local example = "RPC\t1\t0.16.0\t1730000040\tready\t\n"
    .. "RESPONSE\tThrall_Nordanaar_1730000000_1\tcombat_log.upload\tcomplete\t1730000000\t1730000040\t\n"
    .. "INSTANCE\tThrall_Nordanaar_1730000000_1\t11111111-1111-1111-1111-111111111111\tMolten Core\thttps://chronicleclassic.com/instances/molten-core-abc\n"
    .. "INSTANCE\tThrall_Nordanaar_1730000000_1\t22222222-2222-2222-2222-222222222222\tBlackwing Lair\thttps://chronicleclassic.com/instances/blackwing-lair-def\n"
local result = sk:ParseStatus(example)
assert(result and result.requests[1].method == "combat_log.upload")
assert(result.requests[1].filename == "ChronicleUpload_Thrall_Nordanaar_1730000000_1.txt")
assert(table.getn(result.requests[1].instances) == 2)
assert(not sk:ParseStatus(string.gsub(example, "combat_log.upload", "instance.prepare")))
assert(not sk:ParseStatus(string.gsub(example, "RPC", "SIDEKICK", 1)))
assert(not sk:ParseStatus(example .. "RESPONSE\tThrall_Nordanaar_1730000000_1\tcombat_log.upload\tqueued\t1\t1\t\n"))
assert(not sk:ParseStatus("RPC\t1\t0.16.0\t1000\tready\t\nINSTANCE\tmissing\tid\tname\thttps://example.com/\n"))
assert(not sk:ParseStatus(example .. "\r\n"))
assert(not sk:ParseStatus(example .. string.rep("x", 262144)))
assert(not sk:ParseStatus(string.gsub(example, "1730000040", "nan")))
assert(not sk:ParseStatus(example .. string.char(0) .. string.char(10)))
assert(not sk:ParseStatus(string.gsub(example, "1730000040", string.rep("9", 400))))
assert(not sk:ParseStatus(string.gsub(example, "1730000040", "1.5")))
assert(not sk:ParseStatus(string.gsub(example, "Molten Core", "Bad\001Name")))
local maxID = string.rep("a", 200)
local idHeader = "RPC\t1\t0.16.0\t1000\tready\t\nRESPONSE\t"
local idTail = "\tcombat_log.upload\tqueued\t900\t1000\t\n"
assert(sk:ParseStatus(idHeader .. maxID .. idTail))
assert(not sk:ParseStatus(idHeader .. maxID .. "a" .. idTail))
assert(not sk:ParseStatus(idHeader .. "../unsafe" .. idTail))
assert(not sk:ParseStatus(idHeader .. "" .. idTail))

-- Queue validation is exact, not just a generic safe filename check.
reset()
local invalid = { id = "valid", filename = "ChronicleUpload_other.txt", created = now }
assert(not sk:Queue(invalid, "request"))
invalid.filename = "ChronicleUpload_valid.txt"
assert(not sk:Queue(invalid, "upload"))
assert(not files["ChronicleRPC.requests"])
invalid.id = maxID .. "a"; invalid.filename = "ChronicleUpload_" .. invalid.id .. ".txt"
assert(not sk:Queue(invalid, "request"))
assert(not sk:Archive("../unsafe"))
local oldUnitName, oldRealm = UnitName, GetRealmName
UnitName = function() return string.rep("x", 250) end
GetRealmName = function() return string.rep("y", 250) end
local generated = sk:NextID()
assert(string.len(generated) <= 200 and string.find(generated, "^[A-Za-z0-9_%-]+$"))
UnitName, GetRealmName = oldUnitName, oldRealm

-- RPC v1 never consumes the old wire files.
reset(); sk.status = nil
files["ChronicleSidekick.status"] = string.gsub(snapshot, "RPC", "SIDEKICK", 1)
sk:Poll(); assert(not sk.status)
files["ChronicleRPC.status"] = snapshot
sk:Poll(); assert(sk:Ready())
assert(not files["ChronicleSidekick.requests"])

-- Legacy local pending entries are recoverable by explicit user action only.
ChronicleCompanionDB.sidekickPending = {
    legacy = { id = "legacy", filename = "ChronicleUpload_legacy.txt", created = 900, state = "waiting" },
}
local beforeMigration = writes["ChronicleRPC.requests"] or 0
sk:Poll()
assert(sk.pending.legacy.state == "failed")
assert((writes["ChronicleRPC.requests"] or 0) == beforeMigration)
files["ChronicleUpload_legacy.txt"] = "archived legacy log"
assert(sk:Retry("legacy"))
assert(string.find(files["ChronicleRPC.requests"], "\n1\trequest\tlegacy\t900\tcombat_log.upload\tChronicleUpload_legacy.txt\n", 1, true))

-- A retry works after Sidekick has moved the CustomData archive. Each requested-at
-- is consumed once, so retries remain distinct across fast failures and reloads.
reset()
ChronicleCompanionDB.sidekickRetryTimes = {}
files["ChronicleRPC.status"] = string.gsub(snapshot, "processing", "failed")
sk:Poll(); assert(sk:Retry("old"))
assert(not files["ChronicleUpload_old.txt"], "managed-archive retry needs no local copy")
assert(string.find(files["ChronicleRPC.requests"], "\n1\tretry\told\t1000\tcombat_log.upload\tChronicleUpload_old.txt\n", 1, true))
-- New failure may share the same clock second as the previous retry.
files["ChronicleRPC.status"] = string.gsub(files["ChronicleRPC.status"], "999", "1000")
sk:Poll(); assert(not sk.pending.old)
local savedDB = ChronicleCompanionDB
dofile("sidekick.lua"); sk = ChronicleSidekick
assert(ChronicleCompanionDB == savedDB)
sk:Poll(); assert(sk:Retry("old"))
assert(ChronicleCompanionDB.sidekickRetryTimes.old == 1001)
assert(string.find(files["ChronicleRPC.requests"], "\n1\tretry\told\t1001\tcombat_log.upload\tChronicleUpload_old.txt\n", 1, true))
assert(writes["Chronicle_Tester.txt"] == nil, "retry must not reset active log")
files["ChronicleRPC.status"] = string.gsub(string.gsub(snapshot, "processing", "failed"), "ready\t", "sign_in_required\t")
sk:Poll(); assert(not sk:Ready())
local priorWrites = writes["ChronicleRPC.requests"]
assert(not sk:Retry("old")); assert(writes["ChronicleRPC.requests"] == priorWrites)
-- No acknowledgement: keep the pending entry, even when bounded history omits it.
files["ChronicleRPC.status"] = "RPC\t1\t0.16.0\t1000\tready\t\n"
sk:Poll(); assert(sk.pending.old)

-- A broken/stuck existence probe must not lock the game or touch the log.
reset()
files["ChronicleRPC.status"] = snapshot
local originalExists = CustomFileExists
local probes = 0
CustomFileExists = function() probes = probes + 1; return true end
assert(not sk:ArchiveAndUpload())
assert(probes == 32, "archive-name allocation must have a hard bound")
assert(files["Chronicle_Tester.txt"] ~= "" and ChronicleLog.bufferSize == 1)
assert(not files["ChronicleRPC.requests"] and not sk.uploadBusy)
assert(string.find(files["ChronicleRPC.debug"], "32 checks", 1, true))
CustomFileExists = originalExists
for _, invalidSequence in ipairs({ 9007199254740992, 1 / 0, -1, 1.5, "broken" }) do
    ChronicleCompanionDB.sidekickSequence = invalidSequence
    assert(not sk:NextID(), "invalid sequence must fail closed, not loop")
end
ChronicleCompanionDB.sidekickSequence = 0 / 0
assert(not sk:NextID(), "NaN sequence must fail closed")
ChronicleCompanionDB.sidekickSequence = 0
sk.uploadBusy = true
assert(not sk:ArchiveAndUpload(), "reentrant uploads must be ignored")
sk.uploadBusy = nil
reset(); files["ChronicleRPC.status"] = snapshot
assert(sk:ArchiveAndUpload())
assert(string.find(files["ChronicleRPC.debug"], "complete: request queued", 1, true))
assert(not sk.trace and not sk.uploadBusy)

-- Background polling remains bounded, with faster refresh only for visible Sidekick.
local polls = 0
sk.Poll = function() polls = polls + 1 end
sk.IsTrayVisible = function() return false end
arg1 = 2; frames[table.getn(frames)].OnUpdate(); assert(polls == 0)
arg1 = 8; frames[table.getn(frames)].OnUpdate(); assert(polls == 1)
sk.IsTrayVisible = function() return true end
arg1 = 2; frames[table.getn(frames)].OnUpdate(); assert(polls == 2)
print("sidekick_test.lua: ok")
