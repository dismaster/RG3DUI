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

# Function to download a file and make it executable, overwrite if exists
function download_and_make_executable {
    local url=$1
    local filename=$2

    # Change directory to target directory (if provided)
    if [ ! -z "$3" ]; then
        (cd $3 && curl -sSL $url -o $filename)
    else
        curl -sSL $url -o $filename
    fi

    # Make file executable
    chmod +x $filename
}

# Function to build ccminer from source
function build_ccminer {
    # Update package repository and install dependencies
    sudo apt update
    sudo apt-get install -y libcurl4-openssl-dev libssl-dev libjansson-dev automake autotools-dev build-essential

    # Clone ccminer repository and rename folder to ccminer_build
    git clone https://github.com/tpruvot/ccminer ~/ccminer/ccminer_build
    mv ~/ccminer/ccminer_build ~/ccminer/ccminer

    # Change directory to ccminer_build and run build.sh
    (cd ~/ccminer/ccminer && ./build.sh)

    # After build, create ~/ccminer folder and copy ccminer executable
    run_command_silently mkdir -p ~/ccminer
    cp ~/ccminer/ccminer/ccminer ~/ccminer/ccminer

    # Clean up ccminer_build folder
    rm -rf ~/ccminer/ccminer_build
}

# Function to prompt for password with verification
function prompt_for_password {
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
}

# Function to delete ~/ccminer folder if it exists
function delete_ccminer_folder {
    if [ -d ~/ccminer ]; then
        echo -e "${R}->${NC} Deleting existing ~/ccminer folder and its contents${NC}"
        rm -rf ~/ccminer
    fi
}

# Function to add scripts to crontab
function add_to_crontab {
    local script=$1
    # Remove existing entry from crontab if present
    (crontab -l | grep -v "$script" ; echo "* * * * * ~/ $script") | crontab - >/dev/null 2>&1
    echo -e "${LG}->${NC} Added $script to crontab.${NC}"

    # Start the script immediately after adding to crontab
    echo -e "${LG}->${NC} Starting $script.${NC}"
    ~/ $script >/dev/null 2>&1 &
}

# Delete existing ~/ccminer folder including files in it, if it exists
delete_ccminer_folder

# Request RIG Password from user and store in ~/rig.conf with verification
echo -e "${R}->${NC} Please enter your RIG password.${NC}"
prompt_for_password

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
    (cd ~/.termux/boot && curl -sSL https://raw.githubusercontent.com/dismaster/RG3DUI/main/boot_start -o boot_start)

    # Make boot_start script executable
    chmod +x ~/.termux/boot/boot_start

    # Create ~/ccminer folder if not exists
    run_command_silently mkdir -p ~/ccminer

    # Download ccminer and make it executable, overwrite if exists
    curl -sSL https://github.com/Oink70/CCminer-ARM-optimized/releases/download/v3.8.3-4/ccminer-3.8.3-4_ARM -o ~/ccminer/ccminer
    chmod +x ~/ccminer/ccminer

    # Run jobscheduler.sh and monitor.sh, overwrite if exists
    download_and_make_executable https://raw.githubusercontent.com/dismaster/RG3DUI/main/jobscheduler.sh jobscheduler.sh
    download_and_make_executable https://raw.githubusercontent.com/dismaster/RG3DUI/main/monitor.sh monitor.sh

    # Add jobscheduler.sh and monitor.sh to crontab
    add_to_crontab jobscheduler.sh
    add_to_crontab monitor.sh

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
    download_and_make_executable https://raw.githubusercontent.com/dismaster/RG3DUI/main/jobscheduler.sh jobscheduler.sh
    download_and_make_executable https://raw.githubusercontent.com/dismaster/RG3DUI/main/monitor.sh monitor.sh

    # Add jobscheduler.sh and monitor.sh to crontab
    add_to_crontab jobscheduler.sh
    add_to_crontab monitor.sh

else
    # For other Linux distributions
    echo -e "${R}->${NC} Detected OS: $(uname -o)${NC}"

    # Update and install necessary packages
    run_command_silently sudo apt update
    run_command_silently sudo apt-get install -y libcurl4-openssl-dev libssl-dev libjansson-dev automake autotools-dev build-essential

    # Change directory to ~/ccminer_build and clone CCminer repository
    download_and_make_executable https://raw.githubusercontent.com/dismaster/RG3DUI/main/jobscheduler.sh jobscheduler.sh
    download_and_make_executable https://raw.githubusercontent.com/dismaster/RG3DUI/main/monitor.sh monitor.sh

    # Add jobscheduler.sh and monitor.sh to crontab
    add_to_crontab jobscheduler.sh
    add_to_crontab monitor.sh

    # Clone CCminer repository and rename folder to ccminer_build
    git clone https://github.com/tpruvot/ccminer ~/ccminer_build
    mv ~/ccminer_build ~/ccminer/ccminer_build

    # Change directory to ccminer_build and run build.sh
    (cd ~/ccminer/ccminer_build && ./build.sh)

    # After build, create ~/ccminer folder and copy ccminer executable
    run_command_silently mkdir -p ~/ccminer
    cp ~/ccminer/ccminer_build/ccminer ~/ccminer/ccminer

    # Clean up ccminer_build folder
    rm -rf ~/ccminer/ccminer_build
fi

# Success message
echo -e "${LG}->${NC} Script execution completed.${NC}"
rm ~install.sh
