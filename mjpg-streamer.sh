#!/bin/bash
# chmod +x mjpg-streamer.sh
# Crontab: @reboot /home/pi/mjpg-streamer/mjpg-streamer.sh start
# Crontab: @reboot /home/pi/mjpg-streamer/mjpg-streamer-experimental/mjpg-streamer.sh start


ID=${2}

MJPG_STREAMER_BIN="/usr/local/bin/mjpg_streamer"  # "$(dirname $0)/mjpg_streamer"
export LD_LIBRARY_PATH="$(dirname $MJPG_STREAMER_BIN):."

MJPG_STREAMER_WWW="/home/pi/www_${ID}"
MJPG_STREAMER_LOG_FILE="${0%.*}_${ID}.log"  # "$(dirname $0)/mjpg-streamer.log"
RUNNING_CHECK_INTERVAL="4" # how often to check to make sure the server is running (in seconds)
HANGING_CHECK_INTERVAL="8" # how often to check to make sure the server is not hanging (in seconds)

VIDEO_DEV="/dev/video${ID}"
FRAME_RATE="-f 15"
QUALITY="-q 80"
# 160x120 176x144 320x240 352x288 424x240 432x240 640x360 640x480 800x448 800x600 960x544 1280x720 1920x1080 (QVGA, VGA, SVGA, WXGA)   
#RESOLUTION="-r 1280x720"  
RESOLUTION="-r 320x240"  
#  lsusb -s 001:006 -v | egrep "Width|Height" 
# https://www.textfixer.com/tools/alphabetical-order.php  
# v4l2-ctl --list-formats-ext  
# Show Supported Video Formates
# Need sudo to start mjpg-streamer to use port 554.
PORT="580${ID}"
YUV="no"

###############
#INPUT_OPTIONS="-r ${RESOLUTION} -d ${VIDEO_DEV} -f ${FRAME_RATE} -q ${QUALITY} -pl 60hz"
#INPUT_OPTIONS="-r ${RESOLUTION} -d ${VIDEO_DEV} -q ${QUALITY} -pl 60hz"  # Limit Framerate with  "--every_frame ", ( mjpg_streamer --input "input_uvc.so --help" )

# Limit Framerate with  "--every_frame ", ( mjpg_streamer --input "input_uvc.so --help" )
#INPUT_OPTIONS="-d ${VIDEO_DEV} -q ${QUALITY} -pl 60hz"  
INPUT_OPTIONS=" -d ${VIDEO_DEV} ${RESOLUTION} ${QUALITY} ${FRAME_RATE} -pl 60hz"  

echo $(date) >> ${MJPG_STREAMER_LOG_FILE} 2>&1
ls -l /dev/video0 >> ${MJPG_STREAMER_LOG_FILE} 2>&1
lsusb >> ${MJPG_STREAMER_LOG_FILE} 2>&1
pwd >> ${MJPG_STREAMER_LOG_FILE} 2>&1

if [ "${YUV}" == "true" ]; then
	INPUT_OPTIONS+=" -y"
fi

OUTPUT_OPTIONS="-p ${PORT} -w ${MJPG_STREAMER_WWW}"

# ==========================================================
function running() {
    if ps aux | grep ${MJPG_STREAMER_BIN} | grep ${VIDEO_DEV} >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

function start() {
    if running; then
        msg="[${VIDEO_DEV}] already started, exiting..."
        echo ${msg}; echo ${msg} >> ${MJPG_STREAMER_LOG_FILE} 2>&1
        return 1
    fi

    if [ ! -e ${VIDEO_DEV} ]; then
        msg="[${VIDEO_DEV}] missing, exiting..."
        echo ${msg}; echo ${msg} >> ${MJPG_STREAMER_LOG_FILE} 2>&1
        return 1
    fi


    echo $(date) >> ${MJPG_STREAMER_LOG_FILE} 2>&1
    ls -l ${VIDEO_DEV} >> ${MJPG_STREAMER_LOG_FILE} 2>&1
    command="${MJPG_STREAMER_BIN} -i \"input_uvc.so ${INPUT_OPTIONS}\" -o \"output_http.so ${OUTPUT_OPTIONS}\""
    echo ${command}; echo ${command} >> ${MJPG_STREAMER_LOG_FILE}
    eval ${command} >> ${MJPG_STREAMER_LOG_FILE} 2>&1 & 
    #${MJPG_STREAMER_BIN} -i "input_uvc.so ${INPUT_OPTIONS}" -o "output_http.so ${OUTPUT_OPTIONS}"
    echo $(date) >> ${MJPG_STREAMER_LOG_FILE} 2>&1
    ls -l ${VIDEO_DEV} >> ${MJPG_STREAMER_LOG_FILE} 2>&1

    if running; then
        if [ "$1" != "nocheck" ]; then
            check_running & > /dev/null 2>&1 # start the running checking task
            check_hanging & > /dev/null 2>&1 # start the hanging checking task
        fi

        msg="[${VIDEO_DEV}] started"
        echo "[${VIDEO_DEV}] started" >> ${MJPG_STREAMER_LOG_FILE} 2>&1
        return 0

    else
        msg="[${VIDEO_DEV}] failed to start"
        echo ${msg}; echo ${msg} >> ${MJPG_STREAMER_LOG_FILE} 2>&1
        echo $(date) >> ${MJPG_STREAMER_LOG_FILE} 2>&1
        ls -l ${VIDEO_DEV} >> ${MJPG_STREAMER_LOG_FILE} 2>&1
        ${command} >> ${MJPG_STREAMER_LOG_FILE} 2>&1 &
        return 1
    fi
}

function stop() {
    if ! running; then
        msg="[${VIDEO_DEV}] not running"
        echo ${msg}; echo ${msg} >> ${MJPG_STREAMER_LOG_FILE} 2>&1
        return 1
    fi

    own_pid=$$

    if [ "$1" != "nocheck" ]; then
        # stop the script running check task
        ps aux | grep $0 | grep start | tr -s ' ' | cut -d ' ' -f 2 | grep -v ${own_pid} | xargs -r kill
        sleep 0.5
    fi

    # stop the server
    ps aux | grep ${MJPG_STREAMER_BIN} | grep ${VIDEO_DEV} | tr -s ' ' | cut -d ' ' -f 2 | grep -v ${own_pid} | xargs -r kill

    msg="[${VIDEO_DEV}] stopped"
    echo ${msg}; echo ${msg} >> ${MJPG_STREAMER_LOG_FILE} 2>&1
    return 0
}

function check_running() {
    echo "[${VIDEO_DEV}] starting running check task" >> ${MJPG_STREAMER_LOG_FILE} 2>&1

    while true; do
        sleep ${RUNNING_CHECK_INTERVAL}

        if ! running; then
            echo "[${VIDEO_DEV}] server stopped, starting" >> ${MJPG_STREAMER_LOG_FILE} 2>&1
            start nocheck
        fi
    done
}

function check_hanging() {
    echo "[${VIDEO_DEV}] starting hanging check task" >> ${MJPG_STREAMER_LOG_FILE} 2>&1

    while true; do
        sleep ${HANGING_CHECK_INTERVAL}

        # treat the "error grabbing frames" case
        if tail -n2 ${MJPG_STREAMER_LOG_FILE} | grep -i "error grabbing frames" > /dev/null; then
            echo "[${VIDEO_DEV}] server is hanging, killing" >> ${MJPG_STREAMER_LOG_FILE} 2>&1
            stop nocheck
        fi
    done
}

function help() {
    msg="Usage: $0 [start|stop|restart|status]"
    echo ${msg}; echo ${msg} >> ${MJPG_STREAMER_LOG_FILE} 2>&1
    return 0
}

if [ "$1" == "start" ]; then
    start && exit 0 || exit -1

elif [ "$1" == "stop" ]; then
    stop && exit 0 || exit -1

elif [ "$1" == "restart" ]; then
    stop && sleep 1
    start && exit 0 || exit -1

elif [ "$1" == "status" ]; then
    if running; then
        msg="[${VIDEO_DEV}] running"
        echo ${msg}; echo ${msg} >> ${MJPG_STREAMER_LOG_FILE} 2>&1
        exit 0
    else
        msg="[${VIDEO_DEV}] stopped"
        echo ${msg}; echo ${msg} >> ${MJPG_STREAMER_LOG_FILE} 2>&1
        exit 1
    fi
else
    help
fi
