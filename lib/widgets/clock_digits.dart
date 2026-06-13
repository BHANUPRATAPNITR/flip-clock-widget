import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../core/providers.dart';
import 'flip_card.dart';

/// [ClockDigitsWidget] encapsulates time-display card groups for Hour, Minute, and Second.
/// It watches [clockProvider] and [settingsProvider] to isolate tick rebuilds.
class ClockDigitsWidget extends ConsumerWidget {
  const ClockDigitsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch settings and clock states
    final settings = ref.watch(settingsProvider);
    final clock = ref.watch(clockProvider);
    final theme = ThemeConfig.get(settings.theme);

    // Compute active display hour format
    final displayHours = settings.use24h 
        ? clock.hour 
        : (clock.hour % 12 == 0 ? 12 : clock.hour % 12);
    final displayMinutes = clock.minute;
    final displaySeconds = clock.second;

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
        
        // Seconds
        if (settings.showSeconds) ...[
          const SizedBox(width: 32),
          FlipCardGroup(
            value: displaySeconds,
            label: "Seconds",
            skin: settings.skin,
            theme: theme,
            isInteractive: false,
          ),
        ],
      ],
    );
  }
}
