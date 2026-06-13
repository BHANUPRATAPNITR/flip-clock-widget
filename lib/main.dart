import 'dart:io';
import 'package:flutter/material.dart';
import 'core/logger.dart';
import 'state/clock_state.dart';
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

class FlipClockApp extends StatefulWidget {
  const FlipClockApp({super.key});

  @override
  State<FlipClockApp> createState() => _FlipClockAppState();
}

class _FlipClockAppState extends State<FlipClockApp> {
  late ClockState _state;

  @override
  void initState() {
    super.initState();
    _state = ClockState();
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flip Clock Widget',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: ListenableBuilder(
        listenable: _state,
        builder: (context, child) {
          return MainView(state: _state);
        },
      ),
    );
  }
}

class HistoryApp extends StatelessWidget {
  const HistoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Stopwatch History Analytics',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const HistoryView(),
    );
  }
}
