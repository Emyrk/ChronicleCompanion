-- =============================================================================
-- ChronicleLog Unit API Wrappers
-- Gracefully handles environments where Unit*(guid) throws errors.
-- On Kronos, all Unit* functions throw when passed a GUID string (e.g. "0x...").
-- On TWoW, GUIDs work fine. We detect support at init and return safe defaults
-- for GUID arguments when unsupported.
-- =============================================================================

-- Detect GUID strings (start with "0x")
local function IsGUID(unit)
    return type(unit) == "string" and strsub(unit, 1, 2) == "0x"
end

-- Whether the environment supports passing GUIDs to Unit* functions.
-- Determined at init time by probing UnitName(playerGuid).
local guidSupported = true  -- optimistic default

-- Known player GUIDs from roster iteration. Populated by RegisterKnownPlayer().
-- knownPlayers[guid] = name
local knownPlayers = {}

-- GUID → unit token lookup. Populated by RegisterGuidToken() during EmitNameMappings.
-- guidTokens[guid] = "raid3", "party1", "player", etc.
local guidTokens = {}

--- Call during PLAYER_ENTERING_WORLD to probe GUID support.
function ChronicleLog:DetectGuidSupport()
    local playerGuid = GetUnitGUID("player")
    if not playerGuid then return end

    local ok, _ = pcall(UnitName, playerGuid)
    guidSupported = ok
    Chronicle:DebugPrint("GUID API support: " .. tostring(guidSupported))
end

--- Register a known player GUID → name mapping from roster iteration.
--- Used by EmitNameMappings to populate the cache so CUnitName/CUnitIsPlayer
--- can return correct values even when the real API doesn't accept GUIDs.
---@param guid string Player GUID
---@param name string Player name
function ChronicleLog:RegisterKnownPlayer(guid, name)
    if guid and name then
        knownPlayers[guid] = name
    end
end

--- Clear the known player cache and token lookup (e.g. on group disband).
function ChronicleLog:ClearKnownPlayers()
    knownPlayers = {}
    guidTokens = {}
end

--- Register a GUID → unit token mapping. Called from EmitNameMappings.
---@param guid string Unit GUID
---@param token string Unit token (e.g. "raid3", "party1", "player")
function ChronicleLog:RegisterGuidToken(guid, token)
    if guid and token then
        guidTokens[guid] = token
    end
end

--- Resolve a GUID to a unit token ("raid1", "party2", "player", etc.) via
--- the cached lookup table (populated by EmitNameMappings on roster changes).
--- Returns the token if found, or the original guid if not.
---@param guid string Unit GUID
---@return string unitOrGuid Unit token if resolved, original GUID otherwise
function ChronicleLog.ResolveGuidToToken(guid)
    if not guid or not IsGUID(guid) then return guid end
    if guidSupported then return guid end
    return guidTokens[guid] or guid
end

-- =============================================================================
-- Wrapped Unit API functions
-- If GUIDs not supported and arg is a GUID, consult the known player cache
-- first, then return safe defaults. Otherwise call the real API.
-- =============================================================================

function CUnitName(unit)
    if not guidSupported and IsGUID(unit) then
        return knownPlayers[unit] or ""
    end
    return UnitName(unit)
end

function CUnitIsUnit(unit1, unit2)
    if not guidSupported and (IsGUID(unit1) or IsGUID(unit2)) then return nil end
    return UnitIsUnit(unit1, unit2)
end

function CUnitIsPlayer(unit)
    if not guidSupported and IsGUID(unit) then
        -- If we know this GUID from roster iteration, it's a player
        if knownPlayers[unit] then return 1 end
        return nil
    end
    return UnitIsPlayer(unit)
end

function CUnitCanCooperate(unit1, unit2)
    if not guidSupported and (IsGUID(unit1) or IsGUID(unit2)) then return nil end
    return UnitCanCooperate(unit1, unit2)
end

function CUnitLevel(unit)
    if not guidSupported and IsGUID(unit) then return 0 end
    return UnitLevel(unit)
end

function CUnitHealthMax(unit)
    if not guidSupported and IsGUID(unit) then return 0 end
    return UnitHealthMax(unit)
end

function CUnitIsConnected(unit)
    if not guidSupported and IsGUID(unit) then return nil end
    return UnitIsConnected(unit)
end

function CUnitClass(unit)
    if not guidSupported and IsGUID(unit) then return "", "" end
    return UnitClass(unit)
end

function CUnitRace(unit)
    if not guidSupported and IsGUID(unit) then return "", "" end
    return UnitRace(unit)
end

function CUnitSex(unit)
    if not guidSupported and IsGUID(unit) then return 1 end
    return UnitSex(unit)
end

function CGetGuildInfo(unit)
    if not guidSupported and IsGUID(unit) then return nil end
    return GetGuildInfo(unit)
end

function CUnitExists(unit)
    if not guidSupported and IsGUID(unit) then return nil, nil end
    return UnitExists(unit)
end
