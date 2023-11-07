# ===================================================================
# IGen::DialogContinent.pm
#
# (c) 2005, Networking team
#           Computing Science and Engineeding Dept.
#           Université catholique de Louvain
#           Belgium
#
# author Bruno Quoitin (bqu@info.ucl.ac.be)
# date 17/08/2005
# lastdate 17/08/2005
# ===================================================================

package IGen::DialogContinent;

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

    $self->SUPER::_init(-title=>"Select continent",
			-btn_okcancel);

    if (!defined($self->{result})) {
	$self->{result}[0]= 'all';
    }

    my $frame=
	$self->{top}->Frame(-relief=>'sunken',
			    -borderwidth=>1
			    )->pack(-side=>'top');
    $frame->Label(-text=>'Continent:'
		  )->pack(-side=>'left');
    my @options= keys %{$self->{args}{-continents}};
    unshift(@options, 'all');
    $frame->Optionmenu(-options=>\@options,
		       -textvariable=>\$self->{result}[0],
		       )->pack(-side=>'right',
			       -fill=>'x');
}
