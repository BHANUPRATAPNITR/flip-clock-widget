import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/config.dart';
import '../../core/logger.dart';
import '../../services/storage.dart';
import '../../services/window.dart';

/// [SettingsController] manages the application's configuration, user preferences,
/// local JSON persistence, and integration with external OS-level services (like autostart).
///
/// It extends [ChangeNotifier] so that widgets and coordinators can listen for settings changes
/// (such as theme swaps, layout locks, and scale modifications) and rebuild accordingly.
class SettingsController extends ChangeNotifier {
  /// The local configuration configuration model holding values for theme, skin, size scale,
  /// widget position, mode, stopwatch history, etc.
  late AppConfig _config;

  /// Constructor initializes the settings by loading existing configurations from storage,
  /// and synchronizing window layering properties based on loaded config.
  SettingsController() {
    _config = StorageService.loadConfig();
    _syncWindowSettings();
  }

  /// Exposes the active application configuration config as a read-only getter.
  AppConfig get config => _config;

  /// Synchronizes window-level behaviors with the desktop environment.
  /// Sets always-on-bottom layer properties as configured in settings.
  void _syncWindowSettings() {
    WindowService.setAlwaysOnBottom(_config.alwaysOnBottom);
  }

  /// Switches the active display mode (e.g. clock, stopwatch, timer)
  /// and persists the update to local config JSON.
  void switchMode(String newMode) {
    if (_config.mode == newMode) return;
    _config.mode = newMode;
    StorageService.saveConfig(_config);
    AppLogger.info("Switching widget mode to: $newMode");
    notifyListeners();
  }

  /// Toggles whether the desktop widget is locked in place.
  /// When locked, background dragging is disabled in the UI.
  void setLocked(bool val) {
    _config.locked = val;
    StorageService.saveConfig(_config);
    AppLogger.info("Locked toggled to: $val");
    notifyListeners();
  }

  /// Sets the display time format (true: 24h format, false: 12h AM/PM format).
  void setUse24h(bool val) {
    _config.use24h = val;
    StorageService.saveConfig(_config);
    AppLogger.info("24-hour format toggled to: $val");
    notifyListeners();
  }

  /// Controls the visibility of seconds in Clock mode.
  void setShowSeconds(bool val) {
    _config.showSeconds = val;
    StorageService.saveConfig(_config);
    AppLogger.info("Seconds visibility toggled to: $val");
    notifyListeners();
  }

  /// Configures application autostart on system login.
  ///
  /// For Linux desktop environments, this creates or deletes a `.desktop` entry
  /// in the user's local autostart directory (`~/.config/autostart/`).
  void setAutostart(bool val) {
    _config.autostart = val;
    StorageService.saveConfig(_config);
    AppLogger.info("Autostart toggled to: $val");
    
    // Resolve paths to the standard autostart directories
    final autostartDir = Directory('${Platform.environment['HOME']}/.config/autostart');
    final autostartFile = File('${autostartDir.path}/flip-clock-flutter.desktop');
    
    if (val) {
      try {
        // Create the directory path if it doesn't already exist
        if (!autostartDir.existsSync()) {
          autostartDir.createSync(recursive: true);
        }
        
        // Retrieve path of the currently executing binary
        final exePath = Platform.resolvedExecutable;
        
        // Write standard Freedesktop compliant Desktop Entry file
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
        
        // Mark the file as executable (chmod +x)
        Process.runSync('chmod', ['+x', autostartFile.path]);
        AppLogger.info("Desktop autostart entry enabled successfully.");
      } catch (e) {
        AppLogger.error("Error creating autostart desktop entry: $e");
      }
    } else {
      try {
        // Delete the entry if autostart is disabled
        if (autostartFile.existsSync()) {
          autostartFile.deleteSync();
          AppLogger.info("Desktop autostart entry disabled successfully.");
        }
      } catch (e) {
        AppLogger.error("Error removing autostart desktop entry: $e");
      }
    }
    notifyListeners();
  }

  /// Toggles the desktop window layering behavior.
  ///
  /// When true, the widget behaves as a background desktop widget (always on bottom).
  /// When false, the widget uses standard desktop layering behavior.
  void setAlwaysOnBottom(bool val) {
    _config.alwaysOnBottom = val;
    StorageService.saveConfig(_config);
    WindowService.setAlwaysOnBottom(val);
    AppLogger.info("Always-on-bottom toggled to: $val");
    notifyListeners();
  }

  /// Updates the descriptive countdown or stopwatch session label text.
  void updateLabel(String text) {
    if (_config.label == text) return;
    _config.label = text;
    StorageService.saveConfig(_config);
    notifyListeners();
  }

  /// Sets the visual glassmorphic theme ID and persists the preference.
  void setTheme(String themeId) {
    _config.theme = themeId;
    StorageService.saveConfig(_config);
    AppLogger.info("Theme updated to: $themeId");
    notifyListeners();
  }

  /// Sets the flip card aesthetic skin style (retro, nixie, minimal, etc.)
  void setSkin(String skinId) {
    _config.skin = skinId;
    StorageService.saveConfig(_config);
    AppLogger.info("Skin updated to: $skinId");
    notifyListeners();
  }

  /// Adjusts the global rendering scale of the widget layout.
  void setScale(double val) {
    _config.scale = val;
    StorageService.saveConfig(_config);
    AppLogger.info("Scale updated to: $val");
    notifyListeners();
  }

  /// Appends a new session record to the top of the stopwatch history array,
  /// enforces a hard cap limit of 50 log records, and saves configuration.
  void saveHistoryEntry(StopwatchHistoryEntry entry) {
    _config.stopwatchHistory.insert(0, entry);
    if (_config.stopwatchHistory.length > 50) {
      _config.stopwatchHistory.removeLast();
    }
    StorageService.saveConfig(_config);
    AppLogger.info("Recording new stopwatch session: name='${entry.name}', time='${entry.time}'");
    notifyListeners();
  }

  /// Removes a stopwatch history session record by its index.
  void deleteHistoryEntry(int index) {
    if (index >= 0 && index < _config.stopwatchHistory.length) {
      final entry = _config.stopwatchHistory.removeAt(index);
      StorageService.saveConfig(_config);
      AppLogger.info("Deleted stopwatch history entry: name='${entry.name}', time='${entry.time}'");
      notifyListeners();
    }
  }

  /// Deletes all records in stopwatch history.
  void clearHistory() {
    _config.stopwatchHistory.clear();
    StorageService.saveConfig(_config);
    AppLogger.info("Cleared all stopwatch history records.");
    notifyListeners();
  }
}
