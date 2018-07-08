#!/bin/sh

for i in 0 1 2
do
    /home/pi/mjpg-streamer.sh status ${i}
done
