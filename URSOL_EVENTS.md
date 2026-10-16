# ChronicleCompanion — extra log events

Extra log lines for deeper raid analysis, written by `advancedlogging/ursol.lua`
on top of everything ChronicleCompanion already logs.

The file is named after "Ursol", the TurtleWoW 1.18.1 client patch, now used by
the servers that came from TurtleWoW (OctoWoW, Capybara, Ravencraft, ...). Nothing
in it is tied to one server: every line type runs only when the client provides
what it needs, so a plain 1.12 client with Nampower logs what it can and the
rest stays off, without errors.

All lines keep the usual layout `TIMESTAMP_MS|EVENT|field|...`. The event names
are new, so Chronicle skips them (checked with Chronicle's own parser on a real
Onyxia log with tens of thousands of extra lines, including UNIT_STATE: 0 errors,
identical results). Existing events are unchanged, except `HEADER` and
`ZONE_INFO`, which get new fields appended at the end (see below).

## Requirements

| Feature | Needs | Without it |
| --- | --- | --- |
| UNIT_STATE (health, power), UNIT_TARGET, UNIT_COMBAT | Nampower with `GetUnitField` | off, events not registered |
| UNIT_STATE position fields | ClassicAPI (any visible unit) or SuperWoW (friendly units only) | fields left empty, no position poll |
| RAID_MARK | `GetRaidTargetIndex` and unit GUIDs (Nampower `GetUnitGUID` or SuperWoW); `markN` tokens of ClassicAPI / SuperWoW make it more complete | off |
| THREAT, THREAT_TANK | a server with the TWThreat threat API (TurtleWoW-based servers); TWThreat or pfUI-ThreatPlates optional | nothing written; requests stop by themselves (see `threatQuery`) |

Line types the client cannot produce are greyed out in the options panel with
the reason, and marked `(off: ...)` in `/chronicle ursol`. The saved setting is
kept, so they come back on with the DLL.

## Events

### HEADER and ZONE_INFO (existing lines, extra fields)
`0|HEADER|playerGuid|realm|zone|addonVer|superWowVer|namPowerVer|xp3Ver|wowVer|wowBuild|wowBuildDate|localTime|utcTime|combatLogRange|classicApi|threatMode`

- `superWowVer`: the existing slot is filled again with `SUPERWOW_VERSION`
  (empty without SuperWoW).
- `classicApi` (new, at the end): ClassicAPI version `X.Y.Z`, decoded from
  `CLASSIC_API_VERSION` (major × 10000 + minor × 100 + patch); empty when
  ClassicAPI is not loaded, `unknown` for a build without that global.
- `threatMode` (new, at the end): `query` (this addon asks the server),
  `listen` (TWThreat / pfUI-ThreatPlates ask, this addon records the answers)
  or empty when threat logging is off.

`ts|ZONE_INFO|zoneName||inInstance|instanceType|isGhost|mapId`

- The slot after the zone name stays empty: Chronicle uses it as an internal
  instance number.
- `mapId` (new, at the end): the `Map.dbc` id (ClassicAPI `GetInstanceInfo`),
  e.g. 309 for Zul'Gurub; empty without ClassicAPI.

### UNIT_STATE
`ts|UNIT_STATE|guid|hp|maxHp|power|maxPower|powerType|mapId|x|y|z`

Health, power and position of one unit on one line, written only when one of
them changes (position: a move of more than `positionMinMove` yards).

| Field | Content |
| --- | --- |
| `hp`, `maxHp` | current and max health |
| `power`, `maxPower` | current and max value of the unit's **current** power type |
| `powerType` | `0` mana, `1` rage, `2` focus, `3` energy, `4` happiness |
| `mapId` | `Map.dbc` id (ClassicAPI), e.g. 309 for Zul'Gurub; empty without ClassicAPI (same value as in `ZONE_INFO`) |
| `x`, `y`, `z` | world coordinates in yards (1 decimal), x = north, y = west whatever the API |

Empty fields mean "not available" (no power, out of position range, etc.).
Rage is converted to the usual 0–100 scale (the unit field stores ×10).

Units: group members, their pets, and hostile creatures seen in combat events
during the last 15 s. Lines come from:
- Nampower `UNIT_HEALTH_GUID` / `UNIT_MANA_GUID` / `UNIT_RAGE_GUID` /
  `UNIT_ENERGY_GUID`, written right away (same timestamp as the event);
- a poll of tracked hostiles every `targetInterval` (0.25 s);
- a position poll every `positionInterval` (1 s), only while you are in combat.

Notes:
- A druid's power is the one of their current form: energy in cat form, rage
  in bear form, mana otherwise. The caster mana is not visible while shifted.
- Check `maxHp` for creatures. If it is 100, the server sends a percentage
  instead of real hit points.

### UNIT_TARGET
`ts|UNIT_TARGET|guid|targetGuid`

Target of each tracked hostile creature (empty = no target), polled every
`targetInterval` (0.25 s), written on change. Gives who is tanking and when a
boss switches target.

### UNIT_COMBAT
`ts|UNIT_COMBAT|guid|inCombat`

A hostile creature enters (`1`) or leaves (`0`) combat. Read from the "in
combat" bit of the unit flags (`UNIT_FLAG_IN_COMBAT`, `0x80000`), on Nampower
`UNIT_FLAGS_GUID` and during the poll of tracked hostiles (`targetInterval`).

- `1`: the mob was pulled (or joined the fight). Mobs only seen idle write nothing.
- `0` after a `DEATH` of the same unit: it died.
- `0` with no `DEATH`: it **reset / evaded** (wipe, kited too far, leash).
  Its health goes back to max and it walks back to its spawn, visible in
  `UNIT_STATE`; attacks on it during the walk back come out as "Evade" in
  `SWING` / `MISS`.
- A mob that goes out of range while in combat is forgotten after 60 s
  without a `0` line: how its fight ended is unknown.


`ts|RAID_MARK|guid|index`

Raid icon 1–8 set on a unit, `0` when removed. Scanned 0.3 s after the last
`RAID_TARGET_UPDATE` of a burst, on enable, and every 5 s in combat. A removal
is written when the icon moves to another unit, or when the unit is missing
from two scans in a row (a single scan can miss a mark for a moment).

### THREAT
`ts|THREAT|mobGuid|mobName|source|list`

Server threat table of one mob: `player:tank:threat:perc:melee;...`
(`tank`/`melee` = 1 or 0, `perc` = % of the tank's threat, rounded to 1
decimal: the server sends `100.000000`). `source`:
- `self`: answer to a `TWT_UDTSv4_TM` request from this client (this addon,
  TWThreat or pfUI-ThreatPlates). `mobGuid` is your target when the answer
  arrived.
- `relay:<Name>`: a `TWTRelayV2` message shared by a group member (TWThreat
  or pfUI-ThreatPlates). `mobGuid` is that player's target, empty if
  it could not be confirmed.

The same table received twice within 1.5 s is written once.

### THREAT_TANK
`ts|THREAT_TANK|source|list`

"Mobs I am tanking" list: `creature:serverGuid:nextPlayer:perc;...` (`perc`
rounded to 1 decimal).
`source` is `self` (TMTv1 answer) or `relay:<Tank>` (`PFTPTankV1` share).
`serverGuid` is the server's decimal form, not the `0x…` form.

## Settings

The options panel (`/clog` or `/chronicle config`) has an **Extra events**
side panel on its right: one checkbox per line type (the Positions line shows
which API gives them) and the threat request mode (auto / on / off). The
ClassicAPI and SuperWoW versions are listed under **Version Info** in the main
panel, next to Nampower. Intervals are only in the slash
command: `/chronicle ursol` lists the settings, `/chronicle ursol <setting>
<value>` changes one.

| Setting | Default | Meaning |
| --- | --- | --- |
| unitState, target, combat, marks, threat | on | turn each line type on/off |
| position | on | add positions to `UNIT_STATE` and poll them in combat |
| targetInterval | 0.25 | seconds between target / combat flag / hostile health and power polls |
| positionInterval | 1 | seconds between position polls (in combat) |
| positionMinMove | 0.5 | yards a unit must move before a position change alone writes a line |
| threatQuery | auto | `auto`: ask the server only if TWThreat and pfUI-ThreatPlates are absent, and stop after 10 requests without any answer (server without the threat API; an answer, even relayed by the group, turns them back on); `on`: always ask; `off`: only listen |
| threatInterval | 1 | seconds between threat requests |
| threatLimit | 10 | players per threat table requested |

## Limits

- Only units your client sees are logged. Several raiders logging together
  cover the whole raid.
- The server only answers threat for **your** target. Shared relays from the
  group fill in the other mobs.
- File size grows with UNIT_STATE lines. Not measured yet in a
  40-man raid: check the first log and raise the intervals if needed.
