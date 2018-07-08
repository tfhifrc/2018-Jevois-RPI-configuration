#!/bin/sh

#set -x
for i in 1 2 4 1 2 4 8
do
    more=0
    for j in 0 1 2
    do
        rc=$(/home/pi/mjpg-streamer.sh status ${j} | grep stopped)
        if [ -z "${rc}" ]; then
            /home/pi/mjpg-streamer.sh stop ${j}
            more=1
        else
            echo "Already stopped: /dev/video${j}"
        fi
    done

    if [ "${more}" -eq "0" ]; then
        exit 0
    fi
    sleep ${i}
done
