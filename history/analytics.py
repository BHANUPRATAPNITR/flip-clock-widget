import os
import json
import logging
from gi.repository import Gtk, Gdk, WebKit2

class HistoryWindow:
    def __init__(self, app):
        self.app = app
        self.window = None
        self.webview = None

    def show(self):
        if self.window is not None:
            logging.info("Stopwatch History Analytics window already open. Focusing window.")
            self.window.present()
            return

        logging.info("Creating Stopwatch History Analytics window container...")
        self.window = Gtk.Window(type=Gtk.WindowType.TOPLEVEL)
        self.window.set_title("Stopwatch History Analytics")
        self.window.set_default_size(760, 480)
        self.window.set_position(Gtk.WindowPosition.CENTER)

        # Support transparency
        screen = self.window.get_screen()
        visual = screen.get_rgba_visual()
        if visual and screen.is_composited():
            self.window.set_visual(visual)
        self.window.set_app_paintable(True)

        settings = WebKit2.Settings()
        settings.set_enable_webgl(False)
        settings.set_enable_accelerated_2d_canvas(True)

        self.webview = WebKit2.WebView.new_with_settings(settings)
        context = self.webview.get_context()
        if context:
            context.set_cache_model(WebKit2.CacheModel.DOCUMENT_VIEWER)
            
        transparent = Gdk.RGBA(0.0, 0.0, 0.0, 0.0)
        self.webview.set_background_color(transparent)

        # Register message handlers for the history window
        history_manager = self.webview.get_user_content_manager()
        
        history_manager.register_script_message_handler("history_ready")
        history_manager.connect("script-message-received::history_ready", self.on_js_history_ready)
        
        history_manager.register_script_message_handler("update_history")
        history_manager.connect("script-message-received::update_history", self.on_js_update_history)
        
        history_manager.register_script_message_handler("window_control")
        history_manager.connect("script-message-received::window_control", self.on_js_history_window_control)
        
        history_manager.register_script_message_handler("log")
        history_manager.connect("script-message-received::log", self.on_js_log)

        self.window.add(self.webview)
        
        # Load history page
        from core.config import PROJECT_ROOT
        html_path = os.path.join(PROJECT_ROOT, "web", "history.html")
        html_uri = "file://" + os.path.abspath(html_path)
        self.webview.load_uri(html_uri)

        self.window.connect("destroy", self.on_destroy)
        self.window.show_all()

    def on_destroy(self, widget):
        logging.info("Stopwatch History Analytics window closed/destroyed.")
        self.window = None
        self.webview = None
        self.app.on_history_window_closed()

    def on_js_history_ready(self, manager, js_result):
        self.send_history()

    def send_history(self):
        if self.window is not None and self.webview is not None:
            history_list = self.app.config.get("stopwatch_history", [])
            theme = self.app.config.get("theme", "dark")
            self.webview.run_javascript(f"setTheme('{theme}')", None, None, None)
            self.webview.run_javascript(f"setStopwatchHistory({json.dumps(history_list)})", None, None, None)

    def on_js_update_history(self, manager, js_result):
        self.app.on_js_update_history(manager, js_result)

    def on_js_history_window_control(self, manager, js_result):
        try:
            data = json.loads(js_result.get_js_value().to_string())
            action = data.get("action")
            if action == "close" and self.window is not None:
                self.window.close()
        except Exception as e:
            logging.error(f"Error handling history window control: {e}")

    def on_js_log(self, manager, js_result):
        self.app.on_js_log(manager, js_result)

    def close(self):
        if self.window is not None:
            self.window.close()
            
    def present(self):
        if self.window is not None:
            self.window.present()
