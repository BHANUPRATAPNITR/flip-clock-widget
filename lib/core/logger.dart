import 'dart:io';

class AppLogger {
  static File? _logFile;

  static void initialize(String projectDir) {
    try {
      _logFile = File('$projectDir/widget.log');
      info("==================================================");
      info("Starting Flutter Flip Clock application...");
      info("==================================================");
    } catch (e) {
      print("Error initializing log file: $e");
    }
  }

  static void info(String message) {
    _log("INFO", message);
  }

  static void debug(String message) {
    _log("DEBUG", message);
  }

  static void warning(String message) {
    _log("WARNING", message);
  }

  static void error(String message) {
    _log("ERROR", message);
  }

  static void _log(String level, String message) {
    final timestamp = DateTime.now().toIso8601String().split('T').join(' ').substring(0, 19);
    final logLine = '[$timestamp] [$level] $message';
    print(logLine);
    try {
      if (_logFile != null) {
        _logFile!.writeAsStringSync('$logLine\n', mode: FileMode.append);
      }
    } catch (e) {
      print("Error writing to log file: $e");
    }
  }
}
