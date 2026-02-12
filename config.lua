-- =============================================================================
-- Configuration System
-- =============================================================================

-- Default settings
local DEFAULTS = {
    turtlogsCompatibility = true,
    autoCombatLogToggle = true,
    disableCombatlogReminder = false,
    debugMode = false,
    debugChatFrame = 1,
    combatLogRangeDefault = 40,
    combatLogRangeInstance = 200,
}

-- =============================================================================
-- SavedVariables Management
-- =============================================================================

function Chronicle:InitializeConfig()
    -- Initialize saved variables with defaults
    if not ChronicleCompanionDB then
        ChronicleCompanionDB = {}
    end
    
    -- Merge defaults (preserves existing values, adds missing ones)
    for key, value in pairs(DEFAULTS) do
        if ChronicleCompanionDB[key] == nil then
            ChronicleCompanionDB[key] = value
        end
    end
end

--- Get a setting value from saved variables, or return the default.
---@param key string Setting key (e.g., "debugMode", "combatLogRangeDefault")
---@return any value The setting value (type depends on the setting)
function Chronicle:GetSetting(key)
    if ChronicleCompanionDB and ChronicleCompanionDB[key] ~= nil then
        return ChronicleCompanionDB[key]
    end
    return DEFAULTS[key]
end

--- Set a setting value in saved variables.
---@param key string Setting key (e.g., "debugMode", "combatLogRangeDefault")
---@param value any The value to set (boolean, number, or string depending on setting)
function Chronicle:SetSetting(key, value)
    if not ChronicleCompanionDB then
        ChronicleCompanionDB = {}
    end
    ChronicleCompanionDB[key] = value
end

-- =============================================================================
-- Debug Output
-- =============================================================================

--- Print a debug message to the configured chat window (only if debug mode is enabled).
---@param msg string|number The message to print
function Chronicle:DebugPrint(msg)
    if not self:GetSetting("debugMode") then
        return
    end
    
    local frameIndex = self:GetSetting("debugChatFrame") or 1
    local frame = getglobal("ChatFrame" .. frameIndex)
    if not frame then
        frame = DEFAULT_CHAT_FRAME
    end
    
    frame:AddMessage("|cff88ffff[Chronicle Debug]|r " .. tostring(msg))
end

-- =============================================================================
-- Combat Log Range Management
-- =============================================================================

--- Get the current combat log range from CVars.
---@return number range The current combat log range in yards
function Chronicle:GetCombatLogRange()
    -- Try to get the CVar - different clients may use different names
    local range = tonumber(GetCVar("CombatLogRangeParty")) 
               or tonumber(GetCVar("CombatLogRangeHostilePlayers"))
               or tonumber(GetCVar("CombatLogRange"))
               or 50  -- fallback default
    return range
end

--- Apply combat log range based on whether player is in an instance.
---@param isInstance boolean Whether the player is currently in an instance
function Chronicle:ApplyCombatLogRange(isInstance)
    local range
    if isInstance then
        range = self:GetSetting("combatLogRangeInstance")
    else
        range = self:GetSetting("combatLogRangeDefault")
    end
    
    self:SetCombatLogRange(range)
    self:DebugPrint("Set combat log range to " .. range .. " yards (inInstance=" .. tostring(isInstance) .. ")")
end

--- Set the combat log range CVars.
---@param range number The range in yards to set
function Chronicle:SetCombatLogRange(range)
    -- Set all known combat log range CVars for compatibility
    if SetCVar then
        SetCVar("CombatLogRangeParty", range)
        SetCVar("CombatLogRangeFriendlyPlayers", range)
        SetCVar("CombatLogRangeHostilePlayers", range)
        SetCVar("CombatLogRangeFriendlyPlayersPets", range)
        SetCVar("CombatLogRangeHostilePlayersPets", range)
        SetCVar("CombatLogRangeCreature", range)
    end
end

-- =============================================================================
-- Options Panel UI (Vanilla-compatible standalone frame)
-- =============================================================================

function Chronicle:CreateOptionsPanel()
    -- Main frame
    local panel = CreateFrame("Frame", "ChronicleOptionsPanel", UIParent)
    panel:SetWidth(350)
    panel:SetHeight(545)
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
    
    -- Close button
    local closeButton = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", -5, -5)
    
    -- Title
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -20)
    title:SetText("ChronicleCompanion Options")
    
    -- Subtitle
    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOP", title, "BOTTOM", 0, -4)
    subtitle:SetText("Configure combat logging behavior")
    
    -- =============================================================================
    -- Combat Log Status Indicator
    -- =============================================================================
    local statusLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    statusLabel:SetPoint("TOPLEFT", 20, -55)
    statusLabel:SetText("Combat Logging:")
    
    local statusText = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    statusText:SetPoint("LEFT", statusLabel, "RIGHT", 5, 0)
    statusText:SetText("|cff00ff00ON|r")  -- Will be updated in OpenOptionsPanel
    
    local toggleButton = CreateFrame("Button", "ChronicleOptionsToggleLogging", panel, "UIPanelButtonTemplate")
    toggleButton:SetWidth(60)
    toggleButton:SetHeight(22)
    toggleButton:SetPoint("LEFT", statusText, "RIGHT", 10, 0)
    toggleButton:SetText("Toggle")
    toggleButton:SetScript("OnClick", function()
        local logging = LoggingCombat() == 1
        if logging then
            LoggingCombat(0)
            Chronicle:Print("Combat logging disabled")
        else
            LoggingCombat(1)
            Chronicle:Print("Combat logging enabled")
        end
        Chronicle:RefreshOptionsPanel()
    end)
    
    panel.statusText = statusText
    panel.toggleButton = toggleButton
    
    -- Combat Log Range Indicator
    local rangeLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    rangeLabel:SetPoint("TOPLEFT", 20, -72)
    rangeLabel:SetText("Current Range:")
    
    local rangeText = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    rangeText:SetPoint("LEFT", rangeLabel, "RIGHT", 5, 0)
    rangeText:SetText("|cffffff00-- yards|r")  -- Will be updated in RefreshOptionsPanel
    
    -- Instance Indicator
    local instanceLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    instanceLabel:SetPoint("LEFT", rangeText, "RIGHT", 15, 0)
    instanceLabel:SetText("In Instance:")
    
    local instanceText = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    instanceText:SetPoint("LEFT", instanceLabel, "RIGHT", 5, 0)
    instanceText:SetText("|cffff0000No|r")  -- Will be updated in RefreshOptionsPanel
    
    panel.rangeText = rangeText
    panel.instanceText = instanceText
    
    local yOffset = -100
    
    -- =============================================================================
    -- SuperWoWLogger Warning (shown if detected)
    -- =============================================================================
    local superWoWWarning = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    superWoWWarning:SetPoint("TOPLEFT", 20, yOffset)
    superWoWWarning:SetText("|cffff6600SuperWoWLogger detected!|r")
    superWoWWarning:Hide()
    
    local superWoWWarningDesc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    superWoWWarningDesc:SetPoint("TOPLEFT", superWoWWarning, "BOTTOMLEFT", 0, -2)
    superWoWWarningDesc:SetText("Some options are disabled. Disable SuperWoWLogger\nto use Chronicle's combat log management.")
    superWoWWarningDesc:SetTextColor(0.6, 0.6, 0.6)
    superWoWWarningDesc:Hide()
    
    panel.superWoWWarning = superWoWWarning
    panel.superWoWWarningDesc = superWoWWarningDesc
    
    -- Reserve space for warning (will be empty if not shown)
    yOffset = yOffset - 40
    
    -- =============================================================================
    -- Checkbox: Turtlogs Compatibility
    -- =============================================================================
    local turtlogsCheck = CreateFrame("CheckButton", "ChronicleOptionsTurtlogs", panel, "UICheckButtonTemplate")
    turtlogsCheck:SetPoint("TOPLEFT", 20, yOffset)
    getglobal(turtlogsCheck:GetName() .. "Text"):SetText("Turtlogs Compatibility")
    turtlogsCheck:SetChecked(self:GetSetting("turtlogsCompatibility"))
    turtlogsCheck:SetScript("OnClick", function()
        Chronicle:SetSetting("turtlogsCompatibility", this:GetChecked() == 1)
    end)
    
    local turtlogsDesc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    turtlogsDesc:SetPoint("TOPLEFT", turtlogsCheck, "BOTTOMLEFT", 26, 2)
    turtlogsDesc:SetText("Keep enabled for Turtlogs upload support.")
    turtlogsDesc:SetTextColor(0.5, 0.5, 0.5)
    
    yOffset = yOffset - 45
    
    -- =============================================================================
    -- Checkbox: Automatic Combat Log Toggle
    -- =============================================================================
    local autoLogCheck = CreateFrame("CheckButton", "ChronicleOptionsAutoLog", panel, "UICheckButtonTemplate")
    autoLogCheck:SetPoint("TOPLEFT", 20, yOffset)
    getglobal(autoLogCheck:GetName() .. "Text"):SetText("Automatic Combat Log Toggle")
    autoLogCheck:SetChecked(self:GetSetting("autoCombatLogToggle"))
    autoLogCheck:SetScript("OnClick", function()
        Chronicle:SetSetting("autoCombatLogToggle", this:GetChecked() == 1)
    end)
    
    local autoLogDesc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    autoLogDesc:SetPoint("TOPLEFT", autoLogCheck, "BOTTOMLEFT", 26, 2)
    autoLogDesc:SetText("Auto-enable logging when entering instances.")
    autoLogDesc:SetTextColor(0.5, 0.5, 0.5)
    
    yOffset = yOffset - 45
    
    -- =============================================================================
    -- Checkbox: Disable Combat Log Reminder
    -- =============================================================================
    local disableReminderCheck = CreateFrame("CheckButton", "ChronicleOptionsDisableReminder", panel, "UICheckButtonTemplate")
    disableReminderCheck:SetPoint("TOPLEFT", 20, yOffset)
    getglobal(disableReminderCheck:GetName() .. "Text"):SetText("Disable Combat Log Reminder")
    disableReminderCheck:SetChecked(self:GetSetting("disableCombatlogReminder"))
    disableReminderCheck:SetScript("OnClick", function()
        Chronicle:SetSetting("disableCombatlogReminder", this:GetChecked() == 1)
    end)
    
    local disableReminderDesc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    disableReminderDesc:SetPoint("TOPLEFT", disableReminderCheck, "BOTTOMLEFT", 26, 2)
    disableReminderDesc:SetText("Suppress the instance entry popup.")
    disableReminderDesc:SetTextColor(0.5, 0.5, 0.5)
    
    yOffset = yOffset - 45
    
    -- =============================================================================
    -- Checkbox: Debug Mode
    -- =============================================================================
    local debugCheck = CreateFrame("CheckButton", "ChronicleOptionsDebug", panel, "UICheckButtonTemplate")
    debugCheck:SetPoint("TOPLEFT", 20, yOffset)
    getglobal(debugCheck:GetName() .. "Text"):SetText("Debug Mode")
    debugCheck:SetChecked(self:GetSetting("debugMode"))
    debugCheck:SetScript("OnClick", function()
        Chronicle:SetSetting("debugMode", this:GetChecked() == 1)
    end)
    
    local debugDesc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    debugDesc:SetPoint("TOPLEFT", debugCheck, "BOTTOMLEFT", 26, 2)
    debugDesc:SetText("Show debug statistics and output.")
    debugDesc:SetTextColor(0.5, 0.5, 0.5)
    
    yOffset = yOffset - 45
    
    -- =============================================================================
    -- Dropdown: Debug Chat Window
    -- =============================================================================
    local debugChatLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    debugChatLabel:SetPoint("TOPLEFT", 20, yOffset)
    debugChatLabel:SetText("Debug Output Window:")
    
    local debugChatDropdown = CreateFrame("Frame", "ChronicleOptionsDebugChat", panel, "UIDropDownMenuTemplate")
    debugChatDropdown:SetPoint("TOPLEFT", debugChatLabel, "BOTTOMLEFT", -15, -2)
    
    local function GetChatWindowName(index)
        local tab = getglobal("ChatFrame" .. index .. "Tab")
        if tab then
            return tab:GetText() or ("Chat " .. index)
        end
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
                    Chronicle:SetSetting("debugChatFrame", this.value)
                    UIDropDownMenu_SetSelectedValue(debugChatDropdown, this.value)
                    UIDropDownMenu_SetText(GetChatWindowName(this.value), debugChatDropdown)
                end
                info.checked = (Chronicle:GetSetting("debugChatFrame") == i)
                UIDropDownMenu_AddButton(info)
            end
        end
    end
    
    UIDropDownMenu_Initialize(debugChatDropdown, DebugChatDropdown_Initialize)
    UIDropDownMenu_SetWidth(150, debugChatDropdown)
    UIDropDownMenu_SetSelectedValue(debugChatDropdown, self:GetSetting("debugChatFrame"))
    UIDropDownMenu_SetText(GetChatWindowName(self:GetSetting("debugChatFrame")), debugChatDropdown)
    
    yOffset = yOffset - 55
    
    -- =============================================================================
    -- Separator: Combat Log Range
    -- =============================================================================
    local separator = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    separator:SetPoint("TOPLEFT", 20, yOffset)
    separator:SetText("Combat Log Range")
    
    local separatorDesc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    separatorDesc:SetPoint("TOPLEFT", separator, "BOTTOMLEFT", 0, -4)
    separatorDesc:SetText("Higher range = more complete logs (max 200).")
    separatorDesc:SetTextColor(0.5, 0.5, 0.5)
    
    yOffset = yOffset - 50
    
    -- =============================================================================
    -- Slider: Default Range
    -- =============================================================================
    local defaultRangeSlider = CreateFrame("Slider", "ChronicleOptionsDefaultRange", panel, "OptionsSliderTemplate")
    defaultRangeSlider:SetPoint("TOPLEFT", 25, yOffset)
    defaultRangeSlider:SetWidth(200)
    defaultRangeSlider:SetMinMaxValues(10, 200)
    defaultRangeSlider:SetValueStep(10)
    defaultRangeSlider:SetValue(self:GetSetting("combatLogRangeDefault"))
    getglobal(defaultRangeSlider:GetName() .. "Low"):SetText("10")
    getglobal(defaultRangeSlider:GetName() .. "High"):SetText("200")
    getglobal(defaultRangeSlider:GetName() .. "Text"):SetText("Default: " .. self:GetSetting("combatLogRangeDefault") .. " yards")
    
    defaultRangeSlider:SetScript("OnValueChanged", function()
        local value = math.floor(this:GetValue())
        Chronicle:SetSetting("combatLogRangeDefault", value)
        getglobal(this:GetName() .. "Text"):SetText("Default: " .. value .. " yards")
        -- Apply the appropriate range for current context
        Chronicle:ApplyCombatLogRange(IsInInstance() == 1)
        Chronicle:RefreshOptionsPanel()
    end)
    
    yOffset = yOffset - 45
    
    -- =============================================================================
    -- Slider: Instance Range
    -- =============================================================================
    local instanceRangeSlider = CreateFrame("Slider", "ChronicleOptionsInstanceRange", panel, "OptionsSliderTemplate")
    instanceRangeSlider:SetPoint("TOPLEFT", 25, yOffset)
    instanceRangeSlider:SetWidth(200)
    instanceRangeSlider:SetMinMaxValues(10, 200)
    instanceRangeSlider:SetValueStep(10)
    instanceRangeSlider:SetValue(self:GetSetting("combatLogRangeInstance"))
    getglobal(instanceRangeSlider:GetName() .. "Low"):SetText("10")
    getglobal(instanceRangeSlider:GetName() .. "High"):SetText("200")
    getglobal(instanceRangeSlider:GetName() .. "Text"):SetText("In Instance: " .. self:GetSetting("combatLogRangeInstance") .. " yards")
    
    instanceRangeSlider:SetScript("OnValueChanged", function()
        local value = math.floor(this:GetValue())
        Chronicle:SetSetting("combatLogRangeInstance", value)
        getglobal(this:GetName() .. "Text"):SetText("In Instance: " .. value .. " yards")
        -- Apply the appropriate range for current context
        Chronicle:ApplyCombatLogRange(IsInInstance() == 1)
        Chronicle:RefreshOptionsPanel()
    end)
    
    -- Store references for refreshing
    panel.turtlogsCheck = turtlogsCheck
    panel.autoLogCheck = autoLogCheck
    panel.disableReminderCheck = disableReminderCheck
    panel.debugCheck = debugCheck
    panel.debugChatDropdown = debugChatDropdown
    panel.defaultRangeSlider = defaultRangeSlider
    panel.instanceRangeSlider = instanceRangeSlider
    
    self.optionsPanel = panel
    
    -- Close on Escape
    tinsert(UISpecialFrames, "ChronicleOptionsPanel")
end

function Chronicle:OpenOptionsPanel()
    if not self.optionsPanel then
        self:CreateOptionsPanel()
    end
    
    self:RefreshOptionsPanel()
    self.optionsPanel:Show()
end

--- Refresh all options panel values from current state and saved variables.
function Chronicle:RefreshOptionsPanel()
    if not self.optionsPanel then
        return
    end
    
    local panel = self.optionsPanel
    
    -- Refresh combat log status
    local logging = LoggingCombat() == 1
    if logging then
        panel.statusText:SetText("|cff00ff00ON|r")
    else
        panel.statusText:SetText("|cffff0000OFF|r")
    end
    
    -- Refresh combat log range
    local currentRange = self:GetCombatLogRange()
    panel.rangeText:SetText("|cffffff00" .. currentRange .. " yards|r")
    
    -- Refresh instance indicator
    local isInstance = IsInInstance() == 1
    if isInstance then
        panel.instanceText:SetText("|cff00ff00Yes|r")
    else
        panel.instanceText:SetText("|cffff0000No|r")
    end
    
    -- Refresh checkbox states from saved variables
    panel.turtlogsCheck:SetChecked(self:GetSetting("turtlogsCompatibility"))
    panel.autoLogCheck:SetChecked(self:GetSetting("autoCombatLogToggle"))
    panel.disableReminderCheck:SetChecked(self:GetSetting("disableCombatlogReminder"))
    panel.debugCheck:SetChecked(self:GetSetting("debugMode"))
    panel.defaultRangeSlider:SetValue(self:GetSetting("combatLogRangeDefault"))
    panel.instanceRangeSlider:SetValue(self:GetSetting("combatLogRangeInstance"))
    
    -- Refresh debug chat dropdown
    local chatFrameIndex = self:GetSetting("debugChatFrame")
    UIDropDownMenu_SetSelectedValue(panel.debugChatDropdown, chatFrameIndex)
    local tab = getglobal("ChatFrame" .. chatFrameIndex .. "Tab")
    local chatName = tab and tab:GetText() or ("Chat " .. chatFrameIndex)
    UIDropDownMenu_SetText(chatName, panel.debugChatDropdown)
    
    -- Handle SuperWoWLogger detection - disable managed options
    if self.superWoWLogger then
        panel.superWoWWarning:Show()
        panel.superWoWWarningDesc:Show()
        -- Disable the checkboxes
        panel.turtlogsCheck:Disable()
        panel.autoLogCheck:Disable()
        panel.disableReminderCheck:Disable()
        -- Gray out the text
        getglobal(panel.turtlogsCheck:GetName() .. "Text"):SetTextColor(0.5, 0.5, 0.5)
        getglobal(panel.autoLogCheck:GetName() .. "Text"):SetTextColor(0.5, 0.5, 0.5)
        getglobal(panel.disableReminderCheck:GetName() .. "Text"):SetTextColor(0.5, 0.5, 0.5)
    else
        panel.superWoWWarning:Hide()
        panel.superWoWWarningDesc:Hide()
        -- Enable the checkboxes
        panel.turtlogsCheck:Enable()
        panel.autoLogCheck:Enable()
        panel.disableReminderCheck:Enable()
        -- Restore text color
        getglobal(panel.turtlogsCheck:GetName() .. "Text"):SetTextColor(1, 1, 1)
        getglobal(panel.autoLogCheck:GetName() .. "Text"):SetTextColor(1, 1, 1)
        getglobal(panel.disableReminderCheck:GetName() .. "Text"):SetTextColor(1, 1, 1)
    end
end
