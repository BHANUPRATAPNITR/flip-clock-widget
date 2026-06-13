import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/providers.dart';
import '../core/theme.dart';

/// [FooterTextWidget] renders the bottom contextual text (Day/Date or active execution status).
/// It conditionally watches providers to prevent unnecessary ticks when in non-clock modes.
class FooterTextWidget extends ConsumerWidget {
  const FooterTextWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch settings provider properties selectively
    final mode = ref.watch(settingsProvider.select((s) => s.mode));
    final themeId = ref.watch(settingsProvider.select((s) => s.theme));
    final theme = ThemeConfig.get(themeId);

    if (mode == "clock") {
      // Watches clock ticks only when clock is active
      final clockTime = ref.watch(clockProvider);
      final formattedDate = DateFormat("EEEE, MMMM d, y").format(clockTime);
      
      return Text(
        formattedDate,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 2.5,
          color: theme.dateTextColor,
        ),
        textAlign: TextAlign.center,
      );
    } else {
      // Watches only the running state of the active stopwatch/timer
      final running = mode == "stopwatch"
          ? ref.watch(stopwatchProvider.select((s) => s.stopwatchRunning))
          : ref.watch(timerProvider.select((s) => s.timerRunning));
          
      return Text(
        "${mode.toUpperCase()} - ${running ? 'RUNNING' : 'PAUSED'}",
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 2.0,
          color: theme.dateTextColor.withOpacity(0.8),
        ),
        textAlign: TextAlign.center,
      );
    }
  }
}
