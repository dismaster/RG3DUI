# Mining GUI Installation Guide

Welcome to the Mining Monitor installation guide! This document will walk you through the steps necessary to install and set up the Mining Monitor on your system.

[Mining GUI](https://api.rg3d.eu:8443)

[Discord](https://discord.gg/P5BmXK8dkp)

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
   1. [Direct Installation on the Phone/SBC](#direct-installation-on-the-phonesbc)
   2. [Installation via Python Script (Windows)](#installation-via-python-script-windows)
3. [Configuration](#configuration)
4. [Information](#information)
5. [CPU/ARM/SBC Hashrates](#cpuarm-hashrate-collection)

## Prerequisites

Before you begin, ensure you have met the following requirements:
- **Device**: Mining Capable Phone or ARM SBC 64-bit CPU and Operating System
- **Operating System**: Linux if you are on an SBC, Userland or Termux (including termux-api and termux-boot) if you are on Android.
- **RIG Password**: Add a RIG in the GUI to get the password generated (Details in [Installation](#installation)).
- **For Windows Installation Method**:
  - **Python**: Installed on your Windows system.
  - **Android SDK**: Installed and configured.
  - **USB Debugging**: Enabled on the phone, and the phone is connected to the host via USB.

## Installation

Go to [Rig Overview](https://api.rg3d.eu:8443/rig_overview.php) and add a rig, **Make Sure to Document the Password!**

### 1. Direct Installation on the Phone/SBC

Follow these steps to install the Mining System directly on your Phone/SBC:

Open your terminal and execute the following command:

```sh
curl -O https://raw.githubusercontent.com/dismaster/RG3DUI/main/install.sh >/dev/null 2>&1 && chmod +x install.sh && ./install.sh
```

Enter the password you obtained when adding the rig to the dashboard.

### 2. Installation via Python Script (Windows)

If you are running Windows, you can also install the mining software via a Python script. This method is useful if you prefer managing the installation from a desktop environment.

#### Prerequisites for Windows Installation:
- Ensure you have Python and the Android SDK installed on your Windows machine.
- Enable USB debugging on your Android phone (go to *Settings > Developer Options* and turn on *USB Debugging*).
- Connect your phone to the Windows machine via USB.

#### Steps:

1. **Download the Python Script**:  
   Download the installer script from the GitHub repository by running the following command in your terminal:
   ```sh
   git clone https://github.com/dismaster/RG3DUI.git
   ```
   This will create a folder with all necessary files.

2. **Run the Python Script**:  
   Navigate to the folder where the script is located:
   ```sh
   cd RG3DUI
   ```
   Run the Python installer:
   ```sh
   python rg3d_installer.py
   ```
   The script will automatically download ADB and APK files into the folder and initiate the setup process.

3. **Follow On-Screen Instructions**:  
   The script will guide you through the installation process, including deploying the necessary APKs to your connected Android phone. Make sure your phone is recognized by the script (you can check if it's connected by running `adb devices`).

4. **Enter RIG Password**:  
   As with the phone installation, enter the password generated when you added the rig to the dashboard.

## Configuration

After installation, the scripts will populate any required configuration according to your RIG configuration itself. After install is complete, wait a couple of minutes and make sure the dashboard shows the device mining!

## Information

The GUI is being updated in specific time frames!

1. Rig Details: every 2 minute(s)
2. Miner Details: every 1 minute(s)

# HAPPY MINING!

## CPU/ARM Hashrate Collection

We're looking for help to gather information around that topic in order to create a new website which shows all relevant information. If you want to participate, try the following in either your Termux, Userland, or SBC installation:
```sh
wget https://raw.githubusercontent.com/dismaster/RG3DUI/main/rg3d_cpu.sh && chmod +x rg3d_cpu.sh && ./rg3d_cpu.sh
```
This way you will easily support us in getting the list growing!
