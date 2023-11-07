# ===================================================================
# IGen::DialogProperties
#
# (c) 2005, Networking team
#           Computing Science and Engineering Dept.
#           Université catholique de Louvain
#           Belgium
#
# author Bruno Quoitin (bqu@info.ucl.ac.be)
# date 01/09/2005
# lastdate 05/10/2005
# ===================================================================

package IGen::DialogProperties;

require Exporter;
@ISA= qw(Exporter UCL::Tk::Dialog);

use Tk 800.000;
use Tk::Toplevel;

use strict;
use UCL::Tk::Dialog;

# -----[ _add_attribute_ro ]-----------------------------------------
#
# -------------------------------------------------------------------
sub _add_attribute_ro($$)
{
    my ($self, $name, $value)= @_;

    my $subframe= $self->{Top}{top}->Frame()->pack(-side=>'top',
						   -fill=>'x',
						   -expand=>1);
    $subframe->Label(-text=>$name,
		     )->pack(-side=>'left');
    return $subframe->Entry(-textvariable=>\$value,
			    -state=>'readonly'
			    )->pack(-side=>'right');
}

# -----[ _add_attribute_header ]-------------------------------------
#
# -------------------------------------------------------------------
sub _add_attribute_header($$)
{
    my ($self, $header)= @_;

    my $subframe=
	$self->{Top}{top}->Frame()->pack(-side=>'top',
					 -fill=>'x',
					 -expand=>1);
    return $subframe->Label(-relief=>'sunken',
			    -borderwidth=>0,
			    -text=>$header,
			    -background=>'darkgray',
			    )->pack(-expand=>1,
				    -fill=>'x');
}

# -----[ _add_attribute_check ]--------------------------------------
#
# -------------------------------------------------------------------
sub _add_attribute_check($$$;%)
{
    my ($self, $name, $variable, %args)= @_;

    my $subframe= 
	$self->{Top}{top}->Frame()->pack(-side=>'top',
					 -fill=>'x',
					 -expand=>1);
    return $subframe->Checkbutton(-text=>$name,
				  -variable=>$variable,
				  %args
				  )->pack(-side=>'left');
}

# -----[ _add_attribute_options ]------------------------------------
#
# -------------------------------------------------------------------
sub _add_attribute_options($$$$;%)
{
    my ($self, $name, $variable, $options, %args)= @_;

    my $subframe= 
	$self->{Top}{top}->Frame()->pack(-side=>'top',
					 -fill=>'x',
					 -expand=>1);
    $subframe->Label(-text=>$name,
		     )->pack(-side=>'left');
    return $subframe->Optionmenu(-options=>$options,
				 -variable=>$variable,
				 %args
				 )->pack(-side=>'right');
}

# -----[ _add_attribute_filename ]-----------------------------------
#
# -------------------------------------------------------------------
sub _add_attribute_filename($$$)
{
    my ($self, $name, $variable)= @_;

    my $subframe= 
	$self->{Top}{top}->Frame()->pack(-side=>'top',
					 -fill=>'x',
					 -expand=>1);
    $subframe->Label(-text=>$name,
		     )->pack(-side=>'left',
			     -fill=>'x');
    $subframe->Button(-text=>'...',
		      -command=>[\&_update_filename, $self, $variable],
		      )->pack(-side=>'right',
			      -fill=>'x');
    return $subframe->Entry(-textvariable=>$variable
			    )->pack(-side=>'right',
				    -fill=>'x');
}

# -----[ _update_filename ]------------------------------------------
#
# -------------------------------------------------------------------
sub _update_filename($$)
{
    my ($self, $variable)= @_;

    my $filename= $self->{top}->getSaveFile(-filetypes=>[['CBGP', '.cli']]);
    return if (!defined($filename));
    $$variable= $filename;
}


# -----[ _init ]-----------------------------------------------------
#
# -------------------------------------------------------------------
sub _init()
{
    my ($self, %args)= @_;
    
    $self->SUPER::_init(%args,
			-btn_okcancel);

    # ---| Build dialog box |---
    my $frame;

    $self->{Top}{top}=
	$self->{top}->Frame(-relief=>'sunken',
			    -borderwidth=>1
			    )->pack(-side=>'top',
				    -fill=>'x',
				    -expand=>1);
}
