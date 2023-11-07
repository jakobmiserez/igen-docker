# ===================================================================
# IGen::DialogGraphMT
#
# (c) 2005, Networking team
#           Computing Science and Engineeding Dept.
#           Université catholique de Louvain
#           Belgium
#
# author Bruno Quoitin (bqu@info.ucl.ac.be)
# date 06/07/2005
# lastdate 06/07/2005
# ===================================================================

package IGen::DialogGraphMT;

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

    $self->SUPER::_init(-title=>"Multi-Tours",
			-btn_okcancel);

    if (!defined($self->{result})) {
	$self->{result}[0]= 5;
	$self->{result}[1]= UCL::Graph::Cluster::WARD;
	$self->{result}[2]= 200;
    }

    $self->{Top}{top}=
	$self->{top}->Frame(-relief=>'sunken',
			    -borderwidth=>1
			    )->pack(-side=>'top',
				    -fill=>'both');
    $self->{Top}{top}->Label(-text=>'K'
			     )->pack(-expand=>1);
    $self->{Top}{top}->Spinbox(-textvariable=>\$self->{result}[0],
			       -from=>1,
			       -to=>100,
			       -increment=>1,
			       )->pack(-expand=>1);
    $self->{Top}{top}->Label(-text=>'Clustering method'
			     )->pack(-expand=>1);
    my @options= ("K-medoids", "Hierarchical (Ward)");
    $self->{Top}{top}->Optionmenu(-options=>
				  [["K-medoids", UCL::Graph::Cluster::KMEDOIDS],
				   ["Hierarchical (Ward)", UCL::Graph::Cluster::WARD]],
				  -variable=>\$self->{result}[1]
				  )->pack(-expand=>1);
    
    $self->{Top}{top}->Label(-text=>'Maximum variance'
			     )->pack(-expand=>1);
    $self->{Top}{top}->Entry(-textvariable=>\$self->{result}[2]
			     )->pack(-expand=>1);
}

