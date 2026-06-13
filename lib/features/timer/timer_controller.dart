import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/logger.dart';
import 'timer_state.dart';

/// [TimerNotifier] manages countdown duration properties, slide operations,
/// and executes CLI-level notifications when timing expires as a Riverpod [Notifier].
class TimerNotifier extends Notifier<TimerState> {
  /// Periodic timer checking timing increments.
  Timer? _ticker;

  @override
  TimerState build() {
    // Clean up timer resource on provider dispose
    ref.onDispose(() {
      _ticker?.cancel();
    });
    return const TimerState();
  }

  /// Toggles countdown activity. Silences active flashing alarms on toggle.
  void toggleTimer() {
    if (state.timerAlertActive) {
      silenceAlert();
      return;
    }

    final isRunning = !state.timerRunning;
    if (isRunning) {
      // Start segment
      state = state.copyWith(
        timerRunning: true,
        timerStartTime: () => DateTime.now(),
      );
      _startTicker();
      AppLogger.info("Countdown timer started. Remaining seconds: ${state.timerRemainingSeconds}");
    } else {
      // Pause segment
      int accumulated = state.timerAccumulatedSeconds;
      if (state.timerStartTime != null) {
        accumulated += DateTime.now().difference(state.timerStartTime!).inSeconds;
      }
      _ticker?.cancel();
      _ticker = null;
      state = state.copyWith(
        timerRunning: false,
        timerStartTime: () => null,
        timerAccumulatedSeconds: accumulated,
      );
      AppLogger.info("Countdown timer paused. Remaining seconds: ${state.timerRemainingSeconds}");
    }
  }

  /// Reset countdown timing to the initial configuration state.
  void resetTimer() {
    _ticker?.cancel();
    _ticker = null;
    state = state.copyWith(
      timerRunning: false,
      timerStartTime: () => null,
      timerAccumulatedSeconds: 0,
      timerRemainingSeconds: state.timerInitialSeconds,
    );
    AppLogger.info("Countdown timer reset back to ${state.timerRemainingSeconds} seconds.");
  }

  /// Sets countdown target durations.
  void setTimerDuration(int totalSeconds) {
    if (state.timerRunning) return;
    state = state.copyWith(
      timerInitialSeconds: totalSeconds,
      timerRemainingSeconds: totalSeconds,
      timerAccumulatedSeconds: 0,
    );
  }

  /// Adjusts remaining seconds by custom offsets.
  void addTimerSeconds(int offsetSeconds) {
    if (state.timerRunning) return;
    int target = state.timerRemainingSeconds + offsetSeconds;
    if (target < 0) target = 0;
    if (target > 86399) target = 86399; // Cap at 23:59:59
    
    state = state.copyWith(
      timerRemainingSeconds: target,
      timerInitialSeconds: target,
      timerAccumulatedSeconds: 0,
    );
  }

  /// Adjusts hour properties.
  void setTimerHours(int hours) {
    if (state.timerRunning) return;
    final mins = (state.timerRemainingSeconds % 3600) ~/ 60;
    final secs = state.timerRemainingSeconds % 60;
    setTimerDuration(hours * 3600 + mins * 60 + secs);
  }

  /// Adjusts minute properties.
  void setTimerMinutes(int minutes) {
    if (state.timerRunning) return;
    final hrs = state.timerRemainingSeconds ~/ 3600;
    final secs = state.timerRemainingSeconds % 60;
    setTimerDuration(hrs * 3600 + minutes * 60 + secs);
  }

  /// Adjusts second properties.
  void setTimerSecondsValue(int seconds) {
    if (state.timerRunning) return;
    final hrs = state.timerRemainingSeconds ~/ 3600;
    final mins = (state.timerRemainingSeconds % 3600) ~/ 60;
    setTimerDuration(hrs * 3600 + mins * 60 + seconds);
  }

  /// Silences flashing warning overlays and resets countdowns.
  void silenceAlert() {
    if (state.timerAlertActive) {
      _ticker?.cancel();
      _ticker = null;
      state = state.copyWith(
        timerAlertActive: false,
        timerRemainingSeconds: state.timerInitialSeconds,
      );
      AppLogger.info("Timer alert silenced. Timer reset to initial state.");
    }
  }

  /// Triggers full-screen visual alarms and executes native OS notification alerts.
  void _triggerTimerAlert() {
    _ticker?.cancel();
    _ticker = null;
    state = state.copyWith(
      timerAlertActive: true,
      timerRunning: false,
      timerStartTime: () => null,
      timerAccumulatedSeconds: 0,
    );
    
    AppLogger.warning("Countdown timer completed! Triggering notification and red flashing alert.");
    
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

  /// Ticker checking timing shifts.
  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (state.timerRunning && state.timerStartTime != null) {
        final elapsedMs = DateTime.now().difference(state.timerStartTime!).inMilliseconds;
        final remaining = state.timerInitialSeconds - ((elapsedMs / 1000).floor() + state.timerAccumulatedSeconds);
        
        if (remaining <= 0) {
          state = state.copyWith(timerRemainingSeconds: 0, timerRunning: false);
          _triggerTimerAlert();
        } else if (remaining != state.timerRemainingSeconds) {
          state = state.copyWith(timerRemainingSeconds: remaining);
        }
      }
    });
  }
}
