import os
import json
import logging
import sys
from gi.repository import GLib

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONFIG_FILE = os.path.join(PROJECT_ROOT, "config.json")
AUTOSTART_DIR = os.path.expanduser("~/.config/autostart")
AUTOSTART_FILE = os.path.join(AUTOSTART_DIR, "flip-clock.desktop")

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

class ConfigManager:
    def __init__(self):
        self.save_timeout_id = None
        self.config = DEFAULT_CONFIG.copy()
        self.load_config()

    def load_config(self):
        logging.info("Loading config.json settings file...")
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

    def get(self, key, default=None):
        return self.config.get(key, default)

    def set(self, key, value):
        self.config[key] = value

    def save_config(self):
        try:
            logging.info("Saving configurations to config.json...")
            with open(CONFIG_FILE, "w") as f:
                json.dump(self.config, f, indent=2)
            logging.info("Configurations saved successfully.")
        except Exception as e:
            logging.error(f"Error saving configurations: {e}")

    def queue_save_config(self):
        if self.save_timeout_id is not None:
            GLib.source_remove(self.save_timeout_id)
        self.save_timeout_id = GLib.timeout_add(1000, self.save_config_timeout)

    def save_config_timeout(self):
        self.save_config()
        self.save_timeout_id = None
        return False

    def enable_autostart(self):
        try:
            os.makedirs(AUTOSTART_DIR, exist_ok=True)
            script_path = os.path.join(PROJECT_ROOT, "main.py")
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
            logging.info("Desktop autostart entry enabled successfully.")
        except Exception as e:
            logging.error(f"Error creating autostart: {e}")

    def disable_autostart(self):
        try:
            if os.path.exists(AUTOSTART_FILE):
                os.remove(AUTOSTART_FILE)
                logging.info("Desktop autostart entry disabled successfully.")
        except Exception as e:
            logging.error(f"Error removing autostart: {e}")
