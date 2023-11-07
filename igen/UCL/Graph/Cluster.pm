# ===================================================================
# UCL::Graph::Cluster.pm
#
# (c) 2005, Networking team
#           Computing Science and Engineeding Dept.
#           Université catholique de Louvain
#           Belgium
#
# author Bruno Quoitin
# date 30/06/2005
# lastdate 07/09/2005
# ===================================================================

package UCL::Graph::Cluster;

require Exporter;
@ISA= qw(Exporter UCL::Graph);
@EXPORT_OK= qw(grid
	       kmedoids
	       threshold
	       );

use strict;
use UCL::Graph;
use UCL::Graph::Base;

use constant KMEDOIDS  => 0;
use constant WARD      => 1;
use constant THRESHOLD => 2;
use constant GRID      => 3;

# -----[ kmedoids_init_random ]--------------------------------------
# Internal function used to initialize the clusters of the K-medoids
# algorithm. Randomly determine initial unique clusters centers.
#
# Arguments:
#   - graph
#   - reference to array of vertices
#   - K, number of clusters
#
# Pre:
#   K >= |V|
#   i.e. number of clusters must be less or equal to number of vertices
#
# Post:
#   the k cluster centers are removed from the initial set of vertices
#   => |V'| = |V|-K
# -------------------------------------------------------------------
sub kmedoids_init_random($$$)
{
    my ($graph, $vertices, $K)= @_;
    my @centroids= ();

    for (my $index= 0; $index < $K; $index++) {
	my $vertex_index= int(rand(@$vertices));
	my $vertex= $vertices->[$vertex_index];
	splice @$vertices, $vertex_index, 1;
	my $vertex_coord=
	    $graph->get_attribute(UCL::Graph::ATTR_COORD(),
				  $vertex);
	$centroids[$index]=
	    [$vertex, {$vertex}, $vertex_coord];
    }
    
    return @centroids;
}

# -----[ kmedoids_init_farthest ]------------------------------------
# Internal function used to initialize the clusters of the K-medoids
# algorithm. Determine initial unique clusters centers by adding the
# vertex that is the farthest from all current clusters.
#
# Arguments:
#   - graph
#   - reference to array of vertices
#   - K, number of clusters
#
# Pre:
#   K >= |V|
#   i.e. number of clusters must be less or equal to number of vertices
#
# Post:
#   the k cluster centers are removed from the initial set of vertices
#   => |V'| = |V|-K
# -------------------------------------------------------------------
sub kmedoids_init_farthest($$$)
{
    my ($graph, $vertices, $K)= @_;
    my @centroids= ();

    # (1) pick first cluster randomly
    my $vertex_index= int(rand(@$vertices));
    my $vertex= $vertices->[$vertex_index];
    splice @$vertices, $vertex_index, 1;
    my $vertex_coord=
	$graph->get_attribute(UCL::Graph::ATTR_COORD(),
			       $vertex);
    $centroids[0]= [$vertex, {$vertex}, $vertex_coord];

    # (2) select vertex that is most distant from existing clusters
    for (my $index= 1; $index < $K; $index++) {
	my $best_dist= undef;
	my $best_vertex_index;
	VERTEX: for (my $j= 0; $j < @$vertices; $j++) {
	    my $vertex= $vertices->[$j];
	    my $min_dist= undef;
	    foreach my $centroid (@centroids) {
		my $dist= UCL::Graph::Base::distance($graph, $vertex, $centroid->[0]);
		if (defined($best_dist) && ($dist < $best_dist)) {
		    next VERTEX;
		}
		if (!defined($min_dist) || ($dist < $min_dist)) {
		    $min_dist= $dist;
		}
	    }
	    if (!defined($best_dist) || ($min_dist > $best_dist)) {
		$best_dist= $min_dist;
		$best_vertex_index= $j;
	    }
	}
	(defined($best_dist)) or die;
	my $best_vertex= $vertices->[$best_vertex_index];
	splice @$vertices, $best_vertex_index, 1;
	my $best_vertex_coord=
	    $graph->get_attribute(UCL::Graph::ATTR_COORD(), $best_vertex);
	$centroids[$index]= [$best_vertex, {$best_vertex}, $best_vertex_coord];
    }

    return @centroids;
}

# -----[ UCL::Graph::Cluster::kmedoids ]-----------------------------
# K-medoids clustering algorithm for 2D points. The distance metric is
# the euclidian distance.
#
# Parameters:
# - graph to be clustered with each vertex having the ATTR_COORD
#   attribute set
# - the number of clusters required, K
#
# Returns:
#   clusters ::= list of [centroid, vertices[hash], coord]
# -------------------------------------------------------------------
sub kmedoids($$)
{
    my ($graph, $K)= @_;
    my @vertices= $graph->vertices();

    my @centroids;
    my %clusters;

    if ($K > scalar(@vertices)) {
	$K= scalar(@vertices);
    }

    #@centroids= kmedoids_init_random($graph, \@vertices, $K);
    @centroids= kmedoids_init_farthest($graph, \@vertices, $K);

    # Affect points to clusters
    foreach my $vertex (@vertices) {
	my $best_dist;
	my $best_cluster;
	for (my $index= 0; $index < $K; $index++) {
	    my $vertex_coord= $graph->get_attribute(UCL::Graph::ATTR_COORD(), $vertex);
	    my $dist= UCL::Graph::Base::pt_distance($vertex_coord,
						    $centroids[$index]->[2]);
	    if (!defined($best_dist) || ($dist < $best_dist)) {
		$best_dist= $dist;
		$best_cluster= $index;
	    }
	}
	$centroids[$best_cluster]->[1]->{$vertex}= 1;
	$clusters{$vertex}= $best_cluster;
    }

    # Loop until no changes are required
    my $modified= 1;
    while ($modified) {
	
	$modified= 0;

	# Determine the centroid of each cluster
	for (my $index= 0; $index < $K; $index++) {
	    my $total_points;
	    my @center= (0, 0);
	    foreach my $vertex (keys %{$centroids[$index]->[1]}) {
		my $coord= $graph->get_attribute(UCL::Graph::ATTR_COORD(),
						 $vertex);
		$center[0]+= $coord->[0];
		$center[1]+= $coord->[1];
		$total_points++;
	    }
	    $center[0]/= $total_points;
	    $center[1]/= $total_points;
	    my $best_dist;
	    foreach my $vertex (keys %{$centroids[$index]->[1]}) {
		my $coord= $graph->get_attribute(UCL::Graph::ATTR_COORD(),
						 $vertex);
		my $dist= UCL::Graph::Base::pt_distance($coord, \@center);
		if (!defined($best_dist) || ($dist < $best_dist)) {
		    $centroids[$index]->[0]= $vertex;
		    $centroids[$index]->[2]= $coord;
		    $best_dist= $dist;
		}
	    }
	}

	# Affect points to clusters
	foreach my $vertex ($graph->vertices) {
	    my $best_dist;
	    my $best_cluster;
	    for (my $index= 0; $index < $K; $index++) {
		my $dist= UCL::Graph::Base::pt_distance($graph->get_attribute(UCL::Graph::ATTR_COORD(), $vertex),
					     $centroids[$index]->[2]);
		if (!defined($best_dist) || ($dist < $best_dist)) {
		    $best_dist= $dist;
		    $best_cluster= $index;
		}
	    }
	    if ($clusters{$vertex} != $best_cluster) {
		undef $centroids[$clusters{$vertex}]->[1]->{$vertex};
		delete $centroids[$clusters{$vertex}]->[1]->{$vertex};
		$modified= 1;
		$centroids[$best_cluster]->[1]->{$vertex}= 1;
		$clusters{$vertex}= $best_cluster;
	    }
	}

    }

    return \@centroids;
}

# -----[ UCL::Graph::Cluster::threshold ]----------------------------
#
# -------------------------------------------------------------------
sub threshold($$$)
{
    my ($graph, $W, $R)= @_;

    if (!$graph->has_attribute(UCL::Graph::ATTR_TM())) {
	print STDERR "Error: no traffic matrix for this graph";
	return undef;
    }
    my $TM= $graph->get_attribute(UCL::Graph::ATTR_TM());

    print "Weight: $W\n";
    print "Radius: $R\n";

    my @backbone_vertices= ();
    my @vertices= $graph->vertices();
    my %weights= ();

    # compute weight for each vertex
    my $max_weight= undef;
    foreach my $u (@vertices) {
	my $weight= 0;
	foreach my $v (@vertices) {
	    ($u == $v) and next;
	    $weight+= $TM->{$u}{$v} + $TM->{$u}{$v};
	}
	if (!defined($max_weight) || ($weight > $max_weight)) {
	    $max_weight= $weight;
	}
	$weights{$u}= $weight;
    }

    # Routers with a normalized weight above $W are moved into the
    # backbone
    my $i= 0;
    while ($i < @vertices) {
	my $u= $vertices[$i];
	$weights{$u}/= $max_weight;
	#print "weight($u): $weights{$u}\n";
	if ($weights{$u} >= $W) {
	    push @backbone_vertices, ($u);
	    splice @vertices, $i, 1;
	} else {
	    $i++;
	}
    }
    
    # Build clusters
    my @centroids= ();
    foreach my $u (@backbone_vertices) {
	push @centroids, ([$u, {$u}, ]);
    }

    # Put non-backbone nodes that are at a distance less than $R from
    # a backbone node
    my $i= 0;
    while ($i < @vertices) {
	my $u= $vertices[$i];
	#print "access: $u\n";
	my $best_dist= undef;
	my $best_centroid;
	foreach my $centroid (@centroids) {
	    my $v= $centroid->[0];
	    my $dist= UCL::Graph::Base::distance($graph, $u, $v);
	    #print "\tdist($u,$v): $dist\n";
	    ($dist > $R) and next;
	    if (!defined($best_dist) || ($dist < $best_dist)) {
		$best_dist= $dist;
		$best_centroid= $centroid;
	    }
	}
	if (defined($best_dist)) {
	    $best_centroid->[1]->{$u}= 1;
	    splice @vertices, $i, 1;
	} else {
	    $i++;
	}
    }

    # Compute merit for remaining vertices
    

    return \@centroids;
}

# -----[ UCL::Graph::Cluster::grid ]---------------------------------
# Arguments:
#   nx   : number of subdivisions of x-axis
#   ny   : number of subdivisions of y-axis
#   maxD : maximum diameter of cluster
# -------------------------------------------------------------------
sub grid($$$)
{
    my ($graph, $nx, $ny, $maxD)= @_;
    my @clusters= ();
    my %squares= ();

    my $nx= 180/$nx;
    my $ny= 180/$ny;

    my @vertices= $graph->vertices();
    foreach my $u (@vertices) {
	my $coord= $graph->get_attribute(UCL::Graph::ATTR_COORD(),
					 $u);
	my ($x, $y);
	if ($coord->[0] >= 0) {
	    $x= (int($coord->[0] / $nx)+0.5)*$nx;
	} else {
	    $x= (-int(-$coord->[0] / $nx)-0.5)*$nx;
	}
	if ($coord->[1] >= 0) {
	    $y= (int($coord->[1] / $ny)+0.5)*$ny;
	} else {
	    $y= (-int(-$coord->[1] / $ny)-0.5)*$ny;
	}
	if (!exists($squares{$x}{$y})) {
	    $squares{$x}{$y}= ();
	}
	print "(".(join ',', @$coord),") -~-> ($x,$y)\n";
	$squares{$x}{$y}{$u}= 1;
    }

    # Convert squares to clusters
    foreach my $x (keys %squares) {
	foreach my $y (keys %{$squares{$x}}) {
	    my @square_vertices= keys %{$squares{$x}{$y}};
	    my @square_cluster= ("$x:$y", $squares{$x}{$y}, undef);
	    push @clusters, (\@square_cluster);
	}
    }

    return \@clusters;
}
