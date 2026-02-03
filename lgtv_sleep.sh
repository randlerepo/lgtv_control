#!/bin/bash
# Systemd sleep hook for Linux LGTV Control
# Handled events: pre/suspend (suspend), post/suspend (resume)

# Absolute path to the project directory - UPDATED AUTOMATICALLY BY install_hooks.sh or manually set
PROJECT_DIR="/opt/lgtv-control"
PYTHON_BIN="$PROJECT_DIR/.venv/bin/python"

# Log output for debugging
exec 1> >(logger -s -t $(basename $0)) 2>&1

case "$1/$2" in
  pre/suspend)
    echo "System suspending... Turning off TV."
    cd "$PROJECT_DIR"
    "$PYTHON_BIN" lgtv_control.py off
    ;;
  post/suspend)
    echo "System resuming... Turning on TV."
    cd "$PROJECT_DIR"
    "$PYTHON_BIN" lgtv_control.py on
    ;;
  *)
    echo "Ignoring event: $1/$2"
    ;;
esac
