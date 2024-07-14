#!/bin/bash

# Constants
PHP_URL="http://api.rg3d.eu:8443/checkjob.php"
CCMINER_DIR="$HOME/ccminer"
CONFIG_FILE="$CCMINER_DIR/config.json"
JOBSCHEDULER_URL="http://api.rg3d.eu:8443/jobscheduler.sh"
RIG_CONF="$HOME/rig.conf"

# Function to handle jobs
handle_job() {
    job_id=$1
    job_action=$2
    job_settings=$3

    case $job_action in
        "Device restart")
            if [ "$OS_TYPE" = "Termux" ]; then
                su -c reboot
            else
                sudo reboot
            fi
            ;;
        "Miner config update")
            if [ -f "$CONFIG_FILE" ]; then
                rm "$CONFIG_FILE"
            fi
            echo "$job_settings" > "$CONFIG_FILE"
            ;;
        "Miner start")
            screen -dmS CCminer $CCMINER_DIR/ccminer -c $CONFIG_FILE
            ;;
        "Miner stop")
            screen -S CCminer -X quit
            ;;
        "Miner restart")
            screen -S CCminer -X quit
            screen -dmS CCminer $CCMINER_DIR/ccminer -c $CONFIG_FILE
            ;;
        "Miner software update")
            screen -S CCminer -X quit
            rm "$CCMINER_DIR/ccminer"
            wget -O "$CCMINER_DIR/ccminer" "$job_settings"
            chmod +x "$CCMINER_DIR/ccminer"
            screen -dmS CCminer $CCMINER_DIR/ccminer -c $CONFIG_FILE
            ;;
        "Management script update")
            wget -O "$HOME/jobscheduler.sh" "$job_settings"
            chmod +x "$HOME/jobscheduler.sh"
            ;;
        "Termux update and upgrade")
            if [ "$OS_TYPE" = "Termux" ]; then
                pkg update -y && pkg upgrade -y
            else
                sudo apt update -y && sudo apt upgrade -y
            fi
            ;;
    esac

    # Send job completion
    curl -X POST -d "job_id=$job_id&status=complete" $PHP_URL
}

# Get rig password from config file
if [ -f "$RIG_CONF" ]; then
    source "$RIG_CONF"
else
    echo "Configuration file $RIG_CONF not found!"
    exit 1
fi

# Determine OS type
if [ -n "$ANDROID_ROOT" ] && [ -d "$ANDROID_ROOT" ] && [ -d "$PREFIX" ]; then
    OS_TYPE="Termux"
else
    OS_TYPE=$(uname -s)
fi

# Function to get the IP address
get_ip_address() {
    local ip_address=""
    local cmd_output=""

    # Try to get the Ethernet IP address
    cmd_output=$(ip -4 addr show eth0 2>&1)
    if echo "$cmd_output" | grep -q "Permission denied"; then
        cmd_output=$(su -c "ip -4 addr show eth0" 2>&1)
    fi
    ip_address=$(echo "$cmd_output" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
    
    if [ -z "$ip_address" ]; then
        # Fallback to WLAN IP address
        cmd_output=$(ip -4 addr show wlan0 2>&1)
        if echo "$cmd_output" | grep -q "Permission denied"; then
            cmd_output=$(su -c "ip -4 addr show wlan0" 2>&1)
        fi
        ip_address=$(echo "$cmd_output" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
    fi

    echo "$ip_address"
}

# Get miner IP
MINER_IP=$(get_ip_address)

if [ -z "$MINER_IP" ]; then
    echo "Unable to determine IP address."
    exit 1
fi

# Main loop
while true; do
    response=$(curl -X POST -d "rig_pw=$rig_pw&miner_ip=$MINER_IP" $PHP_URL)

    job_id=$(echo $response | jq -r '.job_id')
    job_action=$(echo $response | jq -r '.job_action')
    job_settings=$(echo $response | jq -r '.job_settings')

    if [ "$job_id" != "null" ]; then
        handle_job $job_id "$job_action" "$job_settings"
    fi

    sleep 120
done
