-- Chronicle local RPC v1. Data files are TSV, never executable Lua. See SIDEKICK_PROTOCOL.md.
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

local METHOD = "combat_log.upload"
local function validID(value)
    return type(value) == "string" and string.len(value) >= 1 and string.len(value) <= 200
        and string.find(value, "^[A-Za-z0-9_%-]+$") ~= nil
end

local function archiveName(id)
    return "ChronicleUpload_" .. id .. ".txt"
end

local function timestamp(value)
    if type(value) ~= "string" or not string.find(value, "^%d+$") then return nil end
    local number = tonumber(value)
    if not number or number > 9007199254740991 or number < 0 then return nil end
    return number
end

-- Strictly parse a complete snapshot; malformed replacements never erase good state.
function Sidekick:ParseStatus(content)
    if type(content) ~= "string" or string.len(content) > 262144 or string.sub(content, -1) ~= "\n" or string.find(content, "[%z\001-\008\011-\031\127]") then return nil end
    local status = { requests = {} }
    local byID = {}
    local first = true
    for line in string.gfind(content, "([^\n]+)\n") do
        local f = fields(line)
        if first then
            if table.getn(f) ~= 6 or f[1] ~= "RPC" or f[2] ~= "1" or not timestamp(f[4]) then return nil end
            status.version, status.heartbeat, status.readiness, status.message = f[3], timestamp(f[4]), f[5], f[6]
            first = false
        elseif f[1] == "RESPONSE" then
            if table.getn(f) ~= 7 or not validID(f[2]) or byID[f[2]]
                or f[3] ~= METHOD or not STATES[f[4]] or not timestamp(f[5]) or not timestamp(f[6]) then return nil end
            local request = { id = f[2], filename = archiveName(f[2]), method = f[3], state = f[4], created = tonumber(f[5]), updated = tonumber(f[6]), message = f[7], instances = {} }
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
    for _, request in pairs(self.pending) do
        if not request.rpcVersion then
            -- Do not silently lose archives queued by the incompatible draft.
            -- Migration is explicit user action, never an automatic upload.
            request.rpcVersion = 1
            request.state = "failed"
            request.message = "Pre-RPC request: Retry to submit this archive using RPC v1"
        end
    end
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
    local content = ChronicleFile:ReadFile("ChronicleRPC.status")
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
    local player = string.sub(string.gsub(UnitName("player") or "Unknown", "[^A-Za-z0-9]", ""), 1, 60)
    local realm = string.sub(string.gsub(GetRealmName() or "Unknown", "[^A-Za-z0-9]", ""), 1, 60)
    local prefix = player .. "_" .. realm .. "_" .. time() .. "_"
    local id = prefix .. ChronicleCompanionDB.sidekickSequence
    while ChronicleFile:FileExists("ChronicleUpload_" .. id .. ".txt") do
        ChronicleCompanionDB.sidekickSequence = ChronicleCompanionDB.sidekickSequence + 1
        id = prefix .. ChronicleCompanionDB.sidekickSequence
    end
    return id
end

-- Snapshot disk + outstanding deferred lines + current buffer without first draining
-- them through FlushToFile (which currently clears buffers even on write failure).
-- Lua callbacks run serially: no logger callback can append during this boundary.
function Sidekick:Archive(id)
    if not validID(id) then return nil, "Invalid request ID" end
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
    local archive = archiveName(id)
    if ChronicleFile:FileExists(archive) then return nil, "Archive already exists" end
    local ok
    ok, err = ChronicleFile:WriteFile(archive, content)
    if not ok then return nil, err end
    local check = ChronicleFile:ReadFile(archive)
    if check ~= content then return nil, "Archive verification failed; active log was not cleared" end
    ok, err = ChronicleFile:WriteFile(filename, "")
    if not ok then return nil, "Archive saved, but active log could not be cleared: " .. tostring(err) end
    if ChronicleFile:ReadFile(filename) ~= "" then return nil, "Archive saved, but active log clear could not be verified" end
    self.pending[id] = { id = id, filename = archive, created = time(), rpcVersion = 1, state = "waiting", message = "Not yet queued" }
    log:ResetLogSession()
    return archive
end

function Sidekick:Queue(request, action)
    if not validID(request.id) or request.filename ~= archiveName(request.id)
        or (action ~= "request" and action ~= "retry") then return false, "Invalid request" end
    request.rpcVersion = 1
    local requestedAt = request.created or time()
    if action == "retry" then
        -- Sidekick consumes each retry timestamp once. Persist the watermark even
        -- across acknowledgments/reloads, and make rapid attempts distinct.
        local times = ChronicleCompanionDB.sidekickRetryTimes or {}
        ChronicleCompanionDB.sidekickRetryTimes = times
        requestedAt = math.max(time(), (times[request.id] or 0) + 1, (request.retryAfter or 0) + 1)
        times[request.id] = requestedAt
    end
    -- A leading newline isolates a previously interrupted append. Blank lines are ignored.
    local line = "\n1\t" .. action .. "\t" .. request.id .. "\t" .. requestedAt .. "\t" .. METHOD .. "\t" .. request.filename .. "\n"
    local ok, err = ChronicleFile:AppendToFile("ChronicleRPC.requests", line)
    request.message = ok and "Waiting for Sidekick" or ("Queue failed: " .. tostring(err))
    request.state = ok and "waiting" or "failed"
    self:Poll()
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
    ok, err = self:Queue(self.pending[id], "request")
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
    local action = request and request.retryAfter and "retry" or "request"
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
