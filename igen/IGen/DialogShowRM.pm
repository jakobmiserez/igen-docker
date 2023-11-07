# ===================================================================
# IGen::DialogShowRM
#
# (c) 2005, Networking team
#           Computing Science and Engineering Dept.
#           Université catholique de Louvain
#           Belgium
#
# author Bruno Quoitin (bqu@info.ucl.ac.be)
# date 24/07/2005
# lastdate 24/08/2005
# ===================================================================

package IGen::DialogShowRM;

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
    
    $self->SUPER::_init(-title=>"Routing matrix",
			-btn_close);

    # ---| Check arguments |---
    (!defined($self->{args}{-graph})) and die "-graph argument not defined";
    my $graph= $self->{args}{-graph};
    my $RM= $graph->get_attribute('RM');

    # ---| Build window |---
    my $frame=
	$self->{top}->Frame(-relief=>'sunken',
			    -borderwidth=>1
			    )->pack(-side=>'top',
				    -fill=>'both',
				    -expand=>1);
    my @headers= ('Src-Dst', 'Path(s)', 'Length', 'Weight', 'Delay');
    my $routesList= $frame->Scrolled("HList",
				     -header=>1,
				     -columns=>scalar(@headers),
				     -background=>'white',
				     -command=>[\&_select, $self],
				     -scrollbars=>'osoe',
				     )->pack(-expand=>1,
					     -fill=>'both');
    $self->{Top}{RoutesList}= $routesList;
    my $column= 0;
    foreach my $header (@headers) {
	$routesList->header('create', $column++,
			    -text=>$header,
			    -borderwidth=>1,
			    -headerbackground=>'gray');
    }
    my $i= 0;
    my $styleRight= $routesList->ItemStyle('text',
					   -justify=>'right',
					   -padx=>10,
					   -pady=>1);
    my $styleLeft= $routesList->ItemStyle('text',
					  -justify=>'left',
					  -padx=>10,
					  -pady=>1);
    foreach my $u (sort {$a <=> $b} keys %$RM) {
	foreach my $v (sort {$a <=> $b} keys %{$RM->{$u}}) {
	    my $paths= $RM->{$u}->{$v};
	    my $j= 0;
	    foreach my $path (@$paths) {
		my $path_str= (join ',', @$path);
		$routesList->add($i,
				 -data=>$path);
		if ($j == 0) {
		    $routesList->itemCreate($i, 0,
					    -text=>"$u->$v",
					    -style=>$styleLeft);
		}
		$routesList->itemCreate($i, 1,
					-text=>$path_str,
					-style=>$styleLeft);
		my ($hop_cnt, $length, $weight)=
		    UCL::Graph::Base::path_length($graph, $path);
		my $delay= UCL::Graph::Base::distance2delay($length);
		$length= sprintf "%8.2f", $length;
		$weight= sprintf "%8.2f", $weight;
		$delay=  sprintf "%8.2f", $delay;
		$routesList->itemCreate($i, 2,
					-text=>$length,
					-style=>$styleLeft);
		$routesList->itemCreate($i, 3,
					-text=>$weight,
					-style=>$styleLeft);
		$routesList->itemCreate($i, 4,
					-text=>$delay,
					-style=>$styleLeft);
		$i++;
		$j++;
	    }
	}
    }
    
    #$frame->Label(-text=>sprintf("Total volume: %.2f", $total_volume),
    #		  )->pack(-side=>'bottom',
    #			  -expand=>1);
}

# -----[ _select ]---------------------------------------------------
#
# -------------------------------------------------------------------
sub _select()
{
    my ($self, $index)= @_;

    if (exists($self->{args}{-command})) {
	my $fct= $self->{args}{-command};
	my $path= $self->{Top}{RoutesList}->info('data', $index);
	&$fct($path);
    }
}
