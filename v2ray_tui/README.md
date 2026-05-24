# v2rayN-like TUI for Proxy Management

A Text User Interface (TUI) application for managing proxy configurations inspired by v2rayN's functionality, built with Python and Textual.

## Features

- **Proxy Management**: Add, edit, delete, and activate/deactivate proxy configurations
- **Supports Multiple Protocols**: VLESS, VMess, Trojan, and JSON configurations
- **Subscription Management**: Add, update, and manage proxy subscriptions
- **System Proxy Control**: Enable/disable system-wide proxy settings
- **Logging**: Comprehensive logging with log viewing capabilities
- **Geo Database Updates**: Update geoip.dat and geosite.dat databases
- **Mihomo Integration**: Uses mihomo as the backend proxy engine

## Installation

```bash
pip install textual
```

## Usage

Run the application:

```bash
python -m v2ray_tui.app
```

### Keyboard Shortcuts

- `q` - Quit the application
- `1` - Manage Proxies
- `2` - Toggle Global Settings (System Proxy)
- `3` - Start Proxy
- `4` - Stop Proxy
- `5` - Test Connectivity (Not Implemented)
- `l` - View Logs
- `s` - Manage Subscriptions
- `g` - Update Geo Databases

### Within Proxy Management Screen

- `b` - Go Back
- `a` - Add Proxy
- `e` - Edit Proxy
- `d` - Delete Proxy
- `t` - Toggle Active Proxy

### Within Subscription Management Screen

- `b` - Go Back
- `a` - Add Subscription
- `e` - Enable/Disable Subscription
- `u` - Update Selected Subscription
- `ua` - Update All Subscriptions
- `d` - Delete Subscription

## Configuration

The application stores proxy configurations in `configs.json` and subscription information in `subscriptions.json`.

## Backend

This application uses mihomo as the backend proxy engine. Make sure mihomo is installed and properly configured on your system.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.