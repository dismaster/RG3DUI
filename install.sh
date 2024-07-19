#!/bin/bash

# Clearing screen
clear 

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

# Function to build ccminer from source for SBCs
function build_ccminer_sbc {
    # Update package repository and install dependencies
    run_command_silently wget http://ports.ubuntu.com/pool/main/o/openssl/libssl1.1_1.1.0g-2ubuntu4_arm64.deb
    run_command_silently sudo dpkg -i libssl1.1_1.1.0g-2ubuntu4_arm64.deb
    run_command_silently rm libssl1.1_1.1.0g-2ubuntu4_arm64.deb
   
    # After build, create ~/ccminer folder and copy ccminer executable
    run_command_silently mkdir -p ~/ccminer
    run_command_silently wget -q -O ~/ccminer/ccminer https://raw.githubusercontent.com/Oink70/CCminer-ARM-optimized/main/ccminer

    # Install default config for DONATION
    wget -q -O ~/ccminer/config.json https://raw.githubusercontent.com/dismaster/RG3DUI/main/config.json
}

# Function to build ccminer from source for UNIX
function build_ccminer_unix {
    # Update package repository and install dependencies
    run_command_silently wget http://ports.ubuntu.com/pool/main/o/openssl/libssl1.1_1.1.0g-2ubuntu4_arm64.deb
    run_command_silently sudo dpkg -i libssl1.1_1.1.0g-2ubuntu4_arm64.deb
    run_command_silently rm libssl1.1_1.1.0g-2ubuntu4_arm64.deb
    run_command_silently cd ~/ccminer_build 
    run_command_silently ./build.sh 
    run_command_silently cd ~/
    
    # After build, create ~/ccminer folder and copy ccminer executable
    run_command_silently mkdir -p ~/ccminer
    run_command_silently mv ~/ccminer_build/ccminer ~/ccminer/ccminer
    
    # Clean up ccminer_build folder
    run_command_silently rm -rf ~/ccminer_build

    # Install default config for DONATION
    wget -q -O ~/ccminer/config.json https://raw.githubusercontent.com/dismaster/RG3DUI/main/config.json
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
    if [ -d ~/ccminer_build ]; then
        echo -e "${R}->${NC} Deleting existing ~/ccminer_build folder and its contents${NC}"
        rm -rf ~/ccminer
    fi
}

# Function to add scripts to crontab
function add_to_crontab {
    local script=$1
    # Remove existing entry from crontab if present
    (crontab -l | grep -v "$script" ; echo "* * * * * ~/$script") | crontab - >/dev/null 2>&1
    echo -e "${LG}->${NC} Added $script to crontab.${NC}"

    # Start the script immediately after adding to crontab
    echo -e "${LG}->${NC} Starting $script.${NC}"
    ~/ $script >/dev/null 2>&1 &
}

# Function to add scripts to crontab
function start_miner_at_reboot {
    # Remove existing entry from crontab if present
    (crontab -l | grep -v "@reboot /usr/bin/screen -dmS CCminer /home/$USER/ccminer/ccminer -c /home/$USER/ccminer/config.json" ; echo "@reboot /usr/bin/screen -dmS CCminer /home/$USER/ccminer/ccminer -c /home/$USER/ccminer/config.json") | crontab - >/dev/null 2>&1
    echo -e "${LG}->${NC} Added automated start of miner at boot.${NC}"
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
    run_command_silently pkg install -y cronie termux-services libjansson wget nano git screen openssh termux-services libjansson netcat-openbsd jq termux-api iproute2 tsu

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
    curl -sSL https://raw.githubusercontent.com/Darktron/pre-compiled/generic/ccminer -o ~/ccminer/ccminer
    chmod +x ~/ccminer/ccminer

    # Run jobscheduler.sh, monitor.sh and vcgencmd, overwrite if exists
    download_and_make_executable https://raw.githubusercontent.com/dismaster/RG3DUI/main/jobscheduler.sh jobscheduler.sh
    download_and_make_executable https://raw.githubusercontent.com/dismaster/RG3DUI/main/monitor.sh monitor.sh
    download_and_make_executable https://raw.githubusercontent.com/dismaster/RG3DUI/main/vcgencmd vcgencmd
    
    # Install default config for DONATION
    wget -q -O ~/ccminer/config.json https://raw.githubusercontent.com/dismaster/RG3DUI/main/config.json
    
    # Add jobscheduler.sh and monitor.sh to crontab
    add_to_crontab jobscheduler.sh
    add_to_crontab monitor.sh

elif [[ $(uname -m) == "aarch64"* ]]; then
    # Assuming Raspberry Pi OS
    echo -e "${R}->${NC} Detected OS: SBC${NC}"
    echo -e "${R}->${NC} ${LC}You might get asked for SUDO password - required for Updates${NC}"

    # Update and install necessary packages
    run_command_silently sudo apt-get update
    run_command_silently sudo apt-get install git libcurl4-openssl-dev libssl-dev libjansson-dev automake autotools-dev build-essential screen netcat-openbsd jq iproute2 gawk -y
    run_command_silently sudo apt-get install libllvm-16-ocaml-dev libllvm16 llvm-16 llvm-16-dev llvm-16-doc llvm-16-examples llvm-16-runtime clang-16 clang-tools-16 clang-16-doc libclang-common-16-dev libclang-16-dev libclang1-16 clang-format-16 python3-clang-16 clangd-16 clang-tidy-16 libclang-rt-16-dev libpolly-16-dev libfuzzer-16-dev lldb-16 lld-16 libc++-16-dev libc++abi-16-dev libomp-16-dev libclc-16-dev libunwind-16-dev libmlir-16-dev mlir-16-tools flang-16 libclang-rt-16-dev-wasm32 libclang-rt-16-dev-wasm64 libclang-rt-16-dev-wasm32 libclang-rt-16-dev-wasm64 -y

    # Build ccminer with basic configuration
    build_ccminer_sbc
    
    # Run jobscheduler.sh and monitor.sh, overwrite if exists
    download_and_make_executable https://raw.githubusercontent.com/dismaster/RG3DUI/main/jobscheduler.sh jobscheduler.sh
    download_and_make_executable https://raw.githubusercontent.com/dismaster/RG3DUI/main/monitor.sh monitor.sh

    # Add jobscheduler.sh and monitor.sh to crontab
    add_to_crontab jobscheduler.sh
    add_to_crontab monitor.sh
    
    # Add ccminer to start on boot
    start_miner_at_reboot

else
    # For other Linux distributions
    echo -e "${R}->${NC} Detected OS: $(uname -o)${NC}"
    echo -e "${R}->${NC} ${LC}You might get asked for SUDO password - required for Updates${NC}"

    # Update and install necessary packages
    run_command_silently sudo apt-get update
    run_command_silently sudo apt-get install git libcurl4-openssl-dev libssl-dev libjansson-dev automake autotools-dev build-essential screen netcat-openbsd jq iproute2 gawk -y
    run_command_silently sudo apt-get install libllvm-16-ocaml-dev libllvm16 llvm-16 llvm-16-dev llvm-16-doc llvm-16-examples llvm-16-runtime clang-16 clang-tools-16 clang-16-doc libclang-common-16-dev libclang-16-dev libclang1-16 clang-format-16 python3-clang-16 clangd-16 clang-tidy-16 libclang-rt-16-dev libpolly-16-dev libfuzzer-16-dev lldb-16 lld-16 libc++-16-dev libc++abi-16-dev libomp-16-dev libclc-16-dev libunwind-16-dev libmlir-16-dev mlir-16-tools flang-16 libclang-rt-16-dev-wasm32 libclang-rt-16-dev-wasm64 libclang-rt-16-dev-wasm32 libclang-rt-16-dev-wasm64 -y

    # Clone CCminer repository and rename folder to ccminer, overwrite if exists
    run_command_silently git clone --single-branch -b Verus2.2 https://github.com/monkins1010/ccminer.git ~/ccminer_build

    # Build ccminer with basic configuration
    build_ccminer_unix
    
    # Run jobscheduler.sh and monitor.sh, overwrite if exists
    download_and_make_executable https://raw.githubusercontent.com/dismaster/RG3DUI/main/jobscheduler.sh jobscheduler.sh
    download_and_make_executable https://raw.githubusercontent.com/dismaster/RG3DUI/main/monitor.sh monitor.sh

    # Add jobscheduler.sh and monitor.sh to crontab
    add_to_crontab jobscheduler.sh
    add_to_crontab monitor.sh

    # Add ccminer to start on boot
    start_miner_at_reboot
fi

# Remove installation script
run_command_silently rm install.sh

# Start mining instance
run_command_silently screen -dmS CCminer ~/ccminer/ccminer -c ~/ccminer/config.json

# Success message
echo -e "${LG}->${NC} Installation completed and mining started.${NC}"
