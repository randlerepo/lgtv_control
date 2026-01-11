#!/bin/bash
# Test Suite for LGTV Companion

set -e

PROJECT_DIR="$(pwd)"
CONFIG_FILE="lgtv_config.json"

echo "=== Linux LGTV Control Test Suite ==="
echo "Project Directory: $PROJECT_DIR"
echo ""

# 1. Dependency Check
echo "[1/6] Checking Dependencies..."
if ! command -v uv &> /dev/null; then
    echo "ERROR: 'uv' is not installed. Please install uv first."
    exit 1
fi
echo "Installing/Syncing Python dependencies..."
uv sync
echo "Dependencies OK."
echo ""

# 2. Configuration & Auth
echo "[2/6] Configuration & Authentication"
if [ -f "$CONFIG_FILE" ]; then
    echo "Found existing config: $CONFIG_FILE"
    grep -v "client_key" "$CONFIG_FILE" # Show config excluding secret key
    read -p "Do you want to re-authenticate/re-configure? (y/N): " REAUTH
else
    REAUTH="y"
fi

if [[ "$REAUTH" =~ ^[Yy]$ ]]; then
    read -p "Enter TV IP Address: " TV_IP
    read -p "Enter TV MAC Address: " TV_MAC
    
    echo "Running Auth (Check TV screen to accept connection)..."
    uv run lgtv_control.py auth "$TV_IP"
    
    echo "Setting MAC address..."
    uv run lgtv_control.py setmac "$TV_MAC"
fi
echo "Configuration OK."
echo ""

# 3. Test Power Off (Direct)
echo "[3/6] Test Power OFF (Direct)"
echo "This will turn off the TV immediately."
read -p "Press Enter to execute 'uv run lgtv_control.py off' (or Ctrl+C to cancel)..."
uv run lgtv_control.py off
echo "Command sent. Was the TV turned off?"
echo ""

# 4. Test Power On (Direct / WoL)
echo "[4/6] Test Power ON (Direct)"
echo "Waiting 5 seconds to ensure TV is fully off..."
sleep 5
echo "Turning TV ON..."
uv run lgtv_control.py on
echo "Command sent (WoL). Did the TV turn on?"
echo ""

# 5. Test System Sleep Hook (Suspend)
echo "[5/6] Test Sleep Hook (Suspend Simulation)"
read -p "Ensure TV is ON. Press Enter to simulate SYSTEM SUSPEND event..."
# The hook script expects to be in the same dir or finds it? 
# Our lgtv_sleep.sh uses absolute paths, but for testing we want to use the local one.
# Let's temporarily export the PROJECT_DIR for the script if it supports it, 
# or just run it and hope the hardcoded path matches (it should if we generated it correctly).
./lgtv_sleep.sh pre suspend
echo "Hook executed. Did the TV turn OFF?"
echo ""

# 6. Test System Sleep Hook (Resume)
echo "[6/6] Test Sleep Hook (Resume Simulation)"
echo "Waiting 5 seconds..."
sleep 5
read -p "Press Enter to simulate SYSTEM RESUME event..."
./lgtv_sleep.sh post suspend
echo "Hook executed. Did the TV turn ON?"
echo ""

echo "=== Test Suite Completed ==="
echo "If all steps worked, you can now run 'sudo ./install_hooks.sh' to install the system integration."
