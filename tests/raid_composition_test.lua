GetBuildInfo = function()
    return "1.12.1", "5875", ""
end

dofile("advancedlogging/core.lua")

GetTime = function()
    return 2
end
ChronicleLog.timeOffset = 1000
ChronicleLog:Write("RAID_COMPOSITION", "PARTY_MEMBERS_CHANGED", 0, "")
assert(ChronicleLog.buffer[1] == "1002000|RAID_COMPOSITION|PARTY_MEMBERS_CHANGED|0|")
ChronicleLog:ClearBuffer()

local roster = {}

GetNumRaidMembers = function()
    return table.getn(roster)
end

GetRaidRosterInfo = function(index)
    local member = roster[index]
    if not member then return nil end
    return member.name, member.rank, member.subgroup
end

GetUnitGUID = function(unit)
    local index = tonumber(string.match(unit, "^raid(%d+)$"))
    local member = index and roster[index]
    return member and member.guid or nil
end

local writes = {}
ChronicleLog.Write = function(self, eventType, reason, memberCount, payload)
    table.insert(writes, {
        eventType = eventType,
        reason = reason,
        memberCount = memberCount,
        payload = payload,
    })
end

local function assertEqual(actual, expected, message)
    if actual ~= expected then
        error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

local function setRoster(members)
    roster = members
end

ChronicleLog.enabled = true
ChronicleLog:ResetRaidGroupCapture()

setRoster({
    { name = "Leader", guid = "0x001", rank = 2, subgroup = 1 },
    { name = "Member", guid = "0x002", rank = 0, subgroup = 1 },
    { name = "Assistant", guid = "0x003", rank = 1, subgroup = 2 },
})

local payload, memberCount, inRaid = ChronicleLog:BuildRaidGroupPayload()
assertEqual(payload, "0x001,1,1,2;0x002,2,1,0;0x003,3,2,1", "raid payload")
assertEqual(memberCount, 3, "raid member count")
assertEqual(inRaid, true, "raid state")

ChronicleLog:CaptureRaidGroup("RAID_ROSTER_UPDATE", false)
assertEqual(table.getn(writes), 1, "initial snapshot count")
assertEqual(writes[1].eventType, "RAID_COMPOSITION", "event type")
assertEqual(writes[1].reason, "RAID_ROSTER_UPDATE", "event reason")
assertEqual(writes[1].memberCount, 3, "written member count")
assertEqual(writes[1].payload, payload, "written payload")

ChronicleLog:CaptureRaidGroup("RAID_ROSTER_UPDATE", false)
assertEqual(table.getn(writes), 1, "duplicate snapshots are suppressed")

setRoster({
    { name = "Member", guid = "0x002", rank = 0, subgroup = 1 },
    { name = "Leader", guid = "0x001", rank = 2, subgroup = 1 },
    { name = "Assistant", guid = "0x003", rank = 1, subgroup = 2 },
})
ChronicleLog:CaptureRaidGroup("RAID_ROSTER_UPDATE", false)
assertEqual(table.getn(writes), 2, "roster-index changes are logged")
assertEqual(writes[2].payload, "0x002,1,1,0;0x001,2,1,2;0x003,3,2,1", "roster-index payload")

roster[1].rank = 1
ChronicleLog:CaptureRaidGroup("RAID_ROSTER_UPDATE", false)
assertEqual(table.getn(writes), 3, "rank changes are logged")
assertEqual(writes[3].payload, "0x002,1,1,1;0x001,2,1,2;0x003,3,2,1", "rank-change payload")

roster[1].subgroup = 3
ChronicleLog:CaptureRaidGroup("RAID_ROSTER_UPDATE", false)
assertEqual(table.getn(writes), 4, "subgroup changes are logged")
assertEqual(writes[4].payload, "0x002,1,3,1;0x001,2,1,2;0x003,3,2,1", "subgroup-change payload")

ChronicleLog:CaptureRaidGroup("ZONE_CHANGED_NEW_AREA", true)
assertEqual(table.getn(writes), 5, "forced zone snapshots are logged")
assertEqual(writes[5].reason, "ZONE_CHANGED_NEW_AREA", "zone snapshot reason")

local fullRaid = {}
for raidIndex = 1, 40 do
    fullRaid[raidIndex] = {
        name = "Member" .. raidIndex,
        guid = string.format("0x%03d", raidIndex),
        rank = 0,
        subgroup = math.floor((raidIndex - 1) / 5) + 1,
    }
end
setRoster(fullRaid)
ChronicleLog:CaptureRaidGroup("RAID_ROSTER_UPDATE", false)
assertEqual(table.getn(writes), 6, "40-player snapshot is logged")
assertEqual(writes[6].memberCount, 40, "40-player member count")
local _, separatorCount = string.gsub(writes[6].payload, ";", "")
assertEqual(separatorCount, 39, "40-player mapping count")
assertEqual(string.match(writes[6].payload, "^[^;]+"), "0x001,1,1,0", "first 40-player mapping")
assertEqual(string.match(writes[6].payload, "([^;]+)$"), "0x040,40,8,0", "last 40-player mapping")

setRoster({})
ChronicleLog:CaptureRaidGroup("PARTY_MEMBERS_CHANGED", false)
assertEqual(table.getn(writes), 7, "raid disband is logged")
assertEqual(writes[7].memberCount, 0, "disband member count")
assertEqual(writes[7].payload, "", "disband payload")

print("raid composition tests passed")
