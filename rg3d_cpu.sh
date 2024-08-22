#!/bin/bash

# Function to calculate average KHS
calculate_avg_khs() {
    local khs_values=("$@")
    local khs_sum=0
    for value in "${khs_values[@]}"; do
        khs_sum=$(echo "$khs_sum + $value" | bc)
    done
    echo "scale=2; $khs_sum / ${#khs_values[@]}" | bc
}

# Detect the running environment
detect_environment() {
    if [ -d /data/data/com.termux/files/home ]; then
        echo "termux"
    elif uname -a | grep -qi "raspberry\|pine\|odroid\|arm"; then
        echo "sbc"
    elif uname -a | grep -qi "android"; then
        echo "userland"
    else
        echo "linux"
    fi
}

# Extract hardware information
extract_hardware_info() {
    model=$(grep "Hardware" cpu_info.txt | head -n 1 | awk -F': ' '{print $2}' | xargs)
    echo "$model"
}

# Extract CPU information from the C program's output
extract_cpu_info() {
    grep "Processor" cpu_info.txt | while read -r line; do
        model=$(echo "$line" | awk -F': ' '{print $2}' | awk -F' @' '{print $1}' | xargs)
        freq=$(echo "$line" | awk -F' @' '{print $2}' | awk '{print $1}')
        echo "$model:$freq"
    done
}

# Extract KHS values based on environment
extract_khs_values() {
    khs_values=$(echo 'threads' | nc 127.0.0.1 4068 | tr -d '\0' | grep -o "KHS=[0-9]*\.[0-9]*" | awk -F= '{print $2}')
}

# Main script execution
env_type=$(detect_environment)
echo "Detected environment: $env_type"

# Run the C program to gather hardware and CPU information
./cpu_check > cpu_info.txt  # Replace 'cpu_check' with the actual binary name

# Extract hardware information
hardware_info=$(extract_hardware_info)

cpu_info=($(extract_cpu_info))
extract_khs_values

# Declare associative arrays to store the data
declare -A cpu_khs_map
declare -A cpu_freq_map

# Initialize arrays with CPU information
for (( i=0; i<${#cpu_info[@]}; i++ )); do
    model=$(echo "${cpu_info[$i]}" | awk -F':' '{print $1}')
    freq=$(echo "${cpu_info[$i]}" | awk -F':' '{print $2}')
    cpu_freq_map["$model"]="$freq"
done

# Assign KHS values to the corresponding CPU model
i=0
for khs in $khs_values; do
    model=$(echo "${cpu_info[$i]}" | awk -F':' '{print $1}')
    if [ -n "${cpu_khs_map[$model]}" ]; then
        cpu_khs_map[$model]+=" $khs"
    else
        cpu_khs_map[$model]="$khs"
    fi
    i=$((i + 1))
done

# Output the summary
echo "Hardware: $hardware_info"
for model in "${!cpu_khs_map[@]}"; do
    khs_list=(${cpu_khs_map[$model]})
    avg_khs=$(calculate_avg_khs "${khs_list[@]}")
    freq=${cpu_freq_map[$model]}
    echo "CPU Model: $model"
    echo "Frequency: $freq MHz"
    echo "Average Hashrate: $avg_khs KHS"
    echo
done
