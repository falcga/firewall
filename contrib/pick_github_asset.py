#!/usr/bin/env python3
""" Выбрать browser_download_url по подстроке в имени и суффиксу (для установщика). """

import json
import sys
import urllib.request

if len(sys.argv) < 5:
	sys.stderr.write("usage: pick_github_asset.py OWNER REPO TOKEN_IN_NAME SUFFIX (.gz|.tar.gz)\n")
	sys.exit(2)

OWNER, REPO, TOKEN, SUFFIX = sys.argv[1:5]
TOKEN = TOKEN.encode().decode()

url = f"https://api.github.com/repos/{OWNER}/{REPO}/releases/latest"


def main() -> None:
	with urllib.request.urlopen(url, timeout=60) as r:
		j = json.load(r)
	best_u = ""
	best_len = 10**9
	for a in j.get("assets") or []:
		name = a.get("name", "")
		u = a.get("browser_download_url")
		if not u or TOKEN not in name:
			continue
		if not name.endswith(SUFFIX):
			continue
		if any(x in name for x in ("-go120-", "-go123-")):
			continue
		if len(name) < best_len:
			best_len = len(name)
			best_u = u
	print(best_u)


if __name__ == "__main__":
	main()
