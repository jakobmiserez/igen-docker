# ===================================================================
# UCL::Graph::Generate.pm
#
# (c) 2005, Networking team
#           Computing Science and Engineeding Dept.
#           Université catholique de Louvain
#           Belgium
#
# author Bruno Quoitin
# date 07/06/2005
# lastdate 18/08/2005
# ===================================================================

package UCL::Graph::Generate;

require Exporter;
@ISA= qw(Exporter);
@EXPORT_OK= qw(clique
	       harary
	       node_linking
	       );

use strict;
use Graph::Undirected;

use constant GRAPH_ATTR_WEIGHT   => 'weight';

# -----[ graph_copy_vertex_attributes ]------------------------------
# Copy the vertices/edges attributes from the src graph into the
# existing vertices/edges of the dst graph. The dst graph must be a
# subgraph of the src graph.
#
# Parameters:
# - dst graph
# - src graph
# -------------------------------------------------------------------
sub graph_copy_vertex_attributes($$)
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

# -----[ UCL::Graph::Generate::clique ]------------------------------
# Build a new graph that is fully connected.
#
# If the optional second argument is <true>, IGP weights based on the
# distance between vertices are assigned to links.
# -------------------------------------------------------------------
sub clique($;$)
{
    my ($graph, $define_weight)= @_;

    my $clique= new Graph::Undirected();

    # Copy vertices
    foreach my $i ($graph->vertices) {
	$clique->add_vertex($i);
	foreach my $attr ($graph->get_attributes($i)) {
	    my $value= $graph->get_attribute($attr, $i);
	    $clique->set_attribute($attr, $i, $value);
	}
    }

    # Create edges
    my @vertices= $clique->vertices();
    for (my $i= 0; $i < @vertices-1; $i++) {
	my $u= $vertices[$i];
	for (my $j= $i+1; $j < @vertices; $j++) {
	    my $v= $vertices[$j];
	    if (!$clique->has_edge($u, $v)) {
		$clique->add_edge($u, $v);
		if (defined($define_weight) && $define_weight) {
		    $clique->set_attribute(GRAPH_ATTR_WEIGHT, $u, $v,
					   UCL::Graph::Base::distance($clique, $u, $v));
		}
	    }
	}
    }

    return $clique;
}

# -----[ harary ]----------------------------------------------------
# Build an n-vertex, k-connected graph
# (see "Graph Theory and its Applications",
#      J. Gross and J. Yellen,
#      CRC Press)
# -------------------------------------------------------------------
sub harary($$)
{
    my ($graph, $k)= @_;

    my @vertices= $graph->vertices();
    my $n= scalar(@vertices);
    return undef if ($k > $n);

    my $harary= new Graph::Undirected;
    graph_copy_vertex_attributes($harary, $graph);

    my $r= int($k/2);
    # Build H(2r,n)
    for (my $i= 0; $i < $n-1; $i++) {
	for (my $j= $i+1; $j < $n; $j++) {
	    if (($j-$i <= $r) || ($n+$i-$j <= $r)) {
		$harary->add_edge($vertices[$i], $vertices[$j]);
	    }
	}
    }
    
    # Completes if K is odd
    if ($k % 2 != 0) {
	if ($n % 2 == 0) {
	    for (my $i= 0; $i < $n/2; $i++) {
		$harary->add_edge($vertices[$i], $vertices[$i+$n/2]);
	    }
	} else {
	    $harary->add_edge($vertices[0], $vertices[($n-1)/2]);
	    $harary->add_edge($vertices[0], $vertices[($n+1)/2]);
	    for (my $i= 1; $i <= ($n-3)/2; $i++) {
		$harary->add_edge($i, $i+($n+1)/2);
	    }
	}
    }

    return $harary;
}

# -----[ node_linking ]----------------------------------------------
# Randomly build a connected graph
# -------------------------------------------------------------------
sub node_linking($)
{
    my ($graph)= @_;
    
    my $nl= new Graph::Undirected;
    graph_copy_vertex_attributes($nl, $graph);

    my @vertices= $graph->vertices();

    my $vertex_index= rand(@vertices);

    while (defined($vertex_index)) {

	my $vertex= $vertices[$vertex_index];
	splice @vertices, $vertex_index, 1;

	my $best_dist= undef;
	my $best_index;
	for (my $index= 0; $index < @vertices; $index++) {
	    my $neighbor= $vertices[$index];

	    next if ($nl->has_edge($vertex, $neighbor));

	    my $dist= UCL::Graph::Base::distance($graph, $vertex, $neighbor);
	    if (!defined($best_dist) || ($best_dist > $dist)) {
		$best_dist= $dist;
		$best_index= $index;
	    }
	}

	if (defined($best_index)) {
	    $nl->add_edge($vertex, $vertices[$best_index]);
	}
	$vertex_index= $best_index;
	
    }

    return $nl;
}

