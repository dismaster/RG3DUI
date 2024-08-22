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

# Output hardware and architecture information
echo "Hardware: $hardware"
echo "Architecture: $architecture"
echo

# Output the consolidated results
for cpu_info in "${!cpu_khs_map[@]}"; do
    khs_values=(${cpu_khs_map[$cpu_info]})
    avg_khs=$(calculate_avg_khs "${khs_values[@]}")
    echo "CPU: $cpu_info"
    echo "Average Hashrate: $avg_khs KHS"
    echo
done
