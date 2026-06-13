import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../core/logger.dart';

class WindowService {
  static Future<void> initialize() async {
    try {
      await windowManager.ensureInitialized();
      
      WindowOptions windowOptions = const WindowOptions(
        size: Size(520, 310),
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.hidden,
      );
      
      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        try {
          await windowManager.show();
        } catch (_) {}
        try {
          await windowManager.focus();
        } catch (_) {}
        try {
          await windowManager.setHasShadow(false);
        } catch (_) {}
        try {
          await windowManager.setBackgroundColor(Colors.transparent);
        } catch (_) {}
      });
    } catch (e) {
      AppLogger.error("Error initializing window manager: $e");
    }
  }

  static Future<void> setAlwaysOnBottom(bool value) async {
    try {
      // Note: windowManager does not have setKeepBelow natively in all versions, 
      // but it supports setAlwaysOnBottom / setAlwaysOnTop.
      // Let's use setAlwaysOnBottom / setAlwaysOnTop if supported, or handle always-on-bottom.
      // Wait, is there setAlwaysOnBottom? Let's check, setAlwaysOnTop(false) ensures normal layering,
      // or windowManager.setAlwaysOnBottom() or windowManager.setKeepBelow()?
      // Wait, window_manager package on Linux maps keepBelow to native gtk_window_set_keep_below.
      // Let's see if windowManager has setAlwaysOnBottom or setKeepBelow. Let's look up or use setAlwaysOnBottom.
      // Wait! Let's check windowManager methods. Let's write the methods safely:
      // windowManager.setAlwaysOnBottom(value) or setAlwaysOnTop(value). Let's call them inside a try-catch.
      // On window_manager, the method is `setAlwaysOnTop(bool isAlwaysOnTop)` and `setAlwaysOnBottom(bool isAlwaysOnBottom)`.
      // Let's check if setAlwaysOnBottom is available. Yes, window_manager has setAlwaysOnBottom.
      await windowManager.setAlwaysOnBottom(value);
    } catch (e) {
      AppLogger.error("Failed to set always on bottom: $e");
    }
  }

  static Future<void> setWindowSize(double width, double height) async {
    try {
      await windowManager.setSize(Size(width, height));
    } catch (e) {
      AppLogger.error("Failed to set window size: $e");
    }
  }

  static Future<void> minimize() async {
    await windowManager.minimize();
  }

  static Future<void> maximize() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  static Future<void> close() async {
    await windowManager.close();
  }

  static Future<void> startDragging() async {
    await windowManager.startDragging();
  }
}
