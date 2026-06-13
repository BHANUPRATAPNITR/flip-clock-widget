import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/logger.dart';
import 'services/window.dart';
import 'screens/main_view.dart';
import 'screens/history_view.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize log/config directories in ~/.config/flip-clock
  final configDir = '${Platform.environment['HOME'] ?? '/home/bhanupratap'}/.config/flip-clock';
  try {
    Directory(configDir).createSync(recursive: true);
  } catch (e) {
    print("Error creating config directory: $e");
  }
  
  AppLogger.initialize(configDir);

  // Initialize WindowManager properties
  await WindowService.initialize();

  if (args.contains('--history')) {
    runApp(const HistoryApp());
  } else {
    runApp(const FlipClockApp());
  }
}

/// [FlipClockApp] is the root desktop widget application.
/// It encapsulates the Riverpod [ProviderScope] internally to make it self-contained
/// during local testing and deployment, avoiding "No ProviderScope found" errors.
class FlipClockApp extends StatelessWidget {
  const FlipClockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProviderScope(
      child: FlipClockAppContent(),
    );
  }
}

/// [FlipClockAppContent] boots up the [MainView] widget inside the MaterialApp context.
class FlipClockAppContent extends StatelessWidget {
  const FlipClockAppContent({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flip Clock Widget',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const MainView(),
    );
  }
}

/// [HistoryApp] boots up the standalone analytics list and bar chart viewer.
class HistoryApp extends StatelessWidget {
  const HistoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Stopwatch History Analytics',
        theme: ThemeData(
          brightness: Brightness.dark,
          useMaterial3: true,
        ),
        home: const HistoryView(),
      ),
    );
  }
}
