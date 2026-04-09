-- =============================================================================
-- Minimap Button for ChronicleCompanion
-- =============================================================================

ChronicleMinimapButton = {}

local ICON_ON = "Interface\\AddOns\\ChronicleCompanion\\textures\\On"
local ICON_OFF = "Interface\\AddOns\\ChronicleCompanion\\textures\\Off"

-- Default position (angle around minimap in degrees)
local DEFAULT_POSITION = 225

-- =============================================================================
-- Minimap Button Creation
-- =============================================================================

function ChronicleMinimapButton:Create()
    -- Create the button frame
    local button = CreateFrame("Button", "ChronicleMinimapBtn", Minimap)
    button:SetWidth(32)
    button:SetHeight(32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    
    -- Icon texture (offset to sit inside the border circle)
    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetWidth(20)
    icon:SetHeight(20)
    icon:SetPoint("CENTER", 0, 0)
    button.icon = icon
    
    -- Border overlay
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetWidth(54)
    border:SetHeight(54)
    border:SetPoint("TOPLEFT", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button.border = border
    
    -- Enable dragging
    button:SetMovable(true)
    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    
    -- Click handler
    button:SetScript("OnClick", function()
        if arg1 == "LeftButton" then
            ChronicleMinimapButton:OnLeftClick()
        elseif arg1 == "RightButton" then
            ChronicleMinimapButton:OnRightClick()
        end
    end)
    
    -- Drag handlers
    button:SetScript("OnDragStart", function()
        button.dragging = true
    end)
    
    button:SetScript("OnDragStop", function()
        button.dragging = false
        ChronicleMinimapButton:SavePosition()
    end)
    
    -- Update position while dragging
    button:SetScript("OnUpdate", function()
        if button.dragging then
            ChronicleMinimapButton:UpdatePositionFromCursor()
        end
    end)
    
    -- Tooltip
    button:SetScript("OnEnter", function()
        GameTooltip:SetOwner(button, "ANCHOR_LEFT")
        ChronicleMinimapButton:UpdateTooltip()
        GameTooltip:Show()
    end)
    
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    self.button = button
    
    -- Set initial position and icon
    self:LoadPosition()
    self:UpdateIcon()
end

-- =============================================================================
-- Position Management
-- =============================================================================

function ChronicleMinimapButton:UpdatePositionFromCursor()
    local xpos, ypos = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    local cx, cy = Minimap:GetCenter()
    cx, cy = cx * scale, cy * scale
    
    local angle = math.atan2(ypos - cy, xpos - cx)
    self:SetPosition(math.deg(angle))
end

function ChronicleMinimapButton:SetPosition(angle)
    local radius = 80
    local rads = math.rad(angle)
    local x = math.cos(rads) * radius
    local y = math.sin(rads) * radius
    
    self.button:ClearAllPoints()
    self.button:SetPoint("CENTER", Minimap, "CENTER", x, y)
    self.angle = angle
end

function ChronicleMinimapButton:SavePosition()
    if not ChronicleCompanionDB then
        ChronicleCompanionDB = {}
    end
    ChronicleCompanionDB.minimapPosition = self.angle
end

function ChronicleMinimapButton:LoadPosition()
    local angle = DEFAULT_POSITION
    if ChronicleCompanionDB and ChronicleCompanionDB.minimapPosition then
        angle = ChronicleCompanionDB.minimapPosition
    end
    self:SetPosition(angle)
end

-- =============================================================================
-- Icon State Management
-- =============================================================================

function ChronicleMinimapButton:UpdateIcon()
    if not self.button then return end
    
    if ChronicleLog and ChronicleLog.enabled then
        self.button.icon:SetTexture(ICON_ON)
    else
        self.button.icon:SetTexture(ICON_OFF)
    end
end

function ChronicleMinimapButton:UpdateTooltip()
    local status = (ChronicleLog and ChronicleLog.enabled) and "|cff00ff00Recording|r" or "|cffff0000Not Recording|r"
    GameTooltip:SetText("Chronicle Companion")
    GameTooltip:AddLine(status)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("|cffffffffLeft-click:|r Open config", 0.7, 0.7, 0.7)
end

-- =============================================================================
-- Click Handlers
-- =============================================================================

function ChronicleMinimapButton:OnLeftClick()
    if ChronicleLog then
        ChronicleLog:OpenOptionsPanel()
    end
end

function ChronicleMinimapButton:OnRightClick()
    -- Reserved for future use
end

-- =============================================================================
-- Initialization
-- =============================================================================

function ChronicleMinimapButton:Init()
    self:Create()
end
