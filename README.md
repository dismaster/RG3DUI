# Mining GUI Installation Guide

Welcome to the Mining Monitor installation guide! This document will walk you through the steps necessary to install and set up the Mining Monitor on your system.

[Mining GUI](https://api.rg3d.eu:8443)

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Configuration](#configuration)

## Prerequisites

Before you begin, ensure you have met the following requirements:
- **Operating System**: Linux with 64bit CPU, mining capable ARM SBC, mining capable Phone with Termux installed (including termix-api and termux-boot)
- **RIG Password**: Generate a RIG to get a new from the GUI

## Installation

Follow these steps to install the Mining Monitoring on your system:

### Download and Run the Installation Script

Open your terminal and execute the following command:

```sh
curl -O https://raw.githubusercontent.com/dismaster/RG3DUI/main/install.sh >/dev/null 2>&1 && chmod +x install.sh && ./install.sh
```

#### Configuration

After installation, the scripts will populate any required configuration according to your RIG configuration itself

HAPPY MINING!
