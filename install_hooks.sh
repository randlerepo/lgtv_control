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
if [ ! -d ".venv" ]; then
    # Ensure uv is available or use pip
    if command -v uv >/dev/null 2>&1; then
        uv sync --locked
    else
        echo "Warning: 'uv' not found. Trying standard python venv..."
        python3 -m venv .venv
        .venv/bin/pip install -r <(python3 -c "import tomli; print('\n'.join(tomli.load(open('pyproject.toml', 'rb'))['project']['dependencies']))" 2>/dev/null || echo "aiowebostv>=0.4.0\nwakeonlan>=3.0.0")
        # Fallback to hardcoded deps if parsing fails or just rely on manual pip install
        .venv/bin/pip install "aiowebostv>=0.4.0" "wakeonlan>=3.0.0"
    fi
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
systemctl start lgtv-control.service

# Make sure permissions are correct
chown -R root:root "$INSTALL_DIR"
chmod -R 755 "$INSTALL_DIR"

echo "Installation complete."
echo "1. Config file will be stored in: $CONFIG_DIR/config.json"
echo "2. Run 'sudo $INSTALL_DIR/.venv/bin/python $INSTALL_DIR/lgtv_control.py auth <IP>' to pair."
