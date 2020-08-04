#!/bin/bash
MP4FILE="$1"
BASENAME="$(basename -s .mp4 -s .mkv -s webm -s .MOV "${MP4FILE}")"
FILENAME="$(basename "${MP4FILE}")"
MP4PATH="$(readlink -f "$(dirname "${MP4FILE}")")"
FILEEXT=${FILENAME##*.}

mkdir "${MP4PATH}/brutesfm-${BASENAME}"
cd "${MP4PATH}/brutesfm-${BASENAME}"
ffmpeg -i "$MP4FILE" -acodec copy -f segment -vcodec copy -reset_timestamps 1 -map 0 "${BASENAME}%d.${FILEEXT}"

find -not -type d -exec video2vsfm.sh '{}' \;
