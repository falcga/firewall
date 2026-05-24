from textual.screen import Screen
from textual.widgets import Header, Footer, Button, DataTable
from textual.widgets import ConfirmationDialog
from textual.containers import Container
from config_manager import load_configs
from add_proxy_screen import AddProxyScreen
from edit_proxy_screen import EditProxyScreen

class ProxyManagementScreen(Screen):
    """Screen for managing proxy configurations."""

    BINDINGS = [
        ("b", "app.pop_screen", "Back"),
        ("a", "add_proxy", "Add Proxy"),
        ("e", "edit_proxy", "Edit Proxy"),
        ("d", "delete_proxy", "Delete Proxy"),
        ("t", "toggle_active", "Toggle Active"),
    ]

    def compose(self) -> ComposeResult:
        yield Header()
        with Container():
            yield DataTable(id="proxy_table", can_focus=True)
            yield Button("Add Proxy", id="add_proxy_button", variant="success")
            yield Button("Edit Proxy", id="edit_proxy_button")
            yield Button("Delete Proxy", id="delete_proxy_button", variant="error")
            yield Button("Toggle Active", id="toggle_active_button")
        yield Footer()

    def on_mount(self) -> None:
        self.update_proxy_table()

    def on_screen_resume(self) -> None:
        """Called when the screen is resumed."""
        self.update_proxy_table()

    def update_proxy_table(self) -> None:
        table = self.query_one("#proxy_table", DataTable)
        table.clear()
        table.add_column("Name", width=20)
        table.add_column("Type", width=10)
        table.add_column("Server", width=20)
        table.add_column("Port", width=8)
        table.add_column("Status", width=10)

        configs = load_configs()
        for i, config in enumerate(configs):
            # For now, status is always 'Inactive' or 'Active' based on selection (not yet implemented)
            status = "Inactive"
            if "active" in config and config["active"]:
                status = "Active"
            table.add_row(config.get("remark", f"Proxy {i+1}"), 
                          config.get("protocol", "Unknown"), 
                          config.get("server", "N/A"), 
                          str(config.get("port", "N/A")),
                          status)

    def action_add_proxy(self) -> None:
        self.app.push_screen(AddProxyScreen())

    def action_edit_proxy(self) -> None:
        table = self.query_one("#proxy_table", DataTable)
        if table.cursor_row is not None:
            proxy_index = table.cursor_row
            configs = load_configs()
            if 0 <= proxy_index < len(configs):
                self.app.push_screen(EditProxyScreen(proxy_index=proxy_index, proxy_config=configs[proxy_index]))
            else:
                self.notify("No proxy selected or invalid index.", severity="warning")
        else:
            self.notify("Please select a proxy to edit.", severity="warning")

    async def action_delete_proxy(self) -> None:
        table = self.query_one("#proxy_table", DataTable)
        if table.cursor_row is not None:
            proxy_index = table.cursor_row
            configs = load_configs()
            if 0 <= proxy_index < len(configs):
                proxy_name = configs[proxy_index].get("remark", f"Proxy {proxy_index + 1}")
                if await self.app.push_screen_wait(ConfirmationDialog(f"Are you sure you want to delete \'{proxy_name}\'?")):
                    del configs[proxy_index]
                    if save_configs(configs):
                        self.notify(f"Proxy \'{proxy_name}\' deleted successfully!")
                        self.update_proxy_table()
                    else:
                        self.notify("Failed to delete proxy configuration.", severity="error")
            else:
                self.notify("No proxy selected or invalid index.", severity="warning")
        else:
            self.notify("Please select a proxy to delete.", severity="warning")

    def action_toggle_active(self) -> None:
        table = self.query_one("#proxy_table", DataTable)
        if table.cursor_row is not None:
            proxy_index = table.cursor_row
            configs = load_configs()
            if 0 <= proxy_index < len(configs):
                # Deactivate all other proxies and activate the selected one
                for i, config in enumerate(configs):
                    if i == proxy_index:
                        config["active"] = not config.get("active", False) # Toggle active status
                    else:
                        config["active"] = False # Deactivate others

                if save_configs(configs):
                    self.notify(f"Proxy \'{configs[proxy_index].get("remark", "Unknown")}\' toggled active status.")
                    self.update_proxy_table()
                else:
                    self.notify("Failed to update proxy active status.", severity="error")
            else:
                self.notify("No proxy selected or invalid index.", severity="warning")
        else:
            self.notify("Please select a proxy to toggle active status.", severity="warning")

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "add_proxy_button":
            self.action_add_proxy()
        elif event.button.id == "edit_proxy_button":
            self.action_edit_proxy()
        elif event.button.id == "delete_proxy_button":
            self.action_delete_proxy()
        elif event.button.id == "toggle_active_button":
            self.action_toggle_active()