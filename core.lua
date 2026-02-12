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

local inilialized = false
function Chronicle:Init()
	if inilialized then
		return
	end
	inilialized = true
	self.logging = LoggingCombat()
	self:InitializeConfig()
	self:CreateOptionsPanel()
	self:InitDeps()
	InitChronicleUnits()
end

function Chronicle:InitDeps()
	self.superWoW = false
	self.superWoWLogger = false
	-- Check for SuperWoW requirement
	if SetAutoloot then
		self.superWoW = true
	end

	if log_combatant_info then
		self.superWoWLogger = true
	end

	if not self.superWoW then
		Chronicle:Print("Warning: The SuperWoW mod by Balake is not detected. This mod is required for ChronicleCompanion to work.")

		StaticPopupDialogs["DEPENDENCIES_MISSING"] = {
			text = "The SuperWoW mod by Balake is not detected. The ChronicleCompanion addon requires both of these addons to function properly. Disable this addon, or fix the missing dependencies.",
			button1 = "Ok",
			timeout = 30,
			whileDead = true,
			hideOnEscape = true
		}
		StaticPopup_Show("DEPENDENCIES_MISSING")
	end

	local version = SUPERWOW_VERSION 
	if not version or version == "" then
		StaticPopupDialogs["SUPERWOW_VERSION_MISSING"] = {
			text = "The SuperWoW mod by Balake is out of date. Version 1.5 is required. Disable this addon or update SuperWoW",
			button1 = "Ok",
			timeout = 30,
			whileDead = true,
			hideOnEscape = true
		}
		StaticPopup_Show("SUPERWOW_VERSION_MISSING")
	end

	if ChronicleCompareVersion(version, "1.5") <= 0 then
		StaticPopupDialogs["SUPERWOW_VERSION_OUTOFDATE"] = {
			text = "The SuperWoW mod by Balake is out of date (found version "..version.."). Version >=1.5 is required. Disable this addon or update SuperWoW",
			button1 = "Ok",
			timeout = 30,
			whileDead = true,
			hideOnEscape = true
		}
		StaticPopup_Show("SUPERWOW_VERSION_OUTOFDATE")
	end
end

-- =============================================================================
-- Database Management
-- =============================================================================

function Chronicle:Reset()
	Chronicle:Init()
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
	self.eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	self.eventFrame:RegisterEvent("UPDATE_INSTANCE_INFO")
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
	-- Always log the player info
	Chronicle:LogPlayerContext() 
	-- Handle instance state
	self:OnInstanceChange()
end

--- Called when the player's instance state may have changed.
--- Handles automatic combat log toggling and reminder popups based on config settings.
function Chronicle:OnInstanceChange()
	local isInstance = IsInInstance() == 1
	local logging = LoggingCombat() == 1
	
	self:DebugPrint("OnInstanceChange: inInstance=" .. tostring(isInstance) .. ", logging=" .. tostring(logging))
	
	-- If SuperWoWLogger is present, let it handle combat log toggling
	if self.superWoWLogger then
		self:DebugPrint("SuperWoWLogger detected, skipping combat log management")
		return
	end
	
	local autoToggle = self:GetSetting("autoCombatLogToggle")
	local disableReminder = self:GetSetting("disableCombatlogReminder")
	
	if isInstance then
		-- Entering an instance
		if autoToggle then
			-- Auto-enable combat logging
			if not logging then
				LoggingCombat(1)
				self:Print("Combat logging enabled (entered instance)")
				self:DebugPrint("Auto-enabled combat logging")
			end
		else
			-- Auto-toggle disabled, show reminder if logging is off
			if not logging and not disableReminder then
				StaticPopupDialogs["CHRONICLE_ENABLE_COMBAT_LOGGING"] = {
					text = "Combat logging is disabled and you have entered an instance, do you want to enable it?",
					button1 = "Enable Combat Logs",
					button2 = "No",
					OnAccept = ChronicleEnableCombatLogging,
					timeout = 30,
					whileDead = true,
					hideOnEscape = true
				}
				StaticPopup_Show("CHRONICLE_ENABLE_COMBAT_LOGGING")
			end
		end
	else
		-- Leaving an instance
		if autoToggle then
			-- Auto-disable combat logging
			if logging then
				LoggingCombat(0)
				self:Print("Combat logging disabled (left instance)")
				self:DebugPrint("Auto-disabled combat logging")
			end
		else
			-- Auto-toggle disabled, show reminder if logging is still on
			if logging and not disableReminder then
				StaticPopupDialogs["CHRONICLE_DISABLE_COMBAT_LOGGING"] = {
					text = "Combat logging is enabled, but you are not in an instance. Do you want to disable it?",
					button1 = "Disable Combat Logs",
					button2 = "No",
					OnAccept = ChronicleDisableCombatLogging,
					timeout = 30,
					whileDead = true,
					hideOnEscape = true
				}
				StaticPopup_Show("CHRONICLE_DISABLE_COMBAT_LOGGING")
			end
		end
	end
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
	elseif event == "ZONE_CHANGED_NEW_AREA" then
		self:OnInstanceChange()
	elseif event == "UPDATE_INSTANCE_INFO" then
		self:OnInstanceChange()
	elseif event == "RAW_COMBATLOG" then
		self:RAW_COMBATLOG()
	elseif event == "PLAYER_LOGIN" then
	elseif event == "PLAYER_REGEN_DISABLED" then
		self:LogPlayerPosition()
	elseif event == "PLAYER_REGEN_ENABLED" then
		self:LogPlayerPosition()


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
	-- Always want this at the top of the logs
	Chronicle:LogPlayerContext()
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
	Chronicle:LogPlayerPosition()
	Chronicle:LogTimings()
end

local lastRealmLogTime = 0
--- Emits a log line with realm and builds information to identify the server and realm
function Chronicle:LogRealm(force)
	-- Every 10 minutes
	if not force and time() - lastRealmLogTime < 600 then
		return
	end
	
	local version, build, buildDate = GetBuildInfo()
	local realmName = GetRealmName()

	local logLine = string.format("REALM_INFO: %s&%s&%s&%s&%s",
		date("%d.%m.%y %H:%M:%S"),
		version,
		build,
		buildDate,
		realmName
	)
	CombatLogAdd(logLine, 1)
end

-- Unsure if this is useful, but want to try it.
function Chronicle:LogPlayerPosition()
	local x, y = GetPlayerMapPosition("player")
	if x == nil or y == nil then
		-- These should never be nil, but just in case
		return
	end

	if x == 0 or y == 0 then
		-- Invalid position
		return
	end

	local  _, guid = UnitExists("player")
	if not guid then
		return
	end

	local logLine = string.format("PLAYER_POSITION: %s&%s&%f&%f",
		date("%d.%m.%y %H:%M:%S"),
		guid,
		x,
		y
	)
	CombatLogAdd(logLine, 1)
end

-- Helpful when parsing to get the right timezone context
function Chronicle:LogTimings()
	local ts = time()

	local logLine = string.format("CLOCK_INFO: %s&%s",
		date("%d.%m.%y %H:%M:%S", ts), -- Local time
		date("!%d.%m.%y %H:%M:%S", ts) -- UTC time
	)
	CombatLogAdd(logLine, 1)
end
