-- Optional trays for the ChronicleLog options panel. Load after ursol/sidekick.
-- WoW 1.12 scripts use the global `this`; keep transport/state in sidekick.lua.
local UI = {}
local MAX_REQUESTS = 20
local GROUP_HEADER = 38
local INSTANCE_HEIGHT = 36
local GROUP_GAP = 6
local CHANNELS = { "SAY", "YELL", "GUILD", "PARTY", "RAID" }
local CHANNEL_NAMES = { "Say", "Yell", "Guild", "Party", "Raid" }
local channelIndex = 1

-- Chat cannot contain server-supplied hyperlink/color markup or control bytes.
local function ChatText(value)
    local text = string.gsub(tostring(value or ""), "[%c]", " ")
    return string.gsub(text, "|", "")
end


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

function UI:Announce(name, url)
    local channel = CHANNELS[channelIndex]
    if channel == "GUILD" and not IsInGuild() then
        Chronicle:Print("Join a guild before announcing to Guild."); return
    elseif channel == "RAID" and GetNumRaidMembers() == 0 then
        Chronicle:Print("Join a raid before announcing to Raid."); return
    elseif channel == "PARTY" and GetNumPartyMembers() == 0 then
        Chronicle:Print("Join a party before announcing to Party."); return
    end
    local link = CopyURL(url)
    if not string.find(link, "^https://[^%s]+$") then return end
    local prefix = "[Chronicle] "
    local available = 255 - string.len(prefix) - string.len(": ") - string.len(link)
    if available < 1 then
        Chronicle:Print("This link is too long to announce in chat. Use Copy instead."); return
    end
    local instance = string.sub(ChatText(name), 1, available)
    SendChatMessage(prefix .. instance .. ": " .. link, channel)
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
    row.share = Button(row, "Announce", 80, function()
        if this.url then UI:Announce(this.instanceName, this.url) end
    end)
    row.share:SetHeight(18)
    row.share:SetPoint("TOPRIGHT", -54, -22)
    row.share:Hide()
    self.rows[index] = row
    return row
end

function UI:GetGroup(index)
    local group = self.groups[index]
    if group then return group end
    group = CreateFrame("Frame", nil, self.content)
    group:SetWidth(248)
    group:SetBackdrop({
        bgFile = "Interface" .. string.char(92) .. "Tooltips" .. string.char(92) .. "UI-Tooltip-Background",
        edgeFile = "Interface" .. string.char(92) .. "Tooltips" .. string.char(92) .. "UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    group:SetBackdropColor(0, 0, 0, 0.55)
    group:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
    self.groups[index] = group
    return group
end

local function LogTitle(request)
    local created = tonumber(request.created)
    if created and created > 0 then return "Log - " .. date("%b %d, %H:%M", created) end
    return "Uploaded log"
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
    local groupCount = math.min(table.getn(requests), MAX_REQUESTS)
    for i = 1, groupCount do
        local request = requests[i]
        local instances = request.instances or {}
        local group = self:GetGroup(i)
        group:ClearAllPoints()
        group:SetPoint("TOPLEFT", 0, -height)
        group:Show()
        local detail = table.getn(instances) .. (table.getn(instances) == 1 and " instance" or " instances")
        if request.state ~= "complete" then
            local states = { waiting = "Waiting for Sidekick", queued = "Queued", uploading = "Uploading", processing = "Processing", failed = "Failed" }
            detail = (states[request.state] or "Pending") .. " - " .. detail
            if request.message and request.message ~= "" then detail = detail .. ": " .. Plain(request.message, 180) end
        elseif table.getn(instances) == 0 then
            detail = "No instance links returned"
        end
        local headerHeight = request.state ~= "complete" and request.message and request.message ~= "" and 50 or GROUP_HEADER
        count = count + 1
        local row = self:GetRow(count)
        row:SetParent(group)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 8, -7)
        row:SetWidth(232)
        row:SetHeight(headerHeight - 7)
        row.title:SetWidth(request.state == "failed" and 178 or 232)
        row.title:SetText("|cffffd100" .. LogTitle(request) .. "|r")
        row.detail:SetWidth(232)
        row.detail:SetHeight(headerHeight - 25)
        row.detail:SetText(detail)
        row.share:Hide()
        row.action:ClearAllPoints()
        row.action:SetPoint("TOPRIGHT", 0, 0)
        row.action.requestID = request.id
        row.action.url = nil
        row.action:SetText("Retry")
        if request.state == "failed" and request.id then row.action:Show() else row.action:Hide() end
        row:Show()
        local groupHeight = headerHeight
        for j = 1, table.getn(instances) do
            local instance = instances[j]
            count = count + 1
            row = self:GetRow(count)
            row:SetParent(group)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 16, -groupHeight)
            row:SetWidth(224)
            row:SetHeight(INSTANCE_HEIGHT)
            row.title:SetWidth(224)
            row.title:SetText(j .. ". " .. Plain(instance.name or instance.id or "Instance", 90))
            row.detail:SetText("")
            row.action:ClearAllPoints()
            row.action:SetPoint("TOPRIGHT", 0, -17)
            row.action.requestID = nil
            row.action.url = CopyURL(instance.url)
            row.action:SetText("Copy")
            if row.action.url ~= "" then row.action:Show() else row.action:Hide() end
            row.share:ClearAllPoints()
            row.share:SetPoint("TOPRIGHT", -54, -17)
            row.share.url = row.action.url
            row.share.instanceName = instance.name or instance.id or "Instance"
            if row.share.url ~= "" then row.share:Show() else row.share:Hide() end
            row:Show()
            groupHeight = groupHeight + INSTANCE_HEIGHT
        end
        group:SetHeight(groupHeight + 7)
        height = height + groupHeight + 7 + GROUP_GAP
    end
    for i = count + 1, table.getn(self.rows) do self.rows[i]:Hide() end
    for i = groupCount + 1, table.getn(self.groups) do self.groups[i]:Hide() end
    self.empty:SetText(count == 0 and "No uploads yet." or "Recent logs")
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

-- Shared entry point for the button and slash command; never uploads directly.
function ChronicleSidekick:ConfirmUpload()
    self:Poll()
    local ready, reason = self:Ready()
    if not ready then
        Chronicle:Print(reason)
        return false
    end
    StaticPopup_Show("CHRONICLE_SIDEKICK_UPLOAD_CONFIRM")
    return true
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
        ChronicleSidekick:ConfirmUpload()
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
    title:SetWidth(100)
    self.channel = Button(side, "Channel: Say", 125, function()
        channelIndex = math.mod(channelIndex, table.getn(CHANNELS)) + 1
        this:SetText("Channel: " .. CHANNEL_NAMES[channelIndex])
    end)
    self.channel:SetPoint("TOPLEFT", 130, -15)
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
    self.groups = {}
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
