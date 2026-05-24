import json
import urllib.parse
from textual.screen import Screen
from textual.widgets import Header, Footer, Input, Button, Label
from textual.containers import Container
from textual.app import ComposeResult
from config_manager import parse_vless_uri, load_configs, save_configs, parse_mihomo_json_config

class EditProxyScreen(Screen):
    """Screen for editing an existing proxy configuration."""

    BINDINGS = [
        ("b", "app.pop_screen", "Back"),
    ]

    def __init__(self, proxy_index: int, proxy_config: dict, name: str | None = None, id: str | None = None, classes: str | None = None):
        super().__init__(name=name, id=id, classes=classes)
        self.proxy_index = proxy_index
        self.proxy_config = proxy_config

    def compose(self) -> ComposeResult:
        yield Header()
        with Container():
            yield Label(f"Editing Proxy: {self.proxy_config.get("remark", "Unknown")}")
            # For simplicity, we'll allow editing the VLESS URI or the full JSON.
            # A more advanced implementation might have individual fields for each setting.
            initial_value = ""
            if self.proxy_config.get("protocol") == "vless" and "uuid" in self.proxy_config:
                # Reconstruct VLESS URI for editing
                params = {}
                if self.proxy_config.get("flow"): params["flow"] = self.proxy_config["flow"]
                if self.proxy_config.get("encryption"): params["encryption"] = self.proxy_config["encryption"]
                if self.proxy_config.get("security"): params["security"] = self.proxy_config["security"]
                if self.proxy_config.get("type"): params["type"] = self.proxy_config["type"]
                if self.proxy_config.get("headerType"): params["headerType"] = self.proxy_config["headerType"]
                if self.proxy_config.get("host"): params["host"] = self.proxy_config["host"]
                if self.proxy_config.get("path"): params["path"] = self.proxy_config["path"]
                if self.proxy_config.get("sni"): params["sni"] = self.proxy_config["sni"]
                if self.proxy_config.get("fp"): params["fp"] = self.proxy_config["fp"]
                if self.proxy_config.get("pbk"): params["pbk"] = self.proxy_config["pbk"]
                if self.proxy_config.get("sid"): params["sid"] = self.proxy_config["sid"]
                
                query_string = urllib.parse.urlencode(params)
                fragment = urllib.parse.quote(self.proxy_config.get("remark", ""))
                initial_value = f"vless://{self.proxy_config["uuid"]}@{self.proxy_config["server"]}:{self.proxy_config["port"]}?{query_string}#{fragment}"
            elif "full_json_config" in self.proxy_config:
                initial_value = json.dumps(self.proxy_config["full_json_config"], indent=4)
            else:
                initial_value = json.dumps(self.proxy_config, indent=4) # Fallback to showing raw config

            yield Input(value=initial_value, id="proxy_input", placeholder="VLESS URI or JSON configuration")
            yield Button("Save Changes", id="save_proxy_button", variant="success")
        yield Footer()

    async def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "save_proxy_button":
            proxy_input = self.query_one("#proxy_input", Input).value
            if proxy_input:
                config = parse_vless_uri(proxy_input)
                if not config:
                    config = parse_mihomo_json_config(proxy_input)

                if config:
                    configs = load_configs()
                    if 0 <= self.proxy_index < len(configs):
                        configs[self.proxy_index] = config
                        if save_configs(configs):
                            self.notify("Proxy updated successfully!")
                            self.app.pop_screen()
                        else:
                            self.notify("Failed to save proxy configuration.", severity="error")
                    else:
                        self.notify("Invalid proxy index.", severity="error")
                else:
                    self.notify("Invalid VLESS URI or JSON configuration.", severity="error")
            else:
                self.notify("Input cannot be empty.", severity="warning")
