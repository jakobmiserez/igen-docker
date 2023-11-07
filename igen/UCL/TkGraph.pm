# ===================================================================
# TkGraph.pm
#
# (c) 2004, Networking team
#           Computing Science and Engineeding Dept.
#           Université catholique de Louvain
#           Belgium
#
# author Bruno Quoitin
# date 02/06/2005
# lastdate 02/06/2005
# ===================================================================

package UCL::TkGraph;

use Tk::widgets qw/DialogBox/;
use base qw/Tk::Derived Tk::DialogBox/;
use strict;

Construct Tk::Widget 'TkGraphDialog';

# -------------------------------------------------------------------
sub ClassInit
{
    my ($class, $mw)= @_;
    $class->SUPER::ClassInit($mw);
}

