#!/bin/sh
MP4FILE="$1"
BASENAME="$(basename -s .mp4 "${MP4FILE}")"
MP4PATH="$(readlink -f "$(dirname "${MP4FILE}")")"

mkdir "${MP4PATH}/sfm-${BASENAME}"
cd "${MP4PATH}/sfm-${BASENAME}"
ffmpeg -i "${MP4PATH}/${BASENAME}.mp4" -q:v 2 -vf fps=8 output%04d.jpg
exiftool -FocalLength=4.2mm -FocalLengthIn35mmFormat=25mm *.jpg
