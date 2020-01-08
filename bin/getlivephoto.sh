#!/bin/sh
INFILE="$1"
OUTFOLDER="Live Photos"

mkdir -p "$OUTFOLDER"
dd if="${INFILE}" bs=$(($(grep --byte-offset --binary --only-matching --text ftypmp42 "${INFILE}"|sed 's/:.*//g') - 4)) skip=1 of="${OUTFOLDER}"/"${INFILE}".mp4
