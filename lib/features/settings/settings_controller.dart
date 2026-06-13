import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/config.dart';
import '../../core/logger.dart';
import '../../services/storage.dart';
import '../../services/window.dart';

class SettingsController extends ChangeNotifier {
  late AppConfig _config;

  SettingsController() {
    _config = StorageService.loadConfig();
    _syncWindowSettings();
  }

  AppConfig get config => _config;

  void _syncWindowSettings() {
    WindowService.setAlwaysOnBottom(_config.alwaysOnBottom);
  }

  void switchMode(String newMode) {
    if (_config.mode == newMode) return;
    _config.mode = newMode;
    StorageService.saveConfig(_config);
    AppLogger.info("Switching widget mode to: $newMode");
    notifyListeners();
  }

  void setLocked(bool val) {
    _config.locked = val;
    StorageService.saveConfig(_config);
    AppLogger.info("Locked toggled to: $val");
    notifyListeners();
  }

  void setUse24h(bool val) {
    _config.use24h = val;
    StorageService.saveConfig(_config);
    AppLogger.info("24-hour format toggled to: $val");
    notifyListeners();
  }

  void setShowSeconds(bool val) {
    _config.showSeconds = val;
    StorageService.saveConfig(_config);
    AppLogger.info("Seconds visibility toggled to: $val");
    notifyListeners();
  }

  void setAutostart(bool val) {
    _config.autostart = val;
    StorageService.saveConfig(_config);
    AppLogger.info("Autostart toggled to: $val");
    
    // Manage autostart desktop entries
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
    notifyListeners();
  }

  void setAlwaysOnBottom(bool val) {
    _config.alwaysOnBottom = val;
    StorageService.saveConfig(_config);
    WindowService.setAlwaysOnBottom(val);
    AppLogger.info("Always-on-bottom toggled to: $val");
    notifyListeners();
  }

  void updateLabel(String text) {
    if (_config.label == text) return;
    _config.label = text;
    StorageService.saveConfig(_config);
    notifyListeners();
  }

  void setTheme(String themeId) {
    _config.theme = themeId;
    StorageService.saveConfig(_config);
    AppLogger.info("Theme updated to: $themeId");
    notifyListeners();
  }

  void setSkin(String skinId) {
    _config.skin = skinId;
    StorageService.saveConfig(_config);
    AppLogger.info("Skin updated to: $skinId");
    notifyListeners();
  }

  void setScale(double val) {
    _config.scale = val;
    StorageService.saveConfig(_config);
    AppLogger.info("Scale updated to: $val");
    notifyListeners();
  }

  void saveHistoryEntry(StopwatchHistoryEntry entry) {
    _config.stopwatchHistory.insert(0, entry);
    if (_config.stopwatchHistory.length > 50) {
      _config.stopwatchHistory.removeLast();
    }
    StorageService.saveConfig(_config);
    AppLogger.info("Recording new stopwatch session: name='${entry.name}', time='${entry.time}'");
    notifyListeners();
  }

  void deleteHistoryEntry(int index) {
    if (index >= 0 && index < _config.stopwatchHistory.length) {
      final entry = _config.stopwatchHistory.removeAt(index);
      StorageService.saveConfig(_config);
      AppLogger.info("Deleted stopwatch history entry: name='${entry.name}', time='${entry.time}'");
      notifyListeners();
    }
  }

  void clearHistory() {
    _config.stopwatchHistory.clear();
    StorageService.saveConfig(_config);
    AppLogger.info("Cleared all stopwatch history records.");
    notifyListeners();
  }
}
