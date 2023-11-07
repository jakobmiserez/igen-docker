# ===================================================================
# IGen::FilterMaxMind
#
# (c) 2005, Networking team
#           Computing Science and Engineering Dept.
#           Université catholique de Louvain
#           Belgium
#
# author Bruno Quoitin (bqu@info.ucl.ac.be)
# date 23/08/2005
# lastdate 24/08/2005
# ===================================================================

package IGen::FilterMaxMind;

require Exporter;
@ISA= qw(Exporter IGen::FilterBase);

use strict;
use IGen::FilterBase;
use IGen::Util;

# -----[ _init ]-----------------------------------------------------
#
# -------------------------------------------------------------------
sub _init()
{
    my ($self)= @_;

    $self->SUPER::_init();
    $self->set_capabilities(IGen::FilterBase::IMPORT_SINGLE);
}

# -----[ import_graph ]----------------------------------------------
#
# -------------------------------------------------------------------
sub import_graph($$)
{
    my ($self, $filename)= @_;
    my %graphs= ();
    my %locations= ();
    my %coord= ();
    my $cnt= 0;

    if (!open(LOCATIONS, "<$filename")) {
	$self->set_error("could not load \"$filename\": $!");
	return undef;
    }

    $graphs{0}= new Graph::Undirected;

    # ---| Read Copyright info |---
    $_= <LOCATIONS>;
    if (!/^Copyright.*/) {
	$self->set_error("no copyright info");
	close(LOCATIONS);
	return undef;
    }
    
    # ---| Read field info |---
    $_= <LOCATIONS>;
    if (!/^locId,country,region,city,postalCode,latitude,longitude,dmaCode,areaCode$/) {
	$self->set_error("no field info");
	close(LOCATIONS);
	return undef;
    }

    # ---| Load all fields |---
    while (<LOCATIONS>) {
	chomp;
	my @fields= split /\,/;
	
	if (scalar(@fields) < 7) {
	    $self->set_error("wrong number of fields (".scalar(@fields).")");
	    close(LOCATIONS);
	    return undef;
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
	    print STDERR "\rWarning: skip invalid coordinates ",
	    "($latitude, $longitude)\n";
	    $valid= 0;
	}

	# Skip (0,0) locations
	if (($latitude == 0) && ($longitude == 0)) {
	    $valid= 0;
	}

	# Record valid locations
	if ($valid) {
	    $locations{int($locId)}=
		[$latitude, $longitude, $city, $country];

	    my $x= $longitude;
	    my $y= $latitude;
	    if ($x > 0) { $x= int($x/2)*2; }
	    else { $x= int($x/2)*2; }
	    if ($y > 0) { $y= int($y/2)*2; }
	    else { $y= int($y/2)*2; }

	    if (!exists($coord{$x}{$y})) {
		$coord{$x}{$y}= [$locId];
		$cnt++;
		$graphs{0}->add_vertex(int($locId));
		$graphs{0}->set_attribute(UCL::Graph::ATTR_COORD,
					  int($locId), [$x, $y]);
	    } else {
		push @{$coord{$x}{$y}}, ($locId);
	    }
	}
    }
    close(LOCATIONS);
    print "info: $cnt vertices\n";

    $self->set_error();
    return \%graphs;
}

# -----[ export_graph ]----------------------------------------------
#
# -------------------------------------------------------------------
sub export_graph($$$)
{
    my ($self, $graphs, $filename)= @_;

    $self->set_error("export not implemented");
    return -1;
}
