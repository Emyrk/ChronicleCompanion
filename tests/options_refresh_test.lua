-- Exercise real options creation/refresh with native-style synchronous callbacks.
local methods = {}
local named = {}
local function noop() end
local function frame(kind, name, parent)
    local object = { name = name, scripts = {}, kind = kind, parent = parent }
    setmetatable(object, { __index = function(self, key) return methods[key] or noop end })
    if name then named[name] = object end
    return object
end
function methods:SetScript(name, callback) self.scripts[name] = callback end
function methods:GetName() return self.name end
function methods:CreateFontString() return frame("FontString") end
function methods:SetText(text) self.text = text end
function methods:GetText() return self.text end
function methods:GetValue() return self.value or 0 end
local callbacks = 0
function methods:SetValue(value)
    self.value = value
    -- Deliberately fire even for unchanged values, to expose callback recursion.
    if self.scripts.OnValueChanged then
        callbacks = callbacks + 1
        assert(callbacks < 100, "unbounded slider/refresh callback cycle")
        local previous = this
        this = self
        self.scripts.OnValueChanged()
        this = previous
    end
end
CreateFrame = frame
getglobal = function(name)
    if not named[name] then named[name] = frame("FontString", name) end
    return named[name]
end
UIParent = frame("Frame", "UIParent")
StaticPopupDialogs = {}
UISpecialFrames = {}
tinsert = table.insert
UIDropDownMenu_Initialize = noop
UIDropDownMenu_SetWidth = noop
UIDropDownMenu_SetSelectedValue = noop
UIDropDownMenu_SetText = noop
Chronicle_ClassicAPIVersion = function() return "" end
ChronicleMinimapButton = { SetShown = noop }
ChronicleCompanionDB = {}
ChronicleLog = {}
dofile("advancedlogging/config.lua")
ChronicleLog.IsEnabled = function() return false end
ChronicleLog.IsInInstance = function() return false end
ChronicleLog.CheckVersion = function() return "1", "ffffff" end
ChronicleLog:InitConfig()
ChronicleLog:CreateOptionsPanel()
local refresh = ChronicleLog.RefreshOptionsPanel
local refreshes = 0
function ChronicleLog:RefreshOptionsPanel()
    refreshes = refreshes + 1
    assert(refreshes < 10, "programmatic slider callbacks reentered options refresh")
    return refresh(self)
end
ChronicleLog:RefreshOptionsPanel()
assert(refreshes == 1 and callbacks == 3)
assert(not ChronicleLog.refreshingRangeSliders)
assert(getglobal("ChronicleLogRangeDefaultText").text == "Default: 40")
local slider = ChronicleLog.optionsPanel.defaultRangeSlider
slider:SetValue(80)
assert(ChronicleLog:GetSetting("rangeDefault") == 80)
assert(refreshes == 2 and callbacks == 7)
assert(getglobal("ChronicleLogRangeDefaultText").text == "Default: 80")
ChronicleLog:RefreshOptionsPanel()
assert(refreshes == 3 and callbacks == 10, "same-value refresh must remain bounded")
print("options_refresh_test.lua: ok")
