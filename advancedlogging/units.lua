-- =============================================================================
-- ChronicleLog Units - GUID tracking and metadata logging
-- =============================================================================

-- Initialize units tracking on ChronicleLog
---@class ChronicleLogUnits
---@field logged table<string, number> GUID → timestamp (when last logged)
---@field staleTimeout number Seconds before a GUID is considered stale (default 300)
---@field challenges string Player challenge modes, comma-separated keys or "na"
ChronicleLog.units = {
    logged = {},
    staleTimeout = 300,
    challenges = "na",
}

-- =============================================================================
-- Challenge Mode Detection
-- =============================================================================

-- Map spell name -> key (localized)
-- TODO: Switch to spell ids, as names can be localized
local CHALLENGE_SPELLS = {
    ["enUS"] = {
        ["Level One Lunatic"] = "lunatic",
        ["Hardcore"] = "hardcore",
        ["Boaring Adventure"] = "boaring",
        ["Path of the Brewmaster"] = "brewmaster",
        ["Exhaustion"] = "exhaustion",
        ["Slow & Steady"] = "slowsteady",
        ["Traveling Craftmaster"] = "craftmaster",
        ["Vagrant's Endeavor"] = "vagrant",
    },
}

--- Returns a comma-separated list of challenge keys the player has.
--- Scans spellbook for known challenge mode spells.
---@return string challenges Comma-separated challenge keys or empty string
local function GetPlayerChallenges()
    local _, locale = GetLocale()
    
    local spellNames = CHALLENGE_SPELLS[locale]
    if spellNames == nil then
        -- Fallback to enUS
        spellNames = CHALLENGE_SPELLS["enUS"]
    end
    
    local challenges = {}
    for tab = 1, GetNumSpellTabs() do
        local _, _, offset, numSpells = GetSpellTabInfo(tab)
        for i = 1, numSpells do
            local name = GetSpellName(offset + i, "spell")
            local key = name and spellNames[name]
            if key then
                challenges[key] = true
            end
        end
    end
    
    local keys = {}
    for k in pairs(challenges) do
        table.insert(keys, k)
    end
    table.sort(keys)
    return table.concat(keys, ",")
end

-- =============================================================================
-- Unit Info Helpers
-- =============================================================================

--- Returns a CSV string of the unit's buffs in format "buffID=stacks,buffID=stacks".
---@param guid string Unit GUID
---@return string buffs CSV of buff IDs and stack counts
local function GetUnitBuffs(guid)
    local auras = ""
    local prefix = ""
    for i = 1, 31 do
        local buffTexture, buffApplications, buffID = UnitBuff(guid, i)
        if not buffTexture then
            return auras
        end
        buffApplications = buffApplications or 1
        auras = auras .. string.format("%s%d=%d", prefix, buffID, buffApplications)
        prefix = ","
    end
    return auras
end

-- =============================================================================
-- Core Functions
-- =============================================================================

--- Initializes the unit tracking system.
--- Caches player challenge modes.
--- Should be called during addon initialization.
function ChronicleLog:InitUnits()
    local challenges = GetPlayerChallenges()
    if challenges ~= "" then
        self.units.challenges = challenges
        Chronicle:Print("Player challenges: " .. challenges)
    end
end

--- Checks if a GUID needs to be logged (new or stale).
--- If so, captures unit info and writes UNIT_INFO event.
--- Call this before writing events that reference the GUID.
---@param guid string Unit GUID to check
function ChronicleLog:CheckUnit(guid)
    if not guid or guid == "" or guid == "0x0000000000000000" then
        return
    end
    
    local now = time()
    local lastLogged = self.units.logged[guid]
    
    -- Skip if recently logged (not stale)
    if lastLogged and (now - lastLogged) < self.units.staleTimeout then
        return
    end
    
    -- Validate unit exists
    local exists, resolvedGuid = UnitExists(guid)
    if not exists then
        return
    end
    
    local name = UnitName(guid)
    if not name then
        return
    end
    
    -- Gather unit info
    local isPlayer = UnitIsUnit(guid, "player") and 1 or 0
    local canCooperate = UnitCanCooperate("player", guid) and 1 or 0
    local level = UnitLevel(guid) or 0
    local maxHealth = UnitHealthMax(guid) or 0
    local buffs = GetUnitBuffs(guid)
    
    -- Check for owner (pets)
    local owner = ""
    local ownerExists, ownerGuid = UnitExists(guid .. "owner")
    if ownerExists and ownerGuid then
        owner = ownerGuid
    end
    
    -- Get challenges (only meaningful for player)
    local challenges = isPlayer == 1 and self.units.challenges or "na"
    
    -- Mark as logged
    self.units.logged[guid] = now
    
    -- Write UNIT_INFO event
    self:Write("UNIT_INFO", guid, isPlayer, name, canCooperate, owner, buffs, level, challenges, maxHealth)
end

--- Purges all units from the logged database.
--- Call this on zone changes or other reset events.
function ChronicleLog:PurgeUnits()
    self.units.logged = {}
end

--- Removes stale units from the logged database.
--- Units not logged within staleTimeout are removed.
---@return number removed Number of units removed
function ChronicleLog:CleanupStaleUnits()
    local now = time()
    local removed = 0
    for guid, loggedTime in pairs(self.units.logged) do
        if (now - loggedTime) > self.units.staleTimeout then
            self.units.logged[guid] = nil
            removed = removed + 1
        end
    end
    return removed
end
