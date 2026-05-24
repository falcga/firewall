import subprocess
import os
from pathlib import Path
import tempfile
import shutil
from typing import Optional

class GeoUpdateManager:
    """
    Manages updating geo databases (geoip.dat, geosite.dat) for mihomo and similar proxy applications.
    """
    
    def __init__(self, mihomo_home: Optional[str] = None):
        """
        Initialize the geo update manager.
        
        Args:
            mihomo_home: Path to mihomo installation directory. If None, tries common locations.
        """
        if mihomo_home:
            self.mihomo_home = Path(mihomo_home)
        else:
            # Try common mihomo installation paths
            possible_paths = [
                Path.home() / ".mihomo",
                Path("/usr/local/share/mihomo"),
                Path("/opt/mihomo"),
                Path("./mihomo"),
                Path("../mihomo"),
            ]
            
            for path in possible_paths:
                if path.exists():
                    self.mihomo_home = path
                    break
            else:
                # Default to current directory if none found
                self.mihomo_home = Path("./mihomo")
    
    def get_geo_database_paths(self):
        """
        Get paths to geo database files.
        """
        geoip_path = self.mihomo_home / "geoip.dat"
        geosite_path = self.mihomo_home / "geosite.dat"
        return geoip_path, geosite_path
    
    def check_existing_databases(self):
        """
        Check if geo databases already exist and return their status.
        """
        geoip_path, geosite_path = self.get_geo_database_paths()
        
        geoip_exists = geoip_path.exists()
        geosite_exists = geosite_path.exists()
        
        return {
            "geoip": {
                "exists": geoip_exists,
                "path": str(geoip_path),
                "size": geoip_path.stat().st_size if geoip_exists else 0
            },
            "geosite": {
                "exists": geosite_exists,
                "path": str(geosite_path),
                "size": geosite_path.stat().st_size if geosite_exists else 0
            }
        }
    
    def update_geodata(self, download_mirror: str = "https://github.com/MetaCubeX/meta-rules-dat/releases/latest/download/"):
        """
        Update geo databases from remote source.
        
        Args:
            download_mirror: Base URL for downloading geo databases
        """
        try:
            geoip_path, geosite_path = self.get_geo_database_paths()
            
            # Create temporary directory for downloads
            with tempfile.TemporaryDirectory() as temp_dir:
                temp_path = Path(temp_dir)
                
                # Download geoip.dat
                geoip_url = f"{download_mirror}geoip.dat"
                geoip_temp_path = temp_path / "geoip.dat"
                
                print(f"Downloading geoip.dat from {geoip_url}...")
                result = subprocess.run([
                    "curl", "-L", "-o", str(geoip_temp_path), geoip_url
                ], capture_output=True, text=True)
                
                if result.returncode != 0:
                    print(f"Failed to download geoip.dat: {result.stderr}")
                    # Try alternative mirror
                    alt_url = "https://raw.githubusercontent.com/Dreamacro/maxmind-geoip/release/geoip.dat"
                    print(f"Trying alternative source: {alt_url}")
                    result = subprocess.run([
                        "curl", "-L", "-o", str(geoip_temp_path), alt_url
                    ], capture_output=True, text=True)
                    
                    if result.returncode != 0:
                        return f"Failed to download geoip.dat from both sources: {result.stderr}"
                
                # Download geosite.dat
                geosite_url = f"{download_mirror}geosite.dat"
                geosite_temp_path = temp_path / "geosite.dat"
                
                print(f"Downloading geosite.dat from {geosite_url}...")
                result = subprocess.run([
                    "curl", "-L", "-o", str(geosite_temp_path), geosite_url
                ], capture_output=True, text=True)
                
                if result.returncode != 0:
                    print(f"Failed to download geosite.dat: {result.stderr}")
                    # Try alternative mirror
                    alt_url = "https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/geosite.dat"
                    print(f"Trying alternative source: {alt_url}")
                    result = subprocess.run([
                        "curl", "-L", "-o", str(geosite_temp_path), alt_url
                    ], capture_output=True, text=True)
                    
                    if result.returncode != 0:
                        return f"Failed to download geosite.dat from both sources: {result.stderr}"
                
                # Move downloaded files to destination
                geoip_path.parent.mkdir(parents=True, exist_ok=True)
                geosite_path.parent.mkdir(parents=True, exist_ok=True)
                
                shutil.move(str(geoip_temp_path), str(geoip_path))
                shutil.move(str(geosite_temp_path), str(geosite_path))
                
                return "Geo databases updated successfully!"
                
        except Exception as e:
            return f"Error updating geo databases: {str(e)}"
    
    def force_update_geodata(self):
        """
        Force update geo databases, overwriting existing files.
        """
        return self.update_geodata()
    
    def backup_current_databases(self, backup_dir: Optional[str] = None):
        """
        Create a backup of current geo databases.
        
        Args:
            backup_dir: Directory to store backups. If None, uses mihomo_home/backup
        """
        try:
            if backup_dir is None:
                backup_path = self.mihomo_home / "backup"
            else:
                backup_path = Path(backup_dir)
            
            backup_path.mkdir(parents=True, exist_ok=True)
            
            geoip_path, geosite_path = self.get_geo_database_paths()
            
            timestamp = __import__('datetime').datetime.now().strftime("%Y%m%d_%H%M%S")
            
            if geoip_path.exists():
                backup_geoip = backup_path / f"geoip_backup_{timestamp}.dat"
                shutil.copy2(geoip_path, backup_geoip)
            
            if geosite_path.exists():
                backup_geosite = backup_path / f"geosite_backup_{timestamp}.dat"
                shutil.copy2(geosite_path, backup_geosite)
            
            return f"Databases backed up to {backup_path}"
        except Exception as e:
            return f"Error backing up databases: {str(e)}"

# Global instance
geo_update_manager = GeoUpdateManager()

def update_geodata():
    """
    Update geo databases.
    """
    return geo_update_manager.update_geodata()

def check_geodata_status():
    """
    Check the status of geo databases.
    """
    return geo_update_manager.check_existing_databases()

def force_update_geodata():
    """
    Force update geo databases, overwriting existing files.
    """
    return geo_update_manager.force_update_geodata()

def backup_geodata(backup_dir: Optional[str] = None):
    """
    Backup current geo databases.
    """
    return geo_update_manager.backup_current_databases(backup_dir)

# Example usage
if __name__ == "__main__":
    print("Checking current geo database status...")
    status = check_geodata_status()
    print(status)
    
    print("\nUpdating geo databases...")
    result = update_geodata()
    print(result)