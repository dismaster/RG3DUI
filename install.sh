#!/bin/bash

# Clearing screen
clear 

# Installer version
VERSION="1.0.7"

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

# Log file location
LOG_FILE="gui_setup.log"

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - v$VERSION - $@" | tee -a $LOG_FILE
}

# Function to run commands and log their output
run_command() {
    log "Running command: $@"
    "$@" >> $LOG_FILE 2>&1
    local status=$?
    if [ $status -ne 0 ]; then
        log "Command failed with status $status"
    fi
    return $status
}

# Parse command-line arguments for -pw <password>
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -pw|--password) PASSWORD="$2"; shift ;;
        *) echo -e "${R}->${NC} Invalid argument: $1"; exit 1 ;;
    esac
    shift
done

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
echo -e "${LC}#${NC}                   \/         \/                  \/  ${LC}#${NC}"
echo -e "${LC}#########################################################${NC}"
echo -e "${LC}#          ${LP}->${NC} ${LG}VERUS Miner SETUP${NC} by Ch3ckr ${P}<-${NC}            ${LC}#${NC}"
echo -e "${LC}#########################################################${NC}"
echo -e "${LC}#${NC}              ${LG}https://api.rg3d.eu:8443${NC}                 ${LC}#${NC}"
echo -e "${LC}#########################################################${NC}"
echo  # New line for spacing
echo -e "${R}->${NC} ${LC}This process may take a while...${NC}"
echo  # New line for spacing

# Function to check if curl works properly with SSL
check_curl_ssl() {
    log "Checking if curl works with SSL..."
    curl -sI https://www.google.com > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        log "curl is working properly with SSL."
        CURL_CMD="curl -sSL"
    else
        log "curl is not working properly with SSL, switching to --insecure mode."
        CURL_CMD="curl -sSL --insecure"
    fi
}

# Run the curl check
check_curl_ssl

# Function to download a file and make it executable, overwrite if exists
download_and_make_executable() {
    local url=$1
    local filename=$2
    local target_dir=$3

    if [ ! -z "$target_dir" ]; then
        cd $target_dir
    fi

    log "Downloading $url to $filename"
    $CURL_CMD $url -o $filename
    if [ $? -eq 0 ]; then
        chmod +x $filename
        log "Downloaded and made executable: $filename"
    else
        log "Failed to download $url"
    fi
}

# Function to build ccminer from source for SBCs
function build_ccminer_sbc {
    log "Building CCminer for SBC..."
    run_command wget http://ports.ubuntu.com/pool/main/o/openssl/libssl1.1_1.1.0g-2ubuntu4_arm64.deb
    run_command sudo dpkg -i libssl1.1_1.1.0g-2ubuntu4_arm64.deb
    run_command rm libssl1.1_1.1.0g-2ubuntu4_arm64.deb
   
    # After build, create ~/ccminer folder and copy ccminer executable
    run_command mkdir -p ~/ccminer
    run_command wget -q -O ~/ccminer/ccminer https://raw.githubusercontent.com/Oink70/CCminer-ARM-optimized/main/ccminer
    run_command chmod +x ~/ccminer/ccminer

    # Install default config for DONATION
    run_command wget -q -O ~/ccminer/config.json https://raw.githubusercontent.com/dismaster/RG3DUI/main/config.json
}

# Function to build ccminer from source for UNIX
function build_ccminer_unix {
    log "Building CCminer for UNIX..."
    run_command wget http://ports.ubuntu.com/pool/main/o/openssl/libssl1.1_1.1.0g-2ubuntu4_arm64.deb
    run_command sudo dpkg -i libssl1.1_1.1.0g-2ubuntu4_arm64.deb
    run_command rm libssl1.1_1.1.0g-2ubuntu4_arm64.deb
    run_command cd ~/ccminer_build 
    run_command ./build.sh 
    run_command cd ~/
    
    # After build, create ~/ccminer folder and copy ccminer executable
    run_command mkdir -p ~/ccminer
    run_command mv ~/ccminer_build/ccminer ~/ccminer/ccminer
    
    # Clean up ccminer_build folder
    run_command rm -rf ~/ccminer_build

    # Install default config for DONATION
    run_command wget -q -O ~/ccminer/config.json https://raw.githubusercontent.com/dismaster/RG3DUI/main/config.json
}

# Function to select the correct ccminer version based on CPU
select_ccminer_version() {
    log "Detecting CPU architecture..."

    CPU_INFO=$(./cpu_check_arm) # Run the CPU detection tool for Termux
    log "CPU info: $CPU_INFO"

    # Prioritize combined CPU configurations first, and then fallback to single core types
    if echo "$CPU_INFO" | grep -q "A76" && echo "$CPU_INFO" | grep -q "A55"; then
        CC_BRANCH="a76-a55"
    elif echo "$CPU_INFO" | grep -q "A75" && echo "$CPU_INFO" | grep -q "A55"; then
        CC_BRANCH="a75-a55"
    elif echo "$CPU_INFO" | grep -q "A72" && echo "$CPU_INFO" | grep -q "A53"; then
        CC_BRANCH="a72-a53"
    elif echo "$CPU_INFO" | grep -q "A73" && echo "$CPU_INFO" | grep -q "A53"; then
        CC_BRANCH="a73-a53"
    elif echo "$CPU_INFO" | grep -q "EM5" && echo "$CPU_INFO" | grep -q "A76" && echo "$CPU_INFO" | grep -q "A55"; then
        CC_BRANCH="em5-a76-a55"
    elif echo "$CPU_INFO" | grep -q "EM4" && echo "$CPU_INFO" | grep -q "A75" && echo "$CPU_INFO" | grep -q "A55"; then
        CC_BRANCH="em4-a75-a55"
    elif echo "$CPU_INFO" | grep -q "EM3" && echo "$CPU_INFO" | grep -q "A55"; then
        CC_BRANCH="em3-a55"
    elif echo "$CPU_INFO" | grep -q "A57" && echo "$CPU_INFO" | grep -q "A53"; then
        CC_BRANCH="a57-a53"
    
    # Now check for single-core architectures if no combinations match
    elif echo "$CPU_INFO" | grep -q "A35"; then
        CC_BRANCH="a35"
    elif echo "$CPU_INFO" | grep -q "A53"; then
        CC_BRANCH="a53"
    elif echo "$CPU_INFO" | grep -q "A55"; then
        CC_BRANCH="a55"
    elif echo "$CPU_INFO" | grep -q "A57"; then
        CC_BRANCH="a57"
    elif echo "$CPU_INFO" | grep -q "A65"; then
        CC_BRANCH="a65"
    elif echo "$CPU_INFO" | grep -q "A72"; then
        CC_BRANCH="a72"
    elif echo "$CPU_INFO" | grep -q "A73"; then
        CC_BRANCH="a73"
    elif echo "$CPU_INFO" | grep -q "A75"; then
        CC_BRANCH="a75"
    elif echo "$CPU_INFO" | grep -q "A76"; then
        CC_BRANCH="a76"
    elif echo "$CPU_INFO" | grep -q "A77"; then
        CC_BRANCH="a77"
    elif echo "$CPU_INFO" | grep -q "A78"; then
        CC_BRANCH="a78"
    elif echo "$CPU_INFO" | grep -q "A78C"; then
        CC_BRANCH="a78c"
    elif echo "$CPU_INFO" | grep -q "X1" && echo "$CPU_INFO" | grep -q "A78" && echo "$CPU_INFO" | grep -q "A55"; then
        CC_BRANCH="x1-a78-a55"
    else
        CC_BRANCH="generic"
    fi

    log "Selected ccminer branch: $CC_BRANCH"
}


# Function to prompt for password with verification, or use provided password
function prompt_for_password {
    if [ -n "$PASSWORD" ]; then
        log "Using provided password."
        echo "rig_pw=$PASSWORD" > ~/rig.conf
    else
        while true; do
            echo -e "${R}->${NC} ${Y}Enter RIG Password:${NC}"
            read -s pw1
            echo
            echo -e "${R}->${NC} ${Y}Confirm RIG Password:${NC}"
            read -s pw2
            echo

            if [[ "$pw1" == "$pw2" ]]; then
                echo "rig_pw=$pw1" > ~/rig.conf
                log "Password set successfully."
                break
            else
                log "Passwords do not match."
                echo -e "${R}->${NC} ${R}Passwords do not match. Please try again.${NC}"
            fi
        done
    fi
}

# Function to delete ~/ccminer folder if it exists
function delete_ccminer_folder {
    if [ -d ~/ccminer ]; then
        log "Deleting existing ~/ccminer folder and its contents"
        rm -rf ~/ccminer
    fi
    if [ -d ~/ccminer_build ]; then
        log "Deleting existing ~/ccminer_build folder and its contents"
        rm -rf ~/ccminer_build
    fi
}

# Function to add scripts to crontab
function add_to_crontab {
    local script=$1
    # Remove existing entry from crontab if present
    (crontab -l | grep -v "$script" ; echo "* * * * * ~/$script") | crontab - >/dev/null 2>&1
    log "Added $script to crontab."

    # Start the script immediately after adding to crontab
    log "Starting $script."
    run_command ~/$script
}

# Function to add scripts to crontab
function start_miner_at_reboot {
    # Remove existing entry from crontab if present
    (crontab -l | grep -v "@reboot /usr/bin/screen -dmS CCminer /home/$USER/ccminer/ccminer -c /home/$USER/ccminer/config.json" ; echo "@reboot /usr/bin/screen -dmS CCminer /home/$USER/ccminer/ccminer -c /home/$USER/ccminer/config.json") | crontab - >/dev/null 2>&1
    log "Added automated start of miner at boot."
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

# Detect OS with debugging
if [[ $(uname -o) == "Android" ]]; then
    log "Detected OS: Android"
    echo -e "${R}->${NC} Detected OS: Android${NC}"
    
    log "Checking for Termux"
    if command -v termux-info > /dev/null 2>&1; then
        log "Running on Termux"
        # Update and upgrade packages
        log "Updating and upgrading packages"
        run_command pkg update -y
        run_command pkg upgrade -y

        # Install required packages
        log "Installing required packages"
        run_command pkg install -y openssl cronie termux-services termux-auth libjansson wget nano git screen openssh termux-services libjansson netcat-openbsd jq termux-api iproute2 tsu android-tools

        # Create ~/.termux folder if not exists
        log "Creating ~/.termux folder"
        run_command mkdir -p ~/.termux
        run_command mkdir -p ~/.cache
        run_command mkdir -p ~/ccminer

        # Create ~/.termux/boot folder if not exists
        log "Creating ~/.termux/boot folder"
        run_command mkdir -p ~/.termux/boot

        # Change directory to ~/.termux/boot and download boot_start script
        log "Downloading boot_start script"
        run_command wget -q https://raw.githubusercontent.com/dismaster/RG3DUI/main/boot_start -O ~/.termux/boot/boot_start

        # Make boot_start script executable
        log "Making boot_start script executable"
        run_command chmod +x ~/.termux/boot/boot_start

        # Download cpu check
        log "Downloading and setting up CPU check"
        download_and_make_executable https://raw.githubusercontent.com/dismaster/RG3DUI/main/cpu_check_arm cpu_check_arm

        # Select and download correct ccminer version based on CPU architecture
        select_ccminer_version
        run_command wget -q "https://raw.githubusercontent.com/Darktron/pre-compiled/$CC_BRANCH/ccminer" -O ~/ccminer/ccminer
        run_command chmod +x ~/ccminer/ccminer

        # Run jobscheduler.sh, monitor.sh, and schedule_job.sh, overwrite if exists
        log "Downloading and setting up jobscheduler.sh, monitor.sh, rg3d_cpu.sh, and schedule_job.sh"
        download_and_make_executable https://raw.githubusercontent.com/dismaster/RG3DUI/main/jobscheduler.sh jobscheduler.sh
        download_and_make_executable https://raw.githubusercontent.com/dismaster/RG3DUI/main/monitor.sh monitor.sh
        download_and_make_executable https://raw.githubusercontent.com/dismaster/RG3DUI/main/rg3d_cpu.sh rg3d_cpu.sh
        download_and_make_executable https://raw.githubusercontent.com/dismaster/RG3DUI/main/schedule_job.sh schedule_job.sh
        download_and_make_executable https://raw.githubusercontent.com/dismaster/RG3DUI/main/vcgencmd vcgencmd
        
        # Install default config for DONATION
        log "Downloading default config"
        run_command wget -q -O ~/ccminer/config.json https://raw.githubusercontent.com/dismaster/RG3DUI/main/config.json
        
        # Add jobscheduler.sh and monitor.sh to crontab
        log "Adding jobscheduler.sh and monitor.sh to crontab"
        add_to_crontab jobscheduler.sh
        add_to_crontab monitor.sh

        # Termux vibration for notification
        termux-vibrate -f -d 1000    
    else
        log "Termux not detected, exiting"
        echo -e "${R}->${NC} Termux not detected. Please run this script in a Termux environment.${NC}"
        exit 1
    fi
    
else
    log "Detected OS: $(uname -o)"
    echo -e "${R}->${NC} Detected OS: $(uname -o)${NC}"
    echo -e "${R}->${NC} ${LC}You might get asked for SUDO password - required for Updates${NC}"

    # Check if the system is an SBC (e.g., Raspberry Pi, Orange Pi) or ARM-based
    if grep -q "Raspberry" /proc/device-tree/model || grep -q "Orange" /proc/device-tree/model || grep -q "Rockchip" /proc/device-tree/model || lscpu | grep -q "ARM"; then
        log "Detected SBC or ARM-based device"
        echo -e "${R}->${NC} Detected SBC or ARM-based device${NC}"

        # Check if the system is Raspberry Pi Zero 2W
        if grep -q "Raspberry Pi Zero 2 W" /proc/device-tree/model; then
            log "Detected Raspberry Pi Zero 2W"
            echo -e "${R}->${NC} Detected Raspberry Pi Zero 2W${NC}"
        fi

        # Update and install necessary packages
        run_command sudo apt-get update
        run_command sudo apt-get install -y openssl android-tools-adb android-tools-fastboot cron libomp5 git libcurl4-openssl-dev libssl-dev libjansson-dev automake autotools-dev build-essential screen netcat-openbsd jq iproute2 gawk
        run_command sudo apt-get install -y libllvm-16-ocaml-dev libllvm16 llvm-16 llvm-16-dev llvm-16-doc llvm-16-examples llvm-16-runtime clang-16 clang-tools-16 clang-16-doc libclang-common-16-dev libclang-16-dev libclang1-16 clang-format-16 python3-clang-16 clangd-16 clang-tidy-16 libclang-rt-16-dev libpolly-16-dev libfuzzer-16-dev lldb-16 lld-16 libc++-16-dev libc++abi-16-dev libomp-16-dev libclc-16-dev libunwind-16-dev libmlir-16-dev mlir-16-tools flang-16 libclang-rt-16-dev-wasm32 libclang-rt-16-dev-wasm64

        # Build ccminer with basic configuration
        build_ccminer_sbc

        # Run jobscheduler.sh, monitor.sh, rg3d_cpu.sh and schedule_job.sh, overwrite if exists
        download_and_make_executable https://raw.githubusercontent.com/dismaster/RG3DUI/main/jobscheduler.sh jobscheduler.sh
        download_and_make_executable https://raw.githubusercontent.com/dismaster/RG3DUI/main/monitor.sh monitor.sh
        download_and_make_executable https://raw.githubusercontent.com/dismaster/RG3DUI/main/rg3d_cpu.sh rg3d_cpu.sh
        download_and_make_executable https://raw.githubusercontent.com/dismaster/RG3DUI/main/schedule_job.sh schedule_job.sh

        # Add jobscheduler.sh and monitor.sh to crontab
        add_to_crontab jobscheduler.sh
        add_to_crontab monitor.sh

        run_command sudo systemctl enable cron

        # Add ccminer to start on boot
        start_miner_at_reboot
    else
        log "Detected general Linux device"
        echo -e "${R}->${NC} Detected general Linux device${NC}"

        # Update and install necessary packages
        run_command sudo apt-get update
        run_command sudo apt-get install -y openssl cron git libcurl4-openssl-dev libssl-dev libjansson-dev automake autotools-dev build-essential screen netcat-openbsd jq iproute2 gawk
        run_command sudo apt-get install -y libllvm-16-ocaml-dev libllvm16 llvm-16 llvm-16-dev llvm-16-doc llvm-16-examples llvm-16-runtime clang-16 clang-tools-16 clang-16-doc libclang-common-16-dev libclang-16-dev libclang1-16 clang-format-16 python3-clang-16 clangd-16 clang-tidy-16 libclang-rt-16-dev libpolly-16-dev libfuzzer-16-dev lldb-16 lld-16 libc++-16-dev libc++abi-16-dev libomp-16-dev libclc-16-dev libunwind-16-dev libmlir-16-dev mlir-16-tools flang-16 libclang-rt-16-dev-wasm32 libclang-rt-16-dev-wasm64

        # Clone CCminer repository and rename folder to ccminer, overwrite if exists
        run_command git clone --single-branch -b Verus2.2 https://github.com/monkins1010/ccminer.git ~/ccminer_build

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
fi

# Remove installation script
run_command rm install.sh

# Start mining instance
run_command screen -dmS CCminer ~/ccminer/ccminer -c ~/ccminer/config.json
run_command ./monitor.sh
run_command ./jobscheduler.sh

# Success message
echo -e "${LG}->${NC} Installation completed and mining started.${NC}"
log "Installation completed and mining started."
