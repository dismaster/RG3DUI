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

# Fancy Banner with RG3D VERUS Logo
echo -e "${LC}#########################################################${NC}"
echo -e "${LC}#${NC} ${LB}__________   ________ ________  ________              ${LC}#${NC}"
echo -e "${LC}#${NC} ${LB}\______   \ /  _____/ \_____  \ \______ \             ${LC}#${NC}"
echo -e "${LC}#${NC} ${LB} |       _//   \  ___   _(__  <  |    |  \            ${LC}#${NC}"
echo -e "${LC}#${NC} ${LB} |    |   \\    \_\  \ /       \ |     |   \           ${LC}#${NC}"
echo -e "${LC}#${NC} ${LB} |____|_  / \______  //______  //_______  /           ${LC}#${NC}"
echo -e "${LC}#${NC} ${LB}        \/         \/        \/         \/            ${LC}#${NC}"
echo -e "${LC}#${NC} ${LB}____   _________________________  ____ ___  _________ ${LC}#${NC}"
echo -e "${LC}#${NC} ${LB}\   \ /   /\_   _____/\______   \|    |   \/   _____/ ${LC}#${NC}"
echo -e "${LC}#${NC} ${LB} \   Y   /  |    __)_  |       _/|    |   /\_____  \  ${LC}#${NC}"
echo -e "${LC}#${NC} ${LB}  \     /   |        \ |    |   \|    |  / /        \ ${LC}#${NC}"
echo -e "${LC}#${NC} ${LB}   \___/   /_______  / |____|_  /|______/ /_______  / ${LC}#${NC}"
echo -e "${LC}#${NC} ${LB}                   \/         \/                  \/  ${LC}#${NC}"
echo -e "${LC}#########################################################${NC}"
echo -e "${LC}#          ${LP}->${NC} ${LG}VERUS Miner SETUP${NC} by Ch3ckr ${P}<-${NC}            ${LC}#${NC}"
echo -e "${LC}#########################################################${NC}"
echo -e "${LC}#${NC}              ${LG}https://api.rg3d.eu:8443${NC}                 ${LC}#${NC}"
echo -e "${LC}#########################################################${NC}"
echo  # New line for spacing
echo -e "${R}->${NC} ${LC}This process may take a while...${NC}"
echo  # New line for spacing

# Function to suppress output of commands
function run_command_silently {
    "$@" >/dev/null 2>&1
}

# Delete existing ~/ccminer folder if it exists
if [ -d ~/ccminer ]; then
    echo -e "${R}->${NC} Deleting existing ~/ccminer folder and its contents${NC}"
    rm -rf ~/ccminer
fi

# Request RIG Password from user and store in ~/rig.conf with verification
while true; do
    echo -e "${R}->${NC} ${Y}Enter RIG Password:${NC}"
    read -s pw1
    echo
    echo -e "${R}->${NC} ${Y}Confirm RIG Password:${NC}"
    read -s pw2
    echo

    if [[ "$pw1" == "$pw2" ]]; then
        echo "rig_pw=$pw1" > ~/rig.conf
        break
    else
        echo -e "${R}->${NC} ${R}Passwords do not match. Please try again.${NC}"
    fi
done

# Ensure rig.conf is created and contains the password
if [ -f ~/rig.conf ]; then
    echo -e "${LG}->${NC} Created rig.conf.${NC}"
else
    echo -e "${R}->${NC} Failed to create rig.conf.${NC}"
fi

# Detect OS
if [[ $(uname -o) == "Android" ]]; then
    # Assuming Android OS is Termux
    echo -e "${R}->${NC} Detected OS: Termux${NC}"

    # Update and upgrade packages
    run_command_silently pkg update -y
    run_command_silently pkg upgrade -y

    # Install required packages
    run_command_silently pkg install -y cronie termux-services libjansson wget nano screen openssh termux-services libjansson netcat-openbsd jq termux-api iproute2 tsu

    # Create ~/.termux folder if not exists
    run_command_silently mkdir -p ~/.termux

    # Create ~/.termux/boot folder if not exists
    run_command_silently mkdir -p ~/.termux/boot

    # Change directory to ~/.termux/boot and download boot_start script
    cd ~/.termux/boot
    curl -sSL https://raw.githubusercontent.com/dismaster/RG3DUI/main/boot_start -o boot_start

    # Make boot_start script executable
    chmod +x ~/.termux/boot/boot_start

    # Create ~/ccminer folder if not exists
    run_command_silently mkdir -p ~/ccminer

    # Download ccminer and make it executable, overwrite if exists
    curl -sSL https://github.com/Oink70/CCminer-ARM-optimized/releases/download/v3.8.3-4/ccminer-3.8.3-4_ARM -o ~/ccminer/ccminer
    chmod +x ~/ccminer/ccminer

    # Run jobscheduler.sh and monitor.sh, overwrite if exists
    curl -sSL https://raw.githubusercontent.com/dismaster/RG3DUI/main/jobscheduler.sh -o ~/jobscheduler.sh
    chmod +x ~/jobscheduler.sh
    curl -sSL https://raw.githubusercontent.com/dismaster/RG3DUI/main/monitor.sh -o ~/monitor.sh
    chmod +x ~/monitor.sh

    # Add jobscheduler.sh and monitor.sh to crontab
    (crontab -l | grep -v "jobscheduler.sh" ; echo "* * * * * ~/jobscheduler.sh") | crontab - >/dev/null 2>&1
    (crontab -l | grep -v "monitor.sh" ; echo "* * * * * ~/monitor.sh") | crontab - >/dev/null 2>&1
    echo -e "${LG}->${NC} Added jobscheduler.sh and monitor.sh to crontab.${NC}"

    # Start jobscheduler.sh once
    ~/jobscheduler.sh >/dev/null 2>&1 &

elif [[ $(uname -m) == "arm"* ]]; then
    # Assuming Raspberry Pi OS
    echo -e "${R}->${NC} Detected OS: Raspberry Pi${NC}"

    # Update and install necessary packages
    run_command_silently sudo apt-get update
    run_command_silently sudo apt-get install -y libcurl4-openssl-dev libssl-dev libjansson-dev automake autotools-dev build-essential

    # Clone CCminer repository and rename folder to ccminer, overwrite if exists
    run_command_silently git clone https://github.com/Oink70/CCminer-ARM-optimized ~/ccminer
    mv ~/ccminer/CCminer-ARM-optimized ~/ccminer/ccminer

    # Run jobscheduler.sh and monitor.sh, overwrite if exists
    curl -sSL https://raw.githubusercontent.com/dismaster/RG3DUI/main/jobscheduler.sh -o ~/jobscheduler.sh
    chmod +x ~/jobscheduler.sh
    curl -sSL https://raw.githubusercontent.com/dismaster/RG3DUI/main/monitor.sh -o ~/monitor.sh
    chmod +x ~/monitor.sh

    # Add jobscheduler.sh and monitor.sh to crontab
    (crontab -l | grep -v "jobscheduler.sh" ; echo "* * * * * ~/jobscheduler.sh") | crontab - >/dev/null 2>&1
    (crontab -l | grep -v "monitor.sh" ; echo "* * * * * ~/monitor.sh") | crontab - >/dev/null 2>&1
    echo -e "${LG}->${NC} Added jobscheduler.sh and monitor.sh to crontab.${NC}"

    # Start jobscheduler.sh once
    ~/jobscheduler.sh >/dev/null 2>&1 &

else
    # Assuming any other Linux OS
    echo -e "${R}->${NC} Detected OS: Linux${NC}"

    # Update and install necessary packages
    run_command_silently sudo apt-get update
    run_command_silently sudo apt-get install -y libcurl4-openssl-dev libssl-dev libjansson-dev automake autotools-dev build-essential

    # Clone CCminer repository, build and install
    run_command_silently git clone https://github.com/tpruvot/ccminer ccminer_build
    cd ccminer_build
    run_command_silently ./build.sh
    run_command_silently mkdir -p ~/ccminer
    run_command_silently cp ccminer ~/ccminer/
    cd ~
    run_command_silently rm -rf ccminer_build

    # Run jobscheduler.sh and monitor.sh, overwrite if exists
    curl -sSL https://raw.githubusercontent.com/dismaster/RG3DUI/main/jobscheduler.sh -o ~/jobscheduler.sh
    chmod +x ~/jobscheduler.sh
    curl -sSL https://raw.githubusercontent.com/dismaster/RG3DUI/main/monitor.sh -o ~/monitor.sh
    chmod +x ~/monitor.sh

    # Add jobscheduler.sh and monitor.sh to crontab
    (crontab -l | grep -v "jobscheduler.sh" ; echo "* * * * * ~/jobscheduler.sh") | crontab - >/dev/null 2>&1
    (crontab -l | grep -v "monitor.sh" ; echo "* * * * * ~/monitor.sh") | crontab - >/dev/null 2>&1
    echo -e "${LG}->${NC} Added jobscheduler.sh and monitor.sh to crontab.${NC}"

    # Start jobscheduler.sh once
    ~/jobscheduler.sh >/dev/null 2>&1 &
fi
