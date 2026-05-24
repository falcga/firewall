import logging
import os
from datetime import datetime
from pathlib import Path

class LogManager:
    """
    Manages application logging for the v2ray TUI application.
    """
    
    def __init__(self, log_dir="logs", log_level=logging.INFO):
        """
        Initialize the log manager.
        
        Args:
            log_dir: Directory to store log files
            log_level: Minimum level of logs to record
        """
        self.log_dir = Path(log_dir)
        self.log_dir.mkdir(exist_ok=True)
        
        # Set up the logger
        self.logger = logging.getLogger('v2ray_tui')
        self.logger.setLevel(log_level)
        
        # Clear any existing handlers to avoid duplicates
        self.logger.handlers.clear()
        
        # Create file handler
        log_file = self.log_dir / f"v2ray_tui_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"
        file_handler = logging.FileHandler(log_file, encoding='utf-8')
        file_handler.setLevel(log_level)
        
        # Create console handler
        console_handler = logging.StreamHandler()
        console_handler.setLevel(log_level)
        
        # Create formatter
        formatter = logging.Formatter(
            '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        )
        file_handler.setFormatter(formatter)
        console_handler.setFormatter(formatter)
        
        # Add handlers to logger
        self.logger.addHandler(file_handler)
        self.logger.addHandler(console_handler)
        
        self.current_log_file = log_file
    
    def get_logger(self):
        """
        Returns the configured logger instance.
        """
        return self.logger
    
    def get_log_files(self):
        """
        Returns a list of available log files.
        """
        log_files = []
        if self.log_dir.exists():
            log_files = [f for f in self.log_dir.iterdir() if f.suffix == '.log']
            # Sort by modification time (most recent first)
            log_files.sort(key=lambda x: x.stat().st_mtime, reverse=True)
        return log_files
    
    def read_log_file(self, log_file_path, max_lines=100):
        """
        Reads the last N lines from a log file.
        
        Args:
            log_file_path: Path to the log file
            max_lines: Maximum number of lines to read from the end
        """
        try:
            with open(log_file_path, 'r', encoding='utf-8') as f:
                lines = f.readlines()
                return lines[-max_lines:] if len(lines) > max_lines else lines
        except Exception as e:
            return [f"Error reading log file: {str(e)}"]
    
    def get_recent_logs(self, max_lines=50):
        """
        Returns recent log entries from the current log file.
        """
        return self.read_log_file(self.current_log_file, max_lines)
    
    def clear_old_logs(self, days_to_keep=7):
        """
        Removes log files older than the specified number of days.
        
        Args:
            days_to_keep: Number of days of logs to keep
        """
        import time
        cutoff_time = time.time() - (days_to_keep * 24 * 60 * 60)
        
        for log_file in self.log_dir.glob("*.log"):
            if log_file.stat().st_mtime < cutoff_time:
                try:
                    log_file.unlink()
                except OSError as e:
                    self.logger.error(f"Could not delete old log file {log_file}: {e}")

# Global log manager instance
log_manager = LogManager()

def get_app_logger():
    """
    Returns the application logger.
    """
    return log_manager.get_logger()

def get_log_files():
    """
    Returns a list of available log files.
    """
    return log_manager.get_log_files()

def read_log_file(log_file_path, max_lines=100):
    """
    Reads the last N lines from a log file.
    """
    return log_manager.read_log_file(log_file_path, max_lines)

def get_recent_logs(max_lines=50):
    """
    Returns recent log entries from the current log file.
    """
    return log_manager.get_recent_logs()

# Example usage
if __name__ == "__main__":
    logger = get_app_logger()
    logger.info("Log manager initialized")
    logger.debug("This is a debug message")
    logger.warning("This is a warning message")
    logger.error("This is an error message")
    
    print("\nRecent logs:")
    for line in get_recent_logs():
        print(line.strip())