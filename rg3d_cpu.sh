#!/bin/bash

VERSION="1.0.2"

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
echo -e "${LB}  _____ _____ _____ ${NC}"
echo -e "${LB} |     |  _  |  |  |${NC}  ${LC}CCminer${NC}"
echo -e "${LB} |   --|   __|  |  |${NC}  ${LC}Hashrate${NC}"
echo -e "${LB} |_____|__|  |_____|${NC}  ${LC}CPU Check${NC}"
echo -e "${LB} ___| |_ ___ ___| |_ ${NC}"
echo -e "${LB}|  _|   | -_|  _| '_|${NC} by ${LP}@Ch3ckr${NC}"
echo -e "${LB}|___|_|_|___|___|_,_|${NC} ${LG}https://api.rg3d.eu:8443${NC}"
echo -e  # New line for spacing

# Check if -crontab argument is passed to add crontab
add_crontab() {
    if crontab -l | grep -q "rg3d_cpu.sh"; then
        echo -e "${LP}->${NC} Crontab:\033[32m already exists.\033[0m"
    else
        (crontab -l 2>/dev/null; echo "* * * * * $PWD/rg3d_cpu.sh") | crontab -
        echo -e "${LP}->${NC} Crontab:\033[32m added (every minute).\033[0m"
    fi
}

if [[ "$1" == "-crontab" ]]; then
    add_crontab
    exit 0
fi

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
            wget -4 -O cpu_check https://raw.githubusercontent.com/dismaster/RG3DUI/main/cpu_check_arm > /dev/null 2>&1
        elif uname -a | grep -qi "raspberry\|pine\|odroid\|arm"; then
            wget -4 -O cpu_check https://raw.githubusercontent.com/dismaster/RG3DUI/main/cpu_check_sbc > /dev/null 2>&1
        elif uname -a | grep -qi "android" && [ -f /etc/os-release ] && grep -qi "Ubuntu" /etc/os-release; then
            wget -4 -O cpu_check https://raw.githubusercontent.com/dismaster/RG3DUI/main/cpu_check_sbc > /dev/null 2>&1
        elif uname -a | grep -qi "linux"; then
            wget -4 -O cpu_check https://raw.githubusercontent.com/dismaster/RG3DUI/main/cpu_check_sbc > /dev/null 2>&1
        else
            echo -e "\033[31mUnsupported OS. Exiting.\033[0m"
            exit 1
        fi
        chmod +x cpu_check > /dev/null 2>&1
        cpu_check_status="downloaded and set as executable."
    fi
}

# Ensure bc and netcat are installed
check_and_install_packages() {
    if ! command -v bc &> /dev/null; then
        if [ -d /data/data/com.termux/files/home ]; then
            pkg install bc -y > /dev/null 2>&1
        else
            sudo apt-get install bc -y > /dev/null 2>&1
        fi
        bc_status="installed."
    else
        bc_status="already installed."
    fi
}

# Ensure netcat (nc) is installed
check_and_install_nc() {
    if ! command -v nc &> /dev/null; then
        if [ -d /data/data/com.termux/files/home ]; then
            pkg install netcat -y > /dev/null 2>&1
        else
            sudo apt-get install netcat-traditional -y > /dev/null 2>&1
        fi
        nc_status="installed."
    else
        nc_status="already installed."
    fi
}

# Main script execution
detect_and_fetch_cpu_check  # Ensure cpu_check is downloaded
check_and_install_packages
check_and_install_nc

# Now that cpu_check is available, run it and store output
cpu_check_output=$(./cpu_check)

# Extract hardware information
extract_hardware() {
    echo "$cpu_check_output" | grep 'Hardware:' | head -n 1 | sed 's/.*Hardware: //'
}

# Extract architecture information
extract_architecture() {
    echo "$cpu_check_output" | grep 'Architecture:' | sed 's/.*Architecture: //'
}

# Extract CPU information from the stored output and parse model and frequency
extract_cpu_info() {
    echo "$cpu_check_output" | grep 'Processor' | awk -F': ' '{print $2}'
}

# Extract KHS values based on environment
extract_khs_values() {
    echo 'threads' | nc 127.0.0.1 4068 | tr -d '\0' | grep -o "KHS=[0-9]*\.[0-9]*" | awk -F= '{print $2}'
}

# Check if ccminer config has correct api settings
check_ccminer_config() {
    if [ -z "$config_file" ]; then
        config_check_status="\033[31m Config file not found. Exiting.\033[0m"
        echo -e "${LP}->${NC} Config check:$config_check_status"
        exit 1
    elif grep -q '"api-allow": "0/0"' "$config_file" && grep -q '"api-bind": "0.0.0.0:4068"' "$config_file"; then
        config_check_status="\033[32m Config is properly set.\033[0m"
    else
        config_check_status="\033[31m Config file is missing required API settings. Exiting.\033[0m"
        echo -e "${LP}->${NC} Config check:$config_check_status"
        exit 1
    fi
}

# Function to check the number of shares from ccminer
check_shares() {
    shares=$(echo 'summary' | nc 127.0.0.1 4068 | tr -d '\0' | grep -oP '(?<=ACC=)[0-9]+')
    if [ -z "$shares" ]; then
        shares_status="\033[31mError (no share data).\033[0m"
        echo -e "${LP}->${NC} Shares:$shares_status"
        exit 1
    elif [ "$shares" -lt 150 ]; then
        shares_status="\033[31m$shares (Bad - Below 150).\033[0m"
        echo -e "${LP}->${NC} Shares:$shares_status"
        exit 0
    else
        shares_status="\033[32m$shares (Good).\033[0m"
        echo -e "${LP}->${NC} Shares:$shares_status"
    fi
}

# Check if ccminer is running in a screen session or independently
check_ccminer_running() {
    if screen -list | grep -q "CCminer"; then
        ccminer_pid=$(pgrep -f 'SCREEN.*CCminer')
        config_file=$(cat /proc/$ccminer_pid/cmdline | tr '\0' ' ' | grep -oP '(?<=-c )[^ ]+')
        ccminer_status="Screen session: 'CCminer'."
    elif pgrep -x "ccminer" > /dev/null; then
        ccminer_pid=$(pgrep -x "ccminer")
        config_file=$(cat /proc/$ccminer_pid/cmdline | tr '\0' ' ' | grep -oP '(?<=-c )[^ ]+')
        ccminer_status="running."
    else
        ccminer_status="not running. Exiting."
        echo -e "\033[31m$ccminer_status\033[0m"
        exit 1
    fi
    # Perform the config file check
    check_ccminer_config
}

# Main script execution
detect_and_fetch_cpu_check
check_and_install_packages
check_and_install_nc
check_ccminer_running

# Check for the number of shares
check_shares

hardware=$(extract_hardware)
architecture=$(extract_architecture)
cpu_info_raw=$(extract_cpu_info)
khs_values_raw=$(extract_khs_values)

# Check for missing hardware or CPU info
if [[ -z "$hardware" || -z "$architecture" || -z "$cpu_info_raw" || "$cpu_info_raw" == "0" ]]; then
    echo -e "\033[31mError: Missing or invalid hardware, architecture, or CPU frequency. Data not sent.\033[0m"
    exit 1
fi

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
    data_status="Success."
else
    data_status="Failed."
fi

# Final user-friendly output
echo -e "${LP}->${NC} Software:\033[32m $cpu_check_status\033[0m"
echo -e "${LP}->${NC} Package (bc):\033[32m $bc_status\033[0m"
echo -e "${LP}->${NC} Package (netcat):\033[32m $nc_status\033[0m"
echo -e "${LP}->${NC} CCminer:\033[32m $ccminer_status\033[0m"
echo -e "${LP}->${NC} Config check:$config_check_status"
echo -e "${LP}->${NC} Shares:\033[32m $shares_status\033[0m"
echo -e "${LP}->${NC} Transmission:\033[32m $data_status\033[0m\n"

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
