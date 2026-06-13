import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/config.dart';
import '../core/theme.dart';
import '../core/providers.dart';

/// [SettingsPanel] is a glassmorphic overlay that allows users to customize clock preferences.
///
/// It is implemented as a [ConsumerWidget] to watch [settingsProvider] directly, ensuring that
/// changes to stopwatch timing or clock second ticks do not cause redundant settings rebuilds.
class SettingsPanel extends ConsumerWidget {
  /// Callback function invoked when the user clicks the close icon button.
  final VoidCallback onClose;

  const SettingsPanel({
    super.key,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watches SettingsNotifier directly for configuration changes
    final state = ref.watch(settingsProvider);
    final theme = ThemeConfig.get(state.theme);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: 440,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: theme.glassBgColor.withOpacity(0.92),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: theme.glassBorderColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Settings",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close, color: Colors.white70),
                    splashRadius: 20,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Body (Scrollable settings list)
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Section: Preferences
                      _buildSectionTitle("Preferences"),
                      _buildToggleRow(
                        label: "Lock Position",
                        value: state.locked,
                        onChanged: (val) => ref.read(settingsProvider.notifier).setLocked(val),
                      ),
                      _buildToggleRow(
                        label: "24-Hour Format",
                        value: state.use24h,
                        onChanged: (val) => ref.read(settingsProvider.notifier).setUse24h(val),
                      ),
                      _buildToggleRow(
                        label: "Show Seconds",
                        value: state.showSeconds,
                        onChanged: (val) => ref.read(settingsProvider.notifier).setShowSeconds(val),
                      ),
                      _buildToggleRow(
                        label: "Start on Login",
                        value: state.autostart,
                        onChanged: (val) => ref.read(settingsProvider.notifier).setAutostart(val),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Section: Themes
                      _buildSectionTitle("Themes"),
                      const SizedBox(height: 8),
                      _buildThemeSelector(ref, state),
                      
                      const SizedBox(height: 20),
                      
                      // Section: Card Skins
                      _buildSectionTitle("Card Skins"),
                      const SizedBox(height: 8),
                      _buildSkinSelector(ref, theme, state),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds standardized section headers.
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
          color: Colors.white38,
        ),
      ),
    );
  }

  /// Builds a toggle row with a label and switch control.
  Widget _buildToggleRow({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF87CF3E),
            activeTrackColor: const Color(0x3D87CF3E),
            inactiveThumbColor: Colors.grey[400],
            inactiveTrackColor: Colors.white12,
          ),
        ],
      ),
    );
  }

  /// Builds the theme selection dot palette grid.
  Widget _buildThemeSelector(WidgetRef ref, AppConfig state) {
    final List<Map<String, dynamic>> themes = [
      {"id": "dark", "color": const Color(0xFFFFFFFF), "name": "Sleek Dark"},
      {"id": "mint", "color": const Color(0xFF87CF3E), "name": "Mint Green"},
      {"id": "neon", "color": const Color(0xFF00F0FF), "name": "Cyber Neon"},
      {"id": "amber", "color": const Color(0xFFFF7B00), "name": "Retro Amber"},
      {"id": "sakura", "color": const Color(0xFFFFB7C5), "name": "Sakura Pink"},
      {"id": "forest", "color": const Color(0xFF50C878), "name": "Forest Green"},
      {"id": "cyberpunk", "color": const Color(0xFFF3E300), "name": "Cyberpunk"},
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: themes.map((t) {
        final isSelected = state.theme == t["id"];
        return Tooltip(
          message: t["name"],
          child: GestureDetector(
            onTap: () => ref.read(settingsProvider.notifier).setTheme(t["id"]),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: t["color"],
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(color: Colors.white, width: 2.5)
                      : Border.all(color: Colors.white30, width: 1),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: (t["color"] as Color).withOpacity(0.4),
                            blurRadius: 8,
                            spreadRadius: 1,
                          )
                        ]
                      : null,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Builds the card skins preview and selection grid.
  Widget _buildSkinSelector(WidgetRef ref, ThemeConfig activeTheme, AppConfig state) {
    final List<Map<String, dynamic>> skins = [
      {"id": "retro", "name": "Retro Flip", "preview": Colors.black45},
      {"id": "hologram", "name": "Hologram", "preview": Colors.cyan.withOpacity(0.2)},
      {"id": "nixie", "name": "Nixie Glow", "preview": Colors.orange.withOpacity(0.2)},
      {"id": "minimal", "name": "Minimal", "preview": Colors.grey[800]},
    ];

    return Row(
      children: skins.map((s) {
        final isSelected = state.skin == s["id"];
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: GestureDetector(
              onTap: () => ref.read(settingsProvider.notifier).setSkin(s["id"]),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withOpacity(0.08)
                        : Colors.white.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? activeTheme.cardTextColor.withOpacity(0.6)
                          : Colors.white.withOpacity(0.05),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        height: 24,
                        width: 40,
                        decoration: BoxDecoration(
                          color: s["preview"],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Colors.white12,
                            width: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        s["name"],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : Colors.white54,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
