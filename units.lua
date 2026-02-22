-- Handles all unit logging to combat logs

---@class ChronicleUnits
---@field units table<string, Unit> map of unit GUID to Unit
---@lastCleanup number timestamp of last cleanup
---@challenges string comma-separated list of challenges of the player
ChronicleUnits = {
  units = {},
  lastCleanup = 0,
  challenges = "na",
}

---@class Unit
---@field id string unit GUID
---@field name string unit name
---@field owner string guid of owner or ""
---@field last_seen number timestamp of last seen
---@field canCooperate boolean whether unit can cooperate
---@field logged number timestamp of last logged
---@field level number unit level

function InitChronicleUnits()
	if not ChronicleUnits.units then
		ChronicleUnits.units = {}
	end

  ChronicleUnits.challenges = ChronicleUnits:PlayerChallenges()
	if ChronicleUnits.challenges ~= "" then
		Chronicle:Print("Player challenges: " .. ChronicleUnits.challenges)
	end
end

--- Returns a string representation of the unit's buffs in csv format
---@param guid string
---@return string
function ChronicleUnits:unitBuffs(guid)
	local auras = ""
	local prefix = ""
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

-- Map spell name -> key you want in the return table
-- TODO: Switch to spell ids, as names can be localized
local CHALLENGE_SPELLS = {
  ["enUS"] = {
    ["Level One Lunatic"] = "lunatic",
    ["Hardcore"] = "hardcore",
    ["Boaring Adventure"] = "boaring",
    ["Path of the Brewmaster"] = "brewmaster",
    ["Exhaustion"] = "exhaustion",
    ["Slow & Steady"] = "slowsteady",
    ["Traveling Craftmaster"] = "craftmaster",
    ["Vagrant's Endeavor"] = "vagrant",
  },
  -- I need people with different language clients to fill this in.
  -- ["enGB"] = {

  -- },
  -- ["deDE"] = {

  -- },
  -- ["esES"] = {

  -- },
  -- ["frFR"] = {

  -- },
  -- ["ruRU"] = {

  -- },
}

-- PlayerChallenges returns a comma-separated list of challenge keys the player has
--- @return string
function ChronicleUnits:PlayerChallenges()
  local _, locale = GetLocale()

  local spellNames = CHALLENGE_SPELLS[locale]
  if spellNames == nil then
    -- Fallback to enUS
    spellNames = CHALLENGE_SPELLS["enUS"]
  end

  local challenges = {}
  for tab = 1, GetNumSpellTabs() do
    local _, _, offset, numSpells = GetSpellTabInfo(tab)
    for i = 1, numSpells do
      local name = GetSpellName(offset + i, "spell")
      local key = name and spellNames[name]
      if key then
        challenges[key] = true
      end
    end
  end

	local keys = {}
	for k in pairs(challenges) do table.insert(keys, k) end
	table.sort(keys)
	return table.concat(keys, ",")
end

--- Add or update a unit in the database
--- @param guid string
--- @param force boolean optional, force update even if recently logged
function ChronicleUnits:UpdateUnit(id, force)
	if not id then return end
  
  -- always fetch the guid properly
  local ok, guid = UnitExists(id)
  if not ok then return end

	local unitData = self.units[guid] or {}
	local lastLogged = unitData.logged or 0
	if (not force) and time() - lastLogged < 300 then
		return
	end

  if UnitName(guid) == nil then
    -- This should not happen, but just in case
    return
  end

	unitData.id = guid
	unitData.name = UnitName(guid)
	unitData.owner = ""
	unitData.last_seen = time()
	unitData.canCooperate = UnitCanCooperate("player", guid)
	unitData.logged = time()
	unitData.level = UnitLevel(guid)
	-- No need to cache this info.
	local buffs = ChronicleUnits:unitBuffs(guid)

	-- Check for owner unit
	local ok, ownerGuid = UnitExists(guid.."owner")
	if ok then
		unitData.owner = ownerGuid
	end

	self.units[guid] = unitData

	local logLine = string.format("UNIT_INFO: %s&%s&%s&%s&%s&%s&%s&%s&%s&%s",
		date("%d.%m.%y %H:%M:%S"),
		unitData.id,
		UnitIsUnit(unitData.id, "player") and "1" or "0",
		unitData.name,
		unitData.canCooperate and "1" or "0",
		unitData.owner or "",
		buffs or "",
		unitData.level or "0",
		-- Dump the player challenges if it is the player
		UnitIsUnit(unitData.id, "player") and self.challenges or "na",
		UnitHealthMax(unitData.id)
	)
	CombatLogAdd(logLine, 1)
	-- Chronicle:DebugPrint(logLine)
	ChronicleUnits:CleanupOldUnits()
end


function ChronicleUnits:Reset()
	self.units = {}
	Chronicle:DebugPrint("Chronicle units database reset.")
end

--- Clean up old units that haven't been seen in a while
function ChronicleUnits:CleanupOldUnits(timeoutSeconds)
	local currentTime = time()
	timeoutSeconds = timeoutSeconds or 300  -- Default 5 minutes
	if self.lastCleanup and (currentTime - self.lastCleanup) < timeoutSeconds then
		return 0 -- Skip cleanup if done recently
	end

	local removed = 0
	
	for guid, unit in pairs(self.units) do
		if unit.last_seen and (currentTime - unit.last_seen) > timeoutSeconds then
			self.units[guid] = nil
			removed = removed + 1
		end
	end
	
	self.lastCleanup = time()
	return removed
end