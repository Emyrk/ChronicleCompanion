-- =============================================================================
-- ChronicleLog Talents - Inspect and cache other players' talent specs
-- =============================================================================
-- Sends INSTalentShow via addon message to request talent data, which arrives as:
--   ← INSTalentInfo;tree;idx;name;tier;col;currRank;maxRank;meetsPrereq
--   ← INSTalentEND

local TALENT_REFRESH_INTERVAL = 900  -- Re-check talents every 15 minutes
local INSPECTION_TIMEOUT = 10        -- Seconds before giving up (transmog data arrives first)

-- Module-level state (avoids polluting ChronicleLog with many keys)
local talentInfo = {}          -- [playerName] = { "", "", "" }  (rank digits per tree)
local talentTabInfo = {}       -- [playerName] = { {name,points}, {name,points}, {name,points} }
local talentLastUpdate = {}    -- [playerName] = GetTime() timestamp
local inspectionQueue = {}     -- ordered list of unit IDs
local currentTarget = nil      -- name of player currently being inspected
local inspectionActive = false -- whether a request is in-flight
local lastRequestTime = 0      -- GetTime() of last request sent
local lastRefreshCheck = 0     -- GetTime() of last periodic refresh scan

-- =============================================================================
-- Helpers
-- =============================================================================

--- Purge all cached talent data for a player, resetting them for a fresh inspection.
---@param playerName string Player name
local function PurgeTalentData(playerName)
    talentInfo[playerName] = { "", "", "" }
    talentTabInfo[playerName] = {}
    talentLastUpdate[playerName] = nil
end

--- Handle a potential talent reset debuff on a unit.
--- For the local player, re-writes COMBATANT_INFO immediately.
--- For other players, forces a talent re-inspection.
---@param guid string GUID of the unit that received the debuff
---@param spellId number|string Spell ID of the debuff
function ChronicleLog:HandleTalentReset(guid, spellId)
    if tonumber(spellId) ~= 57734 then return end
    if not UnitIsPlayer(guid) or UnitIsPlayer(guid) ~= 1 then return end

    local playerName = UnitName(guid)
    Chronicle:DebugPrint("TalentResetDetected: " .. (playerName or guid))

    if UnitIsUnit(guid, "player") == 1 then
        -- Self talents are always in COMBATANT_INFO
        self:WriteCombatantInfo("player")
    else
        -- Other's talents come from inspection.
        PurgeTalentData(playerName)
        self:QueueTalentInspection(guid, true)
    end
end

--- Purge all talent cache data (all players).
function ChronicleLog:PurgeTalentCache()
    talentInfo = {}
    talentTabInfo = {}
    talentLastUpdate = {}
    inspectionQueue = {}
    currentTarget = nil
    inspectionActive = false
    lastRefreshCheck = 0
    Chronicle:DebugPrint("PurgeTalentCache: all talent data cleared")
end

--- Begin an inspection for a player by name. Purges cached data, sets active
--- inspection state, and sends the addon message request.
---@param playerName string Player name to inspect
local function BeginInspection(playerName)
    PurgeTalentData(playerName)
    currentTarget = playerName
    inspectionActive = true
    lastRequestTime = GetTime()
    SendAddonMessage("TW_CHAT_MSG_WHISPER<" .. playerName .. ">", "INSTalentShow", "GUILD")
end

-- =============================================================================
-- Slash Command / External API
-- =============================================================================

--- Force a talent inspection of a player by name (slash command).
---@param playerName string Player name to inspect
function ChronicleLog:ForceInspectPlayer(playerName)
    if not playerName or playerName == "" then
        Chronicle:Print("Usage: /chronicle inspect <player name>")
        return
    end

    -- Find the unit ID for this player in raid or party
    local unit = nil
    local numRaid = GetNumRaidMembers()
    if numRaid > 0 then
        for i = 1, numRaid do
            if UnitName("raid" .. i) == playerName then
                unit = "raid" .. i
                break
            end
        end
    else
        local numParty = GetNumPartyMembers()
        for i = 1, numParty do
            if UnitName("party" .. i) == playerName then
                unit = "party" .. i
                break
            end
        end
    end

    if not unit then
        Chronicle:Print("Player \"" .. playerName .. "\" not found in raid or party.")
        return
    end

    Chronicle:Print("Inspecting talents for " .. playerName .. "...")
    Chronicle:DebugPrint("RequestTalentInfo: " .. playerName .. " (forced)")
    BeginInspection(playerName)
end





-- =============================================================================
-- Queue Management
-- =============================================================================

--- Queue a unit for talent inspection.
---@param unit string Unit ID or GUID
---@param force boolean|nil Force re-inspection even if recently updated
function ChronicleLog:QueueTalentInspection(unit, force)
    if not unit then return end

    local name = UnitName(unit)
    if not name then return end

    -- Skip self
    if UnitIsUnit(unit, "player") == 1 then return end

    -- Skip if recently updated (unless forced)
    if not force and talentLastUpdate[name] then
        if (GetTime() - talentLastUpdate[name]) < TALENT_REFRESH_INTERVAL then
            return
        end
    end

    -- Skip if already queued (compare by name since unit could be GUID or token)
    for _, queued in ipairs(inspectionQueue) do
        if UnitName(queued) == name then
            return
        end
    end

    table.insert(inspectionQueue, unit)
end

--- Process the next item in the inspection queue.
--- Called from OnUpdate; handles timeouts and combat safety.
function ChronicleLog:ProcessTalentQueue()
    if not self.enabled then return end

    local now = GetTime()

    -- Handle timeout on active inspection
    if inspectionActive and (now - lastRequestTime) > INSPECTION_TIMEOUT then
        Chronicle:DebugPrint("TalentInfoTimeout: " .. (currentTarget or "unknown"))
        inspectionActive = false
        currentTarget = nil
    end

    -- Don't start new inspections if one is active or we're in combat
    if inspectionActive then return end
    if UnitAffectingCombat("player") then return end

    -- Pop next unit from queue
    while table.getn(inspectionQueue) > 0 do
        local unit = table.remove(inspectionQueue, 1)
        local name = UnitName(unit)

        -- Skip if unit is gone, offline, or is self
        if name and UnitIsConnected(unit) and UnitIsUnit(unit, "player") ~= 1 then
            -- Skip if another check happened while queued
            if not talentLastUpdate[name] or (now - talentLastUpdate[name]) >= TALENT_REFRESH_INTERVAL then
                Chronicle:DebugPrint("RequestTalentInfo: " .. name)
                BeginInspection(name)
                return
            end
        end
    end
end

-- =============================================================================
-- Addon Message Handling
-- =============================================================================

--- Handle talent-related addon messages (INSTalentInfo / INSTalentEND).
--- Called from CHAT_MSG_ADDON dispatcher in units.lua.
---@param message string The addon message content
---@param sender string The sending player's name
function ChronicleLog:HandleTalentAddonMessage(message, sender)
    -- INSTalentEND marks the end of a talent dump
    if strfind(message, "^INSTalentEND") then
        if sender == currentTarget then
            inspectionActive = false
            currentTarget = nil
            talentLastUpdate[sender] = GetTime()

            -- Write single compact talent log line
            -- Format: COMBATANT_TALENTS|player|TabName1;points;rankDigits|TabName2;points;rankDigits|TabName3;points;rankDigits
            local t = talentInfo[sender]
            local tabs = talentTabInfo[sender]
            if t then
                local tabStrings = {}
                local summaryParts = {}
                for i = 1, 3 do
                    local ranks = t[i] or ""
                    local tabName = (tabs and tabs[i]) and tabs[i].name or ("Tree" .. i)
                    local points = (tabs and tabs[i]) and tabs[i].points or "0"
                    table.insert(tabStrings, tabName .. ";" .. points .. ";" .. ranks)
                    table.insert(summaryParts, points)
                end
                -- Resolve GUID from raid/party unit
                local guid = ""
                local numRaid = GetNumRaidMembers()
                if numRaid > 0 then
                    for i = 1, numRaid do
                        if UnitName("raid" .. i) == sender then
                            local _, g = UnitExists("raid" .. i)
                            guid = g or ""
                            break
                        end
                    end
                else
                    local numParty = GetNumPartyMembers()
                    for i = 1, numParty do
                        if UnitName("party" .. i) == sender then
                            local _, g = UnitExists("party" .. i)
                            guid = g or ""
                            break
                        end
                    end
                end
                self:Write("COMBATANT_TALENTS", guid, sender, tabStrings[1], tabStrings[2], tabStrings[3])
                Chronicle:DebugPrint("TalentInfoResult: " .. sender .. " " .. table.concat(summaryParts, "/"))
            else
                Chronicle:DebugPrint("TalentInfoResult: " .. sender .. " (no data)")
            end

            -- Re-write COMBATANT_INFO now that we have talents
            -- Find the unit ID for this player
            local numRaid = GetNumRaidMembers()
            if numRaid > 0 then
                for i = 1, numRaid do
                    if UnitName("raid" .. i) == sender then
                        self:WriteCombatantInfo("raid" .. i)
                        return
                    end
                end
            else
                local numParty = GetNumPartyMembers()
                for i = 1, numParty do
                    if UnitName("party" .. i) == sender then
                        self:WriteCombatantInfo("party" .. i)
                        return
                    end
                end
            end
        end
        return
    end

    -- Parse semicolon-delimited fields for both message types
    local parts = {}
    for part in string.gfind(message, "[^;]+") do
        table.insert(parts, part)
    end

    -- INSTalentTabInfo;tree;tabName;numTalents;pointsSpent
    if strfind(message, "^INSTalentTabInfo") then
        if sender ~= currentTarget then return end
        if table.getn(parts) >= 5 then
            local tree = tonumber(parts[2])
            if tree and tree >= 1 and tree <= 3 then
                if not talentTabInfo[sender] then
                    talentTabInfo[sender] = {}
                end
                talentTabInfo[sender][tree] = { name = parts[3], points = parts[5] }
            end
        end
        return
    end

    -- INSTalentInfo;tree;idx;name;tier;col;currRank;maxRank;meetsPrereq;prereqTree;prereqTalent;prereqRank
    if not strfind(message, "^INSTalentInfo") then return end

    -- Only accept data from the player we're currently inspecting
    if sender ~= currentTarget then return end

    -- Ensure we have storage initialized
    if not talentInfo[sender] then
        talentInfo[sender] = { "", "", "" }
    end

    if table.getn(parts) >= 7 then
        local tree = tonumber(parts[2])
        local currRank = tonumber(parts[7])
        if tree and tree >= 1 and tree <= 3 and currRank then
            talentInfo[sender][tree] = talentInfo[sender][tree] .. currRank
        end
    end
end

-- =============================================================================
-- Talent Data Access
-- =============================================================================

--- Returns cached talent string for a player, or empty string if unavailable.
---@param playerName string Player name
---@return string talents Format: "tree1}tree2}tree3" or ""
function ChronicleLog:GetCachedTalents(playerName)
    if not playerName or not talentInfo[playerName] then
        return ""
    end

    local t = talentInfo[playerName]
    local result = cstrjoin("}", t[1], t[2], t[3])

    -- Only return if meaningful (more than just separators)
    if strlen(result) > 10 then
        return result
    end
    return ""
end

-- =============================================================================
-- Periodic Refresh
-- =============================================================================

--- Queue all raid/party members for talent refresh (respects cooldown).
--- Called periodically from OnUpdate.
function ChronicleLog:QueueRaidTalentRefresh()
    local now = GetTime()
    if (now - lastRefreshCheck) < TALENT_REFRESH_INTERVAL then return end
    lastRefreshCheck = now

    local numRaid = GetNumRaidMembers()
    if numRaid > 0 then
        for i = 1, numRaid do
            local guid = GetUnitGUID("raid" .. i)
            if guid then
                self:QueueTalentInspection(guid)
            end
        end
    else
        local numParty = GetNumPartyMembers()
        for i = 1, numParty do
            local guid = GetUnitGUID("party" .. i)
            if guid then
                self:QueueTalentInspection(guid)
            end
        end
    end
end
