import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/config.dart';
import '../../core/logger.dart';
import '../settings/settings_controller.dart';

class StopwatchController extends ChangeNotifier {
  final SettingsController settings;
  int _stopwatchElapsedSeconds = 0;
  bool _stopwatchRunning = false;
  DateTime? _stopwatchStartTime;
  int _stopwatchAccumulatedSeconds = 0;
  Timer? _ticker;

  StopwatchController(this.settings);

  int get stopwatchElapsed => _stopwatchElapsedSeconds;
  bool get stopwatchRunning => _stopwatchRunning;

  void toggleStopwatch() {
    _stopwatchRunning = !_stopwatchRunning;
    if (_stopwatchRunning) {
      _stopwatchStartTime = DateTime.now();
      _startTicker();
      AppLogger.info("Stopwatch started.");
    } else {
      if (_stopwatchStartTime != null) {
        _stopwatchAccumulatedSeconds += DateTime.now().difference(_stopwatchStartTime!).inSeconds;
      }
      _stopwatchStartTime = null;
      _stopwatchElapsedSeconds = _stopwatchAccumulatedSeconds;
      _ticker?.cancel();
      _ticker = null;
      AppLogger.info("Stopwatch paused.");
    }
    notifyListeners();
  }

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

  void recordStopwatchSession() {
    final elapsed = _stopwatchElapsedSeconds;
    final hrs = elapsed ~/ 3600;
    final mins = (elapsed % 3600) ~/ 60;
    final secs = elapsed % 60;
    final formattedTime = '${hrs.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    
    final labelVal = settings.config.label;
    final sessionName = labelVal.isNotEmpty ? labelVal : 'Session #${settings.config.stopwatchHistory.length + 1}';
    final dateStr = DateFormat("dd MMM, HH:mm").format(DateTime.now());
    
    final entry = StopwatchHistoryEntry(
      name: sessionName,
      time: formattedTime,
      date: dateStr,
    );
    
    settings.saveHistoryEntry(entry);
  }

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

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
