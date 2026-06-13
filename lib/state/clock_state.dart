import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/config.dart';
import '../core/logger.dart';
import '../services/storage.dart';
import '../services/window.dart';

class ClockState extends ChangeNotifier {
  late AppConfig _config;
  Timer? _ticker;
  DateTime _now = DateTime.now();

  // Stopwatch state variables
  int _stopwatchElapsedSeconds = 0;
  bool _stopwatchRunning = false;
  DateTime? _stopwatchStartTime;
  int _stopwatchAccumulatedSeconds = 0;

  // Countdown Timer state variables
  int _timerRemainingSeconds = 300; // default 5m
  int _timerInitialSeconds = 300;
  bool _timerRunning = false;
  bool _timerAlertActive = false;

  ClockState() {
    _config = StorageService.loadConfig();
    _startTicker();
    
    // Sync initial window settings
    _syncWindowSettings();
  }

  AppConfig get config => _config;
  DateTime get now => _now;
  
  // Getters for timer displays
  int get stopwatchElapsed => _stopwatchElapsedSeconds;
  bool get stopwatchRunning => _stopwatchRunning;
  
  int get timerRemaining => _timerRemainingSeconds;
  int get timerInitial => _timerInitialSeconds;
  bool get timerRunning => _timerRunning;
  bool get timerAlertActive => _timerAlertActive;

  void _startTicker() {
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      final oldNow = _now;
      _now = DateTime.now();
      
      // Perform clock-second transitions
      if (_config.mode == "clock") {
        if (oldNow.second != _now.second) {
          notifyListeners();
        }
      } else if (_config.mode == "stopwatch") {
        if (_stopwatchRunning && _stopwatchStartTime != null) {
          final elapsed = DateTime.now().difference(_stopwatchStartTime!).inSeconds + _stopwatchAccumulatedSeconds;
          if (elapsed != _stopwatchElapsedSeconds) {
            _stopwatchElapsedSeconds = elapsed;
            notifyListeners();
          }
        }
      } else if (_config.mode == "timer") {
        // Countdown updates every second
        // Check if a whole second passed
        if (_timerRunning) {
          final elapsedMs = DateTime.now().difference(_timerStartTime!).inMilliseconds;
          final remaining = _timerInitialSeconds - ((elapsedMs / 1000).floor() + _timerAccumulatedSeconds);
          
          if (remaining <= 0) {
            _timerRemainingSeconds = 0;
            _timerRunning = false;
            _triggerTimerAlert();
            notifyListeners();
          } else if (remaining != _timerRemainingSeconds) {
            _timerRemainingSeconds = remaining;
            notifyListeners();
          }
        }
      }
    });
  }

  DateTime? _timerStartTime;
  int _timerAccumulatedSeconds = 0;

  void _syncWindowSettings() {
    WindowService.setAlwaysOnBottom(_config.alwaysOnBottom);
  }

  // Action switches
  void switchMode(String newMode) {
    if (_config.mode == newMode) return;
    
    _config.mode = newMode;
    StorageService.saveConfig(_config);
    AppLogger.info("Switching widget mode to: $newMode");
    
    // If switching away from timer alert
    if (_timerAlertActive) {
      silenceAlert();
    }
    
    StorageService.saveConfig(_config);
    notifyListeners();
  }

  // Stopwatch controls
  void toggleStopwatch() {
    _stopwatchRunning = !_stopwatchRunning;
    if (_stopwatchRunning) {
      _stopwatchStartTime = DateTime.now();
      AppLogger.info("Stopwatch started.");
    } else {
      if (_stopwatchStartTime != null) {
        _stopwatchAccumulatedSeconds += DateTime.now().difference(_stopwatchStartTime!).inSeconds;
      }
      _stopwatchStartTime = null;
      AppLogger.info("Stopwatch paused.");
    }
    notifyListeners();
  }

  void resetStopwatch() {
    _stopwatchRunning = false;
    _stopwatchStartTime = null;
    _stopwatchAccumulatedSeconds = 0;
    _stopwatchElapsedSeconds = 0;
    AppLogger.info("Stopwatch reset.");
    notifyListeners();
  }

  void recordStopwatchSession() {
    final elapsed = _stopwatchElapsedSeconds;
    final hrs = elapsed ~/ 3600;
    final mins = (elapsed % 3600) ~/ 60;
    final secs = elapsed % 60;
    final formattedTime = '${hrs.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    
    final labelVal = _config.label;
    final sessionName = labelVal.isNotEmpty ? labelVal : 'Session #${_config.stopwatchHistory.length + 1}';
    final dateStr = DateFormat("dd MMM, HH:mm").format(DateTime.now());
    
    final entry = StopwatchHistoryEntry(
      name: sessionName,
      time: formattedTime,
      date: dateStr,
    );
    
    _config.stopwatchHistory.insert(0, entry);
    if (_config.stopwatchHistory.length > 50) {
      _config.stopwatchHistory.removeLast();
    }
    
    StorageService.saveConfig(_config);
    AppLogger.info("Recording new stopwatch session: name='$sessionName', time='$formattedTime'");
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

  // Timer controls
  void toggleTimer() {
    if (_timerAlertActive) {
      silenceAlert();
      return;
    }

    _timerRunning = !_timerRunning;
    if (_timerRunning) {
      _timerStartTime = DateTime.now();
      AppLogger.info("Countdown timer started. Remaining seconds: $_timerRemainingSeconds");
    } else {
      if (_timerStartTime != null) {
        _timerAccumulatedSeconds += DateTime.now().difference(_timerStartTime!).inSeconds;
      }
      _timerStartTime = null;
      AppLogger.info("Countdown timer paused. Remaining seconds: $_timerRemainingSeconds");
    }
    notifyListeners();
  }

  void resetTimer() {
    _timerRunning = false;
    _timerStartTime = null;
    _timerAccumulatedSeconds = 0;
    _timerRemainingSeconds = _timerInitialSeconds;
    AppLogger.info("Countdown timer reset back to $_timerRemainingSeconds seconds.");
    notifyListeners();
  }

  void setTimerDuration(int totalSeconds) {
    if (_timerRunning) return;
    _timerInitialSeconds = totalSeconds;
    _timerRemainingSeconds = totalSeconds;
    _timerAccumulatedSeconds = 0;
    notifyListeners();
  }

  void addTimerSeconds(int offsetSeconds) {
    if (_timerRunning) return;
    int target = _timerRemainingSeconds + offsetSeconds;
    if (target < 0) target = 0;
    if (target > 86399) target = 86399; // Cap at 23:59:59
    
    _timerRemainingSeconds = target;
    _timerInitialSeconds = target;
    _timerAccumulatedSeconds = 0;
    notifyListeners();
  }

  void setTimerHours(int hours) {
    if (_timerRunning) return;
    final mins = (_timerRemainingSeconds % 3600) ~/ 60;
    final secs = _timerRemainingSeconds % 60;
    setTimerDuration(hours * 3600 + mins * 60 + secs);
  }

  void setTimerMinutes(int minutes) {
    if (_timerRunning) return;
    final hrs = _timerRemainingSeconds ~/ 3600;
    final secs = _timerRemainingSeconds % 60;
    setTimerDuration(hrs * 3600 + minutes * 60 + secs);
  }

  void setTimerSecondsValue(int seconds) {
    if (_timerRunning) return;
    final hrs = _timerRemainingSeconds ~/ 3600;
    final mins = (_timerRemainingSeconds % 3600) ~/ 60;
    setTimerDuration(hrs * 3600 + mins * 60 + seconds);
  }

  void _triggerTimerAlert() {
    _timerAlertActive = true;
    _timerRunning = false;
    _timerStartTime = null;
    _timerAccumulatedSeconds = 0;
    
    AppLogger.warning("Countdown timer completed! Triggering notification and red flashing alert.");
    
    // Trigger notify-send
    try {
      Process.run('notify-send', [
        '-t', '6000', 
        '-a', 'Flip Clock', 
        'Timer Alert', 
        'Timer Completed!',
        '-i', 'alarm-clock'
      ]);
    } catch (e) {
      AppLogger.error("Failed to run notify-send: $e");
    }
  }

  void silenceAlert() {
    if (_timerAlertActive) {
      _timerAlertActive = false;
      _timerRemainingSeconds = _timerInitialSeconds;
      AppLogger.info("Timer alert silenced. Timer reset to initial state.");
      notifyListeners();
    }
  }

  // Preferences toggles
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
        // chmod +x
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

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
