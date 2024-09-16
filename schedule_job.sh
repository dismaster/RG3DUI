#!/bin/bash

## This File is for running jobscheduler and monitoring in a separated screen session
## screen -dmS Scheduler ./schedule_job.sh

while true; do
    ~/jobscheduler.sh -debug
    ~/monitor.sh
    ~/rg3d_cpu.sh
    sleep 60
done
