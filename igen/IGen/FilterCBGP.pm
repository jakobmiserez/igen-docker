# ===================================================================
# IGen::FilterCBGP
#
# This filter generates a C-BGP script from a single graph or a set of
# intradomain graphs + an interdomain graph.
#
# (c) 2005, Networking team
#           Computing Science and Engineering Dept.
#           Université catholique de Louvain
#           Belgium
#
# author Bruno Quoitin (bruno.quoitin@uclouvain.be)
# date 23/08/2005
# $Id$
# ===================================================================

package IGen::FilterCBGP;

require Exporter;
@ISA= qw(Exporter IGen::FilterBase);

use strict;
use IGen::Definitions;
use IGen::FilterBase;

use constant IBGP_SESSION_NORMAL => 0;
use constant IBGP_SESSION_RR_CLIENT => 1;

# -----[ _init ]-----------------------------------------------------
#
# -------------------------------------------------------------------
sub _init()
{
    my ($self)= @_;

    $self->SUPER::_init();
    $self->set_capabilities(IGen::FilterBase::EXPORT_SINGLE |
			    IGen::FilterBase::EXPORT_MULTIPLE);
    $self->set_export_dialog(\&_configure_export);
}

# -----[ import_graph ]----------------------------------------------
#
# -------------------------------------------------------------------
sub import_graph($$)
{
    my ($self)= @_;
    $self->set_error("FilterCBGP can not import");
    return undef;
}

# -----[ cbgp_v2ip ]-------------------------------------------------
# Convert an AS-number (as) and a node ID (vertex) into an IP
# address.
#
# Pre:
#   (0 <= as <= 65535) and (0 <= vertex <= 65535)
# -------------------------------------------------------------------
sub cbgp_v2ip($$)
{
    my ($as, $vertex)= @_;
    return ($as >> 8).'.'.($as & 255).'.'.
	($vertex >> 8).'.'.($vertex & 255);
}

# -----[ cbgp_build_ospf_hierarchy ]---------------------------------
# Build an hierarchy of OSPF areas. Each PoP belongs to a different
# area. The hierarchy is therefore built based on the clusters
# associated with the graph.
#
# Return value:
#   - hash of areas: array of nodes belonging to area
#   - hash of nodes: array of areas containing node
# -------------------------------------------------------------------
sub cbgp_build_ospf_hierarchy()
{
    my ($self, $graph)= @_;
    my %areas= ();
    my %nodes_areas= ();
    
    # ---| Put backbone routers in backbone area (0) |---
    foreach my $v ($graph->vertices) {
	my $type= 'backbone';
	if ($graph->has_attribute(UCL::Graph::ATTR_TYPE, $v)) {
	    $type= $graph->get_attribute(UCL::Graph::ATTR_TYPE, $v);
	}
	if ($type eq 'backbone') {
	    (!exists($areas{0})) and
		$areas{0}= [];
	    push @{$areas{0}}, ($v);
	    $nodes_areas{$v}= [0];
	}
    }

    # ---| Clusters defined ? |---
    if ($graph->has_attribute(UCL::Graph::ATTR_CLUSTERS)) {
	my $clusters= $graph->get_attribute(UCL::Graph::ATTR_CLUSTERS);

	# ---| Put routers in PoP areas |---
	my $area_index= 1;
	foreach my $cluster (@$clusters) {
	    (!exists($areas{$area_index})) and
		$areas{$area_index}= [];
	    my $v_set= $cluster->[1];
	    foreach my $v (keys %$v_set) {
		push @{$areas{$area_index}}, ($v);
		(!exists($nodes_areas{$v})) and
		    $nodes_areas{$v}= [];
		push @{$nodes_areas{$v}}, ($area_index);
	    }
	    $area_index++;
	}
    }
	
    return (\%areas, \%nodes_areas);
}

# -----[ cbgp_build_ibgp_mesh ]--------------------------------------
# Build an full-mesh of iBGP sessions for the given graph.
#
# Return value:
#   reference to hashtable of iBGP sessions
#   undef  in case of error
#
# Notes:
#   iBGP-sessions are defined as follows: <R1><R2> => <TYPE>
#   where <Ri> is a vertex in the graph
#         <TYPE> is the iBGP session type (only NORMAL for full-mesh)
# -------------------------------------------------------------------
sub cbgp_build_ibgp_mesh($$)
{
    my ($self, $graph)= @_;
    my %ibgp_sessions= ();

    # ---| N*(N-1)/2 sessions |---
    my @vertices= $graph->vertices();
    for (my $i= 0; $i < scalar(@vertices)-1; $i++) {
	my $v_i= $vertices[$i];
	for (my $j= $i+1; $j < scalar(@vertices); $j++) {
	    my $v_j= $vertices[$j];
	    $ibgp_sessions{$v_i}{$v_j}= IBGP_SESSION_NORMAL;
	    $ibgp_sessions{$v_j}{$v_i}= IBGP_SESSION_NORMAL;
	}
    }

    return \%ibgp_sessions;
}

# -----[ cbgp_build_ibgp_hierarchy ]---------------------------------
# Build an hierarchy of iBGP sessions for the given graph. The
# hierarchy is based on the clusters associated with the graph.
#
# Return value:
#   reference to hashtable of iBGP sessions
#   undef  in case of error
#
# Notes:
#   iBGP-sessions are defined as follows: <R1><R2> => <TYPE>
#   where <Ri> is a vertex in the graph
#         <TYPE> is the iBGP session type which can be either
#           RR_CLIENT (R2 is client of R1) or NORMAL
# -------------------------------------------------------------------
sub cbgp_build_ibgp_hierarchy($$)
{
    my ($self, $graph)= @_;
    my %ibgp_sessions= ();

    if ($graph->has_attribute(UCL::Graph::ATTR_CLUSTERS)) {
	my $clusters= $graph->get_attribute(UCL::Graph::ATTR_CLUSTERS);
	my %bb_set= ();
	foreach my $cluster (@$clusters) {
	    my %access_set= ();
	    my %pop_bb_set= ();
	    my $v_set= $cluster->[1];
	    foreach (keys %$v_set) {
		my $access= 0;
		if ($graph->has_attribute(UCL::Graph::ATTR_TYPE, $_)) {
		    my $type= $graph->get_attribute(UCL::Graph::ATTR_TYPE, $_);
		    $access= ($type eq 'access');
		}
		if ($access) {
		    $access_set{$_}= 1;
		} else {
		    $pop_bb_set{$_}= 1;
		    $bb_set{$_}= 1;
		}
	    }
	    # Build clients (connected to all RRs in same POP)
	    foreach my $v_i (keys %access_set) {
		foreach my $v_j (keys %pop_bb_set) {
		    $ibgp_sessions{$v_i}{$v_j}= IBGP_SESSION_NORMAL;
		    $ibgp_sessions{$v_j}{$v_i}= IBGP_SESSION_RR_CLIENT;
		}
	    }
	}
	# Build full-mesh between all RRs
	my @RRs= keys %bb_set;
	for (my $i= 0; $i < scalar(@RRs); $i++) {
	    my $v_i= $RRs[$i];
	    for (my $j= $i+1; $j < scalar(@RRs); $j++) {
		my $v_j= $RRs[$j];
		$ibgp_sessions{$v_i}{$v_j}= IBGP_SESSION_NORMAL;
		$ibgp_sessions{$v_j}{$v_i}= IBGP_SESSION_NORMAL;
	    }
	}
    } else {
	$self->set_error("no clusters associated with graph");
	return undef;
    }

    return \%ibgp_sessions;
}

# -----[ cbgp_configure_topology ]-----------------------------------
# Configure the topology of a single domain into C-BGP.
#
# Arguments:
# - graph   : graph of the topology to be configured
# - options :
# -------------------------------------------------------------------
sub cbgp_configure_topology($$$)
{
    my ($self, $graph, $options)= @_;

    my $stream= $self->{stream};
    my $as= $graph->get_attribute(UCL::Graph::ATTR_AS);

    # ---| add routers |---
    foreach my $v ($graph->vertices()) {
	my $v_addr= cbgp_v2ip($as, $v);
	print $stream "net add node $v_addr\n";
	if ($graph->has_attribute(UCL::Graph::ATTR_NAME, $v)) {
	    my $name= $graph->get_attribute(UCL::Graph::ATTR_NAME, $v);
	    print $stream "net node $v_addr name \"$name\"\n";
	}
    }

    # ---| add links |---
    my @edges= $graph->edges();
    for (my $i= 0; $i < @edges/2; $i++) {
	my $u= $edges[$i*2];
	my $v= $edges[$i*2+1];
	my $u_addr= cbgp_v2ip($as, $u);
	my $v_addr= cbgp_v2ip($as, $v);
	my $weight= int($graph->get_attribute(UCL::Graph::ATTR_WEIGHT,
					      $u, $v));
	#print $stream "net add link $u_addr $v_addr $weight\n";
	print $stream "net add link $u_addr $v_addr\n";
	print $stream "net link $u_addr $v_addr igp-weight --bidir $weight\n";
    }
}

# -----[ cbgp_configure_igp ]----------------------------------------
# Configure IGP with new models (simple IGP / OSPF).
#
# Arguments:
# - graph   : graph of the domain to be configured
# - options :
# -------------------------------------------------------------------
sub cbgp_configure_igp($$$)
{
    my ($self, $graph, $options)= @_;

    my $stream= $self->{stream};
    my $as= $graph->get_attribute(UCL::Graph::ATTR_AS);

    # ---| create IGP domain |---
    if ($options->{igp}{model} == 0) {
	print $stream "net add domain $as igp\n";
    } elsif ($options->{igp}{model} == 1) {
	print $stream "net add domain $as ospf\n";
    }

    # ---| Put routers into domains |---
    foreach my $v ($graph->vertices()) {
	my $v_addr= cbgp_v2ip($as, $v);
	print $stream "net node $v_addr domain $as\n";
    }

    # ---| Put routers/links into areas if required |---
    if ($options->{igp}{model} == 1) {
	my $areas;
	my $nodes_areas;
	($areas, $nodes_areas)= $self->cbgp_build_ospf_hierarchy($graph);
	foreach my $area (keys %$areas) {
	    foreach my $v (@{$areas->{$area}}) {
		my $v_addr= cbgp_v2ip($as, $v);
		print $stream "net node $v_addr ospf area $area\n";
	    }
	}
	my @edges= $graph->edges();
	for (my $i= 0; $i < @edges/2; $i++) {
	    my $u= $edges[$i*2];
	    my $v= $edges[$i*2+1];
	    my $u_addr= cbgp_v2ip($as, $u);
	    my $v_addr= cbgp_v2ip($as, $v);
	    my $u_area= $nodes_areas->{$u}->[0];
	    my $v_area= $nodes_areas->{$v}->[0];
	    my $link_area= undef;
	    if (($u_area == $v_area)) {
		$link_area= $u_area;
	    } elsif ($u_area == 0) {
		$link_area= $v_area;
	    } elsif ($v_area == 0) {
		$link_area= $u_area;
	    } else {
		die "don't know to which area link $u->$v belongs";
	    }
	    print $stream "net node $u_addr link $v_addr ospf area $link_area\n";
	}
    }
}

# -----[ cbgp_configure_compute_igp ]--------------------------------
# Configure IGP in given domain.
#
# Arguments:
# - graph   : the domain's graph
# - options :
# -------------------------------------------------------------------
sub cbgp_configure_compute_igp($$$)
{
    my ($self, $graph, $options)= @_;

    my $as= int($graph->get_attribute(UCL::Graph::ATTR_AS));
    my $stream= $self->{stream};

    # Compute IGP routes in each domain
    print $stream "net domain $as compute\n";
}

# -----[ cbgp_configure_filter ]-------------------------------------
# Configure a input/output filter.
#
# Arguments:
# - type   : in / out
# - filter : array of rules
# -------------------------------------------------------------------
sub cbgp_configure_filter($$$)
{
    my ($self, $type, $filter)= @_;

    my $stream= $self->{stream};

    print $stream "    filter $type\n";
    foreach my $rule_match (keys %$filter) {
	my $rule_actions= $filter->{$rule_match};
	print $stream "      add-rule\n";
	print $stream "        match \"$rule_match\"\n";
	if (scalar(@$rule_actions) > 0) {
	    print $stream "        action \"";
	    for (my $i= 0; $i < scalar(@$rule_actions); $i++) {
		($i > 0) and print $stream ", ";
		print $stream $rule_actions->[$i];
	    }
	    print $stream "\"\n";
	}
	print $stream "        exit\n";
    }
    print $stream "      exit\n";
}

# -----[ cbgp_configure_ebgp_session ]-------------------------------
# Configure a single eBGP session between a router and its peers.
# Optionaly, next-hop-self and filters will be configured.
#
# Arguments:
# - igraph  : graph of interdomain links
# - u       : router
# - v       : eBGP peer
# - reverse : the roles of router/peer are inversed (important for the
#             business relationship)
# - options :
# -------------------------------------------------------------------
sub cbgp_configure_ebgp_session($$$$$$)
{
    my ($self, $igraph, $u, $v, $reverse, $options)= @_;

    my $stream= $self->{stream};

    my ($u_as, $u_id)= split /\:/, $u;
    my ($v_as, $v_id)= split /\:/, $v;
    my $u_addr= cbgp_v2ip($u_as, $u_id);
    my $v_addr= cbgp_v2ip($v_as, $v_id);

    # ---| Get business relationship |---
    my $relation;
    if (!$reverse) {
	$relation= $igraph->get_attribute(UCL::Graph::ATTR_RELATION,
					  $u, $v);
    } else {
	$relation= $igraph->get_attribute(UCL::Graph::ATTR_RELATION,
					  $v, $u);
    }
    
    print $stream "bgp router $u_addr\n";
    print $stream "  add peer $v_as $v_addr\n";
    print $stream "  peer $v_addr\n";

    # ---| Use next-hop-self ? |---
    if ($options->{bgp}{nhself}) {
	print $stream "    next-hop-self\n";
    }

    # ---| Define filters to implement business relationships ? |---
    if ($options->{bgp}{filters}) {
	if ($relation == ILINK_RELATION_PEER_PEER) {
	    # This is a relation with a peer, so we
	    # - set preference of received routes to 80 (middle)
	    # - avoid redistribution of peer/provider routes
	    $self->cbgp_configure_filter('in', {
		'any' => ['local-pref 80',
			  'community add 1'],
	    });
	    $self->cbgp_configure_filter('out', {
		'community is 1' => ['deny'],
		'any' => ['community remove 1'],
	    });
	} elsif ($relation == ILINK_RELATION_PROV_CUST) {
	    if (!$reverse) {
		# This is a relation with a customer, so we
		# - set preference of received routes to 100 (highest)
		$self->cbgp_configure_filter('in', {
		    'any' => ['local-pref 100'],
		});
		$self->cbgp_configure_filter('out', {
		    'any' => ['community remove 1'],
		});
	    } else {
		# This is a relation with a provider, so we
		# - set preference to 60 (lowest)
		# - avoid redistribution of peer/provider routes
		$self->cbgp_configure_filter('in', {
		    'any' => ['local-pref 60',
			      'community add 1'],
		});
		$self->cbgp_configure_filter('out', {
		    'community is 1' => ['deny'],
		    'any' => ['community remove 1'],
		});
	    }
	} elsif ($relation == ILINK_RELATION_SIBLING) {
	    # This is a relation with a sibling, so we
	    # - set preference to 80 (middle)
	    $self->cbgp_configure_filter('in', {
		'any' => ['local-pref 80'],
	    });
	    $self->cbgp_configure_filter('out', {
		'any' => ['community remove 1'],
	    });
	}
    }

    print $stream "    up\n";
    print $stream "    exit\n";
    print $stream "  exit\n";
}

# -----[ cbgp_configure_ebgp ]---------------------------------------
# Create the eBGP sessions corresponding to the given interdomain
# graph.
#
# Arguments:
# - igraph     : graph of interdomain links
# - opt_nhself : use next-hop-self on eBGP links
# - opt_filter : configure filters to enforce business relationships
# -------------------------------------------------------------------
sub cbgp_configure_ebgp($$$)
{
    my ($self, $igraph, $options)= @_;

    my $stream= $self->{stream};

    my @edges= $igraph->edges();
    for (my $i= 0; $i < scalar(@edges)/2; $i++) {
	my $u= $edges[$i*2]; # form: AS:ID
	my $v= $edges[$i*2+1]; # form AS:ID

	$self->cbgp_configure_ebgp_session($igraph, $u, $v, 0, $options);
	$self->cbgp_configure_ebgp_session($igraph, $v, $u, 1, $options);
    }
}

# -----[ export_graph ]----------------------------------------------
# Build a C-BGP script for the given graph(s).
#
# Options:
# - igp_model  : 0 for simple-model, 1, for OSPF-model
# - ibgp       : 0 for full-mesh, 1 for hierarchy
# - nhself     : if set, use next-hop-self on eBGP sessions
#                [ not yet implemented ]
# - filters    : if set, define filters that implement policies
# - check_reachability
# - check_peerings
# - sim_run
# -------------------------------------------------------------------
sub export_graph($$$;$)
{
    my ($self, $graphs, $filename, $options)= @_;

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

    # ---[ Generate C-BGP script |---
    if (!open(CBGP, ">$filename")) {
	$self->set_error("could not create \"$filename\": $!");
	return -1;
    }
    $self->{stream}= *CBGP;

    print CBGP "# C-BGP script\n";
    print CBGP "# Generated by IGen::FilterCBGP\n";
    print CBGP "# on ".localtime(time())."\n";

    # ---| Version 2.0.0 or above is required |---
    print CBGP "require version 2.0.0\n";

    # ---| parameters |----------------------------------------------
    # - IGP model: IGP (simple) / OSPF
    # - iBGP structure: full-mesh / hierarchy (POP's BB nodes are RRs,
    #                   others are RR-clients)
    # ---------------------------------------------------------------

    # ---| building intradomain topologies |---
    foreach my $as (keys %{$graphs->{as2graph}}) {	
	my $graph= $graphs->{as2graph}{$as};
	$self->cbgp_configure_topology($graph, $options);
    }

    # ---| configure IGP |---
    foreach my $as (keys %{$graphs->{as2graph}}) {
	my $graph= $graphs->{as2graph}{$as};
	$self->cbgp_configure_igp($graph, $options);
    }

    # ---| adding interdomain links |---
    if (defined($graphs->{igraph})) {
	my @edges= $graphs->{igraph}->edges();
	for (my $i= 0; $i < scalar(@edges)/2; $i++) {
	    my $u= $edges[$i*2]; # form: AS:ID
	    my $v= $edges[$i*2+1]; # form AS:ID
	    my ($u_as, $u_id)= split /\:/, $u;
	    my ($v_as, $v_id)= split /\:/, $v;
	    my $u_addr= cbgp_v2ip($u_as, $u_id);
	    my $v_addr= cbgp_v2ip($v_as, $v_id);
	    print CBGP "net add link $u_addr $v_addr\n";

	    # ---| Add static routes in both directions |---
	    print CBGP "net node $u_addr route add $v_addr/32 --oif=$v_addr 1\n";
	    print CBGP "net node $v_addr route add $u_addr/32 --oif=$u_addr 1\n";
	}
    }

    # ---| compute IGP |---
    foreach my $as (keys %{$graphs->{as2graph}}) {	
	my $graph= $graphs->{as2graph}->{$as};
	$self->cbgp_configure_compute_igp($graph, $options);
    }

    # ---| Configure iBGP |---
    if ($options->{bgp}{enabled}) {
	foreach my $as (keys %{$graphs->{as2graph}}) {	
	    my $graph= $graphs->{as2graph}{$as};
	    my $as_num= int($as);
	    
	    # ---| add BGP routers |---
	    foreach my $v ($graph->vertices()) {
		my $v_addr= cbgp_v2ip($as_num, $v);
		print CBGP "bgp add router $as_num $v_addr\n";
	    }
	    
	    # ---| building iBGP structures |---
	    if (($options->{ibgp}{method} == 0) &&
		$options->{ibgp}{full_mesh_command}) {
		# Full-mesh of iBGP sessions with full-mesh command
		# (decrease size of simulation scripts)
		print CBGP "bgp domain $as full-mesh\n";
	    } else {
		my $ibgp_sessions= undef;
		if ($options->{ibgp}{method} == 0) {
		    # Full-mesh
		    $ibgp_sessions= $self->cbgp_build_ibgp_mesh($graph);
		} elsif ($options->{ibgp}{method} == 1) {
		    # Route-reflection
		    # - backbone routers are RR in full-mesh
		    # - access routers are clients of RRs in their POP	    
		    $ibgp_sessions= $self->cbgp_build_ibgp_hierarchy($graph);
		}
		if (!defined($ibgp_sessions)) {
		    $self->set_error("problem building iBGP sessions");
		    close(CBGP);
		    return -1;
		}
		# Build iBGP sessions
		foreach my $v_i (keys %$ibgp_sessions) {
		    my $v_i_addr= cbgp_v2ip($as_num, $v_i);
		    print CBGP "bgp router $v_i_addr\n";
		    foreach my $v_j (keys %{$ibgp_sessions->{$v_i}}) {
			my $v_j_addr= cbgp_v2ip($as_num, $v_j);
			my $type= $ibgp_sessions->{$v_i}{$v_j};
			print CBGP "  add peer $as_num $v_j_addr\n";
			if ($type == IBGP_SESSION_RR_CLIENT) {
			    print CBGP "  peer $v_j_addr rr-client\n";
			}
			print CBGP "  peer $v_j_addr up\n";
		    }
		    print CBGP "  exit\n";
		}
	    }
	}
    }

    # ---| configure eBGP |---
    if ($options->{bgp}{enabled} &&
	defined($graphs->{igraph})) {
	$self->cbgp_configure_ebgp($graphs->{igraph}, $options);
    }

    # ---| Originate one prefix/AS |---
    if ($options->{bgp}{enabled} &&
	$options->{bgp}{originates}) {
	foreach my $as (keys %{$graphs->{as2graph}}) {
	    my $graph= $graphs->{as2graph}->{$as};
	    my $network= cbgp_v2ip($as, 0)."/16";
	    foreach my $v ($graph->vertices()) {
		my $v_addr= cbgp_v2ip($as, $v);
		print CBGP "bgp router $v_addr add network $network\n";
	    }
	}
    }

    # ---[ Checks |---
    ($options->{check}{reachability}) and
	print CBGP "bgp assert reachability-ok\n";
    ($options->{check}{peerings}) and
	print CBGP "bgp assert peerings-ok\n";

    # ---| Run simulation |---
    ($options->{sim_run}) and
	print CBGP "sim run\n";

    close(CBGP);

    $self->set_error();
    return 0;
}

# -----[ _configure_export ]-----------------------------------------
#
# -------------------------------------------------------------------
sub _configure_export(%)
{
    my (%args)= @_;

    my $dialog= IGen::DialogExportCBGP->new(%args);
    my $result= $dialog->show_modal();
    $dialog->destroy;
    return $result;
}
