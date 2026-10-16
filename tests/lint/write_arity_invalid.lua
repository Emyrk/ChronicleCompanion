ChronicleLog = {}

function ChronicleLog:Write2(eventType, a1, a2)
    return eventType, a1, a2
end

ChronicleLog:Write2("EXTRA_DIRECT", 1, 2, 3)
ChronicleLog:Write2("MISSING_DIRECT", 1)

local self = ChronicleLog
self:Write2(
    "EXTRA_SELF",
    string.format("%s", "nested"),
    (1 + 2),
    { value = 3 }
)

function relay(...)
    self:Write2("VARARG", ...)
end
