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