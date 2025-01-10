#!/data/data/com.termux/files/usr/bin/bash

# ANSI color codes for formatting
NC='\033[0m'     # No Color
LC='\033[1;36m'  # Light Cyan
LG='\033[1;32m'  # Light Green
LP='\033[1;35m'  # Light Purple

# Banner
echo -e "${LC} _____             _            ${NC}"
echo -e "${LC}|::   |___ ___ ___| |_ ___ ___  ${NC}"
echo -e "${LC}|:    | . |  _| .'|  _| . |  _| ${NC}"
echo -e "${LC}|     |___|___|__,|_| |___|_|   ${NC}"
echo -e "${LC}|     |${NC} Tool ~ ${LG}Locator${NC}"
echo -e "${LC}|     |${NC} Dev  ~ ${LP}@Ch3ckr${NC}"
echo -e "${LC}|     |${NC} https://gui.refurbminer.de${NC}"
echo -e "${LC}|:.   |_______________________________${NC}"
echo -e "${LC}|:::.                             .:::|${NC}"
echo -e "${LC}'-------------------------------------'${NC}"

# Function to show usage
usage() {
  echo -e "${LG}Usage: $0 {on|off}${NC}"
  exit 1
}

# Check arguments
if [ $# -ne 1 ]; then
  usage
fi

# Handle the argument
case $1 in
  on)
    echo -e "${LG}Starting flashing... Press Ctrl+C to stop.${NC}"
    while true; do
      termux-torch on
      termux-torch off
    done
    ;;
  off)
    echo -e "${LG}Stopping the torch and turning it off.${NC}"
    termux-torch off
    ;;
  *)
    usage
    ;;
esac
