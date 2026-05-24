from textual.screen import Screen
from textual.widgets import Header, Footer, Input, Button, Label
from textual.containers import Container
from textual.app import ComposeResult
from config_manager import parse_vless_uri, load_configs, save_configs, parse_mihomo_json_config

class AddProxyScreen(Screen):
    """Screen for adding a new proxy configuration."""

    BINDINGS = [
        ("b", "app.pop_screen", "Back"),
    ]

    def compose(self) -> ComposeResult:
        yield Header()
        with Container():
            yield Label("Paste VLESS URI or JSON configuration below:")
            yield Input(placeholder="vless://... or {\"protocol\": \"vless\", ...}", id="proxy_input")
            yield Button("Add Proxy", id="submit_proxy_button", variant="success")
        yield Footer()

    async def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "submit_proxy_button":
            proxy_input = self.query_one("#proxy_input", Input).value
            if proxy_input:
                # Attempt to parse as VLESS URI first
                config = parse_vless_uri(proxy_input)

                if config:
                    configs = load_configs()
                    configs.append(config)
                    if save_configs(configs):
                        self.notify("Proxy added successfully!")
                        self.app.pop_screen()
                    else:
                        self.notify("Failed to save proxy configuration.", severity="error")
                else:
                    # Attempt to parse as JSON configuration
                    config = parse_mihomo_json_config(proxy_input)
                    if config:
                        configs = load_configs()
                        configs.append(config)
                        if save_configs(configs):
                            self.notify("Proxy added successfully!")
                            self.app.pop_screen()
                        else:
                            self.notify("Failed to save proxy configuration.", severity="error")
                    else:
                        self.notify("Invalid VLESS URI or JSON configuration.", severity="error")
            else:
                self.notify("Input cannot be empty.", severity="warning")
