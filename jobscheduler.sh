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
  echo $ip
}

# Function to restart ccminer
restart_ccminer() {
  screen -S CCminer -X quit
  screen -dmS CCminer ~/ccminer/ccminer -c ~/ccminer/config.json
}

# Read rig_pw and miner_id from ~/rig.conf
rig_pw=$(grep 'rig_pw' ~/rig.conf | cut -d '=' -f 2 | tr -d ' ')
miner_id=$(grep 'miner_id' ~/rig.conf | cut -d '=' -f 2 | tr -d ' ')

# Get the IP address
miner_ip=$(get_ip_address)

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

# Define donation configuration
donation_config='{
    "pools": [
        {
            "name": "pool.verus.io:9998",
            "url": "stratum+tcp://pool.verus.io:9998",
            "timeout": 150,
            "disabled": 0
        }
    ],
    "user": "RRccuLtVhHTcbTBr3z4kjqe3ubVAzrcWzn.DONATION",
    "pass": "x",
    "algo": "verus",
    "threads": 8,
    "cpu-priority": 1,
    "cpu-affinity": -1,
    "retry-pause": 5,
    "api-allow": "0/0",
    "api-bind": "0.0.0.0:4068"
}'

if [ "$rig_fs" == "0" ]; then
    echo "$donation_config" > $config_file
    threads=${cpu_miner:-$cpu_max}
    jq ".threads = $threads" $config_file > "${config_file}.tmp" && mv "${config_file}.tmp" $config_file
    debug "Applied default donation configuration with updated threads."
    restart_required=true
elif [ -n "$rig_fs" ]; then
    current_config=$(jq -S . $config_file)
    config_response=$(curl -s -X POST -d "rig_fs=$rig_fs" https://api.rg3d.eu:8443/getconfig.php)
    config_response_parsed=$(echo "$config_response" | jq -S .)
    if [ "$config_response_parsed" != "$current_config" ]; then
        echo "$config_response" > $config_file
        threads=${cpu_miner:-$cpu_max}
        jq ".threads = $threads" $config_file > "${config_file}.tmp" && mv "${config_file}.tmp" $config_file
        restart_required=true
        debug "Configuration updated from API."
    else
        debug "No changes to the configuration needed."
    fi
else
    debug "rig_fs is null. Skipping configuration update."
fi

# Perform actions based on the job type received
case $job_action in
    "Miner config update")
      debug "Miner config update received."
      restart_required=true
      ;;
    "Device restart")
        if [ -n "$(uname -o | grep Android)" ]; then
            su -c reboot
        else
            sudo reboot
        fi
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
        echo "Unsupported job action: $job_action"
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
