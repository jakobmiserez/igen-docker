# ===================================================================
# IGen::DialogCapacity
#
# (c) 2005, Networking team
#           Computing Science and Engineering Dept.
#           Université catholique de Louvain
#           Belgium
#
# author Bruno Quoitin (bqu@info.ucl.ac.be)
# date 06/07/2005
# lastdate 18/07/2005
# ===================================================================

package IGen::DialogCapacity;

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
    
    $self->SUPER::_init(-title=>"Capacity",
			-btn_okcancel);

    # parse 'method' specification (if it exists)
    if (exists($self->{args}{-method})) {
	my @fields= split /\:/, $self->{args}{-method};
	$self->{result}{method}= shift @fields;
	$self->{result}{params}= \@fields;
    }

    if (!defined($self->{result})) {
	$self->{result}{method}= undef;
	$self->{result}{params}= [];
    }

    # define available methods and their default parameters
    # [ <update_fct>, <param_1>, ..., <param_n> ]
    $self->{methods}= {
	'<none>' => undef,
	'fixed' => [\&_update_fixed, '2.4G'],
	'rand-uniform' => [\&_update_rand_uniform, '33M', '10G'],
	'access-backbone' => [\&_update_access_backbone, '155M', '10G'],
	'load' => [\&_update_load, undef, 50, 1, 0],
    };

    $self->{Top}{top}=
	$self->{top}->Frame(-relief=>'sunken',
			    -borderwidth=>1
			    )->pack(-side=>'top',
				    -fill=>'x',
				    -expand=>1);
    $self->{Top}{top}->Label(-text=>'Method:'
			     )->pack(-side=>'left',
				     -fill=>'x');
    my @options= keys %{$self->{methods}};
    $self->{Top}{top}->Optionmenu(-options=>\@options,
				  -command=>[\&_update_dialog, $self],
				  -textvariable=>\$self->{result}{method},
				  )->pack(-side=>'right',
					  -fill=>'x');

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
sub _update_fixed($)
{
    my ($self)= @_;

    $self->{Params}{top}->Label(-text=>'Capacity:'
				)->pack(-side=>'left',
					-expand=>1);
    $self->{Params}{top}->Entry(-textvariable=>\$self->{result}{params}[0]
				)->pack(-side=>'right',
					-expand=>1);
}

# -----[ _update_rand_uniform ]--------------------------------------
#
# -------------------------------------------------------------------
sub _update_rand_uniform($)
{
    my ($self)= @_;

    my $subframe;
    $subframe= $self->{Params}{top}->Frame()->pack(-side=>'top',
						   -fill=>'x',
						   -expand=>1);
    $subframe->Label(-text=>'Min Capacity:'
		     )->pack(-side=>'left');
    $subframe->Entry(-textvariable=>\$self->{result}{params}[0]
		     )->pack(-side=>'right');
    $subframe= $self->{Params}{top}->Frame()->pack(-side=>'top',
						   -fill=>'x',
						   -expand=>1);
    $subframe->Label(-text=>'Max Capacity:'
		     )->pack(-side=>'left');
    $subframe->Entry(-textvariable=>\$self->{result}{params}[1]
		     )->pack(-side=>'right');
}

# -----[ _update_load ]----------------------------------------------
#
# -------------------------------------------------------------------
sub _update_load($)
{
    my ($self)= @_;

    my $subframe;
    $subframe= $self->{Params}{top}->Frame()->pack(-side=>'top',
						   -fill=>'x',
						   -expand=>1);
    $subframe->Label(-text=>'Traffic matrix:'
		     )->pack(-side=>'left');
#    $subframe->Entry(-textvariable=>\$self->{result}{params}[0]
#		     )->pack(-side=>'right');
#    $self->{Params}{top}->Optionmenu(-options=>[]
#				     -textvariable=>\$self->{result}{params}[0]
#				     )->pack(-expand=>1);
    $subframe= $self->{Params}{top}->Frame()->pack(-side=>'top',
						   -fill=>'x',
						   -expand=>1);
    $subframe->Label(-text=>'Maximum load:'
		     )->pack(-side=>'left');
    $subframe->Entry(-textvariable=>\$self->{result}{params}[1]
		     )->pack(-side=>'right');
    $subframe= $self->{Params}{top}->Frame()->pack(-side=>'top',
						   -fill=>'x',
						   -expand=>1);
    $subframe->Checkbutton(-text=>'Allow ECMP',
			   -variable=>\$self->{result}{params}[2]
			   )->pack(-side=>'left');
    $subframe= $self->{Params}{top}->Frame()->pack(-side=>'top',
						   -fill=>'x',
						   -expand=>1);
    $subframe->Checkbutton(-text=>'Single-link failures',
			   -variable=>\$self->{result}{params}[3],
			   -state=>'disabled'
			   )->pack(-side=>'left');
}

# -----[ _update_access_backbone ]-----------------------------------
#
# -------------------------------------------------------------------
sub _update_access_backbone($)
{
    my ($self)= @_;

    my $subframe;
    $subframe= $self->{Params}{top}->Frame()->pack(-side=>'top',
						   -fill=>'x',
						   -expand=>1);
    $subframe->Label(-text=>'Access capacity:'
		     )->pack(-side=>'left');
    $subframe->Entry(-textvariable=>\$self->{result}{params}[0]
		     )->pack(-side=>'right');
    $subframe= $self->{Params}{top}->Frame()->pack(-side=>'top',
						   -fill=>'x',
						   -expand=>1);
    $subframe->Label(-text=>'Backbone capacity:'
		     )->pack(-side=>'left');
    $subframe->Entry(-textvariable=>\$self->{result}{params}[1]
		     )->pack(-side=>'right');
}
