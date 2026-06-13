import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/logger.dart';

class TimerController extends ChangeNotifier {
  int _timerRemainingSeconds = 300; // default 5m
  int _timerInitialSeconds = 300;
  bool _timerRunning = false;
  bool _timerAlertActive = false;
  DateTime? _timerStartTime;
  int _timerAccumulatedSeconds = 0;
  Timer? _ticker;

  int get timerRemaining => _timerRemainingSeconds;
  int get timerInitial => _timerInitialSeconds;
  bool get timerRunning => _timerRunning;
  bool get timerAlertActive => _timerAlertActive;

  void toggleTimer() {
    if (_timerAlertActive) {
      silenceAlert();
      return;
    }

    _timerRunning = !_timerRunning;
    if (_timerRunning) {
      _timerStartTime = DateTime.now();
      _startTicker();
      AppLogger.info("Countdown timer started. Remaining seconds: $_timerRemainingSeconds");
    } else {
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

  void _triggerTimerAlert() {
    _timerAlertActive = true;
    _timerRunning = false;
    _timerStartTime = null;
    _timerAccumulatedSeconds = 0;
    _ticker?.cancel();
    _ticker = null;
    
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

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
