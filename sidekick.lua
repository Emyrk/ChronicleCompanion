-- Sidekick IPC v1. Data files are TSV, never executable Lua. See SIDEKICK_PROTOCOL.md.
ChronicleSidekick = { pending = {}, elapsed = 0 }
local Sidekick = ChronicleSidekick
local STATES = { queued = true, uploading = true, processing = true, complete = true, failed = true }

local function fields(line)
    local result = {}
    for value in string.gfind(line .. "\t", "([^\t]*)\t") do
        table.insert(result, value)
    end
    return result
end

local function safeName(value)
    return value and string.find(value, "^ChronicleUpload_[%w_%-]+%.txt$") ~= nil
end

-- Strictly parse a complete snapshot; malformed replacements never erase good state.
function Sidekick:ParseStatus(content)
    if type(content) ~= "string" or string.len(content) > 262144 or string.sub(content, -1) ~= "\n" then return nil end
    local status = { requests = {} }
    local byID = {}
    local first = true
    for line in string.gfind(content, "([^\n]+)\n") do
        local f = fields(line)
        if first then
            if table.getn(f) ~= 6 or f[1] ~= "SIDEKICK" or f[2] ~= "1" or not tonumber(f[4]) then return nil end
            status.version, status.heartbeat, status.readiness, status.message = f[3], tonumber(f[4]), f[5], f[6]
            first = false
        elseif f[1] == "REQUEST" then
            if table.getn(f) ~= 7 or not string.find(f[2], "^[%w_%-]+$") or byID[f[2]]
                or not safeName(f[3]) or not STATES[f[4]] or not tonumber(f[5]) or not tonumber(f[6]) then return nil end
            local request = { id = f[2], filename = f[3], state = f[4], created = tonumber(f[5]), updated = tonumber(f[6]), message = f[7], instances = {} }
            byID[request.id] = request
            table.insert(status.requests, request)
        elseif f[1] == "INSTANCE" then
            local request = byID[f[2]]
            if table.getn(f) ~= 5 or not request or not string.find(f[5], "^https://[^%s]+$") then return nil end
            table.insert(request.instances, { id = f[3], name = f[4], url = f[5] })
        else
            return nil
        end
    end
    if first then return nil end
    return status
end

function Sidekick:LoadPending()
    if not ChronicleCompanionDB then return end
    if not ChronicleCompanionDB.sidekickPending then ChronicleCompanionDB.sidekickPending = {} end
    self.pending = ChronicleCompanionDB.sidekickPending
end

function Sidekick:Ready()
    local s = self.status
    if not s then return false, "Sidekick offline" end
    local age = time() - s.heartbeat
    if age < -5 or age > 20 then return false, "Sidekick offline (stale heartbeat)" end
    if s.readiness ~= "ready" then return false, s.message ~= "" and s.message or s.readiness end
    return true, "Sidekick ready"
end

function Sidekick:Poll()
    self:LoadPending()
    local content = ChronicleFile:ReadFile("ChronicleSidekick.status")
    local status = self:ParseStatus(content)
    if status then
        self.status = status
        for _, request in ipairs(status.requests) do
            -- Acknowledged requests are now Sidekick's durable responsibility.
            local pending = self.pending[request.id]
            if not pending or not pending.retryAfter or request.state ~= "failed" or request.updated > pending.retryAfter then
                self.pending[request.id] = nil
            end
        end
    end
    if self.RefreshUI then self:RefreshUI() end
end

function Sidekick:NextID()
    ChronicleCompanionDB.sidekickSequence = (ChronicleCompanionDB.sidekickSequence or 0) + 1
    local player = string.gsub(UnitName("player") or "Unknown", "[^%w]", "")
    local realm = string.gsub(GetRealmName() or "Unknown", "[^%w]", "")
    local id = player .. "_" .. realm .. "_" .. time() .. "_" .. ChronicleCompanionDB.sidekickSequence
    while ChronicleFile:FileExists("ChronicleUpload_" .. id .. ".txt") do
        ChronicleCompanionDB.sidekickSequence = ChronicleCompanionDB.sidekickSequence + 1
        id = id .. "_" .. ChronicleCompanionDB.sidekickSequence
    end
    return id
end

-- Snapshot disk + outstanding deferred lines + current buffer without first draining
-- them through FlushToFile (which currently clears buffers even on write failure).
-- Lua callbacks run serially: no logger callback can append during this boundary.
function Sidekick:Archive(id)
    local log = ChronicleLog
    local filename = log:GetLogFilename()
    local existing, err = ChronicleFile:ReadFile(filename)
    if err then return nil, err end
    if (existing ~= nil and type(existing) ~= "string") or (existing == nil and ChronicleFile:FileExists(filename)) then return nil, "Unable to read active log" end
    local parts = { existing or "" }
    local pending = log.pendingFlush
    if pending then
        if pending.filename ~= filename then return nil, "Pending log filename changed; save it before uploading" end
        table.insert(parts, table.concat(pending.lines, "\n", pending.pos, pending.n) .. "\n")
    end
    if log.bufferSize > 0 then
        table.insert(parts, "0|" .. log:GenerateHeader() .. "\n")
        table.insert(parts, table.concat(log.buffer, "\n", 1, log.bufferSize) .. "\n")
    end
    local content = table.concat(parts)
    if content == "" then return nil, "There are no logs to upload" end
    local archive = "ChronicleUpload_" .. id .. ".txt"
    if ChronicleFile:FileExists(archive) then return nil, "Archive already exists" end
    local ok
    ok, err = ChronicleFile:WriteFile(archive, content)
    if not ok then return nil, err end
    local check = ChronicleFile:ReadFile(archive)
    if check ~= content then return nil, "Archive verification failed; active log was not cleared" end
    ok, err = ChronicleFile:WriteFile(filename, "")
    if not ok then return nil, "Archive saved, but active log could not be cleared: " .. tostring(err) end
    if ChronicleFile:ReadFile(filename) ~= "" then return nil, "Archive saved, but active log clear could not be verified" end
    self.pending[id] = { id = id, filename = archive, created = time(), state = "waiting", message = "Not yet queued" }
    log:ResetLogSession()
    return archive
end

function Sidekick:Queue(request, action)
    if not safeName(request.filename) or not string.find(request.id, "^[%w_%-]+$") then return false, "Invalid request" end
    -- A leading newline isolates a previously interrupted append. Blank lines are ignored.
    local line = "\n1\t" .. action .. "\t" .. request.id .. "\t" .. time() .. "\t" .. request.filename .. "\n"
    local ok, err = ChronicleFile:AppendToFile("ChronicleSidekick.requests", line)
    request.message = ok and "Waiting for Sidekick" or ("Queue failed: " .. tostring(err))
    request.state = ok and "waiting" or "failed"
    if self.RefreshUI then self:RefreshUI() end
    return ok, err
end

function Sidekick:ArchiveAndUpload()
    self:Poll()
    local ready, reason = self:Ready()
    if not ready then Chronicle:Print(reason); return false end
    local id = self:NextID()
    local filename, err = self:Archive(id)
    if not filename then Chronicle:Print("Upload not queued: " .. tostring(err)); return false end
    local ok
    ok, err = self:Queue(self.pending[id], "upload")
    Chronicle:Print(ok and ("Archived and queued: " .. filename) or ("Archive retained; retry upload: " .. tostring(err)))
    if self.OpenTray then self:OpenTray("sidekick") end
    ChronicleLog:RefreshOptionsPanel()
    return ok
end

function Sidekick:Retry(id)
    self:Poll()
    local ready, reason = self:Ready()
    if not ready then Chronicle:Print(reason); return false end
    local request = self.pending[id]
    local action = request and request.retryAfter and "retry" or "upload"
    if not request and self.status then
        for _, candidate in ipairs(self.status.requests) do
            if candidate.id == id and candidate.state == "failed" then
                request = { id = id, filename = candidate.filename, created = candidate.created, retryAfter = candidate.updated }
                action = "retry"
                break
            end
        end
    end
    if not request then return false end
    self.pending[id] = request
    local ok, err = self:Queue(request, action)
    if not ok then Chronicle:Print("Retry queue failed: " .. tostring(err)) end
    return ok
end

local frame = CreateFrame("Frame")
frame:SetScript("OnUpdate", function()
    Sidekick.elapsed = Sidekick.elapsed + arg1
    local visible = Sidekick.IsTrayVisible and Sidekick:IsTrayVisible()
    if Sidekick.elapsed >= (visible and 2 or 10) then
        Sidekick.elapsed = 0
        Sidekick:Poll()
    end
end)
