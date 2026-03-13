-- =============================================================================
-- ChronicleLog - Event-driven combat logging system
-- =============================================================================

---@class ChronicleLog
---@field enabled boolean Whether logging is currently active
---@field frame Frame Event listener frame
ChronicleLog = {
    enabled = false,
    frame = nil,
    buffer = {},       -- In-memory buffer for log lines
    bufferSize = 0,    -- Current number of lines in buffer
}

-- Delimiter for log output format: TIMESTAMP|EVENT_TYPE|field1|field2|...
local LOG_SEP = "|"

-- Events to listen for
ChronicleLog.events = {
    -- "UNIT_CASTEVENT",
    "UNIT_DIED",
    -- "PLAYER_REGEN_DISABLED",
    -- "PLAYER_REGEN_ENABLED",
    "AUTO_ATTACK_SELF",   -- Requires CVar NP_EnableAutoAttackEvents = 1
    "AUTO_ATTACK_OTHER",  -- Requires CVar NP_EnableAutoAttackEvents = 1
    "SPELL_HEAL_BY_SELF",  -- Requires CVar NP_EnableSpellHealEvents = 1
    "SPELL_HEAL_BY_OTHER", -- Requires CVar NP_EnableSpellHealEvents = 1
    "SPELL_HEAL_ON_SELF",  -- Requires CVar NP_EnableSpellHealEvents = 1
    "SPELL_ENERGIZE_BY_SELF",  -- Requires CVar NP_EnableSpellEnergizeEvents = 1
    "SPELL_ENERGIZE_BY_OTHER", -- Requires CVar NP_EnableSpellEnergizeEvents = 1
    "SPELL_ENERGIZE_ON_SELF",  -- Requires CVar NP_EnableSpellEnergizeEvents = 1
    "SPELL_MISS_SELF",         -- Your spells that missed/resisted/etc.
    "SPELL_MISS_OTHER",        -- Others' spells that missed/resisted/etc.
    "AURA_CAST_ON_SELF",       -- Requires CVar NP_EnableAuraCastEvents = 1
    "AURA_CAST_ON_OTHER",      -- Requires CVar NP_EnableAuraCastEvents = 1
    "BUFF_UPDATE_DURATION_SELF",   -- Buff duration refreshed on active player
    "DEBUFF_UPDATE_DURATION_SELF", -- Debuff duration refreshed on active player
    "BUFF_ADDED_SELF",             -- Buff added to active player
    "BUFF_REMOVED_SELF",           -- Buff removed from active player
    "BUFF_ADDED_OTHER",            -- Buff added to another unit
    "BUFF_REMOVED_OTHER",          -- Buff removed from another unit
    "DEBUFF_ADDED_SELF",           -- Debuff added to active player
    "DEBUFF_REMOVED_SELF",         -- Debuff removed from active player
    "DEBUFF_ADDED_OTHER",          -- Debuff added to another unit
    "DEBUFF_REMOVED_OTHER",        -- Debuff removed from another unit
    "SPELL_DAMAGE_EVENT_SELF",     -- Spell damage dealt by active player
    "SPELL_DAMAGE_EVENT_OTHER",    -- Spell damage dealt by others
    "SPELL_DELAYED_SELF",          -- Your spell was delayed (pushback)
    "SPELL_DELAYED_OTHER",         -- Other's spell was delayed (currently non-functional)
    "SPELL_CHANNEL_START",         -- Active player started channeling
    "SPELL_CHANNEL_UPDATE",        -- Active player channel time updated
    "SPELL_FAILED_SELF",           -- Active player's spell failed
    "SPELL_FAILED_OTHER",          -- Other's spell failed (limited info)
    "SPELL_GO_SELF",               -- Requires CVar NP_EnableSpellGoEvents = 1
    "SPELL_GO_OTHER",              -- Requires CVar NP_EnableSpellGoEvents = 1
    "SPELL_START_SELF",            -- Requires CVar NP_EnableSpellStartEvents = 1
    "SPELL_START_OTHER",           -- Requires CVar NP_EnableSpellStartEvents = 1

    -- Chat events
    "CHAT_MSG_LOOT",               -- Loot messages (arg1 = message)
    "CHAT_MSG_SYSTEM",             -- System messages (arg1 = message) - used for trade detection
    
    -- Session events
    "PLAYER_LEAVING_WORLD",        -- Flush logs on logout/disconnect/reload
}

-- =============================================================================
-- Core Setup
-- =============================================================================

--- Initializes the ChronicleLog system.
--- Creates the event frame and sets up the event dispatcher.
--- Must be called once during addon initialization.
function ChronicleLog:Init()
    -- Initialize config (merge defaults into SavedVariables)
    self:InitConfig()
    
    -- Store time offset for millisecond timestamps
    -- GetTime() returns session time with ms precision, time() returns unix seconds
    self.timeOffset = time() - GetTime()
    
    self.frame = CreateFrame("Frame", "ChronicleLogFrame")
    self.frame:SetScript("OnEvent", function()
        -- Always process zone changes (for auto-enable/disable even when logging is off)
        if event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ENTERING_WORLD" then
            -- Flush buffer on loading screens to prevent data loss
            if event == "PLAYER_ENTERING_WORLD" then
                ChronicleLog:FlushToFile()
            end
            ChronicleLog:ZONE_CHANGED_NEW_AREA()
            return
        end
        -- Other events only when enabled
        if ChronicleLog.enabled and ChronicleLog[event] then
            ChronicleLog[event](ChronicleLog, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9)
        end
    end)
    
    -- Always register zone events (needed for auto-enable even when logging is off)
    self.frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    self.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    
    -- Restore logging state from last session
    if self:GetSetting("enabled") then
        self:Enable()
    end
    
    -- Check dependencies and warn if any issues
    local problems = self:CheckDependencies()
    if table.getn(problems) > 0 then
        StaticPopup_Show("CHRONICLELOG_DEPENDENCY_WARNING", table.concat(problems, "\n"))
    end
end

--- Enables combat logging and registers all events.
--- Does nothing if already enabled.
function ChronicleLog:Enable()
    if self.enabled then return end
    self.enabled = true
    self:SetSetting("enabled", true)

    -- Enable required CVars for extended events
    SetCVar("NP_EnableAutoAttackEvents", 1)
    SetCVar("NP_EnableSpellHealEvents", 1)
    SetCVar("NP_EnableSpellEnergizeEvents", 1)
    SetCVar("NP_EnableAuraCastEvents", 1)
    SetCVar("NP_EnableSpellGoEvents", 1)
    SetCVar("NP_EnableSpellStartEvents", 1)

    for _, evt in ipairs(self.events) do
        self.frame:RegisterEvent(evt)
    end
end

--- Disables combat logging, unregisters all events, and writes buffer to file.
--- Does nothing if already disabled.
--- Returns the number of lines written to file.
---@return number linesWritten Number of lines written to file
function ChronicleLog:Disable()
    if not self.enabled then return 0 end
    self.enabled = false
    self:SetSetting("enabled", false)
    
    for _, evt in ipairs(self.events) do
        self.frame:UnregisterEvent(evt)
    end
    
    -- Write buffer to file on disable
    local linesWritten = self:FlushToFile()
    return linesWritten
end

function ChronicleLog:Toggle()
    if self.enabled then
        self:Disable()
    else
        self:Enable()
    end
end

--- Returns whether combat logging is currently enabled.
---@return boolean enabled True if logging is active
function ChronicleLog:IsEnabled()
    return self.enabled
end

-- =============================================================================
-- Log Output
-- =============================================================================

--- Generates a header string with player and version metadata.
--- Format: HEADER|playerGuid|realm|zone|addonVer|superWowVer|namPowerVer|xp3Ver|wowVer|wowBuild|wowBuildDate
---@return string header Pipe-delimited header line
function ChronicleLog:GenerateHeader()
    -- Player info
    local _, playerGuid = UnitExists("player")
    playerGuid = playerGuid or ""
    local realm = GetRealmName() or ""
    local zone = GetRealZoneText() or ""
    
    -- Addon versions
    local addonVersion = GetAddOnMetadata("ChronicleCompanion", "Version") or ""
    local superWowVersion = SUPERWOW_VERSION or ""
    local namPowerVersion = NAMPOWER_VERSION or ""
    
    -- UnitXP3 version (returns build timestamp)
    local xp3Version = ""
    local xp3ok, xp3buildTime = pcall(UnitXP, "version", "coffTimeDateStamp")
    if xp3ok and xp3buildTime then
        xp3Version = tostring(xp3buildTime)
    end
    
    -- WoW client version
    local wowVersion, wowBuild, wowBuildDate = GetBuildInfo()
    wowVersion = wowVersion or ""
    wowBuild = wowBuild or ""
    wowBuildDate = wowBuildDate or ""
    
    -- Clock info (local and UTC)
    local ts = time()
    local localTime = date("%d.%m.%y %H:%M:%S", ts)
    local utcTime = date("!%d.%m.%y %H:%M:%S", ts)
    
    -- Combat log range
    local combatLogRange = GetCVar("CombatLogRangeCreature") or ""
    
    local parts = {
        "HEADER",
        playerGuid,
        realm,
        zone,
        addonVersion,
        superWowVersion,
        namPowerVersion,
        xp3Version,
        wowVersion,
        wowBuild,
        wowBuildDate,
        localTime,
        utcTime,
        combatLogRange
    }
    
    return table.concat(parts, LOG_SEP)
end

--- Writes the header line to the buffer.
--- Call this on zone changes to record session metadata.
function ChronicleLog:WriteHeader()
    local header = "0" .. LOG_SEP .. self:GenerateHeader()
    self.bufferSize = self.bufferSize + 1
    self.buffer[self.bufferSize] = header
end

--- Formats a log line and appends it to the in-memory buffer.
--- Output format: TIMESTAMP|EVENT_TYPE|field1|field2|...
--- Uses Lua 5.0 vararg style (arg table) for Vanilla WoW compatibility.
--- Buffer is written to file when logging is disabled via ChronicleLog:Disable().
---@param eventType string Event type code (SWING, CAST, DEATH, COMBAT_START, COMBAT_END, RAW)
function ChronicleLog:Write(eventType, ...)
    -- Millisecond timestamp: combine GetTime() precision with unix offset
    local timestamp = math.floor((GetTime() + self.timeOffset) * 1000)
    local parts = { timestamp, eventType }
    for i = 1, arg.n do
        local v = arg[i]
        parts[table.getn(parts) + 1] = v ~= nil and tostring(v) or ""
    end
    local line = table.concat(parts, LOG_SEP)
    
    -- Append to in-memory buffer
    self.bufferSize = self.bufferSize + 1
    self.buffer[self.bufferSize] = line
end

--- Clears the in-memory buffer.
function ChronicleLog:ClearBuffer()
    self.buffer = {}
    self.bufferSize = 0
end

--- Returns the current buffer size (number of log lines).
---@return number size Number of lines in buffer
function ChronicleLog:GetBufferSize()
    return self.bufferSize
end

--- Writes the in-memory buffer to a file and clears the buffer.
--- Appends to existing file content (reads via ImportFile first).
--- Filename: Chronicle_<CharacterName>.txt
---@return number linesWritten Number of new lines written
function ChronicleLog:FlushToFile()
    if self.bufferSize == 0 then
        return 0
    end
    
    -- Generate header line to prepend (timestamp 0 since it covers the whole flush)
    local header = "0" .. LOG_SEP .. self:GenerateHeader()
    
    -- Generate filename based on character name
    local playerName = UnitName("player") or "Unknown"
    local filename = "Chronicle_" .. playerName
    
    -- Read existing file content
    local existingContent = ""
    if ImportFile then
        existingContent = ImportFile(filename) or ""
    end
    
    -- Join buffer lines with newlines, prepend header
    local bufferContent = table.concat(self.buffer, "\n")
    local newContent = header .. "\n" .. bufferContent
    
    -- Append new content (add newline separator if existing content exists)
    local finalContent
    if existingContent ~= "" then
        finalContent = existingContent .. "\n" .. newContent
    else
        finalContent = newContent
    end
    
    -- Write combined content to file
    if ExportFile then
        ExportFile(filename, finalContent)
        Chronicle:Print("Appended " .. self.bufferSize .. " lines to " .. filename)
    else
        Chronicle:Print("ExportFile not available (requires SuperWoW)")
    end
    
    local written = self.bufferSize
    self:ClearBuffer()
    return written
end

--- Copy file
---@param origFilename string filename of original version
---@param destFilename string filename of copied version
function ChronicleLog:CopyFile(origFilename, destFilename)
    if not ExportFile or not ImportFile then
        Chronicle:Print("ExportFile/ImportFile not available (requires SuperWoW)")
        return
    end

    ExportFile(destFilename, ImportFile(origFilename));
end

-- =============================================================================
-- Event Handlers
-- =============================================================================

--- Handles ZONE_CHANGED_NEW_AREA events every time the zone changes.
--- Handles auto-enable/disable and reminder popups, then logs zone info.
function ChronicleLog:ZONE_CHANGED_NEW_AREA()
    -- Close options panel on zone change (avoids stale state display)
    if self.optionsPanel and self.optionsPanel:IsShown() then
        self.optionsPanel:Hide()
    end
    
    -- Get zone name and find instance ID from saved instances
    local zoneName = GetRealZoneText() or ""
    local zoneLower = strlower(zoneName)
    local instanceId = 0
    
    for i = 1, GetNumSavedInstances() do
        local instanceName, savedId = GetSavedInstanceInfo(i)
        if zoneLower == strlower(instanceName) then
            instanceId = savedId
            break
        end
    end
    
    -- IsInInstance returns: inInstance (1/nil), instanceType (string)
    local inInstance, instanceType = IsInInstance()
    local isInInstance = inInstance and true or false
    local isRaid = instanceType == "raid"
    local isDungeon = instanceType == "party"
    
    -- Check auto-enable settings
    local autoEnableRaid = self:GetSetting("autoEnableInRaid")
    local autoEnableDungeon = self:GetSetting("autoEnableInDungeon")
    local showReminder = self:GetSetting("showLogReminder")
    local logging = self:IsEnabled()
    
    -- Debug output
    Chronicle:DebugPrint("Zone: " .. zoneName .. ", inInstance: " .. tostring(isInInstance) .. ", type: " .. tostring(instanceType))
    Chronicle:DebugPrint("autoRaid: " .. tostring(autoEnableRaid) .. ", autoDungeon: " .. tostring(autoEnableDungeon) .. ", showReminder: " .. tostring(showReminder) .. ", logging: " .. tostring(logging))
    
    if isInInstance then
        -- Entering an instance
        local shouldAutoEnable = (isRaid and autoEnableRaid) or (isDungeon and autoEnableDungeon)
        
        if shouldAutoEnable then
            if not logging then
                self:Enable()
                Chronicle:Print("ChronicleLog enabled (entered " .. (isRaid and "raid" or "dungeon") .. ")")
            end
        elseif showReminder and not logging then
            -- Show reminder popup
            StaticPopupDialogs["CHRONICLELOG_ENABLE_REMINDER"] = {
                text = "You entered an instance but ChronicleLog is disabled. Enable logging?",
                button1 = "Enable",
                button2 = "No",
                OnAccept = function()
                    ChronicleLog:Enable()
                    Chronicle:Print("ChronicleLog enabled.")
                end,
                timeout = 30,
                whileDead = true,
                hideOnEscape = true,
            }
            StaticPopup_Show("CHRONICLELOG_ENABLE_REMINDER")
        end
    else
        -- Leaving an instance
        local wasAutoEnabled = (autoEnableRaid or autoEnableDungeon)
        
        if wasAutoEnabled and logging then
            self:Disable()
            Chronicle:Print("ChronicleLog disabled (left instance)")
        elseif showReminder and logging then
            -- Show reminder popup
            StaticPopupDialogs["CHRONICLELOG_DISABLE_REMINDER"] = {
                text = "You left the instance but ChronicleLog is still enabled. Disable logging?",
                button1 = "Disable",
                button2 = "No",
                OnAccept = function()
                    ChronicleLog:Disable()
                    Chronicle:Print("ChronicleLog disabled.")
                end,
                timeout = 30,
                whileDead = true,
                hideOnEscape = true,
            }
            StaticPopup_Show("CHRONICLELOG_DISABLE_REMINDER")
        end
    end
    
    -- Log zone info and purge units if enabled
    self:WriteZoneInfo(true)
    if self:IsEnabled() then
        self:PurgeUnits()
    end
end

--- Writes zone info to the log buffer.
--- Call this after clearing logs to provide context for new entries.
function ChronicleLog:WriteZoneInfo(force)
    if not force and not self:IsEnabled() then return end
    
    local zoneName = GetRealZoneText() or ""
    local zoneLower = strlower(zoneName)
    local instanceId = 0
    
    for i = 1, GetNumSavedInstances() do
        local instanceName, savedId = GetSavedInstanceInfo(i)
        if zoneLower == strlower(instanceName) then
            instanceId = savedId
            break
        end
    end
    
    local inInstance, instanceType = IsInInstance()
    local inInstanceNum = inInstance and 1 or 0
    instanceType = instanceType or "none"
    local isGhost = UnitIsGhost("player") and 1 or 0
    
    self:WriteHeader()
    self:Write("ZONE_INFO", zoneName, instanceId, inInstanceNum, instanceType, isGhost)
end

--- Handles UNIT_CASTEVENT events.
--- Called when a unit starts, finishes, fails, or channels a cast.
--- Also fires for melee swings (MAINHAND/OFFHAND).
--- Writes a CAST event with caster, target, event type, spell ID, and duration.
---@param casterGUID string GUID of the caster
---@param targetGUID string GUID of the target (may be empty)
---@param eventType string "START", "CAST", "FAIL", "CHANNEL", "MAINHAND", "OFFHAND"
---@param spellId number Spell ID
---@param duration number Cast duration in milliseconds
function ChronicleLog:UNIT_CASTEVENT(casterGUID, targetGUID, eventType, spellId, duration)
    self:Write("CAST", casterGUID, targetGUID, eventType, spellId, duration)
end

--- Handles UNIT_DIED events.
--- Called when any unit dies.
--- Writes a DEATH event with the unit's GUID.
---@param guid string GUID of the unit that died
function ChronicleLog:UNIT_DIED(guid)
    self:CheckUnit(guid)
    self:Write("DEATH", guid)
end

--- Handles PLAYER_REGEN_DISABLED events.
--- Called when the player enters combat (loses regen).
--- Writes a COMBAT_START event with no additional fields.
function ChronicleLog:PLAYER_REGEN_DISABLED()
    self:Write("COMBAT_START")
end

--- Handles PLAYER_REGEN_ENABLED events.
--- Called when the player leaves combat (regains regen).
--- Writes a COMBAT_END event with no additional fields.
function ChronicleLog:PLAYER_REGEN_ENABLED()
    self:Write("COMBAT_END")
end

--- Handles AUTO_ATTACK_SELF events.
--- Called when the active player's auto attack damage is processed.
--- Requires CVar: /run SetCVar("NP_EnableAutoAttackEvents", 1)
--- Writes a SWING event with all attack details.
---@param attackerGuid string Attacker GUID (e.g., "0xF5300000000000A5")
---@param targetGuid string Target GUID
---@param totalDamage number Total damage dealt
---@param hitInfo number Bitfield containing hit flags (critical, glancing, crushing, etc.)
---@param victimState number State of victim after attack (dodged, parried, blocked, etc.)
---@param subDamageCount number Number of damage components (1-3, for elemental weapons)
---@param blockedAmount number Amount of damage blocked
---@param totalAbsorb number Total damage absorbed
---@param totalResist number Total damage resisted
function ChronicleLog:AUTO_ATTACK_SELF(attackerGuid, targetGuid, totalDamage, hitInfo, victimState, subDamageCount, blockedAmount, totalAbsorb, totalResist)
    self:CheckUnit(attackerGuid)
    self:CheckUnit(targetGuid)
    self:Write("SWING", attackerGuid, targetGuid, totalDamage, hitInfo, victimState, subDamageCount, blockedAmount, totalAbsorb, totalResist)
end

--- Handles AUTO_ATTACK_OTHER events.
--- Called when someone other than the active player's auto attack damage is processed.
--- Requires CVar: /run SetCVar("NP_EnableAutoAttackEvents", 1)
--- Writes a SWING event with all attack details.
--- https://gitea.com/avitasia/nampower/src/branch/master/EVENTS.md#auto_attack_self-and-auto_attack_other
---@param attackerGuid string Attacker GUID (e.g., "0xF5300000000000A5")
---@param targetGuid string Target GUID
---@param totalDamage number Total damage dealt
---@param hitInfo number Bitfield containing hit flags (critical, glancing, crushing, etc.)
---@param victimState number State of victim after attack (dodged, parried, blocked, etc.)
---@param subDamageCount number Number of damage components (1-3, for elemental weapons)
---@param blockedAmount number Amount of damage blocked
---@param totalAbsorb number Total damage absorbed
---@param totalResist number Total damage resisted
function ChronicleLog:AUTO_ATTACK_OTHER(attackerGuid, targetGuid, totalDamage, hitInfo, victimState, subDamageCount, blockedAmount, totalAbsorb, totalResist)
    self:CheckUnit(attackerGuid)
    self:CheckUnit(targetGuid)
    self:Write("SWING", attackerGuid, targetGuid, totalDamage, hitInfo, victimState, subDamageCount, blockedAmount, totalAbsorb, totalResist)
end

--- Handles SPELL_HEAL_BY_SELF events.
--- Called when the active player casts a heal on any target.
--- Requires CVar: SetCVar("NP_EnableSpellHealEvents", 1)
--- Writes a HEAL event with target, caster, spell, amount, and flags.
--- Note: Can fire alongside SPELL_HEAL_ON_SELF if you heal yourself.
--- https://gitea.com/avitasia/nampower/src/branch/master/EVENTS.md#spell_heal_by_self-spell_heal_by_other-and-spell_heal_on_self
---@param targetGuid string GUID of the heal target
---@param casterGuid string GUID of the healer (active player)
---@param spellId number Spell ID that caused the heal
---@param amount number Amount healed
---@param critical number 1 if critical heal, 0 otherwise
---@param periodic number 1 if from periodic aura (HoT tick), 0 otherwise
function ChronicleLog:SPELL_HEAL_BY_SELF(targetGuid, casterGuid, spellId, amount, critical, periodic)
    self:CheckUnit(targetGuid)
    self:CheckUnit(casterGuid)
    self:Write("HEAL", targetGuid, casterGuid, spellId, amount, critical, periodic)
end

--- Handles SPELL_HEAL_BY_OTHER events.
--- Called when someone other than the active player casts a heal.
--- Requires CVar: SetCVar("NP_EnableSpellHealEvents", 1)
--- Writes a HEAL event with target, caster, spell, amount, and flags.
--- https://gitea.com/avitasia/nampower/src/branch/master/EVENTS.md#spell_heal_by_self-spell_heal_by_other-and-spell_heal_on_self
---@param targetGuid string GUID of the heal target
---@param casterGuid string GUID of the healer
---@param spellId number Spell ID that caused the heal
---@param amount number Amount healed
---@param critical number 1 if critical heal, 0 otherwise
---@param periodic number 1 if from periodic aura (HoT tick), 0 otherwise
function ChronicleLog:SPELL_HEAL_BY_OTHER(targetGuid, casterGuid, spellId, amount, critical, periodic)
    self:CheckUnit(targetGuid)
    self:CheckUnit(casterGuid)
    self:Write("HEAL", targetGuid, casterGuid, spellId, amount, critical, periodic)
end

--- Handles SPELL_HEAL_ON_SELF events.
--- Called when the active player receives a heal from any source.
--- Requires CVar: SetCVar("NP_EnableSpellHealEvents", 1)
--- Writes a HEAL event with target, caster, spell, amount, and flags.
--- Note: Can fire alongside SPELL_HEAL_BY_SELF if you heal yourself.
--- https://gitea.com/avitasia/nampower/src/branch/master/EVENTS.md#spell_heal_by_self-spell_heal_by_other-and-spell_heal_on_self
---@param targetGuid string GUID of the heal target (active player)
---@param casterGuid string GUID of the healer
---@param spellId number Spell ID that caused the heal
---@param amount number Amount healed
---@param critical number 1 if critical heal, 0 otherwise
---@param periodic number 1 if from periodic aura (HoT tick), 0 otherwise
function ChronicleLog:SPELL_HEAL_ON_SELF(targetGuid, casterGuid, spellId, amount, critical, periodic)
    -- self:CheckUnit(targetGuid)
    -- self:CheckUnit(casterGuid)
    -- Caught by the other
    -- self:Write("HEAL", targetGuid, casterGuid, spellId, amount, critical, periodic)
end

--- Handles SPELL_ENERGIZE_BY_SELF events.
--- Called when the active player restores power (mana, rage, energy, etc.) to any target.
--- Requires CVar: SetCVar("NP_EnableSpellEnergizeEvents", 1)
--- Writes an ENERGIZE event with target, caster, spell, power type, amount, and flags.
--- Note: Can fire alongside SPELL_ENERGIZE_ON_SELF if you restore power to yourself.
--- Power types: 0=Mana, 1=Rage, 2=Focus, 3=Energy, 4=Happiness, -2=Health
--- https://gitea.com/avitasia/nampower/src/branch/master/EVENTS.md#spell_energize_by_self-spell_energize_by_other-and-spell_energize_on_self
---@param targetGuid string GUID of the power recipient
---@param casterGuid string GUID of the caster (active player)
---@param spellId number Spell ID that caused the energize
---@param powerType number Power type (0=Mana, 1=Rage, 2=Focus, 3=Energy, 4=Happiness, -2=Health)
---@param amount number Amount of power restored
---@param periodic number 1 if from periodic aura, 0 otherwise
function ChronicleLog:SPELL_ENERGIZE_BY_SELF(targetGuid, casterGuid, spellId, powerType, amount, periodic)
    self:CheckUnit(targetGuid)
    self:CheckUnit(casterGuid)
    self:Write("ENERGIZE", targetGuid, casterGuid, spellId, powerType, amount, periodic)
end

--- Handles SPELL_ENERGIZE_BY_OTHER events.
--- Called when someone other than the active player restores power.
--- Requires CVar: SetCVar("NP_EnableSpellEnergizeEvents", 1)
--- Writes an ENERGIZE event with target, caster, spell, power type, amount, and flags.
--- Power types: 0=Mana, 1=Rage, 2=Focus, 3=Energy, 4=Happiness, -2=Health
--- https://gitea.com/avitasia/nampower/src/branch/master/EVENTS.md#spell_energize_by_self-spell_energize_by_other-and-spell_energize_on_self
---@param targetGuid string GUID of the power recipient
---@param casterGuid string GUID of the caster
---@param spellId number Spell ID that caused the energize
---@param powerType number Power type (0=Mana, 1=Rage, 2=Focus, 3=Energy, 4=Happiness, -2=Health)
---@param amount number Amount of power restored
---@param periodic number 1 if from periodic aura, 0 otherwise
function ChronicleLog:SPELL_ENERGIZE_BY_OTHER(targetGuid, casterGuid, spellId, powerType, amount, periodic)
    self:CheckUnit(targetGuid)
    self:CheckUnit(casterGuid)
    self:Write("ENERGIZE", targetGuid, casterGuid, spellId, powerType, amount, periodic)
end

--- Handles SPELL_ENERGIZE_ON_SELF events.
--- Called when the active player receives power restoration from any source.
--- Requires CVar: SetCVar("NP_EnableSpellEnergizeEvents", 1)
--- Writes an ENERGIZE event with target, caster, spell, power type, amount, and flags.
--- Note: Can fire alongside SPELL_ENERGIZE_BY_SELF if you restore power to yourself.
--- Power types: 0=Mana, 1=Rage, 2=Focus, 3=Energy, 4=Happiness, -2=Health
--- https://gitea.com/avitasia/nampower/src/branch/master/EVENTS.md#spell_energize_by_self-spell_energize_by_other-and-spell_energize_on_self
---@param targetGuid string GUID of the power recipient (active player)
---@param casterGuid string GUID of the caster
---@param spellId number Spell ID that caused the energize
---@param powerType number Power type (0=Mana, 1=Rage, 2=Focus, 3=Energy, 4=Happiness, -2=Health)
---@param amount number Amount of power restored
---@param periodic number 1 if from periodic aura, 0 otherwise
function ChronicleLog:SPELL_ENERGIZE_ON_SELF(targetGuid, casterGuid, spellId, powerType, amount, periodic)
    -- self:CheckUnit(targetGuid)
    -- self:CheckUnit(casterGuid)
    -- self:Write("ENERGIZE", targetGuid, casterGuid, spellId, powerType, amount, periodic)
end

--- Handles SPELL_MISS_SELF events.
--- Called when the active player's spell misses, is resisted, dodged, parried, etc.
--- Triggered by SMSG_SPELL_GO, SMSG_SPELLLOGMISS, SMSG_PROCRESIST, SMSG_SPELLORDAMAGE_IMMUNE.
--- Writes a MISS event with caster, target, spell ID, and miss type.
--- Miss types: 0=None, 1=Miss, 2=Resist, 3=Dodge, 4=Parry, 5=Block, 6=Evade,
---             7=Immune, 8=Immune2, 9=Deflect, 10=Absorb, 11=Reflect
---@param casterGuid string GUID of the caster (active player)
---@param targetGuid string GUID of the target
---@param spellId number Spell ID that missed
---@param missInfo number Miss type (see SpellMissInfo constants)
function ChronicleLog:SPELL_MISS_SELF(casterGuid, targetGuid, spellId, missInfo)
    self:CheckUnit(casterGuid)
    self:CheckUnit(targetGuid)
    self:Write("MISS", casterGuid, targetGuid, spellId, missInfo)
end

--- Handles SPELL_MISS_OTHER events.
--- Called when someone other than the active player's spell misses, is resisted, etc.
--- Triggered by SMSG_SPELL_GO, SMSG_SPELLLOGMISS, SMSG_PROCRESIST, SMSG_SPELLORDAMAGE_IMMUNE.
--- Writes a MISS event with caster, target, spell ID, and miss type.
--- Miss types: 0=None, 1=Miss, 2=Resist, 3=Dodge, 4=Parry, 5=Block, 6=Evade,
---             7=Immune, 8=Immune2, 9=Deflect, 10=Absorb, 11=Reflect
---@param casterGuid string GUID of the caster
---@param targetGuid string GUID of the target
---@param spellId number Spell ID that missed
---@param missInfo number Miss type (see SpellMissInfo constants)
function ChronicleLog:SPELL_MISS_OTHER(casterGuid, targetGuid, spellId, missInfo)
    self:CheckUnit(casterGuid)
    self:CheckUnit(targetGuid)
    self:Write("MISS", casterGuid, targetGuid, spellId, missInfo)
end

--- Handles AURA_CAST_ON_SELF events.
--- Called when a spell cast applies an aura to the active player.
--- Includes cases where active player is caster with no explicit target.
--- Requires CVar: SetCVar("NP_EnableAuraCastEvents", 1)
--- Note: Some auras without spell effects won't trigger this; use BUFF/DEBUFF gain events instead.
--- Fires once per qualifying spell effect per target (AOE spells fire multiple times).
---@param spellId number Spell ID
---@param casterGuid string GUID of the caster
---@param targetGuid string GUID of the target (active player)
---@param effect number Aura-applying effect ID
---@param effectAuraName number Entry from EffectApplyAuraName
---@param effectAmplitude number EffectAmplitude for the aura effect
---@param effectMiscValue number EffectMiscValue for the aura effect
---@param durationMs number Spell duration in milliseconds (includes client modifiers if you're caster)
---@param auraCapStatus number Bitfield: 1=buff bar full, 2=debuff bar full, 3=both
function ChronicleLog:AURA_CAST_ON_SELF(spellId, casterGuid, targetGuid, effect, effectAuraName, effectAmplitude, effectMiscValue, durationMs, auraCapStatus)
    self:CheckUnit(casterGuid)
    self:CheckUnit(targetGuid)
    self:Write("AURA_CAST", spellId, casterGuid, targetGuid, effect, effectAuraName, effectAmplitude, effectMiscValue, durationMs, auraCapStatus)
end

--- Handles AURA_CAST_ON_OTHER events.
--- Called when a spell cast applies an aura to someone other than the active player.
--- Requires CVar: SetCVar("NP_EnableAuraCastEvents", 1)
--- Note: Some auras without spell effects won't trigger this; use BUFF/DEBUFF gain events instead.
--- Fires once per qualifying spell effect per target (AOE spells fire multiple times).
---@param spellId number Spell ID
---@param casterGuid string GUID of the caster
---@param targetGuid string GUID of the target
---@param effect number Aura-applying effect ID
---@param effectAuraName number Entry from EffectApplyAuraName
---@param effectAmplitude number EffectAmplitude for the aura effect
---@param effectMiscValue number EffectMiscValue for the aura effect
---@param durationMs number Spell duration in milliseconds (includes client modifiers if you're caster)
---@param auraCapStatus number Bitfield: 1=buff bar full, 2=debuff bar full, 3=both
function ChronicleLog:AURA_CAST_ON_OTHER(spellId, casterGuid, targetGuid, effect, effectAuraName, effectAmplitude, effectMiscValue, durationMs, auraCapStatus)
    self:CheckUnit(casterGuid)
    self:CheckUnit(targetGuid)
    self:Write("AURA_CAST", spellId, casterGuid, targetGuid, effect, effectAuraName, effectAmplitude, effectMiscValue, durationMs, auraCapStatus)
end

--- Handles BUFF_UPDATE_DURATION_SELF events.
--- Called when the client updates the duration of a buff on the active player.
--- Fires when server refreshes an aura's duration (e.g., reapplying existing buff).
--- Note: Fires before aura is added to unit fields, so spellId=0 for new auras.
--- Use BUFF_ADDED_SELF for tracking newly applied auras.
--- Aura slot range: 0-31 for buffs.
---@param auraSlot number Raw 0-based aura slot index (0-31 for buffs)
---@param durationMs number Updated duration in milliseconds
---@param expirationTimeMs number Calculated expiration time (GetWowTimeMs() + durationMs), or 0 if no duration
---@param spellId number Spell ID of aura in slot (0 for new auras, >0 for refreshed auras)
function ChronicleLog:BUFF_UPDATE_DURATION_SELF(auraSlot, durationMs, expirationTimeMs, spellId)
    -- self:Write("BUFF_DURATION", auraSlot, durationMs, expirationTimeMs, spellId)
end

--- Handles DEBUFF_UPDATE_DURATION_SELF events.
--- Called when the client updates the duration of a debuff on the active player.
--- Fires when server refreshes an aura's duration (e.g., reapplying existing debuff).
--- Note: Fires before aura is added to unit fields, so spellId=0 for new auras.
--- Use DEBUFF_ADDED_SELF for tracking newly applied auras.
--- Aura slot range: 32-47 for debuffs.
---@param auraSlot number Raw 0-based aura slot index (32-47 for debuffs)
---@param durationMs number Updated duration in milliseconds
---@param expirationTimeMs number Calculated expiration time (GetWowTimeMs() + durationMs), or 0 if no duration
---@param spellId number Spell ID of aura in slot (0 for new auras, >0 for refreshed auras)
function ChronicleLog:DEBUFF_UPDATE_DURATION_SELF(auraSlot, durationMs, expirationTimeMs, spellId)
    -- self:Write("DEBUFF_DURATION", auraSlot, durationMs, expirationTimeMs, spellId)
end

--- Handles BUFF_ADDED_SELF events.
--- Called when a buff is added to the active player.
--- State: 0=newly added, 2=modified (stack increased).
---@param guid string GUID of the unit (active player)
---@param luaSlot number 1-based Lua slot index (matches UnitBuff ordering)
---@param spellId number Spell ID of the buff
---@param stackCount number Current stack count
---@param auraLevel number Caster level from UnitFields.auraLevels
---@param auraSlot number Raw 0-based aura slot index (0-31 for buffs)
---@param state number 0=added, 1=removed, 2=modified (stack change)
function ChronicleLog:BUFF_ADDED_SELF(guid, luaSlot, spellId, stackCount, auraLevel, auraSlot, state)
    self:CheckUnit(guid)
    self:Write("BUFF_ADD", guid, luaSlot, spellId, stackCount, auraLevel, auraSlot, state)
end

--- Handles BUFF_REMOVED_SELF events.
--- Called when a buff is removed from the active player.
--- State: 1=newly removed, 2=modified (stack decreased).
---@param guid string GUID of the unit (active player)
---@param luaSlot number 1-based Lua slot index (matches UnitBuff ordering)
---@param spellId number Spell ID of the buff
---@param stackCount number Current stack count
---@param auraLevel number Caster level from UnitFields.auraLevels
---@param auraSlot number Raw 0-based aura slot index (0-31 for buffs)
---@param state number 0=added, 1=removed, 2=modified (stack change)
function ChronicleLog:BUFF_REMOVED_SELF(guid, luaSlot, spellId, stackCount, auraLevel, auraSlot, state)
    self:CheckUnit(guid)
    self:Write("BUFF_REM", guid, luaSlot, spellId, stackCount, auraLevel, auraSlot, state)
end

--- Handles BUFF_ADDED_OTHER events.
--- Called when a buff is added to a unit other than the active player.
--- State: 0=newly added, 2=modified (stack increased).
---@param guid string GUID of the unit
---@param luaSlot number 1-based Lua slot index (matches UnitBuff ordering)
---@param spellId number Spell ID of the buff
---@param stackCount number Current stack count
---@param auraLevel number Caster level from UnitFields.auraLevels
---@param auraSlot number Raw 0-based aura slot index (0-31 for buffs)
---@param state number 0=added, 1=removed, 2=modified (stack change)
function ChronicleLog:BUFF_ADDED_OTHER(guid, luaSlot, spellId, stackCount, auraLevel, auraSlot, state)
    self:CheckUnit(guid)
    self:Write("BUFF_ADD", guid, luaSlot, spellId, stackCount, auraLevel, auraSlot, state)
end

--- Handles BUFF_REMOVED_OTHER events.
--- Called when a buff is removed from a unit other than the active player.
--- State: 1=newly removed, 2=modified (stack decreased).
---@param guid string GUID of the unit
---@param luaSlot number 1-based Lua slot index (matches UnitBuff ordering)
---@param spellId number Spell ID of the buff
---@param stackCount number Current stack count
---@param auraLevel number Caster level from UnitFields.auraLevels
---@param auraSlot number Raw 0-based aura slot index (0-31 for buffs)
---@param state number 0=added, 1=removed, 2=modified (stack change)
function ChronicleLog:BUFF_REMOVED_OTHER(guid, luaSlot, spellId, stackCount, auraLevel, auraSlot, state)
    self:CheckUnit(guid)
    self:Write("BUFF_REM", guid, luaSlot, spellId, stackCount, auraLevel, auraSlot, state)
end

--- Handles DEBUFF_ADDED_SELF events.
--- Called when a debuff is added to the active player.
--- State: 0=newly added, 2=modified (stack increased).
---@param guid string GUID of the unit (active player)
---@param luaSlot number 1-based Lua slot index (matches UnitDebuff ordering)
---@param spellId number Spell ID of the debuff
---@param stackCount number Current stack count
---@param auraLevel number Caster level from UnitFields.auraLevels
---@param auraSlot number Raw 0-based aura slot index (32-47 for debuffs)
---@param state number 0=added, 1=removed, 2=modified (stack change)
function ChronicleLog:DEBUFF_ADDED_SELF(guid, luaSlot, spellId, stackCount, auraLevel, auraSlot, state)
    self:CheckUnit(guid)
    self:Write("DEBUFF_ADD", guid, luaSlot, spellId, stackCount, auraLevel, auraSlot, state)
end

--- Handles DEBUFF_REMOVED_SELF events.
--- Called when a debuff is removed from the active player.
--- State: 1=newly removed, 2=modified (stack decreased).
---@param guid string GUID of the unit (active player)
---@param luaSlot number 1-based Lua slot index (matches UnitDebuff ordering)
---@param spellId number Spell ID of the debuff
---@param stackCount number Current stack count
---@param auraLevel number Caster level from UnitFields.auraLevels
---@param auraSlot number Raw 0-based aura slot index (32-47 for debuffs)
---@param state number 0=added, 1=removed, 2=modified (stack change)
function ChronicleLog:DEBUFF_REMOVED_SELF(guid, luaSlot, spellId, stackCount, auraLevel, auraSlot, state)
    self:CheckUnit(guid)
    self:Write("DEBUFF_REM", guid, luaSlot, spellId, stackCount, auraLevel, auraSlot, state)
end

--- Handles DEBUFF_ADDED_OTHER events.
--- Called when a debuff is added to a unit other than the active player.
--- State: 0=newly added, 2=modified (stack increased).
---@param guid string GUID of the unit
---@param luaSlot number 1-based Lua slot index (matches UnitDebuff ordering)
---@param spellId number Spell ID of the debuff
---@param stackCount number Current stack count
---@param auraLevel number Caster level from UnitFields.auraLevels
---@param auraSlot number Raw 0-based aura slot index (32-47 for debuffs)
---@param state number 0=added, 1=removed, 2=modified (stack change)
function ChronicleLog:DEBUFF_ADDED_OTHER(guid, luaSlot, spellId, stackCount, auraLevel, auraSlot, state)
    self:CheckUnit(guid)
    self:Write("DEBUFF_ADD", guid, luaSlot, spellId, stackCount, auraLevel, auraSlot, state)
end

--- Handles DEBUFF_REMOVED_OTHER events.
--- Called when a debuff is removed from a unit other than the active player.
--- State: 1=newly removed, 2=modified (stack decreased).
---@param guid string GUID of the unit
---@param luaSlot number 1-based Lua slot index (matches UnitDebuff ordering)
---@param spellId number Spell ID of the debuff
---@param stackCount number Current stack count
---@param auraLevel number Caster level from UnitFields.auraLevels
---@param auraSlot number Raw 0-based aura slot index (32-47 for debuffs)
---@param state number 0=added, 1=removed, 2=modified (stack change)
function ChronicleLog:DEBUFF_REMOVED_OTHER(guid, luaSlot, spellId, stackCount, auraLevel, auraSlot, state)
    self:CheckUnit(guid)
    self:Write("DEBUFF_REM", guid, luaSlot, spellId, stackCount, auraLevel, auraSlot, state)
end

--- Handles SPELL_DAMAGE_EVENT_SELF events.
--- Called when the active player deals spell damage.
--- Writes a SPELL_DMG event with target, caster, spell, amount, mitigation, hit info, school, and effects.
--- hitInfo: 0=normal, 2=crit (see SpellDefines.h for full enum)
--- spellSchool: damage school of the spell (see SpellDefines.h)
--- mitigationStr: comma-separated "absorb,block,resist" amounts
--- effectAuraStr: comma-separated "effect1,effect2,effect3,auraType"
---@param targetGuid string GUID of the damage target
---@param casterGuid string GUID of the caster (active player)
---@param spellId number Spell ID
---@param amount number Damage dealt (or % health if auraType is 89/SPELL_AURA_PERIODIC_DAMAGE_PERCENT)
---@param mitigationStr string Comma-separated "absorb,block,resist" amounts
---@param hitInfo number Hit flags (0=normal, 2=crit)
---@param spellSchool number Damage school
---@param effectAuraStr string Comma-separated "effect1,effect2,effect3,auraType"
function ChronicleLog:SPELL_DAMAGE_EVENT_SELF(targetGuid, casterGuid, spellId, amount, mitigationStr, hitInfo, spellSchool, effectAuraStr)
    self:CheckUnit(targetGuid)
    self:CheckUnit(casterGuid)
    self:Write("SPELL_DMG", targetGuid, casterGuid, spellId, amount, mitigationStr, hitInfo, spellSchool, effectAuraStr)
end

--- Handles SPELL_DAMAGE_EVENT_OTHER events.
--- Called when someone other than the active player deals spell damage.
--- Writes a SPELL_DMG event with target, caster, spell, amount, mitigation, hit info, school, and effects.
--- hitInfo: 0=normal, 2=crit (see SpellDefines.h for full enum)
--- spellSchool: damage school of the spell (see SpellDefines.h)
--- mitigationStr: comma-separated "absorb,block,resist" amounts
--- effectAuraStr: comma-separated "effect1,effect2,effect3,auraType"
---@param targetGuid string GUID of the damage target
---@param casterGuid string GUID of the caster
---@param spellId number Spell ID
---@param amount number Damage dealt (or % health if auraType is 89/SPELL_AURA_PERIODIC_DAMAGE_PERCENT)
---@param mitigationStr string Comma-separated "absorb,block,resist" amounts
---@param hitInfo number Hit flags (0=normal, 2=crit)
---@param spellSchool number Damage school
---@param effectAuraStr string Comma-separated "effect1,effect2,effect3,auraType"
function ChronicleLog:SPELL_DAMAGE_EVENT_OTHER(targetGuid, casterGuid, spellId, amount, mitigationStr, hitInfo, spellSchool, effectAuraStr)
    self:CheckUnit(targetGuid)
    self:CheckUnit(casterGuid)
    self:Write("SPELL_DMG", targetGuid, casterGuid, spellId, amount, mitigationStr, hitInfo, spellSchool, effectAuraStr)
end

--- Handles SPELL_DELAYED_SELF events.
--- Called when the active player's spell is delayed (pushback from damage).
--- Writes a SPELL_DELAY event with caster GUID and delay amount.
---@param casterGuid string GUID of the caster (active player)
---@param delayMs number Delay in milliseconds
function ChronicleLog:SPELL_DELAYED_SELF(casterGuid, delayMs)
    self:CheckUnit(casterGuid)
    self:Write("SPELL_DELAY", casterGuid, delayMs)
end

--- Handles SPELL_DELAYED_OTHER events.
--- Called when another player's spell is delayed (pushback from damage).
--- Note: Currently non-functional - server only sends packet to affected player.
--- Writes a SPELL_DELAY event with caster GUID and delay amount.
---@param casterGuid string GUID of the caster
---@param delayMs number Delay in milliseconds
function ChronicleLog:SPELL_DELAYED_OTHER(casterGuid, delayMs)
    self:CheckUnit(casterGuid)
    self:Write("SPELL_DELAY", casterGuid, delayMs)
end

--- Handles SPELL_CHANNEL_START events.
--- Called when the active player starts channeling a spell.
--- Self-only event. Target GUID read from ChannelTargetGuid memory address.
--- Writes a CHANNEL_START event with spell ID, target, and duration.
---@param spellId number Spell ID being channeled
---@param targetGuid string Target GUID or "0x0000000000000000" if none
---@param durationMs number Channel duration in milliseconds
function ChronicleLog:SPELL_CHANNEL_START(spellId, targetGuid, durationMs)
    self:CheckUnit(targetGuid)
    self:Write("CHANNEL_START", spellId, targetGuid, durationMs)
end

--- Handles SPELL_CHANNEL_UPDATE events.
--- Called when the active player's channel time is updated (e.g., after tick or pushback).
--- Self-only event. Target GUID read from ChannelTargetGuid memory address.
--- Writes a CHANNEL_UPDATE event with spell ID, target, and remaining time.
---@param spellId number Spell ID being channeled
---@param targetGuid string Target GUID or "0x0000000000000000" if none
---@param remainingMs number Remaining channel time in milliseconds
function ChronicleLog:SPELL_CHANNEL_UPDATE(spellId, targetGuid, remainingMs)
    self:CheckUnit(targetGuid)
    self:Write("CHANNEL_UPDATE", spellId, targetGuid, remainingMs)
end

--- Handles SPELL_FAILED_SELF events.
--- Called when the active player's spell fails.
--- Fired from client spell failure hook with detailed failure info.
--- Writes a SPELL_FAIL event with spell ID, result code, and server flag.
---@param spellId number Spell ID that failed
---@param spellResult number SpellCastResult enum value
---@param failedByServer number 1 if failed by server, 0 if client-side failure
function ChronicleLog:SPELL_FAILED_SELF(spellId, spellResult, failedByServer)
    self:Write("SPELL_FAIL", spellId, spellResult, failedByServer)
end

--- Handles SPELL_FAILED_OTHER events.
--- Called when another player's spell fails.
--- Fired from server handler with limited information (no failure reason).
--- Writes a SPELL_FAIL event with caster GUID and spell ID.
---@param casterGuid string GUID of the caster
---@param spellId number Spell ID that failed
function ChronicleLog:SPELL_FAILED_OTHER(casterGuid, spellId)
    self:CheckUnit(casterGuid)
    self:Write("SPELL_FAIL", casterGuid, spellId)
end

--- Handles SPELL_GO_SELF events.
--- Called when the active player's spell go packet is received (spell completed casting).
--- Requires CVar: SetCVar("NP_EnableSpellGoEvents", 1)
--- Writes a SPELL_GO event with item, spell, caster, target, flags, and hit/miss counts.
--- Cast flags bitmask: 0=NONE, 1=HIDDEN_COMBATLOG, 32=AMMO, etc.
---@param itemId number Item ID that triggered spell, or 0 if not item-triggered
---@param spellId number Spell ID
---@param casterGuid string GUID of the caster (active player)
---@param targetGuid string Target GUID or "0x0000000000000000" if none
---@param castFlags number Bitmask of cast flags
---@param numTargetsHit number Number of targets hit
---@param numTargetsMissed number Number of targets missed
function ChronicleLog:SPELL_GO_SELF(itemId, spellId, casterGuid, targetGuid, castFlags, numTargetsHit, numTargetsMissed)
    self:CheckUnit(casterGuid)
    self:CheckUnit(targetGuid)
    self:Write("SPELL_GO", itemId, spellId, casterGuid, targetGuid, castFlags, numTargetsHit, numTargetsMissed)
end

--- Handles SPELL_GO_OTHER events.
--- Called when another unit's spell go packet is received (spell completed casting).
--- Requires CVar: SetCVar("NP_EnableSpellGoEvents", 1)
--- Writes a SPELL_GO event with item, spell, caster, target, flags, and hit/miss counts.
--- Cast flags bitmask: 0=NONE, 1=HIDDEN_COMBATLOG, 32=AMMO, etc.
---@param itemId number Item ID that triggered spell, or 0 if not item-triggered
---@param spellId number Spell ID
---@param casterGuid string GUID of the caster
---@param targetGuid string Target GUID or "0x0000000000000000" if none
---@param castFlags number Bitmask of cast flags
---@param numTargetsHit number Number of targets hit
---@param numTargetsMissed number Number of targets missed
function ChronicleLog:SPELL_GO_OTHER(itemId, spellId, casterGuid, targetGuid, castFlags, numTargetsHit, numTargetsMissed)
    self:CheckUnit(casterGuid)
    self:CheckUnit(targetGuid)
    self:Write("SPELL_GO", itemId, spellId, casterGuid, targetGuid, castFlags, numTargetsHit, numTargetsMissed)
end

--- Handles SPELL_START_SELF events.
--- Called when the active player's spell start packet is received (cast time spell begun).
--- Requires CVar: SetCVar("NP_EnableSpellStartEvents", 1)
--- Writes a SPELL_START event with item, spell, caster, target, flags, cast time, duration, and type.
--- spellType: 0=Normal, 1=Channeling, 2=Autorepeating
---@param itemId number Item ID that triggered spell, or 0 if not item-triggered
---@param spellId number Spell ID
---@param casterGuid string GUID of the caster (active player)
---@param targetGuid string Target GUID or "0x0000000000000000" if none
---@param castFlags number Bitmask of cast flags
---@param castTime number Cast time in milliseconds
---@param duration number Channel duration in ms (only for channeling spells, 0 otherwise)
---@param spellType number 0=Normal, 1=Channeling, 2=Autorepeating
function ChronicleLog:SPELL_START_SELF(itemId, spellId, casterGuid, targetGuid, castFlags, castTime, duration, spellType)
    self:CheckUnit(casterGuid)
    self:CheckUnit(targetGuid)
    self:Write("SPELL_START", itemId, spellId, casterGuid, targetGuid, castFlags, castTime, duration, spellType)
end

--- Handles SPELL_START_OTHER events.
--- Called when another unit's spell start packet is received (cast time spell begun).
--- Also fires for channeling spells by others (no separate SPELL_CHANNEL_START for others).
--- Use spellType to distinguish channeling spells.
--- Requires CVar: SetCVar("NP_EnableSpellStartEvents", 1)
--- Writes a SPELL_START event with item, spell, caster, target, flags, cast time, duration, and type.
--- spellType: 0=Normal, 1=Channeling, 2=Autorepeating
---@param itemId number Item ID that triggered spell, or 0 if not item-triggered
---@param spellId number Spell ID
---@param casterGuid string GUID of the caster
---@param targetGuid string Target GUID or "0x0000000000000000" if none
---@param castFlags number Bitmask of cast flags
---@param castTime number Cast time in milliseconds
---@param duration number Channel duration in ms (only for channeling spells, 0 otherwise)
---@param spellType number 0=Normal, 1=Channeling, 2=Autorepeating
function ChronicleLog:SPELL_START_OTHER(itemId, spellId, casterGuid, targetGuid, castFlags, castTime, duration, spellType)
    self:CheckUnit(casterGuid)
    self:CheckUnit(targetGuid)
    self:Write("SPELL_START", itemId, spellId, casterGuid, targetGuid, castFlags, castTime, duration, spellType)
end

-- =============================================================================
-- Chat Event Handlers
-- =============================================================================

--- Handles CHAT_MSG_LOOT events.
--- Message format: "You receive loot: [Item]." or "PlayerName receives loot: [Item]."
--- Writes a LOOT event with unit name and item link.
---@param msg string The loot message
function ChronicleLog:CHAT_MSG_LOOT(msg)
    if not msg then return end
    
    -- Parse "You receive loot:" or "PlayerName receives loot:"
    -- Pattern captures the name (or "You") and the item link
    local _, _, looter, itemLink = strfind(msg, "^(.+) receives? loot: (.+)%.$")
    if not looter then return end
    
    -- Convert "You" to player name
    if looter == "You" then
        looter = UnitName("player") or "You"
    end
    
    self:Write("LOOT", looter, itemLink)
end

--- Handles CHAT_MSG_SYSTEM events.
--- Detects trade messages: "PlayerA trades item ItemName to PlayerB."
--- Writes a LOOT_TRADE event with the raw message.
---@param msg string The system message
function ChronicleLog:CHAT_MSG_SYSTEM(msg)
    if not msg then return end
    
    -- Check for trade pattern: "Iseut trades item Libram of the Faithful to Milkpress."
    if strfind(msg, "^%w+ trades item") then
        self:Write("LOOT_TRADE", msg)
    end
end

-- =============================================================================
-- Session Event Handlers
-- =============================================================================

--- Handles PLAYER_LEAVING_WORLD events.
--- Flushes the log buffer to file on logout/disconnect/reload.
function ChronicleLog:PLAYER_LEAVING_WORLD()
    if self.bufferSize > 0 then
        self:FlushToFile()
    end
end
