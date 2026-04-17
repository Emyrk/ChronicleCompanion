# COMBATANT_TALENTS Log Format

## Line Format

```
timestamp|COMBATANT_TALENTS|guid|playerName|tab1|tab2|tab3
```

Each `tab` field is semicolon-delimited:

```
TabName;pointsSpent;rankDigits
```

| Field        | Description                                                    |
|--------------|----------------------------------------------------------------|
| TabName      | Talent tree name (e.g., `Discipline`, `Holy`, `Shadow`)        |
| pointsSpent  | Total talent points spent in this tree                         |
| rankDigits   | One digit per talent, in talent index order (0 = unlearned)    |

## Example

```
1713312000000|COMBATANT_TALENTS|0x00000000001A2B3C|Priests|Discipline;14;00503001500001|Holy;21;05230010500501|Shadow;0;00000000000000000
```

Breaking down the first tab:

- **TabName**: `Discipline`
- **pointsSpent**: `14`
- **rankDigits**: `00503001500001`
  - Talent index 1: 0 points
  - Talent index 2: 0 points
  - Talent index 3: 5 points (of some max)
  - Talent index 4: 0 points
  - Talent index 5: 3 points
  - ... and so on

## Parsing

1. Split the log line by `|` to get fields
2. Field 0 = timestamp (ms unix), field 1 = `COMBATANT_TALENTS`, field 2 = guid, field 3 = player name
3. Fields 4, 5, 6 are the three talent tabs
4. Split each tab field by `;` → `[tabName, pointsSpent, rankDigits]`
5. Each character in `rankDigits` is the current rank for that talent index (starting at index 1)

### Pseudocode

```python
parts = line.split("|")
timestamp = int(parts[0])
guid = parts[2]
player = parts[3]

for i, tab in enumerate(parts[4:7]):
    name, points_spent, rank_digits = tab.split(";")
    for talent_index, ch in enumerate(rank_digits, start=1):
        current_rank = int(ch)
        # talent_index corresponds to the talent's position in the tree
        # (ordered by tier top-to-bottom, then column left-to-right)
```

## Reconstructing the Talent Tree

The `rankDigits` order matches the game's internal talent index order for that tree,
which is ordered by tier (top to bottom), then by column (left to right) within each tier.

To fully reconstruct the tree visually, you need a talent definition table for each
class that maps `(tree, index)` → `(name, tier, column, maxRank, icon)`. These
definitions are static per class and don't change.

Given the player's class (from the `COMBATANT_INFO` line) and the `rankDigits`, you
can look up each talent and place it in the correct grid position with its allocated points.

## Related Log Events


- **`COMBATANT_INFO`** — contains player class, gear, and a compact talent string
  (`tree1}tree2}tree3` rank digits only, no tab names). Written when a player is first
  seen and again after talents are inspected.
- **`COMBATANT_TALENTS`** — the detailed format described here, with tab names and
  points spent. Written once per successful talent inspection.
