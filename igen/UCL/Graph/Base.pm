# ===================================================================
# UCL::Graph::Base.pm
#
# (c) 2005, Networking team
#           Computing Science and Engineeding Dept.
#           Université catholique de Louvain
#           Belgium
#
# author Bruno Quoitin
# date 07/06/2005
# lastdate 07/09/2005
# ===================================================================

package UCL::Graph::Base;

require Exporter;
@ISA= qw(Exporter UCL::Graph);
@EXPORT_OK= qw(copy_vertex_attributes
	       distance
	       get_options_ref
	       pt_distance
	       distance
	       path_length
	       distance2delay
	       bounds
	       );

use strict;
use Graph::Undirected;
use UCL::Graph;

use constant DISTANCE_EUCLIDIAN => 0;
use constant DISTANCE_TERRESTRIAL => 1;

use constant PI => atan2(1,1)*4;
use constant EARTH_RADIUS => 6367;  # in kilometers

use constant LIGHT_SPEED => 300; # km/ms

my $options;

sub BEGIN {
    $options->{distance}= DISTANCE_TERRESTRIAL;
    return 1;
}

sub get_options_ref()
{
    return $options;
}

# -----[ UCL::Graph::Base::copy_vertex_attributes ]------------------
# Copy the vertices/edges attributes from the src graph into the
# existing vertices/edges of the dst graph. The dst graph must be a
# subgraph of the src graph.
#
# Parameters:
# - dst graph
# - src graph
# -------------------------------------------------------------------
sub copy_vertex_attributes($$)
{
    my ($dst_graph, $src_graph)= @_;

    foreach my $vertex_i ($dst_graph->vertices) {
	my %attributes= $src_graph->get_attributes($vertex_i);
	foreach my $attr (keys %attributes) {
	    $dst_graph->set_attribute($attr, $vertex_i,
				      $attributes{$attr});
	}
    }
}

# -----[ euclidian_distance ]----------------------------------------
# Return the euclidian distance between two nodes A and B.
#
# Parameters:
# - point A
# - point B
# -------------------------------------------------------------------
sub euclidian_distance($$)
{
    my ($A, $B)= @_;

    return sqrt(($A->[0]-$B->[0])**2+($A->[1]-$B->[1])**2);
}

# -----[ earth_distance ]--------------------------------------------
#
# -------------------------------------------------------------------
sub earth_distance($$)
{
    my ($coord_a, $coord_b)= @_;

    my $a_lat= $coord_a->[1]*PI/180;
    my $a_long= $coord_a->[0]*PI/180;
    my $b_lat= $coord_b->[1]*PI/180;
    my $b_long= $coord_b->[0]*PI/180;

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

# -----[ UCL::Graph::Base::pt_distance ]-----------------------------
#
# -------------------------------------------------------------------
sub pt_distance($$)
{
    my ($coord_i, $coord_j)= @_;

    if ($options->{distance} == DISTANCE_TERRESTRIAL) {
	return earth_distance($coord_i, $coord_j);
    } elsif ($options->{distance} == DISTANCE_EUCLIDIAN) {
	return euclidian_distance($coord_i, $coord_j);
    } else {
	die "Error: unsupported distance function";
    }
}

# -----[ UCL::Graph::Base::distance ]--------------------------------
#
# -------------------------------------------------------------------
sub distance($$$)
{
    my ($graph, $vertex_i, $vertex_j)= @_;

    my $coord_i= $graph->get_attribute(UCL::Graph::ATTR_COORD(), $vertex_i);
    my $coord_j= $graph->get_attribute(UCL::Graph::ATTR_COORD(), $vertex_j);

    if (defined($coord_i) && defined($coord_j)) {
	return pt_distance($coord_i, $coord_j);
    }

    return undef;
}

# -----[ path_length ]-----------------------------------------------
#
# -------------------------------------------------------------------
sub path_length($$)
{
    my ($graph, $path)= @_;
    my ($hop_cnt, $length, $weight)= (0, 0, undef);

    if (scalar(@$path) > 1) {
	for (my $i= 1; $i < @$path; $i++) {
	    my $u= $path->[$i-1];
	    my $v= $path->[$i];
	    $length+= distance($graph, $u, $v);
	    $hop_cnt++;
	    if ($graph->has_attribute(UCL::Graph::ATTR_WEIGHT(), $u, $v)) {
		my $w= $graph->get_attribute(UCL::Graph::ATTR_WEIGHT(),
					     $u, $v);
		if (!defined($weight)) {
		    $weight= $w;
		} else {
		    $weight+= $w;
		}
	    }
	}
    }
    return ($hop_cnt, $length, $weight);
}

# -----[ distance2delay ]--------------------------------------------
# Convert a distance in kilometers (km) to a delay in milliseconds
# (ms).
# -------------------------------------------------------------------
sub distance2delay($)
{
    my ($distance)= @_;
    return $distance/(LIGHT_SPEED);
}

# -----[ bounds ]----------------------------------------------------
# Compute the geographical extent of the graph, i.e. the
# minimum/maximum latitude and longitude.
#
# Return value:
# - array of coordinates (min-x, min-y, max-x, max-y)
#   OR
# - undef if one node has no coordinates
# -------------------------------------------------------------------
sub bounds($)
{
    my ($graph)= @_;

    my ($min_x, $min_y, $max_x, $max_y);

    foreach my $vertex ($graph->vertices) {
	if (!$graph->has_attribute(UCL::Graph::ATTR_COORD(), $vertex)) {
	    return undef;
	}
	my $coord= $graph->get_attribute(UCL::Graph::ATTR_COORD(), $vertex);
	if (!defined($min_x) || ($coord->[0] < $min_x)) {
	    $min_x= $coord->[0];
	}
	if (!defined($max_x) || ($coord->[0] > $max_x)) {
	    $max_x= $coord->[0];
	}
	if (!defined($min_y) || ($coord->[1] < $min_y)) {
	    $min_y= $coord->[1];
	}
	if (!defined($max_y) || ($coord->[1] > $max_y)) {
	    $max_y= $coord->[1];
	}
    }
    
    return ($min_x, $min_y, $max_x, $max_y);
}
