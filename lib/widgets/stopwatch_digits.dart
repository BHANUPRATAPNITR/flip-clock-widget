import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../core/providers.dart';
import 'flip_card.dart';

/// [StopwatchDigitsWidget] handles formatting and rendering of elapsed timing cards.
/// It watches [stopwatchProvider] to restrict stopwatch tick scopes.
class StopwatchDigitsWidget extends ConsumerWidget {
  const StopwatchDigitsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch settings and stopwatch states
    final settings = ref.watch(settingsProvider);
    final stopwatch = ref.watch(stopwatchProvider);
    final theme = ThemeConfig.get(settings.theme);

    // Format total elapsed seconds
    final totalSecs = stopwatch.stopwatchElapsedSeconds;
    final displayHours = totalSecs ~/ 3600;
    final displayMinutes = (totalSecs % 3600) ~/ 60;
    final displaySeconds = totalSecs % 60;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hours
        FlipCardGroup(
          value: displayHours,
          label: "Hours",
          skin: settings.skin,
          theme: theme,
          isInteractive: false,
        ),
        const SizedBox(width: 32),
        
        // Minutes
        FlipCardGroup(
          value: displayMinutes,
          label: "Minutes",
          skin: settings.skin,
          theme: theme,
          isInteractive: false,
        ),
        const SizedBox(width: 32),
        
        // Seconds
        FlipCardGroup(
          value: displaySeconds,
          label: "Seconds",
          skin: settings.skin,
          theme: theme,
          isInteractive: false,
        ),
      ],
    );
  }
}
