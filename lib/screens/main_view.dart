import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../core/providers.dart';
import '../core/config.dart';
import '../services/window.dart';
import '../widgets/window_controls.dart';
import '../widgets/settings_panel.dart';
import '../widgets/clock_digits.dart';
import '../widgets/stopwatch_digits.dart';
import '../widgets/timer_digits.dart';
import '../widgets/action_controls.dart';
import '../widgets/footer_text.dart';

/// [MainView] represents the main desktop overlay interface of the Flip Clock application.
/// Under the performance optimization refactoring, it only watches structural layout triggers
/// (mode, theme, locked, and alert states) to keep CPU overhead and unnecessary ticks low.
class MainView extends ConsumerStatefulWidget {
  const MainView({super.key});

  @override
  ConsumerState<MainView> createState() => _MainViewState();
}

class _MainViewState extends ConsumerState<MainView> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _showSettings = false;
  late TextEditingController _labelController;
  late FocusNode _labelFocusNode;
  
  // Animation for red flashing alarm
  AnimationController? _alarmAnimationController;

  @override
  void initState() {
    super.initState();
    final config = ref.read(settingsProvider);
    _labelController = TextEditingController(text: config.label);
    _labelFocusNode = FocusNode();
    
    _labelFocusNode.addListener(() {
      if (!_labelFocusNode.hasFocus) {
        ref.read(settingsProvider.notifier).updateLabel(_labelController.text);
      }
    });

    _alarmAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _alarmAnimationController?.reverse();
        } else if (status == AnimationStatus.dismissed) {
          _alarmAnimationController?.forward();
        }
      });
  }

  @override
  void dispose() {
    _labelController.dispose();
    _labelFocusNode.dispose();
    _alarmAnimationController?.dispose();
    super.dispose();
  }

  void _switchMode(String newMode) {
    final mode = ref.read(settingsProvider).mode;
    if (mode == newMode) return;
    
    final timerAlertActive = ref.read(timerProvider).timerAlertActive;
    if (newMode != "timer" && timerAlertActive) {
      ref.read(timerProvider.notifier).silenceAlert();
    }
    ref.read(settingsProvider.notifier).switchMode(newMode);
  }

  @override
  Widget build(BuildContext context) {
    // Watches only specific select parameters for scaffold-level rebuilding
    final mode = ref.watch(settingsProvider.select((s) => s.mode));
    final themeId = ref.watch(settingsProvider.select((s) => s.theme));
    final locked = ref.watch(settingsProvider.select((s) => s.locked));
    final label = ref.watch(settingsProvider.select((s) => s.label));
    
    final timerAlertActive = ref.watch(timerProvider.select((t) => t.timerAlertActive));
    
    final theme = ThemeConfig.get(themeId);

    // Update label text if changed externally and not currently focused
    if (!_labelFocusNode.hasFocus && _labelController.text != label) {
      _labelController.text = label;
    }
    
    // Manage alarm animation status
    if (timerAlertActive) {
      if (!_alarmAnimationController!.isAnimating) {
        _alarmAnimationController!.forward();
      }
    } else {
      if (_alarmAnimationController!.isAnimating) {
        _alarmAnimationController!.stop();
        _alarmAnimationController!.reset();
      }
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Silencer Click Overlay when alert is active
            if (timerAlertActive)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {
                    ref.read(timerProvider.notifier).silenceAlert();
                  },
                  child: Container(
                    color: Colors.transparent,
                  ),
                ),
              ),

            // Main Widget Container
            GestureDetector(
              onPanStart: (_) {
                if (!locked) {
                  // If alarm is active, clicking anywhere silences it
                  if (timerAlertActive) {
                    ref.read(timerProvider.notifier).silenceAlert();
                  } else {
                    WindowService.startDragging();
                  }
                }
              },
              onTap: () {
                if (timerAlertActive) {
                  ref.read(timerProvider.notifier).silenceAlert();
                }
              },
              child: AnimatedBuilder(
                animation: _alarmAnimationController!,
                builder: (context, child) {
                  final alertOpacity = _alarmAnimationController!.value;
                  
                  // Compute flashing alarm color
                  final baseBgColor = theme.glassBgColor.withOpacity(0.88);
                  final alertBgColor = const Color(0xFFE53935).withOpacity(0.16); // red alert
                  final currentBgColor = timerAlertActive
                      ? Color.lerp(baseBgColor, alertBgColor, alertOpacity)!
                      : baseBgColor;

                  final baseBorderColor = theme.glassBorderColor.withOpacity(0.3);
                  final alertBorderColor = const Color(0xFFE53935).withOpacity(0.45);
                  final currentBorderColor = timerAlertActive
                      ? Color.lerp(baseBorderColor, alertBorderColor, alertOpacity)!
                      : baseBorderColor;

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
                    decoration: BoxDecoration(
                      color: currentBgColor,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: currentBorderColor,
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: timerAlertActive
                              ? const Color(0xFFE53935).withOpacity(0.4 * alertOpacity)
                              : Colors.black.withOpacity(0.4),
                          blurRadius: timerAlertActive ? 30.0 : 48.0,
                          spreadRadius: timerAlertActive ? 4.0 : -8.0,
                        ),
                        BoxShadow(
                          color: theme.shadowGlowColor.withOpacity(0.12),
                          blurRadius: 40,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Space for window controls
                        const SizedBox(height: 12),
                        
                        // Text Label Input
                        _buildLabelInput(theme),
                        
                        // Mode Selector Tab Bar
                        _buildModeSelector(mode, theme),
                        
                        // Digits display + sliders
                        _buildActiveDigits(mode),
                        
                        // Action Controls Bar
                        ActionControlsWidget(
                          isHovered: _isHovered,
                          onSettingsPressed: () => setState(() => _showSettings = true),
                        ),
                        
                        // Date displays or stopwatch running hint
                        const SizedBox(height: 16),
                        const FooterTextWidget(),
                        
                        // Drag Hint
                        _buildDragHint(locked),
                      ],
                    ),
                  );
                },
              ),
            ),
            
            // Window control dots overlay (visible on hover)
            Positioned(
              top: 14,
              right: 18,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _isHovered ? 1.0 : 0.0,
                child: const WindowControls(),
              ),
            ),

            // Settings Overlay
            if (_showSettings)
              Positioned.fill(
                child: Center(
                  child: SettingsPanel(
                    onClose: () => setState(() => _showSettings = false),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabelInput(ThemeConfig theme) {
    return Container(
      width: 360,
      margin: const EdgeInsets.only(bottom: 18),
      child: TextField(
        controller: _labelController,
        focusNode: _labelFocusNode,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 2,
          color: Colors.white,
        ),
        decoration: InputDecoration(
          hintText: "WHAT ARE YOU TIMING?",
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.35),
            letterSpacing: 0.5,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          filled: true,
          fillColor: Colors.white.withOpacity(0.03),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.22)),
          ),
        ),
        maxLines: 2,
        minLines: 1,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) {
          _labelFocusNode.unfocus();
        },
      ),
    );
  }

  Widget _buildModeSelector(String mode, ThemeConfig theme) {
    final modes = ["clock", "stopwatch", "timer"];
    final labels = ["Clock", "Stopwatch", "Timer"];

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(modes.length, (idx) {
          final isSelected = mode == modes[idx];
          return GestureDetector(
            onTap: () {
              _switchMode(modes[idx]);
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withOpacity(0.08) : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? Colors.white.withOpacity(0.1) : Colors.transparent,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  labels[idx],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                    color: isSelected ? Colors.white : theme.dateTextColor.withOpacity(0.65),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildActiveDigits(String mode) {
    switch (mode) {
      case "clock":
        return const ClockDigitsWidget();
      case "stopwatch":
        return const StopwatchDigitsWidget();
      case "timer":
        return const TimerDigitsWidget();
      default:
        return const ClockDigitsWidget();
    }
  }

  Widget _buildDragHint(bool isLocked) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(top: 10),
      height: (_isHovered && !isLocked) ? 14 : 0,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: (_isHovered && !isLocked) ? 1.0 : 0.0,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.drag_indicator, size: 12, color: Colors.white38),
            SizedBox(width: 4),
            Text(
              "Hold Super key or drag background to move",
              style: TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
