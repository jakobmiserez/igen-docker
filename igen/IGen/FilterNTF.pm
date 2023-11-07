# ===================================================================
# IGen::FilterNTF
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

package IGen::FilterNTF;

require Exporter;
@ISA= qw(Exporter IGen::FilterBase);

use strict;
use IGen::FilterBase;

# -----[ _lspid2ip ]-------------------------------------------------
# Convert an LSP Id to the IP loopback address of the router.
# -------------------------------------------------------------------
sub _lspid2ip($)
{
    my ($lspid)= @_;

    if ($lspid =~ m/^([0-9]{3})([0-9]).([0-9]{2})([0-9]{2}).([0-9])([0-9]{3})/) {
	return "".int($1).".".($2*100+$3).".".($4*10+$5).".".int($6);
    }
    return undef;
}

# -----[ _ipresolve ]------------------------------------------------
# Try to resolve the given IP address to a name.
# -------------------------------------------------------------------
sub _ipresolve($$)
{
    my ($self, $ip)= @_;

    if (!exists($self->{resolve_cache}->{$ip})) {
        open(HOST, "host $ip |") or return $ip;
	my $answer= <HOST>;
        close(HOST);
	if ($answer =~ m/not found/) {
	    return $ip;
	}
        my @fields= split /\s+/, $answer;
        $self->{resolve_cache}->{$ip}= $fields[4];
    }
    return $self->{resolve_cache}->{$ip};
}

# -----[ _init ]-----------------------------------------------------
#
# -------------------------------------------------------------------
sub _init()
{
    my ($self)= @_;

    $self->SUPER::_init();
    $self->set_capabilities(IGen::FilterBase::EXPORT_SINGLE |
			    IGen::FilterBase::IMPORT_SINGLE);
    $self->{resolve_cache}= {};
}

# -----[ import_graph ]----------------------------------------------
#
# -------------------------------------------------------------------
sub import_graph($$)
{
    my ($self, $filename)= @_;
    my $graph= new Graph::Undirected;
    # NTF graphs do not contains geographical coordinates
    $graph->set_attribute(UCL::Graph::ATTR_GFX, 0);

    my $vertex_id= 0;
    my %vertices= ();
    
    if (!open(NTF, "<$filename")) {
	$self->set_error("unable to open \"$filename\": $!");
	return undef;
    }

    while (<NTF>) {
	chomp;
	(m/^\#/) and next;

	my @fields= split /\s+/;
	if (@fields < 3) {
	    $self->set_error("not enough fields");
	    close(NTF);
	    return undef;
	}
	my $src= $fields[0];
	my $dst= $fields[1];

	(!exists($vertices{$src})) and
	    $vertices{$src}= $vertex_id++;
	$src= $vertices{$src};
	(!exists($vertices{$dst})) and
	    $vertices{$dst}= $vertex_id++;
	$dst= $vertices{$dst};

	my $weight= $fields[2];
	if (!$graph->has_vertex($src)) {
	    $graph->add_vertex($src);
	    my $name=_lspid2ip($fields[0]);
	    (!defined($name)) and $name= $fields[0];
	    #$name= $self->_ipresolve($name);
	    $graph->set_attribute(UCL::Graph::ATTR_NAME, $src, $name);
	}
	if (!$graph->has_vertex($dst)) {
	    $graph->add_vertex($dst);
	    my $name=_lspid2ip($fields[1]);
	    (!defined($name)) and $name= $fields[1];
	    #$name= $self->_ipresolve($name);
	    $graph->set_attribute(UCL::Graph::ATTR_NAME, $dst, $name);
	}
	if (!$graph->has_edge($src, $dst)) {
	    $graph->add_weighted_edge($src, $weight, $dst);
	    if (scalar(@fields > 3)) {
		$graph->set_attribute(UCL::Graph::ATTR_CAPACITY,
				      $src, $dst, $fields[3]);
	    }
	}
    }
    close(NTF);

    $self->set_error();
    return $graph;
}

# -----[ export_graph ]----------------------------------------------
#
# -------------------------------------------------------------------
sub export_graph($$$)
{
    my ($self, $graph, $filename)= @_;

    if (!open(NTF, ">$filename")) {
	$self->set_error("could not create \"$filename\": $!");
	return -1;
    }

    print NTF "# Generated by IGen::FilterNTF\n";
    print NTF "# on ".localtime(time())."\n";

    my @edges= $graph->edges();
    for (my $i= 0; $i < @edges/2; $i++) {
	my $u= $edges[$i*2];
	my $v= $edges[$i*2+1];
	my $weight= 0;
	if ($graph->has_attribute(UCL::Graph::ATTR_WEIGHT, $u, $v)) {
	  $weight= $graph->get_attribute(UCL::Graph::ATTR_WEIGHT, $u, $v);
	}
	print NTF "$u\t$v\t$weight\n";
    }
    close(NTF);

    $self->set_error();
    return 0;
}