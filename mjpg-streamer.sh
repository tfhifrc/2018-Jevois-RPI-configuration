#!/bin/bash
# chmod +x mjpg-streamer.sh
#
# $1 must be one of ( start | stop | status | restart )
#
# $2 determines what /dev/videoX device is used. The X must match the argument specified or the camera will not be found.
#    - $2 also determines /home/pi/www_X for the WWW output directory to use
#    - $2 also determines 580X HTTP port where the stream will be available.
#

ID=${2}  # Used 

MJPG_STREAMER_BIN="/usr/local/bin/mjpg_streamer" 
export LD_LIBRARY_PATH="$(dirname $MJPG_STREAMER_BIN):."

MJPG_STREAMER_WWW="/home/pi/www_${ID}"
MJPG_STREAMER_LOG_FILE="${0%.*}_${ID}.log"  # "$(dirname $0)/mjpg-streamer.log"
RUNNING_CHECK_INTERVAL="4" # how often to check to make sure the server is running (in seconds)
HANGING_CHECK_INTERVAL="8" # how often to check to make sure the server is not hanging (in seconds)

VIDEO_DEV="/dev/video${ID}"
FRAME_RATE="-f 15"
QUALITY="-q 80"
RESOLUTION="-r 320x240"  
PORT="580${ID}"
YUV="no"

###############
INPUT_OPTIONS=" -d ${VIDEO_DEV} ${RESOLUTION} ${QUALITY} ${FRAME_RATE} -pl 60hz"  


if [ "${YUV}" == "true" ]; then
	INPUT_OPTIONS+=" -y"
fi


###############
OUTPUT_OPTIONS="-p ${PORT} -w ${MJPG_STREAMER_WWW}"

# ==========================================================
function print_debug_data() {
    echo "========================" >> ${MJPG_STREAMER_LOG_FILE} 2>&1
    echo "Debug timestamp: $(date)" >> ${MJPG_STREAMER_LOG_FILE} 2>&1
    ls -l ${VIDEO_DEV} >> ${MJPG_STREAMER_LOG_FILE} 2>&1
    echo "Check Target Video Device ${VIDEO_DEV}..." >> ${MJPG_STREAMER_LOG_FILE} 2>&1
    ls -l ${VIDEO_DEV} >> ${MJPG_STREAMER_LOG_FILE} 2>&1
    echo "Check All Video devices...:" >> ${MJPG_STREAMER_LOG_FILE} 2>&1
    ls -l /dev/video* >> ${MJPG_STREAMER_LOG_FILE} 2>&1
    echo "Check USB by invoking lsusb..." >> ${MJPG_STREAMER_LOG_FILE} 2>&1
    lsusb >> ${MJPG_STREAMER_LOG_FILE} 2>&1
    echo "Check video devices with v4l2-ctl --list-formats-ext" >> ${MJPG_STREAMER_LOG_FILE} 2>&1
    /usr/bin/v4l2-ctl --list-formats-ext >> ${MJPG_STREAMER_LOG_FILE} 2>&1
    echo "Current working directory: $(pwd)" >> ${MJPG_STREAMER_LOG_FILE} 2>&1
    echo "" >> ${MJPG_STREAMER_LOG_FILE} 2>&1
}

function running() {
    if ps aux | grep ${MJPG_STREAMER_BIN} | grep ${VIDEO_DEV} >/dev/null 2>&1; then
        return 0
    else
        msg="Check if running...Not running"
        echo ${msg} 2>&1 | tee -a ${MJPG_STREAMER_LOG_FILE}
        return 1
    fi
}

function start() {

    if running; then
        msg="Already streaming on device: [${VIDEO_DEV}]."
        echo ${msg} 2>&1 | tee -a ${MJPG_STREAMER_LOG_FILE}
        print_debug_data
        msg="Exiting for device: ${VIDEO_DEV}]..."
        echo ${msg} 2>&1 | tee -a ${MJPG_STREAMER_LOG_FILE}
        return 1
    fi

    if [ ! -e ${VIDEO_DEV} ]; then
        msg="Missing video device file: [${VIDEO_DEV}]."
        echo ${msg} 2>&1 | tee -a ${MJPG_STREAMER_LOG_FILE}
        print_debug_data
        msg="Exiting for device: ${VIDEO_DEV}]..."
        echo ${msg} 2>&1 | tee -a ${MJPG_STREAMER_LOG_FILE}
        return 1
    fi
   
    command="${MJPG_STREAMER_BIN} -i \"input_uvc.so ${INPUT_OPTIONS}\" -o \"output_http.so ${OUTPUT_OPTIONS}\""
    echo ${command}; echo ${command} >> ${MJPG_STREAMER_LOG_FILE}
    
    print_debug_data
    eval ${command} >> ${MJPG_STREAMER_LOG_FILE} 2>&1 & 
    print_debug_data

    if running; then
        if [ "$1" != "nocheck" ]; then
            check_running & > /dev/null 2>&1 # start the running checking task
            check_hanging & > /dev/null 2>&1 # start the hanging checking task
        fi

        msg="Successfully started streaming on [${VIDEO_DEV}]"
        echo "[${VIDEO_DEV}] started" >> ${MJPG_STREAMER_LOG_FILE} 2>&1
        return 0

    else
        msg="Failed to start streaming on device: [${VIDEO_DEV}]."
        echo ${msg} 2>&1 | tee -a ${MJPG_STREAMER_LOG_FILE}
        print_debug_data
        return 1
    fi
}

function stop() {
    if ! running; then
        msg="Called stop but not streaming on device: [${VIDEO_DEV}]"
        echo ${msg} 2>&1 | tee -a ${MJPG_STREAMER_LOG_FILE}
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

    msg="Stopped streamin on device: [${VIDEO_DEV}]"
    echo ${msg} 2>&1 | tee -a ${MJPG_STREAMER_LOG_FILE}
    return 0
}

function check_running() {
    echo "Check streaming on device: [${VIDEO_DEV}]. Starting running check task..." >> ${MJPG_STREAMER_LOG_FILE} 2>&1

    while true; do
        sleep ${RUNNING_CHECK_INTERVAL}

        if ! running; then
            debug
            echo "Streaming stopped on device: [${VIDEO_DEV}]." >> ${MJPG_STREAMER_LOG_FILE} 2>&1
            debug
            echo "Start streaming on device: [${VIDEO_DEV}]..." >> ${MJPG_STREAMER_LOG_FILE} 2>&1
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
            echo "Streaming hung on device: [${VIDEO_DEV}]." >> ${MJPG_STREAMER_LOG_FILE} 2>&1
            debug
            echo "Invoke stop device: [${VIDEO_DEV}]..." >> ${MJPG_STREAMER_LOG_FILE} 2>&1
            stop nocheck
        fi
    done
}

function help() {
    msg="Usage: $0 [start|stop|restart|status]"
    echo ${msg} 2>&1 | tee -a ${MJPG_STREAMER_LOG_FILE}
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
        msg="Running: [${VIDEO_DEV}]"
        echo ${msg} 2>&1 | tee -a ${MJPG_STREAMER_LOG_FILE}
        exit 0
    else
        msg="Stopped: [${VIDEO_DEV}]"
        echo ${msg} 2>&1 | tee -a ${MJPG_STREAMER_LOG_FILE}
        exit 1
    fi
else
    help
fi
