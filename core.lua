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

Chronicle = {}
Chronicle.version = "0.1"

-- =============================================================================
-- Database Management
-- =============================================================================

-- Initialize the database
function Chronicle:InitDB()
	-- Create default structure if DB doesn't exist
	if not ChronicleDB then
		ChronicleDB = {
			version = self.version,
			units = {}  -- Stores GUID -> unit data
		}
	end
	
	-- Upgrade DB if needed
	if not ChronicleDB.version or ChronicleDB.version ~= self.version then
		ChronicleDB.version = self.version
		-- Add migration logic here if needed
	end
	
	-- Ensure units table exists
	if not ChronicleDB.units then
		ChronicleDB.units = {}
	end
	
	self.db = ChronicleDB
end

-- Add or update a unit in the database
function Chronicle:UpdateUnit(guid, name, owner, additionalData)
	if not guid then return end
	
	local unitData = self.db.units[guid] or {}
	unitData.guid = guid
	unitData.name = name or unitData.name
	unitData.owner = owner or unitData.owner
	unitData.last_seen = time()
	
	-- Merge any additional data
	if additionalData then
		for k, v in pairs(additionalData) do
			unitData[k] = v
		end
	end
	
	self.db.units[guid] = unitData
	return unitData
end

-- Get unit data by GUID
function Chronicle:GetUnit(guid)
	return self.db.units[guid]
end

-- Clean up old units that haven't been seen in a while
function Chronicle:CleanupOldUnits(timeoutSeconds)
	timeoutSeconds = timeoutSeconds or 3600  -- Default 1 hour
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

-- Get statistics about stored units
function Chronicle:GetStats()
	local count = 0
	local oldestSeen = time()
	local newestSeen = 0
	
	for guid, unit in pairs(self.db.units) do
		count = count + 1
		if unit.last_seen then
			if unit.last_seen < oldestSeen then
				oldestSeen = unit.last_seen
			end
			if unit.last_seen > newestSeen then
				newestSeen = unit.last_seen
			end
		end
	end
	
	return {
		count = count,
		oldest_seen = oldestSeen,
		newest_seen = newestSeen
	}
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
	self.eventFrame:RegisterEvent("PLAYER_LOGIN")
	self.eventFrame:RegisterEvent("PLAYER_LOGOUT")
	
	-- Add more events as needed for tracking units
	-- self.eventFrame:RegisterEvent("UNIT_NAME_UPDATE")
	-- self.eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
	-- etc.
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
	end
end

function Chronicle:OnPlayerLogin()
	-- Perform any login tasks
	self:DebugPrint("Player logged in")
end

function Chronicle:OnPlayerLogout()
	-- Perform any cleanup before logout
	self:DebugPrint("Player logging out")
end

-- =============================================================================
-- Debug Frame
-- =============================================================================

function Chronicle:CreateDebugFrame()
	local frame = CreateFrame("Frame", "ChronicleDebugFrame", UIParent)
	frame:SetWidth(500)
	frame:SetHeight(400)
	frame:SetPoint("CENTER")
	frame:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true,
		tileSize = 32,
		edgeSize = 32,
		insets = { left = 11, right = 12, top = 12, bottom = 11 }
	})
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function() this:StartMoving() end)
	frame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
	frame:Hide()
	
	-- Title
	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOP", 0, -20)
	title:SetText("Chronicle Debug Console")
	frame.title = title
	
	-- Close button
	local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	closeBtn:SetPoint("TOPRIGHT", -5, -5)
	frame.closeBtn = closeBtn
	
	-- Scroll frame for content
	local scrollFrame = CreateFrame("ScrollFrame", "ChronicleDebugScrollFrame", frame, "UIPanelScrollFrameTemplate")
	scrollFrame:SetPoint("TOPLEFT", 20, -50)
	scrollFrame:SetPoint("BOTTOMRIGHT", -30, 80)
	
	-- Content frame
	local content = CreateFrame("Frame", nil, scrollFrame)
	content:SetWidth(450)
	content:SetHeight(1)  -- Will grow as needed
	scrollFrame:SetScrollChild(content)
	
	-- Text display
	local text = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	text:SetPoint("TOPLEFT", 5, -5)
	text:SetWidth(440)
	text:SetJustifyH("LEFT")
	text:SetJustifyV("TOP")
	text:SetText("Debug output will appear here...")
	content.text = text
	
	frame.content = content
	frame.scrollFrame = scrollFrame
	
	-- Clear button
	local clearBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	clearBtn:SetWidth(80)
	clearBtn:SetHeight(22)
	clearBtn:SetPoint("BOTTOMLEFT", 20, 20)
	clearBtn:SetText("Clear")
	clearBtn:SetScript("OnClick", function()
		Chronicle:ClearDebugLog()
	end)
	frame.clearBtn = clearBtn
	
	-- Stats button
	local statsBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	statsBtn:SetWidth(80)
	statsBtn:SetHeight(22)
	statsBtn:SetPoint("LEFT", clearBtn, "RIGHT", 5, 0)
	statsBtn:SetText("Stats")
	statsBtn:SetScript("OnClick", function()
		Chronicle:ShowStats()
	end)
	frame.statsBtn = statsBtn
	
	-- Cleanup button
	local cleanupBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	cleanupBtn:SetWidth(100)
	cleanupBtn:SetHeight(22)
	cleanupBtn:SetPoint("LEFT", statsBtn, "RIGHT", 5, 0)
	cleanupBtn:SetText("Cleanup Old")
	cleanupBtn:SetScript("OnClick", function()
		local removed = Chronicle:CleanupOldUnits()
		Chronicle:DebugPrint("Cleaned up " .. removed .. " old units")
	end)
	frame.cleanupBtn = cleanupBtn
	
	self.debugFrame = frame
	self.debugLog = {}
end

function Chronicle:ToggleDebugFrame()
	if not self.debugFrame then
		self:CreateDebugFrame()
	end
	
	if self.debugFrame:IsShown() then
		self.debugFrame:Hide()
	else
		self.debugFrame:Show()
		self:UpdateDebugDisplay()
	end
end

function Chronicle:DebugPrint(msg)
	if not self.debugLog then
		self.debugLog = {}
	end
	
	local timestamp = date("%H:%M:%S")
	local logEntry = "[" .. timestamp .. "] " .. tostring(msg)
	table.insert(self.debugLog, logEntry)
	
	-- Keep only last 100 entries
	if table.getn(self.debugLog) > 100 then
		table.remove(self.debugLog, 1)
	end
	
	-- Update display if frame is open
	if self.debugFrame and self.debugFrame:IsShown() then
		self:UpdateDebugDisplay()
	end
end

function Chronicle:UpdateDebugDisplay()
	if not self.debugFrame or not self.debugFrame.content then return end
	
	local text = table.concat(self.debugLog, "\n")
	self.debugFrame.content.text:SetText(text)
	
	-- Adjust content height
	local height = self.debugFrame.content.text:GetHeight() + 20
	self.debugFrame.content:SetHeight(math.max(height, 300))
end

function Chronicle:ClearDebugLog()
	self.debugLog = {}
	self:DebugPrint("Debug log cleared")
end

function Chronicle:ShowStats()
	local stats = self:GetStats()
	self:DebugPrint("=== Database Statistics ===")
	self:DebugPrint("Total units: " .. stats.count)
	
	if stats.count > 0 then
		local currentTime = time()
		local oldestAge = currentTime - stats.oldest_seen
		local newestAge = currentTime - stats.newest_seen
		
		self:DebugPrint("Oldest seen: " .. self:FormatTime(oldestAge) .. " ago")
		self:DebugPrint("Newest seen: " .. self:FormatTime(newestAge) .. " ago")
	end
	
	self:DebugPrint("===========================")
end

-- =============================================================================
-- Slash Commands
-- =============================================================================

function Chronicle:RegisterSlashCommands()
	SLASH_CHRONICLE1 = "/chronicle"
	SLASH_CHRONICLE2 = "/chron"
	
	SlashCmdList["CHRONICLE"] = function(msg)
		Chronicle:HandleSlashCommand(msg)
	end
end

function Chronicle:HandleSlashCommand(msg)
	-- Parse command and arguments
	local cmd, args = self:ParseCommand(msg)
	
	if cmd == "debug" then
		self:ToggleDebugFrame()
		
	elseif cmd == "help" then
		self:ShowHelp()
		
	elseif cmd == "stats" then
		self:ShowStats()
		self:Print("Check the debug window for details, or see chat.")
		local stats = self:GetStats()
		self:Print("Total units tracked: " .. stats.count)
		
	elseif cmd == "cleanup" then
		local timeout = tonumber(args) or 3600
		local removed = self:CleanupOldUnits(timeout)
		self:Print("Cleaned up " .. removed .. " units not seen in " .. self:FormatTime(timeout))
		
	elseif cmd == "clear" then
		ChronicleDB.units = {}
		self.db.units = {}
		self:Print("Database cleared!")
		
	elseif cmd == "version" or cmd == "ver" then
		self:Print("Chronicle version " .. self.version)
		
	else
		self:Print("Unknown command. Type '/chronicle help' for available commands.")
	end
end

function Chronicle:ParseCommand(msg)
	msg = strtrim(msg or "")
	local cmd, args = strsplit(" ", msg, 2)
	cmd = strlower(cmd or "")
	return cmd, args
end

function Chronicle:ShowHelp()
	self:Print("=== Chronicle Commands ===")
	self:Print("/chronicle debug - Toggle debug console")
	self:Print("/chronicle stats - Show database statistics")
	self:Print("/chronicle cleanup [seconds] - Remove units not seen in X seconds (default 3600)")
	self:Print("/chronicle clear - Clear entire database")
	self:Print("/chronicle version - Show addon version")
	self:Print("/chronicle help - Show this help")
end

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

-- =============================================================================
-- Initialization
-- =============================================================================

Chronicle:CreateEventFrame()
Chronicle:RegisterSlashCommands()

