# ===================================================================
# IGen::DialogInterConnect
#
# (c) 2005, Networking team
#           Computing Science and Engineering Dept.
#           Université catholique de Louvain
#           Belgium
#
# author Bruno Quoitin (bqu@info.ucl.ac.be)
# date 19/07/2005
# lastdate 19/07/2005
# ===================================================================

package IGen::DialogInterConnect;

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

    $self->SUPER::_init(-title=>'Connect domains',
			-btn_okcancel);

    my @ases= ();
    if (exists($self->{args}{-as2graph})) {
	@ases= keys(%{$self->{args}{-as2graph}});
    }

    if (!defined($self->{result})) {
	$self->{result}{domainA}= $ases[0];
	$self->{result}{domainB}= $ases[1];
	$self->{result}{relation}= 0;
	$self->{result}{num_links}= 3;
    }

    $self->{Top}{top}=
	$self->{top}->Frame()->pack(-side=>'top', -fill=>'x');
    my $subframe=
	$self->{Top}{top}->Frame()->pack(-side=>'top',
					 -fill=>'x',
					 -expand=>1);
    $subframe->Label(-text=>'Domain A:'
		     )->pack(-side=>'left');
    $subframe->BrowseEntry(-choices=>\@ases,
			   -state=>'readonly',
			   -browsecmd=>[\&_update_ok, $self],
			   -variable=>\$self->{result}{domainA}
			   )->pack(-side=>'right');
    $subframe=
	$self->{Top}{top}->Frame()->pack(-side=>'top',
					 -fill=>'x',
					 -expand=>1);    
    $subframe->Label(-text=>'Domain B:'
		     )->pack(-side=>'left');
    $subframe->BrowseEntry(-choices=>\@ases,
			   -state=>'readonly',
			   -browsecmd=>[\&_update_ok, $self],
			   -variable=>\$self->{result}{domainB}
			   )->pack(-side=>'right');
    $subframe=
	$self->{Top}{top}->Frame()->pack(-side=>'top',
					 -fill=>'x',
					 -expand=>1);    
    $subframe->Label(-text=>'Relationship:'
		     )->pack(-side=>'left');
    $subframe->Optionmenu(-options=>get_ilink_relations_options,
			  -variable=>\$self->{result}{relation}
			  )->pack(-side=>'right');
    $subframe=
	$self->{Top}{top}->Frame()->pack(-side=>'top',
					 -fill=>'x',
					 -expand=>1);
    $subframe->Label(-text=>'Num. links:'
		     )->pack(-side=>'left');
    $subframe->Spinbox(-from=>1,
		       -to=>10,
		       -increment=>1,
		       -state=>'readonly',
		       -textvariable=>\$self->{result}{num_links}
		       )->pack(-side=>'right');
}

# -----[ _update_ok ]------------------------------------------------
#
# -------------------------------------------------------------------
sub _update_ok()
{
    my ($self)= @_;

    my $ok= ($self->{result}{domainA} != $self->{result}{domainB});
    $self->{ButtonOk}->configure(-state=>($ok?'normal':'disabled'));
}
