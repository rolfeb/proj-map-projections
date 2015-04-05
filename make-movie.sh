#!/bin/sh
#
# Simple shell script to generate 360 frames of reprojected data, at 1 degree
# steps. We then use ffmpeg to combine the frames into an mpeg movie.
#

n=0
lat=35
for lon in `seq 180 -1 -180`
do
    echo "Frame $n..."
    file=`printf 'frame%03d.png' $n`

    ./orthographic-reproject.pl $lat $lon > $file

    let n=$n+1
done

rm -f ortho.mpg

ffmpeg -r 25 -i frame%3d.png -vb 20M ortho.mpg

rm -f frame*.png
