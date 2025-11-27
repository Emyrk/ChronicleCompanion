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