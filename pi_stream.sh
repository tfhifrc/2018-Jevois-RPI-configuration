#!/bin/sh

mjpg_streamer -o "output_http.so -p 9000 -w /home/pi/www" -i "input_uvc.so -n -d /dev/video0"

