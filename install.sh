#!/usr/bin/env bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
NC='\033[0m' # No Color

APP_NAME="XUI_SyncMultiServer"
APP_DIR="$HOME/.${APP_NAME}"
PYTHON_PATH=$(which python3)
SCRIPT_NAME="main.py"
CONFIG_FILE="$APP_DIR/servers.json"
CRON_JOB="* * * * * cd $APP_DIR && $PYTHON_PATH $APP_DIR/$SCRIPT_NAME"
# CRON_JOB="* * * * * cd $APP_DIR && $PYTHON_PATH $APP_DIR/$SCRIPT_NAME >> $APP_DIR/cron.log 2>&1"


# Clean previous installation
echo "=== $APP_NAME Installer ==="
echo "Uninstalling previous version..."
crontab -l 2>/dev/null | grep -vF "$CRON_JOB" | crontab -
rm -rf "$APP_DIR"
echo "Previous version uninstalled."

if [ "$1" == "--uninstall" ]; then
    echo "$APP_NAME has been removed."
    exit 0
fi


# Install dependencies
if ! command -v git &> /dev/null; then
    echo "Installing git..."
    apt-get update && apt-get install -y git
fi
if ! command -v jq &> /dev/null; then
    echo "Installing jq..."
    apt-get update && apt-get install -y jq
fi

# Download repository
mkdir -p "$APP_DIR"
echo -e "${yellow}Downloading files...${NC}"
curl -O https://raw.githubusercontent.com/rahmadi89/XUI_SyncMultiServer/main/main.py



# Set permissions
if [ -f "$SCRIPT_NAME" ]; then
    mv "$SCRIPT_NAME" "$APP_DIR/"
    chmod +x "$APP_DIR/$SCRIPT_NAME"
else
    echo "Error: $SCRIPT_NAME not found in current directory."
    exit 1
fi

# Configure servers
echo -e "${yellow}Now let's configure your servers.${NC}"
servers=()

while true; do
    echo -e "${yellow}Enter server name (or leave empty to finish, example: Germany):${NC}"
    read NAME
    if [ -z "$NAME" ]; then
        break
    fi

    echo -e "${yellow}Enter base_url for '$NAME' (example: http://example.com:12345/ahslv982d92mjd8):${NC}"
    read BASE_URL

    echo -e "${yellow}Enter username for '$NAME':${NC}"
    read USER

    echo -e "${yellow}Enter password for '$NAME':${NC}"
    read -s PASS
    echo

    echo -e "${yellow}Please wait while testing login informations...${NC}"

    # Escape double quotes in inputs (and final slash in url) 
    esc_NAME=$(printf '%s' "$NAME" | sed 's/"/\\"/g')
    esc_BASE_URL=$(printf '%s' "${BASE_URL%/}" | sed 's/"/\\"/g')
    esc_USER=$(printf '%s' "$USER" | sed 's/"/\\"/g')
    esc_PASS=$(printf '%s' "$PASS" | sed 's/"/\\"/g')

    # Test login using curl with escaped values
    response=$(curl -s -X POST "$esc_BASE_URL/login" \
        -d "username=$esc_USER&password=$esc_PASS" \
        -k \
        --connect-timeout 5 \
        --max-time 10)

    
    # Extract the "success" field from JSON (requires jq)
    success=$(echo "$response" | jq -r '.success' 2>/dev/null || echo "false")

    if [ "$success" != "true" ]; then
        echo -e "${red}[!] Login failed for $esc_USER@$esc_BASE_URL${NC}"
        echo "Message: $(echo "$response" | jq -r '.msg' 2>/dev/null || echo "Unknown error")"
        continue
    fi
    
    # Append JSON object string to array
    servers+=("{\"name\": \"$esc_NAME\", \"base_url\": \"$esc_BASE_URL\", \"user\": \"$esc_USER\", \"pass\": \"$esc_PASS\"}")
    echo -e "${green}[+] Login successful for $USER@$esc_BASE_URL. Server added.${NC}"
done

if [ ${#servers[@]} -eq 0 ]; then
    echo -e "${red}No servers configured. Exiting.${NC}"
    exit 1
fi

# Build final JSON array string
json="["
json+=$(IFS=, ; echo "${servers[*]}")
json+="]"

echo "$json" > "$CONFIG_FILE"
echo -e "${green}Config saved to $CONFIG_FILE ${NC}"

# Setup cron
if crontab -l 2>/dev/null | grep -F "$CRON_JOB" >/dev/null; then
    echo -e "${yellow}Cron job already exists. Skipping cron setup.${NC}"
else
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
    echo -e "${green}Cron job added to run every minute.${NC}"
fi

# Display success message
echo
echo "===== Installation complete! ====="
echo "$APP_NAME is now scheduled to run every minute."
