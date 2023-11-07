# ===================================================================
# IGen::DialogGraph
#
# (c) 2005, Networking team
#           Computing Science and Engineering Dept.
#           Université catholique de Louvain
#           Belgium
#
# author Bruno Quoitin (bqu@info.ucl.ac.be)
# date 06/07/2005
# lastdate 06/07/2005
# ===================================================================

package IGen::DialogGraph;

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
    
    $self->SUPER::_init(-title=>"Graph",
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
	'clique' => undef,
	'delaunay' => undef,
	'harary' => [\&_update_harary, 2],
	'mentor' => [\&_update_mentor, 0.3],
	'multi-tours' => [\&_update_multitours, 3],
	'mst' => undef,
	'node-linking' => undef,
	'sprint' => [\&_update_sprint, 2, 2],
	'spt' => undef,
	'tsp' => [\&_update_tsp, 0],
	'two-trees' => undef,
	'waxman' => [\&_update_waxman, 0.15, 0.2, 2],
    };

    $self->{Top}{top}=
	$self->{top}->Frame(-relief=>'sunken',
			    -borderwidth=>1
			    )->pack(-side=>'top',
				    -fill=>'x',
				    -expand=>1);
    $self->{Top}{top}->Label(-text=>"Method"
			     )->pack(-side=>'left',
				     -fill=>'x');
    my @options= sort keys %{$self->{methods}};
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

# -----[ _update_harary ]--------------------------------------------
#
# -------------------------------------------------------------------
sub _update_harary($)
{
    my ($self)= @_;

    $self->{Params}{top}->Label(-text=>'K: '
				)->pack(-side=>'left');
    $self->{Params}{top}->Entry(-textvariable=>\$self->{result}{params}[0]
				)->pack(-side=>'right');
}

# -----[ _update_mentor ]--------------------------------------------
#
# -------------------------------------------------------------------
sub _update_mentor($)
{
    my ($self)= @_;

    $self->{Params}{top}->Label(-text=>'Alpha: '
				)->pack(-side=>'left',
					-expand=>1);
    $self->{Params}{top}->Entry(-textvariable=>\$self->{result}{params}[0]
				)->pack(-side=>'right',
					-expand=>1);
}

# -----[ _update_multitours ]----------------------------------------
#
# -------------------------------------------------------------------
sub _update_multitours($)
{
    my ($self)= @_;

    $self->{Params}{top}->Label(-text=>'Num. tours: '
				)->pack(-side=>'left',
					-expand=>1);
    $self->{Params}{top}->Entry(-textvariable=>\$self->{result}{params}[0]
				)->pack(-side=>'right',
					-expand=>1);
}

# -----[ _update_sprint ]--------------------------------------------
#
# -------------------------------------------------------------------
sub _update_sprint($)
{
    my ($self)= @_;

    my $subframe;
    $subframe= $self->{Params}{top}->Frame()->pack(-side=>'top',
						   -fill=>'x',
						   -expand=>1);
    $subframe->Label(-text=>'Num. BB routers: '
		     )->pack(-side=>'left');
    $subframe->Spinbox(-from=>1,
		       -to=>10,
		       -textvariable=>\$self->{result}{params}[0]
		       )->pack(-side=>'right');
    $subframe= $self->{Params}{top}->Frame()->pack(-side=>'top',
						   -fill=>'x',
						   -expand=>1);
    $subframe->Label(-text=>'Num. access-BB links: ',
		     )->pack(-side=>'left');
    $subframe->Spinbox(-from=>1,
		       -to=>10,
		       -textvariable=>\$self->{result}{params}[1]
		       )->pack(-side=>'right');
}

# -----[ _update_tsp ]-----------------------------------------------
#
# -------------------------------------------------------------------
sub _update_tsp($)
{
    my ($self)= @_;

    my $subframe;
    $subframe= $self->{Params}{top}->Frame()->pack(-side=>'top',
						   -fill=>'x',
						   -expand=>1);
    $subframe->Label(-text=>'Heuristic: '
		     )->pack(-expand=>1);
    my $options= [['nearest-neighbor', 0],
		  ['furthest-neighbor', 1]];
    $subframe->Optionmenu(-options=>$options,
			  -variable=>\$self->{result}{params}[0]
			  )->pack(-expand=>1);
}

# -----[ _update_waxman ]--------------------------------------------
#
# -------------------------------------------------------------------
sub _update_waxman($)
{
    my ($self)= @_;

    my $subframe;
    $subframe= $self->{Params}{top}->Frame()->pack(-side=>'top',
						   -fill=>'x',
						   -expand=>1);
    $subframe->Label(-text=>'Alpha: '
		     )->pack(-side=>'left');
    $subframe->Entry(-textvariable=>\$self->{result}{params}[0]
		     )->pack(-side=>'right');
    $subframe= $self->{Params}{top}->Frame()->pack(-side=>'top',
						   -fill=>'x',
						   -expand=>1);
    $subframe->Label(-text=>"Beta"
		     )->pack(-side=>'left');
    $subframe->Entry(-textvariable=>\$self->{result}{params}[1]
		     )->pack(-side=>'right');
    $subframe= $self->{Params}{top}->Frame()->pack(-side=>'top',
						   -fill=>'x',
						   -expand=>1);
    $subframe->Label(-text=>'M: '
		     )->pack(-side=>'left');
    $subframe->Spinbox(-from=>1,
		       -to=>10,
		       -textvariable=>\$self->{result}{params}[2]
		       )->pack(-side=>'right');
}
