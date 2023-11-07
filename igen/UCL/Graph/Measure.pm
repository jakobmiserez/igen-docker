# ===================================================================
# UCL::Graph::Measure.pm
#
# (c) 2005, Networking team
#           Computing Science and Engineeding Dept.
#           Université catholique de Louvain
#           Belgium
#
# author Bruno Quoitin
# date 07/06/2005
# lastdate 07/06/2005
# ===================================================================

package UCL::Graph::Measure;

require Exporter;
@ISA= qw(Exporter);
@EXPORT_OK= qw(degrees
	       min_cut
	       total_weight
	       );

use strict;
use Graph::Undirected;

use constant GRAPH_ATTR_WEIGHT   => 'weight';

# -----[ UCL::Graph::Measure::degrees ]------------------------------
#
# -------------------------------------------------------------------
sub degrees($)
{
    my ($graph)= @_;

    my @node_degrees;
    foreach my $vertex ($graph->vertices) {
	my $node_degree= scalar($graph->neighbors($vertex));
	push @node_degrees, ($node_degree);
    }
    
    return \@node_degrees;
}

# -----[ min_cut_phase ]---------------------------------------------
# Min-Cut algorithm by M. Stoer and F. Wagner (1997)
# Utility function.
# -------------------------------------------------------------------
sub min_cut_phase($)
{
    my ($graph)= @_;

    my @V= $graph->vertices;
    my @A= () ;
    my %A_visited= ();
    my %labels= ();

    # Initialize labels to 0: label(v) represents the number of
    # adjacences between v and A.
    foreach my $vertex (@V) {
	$labels{$vertex}= 0;
    }

    # Compute maximum adjacency search (breadth-first-search)
    while (@V > 0) {

	# Extract first item: O(1) ~ depend on Perl
	my $vertex= shift @V;
	push @A, ($vertex);
	$A_visited{$vertex}= 1;

	# Increase adjacency of neighbors. Hypothesis: undirected
	# graph. Use $graph->successors() instead if graph is
	# directed.
	foreach my $neighbor ($graph->neighbors($vertex)) {
	    if (!exists($A_visited{$neighbor})) {
		my $weight= $graph->get_attribute(GRAPH_ATTR_WEIGHT,
						  $vertex, $neighbor);
		$labels{$neighbor}+= $weight;
	    }
	}

	# Sort based on label: O(log(n)) ~ depend on Perl
	@V= sort {$labels{$b} <=> $labels{$a}} @V;

    }

#    print "cut-of-phase: ".(join ',', @A)."\n";
#    print "cut-of-phase: ";
#    foreach my $i (@A) {
#	print "$labels{$i},";
#    }
#    print "\n";
    my $vertex_n= pop @A;
    my $vertex_n_1= pop @A;
    my $cut_of_phase= $labels{$vertex_n};
#    print "cut-of-phase: $cut_of_phase ($vertex_n_1, $vertex_n)\n";
    
    # Merge last added vertices
    foreach my $neighbor ($graph->neighbors($vertex_n)) {
	next if ($neighbor == $vertex_n_1);
	my $weight= $graph->get_attribute(GRAPH_ATTR_WEIGHT,
					  $neighbor, $vertex_n);
	if (!$graph->has_edge($vertex_n_1, $neighbor)) {
	    $graph->add_edge($vertex_n_1, $neighbor);
	    $graph->set_attribute(GRAPH_ATTR_WEIGHT,
				  $vertex_n_1, $neighbor, $weight);
	} else {
	    $weight+= $graph->get_attribute(GRAPH_ATTR_WEIGHT,
					    $vertex_n_1, $neighbor);
	    $graph->set_attribute(GRAPH_ATTR_WEIGHT,
				  $vertex_n_1, $neighbor, $weight);
	}
    }
    $graph->delete_vertex($vertex_n);
    return $cut_of_phase;
}

# -----[ UCL::Graph::Measure::min_cut ]------------------------------
# Min-Cut algorithm by M. Stoer and F. Wagner (1997)
# Simple, non max-flow based, deterministic, running in O(|E||V|).
# -------------------------------------------------------------------
sub min_cut($)
{
    my ($graph)= @_;

    my $graph_copy= $graph->copy();

    my $min_cut= undef;

    # Initialize weights to 1
    my @edges= $graph_copy->edges;
    for (my $index= 0; $index < @edges/2; $index++) {
	my $vertex_i= $edges[$index*2];
	my $vertex_j= $edges[$index*2+1];
	$graph_copy->set_attribute(GRAPH_ATTR_WEIGHT,
				   $vertex_i, $vertex_j, 1);
    }

    # Compute minimum cut-of-phase
    while (scalar($graph_copy->vertices) > 1) {
	my $cut_of_phase= min_cut_phase($graph_copy);
	if (!defined($min_cut) || ($min_cut > $cut_of_phase)) {
	    $min_cut= $cut_of_phase;
	}
    }

    return $min_cut;
}

# -----[ UCL::Graph::Measure::total_weight ]-------------------------
#
# -------------------------------------------------------------------
sub total_weight($;$)
{
    my ($graph, $attr)= @_;

    my $total_weight= 0;
    my @edges= $graph->edges();
    for (my $index= 0; $index < scalar(@edges)/2; $index++) {
	my $u= $edges[$index*2];
	my $v= $edges[$index*2+1];
	my $w;
	if (defined($attr)) {
	    $w= $graph->get_attribute($attr, $u, $v);
	} else {
	    $w= UCL::Graph::Base::distance($graph, $u, $v);
	}
	$total_weight+= $w;
    }

    return $total_weight;
}
