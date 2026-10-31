-- Lua 5.0 smoke test; run from the repository root.
local frames = {}
local methods = {}
local function frame(kind, name, parent)
    local value = { kind = kind, name = name, parent = parent, shown = true,
        scripts = {}, width = 520, height = 400, enabled = true }
    setmetatable(value, { __index = methods })
    table.insert(frames, value)
    if name then _G[name] = value end
    return value
end
function methods:SetWidth(n) self.width = n end
function methods:SetHeight(n) self.height = n end
function methods:GetHeight() return self.height end
function methods:SetPoint() end
function methods:ClearAllPoints() end
function methods:SetBackdrop(value) self.backdrop = value end
function methods:SetBackdropColor() end
function methods:SetBackdropBorderColor() end
function methods:SetParent(parent) self.parent = parent end
function date(format, value) return "Oct 31, 21:04" end
function methods:SetJustifyH() end
function methods:SetAutoFocus() end
function methods:SetScript(event, script) self.scripts[event] = script end
function methods:CreateFontString() return frame("FontString", nil, self) end
function methods:SetText(text) self.text = text end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false end
function methods:IsShown() return self.shown and (not self.parent or self.parent:IsShown()) end
function methods:Enable() self.enabled = true end
function methods:Disable() self.enabled = false end
function methods:SetScrollChild(child) self.child = child end
function methods:UpdateScrollChildRect() end
function methods:GetVerticalScroll() return self.scroll or 0 end
function methods:SetVerticalScroll(n) self.scroll = n end
function methods:SetFocus() self.focus = true end
function methods:ClearFocus() self.focus = false end
function methods:HighlightText() self.highlight = true end
CreateFrame = frame
StaticPopupDialogs = {}
local popup
function StaticPopup_Show(name) popup = name end
local polls, uploads, retries = 0, 0, 0
local announcements, errors = {}, {}
local guild, party, raid = false, 0, 0
Chronicle = { Print = function(self, message) table.insert(errors, message) end }
IsInGuild = function() return guild end
GetNumPartyMembers = function() return party end
GetNumRaidMembers = function() return raid end
SendChatMessage = function(message, channel)
    assert(string.len(message) <= 255)
    table.insert(announcements, { message = message, channel = channel })
end
ChronicleCompanionDB = {}
ChronicleUrsol = {}
ChronicleLog = {}
function ChronicleLog:CreateOptionsPanel()
    self.optionsPanel = frame("Frame", "ChronicleLogOptionsPanel")
    ChronicleUrsol.options = frame("Frame", "ChronicleUrsolOptions", self.optionsPanel)
end
function ChronicleLog:RefreshOptionsPanel() end
function ChronicleLog:OpenOptionsPanel()
    if not self.optionsPanel then self:CreateOptionsPanel() end
    self:RefreshOptionsPanel()
    self.optionsPanel:Show()
end
ChronicleSidekick = { pending = {}, status = { requests = {} }, ready = true }
function ChronicleSidekick:Ready() return self.ready, "|cffff0000offline|r" end
function ChronicleSidekick:Poll() polls = polls + 1; self:RefreshUI() end
function ChronicleSidekick:ArchiveAndUpload() uploads = uploads + 1 end
function ChronicleSidekick:Retry(id) retries = retries + 1; self.lastRetry = id end
assert(loadfile("advancedlogging/sidekick_ui.lua"))()
local function find(text)
    for _, f in ipairs(frames) do if f.text == text and f:IsShown() then return f end end
    error("Missing UI text: " .. text)
end
local function click(button)
    assert(button.enabled)
    this = button
    button.scripts.OnClick()
    this = nil
end
ChronicleLog:OpenOptionsPanel()
assert(ChronicleLog.optionsPanel.height == 442)
assert(not ChronicleUrsol.options.shown and not ChronicleSidekickOptions.shown)
click(find("Extra Events +"))
assert(ChronicleUrsol.options.shown and ChronicleCompanionDB.sidekickTray == "events")
click(find("Extra Events -"))
assert(not ChronicleUrsol.options.shown and ChronicleCompanionDB.sidekickTray == nil)
click(find("Extra Events +"))
click(find("Sidekick +"))
assert(not ChronicleUrsol.options.shown and ChronicleSidekick:IsTrayVisible())
assert(ChronicleCompanionDB.sidekickTray == "sidekick" and polls == 1)
click(find("-"))
assert(not ChronicleSidekick:IsTrayVisible() and ChronicleCompanionDB.sidekickTray == nil)
ChronicleSidekick:OpenTray("sidekick")
ChronicleLog.optionsPanel:Hide()
assert(not ChronicleSidekick:IsTrayVisible())
ChronicleLog:OpenOptionsPanel()
assert(ChronicleSidekick:IsTrayVisible() and ChronicleCompanionDB.sidekickTray == "sidekick")
click(find("Archive & Upload..."))
assert(uploads == 0 and popup == "CHRONICLE_SIDEKICK_UPLOAD_CONFIRM")
StaticPopupDialogs[popup].OnAccept()
assert(uploads == 1)
ChronicleSidekick.ready = false
StaticPopupDialogs[popup].OnAccept()
assert(uploads == 1 and not find("Archive & Upload...").enabled)
ChronicleSidekick.ready = true
ChronicleSidekick.pending.localFail = { id = "localFail", filename = "local.txt", state = "failed", message = "write failed", created = 3 }
ChronicleSidekick.status.requests = {
    { id = "serverFail", filename = "server.txt", state = "failed", created = 2, message = "|Hbad|hBAD|h", instances = {} },
    { id = "done", filename = "done.txt", state = "complete", created = 1,
      instances = { { id = "raid", name = "|cffFF0000Raid|r", url = "https://example.com/|cffABCDEF" } } },
    { id = "localFail", filename = "duplicate.txt", state = "failed", created = 0 },
}
ChronicleSidekick:RefreshUI()
local retryCount = 0
local firstFrameCount = table.getn(frames)
for _, f in ipairs(frames) do
    if f.kind == "Button" and f.text == "Retry" and f.shown then
        retryCount = retryCount + 1
        click(f)
    end
end
assert(retryCount == 2 and retries == 2)
assert(find("Failed - 0 instances: ||Hbad||hBAD||h"))
assert(find("1. ||cffFF0000Raid||r"))
click(find("Copy"))
assert(ChronicleSidekickCopyLink.text == "https://example.com/%7CcffABCDEF")
assert(ChronicleSidekickCopyLink.focus and ChronicleSidekickCopyLink.highlight)
click(find("Announce"))
assert(announcements[1].channel == "SAY")
assert(announcements[1].message == "[Chronicle] cffFF0000Raidr: https://example.com/%7CcffABCDEF")
click(find("Channel: Say")); click(find("Announce"))
assert(announcements[2].channel == "YELL")
click(find("Channel: Yell")); click(find("Announce"))
assert(table.getn(announcements) == 2 and table.getn(errors) == 1, "guild requires membership")
guild = true; click(find("Announce")); assert(announcements[3].channel == "GUILD")
click(find("Channel: Guild")); click(find("Announce"))
assert(table.getn(announcements) == 3, "party requires membership")
party = 1; click(find("Announce")); assert(announcements[4].channel == "PARTY")
click(find("Channel: Party")); click(find("Announce"))
assert(table.getn(announcements) == 4, "raid requires membership")
raid = 1; click(find("Announce")); assert(announcements[5].channel == "RAID")
click(find("Channel: Raid")); assert(find("Channel: Say"))
local share = find("Announce")
local originalURL = share.url
share.url = "https://example.com/" .. string.rep("x", 255)
click(share); assert(table.getn(announcements) == 5, "oversized URLs must not be truncated")
share.url = originalURL
for i = 1, 5 do ChronicleSidekick:RefreshUI() end
assert(table.getn(frames) == firstFrameCount, "refresh must reuse rows/callbacks")
ChronicleSidekick.status.requests = {}
ChronicleSidekick.pending = {}
for i = 1, 100 do
    table.insert(ChronicleSidekick.status.requests, { id = tostring(i), filename = "f.txt", created = i, state = "complete", instances = {} })
end
ChronicleSidekick:RefreshUI()
local maximumFrames = table.getn(frames)
ChronicleSidekick:RefreshUI()
assert(table.getn(frames) == maximumFrames)
assert(ChronicleSidekickHistory.child.height == 20 * (38 + 7 + 6), "history must be bounded")
-- Instances from a single log share one bordered group; other logs do not.
ChronicleSidekick.status.requests = {
    { id = "grouped", filename = "ChronicleUpload_grouped.txt", created = 10, state = "complete",
      instances = {
        { id = "a", name = "Ragefire Chasm", url = "https://example.com/a" },
        { id = "b", name = "Ragefire Chasm", url = "https://example.com/b" },
      } },
    { id = "other", filename = "ChronicleUpload_other.txt", created = 9, state = "processing", message = "Analyzing",
      instances = { { id = "c", name = "Molten Core", url = "https://example.com/c" } } },
}
ChronicleSidekick:RefreshUI()
local firstGroup = find("1. Ragefire Chasm").parent.parent
assert(firstGroup == find("2. Ragefire Chasm").parent.parent)
assert(firstGroup ~= find("1. Molten Core").parent.parent)
assert(firstGroup.backdrop and firstGroup.height == 38 + 2 * 36 + 7)
assert(find("2 instances"))
assert(find("Processing - 1 instance: Analyzing"))
assert(find("|cffffd100Log - Oct 31, 21:04|r"))
for _, f in ipairs(frames) do
    if f:IsShown() and f.text then
        assert(not string.find(f.text, "ChronicleUpload_", 1, true), "hide implementation filenames")
        assert(f.text ~= "complete:", "completed links do not need a state label")
    end
end
ChronicleSidekick.status.requests = {}
ChronicleSidekick:RefreshUI()
assert(not firstGroup:IsShown(), "empty history must hide old groups")
assert(find("No uploads yet."))
print("sidekick_ui_test: PASS (Lua " .. _VERSION .. ")")
