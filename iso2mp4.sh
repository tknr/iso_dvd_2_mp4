#!/bin/bash -x

export IFS=$'\n'

DATE=`date +%Y_%m_%d`
argv=("$@")
CMDNAME=`basename $0`

if [ $# -eq 0 ]; then
    echo "Usage : ${CMDNAME} [filename]"
    exit 1
fi

filename=$1
abspath=$(cd $(dirname $1) && pwd)/$(basename $1)
filename_noext="${filename&&.iso}"
MOUNT_DIR="/media/iso"

mkdir -p $MOUNT_DIR || exit 1

mount -o loop,ro ${abspath} $MOUNT_DIR || exit 1

featureNumber=$(dvdbackup -I -i "$MOUNT_DIR" 2> /dev/null | grep 'Title set containing the main feature is' | sed 's/[^0-9]//g'  )
featurePadded=$(printf "%02d" $featureNumber)
files=$(find "$MOUNT_DIR/VIDEO_TS/" | grep $(echo "VTS_"$featurePadded"_[1-9].VOB") | sort | tr '\n' '|' | sed 's/|$//g' )

ffmpeg -i "concat:$files" -y -acodec aac -strict -2 -aq 100 -ac 2 -async 1 -vf "scale=480:-1" -vcodec libx264 -crf 24 -threads 0 ./"$filename_noext".mp4 || exit 1
umount $MOUNT_DIR