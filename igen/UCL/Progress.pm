# ===================================================================
# @(#)Progress.pm
#
# @author Bruno Quoitin (bqu@info.ucl.ac.be)
# @date 21/06/2004
# @lastdate 04/10/2005
# ===================================================================

package UCL::Progress;

require Exporter;
@ISA= qw(Exporter);
$VERSION= '0.1';

use strict;
use IO::Handle;

# -----[ new ]-------------------------------------------------------
#
# -------------------------------------------------------------------
sub new()
{
    my $progress_ref= {
	'message' => '',
	'old_time' => undef,
	'pace' => 1,
	'percent' => 0,
	'stream' => undef,
	'verbose' => 1,
    };
    $progress_ref->{stream}= *STDOUT;
    bless $progress_ref;
    return $progress_ref;
}

# -----[ log ]-------------------------------------------------------
#
# -------------------------------------------------------------------
sub log($)
{
    my $self= shift;
    my $message= shift;

    my $stream= $self->{stream};

    if ($self->{verbose} && (($self->{old_time} == undef) ||
			     ($self->{old_time} < time))) {
	$self->{old_time}= time;
	print $stream "\r$message";
	$self->{stream}->flush();
    }
}

# -----[ write ]-----------------------------------------------------
#
# -------------------------------------------------------------------
sub write($$)
{
    my ($self, $message, $progress)= @_;

    my $stream= $self->{stream};

    if ($message == undef) {
	$message= $self->{message};
    }

    if ($self->{percent}) {
	printf $stream "\r$message%.2f%%", $progress;
    } else {
	printf $stream "\r$message%d", $progress;
    }
    $self->{stream}->flush();
}

# -----[ write ]-----------------------------------------------------
#
# -------------------------------------------------------------------
sub writeln($$)
{
    my ($self, $message, $progress)= @_;

    my $stream= $self->{stream};

    if ($message == undef) {
	$message= $self->{message};
    }

    if ($self->{percent}) {
	printf $stream "\r$message%.2f%%\n", $progress;
    } else {
	printf $stream "\r$message%d\n", $progress;
    }
    $self->{stream}->flush();
}

# -----[ bar ]-------------------------------------------------------
#
# -------------------------------------------------------------------
sub bar($$$;$)
{
    my ($self, $progress, $max, $len, $detail)= @_;

#    print "params: ".(join ';', @_)."\n";

    my $message= "";
    (defined($self->{message})) and
	$message= $self->{message};
    (!defined($detail)) and
	$detail= '';

    if ($self->{verbose} && (($self->{old_time} == undef) ||
			     ($self->{old_time}+$self->{pace} <= time))) {
	$self->{old_time}= time;
	my $stream= $self->{stream};
	print $stream "\r$message [";
	if ($max > 0) {
	    for (my $i= 0; $i < $len; $i++) {
		print $stream ($i < int(($len*$progress)/$max))?"#":" ";
	    }
	    printf $stream "] %.1f %% $detail", (100*$progress/$max);
	} else {
	    for (my $i= 0; $i < $len; $i++) {
		print $stream "#";
	    }
	    printf $stream "] *** $detail";
	}
	$stream->flush();
    }
}

# -----[ progress ]--------------------------------------------------
#
# -------------------------------------------------------------------
sub progress($$;$)
{
    my ($self, $progress, $message)= @_;

    if ($self->{verbose} && (($self->{old_time} == undef) ||
			     ($self->{old_time}+$self->{pace} <= time))) {
	$self->{old_time}= time;
	$self->write($message, $progress);
    }
}

# -----[ end ]-------------------------------------------------------
#
# -------------------------------------------------------------------
sub end($;$)
{
    my ($self, $progress, $message)= @_;

    $self->writeln($message, $progress);
}

# -----[ reset ]-----------------------------------------------------
#
# -------------------------------------------------------------------
sub reset()
{
    my $self= shift;

    $self->{old_time}= undef;
}

