#!/bin/bash

# ANSI color codes for formatting
NC='\033[0m'     # No Color
R='\033[0;31m'   # Red
G='\033[1;32m'   # Light Green
Y='\033[1;33m'   # Yellow
LC='\033[1;36m'  # Light Cyan
LG='\033[1;32m'  # Light Green
LB='\033[1;34m'  # Light Blue
P='\033[0;35m'   # Purple
LP='\033[1;35m'  # Light Purple

# Fancy banner
echo -e "${LC}#########################################################${NC}"
echo -e "${LC}#${NC} ${LB}     __________   ________ ________  ________         ${LC}#${NC}"
echo -e "${LC}#${NC} ${LB}     \______   \ /  _____/ \_____  \ \______ \        ${LC}#${NC}"
echo -e "${LC}#${NC} ${LB}      |       _//   \  ___   _(__  <  |    |  \       ${LC}#${NC}"
echo -e "${LC}#${NC} ${LB}      |    |   \\    \_\  \ /       \ |     |   \      ${LC}#${NC}"
echo -e "${LC}#${NC} ${LB}      |____|_  / \______  //______  //_______  /      ${LC}#${NC}"
echo -e "${LC}#${NC} ${LB}             \/         \/        \/         \/       ${LC}#${NC}"
echo -e "${LC}#${NC} ${LB}____   _________________________  ____ ___  _________ ${LC}#${NC}"
echo -e "${LC}#${NC} ${LB}\   \ /   /\_   _____/\______   \|    |   \/   _____/ ${LC}#${NC}"
echo -e "${LC}#${NC} ${LB} \   Y   /  |    __)_  |       _/|    |   /\_____  \  ${LC}#${NC}"
echo -e "${LC}#${NC} ${LB}  \     /   |        \ |    |   \|    |  / /        \ ${LC}#${NC}"
echo -e "${LC}#${NC} ${LB}   \___/   /_______  / |____|_  /|______/ /_______  / ${LC}#${NC}"
echo -e "${LC}#${NC} ${LB}                   \/         \/                  \/  ${LC}#${NC}"
echo -e "${LC}#########################################################${NC}"
echo -e "${LC}#           ${LP}->${NC} ${LG}VERUS CPU CHECK${NC} by Ch3ckr  ${P}<-${NC}            ${LC}#${NC}"
echo -e "${LC}#########################################################${NC}"
echo -e "${LC}#${NC}              ${LG}https://api.rg3d.eu:8443${NC}                 ${LC}#${NC}"
echo -e "${LC}#########################################################${NC}"
echo  # New line for spacing
#echo -e "${R}->${NC} ${LC}This process may take a while...${NC}"
#echo  # New line for spacing


# Function to calculate average KHS
calculate_avg_khs() {
    local khs_values=("$@")
    local khs_sum=0
    local count=0

    for value in "${khs_values[@]}"; do
        if [[ $value =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            khs_sum=$(echo "$khs_sum + $value" | bc)
            count=$((count + 1))
        fi
    done

    if [ $count -gt 0 ]; then
        avg=$(echo "scale=2; $khs_sum / $count" | bc)
        echo "$avg"
    else
        echo "0.00"
    fi
}

# Detect the running environment and fetch the correct cpu_check binary if necessary
detect_and_fetch_cpu_check() {
    if [ -f "./cpu_check" ] && [ -x "./cpu_check" ]; then
        cpu_check_status="exists and is executable."
    else
        if [ -d /data/data/com.termux/files/home ]; then
            wget -4 -O cpu_check https://raw.githubusercontent.com/dismaster/RG3DUI/main/cpu_check_arm
        elif uname -a | grep -qi "raspberry\|pine\|odroid\|arm"; then
            wget -4 -O cpu_check https://raw.githubusercontent.com/dismaster/RG3DUI/main/cpu_check_sbc
        elif uname -a | grep -qi "android" && [ -f /etc/os-release ] && grep -qi "Ubuntu" /etc/os-release; then
            wget -4 -O cpu_check https://raw.githubusercontent.com/dismaster/RG3DUI/main/cpu_check_sbc
        elif uname -a | grep -qi "linux"; then
            wget -4 -O cpu_check https://raw.githubusercontent.com/dismaster/RG3DUI/main/cpu_check_sbc
        else
            echo -e "\033[31mUnsupported OS. Exiting.\033[0m"
            exit 1
        fi
        chmod +x cpu_check
        cpu_check_status="downloaded and set as executable."
    fi
}

# Ensure bc is installed
check_and_install_bc() {
    if ! command -v bc &> /dev/null; then
        if [ -d /data/data/com.termux/files/home ]; then
            pkg install bc -y
        else
            sudo apt-get install bc -y
        fi
        bc_status="installed."
    else
        bc_status="already installed."
    fi
}

# Extract hardware information
extract_hardware() {
    ./cpu_check | grep 'Hardware:' | head -n 1 | sed 's/.*Hardware: //'
}

# Extract architecture information
extract_architecture() {
    ./cpu_check | grep 'Architecture:' | sed 's/.*Architecture: //'
}

# Extract CPU information from the file and parse model and frequency
extract_cpu_info() {
    ./cpu_check | grep 'Processor' | awk -F': ' '{print $2}'
}

# Extract KHS values based on environment
extract_khs_values() {
    echo 'threads' | nc 127.0.0.1 4068 | tr -d '\0' | grep -o "KHS=[0-9]*\.[0-9]*" | awk -F= '{print $2}'
}

# Check if ccminer is running in a screen session or independently
check_ccminer_running() {
    if screen -list | grep -q "CCminer"; then
        ccminer_status="running in screen session 'CCminer'."
    elif pgrep -x "ccminer" > /dev/null; then
        ccminer_status="running."
    else
        ccminer_status="not running. Exiting."
        echo -e "\033[31m$ccminer_status\033[0m"
        exit 1
    fi
}

# Main script execution
detect_and_fetch_cpu_check
check_and_install_bc
check_ccminer_running

hardware=$(extract_hardware)
architecture=$(extract_architecture)
cpu_info_raw=$(extract_cpu_info)
khs_values_raw=$(extract_khs_values)

# Convert CPU info and KHS values to arrays
IFS=$'\n' read -r -d '' -a cpu_info_lines <<<"$cpu_info_raw"
IFS=$'\n' read -r -d '' -a khs_values <<<"$khs_values_raw"

# Check lengths
cpu_count=${#cpu_info_lines[@]}
khs_count=${#khs_values[@]}

if [ "$cpu_count" -ne "$khs_count" ]; then
    echo -e "\033[31mERROR: The number of CPUs does not match the number of KHS values.\033[0m"
    exit 1
fi

declare -A cpu_khs_map

# Populate the map with KHS values grouped by CPU info
for i in "${!cpu_info_lines[@]}"; do
    cpu_info=${cpu_info_lines[$i]}
    khs=${khs_values[$i]}

    if [ -n "${cpu_khs_map[$cpu_info]}" ]; then
        cpu_khs_map[$cpu_info]+=" $khs"
    else
        cpu_khs_map[$cpu_info]=$khs
    fi
done

# Prepare JSON payload
json_payload="{\"hardware\":\"$hardware\", \"architecture\":\"$architecture\", \"cpus\":["

cpu_first=true
for cpu_info in "${!cpu_khs_map[@]}"; do
    if [ "$cpu_first" = true ]; then
        cpu_first=false
    else
        json_payload+=","
    fi

    khs_values=(${cpu_khs_map[$cpu_info]})
    avg_khs=$(calculate_avg_khs "${khs_values[@]}")
    cpu_model=$(echo "$cpu_info" | awk -F' @ ' '{print $1}')
    cpu_freq=$(echo "$cpu_info" | awk -F' @ ' '{print $2}' | sed 's/ MHz//')

    json_payload+="{\"cpu\":\"$cpu_model\", \"frequency\":\"$cpu_freq\", \"avg_khs\":\"$avg_khs\"}"
done

json_payload+="]}"

# Send JSON payload to the PHP API script
api_url="https://api.rg3d.eu:8443/cpu_api.php"
response=$(curl -s -X POST -H "Content-Type: application/json" -d "$json_payload" "$api_url")

if [[ $response == *"success"* ]]; then
    data_status="success"
else
    data_status="failed"
fi

# Final user-friendly output
echo -e "${LP}->${NC} Required Software:\033[32m $cpu_check_status\033[0m"
echo -e "${LP}->${NC} Required Packages:\033[32m $bc_status\033[0m"
echo -e "${LP}->${NC} CCminer:\033[32m $ccminer_status\033[0m"
echo -e "${LP}->${NC} Data send:\033[32m $data_status\033[0m\n"

# Fancy overview of what has been sent
echo -e "${LP}->${NC} Hardware:${LP} $hardware${NC}"
echo -e "${LP}->${NC} Architecture:${LP} $architecture${NC}"

for cpu_info in "${!cpu_khs_map[@]}"; do
    khs_values=(${cpu_khs_map[$cpu_info]})
    avg_khs=$(calculate_avg_khs "${khs_values[@]}")
    cpu_model=$(echo "$cpu_info" | awk -F' @ ' '{print $1}')
    cpu_freq=$(echo "$cpu_info" | awk -F' @ ' '{print $2}')

    echo -e "${LP}->${NC} CPU:${LC} $cpu_model${NC}"
    echo -e "${LP}->${NC} Frequency:${LC} $cpu_freq${NC}"
    echo -e "${LP}->${NC} AVG KHS:${LC} $avg_khs${NC}"
done
