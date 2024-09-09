import json
import subprocess
import threading
import requests
import os
import time
from tqdm import tqdm
from datetime import datetime
import sys
import zipfile

# ANSI color codes for formatting
NC = '\033[0m'     # No Color
R = '\033[0;31m'   # Red
G = '\033[1;32m'   # Light Green
Y = '\033[1;33m'   # Yellow
LC = '\033[1;36m'  # Light Cyan
LB = '\033[1;34m'  # Light Blue
P = '\033[0;35m'   # Purple
LP = '\033[1;35m'  # Light Purple

# Enhanced feedback symbols
CHECKMARK = f"{G}🟢{NC}"
INFO = f"{LB}🔵{NC}"
ERROR = f"{R}❌{NC}"

# Global variables to hold the RIG password and SSH configuration if provided
RIG_PASSWORD = None
ENABLE_SSH = False
SSH_PASSWORD = None
DEBUG = False  # Set to True for debugging output, False to disable

ADB_URL = "https://dl.google.com/android/repository/platform-tools-latest-{}.zip"

# Clear the console screen
def clear_screen():
    os.system('cls' if os.name == 'nt' else 'clear')

# Fancy Banner with RG3D VERUS Logo (Original Format)
def print_banner():
    banner = f"""
{LC} ___             __         __ __{NC}            
{LC}|   .-----.-----|  |_.---.-|  |  .-----.----.{NC}
{LC}|.  |     |__ --|   _|  _  |  |  |  -__|   _|{NC}
{LC}|.  |__|__|_____|____|___._|__|__|_____|__|{NC}  
{LC}|:  |       Developer ~ @Ch3ckr{NC}
{LC}|::.|       Tool      ~ RG3D Mining GUI Installer{NC}
{LC}`---'       For More ~ https://api.rg3d.eu:8443{NC}
    """
    print(banner)

# Ensure ADB is available in the current folder, download if missing
def ensure_adb():
    adb_executable = "adb.exe" if os.name == 'nt' else "adb"
    
    if not os.path.exists(adb_executable):
        if DEBUG:
            print(f"{INFO} Setting up ADB...")
        platform = 'windows' if os.name == 'nt' else 'linux' if sys.platform == 'linux' else 'macosx'
        adb_zip_url = ADB_URL.format(platform)
        adb_zip_file = f"platform-tools-{platform}.zip"
        
        try:
            response = requests.get(adb_zip_url)
            with open(adb_zip_file, 'wb') as f:
                f.write(response.content)
            with zipfile.ZipFile(adb_zip_file, 'r') as zip_ref:
                zip_ref.extractall(".")
        except Exception as e:
            print(f"{ERROR} Failed to download ADB: {e}")
            sys.exit(1)

# Check if required Python packages are installed
def check_required_packages():
    required_packages = ["requests", "tqdm"]
    missing_packages = []
    
    for package in required_packages:
        try:
            __import__(package)
        except ImportError:
            missing_packages.append(package)
    
    if missing_packages:
        if DEBUG:
            print(f"{INFO} Installing required packages...")
        try:
            subprocess.check_call([sys.executable, "-m", "pip", "install"] + missing_packages)
        except subprocess.CalledProcessError as e:
            print(f"{ERROR} Failed to install required packages: {e}")
            sys.exit(1)

# Check if Termux APKs are already in the same folder
def ensure_termux_apks():
    apks = {
        'termux': 'com.termux_1000.apk',
        'termux_api': 'com.termux.api_51.apk',
        'termux_boot': 'com.termux.boot_1000.apk'
    }
    base_url = "https://f-droid.org/repo/"
    
    for apk_name, apk_file in apks.items():
        if not os.path.exists(apk_file):
            try:
                response = requests.get(base_url + apk_file)
                with open(apk_file, 'wb') as f:
                    f.write(response.content)
            except Exception as e:
                print(f"{ERROR} Failed to download {apk_file}: {e}")
                sys.exit(1)

# Uninstall Google Play Services, Google Play Store, and related apps
def uninstall_google_play_apps(device):
    packages_to_uninstall = [
        'com.google.android.gms',       # Google Play Services
        'com.android.vending',          # Google Play Store
        'com.google.android.gsf',       # Google Services Framework
    ]

    installed_packages = get_installed_packages(device)

    for package in packages_to_uninstall:
        if package in installed_packages:
            run_adb_command(device, ['shell', 'pm', 'uninstall', '--user', '0', package])
        else:
            if DEBUG:
                print(f"{INFO} {package} is not installed on device {device}, skipping.")

# Apply system settings to optimize the device for mining
def apply_system_settings(device):
    settings_commands = [
        'shell settings put global wifi_sleep_policy 2',
        'shell settings put global system_capabilities 100',
        'shell settings put global sem_enhanced_cpu_responsiveness 1',
        'shell settings put global adaptive_battery_management_enable 0',
        'shell settings put global adaptive_power_saving_setting 0',
        'shell dumpsys battery set level 100',
        'shell settings put global window_animation_scale 0',
        'shell settings put global transition_animation_scale 0',
        'shell settings put global animator_duration_scale 0',
        'shell settings put global background_limit 4'
    ]
    
    for command in settings_commands:
        run_adb_command(device, command.split())

# Install the Termux APKs on the device
def install_termux(device):
    apk_paths = {
        'termux': 'com.termux_1000.apk',
        'termux_api': 'com.termux.api_51.apk',
        'termux_boot': 'com.termux.boot_1000.apk'
    }
    
    for apk_name, apk_file in apk_paths.items():
        run_adb_command(device, ['install', apk_file])

# Start and stop Termux Boot using "monkey" command
def start_stop_termux_boot(device):
    run_adb_command(device, ['shell', 'monkey', '-p', 'com.termux.boot', '1'])

# Remove recommended apps based on UAD JSON
def remove_recommended_apps(device, installed_packages):
    uad_url = "https://raw.githubusercontent.com/0x192/universal-android-debloater/main/resources/assets/uad_lists.json"
    
    try:
        response = requests.get(uad_url)
        app_list = response.json()

        # Filter for apps where removal is "Recommended" and installed on the device
        recommended_apps = [app.get('id') for app in app_list if app.get('removal') == 'Recommended' and app.get('id') in installed_packages]
        
        # Uninstall recommended apps
        if recommended_apps:
            uninstall_packages(device, recommended_apps)
    except (requests.RequestException, json.JSONDecodeError) as e:
        print(f"{ERROR} Failed to fetch or parse UAD list: {e}")

# Ask the user if they want to submit a RIG password
def ask_for_rig_password():
    global RIG_PASSWORD
    choice = input(f"{INFO} Submit RIG password? (y/n): ").strip().lower()
    if choice == 'y':
        RIG_PASSWORD = input(f"{INFO} Enter RIG password: ").strip()

# Ask the user if they want to enable SSH and provide a password
def ask_for_ssh():
    global ENABLE_SSH, SSH_PASSWORD
    choice = input(f"{INFO} Enable SSH? (y/n): ").strip().lower()
    if choice == 'y':
        SSH_PASSWORD = input(f"{INFO} Enter SSH password (cannot be empty): ").strip()
        if SSH_PASSWORD:
            ENABLE_SSH = True
        else:
            print(f"{ERROR} SSH password cannot be empty. Skipping SSH setup.")

# ADB command executor with retry logic and debug
def run_adb_command(device, command, retries=3):
    if DEBUG:
        print(f"Running command on device {device}: {' '.join(command)}")  # Debugging statement
    try:
        subprocess.run(['adb', '-s', device] + command, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, check=True)
    except subprocess.CalledProcessError as e:
        if DEBUG:
            print(f"{ERROR} Command failed on device {device}: {' '.join(command)}")
            print(f"{ERROR} stderr: {e.stderr.decode()}")
        if retries > 0:
            time.sleep(2)
            return run_adb_command(device, command, retries - 1)
        else:
            if DEBUG:
                print(f"{ERROR} Command permanently failed on device {device}.")
            return False
    return True

# Fetch list of installed packages
def get_installed_packages(device):
    try:
        output = subprocess.check_output(['adb', '-s', device, 'shell', 'pm', 'list', 'packages']).decode()
        packages = [line.replace('package:', '').strip() for line in output.splitlines()]
        return packages
    except subprocess.CalledProcessError as e:
        print(f"{ERROR} Failed to fetch installed packages on device {device}: {e}")
        return []

# Uninstall packages using the ADB package manager
def uninstall_packages(device, packages_to_uninstall):
    for package in packages_to_uninstall:
        run_adb_command(device, ['shell', 'pm', 'uninstall', '--user', '0', package])

# Start Termux and run commands using key input simulation
def setup_termux(device):
    run_adb_command(device, ['shell', 'am', 'start', '-n', 'com.termux/.HomeActivity'])
    time.sleep(5)

    # Use key input simulation to run termux-change-repo
    type_in_termux(device, 'termux-change-repo')
    submit_enter(device)
    time.sleep(2)
    submit_enter(device)  # Press enter twice for default repos
    time.sleep(2)
    submit_enter(device)
    time.sleep(15)

    # Use key input simulation to type commands in Termux separately
    type_in_termux(device, 'yes | pkg update')
    submit_enter(device)
    time.sleep(15)

    type_in_termux(device, 'yes | pkg upgrade')
    submit_enter(device)
    time.sleep(60)

    # Download the mining setup script
    type_in_termux(device, 'curl -O https://raw.githubusercontent.com/dismaster/RG3DUI/main/install.sh')
    submit_enter(device)
    time.sleep(5)

    # Execute the downloaded script
    type_in_termux(device, 'chmod +x install.sh && ./install.sh')
    submit_enter(device)
    time.sleep(5)

    # Submit RIG password if provided
    if RIG_PASSWORD:
        type_in_termux(device, RIG_PASSWORD)
        submit_enter(device)
        type_in_termux(device, RIG_PASSWORD)
        submit_enter(device)
        time.sleep(60)

    # Set SSH password and enable SSH if requested
    if ENABLE_SSH and SSH_PASSWORD:
        # Set the SSH password interactively
        type_in_termux(device, 'passwd')
        submit_enter(device)
        time.sleep(2)

        # Enter SSH password
        type_in_termux(device, SSH_PASSWORD)
        submit_enter(device)
        time.sleep(2)

        # Confirm SSH password
        type_in_termux(device, SSH_PASSWORD)
        submit_enter(device)
        time.sleep(2)

        # Start SSH service
        type_in_termux(device, 'sshd')
        submit_enter(device)

        # ADB shell step for user approval
        type_in_termux(device, 'adb shell')
        submit_enter(device)
        time.sleep(20)  # Wait for user to approve ADB shell access
        type_in_termux(device, 'exit')
        submit_enter(device)

# Simulate typing commands in Termux using ADB key inputs
def type_in_termux(device, command):
    run_adb_command(device, ['shell', f'input text "{command}"'])

# Simulate pressing the "Enter" key
def submit_enter(device):
    run_adb_command(device, ['shell', 'input', 'keyevent', '66'])

# Main function to detect ADB devices and launch threads
def process_device(device):
    # Steps for individual device setup, now reflecting 7 steps
    total_steps = 6  # Disable Google Play, Install Termux, Apply System Settings, Debloat, Termux Boot, Setup Termux, Install Mining Script
    device_progress = tqdm(total=total_steps, desc=f"Setting up device {device}", unit="step")

    # Step 1: Uninstall Google Play Services and related apps
    uninstall_google_play_apps(device)
    device_progress.update(1)

    # Step 2: Install Termux and related APKs
    install_termux(device)
    device_progress.update(1)

    # Step 3: Apply system settings
    apply_system_settings(device)
    device_progress.update(1)

    # Step 4: Debloat the device
    installed_packages = get_installed_packages(device)
    remove_recommended_apps(device, installed_packages)
    device_progress.update(1)

    # Step 5: Start/Stop Termux Boot
    start_stop_termux_boot(device)
    device_progress.update(1)

    # Step 6: Setup Termux and run commands
    setup_termux(device)
    device_progress.update(1)

def main():
    clear_screen()
    print_banner()
    ask_for_rig_password()
    ask_for_ssh()
    check_required_packages()
    ensure_adb()
    ensure_termux_apks()
    start_time = datetime.now()

    devices_output = subprocess.check_output(['adb', 'devices']).decode()
    devices = [line.split()[0] for line in devices_output.splitlines() if '\tdevice' in line]
    
    if not devices:
        print(f"{ERROR} No devices found.")
        return

    threads = []
    for device in devices:
        thread = threading.Thread(target=process_device, args=(device,))
        threads.append(thread)
        thread.start()

    # Wait for all threads to complete
    for thread in threads:
        thread.join()

    end_time = datetime.now()
    total_time = end_time - start_time
    print(f"\n{G}🟢 All tasks completed. Total time: {total_time}")

if __name__ == "__main__":
    main()
