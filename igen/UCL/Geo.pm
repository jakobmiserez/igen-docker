# ===================================================================
# @(#)GEO.pm
#
# @author Bruno Quoitin (bqu@info.ucl.ac.be)
# @date 04/06/2004
# @lastdate 14/06/2004
# ===================================================================

package GEO;

require Exporter;
@ISA= qw(Exporter);
@EXPORT= qw(distance distance2);
$VERSION= '0.1';

use strict;
use IO::Handle;
use POSIX;

# -----[ constants ]-----
use constant PI => atan2(1,1)*4;
use constant EARTH_RADIUS => 6367;  # in kilometers

# -----[ geo_distance ]----------------------------------------------
# Computes the distance between two geographical locations given their
# coordinates (longitude and latitude). Haversine formula from
# R. W. Sinnott, "Virtues of the Haversine," Sky and Telescope,
# vol. 68, no. 2, 1984, p. 159
#
# Note: http://www.census.gov/cgi-bin/geo/gisfaq?Q5.1 gives some
# insightful comments on the computation problems that may arise when
# using the Haversine formula. For instance, rounding can cause the
# argument of 'asin' to be greater than 1, causing asin to crash. This
# is why there is a bulletproofing provided by 'min' in the subroutine
# below.
# -------------------------------------------------------------------
sub distance($$$$)
{
    my ($a_lat, $a_long, $b_lat, $b_long)= @_;

    $a_lat*= PI/180;
    $a_long*= PI/180;
    $b_lat*= PI/180;
    $b_long*= PI/180;

    my $R= EARTH_RADIUS;

    my $dlon= $b_long-$a_long;
    my $dlat= $b_lat-$a_lat;
    my $a= (sin($dlat/2)) ** 2 
	+ cos($a_lat)*cos($b_lat) * (sin($dlon/2)) ** 2;
    my $alpha;
    if (1 < sqrt($a)) {
	$alpha= 2 * POSIX::asin(1);
    } else {
	$alpha= 2 * POSIX::asin(sqrt($a));
    }
    
    return $R*$alpha;
}
