# ===================================================================
# IGen::FilterPOPS
#
# (c) 2005, Networking team
#           Computing Science and Engineering Dept.
#           Université catholique de Louvain
#           Belgium
#
# author Bruno Quoitin (bqu@info.ucl.ac.be)
# date 23/08/2005
# lastdate 04/10/2005
# ===================================================================

package IGen::FilterPOPS;

require Exporter;
@ISA= qw(Exporter IGen::FilterBase);

use strict;
use IGen::FilterBase;
use IGen::Util;
use UCL::Progress;

# -----[ _init ]-----------------------------------------------------
#
# -------------------------------------------------------------------
sub _init()
{
    my ($self)= @_;

    $self->SUPER::_init();
    $self->set_capabilities(IGen::FilterBase::EXPORT_SINGLE |
			    IGen::FilterBase::EXPORT_MULTIPLE |
			    IGen::FilterBase::IMPORT_SINGLE |
			    IGen::FilterBase::IMPORT_MULTIPLE);
}

# -----[ import_graph ]----------------------------------------------
#
# -------------------------------------------------------------------
sub import_graph($$)
{
    my ($self, $filename)= @_;

    my $rid= 0;
    my %graphs= ();
    my %as2rid;
    my $num_fields= undef;

    my $progress= new UCL::Progress;
    $progress->{message}= "Importing ";
    $progress->{verbose}= 1;
    $progress->{pace}= 1;
    $progress->{percent}= 0;

    if (!open(POPS, "<$filename")) {
	$self->set_error("unable to open \"$filename\": $!");
	return undef;
    }

    my $cnt= 0;
    while (<POPS>) {
	chomp;
	(m/^\#/) and next;
	my @fields= split /\s+/;
	if ((@fields < 3) ||
	    (defined($num_fields) && ($num_fields != @fields))) {
	    $self->set_error("invalid number of fields ".@fields.
			     "[$_] => [".(join ",", @fields)."]");
	    close(POPS);
	    return undef;
	}
	$num_fields= @fields;

	my $pop_as= shift @fields;
	# ---| check domain-id |---
	if (!($pop_as =~ m/^[0-9]+$/) || ($pop_as > 65535)) {
	    $self->set_error("invalid domain-id ($pop_as)");
	    close(POPS);
	    return undef;
	}
	if (!exists($graphs{$pop_as})) {
	    my $graph= new Graph::Undirected;
	    $graph->set_attribute(UCL::Graph::ATTR_GFX, 1);
	    $graph->set_attribute(UCL::Graph::ATTR_AS, $pop_as);
	    $graphs{$pop_as}= $graph;
	    $as2rid{$pop_as}= 0;
	}
	my $pop_graph= $graphs{$pop_as};
	my $pop_rid= undef;
	if ($num_fields >= 4) {
	    $pop_rid= shift @fields;
	    # ---| check router-id |---
	    if (!($pop_rid =~ m/^[0-9]+$/)) {
		$self->set_error("invalid router-id ($pop_rid)");
		close(POPS);
		return undef;
	    }
	} else {
	    $pop_rid= $as2rid{$pop_as}++;
	}
	my $pop_coord_lat= shift @fields;
	my $pop_coord_long= shift @fields;

	# ---| check coordinates |---
	if (($pop_coord_lat < -90) || ($pop_coord_lat > 90) ||
	    ($pop_coord_long < -180) || ($pop_coord_long > 180)) {
	    $self->set_error("invalid coordinates ($pop_coord_long, $pop_coord_lat)");
	    close(POPS);
	    return undef;
	}
	
	$pop_graph->add_vertex($pop_rid);
	$pop_graph->set_attribute(UCL::Graph::ATTR_COORD, $pop_rid,
				  [$pop_coord_long, $pop_coord_lat]);
	$pop_graph->set_attribute(UCL::Graph::ATTR_AS, $pop_rid, $pop_as);
	
	$cnt++;
	$progress->progress($cnt);
    }
    $progress->end($cnt);
    close(POPS);

    $self->set_error();
    return {'as2graph' => \%graphs };
}

# -----[ export_graph ]----------------------------------------------
#
# -------------------------------------------------------------------
sub export_graph($$$)
{
    my ($self, $graphs, $filename)= @_;

    if (!open(POPS, ">$filename")) {
	$self->set_error("unable to create file \"$filename\": $!");
	return -1;
    }

    # ---| Single domain: convert to hash of domains |---
    if (ref($graphs) ne "HASH") {
	$graphs= {
	    'as2graph' => {
		$graphs->get_attribute(UCL::Graph::ATTR_AS) => $graphs
		},
		};
    }

    # ---| Generate file of points-of-presence |---
    print POPS "# Generated by IGen::FilterPOPS\n";
    print POPS "# on ".localtime(time())."\n";
    print POPS "# <AS> <ID> <latitude (Y)> <longitude (X)>\n";
    foreach my $graph (values %{$graphs->{as2graph}}) {
	my $as_id= $graph->get_attribute(UCL::Graph::ATTR_AS);
	foreach my $vertex ($graph->vertices()) {
	    my $coord= $graph->get_attribute(UCL::Graph::ATTR_COORD, $vertex);
	    print POPS "$as_id\t$vertex\t$coord->[1]\t$coord->[0]\n";
	}
    }
    close(POPS);

    $self->set_error();
    return 0;
}
