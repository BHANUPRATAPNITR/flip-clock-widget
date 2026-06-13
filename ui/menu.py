import logging
from gi.repository import Gtk
from modes.clock import ClockMode
from modes.stopwatch import StopwatchMode
from modes.timer import TimerMode
from themes.theme_manager import get_themes, get_skins

class ContextMenu:
    def __init__(self, app):
        self.app = app
        self.menu = Gtk.Menu()
        self.build_menu()

    def build_menu(self):
        # 1. Mode Selection Submenu
        mode_menu = Gtk.Menu()
        modes = [
            (ClockMode.LABEL, ClockMode.NAME),
            (StopwatchMode.LABEL, StopwatchMode.NAME),
            (TimerMode.LABEL, TimerMode.NAME)
        ]
        mode_group = None
        for label, val in modes:
            mode_item = Gtk.RadioMenuItem(label=label, group=mode_group)
            if mode_group is None:
                mode_group = mode_item
            if val == self.app.config.get("mode"):
                mode_item.set_active(True)
            mode_item.connect("activate", self.on_set_mode, val)
            mode_menu.append(mode_item)
            
        mode_root = Gtk.MenuItem(label="Widget Mode")
        mode_root.set_submenu(mode_menu)
        self.menu.append(mode_root)

        # 2. Mode-specific Controls (Play, Reset, Presets)
        active_mode = self.app.config.get("mode")
        if active_mode in [StopwatchMode.NAME, TimerMode.NAME]:
            play_item = Gtk.MenuItem(label="Start / Pause")
            play_item.connect("activate", lambda w: self.app.run_javascript("toggleTimerState()"))
            self.menu.append(play_item)

            reset_item = Gtk.MenuItem(label="Reset")
            reset_item.connect("activate", lambda w: self.app.run_javascript("resetTimerState()"))
            self.menu.append(reset_item)

            if active_mode == TimerMode.NAME:
                durations_menu = Gtk.Menu()
                for label, mins in TimerMode.DURATIONS:
                    dur_item = Gtk.MenuItem(label=label)
                    dur_item.connect("activate", lambda w, m=mins: self.app.run_javascript(f"setTimerDuration({m})"))
                    durations_menu.append(dur_item)
                
                dur_root = Gtk.MenuItem(label="Set Timer Duration")
                dur_root.set_submenu(durations_menu)
                self.menu.append(dur_root)

        # Separator
        self.menu.append(Gtk.SeparatorMenuItem())

        # 3. Preferences (CheckMenuItems)
        lock_item = Gtk.CheckMenuItem(label="Lock Position")
        lock_item.set_active(self.app.config.get("locked"))
        lock_item.connect("toggled", self.on_toggle_lock)
        self.menu.append(lock_item)

        format_item = Gtk.CheckMenuItem(label="24-Hour Format")
        format_item.set_active(self.app.config.get("use_24h"))
        format_item.connect("toggled", self.on_toggle_format)
        self.menu.append(format_item)

        seconds_item = Gtk.CheckMenuItem(label="Show Seconds")
        seconds_item.set_active(self.app.config.get("show_seconds"))
        seconds_item.connect("toggled", self.on_toggle_seconds)
        self.menu.append(seconds_item)

        bottom_item = Gtk.CheckMenuItem(label="Keep Below (Desktop Widget)")
        bottom_item.set_active(self.app.config.get("always_on_bottom"))
        bottom_item.connect("toggled", self.on_toggle_always_on_bottom)
        self.menu.append(bottom_item)

        # Separator
        self.menu.append(Gtk.SeparatorMenuItem())

        # 4. Themes Submenu
        theme_menu = Gtk.Menu()
        theme_group = None
        for label, val in get_themes():
            theme_item = Gtk.RadioMenuItem(label=label, group=theme_group)
            if theme_group is None:
                theme_group = theme_item
            if val == self.app.config.get("theme"):
                theme_item.set_active(True)
            theme_item.connect("activate", self.on_set_theme, val)
            theme_menu.append(theme_item)
            
        theme_root = Gtk.MenuItem(label="Themes")
        theme_root.set_submenu(theme_menu)
        self.menu.append(theme_root)

        # 5. Skins Submenu
        skin_menu = Gtk.Menu()
        skin_group = None
        for label, val in get_skins():
            skin_item = Gtk.RadioMenuItem(label=label, group=skin_group)
            if skin_group is None:
                skin_group = skin_item
            if val == self.app.config.get("skin", "retro"):
                skin_item.set_active(True)
            skin_item.connect("activate", self.on_set_skin, val)
            skin_menu.append(skin_item)
            
        skin_root = Gtk.MenuItem(label="Skins")
        skin_root.set_submenu(skin_menu)
        self.menu.append(skin_root)

        # 6. Scale Submenu
        scale_menu = Gtk.Menu()
        scales = [("75% (Small)", 0.75), ("100% (Normal)", 1.0), ("125% (Large)", 1.25), ("150% (Extra Large)", 1.5)]
        scale_group = None
        for label, val in scales:
            scale_item = Gtk.RadioMenuItem(label=label, group=scale_group)
            if scale_group is None:
                scale_group = scale_item
            if abs(val - self.app.config.get("scale")) < 0.05:
                scale_item.set_active(True)
            scale_item.connect("activate", self.on_set_scale, val)
            scale_menu.append(scale_item)
            
        scale_root = Gtk.MenuItem(label="Scale Size")
        scale_root.set_submenu(scale_menu)
        self.menu.append(scale_root)

        # Separator
        self.menu.append(Gtk.SeparatorMenuItem())

        # 7. Start on Login
        autostart_item = Gtk.CheckMenuItem(label="Start on Login")
        autostart_item.set_active(self.app.config.get("autostart"))
        autostart_item.connect("toggled", self.on_toggle_autostart)
        self.menu.append(autostart_item)

        # Separator
        self.menu.append(Gtk.SeparatorMenuItem())

        # 8. Quit
        quit_item = Gtk.MenuItem(label="Quit Widget")
        quit_item.connect("activate", lambda w: Gtk.main_quit())
        self.menu.append(quit_item)

    def popup(self, event):
        self.menu.show_all()
        self.menu.popup_at_pointer(None)

    def on_set_mode(self, item, mode_name):
        if item.get_active():
            self.app.set_mode(mode_name)

    def on_toggle_lock(self, item):
        self.app.toggle_lock(item.get_active())

    def on_toggle_format(self, item):
        self.app.toggle_format(item.get_active())

    def on_toggle_seconds(self, item):
        self.app.toggle_seconds(item.get_active())

    def on_toggle_always_on_bottom(self, item):
        self.app.toggle_always_on_bottom(item.get_active())

    def on_set_theme(self, item, theme_name):
        if item.get_active():
            self.app.set_theme(theme_name)

    def on_set_skin(self, item, skin_name):
        if item.get_active():
            self.app.set_skin(skin_name)

    def on_set_scale(self, item, scale_val):
        if item.get_active():
            self.app.set_scale(scale_val)

    def on_toggle_autostart(self, item):
        self.app.toggle_autostart(item.get_active())
