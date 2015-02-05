#!/bin/bash

FILE_BASE=$(sed 's/.glc//' <(echo $1) )

AUDIO_STREAM=1
AUDIO_CODEC=libmp3lame
AUDIO_BITRATE=256k

VIDEO_CODEC=libx264
VIDEO_QUALITY="-crf 22"
VIDEO_FLIP="-vf vflip"

glc-play $1 -a ${AUDIO_STREAM} -o ${FILE_BASE}.wav
glc-play $1 -o - -y 1 | ffmpeg -i ${FILE_BASE}.wav -i - \
	${VIDEO_FLIP} -vcodec ${VIDEO_CODEC} ${VIDEO_QUALITY} \
	-acodec ${AUDIO_CODEC} -ab ${AUDIO_BITRATE} -ac 2 \
	-threads 0 ${FILE_BASE}.mp4

rm ${FILE_BASE}.wav
