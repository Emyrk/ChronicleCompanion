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
