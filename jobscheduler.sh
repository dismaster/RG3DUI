#!/bin/bash

# API endpoint and credentials
API_URL="https://api.rg3d.eu:8443/checkjob.php"

# Function to handle errors
handle_error() {
    echo "Error: $1"
    exit 1
}

# Function to determine miner_ip based on OS
get_miner_ip() {
    if [ -n "$(uname -o | grep Android)" ]; then
        # For Android
        if su -c true 2>/dev/null; then
            # SU rights are available
            ip=$(su -c ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v 127.0.0.1 | head -n 1)
        else
            # SU rights are not available
            ip=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v 127.0.0.1 | head -n 1)
        fi
    else
        # For other Unix systems
        ip=$(ip -4 -o addr show | awk '$2 !~ /lo|docker/ {print $4}' | cut -d "/" -f 1 | head -n 1)
    fi
    echo "$ip"
}

# Get miner_ip based on OS
MINER_IP=$(get_miner_ip)

# Function to read rig_pw from rig.conf file
read_rig_pw() {
    # Assuming rig.conf is in the home directory (~)
    local rig_conf="$HOME/rig.conf"
    if [ ! -f "$rig_conf" ]; then
        handle_error "rig.conf file not found at $rig_conf"
    fi
    # Extract rig_pw from rig.conf
    rig_pw=$(grep -Po '(?<=rig_pw=).*' "$rig_conf")
    if [ -z "$rig_pw" ]; then
        handle_error "rig_pw not found in $rig_conf"
    fi
    echo "$rig_pw"
}

# Get rig_pw from rig.conf
RIG_PW=$(read_rig_pw)

# Make request to API and handle response
response=$(curl -s -X POST -d "rig_pw=$RIG_PW&miner_ip=$MINER_IP" $API_URL)

# Check if curl request was successful
if [ $? -ne 0 ]; then
    handle_error "Failed to make API request"
fi

# Check if response is a valid JSON
echo $response | jq . >/dev/null 2>&1
if [ $? -ne 0 ]; then
    handle_error "Error: Response is not valid JSON"
fi

# Parse JSON response
job_id=$(echo $response | jq -r '.job_id')
job_action=$(echo $response | jq -r '.job_action')
job_settings=$(echo $response | jq -r '.job_settings')

# Check if job_action is supported
case $job_action in
    "Device restart")
        echo "Performing device restart..."
        su -c reboot
        ;;
    "Miner start")
        echo "Starting miner..."
        screen -S CCminer -X quit  # Stop existing session if running
        screen -dmS CCminer ~/ccminer/ccminer -c ~/ccminer/config.json
        ;;
    "Miner stop")
        echo "Stopping miner..."
        screen -S CCminer -X quit  # Stop existing session if running
        ;;
    "Miner restart")
        echo "Restarting miner..."
        screen -S CCminer -X quit  # Stop existing session if running
        screen -dmS CCminer ~/ccminer/ccminer -c ~/ccminer/config.json
        ;;
    "Miner software update")
        echo "Performing miner software update..."
        # Example: Stop ccminer, update software, and start again
        screen -S CCminer -X quit
        rm ~/ccminer/ccminer  # Delete existing ccminer app
        # Example: Download new version from job_settings URL
        wget -O ~/ccminer/ccminer_new $job_settings
        mv ~/ccminer/ccminer_new ~/ccminer/ccminer
        chmod +x ~/ccminer/ccminer
        screen -dmS CCminer ~/ccminer/ccminer -c ~/ccminer/config.json
        ;;
    "Management script update")
        echo "Performing management script update..."
        # Example: Delete current jobscheduler.sh and download new version from job_settings URL
        rm ~/jobscheduler.sh
        wget -O ~/jobscheduler.sh $job_settings
        chmod +x ~/jobscheduler.sh
        ;;
    "Software update and upgrade")
        echo "Performing software update and upgrade..."
        # Check if OS is Termux
        if [ "$(uname)" == "Linux" ] && [ -d "/data/data/com.termux/files" ]; then
            yes | pkg update
        else
            sudo apt-get upgrade -y
        fi
        ;;
    *)  # Unsupported job action
        echo "Warning: Unsupported job action: $job_action"
        ;;
esac

# Notify server that job is complete if supported job action
if [ -n "$job_id" ]; then
    complete_response=$(curl -s -X POST -d "job_id=$job_id" https://api.rg3d.eu:8443/completejob.php)
    if [ $? -ne 0 ]; then
        handle_error "Failed to send job completion notification"
    fi
    echo "Job successfully completed."
else
    handle_error "No valid job_id received from API"
fi

exit 0
