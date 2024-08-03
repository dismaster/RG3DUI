#!/bin/bash

# Version number
VERSION="1.0.2"

# Function to check if API URL is reachable
check_api_url() {
  local url="https://api.rg3d.eu:8443/api.php"
  if curl --output /dev/null --silent --head --fail --connect-timeout 5 --max-time 10 "$url"; then
    return 0  # URL reachable
  else
    return 1  # URL not reachable
  fi
}

# Function to send data to PHP script or echo if dryrun or debug
send_data() {
  local url="https://api.rg3d.eu:8443/api.php"
  local data="hw_brand=$hw_brand&hw_model=$hw_model&ip=$ip&summary=$summary_json&pool=$pool_json&battery=$battery&cpu_temp=$cpu_temp_json&cpu_max=$cpu_count&password=$rig_pw&monitor_version=$VERSION&scheduler_version=$scheduler_version"

  if [ -n "$miner_id" ]; then
    data+="&miner_id=$miner_id"
  fi

  if [ "$dryrun" == true ] || [ "$debug" == true ]; then
    echo "curl -s -X POST -d \"$data\" \"$url\""
  else
    if check_api_url; then
      # Sending POST request to API endpoint and capturing response
      response=$(curl -s -X POST -d "$data" "$url")
      echo "Response from server: $response"

      # Extracting miner_id from the response
      miner_id=$(echo "$response" | jq -r '.miner_id')

      # Check if miner_id is valid and update rig.conf
      if [[ "$miner_id" =~ ^[0-9]+$ ]]; then
        update_rig_conf "$miner_id"
      else
        echo "Invalid miner_id received: $miner_id"
      fi
    else
      echo "API URL ($url) is not reachable. Data not sent."
    fi
  fi
}

# Function to update rig.conf with miner_id
update_rig_conf() {
  local miner_id=$1
  local rig_conf_path=~/rig.conf

  if [ -f "$rig_conf_path" ]; then
    if grep -q "miner_id=" "$rig_conf_path"; then
      sed -i "s/miner_id=.*/miner_id=$miner_id/" "$rig_conf_path"
    else
      echo "miner_id=$miner_id" >> "$rig_conf_path"
    fi
  else
    echo "rig.conf file not found. Creating a new one."
    echo "miner_id=$miner_id" > "$rig_conf_path"
  fi
}

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
debug=false
if [ "$1" == "--dryrun" ]; then
  dryrun=true
elif [ "$1" == "--debug" ]; then
  debug=true
fi

# 1. Check if ~/rig.conf exists and rig_pw is set
if [ -f ~/rig.conf ]; then
  rig_pw=$(grep -E "^rig_pw=" ~/rig.conf | cut -d '=' -f 2)
  if [ -z "$rig_pw" ]; then
    echo "rig_pw not set in ~/rig.conf. Exiting."
    exit 1
  fi
  miner_id=$(grep -E "^miner_id=" ~/rig.conf | cut -d '=' -f 2)
else
  echo "~/rig.conf file not found. Exiting."
  exit 1
fi

if [ "$debug" == true ]; then
  echo "rig_pw: $rig_pw"
  echo "miner_id: $miner_id"
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

if [ "$debug" == true ]; then
  echo "hw_brand: $hw_brand"
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

if [ "$debug" == true ]; then
  echo "hw_model: $hw_model"
fi

# 4. Get local IP address (prefer ethernet over wlan, IPv4 only)
if [ -n "$(uname -o | grep Android)" ]; then
  # For Android
  # First try without 'su'
  # old: ip=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v 127.0.0.1)
  ip=$(ifconfig 2> /dev/null | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '[0-9.]*' | grep -v 127.0.0.1)
  if [ -z "$ip" ]; then  # If no IP address was found, try with 'su' rights
    if su -c true 2>/dev/null; then
      # SU rights are available
      ip=$(su -c ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v 127.0.0.1)
    fi
  fi
else
  # For other Unix systems
  ip=$(ip -4 -o addr show | awk '$2 !~ /lo|docker/ {print $4}' | cut -d "/" -f 1 | head -n 1)
  # ip=$(ifconfig 2> /dev/null | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '[0-9.]*' | grep -v 127.0.0.1)
fi

if [ "$debug" == true ]; then
  echo "ip: $ip"
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

if [ "$debug" == true ]; then
  echo "summary_json: $summary_json"
fi

# 7. Get pool output of ccminer API socket (default port)
pool_raw=$(echo 'pool' | nc 127.0.0.1 4068 | tr -d '\0')
pool_raw=${pool_raw%|}  # Remove trailing '|'
pool_json=$(echo "$pool_raw" | jq -R 'split(";") | map(split("=")) | map({(.[0]): .[1]}) | add')

if [ "$debug" == true ]; then
  echo "pool_json: $pool_json"
fi

# 8. Check battery status if OS is Termux
if [ "$(uname -o)" == "Android" ]; then
  battery=$(termux-battery-status | jq -c '.')
else
  battery="{}"
fi

if [ "$debug" == true ]; then
  echo "battery: $battery"
fi

# 9. Check CPU temperature
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

elif [ -f /sys/class/thermal/thermal_zone0/temp ]; then
  # For Raspberry Pi and other Linux systems
  cpu_temp=$(awk '{printf "%.1f", $1 / 1000}' /sys/class/thermal/thermal_zone0/temp)
else
  # For systems with sensors installed
  cpu_temp=$(sensors | grep 'Core 0' | awk '{print $3}' | cut -c2- | head -n 1)
  # Ensure the result is a number, otherwise set to zero
  if ! [[ "$cpu_temp" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    cpu_temp=0
  fi
fi

# Format cpu_temp as JSON
cpu_temp_json="{\"temp\":\"$cpu_temp\"}"

if [ "$debug" == true ]; then
  echo "cpu_temp_json: $cpu_temp_json"
fi

# Get the scheduler version from the jobscheduler.sh file
scheduler_version=$(grep -E "^VERSION=" ~/jobscheduler.sh | cut -d '=' -f 2 | tr -d '"')

if [ "$debug" == true ]; then
  echo "scheduler_version: $scheduler_version"
fi

# Send data to PHP script or echo if dryrun or debug
send_data
