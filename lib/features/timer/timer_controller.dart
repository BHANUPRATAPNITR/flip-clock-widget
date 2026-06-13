import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/logger.dart';

/// [TimerController] manages countdown timer logic, slider value mappings,
/// and fires desktop notification triggers when the countdown expires.
///
/// In alignment with resource optimization objectives, the countdown ticker
/// runs *only* when the timer is active (`_timerRunning == true`).
class TimerController extends ChangeNotifier {
  /// Remaining countdown duration in seconds. Default is 300s (5 minutes).
  int _timerRemainingSeconds = 300;

  /// Holds the initial starting time in seconds. Used during reset operations.
  int _timerInitialSeconds = 300;

  /// Track if the timer is actively counting down.
  bool _timerRunning = false;

  /// Active state of the full-screen flashing alert UI when the timer finishes.
  bool _timerAlertActive = false;

  /// System timestamp marking when the countdown segment started or resumed.
  DateTime? _timerStartTime;

  /// Accumulated seconds elapsed in previous segments before pause.
  int _timerAccumulatedSeconds = 0;

  /// Periodical timer checking second shifts.
  Timer? _ticker;

  /// Getters exposing current countdown state values to facade listeners
  int get timerRemaining => _timerRemainingSeconds;
  int get timerInitial => _timerInitialSeconds;
  bool get timerRunning => _timerRunning;
  bool get timerAlertActive => _timerAlertActive;

  /// Resumes or pauses the countdown state machine.
  /// If the countdown alert is flashing, clicking play will silence the alarm.
  void toggleTimer() {
    if (_timerAlertActive) {
      silenceAlert();
      return;
    }

    _timerRunning = !_timerRunning;
    if (_timerRunning) {
      // Start segment
      _timerStartTime = DateTime.now();
      _startTicker();
      AppLogger.info("Countdown timer started. Remaining seconds: $_timerRemainingSeconds");
    } else {
      // Pause segment
      if (_timerStartTime != null) {
        _timerAccumulatedSeconds += DateTime.now().difference(_timerStartTime!).inSeconds;
      }
      _timerStartTime = null;
      _ticker?.cancel();
      _ticker = null;
      AppLogger.info("Countdown timer paused. Remaining seconds: $_timerRemainingSeconds");
    }
    notifyListeners();
  }

  /// Cancels any active timing logic and rolls the timer back to its initial start duration.
  void resetTimer() {
    _timerRunning = false;
    _timerStartTime = null;
    _timerAccumulatedSeconds = 0;
    _timerRemainingSeconds = _timerInitialSeconds;
    _ticker?.cancel();
    _ticker = null;
    AppLogger.info("Countdown timer reset back to $_timerRemainingSeconds seconds.");
    notifyListeners();
  }

  /// Updates the base target countdown duration. Only valid when the timer is paused.
  void setTimerDuration(int totalSeconds) {
    if (_timerRunning) return;
    _timerInitialSeconds = totalSeconds;
    _timerRemainingSeconds = totalSeconds;
    _timerAccumulatedSeconds = 0;
    notifyListeners();
  }

  /// Modifies current duration values by a custom offset (used by mouse scroll wheel actions).
  /// Caps configuration bounds between 0 and 23:59:59 (86399 seconds).
  void addTimerSeconds(int offsetSeconds) {
    if (_timerRunning) return;
    int target = _timerRemainingSeconds + offsetSeconds;
    if (target < 0) target = 0;
    if (target > 86399) target = 86399;
    
    _timerRemainingSeconds = target;
    _timerInitialSeconds = target;
    _timerAccumulatedSeconds = 0;
    notifyListeners();
  }

  /// Updates hour values from the symmetrical adjusters slider.
  void setTimerHours(int hours) {
    if (_timerRunning) return;
    final mins = (_timerRemainingSeconds % 3600) ~/ 60;
    final secs = _timerRemainingSeconds % 60;
    setTimerDuration(hours * 3600 + mins * 60 + secs);
  }

  /// Updates minute values from the symmetrical adjusters slider.
  void setTimerMinutes(int minutes) {
    if (_timerRunning) return;
    final hrs = _timerRemainingSeconds ~/ 3600;
    final secs = _timerRemainingSeconds % 60;
    setTimerDuration(hrs * 3600 + minutes * 60 + secs);
  }

  /// Updates second values from the symmetrical adjusters slider.
  void setTimerSecondsValue(int seconds) {
    if (_timerRunning) return;
    final hrs = _timerRemainingSeconds ~/ 3600;
    final mins = (_timerRemainingSeconds % 3600) ~/ 60;
    setTimerDuration(hrs * 3600 + mins * 60 + seconds);
  }

  /// Silences the flashing red widget alert overlays and restores the timer to its initial duration state.
  void silenceAlert() {
    if (_timerAlertActive) {
      _timerAlertActive = false;
      _timerRemainingSeconds = _timerInitialSeconds;
      _ticker?.cancel();
      _ticker = null;
      AppLogger.info("Timer alert silenced. Timer reset to initial state.");
      notifyListeners();
    }
  }

  /// Triggers a desktop visual alarm alert.
  /// Sets flashing alert modes, resets accumulation counts, and runs the Linux native `notify-send` command.
  void _triggerTimerAlert() {
    _timerAlertActive = true;
    _timerRunning = false;
    _timerStartTime = null;
    _timerAccumulatedSeconds = 0;
    _ticker?.cancel();
    _ticker = null;
    
    AppLogger.warning("Countdown timer completed! Triggering notification and red flashing alert.");
    
    // Spawns native Linux shell notification command.
    // Falls back gracefully if notify-send command is missing or lacks display headers.
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

  /// Tickers evaluate elapsed milliseconds using wall-clock timing offsets
  /// to ensure consistent and correct increments.
  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_timerRunning && _timerStartTime != null) {
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
    });
  }

  /// Clean up timer subscriptions on destroy.
  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
