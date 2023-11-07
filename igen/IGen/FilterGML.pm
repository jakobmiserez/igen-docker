# ===================================================================
# IGen::FilterGML
#
# (c) 2005, Networking team
#           Computing Science and Engineering Dept.
#           Université catholique de Louvain
#           Belgium
#
# author Bruno Quoitin (bqu@info.ucl.ac.be)
# date 23/08/2005
# lastdate 26/08/2005
# ===================================================================

package IGen::FilterGML;

require Exporter;
@ISA= qw(Exporter IGen::FilterBase);

use strict;
use IGen::FilterBase;
use IGen::Util;

# -----[ _init ]-----------------------------------------------------
#
# -------------------------------------------------------------------
sub _init()
{
    my ($self)= @_;

    $self->SUPER::_init();
    $self->set_capabilities(IGen::FilterBase::EXPORT_SINGLE |
			    IGen::FilterBase::IMPORT_SINGLE);
}

# -----[ import_graph ]----------------------------------------------
#
# -------------------------------------------------------------------
sub import_graph($$)
{
    my ($self, $filename)= @_;

    # ---[ parsing states ]---
    use constant GML_NULL => 0;
    use constant GML_GRAPH => 1;
    use constant GML_NODE => 2;
    use constant GML_GFX => 3;
    use constant GML_CENTER => 4;
    use constant GML_EDGE => 5;

    my $graph= new Graph::Undirected;
    $graph->set_attribute(UCL::Graph::ATTR_GFX, 1);
    my %vertices= ();
    my %node_names= ();

    if (!open(GML, "<$filename")) {
	$self->set_error("unable to open \"$filename\": $!");
	return -1;
    }

    my $state= GML_NULL;
    my @states_stack;
    my %node= ();
    my %edge= ();
    my %locations= ();
    my %edges= ();
    my %redirect= ();
    while (<GML>) {
	chomp;
	(m/\#/) and next;
	if (m/^\s*\]\s*$/) {
	    if ($state == GML_NODE) {
		if (exists($locations{"$node{x}:$node{y}"})) {
		    print STDERR "Warning: a node already exists at the same location $node{x},$node{y} (redirected)";
		    $redirect{$node{id}}= $locations{"$node{x}:$node{y}"};
		} else {
		    if (!exists($vertices{$node{id}})) {
			$graph->add_vertex($node{id});
			$graph->set_attribute(UCL::Graph::ATTR_COORD,
					      $node{id},
					      [$node{x},
					       $node{y}]);
			if (exists($node{name})) {
			    $graph->set_attribute(UCL::Graph::ATTR_NAME,
						  $node{id},
						  $node{name});
			}
			$vertices{$node{id}}= 1;
			$locations{"$node{x}:$node{y}"}= $node{id};
		    } else {
			print STDERR "Warning: weird vertex $node{id} (skipped)\n";
		    }
		}
	    } elsif ($state == GML_EDGE) {

		my $u= $edge{source};
		my $v= $edge{target};

		if (exists($redirect{$u})) {
		    $u= $redirect{$u};
		}
		if (exists($redirect{$v})) {
		    $v= $redirect{$v};
		}

		if (exists($edges{$u}{$v}) ||
		    exists($edges{$v}{$u})) {
		    print STDERR "Warning: duplicate link $u-$v (skipped)\n";
		} elsif ($u == $v) {
		    print STDERR "Warning: weird link $edge{source}-$edge{target} (skipped)\n";
		} else {
		    $graph->add_edge($u, $v);
		    $edges{$u}{$v}= 1;
		    if (exists($edge{metric})) {
			$graph->set_attribute(UCL::Graph::ATTR_WEIGHT,
					      $u, $v, $edge{metric});
		    }
		    if (exists($edge{bandwidth})) {
			my $capacity= text2capacity($edge{bandwidth});
			if (!defined($capacity)) {
			    $self->set_error("invalid capacity \"$edge{bandwidth}\"");
			    close(GML);
			    return undef;
			}
			$graph->set_attribute(UCL::Graph::ATTR_CAPACITY,
					      $u, $v, $capacity);
		    }
		}
	    }
	    (@states_stack == 0) and die;
	    $state= pop(@states_stack);
	} elsif ($state == GML_NULL) {
	    if (m/^\s*graph\s+\[\s*$/) {
		push @states_stack, ($state);
		$state= GML_GRAPH;
	    } else {
		die;
	    }
	} elsif ($state == GML_GRAPH) {
	    if (m/^\s*node\s+\[\s*$/) {
		push @states_stack, ($state);
		$state= GML_NODE;
		%node= ();
	    } elsif (m/^\s*edge\s+\[\s*/) {
		push @states_stack, ($state);
		$state= GML_EDGE;
		%edge= ();
	    } else {
		die "unknown GML_GRAPH attribute [$_]";
	    }
	} elsif ($state == GML_NODE) {
	    if (m/^\s*id\s+([0-9]+)\s*$/) {
		$node{id}= $1;
	    } elsif (m/^\s*type\s+([0-9]+)\s*$/) {
	    } elsif (m/^\s*name\s+\"?([^\"]*)\"?\s*$/) {
		$node{name}= $1;
	    } elsif (m/^\s*graphics\s+\[\s*/) {
		push @states_stack, ($state);
		$state= GML_GFX;
	    } else {
		die "unknown GML_NODE attribute [$_]";
	    }
	} elsif ($state == GML_GFX) {
	    if (m/^\s*center\s+\[\s*/) {
		push @states_stack, ($state);
		$state= GML_CENTER;
	    } else {
		die "unknown GML_GFX attribute [$_]";
	    }
	} elsif ($state == GML_CENTER) {
	    if (m/^\s*x\s+([-0-9.]+)\s*/) {
		$node{x}= $1;
		if (($node{x} > 180) || ($node{x} < -180)) {
		    $self->set_error("invalid X coordinate ($node{x})");
		    close(GML);
		    return undef;
		}
	    } elsif (m/^\s*y\s+([-0-9.]+)\s*/) {
		$node{y}= $1;
		if (($node{y} > 90) || ($node{y} < -90)) {
		    $self->set_error("invalid Y coordinate ($node{y})");
		    close(GML);
		    return undef;
		}
	    } else {
		die "unknown GML_CENTER attribute [$_]";
	    }
	} elsif ($state == GML_EDGE) {
	    if (m/^\s*([a-z]+)\s+([0-9a-zA-Z.]+)\s*$/) {
		$edge{$1}= $2;
	    } else {
		die "unknown GML_EDGE attribute [$_]";
	    }
	} else {
	    die;
	}
    }
    close(GML);

    $self->set_error();
    return $graph;
}

# -----[ export_graph ]----------------------------------------------
#
# -------------------------------------------------------------------
sub export_graph($$$)
{
    my ($self, $graph, $filename)= @_;

    if (!open(GML, ">$filename")) {
	$self->set_error("unable to create file \"$filename\": $!");
	return -1;
    }

    print GML "graph [\n";
    # Export vertices
    foreach my $v ($graph->vertices()) {
	print GML "\tnode [\n";
	print GML "\t\tid $v\n";
	if ($graph->has_attribute(UCL::Graph::ATTR_NAME, $v)) {
	    my $name= $graph->get_attribute(UCL::Graph::ATTR_NAME, $v);
	    print GML "\t\tname \"$name\"\n";
	}
	if ($graph->has_attribute(UCL::Graph::ATTR_COORD, $v)) {
	    my $coord= $graph->get_attribute(UCL::Graph::ATTR_COORD, $v);
	    print GML "\t\tgraphics [\n";
	    print GML "\t\t\tcenter [\n";
	    print GML "\t\t\t\tx ".$coord->[0]."\n";
	    print GML "\t\t\t\ty ".$coord->[1]."\n";
	    print GML "\t\t\t]\n";
	    print GML "\t\t]\n";
	}
	print GML "\t]\n";
    }
    # Export edges
    my @edges= $graph->edges();
    for (my $i= 0; $i < @edges/2; $i++) {
	my $u= $edges[$i*2];
	my $v= $edges[$i*2+1];
	print GML "\tedge [\n";
	print GML "\t\tsimplex 1\n";
	print GML "\t\tsource $u\n";
	print GML "\t\ttarget $v\n";
	if ($graph->has_attribute(UCL::Graph::ATTR_CAPACITY, $u, $v)) {
	    my $capacity= $graph->get_attribute(UCL::Graph::ATTR_CAPACITY, $u, $v);
	    print GML "\t\tbandwidth $capacity\n";
	}
	if ($graph->has_attribute(UCL::Graph::ATTR_WEIGHT, $u, $v)) {
	    my $weight= $graph->get_attribute(UCL::Graph::ATTR_WEIGHT, $u, $v);
	    print GML "\t\tmetric $weight\n";
	}
	print GML "\t]\n";
    }
    print GML "]\n";
    close(GML);

    $self->set_error();
    return 0;
}
