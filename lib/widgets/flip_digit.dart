import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';

class FlipDigit extends StatefulWidget {
  final int value;
  final String skin;
  final ThemeConfig theme;

  const FlipDigit({
    super.key,
    required this.value,
    required this.skin,
    required this.theme,
  });

  @override
  State<FlipDigit> createState() => _FlipDigitState();
}

class _FlipDigitState extends State<FlipDigit> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _prevValue = 0;
  int _currentValue = 0;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.value;
    _prevValue = widget.value;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 580),
    );
  }

  @override
  void didUpdateWidget(FlipDigit oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _currentValue) {
      setState(() {
        _prevValue = _currentValue;
        _currentValue = widget.value;
      });
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final val = _controller.value;
        if (val == 0.0 || val == 1.0) {
          return _buildStaticCard(_currentValue);
        }
        
        return SizedBox(
          width: 96,
          height: 140,
          child: Stack(
            children: [
              // Bottom-back: New bottom half
              Positioned.fill(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    heightFactor: 0.5,
                    alignment: Alignment.bottomCenter,
                    child: _buildCardHalf(_currentValue, isTop: false),
                  ),
                ),
              ),
              // Top-back: New top half
              Positioned.fill(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: FractionallySizedBox(
                    heightFactor: 0.5,
                    alignment: Alignment.topCenter,
                    child: _buildCardHalf(_currentValue, isTop: true),
                  ),
                ),
              ),
              
              // Top-front/Bottom-front folding logic
              if (val <= 0.5)
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: FractionallySizedBox(
                      heightFactor: 0.5,
                      alignment: Alignment.topCenter,
                      child: Transform(
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.003)
                          ..rotateX(-val * math.pi),
                        alignment: Alignment.bottomCenter,
                        child: _buildCardHalf(_prevValue, isTop: true),
                      ),
                    ),
                  ),
                )
              else
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      heightFactor: 0.5,
                      alignment: Alignment.bottomCenter,
                      child: Transform(
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.003)
                          ..rotateX((1.0 - val) * math.pi),
                        alignment: Alignment.topCenter,
                        child: _buildCardHalf(_currentValue, isTop: false),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStaticCard(int val) {
    return SizedBox(
      width: 96,
      height: 140,
      child: Stack(
        children: [
          // Background top half
          Positioned.fill(
            child: Align(
              alignment: Alignment.topCenter,
              child: FractionallySizedBox(
                heightFactor: 0.5,
                alignment: Alignment.topCenter,
                child: _buildCardHalf(val, isTop: true),
              ),
            ),
          ),
          // Background bottom half
          Positioned.fill(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: 0.5,
                alignment: Alignment.bottomCenter,
                child: _buildCardHalf(val, isTop: false),
              ),
            ),
          ),
          // Horizontal splitter line (for Retro Flip/Nixie/etc)
          if (widget.skin != "minimal")
            Positioned(
              left: 0,
              right: 0,
              top: 69,
              height: 2,
              child: Container(
                color: Colors.black.withOpacity(0.45),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCardHalf(int val, {required bool isTop}) {
    // Skin decorations
    BoxDecoration decoration;
    TextStyle textStyle;

    final isNixie = widget.skin == "nixie";
    final isHologram = widget.skin == "hologram";
    final isMinimal = widget.skin == "minimal";

    // Build TextStyle based on Skin
    final fontFn = isNixie ? GoogleFonts.shareTechMono : GoogleFonts.outfit;
    
    textStyle = fontFn(
      fontSize: 105,
      fontWeight: isNixie ? FontWeight.normal : FontWeight.w800,
      color: isNixie ? const Color(0xFFFF7B00) : widget.theme.cardTextColor,
      shadows: isNixie 
          ? [
              const Shadow(
                color: Color(0x8CFF7B00),
                blurRadius: 12,
              ),
            ]
          : isHologram 
              ? [
                  Shadow(
                    color: widget.theme.cardTextColor.withOpacity(0.5),
                    blurRadius: 8,
                  ),
                ]
              : [
                  Shadow(
                    color: widget.theme.shadowGlowColor.withOpacity(0.2),
                    blurRadius: 6,
                  ),
                ],
    );

    // Build decoration based on Skin
    if (isMinimal) {
      decoration = BoxDecoration(
        color: widget.theme.cardBgColor,
        borderRadius: isTop
            ? const BorderRadius.vertical(top: Radius.circular(14))
            : const BorderRadius.vertical(bottom: Radius.circular(14)),
      );
    } else if (isHologram) {
      decoration = BoxDecoration(
        color: widget.theme.cardBgColor.withOpacity(0.6),
        border: Border.all(
          color: widget.theme.cardTextColor.withOpacity(0.35),
          width: 1.5,
        ),
        borderRadius: isTop
            ? const BorderRadius.vertical(top: Radius.circular(14))
            : const BorderRadius.vertical(bottom: Radius.circular(14)),
        boxShadow: [
          BoxShadow(
            color: widget.theme.cardTextColor.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: -2,
          ),
        ],
      );
    } else if (isNixie) {
      decoration = BoxDecoration(
        color: const Color(0x3D1C0E02), // transparent glass Nixie body
        border: Border.all(
          color: const Color(0x29FF7B00),
          width: 1,
        ),
        borderRadius: isTop
            ? const BorderRadius.vertical(top: Radius.circular(14))
            : const BorderRadius.vertical(bottom: Radius.circular(14)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1CFF7B00),
            blurRadius: 8,
          ),
        ],
      );
    } else {
      // Retro Flip
      decoration = BoxDecoration(
        color: widget.theme.cardBgColor,
        borderRadius: isTop
            ? const BorderRadius.vertical(top: Radius.circular(14))
            : const BorderRadius.vertical(bottom: Radius.circular(14)),
        boxShadow: [
          BoxShadow(
            color: widget.theme.shadowColor,
            blurRadius: 12,
            spreadRadius: -3,
          ),
        ],
      );
    }

    return Container(
      decoration: decoration,
      clipBehavior: Clip.antiAlias,
      alignment: isTop ? Alignment.topCenter : Alignment.bottomCenter,
      child: SizedBox(
        width: 96,
        height: 140,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              // Position text correctly so top half displays upper part, bottom half displays lower part
              top: isTop ? 0 : -70,
              child: SizedBox(
                width: 96,
                height: 140,
                child: Center(
                  child: Text(
                    val.toString(),
                    style: textStyle,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
