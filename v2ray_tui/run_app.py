#!/usr/bin/env python3
"""
Runner script for the v2ray TUI application.
"""

import sys
import os

# Add the v2ray_tui directory to the path so imports work correctly
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app import V2RayTUI

def main():
    """Main function to run the v2ray TUI application."""
    try:
        app = V2RayTUI()
        app.run()
    except KeyboardInterrupt:
        print("\nApplication interrupted by user.")
        sys.exit(0)
    except Exception as e:
        print(f"An error occurred: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()