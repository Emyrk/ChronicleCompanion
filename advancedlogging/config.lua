-- =============================================================================
-- ChronicleLog Configuration - Settings and Options Panel
-- =============================================================================

-- Minimum required versions for dependencies (empty string = no minimum)
local MIN_VERSIONS = {
    superwow = "1.5",         
    unitxp3 = "1771083771",          
    nampower = "2.38.1",       
}

-- Default settings
local DEFAULTS = {
    autoEnableInRaid = true,
    autoEnableInDungeon = true,
    showLogReminder = true,
    autoCombatSave = false,
    rangeDefault = 40,
    rangeDungeon = 100,
    rangeRaid = 200,
    debugMode = false,
    debugChatFrame = 1,
    enabled = false,
}

-- =============================================================================
-- SavedVariables Management
-- =============================================================================

function ChronicleLog:InitConfig()
    if not ChronicleCompanionDB then ChronicleCompanionDB = {} end
    if not ChronicleCompanionDB.advancedLog then ChronicleCompanionDB.advancedLog = {} end
    for key, value in pairs(DEFAULTS) do
        if ChronicleCompanionDB.advancedLog[key] == nil then
            ChronicleCompanionDB.advancedLog[key] = value
        end
    end
end

function ChronicleLog:GetSetting(key)
    if ChronicleCompanionDB and ChronicleCompanionDB.advancedLog and ChronicleCompanionDB.advancedLog[key] ~= nil then
        return ChronicleCompanionDB.advancedLog[key]
    end
    return DEFAULTS[key]
end

function ChronicleLog:SetSetting(key, value)
    if not ChronicleCompanionDB then ChronicleCompanionDB = {} end
    if not ChronicleCompanionDB.advancedLog then ChronicleCompanionDB.advancedLog = {} end
    ChronicleCompanionDB.advancedLog[key] = value
end

-- =============================================================================
-- Version Checking
-- =============================================================================

-- Compare two version strings (supports numeric and dotted versions like "2.38.1")
-- Returns true if v1 >= v2
local function CompareVersions(v1, v2)
    if not v1 or not v2 or v2 == "" then return true end
    
    -- Try numeric comparison first (for timestamps like UnitXP3)
    local n1, n2 = tonumber(v1), tonumber(v2)
    if n1 and n2 then return n1 >= n2 end
    
    -- Dotted version comparison (e.g. "2.38.1")
    local parts1, parts2 = {}, {}
    for p in string.gfind(v1, "([^.]+)") do table.insert(parts1, tonumber(p) or 0) end
    for p in string.gfind(v2, "([^.]+)") do table.insert(parts2, tonumber(p) or 0) end
    
    for i = 1, math.max(table.getn(parts1), table.getn(parts2)) do
        local p1, p2 = parts1[i] or 0, parts2[i] or 0
        if p1 > p2 then return true end
        if p1 < p2 then return false end
    end
    return true
end

function ChronicleLog:CheckVersion(name)
    local version = nil
    local minVersion = MIN_VERSIONS[name] or ""
    
    if name == "addon" then
        version = GetAddOnMetadata("ChronicleCompanion", "Version")
    elseif name == "superwow" then
        version = SUPERWOW_VERSION
    elseif name == "unitxp3" then
        local ok, buildTime = pcall(UnitXP, "version", "coffTimeDateStamp")
        if ok and buildTime then version = tostring(buildTime) end
    elseif name == "nampower" then
        if GetNampowerVersion then
            local major, minor, patch = GetNampowerVersion()
            if major then version = major .. "." .. (minor or 0) .. "." .. (patch or 0) end
        end
    end
    
    if not version then
        return "Not Found", "ff0000"
    end
    
    -- Check against minimum version
    if minVersion ~= "" and not CompareVersions(version, minVersion) then
        return tostring(version), "ff0000"  -- Below minimum: red
    end
    
    return tostring(version), "00ff00"  -- OK: green
end

function ChronicleLog:CheckDependencies()
    local problems = {}
    
    local deps = { "superwow", "unitxp3", "nampower" }
    local names = { superwow = "SuperWoW", unitxp3 = "UnitXP3", nampower = "Nampower" }
    
    for _, dep in ipairs(deps) do
        local version, color = self:CheckVersion(dep)
        if color == "ff0000" then  -- red = problem
            local minVer = MIN_VERSIONS[dep] or ""
            if version == "Not Found" then
                table.insert(problems, names[dep] .. ": Not Found")
            else
                table.insert(problems, names[dep] .. ": " .. version .. " (need " .. minVer .. ")")
            end
        end
    end
    
    return problems
end

StaticPopupDialogs["CHRONICLELOG_DEPENDENCY_WARNING"] = {
    text = "ChronicleLog cannot function correctly.\n\nMissing or outdated dependencies:\n%s\n\nPlease update these dependencies or remove ChronicleCompanion addon.",
    button1 = "OK",
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

-- =============================================================================
-- Options Panel UI
-- =============================================================================

function ChronicleLog:CreateOptionsPanel()
    local panel = CreateFrame("Frame", "ChronicleLogOptionsPanel", UIParent)
    panel:SetWidth(520)
    panel:SetHeight(400)
    panel:SetPoint("CENTER", 0, 0)
    panel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function() this:StartMoving() end)
    panel:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    panel:Hide()
    
    local closeButton = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", -5, -5)
    
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -15)
    title:SetText("ChronicleLog Options")
    
    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOP", title, "BOTTOM", 0, -2)
    subtitle:SetText("Advanced combat logging settings")
    
    -- Layout constants
    local leftCol = 20
    local rightCol = 265
    local yStart = -50
    local yLeft = yStart
    local yRight = yStart
    
    -- =========================================================================
    -- SECTION 1: Status (Left Column)
    -- =========================================================================
    local statusLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    statusLabel:SetPoint("TOPLEFT", leftCol, yLeft)
    statusLabel:SetText("Logging:")
    local statusText = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    statusText:SetPoint("LEFT", statusLabel, "RIGHT", 5, 0)
    panel.statusText = statusText
    
    local toggleButton = CreateFrame("Button", "ChronicleLogToggleButton", panel, "UIPanelButtonTemplate")
    toggleButton:SetWidth(55)
    toggleButton:SetHeight(18)
    toggleButton:SetPoint("LEFT", statusLabel, "RIGHT", 55, 0)
    toggleButton:SetText("Toggle")
    toggleButton:SetScript("OnClick", function()
        if ChronicleLog:IsEnabled() then ChronicleLog:Disable() else ChronicleLog:Enable() end
        ChronicleLog:RefreshOptionsPanel()
    end)
    
    yLeft = yLeft - 18
    
    local rangeLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    rangeLabel:SetPoint("TOPLEFT", leftCol, yLeft)
    rangeLabel:SetText("Range:")
    local rangeText = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    rangeText:SetPoint("LEFT", rangeLabel, "RIGHT", 5, 0)
    panel.rangeText = rangeText
    
    yLeft = yLeft - 16
    
    local bufferLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    bufferLabel:SetPoint("TOPLEFT", leftCol, yLeft)
    bufferLabel:SetText("Buffer:")
    local bufferText = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    bufferText:SetPoint("LEFT", bufferLabel, "RIGHT", 5, 0)
    panel.bufferText = bufferText
    
    yLeft = yLeft - 16
    
    local instanceLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    instanceLabel:SetPoint("TOPLEFT", leftCol, yLeft)
    instanceLabel:SetText("Instance:")
    local instanceText = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    instanceText:SetPoint("LEFT", instanceLabel, "RIGHT", 5, 0)
    panel.instanceText = instanceText
    
    yLeft = yLeft - 22
    
    -- =========================================================================
    -- SECTION 2: Automatic Combat Logger (Right Column)
    -- =========================================================================
    local autoHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    autoHeader:SetPoint("TOPLEFT", rightCol, yRight)
    autoHeader:SetText("Automatic Combat Logger")
    yRight = yRight - 18
    
    local autoRaidCheck = CreateFrame("CheckButton", "ChronicleLogAutoRaid", panel, "UICheckButtonTemplate")
    autoRaidCheck:SetPoint("TOPLEFT", rightCol, yRight)
    getglobal(autoRaidCheck:GetName() .. "Text"):SetText("Auto-enable in Raids")
    autoRaidCheck:SetScript("OnClick", function()
        ChronicleLog:SetSetting("autoEnableInRaid", this:GetChecked() == 1)
        ChronicleLog:RefreshOptionsPanel()
    end)
    panel.autoRaidCheck = autoRaidCheck
    
    yRight = yRight - 20
    
    local autoDungeonCheck = CreateFrame("CheckButton", "ChronicleLogAutoDungeon", panel, "UICheckButtonTemplate")
    autoDungeonCheck:SetPoint("TOPLEFT", rightCol, yRight)
    getglobal(autoDungeonCheck:GetName() .. "Text"):SetText("Auto-enable in Dungeons")
    autoDungeonCheck:SetScript("OnClick", function()
        ChronicleLog:SetSetting("autoEnableInDungeon", this:GetChecked() == 1)
        ChronicleLog:RefreshOptionsPanel()
    end)
    panel.autoDungeonCheck = autoDungeonCheck
    
    yRight = yRight - 20
    
    local reminderCheck = CreateFrame("CheckButton", "ChronicleLogReminder", panel, "UICheckButtonTemplate")
    reminderCheck:SetPoint("TOPLEFT", rightCol, yRight)
    getglobal(reminderCheck:GetName() .. "Text"):SetText("Show Reminder")
    reminderCheck:SetScript("OnClick", function()
        ChronicleLog:SetSetting("showLogReminder", this:GetChecked() == 1)
    end)
    panel.reminderCheck = reminderCheck
    
    local reminderDesc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    reminderDesc:SetPoint("TOPLEFT", rightCol + 98, yRight-11)
    reminderDesc:SetText("(disabled when auto is on)")
    reminderDesc:SetTextColor(0.5, 0.5, 0.5)
    panel.reminderDesc = reminderDesc
    
    yRight = yRight - 20

    local autoCombatSaveCheck = CreateFrame("CheckButton", "ChronicleLogAutoCombatSave", panel, "UICheckButtonTemplate")
    autoCombatSaveCheck:SetPoint("TOPLEFT", rightCol, yRight)
    getglobal(autoCombatSaveCheck:GetName() .. "Text"):SetText("Auto-save when leaving combat")
    autoCombatSaveCheck:SetScript("OnClick", function()
        ChronicleLog:SetSetting("autoCombatSave", this:GetChecked() == 1)
        ChronicleLog:RefreshOptionsPanel()
    end)
    panel.autoCombatSaveCheck = autoCombatSaveCheck

    yRight = yRight - 32

    -- Sync columns
    local yRow2 = math.min(yLeft, yRight)
    yLeft = yRow2
    yRight = yRow2
    
    -- =========================================================================
    -- SECTION 3: Versions (Left Column)
    -- =========================================================================
    local versionHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    versionHeader:SetPoint("TOPLEFT", leftCol, yLeft)
    versionHeader:SetText("Version Info")
    yLeft = yLeft - 16
    
    local addonVerLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    addonVerLabel:SetPoint("TOPLEFT", leftCol, yLeft)
    addonVerLabel:SetText("Addon:")
    local addonVerText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    addonVerText:SetPoint("LEFT", addonVerLabel, "RIGHT", 5, 0)
    panel.addonVerText = addonVerText
    
    yLeft = yLeft - 14
    
    local swVerLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    swVerLabel:SetPoint("TOPLEFT", leftCol, yLeft)
    swVerLabel:SetText("SuperWoW:")
    local swVerText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    swVerText:SetPoint("LEFT", swVerLabel, "RIGHT", 5, 0)
    panel.swVerText = swVerText
    
    yLeft = yLeft - 14
    
    local xp3VerLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    xp3VerLabel:SetPoint("TOPLEFT", leftCol, yLeft)
    xp3VerLabel:SetText("UnitXP3:")
    local xp3VerText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    xp3VerText:SetPoint("LEFT", xp3VerLabel, "RIGHT", 5, 0)
    panel.xp3VerText = xp3VerText
    
    yLeft = yLeft - 14
    
    local npVerLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    npVerLabel:SetPoint("TOPLEFT", leftCol, yLeft)
    npVerLabel:SetText("Nampower:")
    local npVerText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    npVerText:SetPoint("LEFT", npVerLabel, "RIGHT", 5, 0)
    panel.npVerText = npVerText
    
    yLeft = yLeft - 22
    
    -- =========================================================================
    -- SECTION 4: Combat Log Range Sliders (Right Column)
    -- =========================================================================
    local rangeHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    rangeHeader:SetPoint("TOPLEFT", rightCol, yRight)
    rangeHeader:SetText("Combat Log Range")
    local rangeHeaderDesc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    rangeHeaderDesc:SetPoint("LEFT", rangeHeader, "RIGHT", 5, 0)
    rangeHeaderDesc:SetText("(higher = more complete)")
    rangeHeaderDesc:SetTextColor(0.5, 0.5, 0.5)
    yRight = yRight - 28
    
    local sliderWidth = 200
    
    local defaultRangeSlider = CreateFrame("Slider", "ChronicleLogRangeDefault", panel, "OptionsSliderTemplate")
    defaultRangeSlider:SetPoint("TOPLEFT", rightCol, yRight)
    defaultRangeSlider:SetWidth(sliderWidth)
    defaultRangeSlider:SetMinMaxValues(10, 200)
    defaultRangeSlider:SetValueStep(10)
    getglobal(defaultRangeSlider:GetName() .. "Low"):SetText("10")
    getglobal(defaultRangeSlider:GetName() .. "High"):SetText("200")
    getglobal(defaultRangeSlider:GetName() .. "Text"):SetText("Default: 40")
    defaultRangeSlider:SetScript("OnValueChanged", function()
        local value = math.floor(this:GetValue())
        ChronicleLog:SetSetting("rangeDefault", value)
        getglobal(this:GetName() .. "Text"):SetText("Default: " .. value)
        ChronicleLog:RefreshOptionsPanel()
    end)
    panel.defaultRangeSlider = defaultRangeSlider
    
    yRight = yRight - 32
    
    local dungeonRangeSlider = CreateFrame("Slider", "ChronicleLogRangeDungeon", panel, "OptionsSliderTemplate")
    dungeonRangeSlider:SetPoint("TOPLEFT", rightCol, yRight)
    dungeonRangeSlider:SetWidth(sliderWidth)
    dungeonRangeSlider:SetMinMaxValues(10, 200)
    dungeonRangeSlider:SetValueStep(10)
    getglobal(dungeonRangeSlider:GetName() .. "Low"):SetText("10")
    getglobal(dungeonRangeSlider:GetName() .. "High"):SetText("200")
    getglobal(dungeonRangeSlider:GetName() .. "Text"):SetText("Dungeon: 100")
    dungeonRangeSlider:SetScript("OnValueChanged", function()
        local value = math.floor(this:GetValue())
        ChronicleLog:SetSetting("rangeDungeon", value)
        getglobal(this:GetName() .. "Text"):SetText("Dungeon: " .. value)
        ChronicleLog:RefreshOptionsPanel()
    end)
    panel.dungeonRangeSlider = dungeonRangeSlider
    
    yRight = yRight - 32
    
    local raidRangeSlider = CreateFrame("Slider", "ChronicleLogRangeRaid", panel, "OptionsSliderTemplate")
    raidRangeSlider:SetPoint("TOPLEFT", rightCol, yRight)
    raidRangeSlider:SetWidth(sliderWidth)
    raidRangeSlider:SetMinMaxValues(10, 200)
    raidRangeSlider:SetValueStep(10)
    getglobal(raidRangeSlider:GetName() .. "Low"):SetText("10")
    getglobal(raidRangeSlider:GetName() .. "High"):SetText("200")
    getglobal(raidRangeSlider:GetName() .. "Text"):SetText("Raid: 150")
    raidRangeSlider:SetScript("OnValueChanged", function()
        local value = math.floor(this:GetValue())
        ChronicleLog:SetSetting("rangeRaid", value)
        getglobal(this:GetName() .. "Text"):SetText("Raid: " .. value)
        ChronicleLog:RefreshOptionsPanel()
    end)
    panel.raidRangeSlider = raidRangeSlider
    
    yRight = yRight - 30
    
    -- Sync columns
    local yRow3 = math.min(yLeft, yRight)
    yLeft = yRow3
    yRight = yRow3
    
    -- =========================================================================
    -- SECTION 5: Debug (Left Column)
    -- =========================================================================
    local debugHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    debugHeader:SetPoint("TOPLEFT", leftCol, yLeft)
    debugHeader:SetText("Debug")
    yLeft = yLeft - 18
    
    local debugCheck = CreateFrame("CheckButton", "ChronicleLogDebug", panel, "UICheckButtonTemplate")
    debugCheck:SetPoint("TOPLEFT", leftCol, yLeft)
    getglobal(debugCheck:GetName() .. "Text"):SetText("Debug Mode")
    debugCheck:SetScript("OnClick", function()
        ChronicleLog:SetSetting("debugMode", this:GetChecked() == 1)
    end)
    panel.debugCheck = debugCheck
    
    yLeft = yLeft - 32
    
    local debugChatLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    debugChatLabel:SetPoint("TOPLEFT", leftCol, yLeft)
    debugChatLabel:SetText("Output:")
    
    local debugChatDropdown = CreateFrame("Frame", "ChronicleLogDebugChat", panel, "UIDropDownMenuTemplate")
    debugChatDropdown:SetPoint("LEFT", debugChatLabel, "RIGHT", -5, -2)
    
    local function GetChatWindowName(index)
        local tab = getglobal("ChatFrame" .. index .. "Tab")
        if tab then return tab:GetText() or ("Chat " .. index) end
        return "Chat " .. index
    end
    
    local function DebugChatDropdown_Initialize()
        for i = 1, NUM_CHAT_WINDOWS do
            local frame = getglobal("ChatFrame" .. i)
            if frame then
                local info = {}
                info.text = GetChatWindowName(i)
                info.value = i
                info.func = function()
                    ChronicleLog:SetSetting("debugChatFrame", this.value)
                    UIDropDownMenu_SetSelectedValue(debugChatDropdown, this.value)
                    UIDropDownMenu_SetText(GetChatWindowName(this.value), debugChatDropdown)
                end
                info.checked = (ChronicleLog:GetSetting("debugChatFrame") == i)
                UIDropDownMenu_AddButton(info)
            end
        end
    end
    
    UIDropDownMenu_Initialize(debugChatDropdown, DebugChatDropdown_Initialize)
    UIDropDownMenu_SetWidth(100, debugChatDropdown)
    panel.debugChatDropdown = debugChatDropdown
    panel.GetChatWindowName = GetChatWindowName
    
    -- =========================================================================
    -- SECTION 6: Log Management (Right Column)
    -- =========================================================================
    local logHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    logHeader:SetPoint("TOPLEFT", rightCol, yRight)
    logHeader:SetText("Log Management")
    yRight = yRight - 20
    
    -- Row 1: Flush + Clear
    local flushButton = CreateFrame("Button", "ChronicleLogFlushButton", panel, "UIPanelButtonTemplate")
    flushButton:SetWidth(105)
    flushButton:SetHeight(22)
    flushButton:SetPoint("TOPLEFT", rightCol, yRight)
    flushButton:SetText("Save")
    flushButton:SetScript("OnClick", function()
        local lines = ChronicleLog:FlushToFile()
        Chronicle:Print("Flushed " .. lines .. " lines to disk.")
        ChronicleLog:RefreshOptionsPanel()
    end)
    
    local clearButton = CreateFrame("Button", "ChronicleLogClearButton", panel, "UIPanelButtonTemplate")
    clearButton:SetWidth(105)
    clearButton:SetHeight(22)
    clearButton:SetPoint("LEFT", flushButton, "RIGHT", 5, 0)
    clearButton:SetText("Delete Logs")
    clearButton:SetScript("OnClick", function()
        StaticPopup_Show("CHRONICLELOG_CLEAR_CONFIRM")
    end)
    
    yRight = yRight - 32
    
    -- Row 2: Suffix input + Move Logs
    local moveLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    moveLabel:SetPoint("TOPLEFT", rightCol, yRight + 3)
    moveLabel:SetText("Name:")
    
    local moveEditBox = CreateFrame("EditBox", "ChronicleLogMoveEditBox", panel, "InputBoxTemplate")
    moveEditBox:SetWidth(80)
    moveEditBox:SetHeight(20)
    moveEditBox:SetPoint("LEFT", moveLabel, "RIGHT", 8, 0)
    moveEditBox:SetAutoFocus(false)
    moveEditBox:SetMaxLetters(20)
    
    local moveButton = CreateFrame("Button", "ChronicleLogMoveButton", panel, "UIPanelButtonTemplate")
    moveButton:SetWidth(80)
    moveButton:SetHeight(22)
    moveButton:SetPoint("LEFT", moveEditBox, "RIGHT", 5, 0)
    moveButton:SetText("Backup")
    moveButton:Disable()
    
    moveEditBox:SetScript("OnTextChanged", function()
        local text = this:GetText()
        if text and text ~= "" then
            moveButton:Enable()
        else
            moveButton:Disable()
        end
    end)
    
    moveButton:SetScript("OnClick", function()
        local suffix = moveEditBox:GetText()
        if not suffix or suffix == "" then return end
        
        local playerName = UnitName("player") or "Unknown"
        local currentFile = "Chronicle_" .. playerName
        local timestamp = time()
        local newFile = "Chronicle_" .. playerName .. "_" .. suffix .. "_" .. timestamp
        
        local existing = ImportFile(currentFile) or ""
        local bufferContent = ""
        if ChronicleLog.bufferSize > 0 then
            bufferContent = table.concat(ChronicleLog.buffer, "\n")
            if existing ~= "" then existing = existing .. "\n" end
        end
        
        ExportFile(newFile, existing .. bufferContent)
        ExportFile(currentFile, "")
        ChronicleLog.buffer = {}
        ChronicleLog.bufferSize = 0
        
        Chronicle:Print("Moved logs to: " .. newFile)
        moveEditBox:SetText("")
        ChronicleLog:RefreshOptionsPanel()
    end)
    
    yRight = yRight - 26
    
    -- Row 3: Reset Settings
    local resetButton = CreateFrame("Button", "ChronicleLogResetButton", panel, "UIPanelButtonTemplate")
    resetButton:SetWidth(105)
    resetButton:SetHeight(22)
    resetButton:SetPoint("TOPLEFT", rightCol, yRight)
    resetButton:SetText("Reset Settings")
    resetButton:SetScript("OnClick", function()
        ChronicleCompanionDB.advancedLog = {}
        ChronicleLog:InitConfig()
        Chronicle:Print("Settings reset to defaults.")
        ChronicleLog:RefreshOptionsPanel()
    end)

    self.optionsPanel = panel
    tinsert(UISpecialFrames, "ChronicleLogOptionsPanel")
end

-- Clear confirmation popup
StaticPopupDialogs["CHRONICLELOG_CLEAR_CONFIRM"] = {
    text = "Are you sure you want to delete all logs (disk and memory)?",
    button1 = "Yes, Delete",
    button2 = "Cancel",
    OnAccept = function()
        local filename = "Chronicle_" .. (UnitName("player") or "Unknown")
        ExportFile(filename, "")
        ChronicleLog:ClearBuffer()
        ChronicleLog:PurgeUnits()
        -- Write fresh zone info to start the new log (bypass enabled check)
        ChronicleLog:WriteZoneInfo(true)
        Chronicle:Print("Deleted all logs: " .. filename)
        ChronicleLog:RefreshOptionsPanel()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function ChronicleLog:OpenOptionsPanel()
    if not self.optionsPanel then self:CreateOptionsPanel() end
    self:RefreshOptionsPanel()
    self.optionsPanel:Show()
end

function ChronicleLog:RefreshOptionsPanel()
    if not self.optionsPanel then return end
    local panel = self.optionsPanel
    
    if self:IsEnabled() then
        panel.statusText:SetText("|cff00ff00ON|r")
    else
        panel.statusText:SetText("|cffff0000OFF|r")
    end
    
    panel.bufferText:SetText("|cffffff00" .. (self.bufferSize or 0) .. " lines|r")
    
    local inInstance, instanceType = IsInInstance()
    local currentRange
    if inInstance then
        if instanceType == "raid" then
            currentRange = self:GetSetting("rangeRaid")
        else
            currentRange = self:GetSetting("rangeDungeon")
        end
    else
        currentRange = self:GetSetting("rangeDefault")
    end
    panel.rangeText:SetText("|cffffff00" .. currentRange .. " yards|r")
    
    if inInstance then
        local typeNames = { party = "Yes - Dungeon", raid = "Yes - Raid", pvp = "Yes - PvP", arena = "Yes - Arena" }
        local displayType = typeNames[instanceType] or ("Yes - " .. (instanceType or "Unknown"))
        panel.instanceText:SetText("|cff00ff00" .. displayType .. "|r")
    else
        panel.instanceText:SetText("|cffff0000No|r")
    end
    
    local addonVer, addonColor = self:CheckVersion("addon")
    panel.addonVerText:SetText("|cff" .. addonColor .. addonVer .. "|r")
    local swVer, swColor = self:CheckVersion("superwow")
    panel.swVerText:SetText("|cff" .. swColor .. swVer .. "|r")
    local xp3Ver, xp3Color = self:CheckVersion("unitxp3")
    panel.xp3VerText:SetText("|cff" .. xp3Color .. xp3Ver .. "|r")
    local npVer, npColor = self:CheckVersion("nampower")
    panel.npVerText:SetText("|cff" .. npColor .. npVer .. "|r")
    
    panel.autoRaidCheck:SetChecked(self:GetSetting("autoEnableInRaid"))
    panel.autoDungeonCheck:SetChecked(self:GetSetting("autoEnableInDungeon"))
    panel.reminderCheck:SetChecked(self:GetSetting("showLogReminder"))
    panel.autoCombatSaveCheck:SetChecked(self:GetSetting("autoCombatSave"))
    panel.debugCheck:SetChecked(self:GetSetting("debugMode"))
    
    local autoEnabled = self:GetSetting("autoEnableInRaid") and self:GetSetting("autoEnableInDungeon")
    if autoEnabled then
        panel.reminderCheck:Disable()
        getglobal(panel.reminderCheck:GetName() .. "Text"):SetTextColor(0.5, 0.5, 0.5)
        panel.reminderDesc:SetText("(disabled - auto-enable is on)")
    else
        panel.reminderCheck:Enable()
        getglobal(panel.reminderCheck:GetName() .. "Text"):SetTextColor(1, 1, 1)
        panel.reminderDesc:SetText("(disabled when auto-enable is on)")
    end
    
    panel.defaultRangeSlider:SetValue(self:GetSetting("rangeDefault"))
    panel.dungeonRangeSlider:SetValue(self:GetSetting("rangeDungeon"))
    panel.raidRangeSlider:SetValue(self:GetSetting("rangeRaid"))
    
    local chatFrameIndex = self:GetSetting("debugChatFrame")
    UIDropDownMenu_SetSelectedValue(panel.debugChatDropdown, chatFrameIndex)
    UIDropDownMenu_SetText(panel.GetChatWindowName(chatFrameIndex), panel.debugChatDropdown)
end
