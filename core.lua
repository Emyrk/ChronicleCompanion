-- =============================================================================
-- Chronicle Addon for Vanilla WoW
-- =============================================================================

-- =============================================================================
-- Chronicle Namespace
-- =============================================================================

---@class Chronicle
Chronicle = {}

local initialized = false
function Chronicle:Init()
	if initialized then
		return
	end
	initialized = true
	ChronicleLog:Init()
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
end

function Chronicle:OnEvent(event, ...)
	if event == "ADDON_LOADED" then
		local addonName = arg1
		if addonName == "ChronicleCompanion" then
			self.chronicleCompanionLoaded = true
			self:Init()
			ChronicleMinimapButton:SetShown(ChronicleLog:GetSetting("showMinimapIcon") ~= false)
			self:Print("Chronicle v" .. GetAddOnMetadata("ChronicleCompanion", "Version") .. " loaded. Type /chronicle help for commands.")
		end
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

-- =============================================================================
-- Utility Functions
-- =============================================================================

function Chronicle:Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cffffff00[Chronicle]|r " .. tostring(msg))
end

function Chronicle:DebugPrint(msg)
	if ChronicleLog:GetSetting("debugMode") then
		local frameNum = ChronicleLog:GetSetting("debugChatFrame") or 1
		local chatFrame = _G["ChatFrame" .. frameNum] or DEFAULT_CHAT_FRAME
		chatFrame:AddMessage("|cff888888[Chronicle Debug]|r " .. tostring(msg))
	end
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