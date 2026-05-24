import json
import urllib.parse

def parse_vless_uri(uri):
    """Parses a vless URI into a dictionary of configuration details."""
    try:
        # vless://UUID@SERVER:PORT?PARAMS#REMARK
        parsed_uri = urllib.parse.urlparse(uri)
        if parsed_uri.scheme != "vless":
            raise ValueError("Invalid scheme, expected 'vless'")

        user_info, netloc = parsed_uri.netloc.split("@", 1)
        uuid = user_info
        server, port = netloc.split(":", 1)

        query_params = urllib.parse.parse_qs(parsed_uri.query)
        remark = urllib.parse.unquote(parsed_uri.fragment)

        config = {
            "protocol": "vless",
            "uuid": uuid,
            "server": server,
            "port": int(port),
            "remark": remark,
            "flow": query_params.get("flow", [None])[0],
            "encryption": query_params.get("encryption", ["none"])[0],
            "security": query_params.get("security", [None])[0],
            "type": query_params.get("type", [None])[0],
            "headerType": query_params.get("headerType", [None])[0],
            "host": query_params.get("host", [None])[0],
            "path": query_params.get("path", [None])[0],
            "sni": query_params.get("sni", [None])[0],
            "fp": query_params.get("fp", [None])[0],
            "pbk": query_params.get("pbk", [None])[0],
            "sid": query_params.get("sid", [None])[0],
        }
        return config
    except Exception as e:
        print(f"Error parsing vless URI: {e}")
        return None

def parse_mihomo_json_config(json_string):
    """Parses a JSON string into a dictionary of configuration details.
    Assumes the JSON describes a single Mihomo outbound proxy configuration.
    """
    try:
        config = json.loads(json_string)
        # Basic validation: check for essential fields if possible, or assume well-formed.
        # For a basic proxy, we might expect 'protocol', 'settings', 'tag' etc.
        # This part might need refinement based on actual Mihomo config examples.
        if not isinstance(config, dict):
            raise ValueError("JSON is not a valid object.")
        if "protocol" not in config:
            # If it's a full outbound object, 'protocol' would be a top-level key
            # If it's a 'proxy' object (e.g., from a subscription list), it might have 'type' or similar.
            # For simplicity, let's assume 'protocol' is directly present or can be inferred.
            # More robust parsing would involve checking different structures.
            # For now, let's just ensure it's a dictionary.
            pass # Will try to extract more specific fields later if needed.

        # Standardize the config to match what parse_vless_uri generates for consistency
        # This will require making assumptions about how the JSON maps to the table columns.
        # For now, let's extract some common fields if they exist.
        # This is a simplified mapping and might need to be expanded.
        extracted_config = {
            "protocol": config.get("protocol", config.get("type", "Unknown")), # 'protocol' for v2ray-style, 'type' for clash-style
            "remark": config.get("tag", config.get("name", f"JSON Proxy")), # 'tag' for v2ray-style, 'name' for clash-style
            "server": config.get("settings", {}).get("vnext", [{}])[0].get("address") if config.get("protocol") == "vless" else config.get("server"),
            "port": config.get("settings", {}).get("vnext", [{}])[0].get("port") if config.get("protocol") == "vless" else config.get("port"),
            # Add other fields as necessary, matching parse_vless_uri's output
            "uuid": config.get("settings", {}).get("vnext", [{}])[0].get("users", [{}])[0].get("id") if config.get("protocol") == "vless" else None,
            "encryption": config.get("settings", {}).get("vnext", [{}])[0].get("users", [{}])[0].get("encryption") if config.get("protocol") == "vless" else None,
            # For other fields, direct mapping is harder without a definitive JSON structure.
            # We can just store the full JSON config for now and display what we can.
            "full_json_config": config # Store the original full JSON for later use if needed
        }

        return {k: v for k, v in extracted_config.items() if v is not None} # Remove None values
    except json.JSONDecodeError as e:
        print(f"Error decoding JSON: {e}")
        return None
    except Exception as e:
        print(f"Error parsing Mihomo JSON config: {e}")
        return None

def save_configs(configs, file_path="z:\home\falcga\lms\firewall\v2ray_tui\configs.json"):
    """Saves a list of configurations to a JSON file."""
    try:
        with open(file_path, "w", encoding="utf-8") as f:
            json.dump(configs, f, indent=4)
        return True
    except Exception as e:
        print(f"Error saving configurations: {e}")
        return False

def load_configs(file_path="z:\home\falcga\lms\firewall\v2ray_tui\configs.json"):
    """Loads configurations from a JSON file."""
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        return []
    except Exception as e:
        print(f"Error loading configurations: {e}")
        return []

if __name__ == "__main__":
    # Example usage
    vless_uri = "vless://your-uuid@your-server.com:443?encryption=none&security=tls&type=ws&host=your-domain.com&path=%2Fyourpath%3Fed%3D2048#MyVlessProxy"
    config = parse_vless_uri(vless_uri)
    if config:
        print("Parsed VLESS Config:", config)
        configs = load_configs()
        configs.append(config)
        save_configs(configs)
        print("Configs saved.")

        loaded_configs = load_configs()
        print("Loaded Configs:", loaded_configs)
