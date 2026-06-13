import 'dart:async';
import 'package:flutter/material.dart';
import '../settings/settings_controller.dart';

class ClockController extends ChangeNotifier {
  final SettingsController settings;
  DateTime _now = DateTime.now();
  Timer? _ticker;

  ClockController(this.settings) {
    _startTicker();
  }

  DateTime get now => _now;

  void _startTicker() {
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      final oldNow = _now;
      _now = DateTime.now();
      
      // Notify when the second changes
      if (oldNow.second != _now.second) {
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
