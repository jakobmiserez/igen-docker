# ===================================================================
# IGen::DialogProgress
#
# (c) 2005, Networking team
#           Computing Science and Engineering Dept.
#           Université catholique de Louvain
#           Belgium
#
# author Bruno Quoitin (bqu@info.ucl.ac.be)
# date 24/08/2005
# lastdate 24/08/2005
# ===================================================================

package IGen::DialogProgress;

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

    $self->SUPER::_init(-title=>'Progress');

    my $frame= $self->{top}->Frame(-relief=>'sunken',
				   -borderwidth=>1
				   )->pack(-side=>'top',
					   -fill=>'x',
					   -expand=>1);
    $self->{Top}{Progress}= $frame->ProgressBar(-borderwidth=>2,
						-relief=>'sunken',
						-width=>40,
						-resolution=>0,
						-blocks=>50,
						-from=>0,
						-to=>100,
						-variable=>$self->{progress})
	->pack(-side=>'top', -fill=>'x');
}

# -----[ update ]----------------------------------------------------
#
# -------------------------------------------------------------------
sub update($)
{
    my ($self)= @_;

    $self->{top}->update();
}
