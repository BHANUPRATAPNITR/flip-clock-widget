import 'dart:async';
import 'package:flutter/material.dart';
import '../settings/settings_controller.dart';

/// [ClockController] manages system clock synchronization.
/// It tracks the current date/time and notifies listeners specifically when the second changes,
/// which triggers fluid flips on the layout digit cards.
class ClockController extends ChangeNotifier {
  /// Reference to [SettingsController] to retrieve settings like 12h/24h time formatting.
  final SettingsController settings;

  /// The active time value currently presented in the clock views.
  DateTime _now = DateTime.now();

  /// Periodic timer checking system time shifts at high frequency (100ms)
  /// to ensure flip animations fire precisely on second change bounds.
  Timer? _ticker;

  /// Constructor initializes the clock controller and kicks off the background ticker.
  ClockController(this.settings) {
    _startTicker();
  }

  /// Exposes the current system time value as a read-only getter.
  DateTime get now => _now;

  /// Starts a periodic timer checking if a whole second boundary has elapsed.
  /// If the current second differs from the previously recorded second, it notifies listeners.
  void _startTicker() {
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      final oldNow = _now;
      _now = DateTime.now();
      
      // We check if the second has shifted, which represents a clock tick event.
      // This boundary prevents redundant Widget updates 10 times a second.
      if (oldNow.second != _now.second) {
        notifyListeners();
      }
    });
  }

  /// Cancels the background timer when the controller is destroyed
  /// to prevent leaks.
  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
