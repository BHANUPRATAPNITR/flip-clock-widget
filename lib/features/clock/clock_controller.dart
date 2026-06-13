import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// [ClockNotifier] tracks the current system time and updates its [DateTime] state
/// on second changes as a Riverpod [Notifier].
class ClockNotifier extends Notifier<DateTime> {
  /// Periodic timer checking system time shifts.
  Timer? _ticker;

  @override
  DateTime build() {
    // Start background ticker
    _startTicker();

    // Clean up timer resource on provider dispose
    ref.onDispose(() {
      _ticker?.cancel();
    });

    return DateTime.now();
  }

  /// Starts a periodic timer checking if a whole second boundary has elapsed.
  /// If the current second differs from the active state second, it updates the state.
  void _startTicker() {
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      final oldNow = state;
      final newNow = DateTime.now();
      
      if (oldNow.second != newNow.second) {
        state = newNow;
      }
    });
  }
}
