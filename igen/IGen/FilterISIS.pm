# ===================================================================
# IGen::FilterISIS
#
# (c) 2005, Networking team
#           Computing Science and Engineering Dept.
#           Université catholique de Louvain
#           Belgium
#
# author Bruno Quoitin (bqu@info.ucl.ac.be)
# date 31/08/2005
# lastdate 02/09/2005
# ===================================================================

package IGen::FilterISIS;

require Exporter;
@ISA= qw(Exporter IGen::FilterBase);

use strict;
use IGen::FilterBase;

# -----[ _init ]-----------------------------------------------------
#
# -------------------------------------------------------------------
sub _init()
{
    my ($self)= @_;

    $self->SUPER::_init();
    $self->set_capabilities(IGen::FilterBase::IMPORT_SINGLE);
    $self->set_extensions('.isis', '.pcap');
}

# -----[ import_graph ]----------------------------------------------
#
# -------------------------------------------------------------------
sub import_graph($$)
{
    my ($self, $filename)= @_;
    my $graph= undef;



    $self->set_error("not yet implemented");
    return $graph;
}
