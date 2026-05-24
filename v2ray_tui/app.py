from textual.app import App, ComposeResult
from textual.widgets import Header, Footer, Static, Button
from textual.containers import Container

from mihomo_controller import get_mihomo_status, start_mihomo, stop_mihomo, restart_mihomo
from config_manager import load_configs
from proxy_management_screen import ProxyManagementScreen
from system_proxy_manager import set_system_proxy, get_system_proxy_status
from logging_manager import get_app_logger
from log_screen import LogScreen
from subscription_screen import SubscriptionScreen
from geo_update_manager import update_geodata, check_geodata_status

# Initialize the logger
logger = get_app_logger()

class V2RayTUI(App):

    SCREENS = {
        "proxy_management": ProxyManagementScreen(),
        "log_screen": LogScreen(),
        "subscription_screen": SubscriptionScreen()
    }
    """A Textual app for V2Ray-like proxy management."""

    BINDINGS = [
        ("q", "quit", "Quit"),
        ("1", "manage_proxies", "Manage Proxies"),
        ("2", "global_settings", "Global Settings"),
        ("3", "start_proxy", "Start Proxy"),
        ("4", "stop_proxy", "Stop Proxy"),
        ("5", "test_connectivity", "Test Connectivity"),
        ("l", "view_logs", "View Logs"),
        ("s", "manage_subscriptions", "Subscriptions"),
        ("g", "update_geo", "Update Geo Data"),
    ]

    def compose(self) -> ComposeResult:
        yield Header()
        with Container():
            yield Static(id="status_display")
            yield Button("Manage Proxies", id="manage_proxies_button", variant="primary")
            yield Button("Global Settings", id="global_settings_button")
            yield Button("Start Proxy", id="start_proxy_button")
            yield Button("Stop Proxy", id="stop_proxy_button")
            yield Button("Test Connectivity", id="test_connectivity_button")

        yield Footer()

    def on_mount(self) -> None:
        self.update_status()

    def update_status(self) -> None:
        status_widget = self.query_one("#status_display", Static)
        status = get_mihomo_status()
        configs = load_configs()
        num_configs = len(configs)
        system_proxy_status = get_system_proxy_status()
        status_widget.update(f"[bold]Proxy Status:[/bold] {status}\n[bold]Configured Proxies:[/bold] {num_configs}\n[bold]System Proxy:[/bold] {system_proxy_status}")

    def action_quit(self) -> None:
        self.exit()

    def action_manage_proxies(self) -> None:
        self.push_screen("proxy_management")

    def action_global_settings(self) -> None:
        # Toggle system proxy
        current_status = get_system_proxy_status()
        if "enabled" in current_status.lower():
            # If system proxy is currently enabled, disable it
            message = set_system_proxy(False)
        else:
            # If system proxy is currently disabled, enable it with default settings
            # Use the currently active proxy configuration if available
            configs = load_configs()
            active_config = None
            for config in configs:
                if config.get("active", False):
                    active_config = config
                    break
            
            if active_config:
                server = active_config.get("server", "127.0.0.1")
                port = active_config.get("port", 7890)
            else:
                # Default to common mihomo ports if no active config
                server = "127.0.0.1"
                port = 7890
                
            message = set_system_proxy(True, server, port)
        
        self.notify(message)
        self.update_status()

    def action_start_proxy(self) -> None:
        message = start_mihomo()
        self.notify(message)
        self.update_status()

    def action_stop_proxy(self) -> None:
        message = stop_mihomo()
        self.notify(message)
        self.update_status()

    def action_test_connectivity(self) -> None:
        self.notify("Test Connectivity not implemented yet.")

    def action_view_logs(self) -> None:
        self.push_screen("log_screen")

    def action_manage_subscriptions(self) -> None:
        self.push_screen("subscription_screen")

    def action_update_geo(self) -> None:
        # Update geo databases
        message = update_geodata()
        self.notify(message)
        logger.info(f"Geo update action performed: {message}")

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "manage_proxies_button":
            self.action_manage_proxies()
        elif event.button.id == "global_settings_button":
            self.action_global_settings()
        elif event.button.id == "start_proxy_button":
            self.action_start_proxy()
        elif event.button.id == "stop_proxy_button":
            self.action_stop_proxy()
        elif event.button.id == "test_connectivity_button":
            self.action_test_connectivity()


if __name__ == "__main__":
    app = V2RayTUI()
    app.run()
