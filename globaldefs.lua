--- DO NOT IMPORT THIS FILE.
--- This file is only for providing type information to the language server.

---Gets the player's map position, x,y. 
---@type fun(unit: string): number, number
GetPlayerMapPosition = GetPlayerMapPosition

---Gets the name of the specified unit. 
---Example:
--- local name = UnitName("player")
--- local name = UnitName("0x0000000000000000")
--- local name = UnitName("targetowner")
---@type fun(unit: string): string|nil
UnitName = UnitName