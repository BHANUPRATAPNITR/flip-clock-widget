import os
import logging
from gi.repository import Gtk, Gdk, WebKit2

class MainWindow:
    def __init__(self, app):
        self.app = app
        self.window = None
        self.webview = None
        self.init_ui()
        self.setup_webview()

    def init_ui(self):
        # Create a Top-Level borderless window
        self.window = Gtk.Window(type=Gtk.WindowType.TOPLEVEL)
        self.window.set_title("Flip Clock Widget")
        self.window.set_keep_below(self.app.config.get("always_on_bottom"))
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

        manager.register_script_message_handler("ready")
        manager.connect("script-message-received::ready", self.on_js_ready)

        manager.register_script_message_handler("resize")
        manager.connect("script-message-received::resize", self.on_js_resize)

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
        from core.config import PROJECT_ROOT
        html_path = os.path.join(PROJECT_ROOT, "web", "index.html")
        html_uri = "file://" + os.path.abspath(html_path)
        self.webview.load_uri(html_uri)

    def apply_config(self):
        # Set initial position
        self.window.move(self.app.config.get("x"), self.app.config.get("y"))
        # Always on bottom
        self.window.set_keep_below(self.app.config.get("always_on_bottom"))

    def show(self):
        self.window.show_all()

    def on_window_configured(self, widget, event):
        x, y = self.window.get_position()
        if x != self.app.config.get("x") or y != self.app.config.get("y"):
            self.app.config.set("x", x)
            self.app.config.set("y", y)
            self.app.config.queue_save_config()

    def on_js_drag(self, manager, js_result):
        self.app.on_js_drag(manager, js_result)

    def on_js_ready(self, manager, js_result):
        self.app.on_js_ready(manager, js_result)

    def on_js_resize(self, manager, js_result):
        self.app.on_js_resize(manager, js_result)

    def on_js_notify(self, manager, js_result):
        self.app.on_js_notify(manager, js_result)

    def on_js_update_label(self, manager, js_result):
        self.app.on_js_update_label(manager, js_result)

    def on_js_update_mode(self, manager, js_result):
        self.app.on_js_update_mode(manager, js_result)

    def on_js_window_control(self, manager, js_result):
        self.app.on_js_window_control(manager, js_result)

    def on_js_update_history(self, manager, js_result):
        self.app.on_js_update_history(manager, js_result)

    def on_js_show_history(self, manager, js_result):
        self.app.on_js_show_history(manager, js_result)

    def on_js_log(self, manager, js_result):
        self.app.on_js_log(manager, js_result)

    def on_js_update_skin(self, manager, js_result):
        self.app.on_js_update_skin(manager, js_result)

    def on_context_menu(self, webview, context_menu, event, hit_test_result):
        self.app.show_context_menu(event)
        return True

    def run_javascript(self, script):
        self.webview.run_javascript(script, None, None, None)
