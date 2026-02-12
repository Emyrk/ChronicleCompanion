# ChronicleCompanion

A World of Warcraft addon that enhances combat logging with additional unit metadata for use with [Chronicle](https://github.com/Emyrk/chronicle).

Upload your enriched combat logs at [chronicleclassic.com](https://chronicleclassic.com).

## Features

- **Extended Unit Tracking** — Automatically logs unit GUIDs, names, levels, owners (for pets/minions), and buff information to your combat log
- **Challenge Mode Detection** — Detects and logs player challenge modes (Hardcore, Level One Lunatic, Exhaustion, etc.)

## Requirements

- [SuperWoW](https://github.com/balakethelock/SuperWoW) — Required for extended API functions

## Installation

1. Download the latest release
2. Extract to your `Interface/AddOns/` folder
3. Ensure the folder is named `ChronicleCompanion`
4. **If you have SuperWowCombatLogger installed, disable or remove it** — ChronicleCompanion now includes this functionality built-in
5. Restart WoW

## Usage

ChronicleCompanion works automatically when combat logging is enabled. It intercepts combat log events and enriches them with additional unit metadata.

### Slash Commands

| Command           | Description                 |
| ----------------- | --------------------------- |
| `/chronicle help` | Show all available commands |

You can also use `/chron` as a shorthand.

## Localization

Currently supports English (`enUS`) for challenge mode detection. Contributions for other locales are welcome! See `units.lua` for the `CHALLENGE_SPELLS` table.

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

## Acknowledgments

This addon includes an embedded version of [SuperWowCombatLogger](https://github.com/pepopo978/SuperWowCombatLogger) by **Shino/pepopo978**. Their work on combat log enhancements made this addon possible. Thank you!

## License

[MIT](LICENSE)

## Author

**Emyrk**

---

_Made for [Chronicle](https://chronicleclassic.com)_ 📜
