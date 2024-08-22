#!/bin/bash

# Function to determine the operating system
detect_os() {
    if [ -f /data/data/com.termux/files/usr/bin/bash ]; then
        echo "termux"
    elif [ -f /usr/bin/lsb_release ]; then
        if lsb_release -a | grep -q "Ubuntu"; then
            echo "userland_ubuntu"
        else
            echo "unsupported"
        fi
    elif [ -f /etc/os-release ]; then
        . /etc/os-release
        if [[ "$ID" == "raspbian" || "$ID" == "debian" || "$ID" == "ubuntu" ]]; then
            echo "sbc"
        else
            echo "unsupported"
        fi
    else
        echo "unsupported"
    fi
}

# Function to download the appropriate cpu_check file
download_cpu_check() {
    local os_type=$1
    case "$os_type" in
        termux)
            curl -s -o cpu_check https://raw.githubusercontent.com/dismaster/RG3DUI/main/cpu_check_arm
            ;;
        userland_ubuntu | sbc)
            curl -s -o cpu_check https://raw.githubusercontent.com/dismaster/RG3DUI/main/cpu_check_sbc
            ;;
        *)
            echo "Unsupported OS or environment."
            exit 1
            ;;
    esac
    chmod +x cpu_check
}

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

# Function to extract CPU information from the file and parse model and frequency
extract_cpu_info() {
    ./cpu_check | grep 'Processor' | awk -F': ' '{print $2}'
}

# Function to extract KHS values based on environment
extract_khs_values() {
    echo 'threads' | nc 127.0.0.1 4068 | tr -d '\0' | grep -o "KHS=[0-9]*\.[0-9]*" | awk -F= '{print $2}'
}

# Function to extract hardware and architecture
extract_system_info() {
    local hardware architecture
    hardware=$(./cpu_check | grep 'Hardware' | awk -F': ' '{print $2}' | xargs)
    architecture=$(./cpu_check | grep 'Architecture' | awk -F': ' '{print $2}' | xargs)
    echo "$hardware $architecture"
}

# Main script execution
os_type=$(detect_os)
download_cpu_check "$os_type"

cpu_info_raw=$(extract_cpu_info)
khs_values_raw=$(extract_khs_values)
system_info_raw=$(extract_system_info)

# Convert CPU info and KHS values to arrays
IFS=$'\n' read -r -d '' -a cpu_info_lines <<<"$cpu_info_raw"
IFS=$'\n' read -r -d '' -a khs_values <<<"$khs_values_raw"
IFS=' ' read -r -a system_info <<<"$system_info_raw"

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

# Prepare JSON data
hardware="${system_info[0]}"
architecture="${system_info[1]}"

json_data=$(cat <<EOF
{
    "hardware": "$hardware",
    "architecture": "$architecture",
    "cpus": [
        $(for cpu_info in "${!cpu_khs_map[@]}"; do
            khs_values=(${cpu_khs_map[$cpu_info]})
            avg_khs=$(calculate_avg_khs "${khs_values[@]}")
            echo "{ \"cpu\": \"$(echo "$cpu_info" | awk -F' @ ' '{print $1}')\", \"frequency\": \"$(echo "$cpu_info" | awk -F' @ ' '{print $2}')\", \"avg_khs\": \"$avg_khs\" }"
        done | paste -sd ",")
    ]
}
EOF
)

# Send JSON data to the PHP API
api_url="https://api.rg3d.ru:8443/cpu_api.php"
curl -X POST -H "Content-Type: application/json" -d "$json_data" "$api_url"

# Output the consolidated results
echo "Hardware: $hardware"
echo "Architecture: $architecture"
for cpu_info in "${!cpu_khs_map[@]}"; do
    khs_values=(${cpu_khs_map[$cpu_info]})
    avg_khs=$(calculate_avg_khs "${khs_values[@]}")
    echo "CPU: $cpu_info"
    echo "Average Hashrate: $avg_khs KHS"
    echo
done
