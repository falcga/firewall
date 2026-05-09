.PHONY: chmod
chmod:
	find scripts contrib contrib/install contrib/install/parts -maxdepth 1 -type f -name '*.sh' -exec chmod +x {} \;
	find . -maxdepth 1 -type f \( -name 'install*.sh' -o -name 'install*.sh.example' \) -exec chmod +x {} \; 2>/dev/null || true
	chmod +x contrib/pick_github_asset.py contrib/shell2http-launcher.sh 2>/dev/null || true
