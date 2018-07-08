#!/bin/sh

MJPG_STREAMER_BIN="/usr/local/bin/mjpg_streamer"
export LD_LIBRARY_PATH="$(dirname $MJPG_STREAMER_BIN):."

${MJPG_STREAMER_BIN} -o "output_http.so -p 5800 -w /apache2/www" -i "input_uvc.so -n -d /dev/video0"

