# ===================================================================
# IGen::DialogShowRouters
#
# (c) 2005, Networking team
#           Computing Science and Engineering Dept.
#           Université catholique de Louvain
#           Belgium
#
# author Bruno Quoitin (bqu@info.ucl.ac.be)
# date 26/08/2005
# lastdate 22/09/2005
# ===================================================================

package IGen::DialogShowRouters;

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
    
    $self->SUPER::_init(-title=>"Routers",
			-btn_close);

    # ---| Check arguments |---
    (!defined($self->{args}{-graph})) and die "-graph argument not defined";
    my $graph= $self->{args}{-graph};
    my $domain_id= $graph->get_attribute(UCL::Graph::ATTR_AS);
    
    # ---| Build window |---
    my $frame=
	$self->{top}->Frame(-relief=>'sunken',
			    -borderwidth=>1
			    )->pack(-side=>'top',
				    -fill=>'both',
				    -expand=>1);
    $self->{Top}{top}= $frame;
    my @headers= ('Router', 'Type', 'Long.', 'Lat.', 'Name');
    my $routersList= $frame->Scrolled("HList",
				      -header=>1,
				      -columns=>scalar(@headers),
				      -background=>'white',
 				      -scrollbars=>'osoe',
				      -command=>[\&_select, $self],
				      )->pack(-expand=>1,
					      -fill=>'both');
    $self->{Top}{RoutersList}= $routersList;
    my $column= 0;
    foreach my $header (@headers) {
	$routersList->header('create', $column++,
			     -text=>$header,
			     -borderwidth=>1,
			     -headerbackground=>'gray');
    }
    my $r= 0;
    my $styleRight= $routersList->ItemStyle('text',
					    -justify=>'right');
    my $styleLeft= $routersList->ItemStyle('text',
					   -justify=>'left');
    foreach my $v (sort {$a <=> $b} $graph->vertices()) {
	$routersList->add($r, -data=>[$v, $domain_id]);
	$routersList->itemCreate($r, 0,
				 -text=>"$v",
				 -style=>$styleLeft);
	# ---| Type (backbone/access) |---
	my $type= '--';
	if ($graph->has_attribute(UCL::Graph::ATTR_TYPE, $v)) {
	    $type= $graph->get_attribute(UCL::Graph::ATTR_TYPE, $v);
	}
	# ---| Geographical coordinates |---
	my ($coord_x, $coord_y)= ('--', '--');
	if ($graph->has_attribute(UCL::Graph::ATTR_COORD, $v)) {
	    my $coord= $graph->get_attribute(UCL::Graph::ATTR_COORD, $v);
	    $coord_x= sprintf "%.2f", $coord->[0];
	    $coord_y= sprintf "%.2f", $coord->[1];
	}
	# ---| Name |---
	my $name= '--';
	if ($graph->has_attribute(UCL::Graph::ATTR_NAME, $v)) {
	    $name= $graph->get_attribute(UCL::Graph::ATTR_NAME, $v);
	}
	$routersList->itemCreate($r, 1,
				 -text=>$type,
				 -style=>$styleRight);
	$routersList->itemCreate($r, 2,
				 -text=>$coord_x,
				 -style=>$styleRight);
	$routersList->itemCreate($r, 3,
				 -text=>$coord_y,
				 -style=>$styleRight);
	$routersList->itemCreate($r, 4,
				 -text=>$name,
				 -style=>$styleRight);
	$r++;
    }

    $frame= $self->{top}->Frame()->pack(-side=>'bottom',
					-after=>$self->{Top}{top});
    $frame->Label(-text=>"Number of routers: ".scalar($graph->vertices()),
    		  )->pack(-side=>'top',
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
	my $router= $self->{Top}{RoutersList}->info('data', $index);
	&$fct($router);
    }
}
