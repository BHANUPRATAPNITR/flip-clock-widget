#!/usr/bin/env python3
import os
import sys
import json
import warnings
import logging
import gi

# Suppress GObject/WebKit deprecation warnings
warnings.filterwarnings("ignore", category=DeprecationWarning)

# Ensure we import GTK3 and WebKit2
gi.require_version('Gtk', '3.0')
gi.require_version('Gdk', '3.0')
gi.require_version('WebKit2', '4.1')
from gi.repository import Gtk, Gdk, WebKit2, GLib

# Import core modular managers
from core.logger import setup_logging
from core.config import ConfigManager
from ui.window import MainWindow
from ui.menu import ContextMenu
from history.analytics import HistoryWindow

class FlipClockWidget:
    def __init__(self):
        setup_logging()
        logging.info("==================================================")
        logging.info("Starting Flip Clock application initialization...")
        logging.info("==================================================")
        
        # Instantiate configurations
        self.config = ConfigManager()
        
        # Windows reference managers
        self.history_window = None
        
        # Instantiate main UI window
        self.main_window = MainWindow(self)
        self.main_window.apply_config()

    def run(self):
        self.main_window.show()
        Gtk.main()

    def run_javascript(self, script):
        self.main_window.run_javascript(script)

    def send_config_to_js(self):
        # Inject current configurations into JS
        self.run_javascript(f"setTheme('{self.config.get('theme')}')")
        self.run_javascript(f"setScale({self.config.get('scale')})")
        self.run_javascript(f"setFormat({str(self.config.get('use_24h')).lower()})")
        self.run_javascript(f"setShowSeconds({str(self.config.get('show_seconds')).lower()})")
        self.run_javascript(f"setLocked({str(self.config.get('locked')).lower()})")
        self.run_javascript(f"setMode('{self.config.get('mode')}')")
        self.run_javascript(f"setLabel({json.dumps(self.config.get('label'))})")
        self.run_javascript(f"setStopwatchHistory({json.dumps(self.config.get('stopwatch_history', []))})")
        self.run_javascript(f"setSkin('{self.config.get('skin', 'retro')}')")
        self.run_javascript(f"setAutostart({str(self.config.get('autostart')).lower()})")
        
        # Trigger JS size calculation
        self.run_javascript("resizeWindow()")

    # --- GTK Context Menu Trigger ---
    def show_context_menu(self, event):
        menu = ContextMenu(self)
        menu.popup(event)

    # --- Mode / Preference updates ---
    def set_mode(self, mode_name):
        self.config.set("mode", mode_name)
        self.config.save_config()
        self.run_javascript(f"setMode('{mode_name}')")

    def toggle_lock(self, val):
        self.config.set("locked", val)
        self.config.save_config()
        self.run_javascript(f"setLocked({str(val).lower()})")
        logging.info(f"[IPC] Position locking toggled to: {val}")

    def toggle_format(self, val):
        self.config.set("use_24h", val)
        self.config.save_config()
        self.run_javascript(f"setFormat({str(val).lower()})")
        GLib.timeout_add(100, lambda: self.run_javascript("resizeWindow()"))
        logging.info(f"[IPC] 24-hour format toggled to: {val}")

    def toggle_seconds(self, val):
        self.config.set("show_seconds", val)
        self.config.save_config()
        self.run_javascript(f"setShowSeconds({str(val).lower()})")
        GLib.timeout_add(100, lambda: self.run_javascript("resizeWindow()"))
        logging.info(f"[IPC] Seconds visibility toggled to: {val}")

    def toggle_always_on_bottom(self, val):
        self.config.set("always_on_bottom", val)
        self.config.save_config()
        self.main_window.window.set_keep_below(val)

    def set_theme(self, theme_name):
        self.config.set("theme", theme_name)
        self.config.save_config()
        self.run_javascript(f"setTheme('{theme_name}')")
        if self.history_window is not None:
            self.history_window.send_history()
        logging.info(f"[IPC] Theme updated to: {theme_name}")

    def set_skin(self, skin_name):
        self.config.set("skin", skin_name)
        self.config.save_config()
        self.run_javascript(f"setSkin('{skin_name}')")
        logging.info(f"[IPC] Skin selected: {skin_name}")

    def set_scale(self, scale_val):
        self.config.set("scale", scale_val)
        self.config.save_config()
        self.run_javascript(f"setScale({scale_val})")
        GLib.timeout_add(100, lambda: self.run_javascript("resizeWindow()"))

    def toggle_autostart(self, val):
        self.config.set("autostart", val)
        self.config.save_config()
        if val:
            self.config.enable_autostart()
        else:
            self.config.disable_autostart()
        self.run_javascript(f"setAutostart({str(val).lower()})")
        logging.info(f"[IPC] Autostart toggled to: {val}")

    # --- WebKit WebView Javascript Callback Handlers ---
    def on_js_ready(self, manager, js_result):
        self.send_config_to_js()
        if "--benchmark" in sys.argv:
            self.start_benchmark_mode()

    def on_js_drag(self, manager, js_result):
        if self.config.get("locked"):
            return
        try:
            data = json.loads(js_result.get_js_value().to_string())
            button = data.get("button", 0)
            x_root = data.get("x", 0)
            y_root = data.get("y", 0)
            timestamp = int(data.get("time", 0))
            self.main_window.window.begin_move_drag(button + 1, x_root, y_root, timestamp)
        except Exception as e:
            logging.error(f"Error handling drag message: {e}")

    def on_js_resize(self, manager, js_result):
        try:
            data = json.loads(js_result.get_js_value().to_string())
            width = int(data.get("width", 300))
            height = int(data.get("height", 150))
            pad_w = 16
            pad_h = 16
            self.main_window.webview.set_size_request(width + pad_w, height + pad_h)
            self.main_window.window.resize(width + pad_w, height + pad_h)
        except Exception as e:
            logging.error(f"Error handling resize message: {e}")

    def on_js_notify(self, manager, js_result):
        try:
            data = json.loads(js_result.get_js_value().to_string())
            title = data.get("title", "Timer Alert")
            body = data.get("body", "Timer Completed!")
            os.system(f'notify-send -t 6000 -a "Flip Clock" "{title}" "{body}" -i alarm-clock')
        except Exception as e:
            logging.error(f"Error triggering system notification: {e}")

    def on_js_update_label(self, manager, js_result):
        try:
            text = js_result.get_js_value().to_string()
            try:
                text = json.loads(text)
            except Exception:
                pass
            if self.config.get("label") != text:
                self.config.set("label", text)
                self.config.save_config()
        except Exception as e:
            logging.error(f"Error saving label update: {e}")

    def on_js_update_mode(self, manager, js_result):
        try:
            mode_name = js_result.get_js_value().to_string()
            try:
                mode_name = json.loads(mode_name)
            except Exception:
                pass
            if self.config.get("mode") != mode_name:
                self.config.set("mode", mode_name)
                self.config.save_config()
        except Exception as e:
            logging.error(f"Error saving mode update: {e}")

    def on_js_update_skin(self, manager, js_result):
        try:
            skin_name = js_result.get_js_value().to_string()
            try:
                skin_name = json.loads(skin_name)
            except Exception:
                pass
            if self.config.get("skin") != skin_name:
                self.config.set("skin", skin_name)
                self.config.save_config()
                logging.info(f"Card skin updated to: {skin_name}")
                self.run_javascript(f"setSkin('{skin_name}')")
        except Exception as e:
            logging.error(f"Error saving skin update from JS: {e}")

    def on_js_window_control(self, manager, js_result):
        try:
            data = json.loads(js_result.get_js_value().to_string())
            action = data.get("action")
            if action == "minimize":
                self.main_window.window.iconify()
            elif action == "maximize":
                if self.main_window.window.is_maximized():
                    self.main_window.window.unmaximize()
                else:
                    self.main_window.window.maximize()
            elif action == "close":
                Gtk.main_quit()
            elif action == "toggle_lock":
                val = bool(data.get("value", False))
                self.toggle_lock(val)
            elif action == "toggle_format":
                val = bool(data.get("value", True))
                self.toggle_format(val)
            elif action == "toggle_seconds":
                val = bool(data.get("value", True))
                self.toggle_seconds(val)
            elif action == "toggle_autostart":
                val = bool(data.get("value", False))
                self.toggle_autostart(val)
            elif action == "toggle_theme":
                theme_name = data.get("value")
                self.set_theme(theme_name)
        except Exception as e:
            logging.error(f"Error handling window control: {e}")

    def on_js_update_history(self, manager, js_result):
        try:
            history_data = js_result.get_js_value().to_string()
            try:
                history_data = json.loads(history_data)
            except Exception:
                pass
            self.config.set("stopwatch_history", history_data)
            self.config.save_config()
            
            # Sync to main window JS
            self.run_javascript(f"setStopwatchHistory({json.dumps(history_data)})")
            
            # Sync to history window if active
            if self.history_window is not None:
                self.history_window.send_history()
        except Exception as e:
            logging.error(f"Error saving history update: {e}")

    def on_js_show_history(self, manager, js_result):
        logging.info("[IPC] Received request to show history window.")
        if self.history_window is None:
            self.history_window = HistoryWindow(self)
        self.history_window.show()

    def on_history_window_closed(self):
        self.history_window = None

    def on_js_log(self, manager, js_result):
        try:
            data_str = js_result.get_js_value().to_string()
            data = json.loads(data_str)
            level = data.get("level", "INFO").upper()
            msg = data.get("message", "")
            window_src = data.get("source", "main")
            
            log_func = logging.info
            if level == "DEBUG":
                log_func = logging.debug
            elif level == "WARNING":
                log_func = logging.warning
            elif level == "ERROR":
                log_func = logging.error
                
            log_func(f"[JS] [{window_src}] {msg}")
        except Exception as e:
            try:
                msg = js_result.get_js_value().to_string()
                logging.info(f"[JS] [raw] {msg}")
            except Exception:
                logging.error(f"Error processing JS message logger callback: {e}")

    # --- Automated Benchmark Mode ---
    def start_benchmark_mode(self):
        print("[Benchmark] Automated testing suite initiated...")
        self.benchmark_step = 0
        GLib.timeout_add(1000, self.run_benchmark_step)

    def run_benchmark_step(self):
        self.benchmark_step += 1
        step = self.benchmark_step
        
        if step == 1:
            print("[Benchmark] Step 1: Switching to Clock Mode (Idle Phase)")
            self.set_mode("clock")
        elif step == 5:
            print("[Benchmark] Step 2: Switching to Stopwatch Mode")
            self.set_mode("stopwatch")
        elif step == 6:
            print("[Benchmark] Step 3: Starting Stopwatch")
            self.run_javascript("toggleTimerState()")
        elif step == 8:
            print("[Benchmark] Step 4: Pausing Stopwatch")
            self.run_javascript("toggleTimerState()")
        elif step == 9:
            print("[Benchmark] Step 5: Switching to Countdown Timer Mode")
            self.set_mode("timer")
        elif step == 10:
            print("[Benchmark] Step 6: Setting Timer Preset (5m)")
            self.run_javascript("setTimerDuration(5)")
        elif step == 11:
            print("[Benchmark] Step 7: Starting Countdown Timer")
            self.run_javascript("toggleTimerState()")
        elif step == 13:
            print("[Benchmark] Step 8: Pausing Countdown Timer")
            self.run_javascript("toggleTimerState()")
        elif step == 14:
            print("[Benchmark] Step 9: Resetting Countdown Timer")
            self.run_javascript("resetTimerState()")
        elif step == 15:
            print("[Benchmark] Step 10: Toggling seconds setting")
            self.toggle_seconds(False)
        elif step == 16:
            print("[Benchmark] Step 11: Simulating window move/resize bounds changes")
            self.main_window.window.move(self.config.get("x") + 10, self.config.get("y") + 10)
        elif step == 19:
            print("[Benchmark] Test suite completed. Exiting...")
            Gtk.main_quit()
            return False
            
        return True

if __name__ == "__main__":
    # Ensure current directory matches script location for relative assets loading
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    widget = FlipClockWidget()
    widget.run()
