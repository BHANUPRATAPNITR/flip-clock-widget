import 'dart:convert';
import 'dart:io';
import '../core/config.dart';
import '../core/logger.dart';

class StorageService {
  static final String _standardPath = 
      '${Platform.environment['HOME'] ?? '/home/bhanupratap'}/.config/flip-clock/config.json';
  static final String _fallbackPath = 
      '/home/bhanupratap/.gemini/antigravity/scratch/flip-clock/config.json';

  static AppConfig loadConfig() {
    AppLogger.info("Attempting to load configuration settings...");
    File file = File(_standardPath);
    
    if (!file.existsSync()) {
      AppLogger.info("Config not found at standard path $_standardPath, checking fallback path $_fallbackPath...");
      file = File(_fallbackPath);
    }

    if (file.existsSync()) {
      try {
        final content = file.readAsStringSync();
        final jsonMap = json.decode(content) as Map<String, dynamic>;
        AppLogger.info("Configuration settings loaded successfully.");
        return AppConfig.fromJson(jsonMap);
      } catch (e) {
        AppLogger.error("Failed to parse config file: $e. Using default config.");
      }
    } else {
      AppLogger.warning("Configuration file not found. Using default config.");
    }
    return AppConfig.defaultConfig();
  }

  static void saveConfig(AppConfig config) {
    try {
      AppLogger.info("Saving configurations to config.json...");
      final file = File(_standardPath);
      if (!file.parent.existsSync()) {
        file.parent.createSync(recursive: true);
      }
      final encoder = const JsonEncoder.withIndent('  ');
      file.writeAsStringSync(encoder.convert(config.toJson()));
      AppLogger.info("Configurations saved successfully to $_standardPath.");
    } catch (e) {
      AppLogger.error("Error saving configurations to file: $e");
    }
  }
}
