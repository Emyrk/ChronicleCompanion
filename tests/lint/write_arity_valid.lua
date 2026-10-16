ChronicleLog = {}

function ChronicleLog:Write2(eventType, a1, a2)
    return eventType, a1, a2
end

ChronicleLog:Write2("DIRECT", 1, 2)

local self = ChronicleLog
self:Write2(
    "MULTILINE",
    string.format("%s", "nested"),
    (1 + 2)
)

-- WriteN is only reserved on ChronicleLog and its conventional self receiver.
local OtherThing = {}
OtherThing:Write2("UNRELATED", 1, 2, 3)
