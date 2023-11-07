# ===================================================================
# UCL::Tk::Dialog
#
# (c) 2005, Networking team
#           Computing Science and Engineeding Dept.
#           Université catholique de Louvain
#           Belgium
#
# author Bruno Quoitin (bqu@info.ucl.ac.be)
# date 05/07/2005
# lastdate 24/08/2005
# ===================================================================

package UCL::Tk::Dialog;

require Exporter;
@ISA= qw(Exporter);
@EXPORT_OK= qw(new destroy show_modal);

use Tk 800.000;
use Tk::Toplevel;

use strict;

# -----[ new ]-------------------------------------------------------
#
# -------------------------------------------------------------------
sub new(%)
{
    my ($class, %args)= @_;
    my $main= $args{-parent};
    my $self= {
	args => \%args,
	main => $main,
	top => $main->Toplevel(),
	semaphore => 0,
	result => undef,
    };
    bless $self, $class;
    $self->{top}->withdraw();
    $self->{top}->resizable(0,0);
    $self->{top}->transient($self->{top}->Parent->toplevel);
    $self->{top}->protocol('WM_DELETE_WINDOW'=>sub{});

    $self->_init();

    return $self;
}

# -----[ destroy ]---------------------------------------------------
#
# -------------------------------------------------------------------
sub destroy()
{
    my ($self)= @_;

    $self->{top}->destroy();
}

# -----[ show_modal ]------------------------------------------------
# Shows the window in modal mode (grab all the application's
# input). Returns once the value of the 'semaphore' variable has been
# changed.
#
# See also the _close method.
# -------------------------------------------------------------------
sub show_modal()
{
    my ($self)= @_;

    $self->show();
    $self->{top}->waitVariable(\$self->{semaphore});
    $self->hide();

    return $self->{result};
}

# -----[ show ]------------------------------------------------------
#
# -------------------------------------------------------------------
sub show()
{
    my ($self)= @_;

    $self->{top}->Popup();
    $self->{top}->grab;
}

# -----[ hide ]------------------------------------------------------
#
# -------------------------------------------------------------------
sub hide()
{
    my ($self)= @_;

    $self->{top}->grabRelease();
    $self->{top}->withdraw();
}

# -----[ _close ]----------------------------------------------------
# Change the 'semaphore' value, subsequently closing the window.
# -------------------------------------------------------------------
sub _close()
{
    my ($self)= @_;
    
    $self->_on_close();
    $self->{semaphore}= 1;
}

# -----[ _init ]------------------------------------------------------
# Initialize the window's content. Must be overriden.
# -------------------------------------------------------------------
sub _init(%)
{
    my ($self, %args)= @_;

    # Set window's title
    if (exists($args{-title})) {
	$self->{top}->title($args{-title});
    }

    # Create a 'close' button
    if (exists($args{-btn_close})) {
	$self->_init_bottom_frame();
	$self->{ButtonClose}=
	    $self->{Bottom}{top}->Button(-text=>'Close',
					 -command=>sub{
					     $self->{result}= undef;
					     $self->_close();
					 }
					 )->pack(-expand=>1,
						 -side=>'top');
    }

    # Create 'cancel' and 'ok' buttons
    if (exists($args{-btn_okcancel})) {
	$self->_init_bottom_frame();
	$self->{ButtonOk}=
	    $self->{Bottom}{top}->Button(-text=>'Ok',
					 -command=>sub{
					     $self->_close();
					 }
					 )->pack(-expand=>1,
						 -side=>'right');
	$self->{ButtonCancel}=
	    $self->{Bottom}{top}->Button(-text=>'Cancel',
					 -command=>sub{
					     $self->{result}= undef;
					     $self->_close();
					 }
					 )->pack(-expand=>1,
						 -side=>'left');
    }
}

# -----[ _init_bottom_frame ]----------------------------------------
# Create a bottom frame if it does not exist yet.
# -------------------------------------------------------------------
sub _init_bottom_frame()
{
    my ($self)= @_;
    
    if (!exists($self->{Bottom})) {
	$self->{Bottom}{top}=
	    $self->{top}->Frame(-relief=>'sunken',
				-borderwidth=>1
				)->pack(-side=>'bottom',
					-fill=>'both');
    }
}

# -----[ _on_close ]-------------------------------------------------
# Called when the window is closing (upon the user's request).
# -------------------------------------------------------------------
sub _on_close($)
{
    my ($self)= @_;
}
