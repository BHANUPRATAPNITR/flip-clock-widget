class AppConfig {
  double x;
  double y;
  bool locked;
  double scale;
  bool use24h;
  bool showSeconds;
  String theme;
  bool alwaysOnBottom;
  bool autostart;
  String mode;
  String label;
  String skin;
  List<StopwatchHistoryEntry> stopwatchHistory;

  AppConfig({
    this.x = 200.0,
    this.y = 200.0,
    this.locked = false,
    this.scale = 1.0,
    this.use24h = true,
    this.showSeconds = true,
    this.theme = "dark",
    this.alwaysOnBottom = true,
    this.autostart = false,
    this.mode = "clock",
    this.label = "",
    this.skin = "retro",
    required this.stopwatchHistory,
  });

  factory AppConfig.defaultConfig() {
    return AppConfig(
      stopwatchHistory: [],
    );
  }

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    var historyList = json['stopwatch_history'] as List? ?? [];
    List<StopwatchHistoryEntry> history = historyList
        .map((e) => StopwatchHistoryEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return AppConfig(
      x: (json['x'] as num?)?.toDouble() ?? 200.0,
      y: (json['y'] as num?)?.toDouble() ?? 200.0,
      locked: json['locked'] as bool? ?? false,
      scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
      use24h: json['use_24h'] as bool? ?? true,
      showSeconds: json['show_seconds'] as bool? ?? true,
      theme: json['theme'] as String? ?? "dark",
      alwaysOnBottom: json['always_on_bottom'] as bool? ?? true,
      autostart: json['autostart'] as bool? ?? false,
      mode: json['mode'] as String? ?? "clock",
      label: json['label'] as String? ?? "",
      skin: json['skin'] as String? ?? "retro",
      stopwatchHistory: history,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
      'locked': locked,
      'scale': scale,
      'use_24h': use24h,
      'show_seconds': showSeconds,
      'theme': theme,
      'always_on_bottom': alwaysOnBottom,
      'autostart': autostart,
      'mode': mode,
      'label': label,
      'skin': skin,
      'stopwatch_history': stopwatchHistory.map((e) => e.toJson()).toList(),
    };
  }
}

class StopwatchHistoryEntry {
  final String name;
  final String time;
  final String date;

  StopwatchHistoryEntry({
    required this.name,
    required this.time,
    required this.date,
  });

  factory StopwatchHistoryEntry.fromJson(Map<String, dynamic> json) {
    return StopwatchHistoryEntry(
      name: json['name'] as String? ?? '',
      time: json['time'] as String? ?? '00:00:00',
      date: json['date'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'time': time,
      'date': date,
    };
  }
}
