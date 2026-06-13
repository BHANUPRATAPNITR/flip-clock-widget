import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../core/providers.dart';
import 'flip_card.dart';
import 'vertical_slider.dart';

/// [TimerDigitsWidget] renders the countdown digits and vertical adjustment sliders.
/// It watches [timerProvider] to restrict countdown rebuilds to this widget scope.
class TimerDigitsWidget extends ConsumerWidget {
  const TimerDigitsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch settings and timer states
    final settings = ref.watch(settingsProvider);
    final timer = ref.watch(timerProvider);
    final theme = ThemeConfig.get(settings.theme);

    // Format remaining duration seconds
    final totalSecs = timer.timerRemainingSeconds;
    final displayHours = totalSecs ~/ 3600;
    final displayMinutes = (totalSecs % 3600) ~/ 60;
    final displaySeconds = totalSecs % 60;

    final isTimerPaused = !timer.timerRunning;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hours Group + Slider
        Stack(
          clipBehavior: Clip.none,
          children: [
            FlipCardGroup(
              value: displayHours,
              label: "Hours",
              skin: settings.skin,
              theme: theme,
              isInteractive: isTimerPaused,
              onScroll: (dir) => ref.read(timerProvider.notifier).addTimerSeconds(dir * 3600),
            ),
            if (isTimerPaused)
              Positioned(
                right: -28,
                top: 0,
                child: VerticalSlider(
                  value: displayHours,
                  maxValue: 23,
                  theme: theme,
                  onChanged: (val) => ref.read(timerProvider.notifier).setTimerHours(val),
                ),
              ),
          ],
        ),
        
        // Spacing offset depending on whether sliders are active
        SizedBox(width: isTimerPaused ? 48 : 32),
        
        // Minutes Group + Slider
        Stack(
          clipBehavior: Clip.none,
          children: [
            FlipCardGroup(
              value: displayMinutes,
              label: "Minutes",
              skin: settings.skin,
              theme: theme,
              isInteractive: isTimerPaused,
              onScroll: (dir) => ref.read(timerProvider.notifier).addTimerSeconds(dir * 60),
            ),
            if (isTimerPaused)
              Positioned(
                right: -28,
                top: 0,
                child: VerticalSlider(
                  value: displayMinutes,
                  maxValue: 59,
                  theme: theme,
                  onChanged: (val) => ref.read(timerProvider.notifier).setTimerMinutes(val),
                ),
              ),
          ],
        ),

        SizedBox(width: isTimerPaused ? 48 : 32),
        
        // Seconds Group + Slider
        Stack(
          clipBehavior: Clip.none,
          children: [
            FlipCardGroup(
              value: displaySeconds,
              label: "Seconds",
              skin: settings.skin,
              theme: theme,
              isInteractive: isTimerPaused,
              onScroll: (dir) => ref.read(timerProvider.notifier).addTimerSeconds(dir * 5),
            ),
            if (isTimerPaused)
              Positioned(
                right: -28,
                top: 0,
                child: VerticalSlider(
                  value: displaySeconds,
                  maxValue: 59,
                  theme: theme,
                  onChanged: (val) => ref.read(timerProvider.notifier).setTimerSecondsValue(val),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
