import 'package:flutter/material.dart';
import '../core/config.dart';
import '../features/settings/settings_controller.dart';
import '../features/clock/clock_controller.dart';
import '../features/stopwatch/stopwatch_controller.dart';
import '../features/timer/timer_controller.dart';

/// [ClockState] acts as the central Coordinating Facade for the state management architecture.
///
/// It aggregates isolated domain controllers ([SettingsController], [ClockController], 
/// [StopwatchController], [TimerController]) and registers listeners to propagate their updates.
///
/// By exposing the exact same public properties, getters, and methods as the legacy design,
/// this class ensures **100% backward compatibility** and guarantees zero changes are needed
/// in UI widgets like `MainView` and `SettingsPanel`.
class ClockState extends ChangeNotifier {
  /// Reference to the settings and configurations manager.
  late final SettingsController settings;

  /// Reference to the main system clock manager.
  late final ClockController clock;

  /// Reference to the stopwatch timing engine.
  late final StopwatchController stopwatch;

  /// Reference to the countdown timer engine.
  late final TimerController timer;

  /// Constructor initializes all sub-controllers and registers listeners to capture
  /// state changes, which are then bubbled up to trigger UI widget rebuilds.
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

  // ===========================================================================
  // CONFIGURATION & DISPLAY GETTERS
  // ===========================================================================

  /// Read-only access to the application config.
  AppConfig get config => settings.config;

  /// Current time values (for Clock mode).
  DateTime get now => clock.now;

  // ===========================================================================
  // STOPWATCH STATE GETTERS
  // ===========================================================================

  /// Elapsed seconds in the current stopwatch session.
  int get stopwatchElapsed => stopwatch.stopwatchElapsed;

  /// Active status of the stopwatch engine.
  bool get stopwatchRunning => stopwatch.stopwatchRunning;

  // ===========================================================================
  // TIMER STATE GETTERS
  // ===========================================================================

  /// Remaining seconds on the countdown timer.
  int get timerRemaining => timer.timerRemaining;

  /// Initial duration configured for the countdown timer.
  int get timerInitial => timer.timerInitial;

  /// Active status of the timer engine.
  bool get timerRunning => timer.timerRunning;

  /// Flashing notification alarm state of the countdown timer.
  bool get timerAlertActive => timer.timerAlertActive;

  // ===========================================================================
  // MODE COORDINATION & CONTROLS
  // ===========================================================================

  /// Switches active clock display modes.
  ///
  /// Orchestrates cross-feature operations: if switching away from the timer
  /// mode while the visual alert is active, it silences the alert first.
  void switchMode(String newMode) {
    if (settings.config.mode == newMode) return;
    
    // Cross-controller orchestration: Silence alarm if user navigates away
    if (newMode != "timer" && timer.timerAlertActive) {
      timer.silenceAlert();
    }
    
    settings.switchMode(newMode);
  }

  // ===========================================================================
  // STOPWATCH CONTROLS
  // ===========================================================================

  /// Starts or pauses the stopwatch timing engine.
  void toggleStopwatch() => stopwatch.toggleStopwatch();

  /// Resets stopwatch timing session counters to zero.
  void resetStopwatch() => stopwatch.resetStopwatch();

  /// Compiles stopwatch session times and appends them to history logs.
  void recordStopwatchSession() => stopwatch.recordStopwatchSession();

  // ===========================================================================
  // HISTORY / SESSION LOGS CONTROLS
  // ===========================================================================

  /// Removes a stopwatch log entry by index.
  void deleteHistoryEntry(int index) => settings.deleteHistoryEntry(index);

  /// Clears all log entries in stopwatch history.
  void clearHistory() => settings.clearHistory();

  // ===========================================================================
  // COUNTDOWN TIMER CONTROLS
  // ===========================================================================

  /// Starts, resumes, or pauses the countdown timer engine.
  void toggleTimer() => timer.toggleTimer();

  /// Resets countdown timer remaining time to its initial duration state.
  void resetTimer() => timer.resetTimer();

  /// Sets the countdown target duration (in seconds).
  void setTimerDuration(int totalSeconds) => timer.setTimerDuration(totalSeconds);

  /// Adjusts remaining seconds by a direct offset value.
  void addTimerSeconds(int offsetSeconds) => timer.addTimerSeconds(offsetSeconds);

  /// Sets target countdown hour values.
  void setTimerHours(int hours) => timer.setTimerHours(hours);

  /// Sets target countdown minute values.
  void setTimerMinutes(int minutes) => timer.setTimerMinutes(minutes);

  /// Sets target countdown second values.
  void setTimerSecondsValue(int seconds) => timer.setTimerSecondsValue(seconds);

  /// Silences the active countdown alert alarm.
  void silenceAlert() => timer.silenceAlert();

  // ===========================================================================
  // PREFERENCES & WINDOW TOGGLES
  // ===========================================================================

  /// Locks the widget desktop position coordinates.
  void setLocked(bool val) => settings.setLocked(val);

  /// Toggles between 12h and 24h clock displays.
  void setUse24h(bool val) => settings.setUse24h(val);

  /// Toggles visibility of clock seconds in UI.
  void setShowSeconds(bool val) => settings.setShowSeconds(val);

  /// Toggles Linux desktop autostart options.
  void setAutostart(bool val) => settings.setAutostart(val);

  /// Controls whether the widget stays layered behind other application windows.
  void setAlwaysOnBottom(bool val) => settings.setAlwaysOnBottom(val);

  /// Updates display timing labels.
  void updateLabel(String text) => settings.updateLabel(text);

  /// Updates visual color themes.
  void setTheme(String themeId) => settings.setTheme(themeId);

  /// Updates display skins (retro, nixie, minimal, hologram).
  void setSkin(String skinId) => settings.setSkin(skinId);

  /// Changes visual rendering size scales.
  void setScale(double val) => settings.setScale(val);

  /// Disposes resources, unbinds controller update listeners, and cancels tickers.
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
