local build = "5875"

GetBuildInfo = function()
    return "1.12.1", build, ""
end

dofile("util.lua")

assert(Chronicle_IsUrsolClient() == false, "native 1.12 build must not be detected as Ursol")
build = "7272"
assert(Chronicle_IsUrsolClient() == true, "build 7272 must be detected as Ursol")

-- Native clients can expose the unit-data capabilities through Nampower,
-- ClassicAPI, and SuperWoW. Only threat stays tied to the Ursol client.
build = "5875"
local fieldValues = {}
GetUnitField = function(unit, field) return fieldValues[field] end
GetUnitGUID = function() return "0xF130000000000001" end
UnitPosition = function() return 1, 2, 3, 4 end
GetRaidTargetIndex = function() return 1 end
GetTime = function() return 100 end

strfind = string.find
strlen = string.len
strlower = string.lower
strsub = string.sub

local messages = {}
Chronicle = {
    Print = function(self, message)
        table.insert(messages, message)
    end,
}

ChronicleLog = {
    events = {},
    enabled = false,
}
function ChronicleLog:CheckUnit() end
function ChronicleLog:WriteZoneInfo() end
function ChronicleLog:Enable() self.enabled = true end
function ChronicleLog:CreateOptionsPanel() end
function ChronicleLog:RefreshOptionsPanel() end

local frame
CreateFrame = function()
    frame = {}
    function frame:SetScript(name, callback)
        self[name] = callback
    end
    return frame
end

dofile("advancedlogging/ursol.lua")

local function HasEvent(name)
    for i = 1, table.getn(ChronicleLog.events) do
        if ChronicleLog.events[i] == name then return true end
    end
    return false
end

assert(ChronicleUrsol.caps.client == false, "native client must not pass the Ursol client gate")
assert(ChronicleUrsol.caps.fields == true, "Nampower fields must be detected on native clients")
assert(ChronicleUrsol.caps.position == true, "ClassicAPI positions must be detected on native clients")
assert(ChronicleUrsol.caps.marks == true, "raid marks must use provider capabilities")
assert(ChronicleUrsol:Available("unitState") == true, "unit state must be available with Nampower")
assert(ChronicleUrsol:Available("position") == true, "positions must be available with Nampower and ClassicAPI")
assert(ChronicleUrsol:Available("threat") == false, "threat must remain unavailable on native clients")
assert(ChronicleUrsol:MissingText("threat") == "needs the Ursol client", "threat must explain its client requirement")
assert(ChronicleUrsol:ThreatQueryActive() == false, "native clients must not query the Ursol threat API")
assert(HasEvent("UNIT_HEALTH_GUID"), "native clients with Nampower must register health events")
assert(HasEvent("UNIT_MANA_GUID"), "native clients with Nampower must register mana events")
assert(HasEvent("UNIT_RAGE_GUID"), "native clients with Nampower must register rage events")
assert(HasEvent("UNIT_ENERGY_GUID"), "native clients with Nampower must register energy events")
assert(HasEvent("UNIT_FLAGS_GUID"), "native clients with Nampower must register flags events")
assert(HasEvent("RAID_TARGET_UPDATE"), "native clients with GUID and mark APIs must register mark events")
assert(frame and frame.OnUpdate, "Ursol polling frame should still initialize safely")

local x, y, z, mapId = ChronicleUrsol:Position("player")
assert(x == 2 and y == 1 and z == 3 and mapId == 4, "ClassicAPI positions must normalize x and y")

fieldValues.health = 321
fieldValues.maxHealth = 654
fieldValues.bytes0 = 16777216
fieldValues.power2 = 550
fieldValues.maxPower2 = 1000
local snapshot = ChronicleUrsol:Snapshot("0xF130000000000001", "player")
assert(snapshot.hp == 321 and snapshot.maxHp == 654, "snapshot must include current and max health")
assert(snapshot.powerType == 1 and snapshot.power == 55 and snapshot.maxPower == 100,
    "snapshot must include rage on the normal 0-100 scale")
assert(snapshot.x == 2 and snapshot.y == 1 and snapshot.z == 3 and snapshot.map == 4,
    "snapshot must include normalized ClassicAPI coordinates")

UnitPosition = function() return 5, 6, 7 end
ChronicleUrsol:DetectCaps()
assert(ChronicleUrsol.positionApi == "superwow", "three-value UnitPosition must be detected as SuperWoW")
x, y, z, mapId = ChronicleUrsol:Position("player")
assert(x == 5 and y == 6 and z == 7 and mapId == nil, "SuperWoW positions must keep their coordinate order")

UnitPosition = nil
ChronicleUrsol:DetectCaps()
assert(ChronicleUrsol.caps.position == false, "positions must be unavailable without ClassicAPI or SuperWoW")
assert(ChronicleUrsol:Available("unitState") == true, "missing positions must not disable health and resources")
assert(ChronicleUrsol:MissingText("position") == "needs ClassicAPI or SuperWoW",
    "missing position providers must have a focused explanation")

local writes = 0
ChronicleUrsol.WriteUnitState = function() writes = writes + 1 end
ChronicleLog:UNIT_HEALTH_GUID("0xF130000000000002", 0, 1, 1, 0, 0, 0)
assert(writes == 0, "target or mouseover flags alone must not log an untracked unit")
ChronicleLog:UNIT_HEALTH_GUID("0xF130000000000002", 1, 0, 0, 0, 0, 0)
assert(writes == 1, "player and grouped unit events must log immediately")
ChronicleUrsol.hostiles["0xF130000000000003"] = GetTime()
ChronicleLog:UNIT_HEALTH_GUID("0xF130000000000003", 0, 0, 0, 0, 0, 0)
assert(writes == 2, "tracked hostile unit events must log immediately")

ChronicleUrsol:Status()
assert(string.find(messages[1], "client: native 1.12", 1, true),
    "native client status must report provider-based support")

build = "7272"
ChronicleUrsol:DetectCaps()
assert(ChronicleUrsol.caps.client == true, "Ursol client gate must accept build 7272")
assert(ChronicleUrsol:Available("unitState") == true, "unit data capabilities must remain available on build 7272")
assert(ChronicleUrsol:Available("threat") == true, "Ursol threat logging must be available on build 7272")

print("ursol_client_test.lua: ok")
