# ===================================================================
# IGen::Gnuplot
#
# (c) 2005, Networking team
#           Computing Science and Engineering Dept.
#           Université catholique de Louvain
#           Belgium
#
# author Bruno Quoitin (bqu@info.ucl.ac.be)
# date 22/09/2005
# lastdate 28/01/2006
# ===================================================================

package IGen::Gnuplot;

require Exporter;
@ISA= qw(Exporter);
@EXPORT_OK= qw(new);

use strict;

# -----[ new ]-------------------------------------------------------
# Authorized options:
#   -xlabel -xrange -xlogscale -ylabel -yrange -ylogscale -grid
# -------------------------------------------------------------------
sub new($;%)
{
    my ($class, %args)= @_;
    my $self= {
	'plots' => [],
    };
    foreach (keys %args) {
	(exists($self->{$_})) and
	    return undef;
	$self->{$_}= $args{$_};
    }
    bless $self, $class;
    return $self;
}

# -----[ add_plot ]--------------------------------------------------
# Authorized plot options:
#   -style -title
# -------------------------------------------------------------------
sub add_plot($$%)
{
    my ($self, $plot_file, %args)= @_;

    push @{$self->{plots}}, ([$plot_file, \%args]);
}

# -----[ plot ]------------------------------------------------------
#
# -------------------------------------------------------------------
sub plot($;$%args)
{
    my ($self, $filename, %args)= @_;

    # ---| Pipe into gnuplot |---
    if ($args{-debug}) {
	print "WARNING: gnuplot-debug \"".$args{-debug}."\"\n";
	open(GNUPLOT, ">".$args{-debug}) or
	    return -1;
    } else {
	if (!defined($filename) || ($filename eq '') || $args{-persist}) {
	    open(GNUPLOT, "| gnuplot -persist >/tmp/.gnuplot.debug") or
		return -1;
	    GNUPLOT->autoflush(1);
	} else {
	    open(GNUPLOT, "| gnuplot >/tmp/.gnuplot.debug") or
		return -1;
	}
    }

    # ---| Set global options |---
    if (defined($self->{-xtics})) {
	print GNUPLOT "set xtics ";
	(defined($self->{-xticsrotate})) and
	    print GNUPLOT "rotate ".$self->{-xticsrotate}." ";
	print GNUPLOT "(";
	my $sep= 0;
	foreach (@{$self->{-xtics}}) {
	    ($sep) and print GNUPLOT ", ";
	    my ($label, $pos);
	    if (ref($_) eq 'ARRAY') {
		$pos= $_->[0];
		$label= $_->[1];
	    } else {
		$pos= $_;
	    }
	    (defined($label)) and print GNUPLOT "\"$label\" ";
	    print GNUPLOT "$pos";
	    $sep= 1;
	}
	print GNUPLOT ")";
	if (defined($self->{-xticsfont})) {
	    print GNUPLOT " font ".$self->{-xticsfont};
	}
	print GNUPLOT "\n";
    }
    (defined($self->{-xlabel})) and
	print GNUPLOT "set xlabel \"".$self->{-xlabel}."\"\n";
    (defined($self->{-xrange})) and
	print GNUPLOT "set xrange [".$self->{-xrange}->[0].
	":".$self->{-xrange}->[1]."]\n";
    ($self->{-xlogscale}) and
	print GNUPLOT "set logscale x\n";
    (defined($self->{-ylabel})) and
	print GNUPLOT "set ylabel \"".$self->{-ylabel}."\"\n";
    (defined($self->{-yrange})) and
	print GNUPLOT "set yrange [".$self->{-yrange}->[0].
	":".$self->{-yrange}->[1]."]\n";
    ($self->{-ylogscale}) and
	print GNUPLOT "set logscale y\n";
    (defined($self->{-grid})) and
	print GNUPLOT "set grid\n";
    (defined($self->{-title})) and
	print GNUPLOT "set title \"".$self->{-title}."\"\n";
    (defined($self->{-boxwidth})) and
	print GNUPLOT "set boxwidth ".$self->{-boxwidth}."\n";

    # ---| Plot all files |---
    for (my $i= 0; $i < scalar(@{$self->{plots}}); $i++) {
	my $plot_spec= $self->{plots}->[$i];
	# Plot spec composed of src file and local options
	my $plot_file= $plot_spec->[0];
	my $plot_options= $plot_spec->[1];

	# ---| Set local options |---
	my $options= '';
	(defined($plot_options->{-plottitle})) and
	    $options.= ' t "'.$plot_options->{-plottitle}.'"';
	(defined($plot_options->{-style})) and
	    $options.= ' w '.$plot_options->{-style};
	my $index= '1:2';
	(defined($plot_options->{-index})) and
	    $index= $plot_options->{-index};

	if ($i == 0) {
	    print GNUPLOT "plot ";
	} else {
	    print GNUPLOT", ";
	}

	# ---| Call gnuplot's 'plot' function |---
	print GNUPLOT "\"$plot_file\" u $index $options";
    }
    print GNUPLOT "\n";

    # ---| Set output & terminal |---
    if (defined($filename)) {
	if (defined($self->{-term})) {
	    print GNUPLOT "set term ".$self->{-term}."\n";
	} else {
	    print GNUPLOT "set term postscript eps\n";
	}
	print GNUPLOT "set output \"$filename\"\n";
	print GNUPLOT "replot\n";
    }

    close(GNUPLOT);

    return 0;
}
