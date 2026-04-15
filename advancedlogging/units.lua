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
-- Transmog Tracking (Async)
-- =============================================================================

-- Pending transmog data: pendingTransmog[playerName] = { [slotId] = {itemId, transmogId}, ... }
local pendingTransmog = {}
-- Timestamp of last transmog message per player (for timeout-based writing)
local pendingTransmogTime = {}

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

--- Returns a CSV string of the unit's auras (buffs and debuffs) in format "spellID=stacks,spellID=stacks".
--- Uses nampower's GetUnitData to read aura arrays directly from unit fields.
--- Aura slots 1-32 are buffs, 33-48 are debuffs.
---@param unitData table Unit data from GetUnitData containing aura, auraApplications arrays
---@return string auras CSV of aura spell IDs and stack counts
local function GetUnitAuras(unitData)
    local auraIds = unitData.aura
    local auraStacks = unitData.auraApplications
    
    if not auraIds then
        return ""
    end
    
    local parts = {}
    for i = 1, 48 do
        local spellId = auraIds[i]
        if spellId and spellId > 0 then
            local stacks = (auraStacks and auraStacks[i]) or 1
            if stacks < 1 then stacks = 1 end
            table.insert(parts, spellId .. "=" .. stacks)
        end
    end
    
    return table.concat(parts, ",")
end

-- =============================================================================
-- Transmog Functions
-- =============================================================================

--- Requests transmog info for a player.
--- Sends addon message and waits for async response via CHAT_MSG_ADDON.
---@param playerName string Player name to request transmog for
function ChronicleLog:RequestTransmogInfo(playerName)
    if not playerName then return end
    
    Chronicle:DebugPrint("RequestTransmogInfo: " .. playerName)
    
    -- Send addon message to request transmog data (works for both local and other players)
    pendingTransmog[playerName] = {}
    pendingTransmogTime[playerName] = GetTime()  -- Set timeout so non-responding requests get cleaned up
    SendAddonMessage("TW_CHAT_MSG_WHISPER<" .. playerName .. ">", "INSShowTransmogs", "GUILD")
end

--- Handles CHAT_MSG_ADDON events for transmog data.
--- Listens for INSTransmogs responses from other players.
---@param prefix string Addon message prefix
---@param message string Message content
---@param channel string Distribution channel
---@param sender string Sender name
function ChronicleLog:CHAT_MSG_ADDON(prefix, message, channel, sender)
    if prefix ~= "TW_CHAT_MSG_WHISPER" then return end
    if not message or not strfind(message, "INSTransmogs;") then return end
    
    -- Strip leading whitespace/tab
    message = string.gsub(message, "^%s+", "")
    
    -- Parse: INSTransmogs;slotOrMarker;transmogId;itemId
    local parts = {}
    for part in string.gfind(message, "[^;]+") do
        table.insert(parts, part)
    end
    
    local marker = parts[2]
    
    if marker == "start" then
        -- Clear/initialize data for this player
        pendingTransmog[sender] = {}
        pendingTransmogTime[sender] = GetTime()
    elseif marker == "end" then
        -- Write the log and clean up
        if pendingTransmog[sender] then
            self:WriteCombatantTransmog(sender, pendingTransmog[sender])
            pendingTransmog[sender] = nil
            pendingTransmogTime[sender] = nil
        end
    else
        -- Data row: slotId;transmogId;itemId (server sends transmog first, then item)
        local slotId = tonumber(marker)
        local transmogId = tonumber(parts[3]) or 0
        local itemId = tonumber(parts[4]) or 0
        if slotId then
            -- Initialize if we missed the start message
            if not pendingTransmog[sender] then
                pendingTransmog[sender] = {}
            end
            pendingTransmog[sender][slotId] = { itemId = itemId, transmogId = transmogId }
            pendingTransmogTime[sender] = GetTime()
        end
    end
end

--- Flushes any pending transmog data that hasn't received new messages for a while.
--- Call this periodically (e.g., from OnUpdate or a timer).
function ChronicleLog:FlushPendingTransmog()
    local now = GetTime()
    local timeout = 0.5  -- Write after 0.5 seconds of no new messages
    
    -- Collect names to flush first (avoid modifying table during iteration)
    local toFlush = {}
    for playerName, lastTime in pairs(pendingTransmogTime) do
        if (now - lastTime) > timeout and pendingTransmog[playerName] then
            table.insert(toFlush, playerName)
        end
    end
    
    -- Now flush collected entries
    for _, playerName in ipairs(toFlush) do
        self:WriteCombatantTransmog(playerName, pendingTransmog[playerName])
        pendingTransmog[playerName] = nil
        pendingTransmogTime[playerName] = nil
    end
end

--- Writes a COMBATANT_TRANSMOG log line for a player.
--- Format: timestamp|COMBATANT_TRANSMOG|playerName|slotId:itemId:transmogId&...
---@param playerName string Player name
---@param data table Transmog data: { [slotId] = { itemId, transmogId }, ... }
function ChronicleLog:WriteCombatantTransmog(playerName, data)
    if not data then return end
    
    Chronicle:DebugPrint("WriteCombatantTransmog: " .. playerName)
    
    local parts = {}
    for slotId, info in pairs(data) do
        table.insert(parts, slotId .. ":" .. (info.itemId or 0) .. ":" .. (info.transmogId or 0))
    end
    
    if table.getn(parts) > 0 then
        self:Write("COMBATANT_TRANSMOG", playerName, table.concat(parts, "&"))
    end
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
    local unitData = GetUnitData(guid)
    if not unitData then
        return
    end
    
    local name = UnitName(guid)
    if not name then
        return
    end
    
    -- Gather unit info
    local isMe = UnitIsUnit(guid, "player") and 1 or 0
    local canCooperate = UnitCanCooperate("player", guid) and 1 or 0
    local level = UnitLevel(guid) or 0
    local maxHealth = UnitHealthMax(guid) or 0
    local auras = GetUnitAuras(unitData)
    
    -- Check for owner (pets)
    local ownerGuid = GetUnitGUID(guid .. "owner")

    local charm = GetUnitField(guid, "charm")
    if(charm == "0x0000000000000000") then
        charm = ""
    end
    
    -- Get challenges (only meaningful for player)
    local challenges = isMe == 1 and self.units.challenges or "na"
    
    -- Mark as logged
    self.units.logged[guid] = now
    
    -- Write UNIT_INFO event
    self:Write("UNIT_INFO", guid, isMe, name, canCooperate, ownerGuid, auras, level, challenges, maxHealth, charm)
    
    -- Write COMBATANT_INFO for players (gear, talents, guild)
    if UnitIsPlayer(guid) == 1 then
        self:WriteCombatantInfo(guid)
        -- Request transmog info async (fires COMBATANT_TRANSMOG when response arrives)
        self:RequestTransmogInfo(name)
    end
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
