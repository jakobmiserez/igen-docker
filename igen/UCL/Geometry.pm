# ===================================================================
# Geometry.pm
#
# author Bruno Quoitin (bqu@info.ucl.ac.be)
# date 22/06/2004
# lastdate 26/06/2004
# ===================================================================
# List of functions:
#   pt_is_left
#   pt_in_triangle
#   pt_in_circle
#   poly_convex
#   poly_has_vertex
# ===================================================================

package Geometry;

require Exporter;
@ISA= qw(Exporter);
@EXPORT= qw(
	    pt_is_left
	    pt_in_triangle
	    pt_in_circle
	    tri_colinear
	    poly_convex
	    poly_has_vertex
	    );
$VERSION= '0.1';

use strict;

1;

# -----[ pt_is_left ]------------------------------------------------
# Test if the point P is at the left side of the infinite line that
# pass through the points A and B. The function returns a positibe
# number if P is at the left side of AB, a negative number if P is at
# the right side of AB and 0 if A, B and P are colinear.
#
# Paramaters:
# - A, B endpoints of the AB segment
# - P point
# -------------------------------------------------------------------
sub pt_is_left($$$)
{
    my ($A, $B, $P)= @_;

    return ($B->[0]-$A->[0])*($P->[1]-$A->[1]) -
	($B->[1]-$A->[1])*($P->[0]-$A->[0]);
}

# -----[ pt_in_triangle ]--------------------------------------------
# Test if the point P is inside the triangle ABC
#
# Parameters:
# - A, B, C vertices of the ABC triangle
# - 
# -------------------------------------------------------------------
sub pt_in_triangle($$$$)
{
    my ($A, $B, $C, $P)= @_;

    if ((pt_is_left($A, $B, $C) * pt_is_left($A, $B, $P) >= 0) &&
	(pt_is_left($B, $C, $A) * pt_is_left($B, $C, $P) >= 0) &&
	(pt_is_left($C, $A, $B) * pt_is_left($C, $A, $P) >= 0)) {
	return 1;
    }
    return 0;
}

# -----[ pt_in_circle ]----------------------------------------------
# Test if the given point lies in the circle formed by (a,b,c). Points
# must not be colinear. Returns > 0 if P is inside the circle, < 0 if
# P is outside the circle and = 0 if points are cocircular.
#
# Parameters:
# - (A, B, C) non colinear, in counterclockwise order
# - point P
# -------------------------------------------------------------------
sub pt_in_circle($$$$)
{
    my $A= shift;
    my $B= shift;
    my $C= shift;
    my $P= shift;

    my $apx= $A->[0]-$P->[0];
    my $apy= $A->[1]-$P->[1];
    my $bpx= $B->[0]-$P->[0];
    my $bpy= $B->[1]-$P->[1];
    my $cpx= $C->[0]-$P->[0];
    my $cpy= $C->[1]-$P->[1];

    my $abdet= $apx*$bpy - $bpx*$apy;
    my $bcdet= $bpx*$cpy - $cpx*$bpy;
    my $cadet= $cpx*$apy - $apx*$cpy;
    my $alift= $apx*$apx + $apy*$apy;
    my $blift= $bpx*$bpx + $bpy*$bpy;
    my $clift= $cpx*$cpx + $cpy*$cpy;

    return $alift*$bcdet + $blift*$cadet + $clift*$abdet;
}

# -----[ tri_colinear ]----------------------------------------------
#
# -------------------------------------------------------------------
sub tri_colinear($$$)
{
    my ($pi, $pj, $pk)= @_;

    return pt_is_left($pi, $pj, $pk) == 0;
}

# -----[ poly_has_vertex ]-------------------------------------------
# Test if the point P is a vertex of the given polygon
#
# Parameters:
# - polygon
# - point P
# -------------------------------------------------------------------
sub poly_has_vertex($$)
{
    my $poly= shift;
    my $P= shift;

    foreach my $pt (@$poly) {
	if ($pt == $P) {
	    return 1;
	}
    }
    return 0;
}

# -----[ poly_convex ]-----------------------------------------------
# Test if the given polygon is convex.
#
# Parameters:
# - array of vertices
# -------------------------------------------------------------------
sub poly_convex($)
{
    my $poly_r= shift;

    # Number of vertices
    my $n_vert= scalar(@$poly_r);

    # A polygon with less than 4 vertices is always convex
    if ($n_vert < 4) {
	return 1;
    }
    
    # Compute the cross product of all pairs of subsequent edges
    my $sign= undef;
    for (my $i= 0; $i < $n_vert; $i++) {

	# Compute the cross-product of vector [i,i+1] and vector [i,i+2]
	my $local_sign= pt_is_left($poly_r->[$i % $n_vert],
				   $poly_r->[($i+1) % $n_vert],
				   $poly_r->[($i+2) % $n_vert]);

	if ($sign == undef) {

	    # Update current sign
	    $sign= $local_sign;

	} else {

	    # If the sign is different, that means that the polygon is
	    # not convex
	    if ($sign*$local_sign < 0) {
		return 0;
	    }

	}
    }
    return 1;

}

# -----[ poly_clockwise ]--------------------------------------------
#
# -------------------------------------------------------------------
sub poly_clockwise($)
{
    my $poly_r= shift;

    my $n_vert= scalar(@$poly_r);

    
}
