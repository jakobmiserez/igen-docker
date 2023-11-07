# ===================================================================
# IGen::DialogSelectRouter
#
# (c) 2005, Networking team
#           Computing Science and Engineering Dept.
#           Université catholique de Louvain
#           Belgium
#
# author Bruno Quoitin (bqu@info.ucl.ac.be)
# date 26/08/2005
# lastdate 02/11/2005
# ===================================================================

package IGen::DialogSelectRouter;

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
    
    $self->SUPER::_init(-title=>"Select router",
			-btn_okcancel);

    # ---| Check arguments |---
    (!defined($self->{args}{-graphs})) and die "-graphs argument not defined";
    my $graphs= $self->{args}{-graphs};
    my @domains= sort {$a <=> $b} keys(%{$graphs->{as2graph}});
    $self->{domains}= \@domains;
    $self->{routers}= [];

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
    $subframe->Label(-text=>'Domain:'
		     )->pack(-side=>'left');
    $subframe->BrowseEntry(-choices=>$self->{domains},
			   -browsecmd=>[\&_update_routers, $self],
			   -variable=>\$self->{result}{domain},
			   -state=>'readonly',
			   )->pack(-side=>'right');
    $subframe= $frame->Frame()->pack(-side=>'top',
				     -fill=>'x',
				     -expand=>1);
    $subframe->Label(-text=>'Router:'
		     )->pack(-side=>'left');
    $self->{RoutersList}=
	$subframe->BrowseEntry(-choices=>$self->{routers},
			       -browsecmd=>[\&_update_ok, $self],
			       -variable=>\$self->{result}{router},
			       -state=>'readonly'
			       )->pack(-side=>'right');

    $self->_update_routers();
}

# -----[ _update_ok ]------------------------------------------------
sub _update_ok() {
    my ($self)= @_;

    if (defined($self->{result}{router}) &&
	defined($self->{result}{domain})) {
	$self->{ButtonOk}->configure(-state=>'active');
    } else {
	$self->{ButtonOk}->configure(-state=>'disabled');
    }
}

# -----[ _update_routers ]-------------------------------------------    
sub _update_routers() {
    my ($self)= @_;

    if (defined($self->{result}{domain})) {
	my $domain= $self->{result}{domain};
	my $graph= $self->{args}{-graphs}->{as2graph}->{$domain};
	my @routers= sort {$a <=> $b} $graph->vertices();
	foreach (@routers) {
	    if ($graph->has_attribute(UCL::Graph::ATTR_NAME, $_)) {
		$_.= ' ('.$graph->get_attribute(UCL::Graph::ATTR_NAME, $_).')';
	    }
	}
	$self->{routers}= \@routers;
	$self->{RoutersList}->configure(-choices=>$self->{routers});
	# ---| Select first router in list |---
	if (scalar(@routers) > 0) {
	    $self->{result}{router}= $routers[0];
	} else {
	    $self->{result}{router}= undef;
	}
    } else {
	$self->{routers}= [];
	$self->{result}{router}= undef;
    }
    $self->_update_ok();
}
