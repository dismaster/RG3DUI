#!/bin/bash

# Version number
VERSION="1.1.5"

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
    ip=$(ifconfig 2> /dev/null | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '[0-9.]*' | grep -v 127.0.0.1)
    if [ -z "$ip" ]; then
      ip=$(su -c "ifconfig" 2>/dev/null | grep -oP '(?<=inet addr:)\d+(\.\d+){3}' | grep -v 127.0.0.1)
      if [ -z "$ip" ]; then
        if su -c true 2>/dev/null; then
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
        su -c input keyevent 26
        su -c svc wifi disable
        su -c svc wifi enable
      else
        debug "No root access to restart WiFi on Android."
      fi
    elif [ -n "$(uname -m | grep arm)" ]; then
      sudo ifconfig wlan0 down
      sudo ifconfig wlan0 up
    else
      debug "Unsupported device for network restart."
    fi
  fi
}

# Function to perform a curl request with SSL support check
curl_request() {
  local url="$1"
  local data="$2"
  
  ssl_supported=$(grep 'ssl_supported' ~/rig.conf | cut -d '=' -f 2 | tr -d ' ')
  
  if [ -z "$ssl_supported" ]; then
    debug "SSL support not found in rig.conf. Checking SSL support..."
    response=$(curl -4 -s -X POST -d "$data" "$url")
    if [ $? -eq 0 ]; then
      ssl_supported=true
    else
      ssl_supported=false
    fi
    echo "ssl_supported=$ssl_supported" >> ~/rig.conf
    debug "SSL support status set to $ssl_supported in rig.conf."
  fi

  if [ "$ssl_supported" = true ]; then
    response=$(curl -4 -s -X POST -d "$data" "$url")
  else
    response=$(curl -4 -k -s -X POST -d "$data" "$url")
  fi

  echo "$response"
}

# Function to perform a wget request with SSL fallback
wget_request() {
  local url="$1"
  local output="$2"
  
  wget -4 -q -O "$output" "$url"
  if [ $? -ne 0 ]; then
    debug "SSL verification failed, retrying with --no-check-certificate option."
    wget -4 --no-check-certificate -q -O "$output" "$url"
  fi
}

# Read rig_pw and miner_id from ~/rig.conf
rig_pw=$(grep 'rig_pw' ~/rig.conf | cut -d '=' -f 2 | tr -d ' ')
miner_id=$(grep 'miner_id' ~/rig.conf | cut -d '=' -f 2 | tr -d ' ')

# Get the IP address
miner_ip=$(get_ip_address)

# Check internet connection
check_internet_connection

# Prepare POST data
post_data="rig_pw=$rig_pw&miner_ip=$miner_ip"
[ -n "$miner_id" ] && post_data+="&miner_id=$miner_id"

# Send data to PHP script and get response
response=$(curl_request "https://api.rg3d.eu:8443/checkjob.php" "$post_data")

# Check if response is empty or null
if [ -z "$response" ]; then
  debug "Failed to reach API or empty response. Keeping the miner running."
  exit 0
fi

# Debugging output
debug "Version: $VERSION"
debug "Response from API: $response"

# Parse response
job_id=$(echo $response | jq -r '.job_id' 2>/dev/null)
job_action=$(echo $response | jq -r '.job_action' 2>/dev/null)
job_settings=$(echo $response | jq -r '.job_settings' 2>/dev/null)
rig_fs=$(echo $response | jq -r '.rig_fs' 2>/dev/null || echo "null")
cpu_miner=$(echo $response | jq -r '.cpu_miner' 2>/dev/null)
cpu_max=$(echo $response | jq -r '.cpu_max' 2>/dev/null)

# Debug rig_fs value
debug "rig_fs value: $rig_fs"

# Handle flightsheet configuration
config_file=~/ccminer/config.json
restart_required=false

# Fetch the new configuration from the server
config_response=$(curl_request "https://api.rg3d.eu:8443/getconfig.php" "$post_data")
config_response_parsed=$(echo "$config_response" | jq -S .)

# Update threads in the new configuration
threads=${cpu_miner:-$cpu_max}
config_response_parsed=$(echo "$config_response_parsed" | jq ".threads = $threads")

# Debug configurations for comparison
debug "Fetched configuration: $config_response_parsed"

if [ -f "$config_file" ]; then
  current_config=$(jq -S . "$config_file")
  debug "Current configuration: $current_config"
else
  current_config=""
fi

# Perform strict comparison
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
        wget_request "$job_settings" ~/ccminer/ccminer
        chmod +x ~/ccminer/ccminer
        restart_required=true
        ;;
    "Management script update")
        if [ -f ~/jobscheduler.sh ]; then
            rm ~/jobscheduler.sh
        fi
        wget_request "https://raw.githubusercontent.com/dismaster/RG3DUI/main/jobscheduler.sh" ~/jobscheduler.sh
        chmod +x ~/jobscheduler.sh
        ;;
    "Monitoring Software update")
        if [ -f ~/monitor.sh ]; then
            rm ~/monitor.sh
        fi
        wget_request "https://raw.githubusercontent.com/dismaster/RG3DUI/main/monitor.sh" ~/monitor.sh
        chmod +x ~/monitor.sh
        ;;
    "Termux Boot update")
        if [ -f ~/.termux/boot/boot_start ]; then
            rm ~/.termux/boot/boot_start
        fi
        wget_request "https://raw.githubusercontent.com/dismaster/RG3DUI/main/boot_start" ~/.termux/boot/boot_start
        chmod +x ~/.termux/boot/boot_start
        ;;
    *)
        debug "Unsupported job action: $job_action"
        ;;
esac

# Notify the server about job completion
if [ -n "$job_id" ]; then
    complete_response=$(curl_request "https://api.rg3d.eu:8443/completejob.php" "job_id=$job_id")
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
