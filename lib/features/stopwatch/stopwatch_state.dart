/// Represents the immutable state of the stopwatch timing engine.
class StopwatchState {
  /// Total seconds elapsed during the active session.
  final int stopwatchElapsedSeconds;

  /// Tracks if the stopwatch is currently ticking.
  final bool stopwatchRunning;

  /// Stores the system timestamp marking the start of the current run segment.
  final DateTime? stopwatchStartTime;

  /// Holds seconds accumulated in prior play segments before pausing.
  final int stopwatchAccumulatedSeconds;

  const StopwatchState({
    this.stopwatchElapsedSeconds = 0,
    this.stopwatchRunning = false,
    this.stopwatchStartTime,
    this.stopwatchAccumulatedSeconds = 0,
  });

  /// Returns a copy of the state with the specified fields modified.
  StopwatchState copyWith({
    int? stopwatchElapsedSeconds,
    bool? stopwatchRunning,
    DateTime? Function()? stopwatchStartTime,
    int? stopwatchAccumulatedSeconds,
  }) {
    return StopwatchState(
      stopwatchElapsedSeconds: stopwatchElapsedSeconds ?? this.stopwatchElapsedSeconds,
      stopwatchRunning: stopwatchRunning ?? this.stopwatchRunning,
      stopwatchStartTime: stopwatchStartTime != null ? stopwatchStartTime() : this.stopwatchStartTime,
      stopwatchAccumulatedSeconds: stopwatchAccumulatedSeconds ?? this.stopwatchAccumulatedSeconds,
    );
  }
}
