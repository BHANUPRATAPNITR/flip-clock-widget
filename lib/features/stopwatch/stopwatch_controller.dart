import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/config.dart';
import '../../core/logger.dart';
import '../settings/settings_controller.dart';

/// [StopwatchController] handles stopwatch state machine logic, including timing counters,
/// active pause/play states, session updates, and history record submissions.
///
/// Under this architecture, the 100ms ticker runs *only* when the stopwatch is running,
/// optimizing CPU resource utilization during widget sleep states or clock display modes.
class StopwatchController extends ChangeNotifier {
  /// Reference to [SettingsController] used to save session history and fetch labels.
  final SettingsController settings;

  /// Total elapsed seconds accrued during the active session.
  int _stopwatchElapsedSeconds = 0;

  /// Controls the active running state of the stopwatch logic.
  bool _stopwatchRunning = false;

  /// Records the exact timestamp when the stopwatch was started or resumed.
  DateTime? _stopwatchStartTime;

  /// Holds the total seconds accumulated in previous play segments before pausing.
  int _stopwatchAccumulatedSeconds = 0;

  /// Periodic timer that ticks at a 100ms interval when the stopwatch is active
  /// to track precise time increments.
  Timer? _ticker;

  /// Constructor initializes the stopwatch controller.
  StopwatchController(this.settings);

  /// Exposes the current elapsed timing seconds.
  int get stopwatchElapsed => _stopwatchElapsedSeconds;

  /// Exposes the current status of the stopwatch engine.
  bool get stopwatchRunning => _stopwatchRunning;

  /// Toggles play/pause status of the stopwatch timing engine.
  void toggleStopwatch() {
    _stopwatchRunning = !_stopwatchRunning;
    if (_stopwatchRunning) {
      // Start stopwatch segment
      _stopwatchStartTime = DateTime.now();
      _startTicker();
      AppLogger.info("Stopwatch started.");
    } else {
      // Pause stopwatch segment and accumulate duration
      if (_stopwatchStartTime != null) {
        _stopwatchAccumulatedSeconds += DateTime.now().difference(_stopwatchStartTime!).inSeconds;
      }
      _stopwatchStartTime = null;
      _stopwatchElapsedSeconds = _stopwatchAccumulatedSeconds;
      
      // Stop the periodic timer to free up CPU
      _ticker?.cancel();
      _ticker = null;
      AppLogger.info("Stopwatch paused.");
    }
    notifyListeners();
  }

  /// Resets the stopwatch to zero, cancels running timers, and clears caches.
  void resetStopwatch() {
    _stopwatchRunning = false;
    _stopwatchStartTime = null;
    _stopwatchAccumulatedSeconds = 0;
    _stopwatchElapsedSeconds = 0;
    _ticker?.cancel();
    _ticker = null;
    AppLogger.info("Stopwatch reset.");
    notifyListeners();
  }

  /// Compiles current stopwatch timings, matches it against configuration label settings,
  /// and saves the session log entry into history.
  void recordStopwatchSession() {
    final elapsed = _stopwatchElapsedSeconds;
    final hrs = elapsed ~/ 3600;
    final mins = (elapsed % 3600) ~/ 60;
    final secs = elapsed % 60;
    
    // Formatting: HH:MM:SS
    final formattedTime = '${hrs.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    
    // Retrieve custom timing descriptions from config or fallback to auto-incrementing IDs
    final labelVal = settings.config.label;
    final sessionName = labelVal.isNotEmpty ? labelVal : 'Session #${settings.config.stopwatchHistory.length + 1}';
    final dateStr = DateFormat("dd MMM, HH:mm").format(DateTime.now());
    
    final entry = StopwatchHistoryEntry(
      name: sessionName,
      time: formattedTime,
      date: dateStr,
    );
    
    // Delegate config array update and storage save back to SettingsController
    settings.saveHistoryEntry(entry);
  }

  /// Registers and starts a high-frequency ticker checking time shifts.
  /// Calculating elapsed time using system timestamps (rather than incrementing a variable)
  /// prevents timer drift when the system scheduler is busy.
  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_stopwatchRunning && _stopwatchStartTime != null) {
        final elapsed = DateTime.now().difference(_stopwatchStartTime!).inSeconds + _stopwatchAccumulatedSeconds;
        if (elapsed != _stopwatchElapsedSeconds) {
          _stopwatchElapsedSeconds = elapsed;
          notifyListeners();
        }
      }
    });
  }

  /// Ensures that any running background timer is terminated upon disposal.
  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
