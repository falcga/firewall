import json
import urllib.request
import urllib.parse
import urllib.error
import base64
from typing import List, Dict, Optional
from config_manager import parse_vless_uri, parse_mihomo_json_config
import re

class SubscriptionManager:
    """
    Manages proxy subscriptions similar to v2rayN functionality.
    """
    
    def __init__(self, subscription_file: str = "subscriptions.json"):
        """
        Initialize the subscription manager.
        
        Args:
            subscription_file: Path to the file storing subscription information
        """
        self.subscription_file = subscription_file
        self.subscriptions = self.load_subscriptions()
    
    def load_subscriptions(self) -> List[Dict]:
        """
        Load subscriptions from file.
        """
        try:
            with open(self.subscription_file, 'r', encoding='utf-8') as f:
                return json.load(f)
        except FileNotFoundError:
            return []
        except json.JSONDecodeError:
            return []
    
    def save_subscriptions(self):
        """
        Save subscriptions to file.
        """
        with open(self.subscription_file, 'w', encoding='utf-8') as f:
            json.dump(self.subscriptions, f, indent=4, ensure_ascii=False)
    
    def add_subscription(self, name: str, url: str, enabled: bool = True) -> bool:
        """
        Add a new subscription.
        
        Args:
            name: Name for the subscription
            url: URL of the subscription
            enabled: Whether the subscription is enabled
        
        Returns:
            True if successful, False otherwise
        """
        # Check if subscription already exists
        for sub in self.subscriptions:
            if sub['url'] == url:
                return False
        
        new_subscription = {
            'name': name,
            'url': url,
            'enabled': enabled,
            'last_updated': None
        }
        
        self.subscriptions.append(new_subscription)
        self.save_subscriptions()
        return True
    
    def remove_subscription(self, url: str) -> bool:
        """
        Remove a subscription by URL.
        
        Args:
            url: URL of the subscription to remove
        
        Returns:
            True if successful, False otherwise
        """
        original_count = len(self.subscriptions)
        self.subscriptions = [sub for sub in self.subscriptions if sub['url'] != url]
        
        if len(self.subscriptions) < original_count:
            self.save_subscriptions()
            return True
        return False
    
    def enable_subscription(self, url: str) -> bool:
        """
        Enable a subscription.
        
        Args:
            url: URL of the subscription to enable
        
        Returns:
            True if successful, False otherwise
        """
        for sub in self.subscriptions:
            if sub['url'] == url:
                sub['enabled'] = True
                self.save_subscriptions()
                return True
        return False
    
    def disable_subscription(self, url: str) -> bool:
        """
        Disable a subscription.
        
        Args:
            url: URL of the subscription to disable
        
        Returns:
            True if successful, False otherwise
        """
        for sub in self.subscriptions:
            if sub['url'] == url:
                sub['enabled'] = False
                self.save_subscriptions()
                return True
        return False
    
    def fetch_subscription_content(self, url: str) -> Optional[str]:
        """
        Fetch content from a subscription URL.
        
        Args:
            url: URL of the subscription
        
        Returns:
            Subscription content as string, or None if failed
        """
        try:
            headers = {
                'User-Agent': 'v2rayN/1.0'
            }
            req = urllib.request.Request(url, headers=headers)
            response = urllib.request.urlopen(req)
            content = response.read()
            
            # Handle base64 encoded content (common in subscription links)
            try:
                decoded_content = base64.b64decode(content).decode('utf-8')
                return decoded_content
            except:
                # If not base64 encoded, return as is (might be plain text)
                return content.decode('utf-8')
        
        except urllib.error.URLError as e:
            print(f"Error fetching subscription: {e}")
            return None
        except Exception as e:
            print(f"Unexpected error fetching subscription: {e}")
            return None
    
    def parse_subscription_content(self, content: str) -> List[Dict]:
        """
        Parse subscription content into a list of proxy configurations.
        
        Args:
            content: Raw subscription content
        
        Returns:
            List of proxy configurations
        """
        proxies = []
        
        # Split content by lines
        lines = content.strip().split('\n')
        
        for line in lines:
            line = line.strip()
            if not line or line.startswith('#'):
                continue  # Skip empty lines and comments
            
            # Check if it's a VLESS URI
            if line.startswith('vless://'):
                config = parse_vless_uri(line)
                if config:
                    proxies.append(config)
            # Check if it's a VMess URI
            elif line.startswith('vmess://'):
                config = self.parse_vmess_uri(line)
                if config:
                    proxies.append(config)
            # Check if it's a Trojan URI
            elif line.startswith('trojan://'):
                config = self.parse_trojan_uri(line)
                if config:
                    proxies.append(config)
            # Check if it's a raw JSON config
            elif line.startswith('{') and line.endswith('}'):
                config = parse_mihomo_json_config(line)
                if config:
                    proxies.append(config)
        
        return proxies
    
    def parse_vmess_uri(self, vmess_uri: str) -> Optional[Dict]:
        """
        Parse a VMess URI into a configuration dictionary.
        """
        try:
            # Remove vmess:// prefix
            uri = vmess_uri[8:]
            
            # VMess URIs are base64 encoded JSON
            decoded = base64.b64decode(uri).decode('utf-8')
            vmess_config = json.loads(decoded)
            
            # Convert to our internal format
            config = {
                "protocol": "vmess",
                "uuid": vmess_config.get("id", ""),
                "server": vmess_config.get("add", ""),
                "port": int(vmess_config.get("port", 0)),
                "remark": vmess_config.get("ps", ""),
                "alterId": vmess_config.get("aid", 0),
                "security": vmess_config.get("scy", "auto"),
                "network": vmess_config.get("net", "tcp"),
                "tls": vmess_config.get("tls", "none"),
                "sni": vmess_config.get("sni", ""),
                "host": vmess_config.get("host", ""),
                "path": vmess_config.get("path", "/"),
            }
            
            return config
        except Exception as e:
            print(f"Error parsing VMess URI: {e}")
            return None
    
    def parse_trojan_uri(self, trojan_uri: str) -> Optional[Dict]:
        """
        Parse a Trojan URI into a configuration dictionary.
        """
        try:
            parsed = urllib.parse.urlparse(trojan_uri)
            
            if parsed.scheme != 'trojan':
                return None
            
            password = parsed.username
            server, port_str = parsed.hostname, str(parsed.port)
            
            config = {
                "protocol": "trojan",
                "password": password,
                "server": server,
                "port": int(port_str) if port_str else 443,
                "remark": urllib.parse.unquote(parsed.fragment) if parsed.fragment else "",
                "sni": parsed.hostname,
                "type": "tcp",
                "encryption": "none",
            }
            
            # Parse query parameters
            query_params = urllib.parse.parse_qs(parsed.query)
            if 'sni' in query_params:
                config['sni'] = query_params['sni'][0]
            if 'type' in query_params:
                config['type'] = query_params['type'][0]
            
            return config
        except Exception as e:
            print(f"Error parsing Trojan URI: {e}")
            return None
    
    def update_subscription(self, url: str) -> tuple[bool, str]:
        """
        Update a specific subscription by fetching its content and parsing it.
        
        Args:
            url: URL of the subscription to update
        
        Returns:
            Tuple of (success: bool, message: str)
        """
        # Find the subscription
        subscription = None
        for sub in self.subscriptions:
            if sub['url'] == url:
                subscription = sub
                break
        
        if not subscription:
            return False, "Subscription not found"
        
        if not subscription['enabled']:
            return False, "Subscription is disabled"
        
        # Fetch subscription content
        content = self.fetch_subscription_content(url)
        if not content:
            return False, "Failed to fetch subscription content"
        
        # Parse the content
        proxies = self.parse_subscription_content(content)
        
        # Save to a file or merge with existing configs
        # For now, we'll return the count of proxies found
        return True, f"Successfully updated subscription '{subscription['name']}' with {len(proxies)} proxies"
    
    def update_all_subscriptions(self) -> List[tuple[bool, str]]:
        """
        Update all enabled subscriptions.
        
        Returns:
            List of results for each subscription update
        """
        results = []
        for sub in self.subscriptions:
            if sub['enabled']:
                result = self.update_subscription(sub['url'])
                results.append(result)
        
        return results
    
    def get_subscription_list(self) -> List[Dict]:
        """
        Get the list of all subscriptions.
        """
        return self.subscriptions

# Global instance
subscription_manager = SubscriptionManager()

def add_subscription(name: str, url: str, enabled: bool = True) -> bool:
    """
    Add a new subscription.
    """
    return subscription_manager.add_subscription(name, url, enabled)

def remove_subscription(url: str) -> bool:
    """
    Remove a subscription.
    """
    return subscription_manager.remove_subscription(url)

def enable_subscription(url: str) -> bool:
    """
    Enable a subscription.
    """
    return subscription_manager.enable_subscription(url)

def disable_subscription(url: str) -> bool:
    """
    Disable a subscription.
    """
    return subscription_manager.disable_subscription(url)

def update_subscription(url: str) -> tuple[bool, str]:
    """
    Update a specific subscription.
    """
    return subscription_manager.update_subscription(url)

def update_all_subscriptions() -> List[tuple[bool, str]]:
    """
    Update all enabled subscriptions.
    """
    return subscription_manager.update_all_subscriptions()

def get_subscription_list() -> List[Dict]:
    """
    Get the list of all subscriptions.
    """
    return subscription_manager.get_subscription_list()

# Example usage
if __name__ == "__main__":
    # Example of how to use the subscription manager
    print("Available subscriptions:")
    subs = get_subscription_list()
    for sub in subs:
        print(f"- {sub['name']}: {sub['url']} (enabled: {sub['enabled']})")