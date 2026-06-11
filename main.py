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

CONFIG_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "config.json")
AUTOSTART_DIR = os.path.expanduser("~/.config/autostart")
AUTOSTART_FILE = os.path.join(AUTOSTART_DIR, "flip-clock.desktop")
LOG_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "widget.log")

def setup_logging():
    logger = logging.getLogger()
    logger.setLevel(logging.DEBUG)
    
    # Format: [Timestamp] [Level] Message
    formatter = logging.Formatter('[%(asctime)s] [%(levelname)s] %(message)s', datefmt='%Y-%m-%d %H:%M:%S')
    
    # File Handler - records everything from DEBUG up
    file_handler = logging.FileHandler(LOG_FILE, mode='a', encoding='utf-8')
    file_handler.setLevel(logging.DEBUG)
    file_handler.setFormatter(formatter)
    logger.addHandler(file_handler)
    
    # Console Handler - outputs INFO and above
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(logging.INFO)
    console_handler.setFormatter(formatter)
    logger.addHandler(console_handler)

setup_logging()
logging.info("==================================================")
logging.info("Starting Flip Clock application initialization...")
logging.info("==================================================")


DEFAULT_CONFIG = {
    "x": 200,
    "y": 200,
    "locked": False,
    "scale": 1.0,
    "use_24h": True,
    "show_seconds": True,
    "theme": "dark",
    "always_on_bottom": True,
    "autostart": False,
    "mode": "clock",
    "label": "",
    "stopwatch_history": [],
    "skin": "retro"
}

class FlipClockWidget:
    def __init__(self):
        logging.info("Initializing FlipClockWidget UI elements...")
        self.save_timeout_id = None
        self.history_window = None
        self.history_webview = None
        self.load_config()
        self.init_ui()
        self.setup_webview()
        self.apply_config_to_window()

    def load_config(self):
        logging.info("Loading config.json settings file...")
        self.config = DEFAULT_CONFIG.copy()
        if os.path.exists(CONFIG_FILE):
            try:
                with open(CONFIG_FILE, "r") as f:
                    saved = json.load(f)
                    self.config.update(saved)
                logging.info("config.json loaded successfully.")
            except Exception as e:
                logging.error(f"Error loading configuration file: {e}")
        else:
            logging.warning("config.json file not found. Falling back to default settings.")
        
        # Verify autostart file actual status matches config
        has_autostart_file = os.path.exists(AUTOSTART_FILE)
        if self.config["autostart"] != has_autostart_file:
            self.config["autostart"] = has_autostart_file

    def save_config(self):
        try:
            logging.info("Saving configurations to config.json...")
            with open(CONFIG_FILE, "w") as f:
                json.dump(self.config, f, indent=2)
            logging.info("Configurations saved successfully.")
        except Exception as e:
            logging.error(f"Error saving configurations: {e}")

    def init_ui(self):
        # Create a Top-Level borderless window
        self.window = Gtk.Window(type=Gtk.WindowType.TOPLEVEL)
        self.window.set_title("Flip Clock Widget")
        self.window.set_keep_below(self.config["always_on_bottom"])
        self.window.set_decorated(False)
        self.window.set_skip_taskbar_hint(True)
        self.window.set_skip_pager_hint(True)
        self.window.set_type_hint(Gdk.WindowTypeHint.UTILITY)
        self.window.set_default_size(1250, 420)

        # Support transparency via RGBA visual
        screen = self.window.get_screen()
        visual = screen.get_rgba_visual()
        if visual and screen.is_composited():
            self.window.set_visual(visual)
        self.window.set_app_paintable(True)

        # Connect window events
        self.window.connect("destroy", Gtk.main_quit)
        self.window.connect("configure-event", self.on_window_configured)

    def setup_webview(self):
        # Setup WebKit Settings to optimize memory and performance
        settings = WebKit2.Settings()
        settings.set_enable_webgl(False)
        settings.set_enable_accelerated_2d_canvas(True)
        
        # Instantiate webview with settings
        self.webview = WebKit2.WebView.new_with_settings(settings)
        
        # Set cache model to DOCUMENT_VIEWER to minimize memory cache footprint
        context = self.webview.get_context()
        if context:
            context.set_cache_model(WebKit2.CacheModel.DOCUMENT_VIEWER)
            
        transparent = Gdk.RGBA(0.0, 0.0, 0.0, 0.0)
        self.webview.set_background_color(transparent)

        # Setup JS message handlers
        manager = self.webview.get_user_content_manager()
        
        manager.register_script_message_handler("drag")
        manager.connect("script-message-received::drag", self.on_js_drag)

        manager.register_script_message_handler("resize")
        manager.connect("script-message-received::resize", self.on_js_resize)

        manager.register_script_message_handler("ready")
        manager.connect("script-message-received::ready", self.on_js_ready)

        manager.register_script_message_handler("notify")
        manager.connect("script-message-received::notify", self.on_js_notify)

        manager.register_script_message_handler("update_label")
        manager.connect("script-message-received::update_label", self.on_js_update_label)

        manager.register_script_message_handler("update_mode")
        manager.connect("script-message-received::update_mode", self.on_js_update_mode)

        manager.register_script_message_handler("window_control")
        manager.connect("script-message-received::window_control", self.on_js_window_control)

        manager.register_script_message_handler("update_history")
        manager.connect("script-message-received::update_history", self.on_js_update_history)

        manager.register_script_message_handler("show_history")
        manager.connect("script-message-received::show_history", self.on_js_show_history)

        # Log bridge for debugging
        manager.register_script_message_handler("log")
        manager.connect("script-message-received::log", self.on_js_log)

        # Skin update handler
        manager.register_script_message_handler("update_skin")
        manager.connect("script-message-received::update_skin", self.on_js_update_skin)

        # Intercept context menu to show native GTK menu instead of browser menu
        self.webview.connect("context-menu", self.on_context_menu)

        # Add WebView to window
        self.window.add(self.webview)

        # Load web page
        html_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "web", "index.html")
        html_uri = "file://" + os.path.abspath(html_path)
        self.webview.load_uri(html_uri)

    def apply_config_to_window(self):
        # Set initial position
        self.window.move(self.config["x"], self.config["y"])
        # Always on bottom
        self.window.set_keep_below(self.config["always_on_bottom"])

    def on_window_configured(self, widget, event):
        # Save position when the window moves
        x, y = self.window.get_position()
        if x != self.config["x"] or y != self.config["y"]:
            self.config["x"] = x
            self.config["y"] = y
            self.queue_save_config()

    def queue_save_config(self):
        if self.save_timeout_id is not None:
            GLib.source_remove(self.save_timeout_id)
        self.save_timeout_id = GLib.timeout_add(1000, self.save_config_timeout)

    def save_config_timeout(self):
        self.save_config()
        self.save_timeout_id = None
        return False

    def on_js_ready(self, manager, js_result):
        # Apply configurations to JavaScript once loaded
        self.send_config_to_js()
        if "--benchmark" in sys.argv:
            self.start_benchmark_mode()

    def start_benchmark_mode(self):
        print("[Benchmark] Automated testing suite initiated...")
        self.benchmark_step = 0
        GLib.timeout_add(1000, self.run_benchmark_step)

    def run_benchmark_step(self):
        self.benchmark_step += 1
        step = self.benchmark_step
        
        if step == 1:
            print("[Benchmark] Step 1: Switching to Clock Mode (Idle Phase)")
            self.set_mode(None, "clock")
        elif step == 5:
            print("[Benchmark] Step 2: Switching to Stopwatch Mode")
            self.set_mode(None, "stopwatch")
        elif step == 6:
            print("[Benchmark] Step 3: Starting Stopwatch")
            self.webview.run_javascript("toggleTimerState()", None, None, None)
        elif step == 8:
            print("[Benchmark] Step 4: Pausing Stopwatch")
            self.webview.run_javascript("toggleTimerState()", None, None, None)
        elif step == 9:
            print("[Benchmark] Step 5: Switching to Countdown Timer Mode")
            self.set_mode(None, "timer")
        elif step == 10:
            print("[Benchmark] Step 6: Setting Timer Preset (5m)")
            self.webview.run_javascript("setTimerDuration(5)", None, None, None)
        elif step == 11:
            print("[Benchmark] Step 7: Starting Countdown Timer")
            self.webview.run_javascript("toggleTimerState()", None, None, None)
        elif step == 13:
            print("[Benchmark] Step 8: Pausing Countdown Timer")
            self.webview.run_javascript("toggleTimerState()", None, None, None)
        elif step == 14:
            print("[Benchmark] Step 9: Resetting Countdown Timer")
            self.webview.run_javascript("resetTimerState()", None, None, None)
        elif step == 15:
            print("[Benchmark] Step 10: Toggling seconds setting")
            # Mimic seconds toggle
            class MockItem:
                def get_active(self): return False
            self.toggle_seconds(MockItem())
        elif step == 16:
            print("[Benchmark] Step 11: Simulating window move/resize bounds changes")
            self.window.move(self.config["x"] + 10, self.config["y"] + 10)
        elif step == 19:
            print("[Benchmark] Test suite completed. Exiting...")
            Gtk.main_quit()
            return False
            
        return True

    def on_js_drag(self, manager, js_result):
        if self.config["locked"]:
            return

        try:
            data = json.loads(js_result.get_js_value().to_string())
            button = data.get("button", 0)
            x_root = data.get("x", 0)
            y_root = data.get("y", 0)
            timestamp = int(data.get("time", 0))

            # Trigger Gtk native window drag
            # button + 1 maps JS button (0: left, 1: middle, 2: right) to Gdk button (1, 2, 3)
            self.window.begin_move_drag(button + 1, x_root, y_root, timestamp)
        except Exception as e:
            print(f"Error handling drag message: {e}")

    def on_js_resize(self, manager, js_result):
        try:
            data = json.loads(js_result.get_js_value().to_string())
            width = int(data.get("width", 300))
            height = int(data.get("height", 150))
            
            # Request new size on webview and resize window to fit
            # We add a small pad to avoid scrolling
            pad_w = 16
            pad_h = 16
            
            self.webview.set_size_request(width + pad_w, height + pad_h)
            self.window.resize(width + pad_w, height + pad_h)
        except Exception as e:
            print(f"Error handling resize message: {e}")

    def on_js_notify(self, manager, js_result):
        try:
            data = json.loads(js_result.get_js_value().to_string())
            title = data.get("title", "Timer Alert")
            body = data.get("body", "Timer Completed!")
            # Trigger native Linux notification
            os.system(f'notify-send -t 6000 -a "Flip Clock" "{title}" "{body}" -i alarm-clock')
        except Exception as e:
            print(f"Error triggering system notification: {e}")

    def on_js_update_label(self, manager, js_result):
        try:
            text = js_result.get_js_value().to_string()
            # If javascript string was serialized as json, we unpack it
            try:
                text = json.loads(text)
            except Exception:
                pass
            if self.config["label"] != text:
                self.config["label"] = text
                self.save_config()
        except Exception as e:
            print(f"Error saving label update: {e}")

    def on_js_update_mode(self, manager, js_result):
        try:
            mode_name = js_result.get_js_value().to_string()
            # If javascript string was serialized as json, we unpack it
            try:
                mode_name = json.loads(mode_name)
            except Exception:
                pass
            if self.config["mode"] != mode_name:
                self.config["mode"] = mode_name
                self.save_config()
        except Exception as e:
            print(f"Error saving mode update: {e}")

    def on_js_update_skin(self, manager, js_result):
        try:
            skin_name = js_result.get_js_value().to_string()
            try:
                skin_name = json.loads(skin_name)
            except Exception:
                pass
            if self.config.get("skin") != skin_name:
                self.config["skin"] = skin_name
                self.save_config()
                logging.info(f"Card skin updated to: {skin_name}")
                # Sync back to main WebView to be safe
                self.webview.run_javascript(f"setSkin('{skin_name}')", None, None, None)
        except Exception as e:
            logging.error(f"Error saving skin update from JS: {e}")

    def on_js_window_control(self, manager, js_result):
        try:
            data = json.loads(js_result.get_js_value().to_string())
            action = data.get("action")
            if action == "minimize":
                self.window.iconify()
            elif action == "maximize":
                if self.window.is_maximized():
                    self.window.unmaximize()
                else:
                    self.window.maximize()
            elif action == "close":
                Gtk.main_quit()
            elif action == "toggle_lock":
                val = bool(data.get("value", False))
                self.config["locked"] = val
                self.save_config()
                self.webview.run_javascript(f"setLocked({str(val).lower()})", None, None, None)
                logging.info(f"[IPC] Position locking toggled to: {val}")
            elif action == "toggle_format":
                val = bool(data.get("value", True))
                self.config["use_24h"] = val
                self.save_config()
                self.webview.run_javascript(f"setFormat({str(val).lower()})", None, None, None)
                logging.info(f"[IPC] 24-hour format toggled to: {val}")
            elif action == "toggle_seconds":
                val = bool(data.get("value", True))
                self.config["show_seconds"] = val
                self.save_config()
                self.webview.run_javascript(f"setShowSeconds({str(val).lower()})", None, None, None)
                logging.info(f"[IPC] Seconds visibility toggled to: {val}")
            elif action == "toggle_autostart":
                val = bool(data.get("value", False))
                self.config["autostart"] = val
                self.save_config()
                if val:
                    self.enable_autostart()
                else:
                    self.disable_autostart()
                logging.info(f"[IPC] Autostart toggled to: {val}")
            elif action == "toggle_theme":
                theme_name = data.get("value")
                self.config["theme"] = theme_name
                self.save_config()
                self.webview.run_javascript(f"setTheme('{theme_name}')", None, None, None)
                if self.history_window is not None and self.history_webview is not None:
                    self.history_webview.run_javascript(f"setTheme('{theme_name}')", None, None, None)
                logging.info(f"[IPC] Theme updated to: {theme_name}")
        except Exception as e:
            logging.error(f"Error handling window control: {e}")

    def on_js_update_history(self, manager, js_result):
        try:
            history_data = js_result.get_js_value().to_string()
            try:
                history_data = json.loads(history_data)
            except Exception:
                pass
            self.config["stopwatch_history"] = history_data
            self.save_config()
            
            # Sync to main window JS
            self.webview.run_javascript(f"setStopwatchHistory({json.dumps(history_data)})", None, None, None)
            
            # Sync to history window JS if open
            if self.history_window is not None and self.history_webview is not None:
                self.history_webview.run_javascript(f"setStopwatchHistory({json.dumps(history_data)})", None, None, None)
        except Exception as e:
            print(f"Error saving history update: {e}")

    def on_js_show_history(self, manager, js_result):
        logging.info("[IPC] Received request to show history window.")
        self.show_history_window()

    def on_js_log(self, manager, js_result):
        """Bridge JavaScript console logs to python standard logging module."""
        try:
            data_str = js_result.get_js_value().to_string()
            data = json.loads(data_str)
            level = data.get("level", "INFO").upper()
            msg = data.get("message", "")
            window_src = data.get("source", "main")
            
            # Map levels to standard logging calls
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

    def show_history_window(self):
        if self.history_window is not None:
            logging.info("Stopwatch History Analytics window already open. Focusing window.")
            self.history_window.present()
            return

        logging.info("Creating Stopwatch History Analytics window container...")
        self.history_window = Gtk.Window(type=Gtk.WindowType.TOPLEVEL)
        self.history_window.set_title("Stopwatch History Analytics")
        self.history_window.set_default_size(760, 480)
        self.history_window.set_position(Gtk.WindowPosition.CENTER)

        # Support transparency
        screen = self.history_window.get_screen()
        visual = screen.get_rgba_visual()
        if visual and screen.is_composited():
            self.history_window.set_visual(visual)
        self.history_window.set_app_paintable(True)

        settings = WebKit2.Settings()
        settings.set_enable_webgl(False)
        settings.set_enable_accelerated_2d_canvas(True)

        self.history_webview = WebKit2.WebView.new_with_settings(settings)
        context = self.history_webview.get_context()
        if context:
            context.set_cache_model(WebKit2.CacheModel.DOCUMENT_VIEWER)
            
        transparent = Gdk.RGBA(0.0, 0.0, 0.0, 0.0)
        self.history_webview.set_background_color(transparent)

        # Register message handlers for the history window
        history_manager = self.history_webview.get_user_content_manager()
        history_manager.register_script_message_handler("history_ready")
        history_manager.connect("script-message-received::history_ready", self.on_js_history_ready)
        history_manager.register_script_message_handler("update_history")
        history_manager.connect("script-message-received::update_history", self.on_js_update_history)
        history_manager.register_script_message_handler("window_control")
        history_manager.connect("script-message-received::window_control", self.on_js_history_window_control)
        history_manager.register_script_message_handler("log")
        history_manager.connect("script-message-received::log", self.on_js_log)

        self.history_window.add(self.history_webview)
        
        # Load history page
        html_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "web", "history.html")
        html_uri = "file://" + os.path.abspath(html_path)
        self.history_webview.load_uri(html_uri)

        self.history_window.connect("destroy", self.on_history_window_destroy)
        self.history_window.show_all()

    def on_history_window_destroy(self, widget):
        logging.info("Stopwatch History Analytics window closed/destroyed.")
        self.history_window = None
        self.history_webview = None

    def on_js_history_ready(self, manager, js_result):
        self.send_history_to_history_window()

    def send_history_to_history_window(self):
        if self.history_window is not None and self.history_webview is not None:
            history_list = self.config.get("stopwatch_history", [])
            theme = self.config.get("theme", "dark")
            self.history_webview.run_javascript(f"setTheme('{theme}')", None, None, None)
            self.history_webview.run_javascript(f"setStopwatchHistory({json.dumps(history_list)})", None, None, None)

    def on_js_history_window_control(self, manager, js_result):
        try:
            data = json.loads(js_result.get_js_value().to_string())
            action = data.get("action")
            if action == "close" and self.history_window is not None:
                self.history_window.close()
        except Exception as e:
            print(f"Error handling history window control: {e}")

    def send_config_to_js(self):
        # Inject current configurations into JS
        self.webview.run_javascript(f"setTheme('{self.config['theme']}')", None, None, None)
        self.webview.run_javascript(f"setScale({self.config['scale']})", None, None, None)
        self.webview.run_javascript(f"setFormat({str(self.config['use_24h']).lower()})", None, None, None)
        self.webview.run_javascript(f"setShowSeconds({str(self.config['show_seconds']).lower()})", None, None, None)
        self.webview.run_javascript(f"setLocked({str(self.config['locked']).lower()})", None, None, None)
        self.webview.run_javascript(f"setMode('{self.config['mode']}')", None, None, None)
        self.webview.run_javascript(f"setLabel({json.dumps(self.config['label'])})", None, None, None)
        self.webview.run_javascript(f"setStopwatchHistory({json.dumps(self.config.get('stopwatch_history', []))})", None, None, None)
        self.webview.run_javascript(f"setSkin('{self.config.get('skin', 'retro')}')", None, None, None)
        self.webview.run_javascript(f"setAutostart({str(self.config['autostart']).lower()})", None, None, None)
        
        # Trigger JS size calculation
        self.webview.run_javascript("resizeWindow()", None, None, None)

    def on_context_menu(self, webview, context_menu, event, hit_test_result):
        # We ignore the default webkit menu and create a native GTK menu
        self.show_context_menu(event)
        return True

    def show_context_menu(self, event):
        menu = Gtk.Menu()

        # --- TIMER / STOPWATCH CONTROLS ---
        # Submenu: Mode Selection
        mode_menu = Gtk.Menu()
        modes = [("Clock Mode", "clock"), ("Stopwatch Mode", "stopwatch"), ("Countdown Timer", "timer")]
        mode_group = None
        for label, val in modes:
            mode_item = Gtk.RadioMenuItem(label=label, group=mode_group)
            if mode_group is None:
                mode_group = mode_item
            if val == self.config["mode"]:
                mode_item.set_active(True)
            mode_item.connect("activate", self.set_mode, val)
            mode_menu.append(mode_item)
            
        mode_root = Gtk.MenuItem(label="Widget Mode")
        mode_root.set_submenu(mode_menu)
        menu.append(mode_root)

        # Mode-specific control items
        active_mode = self.config["mode"]
        if active_mode in ["stopwatch", "timer"]:
            # Play / Pause Item
            play_item = Gtk.MenuItem(label="Start / Pause")
            play_item.connect("activate", lambda w: self.webview.run_javascript("toggleTimerState()", None, None, None))
            menu.append(play_item)

            # Reset Item
            reset_item = Gtk.MenuItem(label="Reset")
            reset_item.connect("activate", lambda w: self.webview.run_javascript("resetTimerState()", None, None, None))
            menu.append(reset_item)

            if active_mode == "timer":
                # Submenu: Set Duration
                durations_menu = Gtk.Menu()
                durations = [
                    ("1 Minute", 1), 
                    ("5 Minutes", 5), 
                    ("10 Minutes", 10), 
                    ("15 Minutes", 15), 
                    ("25 Minutes (Pomodoro)", 25), 
                    ("30 Minutes", 30), 
                    ("60 Minutes", 60)
                ]
                for label, mins in durations:
                    dur_item = Gtk.MenuItem(label=label)
                    dur_item.connect("activate", lambda w, m=mins: self.webview.run_javascript(f"setTimerDuration({m})", None, None, None))
                    durations_menu.append(dur_item)
                
                dur_root = Gtk.MenuItem(label="Set Timer Duration")
                dur_root.set_submenu(durations_menu)
                menu.append(dur_root)

        # Separator
        menu.append(Gtk.SeparatorMenuItem())

        # Item: Lock Position
        lock_item = Gtk.CheckMenuItem(label="Lock Position")
        lock_item.set_active(self.config["locked"])
        lock_item.connect("toggled", self.toggle_lock)
        menu.append(lock_item)

        # Item: Use 24-Hour Format
        format_item = Gtk.CheckMenuItem(label="24-Hour Format")
        format_item.set_active(self.config["use_24h"])
        format_item.connect("toggled", self.toggle_format)
        menu.append(format_item)

        # Item: Show Seconds
        seconds_item = Gtk.CheckMenuItem(label="Show Seconds")
        seconds_item.set_active(self.config["show_seconds"])
        seconds_item.connect("toggled", self.toggle_seconds)
        menu.append(seconds_item)

        # Item: Always on Bottom
        bottom_item = Gtk.CheckMenuItem(label="Keep Below (Desktop Widget)")
        bottom_item.set_active(self.config["always_on_bottom"])
        bottom_item.connect("toggled", self.toggle_always_on_bottom)
        menu.append(bottom_item)

        # Separator
        menu.append(Gtk.SeparatorMenuItem())

        # Submenu: Theme selection
        theme_menu = Gtk.Menu()
        themes = [
            ("Mint Green", "mint"), 
            ("Sleek Dark", "dark"), 
            ("Cyber Neon", "neon"), 
            ("Retro Amber", "amber"),
            ("Sakura Pink", "sakura"),
            ("Forest Green", "forest"),
            ("Cyberpunk Yellow", "cyberpunk")
        ]
        group = None
        for label, val in themes:
            theme_item = Gtk.RadioMenuItem(label=label, group=group)
            if group is None:
                group = theme_item
            if val == self.config["theme"]:
                theme_item.set_active(True)
            theme_item.connect("activate", self.set_theme, val)
            theme_menu.append(theme_item)
            
        theme_root = Gtk.MenuItem(label="Themes")
        theme_root.set_submenu(theme_menu)
        menu.append(theme_root)

        # Submenu: Skin selection
        skin_menu = Gtk.Menu()
        skins = [
            ("Retro Flip", "retro"), 
            ("Cyber Hologram", "hologram"), 
            ("Nixie Glow", "nixie"), 
            ("Minimal Flat", "minimal")
        ]
        skin_group = None
        for label, val in skins:
            skin_item = Gtk.RadioMenuItem(label=label, group=skin_group)
            if skin_group is None:
                skin_group = skin_item
            if val == self.config.get("skin", "retro"):
                skin_item.set_active(True)
            skin_item.connect("activate", self.set_skin, val)
            skin_menu.append(skin_item)
            
        skin_root = Gtk.MenuItem(label="Skins")
        skin_root.set_submenu(skin_menu)
        menu.append(skin_root)

        # Submenu: Size Selection
        scale_menu = Gtk.Menu()
        scales = [("75% (Small)", 0.75), ("100% (Normal)", 1.0), ("125% (Large)", 1.25), ("150% (Extra Large)", 1.5)]
        scale_group = None
        for label, val in scales:
            scale_item = Gtk.RadioMenuItem(label=label, group=scale_group)
            if scale_group is None:
                scale_group = scale_item
            if abs(val - self.config["scale"]) < 0.05:
                scale_item.set_active(True)
            scale_item.connect("activate", self.set_scale, val)
            scale_menu.append(scale_item)
            
        scale_root = Gtk.MenuItem(label="Scale Size")
        scale_root.set_submenu(scale_menu)
        menu.append(scale_root)

        # Separator
        menu.append(Gtk.SeparatorMenuItem())

        # Item: Start on Login
        autostart_item = Gtk.CheckMenuItem(label="Start on Login")
        autostart_item.set_active(self.config["autostart"])
        autostart_item.connect("toggled", self.toggle_autostart)
        menu.append(autostart_item)

        # Separator
        menu.append(Gtk.SeparatorMenuItem())

        # Item: Quit
        quit_item = Gtk.MenuItem(label="Quit Widget")
        quit_item.connect("activate", lambda w: Gtk.main_quit())
        menu.append(quit_item)

        # Display menu
        menu.show_all()
        menu.popup_at_pointer(None)

    def toggle_lock(self, item):
        self.config["locked"] = item.get_active()
        self.save_config()
        self.webview.run_javascript(f"setLocked({str(self.config['locked']).lower()})", None, None, None)

    def toggle_format(self, item):
        self.config["use_24h"] = item.get_active()
        self.save_config()
        self.webview.run_javascript(f"setFormat({str(self.config['use_24h']).lower()})", None, None, None)
        # Sizing might change slightly, trigger resize
        GLib.timeout_add(100, lambda: self.webview.run_javascript("resizeWindow()", None, None, None))

    def toggle_seconds(self, item):
        self.config["show_seconds"] = item.get_active()
        self.save_config()
        self.webview.run_javascript(f"setShowSeconds({str(self.config['show_seconds']).lower()})", None, None, None)
        # Resizing is needed as card width shrinks/grows
        GLib.timeout_add(100, lambda: self.webview.run_javascript("resizeWindow()", None, None, None))

    def toggle_always_on_bottom(self, item):
        self.config["always_on_bottom"] = item.get_active()
        self.save_config()
        self.window.set_keep_below(self.config["always_on_bottom"])

    def set_theme(self, item, theme_name):
        if item.get_active():
            self.config["theme"] = theme_name
            self.save_config()
            self.webview.run_javascript(f"setTheme('{theme_name}')", None, None, None)
            if self.history_window is not None and self.history_webview is not None:
                self.history_webview.run_javascript(f"setTheme('{theme_name}')", None, None, None)

    def set_skin(self, item, skin_name):
        if item.get_active():
            self.config["skin"] = skin_name
            self.save_config()
            logging.info(f"[GTK Menu] Skin selected: {skin_name}")
            self.webview.run_javascript(f"setSkin('{skin_name}')", None, None, None)

    def set_scale(self, item, scale_val):
        if item.get_active():
            self.config["scale"] = scale_val
            self.save_config()
            self.webview.run_javascript(f"setScale({scale_val})", None, None, None)
            # Resize window based on new HTML bounding box
            GLib.timeout_add(100, lambda: self.webview.run_javascript("resizeWindow()", None, None, None))

    def set_mode(self, item, mode_name):
        if item is None or item.get_active():
            self.config["mode"] = mode_name
            self.save_config()
            self.webview.run_javascript(f"setMode('{mode_name}')", None, None, None)

    def toggle_autostart(self, item):
        active = item.get_active()
        self.config["autostart"] = active
        self.save_config()
        
        if active:
            self.enable_autostart()
        else:
            self.disable_autostart()

    def enable_autostart(self):
        try:
            os.makedirs(AUTOSTART_DIR, exist_ok=True)
            script_path = os.path.abspath(sys.argv[0])
            content = f"""[Desktop Entry]
Type=Application
Exec={sys.executable} {script_path}
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Flip Clock Widget
Comment=Starts the transparent flip clock widget at login
"""
            with open(AUTOSTART_FILE, "w") as f:
                f.write(content)
            os.chmod(AUTOSTART_FILE, 0o755)
        except Exception as e:
            print(f"Error creating autostart: {e}")

    def disable_autostart(self):
        try:
            if os.path.exists(AUTOSTART_FILE):
                os.remove(AUTOSTART_FILE)
        except Exception as e:
            print(f"Error removing autostart: {e}")

    def run(self):
        self.window.show_all()
        Gtk.main()

if __name__ == "__main__":
    # Ensure current directory matches script location for relative assets loading
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    widget = FlipClockWidget()
    widget.run()
