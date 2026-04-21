<p align="center">
  <a href="https://chronicleclassic.com">
    <img src="assets/ChronicleLogoCenter.svg" alt="ChronicleClassic.com" width="400" />
  </a>
</p>

# ChronicleCompanion

> _Every raid tells a story. Chronicle helps you read it._

The official companion addon for **[ChronicleClassic.com](https://chronicleclassic.com)** — created and maintained by the Chronicle team. ChronicleCompanion enriches your combat logs with extended unit metadata so Chronicle can transform them into clear, actionable insights for raid leaders.

Upload your logs at **[chronicleclassic.com](https://chronicleclassic.com)**.

## Features

- **Extended Unit Tracking** — Automatically logs unit GUIDs, names, levels, owners (for pets/minions), and buff information to your combat log
- **Challenge Mode Detection** — Detects and logs player challenge modes (Hardcore, Level One Lunatic, Exhaustion, etc.)

## Requirements

- [Nampower](https://gitea.com/avitasia/nampower)

## Installation

1. Download the latest release
2. Extract to your `Interface/AddOns/` folder
3. Ensure the folder is named `ChronicleCompanion`
4. Restart WoW

## Usage

### On Raid Night

**Optional:** Configure the addon with `/chronicle config`

#### 1. Prepare the logs

Type `/chron delete` to delete any existing logs.

#### 2. Do your raid

#### 3. Save your logs

Type `/chron save` to save the logs to disk.

#### 4. Upload the file

Upload `<TurtleWoWFolder>/Imports/Chronicle_<character_name>.txt` to **[ChronicleClassic.com](https://chronicleclassic.com)**.

### Slash Commands

| Command             | Description                 |
| ------------------- | --------------------------- |
| `/chronicle help`   | Show all available commands |
| `/chronicle config` | Open the options panel      |
| `/chron delete`     | Delete existing logs        |
| `/chron save`       | Save logs to disk           |

You can also use `/chron` as a shorthand for `/chronicle`.

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

## License

[MIT](LICENSE)

## Author

**Emyrk** · Creator of [ChronicleClassic.com](https://chronicleclassic.com)

---

_ChronicleCompanion is the official addon for [ChronicleClassic.com](https://chronicleclassic.com) — every raid tells a story._ 📜
