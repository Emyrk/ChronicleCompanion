-- Optional trays for the ChronicleLog options panel. Load after ursol/sidekick.
-- WoW 1.12 scripts use the global `this`; keep transport/state in sidekick.lua.
local UI = {}
local MAX_REQUESTS = 20
local ROW_HEIGHT = 58

-- Never interpret server-supplied text as WoW color, texture or hyperlink markup.
local function Plain(value, limit)
    local text = string.sub(tostring(value or ""), 1, limit or 240)
    text = string.gsub(text, "[%c]", " ")
    return string.gsub(text, "|", "||")
end

local function CopyURL(value)
    -- A literal pipe is URL-encoded rather than doubled, so copying preserves a URL.
    local text = string.gsub(tostring(value or ""), "[%c]", "")
    return string.gsub(text, "|", "%%7C")
end

local function Button(parent, label, width, click)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetWidth(width)
    button:SetHeight(22)
    button:SetText(label)
    button:SetScript("OnClick", click)
    return button
end

local function Label(parent, width, template)
    local text = parent:CreateFontString(nil, "ARTWORK", template or "GameFontHighlightSmall")
    text:SetWidth(width)
    text:SetJustifyH("LEFT")
    return text
end

function UI:Selected()
    local selected = ChronicleCompanionDB and ChronicleCompanionDB.sidekickTray
    if selected == "sidekick" or selected == "events" then return selected end
end

function UI:Toggle(selected)
    if not ChronicleCompanionDB then ChronicleCompanionDB = {} end
    if self:Selected() == selected then selected = nil end
    ChronicleCompanionDB.sidekickTray = selected
    self:ApplyTray()
    if selected == "sidekick" then ChronicleSidekick:Poll() end
    self:Refresh()
end

function UI:ApplyTray()
    if not self.panel then return end
    local selected = self:Selected()
    if ChronicleUrsol and ChronicleUrsol.options then
        if selected == "events" then ChronicleUrsol.options:Show()
        else ChronicleUrsol.options:Hide() end
    end
    if selected == "sidekick" then self.side:Show() else self.side:Hide() end
    self.minimize:ClearAllPoints()
    self.minimize:SetPoint("TOPLEFT", self.panel, "TOPRIGHT", selected == "sidekick" and 263 or 193, -12)
    if selected then self.minimize:Show() else self.minimize:Hide() end
    self.eventsButton:SetText(selected == "events" and "Extra Events -" or "Extra Events +")
    self.sidekickButton:SetText(selected == "sidekick" and "Sidekick -" or "Sidekick +")
end

function UI:GetRow(index)
    local row = self.rows[index]
    if row then return row end
    row = CreateFrame("Frame", nil, self.content)
    row:SetWidth(248)
    row.title = Label(row, 244)
    row.title:SetPoint("TOPLEFT", 0, -2)
    row.detail = Label(row, 244, "GameFontDisableSmall")
    row.detail:SetPoint("TOPLEFT", 0, -18)
    row.detail:SetHeight(30)
    row.action = Button(row, "Retry", 48, function()
        if this.requestID then
            ChronicleSidekick:Retry(this.requestID)
            UI:Refresh()
        elseif this.url then
            UI.copy:SetText(this.url)
            UI.copy:SetFocus()
            UI.copy:HighlightText()
        end
    end)
    row.action:SetHeight(18)
    row.action:SetPoint("TOPRIGHT", 0, 0)
    self.rows[index] = row
    return row
end

function UI:History()
    local status = ChronicleSidekick.status or {}
    local requests = {}
    local seen = {}
    local source = status.requests or {}
    -- Pending local state wins over an older server failure for the same id.
    for id, request in pairs(ChronicleSidekick.pending or {}) do
        if type(request) == "table" then
            local key = request.id or id
            seen[key] = true
            table.insert(requests, { id = key, filename = request.filename,
                created = request.created, updated = request.updated,
                state = request.state or "waiting", message = request.message or "Waiting for Sidekick acknowledgement" })
        end
    end
    for i = 1, table.getn(source) do
        local request = source[i]
        if type(request) == "table" and request.id and not seen[request.id] then
            seen[request.id] = true
            table.insert(requests, request)
        end
    end
    table.sort(requests, function(a, b)
        local first = tonumber(a.updated or a.created) or 0
        local second = tonumber(b.updated or b.created) or 0
        if first == second then return tostring(a.id) > tostring(b.id) end
        return first > second
    end)

    local count = 0
    local height = 0
    for i = 1, math.min(table.getn(requests), MAX_REQUESTS) do
        local request = requests[i]
        count = count + 1
        local row = self:GetRow(count)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -height)
        row:SetHeight(ROW_HEIGHT)
        row.title:SetWidth(request.state == "failed" and 190 or 244)
        row.title:SetText(Plain(request.filename or request.id, 90))
        row.detail:SetText(Plain(request.state or "pending", 32) .. ": " .. Plain(request.message, 180))
        row.action.requestID = request.id
        row.action.url = nil
        row.action:SetText("Retry")
        if request.state == "failed" and request.id then row.action:Show()
        else row.action:Hide() end
        row:Show()
        height = height + ROW_HEIGHT
        local instances = request.instances or {}
        for j = 1, table.getn(instances) do
            local instance = instances[j]
            count = count + 1
            row = self:GetRow(count)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -height)
            row:SetHeight(24)
            row.title:SetWidth(190)
            row.title:SetText(Plain(instance.name or instance.id or "Instance", 90))
            row.detail:SetText("")
            row.action.requestID = nil
            row.action.url = CopyURL(instance.url)
            row.action:SetText("Copy")
            if row.action.url ~= "" then row.action:Show() else row.action:Hide() end
            row:Show()
            height = height + 24
        end
    end
    for i = count + 1, table.getn(self.rows) do self.rows[i]:Hide() end
    self.empty:SetText(count == 0 and "No upload requests yet." or "Latest 20 requests and their instance links.")
    self.content:SetHeight(math.max(height, 1))
    self.scroll:UpdateScrollChildRect()
    local maximum = math.max(0, height - self.scroll:GetHeight())
    if self.scroll:GetVerticalScroll() > maximum then self.scroll:SetVerticalScroll(maximum) end
end

function UI:Refresh()
    if not self.panel then return end
    self:ApplyTray()
    local ready, reason = ChronicleSidekick:Ready()
    if ready then self.upload:Enable() else self.upload:Disable() end
    local status = ChronicleSidekick.status or {}
    self.readiness:SetText((ready and "Ready" or "Not ready") .. ": " .. Plain(reason, 180)
        .. "\nVersion: " .. Plain(status.version or "unknown", 60)
        .. "  Heartbeat: " .. Plain(status.heartbeat or "none", 60)
        .. "\n" .. Plain(status.readiness, 80) .. " " .. Plain(status.message, 180))
    self:History()
end

StaticPopupDialogs["CHRONICLE_SIDEKICK_UPLOAD_CONFIRM"] = {
    text = "Archive the current combat log and queue it for upload by Sidekick?\n\nThis clears the active log after archiving it locally. Sidekick will send the archive to the configured server.",
    button1 = "Archive & Upload",
    button2 = "Cancel",
    OnAccept = function()
        -- Recheck at acceptance: readiness can change while the dialog is open.
        ChronicleSidekick:Poll()
        local ready = ChronicleSidekick:Ready()
        if ready then ChronicleSidekick:ArchiveAndUpload() end
        UI:Refresh()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

function UI:Create(panel)
    if self.panel == panel then return end
    self.panel = panel
    panel:SetHeight(panel:GetHeight() + 42)
    if ChronicleUrsol and ChronicleUrsol.options then
        ChronicleUrsol.options:SetHeight(panel:GetHeight())
    end
    self.upload = Button(panel, "Archive & Upload...", 172, function()
        ChronicleSidekick:Poll()
        local ready = ChronicleSidekick:Ready()
        if ready then StaticPopup_Show("CHRONICLE_SIDEKICK_UPLOAD_CONFIRM") end
        UI:Refresh()
    end)
    self.upload:SetPoint("BOTTOMLEFT", 20, 18)
    self.eventsButton = Button(panel, "Extra Events +", 135, function() UI:Toggle("events") end)
    self.eventsButton:SetPoint("LEFT", self.upload, "RIGHT", 8, 0)
    self.sidekickButton = Button(panel, "Sidekick +", 135, function() UI:Toggle("sidekick") end)
    self.sidekickButton:SetPoint("LEFT", self.eventsButton, "RIGHT", 8, 0)

    local side = CreateFrame("Frame", "ChronicleSidekickOptions", panel)
    self.side = side
    side:SetWidth(300)
    side:SetHeight(panel:GetHeight())
    side:SetPoint("TOPLEFT", panel, "TOPRIGHT", -4, 0)
    side:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    local title = Label(side, 200, "GameFontNormal")
    title:SetPoint("TOPLEFT", 20, -18)
    title:SetText("Sidekick")
    self.minimize = Button(panel, "-", 24, function() UI:Toggle(UI:Selected()) end)
    self.minimize:SetPoint("TOPLEFT", panel, "TOPRIGHT", 193, -12)
    self.readiness = Label(side, 260)
    self.readiness:SetPoint("TOPLEFT", 20, -44)
    self.readiness:SetHeight(76)
    self.empty = Label(side, 260, "GameFontDisableSmall")
    self.empty:SetPoint("TOPLEFT", 20, -122)

    self.scroll = CreateFrame("ScrollFrame", "ChronicleSidekickHistory", side, "UIPanelScrollFrameTemplate")
    self.scroll:SetPoint("TOPLEFT", 20, -146)
    self.scroll:SetPoint("BOTTOMRIGHT", -36, 74)
    self.content = CreateFrame("Frame", nil, self.scroll)
    self.content:SetWidth(248)
    self.content:SetHeight(1)
    self.scroll:SetScrollChild(self.content)
    self.rows = {}
    local copyLabel = Label(side, 260, "GameFontDisableSmall")
    copyLabel:SetPoint("BOTTOMLEFT", 20, 51)
    copyLabel:SetText("Copy link: select a link, then Ctrl+C")
    self.copy = CreateFrame("EditBox", "ChronicleSidekickCopyLink", side, "InputBoxTemplate")
    self.copy:SetPoint("BOTTOMLEFT", 24, 28)
    self.copy:SetWidth(252)
    self.copy:SetHeight(20)
    self.copy:SetAutoFocus(false)
    self.copy:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    self.copy:SetScript("OnEnterPressed", function() this:ClearFocus() end)
    self.copy:SetScript("OnEditFocusGained", function() this:HighlightText() end)
    self:Refresh()
end

local originalCreate = ChronicleLog.CreateOptionsPanel
function ChronicleLog:CreateOptionsPanel()
    originalCreate(self)
    if self.optionsPanel then UI:Create(self.optionsPanel) end
end

local originalOpen = ChronicleLog.OpenOptionsPanel
function ChronicleLog:OpenOptionsPanel()
    originalOpen(self)
    if UI:Selected() == "sidekick" then ChronicleSidekick:Poll() end
end

local originalRefresh = ChronicleLog.RefreshOptionsPanel
function ChronicleLog:RefreshOptionsPanel()
    originalRefresh(self)
    UI:Refresh()
end

function ChronicleSidekick:OpenTray(selected)
    if selected ~= "sidekick" and selected ~= "events" then return end
    if not ChronicleCompanionDB then ChronicleCompanionDB = {} end
    ChronicleCompanionDB.sidekickTray = selected
    ChronicleLog:OpenOptionsPanel()
    UI:Refresh()
end

function ChronicleSidekick:IsTrayVisible()
    return UI.panel and UI.panel:IsShown() and UI:Selected() == "sidekick" or false
end

local originalSidekickRefresh = ChronicleSidekick.RefreshUI
function ChronicleSidekick:RefreshUI()
    if originalSidekickRefresh then originalSidekickRefresh(self) end
    UI:Refresh()
end

-- Also support loading after another module has already constructed the panel.
if ChronicleLog.optionsPanel then UI:Create(ChronicleLog.optionsPanel) end
