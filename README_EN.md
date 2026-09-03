<p align="center">
  <img src="assets/quotty.png" width="80" height="80" alt="Quotty Logo" />
</p>

# Quotty (macOS)

<p align="center">
  <b><a href="README.md">🇷🇺 Русский</a></b> | <b><a href="README_EN.md">🇬🇧 English</a></b>
</p>

> 💡 **Native macOS port of [Quotty](https://github.com/confeden/Quotty) written in Swift (SwiftUI + AppKit).**  
> Original project for Windows by: **[@confeden](https://github.com/confeden)** ([Telegram](https://t.me/nova_txt)).

An interactive, movable HUD strip showing the quota and reset timers for **Claude / Codex / Antigravity** on macOS — showing not only your current quota consumption, but also how fast you are spending it.

<img width="700" height="194" alt="quotty_demo" src="https://github.com/user-attachments/assets/4adfc8f7-5468-435d-bb2c-ce5a4624582a" />

A sleek floating strip on top of all windows: shows remaining quota of the AI tool you are currently using, and when the quota window resets.

The strip automatically switches to whichever tool's window was focused last.
Supports three tool families:

- **Antigravity** — Antigravity 2.0, Antigravity IDE and CLI (`agy`);
- **Codex** — Codex / ChatGPT desktop app and Codex CLI;
- **Claude** — Claude Desktop app and Claude Code / CLI.

---

## Features

- **Separate row for each quota window** (from 5 hours to monthly — whatever the service provides).
- **Usage bar with a white time marker**: see at a glance whether you are spending faster or slower than time elapsed:
  - 🟢 **green** — spending with buffer; rising bubbles emerge from the spend edge;
  - 🟡 **yellow** — spending faster than time elapsed (overspend alert);
  - 🟠 **orange** — quota fully depleted (100%).
- **Accurate reset countdown** and exact rollover timestamp.
- **Auto-switching by active window** — including CLI tools running in terminal emulators (Terminal, iTerm2, Alacritty, Warp, Ghostty, Kitty, VS Code, Cursor).
- **macOS Menu Bar item** with quick tool switching, refresh, and settings.
- **Customizable appearance**: opacity slider (with 50%, 80%, 100% presets), header mode (Environment + Plan / Family only / Hidden).
- **Does not clutter the Dock** (`LSUIElement` accessory app).
- **Controls**: Drag with Left-Click anywhere, context menu & settings with Right-Click or from the Menu Bar.

---

## Privacy

- **No telemetry.** No analytics, no counters, no usage statistics.
- **No ads.** No banners, affiliate links, or trackers.
- **No third-party servers.** The application only talks directly to the official APIs of the services (Anthropic, OpenAI) and to Antigravity's local language server on `127.0.0.1`.
- Tokens are read locally from the existing configs of installed tools and sent only to their respective services. Quotty never writes to other tools' files or modifies tokens.
- Settings are stored locally in `~/Library/Application Support/Quotty/settings.json`.

---

## Where the Data Comes From

| Tool | Source |
|---|---|
| **Antigravity** | Local Antigravity language server — the same RPC called by the usage panel in the IDE |
| **Codex** | `~/.codex/auth.json` (shared between app and CLI) → Codex usage endpoint |
| **Claude** | Local Claude Desktop / CLI token → official account usage endpoint |

If a tool is not installed or not running, its row gracefully reports unavailable while others continue working.

---

## Installation

### Pre-built Application
1. Download **`Quotty-macOS.zip`** from the [Releases](https://github.com/YOUR_USERNAME/Quotty-macOS/releases) page.
2. Unzip and drag `Quotty.app` to your **`/Applications`** folder.
3. Launch it. On first launch, macOS Gatekeeper may ask for confirmation to open.

---

## How to Use

- **Left-Click & Drag on the strip** — move it anywhere on screen (position is automatically saved).
- **Right-Click on the strip** — context menu for quick switching, opacity, and settings.
- **Menu Bar Icon** — click for status overview and full controls.

---

## Requirements

- macOS 13.0 (Ventura) or newer (Apple Silicon M1/M2/M3/M4 or Intel).
- An installed AI tool: Antigravity, Codex CLI / app, Claude Desktop.
- For Antigravity — a running Antigravity IDE or app (the quota lives in its local language server).

---

## Building from Source

Requires the Swift compiler (included with Xcode or Command Line Tools: `xcode-select --install`):

```bash
git clone https://github.com/YOUR_USERNAME/Quotty-macOS.git
cd Quotty-macOS
./scripts/build_app.sh
```

The built `Quotty.app` bundle will appear in the repository root.

---

## Created with ❤️

- 💡 Original concept, design and Windows version: **[@confeden](https://github.com/confeden)**
- 🙋 Author's Telegram group: **[@nova_txt](https://t.me/nova_txt)**
- ☕ [Donate to the original author](https://nova-app.eu/donate)
- 🍏 Native macOS port: **SwiftUI + AppKit**
