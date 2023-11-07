# ===================================================================
# IGen::DialogMessage
#
# (c) 2005, Networking team
#           Computing Science and Engineering Dept.
#           Université catholique de Louvain
#           Belgium
#
# author Bruno Quoitin (bqu@info.ucl.ac.be)
# date 23/08/2005
# lastdate 23/08/2005
# ===================================================================

package IGen::DialogMessage;

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

    $self->SUPER::_init(-title=>'Message');

    $self->_init_bottom_frame();

    # ---| Create buttons |---
    # Each button is specified by a TEXT and a VALUE
    foreach my $btn (@{$self->{args}{-buttons}}) {
	my $text= $btn->[0];
	my $value= $btn->[1];
	$self->{Bottom}{top}->Button(-text=>$text,
				     -command=>sub{
					 $self->{result}{btn}= $value;
					 $self->_close();
				     }
				     )->pack(-expand=>1,
					     -side=>'right');
    }
    
    # ---| Display message |---
    my $frame= $self->{top}->Frame(-relief=>'sunken',
				   -borderwidth=>1
				   )->pack(-side=>'top',
					   -fill=>'x',
					   -expand=>1);
    $frame->Label(-text=>$self->{args}{-text})->pack(-side=>'top',
						     -fill=>'x');;

}
