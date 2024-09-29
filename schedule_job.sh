#!/data/data/com.termux/files/usr/bin/bash

source /data/data/com.termux/files/usr/etc/profile

while true; do
    bash /data/data/com.termux/files/home/jobscheduler.sh -debug
    bash /data/data/com.termux/files/home/monitor.sh
    bash /data/data/com.termux/files/home/rg3d_cpu.sh
    sleep 60
done
