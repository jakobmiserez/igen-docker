# ===================================================================
# IGen::Definitions
#
# (c) 2005, Networking team
#           Computing Science and Engineering Dept.
#           Université catholique de Louvain
#           Belgium
#
# author Bruno Quoitin (bruno.quoitin@uclouvain.be)
# date 03/10/2005
# lastdate 10/02/2009
# ===================================================================

package IGen::Definitions;

require Exporter;
@ISA= qw(Exporter);
@EXPORT= qw(get_ilink_relations
	    get_ilink_relations_options
	    ILINK_RELATION_PEER_PEER
	    ILINK_RELATION_PROV_CUST
	    ILINK_RELATION_SIBLING
	    ILINK_RELATIONS
	    ILINK_RELATIONS_NAMES
	    PROGRAM_NAME
	    PROGRAM_VERSION);

use strict;

# ---| Program name & version |--------------------------------------
use constant PROGRAM_NAME    => 'IGen';
use constant PROGRAM_VERSION => '0.15';

# ---| Business relationships |--------------------------------------
use constant ILINK_RELATION_PEER_PEER => 0;
use constant ILINK_RELATION_PROV_CUST => 1;
use constant ILINK_RELATION_SIBLING => 2;
use constant ILINK_RELATIONS => {
    (ILINK_RELATION_PEER_PEER) => 'Peer-Peer',
    (ILINK_RELATION_PROV_CUST) => 'Provider-Customer',
    (ILINK_RELATION_SIBLING)   => 'Sibling',
};
use constant ILINK_RELATIONS_NAMES => {};

# -----[ BEGIN: package initialization method ]----------------------
BEGIN
{
    foreach (keys %{ILINK_RELATIONS()}) {
	ILINK_RELATIONS_NAMES->{ILINK_RELATIONS->{$_}}= $_;
    }
}

# -----[ get_ilink_relations ]---------------------------------------
sub get_ilink_relations()
{
    return ILINK_RELATIONS;
}

# -----[ get_ilink_relations_options ]-------------------------------
sub get_ilink_relations_options()
{
    my @relations= ();
    foreach my $relation (keys %{(ILINK_RELATIONS)}) {
	my $name= ILINK_RELATIONS->{$relation};
	push @relations, ([$name=>$relation]);
    }
    return \@relations;
}
