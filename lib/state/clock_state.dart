import 'package:flutter/material.dart';
import '../core/config.dart';
import '../features/settings/settings_controller.dart';
import '../features/clock/clock_controller.dart';
import '../features/stopwatch/stopwatch_controller.dart';
import '../features/timer/timer_controller.dart';

class ClockState extends ChangeNotifier {
  late final SettingsController settings;
  late final ClockController clock;
  late final StopwatchController stopwatch;
  late final TimerController timer;

  ClockState() {
    settings = SettingsController();
    clock = ClockController(settings);
    stopwatch = StopwatchController(settings);
    timer = TimerController();

    // Propagate changes from sub-controllers to facade listeners
    settings.addListener(notifyListeners);
    clock.addListener(notifyListeners);
    stopwatch.addListener(notifyListeners);
    timer.addListener(notifyListeners);
  }

  // Configuration settings getters
  AppConfig get config => settings.config;
  DateTime get now => clock.now;

  // Stopwatch state getters
  int get stopwatchElapsed => stopwatch.stopwatchElapsed;
  bool get stopwatchRunning => stopwatch.stopwatchRunning;

  // Countdown Timer state getters
  int get timerRemaining => timer.timerRemaining;
  int get timerInitial => timer.timerInitial;
  bool get timerRunning => timer.timerRunning;
  bool get timerAlertActive => timer.timerAlertActive;

  // Orchestrated switch mode
  void switchMode(String newMode) {
    if (settings.config.mode == newMode) return;
    
    // Silence timer alert if switching away from it
    if (newMode != "timer" && timer.timerAlertActive) {
      timer.silenceAlert();
    }
    
    settings.switchMode(newMode);
  }

  // Stopwatch controls
  void toggleStopwatch() => stopwatch.toggleStopwatch();
  void resetStopwatch() => stopwatch.resetStopwatch();
  void recordStopwatchSession() => stopwatch.recordStopwatchSession();

  // History / logs controls
  void deleteHistoryEntry(int index) => settings.deleteHistoryEntry(index);
  void clearHistory() => settings.clearHistory();

  // Countdown timer controls
  void toggleTimer() => timer.toggleTimer();
  void resetTimer() => timer.resetTimer();
  void setTimerDuration(int totalSeconds) => timer.setTimerDuration(totalSeconds);
  void addTimerSeconds(int offsetSeconds) => timer.addTimerSeconds(offsetSeconds);
  void setTimerHours(int hours) => timer.setTimerHours(hours);
  void setTimerMinutes(int minutes) => timer.setTimerMinutes(minutes);
  void setTimerSecondsValue(int seconds) => timer.setTimerSecondsValue(seconds);
  void silenceAlert() => timer.silenceAlert();

  // Preferences controls
  void setLocked(bool val) => settings.setLocked(val);
  void setUse24h(bool val) => settings.setUse24h(val);
  void setShowSeconds(bool val) => settings.setShowSeconds(val);
  void setAutostart(bool val) => settings.setAutostart(val);
  void setAlwaysOnBottom(bool val) => settings.setAlwaysOnBottom(val);
  void updateLabel(String text) => settings.updateLabel(text);
  void setTheme(String themeId) => settings.setTheme(themeId);
  void setSkin(String skinId) => settings.setSkin(skinId);
  void setScale(double val) => settings.setScale(val);

  @override
  void dispose() {
    settings.removeListener(notifyListeners);
    clock.removeListener(notifyListeners);
    stopwatch.removeListener(notifyListeners);
    timer.removeListener(notifyListeners);

    settings.dispose();
    clock.dispose();
    stopwatch.dispose();
    timer.dispose();

    super.dispose();
  }
}
