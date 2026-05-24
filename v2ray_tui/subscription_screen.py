from textual.screen import Screen
from textual.widgets import Header, Footer, Button, DataTable, Input, Label
from textual.widgets import ConfirmationDialog
from textual.containers import Container
from textual.app import ComposeResult
from subscription_manager import get_subscription_list, add_subscription, remove_subscription, enable_subscription, disable_subscription, update_subscription, update_all_subscriptions

class SubscriptionScreen(Screen):
    """Screen for managing proxy subscriptions."""

    BINDINGS = [
        ("b", "app.pop_screen", "Back"),
        ("a", "add_subscription", "Add Subscription"),
        ("e", "toggle_enabled", "Enable/Disable"),
        ("u", "update_subscription", "Update"),
        ("ua", "update_all_subscriptions", "Update All"),
        ("d", "delete_subscription", "Delete"),
    ]

    def compose(self) -> ComposeResult:
        yield Header()
        with Container():
            yield Label("[b]Subscriptions Management[/b]")
            yield DataTable(id="subscription_table", can_focus=True)
            yield Input(placeholder="Enter subscription name", id="sub_name_input")
            yield Input(placeholder="Enter subscription URL", id="sub_url_input")
            yield Button("Add Subscription", id="add_sub_button", variant="success")
            yield Button("Enable/Disable", id="toggle_enabled_button")
            yield Button("Update Selected", id="update_selected_button", variant="primary")
            yield Button("Update All", id="update_all_button", variant="warning")
            yield Button("Delete Selected", id="delete_selected_button", variant="error")
            yield Button("Back", id="back_button")
        yield Footer()

    def on_mount(self) -> None:
        self.update_subscription_table()

    def update_subscription_table(self) -> None:
        table = self.query_one("#subscription_table", DataTable)
        table.clear()
        table.add_column("Name", width=20)
        table.add_column("URL", width=40)
        table.add_column("Status", width=10)
        table.add_column("Last Updated", width=15)

        subscriptions = get_subscription_list()
        for sub in subscriptions:
            status = "Enabled" if sub.get("enabled", True) else "Disabled"
            last_updated = sub.get("last_updated", "Never")
            table.add_row(
                sub.get("name", "Unknown"),
                sub.get("url", ""),
                status,
                last_updated
            )

    def action_add_subscription(self) -> None:
        name_input = self.query_one("#sub_name_input", Input)
        url_input = self.query_one("#sub_url_input", Input)
        
        name = name_input.value.strip()
        url = url_input.value.strip()
        
        if not name or not url:
            self.notify("Both name and URL are required!", severity="error")
            return
        
        if add_subscription(name, url):
            self.notify(f"Subscription '{name}' added successfully!")
            name_input.value = ""
            url_input.value = ""
            self.update_subscription_table()
        else:
            self.notify("Failed to add subscription. It may already exist.", severity="error")

    def action_toggle_enabled(self) -> None:
        table = self.query_one("#subscription_table", DataTable)
        if table.cursor_row is not None:
            row_data = table.get_row_at(table.cursor_row)
            name = row_data[0]
            url = row_data[1]
            current_status = row_data[2]
            
            if current_status == "Enabled":
                success = disable_subscription(url)
                action = "disabled"
            else:
                success = enable_subscription(url)
                action = "enabled"
            
            if success:
                self.notify(f"Subscription '{name}' {action} successfully!")
                self.update_subscription_table()
            else:
                self.notify(f"Failed to {action} subscription.", severity="error")
        else:
            self.notify("Please select a subscription to enable/disable.", severity="warning")

    def action_update_subscription(self) -> None:
        table = self.query_one("#subscription_table", DataTable)
        if table.cursor_row is not None:
            row_data = table.get_row_at(table.cursor_row)
            name = row_data[0]
            url = row_data[1]
            
            success, message = update_subscription(url)
            self.notify(message)
            if success:
                self.update_subscription_table()
        else:
            self.notify("Please select a subscription to update.", severity="warning")

    def action_update_all_subscriptions(self) -> None:
        results = update_all_subscriptions()
        success_count = sum(1 for success, _ in results if success)
        self.notify(f"Updated {success_count} out of {len(results)} subscriptions.")
        self.update_subscription_table()

    async def action_delete_subscription(self) -> None:
        table = self.query_one("#subscription_table", DataTable)
        if table.cursor_row is not None:
            row_data = table.get_row_at(table.cursor_row)
            name = row_data[0]
            
            if await self.app.push_screen_wait(ConfirmationDialog(f"Are you sure you want to delete subscription '{name}'?")):
                url = row_data[1]
                if remove_subscription(url):
                    self.notify(f"Subscription '{name}' deleted successfully!")
                    self.update_subscription_table()
                else:
                    self.notify("Failed to delete subscription.", severity="error")
        else:
            self.notify("Please select a subscription to delete.", severity="warning")

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "add_sub_button":
            self.action_add_subscription()
        elif event.button.id == "toggle_enabled_button":
            self.action_toggle_enabled()
        elif event.button.id == "update_selected_button":
            self.action_update_subscription()
        elif event.button.id == "update_all_button":
            self.action_update_all_subscriptions()
        elif event.button.id == "delete_selected_button":
            self.action_delete_subscription()
        elif event.button.id == "back_button":
            self.app.pop_screen()