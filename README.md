# Linux LGTV Control

Linux LGTV Control is a set of tools to control LG WebOS TVs from a Linux system. It allows you to turn the TV on (via Wake-on-LAN) and off (via WebOS API) programmatically. It is designed to run as a systemd sleep hook, automatically turning your TV on/off when your connected PC suspends or resumes, and as a systemd service, automatically turning your TV on when your PC boots and off when your PC shuts down.

## Features

- **Pairing**: Securely pairs with your LG TV using `aiowebostv`.
- **Power Control**: Turn TV On (WoL) and Off (API).
- **System Integration**: Automatically control TV power based on PC sleep/wake AND boot/shutdown state.
- **CLI**: Simple command-line interface for manual control.

## Prerequisites

- **LG WebOS TV**: Connected to the same network as your PC.
- **Wake-on-LAN**: Must be enabled on the TV (often called "Mobile TV On" or "Network Standby").
- **Python**: Version 3.12 or higher.
- **Package Manager**: [uv](https://github.com/astral-sh/uv) (recommended) or pip.

## Installation

1.  **Clone the repository**:
    ```bash
    git clone https://github.com/randlerepo/lgtv_control.git
    cd lgtv_control
    ```

2.  **Run the system installer** (Recommended):
    ```bash
    chmod +x ./install_hooks.sh
    sudo ./install_hooks.sh
    ```
    This will:
    - Install the application to `/opt/lgtv-control`.
    - Create a virtual environment and install dependencies.
    - Create configuration directory `/etc/lgtv-control`.
    - Install the systemd sleep hook (suspend/resume).
    - Install the systemd service (boot/shutdown).

    *Alternatively, for local user usage, you can just run `uv sync` and use the scripts directly, but system sleep integration requires the system install.*

## Configuration & Pairing

Before using the tool, you must pair it with your TV.

1.  **Find your TV's IP address**: Check your router or TV network settings.
2.  **Run the authentication command**:
    *For system/sleep hook usage (Run as Root):*
    ```bash
    sudo /opt/lgtv-control/.venv/bin/python /opt/lgtv-control/lgtv_control.py auth <TV_IP_ADDRESS>
    ```

    *For local user usage:*
    ```bash
    uv run lgtv_control.py auth <TV_IP_ADDRESS>
    ```

3.  **Accept the prompt**: A notification will appear on your TV screen. Select "Yes" or "Allow" using your TV remote.

4.  **Success**: The script will save your client key and MAC address (needed for WoL) to `/etc/lgtv-control/config.json` (system) or `~/.config/lgtv-control/config.json` (user).

**Set MAC Address Manually:**
If the MAC address wasn't captured during auth, or needs updating:
```bash
uv run lgtv_control.py setmac AA:BB:CC:DD:EE:FF
```

## Usage

### Manual Control

**Turn TV On:**
```bash
# System install
sudo /opt/lgtv-control/.venv/bin/python /opt/lgtv-control/lgtv_control.py on

# Local user
uv run lgtv_control.py on
```

**Turn TV Off:**
```bash
# System install
sudo /opt/lgtv-control/.venv/bin/python /opt/lgtv-control/lgtv_control.py off

# Local user
uv run lgtv_control.py off
```


## System Integration

The `install_hooks.sh` script automatically sets up two types of integration:

1.  **Sleep Hook** (`/lib/systemd/system-sleep/lgtv_sleep`):
    - Triggers on **Suspend**: Turns TV **OFF**.
    - Triggers on **Resume**: Turns TV **ON**.

2.  **Systemd Service** (`lgtv-control.service`):
    - Triggers on **Boot/Startup**: Turns TV **ON**.
    - Triggers on **Shutdown/Reboot**: Turns TV **OFF**.

To verify:
1.  Ensure you have paired as root (see Configuration above).
2.  Suspend/Resume or Reboot your PC. The TV should react accordingly.

## Troubleshooting

-   **TV not turning on:** Ensure "Mobile TV On" / "Turn on via Wi-Fi" is enabled in your LG TV Network settings. Ensure your PC and TV are on the same subnet.
-   **TV not turning off:** Ensure the TV IP hasn't changed. Assigning a static IP to the TV in your router is recommended.
-   **Connection refused:** The TV might be fully powered down (not in standby) or network-disconnected.

## License

[MIT License](LICENSE)
