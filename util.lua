-- Compare version strings like "1.5.2" > "1.5"
---@param v1 string
---@param v2 string
---@return number
function ChronicleCompareVersion(v1, v2)
    -- Returns: 1 if v1 > v2, -1 if v1 < v2, 0 if equal
    local function split(str)
        local parts = {}
        for num in string.gmatch(str, "(%d+)") do
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