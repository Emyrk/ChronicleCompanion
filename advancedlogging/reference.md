{{wowapievent|t=e|namespace=C_CombatLog|system=CombatLog}} {{tocright}}
Fires for [[Combat Log]] events such as a player casting a spell or an NPC taking damage.

- COMBAT_LOG_EVENT only reflects the filtered events in the combat log window
- COMBAT_LOG_EVENT_UNFILTERED (CLEU) is unfiltered, making it preferred for use by addons.

Both events have identical parameters. The event payload is returned from {{api|CombatLogGetCurrentEventInfo}}(), or from {{api|CombatLogGetCurrentEntry}}() if selected using {{api|CombatLogSetCurrentEntry}}().

==Base Parameters==
{| class="darktable"
! 1st Param !! 2nd Param !! 3rd Param !! 4th Param !! 5th Param !! 6th Param !! 7th Param !! 8th Param !! 9th Param !! 10th Param !! 11th Param
|-
| timestamp || subevent || hideCaster || [[GUID|sourceGUID]] || sourceName || [[unitFlag|sourceFlags]] || [[raidFlag|sourceRaidFlags]] || destGUID || destName || destFlags || destRaidFlags
|}

:;timestamp:{{apitype|number}} - Unix Time in seconds with milliseconds precision, for example <code>1555749627.861</code>. Similar to {{api|time}}() and can be passed as the second argument of {{api|date}}().
:;subevent:{{apitype|string}} - The combat log event, for example <code>SPELL_DAMAGE</code>.
:;hideCaster:{{apitype|boolean}} - Returns true if the source unit is hidden (an empty string).<sup>[https://www.townlong-yak.com/framexml/8.1.5/Blizzard_CombatLog/Blizzard_CombatLog.lua#3234]</sup>
:;guid:{{apitype|string}} - Globally [[GUID|unique identifier]] for units (NPCs, players, pets, etc), for example <code>"Creature-0-3113-0-47-94-00003AD5D7"</code>.
:;name:{{apitype|string}} - Name of the unit.
:;flags:{{apitype|number}} - Contains the [[UnitFlag|flag]] bits for a unit's type, controller, reaction and affiliation. For example <code>68168 (0x10A48)</code>: Unit is the current target, is an NPC, the controller is an NPC, reaction is hostile and affiliation is outsider.
:;raidFlags:{{apitype|number}} - Contains the [[raidFlag|raid flag]] bits for a unit's [[Target marker|raid target]] icon. For example <code>64 (0x40)</code>: Unit is marked with {{Raidicon|Cross}}.

==Events==
Combat log events consist of a prefix and suffix part, with their related parameters. For a full example see [[#Payload]].

===Prefixes===
Spell IDs are always <code>0</code> on [[World of Warcraft: Classic|vanilla]].
{| class="darktable zebra"
! Prefix !! 1st Param (12th) !! 2nd Param (13th) !! 3rd Param (14th)
|-
| SWING
|-
| RANGE || spellId || spellName || spellSchool
|-
| SPELL || spellId || spellName || spellSchool
|-
| SPELL_PERIODIC || spellId || spellName || spellSchool
|-
| SPELL_BUILDING || spellId || spellName || spellSchool
|-
| ENVIRONMENTAL || environmentalType
|}

===Suffixes===
The parameters for <code>critical</code>, <code>glancing</code>, <code>crushing</code>, and <code>isOffHand</code> are true/false flags.
{| class="darktable zebra"
!Suffix !! 1st Param (15th) !! 2nd Param (16th) !! 3rd Param (17th) !! 4th Param (18th) !! 5th Param (19th) !! 6th Param (20th) !! 7th Param (21st) !! 8th Param (22nd) !! 9th Param (23rd) !! 10th Param (24th)
|-
| \_DAMAGE || amount || overkill || school || resisted || blocked || absorbed || critical || glancing || crushing || isOffHand
|-
| \_MISSED || missType || isOffHand || amountMissed || critical
|-
| \_HEAL || amount || overhealing || absorbed || critical
|-
| \_HEAL_ABSORBED || extraGUID || extraName || extraFlags || extraRaidFlags || extraSpellID || extraSpellName || extraSchool || absorbedAmount || [[#SPELL_HEAL_ABSORBED|#totalAmount]]
|-
| [[#SPELL_ABSORBED|_ABSORBED]]
|-
| \_ENERGIZE || amount || overEnergize || powerType || [[#SPELL_ENERGIZE|#maxPower]]
|-
| \_DRAIN || amount || powerType || extraAmount || [[#SPELL_ENERGIZE|#maxPower]]
|-
| \_LEECH || amount || powerType || extraAmount
|-
| \_INTERRUPT || extraSpellId || extraSpellName || extraSchool
|-
| \_DISPEL || extraSpellId || extraSpellName || extraSchool || auraType
|-
| \_DISPEL_FAILED || extraSpellId || extraSpellName || extraSchool
|-
| \_STOLEN || extraSpellId || extraSpellName || extraSchool || auraType
|-
| \_EXTRA_ATTACKS || amount
|-
| \_AURA_APPLIED || auraType || amount
|-
| \_AURA_REMOVED || auraType || amount
|-
| \_AURA_APPLIED_DOSE || auraType || amount
|-
| \_AURA_REMOVED_DOSE || auraType || amount
|-
| \_AURA_REFRESH || auraType || [[#SPELL_AURA_REFRESH|#amount]]
|-
| \_AURA_BROKEN || auraType
|-
| \_AURA_BROKEN_SPELL || extraSpellId || extraSpellName || extraSchool || auraType
|-
| \_CAST_START
|-
| \_CAST_SUCCESS
|-
| \_CAST_FAILED || failedType
|-
| \_INSTAKILL || [[#Death_Events|#unconsciousOnDeath]]
|-
| \_DURABILITY_DAMAGE
|-
| \_DURABILITY_DAMAGE_ALL
|-
| \_CREATE
|-
| \_SUMMON
|-
| \_RESURRECT
|}

===Special events===
{| class="darktable zebra"
! Subevent !! Prefix to use !! Suffix to use
|-
| DAMAGE_SPLIT || SPELL || \_DAMAGE
|-
| DAMAGE_SHIELD || SPELL || \_DAMAGE
|-
| DAMAGE_SHIELD_MISSED || SPELL || \_MISSED
|}

{| class="darktable zebra"
! Subevent !! 1st Param (12th) !! 2nd Param (13th) !! 3rd Param (14th)
|-
| ENCHANT_APPLIED || spellName || itemID || itemName
|-
| ENCHANT_REMOVED || spellName || itemID || itemName
|-
| PARTY_KILL
|-
| UNIT_DIED || {{api|GetDeathRecapLink|recapID}} || [[#Death_Events|#unconsciousOnDeath]]
|-
| UNIT_DESTROYED || recapID || [[#Death_Events|#unconsciousOnDeath]]
|-
| UNIT_DISSIPATES || recapID || [[#Death_Events|#unconsciousOnDeath]]
|}

==Parameter Values==
===Spell School===
{| class="darktable zebra col1-center col2-center"
!Type<br />(bitmask) !! Type<br />(decimal) !! <font size="3">{{api|GetSchoolString|Name}}</font> !! <font size="3">[[Magic schools#Multi-school|Combination]]</font>
|-
| 00000001 || 1 || <font color="#FFFF00">Physical</font> || #FFFF00 &nbsp; <code>255, 255, 0</code>
|-
| 00000010 || 2 || <font color="#FFE680">Holy</font> || #FFE680 &nbsp; <code>255, 230, 128</code>
|-
| 00000100 || 4 || <font color="#FF8000">Fire</font> || #FF8000 &nbsp; <code>255, 128, 0</code>
|-
| 00001000 || 8 || <font color="#4DFF4D">Nature</font> || #4DFF4D &nbsp; <code>77, 255, 77</code>
|-
| 00010000 || 16 || <font color="#80FFFF">Frost</font> || #80FFFF &nbsp; <code>128, 255, 255</code>
|-
| 00100000 || 32 || <font color="#8080FF">Shadow</font> || #8080FF &nbsp; <code>128, 128, 255</code>
|-
| 01000000 || 64 || <font color="#FF80FF">Arcane</font> || #FF80FF &nbsp; <code>255, 128, 255</code>
|-
! colspan="5" | '''Double schools'''
|-
| 00000011 || 3 || Holystrike || Holy, Physical
|-
| 00000101 || 5 || Flamestrike || Fire, Physical
|-
| 00000110 || 6 || [[Radiant]] (Holyfire) || Fire, Holy
|-
| 00001001 || 9 || Stormstrike || Nature, Physical
|-
| 00001010 || 10 || Holystorm || Nature, Holy
|-
| 00001100 || 12 || [[Volcanic (spell school)|Volcanic]] || Nature, Fire
|-
| 00010001 || 17 || Froststrike || Frost, Physical
|-
| 00010010 || 18 || Holyfrost || Frost, Holy
|-
| 00010100 || 20 || [[Frostfire]] || Frost, Fire
|-
| 00011000 || 24 || Froststorm || Frost, Nature
|-
| 00100001 || 33 || [[Shadowstrike_(spell_school)|Shadowstrike]] || Shadow, Physical
|-
| 00100010 || 34 || [[Twilight_(spell_school)|Twilight]] (Shadowlight) || Shadow, Holy
|-
| 00100100 || 36 || [[Shadowflame_(spell_school)|Shadowflame]] || Shadow, Fire
|-
| 00101000 || 40 || [[Plague_(spell_school)|Plague]] (Shadowstorm) || Shadow, Nature
|-
| 00110000 || 48 || [[Shadowfrost]] || Shadow, Frost
|-
| 01000001 || 65 || Spellstrike || Arcane, Physical
|-
| 01000010 || 66 || [[Divine_(spell_school)|Divine]] || Arcane, Holy
|-
| 01000100 || 68 || Spellfire || Arcane, Fire
|-
| 01001000 || 72 || [[Astral]] (Spellstorm) || Arcane, Nature
|-
| 01010000 || 80 || Spellfrost || Arcane, Frost
|-
| 01100000 || 96 || [[Spellshadow]] || Arcane, Shadow
|-
! colspan="5" | '''Multi schools'''
|-
| 00011100 || 28 || [[Elemental_(spell_school)|Elemental]] || Frost, Nature, Fire
|-
| 00111110 || 62 || Chromatic || Shadow, Frost, Nature, Fire, Holy
|-
| 01101010 || 106 || Cosmic || Arcane, Shadow, Nature, Holy
|-
| 01111100 || 124 || Chaos || Arcane, Shadow, Frost, Nature, Fire
|-
| 01111110 || 126 || Magic || Arcane, Shadow, Frost, Nature, Fire, Holy
|-
| 01111111 || 127 || [[Chaos]] || Arcane, Shadow, Frost, Nature, Fire, Holy, Physical
|}

===Power Type===
{{:Enum.PowerType}}

{| class="vertical-align-row"
|
===Failed Type===
See the [https://www.townlong-yak.com/framexml/8.1.5/GlobalStrings.lua#12934 SPELL_FAILED] GlobalStrings for a full list of failed types.
_"A more powerful spell is already active"
_"Another action is in progress"
_"Can't do that while asleep"
_"Can't do that while charmed"
_"Can't do that while confused"
_"Can't do that while fleeing"
_"Can't do that while horrified"
_"Can't do that while incapacitated"
_"Can't do that while moving"
_"Can't do that while silenced"
_"Can't do that while stunned"
_"Interrupted"
_"Invalid target"
_"No target"
_"Not enough energy"
_"Not enough mana"
_"Not enough rage"
_"Out of range"
_"Target needs to be in front of you."
_"Target not in line of sight"
_"Target too close"
_"You are dead"
_"You are in combat"
_"You are in shapeshift form"
_"You are unable to move"
_"You can't do that yet"
_"You must be behind your target."
|
===Miss Type===
_"ABSORB"
_"BLOCK"
_"DEFLECT"
_"DODGE"
_"EVADE"
_"IMMUNE"
_"MISS"
_"PARRY"
_"REFLECT"
\*"RESIST"

===Aura Type===
_"BUFF"
_"DEBUFF"

===Environmental Type===
_"Drowning"
_"Falling"
_"Fatigue"
_"Fire"
_"Lava"
_"Slime"
|}

==Example==
===Script===
{{:API_CombatLogGetCurrentEventInfo}}

===Payload===
This comparison illustrates the difference between swing and spell events, e.g. the <code>amount</code> suffix parameter is on arg12 for SWING_DAMAGE and arg15 for SPELL_DAMAGE.
<syntaxhighlight lang="lua">
1617986084.18, "SWING_DAMAGE", false, "Player-1096-06DF65C1", "Xiaohuli", 1297, 0, "Creature-0-4253-0-160-94-000070569B", "Cutpurse", 68168, 0, 3, -1, 1, nil, nil, nil, true, false, false, false

1617986113.264, "SPELL_DAMAGE", false, "Player-1096-06DF65C1", "Xiaohuli", 1297, 0, "Creature-0-4253-0-160-94-000070569B", "Cutpurse", 68168, 0, 585, "Smite", 2, 47, 19, 2, nil, nil, nil, false, false, false, false
</syntaxhighlight>
{| class="vertical-align-row"
|
{| class="sortable darktable zebra col1-center"
|+ SWING_DAMAGE
! Idx !! Param !! Value
|-
| || self || <Frame>
|-
| || event || <code>"COMBAT_LOG_EVENT_UNFILTERED"</code>
|-
| 1 || timestamp || <code>1617986084.18</code>
|-
| 2 || subevent || <code>"SWING_DAMAGE"</code>
|-
| 3 || hideCaster || <code>false</code>
|-
| 4 || sourceGUID || <code>"Player-1096-06DF65C1"</code>
|-
| 5 || sourceName || <code>"Xiaohuli"</code>
|-
| 6 || sourceFlags || <code>1297</code>
|-
| 7 || sourceRaidFlags || <code>0</code>
|-
| 8 || destGUID || <code>"Creature-0-4253-0-160-94-000070569B"</code>
|-
| 9 || destName || <code>"Cutpurse"</code>
|-
| 10 || destFlags || <code>68168</code>
|-
| 11 || destRaidFlags || <code>0</code>
|-
| 12 || amount || <code>3</code>
|-
| 13 || overkill || <code>-1</code>
|-
| 14 || school || <code>1</code>
|-
| 15 || resisted || <code>nil</code>
|-
| 16 || blocked || <code>nil</code>
|-
| 17 || absorbed || <code>nil</code>
|-
| 18 || critical || <code>true</code>
|-
| 19 || glancing || <code>false</code>
|-
| 20 || crushing || <code>false</code>
|-
| 21 || isOffHand || <code>false</code>
|}
|
{| class="sortable darktable zebra col1-center"
|+ SPELL_DAMAGE
! Idx !! Param !! Value
|-
| || self || <Frame>
|-
| || event || <code>"COMBAT_LOG_EVENT_UNFILTERED"</code>
|-
| 1 || timestamp || <code>1617986113.264</code>
|-
| 2 || subevent || <code>"SPELL_DAMAGE"</code>
|-
| 3 || hideCaster || <code>false</code>
|-
| 4 || sourceGUID || <code>"Player-1096-06DF65C1"</code>
|-
| 5 || sourceName || <code>"Xiaohuli"</code>
|-
| 6 || sourceFlags || <code>1297</code>
|-
| 7 || sourceRaidFlags || <code>0</code>
|-
| 8 || destGUID || <code>"Creature-0-4253-0-160-94-000070569B"</code>
|-
| 9 || destName || <code>"Cutpurse"</code>
|-
| 10 || destFlags || <code>68168</code>
|-
| 11 || destRaidFlags || <code>0</code>
|-
| 12 || <font color="#71D5FF">spellId</font> || <code>585</code>
|-
| 13 || <font color="#71D5FF">spellName</font> || <code>"Smite"</code>
|-
| 14 || <font color="#71D5FF">spellSchool</font> || <code>2</code>
|-
| 15 || amount || <code>47</code>
|-
| 16 || overkill || <code>19</code>
|-
| 17 || school || <code>2</code>
|-
| 18 || resisted || <code>nil</code>
|-
| 19 || blocked || <code>nil</code>
|-
| 20 || absorbed || <code>nil</code>
|-
| 21 || critical || <code>false</code>
|-
| 22 || glancing || <code>false</code>
|-
| 23 || crushing || <code>false</code>
|-
| 24 || isOffHand || <code>false</code>
|}
|}

==Details==
===Event Trace===
[[File:CLEU_etrace.png|thumb|/etrace with CLEU params.]]
For the new [[MACRO eventtrace|event trace]] tool added in [[Patch 9.1.0/API_changes|Patch 9.1.0]] the following script can be loaded.

<syntaxhighlight lang="lua">
local function LogEvent(self, event, ...)
	if event == "COMBAT_LOG_EVENT_UNFILTERED" or event == "COMBAT_LOG_EVENT" then
		self:LogEvent_Original(event, CombatLogGetCurrentEventInfo())
	elseif event == "COMBAT_TEXT_UPDATE" then
		self:LogEvent_Original(event, (...), GetCurrentCombatTextEventInfo())
	else
		self:LogEvent_Original(event, ...)
	end
end

local function OnEventTraceLoaded()
EventTrace.LogEvent_Original = EventTrace.LogEvent
EventTrace.LogEvent = LogEvent
end

if EventTrace then
OnEventTraceLoaded()
else
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, ...)
if event == "ADDON_LOADED" and (...) == "Blizzard_EventTrace" then
OnEventTraceLoaded()
self:UnregisterAllEvents()
end
end)
end
</syntaxhighlight>

===SPELL_ABSORBED===
This relatively new subevent fires ''in addition'' to SWING_MISSED / SPELL_MISSED which already have the "ABSORB" <code>missType</code> and same <code>amount</code>. It optionally includes the spell payload if triggered from what would be SPELL_DAMAGE.

timestamp, subevent, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, <font color="#4ec9b0">[spellID, spellName, spellSchool]</font>, casterGUID, casterName, casterFlags, casterRaidFlags, absorbSpellId, absorbSpellName, absorbSpellSchool, amount, critical
[[File:CLEU_SPELL_ABSORBED.png]] [[File:CLEU_SPELL_ABSORBED_spell.png]]

<syntaxhighlight lang="lua">
-- swing
1620562047.156, "SWING_MISSED", false, "Creature-0-4234-0-138-44176-000016DAE1", "Bluegill Wanderer", 2632, 0, "Player-1096-06DF65C1", "Xiaohuli", 66833, 0, "ABSORB", false, 13, false
1620562047.156, "SPELL_ABSORBED", false, "Creature-0-4234-0-138-44176-000016DAE1", "Bluegill Wanderer", 2632, 0, "Player-1096-06DF65C1", "Xiaohuli", 66833, 0, "Player-1096-06DF65C1", "Xiaohuli", 66833, 0, 17, "Power Word: Shield", 2, 13, false

-- spell
1620561974.121, "SPELL_MISSED", false, "Creature-0-4234-0-138-44176-000016DAE1", "Bluegill Wanderer", 2632, 0, "Player-1096-06DF65C1", "Xiaohuli", 66833, 0, 83669, "Water Bolt", 16, "ABSORB", false, 15, false
1620561974.121, "SPELL_ABSORBED", false, "Creature-0-4234-0-138-44176-000016DAE1", "Bluegill Wanderer", 2632, 0, "Player-1096-06DF65C1", "Xiaohuli", 66833, 0, 83669, "Water Bolt", 16, "Player-1096-06DF65C1", "Xiaohuli", 66833, 0, 17, "Power Word: Shield", 2, 15, false
</syntaxhighlight>

==Advanced Combat Log==
Combat log messages may be written to the <code>World of Warcraft_retail\_\Logs\WoWCombatLog.txt</code> file for external parsing purposes.
This feature can be enabled with {{api|LoggingCombat(true)}} or toggled with the [[MACRO_combatlog|/combatlog]] slash command. Combat logging was added on patch 1.7.0<sup>[https://github.com/Gethe/wow-ui-source/commit/7d3dbc924e4aee60f94b450146a507ce52be8cb5#diff-92f522e85f5c50033ed4f36f37403dc98a11669869880afc658842510f9256ddR668]</sup>

===COMBAT_LOG_VERSION===
This log line is added when combat logging starts.
<syntaxhighlight lang="lua">
11/21 12:01:34.071 COMBAT_LOG_VERSION,19,ADVANCED_LOG_ENABLED,1,BUILD_VERSION,9.1.5,PROJECT_ID,1
</syntaxhighlight>

===Advanced parameters===
There can be up to 39 parameters, in order:

- 9 base params (subevent, source and dest unit)
- 0 to 3 prefix params (spell/environmental)
- 17 advanced params
- 0 to 10 suffix params

Advanced parameters require CVar <span class="tttemplatelink">[[CVar advancedCombatLogging|advancedCombatLogging]]</span><span style="display:none">Default: <code><font color="#ecbc2a">0</font></code><br><small>Whether we want advanced combat log data sent from the server</small></span> (added in 5.4.2)<sup>[https://github.com/Gethe/wow-ui-source/blame/f38975ca272eb537ebd4dd895ac00847f1163291/Interface/SharedXML/VideoOptionsPanels.lua#L1073]</sup> to be enabled for meaningful values.
: [[File:COMBAT_LOG_EVENT_advancedCombatLogging.png]]
{| class="sortable darktable zebra col1-center" style="margin-left: 2em"
! Idx !! Param !! Example !! Description
|-
| 1 || infoGUID || <code>Player-1096-06DF65C1</code> || [[GUID]] of the advanced params unit
|-
| 2 || ownerGUID || <code>0000000000000000</code> || GUID of the owner in case of pets/minions
|-
| 3 || currentHP || <code>584</code> || Unit current HP
|-
| 4 || maxHp || <code>584</code> || Unit max HP
|-
| 5 || attackPower || <code>3</code> || Unit attack power
|-
| 6 || spellPower || <code>75</code> || Unit spell power
|-
| 7 || armor || <code>19</code> || Unit armor
|-
| 8 || absorb || <code>0</code> || Unit applied absorb amount
|-
| 9 || powerType || <code>0</code> || [[Enum.PowerType]]
|-
| 10 || currentPower || <code>430</code> || Unit current power
|-
| 11 || maxPower || <code>430</code> || Unit max power
|-
| 12 || powerCost || <code>1</code> || Required power amount for the ability
|-
| 13 || positionX || <code>-9250.90</code> || Unit X position on the [[InstanceID|map instance]]
|-
| 14 || positionY || <code>158.82</code> || Unit Y position on the map instance
|-
| 15 || uiMapID || <code>37</code> || [[UiMapID]]
|-
| 16 || facing || <code>5.5502</code> || [[API GetPlayerFacing|Unit facing]] direction in the [0, 2π] range
|-
| 17 || level || <code>13</code> || Level for NPCs, item level for players
|}

Example for a low level priest in Elwynn Forest successfully casting a spell.
<syntaxhighlight lang="lua">
4/9 05:05:01.824 SPELL_CAST_SUCCESS,Player-1096-06DF65C1,"Xiaohuli-DefiasBrotherhood",0x511,0x0,Creature-0-4253-0-160-94-00006FB363,"Cutpurse",0x10a48,0x0,585,"Smite",0x2,Player-1096-06DF65C1,0000000000000000,584,584,3,75,19,0,0,430,430,1,-9250.90,158.82,37,5.5502,13

4/9 05:05:01.824 SPELL_DAMAGE,Player-1096-06DF65C1,"Xiaohuli-DefiasBrotherhood",0x511,0x0,Creature-0-4253-0-160-94-00006FB363,"Cutpurse",0x10a48,0x0,585,"Smite",0x2,Creature-0-4253-0-160-94-00006FB363,0000000000000000,105,152,0,0,189,0,1,0,0,0,-9213.11,144.31,37,1.7189,30,46,45,-1,2,0,0,0,nil,nil,nil
</syntaxhighlight>

These coords are also returned from {{api|C_Map.GetWorldPosFromMapPos}}() and {{api|UnitPosition}}() (provided the player is not in an instanced area).
<syntaxhighlight lang="lua">
local uiMap = C_Map.GetBestMapForUnit("player")
local pos = C_Map.GetPlayerMapPosition(uiMap, "player")
local continentID, worldPos = C_Map.GetWorldPosFromMapPos(uiMap, pos)

print(continentID, worldPos:GetXY()) -- 0, -9250.8974609375, 158.81927490234
print(UnitPosition("player")) -- -9250.900390625, 158.80000305176, 0, 0
</syntaxhighlight>

====Multiple Values====
Some events can have multiple values for a param, delimited by a <code>|</code> vertical bar, for example <code>3|4,120|5,120|5,25|5</code> for <code>powerType, currentPower, maxPower, powerCost</code> respectively. This is the case when spells use more than one powertype to cast.
12/27 20:40:53.015 SPELL_CAST_SUCCESS,Player-3686-09B3C091,"Katara-Antonidas",0x514,0x0,Vehicle-0-4252-2450-10829-175732-00004A11DB,"Sylvanas Windrunner",0x10a48,0x0,1943,"Rupture",0x1,Player-3686-09B3C091,0000000000000000,55660,55660,2018,321,689,8046,<font color="#ecbc2a">3|4,120|5,120|5,25|5</font>,230.09,-841.17,2002,3.8727,249

====Death Events====
For the following events, <code>recapID</code> is changed with (possibly) <code>unconsciousOnDeath</code>
11/18 21:07:31.950 PARTY_KILL,Player-3686-070D56DD,"Môrclen-Antonidas",0x10512,0x0,Creature-0-1465-2450-15939-178008-000016B283,"Decrepit Orb",0xa48,0x0,<font color="#ecbc2a">0</font>
10/26 21:06:20.604 SPELL_INSTAKILL,Creature-0-1469-2450-16377-99773-000078519D,"Bloodworm",0x2114,0x0,Creature-0-1469-2450-16377-99773-000078519D,"Bloodworm",0x2114,0x0,197509,"Bloodworm",0x20,<font color="#ecbc2a">0</font>
10/26 21:18:26.917 UNIT_DIED,0000000000000000,nil,0x80000000,0x80000000,Creature-0-1469-2450-16377-99773-0000785473,"Bloodworm",0x2114,0x0,<font color="#ecbc2a">0</font>
10/26 21:18:22.056 UNIT_DESTROYED,0000000000000000,nil,0x80000000,0x80000000,Creature-0-1469-2450-16377-26125-0000785441,"Risen Ghoul",0x2114,0x0,<font color="#ecbc2a">0</font>

====SPELL_AURA_REFRESH====
This is missing the <code>amount</code> param.
10/26 20:45:44.932 SPELL_AURA_REFRESH,Player-3686-0672A7D3,"Slivered-Antonidas",0x511,0x0,Player-3686-0672A7D3,"Slivered-Antonidas",0x511,0x0,21562,"Power Word: Fortitude",0x2,BUFF

====SPELL_HEAL_ABSORBED====
This has an additional 9th suffix param <code>totalAmount</code>
10/26 21:06:21.326 SPELL_HEAL_ABSORBED,Vehicle-0-1469-2450-16377-175732-0000784ACE,"Sylvanas Windrunner",0x10a48,0x0,Player-3686-0672A7D3,"Slivered-Antonidas",0x511,0x0,347704,"Veil of Darkness",0x20,Player-3686-0672A7D3,"Slivered-Antonidas",0x511,0x0,77489,"Echo of Light",0x2,104,<font color="#ecbc2a">667</font>

====\_DAMAGE and \_HEAL====

- SWING_DAMAGE, SPELL_DAMAGE, SPELL_HEAL, SPELL_PERIODIC_DAMAGE, and SPELL_PERIODIC HEAL: These have an additional 2nd suffix parameter, <code>baseAmount</code>. This is the amount before critical strike bonus, and before percent modifiers on the target, including effects like damage reduction from armor, [[Chaos Brand]], [[Mortal Strike]], etc.

====SWING_DAMAGE====

- SWING_DAMAGE: <code>infoGUID</code> is the source unit. This event is not guaranteed to fire, in that case SWING_MISSED would fire or nothing at all.
- SWING_DAMAGE_LANDED: <code>infoGUID</code> is the dest unit. This event is exclusive to the advanced combat log and always fires.
  <syntaxhighlight lang="lua">
  4/9 05:05:07.807 SWING_DAMAGE,Player-1096-06DF65C1,"Xiaohuli-DefiasBrotherhood",0x511,0x0,Creature-0-4253-0-160-94-00006FB363,"Cutpurse",0x10a48,0x0,Player-1096-06DF65C1,0000000000000000,584,584,3,75,19,0,0,430,430,0,-9250.90,158.82,37,5.5502,13,1,0,-1,1,0,0,0,nil,nil,nil

4/9 05:05:07.807 SWING_DAMAGE_LANDED,Player-1096-06DF65C1,"Xiaohuli-DefiasBrotherhood",0x511,0x0,Creature-0-4253-0-160-94-00006FB363,"Cutpurse",0x10a48,0x0,Creature-0-4253-0-160-94-00006FB363,0000000000000000,104,152,0,0,189,0,1,0,0,0,-9245.84,156.92,37,2.8016,30,1,0,-1,1,0,0,0,nil,nil,nil
</syntaxhighlight>

====SPELL_ENERGIZE====

- SPELL_ENERGIZE: This has an additional 4th suffix param, possibly <code>maxPower</code>
  11/18 20:44:41.889 SPELL_ENERGIZE,Player-3686-065B1FFB,"Withered-Antonidas",0x511,0x0,Player-3686-065B1FFB,"Withered-Antonidas",0x511,0x0,336637,"Grounding Breath",0x1,Player-3686-065B1FFB,0000000000000000,58296,58296,2246,2160,687,243,0,43673,50000,0,243.55,-868.29,2002,2.3365,248,1900.0000,0.0000,0,<font color="#ecbc2a">50000</font>

- SPELL_DRAIN: This has an additional 4th suffix param, possibly <code>maxPower</code>
  11/18 22:59:04.817 SPELL_DRAIN,Vehicle-0-1465-2450-15939-178072-000016CA7A,"Anduin Wrynn",0xa48,0x0,Vehicle-0-1465-2450-15939-178072-000016CA7A,"Anduin Wrynn",0xa48,0x0,357730,"Blasphemy",0x2,Vehicle-0-1465-2450-15939-178072-000016CA7A,0000000000000000,36198842,36339500,0,0,1071,0,0,0,2568,0,-246.06,-1280.08,2004,4.3350,62,5000,0,0,<font color="#ecbc2a">2568</font>

===ARENA_MATCH_START / END===
<syntaxhighlight lang="lua">
ARENA_MATCH_START: instanceID, unk, matchType, teamId
ARENA_MATCH_START,1505,0,Skirmish,0
</syntaxhighlight>
<syntaxhighlight lang="lua">
ARENA_MATCH_END: winningTeam, matchDuration, newRatingTeam1, newRatingTeam2
ARENA_MATCH_END,0,58,0,0
</syntaxhighlight>

===CHALLENGE_MODE_START / END===
CHALLENGE_MODE_START: zoneName, instanceID, [https://wow.tools/dbc/?dbc=mapchallengemode challengeModeID], keystoneLevel, [[https://wow.tools/dbc/?dbc=keystoneaffix affixID], ...]
CHALLENGE_MODE_START,"Mists of Tirna Scithe",2290,375,11,[9,122,4,121]

CHALLENGE_MODE_END: instanceID, success, keystoneLevel, totalTime

- <code>totalTime</code>: time in milliseconds, and including the time penalties for deaths

===EMOTE===
Emotes don't include a dest unit, compared to in-game events like {{api|t=e|CHAT_MSG_RAID_BOSS_EMOTE}}.
EMOTE: sourceGUID, sourcename, sourceflags, sourceraidflags, text
EMOTE,Vehicle-0-1465-2450-15939-175732-000016A7D7,"Sylvanas Windrunner",0000000000000000,nil,|TInterface\ICONS\Achievement_Leader_Sylvanas.blp:20|t Sylvanas Windrunner gains |cFFFF0000|Hspell:347504|h[Windrunner]|h|r!

===ENCOUNTER_START / END===
ENCOUNTER_START: [[DungeonEncounterID|encounterID]], encounterName, [[difficultyID]], groupSize, [[instanceID]]
ENCOUNTER_START,1146,"Randolph Moloch",1,5,34
<syntaxhighlight lang="lua">
ENCOUNTER_END: encounterID, encounterName, difficultyID, groupSize, success, fightTime
ENCOUNTER_END,2435,"Sylvanas Windrunner",15,16,1,671425
</syntaxhighlight>

- <code>success</code> is 1 for a kill, 0 for a wipe
- <code>fightTime</code> is in milliseconds.

===MAP_CHANGE===
The coords are the boundary box for the world map.
<syntaxhighlight lang="lua">
MAP_CHANGE: uiMapID, uiMapName, x0, x1, y0, y1
MAP_CHANGE,37,"Elwynn Forest",-7939.580078,-10254.200195,1535.420044,-1935.420044
</syntaxhighlight>
<syntaxhighlight lang="lua">
/dump C_Map.GetWorldPosFromMapPos(37, {x=0, y=0}) -- x = -7939.580078125, y = 1535.4200439453
/dump C_Map.GetWorldPosFromMapPos(37, {x=1, y=1}) -- x = -10254.200195312, y = -1935.4200439453
/dump C_Map.GetMapWorldSize(37) -- 3470.8400878906, 2314.6201171875
</syntaxhighlight>

===WORLD_MARKER_PLACED / REMOVED===
<syntaxhighlight lang="lua">
WORLD_MARKER_PLACED: instanceID, marker, x, y
WORLD_MARKER_PLACED,2450,2,269.82,-828.35
</syntaxhighlight>
<syntaxhighlight lang="lua">
WORLD_MARKER_REMOVED: marker
WORLD_MARKER_REMOVED,2
</syntaxhighlight>

===ZONE_CHANGE===
<syntaxhighlight lang="lua">
ZONE_CHANGE: instanceID, zoneName, difficultyID
ZONE_CHANGE,34,"Stormwind Stockade",1
</syntaxhighlight>

===COMBATANT_INFO===
This logging feature was added on patch 7.0.3

<div style="max-width:calc(150px + 50vw); margin-left:2vw">{{Bluepost|poster=Celestalon|date=2016-01-13|title=New Logging Feature: COMBATANT_INFO|link=https://blue.mmo-champion.com/topic/398157-new-logging-feature-combatant-info/|
body=<p>Whenever an ENCOUNTER_START event occurs, a new “COMBATANT_INFO” log line will also be printed for each player in the instance. The current data structure for COMBATANT_INFO is as follows, but is subject to change based on feedback and technical needs:

<syntaxhighlight lang="lua">COMBATANT_INFO,playerGUID,Strength,Agility,Stamina,Intelligence,Dodge,Parry,Block,CritMelee,CritRanged,CritSpell,Speed,Lifesteal,HasteMelee,HasteRanged,HasteSpell,Avoidance,Mastery,VersatilityDamageDone,VersatilityHealingDone,VersatilityDamageTaken,Armor,CurrentSpecID,(Class Talent 1, ...),(PvP Talent 1, ...),[Artifact Trait ID 1, Trait Effective Level 1, ...],[(Equipped Item ID 1,Equipped Item iLvL 1,(Permanent Enchant ID, Temp Enchant ID, On Use Spell Enchant ID),(Bonus List ID 1, ...),(Gem ID 1, Gem iLvL 1, ...)) ...],[Interesting Aura Caster GUID 1, Interesting Aura Spell ID 1, ...]</syntaxhighlight>

Some clarifications about a few of those elements:

- '''Stats''' – Those are the current stat values at the time of the log line. Secondary stats are in terms of the Rating amount, not a %.
- '''Armor''' – This is the Armor amount before multipliers (such as Bear Form).
- '''Talents''' – A list of the selected talents. Today’s build will print this ID as a TalentID, a record type that is not dataminable. This will be fixed in a future build to be the SpellID of the talent.
- '''Artifact Traits''' – This will be a list of the selected traits for the character’s current specialization’s artifact (even if it’s not equipped). The Artifact Trait ID is an ID to a new record type to 7.0, which should be dataminable already. Trait Effective Level is the number of points placed in that talent. Note that some Relics will allow this to go beyond the max.
- '''Equipment''' – This is a list of all equipped gear on the character. The first ID is the standard Item ID of the item, followed by its ilvl. After that is a list of enchants on the item, one of each of the 3 possible enchantment types (using the ItemEnchantment ID).
- '''Interesting Auras''' – This is a list of interesting auras (buffs/debuffs) that we have manually flagged to be included in this log line. We’ll welcome feedback about what should be included here but currently plan for set bonuses, well fed, flasks, combat potions, Vantus runes, and player buffs. Nothing has been flagged for this yet, so you won’t see anything here in the current build.
</p>}}</div>

On a character without any Shadowlands-specific powers.

: <syntaxhighlight lang="lua">4/22 05:27:15.478 COMBATANT_INFO,Player-3299-004E8630,1,132,184,906,653,0,0,0,257,257,257,11,0,188,188,188,0,118,90,90,90,120,257,(193155,64129,238136,200199,321377,193157,265202),(0,235587,215982,328530),[0,0,[],[],[]],[(173845,90,(),(1479,4786,6502),()),(158075,140,(),(4932,4933,6316),()),(157971,105,(),(1514,4786,6506),()),(3427,1,(),(),()),(157994,105,(),(1514,4786,6504),()),(173341,90,(0,0,4223),(6707),()),(174237,100,(),(4822,6516,6513,1487,4786),()),(173322,90,(),(6707),()),(158037,99,(),(4803,4802,42,6516,6515,1513,4786),()),(183675,110,(),(1482,4786),()),(173344,98,(),(6706),()),(174469,100,(),(4822,6516,6513,1487,4786),()),(173349,98,(),(6706),()),(175719,104,(),(6707,6901),()),(169223,133,(),(6276,1472),()),(165628,115,(),(5844,1527,4786),()),(0,0,(),(),()),(0,0,(),(),())],[Player-3299-004E8630,295365,Player-3299-004E8630,298268,Player-3299-004E8630,296320],1,0,0,0</syntaxhighlight>

{| class="sortable darktable zebra" style="margin-left: 2em"
! Param !! Example !! Description
|-
| Event || <code>COMBATANT_INFO</code> || Version 18
|-
| PlayerGUID || <code>Player-3299-004E8630</code> ||
|-
| Faction || <code>1</code> || 0: Horde, 1: Alliance
|-
! colspan="3" | Character Stats
|-
| Strength || <code>132</code> ||
|-
| Agility || <code>184</code> ||
|-
| Stamina || <code>906</code> ||
|-
| Intelligence || <code>653</code> ||
|-
| Dodge || <code>0</code> ||
|-
| Parry || <code>0</code> ||
|-
| Block || <code>0</code> ||
|-
| CritMelee || <code>257</code> ||
|-
| CritRanged || <code>257</code> ||
|-
| CritSpell || <code>257</code> ||
|-
| Speed || <code>11</code> ||
|-
| Lifesteal || <code>0</code> ||
|-
| HasteMelee || <code>188</code> ||
|-
| HasteRanged || <code>188</code> ||
|-
| HasteSpell || <code>188</code> ||
|-
| Avoidance || <code>0</code> ||
|-
| Mastery || <code>118</code> ||
|-
| VersatilityDamageDone || <code>90</code> ||
|-
| VersatilityHealingDone || <code>90</code> ||
|-
| VersatilityDamageTaken || <code>90</code> ||
|-
| Armor || <code>120</code> ||
|-
! colspan="3" | [[API GetTalentInfo|Class]] Talents
|-
| CurrentSpecID || <code>257</code> || [[SpecializationID|Holy]]
|-
| Class Talent 1 || <code>(193155</code> || [https://www.wowhead.com/spell=193155/enlightenment Enlightenment]
|-
| Class Talent 2 || <code>64129</code> || Body and Soul
|-
| Class Talent 3 || <code>238136</code> || Cosmic Ripple
|-
| Class Talent 4 || <code>200199</code> || Censure
|-
| Class Talent 5 || <code>321377</code> || Prayer Circle
|-
| Class Talent 6 || <code>193157</code> || Benediction
|-
| Class Talent 7 || <code>265202)</code> || Holy Word: Salvation
|-
! colspan="3" | [[API_GetPvpTalentInfoByID|PvP]] Talents
|-
| PvP Talent 1 || <code>(0</code> ||
|-
| PvP Talent 2 || <code>235587</code> || [https://www.wowhead.com/spell=235587/miracle-worker Miracle Worker]
|-
| PvP Talent 3 || <code>215982</code> || Spirit of the Redeemer
|-
| PvP Talent 4 || <code>328530)</code> || Divine Ascension
|-
! colspan="3" | [[World_of_Warcraft_API#Artifacts|Artifact]] Traits
|-
| <font color="#ecbc2a">Artifact Trait ID 1</font> || <code>[0</code> ||
|-
| <font color="#ecbc2a">Trait Effective Level 1</font> || <code>0</code> ||
|-
| Artifact Trait ID 2 || <code>[]</code> ||
|-
| Artifact Trait ID 3 || <code>[]</code> ||
|-
| Artifact Trait ID 4 || <code>[]]</code> ||
|-
! colspan="3" | [[InventorySlotId|Equipped]] Items
|-
| <font color="#ecbc2a">Equipped Item ID 1</font> || <code>[(173845</code> || [https://www.wowhead.com/item=173845/vile-manipulators-hood Vile Manipulator's Hood]
|-
| <font color="#ecbc2a">Equipped Item iLvL 1</font> || <code>90</code> ||
|-
| <font color="#ecbc2a">Permanent Enchant ID<br>Temp Enchant ID<br>On Use Spell Enchant ID</font> || <code>()</code> ||
|-
| <font color="#ecbc2a">Bonus List ID 1</font> || <code>(1479</code> ||
|-
| <font color="#ecbc2a">Bonus List ID 2</font> || <code>4786</code> ||
|-
| <font color="#ecbc2a">Bonus List ID 3</font> || <code>6502)</code> ||
|-
| <font color="#ecbc2a">Gem ID 1</font> || <code>())</code> ||
|-
| Equipped Item 2 || <code>(158075,140,(),(4932,4933,6316),())</code> || Heart of Azeroth
|-
| Equipped Item 3 || <code>(157971,105,(),(1514,4786,6506),())</code> || Sirensong Amice
|-
| Equipped Item 4 || <code>(3427,1,(),(),())</code> || Stylish Black Shirt
|-
| Equipped Item 5 || <code>(157994,105,(),(1514,4786,6504),())</code> || Sirensong Garments
|-
| Equipped Item 6 || <code>(173341,90,(0,0,4223),(6707),())</code> || Cord of Uncertain Devotion
|-
| Equipped Item 7 || <code>(174237,100,(),(4822,6516,6513,1487,4786)</code> || Breeches of Faithful Execution
|-
| Equipped Item 8 || <code>(173322,90,(),(6707),())</code> || Sandals of Soul's Clarity
|-
| Equipped Item 9 || <small><code>(158037,99,(),(4803,4802,42,6516,6515,1513,4786),())</code></small> || Squallshaper Cuffs
|-
| Equipped Item 10 || <code>(183675,110,(),(1482,4786),())</code> || Cold Sweat Mitts
|-
| Equipped Item 11 || <code>(173344,98,(),(6706),())</code> || Band of Chronicled Deeds
|-
| Equipped Item 12 || <small><code>(174469,100,(),(4822,6516,6513,1487,4786),())</code></small> || Band of Insidious Ruminations
|-
| Equipped Item 13 || <code>(173349,98,(),(6706),())</code> || Misfiring Centurion Controller
|-
| Equipped Item 14 || <code>(175719,104,(),(6707,6901),())</code> || Agthia's Void-Tinged Speartip
|-
| Equipped Item 15 || <code>(169223,133,(),(6276,1472),())</code> || Ashjra'kamas, Shroud of Resolve
|-
| Equipped Item 16 || <code>(165628,115,(),(5844,1527,4786),())</code> || Sentinel's Branch
|-
| Equipped Item 17 || <code>(0,0,(),(),())</code> ||
|-
| Equipped Item 18 || <code>(0,0,(),(),())]</code> ||
|-
! colspan="3" | Interesting Auras
|-
| <font color="#ecbc2a">Aura Caster GUID 1</font> || <code>[Player-3299-004E8630</code> ||
|-
| <font color="#ecbc2a">Aura Spell ID 1</font> || <code>295365</code> || [https://www.wowhead.com/spell=295365/ancient-flame Ancient Flame]
|-
| Aura 2 || <code>Player-3299-004E8630,298268</code> || Lucid Dreams
|-
| Aura 3 || <code>Player-3299-004E8630,296320]</code> || Strive for Perfection
|-
! colspan="3" | PvP Stats
|-
| Honor Level || <code>1</code> || {{api|UnitHonorLevel}}()
|-
| Season || <code>0</code> || Possibly only applicable in Arena
|-
| Rating || <code>0</code> ||
|-
| Tier || <code>0</code> ||
|}

On a character with Shadowlands-specific powers, the Artifact Trait part is replaced with:
: <syntaxhighlight lang="lua">[18,1,[(343203,335,1),(348511,1432,1),(333759,995,1),(295965,56,1),(315288,357,1),(313833,264,1),(333505,1002,1),(295068,49,1)],[(1379),(1380),(1381),(1408),(1410),(1414),(1416),(1418)],[(233,200),(231,213),(244,213),(230,213)]]</syntaxhighlight>

{| class="sortable darktable zebra" style="margin-left: 2em"
! Param !! Example !! Description
|-
| Soulbind ID || <code>[18</code> || [[API C Soulbinds.GetActiveSoulbindID|Forgelite Prime Mikanikos]]
|-
| Covenant ID || <code>1</code> || [[API C_Covenants.GetActiveCovenantID|Kyrian]]
|-
! colspan="3" | [[World_of_Warcraft_API#Anima|Anima]] Powers
|-
| <font color="#ecbc2a">Anima Spell ID 1</font> || <code>[(343203</code> || [https://www.wowhead.com/spell=343203/ringing-doom Ringing Doom]
|-
| <font color="#ecbc2a">Maw Power ID 1</font> || <code>335</code> || {{api|GetMawPowerLinkBySpellID}}()
|-
| <font color="#ecbc2a">Count 1</font> || <code>1)</code> ||
|-
| Anima Power 2 || <code>(348511,1432,1)</code> || Bloodgorged Leech
|-
| Anima Power 3 || <code>(333759,995,1)</code> || Leather Apron
|-
| Anima Power 4 || <code>(295965,56,1)</code> || Curious Miasma
|-
| Anima Power 5 || <code>(315288,357,1)</code> || Frostbite Wand
|-
| Anima Power 6 || <code>(313833,264,1)</code> || Shadowblade's Gift
|-
| Anima Power 7 || <code>(333505,1002,1)</code> || Rupturing Spike
|-
| Anima Power 8 || <code>(295068,49,1)]</code> || Abundance of Phantasma
|-
! colspan="3" | [[API C_Garrison.GetTalentInfo|Soulbind]] Traits
|-
| Soulbind Trait 1 || <code>[(1379)</code> || Finesse Conduit
|-
| Soulbind Trait 2 || <code>(1380)</code> || Endurance Conduit
|-
| Soulbind Trait 3 || <code>(1381)</code> || Potency Conduit
|-
| Soulbind Trait 4 || <code>(1408)</code> || Forgelite Filter
|-
| Soulbind Trait 5 || <code>(1410)</code> || Hammer of Genesis
|-
| Soulbind Trait 6 || <code>(1414)</code> || Endurance Conduit
|-
| Soulbind Trait 7 || <code>(1416)</code> || Regenerating Materials
|-
| Soulbind Trait 8 || <code>(1418)]</code> || Forgelite Prime's Expertise
|-
! colspan="3" | [[API_C_Soulbinds.GetConduitSpellID|Conduit]] Spells
|-
| <font color="#ecbc2a">Conduit ID 1</font> || <code>[(233</code> || [https://www.wowhead.com/spell=341531/quick-decisions Quick Decisions]
|-
| <font color="#ecbc2a">Conduit Level 1</font> || <code>200)</code> ||
|-
| Conduit 2 || <code>(231,213)</code> || [https://www.wowhead.com/spell=341312/recuperator Recuperator]
|-
| Conduit 3 || <code>(244,213)</code> || [https://www.wowhead.com/spell=341546/count-the-odds Count the Odds]
|-
| Conduit 4 || <code>(230,213)]]</code> || [https://www.wowhead.com/spell=341311/nimble-fingers Nimble Fingers]
|}

==Event Descriptions==
===Prefixes===
{| class="darktable zebra"
|-
! Event Prefix
! Description
|-
| SPELL*
| Spell is the prefix for most effects even if the spell is a DoT or channeled. IE when the spell begins to be cast, SPELL_CAST_START is fired and not SPELL_PERIODIC_CAST_START. This is the same with \_MISS, \_FAILED, etc.
|-
| SPELL_PERIODIC
| Only the effects that are periodic start with this PREFIX. IE: Successfully casting a DoT only happens once therefore even though the spell is periodic use the SPELL* prefix. However, the damage is periodic so it will start with SPELL*PERIODIC*. 90% of the time you will only care about \_DAMAGE or \_HEAL.
|-
| SPELL_BUILDING
| {{Wotlk-inline}} damage or healing that can affect destructable buildings.
|-
| ENVIRONMENTAL
|
|}

===Suffixes===
{| class="darktable zebra"
|-
! Event Suffix !! Description
|-
| \_DAMAGE || Triggered on damage to health. Nothing Special. (overkill returns a number greater than or equal to zero)
|-
| \_MISSED || Triggered When Effect isn't applied but mana/energy is used IE: ABSORB BLOCK DEFLECT DODGE EVADE IMMUNE MISS PARRY REFLECT RESIST
|-
| \_HEAL || Triggered when a unit is healed
|-
| \_HEAL_ABSORBED || Triggered when a spell absorbs the healing done by another spell. Extra info is provided for the healer and the heal spell, as well as the amount absorbed.
|-
| \_ENERGIZE || Any effect that restores power. Spell/trinket/item set bonuses can trigger this event. IE: Vampiric Touch, or Mark of Defiance (Trinket)
|-
| \_DRAIN || Same as \_ENERGIZE but this time you are losing power. Caused by enemies.
|-
| \_LEECH || Same as \_DRAIN, but the source unit will simultaneously receive the same kind of power (specified in ''extraAmount'')
|-
| \_INTERRUPT || Spellcasting being interrupted by an ability such as Kick or Pummel.
|-
| \_DISPEL || A buff or debuff being actively dispelled by a spell like Remove Curse or Dispel Magic. The source is the caster of the aura that was dispelled, and the destination is the target which was dispelled (needs verifying).
|-
| \_DISPEL_FAILED || A failed attempt to dispel a buff or debuff, most likely due to immunity.
|-
| \_STOLEN || A buff being transferred from the destination unit to the source unit (i.e. mages' Spellsteal).
|-
| \_EXTRA_ATTACKS || Unit gains extra melee attacks due to an ability (like Sword Sepcialization or Windfury). These attacks usually happen in brief succession 100-200ms following this event.
|-
| \_AURA_APPLIED || Triggered When Buffs/Debuffs are Applied. Note: This event doesn't fire if a debuff is applied twice without being removed. IE: casting Vampiric Embrace twice in a row only triggers this event once. This can make it difficult to track whether a debuff was successfully reapplied to the target. However, for instant cast spells, SPELL_CAST_SUCCESS can be used.
|-
| \_AURA_REMOVED || Triggered When Buffs/Debuffs expire. The souce is the caster of the aura which faded, and the destination is the target from which the aura faded (needs verifying).
|-
| \_AURA_APPLIED_DOSE || Triggered by stacking Debuffs if the debuff is already applied to a target. IE: If you cast Mind Flay twice it causes 2 doses of shadow vunerability, the first time it will trigger, SPELL_AURA_APPLIED (arg10 = shadow vulnerability), and SPELL_AURA_APPLIED_DOSE (arg10 = shadow vunerability) the second. The last argument reflects the new number of doses on the unit.
|-
| \_AURA_REMOVED_DOSE || The opposite of \_AURA_APPLIED_DOSE, reducing the amount of doses on a buff/debuff on the unit.
|-
| \_AURA_REFRESH || Resets the expiration timer of a buff/debuff on the unit.
|-
| \_AURA_BROKEN || A buff or debuff is being removed by melee damage. The source is the name of the caster of the aura that was broken, and the destination is the target which the aura broke off of (needs verifying).
|-
| \_AURA_BROKEN_SPELL || A buff or debuff is being removed by spell damage (specified in ''extraSpell...''). Source and destination is the same as the above.
|-
| \_CAST_START || Triggered when a spell begins casting. Instant spells don't invoke this event. They trigger \_CAST_SUCCESS, \_FAILED instead.
|-
| \_CAST_SUCCESS || Triggered when an instant spell is cast or when a spellcast finishes and doesn't fail. This isn't triggered when the spell misses. On a miss SPELL_MISS will be triggered instead.
|-
| \_CAST_FAILED || If the cast fails before it starts (IE invalid target), then \_CAST_START never triggers. However it is possible for a cast to fail after beginning. (IE you jump, move, hit escape etc.)
|-
| \_INSTAKILL || Immediately kills the destination unit (usually happens when warlocks sacrifice their minions).
|-
| \_DURABILITY_DAMAGE ||
|-
| \_DURABILITY_DAMAGE_ALL ||
|-
| \_CREATE || Creates an object (as opposed to an NPC who are 'summoned') like a hunter's trap or a mage's portal.
|-
| \_SUMMON || Summmons an NPC such as a pet or totem.
|-
| \_DISSIPATES || Fires when Gas Clouds are being extracted with [http://www.wowhead.com/item=23821 Zapthrottle Mote Extractor]
|}

===Special Events===
{| class="darktable zebra"
|-
! Event !! Description
|-
| UNIT_DIED || destGUID and destName refer to the unit that died.
|-
| PARTY_KILL || includes both sourceGUID and destGUID, but only reports for you (not in a party) or your other 4 party members (not raid members)
|}

==Patch changes==
====<font color="#4ec9b0">Retail</font>====
{{Patch 9.2.0|note=Added Cosmic spell school.}}
{{Patch 9.0.1|note=Chromatic was changed from 124 to 62, possibly in a previous patch.<sup>[https://github.com/Gethe/wow-ui-source/blame/9.2.0/Interface/AddOns/Blizzard_APIDocumentation/DamageConstantsDocumentation.lua#L56]</sup>}}
{{Patch 8.0.1|note=COMBAT_LOG_EVENT and CLEU no longer have any payload, which is now returned by {{api|CombatLogGetCurrentEventInfo}}(). The payload itself is unchanged. <ref>{{ref web|url=https://us.battle.net/forums/en/wow/topic/20762318007|author=[[Ythisens]]|date=2018-04-24 16:45|title=Combat Log Event Changes}}</ref>}}
{{Patch 6.1.0|note=Additional parameters: recapID is added to UNIT_DIED; and unconsciousOnDeath is added to UNIT_DIED, UNIT_DESTROYED and UNIT_DISSIPATES.<ref>{{ref FrameXML|Blizzard_CombatLog/Blizzard_CombatLog.lua|8.1.5||2684|}}</ref>}}
{{Patch 5.0.4|note=The environmental types are now a non-localized, proper-case strings instead of capitalized ones (e.g. "Falling" instead "FALLING").}}
{{Patch 4.2.0|note=Added two new parameters, [[raidFlag|sourceRaidFlags]] and [[raidFlag|destRaidFlags]], after sourceFlags and destFlags respectively.}}
{{Patch 4.1.0|note=Added hideCaster, after the event param.}}
{{Patch 2.4.0|note=Reworked to support filters and the terse format. <ref>{{ref web|url=https://blue.mmo-champion.com/topic/86577-05-02-240-guide-to-the-new-combat-log/|author=[[Slouken]]|date=2008-02-05|title=2.4.0 Guide to the New Combat Log}}</ref>}}

====<font color="#4ec9b0">Classic</font>====
{{Patch 2.5.1|note=The spellId parameter is provided again in [[Burning Crusade Classic]].}}
{{Hotfix|date=2020-06-22|classic=|doc=|link=https://us.forums.blizzard.com/en/wow/t/wow-classic-hotfixes-updated-september-14/361448|note=The Combat Log is no longer restricted for dungeons and raids. The open world remains restricted to 50 yards.}}
{{Hotfix|date=2019-11-20|classic=|doc=|link=https://us.forums.blizzard.com/en/wow/t/in-game-combat-log-range-decreased/370390|note=The Combat Log is restricted to events within 50 yards of the player. (Build 32600)}}
{{Patch 1.13.2|note=The spellId parameter is defunct in vanilla, returning <code>0</code> to resemble the pre-2.4.0 combat log.}}

==References==
{{Reflist}}
