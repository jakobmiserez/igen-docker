# ===================================================================
# @(#)MRT.pm
#
# @author Bruno Quoitin (bqu@info.ucl.ac.be)
# @date 04/06/2004
# @lastdate 06/09/2005
# ===================================================================

package MRT;

require Exporter;
@ISA= qw(Exporter);
@EXPORT= qw(load_rib);
$VERSION= '0.1';

use strict;
use Net::Patricia;
use UCL::Progress;

# -----[ new ]-------------------------------------------------------
#
# -------------------------------------------------------------------
sub new()
{
    my $mrt_ref= {
	'ascii' => 0,
	'prefixes' => new Net::Patricia,
	'prefix_cnt' => 0,
	'verbose' => 0,
	'warnings' => 0,
    };
    bless $mrt_ref;
    return $mrt_ref;
}

# -----[ load_rib ]--------------------------------------------------
# Loads a routing table in MRT format.
# -------------------------------------------------------------------
sub load_rib($)
{
    my $self= shift;
    my $file_name= shift;
    my $progress= Progress::new();
    $progress->{verbose}= $self->{verbose};
    $progress->{pace}= 1;
    $progress->{message}= "Loading prefixes: ";

    my $result;
    my $line_number= 1;

    if (!$self->{ascii}) {
	if ($file_name =~ m/\.gz$/) {
	    $result= open FILE, "zcat $file_name | route_btoa -m |";
	} elsif ($file_name =~ m/\.bz2$/) {
	    $result= open FILE, "bzcat $file_name | route_btoa -m |";
	} elsif ($file_name =~ m/\.txt$/) {
	    $result= open FILE, "<$file_name";
	} else {
	    $result= open FILE, "route_btoa -m $file_name";
	}
    } else {
	$result= open FILE, "$file_name";
    }

    if (!$result) {
	print STDERR "Error: could not open \"$file_name\": $!\n";
	return -1;
    }

    while (<FILE>) {
	chomp;
	my @fields= split /\|/;

	if (scalar(@fields) < 7) {
	    print STDERR "Error: missing fields in \"$file_name\" at line ".
		"$line_number\n";
	    return -1;
	}

	my $table_dump= shift @fields;
	my $time= shift @fields;
	my $type= shift @fields;
	my $peer_ip= shift @fields;
	my $peer_as= shift @fields;
	my $prefix= shift @fields;
	my @as_path= split /\s+/, shift @fields;

	if (scalar(@as_path) == 0) {
	    if ($self->{warnings}) {
		print STDERR "\rWarning: skip record (empty AS-PATH) in ",
		"\"$file_name\" at line $line_number\n";
		$progress->reset();
	    }
	    next;
	}

	my $origin_as= $as_path[$#as_path];

	$origin_as=~ tr/\[\]//d;

	if (!$self->{prefixes}->match_exact_string($prefix)) {

	    $self->{prefixes}->add_string($prefix, [$prefix, $origin_as]);

	    $self->{prefix_cnt}++;
	    $progress->progress(undef, $self->{prefix_cnt});
	}
	$line_number++;
    }

    $progress->end(undef, $self->{prefix_cnt});

    close FILE;
    
    return 0;
}
