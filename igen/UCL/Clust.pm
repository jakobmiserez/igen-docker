# ===================================================================
# Clust.pm
#
# author Bruno Quoitin (bqu@info.ucl.ac.be)
# date 28/05/2004
# lastdate 27/06/2004
# ===================================================================

package Clust;

require Exporter;
@ISA= qw(Exporter);
@EXPORT= qw(new set_points hierarchical_clustering);
$VERSION= '0.1';

use strict;

# -----[ new ]-------------------------------------------------------
# Create an instance of the clustering class.
# -------------------------------------------------------------------
sub new()
{
    my $class= shift;
    my $clust_ref= {
	'points' => [],
	'clusters' => [],
	'verbose' => 0,
    };
    bless $clust_ref;
    return $clust_ref;
}

# -----[ set_points ]------------------------------------------------
# Set the array of points to classify.
#
# Parameter:
# - a reference to an array of couples (2-items arrays)
# -------------------------------------------------------------------
sub set_points($)
{
    my $self= shift;

    $self->{points}= shift;
}

# -----[ load_points ]-----------------------------------------------
# Load the array of points from a file.
#
# Parameter:
# - the name of a file that contains points organized in two
#   columns. The first column contains the X coordinate (or the
#   longitude) while the second column contains the Y coordinate (or
#   the latitude).
# -------------------------------------------------------------------
sub load_points($)
{
    my $self= shift;
    my $file_name= shift;
    my $result= open FILE, "<$file_name";
    if (!$result) {
	print STDERR "Error: unable to open $file_name: $!\n";
	return -1;
    }
    while (<FILE>) {
	chomp;
	(m/^\#/) and next;
	my @fields= split /\s+/;
	if (scalar(@fields) < 2) {
	    print STDERR "Error: a line contains less than two ".
		"coordinates\n";
	    close FILE;
	    return-1;
	}
	push @{$self->{points}}, ([$fields[1], $fields[2]]);
    }
    close FILE;

    return 0;
}

# -----[ hc_centroid ]-----------------------------------------------
# Compute the center of mass of two clusters of points
# -------------------------------------------------------------------
sub hc_centroid($$)
{
    my $self= shift;

    my $cluster_i= shift;
    my $cluster_j= shift;
    my @centroid= ();

    my $centroid_i= $cluster_i->{centroid};
    my $num_i= scalar(@{$cluster_i->{points}});
    my $centroid_j= $cluster_j->{centroid};
    my $num_j= scalar(@{$cluster_j->{points}});

    # Compute joint centroid (in N dimensions, N=2)
    my $dim;
    for ($dim= 0; $dim < 2; $dim++) {
	$centroid[$dim]=
	    ($centroid_i->[$dim]*$num_i+
	     $centroid_j->[$dim]*$num_j)/
	     ($num_i+$num_j);
    }

    return \@centroid;
}

# -----[ hc_variance ]-----------------------------------------------
# Compute the variance of two clusters of points
# -------------------------------------------------------------------
sub hc_variance($$)
{
    my $self= shift;

    my $cluster_i= shift;
    my $cluster_j= shift;

    my $cm_ref= $self->hc_centroid($cluster_i, $cluster_j);
    my $variance= 0;

    my $pt_id;
    foreach $pt_id (@{$cluster_i->{points}}) {
	my $pt_ref= $self->{points}->[$pt_id];
	$variance+=
	    ($cm_ref->[0]-$pt_ref->[0]) ** 2 +
	    ($cm_ref->[1]-$pt_ref->[1]) ** 2;
    }
    foreach $pt_id (@{$cluster_j->{points}}) {
	my $pt_ref= $self->{points}->[$pt_id];
	$variance+=
	    ($cm_ref->[0]-$pt_ref->[0]) ** 2 +
	    ($cm_ref->[1]-$pt_ref->[1]) ** 2;
    }

    return sqrt($variance);
}

# -----[ hc_merge ]--------------------------------------------------
# Merge two clusters of points in one
# -------------------------------------------------------------------
sub hc_merge($$)
{
    my $self= shift;

    my $cluster_i= shift;
    my $cluster_j= shift;

    # Compute the joint centroid
    my $centroid= $self->hc_centroid($cluster_i, $cluster_j);
    
    $cluster_i->{variance}= $self->hc_variance($cluster_i, $cluster_j);

    $cluster_i->{centroid}= $centroid;

    # Join the sets of points
    push @{$cluster_i->{points}}, @{$cluster_j->{points}};

}

# -----[ hc_dump_cluster ]-------------------------------------------
# Dump the content of a cluster.
# -------------------------------------------------------------------
sub hc_dump_cluster($)
{
    my $self= shift;

    my $cluster= shift;

    print "cluster { ";
    printf "cm:(%.2f,%.2f), ", $cluster->{centroid}->[0],
    $cluster->{centroid}->[1];
    printf "var:%.2f, ", $cluster->{variance};
    print "points:( ";
    my $point_id;
    foreach $point_id (@{$cluster->{points}}) {
	print "$point_id ";
    }
    print ")";
    print " }\n";
}

# -----[ hierarchical_clustering ]-----------------------------------
# Hierarchical clustering of a set of points
#
# Parameters:
# - K, which is the number of clusters (or the stop condition of the
#   algorithm)
# - the maximum variance of a single cluster
# -------------------------------------------------------------------
sub hierarchical_clustering($$$)
{
    my $self= shift;

    # Parameters
    my $K= shift;
    my $max_var= shift;

    # Variables
    my @var_matrix= ();

    # Init: Build one cluster for each individual point
    if (scalar(@{$self->{clusters}}) == 0) {
	$self->{clusters}= [];
	for (my $point_index= 0; $point_index < scalar(@{$self->{points}});
	     $point_index++) {
	    push @{$self->{clusters}}, ({
		'points' => [$point_index],
		'centroid' => [$self->{points}->[$point_index]->[0],
			       $self->{points}->[$point_index]->[1]],
		'variance' => 0,
	    });
	}
    }

    # Compute matrix of pairwise variances
    my $i, my $j;
    for ($i= 0; $i < scalar(@{$self->{clusters}}); $i++) {
	for ($j= $i+1; $j < scalar(@{$self->{clusters}}); $j++) {
	    $var_matrix[$i][$j]= -1;
	}
    }

    # Algorithm's main loop, find the two clusters that form the set
    # with the smallest variance and merge them into a single cluster
    # until there is K clusters
    while (scalar(@{$self->{clusters}}) > $K) {

	my $old_time= time;
	my $log= 1;
	
	# Take all pairs of clusters and remember the pair with the
	# smallest variance
	my $i;
	my $b_var= undef;
	my $b_centroid;
	my @b_pair;
	for ($i= 0; $i < scalar(@{$self->{clusters}}); $i++) {

	    if ($self->{verbose} && ((time-1 >= $old_time) || ($log))) {
		if ($log) {
		    print "\r                         ";
		}
		$log= 0;
		printf "\rClustering %d/%d", scalar(@{$self->{clusters}}), $i;
		STDOUT->flush();
		$old_time= time;
	    }

	    my $j;
	    for ($j= $i+1; $j < scalar(@{$self->{clusters}}); $j++) {

		# Look into the variance cache for the couple (i, j)
		if (!exists($var_matrix[$i][$j]) ||
		    ($var_matrix[$i][$j] == -1)) {
		    $var_matrix[$i][$j]=
			$self->hc_variance($self->{clusters}->[$i],
					   $self->{clusters}->[$j]);
		}

		# Compare to the current variance
		if (($b_var == undef) ||
		    ($b_var > $var_matrix[$i][$j])) {
		    $b_var= $var_matrix[$i][$j];
		    @b_pair= ($i, $j);
		}
	    }
	}

	# Do not make possible that a single cluster has a variance
	# greater than the maximum variance
	(($max_var != undef) && ($b_var > $max_var)) and last;

	# Merge clusters i and j
	$self->hc_merge($self->{clusters}->[$b_pair[0]],
			$self->{clusters}->[$b_pair[1]]);
	splice @{$self->{clusters}}, $b_pair[1], 1;

	#hc_dump_cluster($clusters[$b_pair[0]]);

	# Update cache: remove lines with the comparison between i and
	# j (these line will be recomputed later if required)
	my $i;
	foreach $i (@var_matrix) {
	    splice @$i, $b_pair[1], 1;
	    $i->[$b_pair[0]]= -1;
	}
	splice @var_matrix, $b_pair[1], 1;
	undef $var_matrix[$b_pair[0]];

    }
}
