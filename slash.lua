-- =============================================================================
-- Slash Commands
-- =============================================================================

function Chronicle:RegisterSlashCommands()
	SLASH_CHRONICLE1 = "/chronicle"

	if not IsAddOnLoaded("Chronometer") and not IsAddOnLoaded("Chronometer-TWoW") then
		-- Deprecate this for /clog
		SLASH_CHRONICLE2 = "/chron"
	end

	SlashCmdList["CHRONICLE"] = function(msg)
		Chronicle:HandleSlashCommand(msg)
	end

	SLASH_CLOG1 = "/clog"
	SlashCmdList["CLOG"] = function(msg)
		Chronicle:HandleSlashCommand(msg)
	end
end

local function split(str, delim)
    delim = delim or "%s"  -- default: split on whitespace
    local result = {}
    if str == nil or str == "" then
        return result
    end
    for part in cgmatch(str, "([^" .. delim .. "]+)") do
        table.insert(result, part)
    end
    return result
end

function Chronicle:HandleSlashCommand(msg)
	-- Parse command and arguments
	local parts = split(msg)
	-- print(PrintTable(parts))
	local cmd = parts[1] or ""
	local arg = parts[2] or ""
	

	-- if true then
	-- 	print("Slash command received: " .. cmd .. " " .. (args or ""))
	-- 	return
	-- end
		
	if cmd == "help" then
		self:ShowHelp()
	elseif cmd == "version" or cmd == "ver" then
		self:Print("Chronicle version " .. GetAddOnMetadata("ChronicleCompanion", "Version"))
	elseif cmd == "log" then
		local shouldEnable
		if arg == "1" or arg == "true" then
			shouldEnable = true
		elseif arg == "0" or arg == "false" then
			shouldEnable = false
		else
			-- No arg or invalid arg: toggle
			shouldEnable = not ChronicleLog:IsEnabled()
		end
		
		if shouldEnable and not ChronicleLog:IsEnabled() then
			ChronicleLog:Enable()
			self:Print("Combat logging enabled. Events will be written to file when disabled.")
		elseif not shouldEnable and ChronicleLog:IsEnabled() then
			local linesWritten = ChronicleLog:Disable()
			self:Print("Combat logging disabled. Wrote " .. linesWritten .. " events to file.")
		end
	elseif cmd =="config" or cmd == "advlog" or cmd == "advancedlog" then
		ChronicleLog:OpenOptionsPanel()
	elseif cmd == "time" or cmd == "timestamp" then
		local getTime = GetTime()
		local unixTime = time()
		local timeOffset = ChronicleLog.timeOffset or (unixTime - getTime)
		local msTimestamp = math.floor((getTime + timeOffset) * 1000)
		self:Print("=== Timestamp Debug ===")
		self:Print("GetTime(): " .. string.format("%.3f", getTime))
		self:Print("time(): " .. unixTime)
		self:Print("timeOffset: " .. string.format("%.3f", timeOffset))
		self:Print("MS Timestamp: " .. msTimestamp)
		local ms = math.mod(msTimestamp, 1000)
		self:Print("Verify: " .. date("%d.%m.%y %H:%M:%S", math.floor(msTimestamp / 1000)) .. string.format(".%03d", ms))
	elseif cmd == "save" then
		local lines = ChronicleLog:FlushToFile()
		if lines > 0 then
			self:Print("Saved " .. lines .. " lines to disk.")
		else
			self:Print("No lines to save.")
		end
	elseif cmd == "delete" then
		StaticPopup_Show("CHRONICLELOG_CLEAR_CONFIRM")
	elseif cmd == "ids" then
		local ids = ChronicleCompanionCharDB and ChronicleCompanionCharDB.lastInstanceIds
		if not ids or not next(ids) then
			self:Print("No saved instance IDs.")
		else
			self:Print("=== Saved Instance IDs ===")
			for zone, id in pairs(ids) do
				self:Print(zone .. ": " .. id)
			end
		end
	elseif cmd == "inspect" then
		if arg == "" then
			self:Print("Usage: /chronicle inspect <player name>")
		else
			ChronicleLog:ForceInspectPlayer(arg)
		end
	elseif cmd == "minimap" then
		local current = ChronicleLog:GetSetting("showMinimapIcon")
		local newVal = not current
		ChronicleLog:SetSetting("showMinimapIcon", newVal)
		ChronicleMinimapButton:SetShown(newVal)
		if newVal then
			self:Print("Minimap icon shown.")
		else
			self:Print("Minimap icon hidden. Type /chronicle minimap to show it again.")
		end
	else
		ChronicleLog:OpenOptionsPanel()
	end
end

function Chronicle:ShowHelp()
	self:Print("=== Chronicle Commands ===")
	self:Print("/chronicle log [1|0|true|false] - Toggle or set logging on/off")
	self:Print("/chronicle save - Save logs to disk")
	self:Print("/chronicle delete - Delete all logs (disk and memory)")
	self:Print("/chronicle version - Show addon version")
	self:Print("/chronicle config - Open options panel")
	self:Print("/chronicle ids - Show saved instance IDs")
	self:Print("/chronicle inspect <name> - Force talent inspection of a player")
	self:Print("/chronicle minimap - Toggle minimap icon visibility")
	self:Print("/chronicle help - Show this help")
	self:Print("/clog - Open chronicle log options")
end
