# ===================================================================
# IGen::DialogShowTM
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

package IGen::DialogShowTM;

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
    
    $self->SUPER::_init(-title=>"Traffic matrix",
			-btn_close);

    # ---| Check arguments |---
    (!defined($self->{args}{-TM})) and die "-TM argument not defined";
    my $TM= $self->{args}{-TM};

    # ---| Build window |---
    my $frame=
	$self->{top}->Frame(-relief=>'sunken',
			    -borderwidth=>1
			    )->pack(-side=>'top',
				    -fill=>'both',
				    -expand=>1);
    my @headers= ('Src-Dst', 'Volume');
    my $trafficList= $frame->Scrolled("HList",
				   -header=>1,
				   -columns=>scalar(@headers),
				   -background=>'white',
				   -scrollbars=>'osoe',
				   -command=>[\&_select, $self],
				   )->pack(-expand=>1,
					   -fill=>'both');
    $self->{Top}{TrafficList}= $trafficList;
    my $column= 0;
    foreach my $header (@headers) {
	$trafficList->header('create', $column++,
			     -text=>$header,
			     -borderwidth=>1,
			     -headerbackground=>'gray');
    }
    my $r= 0;
    my $styleRight= $trafficList->ItemStyle('text',
					    -justify=>'right',
					    -padx=>0,
					    -pady=>1);
    my $styleLeft= $trafficList->ItemStyle('text',
					   -justify=>'left',
					   -padx=>10,
					   -pady=>1);
    my $total_volume= 0;
    foreach my $u (sort {$a <=> $b} keys %$TM) {
	foreach my $v (sort {$a <=> $b} keys %{$TM->{$u}}) {
	    my $volume= $TM->{$u}->{$v};
		$trafficList->add($r, -data=>[$u, $v]);
	    $trafficList->itemCreate($r, 0,
				     -text=>"$u->$v",
				     -style=>$styleLeft);
	    $trafficList->itemCreate($r, 1,
				     -text=>sprintf("%.2f", $volume),
				     -style=>$styleRight);
	    $r++;
	    $total_volume+= $volume;
	}
    }
    $frame->Label(-text=>sprintf("Total volume: %.2f", $total_volume),
		  )->pack(-side=>'bottom',
			  -expand=>1);
}

# -----[ _select ]---------------------------------------------------
#
# -------------------------------------------------------------------
sub _select()
{
    my ($self, $index)= @_;

    if (exists($self->{args}{-command})) {
	my $fct= $self->{args}{-command};
	my $pair= $self->{Top}{TrafficList}->info('data', $index);
	&$fct($pair);
    }
}
