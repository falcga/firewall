import subprocess

def start_mihomo():
    """Starts the mihomo.service."""
    try:
        subprocess.run(["systemctl", "start", "mihomo.service"], check=True)
        return "Mihomo service started successfully."
    except subprocess.CalledProcessError as e:
        return f"Error starting Mihomo service: {e}"

def stop_mihomo():
    """Stops the mihomo.service."""
    try:
        subprocess.run(["systemctl", "stop", "mihomo.service"], check=True)
        return "Mihomo service stopped successfully."
    except subprocess.CalledProcessError as e:
        return f"Error stopping Mihomo service: {e}"

def restart_mihomo():
    """Restarts the mihomo.service."""
    try:
        # First, regenerate the config as per gen-mihomo-config.sh
        subprocess.run(["z:\home\falcga\lms\firewall\scripts\gen-mihomo-config.sh"], check=True)
        subprocess.run(["systemctl", "restart", "mihomo.service"], check=True)
        return "Mihomo service restarted successfully."
    except subprocess.CalledProcessError as e:
        return f"Error restarting Mihomo service: {e}"

def get_mihomo_status():
    """Gets the status of the mihomo.service."""
    try:
        result = subprocess.run(["systemctl", "is-active", "mihomo.service"], capture_output=True, text=True, check=True)
        if "active" in result.stdout.strip():
            return "Mihomo service is running."
        else:
            return "Mihomo service is not running."
    except subprocess.CalledProcessError:
        return "Mihomo service is not running or not found."
    except Exception as e:
        return f"Error getting Mihomo service status: {e}"

if __name__ == "__main__":
    print("Mihomo Controller module. Import and use functions.")