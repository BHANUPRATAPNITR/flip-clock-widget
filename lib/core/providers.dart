import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/settings/settings_controller.dart';
import '../features/clock/clock_controller.dart';
import '../features/stopwatch/stopwatch_controller.dart';
import '../features/timer/timer_controller.dart';
import '../features/stopwatch/stopwatch_state.dart';
import '../features/timer/timer_state.dart';
import '../core/config.dart';

/// Provider for [SettingsNotifier] which holds and saves configurations immutably.
final settingsProvider = NotifierProvider<SettingsNotifier, AppConfig>(() {
  return SettingsNotifier();
});

/// Provider for [ClockNotifier] which updates system time.
final clockProvider = NotifierProvider<ClockNotifier, DateTime>(() {
  return ClockNotifier();
});

/// Provider for [StopwatchNotifier] which tracks stopwatch timings.
final stopwatchProvider = NotifierProvider<StopwatchNotifier, StopwatchState>(() {
  return StopwatchNotifier();
});

/// Provider for [TimerNotifier] which tracks countdown durations.
final timerProvider = NotifierProvider<TimerNotifier, TimerState>(() {
  return TimerNotifier();
});

