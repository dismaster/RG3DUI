#!/bin/bash

# Version number
VERSION="1.2.0"

# Function to check if API URL is reachable with SSL
check_ssl_support() {
  local url="https://api.rg3d.eu:8443/api.php"
  if curl --output /dev/null --silent --head --fail --connect-timeout 5 --max-time 10 "$url"; then
    return 0  # SSL supported
  else
    return 1  # SSL not supported
  fi
}

# Function to authenticate and get miner_token
authenticate() {
  echo "Authenticating with the server..."
  local url="https://api.rg3d.eu:8443/api.php"
  local data="password=$rig_pw"

  response=$(curl -s -X POST -d "$data" "$url")
  miner_token=$(echo "$response" | jq -r '.miner_token')
  new_miner_id=$(echo "$response" | jq -r '.miner_id')

  if [ -n "$miner_token" ] && [ "$miner_token" != "null" ]; then
    # Save miner_token and miner_id to rig.conf
    update_rig_conf "$new_miner_id" "$miner_token"
    echo "Authentication successful. Miner Token obtained."
  else
    echo "Authentication failed. Response: $response"
    exit 1
  fi
}

# Function to send data to PHP script or echo if dryrun
send_data() {
  local url="https://api.rg3d.eu:8443/api.php"

  # Load miner_token and miner_id from rig.conf
  miner_token=$(grep -E "^miner_token=" ~/rig.conf | cut -d '=' -f 2)
  miner_id=$(grep -E "^miner_id=" ~/rig.conf | cut -d '=' -f 2)

  # Build data payload
  local data="hw_brand=$hw_brand&hw_model=$hw_model&ip=$ip&summary=$summary_json&pool=$pool_json&battery=$battery&cpu_temp=$cpu_temp_json&cpu_max=$cpu_count&monitor_version=$VERSION&scheduler_version=$scheduler_version"

  if [ -n "$miner_id" ]; then
    data+="&miner_id=$miner_id"
  fi

  if [ -n "$rig_pw" ]; then
    data+="&password=$rig_pw"
  fi

  if [ "$dryrun" == true ]; then
    if [ -n "$miner_token" ]; then
      echo "curl -s -X POST -H 'Authorization: Bearer $miner_token' -d \"$data\" \"$url\""
    else
      echo "curl -s -X POST -d \"$data\" \"$url\""
    fi
  elif [ "$ssl_supported" == "true" ]; then
    if [ -n "$miner_token" ]; then
      response=$(curl -s -X POST -H "Authorization: Bearer $miner_token" -d "$data" "$url")
    else
      response=$(curl -s -X POST -d "$data" "$url")
    fi
    echo "Response from server: $response"
  else
    if [ -n "$miner_token" ]; then
      response=$(curl -s -k -X POST -H "Authorization: Bearer $miner_token" -d "$data" "$url")
    else
      response=$(curl -s -k -X POST -d "$data" "$url")
    fi
    echo "Response from server (insecure): $response"
  fi

  # Check if token is invalid or expired
  if echo "$response" | grep -q "Authentication failed"; then
    echo "Miner token invalid or expired. Re-authenticating..."
    authenticate
    # Retry sending data
    miner_token=$(grep -E "^miner_token=" ~/rig.conf | cut -d '=' -f 2)
    response=$(curl -s -X POST -H "Authorization: Bearer $miner_token" -d "$data" "$url")
    echo "Response from server after re-authentication: $response"
  fi

  # Extract miner_token and miner_id from the response if provided
  new_miner_token=$(echo "$response" | jq -r '.miner_token')
  new_miner_id=$(echo "$response" | jq -r '.miner_id')

  if [ -n "$new_miner_token" ] && [ "$new_miner_token" != "null" ]; then
    update_rig_conf "$new_miner_id" "$new_miner_token"
  fi
}

# Function to update rig.conf with miner_id, miner_token, and ssl_supported
update_rig_conf() {
  local miner_id=$1
  local miner_token=$2
  local rig_conf_path=~/rig.conf

  if [ -f "$rig_conf_path" ]; then
    # Update miner_id
    if grep -q "^miner_id=" "$rig_conf_path"; then
      sed -i "s/^miner_id=.*/miner_id=$(printf '%q' "$miner_id")/" "$rig_conf_path"
    else
      echo "miner_id=$miner_id" >> "$rig_conf_path"
    fi

    # Update miner_token
    if [ -n "$miner_token" ]; then
      if grep -q "^miner_token=" "$rig_conf_path"; then
        sed -i "s/^miner_token=.*/miner_token=$(printf '%q' "$miner_token")/" "$rig_conf_path"
      else
        echo "miner_token=$miner_token" >> "$rig_conf_path"
      fi
    fi

    # Update ssl_supported
    if grep -q "^ssl_supported=" "$rig_conf_path"; then
      sed -i "s/^ssl_supported=.*/ssl_supported=$(printf '%q' "$ssl_supported")/" "$rig_conf_path"
    else
      echo "ssl_supported=$ssl_supported" >> "$rig_conf_path"
    fi
  else
    echo "rig.conf file not found. Creating a new one."
    echo "miner_id=$miner_id" > "$rig_conf_path"
    [ -n "$miner_token" ] && echo "miner_token=$miner_token" >> "$rig_conf_path"
    echo "ssl_supported=$ssl_supported" >> "$rig_conf_path"
  fi
}

# Ensure jq is installed
if ! command -v jq &> /dev/null; then
  echo "jq is required but not installed. Installing jq..."
  if [ "$(uname -o)" == "Android" ]; then
    pkg install jq -y
  else
    sudo apt-get install jq -y
  fi
fi

# Determine SSL support and update rig.conf only if not already set
ssl_supported="false"
if [ -f ~/rig.conf ]; then
  ssl_supported=$(grep -E "^ssl_supported=" ~/rig.conf | cut -d '=' -f 2)
fi

if [ -z "$ssl_supported" ]; then
  if check_ssl_support; then
    ssl_supported="true"
  else
    ssl_supported="false"
  fi
  # Update rig.conf with the SSL support status
  update_rig_conf "$miner_id"
fi

# Get the number of CPUs
cpu_count=$(lscpu | grep -E '^CPU\(s\):' | awk '{print $2}')

# Check if connectivity to Internet is given
x=$(ping -c1 google.com 2>&1 | grep unknown)
if [ ! "$x" = "" ]; then
  # For Android if connection is down try to restart Wifi network
  if su -c true 2>/dev/null; then
    # SU rights are available
    echo "Connection to Internet broken. Restarting Network!"
    su -c input keyevent 26
    su -c svc wifi disable
    su -c svc wifi enable
    sleep 10
  fi
fi

# Parse arguments
dryrun=false
if [ "$1" == "--dryrun" ]; then
  dryrun=true
fi

# 1. Check if ~/rig.conf exists and necessary credentials are set
if [ -f ~/rig.conf ]; then
  rig_pw=$(grep -E "^rig_pw=" ~/rig.conf | cut -d '=' -f 2)
  miner_id=$(grep -E "^miner_id=" ~/rig.conf | cut -d '=' -f 2)
  miner_token=$(grep -E "^miner_token=" ~/rig.conf | cut -d '=' -f 2)
  
  if [ -z "$rig_pw" ] && [ -z "$miner_token" ]; then
    echo "Neither rig_pw nor miner_token is set in ~/rig.conf. Exiting."
    exit 1
  fi
else
  echo "~/rig.conf file not found. Exiting."
  exit 1
fi

# 2. Check hardware brand and format to uppercase
if [ -f /sys/firmware/devicetree/base/model ]; then
  hw_brand=$(cat /sys/firmware/devicetree/base/model | awk '{print $1}' | tr '[:lower:]' '[:upper:]')
elif [ -n "$(uname -o | grep Android)" ]; then
  hw_brand=$(getprop ro.product.brand | tr '[:lower:]' '[:upper:]')
elif [ "$(uname -s)" == "Linux" ]; then
  # For GNU/Linux systems, fetch PRETTY_NAME from lsb_release -a
  hw_brand=$(lsb_release -a 2>/dev/null | grep "Description:" | cut -d ':' -f 2- | sed 's/^[ \t]*//;s/[ \t]*$//')
else
  hw_brand=$(uname -o | tr '[:lower:]' '[:upper:]')
fi

# 3. Check hardware model and format to uppercase
if [ -f /sys/firmware/devicetree/base/model ]; then
  hw_model=$(cat /sys/firmware/devicetree/base/model | awk '{print $2 $3}')
elif [ -n "$(uname -o | grep Android)" ]; then
  hw_model=$(getprop ro.product.model)
else
  hw_model=$(uname -m)
fi
hw_model=$(echo "$hw_model" | tr '[:lower:]' '[:upper:]')

# 4. Get local IP address (prefer ethernet over wlan, IPv4 only)
if [ -n "$(uname -o | grep Android)" ]; then
  # For Android
  ip=$(termux-wifi-connectioninfo | grep -oP '(?<="ip": ")[^"]*')
  if [ -z "$ip" ]; then  # Fallback to previous method if no IP is found
    ip=$(ifconfig 2> /dev/null | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '[0-9.]*' | grep -v 127.0.0.1)
    if [ -z "$ip" ]; then  # If no IP address was found, try with 'su' rights
      if su -c true 2>/dev/null; then
        # SU rights are available
        ip=$(su -c ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v 127.0.0.1)
      fi
    fi
  fi
else
  # For other Unix systems
  ip=$(ip -4 -o addr show | awk '$2 !~ /lo|docker/ {print $4}' | cut -d "/" -f 1 | head -n 1)
fi

# 5. Check if ccminer is running, exit if not
if ! screen -list | grep -q "\.CCminer"; then
  echo "ccminer not running. Exiting."
  exit 1
fi

# 6. Get summary output of ccminer API socket (default port)
summary_raw=$(echo 'summary' | nc 127.0.0.1 4068 | tr -d '\0')
summary_raw=${summary_raw%|}  # Remove trailing '|'
summary_json=$(echo "$summary_raw" | jq -R 'split(";") | map(split("=")) | map({(.[0]): .[1]}) | add')

# 7. Get pool output of ccminer API socket (default port)
pool_raw=$(echo 'pool' | nc 127.0.0.1 4068 | tr -d '\0')
pool_raw=${pool_raw%|}  # Remove trailing '|'
pool_json=$(echo "$pool_raw" | jq -R 'split(";") | map(split("=")) | map({(.[0]): .[1]}) | add')

# 8. Check battery status if OS is Termux and termux-battery-status is available
if [ "$(uname -o)" == "Android" ]; then
  if ! command -v termux-battery-status &> /dev/null; then
    battery='{}'
  else
    battery=$(timeout 2s termux-battery-status | jq -c '.')
    if [ -z "$battery" ]; then
      battery='{"health":"0","percentage":"0","plugged":"0","status":"0","temperature":"0.0","current":"0"}'
    fi
  fi
else
  battery="{}"
fi

# 9. Check CPU temperature
cpu_temp=0

# Check for Raspberry Pi or other Linux systems
if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
  cpu_temp=$(awk '{printf "%.1f", $1 / 1000}' /sys/class/thermal/thermal_zone0/temp)
fi

# If still zero, check for Android devices
if [ "$cpu_temp" == "0" ] || [ -z "$cpu_temp" ]; then
  if [ -n "$(uname -o | grep Android)" ]; then
    # Attempt to get temperature without SU first
    cpu_temp_raw=$("~/vcgencmd measure_temp" 2>/dev/null)
    cpu_temp=$(echo "$cpu_temp_raw" | grep -oP 'temp=\K\d+\.\d+')

    # If no valid temperature was obtained, try with SU
    if ! [[ "$cpu_temp" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
      cpu_temp_raw=$(su -c ~/vcgencmd measure_temp 2>/dev/null)
      cpu_temp=$(echo "$cpu_temp_raw" | grep -oP 'temp=\K\d+\.\d+')
    fi

    # Check if the temperature is still not valid or if the command simply failed
    if ! [[ "$cpu_temp" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
      cpu_temp=0
    fi
  fi
fi

# Additional check if cpu_temp is still 0
if [ "$cpu_temp" == "0" ] || [ -z "$cpu_temp" ]; then
  for cpuseq in $(seq 1 60); do
    v1=$(cat /sys/devices/virtual/thermal/thermal_zone$cpuseq/type 2>/dev/null)
    v2="back_temp"
    if [[ "$v1" == "$v2" ]]; then
      cpu_temp_raw=$(cat /sys/devices/virtual/thermal/thermal_zone$cpuseq/temp 2>/dev/null)
      cpu_temp=$((cpu_temp_raw / 1000))
      break
    fi
  done
fi

# Format cpu_temp as JSON
cpu_temp_json="{\"temp\":\"$cpu_temp\"}"

# Get the scheduler version from the jobscheduler.sh file
scheduler_version=$(grep -E "^VERSION=" ~/jobscheduler.sh | cut -d '=' -f 2 | tr -d '"')

# Authenticate if miner_token is missing and rig_pw is available
if [ -z "$miner_token" ]; then
  if [ -n "$rig_pw" ]; then
    authenticate
  else
    echo "Cannot authenticate because neither miner_token nor rig_pw is available."
    exit 1
  fi
fi

# Send data to PHP script or echo if dryrun
send_data
