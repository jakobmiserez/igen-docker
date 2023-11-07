# ===================================================================
# IGen::DialogGraphMentor
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

package IGen::DialogGraphMentor;

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

    $self->SUPER::_init(-title=>"Mentor",
			-btn_okcancel);

    if (!defined($self->{result})) {
	$self->{result}[0]= 0.3;
    }

    $self->{Top}{top}=
	$self->{top}->Frame(-relief=>'sunken',
					-borderwidth=>1
					)->pack(-side=>'top');
    $self->{Top}{top}->Label(-text=>'Alpha')->pack(-expand=>1);
    $self->{Top}{top}->Entry(-textvariable=>\$self->{result}[0]
			     )->pack(-expand=>1);
}

