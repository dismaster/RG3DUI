#!/data/data/com.termux/files/usr/bin/bash

source /data/data/com.termux/files/usr/etc/profile

echo -c " __________     _         _     _         "
echo -c "|          |___| |_ ___ _| |_ _| |___ ___ "
echo -c "|     _____|  _|   | -_| . | | | | -_|  _|"
echo -c "|          |___|_|_|___|___|___|_|___|_|  "
echo -c "|_____     |    Tool ~ Jobscheduler"
echo -c "|          |    Dev  ~ @Ch3ckr"
echo -c "|__________|    URL  ~ https://gui.rg3d.eu"

while true; do
    bash /data/data/com.termux/files/home/jobscheduler.sh -debug
    bash /data/data/com.termux/files/home/monitor.sh
    bash /data/data/com.termux/files/home/rg3d_cpu.sh
    sleep 60
done
