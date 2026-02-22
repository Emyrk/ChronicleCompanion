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
		
	elseif cmd == "stats" then
		self:ShowStats()
		
	elseif cmd == "cleanup" then
		local timeout = tonumber(arg) or 300
		local removed = ChronicleUnits:CleanupOldUnits(timeout)
		self:Print("Cleaned up " .. removed .. " units not seen in " .. self:FormatTime(timeout))
		
	elseif cmd == "clear" then
		self:Reset()
		self:Print("Database cleared!")
		
	elseif cmd == "version" or cmd == "ver" then
		self:Print("Chronicle version " .. self.version)
		
	elseif cmd == "config" or cmd == "options" then
		self:OpenOptionsPanel()
	elseif cmd == "log" then
		if(ChronicleLog:IsEnabled()) then
			local linesWritten = ChronicleLog:Disable()
			self:Print("Combat logging disabled. Wrote " .. linesWritten .. " events to file.")
		else
			ChronicleLog:Enable()
			self:Print("Combat logging enabled. Events will be written to file when disabled.")
		end
	elseif cmd == "advlog" or cmd == "advancedlog" then
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
	else
		self:Print("Unknown command. Type '/chronicle help' for available commands.")
	end
end

function Chronicle:ShowHelp()
	self:Print("=== Chronicle Commands ===")
	self:Print("/chronicle log - Toggle advanced combat logging")
	self:Print("/chronicle advlog - Open advanced logging options")
	self:Print("/chronicle time - Debug timestamp calculation")
	self:Print("/chronicle stats - Show database statistics")
	self:Print("/chronicle cleanup [seconds] - Remove units not seen in X seconds (default 300)")
	self:Print("/chronicle clear - Clear entire database")
	self:Print("/chronicle version - Show addon version")
	self:Print("/chronicle config - Open options panel")
	self:Print("/chronicle help - Show this help")
end