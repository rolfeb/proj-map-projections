#!/usr/bin/env perl
#
# Take an image in equirectangular projection and reproject it into
# Orthographic projection from the given lat/long position (note that this
# point is on the opposite side of the earth).
# The output is written in PNG output to stdout.
#
use strict;
use warnings;

use Geo::Proj4;
use GD;
use List::Util qw(min max);

my ($lat_0, $lon_0) = @ARGV;

GD::Image->trueColor(1);

#
# Open the original image. This image is in Equirectangular projection,
# which is a very simple projection that just scales the (long, lat) values
# to (x, y) [pixel] coordinates.
#
# (source: http://commons.wikimedia.org/wiki/File:WorldMap-A_non-Frame.png)
#
my $src = GD::Image->new("WorldMap-A_non-Frame.png");

my $src_width = $src->width;
my $src_height = $src->height;

#
# Define the destination projection.  This is an Orthographic projection
# with an origin at the given (lat, lon) position.
#
my $dst_proj = Geo::Proj4->new(
    proj => "ortho",
    ellps => "sphere",
    lat_0 => $lat_0,
    lon_0 => $lon_0,
)
    or die "$0: failed to create dst projection: $!\n";

my $min_lon = -180;
my $max_lon = 180;
my $min_lat = -90;
my $max_lat = 90;

=begin comment
"""
#
# Work out the new image's bounding box in the reprojected coordinate system.
# This is just an approximation.  We also add a 5% border around the image
#
my $min_x = undef;
my $min_y = undef;
my $max_x = undef;
my $max_y = undef;

#
# There's often no simple way to find the bounding box of a map in
# projected coordinates, so we just project a grid of points and keeep
# track of the min/max values.
#
for (my $lat = $min_lat; $lat <= $max_lat; $lat += 10)
{
    for (my $lon = $min_lon; $lon <= $max_lon; $lon += 10)
    {
        my ($x, $y) = $dst_proj->forward($lat, $lon);

        $min_x = min($min_x, $x);
        $min_y = min($min_y, $y);
        $max_x = max($max_x, $x);
        $max_y = max($max_y, $y);
    }
}

$min_x -= ($max_x - $min_x) * 0.025;
$max_x += ($max_x - $min_x) * 0.025;
$min_y -= ($max_y - $min_y) * 0.025;
$max_y += ($max_y - $min_y) * 0.025;

print STDERR "$min_x, $min_y, $max_x, $max_y\n";
=end comment
=cut

#
# Because I'm generating a sequence of images, I did this once and
# am using it for each frame.
#
my $min_x = -6689546;
my $max_x = 6697510;
my $min_y = -6689546;
my $max_y = 6697510;

#
# Create a new image, set the pixels to black.
#
my ($dst_width, $dst_height) = (500, 500);

my $dst = new GD::Image->newTrueColor($dst_width, $dst_height);

for (my $r = 0; $r < $dst_height; $r++)
{
    for (my $c = 0; $c < $dst_width; $c++)
    {
        $dst->setPixel($c, $r, $dst->colorResolve(0, 0, 0));
    }
}

#
# Map each pixel in the destination image to a pixel in the source image
#
my $x_scale = 1 / ($dst_width - 1) * ($max_x - $min_x);
my $y_scale = 1 / ($dst_height - 1) * ($max_y - $min_y);

my $src_c_scale = 1 / ($max_lon - $min_lon) * ($src_width - 1);
my $src_r_scale = 1 / ($max_lat - $min_lat) * ($src_height - 1);

# for each row...
for (my $dst_r = 0; $dst_r < $dst_height; $dst_r++)
{
    # for each column...
    for (my $dst_c = 0; $dst_c < $dst_width; $dst_c++)
    {
        # convert pixel (col, row) to dst PCS coordinate
        my $x = $dst_c * $x_scale + $min_x;
        my $y = $dst_r * $y_scale + $min_y;

        # invert the projection to convert to GCS coordinate
        my ($lat, $lon) = $dst_proj->inverse($x, $y);

        # ignore if out of bounds
        defined $lat and defined $lon or next;

        # convert the GCS coordinate to src pixel (col', row')
        my $src_c = int(($lon - $min_lon) * $src_c_scale + 0.5);
        my $src_r = int(($lat - $min_lat) * $src_r_scale + 0.5);

        # ignore if out of bounds
        defined $src_c and defined $src_r or next;
        $src_c >= 0 and $src_c < $src_width or next;
        $src_r >= 0 and $src_r < $src_height or next;

        # look up the colour value and set in the destination pixel
        my ($r, $g, $b) = $src->rgb($src->getPixel($src_c, $src_r));
        $dst->setPixel($dst_c, $dst_r, $dst->colorResolve($r, $g, $b));
    }
}

#
# Write the image to stdout
#
binmode STDOUT;
print $dst->png();

exit 0;
