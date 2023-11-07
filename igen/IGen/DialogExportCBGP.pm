# ===================================================================
# IGen::DialogExportCBGP
#
# (c) 2005, Networking team
#           Computing Science and Engineering Dept.
#           Université catholique de Louvain
#           Belgium
#
# author Bruno Quoitin (bqu@info.ucl.ac.be)
# date 09/08/2005
# lastdate 05/10/2005
# ===================================================================

package IGen::DialogExportCBGP;

require Exporter;
@ISA= qw(Exporter IGen::DialogProperties);

use Tk 800.000;
use Tk::Toplevel;

use strict;
use IGen::DialogProperties;
use UCL::Tk::Dialog;

# -----[ _init_igp ]-------------------------------------------------
sub _init_igp($)
{
    my ($self)= @_;

    $self->_add_attribute_header('IGP');
    $self->_add_attribute_options('Model',
				  \$self->{result}{igp}{model},
				  [['simple IGP', 0],
				   ['OSPF', 1]],
				  -command=>[\&_update_igp, $self]);
    $self->{IGP}{Areas}=
	$self->_add_attribute_check('use area/PoP',
				    \$self->{result}{igp}{areas},
				    -state=>'disabled');
}

# -----[ _update_igp ]-----------------------------------------------
sub _update_igp($)
{
    my ($self)= @_;

    if ($self->{result}{igp}{model} == 1) {
	$self->{IGP}{Areas}->configure(-state=>'normal');
    } else {
	defined($self->{IGP}{Areas}) and
	    $self->{IGP}{Areas}->configure(-state=>'disabled');
    }
}

# -----[ _init_bgp ]-------------------------------------------------
sub _init_bgp($)
{
    my ($self)= @_;

    $self->_add_attribute_header('BGP');
    $self->_add_attribute_check('enable BGP',
				\$self->{result}{bgp}{enabled});
    $self->_add_attribute_options('iBGP structure',
				  \$self->{result}{ibgp}{method},
				  [['full-mesh', 0],
				   ['route-reflection', 1]]);
    $self->_add_attribute_check('define filters',
				\$self->{result}{bgp}{filters});
    $self->_add_attribute_check('use next-hop-self',
				\$self->{result}{bgp}{nhself});
    $self->_add_attribute_check('each AS originates a prefix',
				\$self->{result}{bgp}{originates});
    $self->_add_attribute_check('use "full-mesh" command',
				\$self->{result}{ibgp}{full_mesh_command});
}

# -----[ _init_options ]---------------------------------------------
sub _init_options()
{
    my ($self)= @_;


    $self->_add_attribute_header('Options');
    $self->_add_attribute_check('check reachability',
				\$self->{result}{checks}{reachability});
    $self->_add_attribute_check('check peerings',
				\$self->{result}{checks}{peerings});
    $self->_add_attribute_check('sim run',
				\$self->{result}{sim_run});
    $self->_add_attribute_check('allow version 1.1.21',
				\$self->{result}{allow_1_1_21});
}

# -----[ _init ]-----------------------------------------------------
#
# -------------------------------------------------------------------
sub _init()
{
    my ($self)= @_;

    $self->SUPER::_init(-title=>"Build C-BGP script",
			-btn_okcancel);

    if (!defined($self->{result})) {
	$self->{result}{filename}= '';
	# ---| IGP model |---
	$self->{result}{igp}{build}= 1;
	$self->{result}{igp}{model}= 0;
	$self->{result}{igp}{areas}= 0;
        # ---| BGP model |---
	$self->{result}{bgp}{enabled}= 1;
	$self->{result}{bgp}{filters}= 1;
	$self->{result}{bgp}{nhself}= 1;
	$self->{result}{bgp}{originates}= 1;
	$self->{result}{ibgp}{method}= 0;
	$self->{result}{ibgp}{full_mesh_command}= 1;
	# ---| Checks |---
	$self->{result}{checks}{reachability}= 0;
	$self->{result}{checks}{peerings}= 0;
	$self->{result}{sim_run}= 0;
	$self->{result}{allow_1_1_21}= 1;
    }

    if (exists($self->{args}{-filename})) {
	$self->{result}{filename}= $self->{args}{-filename};
    }

    $self->{Top}{top}=
	$self->{top}->Frame(-relief=>'sunken',
			    -borderwidth=>1
			    )->pack(-side=>'top',
				    -fill=>'x',
				    -expand=>1);
    # ---| Filename |---
    my $subframe= $self->{Top}{top}->Frame()->pack(-side=>'top',
						   -fill=>'x',
						   -expand=>1);
    $self->_add_attribute_header('Output');
    $self->_add_attribute_filename('Filename',
				   \$self->{result}{filename});
    # ---| IGP model |---
    $self->_init_igp();
    # ---| iBGP structure |---
    $self->_init_bgp();
    # ---| Options |---
    $self->_init_options();
}
