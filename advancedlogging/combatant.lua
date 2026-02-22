-- =============================================================================
-- ChronicleLog Combatant - Player-specific info (gear, talents, guild)
-- =============================================================================

-- =============================================================================
-- Helper Functions
-- =============================================================================

--- Derives the pet unit ID from a player unit ID.
--- Returns nil if the unit is already a pet or no pet unit exists.
---@param unit string Unit ID (e.g., "player", "raid5", "party2")
---@return string|nil petUnit The pet unit ID or nil
local function GetPetUnit(unit)
    if strfind(unit, "pet") then
        return nil  -- Already a pet unit
    end
    
    if unit == "player" then
        return "pet"
    elseif strfind(unit, "raid") then
        return "raidpet" .. strsub(unit, 5)
    elseif strfind(unit, "party") then
        return "partypet" .. strsub(unit, 6)
    end
    
    return nil
end

--- Extracts item string from an inventory item link.
--- Returns nil if no item or link parsing fails.
---@param link string|nil Item link from GetInventoryItemLink
---@return string|nil itemString The item string or nil
local function ParseItemLink(link)
    if not link then
        return nil
    end
    local found, _, itemString = strfind(link, "Hitem:(.+)|h%[")
    return found and itemString or nil
end

-- =============================================================================
-- Core Functions
-- =============================================================================

---@class CombatantInfo
---@field guid string Unit GUID
---@field name string Character name
---@field class string English class name
---@field race string English race name
---@field sex number 1=unknown, 2=male, 3=female
---@field guild_name string|nil Guild name
---@field guild_rank_name string|nil Guild rank name
---@field guild_rank_index number|nil Guild rank index
---@field pet_name string|nil Pet name
---@field pet_guid string|nil Pet GUID
---@field gear table Array of 19 item strings (nil for empty slots)
---@field talents string|nil Talent string (only for "player" unit)

--- Gathers combatant info for a player unit.
--- Returns nil if the unit is not a player or unavailable.
---@param unit string Unit ID or GUID
---@return CombatantInfo|nil info Combatant info table or nil
function ChronicleLog:GetCombatantInfo(unit)
    local exists, guid = UnitExists(unit)
    if not exists then
        return nil
    end
    
    if not UnitIsPlayer(unit) then
        return nil
    end
    
    local name = UnitName(unit)
    if not name then
        return nil
    end
    
    local info = {}
    info.guid = guid
    info.name = name
    
    -- Class, race, sex
    local _, englishClass = UnitClass(unit)
    info.class = englishClass or ""
    
    local _, englishRace = UnitRace(unit)
    info.race = englishRace or ""
    
    info.sex = UnitSex(unit) or 1
    
    -- Guild info
    local guildName, guildRankName, guildRankIndex = GetGuildInfo(unit)
    if guildName then
        info.guild_name = guildName
        info.guild_rank_name = guildRankName
        info.guild_rank_index = guildRankIndex
    end
    
    -- Pet info
    local petUnit = GetPetUnit(unit)
    if petUnit then
        local petExists, petGuid = UnitExists(petUnit)
        if petExists then
            local petName = UnitName(petUnit)
            if petName then
                info.pet_name = petName
                info.pet_guid = petGuid
            end
        end
    end
    
    -- Gear (19 slots)
    info.gear = {}
    local anyGear = false
    for i = 1, 19 do
        local link = GetInventoryItemLink(unit, i)
        if link then
            anyGear = true
            info.gear[i] = ParseItemLink(link)
        end
    end
    
    -- If no gear visible, leave gear table empty
    if not anyGear then
        info.gear = {}
    end
    
    -- Talents (only available for "player" unit)
    if UnitIsPlayer(unit) == 1 then
        local talents = { "", "", "" }
        for t = 1, 3 do
            local numTalents = GetNumTalents(t)
            for i = 1, numTalents do
                local _, _, _, _, currRank = GetTalentInfo(t, i)
                talents[t] = talents[t] .. (currRank or 0)
            end
        end
        local talentStr = strjoin("}", talents[1], talents[2], talents[3])
        -- Only include if meaningful (more than just separators)
        if strlen(talentStr) > 10 then
            info.talents = talentStr
        end
    end
    
    return info
end

--- Writes a COMBATANT_INFO log line for a player unit.
--- Does nothing if the unit is not a player or info unavailable.
---@param unit string Unit ID or GUID
function ChronicleLog:WriteCombatantInfo(unit)
    local info = self:GetCombatantInfo(unit)
    if not info then
        return
    end
    
    -- Build gear string: item1&item2&...&item19
    local gearParts = {}
    for i = 1, 19 do
        gearParts[i] = info.gear[i] or ""
    end
    local gearStr = table.concat(gearParts, "&")
    
    -- Write the log line
    self:Write("COMBATANT_INFO",
        info.guid,
        info.name,
        info.class,
        info.race,
        info.sex,
        info.guild_name or "",
        info.guild_rank_name or "",
        info.guild_rank_index or "",
        gearStr,
        info.talents or "",
        info.pet_name or "",
        info.pet_guid or ""
    )
end
