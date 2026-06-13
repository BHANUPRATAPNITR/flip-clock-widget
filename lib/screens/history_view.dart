import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/config.dart';
import '../core/theme.dart';
import '../core/logger.dart';
import '../services/storage.dart';
import '../services/window.dart';

class HistoryView extends StatefulWidget {
  const HistoryView({super.key});

  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  late AppConfig _config;
  StreamSubscription<FileSystemEvent>? _fileSubscription;
  int? _hoveredBarIndex;
  Offset _mousePos = Offset.zero;

  @override
  void initState() {
    super.initState();
    _config = StorageService.loadConfig();
    _startFileWatcher();
    
    // Set window properties for standalone history window
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WindowService.setWindowSize(760, 480);
    });
  }

  void _startFileWatcher() {
    try {
      final configPath = '${Platform.environment['HOME'] ?? '/home/bhanupratap'}/.config/flip-clock/config.json';
      final file = File(configPath);
      if (file.existsSync()) {
        _fileSubscription = file.watch().listen((event) {
          if (event.type == FileSystemEvent.modify) {
            // Wait slightly for file to finalize writing
            Future.delayed(const Duration(milliseconds: 50), () {
              if (mounted) {
                setState(() {
                  _config = StorageService.loadConfig();
                });
              }
            });
          }
        });
      }
    } catch (e) {
      AppLogger.error("Failed to start file watcher in History window: $e");
    }
  }

  @override
  void dispose() {
    _fileSubscription?.cancel();
    super.dispose();
  }

  void _deleteEntry(int index) {
    if (index >= 0 && index < _config.stopwatchHistory.length) {
      _config.stopwatchHistory.removeAt(index);
      StorageService.saveConfig(_config);
      setState(() {});
    }
  }

  void _clearAll() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161616),
        title: const Text("Clear History", style: TextStyle(color: Colors.white)),
        content: const Text("Are you sure you want to clear all stopwatch history records?", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () {
              _config.stopwatchHistory.clear();
              StorageService.saveConfig(_config);
              setState(() {});
              Navigator.pop(context);
            },
            child: const Text("Clear All", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  int _parseDurationToSeconds(String durationStr) {
    try {
      final parts = durationStr.split(':');
      if (parts.length == 3) {
        final hrs = int.parse(parts[0]);
        final mins = int.parse(parts[1]);
        final secs = int.parse(parts[2]);
        return hrs * 3600 + mins * 60 + secs;
      }
    } catch (_) {}
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeConfig.get(_config.theme);
    final history = _config.stopwatchHistory;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onPanStart: (_) => WindowService.startDragging(),
        child: Container(
          decoration: BoxDecoration(
            color: theme.glassBgColor.withOpacity(0.92),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: theme.glassBorderColor.withOpacity(0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 30,
              ),
            ],
          ),
          child: Stack(
            children: [
              Column(
                children: [
                  // Header
                  _buildHeader(theme),
                  
                  // Content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Left Panel: Bar Chart
                          Expanded(
                            flex: 5,
                            child: _buildChartPanel(history, theme),
                          ),
                          const SizedBox(width: 24),
                          // Right Panel: Logs List
                          Expanded(
                            flex: 4,
                            child: _buildLogsPanel(history, theme),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              
              // Floating Tooltip
              if (_hoveredBarIndex != null && _hoveredBarIndex! < history.length)
                _buildTooltip(history[_hoveredBarIndex!], theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeConfig theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, right: 24, top: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart, color: theme.cardTextColor, size: 24),
              const SizedBox(width: 10),
              const Text(
                "Stopwatch History Analytics",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          Row(
            children: [
              TextButton.icon(
                onPressed: _clearAll,
                icon: const Icon(Icons.delete_sweep, color: Colors.redAccent, size: 18),
                label: const Text("Clear All", style: TextStyle(color: Colors.redAccent, fontSize: 13)),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => WindowService.close(),
                icon: const Icon(Icons.close, color: Colors.white70),
                splashRadius: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartPanel(List<StopwatchHistoryEntry> history, ThemeConfig theme) {
    if (history.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.04)),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.query_stats, size: 48, color: Colors.white24),
              SizedBox(height: 12),
              Text(
                "No Session Records Available",
                style: TextStyle(color: Colors.white38, fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }

    // Determine max duration for scaling
    final List<int> durations = history.map((e) => _parseDurationToSeconds(e.time)).toList();
    final int maxDuration = durations.isEmpty ? 1 : durations.reduce((a, b) => a > b ? a : b);
    final int maxScaled = maxDuration == 0 ? 1 : maxDuration;

    // We only display the latest 10 items in the chart to prevent cluttering
    final chartEntriesCount = math.min(history.length, 10);

    return Container(
      padding: const EdgeInsets.only(top: 24, left: 16, right: 16, bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Chart view
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(chartEntriesCount, (idx) {
                // Render from oldest to newest (right to left or vice versa)
                final entryIndex = chartEntriesCount - 1 - idx;
                final entry = history[entryIndex];
                final duration = durations[entryIndex];
                final double percent = duration / maxScaled;

                return Expanded(
                  child: MouseRegion(
                    onEnter: (event) {
                      setState(() {
                        _hoveredBarIndex = entryIndex;
                        _mousePos = event.localPosition;
                      });
                    },
                    onHover: (event) {
                      setState(() {
                        _mousePos = event.localPosition;
                      });
                    },
                    onExit: (_) {
                      setState(() {
                        _hoveredBarIndex = null;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final barHeight = constraints.maxHeight * percent;
                                return Align(
                                  alignment: Alignment.bottomCenter,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    height: math.max(barHeight, 4.0),
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [
                                          theme.cardTextColor.withOpacity(0.2),
                                          theme.cardTextColor,
                                        ],
                                      ),
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                      boxShadow: [
                                        BoxShadow(
                                          color: theme.cardTextColor.withOpacity(0.3),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            entry.name.length > 8 ? '${entry.name.substring(0, 6)}..' : entry.name,
                            style: const TextStyle(color: Colors.white38, fontSize: 10),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsPanel(List<StopwatchHistoryEntry> history, ThemeConfig theme) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.01),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              "HISTORY LOGS (${history.length})",
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: Colors.white38,
              ),
            ),
          ),
          const Divider(height: 1, color: Colors.white10),
          Expanded(
            child: history.isEmpty
                ? const Center(
                    child: Text("Empty log history", style: TextStyle(color: Colors.white24, fontSize: 13)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: history.length,
                    separatorBuilder: (context, index) => Divider(height: 1, color: Colors.white.withOpacity(0.05)),
                    itemBuilder: (context, index) {
                      final entry = history[index];
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        title: Text(
                          entry.name,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          entry.date,
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              entry.time,
                              style: TextStyle(
                                fontFamily: 'ShareTechMono',
                                color: theme.cardTextColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () => _deleteEntry(index),
                              icon: const Icon(Icons.close, color: Colors.redAccent, size: 16),
                              splashRadius: 16,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTooltip(StopwatchHistoryEntry entry, ThemeConfig theme) {
    return Positioned(
      left: _mousePos.dx + 16,
      top: _mousePos.dy + 16,
      child: IgnorePointer(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.cardTextColor.withOpacity(0.2), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.name,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Duration: ${entry.time}",
                    style: TextStyle(color: theme.cardTextColor, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.date,
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


