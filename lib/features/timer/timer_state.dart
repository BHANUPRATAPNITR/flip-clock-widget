/// Represents the immutable state of the countdown timer timing engine.
class TimerState {
  /// Remaining countdown duration in seconds.
  final int timerRemainingSeconds;

  /// Holds the base duration target in seconds. Used during reset.
  final int timerInitialSeconds;

  /// Tracks if the timer is actively counting down.
  final bool timerRunning;

  /// Tracks if the flashing alarm alert UI is active.
  final bool timerAlertActive;

  /// Stores the system timestamp marking when the countdown segment started.
  final DateTime? timerStartTime;

  /// Holds the total seconds elapsed in previous segments before pause.
  final int timerAccumulatedSeconds;

  const TimerState({
    this.timerRemainingSeconds = 300,
    this.timerInitialSeconds = 300,
    this.timerRunning = false,
    this.timerAlertActive = false,
    this.timerStartTime,
    this.timerAccumulatedSeconds = 0,
  });

  /// Returns a copy of the state with the specified fields modified.
  TimerState copyWith({
    int? timerRemainingSeconds,
    int? timerInitialSeconds,
    bool? timerRunning,
    bool? timerAlertActive,
    DateTime? Function()? timerStartTime,
    int? timerAccumulatedSeconds,
  }) {
    return TimerState(
      timerRemainingSeconds: timerRemainingSeconds ?? this.timerRemainingSeconds,
      timerInitialSeconds: timerInitialSeconds ?? this.timerInitialSeconds,
      timerRunning: timerRunning ?? this.timerRunning,
      timerAlertActive: timerAlertActive ?? this.timerAlertActive,
      timerStartTime: timerStartTime != null ? timerStartTime() : this.timerStartTime,
      timerAccumulatedSeconds: timerAccumulatedSeconds ?? this.timerAccumulatedSeconds,
    );
  }
}
