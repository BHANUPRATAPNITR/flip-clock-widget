import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config.dart';
import '../../core/logger.dart';
import '../../services/storage.dart';
import '../../services/window.dart';

/// [SettingsNotifier] manages the application's configuration, user preferences,
/// local JSON persistence, and autostart capabilities as a Riverpod [Notifier].
///
/// It holds an immutable [AppConfig] state instance and triggers UI rebuilds on changes.
class SettingsNotifier extends Notifier<AppConfig> {
  @override
  AppConfig build() {
    // Initial state setup is loaded from JSON storage
    final config = StorageService.loadConfig();
    _syncWindowSettings(config.alwaysOnBottom);
    return config;
  }

  /// Synchronizes window-level behaviors with the desktop environment.
  void _syncWindowSettings(bool alwaysOnBottom) {
    WindowService.setAlwaysOnBottom(alwaysOnBottom);
  }

  /// Helper method to commit state mutations to persistent JSON storage and trigger provider updates.
  void _updateState(AppConfig newConfig) {
    state = newConfig;
    StorageService.saveConfig(state);
  }

  /// Helper method to duplicate the mutable config instance via JSON serialization.
  AppConfig _copyConfig() {
    return AppConfig.fromJson(state.toJson());
  }

  /// Switches active modes (clock, stopwatch, timer).
  void switchMode(String newMode) {
    if (state.mode == newMode) return;
    final newConfig = _copyConfig();
    newConfig.mode = newMode;
    AppLogger.info("Switching widget mode to: $newMode");
    _updateState(newConfig);
  }

  /// Toggles whether the desktop widget is locked in place.
  void setLocked(bool val) {
    final newConfig = _copyConfig();
    newConfig.locked = val;
    AppLogger.info("Locked toggled to: $val");
    _updateState(newConfig);
  }

  /// Sets the display time format (true: 24h format, false: 12h format).
  void setUse24h(bool val) {
    final newConfig = _copyConfig();
    newConfig.use24h = val;
    AppLogger.info("24-hour format toggled to: $val");
    _updateState(newConfig);
  }

  /// Controls the visibility of seconds in Clock mode.
  void setShowSeconds(bool val) {
    final newConfig = _copyConfig();
    newConfig.showSeconds = val;
    AppLogger.info("Seconds visibility toggled to: $val");
    _updateState(newConfig);
  }

  /// Configures application autostart on system login.
  void setAutostart(bool val) {
    final newConfig = _copyConfig();
    newConfig.autostart = val;
    AppLogger.info("Autostart toggled to: $val");
    
    final autostartDir = Directory('${Platform.environment['HOME']}/.config/autostart');
    final autostartFile = File('${autostartDir.path}/flip-clock-flutter.desktop');
    
    if (val) {
      try {
        if (!autostartDir.existsSync()) {
          autostartDir.createSync(recursive: true);
        }
        final exePath = Platform.resolvedExecutable;
        final content = '''[Desktop Entry]
Type=Application
Exec=$exePath
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Flip Clock Flutter Widget
Comment=Starts the transparent flip clock flutter widget at login
''';
        autostartFile.writeAsStringSync(content);
        Process.runSync('chmod', ['+x', autostartFile.path]);
        AppLogger.info("Desktop autostart entry enabled successfully.");
      } catch (e) {
        AppLogger.error("Error creating autostart desktop entry: $e");
      }
    } else {
      try {
        if (autostartFile.existsSync()) {
          autostartFile.deleteSync();
          AppLogger.info("Desktop autostart entry disabled successfully.");
        }
      } catch (e) {
        AppLogger.error("Error removing autostart desktop entry: $e");
      }
    }
    
    _updateState(newConfig);
  }

  /// Toggles whether the widget stays layered behind other windows.
  void setAlwaysOnBottom(bool val) {
    final newConfig = _copyConfig();
    newConfig.alwaysOnBottom = val;
    WindowService.setAlwaysOnBottom(val);
    AppLogger.info("Always-on-bottom toggled to: $val");
    _updateState(newConfig);
  }

  /// Updates current timing labels.
  void updateLabel(String text) {
    if (state.label == text) return;
    final newConfig = _copyConfig();
    newConfig.label = text;
    _updateState(newConfig);
  }

  /// Sets visual glassmorphic theme IDs.
  void setTheme(String themeId) {
    final newConfig = _copyConfig();
    newConfig.theme = themeId;
    AppLogger.info("Theme updated to: $themeId");
    _updateState(newConfig);
  }

  /// Sets flip card skins.
  void setSkin(String skinId) {
    final newConfig = _copyConfig();
    newConfig.skin = skinId;
    AppLogger.info("Skin updated to: $skinId");
    _updateState(newConfig);
  }

  /// Adjusts global layout render scales.
  void setScale(double val) {
    final newConfig = _copyConfig();
    newConfig.scale = val;
    AppLogger.info("Scale updated to: $val");
    _updateState(newConfig);
  }

  /// Appends a new stopwatch record to history configurations.
  void saveHistoryEntry(StopwatchHistoryEntry entry) {
    final newConfig = _copyConfig();
    newConfig.stopwatchHistory.insert(0, entry);
    if (newConfig.stopwatchHistory.length > 50) {
      newConfig.stopwatchHistory.removeLast();
    }
    _updateState(newConfig);
  }

  /// Removes a stopwatch log entry by index.
  void deleteHistoryEntry(int index) {
    if (index >= 0 && index < state.stopwatchHistory.length) {
      final newConfig = _copyConfig();
      newConfig.stopwatchHistory.removeAt(index);
      _updateState(newConfig);
    }
  }

  /// Deletes all history entries in logs configuration.
  void clearHistory() {
    final newConfig = _copyConfig();
    newConfig.stopwatchHistory.clear();
    _updateState(newConfig);
  }
}
