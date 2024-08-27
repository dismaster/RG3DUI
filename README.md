# Mining GUI Installation Guide

Welcome to the Mining Monitor installation guide! This document will walk you through the steps necessary to install and set up the Mining Monitor on your system.

[Mining GUI](https://api.rg3d.eu:8443)

[Discord](https://discord.gg/P5BmXK8dkp)

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Configuration](#configuration)
4. [Information](#information)
5. [CPU/ARM/SBC Hashrates](#cpuarm-hashrate-collection)

## Prerequisites

Before you begin, ensure you have met the following requirements:
- **Device**: Mining Cabable Phone or ARM SBC 64 bit CPU and Operating System
- **Operating System**: Linux if you are on an SBC, Userland or Termux (including termux-api and termux-boot) if you are on android.
- **RIG Password**: Add a RIG in the GUI to get the password generated (Details in [Installation](#installation)).

## Installation

Go to [Rig Overview](https://api.rg3d.eu:8443/rig_overview.php) and add a rig, **Make Sure to Document the Password!**

### Follow these steps to install the Mining System on your Phone/SBC:

Open your terminal and execute the following command:

```sh
curl -O https://raw.githubusercontent.com/dismaster/RG3DUI/main/install.sh >/dev/null 2>&1 && chmod +x install.sh && ./install.sh
```
Enter the password you obtained when adding the rig to the dashboard.

#### Configuration

After installation, the scripts will populate any required configuration according to your RIG configuration itself.
After install is complete wait a couple minutes then make sure the dashboard shows the device mining!

#### Information

The GUI is being updated in specific time frames!

1. Rig Details: every 2 minute(s)
2. Miner Details: every 1 minute(s)

# HAPPY MINING!

## CPU/ARM Hashrate Collection

We're looking for help to gather informations around that topic in order to create a new website which shows all relevant informations.
If you want to participate, try the following in either your Termux, Userland or SBC installation:
```sh
wget https://raw.githubusercontent.com/dismaster/RG3DUI/main/rg3d_cpu.sh && chmod +x rg3d_cpu.sh && ./rg3d_cpu.sh
```
This way you will easily support us getting the list growing!