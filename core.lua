-- =============================================================================
-- Chronicle Addon for Turtle WoW
-- =============================================================================

-- =============================================================================
-- Chronicle Namespace
-- =============================================================================

---@class Chronicle
---@field version string
---@field db ChronicleDB
---@field superWoW boolean
---@field superWoWLogger boolean
---@field challenges string comma-separated list of challenges
Chronicle = {}
Chronicle.version = "0.1"

-- =============================================================================
-- Database Management
-- =============================================================================

---@class ChronicleDB
---@field units UnitsTable
---@field logging boolean

---@class UnitsTable
---@field id string unit GUID
---@field name string unit name
---@field owner string guid of owner or ""
---@field last_seen number timestamp of last seen
---@field canCooperate boolean whether unit can cooperate
---@field logged number timestamp of last logged
---@field level number unit level

function Chronicle:Init()
	self:InitDeps()
	self:InitChallenges()
	self:InitDB()
end

function Chronicle:InitChallenges()
	self.challenges = self:PlayerChallenges()
	if self.challenges ~= "" then
		self:Print("Player challenges: " .. self.challenges)
	end
end

function Chronicle:InitDeps()
	-- Check for SuperWoW requirement
	if not SetAutoloot then
		self.superWoW = false
	end

	if not log_combatant_info then
		self.superWoWLogger = false
	end

	-- TODO: Add some UI alerts if deps are missing
end

-- Initialize the database
function Chronicle:InitDB()
	local logging = LoggingCombat() == 1
	-- Create default structure if DB doesn't exist or not up to date
	if not ChronicleDB  or ChronicleDB.version ~= self.version then
		ChronicleDB = {
			version = self.version,
			units = {},  -- Stores GUID -> unit data
			logging = logging
		}
	end
	
	-- Ensure units table exists
	if not ChronicleDB.units then
		ChronicleDB.units = {}
	end
	
	self.db = ChronicleDB
	self.logging = logging
end

-- Map spell name -> key you want in the return table
local CHALLENGE_SPELLS = {
	["Level One Lunatic"] = "lunatic",
	["Hardcore"] = "hardcore",
	["Boaring Adventure"] = "boaring",
	["Path of the Brewmaster"] = "brewmaster",
	["Exhaustion"] = "exhaustion",
	["Slow & Steady"] = "slowsteady",
	["Traveling Craftmaster"] = "craftmaster",
	["Vagrant's Endeavor"] = "vagrant",
}

-- PlayerChallenges returns a comma-separated list of challenge keys the player has
--- @return string
function Chronicle:PlayerChallenges()
 local challenges = {}
  for tab = 1, GetNumSpellTabs() do
    local _, _, offset, numSpells = GetSpellTabInfo(tab)
    for i = 1, numSpells do
      local name = GetSpellName(offset + i, "spell")
      local key = name and CHALLENGE_SPELLS[name]
      if key then
        challenges[key] = true
      end
    end
  end

	local keys = {}
	for k in pairs(challenges) do table.insert(keys, k) end
	table.sort(keys)
	return table.concat(keys, ",")
end

-- ChronicleTest = {}
-- for k, v in pairs(_G) do
--   if type(v) == "function" then
--     table.insert(ChronicleTest, k)
--   end
-- end



---@param guid string
---@return string
function Chronicle:unitBuffs(guid)
	local auras = ""
	local prefix = ","
	for i=1, 31 do
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

-- Add or update a unit in the database
function Chronicle:UpdateUnit(guid)
	if not guid then return end
	local unitData = self.db.units[guid] or {}
	local lastLogged = unitData.logged or 0
	if time() - lastLogged < 300 then
		return
	end

	unitData.guid = guid
	unitData.name = UnitName(guid)
	unitData.owner = ""
	unitData.last_seen = time()
	unitData.canCooperate = UnitCanCooperate("player", guid)
	unitData.logged = time()
	unitData.level = UnitLevel(guid)
	-- No need to cache this info.
	local buffs = Chronicle:unitBuffs(guid)

	-- Check for owner unit
	local ok, ownerGuid = UnitExists(guid.."owner")
	if ok then
		unitData.owner = ownerGuid
	end
	

	self.db.units[guid] = unitData

	local logLine = string.format("UNIT_INFO: %s&%s&%s&%s&%s&%s&%s&%s&%s",
		date("%d.%m.%y %H:%M:%S"),
		unitData.guid,
		UnitIsUnit(unitData.guid, "player") and "1" or "0",
		unitData.name,
		unitData.canCooperate and "1" or "0",
		unitData.owner or "",
		buffs or "",
		unitData.level or "0",
		-- Dump the player challenges if it is the player
		UnitIsUnit(unitData.guid, "player") and self.challenges or "na"
	)
	CombatLogAdd(logLine, 1)
	Chronicle:CleanupOldUnits()
	-- self:DebugPrint(logLine)
end

function Chronicle:Reset()
	self.db.units = {}
	self:Print("Chronicle database reset.")
end

-- Clean up old units that haven't been seen in a while
function Chronicle:CleanupOldUnits(timeoutSeconds)
	local currentTime = time()
	timeoutSeconds = timeoutSeconds or 300  -- Default 5 minutes
	if self.lastCleanup and (currentTime - self.lastCleanup) < timeoutSeconds then
		return 0 -- Skip cleanup if done recently
	end

	local removed = 0
	
	for guid, unit in pairs(self.db.units) do
		if unit.last_seen and (currentTime - unit.last_seen) > timeoutSeconds then
			self.db.units[guid] = nil
			removed = removed + 1
		end
	end
	
	Chronicle.lastCleanup = time()
	return removed
end

-- =============================================================================
-- Event Frame
-- =============================================================================

function Chronicle:CreateEventFrame()
	self.eventFrame = CreateFrame("Frame", "ChronicleEventFrame")
	self.eventFrame:SetScript("OnEvent", function()
		Chronicle:OnEvent(event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9)
	end)
	
	-- Register events
	self.eventFrame:RegisterEvent("ADDON_LOADED")
	self.eventFrame:RegisterEvent("RAW_COMBATLOG")
	self.eventFrame:RegisterEvent("PLAYER_LOGIN")
	self.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	-- self.eventFrame:RegisterEvent("PLAYER_LOGIN")
	-- self.eventFrame:RegisterEvent("PLAYER_LOGOUT")
	
	-- Add more events as needed for tracking units
	-- self.eventFrame:RegisterEvent("UNIT_NAME_UPDATE")
	-- self.eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
	-- etc.
end

-- Finds all 0x0000000000000000-style hex strings
local function FindHexGUIDs(str)
    local results = {}
    
    -- pattern:
    -- 0x followed by exactly 16 hex chars
    for match in string.gmatch(str, "0x(%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x)") do
        table.insert(results, "0x" .. match)
    end

    return results
end

function Chronicle:RAW_COMBATLOG()
	local logging = LoggingCombat()

	if logging ~= 1 then
		if self.logging then
			self.logging = false
			self:Reset()
		end
		return
	end

	-- Reset the db on first logging event
	if not self.logging then
		self.logging = true
		self:Reset()
	end

	local event_name = arg1
	local log = arg2
	if not arg2 then return end

	-- local input = "Mob died: 0x000000000000ABCD killed by 0x0000000000001234"
	local guids = FindHexGUIDs(log)
	for i = 1, table.getn(guids) do
		self:UpdateUnit(guids[i])
	end

	local hasYou = string.match(log, " [yY]ou(['.\\sr])")
	if hasYou then
		local ok, playerGuid = UnitExists("player")
		if ok then
			self:UpdateUnit(playerGuid)
		end
	end
end

function Chronicle:OnPlayerEnteringWorld()
	self:Reset()
	if not Chronicle:IsEnteringInstance() then
		return
	end

	-- TODO: For non raids, probably do not do this.
	if not IsInInstance() then
		return
	end
	
	StaticPopupDialogs["ENABLE_COMBAT_LOGGING"] = {
		text = "Would you like to enable Combat Logging?",
		button1 = "Yes",
		button2 = "No",
		OnAccept = ChronicleEnableCombatLogging,
		timeout = 30,
		whileDead = true,
		hideOnEscape = true
	}
end

function Chronicle:OnEvent(event, ...)
	if event == "ADDON_LOADED" then
		local addonName = arg1
		if addonName == "ChronicleCompanion" then
			self.chronicleCompanionLoaded = true
			self:Init()
			self:Print("Chronicle v" .. self.version .. " loaded. Type /chronicle help for commands.")
		end
	elseif event == "PLAYER_ENTERING_WORLD" then
		self:OnPlayerEnteringWorld()
	elseif event == "RAW_COMBATLOG" then
		self:RAW_COMBATLOG()
	elseif event == "PLAYER_LOGIN" then
		-- local existing = LoggingCombat()
		-- LoggingCombat(1)
		-- local zone = GetRealZoneText()
		-- local pgid, ok = UnitExists("player")
		-- local loginMessage = "PLAYER_LOGIN: " .. UnitName("player") .. "&" .. tostring(ok and pgid or "nil") .. "&" .. zone
		-- CombatLogAdd(loginMessage, 1)
		-- CombatLogAdd(loginMessage)
		-- LoggingCombat(existing)
	end
end

function Chronicle:ADDON_LOADED()
	local addonName = arg1
	if addonName ~= "ChronicleLogger" then
		return
	end

	self:Init()
	self:Print("Chronicle v" .. self.version .. " loaded. Type /chronicle help for commands.")
end


-- sub to RAW_COMBATLOG

-- =============================================================================
-- Utility Functions
-- =============================================================================

function Chronicle:Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cffffff00[Chronicle]|r " .. tostring(msg))
end

function Chronicle:FormatTime(seconds)
	if seconds < 60 then
		return seconds .. "s"
	elseif seconds < 3600 then
		return math.floor(seconds / 60) .. "m"
	elseif seconds < 86400 then
		return string.format("%.1fh", seconds / 3600)
	else
		return string.format("%.1fd", seconds / 86400)
	end
end

function Chronicle:IsEnteringInstance()
	local x, y = GetPlayerMapPosition("player")
	if x == nil or y == nil then
		return true
	end
	return x == y and y == 0
end


function ChronicleEnableCombatLogging()
	LoggingCombat(1)
	DEFAULT_CHAT_FRAME:AddMessage("Combat Logging Enabled")
end

function ChronicleDisableCombatLogging()
	LoggingCombat(0)
	DEFAULT_CHAT_FRAME:AddMessage("Combat Logging Disabled")
end

-- =============================================================================
-- Example: Add a unit to the database
-- =============================================================================
-- Usage example:
-- Chronicle:UpdateUnit("0x0000000000001234", "PlayerName", "OwnerName", {level = 60, class = "Warrior"})