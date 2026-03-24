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
    if not ok then
        return false, err
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
    if not ok then
        return false, err
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
