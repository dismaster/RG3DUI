#!/bin/bash

# Define the file path for the rig.conf file
RIG_CONF="rig.conf"

# Check if rig.conf exists
if [ ! -f "$RIG_CONF" ]; then
    echo "Error: $RIG_CONF not found!"
    exit 1
fi

# Extract the rig_pw value from the file
rig_pw=$(grep -E "^rig_pw=" "$RIG_CONF" | cut -d'=' -f2)

# If rig_pw is set, rewrite the file to only contain the rig_pw line
if [ -n "$rig_pw" ]; then
    echo "rig_pw=$rig_pw" > "$RIG_CONF"
    echo "Cleaned up $RIG_CONF, preserving rig_pw."
else
    # If no rig_pw is found, clear the file
    echo "" > "$RIG_CONF"
    echo "No rig_pw found. Cleared $RIG_CONF."
fi
