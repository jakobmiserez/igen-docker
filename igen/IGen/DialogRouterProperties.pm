# ===================================================================
# IGen::DialogRouterProperties
#
# (c) 2005, Networking team
#           Computing Science and Engineering Dept.
#           Université catholique de Louvain
#           Belgium
#
# author Bruno Quoitin (bqu@info.ucl.ac.be)
# date 31/08/2005
# lastdate 04/10/2005
# ===================================================================

package IGen::DialogRouterProperties;

require Exporter;
@ISA= qw(Exporter IGen::DialogProperties);

use Tk 800.000;
use Tk::Toplevel;

use strict;
use IGen::DialogProperties;

# -----[ _init ]-----------------------------------------------------
#
# -------------------------------------------------------------------
sub _init()
{
    my ($self)= @_;
    
    $self->SUPER::_init(-title=>"Router properties");

    # ---| Check parameters |---
    (!exists($self->{args}{-graph}) ||
     !exists($self->{args}{-router})) and
     die "missing argument -graph or -router";
    $self->{graph}= $self->{args}{-graph};
    $self->{router}= $self->{args}{-router};

    # ---| Router infos |---
    $self->_add_attribute_header("Router ".$self->{router});
    my $coord= $self->{graph}->get_attribute(UCL::Graph::ATTR_COORD,
					     $self->{router});
    my $domain= $self->{graph}->get_attribute(UCL::Graph::ATTR_AS,
					      $self->{router});
    $self->_add_attribute_ro('Longitude:', $coord->[0]);
    $self->_add_attribute_ro('Latitude:', $coord->[1]);
    $self->_add_attribute_ro('Domain:', $domain);
    if ($self->{graph}->has_attribute(UCL::Graph::ATTR_TYPE,
				      $self->{router})) {
	my $type= $self->{graph}->get_attribute(UCL::Graph::ATTR_TYPE,
						$self->{router});
	$self->_add_attribute_ro('Type:', $type);
    }

    # ---| Modifiable attributes |---
    my $subframe= 
	$self->{Top}{top}->Frame()->pack(-side=>'top',
					 -fill=>'x',
					 -expand=>1);
    $self->{result}{UCL::Graph::ATTR_NAME}=
	$self->{graph}->get_attribute(UCL::Graph::ATTR_NAME,
				      $self->{router});
    $subframe->Label(-text=>'Name:'
		     )->pack(-side=>'left');
    $subframe->Entry(-textvariable=>\$self->{result}{UCL::Graph::ATTR_NAME}
		     )->pack(-side=>'right');

}

# -----[ _on_close ]-------------------------------------------------
#
# -------------------------------------------------------------------
sub _on_close()
{
    my ($self)= @_;

    # ---| Close with ok, apply changes |---
    if (defined($self->{result})) {
	my $graph= $self->{graph};
	my $router= $self->{router};

	foreach my $attribute (keys %{$self->{result}}) {
	    my $value= $self->{result}{$attribute};
	    $graph->set_attribute($attribute, $router, $value);
	}
    }
}
