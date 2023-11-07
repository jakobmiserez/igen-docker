# ===================================================================
# IGen::DialogCluster
#
# (c) 2005, Networking team
#           Computing Science and Engineering Dept.
#           Université catholique de Louvain
#           Belgium
#
# author Bruno Quoitin (bqu@info.ucl.ac.be)
# date 05/07/2005
# lastdate 06/07/2005
# ===================================================================

package IGen::DialogCluster;

require Exporter;
@ISA= qw(Exporter UCL::Tk::Dialog);
@EXPORT_OK= qw(_init);

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
    
    $self->SUPER::_init(-title=>"Clustering",
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
	'k-medoids' => [\&_update_kmedoids, 5],
	'hierarchical-ward' => [\&_update_ward, 5, 100],
	'threshold' => [\&_update_threshold, 0.9, 100],
	'grid' => [\&_update_grid, 10, 5],
	'continental' => undef,
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

# -----[ _update_kmedoids ]------------------------------------------
#
# -------------------------------------------------------------------
sub _update_kmedoids($)
{
    my ($self)= @_;

    $self->{Params}{top}->Label(-text=>'Num. clusters: '
				)->pack(-side=>'left');
    $self->{Params}{top}->Spinbox(-textvariable=>
				  \$self->{result}{params}[0],
				  -from=>1,
				  -to=>100,
				  -increment=>1,
				  )->pack(-side=>'right');
}

# -----[ _update_ward ]----------------------------------------------
#
# -------------------------------------------------------------------
sub _update_ward($)
{
    my ($self)= @_;

    my $subframe;
    $subframe= $self->{Params}{top}->Frame()->pack(-side=>'top',
						   -fill=>'x',
						   -expand=>1);
    $subframe->Label(-text=>'Num. clusters: '
		     )->pack(-side=>'left');
    $subframe->Spinbox(-textvariable=>
		       \$self->{result}{params}[0],
		       -from=>1,
		       -to=>100,
		       -increment=>1,
		       )->pack(-side=>'right');
    $subframe= $self->{Params}{top}->Frame()->pack(-side=>'top',
						   -fill=>'x',
						   -expand=>1);
    $subframe->Label(-text=>'Max. variance: '
		     )->pack(-side=>'left');
    $subframe->Entry(-textvariable=>\$self->{result}{params}[1]
		     )->pack(-side=>'right');
}

# -----[ _update_threshold ]-----------------------------------------
#
# -------------------------------------------------------------------
sub _update_threshold($)
{
    my ($self)= @_;

    my $subframe;
    $subframe= $self->{Params}{top}->Frame()->pack(-side=>'top',
						   -fill=>'x',
						   -expand=>1);
    $subframe->Label(-text=>'Max. weight: '
		     )->pack(-side=>'left');
    $subframe->Entry(-textvariable=>\$self->{result}{params}[0]
		     )->pack(-side=>'right');
    $subframe= $self->{Params}{top}->Frame()->pack(-side=>'top',
						   -fill=>'x',
						   -expand=>1);
    $subframe->Label(-text=>'Max. radius: '
		     )->pack(-side=>'left');
    $subframe->Entry(-textvariable=>\$self->{result}{params}[1]
		     )->pack(-side=>'right');
}

# -----[ _update_grid ]----------------------------------------------
#
# -------------------------------------------------------------------
sub _update_grid($)
{
    my ($self)= @_;

    my $subframe;
    $subframe= $self->{Params}{top}->Frame()->pack(-side=>'top',
						   -fill=>'x',
						   -expand=>1);
    $subframe->Label(-text=>'Num. X-divs: '
		     )->pack(-side=>'left');
    $subframe->Spinbox(-textvariable=>\$self->{result}{params}[0],
		       -from=>1,
		       -to=>100,
		       -increment=>1,
		       )->pack(-side=>'right');
    $subframe= $self->{Params}{top}->Frame()->pack(-side=>'top',
						   -fill=>'x',
						   -expand=>1);
    $subframe->Label(-text=>'Num. Y-divs: '
		     )->pack(-side=>'left');
    $subframe->Spinbox(-textvariable=>\$self->{result}{params}[1],
		       -from=>1,
		       -to=>100,
		       -increment=>1,
		       )->pack(-side=>'right');
}
