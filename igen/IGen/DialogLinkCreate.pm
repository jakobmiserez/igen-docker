# ===================================================================
# IGen::DialogLinkCreate
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

package IGen::DialogLinkCreate;

require Exporter;
@ISA= qw(Exporter UCL::Tk::Dialog);

use Tk 800.000;
use Tk::Toplevel;

use strict;
use IGen::Definitions;

# -----[ _init ]-----------------------------------------------------
#
# -------------------------------------------------------------------
sub _init()
{
    my ($self)= @_;
    
    $self->SUPER::_init(-title=>"Create link",
			-btn_okcancel);

    # ---| Check parameters |---
    (!exists($self->{args}{-graph})) and
     die "missing argument -graph";
    $self->{graph}= $self->{args}{-graph};

    # ---| Build dialog box |---
    my $frame;
    my $subframe;

    $frame=
	$self->{top}->Frame(-relief=>'sunken',
			    -borderwidth=>1
			    )->pack(-side=>'top',
				    -fill=>'x',
				    -expand=>1);
    $self->{Top}{top}= $frame;

    # ---| Link infos |---
    my @routers= $self->{graph}->vertices();
    $self->{routers}= \@routers;
    $subframe= $frame->Frame()->pack(-side=>'top',
				     -fill=>'x',
				     -expand=>1);
    $subframe->Label(-text=>'Router 1:'
		     )->pack(-side=>'left');
    $self->{Routers1List}=
	$subframe->BrowseEntry(-choices=>$self->{routers},
#			       -browsecmd=>[\&_update_ok, $self],
			       -variable=>\$self->{result}{router1},
			       -state=>'readonly'
			       )->pack(-side=>'right');
    $subframe->Label(-text=>'Router 2:'
		     )->pack(-side=>'left');
    $self->{Routers2List}=
	$subframe->BrowseEntry(-choices=>$self->{routers},
#			       -browsecmd=>[\&_update_ok, $self],
			       -variable=>\$self->{result}{router2},
			       -state=>'readonly'
			       )->pack(-side=>'right');

#    my $u_id= $self->{link}->[0];
#    my $u_name= $self->{graph}->get_attribute(UCL::Graph::ATTR_NAME, $u_id);
#    (defined($u_name)) and $u_id.= " ($u_name)";
#    my $v_id= $self->{link}->[1];
#    my $v_name= $self->{graph}->get_attribute(UCL::Graph::ATTR_NAME, $v_id);
#    (defined($v_name)) and $v_id.= " ($v_name)";
#    $self->_add_attribute_header("Link $u_id -> $v_id");
#    my $type= 'Internal';
#    if ($self->{graph}->has_attribute(UCL::Graph::ATTR_RELATION,
#				      $u_id, $v_id)) {
#	my $relation= $self->{graph}->get_attribute(UCL::Graph::ATTR_RELATION,
#						    $u_id, $v_id);
#	$type= ILINK_RELATIONS->{$relation};
#    }
#    $self->_add_attribute_ro('Type:', $type);
#    my $length= UCL::Graph::Base::distance($self->{graph},
#					   $self->{link}->[0],
#					   $self->{link}->[1]);
#    $self->_add_attribute_ro('Length (km):', sprintf("%.2f", $length));
#
#    # ---| IGP weight |---
#    $subframe= $frame->Frame()->pack(-side=>'top',
#				     -fill=>'x',
#				     -expand=>1);
#    $self->{result}{UCL::Graph::ATTR_WEIGHT}=
#	$self->{graph}->get_attribute(UCL::Graph::ATTR_WEIGHT,
#				      $self->{link}->[0],
#				      $self->{link}->[1]);
#    $subframe->Label(-text=>'IGP weight:'
#		     )->pack(-side=>'left');
#    $subframe->Entry(-textvariable=>\$self->{result}{UCL::Graph::ATTR_WEIGHT}
#		     )->pack(-side=>'right');
#
#    # ---| Bandwidth |---
#    $subframe= $frame->Frame()->pack(-side=>'top',
#				     -fill=>'x',
#				     -expand=>1);
#    $self->{result}{UCL::Graph::ATTR_CAPACITY}=
#	$self->{graph}->get_attribute(UCL::Graph::ATTR_CAPACITY,
#				      $self->{link}->[0], $self->{link}->[1]);
#    $subframe->Label(-text=>'Bandwidth:'
#		     )->pack(-side=>'left');
#    $subframe->BrowseEntry(-choices=>$self->{capacities},
#			   -variable=>
#			   \$self->{result}{UCL::Graph::ATTR_CAPACITY},
#			   )->pack(-side=>'right');
#
#    # ---| Load |---
#    if ($self->{graph}->has_attribute(UCL::Graph::ATTR_LOAD,
#				      $self->{link}->[0],
#				      $self->{link}->[1])) {
#	my $load= $self->{graph}->get_attribute(UCL::Graph::ATTR_LOAD,
#						$self->{link}->[0],
#						$self->{link}->[1]);
#	$self->_add_attribute_ro('Load (%):', $load);
#    }
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
	my $link= $self->{link};

	foreach my $attribute (keys %{$self->{result}}) {
	    my $value= $self->{result}{$attribute};
	    $graph->set_attribute($attribute, $link->[0], $link->[1], $value);
	}
    }
}
