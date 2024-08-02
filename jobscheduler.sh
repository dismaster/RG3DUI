#!/bin/bash

# Enable debugging if -debug argument is provided
DEBUG=false
if [ "$1" == "-debug" ]; then
  DEBUG=true
fi

# Function to print debug messages
debug() {
  if [ "$DEBUG" = true ]; then
    echo "$1"
  fi
}

# Function to get the IP address
get_ip_address() {
if [ -n "$(uname -o | grep Android)" ]; then
  # For Android
  # First try without 'su'
  ip=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v 127.0.0.1)
  if [ -z "$ip" ]; then
    # If no IP address was found, try with 'ifconfig' and 'su'
    ip=$(su -c "ifconfig" 2>/dev/null | grep -oP '(?<=inet addr:)\d+(\.\d+){3}' | grep -v 127.0.0.1)
    if [ -z "$ip" ]; then
      if su -c true 2>/dev/null; then
        # SU rights are available
        ip=$(su -c "ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v 127.0.0.1")
      fi
    fi
  fi
else
  # For other Unix systems
  ip=$(ip -4 -o addr show | awk '$2 !~ /lo|docker/ {print $4}' | cut -d "/" -f 1 | head -n 1)
fi
  echo $ip
}

# Function to restart ccminer
restart_ccminer() {
  screen -S CCminer -X quit
  screen -dmS CCminer ~/ccminer/ccminer -c ~/ccminer/config.json
}

# Function to check internet connection and restart WiFi if down
check_internet_connection() {
  x=$(ping -c1 google.com 2>&1 | grep unknown)
  if [ ! "$x" = "" ]; then
    debug "Internet is down! Attempting to restart network."
    if [ -n "$(uname -o | grep Android)" ]; then
      if su -c true 2>/dev/null; then
        # SU rights are available
        su -c input keyevent 26
        su -c svc wifi disable
        su -c svc wifi enable
      else
        debug "No root access to restart WiFi on Android."
      fi
    elif [ -n "$(uname -m | grep arm)" ]; then
      # For Raspberry Pi (assuming Debian-based OS)
      sudo ifconfig wlan0 down
      sudo ifconfig wlan0 up
    else
      debug "Unsupported device for network restart."
    fi
  fi
}

# Read rig_pw and miner_id from ~/rig.conf
rig_pw=$(grep 'rig_pw' ~/rig.conf | cut -d '=' -f 2 | tr -d ' ')
miner_id=$(grep 'miner_id' ~/rig.conf | cut -d '=' -f 2 | tr -d ' ')

# Get the IP address
miner_ip=$(get_ip_address)

# Check internet connection
check_internet_connection

# Send data to PHP script and get response
if [ -n "$miner_id" ]; then
  response=$(curl -s -X POST -d "rig_pw=$rig_pw&miner_id=$miner_id&miner_ip=$miner_ip" https://api.rg3d.eu:8443/checkjob.php)
else
  response=$(curl -s -X POST -d "rig_pw=$rig_pw&miner_ip=$miner_ip" https://api.rg3d.eu:8443/checkjob.php)
fi

# Debugging output
debug "Response from API: $response"

# Parse response
job_id=$(echo $response | jq -r '.job_id' 2>/dev/null)
job_action=$(echo $response | jq -r '.job_action' 2>/dev/null)
job_settings=$(echo $response | jq -r '.job_settings' 2>/dev/null)
rig_fs=$(echo $response | jq -r '.rig_fs' 2>/dev/null)
cpu_miner=$(echo $response | jq -r '.cpu_miner' 2>/dev/null)
cpu_max=$(echo $response | jq -r '.cpu_max' 2>/dev/null)

# Handle flightsheet configuration
config_file=~/ccminer/config.json
restart_required=false

# Fetch the new configuration from the server
config_response=$(curl -s -X POST -d "rig_pw=$rig_pw&miner_ip=$miner_ip" https://api.rg3d.eu:8443/getconfig.php)
config_response_parsed=$(echo "$config_response" | jq -S .)

# Update threads in the new configuration
threads=${cpu_miner:-$cpu_max}
config_response_parsed=$(echo "$config_response_parsed" | jq ".threads = $threads")

# Compare the new configuration with the current configuration
if [ -f "$config_file" ]; then
  current_config=$(jq -S . "$config_file")
else
  current_config=""
fi

if [ "$config_response_parsed" != "$current_config" ]; then
  echo "$config_response_parsed" > "$config_file"
  restart_required=true
  debug "Configuration updated from API."
else
  debug "No changes to the configuration needed."
fi

# Perform actions based on the job type received
case $job_action in
    "Miner config update")
      debug "Miner config update received."
      restart_required=true
      ;;
    "Miner start")
        restart_required=true
        ;;
    "Miner stop")
        screen -S CCminer -X quit
        ;;
    "Miner restart")
        restart_required=true
        ;;
    "Miner software update")
        screen -S CCminer -X quit
        wget -q -O ~/ccminer/ccminer "$job_settings"
        chmod +x ~/ccminer/ccminer
        restart_required=true
        ;;
    "Management script update")
        if [ -f ~/jobscheduler.sh ]; then
            rm ~/jobscheduler.sh
        fi
        wget -q -O ~/jobscheduler.sh "https://raw.githubusercontent.com/dismaster/RG3DUI/main/jobscheduler.sh"
        chmod +x ~/jobscheduler.sh
        ;;
    "Monitoring Software update")
        if [ -f ~/monitor.sh ]; then
            rm ~/monitor.sh
        fi
        wget -q -O ~/monitor.sh "https://raw.githubusercontent.com/dismaster/RG3DUI/main/monitor.sh"
        chmod +x ~/monitor.sh
        ;;
    "Termux Boot update")
        if [ -f ~/.termux/boot/boot_start ]; then
            rm ~/.termux/boot/boot_start
        fi
        wget -q -O ~/.termux/boot/boot_start "https://raw.githubusercontent.com/dismaster/RG3DUI/main/boot_start"
        chmod +x ~/.termux/boot/boot_start
        ;;
    *)
        debug "Unsupported job action: $job_action"
        ;;
esac

# Notify the server about job completion
if [ -n "$job_id" ]; then
    complete_response=$(curl -s -X POST -d "job_id=$job_id" https://api.rg3d.eu:8443/completejob.php)
    if [ $? -ne 0 ]; then
        debug "Failed to send job completion notification"
    fi
    debug "Job successfully completed."
else
    debug "No valid job_id received from API"
fi

# Restart ccminer only if needed
if [ "$restart_required" = true ]; then
  restart_ccminer
fi
