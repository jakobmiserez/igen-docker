# ===================================================================
# IGen::DialogAbout
#
# (c) 2005, Networking team
#           Computing Science and Engineeding Dept.
#           Université catholique de Louvain
#           Belgium
#
# author Bruno Quoitin (bqu@info.ucl.ac.be)
# date 06/07/2005
# lastdate 05/10/2005
# ===================================================================

package IGen::DialogAbout;

require Exporter;
@ISA= qw(Exporter UCL::Tk::Dialog);

use Tk 800.000;
use Tk::Toplevel;

use strict;
use UCL::Tk::Dialog;
use IGen::Definitions;

# -----[ _init ]-----------------------------------------------------
#
# -------------------------------------------------------------------
sub _init()
{
    my ($self)= @_;

    $self->SUPER::_init();

    $self->{top}->title("About ...");
    $self->{Top}{top}=
	$self->{top}->Frame()->pack(-side=>'top',
				    -fill=>'both');
    $self->{Top}{top}->Label(-relief=>'sunken',
			     -borderwidth=>1,
			     -text=>"IGen ".PROGRAM_VERSION,
			     -background=>'darkgray',
			     )->pack(-expand=>1);
    $self->{Top}{top}->Label(-text=>"Prototype of a\n".
			     "topology generator\n\n".
			     "written by B. Quoitin\n".
			     "IP Networking Lab\n".
			     "Universite catholique de Louvain\n".
			     "Louvain-la-Neuve, Belgium"
			     )->pack(-expand=>1);
    $self->{Bottom}{top}=
	$self->{top}->Frame(-relief=>'sunken',
			    -borderwidth=>1
			    )->pack(-side=>'bottom',
				    -fill=>'both');
    $self->{Bottom}{top}->Button(-text=>"Close",
				 -command=>sub{
				     $self->{semaphore}= 1;
				 })->pack(-expand=>1);
    my $img= $self->{top}->Photo(-file=>"logo_totem.gif");
    $self->{Top}{top}->Label(-image=>$img)->pack();
}

