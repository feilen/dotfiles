#!/bin/bash
MP4FILE="$1"
BASENAME="$(basename -s .webm -s .mp4 -s .mkv -s .MOV "${MP4FILE}")"
MP4PATH="$(dirname "${MP4FILE}")"

if [[ -e "${MP4PATH}/sfm-${BASENAME}" ]]; then
    echo "Skipping reconstruction of $MP4FILE"
    exit
fi
batchsfm.sh "$MP4FILE"
# Perform a maximum of ~1000 matches, on frames spaced ~117ms apart
# visualsfm-mardy.visualsfm sfm+pairs+merge+pmvs "${MP4PATH}/sfm-${BASENAME}" "${MP4PATH}/sfm-${BASENAME}/output.nvm" @32,7 sleep 1
# Perform a maximum of ~1000 matches, on frames spaced ~117ms apart
visualsfm-mardy.visualsfm sfm+pairs+merge+pmvs "${MP4PATH}/sfm-${BASENAME}" "${MP4PATH}/sfm-${BASENAME}/output.nvm" @11,7 sleep 1
cd "${MP4PATH}/sfm-${BASENAME}"
if [[ -e "output.0.ply" ]]; then
    #visualsfm-mardy.visualsfm output.nvm &
    ~/scratch/meshlab/distrib/meshlabserver -p output.nvm -i output.0.ply -w poisson.mlp -s /home/feilen/.local/dotfiles/poisson.mlx
    ~/scratch/meshlab/distrib/meshlabserver -p poisson.mlp -w textured.mlp -s /home/feilen/.local/dotfiles/texture.mlx
    ~/scratch/meshlab/distrib/meshlab textured.mlp &
fi
