# ===================================================================
# UCL::Graph.pm
#
# (c) 2005, Networking team
#           Computing Science and Engineeding Dept.
#           Université catholique de Louvain
#           Belgium
#
# author Bruno Quoitin
# date 06/07/2005
# lastdate 02/09/2005
# ===================================================================

package UCL::Graph;

require Exporter;
use Graph 0.20105;
@ISA= qw(Exporter);
#@EXPORT_OK= qw();

use strict;
use UCL::Graph::Base;
use UCL::Graph::Cluster;
use UCL::Graph::Generate;
use UCL::Graph::Measure;

# ---| Link attributes |---
use constant ATTR_CAPACITY => 'capacity'; # Link capacity
use constant ATTR_DELAY    => 'delay';    # Link delay
use constant ATTR_WEIGHT   => 'weight';   # Link IGP weight
use constant ATTR_LOAD     => 'load';     # Link load
use constant ATTR_UTIL     => 'util';     # Link utilization

# ---| Interdomain link attributes |---
use constant ATTR_RELATION => 'relation'; # Business relationship

# ---| Node attributes |---
use constant ATTR_COORD    => 'coord';    # Geographical coordinates
use constant ATTR_TYPE     => 'type';     # Node type (backbone/access)
use constant ATTR_NAME     => 'name';     # Node name
use constant ATTR_AS       => 'as';       # Domain-id

# ---| Domain-wide attributes |---
use constant ATTR_CLUSTERS => 'clusters'; # Clusters
use constant ATTR_TM       => 'TM';       # Traffic matrix
use constant ATTR_RM       => 'RM';       # Routing matrix
use constant ATTR_GFX      => 'gfx';      # Has geographical coordinates

# ---| Misc attributes |---
use constant ATTR_CLUSTER  => 'cluster';
use constant ATTR_COLOR    => 'color';
use constant ATTR_FLOW     => 'flow';
use constant ATTR_PATH     => 'path';
use constant ATTR_GUI_OBJ  => 'gui_obj';
