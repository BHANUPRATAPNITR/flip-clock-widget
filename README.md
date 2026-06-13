# Flip Clock Desktop Widget (Flutter Migration)

A native Flutter desktop implementation of the Linux Mint Flip Clock desktop widget, migrated from Python/GTK3/WebKit. This migration reduces the memory footprint from **~448 MB to under 180 MB** (achieving >60% RAM savings) while delivering smooth 3D perspective flip animations and high-performance glassmorphic designs.

## Features

- **Three Modes**: Clock (12h/24h formats), Stopwatch (with session records and visual log list), and Countdown Timer.
- **Glassmorphic Themes**: 7 preset color themes including Sleek Dark, Mint Green, Cyberpunk Yellow, Cyber Neon, Sakura Pink, Forest Green, and Retro Amber.
- **Card Skins**: Retro Flip, Hologram, Nixie Glow, and Minimal.
- **Interactive Adjusters**: Symmetrical vertical sliders and mouse wheel scroll support to modify timer duration when paused.
- **Multi-Window Sync**: A separate standalone History window launched with `--history` synced bidirectionally via file watches on `config.json`.
- **Desktop System Settings**: Lock position, always-on-bottom layering, and "Start on Login" autostart configuration.

## File Structure

```
flip_clock_flutter/
├── lib/
│   ├── main.dart             # Application entry point & screen routing
│   ├── core/
│   │   ├── config.dart       # Configuration & settings models
│   │   ├── logger.dart       # Logging service to ~/.config/flip-clock/widget.log
│   │   └── theme.dart        # Custom glassmorphic theme definitions
│   ├── services/
│   │   ├── storage.dart      # Local JSON persistence with schema backwards-compatibility
│   │   └── window.dart       # Borderless, drag, resize, and always-on-bottom window wrappers
│   ├── state/
│   │   └── clock_state.dart  # ChangeNotifier state controller (modes, timers, stopwatch)
│   ├── widgets/
│   │   ├── flip_card.dart    # Digits layout groups with scroll listener
│   │   ├── flip_digit.dart   # 3D mechanical card folding & perspective transforms
│   │   ├── settings_panel.dart # Visual settings overlay panel
│   │   ├── vertical_slider.dart # Symmetrical drag sliders for timer mode
│   │   └── window_controls.dart # macOS style borderless window controls
│   └── screens/
│       ├── main_view.dart    # Main dashboard UI
│       └── history_view.dart # Standalone analytics history window (bar chart)
└── pubspec.yaml              # Dependencies (window_manager, google_fonts, intl)
```

## Running the Application

### 1. Compile the Release Build
To compile the release bundle:
```bash
flutter build linux
```

### 2. Run the Main Widget
Launch the borderless, transparent desktop widget:
```bash
./build/linux/x64/release/bundle/flip_clock_flutter
```

### 3. Run the Standalone History Window
Launch the standalone history session analytics window:
```bash
./build/linux/x64/release/bundle/flip_clock_flutter --history
```

## Logs and Configuration Paths

- **Widget log file**: `~/.config/flip-clock/widget.log`
- **Configuration JSON file**: `~/.config/flip-clock/config.json`
- **Autostart desktop entry**: `~/.config/autostart/flip-clock-flutter.desktop`

