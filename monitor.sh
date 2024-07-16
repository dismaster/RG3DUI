#!/bin/bash

# Function to send data to PHP script or echo if dryrun
send_data() {
  local url="https://api.rg3d.eu:8443/api.php"
  local data="hw_brand=$hw_brand&hw_model=$hw_model&ip=$ip&summary=$summary_json&pool=$pool_json&battery=$battery&cpu_temp=$cpu_temp_json&password=$rig_pw"
  
  if [ "$dryrun" == true ]; then
    echo "curl -s -X POST -d \"$data\" \"$url\""
  else
    # Sending POST request to API endpoint
    curl -s -X POST -d "$data" "$url"
  fi
}

# Check if connectivity to Internet is given
x=$(ping -c1 google.com 2>&1 | grep unknown)
if [ ! "$x" = "" ]; then
  # For Android if connection is down, try to restart Wifi network
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

# 1. Check if ~/rig.conf exists and rig_pw is set
if [ -f ~/rig.conf ]; then
  rig_pw=$(grep -E "^rig_pw=" ~/rig.conf | cut -d '=' -f 2)
  if [ -z "$rig_pw" ]; then
    echo "rig_pw not set in ~/rig.conf. Exiting."
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
  if su -c true 2>/dev/null; then
    # SU rights are available
    ip=$(su -c ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v 127.0.0.1)
  else
    # SU rights are not available
    ip=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v 127.0.0.1)
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

# Remove trailing '|'
summary_raw=${summary_raw%|}

# Convert summary_raw into JSON format
IFS=';' read -ra summary_fields <<< "$summary_raw"
summary_json="{"
for field in "${summary_fields[@]}"; do
  key=$(echo "$field" | cut -d '=' -f 1)
  value=$(echo "$field" | cut -d '=' -f 2)
  summary_json+="\"$key\":\"$value\","
done
summary_json="${summary_json%,}" # Remove the trailing comma
summary_json+="}"

# 7. Get pool output of ccminer API socket (default port)
pool_raw=$(echo 'pool' | nc 127.0.0.1 4068 | tr -d '\0')

# Remove trailing '|'
pool_raw=${pool_raw%|}

# Convert pool_raw into JSON format
IFS=';' read -ra pool_fields <<< "$pool_raw"
pool_json="{"
for field in "${pool_fields[@]}"; do
  key=$(echo "$field" | cut -d '=' -f 1)
  value=$(echo "$field" | cut -d '=' -f 2)
  pool_json+="\"$key\":\"$value\","
done
pool_json="${pool_json%,}" # Remove the trailing comma
pool_json+="}"

# 8. Check battery status if OS is Termux
if [ "$(uname -o)" == "Android" ]; then
  battery=$(termux-battery-status | jq -c '.')
else
  battery=""
fi

# 9. Check CPU temperature
if [ -n "$(uname -o | grep Android)" ]; then
  # For Termux on Android
  cpu_temp=$(~/vcgencmd measure_temp 2>/dev/null | cut -d '=' -f 2 | cut -d "'" -f 1)
  if [ -z "$cpu_temp" ]; then
    cpu_temp=$(su -c ~/vcgencmd measure_temp | cut -d '=' -f 2 | cut -d "'" -f 1)
  fi
elif [ -f /sys/class/thermal/thermal_zone0/temp ]; then
  # For Raspberry Pi (or similar ARM-based systems)
  cpu_temp=$(awk '{printf "%.1f", $1 / 1000}' /sys/class/thermal/thermal_zone0/temp)
else
  # For Ubuntu (or other Linux distributions)
  cpu_temp=$(sensors | grep 'Core 0' | awk '{print $3}' | cut -c2- | head -n 1)
fi

# Check if cpu_temp is still empty or error
if [ -z "$cpu_temp" ]; then
  cpu_temp=0
fi

# Format cpu_temp as JSON
cpu_temp_json="{\"temp\":\"$cpu_temp\"}"

# Send data to PHP script or echo if dryrun
send_data
