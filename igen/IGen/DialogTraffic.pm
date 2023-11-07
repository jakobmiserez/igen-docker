# ===================================================================
# IGen::DialogTraffic
#
# (c) 2005, Networking team
#           Computing Science and Engineering Dept.
#           Université catholique de Louvain
#           Belgium
#
# author Bruno Quoitin (bqu@info.ucl.ac.be)
# date 05/07/2005
# lastdate 19/07/2005
# ===================================================================

package IGen::DialogTraffic;

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

    $self->SUPER::_init(-title=>"Traffic generator",
			-btn_okcancel);

    if (!defined($self->{result})) {
	$self->{result}{method}= 'fixed';
	$self->{result}{params}[0]= '100K';
    }

    # define available methods and their default parameters
    # [ <update_fct>, <param_1>, ..., <param_n> ]
    $self->{methods}= {
	'fixed' => [\&_update_fixed, '100K'],
	'rand-uniform' => [\&_update_rand_uniform, '33M', '155M'],
	'rand-pareto' => [\&_update_rand_pareto, 1, 1, '10M'],
    };

    $self->{Top}{top}=
	$self->{top}->Frame(-relief=>'sunken',
			    -borderwidth=>1
			    )->pack(-side=>'top', -fill=>'x');
    $self->{Top}{top}->Label(-text=>'Method:'
			     )->pack(-side=>'left');
    my @options= sort keys %{$self->{methods}};
    $self->{Top}{top}->Optionmenu(-options=>\@options,
				  -command=>[\&_update_dialog, $self],
				  -textvariable=>\$self->{result}{method},
				  )->pack(-side=>'right');

    # update dialog box with currently selected 'method'
    $self->_update_dialog($self->{result}{method});
}

# -----[ _update_dialog ]--------------------------------------------
# Update the dialog box depending on the 'method' selected in the
# option-menu.
# -------------------------------------------------------------------
sub _update_dialog()
{
    my ($self, $textvariable)= @_;

    # check if the selected method has changed (cache)
    ($textvariable eq $self->{Params}{method}) and return;
    $self->{Params}{method}= $textvariable;

    # withdraw previous frame
    if (exists($self->{Params}{top})) {
	$self->{Params}{top}->packForget();
	$self->{Params}{top}->destroy();
	delete($self->{Params});
	$self->{top}->update();
	$self->{result}{params}= [];
    }

    # check that selected method is defined
    (!exists($self->{methods}{$self->{result}{method}})) and
	die "Unknown method $self->{result}{method}";
    
    # build new frame
    $self->{Params}{top}=
	$self->{top}->Frame(-relief=>'sunken',
			    -borderwidth=>1,
			    );

    # add widgets depending on the selected 'method'
    if (defined($self->{methods}{$self->{result}{method}})) {
	my @params= @{$self->{methods}{$self->{result}{method}}};
	my $update_fct= shift @params;
	if (!defined($self->{result}{params}) ||
	    (scalar(@{$self->{result}{params}}) <
	     scalar(@params))) {
	    $self->{result}{params}= \@params;
	}
	&$update_fct($self);
    } else {
	$self->{Params}{top}->configure(-label=>'No parameter');
    }

    # pack frame
    $self->{top}->update();
    $self->{Params}{top}->pack(-side=>'top',
			       -expand=>1,
			       -after=>$self->{Top}{top},
			       -fill=>'both',
			       );
}

# -----[ _update_fixed ]---------------------------------------------
#
# -------------------------------------------------------------------
sub _update_fixed()
{
    my ($self)= @_;

    my $subframe;
    $subframe= $self->{Params}{top}->Frame()->pack(-side=>'top',
						   -fill=>'x',
						   -expand=>1);
    $subframe->Label(-text=>'Demand:'
		     )->pack(-side=>'left');
    $subframe->Entry(-textvariable=>\$self->{result}{params}[0]
		     )->pack(-side=>'right');
}

# -----[ _update_rand_uniform ]--------------------------------------
#
# -------------------------------------------------------------------
sub _update_rand_uniform()
{
    my ($self)= @_;

    my $subframe;
    $subframe= $self->{Params}{top}->Frame()->pack(-side=>'top',
						   -fill=>'x',
						   -expand=>1);
    $subframe->Label(-text=>'Min. bandwidth:'
		     )->pack(-side=>'left');
    $subframe->Entry(-textvariable=>\$self->{result}{params}[0]
		     )->pack(-side=>'right');
    $subframe= $self->{Params}{top}->Frame()->pack(-side=>'top',
						   -fill=>'x',
						   -expand=>1);
    $subframe->Label(-text=>'Max. bandwidth:'
		     )->pack(-side=>'left');
    $subframe->Entry(-textvariable=>\$self->{result}{params}[1]
		     )->pack(-side=>'right');
}

# -----[ _update_rand_pareto ]---------------------------------------
#
# -------------------------------------------------------------------
sub _update_rand_pareto()
{
    my ($self)= @_;

    my $subframe;
    $subframe= $self->{Params}{top}->Frame()->pack(-side=>'top',
						   -fill=>'x',
						   -expand=>1);
    $subframe->Label(-text=>'Shape:'
		     )->pack(-side=>'left');
    $subframe->Entry(-textvariable=>\$self->{result}{params}[0]
		     )->pack(-side=>'right');
    $subframe= $self->{Params}{top}->Frame()->pack(-side=>'top',
						   -fill=>'x',
						   -expand=>1);
    $subframe->Label(-text=>'Scale:'
		     )->pack(-side=>'left');
    $subframe->Entry(-textvariable=>\$self->{result}{params}[1]
		     )->pack(-side=>'right');
    $subframe= $self->{Params}{top}->Frame()->pack(-side=>'top',
						   -fill=>'x',
						   -expand=>1);
    $subframe->Label(-text=>'Demand:'
		     )->pack(-side=>'left');
    $subframe->Entry(-textvariable=>\$self->{result}{params}[2]
		     )->pack(-side=>'right');
}
