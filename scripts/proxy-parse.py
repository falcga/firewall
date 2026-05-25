#!/usr/bin/env python3
"""
Minimal Python helper for proxy URI parsing.
Used by bash TUI and shell2http endpoints — only what bash CANNOT do:
  - base64 decode (VMess, subscription content)
  - URI parsing with query parameters (VLESS, Trojan)
  - JSON manipulation
Output: always JSON (parseable by bash via `jq` or `python3 -c "import json,..."`)
"""
import json, sys, base64, urllib.parse, urllib.request, os

def parse_vless(uri):
    """Parse vless:// UUID@SERVER:PORT?params#remark → JSON"""
    try:
        p = urllib.parse.urlparse(uri)
        if p.scheme != "vless": return None
        user, netloc = (p.netloc.split("@", 1) if "@" in p.netloc else ("", p.netloc))
        server, port = (netloc.rsplit(":", 1) if ":" in netloc else (netloc, "443"))
        q = urllib.parse.parse_qs(p.query)
        return {
            "protocol": "vless", "uuid": urllib.parse.unquote(user),
            "server": server, "port": int(port),
            "remark": urllib.parse.unquote(p.fragment) if p.fragment else "",
            "flow": q.get("flow", [""])[0], "encryption": q.get("encryption", ["none"])[0],
            "security": q.get("security", [""])[0], "type": q.get("type", [""])[0],
            "host": q.get("host", [""])[0], "path": q.get("path", [""])[0],
            "sni": q.get("sni", [""])[0],
        }
    except: return None

def parse_vmess(uri):
    """Parse vmess:// base64json → JSON"""
    try:
        raw = uri[8:]  # remove vmess://
        data = json.loads(base64.b64decode(raw))
        return {
            "protocol": "vmess", "uuid": data.get("id",""),
            "server": data.get("add",""), "port": int(data.get("port",0)),
            "remark": data.get("ps",""), "alterId": data.get("aid",0),
            "security": data.get("scy","auto"), "network": data.get("net","tcp"),
            "tls": data.get("tls",""), "host": data.get("host",""),
            "path": data.get("path","/"),
        }
    except: return None

def parse_trojan(uri):
    """Parse trojan:// password@SERVER:PORT?params#remark → JSON"""
    try:
        p = urllib.parse.urlparse(uri)
        if p.scheme != "trojan": return None
        q = urllib.parse.parse_qs(p.query)
        return {
            "protocol": "trojan", "password": p.username or "",
            "server": p.hostname or "", "port": p.port or 443,
            "remark": urllib.parse.unquote(p.fragment) if p.fragment else "",
            "sni": q.get("sni", [p.hostname])[0],
            "type": q.get("type", ["tcp"])[0],
        }
    except: return None

def decode_subscription(url):
    """Fetch and decode subscription content → JSON array of proxies"""
    try:
        headers = {"User-Agent": "v2rayN/1.0"}
        req = urllib.request.Request(url, headers=headers)
        resp = urllib.request.urlopen(req, timeout=30)
        raw = resp.read()
        # Try base64 first
        try:
            text = base64.b64decode(raw).decode("utf-8")
        except:
            text = raw.decode("utf-8")
        proxies = []
        for line in text.strip().split("\n"):
            line = line.strip()
            if not line or line.startswith("#"): continue
            cfg = parse_vless(line) or parse_vmess(line) or parse_trojan(line)
            if cfg: proxies.append(cfg)
        return proxies
    except Exception as e:
        return {"error": str(e)}

def list_urls_from_config(config_path):
    """Extract subscription URLs from mihomo config"""
    import re
    urls = []
    try:
        with open(config_path) as f:
            for line in f:
                m = re.search(r"url:\s*['\"]?(https?://[^'\n\"]+)", line)
                if m:
                    urls.append(m.group(1))
    except: pass
    return urls

def encode_vless(cfg):
    """Rebuild a vless:// URI from config dict"""
    params = {}
    for k in ("flow","encryption","security","type","host","path","sni"):
        v = cfg.get(k,"")
        if v: params[k] = v
    qs = urllib.parse.urlencode(params)
    frag = urllib.parse.quote(cfg.get("remark",""))
    return f"vless://{cfg['uuid']}@{cfg['server']}:{cfg['port']}?{qs}#{frag}"

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    
    if cmd == "parse" and len(sys.argv) >= 3:
        uri = sys.argv[2]
        c = parse_vless(uri) or parse_vmess(uri) or parse_trojan(uri)
        print(json.dumps(c if c else {"error": "unrecognized format"}))
    
    elif cmd == "decode-sub" and len(sys.argv) >= 3:
        proxies = decode_subscription(sys.argv[2])
        print(json.dumps(proxies))
    
    elif cmd == "list-urls" and len(sys.argv) >= 3:
        urls = list_urls_from_config(sys.argv[2])
        print(json.dumps(urls))
    
    elif cmd == "encode-vless":
        cfg = json.loads(sys.stdin.read())
        print(encode_vless(cfg))
    
    elif cmd == "save-config":
        """Save/append proxy configs to v2ray_tui/configs.json"""
        configs_path = os.path.join(os.path.dirname(__file__), "..", "v2ray_tui", "configs.json")
        configs_path = os.path.normpath(configs_path)
        try:
            with open(configs_path) as f:
                configs = json.load(f)
        except:
            configs = []
        
        new_configs = json.loads(sys.stdin.read())
        if isinstance(new_configs, dict):
            new_configs = [new_configs]
        configs.extend(new_configs)
        os.makedirs(os.path.dirname(configs_path), exist_ok=True)
        with open(configs_path, "w") as f:
            json.dump(configs, f, indent=2)
        print(json.dumps({"ok": True, "count": len(new_configs)}))
    
    elif cmd == "load-configs":
        configs_path = os.path.join(os.path.dirname(__file__), "..", "v2ray_tui", "configs.json")
        configs_path = os.path.normpath(configs_path)
        try:
            with open(configs_path) as f:
                configs = json.load(f)
        except:
            configs = []
        print(json.dumps(configs))
    
    elif cmd == "fetch-subscription":
        """Fetch subscription URL and decode proxies → save to configs.json"""
        url = sys.argv[2] if len(sys.argv) >= 3 else ""
        if not url:
            print(json.dumps({"error": "no url provided"}))
            sys.exit(1)
        proxies = decode_subscription(url)
        if isinstance(proxies, dict) and "error" in proxies:
            print(json.dumps(proxies))
            sys.exit(1)
        # Save to configs
        configs_path = os.path.join(os.path.dirname(__file__), "..", "v2ray_tui", "configs.json")
        configs_path = os.path.normpath(configs_path)
        try:
            with open(configs_path) as f:
                existing = json.load(f)
        except:
            existing = []
        existing.extend(proxies)
        os.makedirs(os.path.dirname(configs_path), exist_ok=True)
        with open(configs_path, "w") as f:
            json.dump(existing, f, indent=2)
        print(json.dumps({"ok": True, "imported": len(proxies), "total": len(existing)}))
    
    else:
        print(json.dumps({"usage": {
            "parse": "proxy-parse.py parse <vless://|vmess://|trojan://>",
            "decode-sub": "proxy-parse.py decode-sub <subscription_url>",
            "list-urls": "proxy-parse.py list-urls <config.yaml>",
            "load-configs": "proxy-parse.py load-configs",
            "save-config": "proxy-parse.py save-config (reads JSON from stdin)",
            "fetch-subscription": "proxy-parse.py fetch-subscription <url>"
        }}))