-- Get statistics about stored units
function Chronicle:GetStats()
	local count = 0
	local oldestSeen = time()
	local newestSeen = 0
	
	for guid, unit in pairs(ChronicleUnits.units) do
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
	Chronicle:Print("=== Database Statistics ===")
	Chronicle:Print("Total units: " .. stats.count)
	
	if stats.count > 0 then
		local currentTime = time()
		local oldestAge = currentTime - stats.oldest_seen
		local newestAge = currentTime - stats.newest_seen
		
		Chronicle:Print("Oldest seen: " .. self:FormatTime(oldestAge) .. " ago")
		Chronicle:Print("Newest seen: " .. self:FormatTime(newestAge) .. " ago")
	end
	
	Chronicle:Print("===========================")
end


-- Helpful to check out some events
-- local f = CreateFrame("Frame")

-- local function RegisterEvent(name)
--     f:UnregisterAllEvents()
--     f:RegisterEvent(name)
--     print("Now listening to:", name)
-- end

-- SLASH_LOGEVENT1 = "/logevent"
-- SlashCmdList["LOGEVENT"] = function(msg)
--     if msg and msg ~= "" then
--         RegisterEvent(msg)
--     else
--         print("Usage: /logevent EVENT_NAME")
--     end
-- end

-- f:SetScript("OnEvent", function()
--     print("Event fired:", event)

--     local i = 1
--     while _G["arg"..i] ~= nil do
--         print("Arg", i, "=", tostring(_G["arg"..i]))
--         i = i + 1
--     end

--     print("----")
-- end)

-- -- Default
-- RegisterEvent("RAW_COMBATLOG")

-- local ADDON = "ChronicleFileRoundTrip"

-- -- 1MB payload in memory (created once, reused on every click)
-- local ONE_MB = string.rep("x", 1024 * 1024*20)

-- local INPUT_NAME  = "chronicle"
-- local OUTPUT_NAME = "chronicle"

-- local function ReadFile(name)
--   if type(ImportFile) == "function" then
--     return ImportFile(name)
--   end
--   return nil, "ImportFile() not available in this client/mod"
-- end

-- local function WriteFile(name, data)
--   if type(ExportFile) == "function" then
--     ExportFile(name, data)
--     return true
--   end
--   return false, "ExportFile() not available in this client/mod"
-- end

-- local function Now()
--   return date("%Y-%m-%d %H:%M:%S")
-- end

-- -- formats seconds nicely (ms)
-- local function fmt_ms(sec)
--   return string.format("%.2fms", sec * 1000)
-- end

-- local btn

-- local function CreateButton()
--   if btn then return end

--   btn = CreateFrame("Button", "ChronicleFileRoundTripButton", UIParent, "UIPanelButtonTemplate")
--   btn:SetWidth(220)
--   btn:SetHeight(28)
--   btn:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
--   btn:SetText("Chronicle: Import → +1MB → Export")
--   btn:Show()

--   btn:SetScript("OnClick", function()
--     local t0 = GetTime()

--     local before, readErr = ReadFile(INPUT_NAME)
--     local t1 = GetTime()

--     if not before then
--       before = ""
--       DEFAULT_CHAT_FRAME:AddMessage(
--         string.format("|cffffcc00[%s]|r No input read (%s). Using empty string.", ADDON, readErr or "unknown")
--       )
--     else
--       DEFAULT_CHAT_FRAME:AddMessage(
--         string.format("|cff00ff00[%s]|r Read %d bytes from %s", ADDON, string.len(before), INPUT_NAME)
--       )
--     end

--     local toAdd = "\n[" .. ADDON .. " " .. Now() .. "] +1MB payload\n" .. ONE_MB
--     local out = before .. toAdd
--     local t2 = GetTime()

--     local ok, writeErr = WriteFile(OUTPUT_NAME, out)
--     local t3 = GetTime()

--     if ok then
--       DEFAULT_CHAT_FRAME:AddMessage(
--         string.format("|cff00ff00[%s]|r Queued export %d bytes to %s", ADDON, string.len(out), OUTPUT_NAME)
--       )
--       DEFAULT_CHAT_FRAME:AddMessage(
--         string.format("|cffffcc00[%s]|r Note: many clients only actually write on /reload or logout.", ADDON)
--       )
--     else
--       DEFAULT_CHAT_FRAME:AddMessage(
--         string.format("|cffff0000[%s]|r Export failed: %s", ADDON, writeErr or "unknown")
--       )
--     end

--     -- Timing output
--     DEFAULT_CHAT_FRAME:AddMessage(string.format(
--       "|cff00ffff[%s]|r Timings: read=%s, build=%s, export_call=%s, total=%s",
--       ADDON,
--       fmt_ms(t1 - t0),
--       fmt_ms(t2 - t1),
--       fmt_ms(t3 - t2),
--       fmt_ms(t3 - t0)
--     ))
--   end)

--   DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ff00[%s]|r Loaded. Click the button to test file round-trip.", ADDON))
-- end

-- local f = CreateFrame("Frame")
-- f:RegisterEvent("PLAYER_LOGIN")
-- f:SetScript("OnEvent", function()
--   CreateButton()
--   DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00["..ADDON.."]|r Loaded. Use /chronicle to toggle.")
-- end)
