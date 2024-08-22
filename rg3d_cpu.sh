#!/bin/bash

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

# Detect and install bc if necessary
install_bc_if_needed() {
    if ! command -v bc &> /dev/null; then
        echo "bc is not installed. Installing bc..."
        if [ -d /data/data/com.termux/files/home ]; then
            pkg install bc -y
        elif uname -a | grep -qi "raspberry\|pine\|odroid\|arm"; then
            sudo apt-get update && sudo apt-get install bc -y
        elif uname -a | grep -qi "android" && [ -f /etc/os-release ] && grep -qi "Ubuntu" /etc/os-release; then
            sudo apt-get update && sudo apt-get install bc -y
        elif uname -a | grep -qi "linux"; then
            sudo apt-get update && sudo apt-get install bc -y
        else
            echo "Unsupported OS. Cannot install bc."
            exit 1
        fi
    else
        echo "bc is already installed."
    fi
}

# Detect the running environment and fetch the correct cpu_check binary if necessary
detect_and_fetch_cpu_check() {
    if [ -f "./cpu_check" ] && [ -x "./cpu_check" ]; then
        echo "cpu_check already exists and is executable."
        return
    fi

    if [ -d /data/data/com.termux/files/home ]; then
        wget -4 -O cpu_check https://raw.githubusercontent.com/dismaster/RG3DUI/main/cpu_check_arm
    elif uname -a | grep -qi "raspberry\|pine\|odroid\|arm"; then
        wget -4 -O cpu_check https://raw.githubusercontent.com/dismaster/RG3DUI/main/cpu_check_sbc
    elif uname -a | grep -qi "android" && [ -f /etc/os-release ] && grep -qi "Ubuntu" /etc/os-release; then
        wget -4 -O cpu_check https://raw.githubusercontent.com/dismaster/RG3DUI/main/cpu_check_sbc
    elif uname -a | grep -qi "linux"; then
        wget -4 -O cpu_check https://raw.githubusercontent.com/dismaster/RG3DUI/main/cpu_check_sbc
    else
        echo "Unsupported OS. Exiting."
        exit 1
    fi
    chmod +x cpu_check
}

# Extract hardware information
extract_hardware() {
    ./cpu_check | grep 'Hardware:' | sed 's/.*Hardware: //'
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

# Main script execution
install_bc_if_needed
detect_and_fetch_cpu_check
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
    echo "ERROR: The number of CPUs does not match the number of KHS values."
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
curl -X POST -H "Content-Type: application/json" -d "$json_payload" "$api_url"

echo "Data sent to $api_url"
