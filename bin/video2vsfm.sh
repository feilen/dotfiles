#!/bin/bash
MP4FILE="$1"
BASENAME="$(basename -s .mp4 "${MP4FILE}")"
MP4PATH="$(dirname "${MP4FILE}")"

if [[ -e "${MP4PATH}/sfm-${BASENAME}" ]]; then
    echo "Skipping reconstruction of $MP4FILE"
    exit
fi
~/batchsfm.sh "$MP4FILE"
visualsfm-mardy.visualsfm sfm+pmvs "${MP4PATH}/sfm-${BASENAME}" "${MP4PATH}/sfm-${BASENAME}/output.nvm"
