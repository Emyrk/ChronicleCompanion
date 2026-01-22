-- =============================================================================
-- Chronicle Addon for Turtle WoW
-- =============================================================================

-- =============================================================================
-- Chronicle Namespace
-- =============================================================================

---@class Chronicle
---@field version string
---@field superWoW boolean if superWoW is present
---@field superWoWLogger boolean if superWoWLogger is present
---@field logging boolean if combat logging is currently enabled
Chronicle = {}
Chronicle.version = "0.1"

function Chronicle:Init()
	self.logging = LoggingCombat()
	self:InitDeps()
	InitChronicleUnits()
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

-- =============================================================================
-- Database Management
-- =============================================================================

function Chronicle:Reset()
	ChronicleUnits:Reset()
end

-- ChronicleTest = {}
-- for k, v in pairs(_G) do
--   if type(v) == "function" then
--     table.insert(ChronicleTest, k)
--   end
-- end

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
		Chronicle:Print("Combat Logging Enabled - Logging player context")
		Chronicle:LogPlayerContext() 
	end

	local event_name = arg1
	local log = arg2
	if not arg2 then return end

	-- local input = "Mob died: 0x000000000000ABCD killed by 0x0000000000001234"
	local guids = FindHexGUIDs(log)
	for i = 1, table.getn(guids) do
		ChronicleUnits:UpdateUnit(guids[i])
	end

	local hasYou = string.match(log, " [yY]ou(['.\\sr])")
	if hasYou then
		local ok, playerGuid = UnitExists("player")
		if ok then
			ChronicleUnits:UpdateUnit(playerGuid)
		end
	end
end

function Chronicle:OnPlayerEnteringWorld()
	self:Reset()
	if not Chronicle:IsEnteringInstance() then
		return
	end

	-- Always log the player info
	Chronicle:LogPlayerContext() 

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
			Chronicle:LogPlayerContext() 
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
		-- These should never be nil, but just in case
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


-- =============================================================================
-- Example: Custom logging events
-- =============================================================================

--- Emits a log line with the player context information for the parser to understand
--- where the logs are coming from.
function Chronicle:LogPlayerContext() 
	ChronicleUnits:UpdateUnit("player", true)
	Chronicle:LogRealm(true)
end

local lastRealmLogTime = 0
--- Emits a log line with realm and builds information to identify the server and realm
function Chronicle:LogRealm(force)
	-- Every 10 minutes
	if not force and time() - lastRealmLogTime < 600 then
		return
	end
	
	local version, build, date = GetBuildInfo()
	local realmName = GetRealmName()

	local logLine = string.format("REALM_INFO: %s&%s&%s&%s&%s",
		date("%d.%m.%y %H:%M:%S"),
		version,
		build,
		date,
		realmName
	)
	CombatLogAdd(logLine, 1)
end