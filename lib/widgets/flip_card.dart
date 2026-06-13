import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../widgets/flip_digit.dart';

class FlipCardGroup extends StatelessWidget {
  final int value;
  final String label;
  final String skin;
  final ThemeConfig theme;
  final bool isInteractive; // true in timer mode (paused) for mouse wheel
  final Function(int offset)? onScroll;

  const FlipCardGroup({
    super.key,
    required this.value,
    required this.label,
    required this.skin,
    required this.theme,
    this.isInteractive = false,
    this.onScroll,
  });

  @override
  Widget build(BuildContext context) {
    final tens = value ~/ 10;
    final ones = value % 10;

    Widget cardRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FlipDigit(value: tens, skin: skin, theme: theme),
        const SizedBox(width: 8),
        FlipDigit(value: ones, skin: skin, theme: theme),
      ],
    );

    if (isInteractive && onScroll != null) {
      cardRow = Listener(
        onPointerSignal: (pointerSignal) {
          if (pointerSignal is PointerScrollEvent) {
            final dy = pointerSignal.scrollDelta.dy;
            if (dy < 0) {
              onScroll!(1); // scroll up -> increase
            } else if (dy > 0) {
              onScroll!(-1); // scroll down -> decrease
            }
          }
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeUpDown,
          child: cardRow,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        cardRow,
        const SizedBox(height: 14),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
            color: theme.dateTextColor.withOpacity(0.65),
          ),
        ),
      ],
    );
  }
}
