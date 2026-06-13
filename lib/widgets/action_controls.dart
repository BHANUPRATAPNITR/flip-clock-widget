import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers.dart';
import '../core/logger.dart';

/// [ActionControlsWidget] renders action buttons (Play, Pause, Reset, Record, History, Settings).
/// It selectively watches [stopwatchProvider] and [timerProvider] running states to prevent redundant rebuilds.
class ActionControlsWidget extends ConsumerWidget {
  final bool isHovered;
  final VoidCallback onSettingsPressed;

  const ActionControlsWidget({
    super.key,
    required this.isHovered,
    required this.onSettingsPressed,
  });

  void _launchHistoryWindow() {
    try {
      final exe = Platform.resolvedExecutable;
      Process.start(exe, ['--history']);
      AppLogger.info("Launched standalone History Analytics process.");
    } catch (e) {
      AppLogger.error("Failed to launch history standalone process: $e");
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watches specific sub-properties rather than entire states
    final mode = ref.watch(settingsProvider.select((s) => s.mode));
    final stopwatchRunning = ref.watch(stopwatchProvider.select((s) => s.stopwatchRunning));
    final timerRunning = ref.watch(timerProvider.select((s) => s.timerRunning));

    final isClockMode = mode == "clock";
    final isTimer = mode == "timer";
    final isStopwatch = mode == "stopwatch";
    
    // Controls container fades out in clock mode when not hovered
    final showControls = isHovered || isTimer || isStopwatch;

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
                icon: (isTimer && timerRunning) || (isStopwatch && stopwatchRunning)
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
              onPressed: onSettingsPressed,
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
}
