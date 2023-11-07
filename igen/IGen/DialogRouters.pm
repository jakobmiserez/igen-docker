# ===================================================================
# IGen::DialogRouters
#
# (c) 2005, Networking team
#           Computing Science and Engineeding Dept.
#           Université catholique de Louvain
#           Belgium
#
# author Bruno Quoitin (bruno.quoitin@uclouvain.be)
# date 05/07/2005
# lastdate 11/02/2009
# ===================================================================
# (11/02/2009) fix typo in dialog field (was 'Sone' instead of 'Zone')
# ===================================================================

package IGen::DialogRouters;

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

    $self->SUPER::_init(-title=>"Generate routers",
			-btn_okcancel);

    if (!defined($self->{result})) {
	$self->{result}[0]= $self->{args}{-domain};
	$self->{result}[1]= 50;
	$self->{result}[2]= 1;
	$self->{result}[3]= 'all';
    }

    my $frame;
    my $subframe;

    $frame=
	$self->{top}->Frame(-relief=>'sunken',
			    -borderwidth=>1
			    )->pack(-side=>'top');
    $subframe=
	$frame->Frame()->pack(-side=>'top',
			      -fill=>'x',
			      -expand=>1);
    $subframe->Label(-text=>'Domain:'
		     )->pack(-side=>'left');
    $subframe->Entry(-textvariable=>\$self->{result}[0]
		     )->pack(-side=>'right');
    $subframe=
	$frame->Frame()->pack(-side=>'top',
				     -fill=>'x',
				     -expand=>1);
    $subframe->Label(-text=>'Num. routers:'
		     )->pack(-side=>'left',
			     -expand=>1);
    $subframe->Spinbox(-from=>1,
			       -to=>1000,
			       -increment=>1,
			       -textvariable=>\$self->{result}[1]
			       )->pack(-side=>'right',
				       -expand=>1);
    $subframe=
	$frame->Frame()->pack(-side=>'top',
				     -fill=>'x',
				     -expand=>1);
    $subframe->Checkbutton(-text=>'Routers in continents',
			   -variable=>\$self->{result}[2],
			   )->pack(-side=>'left',
				   -fill=>'x');
    $subframe=
	$frame->Frame()->pack(-side=>'top',
				     -fill=>'x',
				     -expand=>1);
    $subframe->Label(-text=>'Area:'
		     )->pack(-side=>'left');
    my @options= keys %{$self->{args}{-continents}};
    unshift(@options, 'all');
    $subframe->Optionmenu(-options=>\@options,
			  -textvariable=>\$self->{result}[3],
			  )->pack(-side=>'right',
				  -fill=>'x');
}

