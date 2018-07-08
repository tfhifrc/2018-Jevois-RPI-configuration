#!/bin/sh
#set -x

VIDEO_DIR=/home/pi/team_videos
#VIDEO_DIR=/opt/vc/src/hello_pi/hello_video/
#VIDEO_LIST=/opt/vc/src/hello_pi/hello_video/test.h264

found=1
while [ $found -eq 1 ]
do
    found=0
    for i in $(ls ${VIDEO_DIR}/*.m*)
    do
        if [ -e ${i} ]; then
            found=1
            omxplayer  --vol -6000 ${i}
            sleep 5
        fi
    done

    sleep 10
done
