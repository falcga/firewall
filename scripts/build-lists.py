#!/usr/bin/env python3
"""Generate all lists for zapret from upstream catalog.
   Can be run from anywhere. Uses FIREWALL_ROOT env or auto-detects."""
import os, sys

# Allow override via environment
FIREWALL_ROOT = os.environ.get("FIREWALL_ROOT", "")
if not FIREWALL_ROOT:
    # Auto-detect: look for catalog/upstream relative to script
    script_dir = os.path.dirname(os.path.abspath(__file__))
    parent = os.path.dirname(script_dir)
    if os.path.isdir(os.path.join(parent, "catalog")):
        FIREWALL_ROOT = parent
    else:
        FIREWALL_ROOT = "/opt/firewall"

BASE = FIREWALL_ROOT
UPSTREAM = os.path.join(BASE, "catalog", "upstream")
GENERATED = os.path.join(BASE, "state", "generated")

os.makedirs(GENERATED, exist_ok=True)

def read_stripped(path):
    with open(path, 'r', encoding='utf-8', errors='replace') as f:
        return [l.strip() for l in f.read().replace('\r', '').split('\n') if l.strip()]

# hostlist
hosts = set()
for fn in ["list-general.txt", "list-google.txt"]:
    fp = os.path.join(UPSTREAM, fn)
    if os.path.isfile(fp):
        for line in read_stripped(fp):
            if not line.startswith('#') and not line.startswith(';'):
                host = line.split()[0].lower().lstrip('.')
                if host and host[0].isalpha():
                    hosts.add(host)
path = os.path.join(GENERATED, "zapret-hostlist.txt")
with open(path, 'w') as f:
    f.write('\n'.join(sorted(hosts)) + '\n')
print(f"hostlist: {len(hosts)}")

# exclude hostlist
exclude = set()
for fn in ["list-exclude.txt"]:
    fp = os.path.join(UPSTREAM, fn)
    if os.path.isfile(fp):
        for line in read_stripped(fp):
            if not line.startswith('#') and not line.startswith(';'):
                host = line.split()[0].lower()
                if host and host[0].isalpha():
                    exclude.add(host)
path = os.path.join(GENERATED, "zapret-hostlist-exclude.txt")
with open(path, 'w') as f:
    f.write('\n'.join(sorted(exclude)) + '\n')
print(f"exclude: {len(exclude)}")

# IPs
ips = set()
for fn in ["ipset-all.txt", "ipset-all.backup.txt"]:
    fp = os.path.join(UPSTREAM, fn)
    if os.path.isfile(fp):
        for line in read_stripped(fp):
            if not line.startswith('#') and not line.startswith(';'):
                ip = line.split()[0].split('/')[0]
                if ip.count('.') == 3:
                    ips.add(ip)
path = os.path.join(GENERATED, "zapret-ip.txt")
with open(path, 'w') as f:
    f.write('\n'.join(sorted(ips)) + '\n')
print(f"ips: {len(ips)}")

# IP exclude
ipex = set()
for fn in ["ipset-exclude.txt"]:
    fp = os.path.join(UPSTREAM, fn)
    if os.path.isfile(fp):
        for line in read_stripped(fp):
            if not line.startswith('#') and not line.startswith(';'):
                ip = line.split()[0].split('/')[0]
                if ip.count('.') == 3:
                    ipex.add(ip)
path = os.path.join(GENERATED, "zapret-ip-exclude.txt")
with open(path, 'w') as f:
    f.write('\n'.join(sorted(ipex)) + '\n')
print(f"ip-exclude: {len(ipex)}")

print("ALL DONE")