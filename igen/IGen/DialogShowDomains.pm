# ===================================================================
# IGen::DialogShowDomains
#
# (c) 2005, Networking team
#           Computing Science and Engineering Dept.
#           Université catholique de Louvain
#           Belgium
#
# author Bruno Quoitin (bqu@info.ucl.ac.be)
# date 18/07/2005
# lastdate 22/09/2005
# ===================================================================

package IGen::DialogShowDomains;

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
    
    $self->SUPER::_init(-title=>"Domains",
			-btn_close);

    my $frame=
	$self->{top}->Frame(-relief=>'sunken',
			    -borderwidth=>1
			    )->pack(-side=>'top',
				    -fill=>'both',
				    -expand=>1);
    $self->{Top}{top}= $frame;
    my @headers= ('AS', 'Routers', 'Links', 'Attributes');
    my $domainsList=
	$frame->Scrolled("HList",
			 -header=>1,
			 -columns=>scalar(@headers),
			 -background=>'white',
			 -scrollbars=>'osoe',
			 -command=>[\&_select, $self],
			 )->pack(-expand=>1,
				 -fill=>'both');
    $self->{Top}{DomainsList}= $domainsList;
    my $column= 0;
    foreach my $header (@headers) {
	$domainsList->header('create', $column++,
			     -text=>$header,
			     -borderwidth=>1,
			     -headerbackground=>'gray');
    }
    my $r= 0;
    my $styleRight= $domainsList->ItemStyle('text',
					    -justify=>'right');
    my $styleLeft= $domainsList->ItemStyle('text',
					   -justify=>'left');
    my $domains= $self->{args}{-domains};
    foreach my $domain (sort keys %$domains) {
	my $graph= $domains->{$domain};
	my $num_routers= scalar($graph->vertices());
	my @edges= $graph->edges();
	my $num_links= scalar(@edges)/2;
	$domainsList->add($r, -data=>$domain);
	$domainsList->itemCreate($r, 0,
				 -text=>$domain,
				 -style=>$styleLeft);
	$domainsList->itemCreate($r, 1,
				 -text=>$num_routers,
				 -style=>$styleLeft);
	$domainsList->itemCreate($r, 2,
				 -text=>$num_links,
				 -style=>$styleLeft);
	# ---| Domain attributes |---
	my $attributes= ' ';
	# ---| Geographical coordinates |---
	if ($graph->has_attribute(UCL::Graph::ATTR_GFX) &&
	    ($graph->get_attribute(UCL::Graph::ATTR_GFX) == 1)) {
	    $attributes.= 'GFX ';
	}
	# ---| Traffic matrix |---
	if ($graph->has_attribute(UCL::Graph::ATTR_TM) &&
	    defined($graph->get_attribute(UCL::Graph::ATTR_TM))) {
	    $attributes.= 'TM ';
	}
	# ---| Routing matrix |---
	if ($graph->has_attribute(UCL::Graph::ATTR_RM) &&
	    defined($graph->get_attribute(UCL::Graph::ATTR_RM))) {
	    $attributes.= 'RM ';
	}
	$domainsList->itemCreate($r, 3,
				 -text=>"{$attributes}",
				 -style=>$styleLeft);
	$r++;
    }
    $frame=
	$self->{top}->Frame()->pack(-side=>'bottom',
				    -after=>$self->{Top}{top});
    $frame->Label(-text=>"Number of domains: ".scalar(keys %$domains),
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
	my $domain= $self->{Top}{DomainsList}->info('data', $index);
	&$fct($domain);
    }
}
