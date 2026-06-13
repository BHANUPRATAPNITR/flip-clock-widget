import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/config.dart';
import '../../core/logger.dart';
import '../../core/providers.dart';
import 'stopwatch_state.dart';

/// [StopwatchNotifier] manages stopwatch timings, start/pause status, and log
/// recordings as a Riverpod [Notifier] over [StopwatchState].
class StopwatchNotifier extends Notifier<StopwatchState> {
  /// Periodic timer tracking timing shifts.
  Timer? _ticker;

  @override
  StopwatchState build() {
    // Clean up timer resource on provider dispose
    ref.onDispose(() {
      _ticker?.cancel();
    });
    return const StopwatchState();
  }

  /// Toggles play/pause status of the stopwatch engine.
  void toggleStopwatch() {
    final isRunning = !state.stopwatchRunning;
    
    if (isRunning) {
      // Start segment
      state = state.copyWith(
        stopwatchRunning: true,
        stopwatchStartTime: () => DateTime.now(),
      );
      _startTicker();
      AppLogger.info("Stopwatch started.");
    } else {
      // Pause segment
      int accumulated = state.stopwatchAccumulatedSeconds;
      if (state.stopwatchStartTime != null) {
        accumulated += DateTime.now().difference(state.stopwatchStartTime!).inSeconds;
      }
      
      _ticker?.cancel();
      _ticker = null;
      
      state = state.copyWith(
        stopwatchRunning: false,
        stopwatchStartTime: () => null,
        stopwatchAccumulatedSeconds: accumulated,
        stopwatchElapsedSeconds: accumulated,
      );
      AppLogger.info("Stopwatch paused.");
    }
  }

  /// Resets stopwatch counters to initial zero states.
  void resetStopwatch() {
    _ticker?.cancel();
    _ticker = null;
    state = const StopwatchState();
    AppLogger.info("Stopwatch reset.");
  }

  /// Compiles stopwatch session details and registers them in Settings history.
  void recordStopwatchSession() {
    final elapsed = state.stopwatchElapsedSeconds;
    final hrs = elapsed ~/ 3600;
    final mins = (elapsed % 3600) ~/ 60;
    final secs = elapsed % 60;
    final formattedTime = '${hrs.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    
    // Read config directly from settingsProvider state
    final settingsState = ref.read(settingsProvider);
    final labelVal = settingsState.label;
    final sessionName = labelVal.isNotEmpty ? labelVal : 'Session #${settingsState.stopwatchHistory.length + 1}';
    final dateStr = DateFormat("dd MMM, HH:mm").format(DateTime.now());
    
    final entry = StopwatchHistoryEntry(
      name: sessionName,
      time: formattedTime,
      date: dateStr,
    );
    
    // Delegate state persistence to settings notifier
    ref.read(settingsProvider.notifier).saveHistoryEntry(entry);
  }

  /// Ticker calculates precise elapsed intervals.
  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (state.stopwatchRunning && state.stopwatchStartTime != null) {
        final elapsed = DateTime.now().difference(state.stopwatchStartTime!).inSeconds + state.stopwatchAccumulatedSeconds;
        if (elapsed != state.stopwatchElapsedSeconds) {
          state = state.copyWith(stopwatchElapsedSeconds: elapsed);
        }
      }
    });
  }
}
