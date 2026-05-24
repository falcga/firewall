from textual.screen import Screen
from textual.widgets import Header, Footer, TextArea, Button, Select
from textual.containers import Container
from textual.app import ComposeResult
from logging_manager import get_log_files, read_log_file, get_recent_logs

class LogScreen(Screen):
    """Screen for viewing application logs."""

    BINDINGS = [
        ("b", "app.pop_screen", "Back"),
        ("r", "refresh_logs", "Refresh"),
    ]

    def compose(self) -> ComposeResult:
        yield Header()
        with Container():
            # Dropdown to select log file
            log_files = get_log_files()
            if log_files:
                options = [(f.name, str(f)) for f in log_files]
                yield Select(options, id="log_file_select", prompt="Select log file...")
            else:
                yield Select([( "No log files available", "")], id="log_file_select", disabled=True)
            
            # Text area to display logs
            yield TextArea(id="log_text_area", read_only=True, language="text")
            
            # Buttons
            yield Button("Refresh Logs", id="refresh_logs_button")
            yield Button("Back", id="back_button")
        yield Footer()

    def on_mount(self) -> None:
        """Called when the screen is mounted."""
        self.refresh_logs_display()

    def refresh_logs_display(self):
        """Refresh the displayed logs."""
        log_text_area = self.query_one("#log_text_area", TextArea)
        
        # Get the currently selected log file from the select widget
        log_file_select = self.query_one("#log_file_select", Select)
        
        if log_file_select.value and log_file_select.value != "":
            # Read the selected log file
            log_lines = read_log_file(log_file_select.value, max_lines=200)
            log_content = "".join(log_lines)
        else:
            # Show recent logs from the current log file
            log_lines = get_recent_logs(max_lines=200)
            log_content = "".join(log_lines)
        
        log_text_area.text = log_content
        # Scroll to the bottom to show the most recent logs
        log_text_area.scroll_end(animate=False)

    def action_refresh_logs(self) -> None:
        """Action to refresh the logs display."""
        self.refresh_logs_display()
        self.notify("Logs refreshed")

    def on_select_changed(self, event: Select.Changed) -> None:
        """Handle when a different log file is selected."""
        if event.select.id == "log_file_select":
            self.refresh_logs_display()

    def on_button_pressed(self, event: Button.Pressed) -> None:
        """Handle button presses."""
        if event.button.id == "refresh_logs_button":
            self.action_refresh_logs()
        elif event.button.id == "back_button":
            self.app.pop_screen()