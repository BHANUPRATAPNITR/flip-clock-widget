import 'package:flutter/material.dart';
import '../core/theme.dart';

class VerticalSlider extends StatelessWidget {
  final int value;
  final int maxValue;
  final ThemeConfig theme;
  final ValueChanged<int> onChanged;

  const VerticalSlider({
    super.key,
    required this.value,
    required this.maxValue,
    required this.theme,
    required this.onChanged,
  });

  void _handleDragOrTap(Offset localPosition) {
    const double trackHeight = 140.0;
    const double knobRadius = 10.0;
    const double maxTravel = 120.0;

    // localPosition.dy goes from 0.0 (top) to 140.0 (bottom)
    final double yFromBottom = (trackHeight - localPosition.dy) - knobRadius;
    final double clampedY = yFromBottom.clamp(0.0, maxTravel);
    
    final int newValue = ((clampedY / maxTravel) * maxValue).round();
    onChanged(newValue);
  }

  @override
  Widget build(BuildContext context) {
    const double trackHeight = 140.0;
    const double maxTravel = 120.0;
    
    // Compute knob position from bottom
    final double knobBottom = (value / maxValue) * maxTravel;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onVerticalDragUpdate: (details) => _handleDragOrTap(details.localPosition),
        onTapDown: (details) => _handleDragOrTap(details.localPosition),
        child: SizedBox(
          width: 24,
          height: trackHeight,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Track
              Container(
                width: 6,
                height: trackHeight,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.05),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              // Knob
              Positioned(
                bottom: knobBottom,
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: theme.sliderKnobColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: theme.sliderKnobColor.withOpacity(0.5),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
