#!/bin/bash
# Installs the lgtv_sleep.sh hook to /etc/systemd/system-sleep/

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="lgtv_sleep.sh"
TARGET_DIR="/lib/systemd/system-sleep"
TARGET_FILE="$TARGET_DIR/lgtv_sleep"

INSTALL_DIR="/opt/lgtv-control"
CONFIG_DIR="/etc/lgtv-control"

echo "Installing Linux LGTV Control..."

if [ "$EUID" -ne 0 ]; then 
  echo "Please run as root (sudo)."
  exit 1
fi

check_dependency() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Error: Missing dependency '$1'. Please install it and try again."
        exit 1
    fi
}

echo "Checking dependencies..."
check_dependency "python3"
check_dependency "systemctl"

# Check for uv or python3-venv
if ! command -v uv >/dev/null 2>&1; then
    # Check if python3-venv is available by trying to run the module
    if ! python3 -m venv --help >/dev/null 2>&1; then
        echo "Error: Neither 'uv' nor 'python3-venv' found. Please install 'uv' or the 'python3-venv' package."
        exit 1
    fi
fi

# 1. Create Directories
echo "Creating directories..."
mkdir -p "$INSTALL_DIR"
mkdir -p "$CONFIG_DIR"
mkdir -p "$TARGET_DIR"

# 2. Copy Files
echo "Copying files to $INSTALL_DIR..."
cp "$SCRIPT_DIR/lgtv_control.py" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/pyproject.toml" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/uv.lock" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/lgtv-control.service" "$INSTALL_DIR/"

# 3. Setup Virtual Environment
echo "Setting up virtual environment..."
cd "$INSTALL_DIR"

# Check for uv and prompt to install if missing
if ! command -v uv >/dev/null 2>&1; then
    echo "The 'uv' package manager is not installed."
    read -p "Would you like to install 'uv' (fast python package installer)? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Installing uv..."
        curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR="/usr/local/bin" sh
    else
        echo "Skipping uv installation. Will use standard pip."
    fi
fi

if command -v uv >/dev/null 2>&1; then
    echo "Using uv to sync dependencies..."
    uv sync --locked
else
    # Force standard python venv to avoid compatibility issues
    echo "Creating/Updating standard python venv..."
    if [ ! -d ".venv" ]; then
        python3 -m venv .venv
    fi

    echo "Installing dependencies..."
    # Force reinstall/upgrade of dependencies
    .venv/bin/pip install --upgrade pip
    .venv/bin/pip install --upgrade "aiowebostv>=0.4.0" "wakeonlan>=3.0.0"
fi

# 4. Install Sleep Hook
echo "Installing systemd sleep hook..."
cp "$SCRIPT_DIR/$SCRIPT_NAME" "$TARGET_FILE"
chmod +x "$TARGET_FILE"

# 5. Install Systemd Service (Boot/Shutdown)
echo "Installing systemd service..."
cp "$SCRIPT_DIR/lgtv-control.service" "/etc/systemd/system/lgtv-control.service"
systemctl daemon-reload
systemctl enable lgtv-control.service

# Only start the service if config exists
if [ -f "$CONFIG_DIR/config.json" ] || [ -f "/etc/lgtv-control/config.json" ]; then
    echo "Config found. Starting service..."
    systemctl start lgtv-control.service
else
    echo "Notice: Service enabled but NOT started."
    echo "Reason: Configuration file not found. Please pair first."
fi

# Make sure permissions are correct
chown -R root:root "$INSTALL_DIR"
chmod -R 755 "$INSTALL_DIR"

echo "Installation complete."
echo "1. Config file will be stored in: $CONFIG_DIR/config.json"
echo "2. Run 'sudo $INSTALL_DIR/.venv/bin/python $INSTALL_DIR/lgtv_control.py auth <IP>' to pair."
