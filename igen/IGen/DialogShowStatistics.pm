# ===================================================================
# IGen::DialogShowStatistics
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

package IGen::DialogShowStatistics;

require Exporter;
@ISA= qw(Exporter UCL::Tk::Dialog IGen::DialogProperties);

use Tk 800.000;
use Tk::Toplevel;

use strict;
use UCL::Graph::Base;
use IGen::DialogGnuplot;
use IGen::DialogProperties;
use IGen::Gnuplot;
use IGen::Util;

# -----[ _init ]-----------------------------------------------------
#
# -------------------------------------------------------------------
sub _init()
{
    my ($self)= @_;
    
    $self->SUPER::_init(-title=>"Show statistics",
			-btn_okcancel);

    # ---| Check arguments |---
    (!defined($self->{args}{-stat})) and
	die "-stat argument not defined";
    my $stat= $self->{args}{-stat};

    # ---| Build window |---
    my ($frame, $subframe);
    $self->{Top}{top}=
	$self->{top}->Frame(-relief=>'sunken',
			    -borderwidth=>1
			    )->pack(-side=>'top',
				    -fill=>'both',
				    -expand=>1);
    $self->_add_attribute_header($self->{args}{-title});
    $self->_add_attribute_ro('Mean   :', $stat->mean());
    $self->_add_attribute_ro('Std-dev:', $stat->standard_deviation());
    $self->_add_attribute_ro('Minimum:', $stat->min());
    $self->_add_attribute_ro('Maximum:', $stat->max());
    $self->_add_attribute_ro('Median :', $stat->median());
    $self->_add_attribute_ro('Perc-20:', $stat->percentile(20));
    $self->_add_attribute_ro('Perc-80:', $stat->percentile(80));

    # ---| Build meni-menu |---
    my $subframe= 
	$self->{Top}{top}->Frame()->pack(-side=>'top',
					 -fill=>'x',
					 -expand=>1);
    $subframe->Button(-text=>'Plot',
		      -command=>[\&_stat_plot, $self]
		      )->pack(-side=>'left');
    $subframe->Button(-text=>'Save',
		      -command=>[\&_stat_save, $self]
		      )->pack(-side=>'left');
    $subframe->Button(-text=>'Save summary',
		      -command=>[\&_stat_save_summary, $self]
		      )->pack(-side=>'left');
}

# -----[ _stat_plot ]------------------------------------------------
#
# -------------------------------------------------------------------
sub _stat_plot()
{
    my ($self)= @_;

    my $tmp_filename= "/tmp/.igen_gnuplot";

    # Open gnuplot options dialog box
    my $dialog= new IGen::DialogGnuplot(-parent=>$self->{main},
					%{$self->{args}});
    my $result= $dialog->show_modal();
    $dialog->destroy();
    (!defined($result)) and return;

    # Save statistics into temporary file
    ($self->_stat_save($tmp_filename, %{$result->{plot}}) < 0) and
	return;

    # Call gnuplot...
    my $gnuplot= new IGen::Gnuplot(%{$result->{global}});
    $gnuplot->add_plot($tmp_filename, %{$result->{plot}},
		       $self->{args});
    $gnuplot->plot($result->{global}{-filename});
}

# -----[ _stat_save ]------------------------------------------------
#
# -------------------------------------------------------------------
sub _stat_save()
{
    my ($self, $filename, %args)= @_;

    my $stat= $self->{args}{-stat};

    save_stat_fdistrib($stat, $filename, %args);

    return 0;
}

# -----[ _stat_save_summary ]----------------------------------------
#
# -------------------------------------------------------------------
sub _stat_save_summary()
{
    my ($self)= @_;
}

# -----[ run ]-------------------------------------------------------
#
# -------------------------------------------------------------------
sub run($%)
{
    my ($class, %args)= @_;

    my $dialog= new IGen::DialogShowStatistics(%args);
    my $result= $dialog->show_modal();
    $dialog->destroy();
    return $result;
}
