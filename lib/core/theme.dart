import 'package:flutter/material.dart';

class ThemeConfig {
  final String id;
  final String name;
  final Color cardBgColor;
  final Color cardTextColor;
  final Color glassBgColor;
  final Color glassBorderColor;
  final Color shadowColor;
  final Color shadowGlowColor;
  final Color dateTextColor;
  final Color colonColor;
  final Color sliderKnobColor;

  const ThemeConfig({
    required this.id,
    required this.name,
    required this.cardBgColor,
    required this.cardTextColor,
    required this.glassBgColor,
    required this.glassBorderColor,
    required this.shadowColor,
    required this.shadowGlowColor,
    required this.dateTextColor,
    required this.colonColor,
    required this.sliderKnobColor,
  });

  static const ThemeConfig dark = ThemeConfig(
    id: "dark",
    name: "Sleek Dark",
    cardBgColor: Color(0xFF121212),
    cardTextColor: Color(0xFFFFFFFF),
    glassBgColor: Color(0xE00F0F0F), // rgba(15, 15, 15, 0.88)
    glassBorderColor: Color(0x14FFFFFF), // rgba(255, 255, 255, 0.08)
    shadowColor: Color(0xD9000000), // rgba(0, 0, 0, 0.85)
    shadowGlowColor: Color(0x0DFFFFFF), // rgba(255, 255, 255, 0.05)
    dateTextColor: Color(0xFFE0E0E0),
    colonColor: Color(0xFFFFFFFF),
    sliderKnobColor: Color(0xFFFFFFFF),
  );

  static const ThemeConfig mint = ThemeConfig(
    id: "mint",
    name: "Mint Green",
    cardBgColor: Color(0xFF131A21), // HSL(215, 24%, 10%)
    cardTextColor: Color(0xFF87CF3E), // Linux Mint bright green
    glassBgColor: Color(0xE0101A14), // rgba(16, 26, 20, 0.88)
    glassBorderColor: Color(0x2E87CF3E), // rgba(135, 207, 62, 0.18)
    shadowColor: Color(0xA6000000), // rgba(0, 0, 0, 0.65)
    shadowGlowColor: Color(0x5987CF3E), // rgba(135, 207, 62, 0.35)
    dateTextColor: Color(0xFFB5F573),
    colonColor: Color(0xFF87CF3E),
    sliderKnobColor: Color(0xFF87CF3E),
  );

  static const ThemeConfig sakura = ThemeConfig(
    id: "sakura",
    name: "Sakura Pink",
    cardBgColor: Color(0xFF191013), // HSL(340, 20%, 8%)
    cardTextColor: Color(0xFFFFB7C5),
    glassBgColor: Color(0xE01C0E12), // rgba(28, 14, 18, 0.88)
    glassBorderColor: Color(0x33FFB7C5), // rgba(255, 183, 197, 0.2)
    shadowColor: Color(0xB3000000), // rgba(0, 0, 0, 0.7)
    shadowGlowColor: Color(0x59FFB7C5), // rgba(255, 183, 197, 0.35)
    dateTextColor: Color(0xFFFFD0D8),
    colonColor: Color(0xFFFFB7C5),
    sliderKnobColor: Color(0xFFFFB7C5),
  );

  static const ThemeConfig forest = ThemeConfig(
    id: "forest",
    name: "Forest Green",
    cardBgColor: Color(0xFF0F1511), // HSL(140, 18%, 7%)
    cardTextColor: Color(0xFF50C878),
    glassBgColor: Color(0xE00C1810), // rgba(12, 24, 16, 0.88)
    glassBorderColor: Color(0x3350C878), // rgba(80, 200, 120, 0.2)
    shadowColor: Color(0xA6000000), // rgba(0, 0, 0, 0.65)
    shadowGlowColor: Color(0x5950C878), // rgba(80, 200, 120, 0.35)
    dateTextColor: Color(0xFF82E39F),
    colonColor: Color(0xFF50C878),
    sliderKnobColor: Color(0xFF50C878),
  );

  static const ThemeConfig cyberpunk = ThemeConfig(
    id: "cyberpunk",
    name: "Cyberpunk Yellow",
    cardBgColor: Color(0xFF0C0C00),
    cardTextColor: Color(0xFFF3E300),
    glassBgColor: Color(0xE0121202), // rgba(18, 18, 2, 0.88)
    glassBorderColor: Color(0x40F3E300), // rgba(243, 227, 0, 0.25)
    shadowColor: Color(0xD9000000), // rgba(0, 0, 0, 0.85)
    shadowGlowColor: Color(0x73F3E300), // rgba(243, 227, 0, 0.45)
    dateTextColor: Color(0xFFFFFFAA),
    colonColor: Color(0xFFF3E300),
    sliderKnobColor: Color(0xFFF3E300),
  );

  static const ThemeConfig neon = ThemeConfig(
    id: "neon",
    name: "Cyber Neon",
    cardBgColor: Color(0xFF0F0B14), // HSL(280, 30%, 6%)
    cardTextColor: Color(0xFF00F0FF), // Cyan digits
    glassBgColor: Color(0xE00C0414), // rgba(12, 4, 20, 0.88)
    glassBorderColor: Color(0x3300F0FF), // rgba(0, 240, 255, 0.2)
    shadowColor: Color(0xCC000000), // rgba(0, 0, 0, 0.8)
    shadowGlowColor: Color(0x73FF007F), // Hot pink glow: rgba(255, 0, 127, 0.45)
    dateTextColor: Color(0xFFFF55A3),
    colonColor: Color(0xFF00F0FF),
    sliderKnobColor: Color(0xFF00F0FF),
  );

  static const ThemeConfig amber = ThemeConfig(
    id: "amber",
    name: "Retro Amber",
    cardBgColor: Color(0xFF1C0E02),
    cardTextColor: Color(0xFFFF7B00), // Nixie amber orange
    glassBgColor: Color(0xE0160A02), // rgba(22, 10, 2, 0.88)
    glassBorderColor: Color(0x29FF7B00), // rgba(255, 123, 0, 0.16)
    shadowColor: Color(0xC0000000), // rgba(0, 0, 0, 0.75)
    shadowGlowColor: Color(0x4CFF7B00), // rgba(255, 123, 0, 0.3)
    dateTextColor: Color(0xFFFFB870),
    colonColor: Color(0xFFFF7B00),
    sliderKnobColor: Color(0xFFFF7B00),
  );

  static const Map<String, ThemeConfig> all = {
    "dark": dark,
    "mint": mint,
    "sakura": sakura,
    "forest": forest,
    "cyberpunk": cyberpunk,
    "neon": neon,
    "amber": amber,
  };

  static ThemeConfig get(String themeId) {
    return all[themeId] ?? dark;
  }
}
