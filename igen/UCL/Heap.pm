# ===================================================================
# Heap.pm
#
# (c) 2005, Networking team
#           Computing Science and Engineeding Dept.
#           Université catholique de Louvain
#           Belgium
#
# author Bruno Quoitin
# date 06/06/2005
# lastdate 06/06/2005
# ===================================================================

package UCL::Heap;

require Exporter;
@ISA= qw(Exporter);
@EXPORT_OK= qw(new
	       empty
	       enqueue
	       dequeue);

use strict;

# -----[ new ]-------------------------------------------------------
#
# -------------------------------------------------------------------
sub new()
{
    my ($class);

    my $heap= {
	'queue' => [],
    };
    bless $heap;
    return $heap;
}

# -----[ UCL::Heap::empty ]------------------------------------------
#
# -------------------------------------------------------------------
sub empty()
{
    my ($self)= @_;

    return (@{$self->{queue}} == 0);
}

# -----[ UCL::Heap::enqueue ]----------------------------------------
# Dichotomic search-based. O(log(n)).
# -------------------------------------------------------------------
sub enqueue($$)
{
    my ($self, $item, $priority)= @_;

    if (!$self->empty()) {
	my $start= 0;
	my $end= @{$self->{queue}}-1;
	if ($priority <= $self->{queue}->[0]->[1]) {
	    unshift @{$self->{queue}}, ([$item, $priority]);
	} elsif ($priority >= $self->{queue}->[$end]->[1]) {
	    push @{$self->{queue}}, ([$item, $priority]);
	} else {
	    my $index= int(($end-$start)/2);
	    while ($end > $start) {
		if ($priority == $self->{queue}->[$index]->[1]) {
		    last;
		} elsif ($priority > $self->{queue}->[$index]->[1]) {
		    $start= $start+$index+1;
		} else {
		    $end= $start+$index-1;
		}
		$index= int(($end-$start)/2);
	    }
	    splice @{$self->{queue}}, $index, 0, ([$item, $priority]);
	}
    } else {
	push @{$self->{queue}}, ([$item, $priority]);
    }
}

# -----[ UCL::Heap::dequeue ]----------------------------------------
# Simple pop. O(1).
# -------------------------------------------------------------------
sub dequeue()
{
    my ($self)= @_;

    if ($self->empty()) {
	return undef;
    } else {
	my $item= shift @{$self->{queue}};
	return $item->[0];
    }
}

