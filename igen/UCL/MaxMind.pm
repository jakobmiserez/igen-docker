# ===================================================================
# @(#)MaxMind.pm
#
# @author Bruno Quoitin (bqu@info.ucl.ac.be)
# @date 04/06/2004
# @lastdate 06/09/2005
# ===================================================================

package MaxMind;

require Exporter;
@ISA= qw(Exporter);
@EXPORT= qw(load_locations
	    load_blocks
	    _unpack_prefix
	    int2ip
	    find_location
	    find_locId);
$VERSION= '0.2';

use strict;

use IO::Handle;
use UCL::Progress;

# -----[ new ]-------------------------------------------------------
# Create a new instance of a mapping from IP addresses to Geographical
# locations
# -------------------------------------------------------------------
sub new()
{
    my $class= shift;
    my $geo_ip_ref= {
	'aliases' => {},
	'locations'=> [],
	'blocks' => {},
	'block_cnt' => 0,
	'longest_prefix' => 0,
	'verbose' => 1,
	'warnings' => 1,
    };
    bless $geo_ip_ref;
    return $geo_ip_ref;
}

# -----[ load_locations ]--------------------------------------------
# Populate the locations' database from the given file
#
# Parameters:
# - .csv file that contains the locations
# -------------------------------------------------------------------
sub load_locations($)
{
    my ($self, $file_name)= @_;
    my $progress= UCL::Progress::new();
    my %coordinates= ();
    my %locIds= ();
    $progress->{pace}= 1;
    $progress->{verbose}= $self->{verbose};
    $progress->{message}= "Loading locations: ";

    my $result= open FILE, "<$file_name";
    my $line_number= 1;
    if (!$result) {
	print STDERR "Error: could not open \"$file_name\": $!\n";
	return -1;
    }

    # Skip Copyright info
    $_= <FILE>;
    if (!/^Copyright.*/) {
	print STDERR "Error: no copyright info in \"$file_name\" at line $line_number\n";
	return -1;
    }
    $line_number++;

    # Skip field info
    $_= <FILE>;
    if (!/^locId,country,region,city,postalCode,latitude,longitude,dmaCode,areaCode$/) {
	print STDERR "Error: no field info in \"$file_name\" at line $line_number\n";
	return -1;
    }
    $line_number++;

    # Load all fields
    while (<FILE>) {
	chomp;
	my @fields= split /\,/;
	
	if (scalar(@fields) < 7) {
	    print STDERR "Error: wrong number of fields (".scalar(@fields).
		") in \"$file_name\" at line $line_number\n";
	    return -1;
	}

	my $locId= shift @fields;
	my $country= shift @fields;
	my $region= shift @fields;
	my $city= shift @fields;
	my $postalCode= shift @fields;
	my $latitude= shift @fields;
	my $longitude= shift @fields;

	$country=~ tr/\"//d;
	$region=~ tr/\"//d;
	$city=~ tr/\"//d;
	$postalCode=~ tr/\"//d;
	$latitude=~ tr/\"//d;
	$longitude=~ tr/\"//d;

	# Check location's validity
	my $valid= 1;
	if (($latitude < -90) || ($latitude > 90) ||
	    ($longitude < -180) || ($longitude > 180)) {
	    if ($self->{warnings}) {
		print STDERR "\rWarning: skip invalid coordinates ",
		"($latitude, $longitude)\n";
		$progress->reset();
	    }
	    $valid= 0;
	}

	# Skip (0,0) locations
	if (($latitude == 0) && ($longitude == 0)) {
	    $valid= 0;
	}

	# Check uniqueness of lodId
	if (exists($locIds{$locId})) {
	    die "duplicate record for locId $locId";
	}
	$locIds{$locId}= 1;

	# Check that these coordinates are not yet defined
	if (exists($coordinates{$latitude}{$longitude})) {
	    $self->{aliases}->{$locId}=
		$coordinates{$latitude}{$longitude};
	} else {
	    $coordinates{$latitude}{$longitude}= $locId;
	
	    # Record valid locations
	    if ($valid) {
		$self->{locations}->[int($locId)]=
		    [$latitude, $longitude, $city, $country];
	    }
	}
	    
	$line_number++;
	if (($line_number % 10) == 0) {
	    $progress->progress(undef, $line_number);
	}
    }
    $progress->end(undef, $line_number);
    close FILE;
    
    return 0;
}

# -----[ load_blocks ]-----------------------------------------------
# Load the database of IP range to location ID mappings from the given
# file
#
# Parameters:
# - file that contains the mapping
# -------------------------------------------------------------------
sub load_blocks($)
{
    my ($self, $file_name)= @_;
    my $progress= UCL::Progress::new();
    $progress->{pace}= 1;
    $progress->{verbose}= $self->{verbose};
    $progress->{message}= "Loading blocks: ";

    my $result= open FILE, "<$file_name";
    my $line_number= 1;
    if (!$result) {
	print "Error: could not open \"$file_name\": $!\n";
	return -1;
    }

    # Skip Copyright info
    $_= <FILE>;
    if (!/^Copyright.*/) {
	print "Error: no copyright info in \"$file_name\" at line $line_number\n";
	return -1;
    }
    $line_number++;

    # Skip field info
    $_= <FILE>;
    if (!/^startIpNum,endIpNum,locId$/) {
	print "Error: wrong field info in \"$file_name\" at line $line_number\n";
	return -1;
    }
    $line_number++;

    while (<FILE>) {
	chomp;
	my @fields= split /\,/;
	
	if (scalar(@fields) != 3) {
	    print "Error: wrong number of fields (".scalar(@fields).
		") in \"$file_name\" at line $line_number\n";
	    return -1;
	}

	my $startIpNum= $fields[0];
	my $endIpNum= $fields[1];
	my $locId= $fields[2];

	$startIpNum=~ tr/\"//d;
	$endIpNum=~ tr/\"//d;
	$locId=~ tr/\"//d;

	$self->_add_range($startIpNum, $endIpNum, $locId);

	$line_number++;
	$progress->progress(undef, $self->{block_cnt});
    }
    $progress->end(undef, $self->{block_cnt});
    close FILE;

    return 0;
}

# -----[ ip2int ]----------------------------------------------------
# Convert an IP address in dotted format into an integer
#
# Parameters:
# - IP address (i.e. A.B.C.D)
# -------------------------------------------------------------------
sub ip2int($)
{
    my $ip= shift;

    my @ip_parts= split /\./, $ip, 4;

    return ((($ip_parts[0]*256)+
	     $ip_parts[1])*256+
	    $ip_parts[2])*256+
		$ip_parts[3];
}

# -----[ int2ip ]----------------------------------------------------
# Convert an integer into an IP address in dotted format
#
# Parameters:
# - IP address (in integer format)
# -------------------------------------------------------------------
sub int2ip($)
{
    my $ip_int= shift;
    my $ip;

    $ip= $ip_int & 255;
    $ip_int= $ip_int >> 8;
    $ip= ($ip_int & 255).".$ip";
    $ip_int= $ip_int >> 8;
    $ip= ($ip_int & 255).".$ip";
    $ip_int= $ip_int >> 8;
    $ip= ($ip_int & 255).".$ip";

    return $ip;
}

# -----[ _add_range ]------------------------------------------------
# Add into the instance's Patricia tree the prefixes that cover the
# given range
#
# The function works as follows: each range of IP addresses is divided
# into the smallest set of independent CIDR prefixes that fully cover
# the range. Each prefix is then added into the Patricia tree.
#
# Parameters:
# - first IP address (in integer format)
# - last IP address (in integer format)
# - location ID (i.e. reference to a record in the locations'
#   database)
# -------------------------------------------------------------------
sub _add_range($$$)
{
    my $self= shift;
    my $ip_int_start= shift;
    my $ip_int_end= shift;
    my $locId= shift;

    my $ip_range= $ip_int_end-$ip_int_start+1;
    my $saved_ip_range= $ip_range;

    my $total_range= 0;

    while ($ip_range > 0) {

	# Find first non-zero bit, i.e. compute the size of the
	# largest CIDR prefix which is aligned with the IP range's
	# lowest bound.
	my $length= 0;
	while ($length < 32) {
	    ($ip_int_start & (1 << $length)) and last;
	    $length++;
	}

	# If the IP range is larger than the computed CIDR prefix, add
	# it to the database.
	if ($ip_range >= (1 << $length)) {
	    my $range= $self->_add_prefix($ip_int_start, 32-$length, $locId);
	    $total_range+= $range;
	    $ip_int_start+= $range;
	    $ip_range-= $range;
	} else {
	    # Otherwise, look for a smaller CIDR prefix...
	    my $index2;
	    for ($index2= $length; $index2 >= 0; $index2--) {
		if ($ip_range & (1 << $index2)) {
		    my $range= $self->_add_prefix($ip_int_start,
						  32-$index2, $locId);
		    
		    $total_range+= $range;
		    $ip_int_start+= $range;
		    $ip_range-= $range;
		    last;
		}		
	    }
	}
    }

    # ---| Check that whole IP range has been covered |---
    if ($total_range != $saved_ip_range) {
	die "IP range error ($total_range != $saved_ip_range)";
    }
}

# -----[ _ip2array ]-------------------------------------------------
sub _ip2array($)
{
    my ($ip_int)= @_;
    my @array= ();

    $array[3]= $ip_int & 255;
    $ip_int= $ip_int >> 8;
    $array[2]= ($ip_int & 255);
    $ip_int= $ip_int >> 8;
    $array[1]= ($ip_int & 255);
    $ip_int= $ip_int >> 8;
    $array[0]= ($ip_int & 255);

    return @array;
}

# -----[ _array2ip ]-------------------------------------------------
sub _array2ip(@)
{
    my (@array)= @_;

    return ((($array[0] * 256) + $array[1]) * 256 + $array[2]) * 256 +$array[3];
}

# -----[ _pack_prefix ]----------------------------------------------
sub _pack_prefix($$)
{
    my ($prefix_int, $length)= @_;

    my $packed_prefix;
    my @ip_array= _ip2array($prefix_int);
    #print "_pack::array ".(join '.', @ip_array)."\n";
    if ($length > 24) {
	$packed_prefix= pack("CCCCC", $length, @ip_array);
    } elsif ($length > 16) {
	$packed_prefix= pack("CCCC", $length, @ip_array);
    } elsif ($length > 8) {
	$packed_prefix= pack("CCC", $length, @ip_array);
    } else {
	$packed_prefix= pack("CC", $length, @ip_array);
    }
    return $packed_prefix;
}

# -----[ _unpack_prefix ]--------------------------------------------
sub _unpack_prefix($)
{
    my ($packed_prefix)= @_;
    my ($prefix, $length);

    my @ip_array= unpack "CCCCC", $packed_prefix;
    $length= shift @ip_array;
    $prefix= _array2ip(@ip_array);
    #print "_unpack::array ".(join '.', @ip_array)."\n";
    #print "_unpack::prefix $prefix (".int2ip($prefix).")\n";
    return ($prefix, $length);
}

# -----[ _add_prefix ]-----------------------------------------------
sub _add_prefix($$$$)
{
    my ($self, $int_prefix, $length, $locId)= @_;

    my $packed_prefix= _pack_prefix($int_prefix, $length);
    my ($upi, $ul)= _unpack_prefix($packed_prefix);
    ($upi != $int_prefix) and die "beeh ($int_prefix != $upi)";
    $self->{blocks}->{$packed_prefix}= int($locId);
    
    # ---| Update prefix statistics |---
    ($length > $self->{longest_prefix}) and
	$self->{longest_prefix}= $length;
    $self->{block_cnt}++;

    return (1 << (32-$length));
}

# -----[ find_locId ]------------------------------------------------
sub find_locId($$)
{
    my ($self, $locId)= @_;

    if (exists($self->{aliases}->{$locId})) {
	$locId= $self->{aliases}->{$locId};
    }
    return $locId;
}

# -----[ find_location ]---------------------------------------------
sub find_location($$)
{
    my ($self, $locId)= @_;

    return $self->{locations}->[$locId];
}

