# ===================================================================
# IGen::DialogLatticeCellSize
#
# (c) 2005, Networking team
#           Computing Science and Engineering Dept.
#           Université catholique de Louvain
#           Belgium
#
# author Bruno Quoitin (bqu@info.ucl.ac.be)
# date 21/09/2005
# lastdate 22/09/2005
# ===================================================================

package IGen::DialogLatticeCellSize;

require Exporter;
@ISA= qw(Exporter UCL::Tk::Dialog);

use Tk 800.000;
use Tk::Toplevel;

use strict;
use UCL::Tk::Dialog;
use UCL::Graph::Base;

# -----[ _init ]-----------------------------------------------------
#
# -------------------------------------------------------------------
sub _init()
{
    my ($self)= @_;
    
    $self->SUPER::_init(-title=>"Select lattice cell size",
			-btn_okcancel);

    # ---| Check arguments |---
    (!defined($self->{args}{-graph})) and
	die "-graph argument not defined";
    my $graphs= $self->{args}{-graph};
    $self->{result}{dx}= 10;
    $self->{result}{dy}= 10;

    # ---| Build window |---
    my ($frame, $subframe);
    $frame=
	$self->{top}->Frame(-relief=>'sunken',
			    -borderwidth=>1
			    )->pack(-side=>'top',
				    -fill=>'both',
				    -expand=>1);
    $subframe= $frame->Frame()->pack(-side=>'top',
				     -fill=>'x',
				     -expand=>1);
    $subframe->Label(-text=>'X-size:'
		     )->pack(-side=>'left');
    $subframe->Spinbox(-textvariable=>\$self->{result}{dx},
		       -from=>1,
		       -to=>100,
		       -increment=>1,
		       -command=>[\&_update_size, $self],
		       )->pack(-side=>'right');
    $subframe= $frame->Frame()->pack(-side=>'top',
				     -fill=>'x',
				     -expand=>1);
    $subframe->Label(-text=>'Y-size:'
		     )->pack(-side=>'left');
    $subframe->Spinbox(-textvariable=>\$self->{result}{dy},
		       -from=>1,
		       -to=>100,
		       -increment=>1,
		       -command=>[\&_update_size, $self],
		       )->pack(-side=>'right');

    $self->_update_size();
}

# -----[ _update_size ]----------------------------------------------
#
# -------------------------------------------------------------------
sub _update_size($)
{
    my ($self)= @_;
    if (defined($self->{args}{-command})) {
	my $command= $self->{args}{-command};
	&$command($self->{result}{dx},
		  $self->{result}{dy});
    }
}
