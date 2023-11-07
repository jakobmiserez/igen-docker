# ===================================================================
# IGen::DialogInput
#
# (c) 2005, Networking team
#           Computing Science and Engineering Dept.
#           Université catholique de Louvain
#           Belgium
#
# author Bruno Quoitin (bqu@info.ucl.ac.be)
# date 23/08/2005
# lastdate 23/08/2005
# ===================================================================

package IGen::DialogInput;

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

    $self->SUPER::_init(-title=>$self->{args}{-title},
			-btn_okcancel);

    $self->{result}= $self->{args}{-value};

    # ---| Create Label & Entry widgets |---
    my $frame=
	$self->{top}->Frame(-relief=>'sunken',
			    -borderwidth=>1
			    )->pack(-side=>'top',
				    -fill=>'x',
				    -expand=>1);
    $frame->Label(-text=>$self->{args}{-label}
		  )->pack(-expand=>1,
			  -side=>'left');
    my $entry= $frame->Entry(-textvariable=>\$self->{result},
			     )->pack(-side=>'right',
				     -fill=>'x');

    # ---| Bind Entry-widget with check function |---
    $entry->bind('<Any-KeyPress>'=>sub{
	$self->_update_entry();
    });

    $entry->focusForce();

    $self->_update_entry($self->{result});
}

# -----[ _update_entry ]---------------------------------------------
#
# -------------------------------------------------------------------
sub _update_entry($)
{
    my ($self)= @_;
    my $active= 1;

    # ---| Check that entry length is > 0 |---
    if (length($self->{result}) == 0) {
	$active= 0;
    }

    # ---| Call check function if specified |---
    if (exists($self->{args}{-check})) {
	my $fct= $self->{args}{-check};
	if (!&$fct($self->{result})) {
	    $active= 0;
	}
    }

    # ---| Configure OK button accordingly |---
    if ($active) {
	$self->{ButtonOk}->configure(-state=>'active');
    } else {
	$self->{ButtonOk}->configure(-state=>'disabled');
    }
}

# -----[ run ]-------------------------------------------------------
# TODO: SHOULD BE MOVED in <<UCL::Tk::Dialog>>, NO ?
# -------------------------------------------------------------------
sub run($%)
{
    my (%args)= @_;

    my $dialog= IGen::DialogInput->new(-parent=>$args{-parent},
				       %args);
    my $result= $dialog->show_modal();
    $dialog->destroy();
    return $result;
}
