-- File I/O abstraction for ChronicleCompanion
-- Wraps Nampower's CustomData file APIs (WriteCustomFile, ReadCustomFile, CustomFileExists)

ChronicleFile = {}

-------------------------------------------------------------------------------
-- File Operations
-------------------------------------------------------------------------------

--- Append content to a file (creates if doesn't exist)
-- @param filename string: File name (no path separators)
-- @param content string: Content to append
-- @return boolean: success
-- @return string|nil: error message on failure
function ChronicleFile:AppendToFile(filename, content)
    if not WriteCustomFile then
        return false, "WriteCustomFile not available (requires Nampower)"
    end
    local ok, err = pcall(WriteCustomFile, filename, content, "a")
    if not ok or err == false then
        return false, (not ok and err) or "WriteCustomFile returned false"
    end
    return true
end

--- Read entire file contents
-- @param filename string: File name (no path separators)
-- @return string|nil: file contents, or nil if doesn't exist
-- @return string|nil: error message on failure
function ChronicleFile:ReadFile(filename)
    if not ReadCustomFile then
        return nil, "ReadCustomFile not available (requires Nampower)"
    end
    local ok, result = pcall(ReadCustomFile, filename)
    if not ok then
        return nil, result
    end
    return result  -- nil if file doesn't exist
end

--- Write content to a file (overwrites existing)
-- @param filename string: File name (no path separators)
-- @param content string: Content to write
-- @return boolean: success
-- @return string|nil: error message on failure
function ChronicleFile:WriteFile(filename, content)
    if not WriteCustomFile then
        return false, "WriteCustomFile not available (requires Nampower)"
    end
    local ok, err = pcall(WriteCustomFile, filename, content, "w")
    if not ok or err == false then
        return false, (not ok and err) or "WriteCustomFile returned false"
    end
    return true
end

--- Check if a file exists
-- @param filename string: File name (no path separators)
-- @return boolean: true if exists
function ChronicleFile:FileExists(filename)
    if not CustomFileExists then
        return false
    end
    local ok, result = pcall(CustomFileExists, filename)
    if not ok then
        return false
    end
    return result == true
end

--- Probe using the read API rather than CustomFileExists. The reported runtime
--- marked every candidate as existing; never loop on that result.
--- @return boolean|nil: true if readable, false if missing, nil on error
--- @return string|nil: error message
function ChronicleFile:ProbeFile(filename)
    local content, err = self:ReadFile(filename)
    if err then return nil, err end
    if content == nil then return false end
    if type(content) ~= "string" then return nil, "ReadCustomFile returned an unexpected value" end
    return true
end
