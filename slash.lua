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
    for part in string.gmatch(str, "([^" .. delim .. "]+)") do
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
		
	else
		self:Print("Unknown command. Type '/chronicle help' for available commands.")
	end
end

function Chronicle:ShowHelp()
	self:Print("=== Chronicle Commands ===")
	self:Print("/chronicle stats - Show database statistics")
	self:Print("/chronicle cleanup [seconds] - Remove units not seen in X seconds (default 300)")
	self:Print("/chronicle clear - Clear entire database")
	self:Print("/chronicle version - Show addon version")
	self:Print("/chronicle config - Open options panel")
	self:Print("/chronicle help - Show this help")
end