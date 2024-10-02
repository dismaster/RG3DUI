#!/data/data/com.termux/files/usr/bin/bash

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

echo -e "${LC} __________     _         _     _         ${NC}"
echo -e "${LC}|          |___| |_ ___ _| |_ _| |___ ___ ${NC}"
echo -e "${LC}|     _____|  _|   | -_| . | | | | -_|  _|${NC}"
echo -e "${LC}|          |___|_|_|___|___|___|_|___|_|  ${NC}"
echo -e "${LC}|_____     |${NC}    Tool ~ ${LG}Jobscheduler${NC}"
echo -e "${LC}|          |${NC}    Dev  ~ ${LP}@Ch3ckr${NC}"
echo -e "${LC}|__________|${NC}    URL  ~ ${Y}https://gui.rg3d.eu${NC}"
echo

while true; do
    # Perform actions and log messages
    bash /data/data/com.termux/files/home/jobscheduler.sh > /dev/null 2>&1

    bash /data/data/com.termux/files/home/monitor.sh > /dev/null 2>&1

    bash /data/data/com.termux/files/home/rg3d_cpu.sh > /dev/null 2>&1

    # Log the end of the minute
    echo "${LC}$(date +'%Y-%m-%d %H:%M:%S')${NC} - Actions performed, waiting for the next cycle..."

    sleep 60
done
