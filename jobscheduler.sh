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

# Function to update threads in config.json
update_threads() {
  cpu_count=$(lscpu | grep -E '^CPU\(s\):' | awk '{print $2}')
  jq --argjson threads "$cpu_count" '.threads = $threads' $config_file > ${config_file}.tmp && mv ${config_file}.tmp $config_file
}

# Function to check if getconfig.php is reachable with a 2-second timeout
check_getconfig_reachable() {
  curl -s --connect-timeout 2 -o /dev/null -w "%{http_code}" https://api.rg3d.eu:8443/getconfig.php
}

# Read rig_pw from ~/rig.conf
rig_pw=$(grep 'rig_pw' ~/rig.conf | cut -d '=' -f 2 | tr -d ' ')

# Get the IP address
miner_ip=$(get_ip_address)

# Send data to PHP script and get response
response=$(curl -s -X POST -d "rig_pw=$rig_pw&miner_ip=$miner_ip" https://api.rg3d.eu:8443/checkjob.php)

# Parse response
job_id=$(echo $response | jq -r '.job_id' 2>/dev/null)
job_action=$(echo $response | jq -r '.job_action' 2>/dev/null)
job_settings=$(echo $response | jq -r '.job_settings' 2>/dev/null)
rig_fs=$(echo $response | jq -r '.rig_fs' 2>/dev/null)

# Debugging output
debug "Response from API:"
debug "job_id: $job_id"
debug "job_action: $job_action"
debug "job_settings: $job_settings"
debug "rig_fs: $rig_fs"

# Handle flightsheet configuration
config_file=~/ccminer/config.json
restart_required=false

if [ "$rig_fs" != "0" ]; then
  getconfig_reachable=$(check_getconfig_reachable)
  if [ "$getconfig_reachable" != "200" ]; then
    debug "getconfig.php is not reachable. Skipping configuration check."
  else
    if [ -f $config_file ]; then
      current_config=$(jq -S . $config_file)
      current_pool=$(jq -r '.pools[0].url' $config_file)
      current_user=$(jq -r '.user' $config_file)
      current_pass=$(jq -r '.pass' $config_file)
      config_response=$(curl -s -X POST -d "rig_fs=$rig_fs&current_pool=$current_pool&current_user=$current_user&current_pass=$current_pass" https://api.rg3d.eu:8443/getconfig.php)
      config_response_parsed=$(echo "$config_response" | jq -S .)
      if [ "$config_response_parsed" != "$current_config" ]; then
        echo "$config_response" > $config_file
        update_threads
        restart_required=true
      fi
    else
      config_response=$(curl -s -X POST -d "rig_fs=$rig_fs&current_pool=&current_user=&current_pass=" https://api.rg3d.eu:8443/getconfig.php)
      config_response_parsed=$(echo "$config_response" | jq -S .)
      if [ "$config_response_parsed" != "Flight sheet not found" ]; then
        echo "$config_response" > $config_file
        update_threads
        restart_required=true
      else
        exit 1
      fi
    fi
  fi
elif [ ! -f $config_file ] || [ "$(jq -r '.user' $config_file)" != "RRccuLtVhHTcbTBr3z4kjqe3ubVAzrcWzn.DONATION" ]; then
  wget -q -O $config_file https://raw.githubusercontent.com/dismaster/RG3DUI/main/config.json
  if [ $? -ne 0 ]; then
    exit 1
  fi
  update_threads
  restart_required=true
fi

# Check if job_id is not null or empty before processing job actions
if [ "$job_id" != "null" ] && [ -n "$job_id" ]; then
  case $job_action in
    "Miner config update")
      getconfig_reachable=$(check_getconfig_reachable)
      if [ "$getconfig_reachable" != "200" ]; then
        debug "getconfig.php is not reachable. Skipping configuration update."
      else
        if [ -f $config_file ]; then
          current_config=$(jq -S . $config_file)
          current_pool=$(jq -r '.pools[0].url' $config_file)
          current_user=$(jq -r '.user' $config_file)
          current_pass=$(jq -r '.pass' $config_file)
          config_response=$(curl -s -X POST -d "rig_fs=$rig_fs&current_pool=$current_pool&current_user=$current_user&current_pass=$current_pass" https://api.rg3d.eu:8443/getconfig.php)
          config_response_parsed=$(echo "$config_response" | jq -S .)
          if [ "$config_response_parsed" != "$current_config" ]; then
            echo "$config_response" > $config_file
            update_threads
            restart_required=true
          fi
        else
          config_response=$(curl -s -X POST -d "rig_fs=$rig_fs&current_pool=&current_user=&current_pass=" https://api.rg3d.eu:8443/getconfig.php)
          config_response_parsed=$(echo "$config_response" | jq -S .)
          if [ "$config_response_parsed" != "Flight sheet not found" ]; then
            echo "$config_response" > $config_file
            update_threads
            restart_required=true
          else
            exit 1
          fi
        fi
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
      rm ~/ccminer/ccminer
      wget -q -O ~/ccminer/ccminer $job_settings
      chmod +x ~/ccminer/ccminer
      restart_required=true
      ;;
    "Management script update")
      if [ -f ~/jobscheduler.sh ]; then
        rm ~/jobscheduler.sh
      fi
      wget -q -O ~/jobscheduler.sh https://raw.githubusercontent.com/dismaster/RG3DUI/main/jobscheduler.sh
      chmod +x ~/jobscheduler.sh
      ;;
    "Monitoring Software update")
      if [ -f ~/monitor.sh ]; then
        rm ~/monitor.sh
      fi
      wget -q -O ~/monitor.sh https://raw.githubusercontent.com/dismaster/RG3DUI/main/monitor.sh
      chmod +x ~/monitor.sh
      ;;
    "Termux Boot update")
      if [ -f ~/.termux/boot/boot_start ]; then
        rm ~/.termux/boot/boot_start
      fi
      wget -q -O ~/.termux/boot/boot_start https://raw.githubusercontent.com/dismaster/RG3DUI/main/boot_start
      chmod +x ~/.termux/boot/boot_start
      ;;
    *)
      ;;
  esac

  # Notify server that job is complete if supported job action
  if [ -n "$job_id" ]; then
    complete_response=$(curl -s -X POST -d "job_id=$job_id" https://api.rg3d.eu:8443/completejob.php)
    if [ $? -ne 0 ]; then
      debug "Failed to send job completion notification"
    fi
  else
    debug "No valid job_id received from API"
  fi
else
  debug "No job available."
fi

# Restart ccminer only if needed
if [ "$restart_required" = true ]; then
  restart_ccminer
fi
