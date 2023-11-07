# ===================================================================
# IGen::FilterRIG
#
# (c) 2005, Networking team
#           Computing Science and Engineering Dept.
#           Université catholique de Louvain
#           Belgium
#
# author Bruno Quoitin (bqu@info.ucl.ac.be)
# date 24/08/2005
# lastdate 04/10/2005
# ===================================================================

package IGen::FilterRIG;

require Exporter;
@ISA= qw(Exporter IGen::FilterBase);

use strict;
use IGen::FilterBase;

# ---| Intradomain link type |---
use constant RIG_EDGE_TYPE_INTERNAL => 'I';
# ---| Interdomain link types |---
use constant RIG_EDGE_TYPE_PP => 'PP';
use constant RIG_EDGE_TYPE_CP => 'CP';
use constant RIG_EDGE_TYPE_PC => 'PC';

# -----[ _init ]-----------------------------------------------------
#
# -------------------------------------------------------------------
sub _init()
{
    my ($self)= @_;

    $self->SUPER::_init();
    $self->set_capabilities(IGen::FilterBase::IMPORT_MULTIPLE |
			    IGen::FilterBase::EXPORT_SINGLE |
			    IGen::FilterBase::EXPORT_MULTIPLE);
}

# -----[ import_graph ]----------------------------------------------
#
# -------------------------------------------------------------------
sub import_graph($$)
{
    my ($self, $filename)= @_;
    my %graphs= (
		 'as2graph' => {},
		 'igraph' => new Graph::Undirected(),
		 );
    my $num_vertices;
    my $num_edges;
    my $node_count= 0;
    my $edge_count= 0;
    my $cnt= 0;
    my $domains= undef;

    # ---| Open RIG file |---
    if (!open(RIG, "<$filename")) {
	$self->set_error("could not open \"$filename\": $!");
	return undef;
    }

    # ---| Read header |---
    while(<RIG>) {
	next if ((m/^\#/) || (m/^\s+$/));
	chomp;
	my @fields= split /\s+/;	
	if (scalar(@fields) != 2 ) {
	    $self->set_error("syntax error");
	    close(RIG);
	    return undef;
	}
	$num_vertices= $fields[0];
	$num_edges= $fields[1];
	last;
    }

    # ---| Read nodes |---
    my $cnt_vertices= 0;
    while (<RIG>) {
	next if ((m/^\#/) || (m/^\s+$/)) ;
	chomp;
	my @fields= split /\s+/;
	
	# Check that there are at least 4 fields
	# <node-id> <latitude> <longitude> <AS-number> [<name>]
	if (scalar(@fields) < 4) {
	    $self->set_error("wrong number of fields in vertice record");
	    close(RIG);
	    return undef;
	}
	my $node_id= $fields[0];
	my $latitude= $fields[1];
	my $longitude= $fields[2];
	my $as= $fields[3];
	
	# Check coordinates
	if (($latitude < -90) || ($latitude > 90) ||
	    ($longitude < -180) || ($longitude > 180)) {
	    $self->set_error("invalid coordinates ".
			     "(".(join " ", @fields).")");
	    return undef;
	}

	# Create domain if required
	if (!exists($graphs{as2graph}->{$as})) {
	    $graphs{as2graph}->{$as}= new Graph::Undirected();
	    $graphs{as2graph}->{$as}->set_attribute(UCL::Graph::ATTR_GFX, 1);
	    $graphs{as2graph}->{$as}->set_attribute(UCL::Graph::ATTR_AS, $as);
	}
	my $graph= $graphs{as2graph}->{$as};
	$graph->add_vertex($node_id);
	$graph->set_attribute(UCL::Graph::ATTR_COORD, $node_id,
			      [$longitude, $latitude]);
	
	$cnt_vertices++;
	($cnt_vertices >= $num_vertices) and last;
    }
    if ($num_vertices != $cnt_vertices) {
	$self->set_error("wrong number of vertices ".
			 "($cnt_vertices < $num_vertices)");
	return undef;
    }

    # ---| Read edges |---
    my $cnt_edges= 0;
    while (<RIG>) {
	next if ((m/^\#/) || (m/^\s+$/)) ;
	chomp;
	my @fields= split /\s+/;

	# Check that there are exactly 7 fields
	# <node-id> <node-id> <type> <bandwidth> <weight> <delay> <length>
	if (scalar(@fields) != 7) {
	    $self->set_error("wrong number of fields in edge record");
	    close(RIG);
	    return undef;
	}
	my $u_node_id= $fields[0];
	my $v_node_id= $fields[1];
	my ($u_as, $u_id)= split /\:/, $u_node_id;
	my ($v_as, $v_id)= split /\:/, $v_node_id;
	my $type= $fields[2];
	my $bandwidth= $fields[3];
	($bandwidth eq 'undef') and
	    $bandwidth= undef;
	my $weight= $fields[4];
	($weight eq 'undef') and
	    $weight= undef;
	my $delay= $fields[5]; # not used
	my $length= $fields[6]; # not used

	# Intradomain or interdomain edge ?
	my $graph;
	if ($type eq 'I') {
	    if ($u_as != $v_as) {
		$self->set_error("internal link with different ASes ".
				 "($u_as != $v_as)");
		close(RIG);
		return undef;
	    }
	    $graph= $graphs{as2graph}->{$u_as};
	    $graph->add_edge($u_id, $v_id);
	    (defined($bandwidth)) and
		$graph->set_attribute(UCL::Graph::ATTR_CAPACITY,
				      $u_id, $v_id, $bandwidth);
	    (defined($weight)) and
		$graph->set_attribute(UCL::Graph::ATTR_WEIGHT,
				      $u_id, $v_id, $weight);
	} else {
	    if ($u_as == $v_as) {
		$self->set_error("external link with single AS ($u_as)");
		close(RIG);
		return undef;
	    }
	    if (!exists($graphs{as2graph}->{$u_as}) ||
		!$graphs{as2graph}->{$u_as}->has_vertex($u_id)) {
		$self->set_error("unknown border router $u_as:$u_id");
		close(RIG);
		return undef;
	    }
	    if (!exists($graphs{as2graph}->{$v_as}) ||
		!$graphs{as2graph}->{$v_as}->has_vertex($v_id)) {
		$self->set_error("unknown border router $v_as:$v_id");
		close(RIG);
		return undef;
	    }
	    my $u_coord= $graphs{as2graph}->{$u_as}->get_attribute(UCL::Graph::ATTR_COORD, $u_id);
	    my $v_coord= $graphs{as2graph}->{$v_as}->get_attribute(UCL::Graph::ATTR_COORD, $v_id);
	    my $relation= undef;
	    if ($type eq 'PP') {
		$relation= 0;
	    } elsif ($type eq 'PC') {
		$relation= 1;
	    } elsif ($type eq 'CP') {
		$relation= -1;
	    }
	    $graph= $graphs{igraph};
	    $graph->add_vertex($u_node_id);
	    $graph->set_attribute(UCL::Graph::ATTR_COORD,
				  $u_node_id, $u_coord);
	    $graph->add_vertex($v_node_id);
	    $graph->set_attribute(UCL::Graph::ATTR_COORD,
				  $v_node_id, $v_coord);
	    $graph->add_edge($u_node_id, $v_node_id);
	    $graph->set_attribute(UCL::Graph::ATTR_RELATION,
				  $u_node_id, $v_node_id, $relation);
	    (defined($bandwidth)) and
		$graph->set_attribute(UCL::Graph::ATTR_CAPACITY,
				      $u_node_id, $v_node_id, $bandwidth);
	    (defined($weight)) and
		$graph->set_attribute(UCL::Graph::ATTR_WEIGHT,
				      $u_node_id, $v_node_id, $weight);
	}

	$cnt_edges++;
	($cnt_edges >= $num_edges) and last;
    }
    if ($num_edges != $cnt_edges) {
	$self->set_error("wrong number of edges ".
			 "($cnt_edges < $num_edges)");
	return undef;
    }

    close(RIG);

        
    $self->set_error();
    return \%graphs;
}

# -----[ export_graph ]----------------------------------------------
#
# -------------------------------------------------------------------
sub export_graph($$$)
{
    my ($self, $graphs, $filename)= @_;

    # ---| Single domain: convert to hash of domains |---
    if (ref($graphs) ne "HASH") {
	if (!$graphs->has_attribute(UCL::Graph::ATTR_AS)) {
	    $self->set_error("no domain-id");
	    return -1;
	}
	my $as_num= $graphs->get_attribute(UCL::Graph::ATTR_AS);
	$graphs= {
	    'as2graph' => {
		$as_num => $graphs
		},
		};
    }

    # ---| Preprocessing |---
    my $num_vertices= 0;
    my $num_edges= 0;
    foreach (values %{$graphs->{as2graph}}) {
	$num_vertices+= scalar($_->vertices());
	$num_edges+= scalar($_->edges());
    }
    if (exists($graphs->{igraph})) {
	$num_edges+= scalar($graphs->{igraph}->edges());
    }

    # ---| Create RIG file |---
    if (!open(RIG, ">$filename")) {
	$self->set_error("could not create \"$filename\": $!");
	return undef;
    }

    # ---| Write header |---
    print RIG "# Generated by IGen::FilterRIG\n";
    print RIG "# on ".localtime(time)."\n";
    print RIG "#\n";
    print RIG "# Header: <num-vertices> <num-edges>\n";
    print RIG "$num_vertices\t$num_edges\n";

    # ---| Write vertices |---
    print RIG "# Vertices: <node-id> <latitude> <longitude> <AS-number> [<name>]\n";
    foreach my $graph (values %{$graphs->{as2graph}}) {
	my $as= $graph->get_attribute(UCL::Graph::ATTR_AS);
	(!defined($as)) and die;
	foreach ($graph->vertices()) {
	    my $id= $_;
	    my $coord= $graph->get_attribute(UCL::Graph::ATTR_COORD, $_);
	    my $latitude= $coord->[1];
	    my $longitude= $coord->[0];
	    print RIG "$id\t$latitude\t$longitude\t$as";
	    if ($graph->has_attribute(UCL::Graph::ATTR_NAME, $_)) {
		my $name= $graph->get_attribute(UCL::Graph::ATTR_NAME, $_);
		print RIG "\t$name";
	    }
	    print RIG "\n";
	}
    }

    # ---| Write edges: intradomain first |---
    print RIG "# Edges: <node-id> <node-id> <type> <bandwidth> <weight> <delay> <length>\n";
    foreach my $graph (values %{$graphs->{as2graph}}) {
	my $as= $graph->get_attribute(UCL::Graph::ATTR_AS);
	(!defined($as)) and die;
	my @edges= $graph->edges();
	for (my $i= 0; $i < scalar(@edges)/2; $i++) {
	    my $u= $edges[$i*2];
	    my $v= $edges[$i*2+1];

	    my $u_node_id= "$as:$u";
	    my $v_node_id= "$as:$v";

	    my $bandwidth= 'undef';
	    ($graph->has_attribute(UCL::Graph::ATTR_CAPACITY, $u, $v)) and
		$bandwidth= $graph->get_attribute(UCL::Graph::ATTR_CAPACITY,
						  $u, $v);
	    my $length= UCL::Graph::Base::distance($graph, $u, $v);
	    my $delay= 'undef';
	    my $weight= 'undef';
	    ($graph->has_attribute(UCL::Graph::ATTR_WEIGHT, $u, $v)) and
		$weight= $graph->get_attribute(UCL::Graph::ATTR_WEIGHT,
					       $u, $v);

	    print RIG "$u_node_id\t$v_node_id\tI\t$bandwidth\t$weight\t$delay\t$length\n";
	}
    }    

    # ---| Then, interdomain edges |---
    if (exists($graphs->{igraph})) {
	my $graph= $graphs->{igraph};
	my @edges= $graph->edges();
	
	for (my $i= 0; $i < scalar(@edges)/2; $i++) {
	    my $u_id= $edges[$i*2];
	    my $v_id= $edges[$i*2+1];
	    my ($u_as, $u)= split /\:/, $u_id;
	    my ($v_as, $v)= split /\:/, $v_id;

	    my $bandwidth= 'undef';
	    ($graph->has_attribute(UCL::Graph::ATTR_CAPACITY,
				   $u_id, $v_id)) and
		$bandwidth= $graph->get_attribute(UCL::Graph::ATTR_CAPACITY,
						  $u, $v);
	    my $length= UCL::Graph::Base::distance($graph, $u_id, $v_id);
	    my $delay= 'undef';
	    my $weight= 'undef';
	    ($graph->has_attribute(UCL::Graph::ATTR_WEIGHT, $u_id, $v_id)) and
		$weight= $graph->get_attribute(UCL::Graph::ATTR_WEIGHT,
					       $u_id, $v_id);

	    my $relation= $graph->get_attribute(UCL::Graph::ATTR_RELATION,
						$u_id, $v_id);
	    my $type= 'undef';
	    if ($relation == 0) {
		$type= RIG_EDGE_TYPE_PP;
	    } elsif ($relation == 1) {
		$type= RIG_EDGE_TYPE_PC;
	    } elsif ($relation == -1) {
		$type= RIG_EDGE_TYPE_CP;
	    }

	    print RIG "$u_id\t$v_id\t$type\t$bandwidth\t$weight\t$delay\t$length\n";
	}
    }

    close(RIG);

    $self->set_error();
    return 0;
}
