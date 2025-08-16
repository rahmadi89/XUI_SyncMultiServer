#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

APP_NAME="XUI_SyncMultiServer"
APP_DIR="$HOME/.${APP_NAME}"
PYTHON_PATH=$(which python3)
SCRIPT_NAME="main.py"
CONFIG_FILE="$APP_DIR/servers.json"
CRON_JOB="* * * * * cd $APP_DIR && $PYTHON_PATH $APP_DIR/$SCRIPT_NAME"
# CRON_JOB="* * * * * cd $APP_DIR && $PYTHON_PATH $APP_DIR/$SCRIPT_NAME >> $APP_DIR/cron.log 2>&1"


# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Fatal error: ${plain} Please run this script with root privilege \n " && exit 1

echo "=== $APP_NAME Installer ==="

if [ "$1" == "--uninstall" ]; then
    echo "Uninstalling $APP_NAME..."
    crontab -l 2>/dev/null | grep -vF "$CRON_JOB" | crontab -
    rm -rf "$APP_DIR"
    echo "$APP_NAME has been removed."
    exit 0
fi

if [ -d "$APP_DIR" ]; then
    echo "$APP_NAME is already installed in: $APP_DIR"
    read -p "Do you want to overwrite the existing installation? (y/N): " ANSWER
    case "$ANSWER" in
        [yY][eE][sS]|[yY]) echo "Proceeding with overwrite..." ;;
        *) echo "Installation aborted."; exit 0 ;;
    esac
fi

apt-get update && apt-get install -y wget curl tar tzdata

mkdir -p "$APP_DIR"
echo "Downloading files..."
curl -O https://raw.githubusercontent.com/rahmadi89/repo/XUI_SyncMultiServer/main.py


if [ -f "$SCRIPT_NAME" ]; then
    mv "$SCRIPT_NAME" "$APP_DIR/"
    chmod +x "$APP_DIR/$SCRIPT_NAME"
else
    echo "Error: $SCRIPT_NAME not found in current directory."
    exit 1
fi

echo "Now let's configure your servers."
servers=()

while true; do
    echo "Enter server name (or leave empty to finish):"
    read NAME
    if [ -z "$NAME" ]; then
        break
    fi

    echo "Enter base_url for '$NAME':"
    read BASE_URL

    echo "Enter username for '$NAME':"
    read USER

    echo "Enter password for '$NAME':"
    read -s PASS
    echo

    # Escape double quotes in inputs
    esc_NAME=$(printf '%s' "$NAME" | sed 's/"/\\"/g')
    esc_BASE_URL=$(printf '%s' "$BASE_URL" | sed 's/"/\\"/g')
    esc_USER=$(printf '%s' "$USER" | sed 's/"/\\"/g')
    esc_PASS=$(printf '%s' "$PASS" | sed 's/"/\\"/g')

    # Append JSON object string to array
    servers+=("{\"name\": \"$esc_NAME\", \"base_url\": \"$esc_BASE_URL\", \"user\": \"$esc_USER\", \"pass\": \"$esc_PASS\"}")
done

if [ ${#servers[@]} -eq 0 ]; then
    echo "No servers configured. Exiting."
    exit 1
fi

# Build final JSON array string
json="["
json+=$(IFS=, ; echo "${servers[*]}")
json+="]"

echo "$json" > "$CONFIG_FILE"
echo "Config saved to $CONFIG_FILE"

# Setup cron
if crontab -l 2>/dev/null | grep -F "$CRON_JOB" >/dev/null; then
    echo "Cron job already exists. Skipping cron setup."
else
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
    echo "Cron job added to run every minute."
fi

echo "=== Installation complete! ==="
echo "$APP_NAME is now scheduled to run every minute."
