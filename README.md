# Flip Clock Widget

A sleek, highly customizable desktop widget for Linux, combining a premium aesthetic flip clock, stopwatch, countdown timer, visual settings UI, and detailed stopwatch analytics. Written in Python 3 using PyGObject (Gtk+ 3) and WebKit2GTK for a high-performance transparent glassmorphic UI.

---

## Key Features

- **Clock Mode**: Displays current time with optional smooth 3D flip card animations, customizable 12h/24h formats, and a clean date banner.
- **Stopwatch Mode**: Standard stopwatch timing with capability to record/save session logs under custom labels.
- **Separate Analytics Window**: A secondary standalone history window displaying a sleek SVG bar chart for stopwatch logs, plus a detailed list-view side panel.
- **Countdown Timer Mode**: Vertically drag the interactive card sliders or scroll the mouse wheel to set durations, with preset buttons for quick timing (1m, 5m, 15m, 25m, 60m).
- **Settings Overlay**: A glassmorphic overlay panel directly inside the clock widget to customize time format, seconds, autostart, positioning lock, theme colors, and card skins.
- **Expanded Theme Library**: Choose between 7 themes: Sleek Dark, Mint Green, Cyber Neon, Retro Amber, Sakura Pink, Forest Green, and Cyberpunk Yellow.
- **Visual Card Skins**: Select from 4 visual styles:
  - `Retro Flip`: Classic matte flip card with split divider.
  - `Cyber Hologram`: Glowing transparent borders with futuristic digital letters.
  - `Nixie Glow`: Amber glass bulb filaments matching retro nixie indicators.
  - `Minimal Flat`: Flat borderless shapes that match the active theme color directly.
- **GTK Right-Click Context Menu**: Fully functional native GTK context menu containing settings, themes, and skins for keyboard-only or mouse layouts (bidirectionally synced with the Settings Overlay).
- **Diagnostics Logger**: A unified logging system routing all Python events and JavaScript errors to `widget.log` for fast debugging.

---

## Installation & Setup

Ensure you are running a Linux distribution with GTK3 and WebKit2GTK installed.

### Dependencies Installation (Debian/Ubuntu/Fedora)

For Debian/Ubuntu:
```bash
sudo apt update
sudo apt install python3 python3-gi python3-gi-cairo gir1.2-gtk-3.0 gir1.2-webkit2-4.1 libgirepository1.0-dev
```

For Fedora/RHEL:
```bash
sudo dnf install python3 python3-gobject gtk3 webkit2gtk4.1
```

---

## Running the Widget

To launch the widget, execute the main script:
```bash
python3 main.py
```

### Automated Benchmark Mode
Run the built-in automated test suite to cycle through clock, stopwatch, countdown timer modes, resize bounds, and settings changes:
```bash
python3 main.py --benchmark
# OR run the standalone benchmark metrics wrapper
python3 benchmark.py
```

---

## Interactions & Controls

### Mouse Bindings
- **Drag to Move**: Click and drag the widget's background or hold the **Super (Windows) key** and drag to position the widget anywhere on your desktop.
- **Scroll Wheel**: Scroll over the Hours, Minutes, or Seconds flip groups in countdown mode (when paused) to manually adjust time.
- **Timer Sliders**: Drag the vertical slider knobs next to digit groups to set countdown durations.
- **Window Control**: A window toolbar appears in the top-right corner on hover, allowing you to Minimize, Maximize, or Close the widget.
- **Right-Click**: Opens the native GTK Context Menu containing mode switches, preferences, themes, scale size adjustments, autostart toggle, and quit widget commands.

### Settings UI Overlay
- Click the **Gear icon** in the timer controls bar (visible on hover in clock mode, or always visible in stopwatch/timer modes) to bring up the Settings panel.
- Preferences toggled here are immediately saved to `config.json` and persist across widget restarts.

---

## Diagnostics & Troubleshooting

All widget events, layout resizing requests, background actions, and frontend JavaScript logs/errors are routed to the central log file in the project directory:
```bash
tail -f widget.log
```

If the widget has composite rendering issues (e.g. background transparency shows black rectangles), verify that your desktop environment has a compositor running (like Picom, Compton, or GNOME/KDE built-in compositing).
