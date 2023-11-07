# ===================================================================
# IGen::DialogShowClusters
#
# (c) 2005, Networking team
#           Computing Science and Engineering Dept.
#           Université catholique de Louvain
#           Belgium
#
# author Bruno Quoitin (bqu@info.ucl.ac.be)
# date 24/07/2005
# lastdate 24/08/2005
# ===================================================================

package IGen::DialogShowClusters;

require Exporter;
@ISA= qw(Exporter UCL::Tk::Dialog);

use Tk 800.000;
use Tk::Toplevel;

use strict;
use UCL::Tk::Dialog;

# -----[ _init ]-----------------------------------------------------
#
# -------------------------------------------------------------------
sub _init()
{
    my ($self)= @_;
    
    $self->SUPER::_init(-title=>"Clusters",
			-btn_close);

    my $graph= $self->{args}{-graph};

    my $frame=
	$self->{top}->Frame(-relief=>'sunken',
			    -borderwidth=>1
			    )->pack(-side=>'top',
				    -fill=>'both',
				    -expand=>1);
    my @headers= ('Cluster', 'Centroid', 'Nodes');
    my $clustersList= $frame->Scrolled("HList",
				       -header=>1,
				       -columns=>scalar(@headers),
				       -background=>'white',
				       -scrollbars=>'osoe',
				       -command=>[\&_select, $self],
				       )->pack(-expand=>1,
					       -fill=>'both');
    $self->{Top}{ClustersList}= $clustersList;
    my $column= 0;
    foreach my $header (@headers) {
	$clustersList->header('create', $column++,
			      -text=>$header,
			      -borderwidth=>1,
			      -headerbackground=>'gray');
    }
    my $r= 0;
    my $styleRight= $clustersList->ItemStyle('text',
					     -justify=>'right');
    my $styleLeft= $clustersList->ItemStyle('text',
					    -justify=>'left');
    my $clusters= $graph->get_attribute('clusters');
    for (my $i= 0; $i < @$clusters; $i++) {
	my $centroid= $clusters->[$i]->[0];
	my @nodes= keys %{$clusters->[$i]->[1]};
	$clustersList->add($r,
			   -data=>$clusters->[$i]);
	$clustersList->itemCreate($r, 0,
				  -text=>$i,
				  -style=>$styleLeft);
	$clustersList->itemCreate($r, 1,
				  -text=>"$centroid",
				  -style=>$styleLeft);
	$clustersList->itemCreate($r, 2,
				  -text=>(join ',', @nodes),
				  -style=>$styleLeft);
	$r++;
    }

    $frame->Label(-text=>"Number of clusters: ".scalar(@$clusters),
		  )->pack(-side=>'bottom',
			  -expand=>1);
}

# -----[ _select ]---------------------------------------------------
#
# -------------------------------------------------------------------
sub _select()
{
    my ($self, $index)= @_;

    if (exists($self->{args}{-command})) {
	my $fct= $self->{args}{-command};
	my $cluster= $self->{Top}{ClustersList}->info('data', $index);
	&$fct($cluster);
    }
}

