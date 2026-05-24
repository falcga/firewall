import platform
import subprocess
import sys

def set_system_proxy_windows(enable: bool, server: str = "127.0.0.1", port: int = 7890):
    """
    Configure system proxy settings on Windows.
    
    Args:
        enable: Whether to enable or disable system proxy
        server: Proxy server address (default: 127.0.0.1)
        port: Proxy server port (default: 7890 - common for mihomo)
    """
    try:
        if enable:
            # Set proxy server
            subprocess.run([
                'reg', 'add', 'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings',
                '/v', 'ProxyServer', '/t', 'REG_SZ', '/d', f'{server}:{port}', '/f'
            ], check=True)
            
            # Enable proxy usage
            subprocess.run([
                'reg', 'add', 'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings',
                '/v', 'ProxyEnable', '/t', 'REG_DWORD', '/d', '1', '/f'
            ], check=True)
            
            return "System proxy enabled successfully."
        else:
            # Disable proxy usage
            subprocess.run([
                'reg', 'add', 'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings',
                '/v', 'ProxyEnable', '/t', 'REG_DWORD', '/d', '0', '/f'
            ], check=True)
            
            return "System proxy disabled successfully."
    except subprocess.CalledProcessError as e:
        return f"Error configuring system proxy: {e}"

def set_system_proxy_linux(enable: bool, server: str = "127.0.0.1", port: int = 7890):
    """
    Configure system proxy settings on Linux.
    
    Args:
        enable: Whether to enable or disable system proxy
        server: Proxy server address (default: 127.0.0.1)
        port: Proxy server port (default: 7890)
    """
    try:
        if enable:
            # Set environment variables
            proxy_url = f"http://{server}:{port}"
            subprocess.run(['gsettings', 'set', 'org.gnome.system.proxy', 'mode', 'manual'], check=True)
            subprocess.run(['gsettings', 'set', 'org.gnome.system.proxy.http', 'host', server], check=True)
            subprocess.run(['gsettings', 'set', 'org.gnome.system.proxy.http', 'port', str(port)], check=True)
            subprocess.run(['gsettings', 'set', 'org.gnome.system.proxy.https', 'host', server], check=True)
            subprocess.run(['gsettings', 'set', 'org.gnome.system.proxy.https', 'port', str(port)], check=True)
            
            # Also export to environment for other applications
            # Note: This won't persist across sessions without being added to shell profile
            subprocess.run(['export', f'http_proxy={proxy_url}'], shell=True)
            subprocess.run(['export', f'https_proxy={proxy_url}'], shell=True)
            
            return "System proxy enabled successfully."
        else:
            # Disable proxy settings
            subprocess.run(['gsettings', 'set', 'org.gnome.system.proxy', 'mode', 'none'], check=True)
            
            # Unset environment variables
            subprocess.run(['unset', 'http_proxy'], shell=True)
            subprocess.run(['unset', 'https_proxy'], shell=True)
            
            return "System proxy disabled successfully."
    except subprocess.CalledProcessError as e:
        return f"Error configuring system proxy: {e}"

def set_system_proxy_macos(enable: bool, server: str = "127.0.0.1", port: int = 7890):
    """
    Configure system proxy settings on macOS.
    
    Args:
        enable: Whether to enable or disable system proxy
        server: Proxy server address (default: 127.0.0.1)
        port: Proxy server port (default: 7890)
    """
    try:
        # Get network service (assuming Wi-Fi, but could be extended to detect active service)
        network_service = "Wi-Fi"  # This might need to be detected dynamically
        
        if enable:
            # Set HTTP proxy
            subprocess.run([
                'networksetup', '-setwebproxy', network_service, server, str(port)
            ], check=True)
            
            # Set HTTPS proxy
            subprocess.run([
                'networksetup', '-setsecurewebproxy', network_service, server, str(port)
            ], check=True)
            
            # Enable proxy
            subprocess.run([
                'networksetup', '-setwebproxystate', network_service, 'on'
            ], check=True)
            
            subprocess.run([
                'networksetup', '-setsecurewebproxystate', network_service, 'on'
            ], check=True)
            
            return "System proxy enabled successfully."
        else:
            # Disable proxy
            subprocess.run([
                'networksetup', '-setwebproxystate', network_service, 'off'
            ], check=True)
            
            subprocess.run([
                'networksetup', '-setsecurewebproxystate', network_service, 'off'
            ], check=True)
            
            return "System proxy disabled successfully."
    except subprocess.CalledProcessError as e:
        return f"Error configuring system proxy: {e}"

def set_system_proxy(enable: bool, server: str = "127.0.0.1", port: int = 7890):
    """
    Cross-platform function to configure system proxy settings.
    
    Args:
        enable: Whether to enable or disable system proxy
        server: Proxy server address (default: 127.0.0.1)
        port: Proxy server port (default: 7890)
    """
    system = platform.system().lower()
    
    if system == "windows":
        return set_system_proxy_windows(enable, server, port)
    elif system == "linux":
        return set_system_proxy_linux(enable, server, port)
    elif system == "darwin":  # macOS
        return set_system_proxy_macos(enable, server, port)
    else:
        return f"System proxy configuration not supported on {system}."

def get_system_proxy_status():
    """
    Check the current system proxy status.
    """
    system = platform.system().lower()
    
    try:
        if system == "windows":
            # Check registry for proxy settings
            result = subprocess.run([
                'reg', 'query', 'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings',
                '/v', 'ProxyEnable'
            ], capture_output=True, text=True)
            
            if '0x1' in result.stdout:
                # Proxy is enabled, get server info
                server_result = subprocess.run([
                    'reg', 'query', 'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings',
                    '/v', 'ProxyServer'
                ], capture_output=True, text=True)
                
                if server_result.returncode == 0:
                    # Extract server:port from output (simplified)
                    import re
                    match = re.search(r'([^\s]+)$', server_result.stdout.strip())
                    if match:
                        return f"System proxy is enabled: {match.group(1)}"
                
                return "System proxy is enabled"
            else:
                return "System proxy is disabled"
        
        elif system == "linux":
            # Check GNOME proxy settings
            result = subprocess.run(['gsettings', 'get', 'org.gnome.system.proxy', 'mode'], 
                                   capture_output=True, text=True)
            
            if "'manual'" in result.stdout:
                return "System proxy is enabled"
            else:
                return "System proxy is disabled"
        
        elif system == "darwin":
            # Check macOS proxy status for Wi-Fi
            result = subprocess.run([
                'networksetup', '-getwebproxy', 'Wi-Fi'
            ], capture_output=True, text=True)
            
            if 'Enabled: Yes' in result.stdout:
                return "System proxy is enabled"
            else:
                return "System proxy is disabled"
        
        else:
            return f"System proxy status check not supported on {system}."
    
    except subprocess.CalledProcessError:
        return "Unable to determine system proxy status"

if __name__ == "__main__":
    # Example usage
    print("Current system proxy status:", get_system_proxy_status())
    # print(set_system_proxy(True))  # Enable proxy
    # print(set_system_proxy(False)) # Disable proxy