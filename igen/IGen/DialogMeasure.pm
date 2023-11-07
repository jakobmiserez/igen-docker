# ===================================================================
# IGen::DialogMeasure
#
# (c) 2005, Networking team
#           Computing Science and Engineering Dept.
#           Université catholique de Louvain
#           Belgium
#
# author Bruno Quoitin (bqu@info.ucl.ac.be)
# date 19/07/2005
# lastdate 06/10/2005
# ===================================================================

package IGen::DialogMeasure;

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
    
    $self->SUPER::_init(-title=>"Measure",
			-btn_okcancel);

    if (defined($self->{args}{-methods})) {
	$self->{result}= ();
	foreach my $method (keys %{$self->{args}{-methods}}) {
	    $self->{result}{$method}= 1;
	}
    }

    $self->{Top}{top}=
	$self->{top}->Frame(-relief=>'sunken',
			    -borderwidth=>1
			    )->pack(-side=>'top',
				    -fill=>'x',
				    -expand=>1);

    my $subframe;
    $subframe= $self->{Top}{top}->Frame()->pack(-side=>'top',
						-fill=>'x',
						-expand=>1);
    $subframe->Button(-text=>'Select all',
		      -command=>[\&_select_all, $self],
		      )->pack(-side=>'left');
    $subframe->Button(-text=>'Deselect all',
		      -command=>[\&_deselect_all, $self],
		      )->pack(-side=>'left');
    for my $method (sort keys %{$self->{result}}) {
	my $subframe;
	$subframe= $self->{Top}{top}->Frame()->pack(-side=>'top',
						    -fill=>'x',
						    -expand=>1);
	$subframe->Checkbutton(-text=>$method,
			       -variable=>\$self->{result}{$method}
			       )->pack(-side=>'left');
    }
}

# -----[ _select_all ]-----------------------------------------------
sub _select_all()
{
    my ($self)= @_;

    foreach my $method (keys %{$self->{result}}) {
	$self->{result}{$method}= 1;
    }
}

# -----[ _deselect_all ]---------------------------------------------
sub _deselect_all()
{
    my ($self)= @_;

    foreach my $method (keys %{$self->{result}}) {
	$self->{result}{$method}= 0;
    }
}
