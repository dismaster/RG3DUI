#!/data/data/com.termux/files/usr/bin/bash

## This File is for running jobscheduler and monitoring in a separated screen session
## screen -dmS Scheduler ./schedule_job.sh

source /data/data/com.termux/files/usr/etc/profile

while true; do
    bash /data/data/com.termux/files/home/jobscheduler.sh -debug
    bash /data/data/com.termux/files/home/monitor.sh
    bash /data/data/com.termux/files/home/rg3d_cpu.sh
    sleep 60
done
