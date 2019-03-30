#!/bin/bash

# Configuration variables START
MOUNT_DIR="/media/iso"
# Configuration variables END

echo
echo "#===============================================#"
echo "| Conversion of DVD ISO to mp4                  |"
echo "#===============================================#"
echo

# ================================================
# output help information
# ================================================
output_help()
{
  echo
  echo "-------------------------------------------------"
  echo
  echo "USE:   $(basename $0) <ISO FILE>"
  echo
  echo "ISO FILE:  An existing ISO file whos feature film will be extracted to mp4"
  echo
}

# ================================================
# check if file was supplied
# ================================================
if [ -z "$1" ]
then
  echo "ERROR: Please supply file as 1st parameter."
  output_help
  exit 1;
fi

# ================================================
# check if we have regular file
# ================================================
if [ ! -f "$1" ]
then
  echo "ERROR: The supplied file is not a regular file."
  output_help
  exit 1;
fi

# ================================================
# check if we have read access to file
# ================================================
if [ ! -r "$1" ]
then
  echo "ERROR: The supplied file is read protected."
  output_help
  exit 1;
fi

# ================================================
# check if  the mount directory exists
# ================================================
if [ ! -d "$MOUNT_DIR" ]
then
  echo "ERROR: Configuration directory MOUNT_DIR=$MOUNT_DIR does not exist."
  output_help
  exit 1;
fi

# ================================================
# collect information
# ================================================
filename_full=$(echo `cd \`dirname "$1"\`; pwd`/`basename "$1"`)
filename_nopath=$(echo `basename "$1"`)
filename_noext=${filename_nopath%.*}

# ================================================
# check for mounted iso
# ================================================
if mount | grep $MOUNT_DIR > /dev/null; then
  echo " - Unmounting volume $MOUNT_DIR"
  umount $MOUNT_DIR
fi

# ================================================
# mount iso
# ================================================
echo " - Mounting $filename_nopath on $MOUNT_DIR" 
mount "$filename_full" "$MOUNT_DIR" -t udf  -o loop
# mount "$filename_full" "$MOUNT_DIR"  -t iso9660 -o loop

# ================================================
# create backup
# ================================================
# dvdbackup -i "$MOUNT_DIR" -F -o "$BACKUP_DIR" -n "$BACKUP_NAME"

# ================================================
# list all the files
# ================================================
featureNumber=$(dvdbackup -I -i "$MOUNT_DIR" 2> /dev/null | grep 'Title set containing the main feature is' | sed 's/[^0-9]//g'  )
featurePadded=$(printf "%02d" $featureNumber)
files=$(find "$MOUNT_DIR/VIDEO_TS/" | grep $(echo "VTS_"$featurePadded"_[1-9].VOB") | sort | tr '\n' '|' | sed 's/|$//g' )

# ================================================
# find the default video and audio streams
# ================================================
videoMap=$(ffmpeg -i "$MOUNT_DIR/VIDEO_TS/VTS_"$featurePadded"_1.VOB" 2>&1 | grep "\[0x1e0\]: Video" | sed 's/\[.*$//g' | sed 's/[^0-9\.]//g')
audioMap=$(ffmpeg -i "$MOUNT_DIR/VIDEO_TS/VTS_"$featurePadded"_1.VOB" 2>&1 | grep "\[0x80\]: Audio" | sed 's/\[.*$//g' | sed 's/[^0-9\.]//g')

# ================================================
# lets encode
# ================================================
ffmpeg -i "concat:$files" -y -map "$videoMap" -map "$audioMap" -acodec libfaac -ar 44100 -aq 70 -async 1 -ac 2 -vf "scale=480:-1" -vcodec libx264 -pass 1/2 -vpre veryslow -crf 25 -threads 0 ./"$filename_noext"'_part'.mp4

# ================================================
# clean up the log files
# ================================================
rm x264*
rm ffmpeg*

# ================================================
# set permissions on the file
# ================================================
chown someuser:someuser ./"$filename_noext"'_part'.mp4
chmod 744 ./"$filename_noext"'_part'.mp4
mv ./"$filename_noext"'_part'.mp4 ./"$filename_noext".mp4
