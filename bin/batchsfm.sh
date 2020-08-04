#!/bin/sh
MP4FILE="$1"
BASENAME="$(basename -s .webm -s .mp4 -s .mkv -s .MOV "${MP4FILE}")"
FILENAME="$(basename "${MP4FILE}")"
MP4PATH="$(readlink -f "$(dirname "${MP4FILE}")")"

mkdir "${MP4PATH}/sfm-${BASENAME}"
cd "${MP4PATH}/sfm-${BASENAME}"
ffmpeg -i "${MP4PATH}/${FILENAME}" -q:v 1 -vf fps=15 output%04d.jpg
#ffmpeg -i "${MP4PATH}/${FILENAME}" -q:v 1 output%04d.jpg
# Normal
exiftool -FocalLength=4.2mm -FocalLengthIn35mmFormat=25mm *.jpg
# Wide
# exiftool -FocalLength=2.18mm -FocalLengthIn35mmFormat=16mm *.jpg
