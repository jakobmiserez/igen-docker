# ===================================================================
# Stat.pm
#
# (c) 2004, Networking team
#           Computing Science and Engineeding Dept.
#           Université catholique de Louvain
#           Belgium
#
# author Bruno Quoitin
# date 16/02/2004
# lastdate 01/06/2005
# ===================================================================

package UCL::Stat;

require Exporter;
@ISA= qw(Exporter);
@EXPORT_OK= qw(new
	       get_deviation
	       get_distrib
	       get_max
	       get_mean
	       get_median
	       get_min
	       get_pth_percentile
	       get_std_deviation
	       plot_distrib
	       write_distrib);

use strict;
use IO::Handle;

# -----[ log10 ]-----------------------------------------------------
# Return logarithm of x, in base 10.
# -------------------------------------------------------------------
sub log10($)
{
    my ($x)= @_;
    ($x <= 0) and die "Error: can not return log10($x) !";
    return log($x)/log(10);
}

# -------------------------------------------------------------------
#
# -------------------------------------------------------------------
sub round($)
{
    my ($x)= @_;
    return int($x+0.5);
}

# -----[ new ]-------------------------------------------------------
#
# -------------------------------------------------------------------
sub new($)
{
    my ($class, $array)= @_;
    my $stat_ref= {
	'array' => $array,
	'array_sorted' => undef,
	'deviation' => undef,
	'distrib' => undef,
	'distrib_cumulative' => 0,
	'distrib_min' => 'min',
	'distrib_max' => 'max',
	'distrib_num_classes' => undef,
	'distrib_bin_size' => undef,
	'distrib_relative' => 0,
	'distrib_weighted' => 0,
	'distrib_logarithmic' => 0,
	'gnuplot_grid' => 0,
	'max' => undef,
	'mean' => undef,
	'median' => undef,
	'min' => undef,
    };
    bless $stat_ref, $class;
    return $stat_ref;
}

# -----[ get_dimension ]---------------------------------------------
# Return the dimension of the data array
# -------------------------------------------------------------------
sub get_dimension()
{
    my ($self)= @_;

    if (ref($self->{array}->[0]) eq 'ARRAY') {
	return scalar(@{$self->{array}});
    } else {
	return 1;
    }
}

# -----[ get_data_at ]-----------------------------------------------
#
# -------------------------------------------------------------------
sub get_data_at($)
{
    my ($self, $index)= @_;

    if ($self->get_dimension() > 1) {
	return $self->{array}->[$index]->[0];
    } else {
	return $self->{array}->[$index];
    }
}

# -----[ get_sorted_data_at ]----------------------------------------
#
# -------------------------------------------------------------------
sub get_sorted_data_at($)
{
    my ($self, $index)= @_;

    if ($self->get_dimension() > 1) {
	return $self->{array_sorted}->[$index]->[0];
    } else {
	return $self->{array_sorted}->[$index];
    }
}

# -----[ sort ]------------------------------------------------------
#
# -------------------------------------------------------------------
sub sort()
{
    my ($self)= @_;

    my @array_sorted;
    if ($self->get_dimension() > 1) {
	@array_sorted= sort {$a->[0] <=> $b->[0]} @{$self->{array}};
    } else {
	@array_sorted= sort {$a <=> $b} @{$self->{array}};
    }
    $self->{array_sorted}= \@array_sorted;
}

# -------------------------------------------------------------------
# Compute the mean value of the array. Also compute the minimum and
# maximum values.
# -------------------------------------------------------------------
sub get_mean()
{
    my ($self)= @_;

    if (!defined($self->{mean})) {
	my $total= 0;
	my $min= undef;
	my $max= undef;
	if (scalar(@{$self->{array}}) > 0) {
	    for (my $index= 0; $index < @{$self->{array}}; $index++) {
		my $data= $self->get_data_at($index);
		$total+= $data;
		if (!defined($min) || ($min > $data)) {
		    $min= $data;
		}
		if (!defined($max) || ($max < $data)) {
		    $max= $data;
		}
	    }
	    $self->{mean}= $total/(scalar(@{$self->{array}}));
	    $self->{min}= $min;
	    $self->{max}= $max;
	}
    }
    return $self->{mean};
}

# -----[ min ]-------------------------------------------------------
#
# -------------------------------------------------------------------
sub get_min()
{
    my ($self)= @_;

    if (!defined($self->{min})) {
	$self->get_mean();
    }
    return $self->{min};
}

# -----[ max ]-------------------------------------------------------
#
# -------------------------------------------------------------------
sub get_max()
{
    my ($self)= @_;

    if (!defined($self->{max})) {
	$self->get_mean();
    }
    return $self->{max};
}

# -------------------------------------------------------------------
#
# -------------------------------------------------------------------
sub get_deviation()
{
    my ($self)= @_;

    if (!defined($self->{deviation})) {
	my $total= 0;
	my $mean= $self->get_mean();
	my $data;
	for (my $index= 0; $index <@{$self->{array}}; $index++) {
	    $total+= ($self->get_data_at($index)-$mean)**2;
	}
	if (scalar(@{$self->{array}}) > 1) {
	    $self->{deviation}= $total/(scalar(@{$self->{array}})-1);
	} else {
	    $self->{deviation}= 0;
	}
    }
    return $self->{deviation};
}


# -------------------------------------------------------------------
#
# -------------------------------------------------------------------
sub get_std_deviation()
{
    my ($self)= @_;

    if (!defined($self->{deviation})) {
	$self->get_deviation();
    }
    return sqrt($self->{deviation});
}


# -------------------------------------------------------------------
# Compute the pth-percentile of the data set.
# -------------------------------------------------------------------
sub get_pth_percentile($)
{
    my ($self, $P)= @_;

    if (!defined($self->{array_sorted})) {
	$self->sort();
    }
    my $index= round((@{$self->{array_sorted}}-1)*$P/100);
    return $self->get_sorted_data_at($index);
}


# -------------------------------------------------------------------
#
# -------------------------------------------------------------------
sub get_median()
{
    my ($self)= @_;

    if (!defined($self->{median})) {
	if (!defined($self->{array_sorted})) {
	    $self->sort();
	}
	my $array_size= @{$self->{array_sorted}};
	if (($array_size % 2) == 0) {
	    $self->{median}= ($self->get_sorted_data_at($array_size/2)+
			       $self->get_sorted_data_at($array_size/2+1))/2;
	} else {
	    $self->{median}= $self->get_sorted_data_at(($array_size-1)/2);
	}	
    }
    return $self->{median};
}

# -----[ get_distrib_options ]---------------------------------------
#
# -------------------------------------------------------------------
sub get_distrib_options()
{
    my ($self)= @_;

    # Default parameters
    my ($min, $max, $num_classes, $logarithmic)= (0, 100, 100, 0);

    # Overriden by options ?
    if (defined($self->{distrib_min})) {
	if ($self->{distrib_min} eq 'min') {
	    $min= $self->get_min();
	} else {
	    $min= $self->{distrib_min};
	}
    }
    if (defined($self->{distrib_max})) {
	if ($self->{distrib_max} eq 'max') {
	    $max= $self->get_max();
	} else {
	    $max= $self->{distrib_max};
	}
    }
    if (defined($self->{distrib_num_classes}) &&
	defined($self->{distrib_bin_size})) {
	die "specifying num_classes and bin_size at the same time ".
	    "is not allowed";
    }
    if (defined($self->{distrib_num_classes})) {
	$num_classes= $self->{distrib_num_classes};
    }
    if (defined($self->{distrib_bin_size})) {
	if ($min >= 0) {
	    $min= int($min/$self->{distrib_bin_size})*
		$self->{distrib_bin_size};
	} else {
	    $min= (int($min/$self->{distrib_bin_size})-1)*
		$self->{distrib_bin_size};
	}
	if ($max >= 0) {
	    $max= (int($max/$self->{distrib_bin_size})+1)*
		$self->{distrib_bin_size};
	} else {	
	    $max= int($max/$self->{distrib_bin_size})*
		$self->{distrib_bin_size};
	}
	$num_classes= int(($max-$min)/$self->{distrib_bin_size})+1;
    }
    if (defined($self->{distrib_logarithmic})) {
	$logarithmic= $self->{distrib_logarithmic};
    }

    return ($min, $max, $num_classes, $logarithmic);
}

# -----[ get_distrib ]-----------------------------------------------
#
# -------------------------------------------------------------------
sub get_distrib()
{
    my ($self)= @_;

    if (!defined($self->{distrib})) {

	my ($min, $max, $num_classes, $logarithmic)=
	    $self->get_distrib_options();

	my ($log_min, $log_max);

	my @classes;
	my $index;

	# Initialize array of classes
	if (!$logarithmic) {
	    for ($index= 0; $index < $num_classes; $index++) {
		$classes[$index]= [$min+$index*($max-$min)/($num_classes-1), 0];
	    }
	} else {
	    if ($min <= 0) {
		die "cannot use logarithmic sampling with data ".
		    "in range [$min:$max]";
	    }
	    $log_min= log10($min);
	    $log_max= log10($max);
	    for ($index= 0; $index < $num_classes; $index++) {
		$classes[$index]= [10**($log_min+$index*
					($log_max-$log_min)/($num_classes-1)), 0];
	    }
	}

	# Classify data
	for ($index= 0; $index < scalar(@{$self->{array}}); $index++) {
	    my $value= $self->get_data_at($index);
	    if ($value < $min) {
		$value= $min;
	    }
	    if ($value > $max) {
		$value= $max;
	    }
	    my $class_index= 0;
	    if (!$logarithmic) {
		if ($max-$min > 0) {
		    $class_index= int(($value-$min)*($num_classes-1)/($max-$min));
		}
	    } else {
		if ($log_max-$log_min > 0) {
		    $class_index= int((log10($value)-$log_min)*
				      ($num_classes-1)/($log_max-$log_min));
		}
	    }
	    if ($self->{distrib_weighted}) {
		$classes[$class_index]->[1]+= $self->{array}->[$index]->[1];
	    } else {
		$classes[$class_index]->[1]++;
	    }
	}

	# Post-processing
	my $factor= 1;
	if ($self->{distrib_relative}) {
	    my $total= 0;
	    for ($index= 0; $index < @classes; $index++) {
		$total+= $classes[$index]->[1];
	    }
	    if ($total > 0) {
		$factor= 100/$total;
	    }
	}

	if ($self->{distrib_cumulative}) {
	    if (@classes > 1) {
		for ($index= 1; $index < @classes; $index++) {
		    $classes[$index]->[1]= $classes[$index-1]->[1]+
			$classes[$index]->[1];
		}
	    }
	}

	if ($factor != 1) {
	    for ($index= 0; $index < @classes; $index++) {
		$classes[$index]->[1]= $classes[$index]->[1]*$factor;
	    }
	}

	$self->{distrib}= \@classes;
    }
    return $self->{distrib};
}

# -----[ plot_array ]------------------------------------------------
#
# -------------------------------------------------------------------
sub plot_array(;%)
{
    my ($self, %args)= @_;

    if (!defined($self->{array_sorted})) {
	die "";
    }

    # ---| Dump distribution into temporary file |---
    my $tmp_filename= "/tmp/.ucl_stat_gnuplot";
    open(TMP, ">$tmp_filename") or
	die "could not create temporary file \"$tmp_filename\": $!";
    my $yvalue= 0;
    for (my $index= 0; $index < @{$self->{array_sorted}}; $index++) {
	if (defined($args{-cumulative}) && $args{-cumulative}) {
	    $yvalue+= $self->{array_sorted}->[$index]->[1];
	} else {
	    $yvalue= $self->{array_sorted}->[$index]->[1];
	}
	print TMP"".$self->{array_sorted}->[$index]->[0]."\t".$yvalue."\n";
    }
    close(TMP);
	 
    # ---| Display plot of distribution |---
    open(GNUPLOT, "| gnuplot -persist") or
	die "could not pipe into gnuplot: $!";
    GNUPLOT->autoflush(1);
    if (defined($args{-filename})) {
	print GNUPLOT "set term postscript eps\n";
	print GNUPLOT "set output \"".$args{-filename}."\"\n";
    }
    print GNUPLOT "set yrange [0:*]\n";
    print GNUPLOT "set xrange [0:*]\n";
    (defined($args{-xlabel})) and
	print GNUPLOT "set xlabel \"".$args{-xlabel}."\"\n";
    (defined($args{-ylabel})) and
	print GNUPLOT "set ylabel \"".$args{-ylabel}."\"\n";
    ($self->{gnuplot_grid}) and
	print GNUPLOT "set grid\n";

    my $options= '';
    (defined($args{-title})) and
	$options.= ' t "'.$args{-title}.'"';
    (defined($args{-style})) and
	$options.= ' w '.$args{-style};
    print GNUPLOT "plot \"$tmp_filename\" u 1:2 $options\n";
    close(GNUPLOT);
}

# -----[ plot_distrib ]----------------------------------------------
#
# -------------------------------------------------------------------
sub plot_distrib(;$$$$%)
{
    my ($self, $filename, $title, $xlabel, $ylabel, %args)= @_;

    if (!defined($self->{distrib})) {
	$self->get_distrib();
    }

    # Dump distribution into temporary file
    my $tmp_filename= "/tmp/.ucl_stat_gnuplot";
    open(TMP, ">$tmp_filename") or
	die "could not create temporary file \"$tmp_filename\": $!";
    for (my $index= 0; $index < @{$self->{distrib}}; $index++) {
	print TMP"".$self->{distrib}->[$index]->[0]."\t".
	    $self->{distrib}->[$index]->[1]."\n";
    }
    close(TMP);
	 
    # Display plot of distribution
    open(GNUPLOT, "| gnuplot -persist") or
	die "could not pipe into gnuplot: $!";
    GNUPLOT->autoflush(1);
    if (defined($filename)) {
	print GNUPLOT "set term postscript eps\n";
	print GNUPLOT "set output \"$filename\"\n";
    }
    if (defined($xlabel)) {
	print GNUPLOT "set xlabel \"$xlabel\"\n";
    }
    if (defined($ylabel)) {
	print GNUPLOT "set xlabel \"$ylabel\"\n";
    }
    (defined($args{-grid})) and
	print GNUPLOT "set grid\n";
    (defined($args{-xlogscale})) and
	print GNUPLOT "set logscale x\n";
    (defined($args{-ylogscale})) and
	print GNUPLOT "set logscale y\n";
    (defined($args{-xlabel})) and
	print GNUPLOT "set xlabel \"".$args{-xlabel}."\"\n";
    (defined($args{-ylabel})) and
	print GNUPLOT "set ylabel \"".$args{-ylabel}."\"\n";
    if (defined($args{-xrange})) {
	print GNUPLOT "set xrange [";
	if (defined($args{-xrange}->[0])) {
	    print GNUPLOT $args{-xrange}->[0];
	} else {
	    print GNUPLOT "*";
	}
	print GNUPLOT ":";
	if (defined($args{-xrange}->[1])) {
	    print GNUPLOT $args{-xrange}->[1];
	} else {
	    print GNUPLOT "*";
	}
	print GNUPLOT "]\n";
    }
    if (defined($args{-yrange})) {
	print GNUPLOT "set yrange [";
	if (defined($args{-yrange}->[0])) {
	    print GNUPLOT $args{-yrange}->[0];
	} else {
	    print GNUPLOT "*";
	}
	print GNUPLOT ":";
	if (defined($args{-yrange}->[1])) {
	    print GNUPLOT $args{-yrange}->[1];
	} else {
	    print GNUPLOT "*";
	}
	print GNUPLOT "]\n";
    }
    my $options= '';
    (defined($args{-title})) and
	$options.= ' t "'.$args{-title}.'"';
    (defined($args{-style})) and
	$options.= ' w '.$args{-style};

    print GNUPLOT "plot \"$tmp_filename\" u 1:2 $options\n";

    close(GNUPLOT);
}

# -----[ write_distrib ]---------------------------------------------
#
# -------------------------------------------------------------------
sub write_distrib($)
{
    my ($self, $filename)= @_;

    if (!defined($self->{distrib})) {
	$self->get_distrib();
    }

    open(WRITE_DISTRIB, ">$filename") or
	die "unable to create \"$filename\", $!";
    for (my $index= 0; $index < @{$self->{distrib}}; $index++) {
	print WRITE_DISTRIB "".$self->{distrib}->[$index]->[0]."\t".
	    $self->{distrib}->[$index]->[1]."\n";
    }
    close(WRITE_DISTRIB);
}

# -----[ euclidian_distance ]----------------------------------------
# Returns the euclidian distance between two points Pi and Pj in a
# plane.
#
# Parameters:
# - point Pi
# - point Pj
# - [optional] dimension, default is 2
# -------------------------------------------------------------------
sub euclidian_distance($$;$)
{
    my $pi= shift;
    my $pj= shift;

    # If a dimension is not provided, the default dimension is 2
    my $dim= 2;
    if (@_ > 0) {
	$dim= shift;
    }

    my $dist= 0;
    for (my $i= 0; $i < $dim; $i++) {
	$dist+= ($pi->[$i]-$pj->[$i])*($pi->[$i]-$pj->[$i]);
    }

    return sqrt($dist);
}

# -----[ dimension ]-------------------------------------------------
# Returns the dimension of a set of points.
#
# Parameters:
# - set of points
# -------------------------------------------------------------------
sub dimension($)
{
    my $points= shift;

    (scalar(@$points) < 1) and die "Error: cannot return the ".
	"dimension of an empty set of points";

    return scalar(@{$points->[0]});
}

# -----[ center_of_mass ]--------------------------------------------
# Returns the center of mass of a set of points
#
# Parameters:
# - set of points
# -------------------------------------------------------------------
sub center_of_mass($;$)
{
    my $points= shift;

    # Get the dimension of the set of points
    my $dim= 2;
    if (scalar(@_) > 0) {
	$dim= shift;
    }

    # Compute the center of mass of the set of points
    my @cm= ();
    foreach my $pt (@$points) {
	for (my $i= 0; $i < $dim; $i++) {
	    $cm[$i]+= $pt->[$i];
	}
    }
    for (my $i= 0; $i < $dim; $i++) {
	$cm[$i]/= scalar(@$points);
    }

    return \@cm;
}

# -----[ centroid ]--------------------------------------------------
# Returns the centroid of a set of points. Note that the centroid is
# not necessarily unique.
#
# Parameters:
# - set of points
# -------------------------------------------------------------------
sub centroid($;$)
{
    my $points= shift;

    # Get the dimension of the set of points
    my $dim= 2;
    if (scalar(@_) > 0) {
	$dim= shift;
    }

    # Get the center of mass of the set of points
    my $cm= center_of_mass($points, $dim);

    # Find the closest point
    my $best_dist= -1;
    my $centroid= undef;
    foreach my $pt (@$points) {
	my $dist= euclidian_distance($pt, $cm, $dim);
	if (($best_dist == -1) || ($dist < $best_dist)) {
	    $best_dist= $dist;
	    $centroid= $pt;
	}
    }

    return $centroid;
}

