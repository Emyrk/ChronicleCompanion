-- =============================================================================
-- ChronicleLog Ursol extensions
--
-- Extra log lines for deeper raid analysis on 1.12 clients, named after the
-- TurtleWoW 1.18.1 "Ursol" client used by the servers that came from it
-- (OctoWoW, Capybara, Ravencraft, ...). Each line type only runs when the client
-- has what it needs (see CAPS below): a plain 1.12 client with Nampower logs
-- what it can and never errors on the rest.
--
--   UNIT_STATE      health, power (with its type) and position of a unit, in one line
--   UNIT_TARGET    target of the hostile units in combat (who is tanking)
--   UNIT_COMBAT    a hostile unit enters / leaves combat (pulls, resets, evades)
--   RAID_MARK      raid target icons
--   THREAT         server threat table of a mob (TWThreat server API)
--   THREAT_TANK    "mobs I am tanking" table (TWThreat tank mode API)
--
-- Every line uses the usual TIMESTAMP|EVENT|field|... layout with event names
-- Chronicle does not know: Chronicle skips them, the separate analysis tool
-- reads them. Field order of existing events is never changed.
-- See URSOL_EVENTS.md for the format of each line.
--
-- Requirements, per line type:
--   UNIT_STATE, UNIT_TARGET, UNIT_COMBAT   Nampower GetUnitField (+ *_GUID events)
--   positions in UNIT_STATE                ClassicAPI or SuperWoW UnitPosition
--   RAID_MARK                              GetRaidTargetIndex + a GUID source
--                                          (Nampower GetUnitGUID or SuperWoW)
--   THREAT, THREAT_TANK                    a server with the TWThreat API; requests
--                                          stop by themselves when nobody answers
-- Lua 5.0 syntax only.
-- =============================================================================

local Ursol = {
    formatVersion = 2,
    hostiles = {},      -- [guid] = GetTime() of the last combat event involving it
    lastData = {},      -- [guid] = last UNIT_STATE written { hp, maxHp, power, maxPower, powerType, map, x, y, z }
    dirty = {},         -- [guid] = unit token or GUID to snapshot at the end of the frame
    lastTarget = {},    -- [guid] = last logged target guid
    inCombat = {},      -- [guid] = GetTime() of the last check that saw it in combat
    marks = {},         -- [guid] = raid icon index
    missingMarks = {},  -- [guid] = consecutive scans the mark was not seen in
    markScanAt = nil,   -- pending scan after RAID_TARGET_UPDATE
    lastThreat = {},    -- [mobGuid] = { list, time }
    caps = {},          -- what this client provides, see DetectCaps
    threatServer = nil, -- true once the server (or a group relay) answered a threat request
    threatUnanswered = 0, -- requests sent since the last answer
    lastQuery = 0,
    lastTargetPoll = 0,
    lastPosPoll = 0,
    lastMarkPoll = 0,
    lastCleanup = 0,
}
ChronicleUrsol = Ursol

local EMPTY_GUID = "0x0000000000000000"
local HOSTILE_TTL = 15          -- seconds a hostile stays tracked after its last event
local MAX_POLL_UNITS = 60       -- cap of hostile units polled per tick
local THREAT_API = "TWTv4="
local TANKMODE_API = "TMTv1="
local RELAY_API = "TWTRelayV2:"
local TANKSHARE_API = "PFTPTankV1:"
local UDTS_TM = "TWT_UDTSv4_TM"
-- auto mode: requests stop after this many without any answer (server without
-- the TWThreat API, e.g. a plain 1.12 server); one answer turns them back on
local MAX_UNANSWERED_QUERIES = 10

-- Default settings (stored in ChronicleCompanionDB.advancedLog with an "ursol_" prefix)
local DEFAULTS = {
    unitState = true,
    target = true,
    combat = true,
    targetInterval = 0.25,
    position = true,
    positionInterval = 1.0,
    positionMinMove = 0.5,
    marks = true,
    threat = true,
    threatQuery = "auto",   -- "auto": only if TWThreat / pfUI-ThreatPlates are not loaded, "on", "off"
    threatInterval = 1.0,
    threatLimit = 10,
}

function Ursol:Get(key)
    local db = ChronicleCompanionDB and ChronicleCompanionDB.advancedLog
    if db and db["ursol_" .. key] ~= nil then
        return db["ursol_" .. key]
    end
    return DEFAULTS[key]
end

function Ursol:Set(key, value)
    ChronicleLog:SetSetting("ursol_" .. key, value)
end

-- =============================================================================
-- Helpers
-- =============================================================================

local function IsCreature(guid)
    return guid and strsub(guid, 1, 5) == "0xF13"
end

local function ValidGuid(guid)
    return guid and guid ~= "" and guid ~= EMPTY_GUID
end

local function SafeField(unit, field)
    if not GetUnitField then return nil end
    local ok, value = pcall(GetUnitField, unit, field)
    if ok then return value end
    return nil
end

local function GuidOf(unit)
    if GetUnitGUID then
        local ok, guid = pcall(GetUnitGUID, unit)
        if ok and ValidGuid(guid) then return guid end
    elseif SUPERWOW_VERSION then
        -- SuperWoW: UnitExists returns the GUID as its second value
        local ok, exists, guid = pcall(UnitExists, unit)
        if ok and exists and ValidGuid(guid) then return guid end
    end
    return nil
end

-- PERF (local change): unit tokens are built once; GroupTokens() returns a shared
-- list (read-only for callers) rebuilt only when the group size changes.
local RAID_TOKENS, RAID_TARGET_TOKENS = {}, {}
for i = 1, 40 do
    RAID_TOKENS[i] = "raid" .. i
    RAID_TARGET_TOKENS["raid" .. i] = "raid" .. i .. "target"
end
local PARTY_TOKENS = { "party1", "party2", "party3", "party4" }
RAID_TARGET_TOKENS["player"] = "playertarget"
for i = 1, 4 do RAID_TARGET_TOKENS["party" .. i] = "party" .. i .. "target" end
local groupTokens, groupTokensKey = {}, nil

local function GroupTokens()
    local raid = GetNumRaidMembers() or 0
    local party = GetNumPartyMembers() or 0
    local key = raid > 0 and raid or -party - 1
    if key == groupTokensKey then return groupTokens end
    groupTokensKey = key
    local tokens = {}
    if raid > 0 then
        for i = 1, raid do
            tokens[i] = RAID_TOKENS[i] or ("raid" .. i)
        end
    else
        tokens[1] = "player"
        for i = 1, party do
            table.insert(tokens, PARTY_TOKENS[i] or ("party" .. i))
        end
    end
    groupTokens = tokens
    return tokens
end

local function UnitTokenByName(name)
    local raid = GetNumRaidMembers() or 0
    if raid > 0 then
        for i = 1, raid do
            if UnitName("raid" .. i) == name then return "raid" .. i end
        end
    else
        for i = 1, (GetNumPartyMembers() or 0) do
            if UnitName("party" .. i) == name then return "party" .. i end
        end
    end
    return nil
end

local function GroupChannel()
    if (GetNumRaidMembers() or 0) > 0 then return "RAID" end
    if (GetNumPartyMembers() or 0) > 0 then return "PARTY" end
    return nil
end

-- Detects which UnitPosition is active. ClassicAPI returns posY, posX, posZ,
-- instanceID; SuperWoW returns x, y, z. When both DLLs are loaded the last one
-- to register wins, so the shape is checked at runtime.
function Ursol:DetectPositionApi()
    if not UnitPosition then
        self.positionApi = "none"
        return
    end
    local ok, a, b, c, d = pcall(UnitPosition, "player")
    if not ok or not a then
        self.positionApi = "unknown"
    elseif d ~= nil then
        self.positionApi = "classicapi"
    else
        self.positionApi = "superwow"
    end
end

--- Returns world x, y, z of a unit token or GUID, plus the Map.dbc id when the
--- API gives it (ClassicAPI), or nil.
function Ursol:Position(unit)
    if self.positionApi == "none" or not UnitPosition then return nil end
    local ok, a, b, c, d = pcall(UnitPosition, unit)
    if not ok or not a then return nil end
    if self.positionApi == "classicapi" then
        return b, a, c, d
    end
    return a, b, c, nil
end

--- Map.dbc id of the current map: ClassicAPI GetInstanceInfo, else nil.
function Ursol:CurrentMapId()
    if GetInstanceInfo then
        local ok, _, _, _, _, _, _, _, instanceID = pcall(GetInstanceInfo)
        if ok and instanceID then return instanceID end
    end
    return nil
end

-- =============================================================================
-- Client capabilities: every line type runs only when the client provides what
-- it needs. DLLs load before addons, so this is known at load time; it is
-- checked again when logging is enabled.
-- =============================================================================

-- setting -> capability it needs, and what to tell the user when it is missing
local NEEDS = {
    unitState = "fields",
    target = "fields",
    combat = "fields",
    position = "position",
    marks = "marks",
    threat = "client",
}
local MISSING = {
    client = "needs the Ursol client",
    fields = "needs Nampower (GetUnitField)",
    position = "needs ClassicAPI or SuperWoW",
    marks = "needs Nampower or SuperWoW GUIDs",
}

function Ursol:DetectCaps()
    local caps = self.caps
    caps.client = Chronicle_IsUrsolClient()
    self:DetectPositionApi()
    caps.fields = GetUnitField ~= nil
    caps.guid = GetUnitGUID ~= nil or SUPERWOW_VERSION ~= nil
    caps.position = caps.fields and (self.positionApi == "classicapi" or self.positionApi == "superwow")
    caps.marks = GetRaidTargetIndex ~= nil and caps.guid
end

--- True when the client can produce this line type.
function Ursol:Available(key)
    local need = NEEDS[key]
    return not need or self.caps[need] and true or false
end

--- Text explaining why a line type is unavailable, or nil.
function Ursol:MissingText(key)
    if self:Available(key) then return nil end
    -- positions are written in UNIT_STATE lines, which need Nampower first
    if key == "position" and not self.caps.fields then return MISSING.fields end
    return MISSING[NEEDS[key]]
end

--- Setting on and supported by the client. Positions also need UNIT_STATE.
function Ursol:Active(key)
    if not self:Get(key) or not self:Available(key) then return false end
    if key == "position" then return self:Active("unitState") end
    return true
end

local function Round(value, decimals)
    local mult = 1
    for i = 1, (decimals or 0) do mult = mult * 10 end
    return math.floor(value * mult + 0.5) / mult
end

function Ursol:ThreatQueryActive()
    if not self:Available("threat") then return false end
    local mode = self:Get("threatQuery")
    if mode == "on" then return true end
    if mode == "off" then return false end
    -- auto: let TWThreat / pfUI-ThreatPlates do the querying, we only listen
    if TWT and TWT.UDTS then return false end
    if pfUI and pfUI.threatplates then return false end
    -- and stop asking a server that never answers (no TWThreat API)
    if not self.threatServer and self.threatUnanswered >= MAX_UNANSWERED_QUERIES then
        return false
    end
    return true
end

--- Threat API state for the panel and /chronicle ursol.
function Ursol:ThreatServerText()
    if self.threatServer then return "server answers" end
    if self.threatUnanswered >= MAX_UNANSWERED_QUERIES then return "no server answer, requests stopped" end
    return "not seen yet"
end

-- =============================================================================
-- Hostile unit tracking (fed by every combat event through CheckUnit)
-- =============================================================================

local originalCheckUnit = ChronicleLog.CheckUnit
function ChronicleLog:CheckUnit(guid)
    if IsCreature(guid) then
        Ursol.hostiles[guid] = GetTime()
    end
    return originalCheckUnit(self, guid)
end

function Ursol:IsTracked(guid)
    local seen = self.hostiles[guid]
    return seen and (GetTime() - seen) < HOSTILE_TTL
end

function Ursol:Cleanup(now)
    for guid, seen in pairs(self.hostiles) do
        if now - seen > HOSTILE_TTL then
            self.hostiles[guid] = nil
            self.lastTarget[guid] = nil
            self.lastData[guid] = nil
        end
    end
    for guid, data in pairs(self.lastThreat) do
        if now - data.time > 30 then self.lastThreat[guid] = nil end
    end
    -- in-combat units not seen for a minute (out of range, gone): forget them
    -- without writing anything, we do not know how their fight ended
    for guid, seen in pairs(self.inCombat) do
        if now - seen > 60 then self.inCombat[guid] = nil end
    end
end

function Ursol:Reset()
    self.hostiles = {}
    self.lastData = {}
    self.dirty = {}
    self.lastTarget = {}
    self.inCombat = {}
    self.marks = {}
    self.missingMarks = {}
    self.markScanAt = nil
    self.lastThreat = {}
end

-- =============================================================================
-- Session state: client APIs and map id are written by core.lua in HEADER
-- (superWowVersion, classicApi, threatMode) and ZONE_INFO (mapId)
-- =============================================================================

function Ursol:WriteInfo()
    self:DetectCaps()
    self.mapId = self:CurrentMapId()
end

local originalWriteZoneInfo = ChronicleLog.WriteZoneInfo
function ChronicleLog:WriteZoneInfo(force)
    originalWriteZoneInfo(self, force)
    if self:IsEnabled() then
        Ursol:Reset()
        Ursol:WriteInfo()
    end
end

local originalEnable = ChronicleLog.Enable
function ChronicleLog:Enable()
    local wasEnabled = self.enabled
    originalEnable(self)
    if not wasEnabled and self.enabled then
        Ursol:Reset()
        Ursol:WriteInfo()
        Ursol:ScanMarks()
    end
end

-- =============================================================================
-- UNIT_STATE: health, power and position of a unit on one line
--   ts|UNIT_STATE|guid|hp|maxHp|power|maxPower|powerType|mapId|x|y|z
-- Written right away on Nampower *_GUID events (health / mana / rage / energy
-- change); the polls (hostile units, positions) mark units "dirty" and write
-- them once at the end of the frame. A line is written only if something
-- changed (position: more than positionMinMove yards).
-- =============================================================================

-- power type -> unit field holding the current value / max, and a divisor
-- (rage is stored x10 in the unit field: 1000 = 100 rage)
local POWER_FIELDS = {
    [0] = { "power1", "maxPower1", 1 },   -- mana
    [1] = { "power2", "maxPower2", 10 },  -- rage
    [2] = { "power3", "maxPower3", 1 },   -- focus (hunter pets)
    [3] = { "power4", "maxPower4", 1 },   -- energy
    [4] = { "power5", "maxPower5", 1 },   -- happiness (hunter pets)
}

--- Power type from bytes0 (byte 3), falls back to UnitPowerType.
local function PowerTypeOf(unit)
    local bytes0 = SafeField(unit, "bytes0")
    if bytes0 then
        return math.mod(math.floor(bytes0 / 16777216), 256)
    end
    if UnitPowerType then
        local ok, pt = pcall(UnitPowerType, unit)
        if ok then return pt end
    end
    return nil
end

function Ursol:MarkDirty(guid, unit)
    if ValidGuid(guid) then
        self.dirty[guid] = unit or guid
    end
end

-- PERF (local change): the snapshot is taken into one reused scratch table; a
-- unit's lastData table is only created/updated when something changed.
local scratch = {}
local SNAP_FIELDS = { "hp", "maxHp", "powerType", "power", "maxPower", "x", "y", "z", "map" }
local NSNAP = 9

function Ursol:Snapshot(guid, unit)
    local hp = SafeField(unit, "health")
    if not hp then return nil end
    local data = scratch
    for i = 1, NSNAP do data[SNAP_FIELDS[i]] = nil end
    data.hp = hp
    data.maxHp = SafeField(unit, "maxHealth") or ""

    local pt = PowerTypeOf(unit)
    local spec = pt and POWER_FIELDS[pt]
    if spec then
        local value, max = SafeField(unit, spec[1]), SafeField(unit, spec[2])
        if value then
            data.powerType = pt
            data.power = math.floor(value / spec[3])
            data.maxPower = max and math.floor(max / spec[3]) or ""
        end
    end

    if self:Active("position") then
        local x, y, z, mapId = self:Position(unit)
        if x then
            data.x, data.y, data.z = Round(x, 1), Round(y, 1), Round(z, 1)
            data.map = mapId
        end
    end
    if not data.map then data.map = self.mapId end
    return data
end

function Ursol:Changed(old, new)
    if not old then return true end
    if old.hp ~= new.hp or old.maxHp ~= new.maxHp or old.power ~= new.power
        or old.maxPower ~= new.maxPower or old.powerType ~= new.powerType or old.map ~= new.map then
        return true
    end
    if new.x and not old.x then return true end
    if new.x and old.x then
        local minMove = tonumber(self:Get("positionMinMove")) or 0.5
        local dx, dy, dz = new.x - old.x, new.y - old.y, new.z - old.z
        if (dx * dx + dy * dy + dz * dz) >= minMove * minMove then return true end
    end
    return false
end

--- Takes a snapshot of one unit and writes UNIT_STATE if anything changed.
function Ursol:WriteUnitState(guid, unit)
    local data = self:Snapshot(guid, unit)
    if not data then return end
    local old = self.lastData[guid]
    if not self:Changed(old, data) then return end
    -- keep a copy of the scratch snapshot (reusing the unit's previous table)
    local keep = old or {}
    for i = 1, NSNAP do
        local k = SNAP_FIELDS[i]
        keep[k] = data[k]
    end
    self.lastData[guid] = keep
    data = keep
    ChronicleLog:CheckUnit(guid)
    ChronicleLog:Write10("UNIT_STATE", guid, data.hp, data.maxHp,
        data.power or "", data.maxPower or "", data.powerType or "",
        data.map or "", data.x or "", data.y or "", data.z or "")
end

--- Writes the units marked by the polls (at most one line per unit per frame).
function Ursol:FlushDirty()
    for guid, unit in pairs(self.dirty) do
        self:WriteUnitState(guid, unit)
        self.dirty[guid] = nil
    end
end

local function IsGrouped(isPlayer, isPet, partyIndex, raidIndex)
    return isPlayer == 1 or isPet == 1
        or (tonumber(partyIndex) or 0) > 0
        or (tonumber(raidIndex) or 0) > 0
end

function Ursol:OnUnitEvent(guid, isPlayer, isPet, partyIndex, raidIndex)
    if not self:Active("unitState") or not ValidGuid(guid) then return end
    if IsGrouped(isPlayer, isPet, partyIndex, raidIndex) or self:IsTracked(guid) then
        -- written right away so the timestamp is the one of the event
        self:WriteUnitState(guid, guid)
    end
end

function ChronicleLog:UNIT_HEALTH_GUID(guid, isPlayer, isTarget, isMouseover, isPet, partyIndex, raidIndex)
    Ursol:OnUnitEvent(guid, isPlayer, isPet, partyIndex, raidIndex)
end

function ChronicleLog:UNIT_MANA_GUID(guid, isPlayer, isTarget, isMouseover, isPet, partyIndex, raidIndex)
    Ursol:OnUnitEvent(guid, isPlayer, isPet, partyIndex, raidIndex)
end

function ChronicleLog:UNIT_RAGE_GUID(guid, isPlayer, isTarget, isMouseover, isPet, partyIndex, raidIndex)
    Ursol:OnUnitEvent(guid, isPlayer, isPet, partyIndex, raidIndex)
end

function ChronicleLog:UNIT_ENERGY_GUID(guid, isPlayer, isTarget, isMouseover, isPet, partyIndex, raidIndex)
    Ursol:OnUnitEvent(guid, isPlayer, isPet, partyIndex, raidIndex)
end

-- =============================================================================
-- UNIT_COMBAT: a hostile unit enters (1) or leaves (0) combat
--   ts|UNIT_COMBAT|guid|1|0
-- From the "in combat" bit of the unit flags (UNIT_FLAG_IN_COMBAT, 0x80000),
-- read on Nampower UNIT_FLAGS_GUID and during the hostile poll. A unit that
-- leaves combat alive (no DEATH line) is a reset / evade: its health goes back
-- to max and it walks back to its spawn (see UNIT_STATE).
-- =============================================================================

local UNIT_FLAG_IN_COMBAT = 524288 -- 0x80000

local function HasCombatFlag(flags)
    flags = tonumber(flags)
    if not flags then return nil end
    if flags < 0 then flags = flags + 4294967296 end -- read as a signed int32
    return math.mod(math.floor(flags / UNIT_FLAG_IN_COMBAT), 2) == 1
end

--- Checks one creature's combat flag and writes UNIT_COMBAT on a change.
--- Units only seen out of combat are not remembered, so idle mobs cost nothing.
function Ursol:CheckCombat(guid)
    if not IsCreature(guid) then return end
    local inCombat = HasCombatFlag(SafeField(guid, "flags"))
    if inCombat == nil then return end -- out of range / gone
    local was = self.inCombat[guid]
    if inCombat then
        if not was then
            ChronicleLog:CheckUnit(guid)
            ChronicleLog:Write2("UNIT_COMBAT", guid, 1)
        end
        self.inCombat[guid] = GetTime()
    elseif was then
        self.inCombat[guid] = nil
        ChronicleLog:Write2("UNIT_COMBAT", guid, 0)
    end
end

function ChronicleLog:UNIT_FLAGS_GUID(guid)
    if Ursol:Active("combat") and ValidGuid(guid) then
        Ursol:CheckCombat(guid)
    end
end

-- =============================================================================
-- UNIT_TARGET (polled: 1.12 has no event for another unit's target change)
-- =============================================================================

function Ursol:PollTargets()
    local count = 0
    for guid in pairs(self.hostiles) do
        if self:IsTracked(guid) then
            count = count + 1
            if count > MAX_POLL_UNITS then return end
            -- health / power too: the *_GUID events may only fire for units bound
            -- to a token; the snapshot is written only if something changed
            if self:Active("unitState") then self:MarkDirty(guid, guid) end
            -- combat flag too: UNIT_FLAGS_GUID may only fire for units bound to a token
            if self:Active("combat") then self:CheckCombat(guid) end
            local target = SafeField(guid, "target")
            if not ValidGuid(target) then target = "" end
            if self:Active("target") and self.lastTarget[guid] ~= target then
                -- nil means the unit is out of range / gone: keep the last known value
                if SafeField(guid, "health") then
                    self.lastTarget[guid] = target
                    ChronicleLog:Write2("UNIT_TARGET", guid, target)
                end
            end
        end
    end
end

-- =============================================================================
-- Position poll (only while the player is in combat): marks units dirty, the
-- UNIT_STATE snapshot is written if they moved more than positionMinMove
-- =============================================================================

function Ursol:PollPositions()
    if not self:Active("position") then return end
    local tokens = GroupTokens()
    for i = 1, table.getn(tokens) do
        local guid = GuidOf(tokens[i])
        if guid then self:MarkDirty(guid, tokens[i]) end
    end
    local count = 0
    for guid in pairs(self.hostiles) do
        if self:IsTracked(guid) then
            count = count + 1
            if count > MAX_POLL_UNITS then return end
            self:MarkDirty(guid, guid)
        end
    end
end

-- =============================================================================
-- RAID_MARK
-- =============================================================================

function Ursol:ScanMarks()
    if not self:Active("marks") or not ChronicleLog:IsEnabled() then return end
    local current = {}
    -- markN tokens (SuperWoW / ClassicAPI)
    for i = 1, 8 do
        local guid = GuidOf("mark" .. i)
        if guid then current[guid] = i end
    end
    -- plain 1.12 fallback: group members and their targets
    local tokens = GroupTokens()
    for i = 1, table.getn(tokens) do
        local unit = tokens[i]
        for j = 1, 2 do
            local guid = GuidOf(unit)
            if guid and not current[guid] then
                local ok, index = pcall(GetRaidTargetIndex, unit)
                if ok and index then current[guid] = index end
            end
            unit = RAID_TARGET_TOKENS[unit] or (unit .. "target")
        end
    end
    local used = {}
    for guid, index in pairs(current) do
        used[index] = guid
        self.missingMarks[guid] = nil
        if self.marks[guid] ~= index then
            ChronicleLog:CheckUnit(guid)
            ChronicleLog:Write2("RAID_MARK", guid, index)
        end
    end
    -- A unit can briefly drop out of a scan (seen in game: set / removed / set
    -- within the same millisecond). A removal is written when the icon is now on
    -- another unit, or when the unit is missing from two scans in a row.
    for guid, index in pairs(self.marks) do
        if not current[guid] then
            local misses = (self.missingMarks[guid] or 0) + 1
            if (used[index] and used[index] ~= guid) or misses >= 2 then
                self.missingMarks[guid] = nil
                ChronicleLog:Write2("RAID_MARK", guid, 0)
            else
                self.missingMarks[guid] = misses
                current[guid] = index
            end
        end
    end
    self.marks = current
end

-- RAID_TARGET_UPDATE comes in bursts: one scan 0.3 s after the last one
function ChronicleLog:RAID_TARGET_UPDATE()
    Ursol.markScanAt = GetTime() + 0.3
end

-- =============================================================================
-- THREAT (TWThreat server API, also relayed by TWThreat / pfUI-ThreatPlates)
-- =============================================================================

--- Rounds the percentage (4th field of every entry) of a threat list to one
--- decimal: "Koniz:1:157:100.000000:0;" -> "Koniz:1:157:100:0;".
--- Works for TWTv4 / TWTRelayV2 (name:tank:threat:perc:melee) and
--- TMTv1 / PFTPTankV1 (creature:guid:player:perc) lists.
local function RoundThreatList(list)
    local out = {}
    local from = 1
    local len = strlen(list)
    while from <= len do
        local sep = strfind(list, ";", from, true)
        local entry = strsub(list, from, (sep or (len + 1)) - 1)
        local fields = {}
        local f = 1
        while true do
            local c = strfind(entry, ":", f, true)
            if not c then
                table.insert(fields, strsub(entry, f))
                break
            end
            table.insert(fields, strsub(entry, f, c - 1))
            f = c + 1
        end
        local perc = tonumber(fields[4] or "")
        if perc then
            fields[4] = tostring(math.floor(perc * 10 + 0.5) / 10)
        end
        table.insert(out, table.concat(fields, ":"))
        if not sep then break end
        table.insert(out, ";")
        from = sep + 1
        if from > len then break end
    end
    -- keep a trailing ";" when the source had one
    local result = table.concat(out, "")
    if strsub(list, len, len) == ";" and strsub(result, -1) ~= ";" then
        result = result .. ";"
    end
    return result
end
Ursol.RoundThreatList = RoundThreatList

function Ursol:WriteThreat(mobGuid, mobName, source, list)
    if not list or list == "" then return end
    list = RoundThreatList(list)
    local key = mobGuid ~= "" and mobGuid or ("name:" .. (mobName or ""))
    local now = GetTime()
    local last = self.lastThreat[key]
    -- several addons can receive / relay the same table within the same second
    if last and last.list == list and (now - last.time) < 1.5 then return end
    self.lastThreat[key] = { list = list, time = now }
    if mobGuid ~= "" then ChronicleLog:CheckUnit(mobGuid) end
    ChronicleLog:Write4("THREAT", mobGuid, mobName or "", source, list)
end

--- Server answer to a TWT_UDTSv4[_TM] request sent by this client (any addon).
--- The table belongs to the mob this client currently targets.
function Ursol:HandleServerThreat(message)
    self.threatServer = true
    self.threatUnanswered = 0
    local threatPart, tankPart = message, nil
    local split = strfind(message, "#", 1, true)
    if split then
        threatPart = strsub(message, 1, split - 1)
        tankPart = strsub(message, split + 1)
    end

    local _, e = strfind(threatPart, THREAT_API, 1, true)
    if e then
        local mobGuid = GuidOf("target") or ""
        self:WriteThreat(mobGuid, UnitName("target"), "self", strsub(threatPart, e + 1))
    end

    if tankPart then
        local _, te = strfind(tankPart, TANKMODE_API, 1, true)
        if te then
            local list = strsub(tankPart, te + 1)
            if list ~= "" then
                ChronicleLog:Write2("THREAT_TANK", "self", RoundThreatList(list))
            end
        end
    end
end

--- TWTRelayV2:<mob>#name:tank:threat:perc:melee;...   (mob = the sender's target)
function Ursol:HandleRelay(message, sender)
    self.threatServer = true -- a group member got an answer: the server has the API
    local body = strsub(message, strlen(RELAY_API) + 1)
    local sep = strfind(body, "#", 1, true)
    if not sep then return end
    local mobName = strsub(body, 1, sep - 1)
    local mobGuid = ""
    local unit = UnitTokenByName(sender)
    if unit and UnitName(unit .. "target") == mobName then
        mobGuid = GuidOf(unit .. "target") or ""
    end
    self:WriteThreat(mobGuid, mobName, "relay:" .. sender, strsub(body, sep + 1))
end

local originalChatMsgAddon = ChronicleLog.CHAT_MSG_ADDON
function ChronicleLog:CHAT_MSG_ADDON(prefix, message, channel, sender)
    if message and Ursol:Active("threat") then
        if strfind(message, THREAT_API, 1, true) then
            Ursol:HandleServerThreat(message)
            return
        end
        if prefix == "TWT" and sender ~= UnitName("player") then
            if strsub(message, 1, strlen(RELAY_API)) == RELAY_API then
                Ursol:HandleRelay(message, sender)
                return
            end
            if strsub(message, 1, strlen(TANKSHARE_API)) == TANKSHARE_API then
                local list = strsub(message, strlen(TANKSHARE_API) + 1)
                if list ~= "" then
                    self:Write2("THREAT_TANK", "relay:" .. sender, RoundThreatList(list))
                end
                return
            end
        end
    end
    if originalChatMsgAddon then
        return originalChatMsgAddon(self, prefix, message, channel, sender)
    end
end

function Ursol:QueryThreat()
    local channel = GroupChannel()
    if not channel then return end
    if not SendAddonMessage then return end
    if not UnitExists("target") or UnitIsPlayer("target") or not UnitCanAttack("player", "target") then return end
    SendAddonMessage(UDTS_TM, "limit=" .. (tonumber(self:Get("threatLimit")) or 10), channel)
    if not self.threatServer then
        self.threatUnanswered = self.threatUnanswered + 1
    end
end

-- =============================================================================
-- Polling frame
-- =============================================================================

Ursol.frame = CreateFrame("Frame", "ChronicleUrsolFrame")
Ursol.frame:SetScript("OnUpdate", function()
    if not ChronicleLog.enabled then return end
    local now = GetTime()
    local inCombat = UnitAffectingCombat("player")

    if now - Ursol.lastCleanup > 5 then
        Ursol.lastCleanup = now
        Ursol:Cleanup(now)
    end

    if (Ursol:Active("target") or Ursol:Active("combat")) and now - Ursol.lastTargetPoll >= (tonumber(Ursol:Get("targetInterval")) or 0.25) then
        Ursol.lastTargetPoll = now
        Ursol:PollTargets()
    end

    if inCombat and Ursol:Active("position") and now - Ursol.lastPosPoll >= (tonumber(Ursol:Get("positionInterval")) or 1) then
        Ursol.lastPosPoll = now
        Ursol:PollPositions()
    end

    -- RAID_TARGET_UPDATE has no payload and can fire before units are known
    if Ursol.markScanAt and now >= Ursol.markScanAt then
        Ursol.markScanAt = nil
        Ursol.lastMarkPoll = now
        Ursol:ScanMarks()
    end
    if inCombat and Ursol:Active("marks") and now - Ursol.lastMarkPoll >= 5 then
        Ursol.lastMarkPoll = now
        Ursol:ScanMarks()
    end

    if inCombat and Ursol:Active("threat") and Ursol:ThreatQueryActive()
        and now - Ursol.lastQuery >= math.max(0.3, tonumber(Ursol:Get("threatInterval")) or 1) then
        Ursol.lastQuery = now
        Ursol:QueryThreat()
    end

    if Ursol:Active("unitState") then
        Ursol:FlushDirty()
    else
        Ursol.dirty = {}
    end
end)

-- New events (registered by ChronicleLog:Enable with the rest), only those the
-- client can use
Ursol:DetectCaps()
if Ursol.caps.fields then
    table.insert(ChronicleLog.events, "UNIT_HEALTH_GUID")
    table.insert(ChronicleLog.events, "UNIT_MANA_GUID")
    table.insert(ChronicleLog.events, "UNIT_RAGE_GUID")
    table.insert(ChronicleLog.events, "UNIT_ENERGY_GUID")
    table.insert(ChronicleLog.events, "UNIT_FLAGS_GUID")
end
if Ursol.caps.marks then
    table.insert(ChronicleLog.events, "RAID_TARGET_UPDATE")
end

-- =============================================================================
-- Slash command: /chronicle ursol [setting] [value]
-- =============================================================================

local BOOL_KEYS = { unitState = true, target = true, combat = true, position = true, marks = true, threat = true }
local NUM_KEYS = { targetInterval = true, positionInterval = true, positionMinMove = true, threatInterval = true, threatLimit = true }

function Ursol:Status()
    self:DetectCaps()
    local threatText = "off (needs the Ursol client)"
    if self:Available("threat") then
        threatText = (self:ThreatQueryActive() and "query" or "listen only")
            .. " (" .. self:ThreatServerText() .. ")"
    end
    Chronicle:Print("Ursol log format v" .. self.formatVersion
        .. " - client: " .. (self.caps.client and "Ursol" or "native 1.12")
        .. ", position API: " .. self.positionApi
        .. ", threat: " .. threatText)
    for key in pairs(DEFAULTS) do
        local missing = self:MissingText(key)
        Chronicle:Print("  " .. key .. " = " .. tostring(self:Get(key))
            .. (missing and (" (off: " .. missing .. ")") or ""))
    end
end

local KEY_BY_LOWER = {}
for key in pairs(DEFAULTS) do KEY_BY_LOWER[strlower(key)] = key end

function Ursol:Slash(key, value)
    if key and key ~= "" then key = KEY_BY_LOWER[strlower(key)] or key end
    if value then value = strlower(value) end
    if not key or key == "" then
        self:Status()
        Chronicle:Print("/chronicle ursol <setting> <value>  (on/off, a number, or auto/on/off for threatQuery)")
        return
    end
    if BOOL_KEYS[key] then
        local new
        if value == "on" or value == "1" or value == "true" then new = true
        elseif value == "off" or value == "0" or value == "false" then new = false
        else new = not self:Get(key) end
        self:Set(key, new)
        Chronicle:Print("ursol " .. key .. " = " .. tostring(new))
    elseif NUM_KEYS[key] and tonumber(value) then
        self:Set(key, tonumber(value))
        Chronicle:Print("ursol " .. key .. " = " .. value)
    elseif key == "threatQuery" and (value == "auto" or value == "on" or value == "off") then
        self:Set(key, value)
        Chronicle:Print("ursol threatQuery = " .. value)
    else
        Chronicle:Print("Unknown ursol setting or value: " .. key .. " " .. (value or ""))
    end
end

-- =============================================================================
-- Options panel: "Extra events" side panel, docked to the right of the
-- ChronicleLog options panel (opened with /clog or /chronicle config)
-- =============================================================================

local UI_TOGGLES = {
    { key = "unitState", label = "Unit state", desc = "UNIT_STATE: health, power" },
    { key = "position", label = "Positions", desc = "x / y / z in UNIT_STATE", parent = "unitState" },
    { key = "target", label = "Mob targets", desc = "UNIT_TARGET: who is tanking" },
    { key = "combat", label = "Mob combat", desc = "UNIT_COMBAT: pulls, resets, evades" },
    { key = "marks", label = "Raid marks", desc = "RAID_MARK" },
    { key = "threat", label = "Threat", desc = "THREAT, THREAT_TANK" },
}
local THREAT_QUERY_NEXT = { auto = "on", on = "off", off = "auto" }

function Ursol:CreateOptions(panel)
    local side = CreateFrame("Frame", "ChronicleUrsolOptions", panel)
    side:SetWidth(230)
    side:SetHeight(panel:GetHeight())
    side:SetPoint("TOPLEFT", panel, "TOPRIGHT", -4, 0)
    side:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })

    local title = side:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOP", 0, -18)
    title:SetText("Extra events (Ursol)")

    local subtitle = side:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOP", title, "BOTTOM", 0, -2)
    subtitle:SetText("Lines Chronicle ignores, for analysis")

    local y = -52
    side.checks = {}
    for i = 1, table.getn(UI_TOGGLES) do
        local t = UI_TOGGLES[i]
        local x = t.parent and 36 or 20
        local check = CreateFrame("CheckButton", "ChronicleUrsolCheck_" .. t.key, side, "UICheckButtonTemplate")
        check:SetPoint("TOPLEFT", x, y)
        getglobal(check:GetName() .. "Text"):SetText(t.label)
        check.key = t.key
        check:SetScript("OnClick", function()
            Ursol:Set(this.key, this:GetChecked() == 1)
            Ursol:RefreshOptions()
        end)
        local desc = side:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        desc:SetPoint("TOPLEFT", x + 26, y - 20)
        desc:SetText(t.desc)
        check.desc = desc
        check.baseDesc = t.desc
        side.checks[t.key] = check
        y = y - 34
    end

    -- threat requests: auto / on / off
    local queryLabel = side:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    queryLabel:SetPoint("TOPLEFT", 36, y - 4)
    queryLabel:SetText("Server requests:")
    local queryButton = CreateFrame("Button", "ChronicleUrsolThreatQuery", side, "UIPanelButtonTemplate")
    queryButton:SetWidth(55)
    queryButton:SetHeight(18)
    queryButton:SetPoint("LEFT", queryLabel, "RIGHT", 6, 0)
    queryButton:SetScript("OnClick", function()
        Ursol:Set("threatQuery", THREAT_QUERY_NEXT[Ursol:Get("threatQuery")] or "auto")
        Ursol:RefreshOptions()
    end)
    side.queryButton = queryButton
    local queryDesc = side:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    queryDesc:SetPoint("TOPLEFT", 36, y - 20)
    queryDesc:SetWidth(180)
    queryDesc:SetJustifyH("LEFT")
    side.queryDesc = queryDesc
    y = y - 58

    local help = side:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    help:SetPoint("TOPLEFT", 20, y)
    help:SetWidth(195)
    help:SetJustifyH("LEFT")
    help:SetText("Intervals: /chronicle ursol\nFormat: URSOL_EVENTS.md")

    self.options = side
end

function Ursol:RefreshOptions()
    local side = self.options
    if not side then return end
    self:DetectCaps()

    for key, check in pairs(side.checks) do
        local missing = self:MissingText(key)
        -- positions are part of UNIT_STATE: greyed out when it is off
        local usable = not missing and (key ~= "position" or self:Active("unitState"))
        if usable then
            check:Enable()
            getglobal(check:GetName() .. "Text"):SetTextColor(1, 1, 1)
        else
            check:Disable()
            getglobal(check:GetName() .. "Text"):SetTextColor(0.5, 0.5, 0.5)
        end
        -- a line type the client cannot produce is shown unchecked, with the reason;
        -- the saved setting is kept for when the DLL is back
        check:SetChecked((self:Get(key) and not missing) and 1 or nil)
        if missing then
            check.desc:SetText("|cffff6060" .. missing .. "|r")
        elseif key == "position" then
            check.desc:SetText(check.baseDesc .. " (" .. self.positionApi .. ")")
        else
            check.desc:SetText(check.baseDesc)
        end
    end

    local mode = self:Get("threatQuery")
    side.queryButton:SetText(mode)
    if self:Active("threat") then side.queryButton:Enable() else side.queryButton:Disable() end
    local active = self:ThreatQueryActive()
    if not self.caps.client then
        side.queryDesc:SetText("off: needs the Ursol client")
    elseif mode == "auto" then
        if active then
            side.queryDesc:SetText("auto: no threat addon, this addon asks")
        elseif (TWT and TWT.UDTS) or (pfUI and pfUI.threatplates) then
            side.queryDesc:SetText("auto: TWThreat / ThreatPlates ask, this addon listens")
        else
            side.queryDesc:SetText("auto: no server answer, requests stopped")
        end
    elseif mode == "on" then
        side.queryDesc:SetText("on: this addon always asks the server")
    else
        side.queryDesc:SetText("off: only listens to other addons")
    end
end

local originalCreateOptionsPanel = ChronicleLog.CreateOptionsPanel
function ChronicleLog:CreateOptionsPanel()
    originalCreateOptionsPanel(self)
    if self.optionsPanel then Ursol:CreateOptions(self.optionsPanel) end
end

local originalRefreshOptionsPanel = ChronicleLog.RefreshOptionsPanel
function ChronicleLog:RefreshOptionsPanel()
    originalRefreshOptionsPanel(self)
    Ursol:RefreshOptions()
end
