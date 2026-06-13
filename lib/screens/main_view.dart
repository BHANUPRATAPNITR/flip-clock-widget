import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../core/providers.dart';
import '../core/config.dart';
import '../features/stopwatch/stopwatch_state.dart';
import '../features/timer/timer_state.dart';
import '../services/window.dart';
import '../widgets/window_controls.dart';
import '../widgets/flip_card.dart';
import '../widgets/vertical_slider.dart';
import '../widgets/settings_panel.dart';
import '../core/logger.dart';

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

  void _launchHistoryWindow() {
    try {
      final exe = Platform.resolvedExecutable;
      Process.start(exe, ['--history']);
      AppLogger.info("Launched standalone History Analytics process.");
    } catch (e) {
      AppLogger.error("Failed to launch history standalone process: $e");
    }
  }

  void _switchMode(String newMode, AppConfig settingsState, TimerState timerState) {
    if (settingsState.mode == newMode) return;
    if (newMode != "timer" && timerState.timerAlertActive) {
      ref.read(timerProvider.notifier).silenceAlert();
    }
    ref.read(settingsProvider.notifier).switchMode(newMode);
  }

  @override
  Widget build(BuildContext context) {
    final settingsState = ref.watch(settingsProvider);
    final clockState = ref.watch(clockProvider);
    final stopwatchState = ref.watch(stopwatchProvider);
    final timerState = ref.watch(timerProvider);
    
    final theme = ThemeConfig.get(settingsState.theme);

    // Update label text if changed externally and not currently focused
    if (!_labelFocusNode.hasFocus && _labelController.text != settingsState.label) {
      _labelController.text = settingsState.label;
    }
    
    // Manage alarm animation status
    if (timerState.timerAlertActive) {
      if (!_alarmAnimationController!.isAnimating) {
        _alarmAnimationController!.forward();
      }
    } else {
      if (_alarmAnimationController!.isAnimating) {
        _alarmAnimationController!.stop();
        _alarmAnimationController!.reset();
      }
    }

    // Determine hour/min/sec values based on current active mode
    int displayHours = 0;
    int displayMinutes = 0;
    int displaySeconds = 0;

    if (settingsState.mode == "clock") {
      final hourVal = settingsState.use24h ? clockState.hour : (clockState.hour % 12 == 0 ? 12 : clockState.hour % 12);
      displayHours = hourVal;
      displayMinutes = clockState.minute;
      displaySeconds = clockState.second;
    } else if (settingsState.mode == "stopwatch") {
      final totalSecs = stopwatchState.stopwatchElapsedSeconds;
      displayHours = totalSecs ~/ 3600;
      displayMinutes = (totalSecs % 3600) ~/ 60;
      displaySeconds = totalSecs % 60;
    } else if (settingsState.mode == "timer") {
      final totalSecs = timerState.timerRemainingSeconds;
      displayHours = totalSecs ~/ 3600;
      displayMinutes = (totalSecs % 3600) ~/ 60;
      displaySeconds = totalSecs % 60;
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
            if (timerState.timerAlertActive)
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
                if (!settingsState.locked) {
                  // If alarm is active, clicking anywhere silences it
                  if (timerState.timerAlertActive) {
                    ref.read(timerProvider.notifier).silenceAlert();
                  } else {
                    WindowService.startDragging();
                  }
                }
              },
              onTap: () {
                if (timerState.timerAlertActive) {
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
                  final currentBgColor = timerState.timerAlertActive
                      ? Color.lerp(baseBgColor, alertBgColor, alertOpacity)!
                      : baseBgColor;

                  final baseBorderColor = theme.glassBorderColor.withOpacity(0.3);
                  final alertBorderColor = const Color(0xFFE53935).withOpacity(0.45);
                  final currentBorderColor = timerState.timerAlertActive
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
                          color: timerState.timerAlertActive
                              ? const Color(0xFFE53935).withOpacity(0.4 * alertOpacity)
                              : Colors.black.withOpacity(0.4),
                          blurRadius: timerState.timerAlertActive ? 30.0 : 48.0,
                          spreadRadius: timerState.timerAlertActive ? 4.0 : -8.0,
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
                        _buildModeSelector(settingsState, timerState, theme),
                        
                        // Digits display + sliders
                        _buildDigitsContainer(settingsState, timerState, theme, displayHours, displayMinutes, displaySeconds),
                        
                        // Action Controls Bar
                        _buildActionControls(settingsState, stopwatchState, timerState, theme),
                        
                        // Date displays or stopwatch running hint
                        const SizedBox(height: 16),
                        _buildFooterText(settingsState, clockState, stopwatchState, timerState),
                        
                        // Drag Hint
                        _buildDragHint(settingsState),
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

  Widget _buildModeSelector(AppConfig settingsState, TimerState timerState, ThemeConfig theme) {
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
          final isSelected = settingsState.mode == modes[idx];
          return GestureDetector(
            onTap: () {
              _switchMode(modes[idx], settingsState, timerState);
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

  Widget _buildDigitsContainer(
    AppConfig settingsState,
    TimerState timerState,
    ThemeConfig theme,
    int hours,
    int minutes,
    int seconds,
  ) {
    final showSeconds = settingsState.showSeconds || settingsState.mode == "stopwatch" || settingsState.mode == "timer";
    final isTimerPaused = settingsState.mode == "timer" && !timerState.timerRunning;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hours Group + Slider
        Stack(
          clipBehavior: Clip.none,
          children: [
            FlipCardGroup(
              value: hours,
              label: "Hours",
              skin: settingsState.skin,
              theme: theme,
              isInteractive: isTimerPaused,
              onScroll: (dir) => ref.read(timerProvider.notifier).addTimerSeconds(dir * 3600),
            ),
            if (isTimerPaused)
              Positioned(
                right: -28,
                top: 0,
                child: VerticalSlider(
                  value: hours,
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
              value: minutes,
              label: "Minutes",
              skin: settingsState.skin,
              theme: theme,
              isInteractive: isTimerPaused,
              onScroll: (dir) => ref.read(timerProvider.notifier).addTimerSeconds(dir * 60),
            ),
            if (isTimerPaused)
              Positioned(
                right: -28,
                top: 0,
                child: VerticalSlider(
                  value: minutes,
                  maxValue: 59,
                  theme: theme,
                  onChanged: (val) => ref.read(timerProvider.notifier).setTimerMinutes(val),
                ),
              ),
          ],
        ),

        if (showSeconds) ...[
          SizedBox(width: isTimerPaused ? 48 : 32),
          
          // Seconds Group + Slider
          Stack(
            clipBehavior: Clip.none,
            children: [
              FlipCardGroup(
                value: seconds,
                label: "Seconds",
                skin: settingsState.skin,
                theme: theme,
                isInteractive: isTimerPaused,
                onScroll: (dir) => ref.read(timerProvider.notifier).addTimerSeconds(dir * 5),
              ),
              if (isTimerPaused)
                Positioned(
                  right: -28,
                  top: 0,
                  child: VerticalSlider(
                    value: seconds,
                    maxValue: 59,
                    theme: theme,
                    onChanged: (val) => ref.read(timerProvider.notifier).setTimerSecondsValue(val),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildActionControls(
    AppConfig settingsState,
    StopwatchState stopwatchState,
    TimerState timerState,
    ThemeConfig theme,
  ) {
    final isClockMode = settingsState.mode == "clock";
    final isTimer = settingsState.mode == "timer";
    final isStopwatch = settingsState.mode == "stopwatch";
    
    // Controls container fades out in clock mode when not hovered
    final showControls = _isHovered || isTimer || isStopwatch;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: showControls ? 1.0 : 0.0,
      child: Container(
        margin: const EdgeInsets.only(top: 20),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Play/Pause (Stopwatch/Timer)
            if (!isClockMode) ...[
              _buildControlButton(
                icon: (isTimer && timerState.timerRunning) || (isStopwatch && stopwatchState.stopwatchRunning)
                    ? Icons.pause
                    : Icons.play_arrow,
                onPressed: () {
                  if (isTimer) {
                    ref.read(timerProvider.notifier).toggleTimer();
                  } else if (isStopwatch) {
                    ref.read(stopwatchProvider.notifier).toggleStopwatch();
                  }
                },
                tooltip: "Play / Pause",
              ),
              const SizedBox(width: 12),
            ],

            // Record (Stopwatch only)
            if (isStopwatch) ...[
              _buildControlButton(
                icon: Icons.fiber_manual_record,
                onPressed: () {
                  ref.read(stopwatchProvider.notifier).recordStopwatchSession();
                },
                tooltip: "Record Session",
              ),
              const SizedBox(width: 12),
            ],

            // History Logs (Stopwatch only)
            if (isStopwatch) ...[
              _buildControlButton(
                icon: Icons.history,
                onPressed: _launchHistoryWindow,
                tooltip: "History Analytics",
              ),
              const SizedBox(width: 12),
            ],

            // Settings gear
            _buildControlButton(
              icon: Icons.settings,
              onPressed: () => setState(() => _showSettings = true),
              tooltip: "Settings",
            ),

            // Reset (Stopwatch/Timer)
            if (!isClockMode) ...[
              const SizedBox(width: 12),
              _buildControlButton(
                icon: Icons.replay,
                onPressed: () {
                  if (isTimer) {
                    ref.read(timerProvider.notifier).resetTimer();
                  } else if (isStopwatch) {
                    ref.read(stopwatchProvider.notifier).resetStopwatch();
                  }
                },
                tooltip: "Reset",
              ),
            ],

            // Preset Buttons (Timer only)
            if (isTimer) ...[
              const SizedBox(width: 12),
              Container(
                height: 24,
                width: 1,
                color: Colors.white10,
              ),
              const SizedBox(width: 12),
              _buildPresetButton("1m", () => ref.read(timerProvider.notifier).setTimerDuration(60)),
              _buildPresetButton("5m", () => ref.read(timerProvider.notifier).setTimerDuration(300)),
              _buildPresetButton("15m", () => ref.read(timerProvider.notifier).setTimerDuration(900)),
              _buildPresetButton("25m", () => ref.read(timerProvider.notifier).setTimerDuration(1500)),
              _buildPresetButton("60m", () => ref.read(timerProvider.notifier).setTimerDuration(3600)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onPressed,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Icon(icon, size: 16, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildPresetButton(String text, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onPressed,
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooterText(
    AppConfig settingsState,
    DateTime clockState,
    StopwatchState stopwatchState,
    TimerState timerState,
  ) {
    if (settingsState.mode == "clock") {
      final formattedDate = DateFormat("EEEE, MMMM d, y").format(clockState);
      return Text(
        formattedDate,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 2.5,
          color: ThemeConfig.get(settingsState.theme).dateTextColor,
        ),
        textAlign: TextAlign.center,
      );
    } else {
      final running = settingsState.mode == "stopwatch" ? stopwatchState.stopwatchRunning : timerState.timerRunning;
      return Text(
        "${settingsState.mode.toUpperCase()} - ${running ? 'RUNNING' : 'PAUSED'}",
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 2.0,
          color: ThemeConfig.get(settingsState.theme).dateTextColor.withOpacity(0.8),
        ),
        textAlign: TextAlign.center,
      );
    }
  }

  Widget _buildDragHint(AppConfig settingsState) {
    final isLocked = settingsState.locked;
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
