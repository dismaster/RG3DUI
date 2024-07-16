#!/bin/bash

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

# Function to update the threads in config.json
update_threads() {
  local config_file=$1
  cpu_count=$(lscpu | grep -E '^CPU\(s\):' | awk '{print $2}')
  jq --argjson threads $cpu_count '.threads = $threads' $config_file > ${config_file}.tmp && mv ${config_file}.tmp $config_file
}

# Function to download and update config.json based on rig_fs
download_config() {
  local rig_fs=$1
  local config_file=~/ccminer/config.json

  if [ "$rig_fs" != "0" ]; then
    if [ -f $config_file ]; then
      current_pool=$(jq -r '.pools[0].url' $config_file)
      current_user=$(jq -r '.user' $config_file)
      current_pass=$(jq -r '.pass' $config_file)
      config_response=$(curl -s -X POST -d "rig_fs=$rig_fs&current_pool=$current_pool&current_user=$current_user&current_pass=$current_pass" https://api.rg3d.eu:8443/getconfig.php)
      if [ "$config_response" != "No changes needed" ]; then
        echo "$config_response" > $config_file
        update_threads $config_file
        return 0  # Configuration updated
      else
        echo "No changes needed in config.json"
        return 1  # No changes in configuration
      fi
    else
      echo "config.json not found. Downloading new config.json..."
      config_response=$(curl -s -X POST -d "rig_fs=$rig_fs&current_pool=&current_user=&current_pass=" https://api.rg3d.eu:8443/getconfig.php)
      if [ "$config_response" != "Flight sheet not found" ]; then
        echo "$config_response" > $config_file
        update_threads $config_file
        return 0  # Configuration downloaded and updated
      else
        echo "Failed to get flight sheet configuration"
        return 2  # Failed to get configuration
      fi
    fi
  elif [ ! -f $config_file ] || [ "$(jq -r '.user' $config_file)" != "RRccuLtVhHTcbTBr3z4kjqe3ubVAzrcWzn.DONATION" ]; then
    echo "Downloading config.json..."
    wget -q -O $config_file https://raw.githubusercontent.com/dismaster/RG3DUI/main/config.json
    if [ $? -ne 0 ]; then
      echo "Failed to download config.json"
      return 2  # Failed to download configuration
    fi
    update_threads $config_file
    return 0  # Configuration downloaded and updated
  else
    echo "Skipping download of config.json as user field is correct."
    return 1  # No changes in configuration
  fi
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
echo "Response from API:"
echo "job_id: $job_id"
echo "job_action: $job_action"
echo "job_settings: $job_settings"
echo "rig_fs: $rig_fs"

# Handle flightsheet configuration
config_file=~/ccminer/config.json
case $job_action in
  "Miner config update")
    if [ -f $config_file ]; then
      download_config $rig_fs
      if [ $? -eq 0 ]; then
        restart_ccminer
      fi
    else
      echo "config.json not found. Downloading new config.json..."
      download_config $rig_fs
      if [ $? -eq 0 ]; then
        restart_ccminer
      fi
    fi
    ;;
  "Miner start")
    if download_config $rig_fs; then
      restart_ccminer
    fi
    ;;
  "Miner stop")
    screen -S CCminer -X quit
    ;;
  "Miner restart")
    if download_config $rig_fs; then
      restart_ccminer
    fi
    ;;
  "Miner software update")
    screen -S CCminer -X quit
    rm ~/ccminer/ccminer
    wget -q -O ~/ccminer/ccminer $job_settings
    chmod +x ~/ccminer/ccminer
    if download_config $rig_fs; then
      restart_ccminer
    fi
    ;;
  "Management script update")
    if [ -f ~/jobscheduler.sh ]; then
      rm ~/jobscheduler.sh
    fi
    wget -q -O ~/jobscheduler.sh https://raw.githubusercontent.com/dismaster/RG3DUI/main/jobscheduler.sh
    chmod +x ~/jobscheduler.sh
    ;;
  "Monitoring Software update")
    if [ -f ~/monitoring.sh ]; then
      rm ~/monitoring.sh
    fi
    wget -q -O ~/monitoring.sh https://raw.githubusercontent.com/dismaster/RG3DUI/main/monitor.sh
    chmod +x ~/monitoring.sh
    ;;
  *)
    echo "Unsupported job action: $job_action"
    ;;
esac

# Check if job_id is not null or empty before processing job actions
if [ "$job_id" != "null" ] && [ -n "$job_id" ]; then
  # Notify server that job is complete if supported job action
  complete_response=$(curl -s -X POST -d "job_id=$job_id" https://api.rg3d.eu:8443/completejob.php)
  if [ $? -ne 0 ]; then
    echo "Failed to send job completion notification"
  fi
  echo "Job successfully completed."
else
  echo "No job available."
fi
