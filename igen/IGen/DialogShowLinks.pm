# ===================================================================
# IGen::DialogShowLinks
#
# (c) 2005, Networking team
#           Computing Science and Engineering Dept.
#           Université catholique de Louvain
#           Belgium
#
# author Bruno Quoitin (bqu@info.ucl.ac.be)
# date 24/07/2005
# lastdate 04/10/2005
# ===================================================================

package IGen::DialogShowLinks;

require Exporter;
@ISA= qw(Exporter UCL::Tk::Dialog);

use Tk 800.000;
use Tk::Toplevel;

use strict;
use UCL::Tk::Dialog;
use UCL::Graph::Base;
use IGen::Definitions;
use IGen::DialogLinkProperties;

# -----[ _init ]-----------------------------------------------------
#
# -------------------------------------------------------------------
sub _init()
{
    my ($self)= @_;
    
    $self->SUPER::_init(-title=>"Links",
			-btn_close);

    # ---| Check arguments |---
    (!defined($self->{args}{-graph})) and die "-graph argument not defined";
    $self->{graph}= $self->{args}{-graph};

    # ---| Build window |---
    my $frame=
	$self->{top}->Frame(-relief=>'sunken',
			    -borderwidth=>1
			    )->pack(-side=>'top',
				    -fill=>'both',
				    -expand=>1);
    $self->{Top}{top}= $frame;
    my $subframe= $frame->Frame()->pack(-side=>'top',
					-fill=>'both',
					-expand=>1);
    my @headers= ('From', 'To', 'Type', 'Length (km)', 'Capacity',
		  'Weight', 'Load (%)');
    my $linksList= $subframe->Scrolled("HList",
				       -header=>1,
				       -columns=>scalar(@headers),
				       -selectbackground=>'lightblue',
				       -background=>'white',
				       -scrollbars=>'osoe',
				       -command=>[\&_select, $self],
				       )->pack(-expand=>1,
					       -fill=>'both');
    $self->{Top}{LinksList}= $linksList;
    my $column= 0;
    foreach my $header (@headers) {
	$linksList->header('create', $column++,
			   -text=>$header,
			   -borderwidth=>1,
			   -headerbackground=>'gray');
    }
    my $r= 0;
    my @edges= $self->{graph}->edges();
    $self->{StyleRight}= $linksList->ItemStyle('text',
					       -justify=>'right');
    $self->{StyleLeft}= $linksList->ItemStyle('text',
					      -justify=>'left');
    my @vertices= sort {$a <=> $b} $self->{graph}->vertices();
    for (my $index_u= 0; $index_u < @vertices-1; $index_u++) {
	for (my $index_v= $index_u+1; $index_v < @vertices; $index_v++) {
	    my $u= $vertices[$index_u];
	    my $v= $vertices[$index_v];
	    ($self->{graph}->has_edge($u, $v)) or next;
	    $linksList->add($r, -data=>[$u, $v]);
	    my $u_id= $u;
	    my $u_name= $self->{graph}->get_attribute(UCL::Graph::ATTR_NAME, $u);
	    (defined($u_name)) and $u_id.= " ($u_name)";
	    my $v_id= $v;
	    my $v_name= $self->{graph}->get_attribute(UCL::Graph::ATTR_NAME, $v);
	    (defined($v_name)) and $v_id.= " ($v_name)";
	    $linksList->itemCreate($r, 0,
				   -text=>"$u_id",
				   -style=>$self->{StyleLeft});
	    $linksList->itemCreate($r, 1,
				   -text=>"$v_id",
				   -style=>$self->{StyleLeft});
	    $self->_update_link($r, $u, $v);
	    $r++;
	}
    }
    $frame= $self->{top}->Frame()->pack(-side=>'top',
					-after=>$self->{Top}{top});
    $frame->Button(-text=>'Edit',
		   -command=>[\&_edit_link, $self]
    		  )->pack(-side=>'bottom',
    			  -expand=>1,
			  -fill=>'x');
}

# -----[ _select ]---------------------------------------------------
#
# -------------------------------------------------------------------
sub _select()
{
    my ($self, $index)= @_;

    if (exists($self->{args}{-command})) {
	my $fct= $self->{args}{-command};
	my $link= $self->{Top}{LinksList}->info('data', $index);
	&$fct($link);
    }
}

# -----[ _edit_link ]------------------------------------------------
#
# -------------------------------------------------------------------
sub _edit_link($)
{
    my ($self)= @_;

    my @selected= $self->{Top}{LinksList}->info('selection');
    (!defined(@selected) || (scalar(@selected) > 1)) and return -1;

    my $link= $self->{Top}{LinksList}->info('data', $selected[0]);

    my $dialog= IGen::DialogLinkProperties->new(-parent=>$self->{main},
						-graph=>$self->{graph},
						-link=>$link,
						-capacities=>$self->{args}{-capacities});
    my $result= $dialog->show_modal();
    $dialog->destroy();
    
    (!defined($result)) and return;

    # ---| Update fields for this link |---
    $self->_update_link($selected[0], $link->[0], $link->[1]);
}

# -----[ _update_link ]----------------------------------------------
#
# -------------------------------------------------------------------
sub _update_link($$$$)
{
    my ($self, $row, $u, $v)= @_;

    my $type= 'Internal';
    if ($self->{graph}->has_attribute(UCL::Graph::ATTR_RELATION, $u, $v)) {
	my $relation= $self->{graph}->get_attribute(UCL::Graph::ATTR_RELATION,
						    $u, $v);
	$type= ILINK_RELATIONS->{$relation};
    }
    my $length= UCL::Graph::Base::distance($self->{graph}, $u, $v);
    if (!defined($length)) {
	$length= '--';
    } else {
	$length= sprintf "%.2f", $length;
    }
    my $capacity= '-';
    my $weight= '-';
    my $load= '-';
    if ($self->{graph}->has_attribute(UCL::Graph::ATTR_CAPACITY, $u, $v)) {
	$capacity= $self->{graph}->get_attribute(UCL::Graph::ATTR_CAPACITY, $u, $v);
	$capacity= IGen::Util::capacity2text($capacity);
    }
    if ($self->{graph}->has_attribute(UCL::Graph::ATTR_WEIGHT, $u, $v)) {
	$weight= sprintf "%.2f", $self->{graph}->get_attribute(UCL::Graph::ATTR_WEIGHT, $u, $v);
    }
    if ($self->{graph}->has_attribute(UCL::Graph::ATTR_LOAD, $u, $v)) {
	$load= sprintf "%.2f", $self->{graph}->get_attribute(UCL::Graph::ATTR_LOAD, $u, $v);
    }
    $self->{Top}{LinksList}->itemCreate($row, 2,
					-text=>$type,
					-style=>$self->{StyleLeft});
    $self->{Top}{LinksList}->itemCreate($row, 3,
					-text=>$length,
					-style=>$self->{StyleRight});
    $self->{Top}{LinksList}->itemCreate($row, 4,
					-text=>$capacity,
					-style=>$self->{StyleRight});
    $self->{Top}{LinksList}->itemCreate($row, 5,
					-text=>$weight,
					-style=>$self->{StyleRight});
    $self->{Top}{LinksList}->itemCreate($row, 6,
					-text=>$load,
					-style=>$self->{StyleRight});
}
