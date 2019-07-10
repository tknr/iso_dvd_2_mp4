#!/bin/bash -x
if [ $(whoami) != "root" ]; then
        echo "This script must be run as root"
        exit 1
fi

export IFS=$'\n'

DATE=`date +%Y_%m_%d`
argv=("$@")
CMDNAME=`basename $0`

if [ $# -eq 0 ]; then
    echo "Usage : ${CMDNAME} [filename]"
    exit 1
fi

filename=$(basename $1)
abspath=$(cd $(dirname $1) && pwd)/${filename}

MOUNT_DIR="/media/iso"

mkdir -p $MOUNT_DIR || exit 1

mount -o loop,ro ${abspath} $MOUNT_DIR || exit 1

featureNumber=$(dvdbackup -I -i "$MOUNT_DIR" 2> /dev/null | grep 'Title set containing the main feature is' | sed 's/[^0-9]//g'  )
featurePadded=$(printf "%02d" $featureNumber)
files=$(find "$MOUNT_DIR/VIDEO_TS/" | grep $(echo "VTS_"$featurePadded"_[1-9].VOB") | sort | tr '\n' '|' | sed 's/|$//g' )

ffmpeg -i "concat:$files" -y -movflags +faststart -codec:v libx264 -preset:v placebo -acodec aac -b:a 256k "${filename%%.ISO}.mp4"

umount $MOUNT_DIR
