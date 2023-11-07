# ===================================================================
# IGen::DialogGnuplot
#
# (c) 2005, Networking team
#           Computing Science and Engineering Dept.
#           Université catholique de Louvain
#           Belgium
#
# author Bruno Quoitin (bqu@info.ucl.ac.be)
# date 21/09/2005
# lastdate 28/11/2005
# ===================================================================

package IGen::DialogGnuplot;

require Exporter;
@ISA= qw(Exporter UCL::Tk::Dialog);

use Tk 800.000;
use Tk::Toplevel;

use strict;
use UCL::Tk::Dialog;
use UCL::Graph::Base;

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
    $subframe->Label(-relief=>'sunken',
		     -borderwidth=>0,
		     -text=>$header,
		     -background=>'darkgray',
		     )->pack(-expand=>1,
			     -fill=>'x');
}

# -----[ _add_attribute_check ]--------------------------------------
#
# -------------------------------------------------------------------
sub _add_attribute_check()
{
    my ($self, $name, $variable)= @_;

    my $subframe= 
	$self->{Top}{top}->Frame()->pack(-side=>'top',
					 -fill=>'x',
					 -expand=>1);
    $subframe->Checkbutton(-text=>$name,
			   -variable=>$variable,
			   )->pack(-side=>'left');
}

# -----[ _add_attribute_entry ]--------------------------------------
#
# -------------------------------------------------------------------
sub _add_attribute_entry()
{
    my ($self, $name, $variable)= @_;

    my $subframe= 
	$self->{Top}{top}->Frame()->pack(-side=>'top',
					 -fill=>'x',
					 -expand=>1);
    $subframe->Label(-text=>$name,
		     )->pack(-side=>'left');
    $subframe->Entry(-textvariable=>$variable,
		     )->pack(-side=>'right');
}

# -----[ _add_attribute_options ]------------------------------------
#
# -------------------------------------------------------------------
sub _add_attribute_options()
{
    my ($self, $name, $variable, $options)= @_;

    my $subframe= 
	$self->{Top}{top}->Frame()->pack(-side=>'top',
					 -fill=>'x',
					 -expand=>1);
    $subframe->Label(-text=>$name,
		     )->pack(-side=>'left');
    $subframe->Optionmenu(-options=>$options,
			  -variable=>$variable,
			  )->pack(-side=>'right');
}

# -----[ _add_attribute_filename ]-----------------------------------
#
# -------------------------------------------------------------------
sub _add_attribute_filename()
{
    my ($self, $name, $variable, $open_mode)= @_;

    my $subframe= 
	$self->{Top}{top}->Frame()->pack(-side=>'top',
					 -fill=>'x',
					 -expand=>1);
    $subframe->Label(-text=>$name,
		     )->pack(-side=>'left');
    $subframe->Button(-text=>'...',
		      -command=>[\&_update_filename, $self, $open_mode,
				 $variable],
		      )->pack(-side=>'right',
			      -fill=>'x');
    $subframe->Entry(-textvariable=>$variable,
		     -state=>'disabled',
		     )->pack(-side=>'right',
			     -fill=>'x');
}

# -----[ _add_attribute_range ]--------------------------------------
#
# -------------------------------------------------------------------
sub _add_attribute_range()
{
    my ($self, $name, $variable_low, $variable_high)= @_;

    my $subframe= 
	$self->{Top}{top}->Frame()->pack(-side=>'top',
					 -fill=>'x',
					 -expand=>1);
    $subframe->Label(-text=>$name,
		     )->pack(-side=>'left');
    my $highEntry=
	$subframe->Entry(-textvariable=>$variable_high,
			 -width=>5,
			 )->pack(-side=>'right');
    $subframe->Entry(-textvariable=>$variable_low,
		     -width=>5,
		     )->pack(-after=>$highEntry);
}

# -----[ _update_filename ]------------------------------------------
sub _update_filename()
{
    my ($self, $open_mode, $variable)= @_;
    my $filename;

    if ($open_mode) {
	$filename= $self->{top}->getOpenFile();
    } else {
	$filename= $self->{top}->getSaveFile();
    }
    (!defined($filename)) and return;
    $$variable= $filename;
}

# -----[ _init ]-----------------------------------------------------
#
# -------------------------------------------------------------------
sub _init()
{
    my ($self)= @_;
    
    $self->SUPER::_init(-title=>"Gnuplot parameters",
			-btn_okcancel);

    # ---| Local gnuplot options |---
    $self->{result}{plot}{-style}= 'lp';
    $self->{result}{plot}{-title}= '';
    $self->{result}{plot}{-cumulative}= 0;
    $self->{result}{plot}{-relative}= 0;
    $self->{result}{plot}{-inverse}= 0;

    # ---| Global gnuplot options |---
    $self->{result}{global}{-filename}= undef;
    $self->{result}{global}{-term}= undef;
    $self->{result}{global}{-xlabel}= '';
    $self->{result}{global}{-xrange}= ['*', '*'];
    $self->{result}{global}{-xlogscale}= 0;
    $self->{result}{global}{-ylabel}= '';
    $self->{result}{global}{-yrange}= ['*', '*'];
    $self->{result}{global}{-ylogscale}= 0;
    $self->{result}{global}{-grid}= 0;

    # ---| Override with options |---
    (defined($self->{args}{-title})) and
	$self->{result}{plot}{-title}= $self->{args}{-title};
    (defined($self->{args}{-xlabel})) and
	$self->{result}{global}{-xlabel}= $self->{args}{-xlabel};
    (defined($self->{args}{-xrange})) and
	$self->{result}{global}{-xrange}= $self->{args}{-xrange};
    (defined($self->{args}{-ylabel})) and
	$self->{result}{global}{-ylabel}= $self->{args}{-ylabel};
    (defined($self->{args}{-yrange})) and
	$self->{result}{global}{-yrange}= $self->{args}{-yrange};
    (defined($self->{args}{-cumulative})) and
	$self->{result}{plot}{-cumulative}= $self->{args}{-cumulative};
    (defined($self->{args}{-inverse})) and
	$self->{result}{plot}{-inverse}= $self->{args}{-inverse};
    (defined($self->{args}{-relative})) and
	$self->{result}{plot}{-relative}= $self->{args}{-relative};

    # ---| Build window |---
    my ($frame, $subframe);
    $self->{Top}{top}=
	$self->{top}->Frame(-relief=>'sunken',
			    -borderwidth=>1
			    )->pack(-side=>'top',
				    -fill=>'both',
				    -expand=>1);

    # ---| GLobal options |---
    $self->_add_attribute_header('Global options');
    $self->_add_attribute_filename('Output file:',
				   \$self->{result}{global}{-filename},
				   0);
    $self->_add_attribute_options('Output type:',
				  \$self->{result}{global}{-term},
				  [['eps 24', 'postscript eps "Helvetica" 24'],
				   ['eps 20', 'postscript eps "Helvetica" 20'],
				   'png medium',
				   'png large']);
    $self->_add_attribute_entry('X-label:',
				\$self->{result}{global}{-xlabel});
    $self->_add_attribute_range('X-range:',
				\$self->{result}{global}{-xrange}->[0],
				\$self->{result}{global}{-xrange}->[1]);
    $self->_add_attribute_check('X-logscale',
				\$self->{result}{global}{-xlogscale});
    $self->_add_attribute_entry('Y-label:',
				\$self->{result}{global}{-ylabel});
    $self->_add_attribute_range('Y-range:',
				\$self->{result}{global}{-yrange}->[0],
				\$self->{result}{global}{-yrange}->[1]);
    $self->_add_attribute_check('Y-logscale',
				\$self->{result}{global}{-ylogscale});
    $self->_add_attribute_check('Show grid',
				\$self->{result}{global}{-grid});

    # ---| Plot options |---
    $self->_add_attribute_header('Plot options');
    $self->_add_attribute_options('Style:',
				  \$self->{result}{plot}{-style},
				  ['lines', 'points', 'boxes', 'linespoints']);
    $self->_add_attribute_entry('Title:',
				\$self->{result}{plot}{-title});
    $self->_add_attribute_check('Cumulative',
				\$self->{result}{plot}{-cumulative});
    $self->_add_attribute_check('Relative',
				\$self->{result}{plot}{-relative});
    $self->_add_attribute_check('Inverse',
				\$self->{result}{plot}{-inverse});
}
