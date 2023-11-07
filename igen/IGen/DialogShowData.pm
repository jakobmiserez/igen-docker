# ===================================================================
# IGen::DialogShowData
#
# (c) 2005, Networking team
#           Computing Science and Engineering Dept.
#           Université catholique de Louvain
#           Belgium
#
# author Bruno Quoitin (bqu@info.ucl.ac.be)
# date 28/01/2006
# lastdate 28/01/2006
# ===================================================================

package IGen::DialogShowData;

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
    
    $self->SUPER::_init(-title=>"Show data",
			-btn_okcancel);

    # ---| Check arguments |---
    (!defined($self->{args}{-data})) and
	die "-data argument not defined";
    my $data= $self->{args}{-data};

    # ---| Build window |---
    my ($frame, $subframe);
    $self->{Top}{top}=
	$self->{top}->Frame(-relief=>'sunken',
			    -borderwidth=>1
			    )->pack(-side=>'top',
				    -fill=>'both',
				    -expand=>1);
    $subframe= $self->{Top}{top}->Frame()->pack(-side=>'top',
						-fill=>'both',
						-expand=>1);
    my @headers= ();
    my $r= 0;
    foreach (@{$data->[0]}) {
	push @headers, "Column $r";
    }
    my $dataList= $subframe->Scrolled("HList",
				      -header=>1,
				      -columns=>scalar(@headers),
				      -selectbackground=>'lightblue',
				      -background=>'white',
				      -scrollbars=>'osoe',
#				       -command=>[\&_select, $self],
				      )->pack(-expand=>1,
					      -fill=>'both');
    $self->{Top}{LinksList}= $dataList;
    my $column= 0;
    foreach my $header (@headers) {
	$dataList->header('create', $column++,
			  -text=>$header,
			  -borderwidth=>1,
			  -headerbackground=>'gray');
    }
    my $r= 0;
    foreach (@$data) {
	$dataList->add($r);
	for (my $c= 0; $c < @$_; $c++) {
	    $dataList->itemCreate($r, $c, -text=>$_->[$c]);
	    $dataList->itemCreate($r, $c, -text=>$_->[$c]);
	}
	$r++;
    }


    # ---| Build meni-menu |---
#    my $subframe= 
#	$self->{Top}{top}->Frame()->pack(-side=>'top',
#					 -fill=>'x',
#					 -expand=>1);
#    $subframe->Button(-text=>'Plot',
#		      -command=>[\&_stat_plot, $self]
#		      )->pack(-side=>'left');
#    $subframe->Button(-text=>'Save',
#		      -command=>[\&_stat_save, $self]
#		      )->pack(-side=>'left');
#    $subframe->Button(-text=>'Save summary',
#		      -command=>[\&_stat_save_summary, $self]
#		      )->pack(-side=>'left');
}

# -----[ _stat_plot ]------------------------------------------------
#
# -------------------------------------------------------------------
#sub _stat_plot()
#{
#    my ($self)= @_;
#
#    my $tmp_filename= "/tmp/.igen_gnuplot";
#
#    # Open gnuplot options dialog box
#    my $dialog= new IGen::DialogGnuplot(-parent=>$self->{main},
#					%{$self->{args}});
#    my $result= $dialog->show_modal();
#    $dialog->destroy();
#    (!defined($result)) and return;
#
#    # Save statistics into temporary file
#    ($self->_stat_save($tmp_filename, %{$result->{plot}}) < 0) and
#	return;
#
#    # Call gnuplot...
#    my $gnuplot= new IGen::Gnuplot(%{$result->{global}});
#    $gnuplot->add_plot($tmp_filename, %{$result->{plot}},
#		       $self->{args});
#    $gnuplot->plot($result->{global}{-filename});
#}

# -----[ _stat_save ]------------------------------------------------
#
# -------------------------------------------------------------------
#sub _stat_save()
#{
#    my ($self, $filename, %args)= @_;
#
#    my $stat= $self->{args}{-stat};
#
#    save_stat_fdistrib($stat, $filename, %args);
#
#    return 0;
#}

# -----[ _stat_save_summary ]----------------------------------------
#
# -------------------------------------------------------------------
#sub _stat_save_summary()
#{
#    my ($self)= @_;
#}

# -----[ run ]-------------------------------------------------------
#
# -------------------------------------------------------------------
sub run($%)
{
    my ($class, %args)= @_;

    my $dialog= new IGen::DialogShowData(%args);
    my $result= $dialog->show_modal();
    $dialog->destroy();
    return $result;
}
