-- Fix the global gmatch function for older Lua versions

cstrjoin = string.join or function(delim, ...)
    if type(arg) == 'table' then
    return table.concat(arg, delim)
    else
    return delim
    end
end

cgmatch = string.gmatch or string.gfind
cunpack = unpack or table.unpack
cmatch = string.match or function (s, pattern, init)
    init = init or 1
    -- try to find captures
    local results = { string.find(s, pattern, init) }
    if table.getn(results) > 2 then
        -- drop the start/end positions, keep captures
        local captures = {}
        for i = 3, table.getn(results) do
            table.insert(captures, results[i])
        end
        return cunpack(captures)
    elseif results[1] and results[2] then
        -- no captures, return the matched substring
        return string.sub(s, results[1], results[2])
    end
    return nil
end

-- Compare version strings like "1.5.2" > "1.5"
---@param v1 string
---@param v2 string
---@return number
function ChronicleCompareVersion(v1, v2)
    -- Returns: 1 if v1 > v2, -1 if v1 < v2, 0 if equal
    local function split(str)
        local parts = {}
        for num in cgmatch(str, "(%d+)") do
            table.insert(parts, tonumber(num))
        end
        return parts
    end
    local p1, p2 = split(v1), split(v2)
    local maxLen = math.max(table.getn(p1), table.getn(p2))
    for i = 1, maxLen do
        local n1 = p1[i] or 0
        local n2 = p2[i] or 0
        if n1 > n2 then return 1 end
        if n1 < n2 then return -1 end
    end
    return 0
end


function Chronicle_NampowerVersion()
    local version = ""
    if GetNampowerVersion then
        local major, minor, patch = GetNampowerVersion()
        if major then version = major .. "." .. (minor or 0) .. "." .. (patch or 0) end
    end
    return version
end