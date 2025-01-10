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

while true; do
  # Flash LED 
  termux-torch on
  termux-torch off
done
