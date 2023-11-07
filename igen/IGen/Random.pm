# ===================================================================
# IGen::Random
#
# (c) 2005, Networking team
#           Computing Science and Engineering Dept.
#           Université catholique de Louvain
#           Belgium
#
# author Bruno Quoitin (bqu@info.ucl.ac.be)
# date 06/10/2005
# lastdate 06/10/2005
# ===================================================================

package IGen::Random;

require Exporter;
@ISA= qw(Exporter);
@EXPORT= qw(lognormal
	    normal
	    pareto
	    poisson
	    uniform
	    weibull
	    zipf);

use strict;
use POSIX;

use constant PI => 3.14159265;

# -----[ uniform ]---------------------------------------------------
# Uniform distribution in the range 0 to MAX.
# Note: it is not clear if MAX is reached because it is not clear if
# Perl's rand() will produce 1 sometimes.
# -------------------------------------------------------------------
sub uniform($)
{
    my ($max)= @_;

    return $max*rand();
}

# -----[ pareto ]----------------------------------------------------
# Two-parameters form of Pareto distribution obtained using
# beta(scale) == gamma(location)
# -------------------------------------------------------------------
sub pareto($$)
{
    my ($shape, $scale)= @_;

    # ---| Generate random number in ]0, 1[ |---
    my $random;
    do {
	# rand(EXPR) generates a random fractional number greater than
	# 0 and less than EXPR
	$random= rand(1);
    } while (($random == 1) || ($random == 0));

    # ---| Use inversion method to generate Pareto |---
    # X= a/(1-R)^(1/c), where a is the scale and c is the shape
    return $scale*1.0/pow(1-$random, 1.0/$shape);
}

# -----[ zipf ]------------------------------------------------------
# Zipf's law (Zipfian distribution)
# -------------------------------------------------------------------
my $rand_zipf_cached_params= undef;
my $rand_zipf_cached_nth_harmonic_number= undef;
sub zipf($$)
{
    my ($s, $N)= @_;

    # Compute nth harmonic number if parameters (s, N) have changed
    if (!defined($rand_zipf_cached_params) ||
	($rand_zipf_cached_params->[0] != $s) ||
	($rand_zipf_cached_params->[1] != $N)) {

	my $nth_harmonic_number= 0;
	for (my $i= 1; $i <= $N; $i++) {
	    $nth_harmonic_number+= 1.0/pow($i, $s);
	}
	$rand_zipf_cached_nth_harmonic_number= $nth_harmonic_number;
	$rand_zipf_cached_params= [$s, $N];
    }

    # ---| Generate uniform random number in ]0, 1[ |---
    my $random;
    do {
	$random= rand(1);
    } while (($random == 0) || ($random == 1));

    # ---| Map random number to the value |---
    my $sum_prob= 0;
    for (my $i= 1; $i <= $N; $i++) {
	$sum_prob+= 1.0/pow($i, $s)*
	    1.0/$rand_zipf_cached_nth_harmonic_number;
	if ($sum_prob >= $random) {
	    return $i;
	}
    }

    return 0;
}

# -----[ normal ]----------------------------------------------------
# Box-Muller method to generate R ~ N(0,1)
# mean: 0, sigma2: 1
# -------------------------------------------------------------------
my $static_rand_normal= undef;
sub normal()
{
    if (!defined($static_rand_normal)) {
	my $u= rand();
	my $v= rand();
	
	my $r= sqrt(-2 * log($v));
	my $t= 2*PI*$u;
	
	# ---| Note: in Perl, angles are expressed in radians |---
	my $x= $r*cos($t);
	my $static_rand_normal= $r*sin($t);
	
	return $x;
    } else {
	my $y= $static_rand_normal;
	$static_rand_normal= undef;
	return $y;
    }
}

# -----[ weibull ]---------------------------------------------------
#
# -------------------------------------------------------------------
sub weibull($$)
{
    die "NOT YET IMPLEMENTED";
}

# -----[ poisson ]---------------------------------------------------
#
# -------------------------------------------------------------------

sub poisson($)
{
    die "NOT YET IMPLEMENTED";
}

# -----[ lognormal ]-------------------------------------------------
#
# -------------------------------------------------------------------
sub lognormal()
{
    die "NOT YET IMPLEMENTED";
}

1;
