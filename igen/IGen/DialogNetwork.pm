# ===================================================================
# IGen::DialogNetwork
#
# (c) 2005, Networking team
#           Computing Science and Engineering Dept.
#           Université catholique de Louvain
#           Belgium
#
# author Bruno Quoitin (bqu@info.ucl.ac.be)
# date 05/07/2005
# lastdate 18/07/2005
# ===================================================================

package IGen::DialogNetwork;

require Exporter;
@ISA= qw(Exporter UCL::Tk::Dialog);

use Tk 800.000;
use Tk::Toplevel;

use strict;
use UCL::Tk::Dialog;
use IGen::DialogCapacity;
use IGen::DialogCluster;
use IGen::DialogGraph;
use IGen::DialogIGP;

# -----[ _init ]-----------------------------------------------------
#
# -------------------------------------------------------------------
sub _init()
{
    my ($self)= @_;
    
    $self->SUPER::_init(-title=>"Build domain \"".$self->{args}{-domain}."\"",
			-btn_okcancel);

    if (!defined($self->{result})) {
	$self->{result}{cluster}{spec}= 'k-medoids:5';
	$self->{result}{cluster}{show}= 0;
	$self->{result}{pop}{mesh}= 'sprint:2:2';
	$self->{result}{bb}{mesh}= 'delaunay';
	$self->{result}{bb}{links}= 2;
	$self->{result}{igp}= 'distance:0';
	$self->{result}{capacity}= 'access-backbone:155M:10G';
    }

    my $frame;
    my $subframe;

    # ---| clustering method |---
    $frame=
	$self->{top}->Frame(-relief=>'sunken',
			    -borderwidth=>1
			    )->pack(-side=>'top',
				    -fill=>'x',
				    -expand=>1);
    $subframe= $frame->Frame()->pack(-side=>'top',
				     -fill=>'x',
				     -expand=>1);
    $subframe->Label(-text=>'Clustering method: '
		     )->pack(-side=>'left',
			     -fill=>'x');
    $subframe->Button(-text=>'...',
		      -command=>[\&_edit_clustering, $self,
				 \$self->{result}{cluster}{spec}]
		      )->pack(-side=>'right');
    $subframe->Entry(-textvariable=>\$self->{result}{cluster}{spec},
		     -state=>'disabled'
		     )->pack(-side=>'right',
			     -fill=>'x');
    $subframe= $frame->Frame()->pack(-side=>'top',
				     -fill=>'x',
				     -expand=>1);
    $subframe->Checkbutton(-text=>'show clusters',
			   -variable=>\$self->{result}{cluster}{show}
			   )->pack(-side=>'left',
				   -fill=>'x');
    # ---| POP parameters |---
    $frame=
	$self->{top}->Frame(-label=>"POP",
			    -relief=>'sunken',
			    -borderwidth=>1
			    )->pack(-side=>'top',
				    -fill=>'x',
				    -expand=>1);
    $subframe= $frame->Frame()->pack(-side=>'top',
				     -fill=>'x',
				     -expand=>1);
    $subframe->Label(-text=>'Mesh method: '
		     )->pack(-side=>'left',
			     -fill=>'x');
    $subframe->Button(-text=>'...',
		      -command=>[\&_edit_mesh, $self,
				 \$self->{result}{pop}{mesh}]
		      )->pack(-side=>'right');
    $subframe->Entry(-textvariable=>\$self->{result}{pop}{mesh},
		     -state=>'disabled'
		     )->pack(-side=>'right',
			     -fill=>'x');
    
    # ---| backbone parameters |---
    $frame=
	$self->{top}->Frame(-label=>"Backbone",
			    -relief=>'sunken',
			    -borderwidth=>1
			    )->pack(-side=>'top',
				    -fill=>'x',
				    -expand=>1);
    $subframe= $frame->Frame()->pack(-side=>'top',
				     -fill=>'x',
				     -expand=>1);
    $subframe->Label(-text=>'Mesh method: '
		     )->pack(-side=>'left',
			     -fill=>'x');
    $subframe->Button(-text=>'...',
		      -command=>[\&_edit_mesh, $self,
				 \$self->{result}{bb}{mesh}]
		      )->pack(-side=>'right');
    $subframe->Entry(-textvariable=>\$self->{result}{bb}{mesh},
		     -state=>'disabled'
		     )->pack(-side=>'right',
			     -fill=>'x');
    $subframe= $frame->Frame()->pack(-side=>'top',
				     -fill=>'x',
				     -expand=>1);
    $subframe->Label(-text=>'Number of POP-POP links'
		     )->pack(-side=>'left',
			     -fill=>'x');
    $subframe->Spinbox(-from=>1,
		       -to=>5,
		       -textvariable=>\$self->{result}{bb}{links}
		       )->pack(-side=>'right',
			     -fill=>'x');

    # ---| IGP weight & capacity assignments |---
    $frame=
	$self->{top}->Frame(-relief=>'sunken',
			    -borderwidth=>1
			    )->pack(-side=>'top',
				    -fill=>'x',
				    -expand=>1);
    $subframe= $frame->Frame()->pack(-side=>'top',
				     -fill=>'x',
				     -expand=>1);
    $subframe->Label(-text=>'IGP assignment: '
		     )->pack(-side=>'left',
			     -fill=>'x');
    $subframe->Button(-text=>'...',
		      -command=>[\&_edit_igp, $self,
				 \$self->{result}{igp}]
		      )->pack(-side=>'right');
    $subframe->Entry(-textvariable=>\$self->{result}{igp},
		     -state=>'disabled'
		     )->pack(-side=>'right',
			     -fill=>'x');
    $subframe= $frame->Frame()->pack(-side=>'top',
				     -fill=>'x',
				     -expand=>1);
    $subframe->Label(-text=>'Capacity assignment: '
		     )->pack(-side=>'left',
			     -fill=>'x');
    $subframe->Button(-text=>'...',
		      -command=>[\&_edit_capacity, $self,
				 \$self->{result}{capacity}]
		      )->pack(-side=>'right');
    $subframe->Entry(-textvariable=>\$self->{result}{capacity},
		     -state=>'disabled'
		     )->pack(-side=>'right',
			     -fill=>'x');
}

# -----[ _edit_clustering ]------------------------------------------
#
# -------------------------------------------------------------------
sub _edit_clustering()
{
    my ($self, $clust_variable)= @_;

    my $dialog= IGen::DialogCluster->new(-parent=>$self->{main},
					 -method=>$$clust_variable);
    my $result= $dialog->show_modal();
    $dialog->destroy();

    if (defined($result)) {
	$$clust_variable=
	    $result->{method}.':'.(join ':', @{$result->{params}});
    }
}

# -----[ _edit_backbone_graph ]--------------------------------------
#
# -------------------------------------------------------------------
sub _edit_backbone_graph()
{
    my ($self)= @_;

    my $dialog= IGen::DialogGraph->new(-parent=>$self->{main},
				       -method=>$self->{result}{bb_mesh});
    my $result= $dialog->show_modal();
    $dialog->destroy();

    if (defined($result)) {
	$self->{result}{bb_mesh}= $result->{method}.':'.
	    (join ':', @{$result->{params}});
    }
}

# -----[ _edit_mesh ]-------------------------------------------
#
# -------------------------------------------------------------------
sub _edit_mesh($)
{
    my ($self, $mesh_variable)= @_;

    my $dialog= IGen::DialogGraph->new(-parent=>$self->{main},
				       -method=>$$mesh_variable);
    my $result= $dialog->show_modal();
    $dialog->destroy();

    if (defined($result)) {
	$$mesh_variable= $result->{method}.':'.
	    (join ':', @{$result->{params}});
    }
}

# -----[ _edit_igp ]-------------------------------------------------
#
# -------------------------------------------------------------------
sub _edit_igp($)
{
    my ($self, $igp_variable)= @_;

    my $dialog= IGen::DialogIGP->new(-parent=>$self->{main},
				     -method=>$$igp_variable);
    my $result= $dialog->show_modal();
    $dialog->destroy();

    if (defined($result)) {
	$$igp_variable= $result->{method}.':'.
	    (join ':', @{$result->{params}});
    }
}

# -----[ _edit_capacity ]--------------------------------------------
#
# -------------------------------------------------------------------
sub _edit_capacity($)
{
    my ($self, $capa_variable)= @_;

    my $dialog= IGen::DialogCapacity->new(-parent=>$self->{main},
					  -method=>$$capa_variable);
    my $result= $dialog->show_modal();
    $dialog->destroy();

    if (defined($result)) {
	$$capa_variable= $result->{method}.':'.
	    (join ':', @{$result->{params}});
    }
}
