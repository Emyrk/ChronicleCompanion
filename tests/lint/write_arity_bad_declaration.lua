ChronicleLog = {}

function ChronicleLog:Write3(eventType, a1, a2, a3, ...)
    return eventType, a1, a2, a3, arg
end
