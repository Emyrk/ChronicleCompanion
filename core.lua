-- =============================================================================
-- Chronicle Addon for Turtle WoW
-- =============================================================================

-- Check for SuperWoW requirement
if not SetAutoloot then
	StaticPopupDialogs["NO_SUPERWOW_CHRONICLE"] = {
		text = "|cffffff00Chronicle|r requires SuperWoW to operate.",
		button1 = TEXT(OKAY),
		timeout = 0,
		whileDead = 1,
		hideOnEscape = 1,
		showAlert = 1,
	}
	StaticPopup_Show("NO_SUPERWOW_CHRONICLE")
	return
end


-- =============================================================================
-- Chronicle Namespace
-- =============================================================================

---@class Chronicle
---@field version string
---@field db ChronicleDB
Chronicle = {}
Chronicle.version = "0.1"

-- =============================================================================
-- Database Management
-- =============================================================================

---@class ChronicleDB
---@field units UnitsTable

---@class UnitsTable
---@field id string unit GUID
---@field name string unit name
---@field owner string guid of owner or ""
---@field last_seen number timestamp of last seen
---@field canCooperate boolean whether unit can cooperate
---@field logged number timestamp of last logged

-- Initialize the database
function Chronicle:InitDB()
	-- Create default structure if DB doesn't exist or not up to date
	if not ChronicleDB  or ChronicleDB.version ~= self.version then
		ChronicleDB = {
			version = self.version,
			units = {}  -- Stores GUID -> unit data
		}
	end
	
	-- Ensure units table exists
	if not ChronicleDB.units then
		ChronicleDB.units = {}
	end
	
	self.db = ChronicleDB
end

---@param guid string
---@return string
function unitBuffs(guid, auraFunction)
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
	-- No need to cache this info.
	local buffs = unitBuffs(guid)

	-- Check for owner unit
	local ok, ownerGuid = UnitExists(guid.."owner")
	if ok then
		unitData.owner = ownerGuid
	end
	

	self.db.units[guid] = unitData

	local logLine = string.format("UNIT_INFO: %s&%s&%s&%s&%s&%s",
		date("%d.%m.%y %H:%M:%S"),
		unitData.guid,
		unitData.name,
		unitData.canCooperate and "1" or "0",
		unitData.owner or "",
		buffs or ""
	)
	CombatLogAdd(logLine, 1)
	self:DebugPrint(logLine)
end

-- Clean up old units that haven't been seen in a while
function Chronicle:CleanupOldUnits(timeoutSeconds)
	timeoutSeconds = timeoutSeconds or 300  -- Default 5 minutes
	local currentTime = time()
	local removed = 0
	
	for guid, unit in pairs(self.db.units) do
		if unit.last_seen and (currentTime - unit.last_seen) > timeoutSeconds then
			self.db.units[guid] = nil
			removed = removed + 1
		end
	end
	
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
	local event_name = arg1
	local log = arg2

	-- local input = "Mob died: 0x000000000000ABCD killed by 0x0000000000001234"
	local guids = FindHexGUIDs(arg2)
	for i = 1, table.getn(guids) do
		self:UpdateUnit(guids[i])
	end
end

function Chronicle:OnEvent(event, ...)
	if event == "ADDON_LOADED" then
		local addonName = arg1
		if addonName == "Chronicle" then
			self:InitDB()
			self:Print("Chronicle v" .. self.version .. " loaded. Type /chronicle help for commands.")
		end
	elseif event == "PLAYER_LOGIN" then
		self:OnPlayerLogin()
	elseif event == "PLAYER_LOGOUT" then
		self:OnPlayerLogout()
	elseif event == "RAW_COMBATLOG" then
		self:RAW_COMBATLOG()
	end
end

function Chronicle:ADDON_LOADED()
	local addonName = arg1
	if addonName ~= "Chronicle" then
		return
	end

	self:InitDB()
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

-- =============================================================================
-- Example: Add a unit to the database
-- =============================================================================
-- Usage example:
-- Chronicle:UpdateUnit("0x0000000000001234", "PlayerName", "OwnerName", {level = 60, class = "Warrior"})