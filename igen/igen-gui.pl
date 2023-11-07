#!/usr/bin/perl
# ===================================================================
# igen-gui.pl
#
# (c) 2005-2009, IP Networking Lab
#                Computing Science and Engineering Dept.
#                Université catholique de Louvain
#                Louvain-la-Neuve
#                Belgium
#
# author Bruno Quoitin (bruno.quoitin@uclouvain.be)
# date 26/06/2004
# lastdate 12/02/2009
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330,
# Boston,  MA 02111-1307  USA
#
# $Id$
# ===================================================================
# Latest changes:
# (15/07/2009) change option --weights to --igp-weights. Document
#              --igp-weights methods in CLI help
# (12/02/2009) allow explicit request to compute routing matrix
#              through GUI
# (12/02/2009) fix bug in SVG export for backbone router nodes
# (10/02/2009) fix bug in multi-tours mesh generation: graph
#              coordinates were not copied to sub graph (used by TSP)
# (10/02/2009) fix bug in initialization of mesh generation methods
#              (was too late to be listed in CLI help)
# ===================================================================

use strict;

use IO::Handle;
use Tk 800.000;
use Tk::Balloon;
use Tk::BrowseEntry;
use Tk::HList;
use Tk::ItemStyle;
use Tk::Menubar;
use Tk::Menubutton;
use Tk::ProgressBar;
use Tk::Spinbox;
use Tk ':eventtypes';
use threads;
use Getopt::Long;
use Graph 0.20105;
use Graph::Directed;
use Graph::Undirected;
use POSIX;
use UCL::Geo;
use UCL::Graph;
use UCL::Graph::Base;
use UCL::Graph::Cluster;
use UCL::Graph::Generate;
use UCL::Graph::Measure;
use UCL::Heap;
use UCL::Progress;
use UCL::SVG;
use UCL::Triangulation;
use Statistics::Basic;
use Statistics::Basic::Mean;
use Statistics::Basic::Variance;
use Statistics::Basic::StdDev;
use Statistics::Basic::CoVariance;
use Statistics::Basic::Correlation;
use Statistics::Descriptive;

use vars qw(%GUI);
# ---[ utilities ]---
use IGen::Definitions;
use IGen::Random;
use IGen::Util;
# ---[ dialog boxes ]---
use IGen::DialogAbout;
use IGen::DialogASRelations;
use IGen::DialogCapacity;
use IGen::DialogCluster;
use IGen::DialogContinent;
use IGen::DialogExportCBGP;
use IGen::DialogGraphMentor;
use IGen::DialogGraphMT;
use IGen::DialogInput;
use IGen::DialogInterConnect;
use IGen::DialogInternet;
use IGen::DialogLatticeCellSize;
use IGen::DialogLinkCreate;
use IGen::DialogLinkProperties;
use IGen::DialogMeasure;
use IGen::DialogMessage;
use IGen::DialogNetwork;
use IGen::DialogProgress;
use IGen::DialogRouterProperties;
use IGen::DialogRouters;
use IGen::DialogSelectRouter;
use IGen::DialogShowClusters;
use IGen::DialogShowData;
use IGen::DialogShowDomains;
use IGen::DialogShowLinks;
use IGen::DialogShowRouters;
use IGen::DialogShowRM;
use IGen::DialogShowStatistics;
use IGen::DialogShowTM;
use IGen::DialogTraffic;
# ---[ import/export filters ]---
use IGen::FilterASRelations;
use IGen::FilterBRITE;
use IGen::FilterCBGP;
use IGen::FilterGML;
use IGen::FilterGMT;
use IGen::FilterISIS;
use IGen::FilterMaxMind;
use IGen::FilterMerindol;
use IGen::FilterNTF;
use IGen::FilterPOPS;
use IGen::FilterRIG;
use IGen::FilterTOTEM;
# ---[ Misc ]---
#use IGen::CanvasGraph;


#####################################################################
#
# GLOBAL VARIABLES
#
#####################################################################

my %igen_continents= undef;
my %igen_mesh_methods= undef;
my %igen_clustering_methods= undef;
my %igen_traffic_methods= undef;
my %igen_igp_methods= undef;
my %igen_capacity_methods= undef;
my %igen_measure_methods= undef;
my %igen_filters= undef;
my %igen_filters_extensions= undef;

my @igen_link_capacities= ();
my %igen_link_widths= ();
my @igen_link_load_colors= ();
my %igen_igp_plf= ();
my @igen_igp_plf_steps= ();

my $global_show= 0;
my $global_verbosity= 1;
my $global_plot_params;
my $global_options;
my $global_time= undef;

my $db_graph= undef;

use constant HPIXELS => 800;
use constant VPIXELS => 400;
use constant HBORDER => 10;
use constant VBORDER => 10;
my $minx= -180;
my $maxx= 180;
my $miny= -90;
my $maxy= 90;

# ----- current selection -----
my $current_as= undef;
my $current_router= undef;
my $current_link= undef;

# -----[ GUI objects ]-----
#my $mw;
my %GUI;
my $bCanvas;
my $bCanvasText;
my $cCanvas;
my $tTerminal;
my $tStatus;

#####################################################################
#
# CONSTANTS DEFINITIONS
#
#####################################################################

use constant XBOUND => 360;
use constant YBOUND => 180;
use constant XOFFSET => -180;
use constant YOFFSET => -90;

use constant INFINITY => 2**31-1;

use constant MENTOUR_TSP_NN => 0;
use constant MENTOUR_TSP_FN => 1;

use constant WAXMAN_ALL => 0;
use constant WAXMAN_INCR => 1;

use constant FAST_REROUTE_NONE => 0;
use constant FAST_REROUTE_LFA => 1;
use constant FAST_REROUTE_UTURN => 2;
use constant FAST_REROUTE_UNUSED => 3;

igen_main();


#####################################################################
#
# REPORTING & UTILITY FUNCTIONS
#
#####################################################################

# -----[ time_save ]-------------------------------------------------
#
# -------------------------------------------------------------------
sub time_save() {
    $global_time= time();
}

# -----[ time_diff ]-------------------------------------------------
#
# -------------------------------------------------------------------
sub time_diff() {
    my $current_time= time();
    if (!defined($global_time)) {
	die "time_diff() called before time_save()";
    }
    my $diff= $current_time-$global_time;
    $global_time= $current_time;
}

# -----[ terminal_clear ]----------------------------------------
#
# -------------------------------------------------------------------
sub gui_terminal_clear()
{
    (!exists($GUI{Terminal})) and return;
    $tTerminal->delete('1.0', 'end');
}

# -----[ gui_terminal_update ]---------------------------------------
#
# -------------------------------------------------------------------
sub gui_terminal_update($)
{
    my ($msg)= @_;

    gui_terminal_clear();
    gui_terminal_add($msg);
}

# -----[ gui_terminal_add ]------------------------------------------
#
# -------------------------------------------------------------------
sub gui_terminal_add($)
{
    my ($msg)= @_;
    
    if (exists($GUI{Terminal})) {
	$tTerminal->insert('end', $msg);
    } else {
	print STDOUT "$msg";
    }
}

# -----[ increase_verbosity ]----------------------------------------
#
#--------------------------------------------------------------------
sub increase_verbosity()
{
    $global_verbosity++;
}

# -----[ decrease_verbosity ]----------------------------------------
#
#--------------------------------------------------------------------
sub decrease_verbosity()
{
    if ($global_verbosity > 0) {
	$global_verbosity--;
    }
}

# -----[ gui_update_hint ]-------------------------------------------
# Update hint with the mouse coordinates in the map
# -------------------------------------------------------------------
sub gui_update_hint($$$)
{
    my ($canvas, $x, $y)= @_;

    $bCanvasText= "(".int(gui_screen2x($canvas, $canvas->canvasx($x))).",".
	int(gui_screen2y($canvas, $canvas->canvasy($y))).")";
}

# -----[ gui_init_link_attributes ]----------------------------------
#
# -------------------------------------------------------------------
sub gui_init_link_attributes($)
{
    my ($canvas)= @_;

    my ($x, $y)= (25, 0);

    foreach my $capacity (@igen_link_capacities) {
	my $txt_capacity= capacity2text($capacity);
	$canvas->createText($x, $y+5,
			    -text=>$txt_capacity,
			    -fill=>'black'
			    );
	my $width= $igen_link_widths{$txt_capacity};
	$canvas->createLine(50, $y+5, $canvas->width, $y+5,
			    -width=>$width,
			    -fill=>'black');
	$y+= 10;
    }
    $y+= 10;
    for (my $load= 0; $load < scalar(@igen_link_load_colors); $load++) {
	$canvas->createText($x, $y+5,
			    -text=>sprintf "%.1f %%",
			    ($load*100/scalar(@igen_link_load_colors)),
			    -fill=>'black'
			    );
	my $color= $igen_link_load_colors[$load];
	$canvas->createRectangle(50, $y, $canvas->width, $y+9,
				 -fill=>$color);
	$y+=10;
    }
}

# -----[ gui_canvas_router_event ]-----------------------------------
# Event types:
# - select  : select object
# - context : open context pop-up
# -------------------------------------------------------------------
sub gui_canvas_router_event($$$$)
{
    my ($canvas, $context, $x, $y)= @_;

    my $item= $canvas->find('withtag', 'current');
    my @taglist= $canvas->gettags($item);

    # ---| Retrieve router info in tags' list |---
    my $rt_id= $taglist[1];
    my $rt_as= $taglist[2];

    # ---| Take action depending on context |---
    if ($context eq 'context') {
	my $graph= $db_graph->{as2graph}->{$rt_as};
	my $popupMenu= $canvas->Menu(-tearoff=>0,
				     -relief=>'groove',
				     -borderwidth=>1,
				     -menuitems=>
				     [[Button => 'Properties',
				       -command=>[\&gui_show_router_properties,
						  $graph, $rt_id],
				       ]]);
	$popupMenu->post($canvas->rootx+$x,
			 $canvas->rooty+$y);
    } elsif ($context eq 'click') {
	select_router($rt_id, $rt_as);
    }
}

# -----[ gui_canvas_link_event ]-------------------------------------
# Event types:
# - select  : select object
# - context : open context pop-up
# -------------------------------------------------------------------
sub gui_canvas_link_event($$$$)
{
    my ($canvas, $context, $x, $y)= @_;
    my $item= $canvas->find('withtag', 'current');
    my @taglist= $canvas->gettags($item);

    # ---| Retrieve link info in tags' list |---
    my $type= $taglist[0];
    my $src= $taglist[1];
    my $dst= $taglist[2];

    # ---| Related tag depend on link type |---
    my $graph= undef;
    if ($type eq 'link') {
	my $as= $taglist[3];
	$graph= $db_graph->{as2graph}->{$as};
    } elsif ($type eq 'ilink') {
	$graph= $db_graph->{igraph};
    }
    (!defined($graph)) and die;

    # ---| Take action depending on context |---
    if ($context eq 'context') {
	my $popupMenu= $canvas->Menu(-tearoff=>0,
				     -relief=>'groove',
				     -borderwidth=>1,
				     -menuitems=>
				     [[Button => 'Properties',
				       -command=>[\&gui_show_link_properties,
						  $graph, [$src, $dst]],
				       ]]);
	$popupMenu->post($canvas->rootx+$x,
			 $canvas->rooty+$y);
    } elsif ($context eq 'click') {
	gui_terminal_update(gui_show_link($src, $dst, $graph));
    }
}

# -----[ gui_show_router_properties ]--------------------------------
#
# -------------------------------------------------------------------
sub gui_show_router_properties($$)
{
    my ($graph, $router)= @_;

    my $dialog= IGen::DialogRouterProperties->new(-parent=>$GUI{Main},
						  -graph=>$graph,
						  -router=>$router);
    $dialog->show_modal();
    $dialog->destroy();
}

# -----[ gui_show_link_properties ]----------------------------------
#
# -------------------------------------------------------------------
sub gui_show_link_properties($$)
{
    my ($graph, $link)= @_;
    
    my $dialog= IGen::DialogLinkProperties->new(-parent=>$GUI{Main},
						-graph=>$graph,
						-link=>$link,
						-capacities=>\@igen_link_capacities);
    my $result= $dialog->show_modal();
    $dialog->destroy();
    (!defined($result)) and return;
    
    # ---| Update link |---
    #gui_redraw_link($GUI{Canvas}, $graph, $link->[0], $link->[1], $global_plot_params);
}

# -----[ gui_create ]------------------------------------------------
#
# -------------------------------------------------------------------
sub gui_create($)
{
    my $noborder= shift;
    
    my $max_width= HPIXELS();
    my $max_height= VPIXELS();
    if ($noborder == 0) {
	$max_width= HPIXELS()+HBORDER();
	$max_height= VPIXELS()+VBORDER();
    }

    my $fLeft;
    my $fRight;
    my $fCanvas;
    my $fCommands;
    my $fTerm;
    my $fClusterNVar;

    # main window
    $GUI{Main}= MainWindow->new;
    $GUI{Main}->title("".PROGRAM_NAME." ".PROGRAM_VERSION."");
    $GUI{Main}->resizable(0,0);

    my $mw= $GUI{Main};

    # Top-level frames
    my $fTop= $mw->Frame()->pack(-side=>'top', -fill=>'x');
    my $fBottom=$mw->Frame()->pack(-side=>'bottom', -fill=>'x');
    $fLeft= $mw->Frame()->pack(-side=>'left', -fill=>'both', -expand=>1);
    $fRight= $mw->Frame(-pady=>5,
			-padx=>5,
			)->pack(-side=>'right', -fill=>'both',
				-anchor=>'w');

    # Build menu bar
    my $MenuItems=
	[
	 [Cascade=>'~Graph', -menuitems=>
	  [
	   [Button=>'Import', -command=>\&gui_menu_filter_import],
	   [Button=>'Generate',
	    -command=>\&gui_menu_gen_random_vertices],
	   [Button=>'Close', -command=>\&gui_menu_close],
	   [Separator=>''],
	   [Cascade=>'~Export', -menuitems=>
	    [
	     [Button=>'Single domain',
	      -command=>[\&gui_menu_filter_export,
			 IGen::FilterBase::EXPORT_SINGLE]],
	     [Button=>'All domains',
	      -command=>[\&gui_menu_filter_export,
			 IGen::FilterBase::EXPORT_MULTIPLE]],			
	     [Separator=>''],
	     [Button=>'as PS', -command=>\&gui_menu_export_ps],
	     [Button=>'as SVG', -command=>\&gui_menu_export_svg],
	     ]
	    ],
	   [Separator=>''],
	   [Cascade=>'Traffic matrix', -menuitems=>
	    [
	     [Button=>'Load', -command=>\&gui_menu_traffic_load],
	     [Button=>'Save', -command=>\&gui_menu_traffic_save],
	     [Button=>'Generate',
	      -command=>\&gui_menu_traffic_generate],
	     ],
	    ],
	   [Separator=>''],
	   [Button=>'~Quit', -command=>sub {$mw->destroy}],
	   ]
	  ],
	 [Cascade=>'~Build', -menuitems=>
	  [
	   [Button=>'Intradomain Network',
	    -command=>\&gui_menu_build_intra],
	   [Button=>'Intradomain mesh',
	    -command=>\&gui_menu_build_mesh],
	   [Button=>'Intradomain clear',
	    -command=>\&gui_menu_intra_clear],
	   [Button=>'Intradomain reduce',
	    -command=>\&gui_menu_intra_reduce],
	   [Button=>'Intradomain clustering',
	    -command=>\&gui_menu_intra_clustering],
	   [Separator=>''],
	   [Button=>'Assign capacities',
	    -command=>\&gui_menu_capacity],
	   [Button=>'Assign IGP weights',
	    -command=>\&gui_menu_igp],
	   [Separator=>''],
	   [Button=>'Interdomain clear',
	    -command=>\&gui_menu_inter_clear],
	   [Button=>'Interconnect domains',
	    -command=>\&gui_menu_inter_connect],
#	   [Button=>'Interdomain Barabasi-Albert',
#	    -command=>\&gui_menu_build_barabasi_albert,
#	   -state=>'disabled'],
#	   [Button=>'Interdomain Ghitle',
#	    -state=>'disabled'],
#	   [Separator=>'', ],
	   [Button=>'Build all',
	    -command=>\&gui_menu_build_internet],
	   ]
	  ],
	 [Cascade=>'~Measure', -menuitems=>
	  [
	   [Button=>'Measure',
	    -command=>\&gui_menu_measure],
	   [Separator=>''],
	   [Button=>'Total graph weight (cost)',
	    -command=>\&gui_measure_total_weight],
	   [Button=>'Node-degree distribution',
	    -command=>\&gui_measure_node_degree],
	   [Button=>'Hop-count distribution',
	    -command=>\&gui_measure_hop_counts],
	   [Button=>'Path-length distribution',
	    -command=>\&gui_measure_path_length],
#		      [Button=>'Clustering coefficient',
#	   -state=>'disabled'],
	  [Button=>'Cell-density',
	   -command=>\&gui_measure_cell_density],
	   [Separator=>''],
	   [Button=>'Links utilization',
	    -command=>\&gui_measure_link_utilization],
#		      [Button=>'Routers utilization', -state=>'disabled'],
	   [Button=>'Maximum throughput',
	    -command=>\&gui_measure_throughput],
	   [Button=>'Path-diversity',
	    -command=>\&gui_measure_path_diversity],
	   [Button=>'Edge-connectivity',
	    -command=>\&gui_measure_edge_connectivity],
	   [Separator=>''],
	   [Button=>'IP Fast Reroute',
	    -command=>\&gui_measure_fast_reroute],
	   ],
	  ],
	 [Cascade=>'~Search', -menuitems=>
	  [
	   [Button=>'~Router', -command=>\&gui_menu_search_router],
	   ]
	  ],
	 [Cascade=>'~Options', -menuitems=>
	  [
	   [Cascade=>'Distance', -menuitems=>
	    [
	     [Radiobutton=>'Euclidian',
	      -value=>UCL::Graph::Base::DISTANCE_EUCLIDIAN,
	      -variable=>\$global_options->{distance}],
	     [Radiobutton=>'Terrestrial',
	      -value=>UCL::Graph::Base::DISTANCE_TERRESTRIAL,
	      -variable=>\$global_options->{distance}],
	     ],
	    ],
	   [Checkbutton=>'Equal-Cost Multi-Path',
	    -variable=>\$global_options->{ecmp}],
	   [Button=>'Test', -command=>\&igen_test],
	   [Button=>'Create link', -command=>\&gui_create_link],
	   [Button=>'Compute routing matrix', -command=>\&gui_compute_rm],
	   ]
	  ],
	 [Cascade=>'~View', -menuitems=>
	  [
	   [Button=>'Zoom in', -command=>\&gui_menu_zoom_in],
	   [Button=>'Zoom out', -command=>\&gui_menu_zoom_out],
	   [Button=>'Zoom domain', -command=>\&gui_menu_zoom_domain],
	   [Button=>'Default zoom', -command=>\&gui_menu_zoom_default],
	   [Separator=>''],
	   [Checkbutton=>'Show continents',
	    -variable=>\$global_plot_params->{continents},
	    -command=>\&gui_menu_view_redraw],
	   [Checkbutton=>'Show grid',
	    -variable=>\$global_plot_params->{grid},
	    -command=>\&gui_menu_view_redraw],
	   [Checkbutton=>'Show labels',
	    -variable=>\$global_plot_params->{labels},
	    -command=>\&gui_menu_view_redraw],
	   [Checkbutton=>'Show intradomain links',
	    -variable=>\$global_plot_params->{links},
	    -command=>\&gui_menu_view_redraw],
	   [Checkbutton=>'Show access routers',
	    -variable=>\$global_plot_params->{access},
	    -command=>\&gui_menu_view_redraw],
	   [Checkbutton=>'Show interdomain links',
	    -variable=>\$global_plot_params->{igraph},
	    -command=>\&gui_menu_view_redraw],
	   [Separator=>''],
	   [Button=>'Filter by zone',
	    -command=>\&gui_menu_filter_zone],
	   [Button=>'Filter access routers',
	    -command=>\&gui_menu_filter_access],
#		      [Button=>'Filter by ~domain', -command=>\&gui_menu_filter_domain],
	   [Separator=>''],
	   [Button=>'~Redraw', -command=>\&gui_menu_view_redraw],
	   [Separator=>''],
	   [Button=>'Show clusters',
	    -command=>\&gui_menu_show_clusters],
	   [Button=>'Show domains',
	    -command=>\&gui_menu_show_domains],
	   [Button=>'Show Links', -command=>\&gui_menu_show_links],
	   [Button=>'Show Routers', -command=>\&gui_menu_show_routers],
	   [Button=>'Show RM', -command=>\&gui_menu_show_RM],
	   [Button=>'Show TM', -command=>\&gui_menu_show_TM],
	   [Separator=>''],
	   [Button=>'Show ILinks',
	    -command=>sub {
		gui_menu_show_links($db_graph->{igraph});
		}],
	   ]
	  ],
	   [Button=>'About', -command=>\&gui_menu_about]
	   ];
    my $mbMenu= $mw->Menu(-menuitems=>$MenuItems);
    $mw->configure(-menu=>$mbMenu);
    
   # Build status bar
    $tStatus= $fBottom->Text(-height=>1);
    $tStatus->pack(-padx=>0, -pady=>0, -side=>'bottom', -fill=>'x');

    # Canvas
    $fCanvas= $fLeft->Frame(-relief=>'sunken',
			    -borderwidth=>1);
    $fCanvas->pack(-pady=>5, -padx=>5,
		   -expand=>1,
		   -fill=>'both');
    $GUI{Canvas}= $fCanvas->Canvas(-background=>'white',
				   -height=>$max_height,
				   -width=>$max_width,
				   -state=>'normal');
    $cCanvas= $GUI{Canvas};
    $cCanvas->pack(-side=>'top',
		   -expand=>1, -fill=>'both');
    $cCanvas->CanvasBind("<Motion>", [\&gui_update_hint, Ev('x'), Ev('y')]);

    my $lDomain= $fRight->Label(-text=>'Current domain')->pack(-side=>'top', -fill=>'x');
    my $tDomain= $fRight->Label(-textvariable=>\$current_as,
				-relief=>'sunken',
				-borderwidth=>1,
				-state=>'disabled')->pack(-side=>'top', -fill=>'x');
    my $lRouter= $fRight->Label(-text=>'Current router')->pack(-side=>'top', -fill=>'x');
    my $tRouter= $fRight->Label(-textvariable=>\$current_router,
				-relief=>'sunken',
				-borderwidth=>1,
				-state=>'disabled'
				)->pack(-side=>'top',
					-fill=>'x');
    $GUI{LinkAttributes}= $fRight->Canvas(-relief=>'sunken',
					  -borderwidth=>1,
					  -background=>'white',
					  -width=>100,
					  )->pack(-pady=>5,
						  -side=>'top',
						  -fill=>'y',
						  -expand=>1
						  );

    $fRight->Button(-text=>'-->', -command=> sub {
	$global_plot_params->{xscroll}-= 10;
	gui_menu_view_redraw();
    })->pack(-side=>'bottom', -fill=>'x');
    $fRight->Button(-text=>'<--', -command=> sub {
	$global_plot_params->{xscroll}+= 10;
	gui_menu_view_redraw();
    })->pack(-side=>'bottom', -fill=>'x');
    $fRight->Button(-text=>'up', -command=> sub {
	$global_plot_params->{yscroll}+= 10;
	gui_menu_view_redraw();
    })->pack(-side=>'bottom', -fill=>'x');
    $fRight->Button(-text=>'down', -command=> sub {
	$global_plot_params->{yscroll}-= 10;
	gui_menu_view_redraw();
    })->pack(-side=>'bottom', -fill=>'x');
    #fRight->Label(-textvariable=>\$global_plot_params->{zoom_factor}
    #	 )->pack(-side=>'bottom',
    #		 -fill=>'x',
    #		 -expand=>1);

    # Terminal
    $fTerm= $fLeft->Frame()->pack(-anchor=>'w', -side=>'bottom',
				     -fill=>'both',
				     -pady=>0, -padx=>0);
    $GUI{Terminal}= $fTerm->Scrolled("Text",
				     -height=>7,
				     -width=>85,
				     -background=>'white',
				     -foreground=>'black',
				     -wrap=>'word',
				     -scrollbars=>'osoe'
				     )->pack(-anchor=>'w',
					     -side=>'bottom',
					     -fill=>'x',
					     -pady=>5,
					     -padx=>5);
    $tTerminal= $GUI{Terminal};

    # *** Hint ***
    $bCanvas= $mw->Balloon(-initwait=>250, -state=>'balloon');
    $bCanvas->attach($cCanvas,
		     -balloonposition=>'mouse', 
		     -balloonmsg=>\$bCanvasText,
		     -msg=>\$bCanvasText);

    # ---| Bind events |---
    #$GUI{Main}->bind('<Configure>' =>
    #[\&gui_event_configure, Ev('h'), Ev('w')]);
    $cCanvas->bind('router', '<Button-3>',
		   [\&gui_canvas_router_event,
		    'context', Ev('x'), Ev('y')]);
    $cCanvas->bind('link', '<Button-3>',
		   [\&gui_canvas_link_event,
		    'context', Ev('x'), Ev('y')]);
    $cCanvas->bind('ilink', '<Button-3>',
		   [\&gui_canvas_link_event,
		    'context', Ev('x'), Ev('y')]);
    $cCanvas->bind('router', '<1>',
		   [\&gui_canvas_router_event,
		    'click']);
    $cCanvas->bind('link', '<1>',
		   [\&gui_canvas_link_event,
		    'click']);
    $cCanvas->bind('ilink', '<1>',
		   [\&gui_canvas_link_event,
		    'click']);

    $GUI{Main}->update();

    gui_init_link_attributes($GUI{LinkAttributes});
}


#####################################################################
#
# GRAPH DATABASE MGMT FUNCTIONS
#
#####################################################################

# -----[ check_domain ]----------------------------------------------
sub check_domain($)
{
    my ($domain)= @_;
    (!($domain =~ m/^[0-9]+$/)) and return 0;
    return (($domain > 0) &&
	    ($domain < 65536));
}

# -----[ graph_set_domain_id ]---------------------------------------
sub graph_set_domain_id($$)
{
    my ($graph, $domain_id)= @_;

    $graph->set_attribute(UCL::Graph::ATTR_AS, $domain_id);
    foreach ($graph->vertices()) {
	$graph->set_attribute(UCL::Graph::ATTR_AS, $_, $domain_id);
    }
}

# -----[ db_graph_clear ]--------------------------------------------
#
# -------------------------------------------------------------------
sub db_graph_clear()
{
    $db_graph= undef;
    select_router(undef, undef);
    select_domain(undef);
    gui_plot_clear();
}

# -----[ db_graph_get_as_id ]----------------------------------------
#
# -------------------------------------------------------------------
sub db_graph_get_as_id()
{
    if (!defined($db_graph)) {
	return 0;
    } else {
	my $next_as_id= 0;
	if (exists($db_graph->{next_as_id})) {
	    $next_as_id= $db_graph->{next_as_id};
	}
	while (exists($db_graph->{as2graph}->{$next_as_id})) {
	    $next_as_id++;
	}
	$db_graph->{next_as_id}= $next_as_id+1;
	return $next_as_id;
    }
}

# -----[ db_graph_get_current_as ]-----------------------------------
#
# -------------------------------------------------------------------
sub db_graph_get_current_as()
{
    if (defined($current_as) &&
	exists($db_graph->{as2graph}->{$current_as})) {
	return $db_graph->{as2graph}->{$current_as};
    } else {
	gui_dialog_error('No domain has been selected.');
	return undef;
    }
}

# -----[ db_graph_set_current_as ]-----------------------------------
#
# -------------------------------------------------------------------
sub db_graph_set_current_as($)
{
    my ($graph)= @_;
    if (defined($current_as) &&
	exists($db_graph->{as2graph}->{$current_as})) {
	$db_graph->{as2graph}->{$current_as}= $graph;
    } else {
	die "Can not set current_as";
    }
}

# -----[ db_graph_exists_domain ]------------------------------------
#
# -------------------------------------------------------------------
sub db_graph_exists_domain($)
{
    my ($as_id)= @_;
    return (defined($db_graph) &&
	    exists($db_graph->{as2graph}->{$as_id}));
}

# -----[ db_graph_new ]----------------------------------------------
#
# -------------------------------------------------------------------
sub db_graph_new()
{
    return {
	'as2graph' => {},
	'next_as_id' => 0,
	igraph => new Graph::Directed(),
    };
}

# -----[ db_graph_set ]----------------------------------------------
#
# -------------------------------------------------------------------
sub db_graph_set($)
{
    my ($new_db_graph)= @_;
    $db_graph= $new_db_graph;
    select_router(undef, undef);
    select_domain('any');
    gui_plot_graph($db_graph);
}

# -----[ db_graph_add ]----------------------------------------------
# Register a graph in the repository. Basically, the repository is a
# hashtable (domain-id => graph).
#
# The domain-id is searched in the graph (ATTR_AS). If none exists,
# the user is asked. Alternatively, a domain-id may be explicitly
# specified. In this case, the graph's domain-id is updated.
#
# Return:
#   0   if graph could be added (or if graph was skipped)
#   -1  otherwise
# -------------------------------------------------------------------
sub db_graph_add($;$)
{
    my ($graph, $domain_id)= @_;

    # ---| Create graph repository if required |---
    if (!defined($db_graph)) {
	$db_graph= db_graph_new();
    }

    # ---[ domain-id: look in graph, then ask |---
    if (!defined($domain_id)) {
	if ($graph->has_attribute(UCL::Graph::ATTR_AS)) {
	    $domain_id= $graph->get_attribute(UCL::Graph::ATTR_AS);
	}
    }
    if (!defined($domain_id)) {
	if (defined($GUI{Main})) {
	    $domain_id= IGen::DialogInput::run(-parent=>$GUI{Main},
					       -title=>"Domain ID",
					       -label=>"Domain ID",
					       -check=>\&check_domain);
	} else {
	    $domain_id= db_graph_get_as_id();
	}
	(!defined($domain_id)) and return -1;
    }

    # ---| domain already exists: ask for replace |---
    while (exists($db_graph->{as2graph}->{$domain_id})) {
	my $dialog= IGen::DialogMessage->new(-parent=>$GUI{Main},
					     -buttons=>[['Yes', 1],
							['No', 2],
							['Cancel', 0]],
					     -text=>"Domain $domain_id already exists. Replace ?");
	my $result= $dialog->show_modal();
	$dialog->destroy();
	if ($result->{btn} == 0) {
	    # Cancel => abort
	    return -1;
	} elsif ($result->{btn} == 2) {
	    $domain_id= IGen::DialogInput::run(-parent=>$GUI{Main},
					       -title=>"Domain ID",
					       -label=>"Domain ID",
					       -value=>$domain_id,
					       -check=>\&check_domain);
	    (!defined($domain_id)) and return -1;
	} else {
	    last;
	}
    }

    graph_set_domain_id($graph, $domain_id);
    $db_graph->{as2graph}->{$domain_id}= $graph;
}


#####################################################################
#
# GRAPH FUNCTIONS
#
#####################################################################

# -----[ graph_check_parallel_edges ]--------------------------------
#
# -------------------------------------------------------------------
sub graph_check_parallel_edges($)
{
    my ($graph)= @_;

    my %visited= ();

    my @edges= $graph->edges();
    for (my $i= 0; $i < @edges/2; $i++) {
	my $u= $edges[$i*2];
	my $v= $edges[$i*2+1];
	if (exists($visited{$u}{$v})) {
	    die "Parallel edges detected !\n";
	}
	$visited{$u}{$v}= 1;
    }
}

# -----[ graph_center_mass ]-----------------------------------------
# Compute the center of mass of a given graph.
# -------------------------------------------------------------------
sub graph_center_mass($)
{
    my ($graph)= @_;
    my @center= (0, 0);

    foreach my $vertex ($graph->vertices) {
	(!$graph->has_attribute(UCL::Graph::ATTR_COORD, $vertex)) and
	    die "Error: no coord attribute for vertex \"$vertex\"";
	my $coord= $graph->get_attribute(UCL::Graph::ATTR_COORD, $vertex);
	$center[0]+= $coord->[0];
	$center[1]+= $coord->[1];
    }

    $center[0]/= $graph->vertices;
    $center[1]/= $graph->vertices;

    return @center;
}

# -----[ graph_centroid ]--------------------------------------------
# Compute the centroid of a given graph.
# -------------------------------------------------------------------
sub graph_centroid($)
{
    my ($graph)= @_;

    # Find center of mass
    my ($cx, $cy)= graph_center_mass($graph);

    # Find closest vertex
    my $best_dist;
    my $best_vertex;
    foreach my $vertex ($graph->vertices) {
	my $coord= $graph->get_attribute(UCL::Graph::ATTR_COORD, $vertex);
	my $dist= UCL::Graph::Base::pt_distance([$cx, $cy], $coord);
	if (!defined($best_dist) || ($dist < $best_dist)) {
	    $best_dist= $dist;
	    $best_vertex= $vertex;
	}
    }

    (!defined($best_vertex)) and
	die "Error: this should not happen [no centroid]";
    
    return $best_vertex;
}

# -----[ graph_copy_attributes ]-------------------------------------
# Copy the vertices/edges attributes from the src graph into the
# existing vertices/edges of the dst graph. The dst graph must be a
# subgraph of the src graph.
#
# Parameters:
# - dst graph
# - src graph
# -------------------------------------------------------------------
sub graph_copy_attributes($$)
{
    my ($dst_graph, $src_graph)= @_;

    foreach my $vertex_i ($dst_graph->vertices) {
	my %attributes= $src_graph->get_attributes($vertex_i);
	foreach my $attr (keys %attributes) {
	    $dst_graph->set_attribute($attr, $vertex_i, $attributes{$attr});
	}
#	foreach my $neighbor ($dst_graph->neighbors($vertex_i)) {
#	    my %attributes= $src_graph->get_attributes($vertex, $neighbor);
#	    foreach my $attr (keys %attributes) {
#		print "\t$attr\n";
#		$dst_graph->set_attribute($attr, $vertex, $neighbor,
#					  $src_graph->get_attribute($attr,
#								    $vertex, $neighbor));
#	    }
#	}
    }
}

# -----[ graph_copy_edges_attributes ]-------------------------------
#
# -------------------------------------------------------------------
sub graph_copy_edges_attributes($$)
{
    my ($dst, $src)= @_;

    my @edges= $dst->edges;
    for (my $i= 0; $i < @edges/2; $i++) {
	my $u= $edges[$i*2];
	my $v= $edges[$i*2+1];
	my %attributes= $src->get_attributes($u, $v);
	foreach my $attr (keys %attributes) {
	    my $w= $src->get_attribute($attr, $u, $v);
	    $dst->set_attribute($attr, $u, $v, $w);
	}
    }
}

# -----[ get_multi_paths ]-------------------------------------------
#
# -------------------------------------------------------------------
sub get_multi_paths($$$)
{
    my ($source, $vertex, $predecessors)= @_;

    if (!exists($predecessors->{$vertex}) ||
	($predecessors->{$vertex} == $source)) {
	return [[$vertex]];
    } else {
	my @paths= ();
	foreach my $pred (keys %{$predecessors->{$vertex}}) {
	    my $sub_paths= get_multi_paths($source, $pred, $predecessors);
	    foreach my $sub_path (@$sub_paths) {
		push @$sub_path, ($vertex);
		push @paths, ($sub_path);
	    }
	}
	return \@paths;
    }
}

# -----[ graph_delete_path ]-----------------------------------------
#
# -------------------------------------------------------------------
sub graph_delete_path($$)
{
    my ($graph, $path)= @_;
    
    if (scalar(@$path) > 1) {
	for (my $i= 1; $i < @$path; $i++) {
	    $graph->delete_edge($path->[$i-1], $path->[$i]);
	    if ($graph->has_edge($path->[$i-1], $path->[$i])) {
		print "warning: could not delete edge ".
		    "($path->[$i-1],$path->[$i])\n";
	    }
	}
    }
}

# -----[ graph_dst_fct_length ]--------------------------------------
sub graph_dst_fct_length($$$)
{
    my ($graph, $u, $v)= @_;
    return UCL::Graph::Base::distance($graph, $u, $v);
}

# -----[ graph_dst_fct_weight ]--------------------------------------
sub graph_dst_fct_weight($$$)
{
    my ($graph, $u, $v)= @_;
    if (!$graph->has_attribute(UCL::Graph::ATTR_WEIGHT, $u, $v)) {
	die "no 'weight' attribute for edge \"$u->$v\"";
    }
    return $graph->get_attribute(UCL::Graph::ATTR_WEIGHT, $u, $v);
}

# -----[ graph_SSSP ]------------------------------------------------
# Single-source shortest-path (Dijkstra's algorithm). With support for
# Equal-Cost Multi-Path (ECMP).
# -------------------------------------------------------------------
sub graph_SSSP($$$$)
{
    my ($graph, $source, $ecmp, $dst_fct)= @_;

    my %distances= ();
    my %predecessors= ();
    my $vertices= new UCL::Heap();

    # Initialize distances to infinity
    foreach my $vertex ($graph->vertices()) {
	$distances{$vertex}= INFINITY;
    }

    # Start with source
    $vertices->enqueue($source, 0);
    $distances{$source}= 0;

    while (!$vertices->empty()) {
	my $vertex= $vertices->dequeue();

	foreach my $neighbor ($graph->successors($vertex)) {
	    my $distance= &$dst_fct($graph, $vertex, $neighbor)+
		$distances{$vertex};
	    if (!exists($distances{$neighbor}) ||
		($distance < $distances{$neighbor})) {
		$distances{$neighbor}= $distance;
		$predecessors{$neighbor}= { $vertex => 1 };
		$vertices->enqueue($neighbor, $distance);
	    } elsif ($distance == $distances{$neighbor}) {
		# Handle equal-cost paths
		if (defined($ecmp) && ($ecmp) &
		    !exists($predecessors{$neighbor}{$vertex})) {
		    $predecessors{$neighbor}{$vertex}= 1;
		}
	    }

	}
    }

    # Return path(s) for each destination
    my %SSSP= ();
    foreach my $vertex (keys %predecessors) {
	$SSSP{$vertex}= get_multi_paths($source, $vertex,
					\%predecessors);
    }

    #print "time(3): ".time()."\n";

    return \%SSSP;
}

# -----[ graph_APSP ]------------------------------------------------
#
# -------------------------------------------------------------------
sub graph_APSP($$$)
{
    my ($graph, $ecmp, $dst_fct)= @_;
    my %APSP= ();

    foreach my $vertex ($graph->vertices()) {
	$APSP{$vertex}= graph_SSSP($graph, $vertex, $ecmp, $dst_fct);
    }

    return \%APSP;
}

# -----[ RM_dump ]---------------------------------------------------
#
# -------------------------------------------------------------------
sub RM_dump($)
{
    my ($RM)= @_;

    foreach my $u (keys %$RM) {
	(!exists($RM->{$u})) and next;
	foreach my $v (keys %{$RM->{$u}}) {
	    (!exists($RM->{$u}->{$v})) and next;
	    print "$u-$v:\n";
	    my $paths= $RM->{$u}->{$v};
	    foreach my $path (@$paths) {
		print "\t";
		path_dump($path);
		print "\n";
	    }
	}
    }
}

# -----[ graph_dump ]------------------------------------------------
#
# -------------------------------------------------------------------
sub graph_dump($)
{
    my ($graph)= @_;

    my @vertices= $graph->vertices;
    my @edges= $graph->edges;

    print "num-vertices: ".@vertices.", num-edges: ".(scalar(@edges)/2)."\n";
    print "vertices: {\n";
    foreach (@vertices) {
	print "\t$_:";
	my %attributes= $graph->get_attributes($_);
	foreach my $attr (keys %attributes) {
	    print " $attr=>$attributes{$attr}";
	}
	print "\n";
    }
    print "}\n";
    print "edges: {\n";
    for (my $index= 0; $index < @edges/2; $index++) {
	my $vertex_i= $edges[$index*2];
	my $vertex_j= $edges[$index*2+1];
	print "\t($vertex_i, $vertex_j):";
	my %attributes= $graph->get_attributes($vertex_i, $vertex_j);
	foreach my $attr (keys %attributes) {
	    print " $attr=>$attributes{$attr}";
	}	
	print "\n";
    }
    print "}\n";
}

# -----[ graph_paths_lengths ]---------------------------------------
#
# -------------------------------------------------------------------
sub graph_paths_lengths($)
{
    my ($graph)= @_;

    # *** Compute routing matrix ***
    # ------------------------------
    my $RM= graph_APSP($graph, $global_options->{ecmp},
		       \&graph_dst_fct_weight);

    my @paths_lengths;
    my @paths_hop_cnts;
    my @paths_weights;
    foreach my $vertex_i (keys %$RM) {
	
	foreach my $vertex_j (keys %{$RM->{$vertex_i}}) {
	    
	    # Skip path from a node to itself
	    ($vertex_i == $vertex_j) and next;
	    
	    my $paths= $RM->{$vertex_i}->{$vertex_j};
	    foreach my $path (@$paths) {
		my ($hop_cnt, $length, $weight)=
		    UCL::Graph::Base::path_length($graph, $path);
		push @paths_lengths, ($length);
		push @paths_weights, ($weight);
		push @paths_hop_cnts, ($hop_cnt);
	    }
	}
    }

    my $stat_paths_length= new Statistics::Descriptive::Full();
    $stat_paths_length->add_data(\@paths_lengths);
    my $stat_paths_hop_cnts= new Statistics::Descriptive::Full();
    $stat_paths_hop_cnts->add_data(\@paths_hop_cnts);
    my $stat_paths_weights= new Statistics::Descriptive::Full();
    $stat_paths_weights->add_data(\@paths_weights);

    return ($stat_paths_length,
	    $stat_paths_hop_cnts,
	    $stat_paths_weights);
}

# -----[ path_dump ]-------------------------------------------------
#
# -------------------------------------------------------------------
sub path_dump($)
{
    my ($path)= @_;
    
    print "(".(join ',', @$path).")";
}

# -----[ path_contains_link ]----------------------------------------
#
# -------------------------------------------------------------------
sub path_contains_link($$$)
		 {
    my ($path, $u, $v)= @_;

    if (@$path > 1) {
	for (my $i= 1; $i < @$path; $i++) {
	    if ($u == $path->[$i-1]) {
		if ($v == $path->[$i]) {
		    return 1;
		} else {
		    return 0;
		}
	    }
	}
    }
    return 0;
}

# -----[ graph_vertex_name ]-----------------------------------------
#
# -------------------------------------------------------------------
sub graph_vertex_name($$)
{
    my ($graph, $v)= @_;

    if ($graph->has_attribute(UCL::Graph::ATTR_NAME, $v)) {
	return $graph->get_attribute(UCL::Graph::ATTR_NAME, $v);
    }
    return $v;
}

# -----[ graph_link_lfas ]-------------------------------------------
#
# -------------------------------------------------------------------
sub graph_link_lfas($$$$$)
{
    my ($graph, $u, $v, $RM, $directions)= @_;
    my @link_lfas= ();

    my $verbose= 0;

    # Look for different neighbors
    my @successors= $graph->successors($u);
    my @link_lfas= ();

    #print "link $u-$v: ".(join ',', @successors)."\n";
    foreach my $n (@successors) {
	
	# Other side of the link cannot be an LFA
	next if ($n == $v);

	# Check if neighbor can be used to reach all destinations
	# without using failing link
	($verbose) and print "\ttesting neighbor $n...\n";
	my $is_lfa= 1;
	foreach my $d (@$directions) {
	    
	    ($verbose) and print "\t\tdestination: $d\n";
	    
	    my $through= 0;
	    if ($d != $n) {
		my $paths= $RM->{$n}->{$d};
		(!defined($paths) || (@$paths < 1)) and
		    print "warning: no path from $n to $d\n";
		foreach my $path (@$paths) {
		    if ($verbose) {
			print "\t\t\tpath($n->$d): ";
			path_dump($path);
			print "\n";
		    }
		    if (path_contains_link($path, $u, $v)) {
			$through= 1;
			last;
		    }
		}
	    }
	    if ($through) {
		($verbose) and print "\t\t\t*** through :-( ***\n";
		$is_lfa= 0;
		last;
	    } else {
		($verbose) and print "\t\t\t*** not through :-) ***\n";
	    }
	}
	if ($is_lfa) {
	    push @link_lfas, ($n);
	}
    }
    return \@link_lfas;
}

# -----[ graph_link_uturns ]-----------------------------------------
#
# -------------------------------------------------------------------
sub graph_link_uturns($$$$$)
{
    my ($graph, $u, $v, $RM, $dests)= @_;
    my @link_uturns= ();

    # Look for neighbors 1 hop
    foreach my $n ($graph->successors($u)) {

	($n == $v) and next;

	# Look for neighbors at 2 hops
	foreach my $r ($graph->successors($n)) {

	    ($r == $u) and next;

	    # Check that link (u,v) is not in SPT(r)
	    my $through= 0;
	    foreach my $d (@$dests) {
		(($d == $u) || ($d == $r)) and next;
		my $paths= $RM->{$r}->{$d};
		(!defined($paths)) and die;
		foreach my $path (@$paths) {
		    if (path_contains_link($path, $u, $v)) {
			$through= 1;
			last;
		    }
		}
		if ($through) {
		    last;
		}
	    }
	    if (!$through) {
		push @link_uturns, ([$n,$r]);
	    }
	}

    }

    return \@link_uturns;
}

# -----[ graph_link_used ]-------------------------------------------
#
# -------------------------------------------------------------------
sub graph_link_used($$$$)
{
    my ($graph, $u, $v, $RM)= @_;

    # Check the destinations that are reached through the failing
    # link
    my @destinations= ();
    foreach my $d ($graph->vertices) {
	($d == $u) and next;
	my $paths= $RM->{$u}->{$d};
	my $through= 0;
	(!defined($paths) || (@$paths < 1)) and
	    print "warning: no path from $u to $d\n";
	foreach my $path (@$paths) {
	    if (path_contains_link($path, $u, $v)) {
		$through= 1;
		push @destinations, ($d);
		last;
	    }
	}
    }

    return \@destinations;
}
		     
# -----[ graph_link_fast_reroute ]-----------------------------------
#
# -------------------------------------------------------------------
sub graph_link_fast_reroute($$$$$)
{
    my ($graph, $u, $v, $RM, $frs)= @_;

    if ($global_verbosity > 1) {
	print "link(".graph_vertex_name($graph, $u).",".
	    graph_vertex_name($graph, $v)."): ";
    }

    # Check that link is used to carry traffic
    my $dests= graph_link_used($graph, $u, $v, $RM);
    if (!defined($dests) || (@$dests == 0)) {
	if ($global_verbosity > 1) {
	    print "not used.\n";
	}
	return;
    }

    # Check protection with Loop-Free Alternates (LFAs)
    my $link_lfas= graph_link_lfas($graph, $u, $v, $RM, $dests);
    if (@$link_lfas > 0) {
	if ($global_verbosity > 1) {
	    print "protectable (".(@$link_lfas)." LFA(s):";
	    foreach my $lfa (@$link_lfas) {
		print " ".graph_vertex_name($graph, $lfa);
	    }
	    print ").\n";
	}
	my $num_lfas= scalar(@$link_lfas);
	($num_lfas > 2) and $num_lfas= 2;
	$frs->[FAST_REROUTE_LFA][$num_lfas]++;
	return [FAST_REROUTE_LFA, scalar(@$link_lfas)];
    }
    $frs->[FAST_REROUTE_LFA][0]++;

    # Check protection with U-turns
    my $link_uturns= graph_link_uturns($graph, $u, $v, $RM, $dests);
    if (@$link_uturns > 0) {
	if ($global_verbosity > 1) {
	    print "protectable (".(@$link_uturns)." U-turn(s): ";
	    foreach my $uturn (@$link_uturns) {
		print "{".graph_vertex_name($graph, $uturn->[0]).",".
		    graph_vertex_name($graph, $uturn->[1])."}";
	    }
	    print ")\n";
	}
	my $num_uturns= scalar(@$link_uturns);
	($num_uturns > 2) and $num_uturns= 2;
	$frs->[FAST_REROUTE_UTURN][$num_uturns]++;
	return [FAST_REROUTE_UTURN, scalar(@$link_uturns)];
    }
    $frs->[FAST_REROUTE_UTURN][0]++;

    if ($global_verbosity > 1) {
	print "not protectable with LFA or U-turn.\n";
    }
    return [FAST_REROUTE_NONE, 1];
}

# -----[ graph_fast_reroute ]----------------------------------------
#
# -------------------------------------------------------------------
sub graph_fast_reroute($)
{
    my ($graph)= @_;
    my @frs= ();
    $frs[FAST_REROUTE_UNUSED]= 0;
    $frs[FAST_REROUTE_NONE]= ();
    $frs[FAST_REROUTE_LFA]= ();
    $frs[FAST_REROUTE_UTURN]= ();

    # Compute routing matrix
    my $RM= graph_APSP($graph, 1, \&graph_dst_fct_weight);

    # Check if each link is fast-reroutable (LFA/U-turn)
    my @edges= $graph->edges();
    for (my $i= 0; $i < @edges/2; $i++) {
	my $u= $edges[$i*2];
	my $v= $edges[$i*2+1];

	if (!defined(graph_link_fast_reroute($graph, $u, $v, $RM, \@frs))) {
	    $frs[FAST_REROUTE_UNUSED]++;
	}

	if (!$graph->directed()) {
	    if (!defined(graph_link_fast_reroute($graph, $v, $u, $RM, \@frs))) {
		$frs[FAST_REROUTE_UNUSED]++;
	    }
	}

    }
    
    return \@frs;
}


#####################################################################
#
# GRAPH CLUSTERING FUNCTIONS
#
#####################################################################

# -----[ graph_cluster_mean ]----------------------------------------
#
# -------------------------------------------------------------------
sub graph_cluster_mean($$)
{
    my ($graph, $cluster)= @_;

    my @mean= (0, 0);
    foreach my $vertex (keys %{$cluster->[1]}) {
	my $coord= $graph->get_attribute(UCL::Graph::ATTR_COORD, $vertex);
	$mean[0]+= $coord->[0];
	$mean[1]+= $coord->[1];
    }
    $mean[0]/= (keys %{$cluster->[1]});
    $mean[1]/= (keys %{$cluster->[1]});

    return \@mean;
}

# -----[ graph_clusters_pair_variance ]------------------------------
#
# -------------------------------------------------------------------
sub graph_clusters_pair_variance($$$)
{
    my ($graph, $cluster_i, $cluster_j)= @_;
    my $cnt= (keys %{$cluster_i->[1]})+(keys %{$cluster_j->[1]});

    # Compute mean
    my @mean= (0, 0);
    foreach my $vertex (keys %{$cluster_i->[1]}, keys %{$cluster_j->[1]}) {
	my $coord= $graph->get_attribute(UCL::Graph::ATTR_COORD, $vertex);
	$mean[0]+= $coord->[0];
	$mean[1]+= $coord->[1];
    }
    $mean[0]/= $cnt;
    $mean[1]/= $cnt;

    # Compute variance
    my $var= 0;
    foreach my $vertex (keys %{$cluster_i->[1]}, keys %{$cluster_j->[1]}) {
	my $coord= $graph->get_attribute(UCL::Graph::ATTR_COORD, $vertex);
	$var+= (($coord->[0]-$mean[0])**2)+(($coord->[1]-$mean[1])**2);
    }
    $var/= $cnt;

    return $var;
}

# -----[ graph_cluster_ward ]----------------------------------------
# Hierarchical clustering of the graph based on minimum variance
# (metric=distance)
#
# Returns:
#   clusters ::= list of [ centroid, vertices[hash], coord]
# -------------------------------------------------------------------
sub graph_cluster_ward($$$)
{
    my ($graph, $maxK, $maxV)= @_;
    my @clusters;

    # Create one cluster per vertex
    foreach my $vertex ($graph->vertices) {
	my $coord= $graph->get_attribute(UCL::Graph::ATTR_COORD, $vertex);
	push @clusters, ([undef, {$vertex}, 0]);
    }
    
    while (@clusters > $maxK) {
	
	# Compute the pair of clusters that will give the minimum variance
	my $best_var;
	my ($best_i, $best_j);
	for (my $i= 0; $i < @clusters; $i++) {
	    for (my $j= $i+1; $j < @clusters; $j++) {

		# If the variance of one cluster is larger than the
		# current best variance, skip the pair
		if (defined($best_var) && (($clusters[$i]->[2] > $best_var) ||
					   ($clusters[$j]->[2] > $best_var))) {
		    next;
		}

		my $var= graph_clusters_pair_variance($graph,
						      $clusters[$i],
						      $clusters[$j]);

		# Limit the variance of a cluster
		if (defined($maxV) && ($var > $maxV)) {
		    next;
		}

		if (!defined($best_var) || ($var < $best_var)) {
		    $best_var= $var;
		    $best_i= $i;
		    $best_j= $j;
		}

	    }
	}

	# No candidate clusters pair, terminate the algorithm
	if (!defined($best_i) || !defined($best_j)) {
	    print "# No more candidate clusters pair: exit\n";
	    last;
	}

	# Merge both clusters
	$clusters[$best_i]->[2]= $best_var;
	foreach my $vertex (keys %{$clusters[$best_j]->[1]}) {
	    $clusters[$best_i]->[1]->{$vertex}= 1;
	}
	splice @clusters, $best_j, 1;

    }

    # Mark vertices with their cluster ID
    for (my $index= 0; $index < @clusters; $index++) {

	# Compute centroid
	my $centre= graph_cluster_mean($graph, $clusters[$index]);
	my $best_dist= undef;
	my $centroid;
	my $best_coord;
	foreach my $vertex (keys %{$clusters[$index]->[1]}) {
	    my $coord= $graph->get_attribute(UCL::Graph::ATTR_COORD, $vertex);
	    my $dist= UCL::Graph::Base::pt_distance($coord, $centre);
	    if (!defined($best_dist) || ($dist < $best_dist)) {
		$best_dist= $dist;
		$centroid= $vertex;
		$best_coord= $coord;
	    }
	}
	$clusters[$index]->[0]= $centroid;
	$clusters[$index]->[2]= $best_coord;
    }

    return \@clusters;
}


#####################################################################
#
# GRAPH BUILDING FUNCTIONS
#
#####################################################################

# -----[ graph_clear_edges ]-----------------------------------------
# Remove all the edges in the given graph.
#
# Important note: delete_edge() does not remove the edge's
# attributes.
# -------------------------------------------------------------------
sub graph_clear_edges($)
{
    my ($graph)= @_;

    # Remove edges and attributes
    my @edges= $graph->edges();
    for (my $i= 0; $i < @edges/2; $i++) {
	my $u= $edges[$i*2];
	my $v= $edges[$i*2+1];
	$graph->delete_attributes($u, $v);
	$graph->delete_edge($u, $v);
	$graph->delete_attributes($v, $u);
	$graph->delete_edge($v, $u);
    }

    # Remove node type
    foreach my $u ($graph->vertices()) {
	$graph->delete_attribute(UCL::Graph::ATTR_TYPE, $u);
    }
}

# -----[ graph_MENTOR ]----------------------------------------------
# Prim-Dijkstra algorithm. Compute a tree starting at the given root
# vertex.
#
# Parameters:
# - graph
# - root: starting node for the search
# - alpha: contribution of the arcs weights (0 <= alpha <= 1)
#     (alpha = 0) => MST
#     (alpha = 1) ~> SPT
# -------------------------------------------------------------------
sub graph_MENTOR($$;$)
{
    my ($graph, $alpha, $root)= @_;

    my %visited= ();
    my %label= ();

    if (!defined($root)) {
	$root= graph_centroid($graph);
    }

    ($graph->has_vertex($root)) or
	die "Error: \"$root\" does not belong to graph";

    $graph= UCL::Graph::Generate::clique($graph, 1);

    # Initialize the label of each vertex
    foreach my $vertex ($graph->vertices) {
	$label{$vertex}= [INFINITY, -1, 0];
    }

    $label{$root}= [0, $root, 0];

    my $number_scanned= 0;
    while ($number_scanned < $graph->vertices) {

	my $dist_min= INFINITY;
	my $vertex_min;
	foreach my $vertex ($graph->vertices) {
	    if (!exists($visited{$vertex}) &&
		($label{$vertex}->[0] < $dist_min)) {
		$vertex_min= $vertex;
		$dist_min= $label{$vertex}->[0];
	    }
	}
	(!defined($vertex_min)) and die "Error: this shoudn't happen";
	$visited{$vertex_min}= 1;
	if ($vertex_min != $root) {
	    $label{$vertex_min}->[2]= $label{$label{$vertex_min}->[1]}->[2]+
		UCL::Graph::Base::distance($graph, $vertex_min,
					   $label{$vertex_min}->[1]);
	}
	my $d= $alpha * $label{$vertex_min}->[2];
	foreach my $neighbor ($graph->neighbors($vertex_min)) {
	    my $dist= UCL::Graph::Base::distance($graph, $vertex_min,
						 $neighbor);
	    if (!exists($visited{$neighbor}) &&
		($d+$dist < $label{$neighbor}->[0])) {
		$label{$neighbor}= [$d+$dist, $vertex_min];
	    }
	}
	$number_scanned++;
    }

    # Convert to Graph...
    my $mentor= new Graph::Undirected;
    foreach my $vertex ($graph->vertices) {
	$mentor->add_vertex($vertex);
	my $value= $graph->get_attribute(UCL::Graph::ATTR_COORD, $vertex);
	$mentor->set_attribute(UCL::Graph::ATTR_COORD, $vertex, $value);
    }
    foreach my $vertex ($graph->vertices) {
	(!$graph->has_vertex($label{$vertex}->[1])) and die;
	if (($vertex != $label{$vertex}->[1]) &&
	    !$mentor->has_edge($vertex, $label{$vertex}->[1])) {
	    $mentor->add_edge($vertex, $label{$vertex}->[1]);
	}
    }
    return $mentor;
}

# -----[ graph_MENTour ]---------------------------------------------
#
# -------------------------------------------------------------------
sub graph_MENTour($$$$$)
{
    my ($graph, $alpha, $K, $tsp_heur, $clust_heur)= @_;

    my $clusters;
    if ($clust_heur == UCL::Graph::Cluster::KMEDOIDS) {
	$clusters= UCL::Graph::Cluster::kmedoids($graph, $K);
    } elsif ($clust_heur == UCL::Graph::Cluster::WARD) {
	$clusters= graph_cluster_ward($graph, $K, undef);
    } else {
	die "Error: unsupported clustering heuristic ($clust_heur)";
    }

    my @access_nets;
    my $backbone= new Graph::Undirected;
    my $cnt= 0;
    for (my $index= 0; $index < @$clusters; $index++) {
	$backbone->add_vertex($clusters->[$index]->[0]);
	$backbone->set_attribute(UCL::Graph::ATTR_COORD,
				 $clusters->[$index]->[0],
				 $clusters->[$index]->[2]);
	my $cluster= new Graph::Undirected;
	foreach my $vertex (keys %{$clusters->[$index]->[1]}) {
	    $cluster->add_vertex($vertex);
	    $cnt++;
	}
	graph_copy_attributes($cluster, $graph);
	$cluster= UCL::Graph::Generate::clique($cluster, 1);
	$access_nets[$index]= graph_MENTOR($cluster,
					   $clusters->[$index]->[0],
					   $alpha);
    }

    my $mentour;
    $backbone= UCL::Graph::Generate::clique($backbone, 1);
    if ($tsp_heur == MENTOUR_TSP_NN) {
	$mentour= graph_TSP_nn($backbone);
    } elsif ($tsp_heur == MENTOUR_TSP_FN) {
	$mentour= graph_TSP_fn($backbone);
    } else {
	die "Error: unsupported TSP heuristic ($tsp_heur)";
    }

    foreach my $access_net (@access_nets) {
	foreach my $vertex ($access_net->vertices) {
	    if (!$mentour->has_vertex($vertex)) {
		$mentour->add_vertex($vertex);
	    }
	    foreach my $neighbor ($access_net->neighbors($vertex)) {
		if (!$mentour->has_vertex($neighbor)) {
		    $mentour->add_vertex($neighbor);
		}
		if (!$mentour->has_edge($vertex, $neighbor)) {
		    $mentour->add_weighted_edge($vertex,
						$graph->get_attribute(UCL::Graph::ATTR_WEIGHT,
								      $vertex, $neighbor),
						$neighbor);
		}
	    }
	}
    }

    graph_copy_attributes($mentour, $graph);

    return $mentour;
}

# -----[ graph_TSP_fn ]----------------------------------------------
# TSP approximation heuristic (insertion): furthest neighbor
# -------------------------------------------------------------------
sub graph_TSP_fn($)
{
    my ($graph)= @_;
    my @shortest_tour;
    my $shortest_tour_len;

    if ($graph->vertices == 1) {
	my $tsp= $graph->copy;
	graph_copy_attributes($tsp, $graph);
	return $tsp;
    }

    foreach my $root ($graph->vertices) {

	my %in_tour;
	my %dtour;
	my @tour;

	$in_tour{$root}= 1;
	push @tour, ($root);

	foreach my $vertex ($graph->vertices) {
	    $dtour{$vertex}= UCL::Graph::Base::distance($graph, $root,
							$vertex);
	}
	
	while (@tour < $graph->vertices) {
	    my $best_dist;
	    my $best_vertex;
	    foreach my $vertex ($graph->vertices) {
		if (!exists($in_tour{$vertex}) &&
		    (!defined($best_dist) || ($dtour{$vertex} > $best_dist))) {
		    $best_dist= $dtour{$vertex};
		    $best_vertex= $vertex;		
		}
	    }
	    (!defined($best_vertex)) and die "Error: this shoud not happen";
	    $in_tour{$best_vertex}= 1;
	    $dtour{$best_vertex}= 0;
	    
	    # Find best insertion slot
	    $best_dist= INFINITY;
	    my $best_slot;
	    for (my $i= 0; $i < @tour; $i++) {
		my $j;
		if ($i+1 < @tour) {
		    $j= $i+1;
		} else {
		    $j= 0;
		}
		my $dtest= UCL::Graph::Base::distance($graph, $tour[$i], $best_vertex)+
		    UCL::Graph::Base::distance($graph, $best_vertex, $tour[$j])-
		    UCL::Graph::Base::distance($graph, $tour[$i], $tour[$j]);
		if ($dtest < $best_dist) {
		    $best_dist= $dtest;
		    $best_slot= $i;
		}
	    }
	    (!defined($best_slot)) and die "Error: this should not happen";
	    if ($best_slot+1 == @tour) {
		push @tour, ($best_vertex);
	    } else {
		for (my $i= @tour-1; $i > $best_slot; $i--) {
		    $tour[$i+1]= $tour[$i];
		}
		$tour[$best_slot+1]= $best_vertex;
	    }
	    
	    # Update dtour...
	    foreach my $vertex ($graph->vertices) {
		if (!exists($in_tour{$vertex}) &&
		    (UCL::Graph::Base::distance($graph, $best_vertex, $vertex) < $dtour{$vertex})) {
		    $dtour{$vertex}= UCL::Graph::Base::distance($graph, $best_vertex, $vertex);
		}
	    }
	}

	my $tour_len= 0;
	for (my $index= 1; $index < @tour; $index++) {
	    $tour_len+= UCL::Graph::Base::distance($graph,
						   $tour[$index-1],
						   $tour[$index]),
	}
	$tour_len+= UCL::Graph::Base::distance($graph,
					       $tour[$#tour],
					       $tour[0]);


	if (!defined($shortest_tour_len) || ($tour_len < $shortest_tour_len)) {
	    $shortest_tour_len= $tour_len;
	    @shortest_tour= @tour;
	}

    }
	
    # Convert to graph
    my $tsp= new Graph::Undirected;
    $tsp->add_vertex($shortest_tour[0]);
    for (my $index= 1; $index < @shortest_tour; $index++) {
	$tsp->add_vertex($shortest_tour[$index]);
	if (!$tsp->has_edge($shortest_tour[$index-1],
			    $shortest_tour[$index])) {
	    $tsp->add_weighted_edge($shortest_tour[$index-1],
				    UCL::Graph::Base::distance($graph,
							     $shortest_tour[$index-1],
							     $shortest_tour[$index]),
				    $shortest_tour[$index]);
	}
    }
    if (!$tsp->has_edge($shortest_tour[$#shortest_tour],
			$shortest_tour[0])) {
	$tsp->add_weighted_edge($shortest_tour[$#shortest_tour],
				UCL::Graph::Base::distance($graph,
							 $shortest_tour[$#shortest_tour],
							 $shortest_tour[0]),
				$shortest_tour[0]);
    }

    return $tsp;
}

# -----[ graph_TSP_nn ]----------------------------------------------
# TSP approximation heuristic (insertion): nearest neighbor
# -------------------------------------------------------------------
sub graph_TSP_nn($)
{
    my ($graph)= @_;
    my %in_tour;
    my %dtour;
    my @tour;

    my @vertices= $graph->vertices;

    my $root= $vertices[0];
    $in_tour{$root}= 1;
    push @tour, ($root);

    foreach my $vertex ($graph->vertices) {
	$dtour{$vertex}= UCL::Graph::Base::distance($graph, $root, $vertex);
    }

    while (scalar(@tour) < scalar($graph->vertices)) {
	my $best_dist;
	my $best_vertex;
	foreach my $vertex ($graph->vertices) {
	    if (!exists($in_tour{$vertex}) &&
		(!defined($best_dist) || ($dtour{$vertex} < $best_dist))) {
		$best_dist= $dtour{$vertex};
		$best_vertex= $vertex;		
	    }
	}
	(!defined($best_vertex)) and die "Error: this should not happen";
	$in_tour{$best_vertex}= 1;
	$dtour{$best_vertex}= 0;

	# Find best insertion slot
	$best_dist= INFINITY;
	my $best_slot;
	for (my $i= 0; $i < @tour; $i++) {
	    my $j;
	    if ($i+1 < @tour) {
		$j= $i+1;
	    } else {
		$j= 0;
	    }
	    my $dtest= UCL::Graph::Base::distance($graph, $tour[$i], $best_vertex)+
		UCL::Graph::Base::distance($graph, $best_vertex, $tour[$j])-
		UCL::Graph::Base::distance($graph, $tour[$i], $tour[$j]);
	    if ($dtest < $best_dist) {
		$best_dist= $dtest;
		$best_slot= $i;
	    }
	}
	(!defined($best_slot)) and die "Error: this should not happen";
	if ($best_slot+1 == @tour) {
	    push @tour, ($best_vertex);
	} else {
	    for (my $i= @tour-1; $i > $best_slot; $i--) {
		$tour[$i+1]= $tour[$i];
	    }
	    $tour[$best_slot+1]= $best_vertex;
	}

	# Update dtour...
	foreach my $vertex ($graph->vertices) {
	    if (!exists($in_tour{$vertex}) &&
		(UCL::Graph::Base::distance($graph, $best_vertex, $vertex) < $dtour{$vertex})) {
		$dtour{$vertex}= UCL::Graph::Base::distance($graph, $best_vertex, $vertex);
	    }
	}
    }

    # Convert to graph
    my $tsp= new Graph::Undirected;
    $tsp->add_vertex($tour[0]);
    for (my $index= 1; $index < @tour; $index++) {
	$tsp->add_vertex($tour[$index]);
	if (!$tsp->has_edge($tour[$index-1], $tour[$index])) {
	    $tsp->add_weighted_edge($tour[$index-1],
				    UCL::Graph::Base::distance($graph,
							     $tour[$index-1],
							     $tour[$index]),
				    $tour[$index]);
	}
    }
    if (!$tsp->has_edge($tour[$#tour], $tour[0])) {
	$tsp->add_weighted_edge($tour[$#tour], UCL::Graph::Base::distance($graph,
									$tour[$#tour],
									$tour[0]),
				$tour[0]);
    }

    return $tsp;
}

# -----[ graph_TSP ]-------------------------------------------------
#
# -------------------------------------------------------------------
sub graph_TSP($$)
{
    my ($graph, $method)= @_;

    if ($method == MENTOUR_TSP_NN) {
	return graph_TSP_nn($graph);
    } elsif ($method == MENTOUR_TSP_FN) {
	return graph_TSP_fn($graph);
    } else {
	die "unknown TSP heuristic \"$method\"";
    }
}

# -----[ graph_two_trees ]-------------------------------------------
#
# -------------------------------------------------------------------
sub graph_two_trees($)
{
    my ($graph)= @_;

    my $graph_copy= UCL::Graph::Generate::clique($graph, 1);
    graph_copy_edges_attributes($graph_copy, $graph);

    my $mst1= $graph_copy->MST_Kruskal();
    my @edges= $mst1->edges;
    for (my $i= 0; $i < @edges/2; $i++) {
	my $u= $edges[$i*2];
	my $v= $edges[$i*2+1];
	$graph_copy->delete_edge($u, $v);
	if ($graph_copy->has_edge($u, $v) ||
	    $graph_copy->has_edge($v, $u)) {
	}
    }

    my $mst2= $graph_copy->MST_Kruskal();
    my @edges= $mst2->edges;
    for (my $i= 0; $i < @edges/2; $i++) {
	my $u= $edges[$i*2];
	my $v= $edges[$i*2+1];
	if (!$mst1->has_edge($u, $v)) {
	    $mst1->add_edge($u, $v);
	}
    }

    graph_copy_edges_attributes($mst1, $mst2);
    graph_copy_attributes($mst1, $graph);

    $mst1->undirected(1);

    return $mst1;
}

# -----[ graph_multitours ]------------------------------------------
#
# -------------------------------------------------------------------
sub graph_multitours($$$$)
{
    my ($graph, $K)= @_;

    my $root= graph_centroid($graph);

    my $multi_tour= new Graph::Undirected;

    # Build clusters...
    my $clusters= UCL::Graph::Cluster::kmedoids($graph, $K);
    $graph->set_attribute(UCL::Graph::ATTR_CLUSTERS, $clusters);

    # Build tours in clusters...
    my @tours;
    for (my $i= 0; $i < @$clusters; $i++) {
	my $sub_graph= new Graph::Undirected;
	foreach my $vertex (keys %{$clusters->[$i]->[1]}) {
	    $sub_graph->add_vertex($vertex);
	    my $value=
		$graph->get_attribute(UCL::Graph::ATTR_COORD, $vertex);
	    $sub_graph->set_attribute(UCL::Graph::ATTR_COORD, $vertex, $value);
	}
	my $tour= graph_TSP_nn($sub_graph);
	foreach my $vertex ($tour->vertices) {
	    $multi_tour->add_vertex($vertex);
	}
	my @edges= $tour->edges;
	for (my $i= 0; $i < @edges/2; $i++) {
	    my $u= $edges[$i*2];
	    my $v= $edges[$i*2+1];
	    my $w= UCL::Graph::Base::distance($graph, $u, $v);
	    if (!$multi_tour->has_edge($u, $v)) {
		$multi_tour->add_weighted_edge($u, $w, $v);
	    }
	}
	$tours[$i]= $tour;
	if (!defined($tour)) {
	    print STDERR "Warning: TSP for cluster $i is undefined\n";
	}
    }

    # Connect clusters together to that an hybrid MST/SPT tree is
    # formed. Start from the cluster which is the closest to the
    # root...
    my %connected= ();
    while ((keys %connected) < @$clusters) {
	
	# Find the cluster which is the closest to the root
	my $current;
	my $b_dist;
	for (my $i= 0; $i < @$clusters; $i++) {
	    (exists($connected{$i})) and next;
	    my $dist= UCL::Graph::Base::distance($graph,
						 $clusters->[$i]->[0],
						 $root);
	    if (!defined($b_dist) || ($dist < $b_dist)) {
		$b_dist= $dist;
		$current= $i;
	    }
	}
	(!defined($current)) and die;
	$connected{$current}= 1;

	# Connect current cluster to "closest" cluster
	# Find the already connected cluster that minimizes the given
	# function...
	my $closest;
	my $b_dist;
	for (my $j= 0; $j < @$clusters; $j++) {
	    (($current == $j) || !exists($connected{$j})) and next;
	    my $dist= UCL::Graph::Base::distance($graph,
					       $clusters->[$current]->[0],
					       $clusters->[$j]->[0])
		+0.3*UCL::Graph::Base::distance($graph, $root, $clusters->[$j]->[0]);
	    if (!defined($b_dist) || ($dist < $b_dist)) {
		$b_dist= $dist;
		$closest= $j;
	    }
	}
	(!defined($closest)) and next;

	# Find the closest pairs of nodes (brute force)
	# We have N1*N2 possible intercluster edges, where Ni is
	# the number of nodes of cluster i
	my @edges;
	foreach my $v_i ($tours[$current]->vertices) {
	    foreach my $v_j ($tours[$closest]->vertices) {
		my $cost= UCL::Graph::Base::distance($graph, $v_i, $v_j);
		push @edges, ([$v_i, $v_j, $cost]);
	    }
	}
	my $b_cost;
	my @b_pair;
	for (my $i= 0; $i < @edges; $i++) {
	    my $cost_i= $edges[$i]->[2];
	    for (my $j= $i+1; $j < @edges; $j++) {
		my $cost_j= $edges[$j]->[2];

		if ((!defined($b_cost) || ($cost_i+$cost_j <
					   $b_cost)) &&
		    (($tours[$current]->vertices == 1) ||
		     ($edges[$i]->[0] != $edges[$j]->[0])) &&
		    (($tours[$closest]->vertices == 1) ||
		     (($edges[$i]->[1] != $edges[$j]->[1])))) {
		    $b_cost= $cost_i+$cost_j;
		    @b_pair= ($i, $j);
		}
	    }
	}
	my $u= $edges[$b_pair[0]]->[0];
	my $v= $edges[$b_pair[0]]->[1];
	my $w= UCL::Graph::Base::distance($graph, $u, $v);
	if (!$multi_tour->has_edge($u, $v)) {
	    $multi_tour->add_weighted_edge($u, $w, $v);
	}
	$u= $edges[$b_pair[1]]->[0];
	$v= $edges[$b_pair[1]]->[1];
	$w= UCL::Graph::Base::distance($graph, $u, $v);
	if (!$multi_tour->has_edge($u, $v)) {
	    $multi_tour->add_weighted_edge($u, $w, $v);
	}
    }
    
    graph_copy_attributes($multi_tour, $graph);

    return $multi_tour;
}

# -----[ graph_tworings ]--------------------------------------------
#
# -------------------------------------------------------------------
sub graph_tworings($)
{
    my ($graph)= @_;

    die "NOT YET IMPLEMENTED";
}

# -----[ graph_gen_star_ring ]---------------------------------------
#
# -------------------------------------------------------------------
sub graph_gen_star_ring($$)
{
    my ($graph, $K)= @_;

    my $star_ring= new Graph::Undirected;
    foreach my $vertex ($graph->vertices) {
	$star_ring->add_vertex($vertex);
	my $value= $graph->get_attribute(UCL::Graph::ATTR_COORD,
					 $vertex);
	$star_ring->set_attribute(UCL::Graph::ATTR_COORD,
				  $vertex, $value);
    }

    my $clusters= UCL::Graph::Cluster::kmedoids($graph, $K);
    
    foreach my $cluster (@$clusters) {
	$star_ring->delete_vertex($cluster->[0]);
    }

    # Generate "ring"
    my $ring_tsp= graph_TSP_fn($star_ring);

    # Generate "star"
    foreach my $cluster (@$clusters) {
	$star_ring->add_vertex($cluster->[0]);
	$star_ring->set_attribute('core', $cluster->[0], 1);
	foreach my $vertex ($star_ring->vertices) {
	    ($star_ring->get_attribute($vertex, 'core')) and next;
	    $star_ring->add_weighted_edge($cluster->[0],
					  $graph->get_attribute(UCL::Graph::ATTR_WEIGHT, $cluster->[0], $vertex), $vertex);
	}
    }

    my @edges= $ring_tsp->edges;
    for (my $index= 0; $index < @edges/2; $index++) {
	my $u= $edges[$index*2];
	my $v= $edges[$index*2+1];
	my $w= $graph->get_attribute(UCL::Graph::ATTR_WEIGHT, $u, $v);
	$star_ring->add_weighted_edge($u, $w, $v);
    }

    return $star_ring;
}

# -----[ graph_waxman ]----------------------------------------------
#
# -------------------------------------------------------------------
sub graph_waxman($$$$;$)
{
    use constant WAXMAN_ALL => 0;
    use constant WAXMAN_INCR => 1;

    my ($graph, $alpha, $beta, $m, $mode)= @_;

    (!defined($alpha) || !defined($beta) ||
     !defined($m)) and
	return undef;

    if (!defined($mode)) {
	$mode= WAXMAN_ALL;
    }

    my $waxman= new Graph::Undirected;
    my @vertices= $graph->vertices;

    # Compute distance between most distant vertices
    my $max_dist;
    for (my $i= 0; $i < @vertices; $i++) {
	$waxman->add_vertex($vertices[$i]);
	my $value= $graph->get_attribute(UCL::Graph::ATTR_COORD,
					 $vertices[$i]);
	$waxman->set_attribute(UCL::Graph::ATTR_COORD,
			       $vertices[$i], $value);
	for (my $j= $i+1; $j < @vertices; $j++) {
	    my $dist= UCL::Graph::Base::distance($graph,
				     $vertices[$i],
				     $vertices[$j]);
	    if (!defined($max_dist) || ($dist > $max_dist)) {
		$max_dist= $dist;
	    }
	}
    }

    my %nodes_degree;
    my $n_connected= 0;
    
    if ($mode == WAXMAN_ALL) {
	
	while ($n_connected < @vertices) {

	    my $v1= $vertices[int(rand(@vertices))];

	    my $n_edges= 0;
	    while (($n_edges < $m) &&
		   ($n_connected < @vertices)) {

		my $v2= $vertices[int(rand(@vertices))];
		
		($v1 == $v2) and next;
		($waxman->has_edge($v1, $v2)) and next;

		# Normalized distance
		my $dist= UCL::Graph::Base::distance($graph, $v1, $v2);
		my $ndist= $dist/$max_dist;

		# Compute attachment probability: A*exp(-d/B)
		my $P= $alpha*exp(-$ndist/$beta);

		# Flip coin in order to determine if the edge must be
		# added
		if (rand(1) < $P) {
		    $waxman->add_weighted_edge($v1, $dist, $v2);

		    if (!exists($nodes_degree{$v1})) {
			$n_connected++;
			$nodes_degree{$v1}= 1;
		    } else {
			$nodes_degree{$v1}++;
		    }
		    if (!exists($nodes_degree{$v2})) {
			$n_connected++;
			$nodes_degree{$v2}= 1;
		    } else {
			$nodes_degree{$v2}++;
		    }

		    $n_edges++;
		}

	    }

	}

    } elsif ($mode == WAXMAN_INCR) {

	for (my $i= $m; $i < @vertices; $i++) {
	    my $v1= $vertices[$i];

	    my $n_edges= 0;
	    while ($n_edges < $m) {
		my $v2= $vertices[int(rand(@vertices))];

		($v2 == $v1) and next;
		($waxman->has_edge($v1, $v2)) and next;

		# Normalized distance
		my $dist= UCL::Graph::Base::distance($graph, $v1, $v2);
		my $ndist= $dist/$max_dist;

		# Compute attachment probability: A*exp(-d/B)
		my $P= $alpha*exp(-$ndist/$beta);

		# Flip coin
		if (rand(1) < $P) {
		    $waxman->add_weighted_edge($v1, $dist, $v2);
		    $n_edges++;

		    if (!exists($nodes_degree{$v1})) {
			$nodes_degree{$v1}= 1;
		    } else {
			$nodes_degree{$v1}++;
		    }
		    if (!exists($nodes_degree{$v2})) {
			$nodes_degree{$v2}= 1;
		    } else {
			$nodes_degree{$v2}++;
		    }
		}
		
	    }

	}

	for (my $i= 0; $i < $m; $i++) {
	    my $v1= $vertices[$i];
	    my $n_edges= 0;

	    while ($n_edges < $m) {
		($nodes_degree{$v1} >= @vertices-$m) and last;

		my $v2= $vertices[$m+int(rand(@vertices-$m))];
		
		($v1 == $v2) and next;
		($waxman->has_edge($v1, $v2)) and next;

		# Normalized distance
		my $dist= UCL::Graph::Base::distance($graph, $v1, $v2);
		my $ndist= $dist/$max_dist;

		# Compute attachment probability: A*exp(-d/B)
		my $P= $alpha*exp(-$ndist/$beta);

		# Flip coin
		if (rand(1) < $P) {
		    $waxman->add_weighted_edge($v1, $dist, $v2);

		    if (!exists($nodes_degree{$v1})) {
			$n_connected++;
			$nodes_degree{$v1}= 1;
		    } else {
			$nodes_degree{$v1}++;
		    }
		    if (!exists($nodes_degree{$v2})) {
			$n_connected++;
			$nodes_degree{$v2}= 1;
		    } else {
			$nodes_degree{$v2}++;
		    }		    
		    $n_edges++;
		}		
	    }
	}
	
    }

    return $waxman;
}

# -----[ graph_gen_BA ]----------------------------------------------
#
# -------------------------------------------------------------------
sub graph_gen_BA($$)
{
    my ($graph, $m)= @_;

    my $barabasi= new Graph::Undirected;
    foreach my $v ($graph->vertices) {
	$barabasi->add_vertex($v);
	my $value= $graph->get_attribute(UCL::Graph::ATTR_COORD, $v);
	$barabasi->set_attribute(UCL::Graph::ATTR_COORD, $v, $value);
    }

    my @vertices= $graph->vertices;

    my %nodes_degree;

    my $sum_Dj= 0;

    for (my $i= 0; $i < $m; $i++) {
	($i < @vertices) or next;

	for (my $j= $i+1; $j < $m; $j++) {
	    ($j < @vertices) or next;
	    
	    my $v1= $vertices[$i];
	    my $v2= $vertices[$j];

	    my $w= UCL::Graph::Base::distance($graph, $v1, $v2);

	    $barabasi->add_weighted_edge($v1, $w, $v2);

	    if (!exists($nodes_degree{$v1})) {
		$nodes_degree{$v1}= 1;
	    } else {
		$nodes_degree{$v1}++;
	    }
	    if (!exists($nodes_degree{$v2})) {
		$nodes_degree{$v2}= 1;
	    } else {
		$nodes_degree{$v2}++;
	    }
	    $sum_Dj+= 2;

	}
    }

    for (my $i= $m; $i < @vertices; $i++) {
	my $v1= $vertices[$i];

	my $n_edges= 0;
	while ($n_edges < $m) {

	    my $P= rand(1);

	    my $last= 0;
	    my $j;
	    for ($j= 0; $j < @vertices; $j++) {
		$last+= $nodes_degree{$vertices[$j]}/$sum_Dj;
		if ($P <= $last) {
		    last;
		}
	    }
	    my $v2= $vertices[$j];

	    ($v1 == $v2) and next;
	    ($barabasi->has_edge($v1, $v2)) and next;

	    my $w= UCL::Graph::Base::distance($graph, $v1, $v2);
	    $barabasi->add_weighted_edge($v1, $w, $v2);

	    if (!exists($nodes_degree{$v1})) {
		$nodes_degree{$v1}= 1;
	    } else {
		$nodes_degree{$v1}++;
	    }
	    if (!exists($nodes_degree{$v2})) {
		$nodes_degree{$v2}= 1;
	    } else {
		$nodes_degree{$v2}++;
	    }

	    $sum_Dj+= 2;
	    $n_edges++;
	}
    }

    return $barabasi;
}

# -----[ graph_delaunay ]--------------------------------------------
#
# -------------------------------------------------------------------
sub graph_delaunay($)
{
    my ($graph)= @_;

    my @points;
    foreach my $vertex ($graph->vertices) {
	(!$graph->has_attribute(UCL::Graph::ATTR_COORD, $vertex)) and die;
	my $coord= $graph->get_attribute(UCL::Graph::ATTR_COORD, $vertex);
	push @points, ( [$coord->[0], $coord->[1], $vertex]);
    }

    my $triang= new Triangulation;
    $triang->compute(\@points);

    my $delaunay= new Graph::Undirected;
    foreach my $triangle (@{$triang->get}) {
	my $a= $triangle->[0];
	my $b= $triangle->[1];
	my $c= $triangle->[2];

	# Create vertices and copy their attributes
	for (my $index= 0; $index < 3; $index++) {
	    my $vertex= $triangle->[$index]->[2];
	    $delaunay->add_vertex($vertex);
	    my %attributes= $graph->get_attributes($vertex);
	    foreach my $attr (keys %attributes) {
		$delaunay->set_attribute($attr, $vertex, $attributes{$attr});
	    }
	}

	# Create edges
	if (!$delaunay->has_edge($a->[2], $b->[2])) {
	    $delaunay->add_edge($a->[2], $b->[2]);
	}
	if (!$delaunay->has_edge($b->[2], $c->[2])) {
	    $delaunay->add_edge($b->[2], $c->[2]);
	}
	if (!$delaunay->has_edge($c->[2], $a->[2])) {
	    $delaunay->add_edge($c->[2], $a->[2]);
	}
    }
    return $delaunay;
}


#####################################################################
#
# GRAPH IGP WEIGHTS & CAPACITIES ASSIGNMENT FUNCTIONS
#
#####################################################################

# -----[ graph_igp_fixed ]-------------------------------------------
# This function sets the IGP weights to a given fixed value.
# -------------------------------------------------------------------
sub graph_igp_fixed($$)
{
    my ($graph, $weight)= @_;

    my @edges= $graph->edges();
    for (my $index= 0; $index < @edges/2; $index++) {
	my $vertex_i= $edges[$index*2];
	my $vertex_j= $edges[$index*2+1];
	$graph->set_attribute(UCL::Graph::ATTR_WEIGHT, $vertex_i, $vertex_j,
			      $weight);
    }

    return 0;
}

sub igp_plf($)
{
    my ($x)= @_;
    my $y= 0;
    
    my $alpha= 1;
    my $index= 0;
    my $remain= 0;
    while ($index <= @igen_igp_plf_steps) {
	my $step= $igen_igp_plf_steps[$index];
	if (($index >= @igen_igp_plf_steps) || ($x <= $step)) {
	    $y+= ($x-$remain)*$alpha;
	    last;
	} else {
	    $y+= ($step-$remain)*$alpha;
	    $remain= $step;
	}
	$alpha= $igen_igp_plf{$step};
	$index++;
    }
    return $y;
}

# -----[ graph_igp_distance ]----------------------------------------
# This function sets the IGP weights to values that depend on the
# links length.
# -------------------------------------------------------------------
sub graph_igp_distance($;$)
{
    my ($graph, $plf)= @_;

    my @edges= $graph->edges();
    for (my $index= 0; $index < @edges/2; $index++) {
	my $vertex_i= $edges[$index*2];
	my $vertex_j= $edges[$index*2+1];
	my $weight= UCL::Graph::Base::distance($graph, $vertex_i, $vertex_j);

	# Piecewise linear function of distance
	if (defined($plf) && $plf) {
	    $weight= igp_plf($weight);
	}

	$graph->set_attribute(UCL::Graph::ATTR_WEIGHT, $vertex_i, $vertex_j,
			      $weight);
    }

    return 0;
}

# -----[ graph_igp_invert_capacity ]---------------------------------
# This function sets the IGP weight based on the links capacities.
# -------------------------------------------------------------------
sub graph_igp_invert_capacity($)
{
    my ($graph)= @_;
    my $max_capacity= undef;

    my @edges= $graph->edges();

    # Compute max capacity
    for (my $i= 0; $i < @edges/2; $i++) {
	my $u= $edges[$i*2];
	my $v= $edges[$i*2+1];
	if (!$graph->has_attribute(UCL::Graph::ATTR_CAPACITY, $u, $v)) {
	    gui_dialog_error("No capacity has been assigned to $u->$v.");
	    return -1;
	}
	my $capacity= $graph->get_attribute(UCL::Graph::ATTR_CAPACITY, $u, $v);
	if ($capacity < 0) {
	    gui_dialog_error("Invalid capacity $capacity on $u->$v.");
	    return -1;
	}
	if (!defined($max_capacity) || ($capacity > $max_capacity)) {
	    $max_capacity= $capacity;
	}
    }

    # Check maximum capacity
    if ($max_capacity <= 0) {
	gui_dialog_error("Maximum capacity <= 0.");
	return -1;
    }

    # Assign invert of capacity
    for (my $i= 0; $i < @edges/2; $i++) {
	my $u= $edges[$i*2];
	my $v= $edges[$i*2+1];	
	my $capacity= $graph->get_attribute(UCL::Graph::ATTR_CAPACITY, $u, $v);
	$graph->set_attribute(UCL::Graph::ATTR_WEIGHT, $u, $v,
			      $max_capacity/$capacity);
    }

    return 0;
}

# -----[ graph_igp_rand_uniform ]------------------------------------
# This function assigns IGP weights to links using a random variable
# with uniform distribution. IGP weights are assigned in the range
# [A, B[
# -------------------------------------------------------------------
sub graph_igp_rand_uniform($$$) {
  my ($graph, $min, $max)= @_;

    my @edges= $graph->edges();
    for (my $index= 0; $index < @edges/2; $index++) {
	my $vertex_i= $edges[$index*2];
	my $vertex_j= $edges[$index*2+1];
	my $weight= $min+rand($max);
	$graph->set_attribute(UCL::Graph::ATTR_WEIGHT, $vertex_i, $vertex_j,
			      $weight);
    }

    return 0;
}

# -----[ graph_capacity_fixed ]--------------------------------------
# This function sets the links capacities to a given fixed value.
# -------------------------------------------------------------------
sub graph_capacity_fixed($$)
{
    my ($graph, $capacity)= @_;

    $capacity= text2capacity($capacity);
    (!defined($capacity)) and return -1;

    my @edges= $graph->edges();
    for (my $i= 0; $i < @edges/2; $i++) {
	my $u= $edges[$i*2];
	my $v= $edges[$i*2+1];
	$graph->set_attribute(UCL::Graph::ATTR_CAPACITY,
			      $u, $v, $capacity);
    }

    return 0;
}

# -----[ graph_capacity_random ]-------------------------------------
# This function sets the links capacities to a random value.
# -------------------------------------------------------------------
sub graph_capacity_random($)
{
    my ($graph)= @_;

    my @edges= $graph->edges();
    for (my $i= 0; $i < @edges/2; $i++) {
	my $u= $edges[$i*2];
	my $v= $edges[$i*2+1];
	
	my $capacity= $igen_link_capacities[rand(@igen_link_capacities)];
	$graph->set_attribute(UCL::Graph::ATTR_CAPACITY,
			      $u, $v, $capacity);
    }
}

# -----[ graph_capacity_access_bb ]----------------------------------
# This function sets the links capacities according to the links types
# (backbone or access). A capacity is provided for backbone links and
# another one for the access links.
# -------------------------------------------------------------------
sub graph_capacity_access_bb($$$)
{
    my ($graph, $pop_capacity, $bb_capacity)= @_;

    $pop_capacity= text2capacity($pop_capacity);
    (!defined($pop_capacity)) and return -1;
    $bb_capacity= text2capacity($bb_capacity);
    (!defined($bb_capacity)) and return -1;

    my @edges= $graph->edges();
    for (my $i= 0; $i < @edges/2; $i++) {
	my $u= $edges[$i*2];
	my $v= $edges[$i*2+1];

	my $capacity;
	if (($graph->get_attribute(UCL::Graph::ATTR_TYPE, $u) eq 'backbone') &&
	    ($graph->get_attribute(UCL::Graph::ATTR_TYPE, $v) eq 'backbone')) {
	    $capacity= $bb_capacity;
	} else {
	    $capacity= $pop_capacity;
	}
	$graph->set_attribute(UCL::Graph::ATTR_CAPACITY,
			      $u, $v, $capacity);
    }    
}

# -----[ graph_capacity_load ]---------------------------------------
# This function sets the links capacities based on the traffic
# load. The function selects the smallest capacity that ensures that
# the traffic load can be accomodated.
#
# The function currently does not support the assignment of spare
# capacity.
# -------------------------------------------------------------------
sub graph_capacity_load($$$;$)
{
    my ($graph, $TM, $max_util, $ecmp, $failures)= @_;
    my $result= 0;

    $TM= $graph->get_attribute(UCL::Graph::ATTR_TM);

    if (($max_util < 0) || ($max_util > 100)) {
	gui_dialog_error("Invalid maximum utilization level ($max_util)");
	return -1;
    }
    
    # PHASE (1): enough capacity to be able to carry traffic
    # ------------------------------------------------------
    
    # Compute routing matrix
    my $RM= graph_APSP($graph, $global_options->{ecmp},
		       \&graph_dst_fct_weight);
    $graph->set_attribute(UCL::Graph::ATTR_RM, $RM);
    # Compute link utilization
    my $links_load= graph_link_utilization($graph, $RM, $TM);
    my @edges= $graph->edges();
    for (my $i= 0; $i < @edges/2; $i++) {
	my $u= $edges[$i*2];
	my $v= $edges[$i*2+1];
	my $capacity= 0;
	if (exists($links_load->{$u}{$v})) {
	    $capacity= $links_load->{$u}{$v};
	}
	if (!$graph->directed()) {
	    if (exists($links_load->{$v}{$u})) {
		$capacity+= $links_load->{$v}{$u};
	    }
	}
	my $best_capacity= best_capacity($capacity*100/$max_util);
	if (!defined($best_capacity)) {
	    gui_terminal_add("warning: could not accomodate load on link $u-$v ($capacity)\n");
	    
	    $graph->delete_attribute(UCL::Graph::ATTR_CAPACITY, $u, $v);
	    $result= -1;
	} else {
	    $graph->set_attribute(UCL::Graph::ATTR_CAPACITY,
				  $u, $v, $best_capacity);
	}
    }
    
    # PHASE (2): spare capacity in order to be able to carry traffic
    # in case of single-link failures.
    # --------------------------------------------------------------



    return $result;
}


#####################################################################
#
# GRAPH MEASUREMENT FUNCTIONS
#
#####################################################################

# -----[ graph_path_diversity ]--------------------------------------
#
# -------------------------------------------------------------------
sub graph_path_diversity($)
{
    my ($graph)= @_;

    my $digraph= $graph->copy;
    $digraph->directed(1);
    graph_copy_attributes($digraph, $graph);
    graph_copy_edges_attributes($digraph, $graph);

    my @links_diversity;
    my @vertices= $graph->vertices();
    my $pair_total= scalar(@vertices)*(scalar(@vertices)-1);
    my $pair_cnt= 0;
    foreach my $v_i ($graph->vertices) {
	foreach my $v_j ($graph->vertices) {
	    ($v_i == $v_j) and next;

	    # Build a copy of the graph
	    my $graph_copy= $digraph->copy;
	    graph_copy_attributes($graph_copy, $digraph);
	    graph_copy_edges_attributes($graph_copy, $digraph);

	    # Iterate while paths are available for the current pair
	    # of vertices
	    my $diversity= 0;
	    while (1) {
		my $paths= graph_SSSP($graph_copy, $v_i, 0,
				    \&graph_dst_fct_weight);
		if (exists($paths->{$v_j})) {
		    $diversity++;
		    my $path= $paths->{$v_j}->[0];
		    graph_delete_path($graph_copy, $path);
		} else {
		    last;
		}
	    }
	    push @links_diversity, ($diversity);

	    $pair_cnt++;
	    #if (($pair_cnt % 100) == 0) {
		printf STDERR "\rpath-diversity: %.2f %%",
		(100*$pair_cnt/$pair_total);
		STDERR->flush;
	    #}
	    
	}
    }
    printf STDERR "\rpath-diversity: %.2f %%\n",
    (100*$pair_cnt/$pair_total);
    my $stats= new Statistics::Descriptive::Full();
    $stats->add_data(\@links_diversity);

    return $stats;
}

# -----[ graph_measure_clust_coefficient ]---------------------------
# This function measures the clustering coefficient of the given
# graph.
#
# NOT IMPLEMENTED YET.
# -------------------------------------------------------------------
sub graph_measure_clust_coefficient($)
{
    my ($graph)= @_;

    gui_dialog_error("not yet implemented");
    return -1;
}

# -----[ graph_measure_info ]----------------------------------------
# This function gives some basic information about the given graph
# such as the number of vertices and edges. The information is
# returned on the terminal (console if invoked from the
# command-line).
#
# Return value:
#   0
# -------------------------------------------------------------------
sub graph_measure_info($)
{
    my ($graph)= @_;

    my $msg= "info:\n";
    $msg.= sprintf "num. vertices: %d\n", scalar($graph->vertices());
    $msg.= sprintf "num. edges   : %d\n", scalar($graph->edges());
    gui_terminal_update($msg);
    return 0;
}

# -----[ graph_measure_igp_dist_correl ]-----------------------------
# This function measures the "correlation" between the IGP weights and
# the links length. The results are shown on the terminal (console if
# invoked from the command-line).
#
# Return value:
#   0
# -------------------------------------------------------------------
sub graph_measure_igp_dist_correl($)
{
    my ($graph)= @_;

    my @edges= $graph->edges();
    for (my $i= 0; $i < @edges/2; $i++) {
	my $u= $edges[$i*2];
	my $v= $edges[$i*2+1];
	my $weight= $graph->get_attribute(UCL::Graph::ATTR_WEIGHT, $u, $v);
	my $distance= UCL::Graph::Base::distance($graph, $u, $v);
	print "$u->$v\t$distance\t$weight\n";
    }
    return 0;
}

# -----[ graph_measure_igp_capa_correl ]-----------------------------
# This function measures the "correlation" between the IGP weights and
# the links capacity. The results are shown on the terminal (console if
# invoked from the command-line).
#
# Return value:
#   0
# -------------------------------------------------------------------
sub graph_measure_igp_capa_correl($)
{
    my ($graph)= @_;

    my @edges= $graph->edges();
    for (my $i= 0; $i < @edges/2; $i++) {
	my $u= $edges[$i*2];
	my $v= $edges[$i*2+1];
	my $weight= $graph->get_attribute(UCL::Graph::ATTR_WEIGHT, $u, $v);
	my $capacity= $graph->get_attribute(UCL::Graph::ATTR_CAPACITY, $u, $v);
	if (defined($capacity)) {
	    print "$u->$v\t$capacity\t$weight\n";
	}
    }
    return 0;
}

# -----[ graph_measure_diameter ]------------------------------------
# This function measures the diameter of a domain, i.e. the maximum
# distance between 2 nodes. If the domain contains a single node, its
# diameter is 0. The distance is the geographical distance
# (spherical).
#
# Return value:
#   the diameter of the given graph.
# -------------------------------------------------------------------
sub graph_measure_diameter($)
{
    my ($graph)= @_;

    my @vertices= $graph->vertices();
    my $diameter= 0;
    for (my $i= 0; $i < scalar(@vertices)-1; $i++) {
	my $u= $vertices[$i];
	for (my $j= $i+1; $j < scalar(@vertices); $j++) {
	    my $v= $vertices[$j];
	    my $distance= UCL::Graph::Base::distance($graph, $u, $v);
	    if ($distance > $diameter) {
		$diameter= $distance;
	    }
	}
    }

    return $diameter;
}

# -----[ graph_measure ]---------------------------------------------
# This function applies a given measure on the given graph. The
# measure is specified using its name. The measure must have been
# registered in the list of measures (the hash table
# %igen_measure_methods).
#
# The measure specification is a string structured as follows:
#   <name>[:<parameter1>[:<parameter2>...]]
# where <parameter1>, <parameter2>, etc. can be of the form
#   -KEY=VALUE
# Such KEY/VALUE pairs are optional parameters that can be used by the
# measure function or by the statistical analysis and ploting
# functions.
#
# The reason for using such a measure specification is to allow the
# user to invoke a measure through the command-line.
#
# Return value:
#   0  in case of success
#  -1  in case of failure
# -------------------------------------------------------------------
sub graph_measure($$)
{
    my ($graph, $spec)= @_;

    my @spec_fields= split /\:/, $spec;
    my $method= shift @spec_fields;

    # Separate arguments and options (starting with '-')
    my %spec_args= ();
    my $i= 0;
    while ($i < scalar(@spec_fields)) {
	if ($spec_fields[$i] =~ m/^(\-.+)\=(.*)$/) {
	    $spec_args{$1}= $2;
	    splice(@spec_fields, $i, 1);
	} else {
	    $i++;
	}
    }

    # Look for the measure method in the repository...
    if (exists($igen_measure_methods{$method})) {
	my $measure_fct= $igen_measure_methods{$method};

	if (defined($measure_fct)) {
	    return &$measure_fct($graph, @spec_fields, %spec_args);
	}

    } else {
	gui_dialog_error("unknown measure method [$method]");
    }

    return -1;
}

# -----[ graph_vertex_distance ]-------------------------------------
# Compute the distance between all the pairs of nodes.
#
# Return value:
# - statistics on array of distances
#   OR
# - undef if one vertex has no coordinates (ATTR_COORD)
# -------------------------------------------------------------------
sub graph_vertex_distance($)
{
    my ($graph)= @_;

    # ---| Build list of positions |---
    my @positions= ();
    foreach my $v ($graph->vertices()) {
	if (!$graph->has_attribute(UCL::Graph::ATTR_COORD, $v)) {
	    return undef;
	}
	my $coord= $graph->get_attribute(UCL::Graph::ATTR_COORD, $v);
	push @positions, ($coord);
    }

    # ---| Compute all distances |---
    my $progress= new UCL::Progress();
    $progress->{message}= 'Computing distances ';
    $progress->{pace}= 1;
    $progress->{percent}= 1;
    my $cnt= 0;
    my $total= scalar(@positions)*(scalar(@positions)-1)/2;
    my @distances= ();
    for (my $i= 0; $i < scalar(@positions)-1; $i++) {
	for (my $j= $i+1; $j < scalar(@positions); $j++) {
	    my $distance= UCL::Graph::Base::pt_distance($positions[$i],
							$positions[$j]);
	    push @distances, ($distance);
	    $cnt++;
	    $progress->bar($cnt, $total, 20);
	}
    }
    $progress->reset();
    $progress->bar($cnt, $total, 20);
    print "\n";

    # ---| Compute distribution |---
    my $stat= new Statistics::Descriptive::Full();
    $stat->add_data(\@distances);
    $stat->frequency_distribution(100);
    
    return $stat;
}

# -----[ graph_adjacency_radius ]------------------------------------
# Compute the number of nodes at a given distance
# -------------------------------------------------------------------
sub graph_adjacency_radius($)
{
    my ($graph)= @_;

    # ---| Build list of positions |---
    my @positions= ();
    foreach my $v ($graph->vertices()) {
	if (!$graph->has_attribute(UCL::Graph::ATTR_COORD, $v)) {
	    return undef;
	}
	my $coord= $graph->get_attribute(UCL::Graph::ATTR_COORD, $v);
	push @positions, ($coord);
    }

    # ---| Compute nodes at given distance of each node |---
    my $progress= new UCL::Progress();
    $progress->{message}= 'Computing distances ';
    $progress->{pace}= 1;
    $progress->{percent}= 1;
    my $cnt= 0;
    my $total= scalar(@positions)*(scalar(@positions)-1);
    my @nodes= ();
    for (my $i= 0; $i < scalar(@positions); $i++) {
	my  @distances= ();
	for (my $j= 0; $j < scalar(@positions); $j++) {
	    ($i != $j) or next;
	    my $distance= int(UCL::Graph::Base::pt_distance($positions[$i],
							    $positions[$j]));
	    push @distances, ($distance);
	    $cnt++;
	    $progress->bar($cnt, $total, 20);
	}
	my $stat= new Statistics::Descriptive::Full();
	$stat->add_data(\@distances);
	my $median= $stat->median();
	my $perc20= $stat->percentile(20);
	my $perc80= $stat->percentile(80);
	push @nodes, ([$i, $median, $perc20, $perc80]);
    }
    $progress->reset();
    $progress->bar($cnt, $total, 20);
    print "\n";

    return \@nodes;
}

# -----[ graphs_domains_sizes ]--------------------------------------
#
# -------------------------------------------------------------------
sub graphs_domains_sizes($)
{
    my ($graphs)= @_;

    my @array_sizes= ();
    foreach my $graph (values %$graphs) {
	push @array_sizes, (scalar($graph->vertices()));
    }

    my $stat= new Statistics::Descriptive::Full();
    $stat->add_data(\@array_sizes);
    $stat->frequency_distribution($stat->max());

    return $stat;
}

# -----[ graphs_domains_diameters ]----------------------------------
#
# -------------------------------------------------------------------
sub graphs_domains_diameters($)
{
    my ($graphs)= @_;

    my $progress= new UCL::Progress();
    $progress->{message}= 'Computing distances ';
    $progress->{pace}= 1;
    $progress->{percent}= 1;
    my @array_sizes= ();
    my $total= scalar(values %$graphs);
    my $cnt= 0;
    foreach my $graph (values %$graphs) {
	push @array_sizes, (graph_measure_diameter($graph));
	$progress->bar($cnt, $total, 20);
	$cnt++;
    }
    $progress->reset();
    $progress->bar($cnt, $total, 20);
    print "\n";

    print "Computing statistics...\n";
    my $stat= new Statistics::Descriptive::Full();
    $stat->add_data(\@array_sizes);
    $stat->frequency_distribution($stat->max());


    return $stat;
}

#####################################################################
#
# TRAFFIC MATRICES GENERATION FUNCTIONS
#
#####################################################################

# -----[ graph_TM_fixed ]--------------------------------------------
#
# -------------------------------------------------------------------
sub graph_TM_fixed($$)
{
    my ($graph, $volume)= @_;
    my %TM= ();

    if (!defined($volume)) {
	gui_dialog_error("Error: missing 'volume' parameter");
    }

    $volume= text2capacity($volume);
    (!defined($volume)) and return undef;

    my @vertices= $graph->vertices();
    for (my $i= 0; $i < @vertices; $i++) {
	for (my $j= 0; $j < @vertices; $j++) {
	    if ($i != $j) {
		$TM{$i}{$j}= $volume;
	    } else {
		$TM{$i}{$j}= 0;
	    }
	}
    }

    return \%TM;
}

# -----[ graph_TM_random_uniform ]-----------------------------------
#
# -------------------------------------------------------------------
sub graph_TM_random_uniform($$$)
{
    my ($graph, $min_volume, $max_volume)= @_;
    my %TM= ();

    if (!defined($min_volume)) {
	gui_dialog_error("Error: missing 'min-bandwidth' parameter");
    }
    if (!defined($max_volume)) {
	gui_dialog_error("Error: missing 'max-bandwidth' parameter");
    }

    $min_volume= text2capacity($min_volume);
    (!defined($min_volume)) and return undef;
    $max_volume= text2capacity($max_volume);
    (!defined($max_volume)) and return undef;

    if ($min_volume > $max_volume) {
	gui_dialog_error("Error: min ($min_volume) > max ($max_volume)");
	return undef;
    }
    my @vertices= $graph->vertices();
    for (my $i= 0; $i < @vertices; $i++) {
	for (my $j= 0; $j < @vertices; $j++) {
	    if ($i != $j) {
		$TM{$i}{$j}= $min_volume+rand($max_volume-$min_volume);
	    } else {
		$TM{$i}{$j}= 0;
	    }
	}
    }

    return \%TM;
}

# -----[ graph_TM_random_pareto ]------------------------------------
#
# -------------------------------------------------------------------
sub graph_TM_random_pareto($$$$)
{
    my ($graph, $shape, $scale, $volume)= @_;
    my %TM= ();

    if (!defined($shape)) {
	gui_dialog_error("Error: missing 'shape' parameter");
    }
    if (!defined($scale)) {
	gui_dialog_error("Error: missing 'scale' parameter");
    }
    if (!defined($volume)) {
	gui_dialog_error("Error: missing 'volume' parameter");
    }

    $volume= text2capacity($volume);
    (!defined($volume)) and return undef;

    if ($shape <= 0) {
	gui_dialog_error("Error: 'shape' must be > 0");
	return undef;
    }
    my @vertices= $graph->vertices();
    for (my $i= 0; $i < @vertices; $i++) {
	for (my $j= 0; $j < @vertices; $j++) {
	    if ($i != $j) {
		my $random= rand();
		$TM{$i}{$j}= $volume*$scale*pow(1/(1-$random), 1.0/$shape);
	    } else {
		$TM{$i}{$j}= 0;
	    }
	}
    }

    return \%TM;
}

# -----[ graph_TM_generate ]-----------------------------------------
#
# -------------------------------------------------------------------
sub graph_TM_generate($$)
{
    my ($graph, $spec)= @_;

    my @spec_fields= split /\:/, $spec;
    my $method= shift @spec_fields;

    if (exists($igen_traffic_methods{$method})) {
	my $TM_fct= $igen_traffic_methods{$method};

	if (defined($TM_fct)) {
	    my $TM= &$TM_fct($graph, @spec_fields);
	    if (!defined($TM)) {
		return -1;
	    } else {
		$graph->set_attribute(UCL::Graph::ATTR_TM, $TM);
	    }
	}

    } else {
	gui_dialog_error("unknown TM-generation method [$method]");
    }

    return 0;
}


#####################################################################
#
# GRAPH DRAWING FUNCTIONS
#
#####################################################################

# -----[ gui_screen2x ]----------------------------------------------
# Convert the screen X coordinate to a longitude coordinate (in the
# map).
# -------------------------------------------------------------------
sub gui_screen2x($$)
{
    my ($canvas, $x)= @_;

    my $width= $canvas->width;
    my $height= $canvas->height;
    return ($x*(XBOUND/$width)/$global_plot_params->{zoom_factor})+
	(XOFFSET)-$global_plot_params->{xscroll};
}

# -----[ gui_screen2y ]----------------------------------------------
# Convert the screen Y coordinate to a latitude coordinate (in the
# map).
# -------------------------------------------------------------------
sub gui_screen2y($$)
{
    my ($canvas, $y)= @_;

    my $width= $canvas->width;
    my $height= $canvas->height;
    return -(($y*(YBOUND/$height)/$global_plot_params->{zoom_factor})+
	     (YOFFSET)-$global_plot_params->{yscroll});
}

# -----[ gui_x2screen ]----------------------------------------------
# Convert a longitude coordinate (in the map) to a canvas coordinate.
# -------------------------------------------------------------------
sub gui_x2screen($$)
{
    my ($canvas, $x)= @_;

    my $width= $canvas->width;
    my $height= $canvas->height;
    return ($global_plot_params->{xscroll}+$x-(XOFFSET))*
	$global_plot_params->{zoom_factor}*
	($width/XBOUND);
}

# -----[ gui_y2screen ]----------------------------------------------
# Convert a latitude coordinate (in the map) to a canvas coordinate.
# -------------------------------------------------------------------
sub gui_y2screen($$)
{
    my ($canvas, $y)= @_;

    my $width= $canvas->width;
    my $height= $canvas->height;
    return ($global_plot_params->{yscroll}-$y-(YOFFSET))*
	$global_plot_params->{zoom_factor}*
	($height/YBOUND);
}

# -----[ gui_draw_poly ]---------------------------------------------
#
# -------------------------------------------------------------------
sub gui_draw_poly($$)
{
    my ($canvas, $poly_r)= @_;

    my $start= undef;
    my $end= undef;
    for (my $i= 0; $i < scalar(@$poly_r); $i++) {
	if ($end == undef) {
	    $end= $poly_r->[$i];
	}
	if ($start != undef) {
	    $canvas->createLine(gui_x2screen($canvas, $start->[0]),
				gui_y2screen($canvas, $start->[1]),
				gui_x2screen($canvas, $poly_r->[$i]->[0]),
				gui_y2screen($canvas, $poly_r->[$i]->[1]),
				-width=>1, -fill=>'red');
	}
	$start= $poly_r->[$i];
    }
    $canvas->createLine(gui_x2screen($canvas, $start->[0]),
			gui_y2screen($canvas, $start->[1]),
			gui_x2screen($canvas, $end->[0]),
			gui_y2screen($canvas, $end->[1]),
			-width=>1, -fill=>'red');
}

# ----[ gui_draw_line ]----------------------------------------------
#
# -------------------------------------------------------------------
sub gui_draw_line($$$$$$;%)
{
    my ($canvas, $coord_i, $coord_j, $color, $width, $tag, %args)= @_;

    #$width*= $global_plot_params->{zoom_factor};

    my ($x1, $y1, $x2, $y2);
    my $behind_earth= undef;
    if ($coord_i->[0] < $coord_j->[0]) {
	$x1= $coord_i->[0];
	$y1= $coord_i->[1];
	$x2= $coord_j->[0];
	$y2= $coord_j->[1];
    } else {
	$x1= $coord_j->[0];
	$y1= $coord_j->[1];
	$x2= $coord_i->[0];
	$y2= $coord_i->[1];
	if (exists($args{-arrow})) {
	    if ($args{-arrow} eq 'last') {
		$args{-arrow}= 'first';
	    } elsif ($args{-arrow} eq 'first') {
		$args{-arrow}= 'last';
	    }
	}
    }
    $behind_earth= ($x2-$x1) > ($x1-(-360+$x2));
    if (!$behind_earth) {
	$canvas->createLine(gui_x2screen($canvas, $x1),
			    gui_y2screen($canvas, $y1),
			    gui_x2screen($canvas, $x2),
			    gui_y2screen($canvas, $y2),
			    -tags=>$tag,
			    -fill=>$color,
			    -width=>$width,
			    %args);
    } else {
	# Find intersection with horizontal border
	my ($x, $y)= (-180, undef);
	$y= $y1+($x-$x1)/((-360+$x2)-$x1)*($y2-$y1);
	
	$canvas->createLine(gui_x2screen($canvas, $x1),
			    gui_y2screen($canvas, $y1),
			    gui_x2screen($canvas, -180),
			    gui_y2screen($canvas, $y),
			    -tags=>$tag,
			    -fill=>$color,
			    -width=>$width,
			    %args);
	$canvas->createLine(gui_x2screen($canvas, $x2),
			    gui_y2screen($canvas, $y2),
			    gui_x2screen($canvas, 180),
			    gui_y2screen($canvas, $y),
			    -tags=>$tag,
			    -fill=>$color,
			    -width=>$width,
			    %args);
    }
}

# -----[ gui_draw_node ]---------------------------------------------
#
# -------------------------------------------------------------------
sub gui_draw_node($$$$$$;$)
{
    my ($canvas, $x, $y, $color, $wnode, $tags, $shape)= @_;

    my $scale_factor= 1;
    #my $scale_factor= $global_plot_params->{zoom_factor};

    if (!defined($shape) || ($shape == 0)) {
	$canvas->createOval(gui_x2screen($canvas, $x)-($wnode)/2*
			    $scale_factor,
			    gui_y2screen($canvas, $y)-($wnode)/2*
			    $scale_factor,
			    gui_x2screen($canvas, $x)+($wnode)/2*
			    $scale_factor,
			    gui_y2screen($canvas, $y)+($wnode)/2*
			    $scale_factor,
			    -tags=>$tags,
			    -fill=>$color,
			    -width=>1);
    } elsif ($shape == 1) {
	$canvas->createRectangle(gui_x2screen($canvas, $x)-($wnode)/2*
				 $scale_factor,
				 gui_y2screen($canvas, $y)-($wnode)/2*
				 $scale_factor,
				 gui_x2screen($canvas, $x)+($wnode)/2*
				 $scale_factor,
				 gui_y2screen($canvas, $y)+($wnode)/2*
				 $scale_factor,
				 -tags=>$tags,
				 -fill=>$color,
				 -width=>1);
    }
}

# ----[ gui_draw_link ]----------------------------------------------
# Draw a link between two nodes.
#
# Arguments:
# - canvas
# - graph: the graph where this link is defined
# - (u, v): the link's endpoints
# - graphical parameters
# - tags
# -------------------------------------------------------------------
sub gui_draw_link($$$$$$)
{
    my ($canvas, $graph, $u, $v, $params, $tags)= @_;

    # ---| Determine endpoints' coordinates |---
    my $u_coord= $graph->get_attribute(UCL::Graph::ATTR_COORD, $u);
    my $v_coord= $graph->get_attribute(UCL::Graph::ATTR_COORD, $v);

    # ---| Determine link color |---
    my $color= 'black';
    if ($graph->has_attribute(UCL::Graph::ATTR_COLOR, $u, $v)) {
	$color= $graph->get_attribute(UCL::Graph::ATTR_COLOR, $u, $v);
    } elsif ($graph->has_attribute(UCL::Graph::ATTR_RELATION, $u, $v)) {
	$color= 'blue';
    } else {
	if ($graph->has_attribute(UCL::Graph::ATTR_LOAD, $u, $v)) {
	    my $load= $graph->get_attribute(UCL::Graph::ATTR_LOAD, $u, $v);
	    $color= gui_link_load_color($load);
	}
    }

    my $access= 0;
    if ($graph->has_attribute(UCL::Graph::ATTR_TYPE, $u)) {
	my $type= $graph->get_attribute(UCL::Graph::ATTR_TYPE, $u);
	($type eq 'access') and $access= 1;
    }
    if ($graph->has_attribute(UCL::Graph::ATTR_TYPE, $v)) {
	my $type= $graph->get_attribute(UCL::Graph::ATTR_TYPE, $v);
	($type eq 'access') and $access= 1;
    }


    # ---| Determine width (proportional to capacity) |---
    my $width= 1;
    if ($graph->has_attribute(UCL::Graph::ATTR_CAPACITY, $u, $v)) {
	my $capacity=
	    capacity2text($graph->get_attribute(UCL::Graph::ATTR_CAPACITY,
						$u, $v));
	if (exists($igen_link_widths{$capacity})) {
	    $width*= $igen_link_widths{$capacity};
	}
    }

    if (($access == 0) or ($params->{access} == 1)) {
	gui_draw_line($canvas, $u_coord, $v_coord, $color, $width, $tags);
    }
}

# ----[ gui_draw_continents ]----------------------------------------
# Draw the underlying continents (polygons).
# -------------------------------------------------------------------
sub gui_draw_continents($)
{
    my ($canvas)= @_;

    foreach my $continent (keys %igen_continents) {
	gui_draw_poly($canvas, $igen_continents{$continent});
    }
}

# ----[ gui_draw_grid ]----------------------------------------------
# Draw the underlying grid.
# -------------------------------------------------------------------
sub gui_draw_grid($$$)
{
    my ($canvas, $xgrid, $ygrid)= @_;

    # Draw grid
    for (my $x= 0; $x <= XBOUND/$xgrid; $x+= 1) {
	$canvas->createLine(gui_x2screen($canvas, $x*$xgrid+(XOFFSET)),
			    gui_y2screen($canvas, YOFFSET),
			    gui_x2screen($canvas, $x*$xgrid+(XOFFSET)),
			    gui_y2screen($canvas, YBOUND+(YOFFSET)),
			    -fill=>'lightgray',
			    -width=>1);
    }
    for (my $y= 0; $y <= YBOUND/$ygrid; $y+= 1) {
	$canvas->createLine(gui_x2screen($canvas, XOFFSET),
			    gui_y2screen($canvas, $y*$ygrid+(YOFFSET)),
			    gui_x2screen($canvas, XBOUND+(XOFFSET)),
			    gui_y2screen($canvas, $y*$ygrid+(YOFFSET)),
			    -fill=>'lightgray',
			    -width=>1);
    }
}

# ----[ gui_draw_graph ]---------------------------------------------
#
# -------------------------------------------------------------------
sub gui_draw_graph($$$)
{
    my ($canvas, $graph, $params)= @_;

    # ---| Do not draw a graph that has no geographical coordinates |---
    if (!$graph->has_attribute(UCL::Graph::ATTR_GFX) ||
	($graph->get_attribute(UCL::Graph::ATTR_GFX) != 1) ||
	(!$graph->has_attribute(UCL::Graph::ATTR_AS))) {
	return;
    }

    my $as= $graph->get_attribute(UCL::Graph::ATTR_AS);

    $graph->directed(0);

    my $wnode= $params->{wnode};
    my $hnode= $params->{hnode};

    # ---| Draw edges |---
    if ($params->{links}) {
	my @edges= $graph->edges();
	for (my $index= 0; $index < @edges/2; $index++) {
	    my $vertex_i= $edges[$index*2];
	    my $vertex_j= $edges[$index*2+1];
	    gui_draw_link($canvas, $graph, $vertex_i, $vertex_j, $params,
			  ['link', $vertex_i, $vertex_j, $as]);
	}
    }

    # ---| Draw vertices |---
    foreach my $vertex ($graph->vertices) {
	my $access= 0;
	my $coord= $graph->get_attribute(UCL::Graph::ATTR_COORD, $vertex);
	my $as= $graph->get_attribute(UCL::Graph::ATTR_AS, $vertex);
	my $color= 'green';
	my $shape= 0;
	if ($graph->has_attribute(UCL::Graph::ATTR_TYPE,
				  $vertex)) {
	    my $type= $graph->get_attribute(UCL::Graph::ATTR_TYPE,
					    $vertex);
	    if ($type eq 'access') {
		$access= 1;
	    } else {
		$shape= 1;
	    }
	}
	    
	if (($access == 0) or ($params->{access} == 1)) {
	    my $tags= ["router", $vertex, $as];
	    gui_draw_node($canvas, $coord->[0], $coord->[1],
			  $color, $wnode, $tags, $shape);
	    if ($params->{labels}) {
		$canvas->createText(gui_x2screen($canvas, $coord->[0])+$wnode,
				    gui_y2screen($canvas, $coord->[1])+$wnode,
				    -text=>graph_vertex_name($graph, $vertex),
				    -fill=>'black',
				    -justify=>'left',
				    -tags=>$tags);
	    }
	}
    }

}

# -----[ gui_draw_igraph ]-------------------------------------------
# Draw graph of interdomain links.
# -------------------------------------------------------------------
sub gui_draw_igraph($$)
{
    my ($cCanvas, $igraph)= @_;

    my @edges= $igraph->edges();
    for (my $i= 0; $i < @edges/2; $i++) {
	my $u= $edges[$i*2];
	my $v= $edges[$i*2+1];
	gui_draw_link($cCanvas, $igraph, $u, $v, undef, ["ilink", $u, $v]);
    }
}

# -----[ gui_plot_clear ]--------------------------------------------
# Clear the current plot (clear the whole canvas).
# -------------------------------------------------------------------
sub gui_plot_clear()
{
    $cCanvas->delete('all');    
}

# -----[ gui_link_load_color ]---------------------------------------
# Determine the color associated with the given link load.
# -------------------------------------------------------------------
sub gui_link_load_color($)
{
    my ($load)= @_;

    my $index= $load/100*@igen_link_load_colors;
    if ($index >= @igen_link_load_colors) {
	$index= @igen_link_load_colors-1;
    }
    return $igen_link_load_colors[$index];
}

# -----[ gui_plot_graph ]--------------------------------------------
# Plot the whole Internet topology.
# -------------------------------------------------------------------
sub gui_plot_graph($)
{
    my ($db_graph)= @_;

    (!exists($GUI{Canvas})) and return;

    # Clear the canvas
    gui_plot_clear();

    return if (!defined($db_graph));

    # ---| Draw grid |---
    if ($global_plot_params->{grid}) {
	gui_draw_grid($cCanvas,
		      $global_plot_params->{xgrid},
		      $global_plot_params->{ygrid});
    }

    # ---| Draw continents |---
    if ($global_plot_params->{continents}) {
	gui_draw_continents($cCanvas);
    }

    (!defined($db_graph)) and return;

    # ---| Draw interdomain links |---
    if ($global_plot_params->{igraph} && defined($db_graph->{igraph})) {
	gui_draw_igraph($cCanvas, $db_graph->{igraph});
    }
    
    # ---| Draw all the domain's graphs |---
    for my $domain (keys %{$db_graph->{as2graph}}) {
	gui_draw_graph($cCanvas, $db_graph->{as2graph}->{$domain},
		       $global_plot_params);
    }

    # ---| Draw traffic |---
    if (exists($db_graph->{traffic})) {
	foreach my $src (keys %{$db_graph->{traffic}}) {
	    my ($src_as, $src_id)= split /\:/, $src;
	    my $graph_i= $db_graph->{as2graph}->{$src_as};
	    my $coord_i= $graph_i->get_attribute(UCL::Graph::ATTR_COORD, $src_id);
	    foreach my $dst (keys %{$db_graph->{traffic}->{$src}}) {
		my ($dst_as, $dst_id)= split /\:/, $dst;
		my $graph_j= $db_graph->{as2graph}->{$dst_as};
		my $coord_j= $graph_j->get_attribute(UCL::Graph::ATTR_COORD,
						     $dst_id);
		my $load= $db_graph->{traffic}->{$src}{$dst};
		gui_draw_line($cCanvas, $coord_i, $coord_j,
			      gui_link_load_color($load), 1,
			      ["traffic", $src_id, $src_as, $dst_id, $dst_as]);
	    }
	}
    }

}


#####################################################################
#
# GRAPH GENERATION FUNCTIONS
#
#####################################################################

# TODO: add options to allow multiple vertices to be placed at the
# same coordinates

# -----[ poly_bounds ]-----------------------------------------------
# Compute the bounds of the smallest rectangle containing the given
# polygon.
#
# Parameters:
#   a polygon (ref to array of coordinates)
#
# Result:
#   array (min-x, min-y, max-x, max-y)
# -------------------------------------------------------------------
sub poly_bounds($)
{
    my ($poly)= @_;
    my ($min_x, $min_y, $max_x, $max_y)= (undef, undef, undef, undef);

    foreach (@$poly) {
	my $x= $_->[0];
	my $y= $_->[1];
	(!defined($min_x) || ($x < $min_x)) and
	    $min_x= $x;
	(!defined($min_y) || ($y < $min_y)) and
	    $min_y= $y;
	(!defined($max_x) || ($x > $max_x)) and
	    $max_x= $x;
	(!defined($max_y) || ($y > $max_y)) and
	    $max_y= $y;
    }

    return ($min_x, $min_y, $max_x, $max_y);
}

# -----[ graph_gen_random_vertices ]---------------------------------
#
# -------------------------------------------------------------------
sub graph_gen_random_vertices($;$$)
{
    my ($n_vertices, $in_continents, $continents)= @_;
    my $graph= new Graph::Undirected;
    $graph->set_attribute(UCL::Graph::ATTR_GFX, 1);
    
    my $index= 0;
    while ($index < $n_vertices) {
	my $x= rand(XBOUND)+XOFFSET;
	my $y= rand(YBOUND)+YOFFSET;
	my $ok= 0;
	if (defined($in_continents) && ($in_continents == 1)) {
	    if ($continents eq 'all') {
		foreach my $continent (%igen_continents) {
		    my $t= pt_in_poly([$x, $y], $igen_continents{$continent});
		    if ($t > 0) {
			$ok= 1;
			last;
		    }
		}
	    } else {
		$ok= pt_in_poly([$x, $y], $igen_continents{$continents});
	    }
	} else {
	    $ok= 1;
	}
	if ($ok) {
	    $graph->add_vertex($index);
	    $graph->set_attribute(UCL::Graph::ATTR_COORD, $index, [$x, $y]);
	    $index++;
	}
    }

    return $graph;
}

# -----[ graph_gen_ht_vertices ]-------------------------------------
sub graph_gen_ht_vertices($)
{
    my ($n_vertices)= @_;

    my ($min_x, $max_x, $min_y, $max_y)= (-180, 180, -90, 90);
    my $delta_x= $max_x-$min_x;
    my $delta_y= $max_y-$min_y;
    my $scale= 10;

    my $graph= new Graph::Undirected();
    $graph->set_attribute(UCL::Graph::ATTR_GFX, 1);

    # ---| Cut area in squares |---
    my $v= 0;
    while ($n_vertices > 0) {
	
	for (my $i= 0; $i < int($delta_x/$scale); $i++) {
	    for (my $j= 0; $j < int($delta_y/$scale); $j++) {

		my $num= IGen::Random::pareto(1000000*$scale*$scale, 1);
		$num= ($num <= (3*$scale*$scale/4)) ?
		    ($num) : (2*$scale*$scale/4);
		
		for (my $k= 0; $k < $num; $k++) {
		    my $x= $scale*$i+IGen::Random::uniform($scale);
		    my $y= $scale*$j+IGen::Random::uniform($scale);
		    $x+= $min_x;
		    $y+= $min_y;

		    print "[$i,$j,$k,$scale,$delta_x, $delta_y] => ($x, $y)\n";

		    $graph->add_vertex($v);
		    $graph->set_attribute(UCL::Graph::ATTR_COORD,
					  $v, [$x, $y]);
		    $n_vertices--;
		    $v++;

		    ($n_vertices == 0) and last;
		    
		}
		
		($n_vertices == 0) and last;

	    }

	    ($n_vertices == 0) and last;
	    
	}

    }
    
    return $graph;
}

# -----[ graph_gen_normal_vertices ]---------------------------------
sub graph_gen_normal_vertices($)
{
    my ($n_vertices)= @_;

    my $graph= Graph::Undirected->new;

    return $graph;
}

#####################################################################
#
# IMPORT/EXPORT FILTERS
#
#####################################################################

# -----[ igen_filters_get_filetypes ]--------------------------------
# Build a list of file types suitable for the open/save file dialog
# box. The listed filetypes will only include filters which support
# the requested capability.
#
# Parameter:
# - capabilities: IGen::FilterBase::EXPORT/IMPORT_SINGLE/MULTIPLE
#
# Return:
#   undef if no suitable filter was found.
# -------------------------------------------------------------------
sub igen_filters_get_filetypes(@)
{
    my (@capabilities)= @_;

    my @filetypes= ();
    #push @filetypes, (['All files', '.*']);
    foreach my $name (sort keys %igen_filters) {
	my $filter= $igen_filters{$name}->[0];
	my $filter_ok= 0;
	foreach (@capabilities) {
	    if ($filter->has_capability($_)) {
		$filter_ok= 1;
		last;
	    }
	}
	if ($filter_ok) {
	    my $extensions= $igen_filters{$name}->[1];
	    if (!defined($extensions)) {
		$extensions= $filter->{extensions};
		(!defined($extensions)) and next;
	    }
	    push @filetypes, ([$name, $extensions]);
	}
    }
    if (scalar(@filetypes) < 1) {
	gui_dialog_error("no suitable export filter found");
	return undef;
    }
    return \@filetypes;
}

# -----[ igen_filter_import ]----------------------------------------
# Import a graph file using a registered filter. The filter which will
# be used is searched based on the filename extension.
#
# Parameter:
# - filename
#
# Return value:
#   0   on success
#   -1  in case of error
# -------------------------------------------------------------------
sub igen_filter_import($;$)
{
    my ($filename, $domain_id)= @_;

    if (!($filename =~ m/^(.+)(\.[^\.]+)$/)) {
	gui_dialog_error('This file type is not supported.');
	return -1;
    }

    my $extension= $2;
    if (exists($igen_filters_extensions{$extension})) {
	my $filter= $igen_filters_extensions{$extension};
	my $graph= $filter->import_graph($filename);
	if (!defined($graph)) {
	    gui_dialog_error("Import error [".$filter->get_error()."]");
	    return -1;
	}
	# ---| multiple/single graph(s) |---
	if (ref($graph) eq "HASH") {
	    foreach (values %{$graph->{as2graph}}) {
		db_graph_add($_);
	    }
	    # ---| Remove all interdomain links from replaced domains |---
	    # To be done...
	    # ---| Add new interdomain links |---
	    $db_graph->{igraph}= $graph->{igraph};
	} else {
	    db_graph_add($graph, $domain_id);
	}
    } else {
	gui_dialog_error("No filter for file of type \"$extension\"");
	return -1;
    }

    return 0;
}

# -----[ igen_filter_export ]----------------------------------------
# Export the given graph using the specified filename. The export
# filter will be based on the filename extension. A filter name may be
# specified in order to force which export filter will be used.
#
# Parameters:
# - filename
# - graph (single graph or hash of multiple graphs)
# - filter-name [optional]
#
# Return value:
#   0   on success
#   -1  in case of error
# -------------------------------------------------------------------
sub igen_filter_export($$;$)
{
    my ($filename, $graph, $options)= @_;
    my $filter= undef;

    # Find filter based on extension or filter-name
    if (!exists($options->{format})) {
	# ---| Find filter based on file extension |---
	if (!($filename =~ m/^(.+)(\.[^\.]+)$/)) {
	    gui_dialog_error("Cannot infer export format from file extension in \"$filename\"");
	    return -1;
	}
	my $extension= $2;
	if (!exists($igen_filters_extensions{$extension})) {
	    gui_dialog_error("Cannot infer export filter for file extension \"$extension\"");
	    return -1;
	}
	$filter= $igen_filters_extensions{$extension};
    } else {
      my $filter_name= $options->{format};
	# ---| Find filter based on name |---
	if (!exists($igen_filters{$filter_name})) {
	    gui_dialog_error("No filter named \"$filter_name\"");
	    return -1;	    
	}
	$filter= $igen_filters{$filter_name}->[0];
    }

    # ---| Export single/multiple graph(s) |---
    if (!defined($options)) {
	$options= $filter->configure_export(-parent=>$GUI{Main},
					    -filename=>$filename);
    }
    my $result= $filter->export_graph($graph, $filename, $options);
    if ($result < 0) {
	gui_dialog_error("Export error [".$filter->get_error()."]");
	return -1;
    }
    
    return 0;
}

# -----[ gui_menu_filter_export ]------------------------------------
# Export a graph. In interactive mode, no filename needs to be
# specified (the GUI will ask the user to provide one). In
# command-line mode, the filename must be specified. In this case, the
# export filter that will be used will be based on the filename
# extension (unless the option --format is provided).
#
# Parameters:
# - capabilities (EXPORT_SINGLE or EXPORT_MULTIPLE)
# - filename [optional]
# - options [optional] (hash reference)
#
# Return value:
#   0   on success
#   -1  in case of error
# -------------------------------------------------------------------
sub gui_menu_filter_export($;$$)
{
    my ($capabilities, $filename, $options)= @_;
    my $graph;

    if ($capabilities == IGen::FilterBase::EXPORT_SINGLE) {
	$graph= db_graph_get_current_as();
    } elsif ($capabilities == IGen::FilterBase::EXPORT_MULTIPLE) {
	$graph= $db_graph;
    }
    if (!defined($graph)) {
	gui_dialog_error("no graph to export");
	return -1;
    }

    if (!defined($filename)) {
	# ---| Build list of export filters |---
	my $filetypes= igen_filters_get_filetypes($capabilities);
	(!defined($filetypes)) and return -1;
	
	# ---| Open file save dialog |---
	$filename= $GUI{Main}->getSaveFile(-filetypes=>$filetypes,
					   -defaultextension=>'.gml');
    }
    (!defined($filename)) and return 0;

    # ---| Export |---
    return igen_filter_export($filename, $graph, $options);
}

# -----[ gui_menu_filter_import ]------------------------------------
#
# -------------------------------------------------------------------
sub gui_menu_filter_import(;$$)
{
    my ($filename, $domain_id)= @_;

    # ---| Open file window |---
    if (!defined($filename)) {
	my $filetypes=
	    igen_filters_get_filetypes(IGen::FilterBase::IMPORT_SINGLE,
				       IGen::FilterBase::IMPORT_MULTIPLE);
	(!defined($filetypes)) and return undef;
	$filename= $GUI{Main}->getOpenFile(-filetypes=>$filetypes);
    }
    (!defined($filename)) and return undef;

    select_router(undef, undef);
    select_domain(undef);

    # ---| Import graph(s) |---
    my $result= igen_filter_import($filename, $domain_id);
    ($result < 0) and return -1;

    # ---| select newly added graph & replot |---
    select_router(undef, undef);
    select_domain('any');
    gui_plot_graph($db_graph);

    return 0;
}


#####################################################################
#
# GUI Actions
#
#####################################################################

# -----[ gui_dialog_error ]------------------------------------------
#
# -------------------------------------------------------------------
sub gui_dialog_error($)
{
    my ($msg)= @_;
    
    if (exists($GUI{Main})) {
	$GUI{Main}->messageBox(-message=>$msg,
			-title=>'Error',
			-default=>'OK');
    } else {
	print STDERR "Error: \033[1;31m$msg\033[0m\n";
    }
}

# -----[ gui_dialog_input ]------------------------------------------
#
# -------------------------------------------------------------------
sub gui_dialog_input($$;$)
{
    my ($title, $label, $value)= @_;

    return IGen::DialogInput::run(-parent=>$GUI{Main},
				  -title=>$title,
				  -label=>$label,
				  -value=>$value);
}

# -----[ gui_dialog_progress ]---------------------------------------
#
# -------------------------------------------------------------------
sub gui_dialog_progress($$$)
{
    my ($title, $label, $status_ref)= @_;

    my $dialog= IGen::DialogMessage->new(-parent=>$GUI{Main});
    $dialog->show();
    return $dialog;
}

# -----[ gui_menu_close ]--------------------------------------------
#
# -------------------------------------------------------------------
sub gui_menu_close()
{
    db_graph_clear();
}

# -----[ gui_menu_gen_random_vertices ]------------------------------
#
# -------------------------------------------------------------------
sub gui_menu_gen_random_vertices(;@)
{
    my ($num_vertices, $continents)= @_;
    my $domain= undef;
    my $continent= 'all';
    if (!defined($num_vertices)) {
	my $dialog= IGen::DialogRouters->new(-parent=>$GUI{Main},
					     -domain=>db_graph_get_as_id(),
					     -continents=>\%igen_continents);
	my $result= $dialog->show_modal();
	$dialog->destroy();
	return -1 if (!defined($result));
	$domain= $result->[0];
	$num_vertices= $result->[1];
	$continents= $result->[2];
	$continent= $result->[3];
    }
    
    db_graph_add(graph_gen_random_vertices($num_vertices, $continents,
    $continent), $domain);

    #db_graph_add(graph_gen_ht_vertices($num_vertices), $domain);

    # ---| select newly added graph & replot |---
    select_router(undef, undef);
    select_domain('any');
    gui_plot_graph($db_graph);


    gui_terminal_update("generate-random [$num_vertices,continents=$continents]\n");

    return 0;
}

# -----[ gui_menu_export_brite ]-------------------------------------
#
# -------------------------------------------------------------------
sub gui_menu_export_brite()
{
    my $filename= 'test.brite';
    my $graph= db_graph_get_current_as();
    (!defined($graph)) and return -1;
    my $filter= IGen::FilterBRITE->new();
    my $result= $filter->export_graph($graph, $filename);
    return $result;
}

# -----[ gui_menu_export_cbgp ]--------------------------------------
#
# -------------------------------------------------------------------
sub gui_menu_export_cbgp()
{
    my $dialog= IGen::DialogExportCBGP->new(-parent=>$GUI{Main});
    my $result= $dialog->show_modal();
    $dialog->destroy();
    (!defined($result)) and return;
    gui_terminal_update("export-cbgp [$result->{filename}]\n");
    my $filter= IGen::FilterCBGP->new();
    $filter->export_graphs($db_graph, $result->{filename});
#		$result->{igp_model},
#		$result->{ibgp_method},
#		$result->{ibgp_nhself});
}

# -----[ gui_menu_export_gml ]---------------------------------------
#
# -------------------------------------------------------------------
sub gui_menu_export_gml()
{
    my $graph= db_graph_get_current_as();
    (!defined($graph)) and return;
    my $filename= $GUI{Main}->getSaveFile();
    return if (!defined($filename));
    gui_terminal_update("export-gml [$filename]\n");
    my $filter= IGen::FilterGML->new();
    $filter->export_graph($graph, $filename);
}

# -----[ gui_menu_export_pops ]--------------------------------------
#
# -------------------------------------------------------------------
sub gui_menu_export_pops()
{
    my $filename= $GUI{Main}->getSaveFile();
    return if (!defined($filename));
    gui_terminal_update("export-pops [$filename]\n");
    my $filter= IGen::FilterPOPS->new();
    my @graphs= values %{$db_graph->{as2graph}};
    $filter->export_graphs(\@graphs, $filename);
}

# -----[ gui_menu_export_ps ]----------------------------------------
#
# -------------------------------------------------------------------
sub gui_menu_export_ps()
{
    my $filename= $GUI{Main}->getSaveFile(-filetypes=>[
						       ['Postscript files', '.ps']
						       ]);
    return if (!defined($filename));
    gui_terminal_update("export-ps [$filename]\n");
    export2ps($filename);
}

# -----[ gui_menu_export_svg ]---------------------------------------
#
# -------------------------------------------------------------------
sub gui_menu_export_svg()
{
    my $graph= db_graph_get_current_as();
    (!defined($graph)) and return -1;
    my $filename= $GUI{Main}->getSaveFile(-filetypes=>[
						       ['SVG files', '.svg']
						       ]);
    (!defined($filename)) and return -1;
    gui_terminal_update("export-svg [$filename]\n");
    export2svg($graph, $filename);
    return 0;
}

# -----[ gui_menu_export_xml ]---------------------------------------
#
# -------------------------------------------------------------------
sub gui_menu_export_xml()
{
    my $graph= db_graph_get_current_as();
    (!defined($graph)) and return;
    my $filename= $GUI{Main}->getSaveFile();
    return if (!defined($filename));
    gui_terminal_update("export-totem-xml [$filename]\n");
    my $filter= IGen::FilterTOTEM->new();
    return $filter->export($graph, $filename);
}

# -----[ gui_menu_build_intra ]--------------------------------------
#
# -------------------------------------------------------------------
sub gui_menu_build_intra()
{
    my $graph= db_graph_get_current_as();
    (!defined($graph)) and return;

    my $dialog= IGen::DialogNetwork->new(-parent=>$GUI{Main},
					 -domain=>$current_as);
    my $result= $dialog->show_modal();
    $dialog->destroy();
    (!defined($result)) and return;

    my $network= graph_build_network($graph,
				     $result->{cluster},
				     $result->{bb},
				     $result->{pop},
				     $result->{igp},
				     $result->{capacity});
    (!defined($network)) and return -1;
    db_graph_set_current_as($network);
    gui_menu_view_redraw();

    return 0;
}

# -----[ gui_menu_build_mesh ]---------------------------------------
#
# -------------------------------------------------------------------
sub gui_menu_build_mesh()
{
    my $graph= db_graph_get_current_as();
    (!defined($graph)) and return;

    my $dialog= IGen::DialogGraph->new(-parent=>$GUI{Main});
    my $result= $dialog->show_modal();
    $dialog->destroy();
    (!defined($result)) and return;

    my $mesh_spec= $result->{method}.':'.(join ':', @{$result->{params}});
    my $mesh= graph_build_mesh($graph, $mesh_spec);
    (!defined($mesh)) and return -1;
    graph_clear_edges($graph);
    graph_add_subgraph($graph, $mesh);
    gui_menu_view_redraw();

    return 0;
}

# -----[ gui_menu_build_delaunay ]-----------------------------------
#
# -------------------------------------------------------------------
sub gui_menu_build_delaunay()
{
    my $graph= db_graph_get_current_as();
    (!defined($graph)) and return;
    my $delaunay= graph_delaunay($graph);
    db_graph_set_current_as($delaunay);
    gui_menu_view_redraw();
    gui_terminal_update("build-delaunay\n");
}

# -----[ gui_menu_build_clique ]-------------------------------------
#
# -------------------------------------------------------------------
sub gui_menu_build_clique()
{
    my $graph= db_graph_get_current_as();
    (!defined($graph)) and return;
    my $clique= UCL::Graph::Generate::clique($graph);
    db_graph_set_current_as($clique);
    gui_menu_view_redraw();
    gui_terminal_update("build-clique\n");
}

# -----[ gui_menu_build_node_linking ]-------------------------------
#
# -------------------------------------------------------------------
sub gui_menu_build_node_linking()
{
    my $graph= db_graph_get_current_as();
    (!defined($graph)) and return;
    my $nl= UCL::Graph::Generate::node_linking($graph);
    graph_copy_attributes($nl, $graph);
    db_graph_set_current_as($nl);
    gui_menu_view_redraw();
    gui_terminal_update("build-node-linking\n");
}

# -----[ gui_menu_build_harary ]-------------------------------------
#
# -------------------------------------------------------------------
sub gui_menu_build_harary()
{
    my $graph= db_graph_get_current_as();
    (!defined($graph)) and return;
    my $k= gui_dialog_input("Generate Harary graph", "K", 2);
    return if (!defined($k));
    my $harary= UCL::Graph::Generate::harary($graph, $k);
    graph_copy_attributes($harary, $graph);
    db_graph_set_current_as($harary);
    gui_menu_view_redraw();
    gui_terminal_update("build-harary [k=$k]\n");
}

# -----[ graph_mst ]----------------------------------------
#
# -------------------------------------------------------------------
sub graph_mst($)
{
    my ($graph)= @_;
    my $clique= UCL::Graph::Generate::clique($graph, 1);
    my $mst= $clique->MST_Kruskal();
    graph_copy_attributes($mst, $clique);
    return $mst;
}

# -----[ gui_menu_build_spt ]----------------------------------------
#
# -------------------------------------------------------------------
sub gui_menu_build_spt()
{
    my $graph= db_graph_get_current_as();
    (!defined($graph)) and return;
    my $root= graph_centroid($graph);
    my $clique= UCL::Graph::Generate::clique($graph, 1);
    my $spt= $clique->SSSP_Dijkstra($root);
    graph_copy_attributes($spt, $clique);
    db_graph_set_current_as($spt);
    gui_menu_view_redraw();
    gui_terminal_update("build-spt\n");
}

# -----[ gui_menu_build_tsp ]----------------------------------------
#
# -------------------------------------------------------------------
sub gui_menu_build_tsp()
{
    my $graph= db_graph_get_current_as();
    (!defined($graph)) and return;
    my $dialog= IGen::DialogGraph->new(-parent=>$GUI{Main},
				       -method=>'tsp:0');
    my $result= $dialog->show_modal();
    $dialog->destroy();
    (!defined($result)) and return;
    my $tsp;
    if ($result->{params}[0] == 0) {
	$tsp= graph_TSP_nn($graph);
    } else {
	$tsp= graph_TSP_fn($graph);
    }
    graph_copy_attributes($tsp, $graph);
    db_graph_set_current_as($tsp);
    gui_menu_view_redraw();
    gui_terminal_update("build-tsp [$result->{params}[0]]\n");
}

# -----[ gui_menu_build_mentor ]-------------------------------------
#
# -------------------------------------------------------------------
sub gui_menu_build_mentor()
{    
    my $graph= db_graph_get_current_as();
    (!defined($graph)) and return;
    my $dialog= IGen::DialogGraphMentor->new(-parent=>$GUI{Main});
    my $result= $dialog->show_modal();
    (defined($result)) or return;
    my $alpha= $result->[0];
    my $mentor= graph_MENTOR($graph, $alpha);
    graph_copy_attributes($mentor, $graph);
    db_graph_set_current_as($mentor);
    gui_menu_view_redraw();
    gui_terminal_update("build-mentor [alpha=$alpha]\n");
}

# -----[ gui_menu_build_mentour ]------------------------------------
#
# -------------------------------------------------------------------
sub gui_menu_build_mentour()
{
    my $graph= db_graph_get_current_as();
    (!defined($graph)) and return;
    my $result= gui_dialog_mentour();
    (!defined($result)) and return;
    my $mentour= graph_MENTour($graph,
			       $result->[0],
			       $result->[1],
			       MENTOUR_TSP_FN,
			       $result->[2]);
    graph_copy_attributes($mentour, $graph);
    db_graph_set_current_as($mentour);
    gui_menu_view_redraw();
    gui_terminal_update("build-mentour [alpha=$result->[0],tsp-fn,k-medoids($result->[1])]\n");
}

# -----[ gui_menu_build_two_trees ]------------------------------------
#
# -------------------------------------------------------------------
sub gui_menu_build_two_trees()
{
    my $graph= db_graph_get_current_as();
    (!defined($graph)) and return;
    my $two_trees= graph_two_trees($graph);
    db_graph_set_current_as($two_trees);
    gui_menu_view_redraw();
    gui_terminal_update("build-two-trees\n");
}

# -----[ gui_menu_build_multitours ]---------------------------------
#
# -------------------------------------------------------------------
sub gui_menu_build_multitours()
{
    my $graph= db_graph_get_current_as();
    (!defined($graph)) and return;
    my $dialog= IGen::DialogGraphMT->new(-parent=>$GUI{Main});
    my $result= $dialog->show_modal();
    $dialog->destroy();
    (!defined($result)) and return;
    my $multi_tour= graph_multitours($graph, $result->[0], $result->[1], $result->[2]);
    graph_copy_attributes($multi_tour, $graph);
    db_graph_set_current_as($multi_tour);
    gui_menu_view_redraw();
    gui_terminal_update("build-multi-tours [m=$result->[0],v=$result->[1],$result->[2]]\n");
}

# -----[ gui_menu_build_star_ring ]----------------------------------
#
# -------------------------------------------------------------------
sub gui_menu_build_star_ring()
{
    my $graph= db_graph_get_current_as();
    (!defined($graph)) and return;
    my $num_stars= gui_dialog_input("Build Star-Ring", "Number of stars", $graph->vertices/5);
    return if (!defined($num_stars));
    my $star_ring= graph_gen_star_ring($graph, $num_stars);
    graph_copy_attributes($star_ring, $graph);
    db_graph_set_current_as($star_ring);
    gui_menu_view_redraw();
    gui_terminal_update("build-star-ring [m=$num_stars]\n");
}

# -----[ gui_menu_build_barabasi_albert ]----------------------------
#
# -------------------------------------------------------------------
sub gui_menu_build_barabasi_albert()
{
    if (defined($current_as) &&
	exists($db_graph->{as2graph}->{$current_as})) {
	my $graph= $db_graph->{as2graph}->{$current_as};
	my $m= gui_dialog_input("Build Barabasi-Albert", "m", 2);
	return if (!defined($m));
	my $barabasi= graph_gen_BA($graph, $m);
	graph_copy_attributes($barabasi, $graph);
	$db_graph->{as2graph}->{$current_as}= $barabasi;
	gui_menu_view_redraw();
	gui_terminal_update("build-barabasi-albert [m=$m]\n");
    } else {
	gui_dialog_error('No domain has been selected.');
    }
}

# -----[ gui_menu_intra_clear ]--------------------------------------
#
# -------------------------------------------------------------------
sub gui_menu_intra_clear()
{
    my $graph= db_graph_get_current_as();
    (!defined($graph)) and return;
    graph_clear_edges($graph);
    gui_menu_view_redraw();
    gui_terminal_update("intradomain-clear\n");
}

# -----[ gui_menu_igp ]----------------------------------------------
#
# -------------------------------------------------------------------
sub gui_menu_igp()
{
    my $graph= db_graph_get_current_as();
    (!defined($graph)) and return;

    my $dialog= IGen::DialogIGP->new(-parent=>$GUI{Main});
    my $result= $dialog->show_modal();
    $dialog->destroy();
    (defined($result)) or return -1;
    my $spec= $result->{method}.':'.(join ':', @{$result->{params}});

    return graph_assign_weights($graph, $spec);
}

# -----[ gui_menu_inter_clear ]--------------------------------------
#
# -------------------------------------------------------------------
sub gui_menu_inter_clear()
{
    graphs_clear();
    gui_menu_view_redraw();
}

# -----[ gui_menu_build_internet ]-----------------------------------
# Parameters:
# - file containing AS relationships
# - number of links used to connect two ASes (0 = auto,
#   i.e. proportional to the sizes of the ASes to be connected)
# -------------------------------------------------------------------
sub gui_menu_build_internet(;@)
{
    my ($as_relations_file, $num_links)= @_;
    my $as_relations= undef;
    if (!defined($as_relations_file)) {
	# ---| Use GUI to ask for parameters |---
	my $dialog= new IGen::DialogInternet(-parent=>$GUI{Main});
	my $result= $dialog->show_modal();
	$dialog->destroy();
	(!defined($result)) and
	    return 0;
	if ($result->{as_relations_source} eq 'file') {
	    $as_relations_file= $result->{as_relations_file};
	} else {
	    $as_relations= $result->{as_relations};
	}
	$num_links= $result->{num_links};
    }

    if (defined($as_relations_file)) {
	# ---| Load AS relationships |---
	my $filter= new IGen::FilterASRelations();
	$as_relations= $filter->import_graph($as_relations_file);
	if (!defined($as_relations)) {
	    gui_dialog_error($filter->get_error());
	    return -1;
	}

    }

    if (graphs_build_internet($db_graph->{as2graph},
			      $as_relations,
			      $num_links) < 0) {
	return -1;
    }
    gui_menu_view_redraw();
    return 0;
}

# -----[ graphs_clear ]----------------------------------------------
#
# -------------------------------------------------------------------
sub graphs_clear()
{
    $db_graph->{igraph}= new Graph::Undirected();
}

# -----[ gui_menu_inter_connect ]------------------------------------
#
# -------------------------------------------------------------------
sub gui_menu_inter_connect()
{
    my $dialog=
	IGen::DialogInterConnect->new(-parent=>$GUI{Main},
				      -as2graph=>$db_graph->{as2graph});
    my $result= $dialog->show_modal();
    $dialog->destroy();
    (!defined($result)) and return -1;

    my $graphA= $db_graph->{as2graph}->{$result->{domainA}};
    my $graphB= $db_graph->{as2graph}->{$result->{domainB}};

    $result= graphs_connect_two_domains($db_graph->{igraph},
					$graphA,
					$graphB,
					$result->{relation},
					$result->{num_links});
    gui_menu_view_redraw();
    return $result;
}

# -----[ gui_menu_zoom_in ]------------------------------------------
#
# -------------------------------------------------------------------
sub gui_menu_zoom_in()
{
    $global_plot_params->{zoom_factor}= $global_plot_params->{zoom_factor}*2;
    gui_menu_view_redraw();
}

# -----[ gui_menu_zoom_out ]-----------------------------------------
#
# -------------------------------------------------------------------
sub gui_menu_zoom_out()
{
    if ($global_plot_params->{zoom_factor} > 1) {
	$global_plot_params->{zoom_factor}= $global_plot_params->{zoom_factor}/2;
	gui_menu_view_redraw();
    }
}

# -----[ gui_menu_zoom_default ]-------------------------------------
#
# -------------------------------------------------------------------
sub gui_menu_zoom_default()
{
    $global_plot_params->{zoom_factor}= 1;
    $global_plot_params->{xscroll}= 0;
    $global_plot_params->{yscroll}= 0;
    gui_menu_view_redraw();
}

# -----[ gui_menu_zoom_domain ]--------------------------------------
#
# -------------------------------------------------------------------
sub gui_menu_zoom_domain()
{
    my $graph= db_graph_get_current_as();
    (!defined($graph)) and return;
    my ($min_x, $min_y, $max_x, $max_y)=
	UCL::Graph::Base::bounds($graph);
    $global_plot_params->{zoom_factor}= XBOUND/($max_x-$min_x)/1.1;
    if ($global_plot_params->{zoom_factor} > YBOUND/($max_y-$min_y)/1.1) {
	$global_plot_params->{zoom_factor}= YBOUND/($max_y-$min_y)/1.1;
    }
    $global_plot_params->{xscroll}= ((XOFFSET)-$min_x+($max_x-$min_x)*0.05);
    $global_plot_params->{yscroll}= (YOFFSET)+$max_y+($max_y-$min_y)*0.05;
    gui_menu_view_redraw();
}

# -----[ gui_menu_filter_zone ]--------------------------------------
#
# -------------------------------------------------------------------
sub gui_menu_filter_zone()
{
    my $dialog= IGen::DialogContinent->new(-parent=>$GUI{Main},
					   -continents=>\%igen_continents);
    my $result= $dialog->show_modal();
    $dialog->destroy();
    my $graph= db_graph_get_current_as();
    (!defined($graph)) and return -1;
    my @vertices= $graph->vertices();
    foreach my $v (@vertices) {
	my $coord= $graph->get_attribute(UCL::Graph::ATTR_COORD, $v);
	if (pt_in_poly($coord,
		       $igen_continents{$result->[0]}) <= 0) {
	    $graph->delete_vertex($v);
	}
    }
    gui_menu_view_redraw();
    return 0;
}

# -----[ gui_menu_filter_access ]------------------------------------
#
# -------------------------------------------------------------------
sub gui_menu_filter_access()
{
    my $graph= db_graph_get_current_as();
    (!defined($graph)) and return -1;
    my @vertices= $graph->vertices();
    foreach my $v (@vertices) {
	my $type= 'backbone';
	if ($graph->has_attribute(UCL::Graph::ATTR_TYPE, $v)) {
	    $type= $graph->get_attribute(UCL::Graph::ATTR_TYPE, $v);
	}
	if ($type ne 'backbone') {
	    $graph->delete_vertex($v);
	}
    }
    gui_menu_view_redraw();
    return 0;
}

# -----[ gui_menu_filter_domain ]------------------------------------
#
# -------------------------------------------------------------------
sub gui_menu_filter_domain()
{
    gui_dialog_error('Not yet implemented. Sorry.');
}

# -----[ gui_menu_view_redraw ]--------------------------------------
#
# -------------------------------------------------------------------
sub gui_menu_view_redraw()
{
    gui_plot_graph($db_graph);
}

# -----[ gui_menu_about ]--------------------------------------------
#
# -------------------------------------------------------------------
sub gui_menu_about()
{
    my $dialog= IGen::DialogAbout->new(-parent=>$GUI{Main});
    $dialog->show_modal();
    $dialog->destroy();
}

# -----[ gui_menu_measure ]------------------------------------------
# This function runs a measure on the current graph.
# -------------------------------------------------------------------
sub gui_menu_measure()
{
    my $graph= db_graph_get_current_as();
    (!defined($graph)) and return -1;

    my $dialog= IGen::DialogMeasure->new(-parent=>$GUI{Main},
					 -methods=>\%igen_measure_methods);
    my $result= $dialog->show_modal();
    $dialog->destroy();

    if (defined($result)) {
	foreach my $method (keys %$result) {
	    if ($result->{$method} == 1) {
		if (graph_measure($graph, $method)) {
		    return -1;
		}
	    }
	}
    }

    return 0;
}

# -----[ gui_measure_total_weight ]----------------------------------
# This function measures the total weight of the graph.
# -------------------------------------------------------------------
sub gui_measure_total_weight()
{
    my $graph= db_graph_get_current_as();
    (!defined($graph)) and return -1;
    my $total_weight= UCL::Graph::Measure::total_weight($graph);
    gui_terminal_update("total-weight: $total_weight\n");
    
    return 0;
}

# -----[ gui_measure_node_degree ]-----------------------------------
# This functions measures the node degree distribution of the
# graph.
# -------------------------------------------------------------------
sub gui_measure_node_degree()
{
    my ($spec_fields, %spec_args)= @_;
    my $graph= db_graph_get_current_as();
    (!defined($graph)) and return -1;

    my $degrees= UCL::Graph::Measure::degrees($graph);
    my $stat= new Statistics::Descriptive::Full();
    $stat->add_data($degrees);
    my @bins= ();
    for (my $i= 0; $i <= $stat->max(); $i++) { push @bins, ($i); }
    $stat->frequency_distribution(\@bins);
    $spec_args{-plottitle}= 'Node degree';
    $spec_args{-xlabel}= 'Degrees';
    if (exists($spec_args{-cumulative}) && $spec_args{-cumulative}) {
	$spec_args{-ylabel}= 'Fraction of nodes (%)';
    } else {
	$spec_args{-ylabel}= 'Number of nodes';
    }
    $spec_args{-binmean}= 0;
    gui_show_statistics($stat, %spec_args);
    return 0;
}

# -----[ gui_measure_path_length ]-----------------------------------
# This function measures the shortest path length distribution of the
# graph.
#
# TODO: define bin-size / number of bins
# -------------------------------------------------------------------
sub gui_measure_path_length()
{
    my ($spec_fields, %spec_args)= @_;
    my $graph= db_graph_get_current_as();
    (!defined($graph)) and return -1;
    my ($stat, $stat_hops, $stat_weights)=
	graph_paths_lengths($graph);
    if (exists($spec_args{-binsize})) {
	my @bins= ();
	my $binsize= $spec_args{-binsize};
	for (my $i= 0; $i*$binsize <= $stat->max(); $i++) {
	    push @bins, ($i*$binsize);
	}
	$stat->frequency_distribution(\@bins);
    } else {
	$stat->frequency_distribution($stat->max());
    }
    $spec_args{-plottitle}= 'Path length';
    $spec_args{-xlabel}= 'Lengths';
    if (exists($spec_args{-cumulative}) && $spec_args{-cumulative}) {
	$spec_args{-ylabel}= 'Fraction of paths (%)';
    } else {
	$spec_args{-ylabel}= 'Number of paths';
    }
    gui_show_statistics($stat, %spec_args);
    return 0;
}

# -----[ gui_measure_path_weights ]----------------------------------
# This function measures the path weight distribution of the graph.
#
# TODO: define bin-size / number of bins
# -------------------------------------------------------------------
sub gui_measure_path_weights()
{
    my ($spec_fields, %spec_args)= @_;
    my $graph= db_graph_get_current_as();
    (!defined($graph)) and return -1;
    my ($stats_lengths, $stats_hops, $stats_weights)=
	graph_paths_lengths($graph);
    $stats_weights->frequency_distribution($stats_weights->max());
    $spec_args{-plottitle}= 'Paths weights';
    $spec_args{-xlabel}= 'Weights';
    if (exists($spec_args{-cumulative}) && $spec_args{-cumulative}) {
	$spec_args{-ylabel}= 'Fraction of paths (%)';
    } else {
	$spec_args{-ylabel}= 'Number of paths';
    }
    gui_show_statistics($stats_weights, %spec_args);
    return 0;
}

# -----[ gui_measure_hop_count ]-------------------------------------
# This function measures the path hop-count distribution of the given
# graph.
# -------------------------------------------------------------------
sub gui_measure_hop_count()
{
    my ($spec_fields, %spec_args)= @_;
    my $graph= db_graph_get_current_as();
    (!defined($graph)) and return -1;

    my ($stats_lenghts, $stat)= graph_paths_lengths($graph);
    my @bins= ();
    for (my $i= 0; $i <= $stat->max(); $i++) { push @bins, ($i); }
    $stat->frequency_distribution(\@bins);
    $spec_args{-plottitle}= 'Paths hop counts';
    $spec_args{-xlabel}= 'Hop counts';
    if (exists($spec_args{-cumulative}) && $spec_args{-cumulative}) {
	$spec_args{-ylabel}= 'Fraction of hop counts (%)';
    } else {
	$spec_args{-ylabel}= 'Number of hops';
    }
    gui_show_statistics($stat, %spec_args);
    return 0;
}

# -----[ gui_measure_path_diversity ]--------------------------------
#
# -------------------------------------------------------------------
sub gui_measure_path_diversity()
{
    my ($spec_fields, %spec_args)= @_;
    my $graph= db_graph_get_current_as();
    (!defined($graph)) and return -1;
    my $stat= graph_path_diversity($graph);
    my @bins= ();
    for (my $i= 0; $i <= $stat->max(); $i++) { push @bins, ($i); }
    $stat->frequency_distribution(\@bins);
    $spec_args{-plottitle}= 'Path diversity';
    $spec_args{-xlabel}= 'Number of disjoint paths';
    if (exists($spec_args{-relative}) && $spec_args{-relative}) {
	$spec_args{-ylabel}= 'Fraction of pairs (%)';
    } else {
	$spec_args{-ylabel}= 'Number of pairs';
    }
    $spec_args{-binmean}= 0;
    gui_show_statistics($stat, %spec_args);
    return 0;
}

# -----[ gui_measure_edge_connectivity ]-----------------------------
# This function measures the k-edge-connectivity of the given graph.
# -------------------------------------------------------------------
sub gui_measure_edge_connectivity()
{
    my $graph= db_graph_get_current_as();
    (!defined($graph)) and return -1;
    my $edge_connectivity=
	UCL::Graph::Measure::min_cut($graph);
    gui_terminal_update("edge-connectivity: $edge_connectivity\n");
    return 0;
}

# -----[ gui_measure_link_utilization ]------------------------------
#
# -------------------------------------------------------------------
sub gui_measure_link_utilization()
{
    my $graph= db_graph_get_current_as();
    (!defined($graph)) and return -1;
    if (!$graph->has_attribute(UCL::Graph::ATTR_TM)) {
	gui_dialog_error("no traffic matrix");
	return -1;
    }
    my $TM= $graph->get_attribute(UCL::Graph::ATTR_TM);
    my $RM= graph_APSP($graph, $global_options->{ecmp},
		       \&graph_dst_fct_weight);
    $graph->set_attribute(UCL::Graph::ATTR_RM, $RM);
    my $links_util= graph_link_utilization($graph);

    gui_terminal_update("link-utilization:\n");

    my @links_util= ();
    my @links_load= ();
    my @edges= $graph->edges();
    for (my $i= 0; $i < @edges/2; $i++) {
	my $u= $edges[$i*2];
	my $v= $edges[$i*2+1];
	my $util= 0;
	if (exists($links_util->{$u}{$v})) {
	    $util= $links_util->{$u}{$v};
	}
	if (!$graph->directed()) {
	    if (exists($links_util->{$v}{$u})) {
		$util+= $links_util->{$v}{$u};
	    }
	}
	$graph->set_attribute(UCL::Graph::ATTR_UTIL, $u, $v, $util);
	my $load= 0;
	if ($util > 0) {
	    if (!$graph->has_attribute(UCL::Graph::ATTR_CAPACITY, $u, $v)) {
		gui_dialog_error("No capacity on link $u-$v");
		return -1;
	    }
	    my $capacity= $graph->get_attribute(UCL::Graph::ATTR_CAPACITY, $u, $v);
	    if ($capacity == 0) {
		gui_dialog_error("Capacity is 0 on link $u-$v and util is $util");
		return -1;
	    }
	    $load= ($util*100)/$capacity;
	}
	$graph->set_attribute(UCL::Graph::ATTR_LOAD, $u, $v, $load);
	
	push @links_util, ($util);
	push @links_load, ($load);
    }

    my $stat= new Statistics::Descriptive::Full();
    $stat->add_data(\@links_util);
    gui_show_statistics($stat,
			-plottitle=>'Link utilization',
			-xlabel=>'Utilization',
			-ylabel=>'Fraction of links');
    gui_menu_view_redraw();

    return 0;
}

# -----[ gui_measure_throughput ]------------------------------------
#
# -------------------------------------------------------------------
sub gui_measure_throughput()
{
    my $graph= db_graph_get_current_as();
    (!defined($graph)) and return -1;

    my @edges= $graph->edges();
    my $max_load= undef;
    my $min_capacity= undef;
    my $blocking_link= undef;
    for (my $i= 0; $i < @edges/2; $i++) {
	my $u= $edges[$i*2];
	my $v= $edges[$i*2+1];
	if ($graph->has_attribute(UCL::Graph::ATTR_LOAD, $u, $v)) {
	    my $load= $graph->get_attribute(UCL::Graph::ATTR_LOAD, $u, $v);
	    my $capacity= $graph->get_attribute(UCL::Graph::ATTR_CAPACITY, $u, $v);
	    if ($load > $max_load) {
		$max_load= $load;
		$min_capacity= $capacity;
		$blocking_link= "$u->$v";
	    } elsif ($load == $max_load) {
		if (!defined($min_capacity) || ($capacity < $min_capacity)) {
		    $min_capacity= $capacity;
		    $blocking_link= "$u->$v";
		}
	    }
	}
    }

    gui_terminal_update("maximum-throughput:\n");
    if (!defined($max_load)) {
	gui_terminal_add("warning: no link is loaded.");
	return 0;
    }
    if ($max_load > 0) {
	gui_terminal_add("\tmax-load    : ".$max_load."\n");
	gui_terminal_add("\tmin-capacity: ".capacity2text($min_capacity).
			 " (link $blocking_link)\n");
	gui_terminal_add("\tscaling     : ".(100/$max_load)."\n");

	for (my $i= 0; $i < @edges/2; $i++) {
	    my $u= $edges[$i*2];
	    my $v= $edges[$i*2+1];
	    my $load= $graph->get_attribute(UCL::Graph::ATTR_LOAD, $u, $v);
	    $graph->set_attribute(UCL::Graph::ATTR_LOAD, $u, $v, $load*(100/$max_load));
	    my $util= $graph->get_attribute(UCL::Graph::ATTR_UTIL, $u, $v);
	    $graph->set_attribute(UCL::Graph::ATTR_UTIL, $u, $v, $util*(100/$max_load));
	}

	gui_menu_view_redraw();
    } else {
	gui_terminal_add("warning: maximum load is 0");
    }

    return 0;
}

# -----[ gui_measure_fast_reroute ]----------------------------------
# This function show the results of the IP Fast-Reroute analysis. In
# verbose mode, shows how many links were protectable using 1 or 2
# LFA(s). And for links that were not potectable using LFA, how many
# could be protected using 1 or 2 U-Turns.
#
# Arguments:
#  spec-fields (mandatory fields)
#  spec-args (optional fields)
#
# Options: (to be given in %spec_args)
#   -verbose
# -------------------------------------------------------------------
sub gui_measure_fast_reroute(;$%)
{
    my ($spec_fields, %spec_args)= @_;
    my $graph= db_graph_get_current_as();
    (!defined($graph)) and return -1;
    my $frs= graph_fast_reroute($graph);
    my $msg;
    if (exists($spec_args{-verbose})) {
	$msg= "ip-fast-reroute:\n";
	$msg.= sprintf "unused links: ".$frs->[FAST_REROUTE_UNUSED]."\n";
	$msg.= sprintf "----------------+-----+-----+-----+\n";
	$msg.= sprintf "                |  0  |  1  |  2+ |\n";
	$msg.= sprintf "----------------+-----+-----+-----+\n";
	$msg.= sprintf "with LFA        | %3d | %3d | %3d |\n",
	($frs->[FAST_REROUTE_LFA][0],
	 $frs->[FAST_REROUTE_LFA][1],
	 $frs->[FAST_REROUTE_LFA][2]);
	$msg.= sprintf "with U-turn     | %3d | %3d | %3d |\n",
	($frs->[FAST_REROUTE_UTURN][0],
	 $frs->[FAST_REROUTE_UTURN][1],
	 $frs->[FAST_REROUTE_UTURN][2]);
	$msg.= sprintf "----------------+-----+-----+-----+\n";
    } else {
	$msg.= sprintf "%d\t%d\t%d\n",
	$frs->[FAST_REROUTE_LFA][1]+$frs->[FAST_REROUTE_LFA][2],
	$frs->[FAST_REROUTE_UTURN][1]+$frs->[FAST_REROUTE_UTURN][2],
	$frs->[FAST_REROUTE_UTURN][0];
    }
    gui_terminal_update($msg);

    return 0;
}

# -----[ gui_measure_vertex_distance ]-------------------------------
sub gui_measure_vertex_distance(;$%)
{
    my ($spec_fields, %spec_args)= @_;

    my $graph= db_graph_get_current_as();
    (!defined($graph)) and return -1;

    my $stats= graph_vertex_distance($graph);
    (!defined($stats)) and return -1;

    gui_show_statistics($stats,
			-plottitle=>'Distances',
			-xlabel=>'Distance (km)',
			-ylabel=>'Fraction of vertices pairs',
			%spec_args
			);
    return 0;
}

# -----[ plot_array ]------------------------------------------------
#
# -------------------------------------------------------------------
sub plot_array($;%)
{
    my ($array, %args)= @_;

    my @sorted_array= sort {$a->[1] <=> $b->[1]} @$array;
    $array= \@sorted_array;

    # ---| Dump distribution into temporary file |---
    my $tmp_filename= "/tmp/.ucl_stat_gnuplot";
    open(TMP, ">$tmp_filename") or
	die "could not create temporary file \"$tmp_filename\": $!";
    my @yvalue= ();
    for (my $index= 0; $index < @{$array}; $index++) {
#	print TMP "$index";
	for (my $column= 0; $column < @{$array->[$index]}; $column++) {
	    if (defined($args{-cumulative}) && $args{-cumulative}) {
		$yvalue[$column]+= $array->[$index]->[$column];
	    } else {
		$yvalue[$column]= $array->[$index]->[$column];
	    }
	    print TMP "\t".$yvalue[$column]."";
	}
	print TMP "\n";
    }
    close(TMP);

    # ---| Display plot of distribution |---
    open(GNUPLOT, "| gnuplot -persist") or
	die "could not pipe into gnuplot: $!";
    GNUPLOT->autoflush(1);
    if (defined($args{-filename})) {
	print GNUPLOT "set term postscript eps \"Helvetica\" 20\n";
	print GNUPLOT "set output \"".$args{-filename}."\"\n";
    }
#    print GNUPLOT "set yrange [0:*]\n";
#    print GNUPLOT "set xrange [0:*]\n";
    (defined($args{-xlabel})) and
	print GNUPLOT "set xlabel \"".$args{-xlabel}."\"\n";
    (defined($args{-ylabel})) and
	print GNUPLOT "set ylabel \"".$args{-ylabel}."\"\n";
    (defined($args{-grid})) and
	print GNUPLOT "set grid\n";
    (defined($args{-xlogscale})) and
	print GNUPLOT "set logscale x\n";
    (defined($args{-ylogscale})) and
	print GNUPLOT "set logscale y\n";

    my $options= '';
    (defined($args{-title})) and
	$options.= ' t "'.$args{-title}.'"';
    (defined($args{-style})) and
	$options.= ' w '.$args{-style};
#    print GNUPLOT "plot \"$tmp_filename\" u :2:3:4 $options\n";
    print GNUPLOT "plot \"$tmp_filename\" u 1:2 $options\n";
    close(GNUPLOT);
}

# -----[ gui_measure_adjacency_radius ]------------------------------
#
# -------------------------------------------------------------------
sub gui_measure_adjacency_radius()
{   my $graph= db_graph_get_current_as();
    (!defined($graph)) and return -1;

    my $stats= graph_adjacency_radius($graph);
    (!defined($stats)) and return -1;

    plot_array($stats,
	       -grid=>1,
	       -plottitle=>'Adjacency radius',
	       -xlabel=>'Routers',
	       -ylabel=>'Distance to other routers (km)');

    return 0;
}

# -----[ gui_menu_search_router ]------------------------------------
#
# -------------------------------------------------------------------
sub gui_menu_search_router()
{
    my $graph= db_graph_get_current_as();
    (!defined($graph)) and return;
    my $dialog= IGen::DialogSelectRouter->new(-parent=>$GUI{Main},
					      -graphs=>$db_graph);
    my $result= $dialog->show_modal();
    $dialog->destroy();
    (!defined($result)) and return -1;
    if (select_router($result->{router}, $result->{domain})) {
	gui_dialog_error("Router $result->{router} does not exist in domain $result->{domain}.");
	return -1;
    }
    return 0;
}

# -----[ gui_menu_search_domain ]------------------------------------
#
# -------------------------------------------------------------------
sub gui_menu_search_domain()
{
    my $domain= gui_dialog_input("Search domain...", "Domain:");
    return if (!defined($domain));
    if (defined($db_graph) &&
	exists($db_graph->{as2graph}->{$domain})) {
	select_domain($domain);
    } else {
	gui_dialog_error('Domain $domain does not exist.');
    }
}


#####################################################################
#
# CANVAS FUNCTIONS
#
#####################################################################

# -----[ select_domain ]---------------------------------------------
#
# -------------------------------------------------------------------
sub select_domain($)
{
    my ($domain)= @_;

    if (defined($db_graph)) {
	if ($domain eq 'any') {
 	    my @ases= keys(%{$db_graph->{as2graph}});
	    if (@ases > 0) {
		$current_as= $ases[0];
	    } else {
		$current_as= undef;
		return -1;
	    } 
	} else  {
	    if (exists($db_graph->{as2graph}->{$domain})) {
		$current_as= $domain;
	    } else {
		$current_as= undef;
		return -1;
	    }
	}
    } else {
	$current_as= undef;
	return -1;
    }
    return 0;
}

# -----[ select_router ]---------------------------------------------
#
# -------------------------------------------------------------------
sub select_router($$;$)
{
    my ($rt_id, $rt_as, $add)= @_;

    $current_router= $rt_id;
    gui_terminal_clear();

    if (defined($rt_id)) {
	if (select_domain($rt_as)) {
	    return -1;
	}
	if ($db_graph->{as2graph}->{$rt_as}->has_vertex($rt_id)) {
	    gui_show_router($rt_id, $db_graph->{as2graph}{$rt_as});
	} else {
	    return -1;
	}
    }
    return 0;
}

# -----[ select_link ]-----------------------------------------------
#
# -------------------------------------------------------------------
sub select_link($$$)
{
    my ($u, $v, $graph)= @_;

    # ---| Deselect router |---
    select_router(undef, $graph->get_attribute(UCL::Graph::ATTR_AS));

    $current_link= [$u, $v];
    gui_terminal_clear();

    gui_terminal_update(gui_show_link($u, $v, $graph));
    return 0;
}

# -----[ gui_show_router ]-------------------------------------------
sub gui_show_router($$)
{
    my ($u, $graph)= @_;
    my %attributes= ();

    # ---| Extract attributes |---
    if ($graph->has_attribute(UCL::Graph::ATTR_COORD, $u)) {
	my $coord= $graph->get_attribute(UCL::Graph::ATTR_COORD, $u);
	$attributes{'Coordinates'}=
	    sprintf "(%.2f, %.2f)", $coord->[0], $coord->[1];
    }
    ($graph->has_attribute(UCL::Graph::ATTR_NAME, $u)) and
	$attributes{'Name'}= $graph->get_attribute(UCL::Graph::ATTR_NAME, $u);
    ($graph->has_attribute(UCL::Graph::ATTR_TYPE, $u)) and
	$attributes{'Type'}= $graph->get_attribute(UCL::Graph::ATTR_TYPE, $u); 
    $attributes{'Domain'}= $graph->get_attribute(UCL::Graph::ATTR_AS, $u);
    $attributes{'Degree'}= scalar($graph->neighbors($u));

    # ---| Display attributes |---
    my $msg= "[ Router $u ]\n";
    foreach (sort keys %attributes) {
	$msg.= sprintf "  %-12s: %s\n", $_, $attributes{$_};
    }
    gui_terminal_update($msg);
}

# -----[ gui_show_link ]---------------------------------------------
#
# -------------------------------------------------------------------
sub gui_show_link($$$)
{
    my ($u, $v, $graph) = @_;
    my %attributes= ();

    # ---| Extract attributes |---
    $attributes{'Type'}= 'Internal';
    if ($graph->has_attribute(UCL::Graph::ATTR_RELATION, $u, $v)) {
	my $relation= $graph->get_attribute(UCL::Graph::ATTR_RELATION, $u, $v);
	$attributes{'Type'}= ILINK_RELATIONS->{$relation};
    }
    $attributes{'Distance'}=
	sprintf "%.2f", UCL::Graph::Base::distance($graph, $u, $v);
    $attributes{'Delay'}=
	sprintf "%.2f", 
	UCL::Graph::Base::distance2delay($attributes{'Distance'});
    ($graph->has_attribute(UCL::Graph::ATTR_WEIGHT, $u, $v)) and
	$attributes{'Weight'}=
	sprintf "%.2f", $graph->get_attribute(UCL::Graph::ATTR_WEIGHT, $u, $v);
    ($graph->has_attribute(UCL::Graph::ATTR_CAPACITY, $u, $v)) and
	$attributes{'Capacity'}=
	capacity2text($graph->get_attribute(UCL::Graph::ATTR_CAPACITY,
					    $u, $v));
    ($graph->has_attribute(UCL::Graph::ATTR_LOAD, $u, $v)) and
	$attributes{'Load'}=
	$graph->get_attribute(UCL::Graph::ATTR_LOAD, $u, $v);
    ($graph->has_attribute(UCL::Graph::ATTR_UTIL, $u, $v)) and
	$attributes{'Utilization'}=
	capacity2text($graph->get_attribute(UCL::Graph::ATTR_UTIL, $u, $v));

    # ---| Display attributes |---
    my $msg= "[ Link $u <-> $v ]\n";
    foreach (sort keys %attributes) {
	$msg.= sprintf "  %-12s: %s\n", $_, $attributes{$_};
    }
    gui_terminal_update($msg);

    return $msg;
}


#####################################################################
#
# EXPORT FUNCTIONS
#
#####################################################################

# -----[ export2ps ]-------------------------------------------------
#
# -------------------------------------------------------------------
sub export2ps($)
{
    my $filename= shift;

    $cCanvas->postscript(-file=>$filename,
			 -colormode=>'color');
}

# -----[ export2svg ]------------------------------------------------
# Export the loaded topology in SVG format.
# -------------------------------------------------------------------
sub export2svg($$)
{
    my $graph= shift;
    my $filename= shift;

    my $svg= SVG::new();

    my $wnode= 1;

    # Draw all the edges
    my @edges= $graph->edges();
    for (my $i= 0; $i < @edges/2; $i++) {
	my $u= $edges[$i*2];
	my $v= $edges[$i*2+1];

	$svg->{pencolor}= '#0000ff';
	#$svg->{pencolor}= '#ff0000';

	my $coord_u= $graph->get_attribute(UCL::Graph::ATTR_COORD, $u);
	my $coord_v= $graph->get_attribute(UCL::Graph::ATTR_COORD, $v);
	
	$svg->line($coord_u->[0], -$coord_u->[1],
		   $coord_v->[0], -$coord_v->[1]);

    }

    # Draw all the nodes
    foreach my $u ($graph->vertices()) {
	$svg->{pencolor}= '#000000';
	$svg->{fillcolor}= '#00ff00';

	# Draw a border router as a rectangle and an internal router
	# as an ellipse
	my $shape= 0;
	if ($graph->has_attribute(UCL::Graph::ATTR_TYPE, $u) &&
	    ($graph->get_attribute(UCL::Graph::ATTR_TYPE, $u) eq 'backbone')) {
	    $shape= 1;
	}

	my $coord= $graph->get_attribute(UCL::Graph::ATTR_COORD, $u);

	if ($shape == 1) {

	    my $x1= $coord->[0]-$wnode/2;
	    my $y1= $coord->[1]-$wnode/2;
	    my $x2= $coord->[0]+$wnode/2;
	    my $y2= $coord->[1]+$wnode/2;

	    $svg->rect($x1, -$y2, $x2, -$y1);

	} else {

	    my $x= $coord->[0];
	    my $y= $coord->[1];

	    $svg->ellipse($x, -$y, $wnode/2, $wnode/2);

	}

    }

    $svg->save($filename);
}

# -----[ id2str ]----------------------------------------------------
#
# -------------------------------------------------------------------
sub id2str($)
{
    my ($id)= @_;

    return ($id >> 8).'.'.($id & 255);
}

#####################################################################
#
# CLUSTERING FUNCTIONS
#
#####################################################################

# -----[ pts_sort ]--------------------------------------------------
# Compare two points lexicographically (two dimensions).
#
# Parameters:
# - $a and $b are references to two points, represented by couple of
#   two coordinates. The first element of the couple is the
#   x-coordinate and the second element is the y-coordinate.
# -------------------------------------------------------------------
sub pts_sort()
{
    ($a->[0] > $b->[0]) and return 1;
    ($a->[0] < $b->[0]) and return -1;
    ($a->[1] > $b->[1]) and return 1;
    ($a->[1] < $b->[1]) and return -1;
    return 0;
}

# -----[ right_turn ]------------------------------------------------
# Determines if by traversing the line segment P0P1 then P1P2 we make
# a right turn.
#
# Parameters:
# - reference to P0
# - reference to P1
# - reference to P2
# -------------------------------------------------------------------
sub right_turn($$$)
{
    my $p0_r= shift;
    my $p1_r= shift;
    my $p2_r= shift;

    # Compute the cross product (P1-P0) x (P2-P0).
    # Note: the cross product (A x B) is computed as (Ax.By - Ay.Bx)
    my $cp= ($p1_r->[0]-$p0_r->[0])*($p2_r->[1]-$p0_r->[1]) -
	($p1_r->[1]-$p0_r->[1])*($p2_r->[0]-$p0_r->[0]);

    # If the result is positive, it is right turn, otherwise it is a
    # left turn.
    return $cp;
}

# -----[ pt_in_poly ]------------------------------------------------
# Check if the point P is inside the given polygon. Winding number
# test method.
#
# Parameters:
# - reference to P (couple of coordinates)
# - reference to Polygon (array of couples of coordinates)
# -------------------------------------------------------------------
sub pt_in_poly($$)
{
    my $p_r= shift;
    my $poly_r= shift;
    my $wn= 0;

    # Define first node = last node (close the polygon)
    if ($poly_r->[scalar(@$poly_r)-1] != $poly_r->[0]) {
	$poly_r->[scalar(@$poly_r)]= $poly_r->[0];
    }

    # Loop through all edges of the polygon (edge [i,i+1])
    for (my $index= 0; $index < scalar(@$poly_r)-1; $index++) {

	# Start Y <= Point Y
	if ($poly_r->[$index]->[1] <= $p_r->[1]) {

	    # Upward crossing
	    if ($poly_r->[$index+1]->[1] > $p_r->[1]) {

		# Point is at left side of edge ?
		if (right_turn($poly_r->[$index],
			       $poly_r->[$index+1],
			       $p_r) > 0) {

		    $wn--;
		}
		
	    }
	    
	} else {

	    # Downward crossing
	    if ($poly_r->[$index+1]->[1] <= $p_r->[1]) {

		# Point is at right side of edge ?
		if (right_turn($poly_r->[$index],
			       $poly_r->[$index+1],
			       $p_r) < 0) {
		    $wn++;
		}
	    }
	    
	}
    }
    
    return $wn;
}

# -----[ convex_hull ]-----------------------------------------------
# Computes the convex hull of the given set of points in the plane
# (two dimensions).
#
# Preconditions:
# - There are no two points at the same coordinates
#
# Complexity: O(n.log(n)), where n is the number of points
#
# Parameters:
# - Reference to an array of points. Each point is a couple where the
#   first element is the x-coordinate and the second element is the
#   y-coordinate.
# -------------------------------------------------------------------
sub convex_hull($)
{
    my ($points_r)= @_;

    # Return undef if there is nothing in the set of points
    (scalar(@$points_r) < 1) and return undef;

    # Return a reference to a set with a single point if the given set
    # of points contains a single point
    (scalar(@$points_r) == 1) and return [$points_r->[0]];

    # Sort the set of points lexicographically
    my @points_ls= sort pts_sort @$points_r;

    # If there are only two points, return a reference to a set of two
    # points, sorted lexicographically
    if (scalar(@points_ls) == 2) {
	return \@points_ls;
    }

    # Compute the upper hull
    my @upper_hull;
    push @upper_hull, ($points_ls[0]);
    push @upper_hull, ($points_ls[1]);
    for (my $index= 2; $index < scalar(@points_ls); $index++) {
	push @upper_hull, ($points_ls[$index]);
	while ((scalar(@upper_hull) > 2) &&
	       (right_turn($upper_hull[$#upper_hull-2],
			   $upper_hull[$#upper_hull-1],
			   $upper_hull[$#upper_hull]) < 0)) {
	    splice(@upper_hull, $#upper_hull-1, 1);
	}
    }

    # Compute the lower hull
    my @lower_hull;
    push @lower_hull, ($points_ls[$#points_ls]);
    push @lower_hull, ($points_ls[$#points_ls-1]);
    for (my $index= scalar(@points_ls)-3; $index >= 0; $index--) {
	push @lower_hull, ($points_ls[$index]);
	while ((scalar(@lower_hull) > 2) &&
	       (right_turn($lower_hull[$#lower_hull-2],
			   $lower_hull[$#lower_hull-1],
			   $lower_hull[$#lower_hull]) < 0)) {
	    splice(@lower_hull, $#lower_hull-1, 1);
	}
    }

    # Merge the upper and lower hulls
    splice(@lower_hull, 0, 1);
    splice(@lower_hull, $#lower_hull, 1);
    splice(@upper_hull, $#upper_hull+1, 0, @lower_hull);

    return \@upper_hull;
}

# -----[ continental_grouping ]--------------------------------------
# Groups routers into continents
#
# Parameters:
# - reference to the set of points to group
#
# Returns:
#   clusters ::= list of [centroid, vertices[hash], coord]
# -------------------------------------------------------------------
sub continental_grouping($)
{
    my ($graph)= @_;
    my %groups= ();
    my $default= [];
    
    my @vertices= $graph->vertices();
  POINT: foreach my $u (@vertices) {
      
      my $pt= $graph->get_attribute(UCL::Graph::ATTR_COORD, $u);

      # Find the continent that contains this point
    CONTINENT: foreach my $cont (keys %igen_continents) {
	if (pt_in_poly($pt, $igen_continents{$cont}) > 0) {
	    if (!exists($groups{$cont})) {
		$groups{$cont}= ();
	    }
	    $groups{$cont}{$u}= 1;
	    next POINT;
	}
	
	# No continent was found, put in default group
	push @$default, ($pt);
	
    }
      
  }

    my @centroids= ();
    foreach my $group (keys %groups) {
	push @centroids, ([undef, $groups{$group}, undef]);
    }

    return \@centroids;
}

# -----[ triangulation_draw ]----------------------------------------
#
# -------------------------------------------------------------------
#sub triangulation_draw($)
#{
#    my $tri= shift;
#    my $triangles= $tri->get();
#
#    #print "Draw #triangles:".scalar(@$triangles)."\n";
#    foreach my $tri (@$triangles) {
#	my $p1= $tri->[0];
#	my $p2= $tri->[1];
#	my $p3= $tri->[2];
#	my $color= $tri->[3];
#	$cCanvas->createLine(x2screen($p1->[0]),
#			     y2screen($p1->[1]),
#			     x2screen($p2->[0]),
#			     y2screen($p2->[1]),
#			     -width=>1, -fill=>$color);
#	$cCanvas->createLine(x2screen($p2->[0]),
#			     y2screen($p2->[1]),
#			     x2screen($p3->[0]),
#			     y2screen($p3->[1]),
#			     -width=>1, -fill=>$color);
#	$cCanvas->createLine(x2screen($p3->[0]),
#			     y2screen($p3->[1]),
#			     x2screen($p1->[0]),
#			     y2screen($p1->[1]),
#			     -width=>1, -fill=>$color);
#    }
#}

#sub circle_through_3_points($$$)
#{
#    my ($A, $B, $C)= @_;
#
#    $cCanvas->createLine(x2screen($A->[0]),
#			 y2screen($A->[1]),
#			 x2screen($B->[0]),
#			 y2screen($B->[1]),
#			 -fill=>'red',
#			 -width=>1);
#    $cCanvas->createLine(x2screen($B->[0]),
#			 y2screen($B->[1]),
#			 x2screen($C->[0]),
#			 y2screen($C->[1]),
#			 -fill=>'red',
#			 -width=>1);
#
#    # Perpendicular bisector of segment AB
#    my $x1= ($A->[0]+$B->[0])/2;
#    my $y1= ($A->[1]+$B->[1])/2;
#    my $dx1= $B->[1]-$A->[1];
#    my $dy1= $A->[0]-$B->[0];
#    $cCanvas->createLine(x2screen($x1),
#			 y2screen($y1),
#			 x2screen($x1+$dx1),
#			 y2screen($y1+$dy1),
#			 -fill=>'blue',
#			 -width=>1);
#
#    # Perpendicular bisector of segment BC
#    my $x2= ($B->[0]+$C->[0])/2;
#    my $y2= ($B->[1]+$C->[1])/2;
#    my $dx2= $C->[1]-$B->[1];
#    my $dy2= $B->[0]-$C->[0];
#    $cCanvas->createLine(x2screen($x2),
#			 y2screen($y2),
#			 x2screen($x2+$dx2),
#			 y2screen($y2+$dy2),
#			 -fill=>'blue',
#			 -width=>1);
#
#    # Find intersection between bisectors (if it exists)
#    my $beta= ($dx1*($y1-$y2)+$dy1*($x2-$x1))/
#	($dy2*$dx1-$dy1*$dx2);
#    my $x= $x2+$beta*$dx2;
#    my $y= $y2+$beta*$dy2;
#
#    # Compute the circle's radius
#    my $r= sqrt(($A->[0]-$x)*($A->[0]-$x)+($A->[1]-$y)*($A->[1]-$y));
#
#    $cCanvas->createOval(x2screen($x-$r),
#			 y2screen($y-$r),
#			 x2screen($x+$r),
#			 y2screen($y+$r),
#			 -width=>1);
#    
#}


#####################################################################
#
# MAIN PROGRAM
#
#####################################################################

# -----[ igen_show_options ]-----------------------------------------
# Display the available options.
# -------------------------------------------------------------------
sub igen_show_options()
{
    print "\nThe calling syntax of IGen is:\n\n";
    print "  ./igen-gui.pl [OPTIONS]\n";
    print "\n";
    print "where OPTIONS are\n";
    print "  --help\n";
    print "    Display this help message.\n\n";
    print "  --version\n";
    print "    Display the version of IGen.\n\n";
    print "  --build=SPEC\n";
    print "    Build a topology based on the given method. The following methods are supported:\n\n";
    foreach (sort keys %igen_mesh_methods) {
      print "      [$_]\n";
    }
    print "\n";
    print "  --build-all\n";
    print "    Build a complete Internet-like topology based.\n\n";
    print "  --igp-weights\n";
    print "    Assign IGP weights. The following methods are supported:\n";
    foreach (sort keys %igen_igp_methods) {
      print "      [$_]\n";
    }
    print "\n";
    print "  --in-net=TOPOLOGY\n";
    print "    Load a network topology. The following formats are supported:\n";
    foreach (sort keys %igen_filters) {
      ($igen_filters{$_}->[0]->has_capability(IGen::FilterBase::IMPORT_SINGLE)) and
	print "      [$_]\n";
    }
    print "\n";
    print "  --in-tm=TRAFFIC-MATRIX\n";
    print "    Load a traffic matrix.\n\n";
    print "  --rand-net\n";
    print "    Generate a set of points.\n\n";
    print "  --rand-tm\n";
    print "    Generate a traffic matrix.\n\n";
    print "  --out-net\n";
    print "    Save a network into a file. The following formats are supported:\n";
    foreach (sort keys %igen_filters) {
      ($igen_filters{$_}->[0]->has_capability(IGen::FilterBase::EXPORT_SINGLE)) and
	print "      [$_]\n";
    }
    print "\n";
    print "  --out-inet\n";
    print "    Save all the networks into a file. The supported file formats are lister for the --in-net parameter.\n\n";
    print "  --[no]gui\n";
    print "    Disable the graphical user interface.\n\n";
    print "  --measure=MEASURE-SPEC\n";
    print "    Measure the given network(s). The following measures are available:\n";
    foreach (sort keys %igen_measure_methods) {
      print "      [$_]\n";
    }
    print "\n";
}

# -----[ igen_show_version ]-----------------------------------------
# Display the current version.
# -------------------------------------------------------------------
sub igen_show_version() {
    print "*** ".PROGRAM_NAME." ".PROGRAM_VERSION." ***\n";
    print "(C) 2005, Bruno Quoitin\n";
    print "CSE Dept., UCL, Belgium\n";
}

# -----[ filter_spec_parser ]----------------------------------------
# Parse a filter specification.
# Return a couple (filename, hash of options)
# -------------------------------------------------------------------
sub filter_spec_parser($) {
  my ($spec_str)= @_;
  my @spec_array= split /\:/, $spec_str;

  # Check that the spec contains at leat a filter
  if (scalar(@spec_array) < 1) {
    print STDERR "Error: no file name specified in filter spec \"$spec_str\"\n";
    return undef;
  }

  my $filename= shift @spec_array;

  my %options;
  foreach (@spec_array) {
    if (!(m/^\-\-([a-zA-Z]+(\=(.+))?)/)) {
      print STDERR "Error: invalid syntax in filter spec \"$_\"";
      return undef;
    }
    my ($key, $value)= split /\=/, $1, 2;
    $options{$key}= $value;
  }
  return ($filename, \%options);
}

# -----[ igen_main_out_net ]-----------------------------------------
sub igen_main_out_net($) {
  my ($spec)= @_;
  my ($filename, $options)= filter_spec_parser($spec);
  if (!defined($filename)) {
    print STDERR "Error: missing output filename. Aborting.\n";
    return -1;
  }
  return gui_menu_filter_export(IGen::FilterBase::EXPORT_SINGLE,
				$filename, $options);
}

# -----[ igen_main_out_inet ]----------------------------------------
sub igen_main_out_inet($) {
  my ($spec)= @_;
  my ($filename, $options)= filter_spec_parser($spec);
  if (!defined($filename)) {
    print STDERR "Error: missing output filename. Aborting.\n";
    return -1;
  }
  return gui_menu_filter_export(IGen::FilterBase::EXPORT_MULTIPLE,
				$filename, $options);
}

# -----[ igen_main ]-------------------------------------------------
# Main program.
# -------------------------------------------------------------------
sub igen_main()
{
    my %opt_ctl= ();
    my $domains= undef;

    print STDERR "IGen, Copyright (C) 2005-2009 Bruno Quoitin\n";
    print STDERR "IGen comes with ABSOLUTELY NO WARRANTY.\n";
    print STDERR "This is free software, and you are welcome to redistribute it\n";
    print STDERR "under certain conditions; see file COPYING for details.\n";

    igen_init_mesh_methods();
    igen_init_clustering_methods();
    igen_init_traffic_methods();
    igen_init_igp_methods();
    igen_init_capacity_methods();
    igen_init_measure_methods();
    igen_init_filters();

    # ---| parse options |---
    if (!GetOptions(\%opt_ctl, 'noborder', 'verbose:i@',
		    'build:s',
		    'build-all:s',
		    'in-net:s@',
		    'in-tm:s',
		    'rand-net:s',
		    'rand-tm:s',
		    'gui!',
		    'measure:s@',
		    'out-net:s@',
		    'out-inet:s',
		    'test:s',
		    'help',
		    'version',
		    'igp-weights:s')) {
	igen_show_options();
	exit(-1);
    }

    # ---| startup functions |---
    igen_init_continents();
    igen_init_link_capacities();
    igen_init_link_load_colors();
    igen_init_link_widths();
    igen_init_igp_plf();

    if (exists($opt_ctl{'version'})) {
	igen_show_version();
	exit(0);
    }

    if (exists($opt_ctl{'help'})) {
	igen_show_options();
	exit(0);
    }

    foreach my $i (@{$opt_ctl{verbose}}) { increase_verbosity(); }

    $global_options= UCL::Graph::Base::get_options_ref();
    $global_options->{ecmp}= 1;

    if (!exists($opt_ctl{'gui'}) ||
	($opt_ctl{'gui'} == 1)) {

	$global_plot_params= {
	    'access' => 1,
	    'borders' => 0,
	    'canvas' => undef,
	    'continents' => 1,
	    'edge_color' => 'black',
	    'grid' => 1,              # Show grid
	    'igraph' => 1,            # Show interdomain links
	    'labels' => 0,            # Show labels
	    'links' => 1,             # Show intradomain links
	    'xgrid' => 15,
	    'ygrid' => 15,
	    'xscroll' => 0,
	    'yscroll' => 0,
	    'zoom_factor' => 1,
	    'wnode' => 5,
	};

	gui_create($opt_ctl{noborder});
    }

    srand(2004);

    # ---| Import network |---
    if (exists($opt_ctl{'in-net'})) {
	foreach (@{$opt_ctl{'in-net'}}) {
	    gui_menu_filter_import($_);
	}
    }

    # ---| Generate random network |---
    if (exists($opt_ctl{'rand-net'})) {
	my @args= split /\:/, $opt_ctl{'rand-net'};
	gui_menu_gen_random_vertices(@args);
    }

    # ---| Load traffic matrix |---
    if (exists($opt_ctl{'in-tm'})) {
	my $result= gui_menu_traffic_load($opt_ctl{'in-tm'});
	if ($result) {
	    gui_dialog_error("in-tm finished with error. Aborted.");
	    exit(-1);
	}
    }

    # ---| Generate traffic matrix |---
    if (exists($opt_ctl{'rand-tm'})) {
	gui_menu_traffic_generate($opt_ctl{'rand-tm'});
    }

    # ---| Build network |---
    if (exists($opt_ctl{'build'})) {
      print "Building graph...\n";
	my $graph= db_graph_get_current_as();
	if (!defined($graph)) {
	    gui_dialog_error("No graph.");
	    exit(-1);
	}
	my $built= graph_build_mesh($graph, $opt_ctl{'build'});
	if (!defined($built)) {
	  gui_dialog_error("Build error.");
	  exit(-1);
	}
	graph_clear_edges($graph);
	graph_add_subgraph($graph, $built);
    }

    # ---| Assign IGP weights |---
    if (exists($opt_ctl{'igp-weights'})) {
	my $graph= db_graph_get_current_as();
	if (!defined($graph)) {
	  gui_dialog_error("No graph.");
	  exit(-1);
	}
	graph_assign_weights($graph, $opt_ctl{'igp-weights'});
    }

    # ---| Build Internet |---
    if (exists($opt_ctl{'build-all'})) {
	my @spec= split /\:/, $opt_ctl{'build-all'};
	if (gui_menu_build_internet(@spec) < 0) {
	    gui_dialog_error("Build error");
	    exit(-1);
	}
    }

    # ---| Measure graph/network |---
    if (exists($opt_ctl{'measure'})) {
	my $graph= db_graph_get_current_as();
	if (!defined($graph)) {
	  gui_dialog_error("No graph.");
	  exit(-1);
	}
	foreach my $spec (@{$opt_ctl{'measure'}}) {
	  if (graph_measure($graph, $spec)) {
	    gui_dialog_error("measure finished with error. Aborted.");
	    exit(-1);
	  }
	}
    }

    # ---| Export network |---
    if (exists($opt_ctl{'out-net'})) {
      foreach (@{$opt_ctl{'out-net'}}) {
	(igen_main_out_net($_) < 0) and exit(-1);
      }
    }
    if (exists($opt_ctl{'out-inet'})) {
      (igen_main_out_inet($opt_ctl{'out-inet'}) < 0) and
	exit(-1);
    }

    # ---| Tests |---
    if (exists($opt_ctl{'test'})) {
	igen_test($opt_ctl{'test'});
    }

    exists($GUI{Main}) and MainLoop;
}

# -----[ graph_link_utilization ]------------------------------------
#
# -------------------------------------------------------------------
sub graph_link_utilization($)
{
    my ($graph)= @_;
    my %links_load= ();

    (!$graph->has_attribute(UCL::Graph::ATTR_TM) ||
     !$graph->has_attribute(UCL::Graph::ATTR_RM)) and
	return undef;

    my $RM= $graph->get_attribute(UCL::Graph::ATTR_RM);
    my $TM= $graph->get_attribute(UCL::Graph::ATTR_TM);

    # Route traffic matrix in order to find minimum link capacities
    my $total_volume= 0;
    foreach my $u (keys %$TM) {
	foreach my $v (keys %{$TM->{$u}}) {
	    next if ($u == $v);
	    my $volume= $TM->{$u}->{$v};
	    #print "$u -> $v: $volume\n";
	    my $paths= $RM->{$u}->{$v};
	    if (!defined($paths) || (@$paths == 0)) {
		print "warning: no route from $u to $v (traffic lost: $volume)\n";
		next;
	    }
	    my $num_paths= scalar(@$paths);
	    $volume/= $num_paths;
	    foreach my $path (@$paths) {
		#print "\t";
		#path_dump($path);
		#print "\n";
		if (@$path <= 1) {
		    print "warning: incomplete path from $u to $v\n";
		    next;
		}
		for (my $i= 1; $i < @$path; $i++) {
		    if (!exists($links_load{$path->[$i-1]}{$path->[$i]})) {
			$links_load{$path->[$i-1]}{$path->[$i]}= $volume;
		    } else {
			$links_load{$path->[$i-1]}{$path->[$i]}+= $volume;
		    }
		    $total_volume+= $volume;
		}
	    }
	}
    }

    gui_terminal_add("total-volume: $total_volume\n");

    return \%links_load;
}

# -----[ best_capacity ]---------------------------------------------
sub best_capacity($)
{
    my ($capacity)= @_;
    my $best_capacity= undef;

    if ($capacity == 0) {
	return 0;
    }

    foreach my $link_capacity (@igen_link_capacities) {
	if (($link_capacity >= $capacity) &&
	    (!defined($best_capacity) ||
	     ($link_capacity < $best_capacity))) {
	    $best_capacity= $link_capacity;
	}
    }

    return $best_capacity;
}

# -----[ gui_menu_capacity ]-----------------------------------------
#
# -------------------------------------------------------------------
sub gui_menu_capacity()
{
    my $graph= db_graph_get_current_as();
    (!defined($graph)) and return;

    my $dialog= IGen::DialogCapacity->new(-parent=>$GUI{Main},
					  -method=>'fixed');
    my $result= $dialog->show_modal();
    $dialog->destroy();
    (!defined($result)) and return;
    my $spec= $result->{method}.':'.(join ':', @{$result->{params}});

    graph_assign_capacities($graph, $spec);
}

# -----[ TM_load ]---------------------------------------------------
#
# -------------------------------------------------------------------
sub TM_load($)
{
    my ($filename)= @_;
    my %TM= ();
    my $line_number= 0;

    (open(TM, "<$filename")) or
	die "Error: unable to load traffic-matrix from \"$filename\": $!";
    while (<TM>) {
	$line_number++;
	chomp;
	# Skip comments
	(m/^\#/) and next;
	# Read triple of fields
	my @fields= split /\s+/;
	(@fields != 3) and
	    die "Error: wrong number of fields at line $line_number";
	# Store into traffic-matrix
	my $u= $fields[0];
	my $v= $fields[1];
	my $volume= $fields[2];
	(exists($TM{$u}{$v})) and
	    die "Error: duplicate pair ($u,$v) at line $line_number";
	$TM{$u}{$v}= $volume;
    }
    close(TM);
    return \%TM;
}

# -----[ TM_save ]---------------------------------------------------
#
# -------------------------------------------------------------------
sub TM_save($$)
{
    my ($TM, $filename)= @_;

    (open(TM, ">$filename")) or
	die "Error: unable to save traffic-matrix in \"$filename\": $!";
    print TM "# Traffic matrix\n";
    print TM "# Generated by ".PROGRAM_NAME." ".PROGRAM_VERSION."\n";
    print TM "# on ".localtime(time())."\n";
    foreach my $u (keys %$TM) {
	foreach my $v (keys %{$TM->{$u}}) {
	    my $volume= $TM->{$u}{$v};
	    print TM "$u\t$v\t$volume\n";
	}
    }
    close(TM);
}

# -----[ gui_menu_traffic_generate ]---------------------------------
#
# -------------------------------------------------------------------
sub gui_menu_traffic_generate(;$)
{
    my ($spec)= @_;
    my $graph= $db_graph->{as2graph}->{$current_as};
    (!defined($graph)) and return -1;
    if (!defined($spec)) {
	my $dialog= IGen::DialogTraffic->new(-parent=>$GUI{Main});
	my $result= $dialog->show_modal();
	$dialog->destroy();
	(!defined($result)) and return -1;
	my $method= $result->{method};
	my @args= @{$result->{params}};
	$spec= "$method:".(join ':', @args);
    }
    gui_terminal_update("traffic-matrix-generate [$spec]\n");
    my $result= graph_TM_generate($graph, $spec);
    if ($result < 0) {
	gui_dialog_error("error in traffic-matrix generation ($spec)!");
    }

    return 0;
}

# -----[ gui_menu_traffic_save ]-------------------------------------
#
# -------------------------------------------------------------------
sub gui_menu_traffic_save()
{
    my $graph= db_graph_get_current_as();
    (!defined($graph)) and return -1;
    my $filename= $GUI{Main}->getSaveFile(-defaultextension=>'.tm',
				   -filetypes=>
				   [['Traffic matrices', '.tm']],
				   -title=>'Save a traffic matrix');
    (!defined($filename)) and return -1;
    my $TM= $graph->get_attribute(UCL::Graph::ATTR_TM);
    TM_save($TM, $filename);
    gui_terminal_update("traffic-matrix-save [$filename]\n");
    return 0;
}

# -----[ gui_menu_traffic_load ]-------------------------------------
#
# -------------------------------------------------------------------
sub gui_menu_traffic_load(;$)
{
    my ($filename)= @_;
    my $graph= db_graph_get_current_as();
    (!defined($graph)) and return -1;
    if (!defined($filename)) {
	$filename= $GUI{Main}->getOpenFile(-defaultextension=>'.tm',
				    -filetypes=>
				    [['Traffic matrices', '.tm']],
				    -title=>'Open a traffic matrix');
	(!defined($filename)) and return -1;
    }
    my $TM= TM_load($filename);
    if (!defined($TM)) {
	gui_dialog_error("Error in loading traffic-matrix !");
	return -1;
    }
    gui_terminal_update("traffic-matrix-load [$filename]\n");
    $graph->set_attribute(UCL::Graph::ATTR_TM, $TM);

    return 0;
}

# -----[ gui_dialog_waxman ]-----------------------------------------
#
# -------------------------------------------------------------------
#sub gui_dialog_waxman()
#{
#    my $result= undef;
#
#    if (exists($GUI{DialogWaxman}) && $GUI{DialogWaxman}{top}->ismapped()) {
#	$GUI{DialogWaxman}{top}->raise();
#    }
#
#    $GUI{DialogWaxman}{top}= $mw->Toplevel();
#    $GUI{DialogWaxman}{top}->title("Waxman");
#    $GUI{DialogWaxman}{top}->resizable(0,0);
#    $GUI{DialogWaxman}{top}->transient($GUI{DialogWaxman}{top}->Parent->toplevel);
#    $GUI{DialogWaxman}{top}->withdraw();
#    $GUI{DialogWaxman}{top}->protocol('WM_DELETE_WINDOW'=>sub{});
#    $GUI{DialogWaxman}{semaphore}= 0;
#    $GUI{DialogWaxman}{alpha}= 0.15;
#    $GUI{DialogWaxman}{beta}= 0.2;
#    $GUI{DialogWaxman}{m}= 2;
#
#    $GUI{DialogWaxman}{Top}{top}=
#	$GUI{DialogWaxman}{top}->Frame(-relief=>'sunken',
#					-borderwidth=>1
#				       )->pack(-side=>'top');
#    $GUI{DialogWaxman}{Top}{top}->Label(-text=>'Alpha')->pack(-expand=>1);
#    $GUI{DialogWaxman}{Top}{top}->Entry(-textvariable=>
#					\$GUI{DialogWaxman}{alpha}
#					)->pack(-expand=>1);
#    $GUI{DialogWaxman}{Top}{top}->Label(-text=>'Beta')->pack(-expand=>1);
#    $GUI{DialogWaxman}{Top}{top}->Entry(-textvariable=>
#					\$GUI{DialogWaxman}{beta}
#					)->pack(-expand=>1);
#    $GUI{DialogWaxman}{Top}{top}->Label(-text=>'m')->pack(-expand=>1);
#    $GUI{DialogWaxman}{Top}{top}->Entry(-textvariable=>
#					\$GUI{DialogWaxman}{m}
#					)->pack(-expand=>1);
#
#    $GUI{DialogWaxman}{Bottom}{top}=
#	$GUI{DialogWaxman}{top}->Frame(-relief=>'sunken',
#					-borderwidth=>1
#				       )->pack(-side=>'bottom');
#    $GUI{DialogWaxman}{Bottom}{top}->Button(-text=>'Ok',
#					    -command=>sub {
#						$GUI{DialogWaxman}{semaphore}= 1;
#						$result=
#						    [$GUI{DialogWaxman}{alpha},
#						     $GUI{DialogWaxman}{beta},
#						     $GUI{DialogWaxman}{m}
#						     ];
#					    }
#					    )->pack(-side=>'right');
#    $GUI{DialogWaxman}{Bottom}{top}->Button(-text=>'Cancel',
#					    -command=>sub {
#						$GUI{DialogWaxman}{semaphore}= 1;
#					    }
#					    )->pack(-side=>'left');
#
#    $GUI{DialogWaxman}{top}->Popup();
#    $GUI{DialogWaxman}{top}->grab();
#    $GUI{DialogWaxman}{top}->waitVariable($GUI{DialogWaxman}{semaphore});
#    $GUI{DialogWaxman}{top}->grabRelease();
#    $GUI{DialogWaxman}{top}->destroy();
#    delete($GUI{DialogWaxman});
#    return $result;
#}

# -----[ gui_menu_show_TM ]------------------------------------------
#
# -------------------------------------------------------------------
sub gui_menu_show_TM()
{
    my $graph= db_graph_get_current_as();
    (!defined($graph)) and return -1;
    if (!$graph->has_attribute(UCL::Graph::ATTR_TM)) {
	gui_dialog_error("no traffic matrix");
	return;
    }
    my $TM= $graph->get_attribute(UCL::Graph::ATTR_TM);
    my $dialog= IGen::DialogShowTM->new(-parent=>$GUI{Main},
					-TM=>$TM,
					-command=>sub{
					    my ($pair)= @_;
					    print "pair: ".(join ':', @$pair)."\n";
				    });
    $dialog->show_modal();
    $dialog->destroy();
}

# -----[ gui_clear_path ]--------------------------------------------
#
# -------------------------------------------------------------------
sub gui_clear_path()
{
    $GUI{Canvas}->delete("path");
}

# -----[ gui_draw_path ]---------------------------------------------
#
# -------------------------------------------------------------------
sub gui_draw_path($$)
{
    my ($graph, $path)= @_;

    for (my $i= 1; $i < @$path; $i++) {
	my $u= $path->[$i-1];
	my $v= $path->[$i];
	my $uc= $graph->get_attribute(UCL::Graph::ATTR_COORD, $u);
	my $vc= $graph->get_attribute(UCL::Graph::ATTR_COORD, $v);
	if ($i+1 == @$path) {
	    gui_draw_line($GUI{Canvas}, $uc, $vc, 'blue', 1, ["path"], -arrow=>'last');
	} else {
	    gui_draw_line($GUI{Canvas}, $uc, $vc, 'blue', 1, ["path"]);
	}
    }
}

# -----[ gui_menu_show_RM ]------------------------------------------
#
# -------------------------------------------------------------------
sub gui_menu_show_RM()
{
    my $graph= db_graph_get_current_as();
    (!defined($graph)) and return -1;
    if (!$graph->has_attribute(UCL::Graph::ATTR_RM)) {
	gui_dialog_error("no routing matrix");
	return -1;
	# Compute routing matrix
	#my $graph= db_graph_get_current_as();
	#$RM= graph_APSP($graph, $global_options->{ecmp},
	#		\&graph_dst_fct_weight);
    }
    my $dialog= IGen::DialogShowRM->new(-parent=>$GUI{Main},
					-graph=>$graph,
					-command=>sub {
					    my ($path)= @_;
					    gui_clear_path();
					    gui_draw_path($graph, $path);
					});
    $dialog->show_modal();
    $dialog->destroy();
}
    
# -----[ gui_menu_show_clusters ]------------------------------------
#
# -------------------------------------------------------------------
sub gui_menu_show_clusters()
{
    my $graph= db_graph_get_current_as();
    (!defined($graph)) and return -1;
    if (!$graph->has_attribute(UCL::Graph::ATTR_CLUSTERS)) {
	gui_dialog_error("no clusters");
	return -1;
    }
    my $clusters= $graph->get_attribute(UCL::Graph::ATTR_CLUSTERS);
    my $dialog= IGen::DialogShowClusters->new(-parent=>$GUI{Main},
					      -graph=>$graph,
					      -command=>sub {
						  my ($index)= @_;
						  gui_clear_cluster();
						  gui_draw_cluster($graph, $index);
					      });
    $dialog->show_modal();
    $dialog->destroy();
    return 0;
}

# -----[ gui_menu_show_domains ]-------------------------------------
#
# -------------------------------------------------------------------
sub gui_menu_show_domains()
{
    my $dialog= IGen::DialogShowDomains->new(-parent=>$GUI{Main},
					     -domains=>$db_graph->{as2graph},
					     -command=>\&select_domain);
    $dialog->show_modal();
    $dialog->destroy();
}

# -----[ gui_menu_show_links ]---------------------------------------
#
# -------------------------------------------------------------------
sub gui_menu_show_links(;$)
{
    my ($graph)= @_;
    
    if (!defined($graph)) {
	$graph= db_graph_get_current_as();
	(!defined($graph)) and return;
    }

    my $domain_id= $graph->get_attribute(UCL::Graph::ATTR_AS);
    my $dialog= IGen::DialogShowLinks->new(-parent=>$GUI{Main},
					   -graph=>$graph,
					   -capacities=>\@igen_link_capacities,
					   -command=>sub {
					       my ($link)= @_;
					       select_link($link->[0], $link->[1], $graph);
					   });
    $dialog->show_modal();
    $dialog->destroy();
}

# -----[ gui_menu_show_routers ]-------------------------------------
#
# -------------------------------------------------------------------
sub gui_menu_show_routers()
{
    my $graph= db_graph_get_current_as();
    (!defined($graph)) and return;
    my $domain_id= $graph->get_attribute(UCL::Graph::ATTR_AS);
    my $dialog= IGen::DialogShowRouters->new(-parent=>$GUI{Main},
					     -graph=>$graph,
					     -command=>sub {
						 my ($info)= @_;
						 select_router($info->[0],
							       $info->[1]);
					     });
    $dialog->show_modal();
    $dialog->destroy();
}

# -----[ graph_reduce ]----------------------------------------------
#
# -------------------------------------------------------------------
sub graph_reduce($)
{
    my ($graph)= @_;
    my @deleted_edges= ();

    my @edges= $graph->edges();
    for (my $i= 0; $i < @edges/2; $i++) {
	my $u= $edges[$i*2];
	my $v= $edges[$i*2+1];
	my $remove= 1;
	if ($graph->has_attribute(UCL::Graph::ATTR_UTIL, $u, $v)) {
	    if ($graph->get_attribute(UCL::Graph::ATTR_UTIL, $u, $v) > 0) {
		$remove= 0;
	    }
	}
	if ($remove) {
	    push @deleted_edges, ($u, $v);
	    $graph->delete_edge($u, $v);
	}
    }

    return @deleted_edges;
}

# -----[ gui_menu_intra_reduce ]-------------------------------------
#
# -------------------------------------------------------------------
sub gui_menu_intra_reduce()
{
    my $graph= db_graph_get_current_as();
    (!defined($graph)) and return -1;
    gui_terminal_update("graph_reduce\n");
    my @deleted_edges= graph_reduce($graph);
    gui_terminal_add((@deleted_edges/2)." links removed\n");
    if ($global_verbosity > 1) {
	for (my $i= 0; $i < @deleted_edges/2; $i++) {
	    my $u= $deleted_edges[$i*2];
	    my $v= $deleted_edges[$i*2+1];
	    gui_terminal_add("link $u->$v removed\n");
	}
    }
    gui_menu_view_redraw();
}

# -----[ gui_menu_intra_clustering ]---------------------------------
#
# -------------------------------------------------------------------
sub gui_menu_intra_clustering()
{
    my $graph= db_graph_get_current_as();
    (!defined($graph)) and return -1;
    my $dialog= IGen::DialogCluster->new(-parent=>$GUI{Main});
    my $result= $dialog->show_modal();
    $dialog->destroy();
    (!defined($result)) and return 0;

    my $spec= $result->{method}.':'.(join ':', @{$result->{params}});
    my $clusters= graph_build_clusters($graph, $spec);
    $graph->set_attribute(UCL::Graph::ATTR_CLUSTERS, $clusters);
    return 0;
}

sub check_shortest_paths()
{
    my $graph= db_graph_get_current_as();
    (!defined($graph)) and return -1;

    my $RM= $graph->get_attribute(UCL::Graph::ATTR_RM);

    gui_terminal_update("check-shortest-paths:\n");

    foreach my $u (keys %$RM) {
	NEXT_PATH: foreach my $v (keys %{$RM->{$u}}) {
	    ($u == $v) and next;

	    my $paths= $RM->{$u}{$v};
	    foreach my $path (@$paths) {
		
		for (my $i= 0; $i < @$path-1; $i++) {
		    for (my $j= $i+1; $j < @$path; $j++) {

			my $xu= $path->[$i];
			my $xv= $path->[$j];

			my $weight= 0;
			my @sub_path= ($path->[$i]);
			for (my $x= $i+1; $x <= $j; $x++) {
			    $weight+= $graph->get_attribute(UCL::Graph::ATTR_WEIGHT,
							    $path->[$x-1],
							    $path->[$x]);
			    push @sub_path, ($path->[$x]);
			}

			my $xpaths= $RM->{$xu}{$xv};
			my $xpath= $xpaths->[0];
			my ($xhop_cnt, $xlength, $xweight)=
			    UCL::Graph::Base::path_length($graph, $xpath);

			if ($xweight < $weight) {
			    gui_terminal_add("warning: path $u-$v (".
					     (join ',', @$path).
					     ") is not shortest:\n");
			    gui_terminal_add("  $xu->$xv ".(join ',', @sub_path)." ($weight)\n");
			    gui_terminal_add("  shortcut ".(join ',', @$xpath)." ($xweight)\n");
			    next NEXT_PATH;
			}

		    }
		}

	    }
	}
    }
}

# -----[ gui_draw_cluster ]------------------------------------------
#
# -------------------------------------------------------------------
sub gui_draw_cluster($$)
{
    my ($graph, $cluster)= @_;

    foreach my $u (keys %{$cluster->[1]}) {
	my $coord= $graph->get_attribute(UCL::Graph::ATTR_COORD, $u);
	gui_draw_node($GUI{Canvas}, $coord->[0], $coord->[1],
		      'red', $global_plot_params->{wnode}+1, ["cluster"]);
    }
}

# -----[ gui_clear_cluster ]-----------------------------------------
#
# -------------------------------------------------------------------
sub gui_clear_cluster()
{
    $GUI{Canvas}->delete("cluster");
}

# -----[ graph_add_subgraph ]----------------------------------------
# Add a subgraph to a graph.
#
# Arguments:
#   graph    : target graph where new vertices/edges will be copied
#   subgraph : subgraph to add
# -------------------------------------------------------------------
sub graph_add_subgraph($$)
{
    my ($graph, $subgraph)= @_;

    # Copy vertices
    foreach my $u ($subgraph->vertices()) {
	$graph->add_vertex($u);
	foreach my $attr ($subgraph->get_attributes($u)) {
	    my $value= $subgraph->get_attribute($attr, $u);
	    $graph->set_attribute($attr, $u, $value);
	}
    }

    # Copy edges
    my @edges= $subgraph->edges();
    for (my $i= 0; $i < @edges/2; $i++) {
	my $u= $edges[$i*2];
	my $v= $edges[$i*2+1];
	if (!$graph->has_edge($u, $v)) {
	    $graph->add_edge($u, $v);
	    foreach my $attr ($subgraph->get_attributes($u, $v)) {
		my $value= $subgraph->get_attribute($attr, $u, $v);
		$graph->set_attribute($attr, $u, $v, $value);
	    }
	}
    }
}

# -----[ graph_extract_subgraph ]------------------------------------
# Extract a subgraph from a graph. The subgraph is specified using a
# set of vertices. The edges between the subgraph's vertices are also
# extracted. All the vertices' and edges' attributes are copied.
#
# Arguments:
#   graph    : source graph
#   vertices : set of vertices that will compose the subgraph
# -------------------------------------------------------------------
sub graph_extract_subgraph($$)
{
    my ($graph, $vertices)= @_;

    my $subgraph= new Graph::Undirected();

    # extract vertices
    foreach my $u (@$vertices) {
	if ($graph->has_vertex($u)) {
	    $subgraph->add_vertex($u);
	    foreach my $attr ($graph->get_attributes($u)) {
		my $value= $graph->get_attribute($attr, $u);
		$subgraph->set_attribute($attr, $u, $value);
	    }
	}
    }

    # extract edges
    foreach my $u ($subgraph->vertices()) {
	foreach my $v ($subgraph->vertices()) {
	    ($u != $v) or next;
	    ($graph->has_edge($u, $v)) or next;
	    $subgraph->add_edge($u, $v);
	    foreach my $attr ($graph->get_attributes($u, $v)) {
		my $value= $graph->get_attribute($attr, $u, $v);
		$subgraph->set_attribute($attr, $u, $v, $value);
	    }	    
	}
    }
    
    return $subgraph;
}

# -----[ graph_center ]----------------------------------------------
# Compute the center of the graph.
#
# Arguments:
#   graph : the graph on which we operate
# -------------------------------------------------------------------
sub graph_center($)
{
    my ($graph)= @_;

    # |V| must be > 0
    my $num_vertices= scalar($graph->vertices());
    ($num_vertices <= 0) and die;

    # Compute mean position
    my @mean= (0, 0);
    foreach my $u ($graph->vertices()) {
	my $coord= $graph->get_attribute(UCL::Graph::ATTR_COORD, $u);
	$mean[0]+= $coord->[0];
	$mean[1]+= $coord->[1];
    }
    $mean[0]/= $num_vertices;
    $mean[1]/= $num_vertices;

    return @mean;
}

# -----[ graph_diameter ]--------------------------------------------
# Compute the diameter of the graph, based on the distance between the
# most distant vertices.
#
# Arguments:
#   graph : the graph on which we operate
# -------------------------------------------------------------------
sub graph_diameter($)
{
    my ($graph)= @_;
    my $diameter= 0;
    
    my @vertices= $graph->vertices();
    for (my $i= 0; $i < @vertices-1; $i++) {
	my $u= $vertices[$i];
	for (my $j= $i+1; $j < @vertices; $j++) {
	    my $v= $vertices[$j];
	    my $dist= UCL::Graph::Base::distance($graph, $u, $v);
	    if ($dist > $diameter) {
		$diameter= $dist;
	    }
	}
    }

    return $diameter;
}


#####################################################################
#
# SERIALIZATION FUNCTIONS
#
#####################################################################

# -----[ igen_load_array ]-------------------------------------------
#
# -------------------------------------------------------------------
sub igen_load_array($$;%)
{
    my ($filename, $array_ref, %args)= @_;
    my $sep= "\\s";
    my $check_fct= undef;

    if (exists($args{-separator})) {
	$sep= $args{-separator};
    }
    if (exists($args{-check})) {
	$check_fct= $args{-check};
    }

    if (!open(ARRAY, $filename)) {
	print STDERR "Error: unable to open \"$filename\": $!\n";
	return -1;
    }
    while (<ARRAY>) {
	chomp;
	(m/^\#/) and next;
	my @fields= split /$sep+/;
	if (scalar(@fields) != 1) {
	    print STDERR "Error: syntax error in \"$filename\"\n";
	    close(ARRAY);
	    return -1;
	}
	if (defined($check_fct) && &$check_fct(\@fields)) {
	    print STDERR "Error: syntax error in \"$filename\"\n";
	    close(ARRAY);
	    return -1;
	}
	my $item= $fields[0];
	push @$array_ref, ($item);
    }
    close(ARRAY);
    return 0;
}

# -----[ igen_load_hash ]--------------------------------------------
#
# -------------------------------------------------------------------
sub igen_load_hash($$;%)
{
    my ($filename, $hash_ref, %args)= @_;
    my $sep= "\\s";
    my $check_fct= undef;

    if (exists($args{-separator})) {
	$sep= $args{-separator};
    }
    if (exists($args{-check})) {
	$check_fct= $args{-check};
    }

    if (!open(HASH, $filename)) {
	print STDERR "Error: unable to open \"$filename\": $!\n";
	return -1;
    }
    while (<HASH>) {
	chomp;
	(m/^\#/) and next;
	my @fields= split /$sep+/;
	if (scalar(@fields) != 2) {
	    print STDERR "Error: syntax error in \"$filename\"\n";
	    return -1;
	}
	if (defined($check_fct) && &$check_fct(\@fields)) {
	    print STDERR "Error: syntax error in \"$filename\"\n";
	    close(ARRAY);
	    return -1;
	}
	my $key= $fields[0];
	my $value= $fields[1];
	if (exists($hash_ref->{$key})) {
	    print STDERR "Error: duplicate key in \"$filename\"\n";
	    close(HASH);
	    return -1;
	}
	$hash_ref->{$key}= $value;
    }
    close(HASH);
    return 0;
}


#####################################################################
#
# STARTUP & CONFIGURATION FUNCTIONS
#
#####################################################################

# -----[ igen_init_continents ]--------------------------------------
#
# -------------------------------------------------------------------
sub igen_init_continents()
{
    my $filename= "config/continents.txt";
    my $result= open(CONT, $filename);
    if (!$result) {
	print STDERR "Error: unable to open \"$filename\": $!\n";
	exit(-1);
    }
    %igen_continents= ();
    my $cont= undef;
    while (<CONT>) {
	chomp;
	m/^\#/ and next;
	my @fields= split /\s+/;
	if (scalar(@fields) == 1) {
	    $cont= $fields[0];
	    if (exists($igen_continents{$cont})) {
		print STDERR "Error: duplicate definition of ".
		    "continent\n";
		exit(-1);
	    }
	    $igen_continents{$cont}= [];
	} elsif (scalar(@fields) == 2) {
	    push @{$igen_continents{$cont}}, ([$fields[0], $fields[1]]);
	}
    }
    close(CONT);
}

# -----[ igen_init_link_capacities ]---------------------------------
#
# -------------------------------------------------------------------
sub igen_init_link_capacities()
{
    if (igen_load_array("config/link-capacities.txt",
			\@igen_link_capacities,
			-check=>sub {
			    my ($fields)= @_;
			    $fields->[0]= text2capacity($fields->[0]);
			    (!defined($fields->[0])) and return -1;
			    return 0;
			})) {
	die "Error: could not load link-capacities";
    }
}

# -----[ igen_init_link_load_colors ]--------------------------------
#
# -------------------------------------------------------------------
sub igen_init_link_load_colors()
{
    if (igen_load_array("config/link-load-colors.txt",
			\@igen_link_load_colors,
			-separator=>"\\t")) {
	die "Error: could not load link-load-colors";
    }
}

# -----[ igen_init_link_widths ]-------------------------------------
#
# -------------------------------------------------------------------
sub igen_init_link_widths()
{
    if (igen_load_hash("config/link-widths.txt",
		       \%igen_link_widths)) {
	die "Error: could not load link-widths";
    }
}

# -----[ igen_init_igp_plf ]-----------------------------------------
#
# -------------------------------------------------------------------
sub igen_init_igp_plf()
{
    if (igen_load_hash("config/igp-plf.txt",
		       \%igen_igp_plf)) {
	die "Error: could not load igp-plf";
    }
    @igen_igp_plf_steps= sort {$a <=> $b} keys %igen_igp_plf;
}

# -----[ igen_init_mesh_methods ]------------------------------------
# Initialize the list of mesh methods. Each mesh method is identified
# by a string.
# -------------------------------------------------------------------
sub igen_init_mesh_methods()
{
    # Register mesh generation methods. The functions must take
    # arguments as follows: <graph> [ <arguments> ]
    %igen_mesh_methods=
	(
	 '<none>' => undef,
	 'clique' => \&UCL::Graph::Generate::clique,
	 'delaunay' => \&graph_delaunay,
	 'harary' => \&UCL::Graph::Generate::harary,
	 'mentor' => \&graph_MENTOR,
	 'multi-tours' => \&graph_multitours,
	 'mst' => \&graph_mst,
	 'node-linking' => \&UCL::Graph::Generate::node_linking,
	 'sprint' => undef,
#	 'spt' => undef,
	 'tsp' => \&graph_TSP,
	 'two-trees' => \&graph_two_trees,
	 'waxman' => \&graph_waxman,
	 );
}

# -----[ igen_init_clustering_methods ]------------------------------
#
# -------------------------------------------------------------------
sub igen_init_clustering_methods()
{
    %igen_clustering_methods=
	(
	 'k-medoids' => \&UCL::Graph::Cluster::kmedoids,
	 'hierarchical-ward' => \&graph_cluster_ward,
	 'threshold' => \&UCL::Graph::Cluster::threshold,
	 'grid' => \&UCL::Graph::Cluster::grid,
	 'continental' => \&continental_grouping,
	 );
}

# -----[ igen_init_traffic_methods ]---------------------------------
#
# -------------------------------------------------------------------
sub igen_init_traffic_methods()
{
    %igen_traffic_methods=
	(
	 'fixed' => \&graph_TM_fixed,
	 'rand-uniform' => \&graph_TM_random_uniform,
	 'rand-pareto' => \&graph_TM_random_pareto,
	 );
}

# -----[ igen_init_igp_methods ]-------------------------------------
#
# -------------------------------------------------------------------
sub igen_init_igp_methods()
{
    %igen_igp_methods=
	(
	 '<none>' => undef,
	 'fixed' => \&graph_igp_fixed,
	 'distance' => \&graph_igp_distance,
	 'invert-capacity' => \&graph_igp_invert_capacity,
	 'rand-uniform' => \&graph_igp_rand_uniform,
	 );
}

# -----[ igen_init_capacity_methods ]--------------------------------
#
# -------------------------------------------------------------------
sub igen_init_capacity_methods()
{
    %igen_capacity_methods=
	(
	 '<none>' => undef,
	 'fixed' => \&graph_capacity_fixed,
	 'access-backbone' => \&graph_capacity_access_bb,
	 'load' => \&graph_capacity_load,
	 );
}

# -----[ igen_init_measure_methods ]---------------------------------
#
# -------------------------------------------------------------------
sub igen_init_measure_methods()
{
    %igen_measure_methods= 
	(
	 'betweenness-centrality' => \&gui_measure_betweenness_centrality,
	 'cell-density' => \&gui_measure_cell_density,
	 'domains-cell-density' => \&gui_measure_internet_cell_density,
#	 'clustering-coefficient' => \&graph_measure_clust_coefficient,
	 'edge-connectivity' => \&gui_measure_edge_connectivity,
	 'distance-distrib' => \&gui_measure_vertex_distance,
	 'domains-continents' => \&gui_measure_domains_continents,
	 'domains-same-pops' => \&gui_measure_domains_same_pops,
	 'domains-diameters' => \&gui_measure_domains_diameters,
	 'domains-sizes' => \&gui_measure_domains_sizes,
	 'adjacency-radius' => \&gui_measure_adjacency_radius,
	 'fast-reroute' => \&gui_measure_fast_reroute,
	 'hop-count' => \&gui_measure_hop_counts,
	 'info' => \&graph_measure_info,
	 'igp-dist-correl' => \&graph_measure_igp_dist_correl,
	 'igp-capa-correl' => \&graph_measure_igp_capa_correl,
	 'link-utilization' => \&gui_measure_link_utilization,
	 'max-throughput' => \&gui_measure_throughput,
	 'node-degree' => \&gui_measure_node_degree,
	 'path-diversity' => \&gui_measure_path_diversity,
	 'path-length' => \&gui_measure_path_length,
	 'path-weight' => \&gui_measure_path_weights,
	 'internet-x-y-correlation' => \&gui_measure_internet_x_y_correlation,
	 );
}

# -----[ igen_init_filters ]-----------------------------------------
# Define supported import/export filters
# -------------------------------------------------------------------
sub igen_init_filters()
{
    %igen_filters=
	(
	 'BRITE' => [IGen::FilterBRITE->new(), ['.brite']],
	 'CBGP' => [IGen::FilterCBGP->new(), ['.cli']],
	 'GML' => [IGen::FilterGML->new(), ['.gml']],
	 'GMT' => [IGen::FilterGMT->new()],
	 'ISIS' => [IGen::FilterISIS->new()],
	 'MaxMind' => [IGen::FilterMaxMind->new(), ['.csv']],
	 'Merindol' => [IGen::FilterMerindol->new(), ['.merindol']],
	 'NTF' => [IGen::FilterNTF->new(), ['.ntf']],
	 'POPS' => [IGen::FilterPOPS->new(), ['.pops']],
	 'RIG' => [IGen::FilterRIG->new(), ['.rig']],
	 'TOTEM' => [IGen::FilterTOTEM->new(), ['.xml']],
	 );

    # Build hashtable to lookup filters by extension
    %igen_filters_extensions= ();
    foreach my $filter_name (keys %igen_filters) {
	my $filter= $igen_filters{$filter_name};
	my $extensions= $filter->[1];
	if (!defined($extensions)) {
	    $extensions= $filter->[0]->{extensions};
	    if (!defined($extensions)) {
		print STDERR "Warning: no extension provided for filter ".
		    "\"$filter_name\"\n";
		next;
	    }
	}
	foreach my $ext (@$extensions) {
	    if (exists($igen_filters_extensions{$ext})) {
		print STDERR "Warning: duplicate filter for extension ".
		    "\"$ext\"\n";
	    }
	    $igen_filters_extensions{$ext}= $filter->[0];
	}
    }
}


#####################################################################
#
# COMPLETE NETWORK BUILDING METHOD
#
#####################################################################

# -----[ graph_build_clusters ]--------------------------------------
#
# -------------------------------------------------------------------
sub graph_build_clusters($$)
{
    my ($graph, $spec)= @_;
    my $clusters;
    
    my @spec_fields= split /\:/, $spec;
    my $method= shift @spec_fields;

    if (exists($igen_clustering_methods{$method})) {
	my $clust_fct= $igen_clustering_methods{$method};

	if (defined($clust_fct)) {
	    $clusters= &$clust_fct($graph, @spec_fields);
	} else {
	    gui_dialog_error("unknown clustering method [$method]");
	    return undef;
	}

    } else {
	gui_dialog_error("unknown clustering method [$method]");
	return undef;
    }

    return $clusters;
}

# -----[ graph_build_pop ]-------------------------------------------
# Build a POP with a Sprint-like structure. The POP is composed of
# backbone and access routers. Backbone routers are densely connected
# together with a clique or a tour). Access routers are connected to
# at least M backbone routers.
#
# Arguments:
#   N : number of backbone nodes (> 0)
#   M : number of links from access router to BB router (> 0)
#   BB-structure : structure of mesh between the POP's BB routers
#                  (clique or tour)
# -------------------------------------------------------------------
sub graph_build_pop($$$)
{
    my ($graph, $N, $M)= @_;
    my @vertices= $graph->vertices();
    my @bb_vertices= ();

    # Both N and M must be > 0
    (($N <= 0) || ($M <= 0)) and die;

    # (1). Select N routers as backbone nodes
    if ($N > $graph->vertices()) {
	# All routers are backbone nodes
	@bb_vertices= @vertices;
	@vertices= ();
    } else {
	# Select centroid, then next centroid, ... (metric is distance)
	my @center= graph_center($graph);
	my @central_vertices= sort {
	  UCL::Graph::Base::pt_distance(\@center, $graph->get_attribute(UCL::Graph::ATTR_COORD, $b)) <=>
	      UCL::Graph::Base::pt_distance(\@center, $graph->get_attribute(UCL::Graph::ATTR_COORD, $a))
	} @vertices;
	for (my $i= 0; $i < $N; $i++) {
	    push @bb_vertices, (pop @central_vertices);
	}
	@vertices= @central_vertices;
    }

    # (2). Generate backbone structure (clique/tour between backbone
    # nodes)
    my $BB_graph= graph_extract_subgraph($graph, \@bb_vertices);
    graph_add_subgraph($graph, UCL::Graph::Generate::clique($BB_graph));
    foreach my $bb (@bb_vertices) {
	$graph->set_attribute(UCL::Graph::ATTR_TYPE, $bb, 'backbone');
    }

    # (3). Generate access links (each access router connected to at
    # least M backbone routers)
    foreach my $access (@vertices) {
	$graph->set_attribute(UCL::Graph::ATTR_TYPE, $access, 'access');
	# Sort backbone routers according to distance to current
	# access router
	my @bb_routers= sort {
	    UCL::Graph::Base::distance($graph, $access, $b) <=>
	      UCL::Graph::Base::distance($graph, $access, $a)
	} @bb_vertices;
	for (my $i= 0; $i < $M; $i++) {
	    my $bb_vertex= pop @bb_routers;
	    (defined($bb_vertex)) or last;
	    $graph->add_edge($access, $bb_vertex);
	}
    }

    return $graph;
}

# -----[ graph_build_mesh ]------------------------------------------
#
# -------------------------------------------------------------------
sub graph_build_mesh($$)
{
    my ($graph, $mesh_spec)= @_;
    my $mesh;

    my @mesh_spec_fields= split /\:/, $mesh_spec;
    my $method= shift @mesh_spec_fields;

    if (exists($igen_mesh_methods{$method})) {
	my $mesh_fct= $igen_mesh_methods{$method};

	if (defined($mesh_fct)) {
	    $mesh= &$mesh_fct($graph, @mesh_spec_fields);
	} else {
	    gui_dialog_error("unknown mesh method [$method]");
	    return undef;
	}

    } else {
	gui_dialog_error("unknown mesh method [$method]");
	return undef;
    }

    return $mesh;
}

# -----[ graph_assign_weights ]--------------------------------------
#
# -------------------------------------------------------------------
sub graph_assign_weights($$)
{
    my ($graph, $spec)= @_;

    my @spec_fields= split /\:/, $spec;
    my $method= shift @spec_fields;

    if (exists($igen_igp_methods{$method})) {
	my $igp_fct= $igen_igp_methods{$method};

	if (defined($igp_fct)) {
	    (&$igp_fct($graph, @spec_fields)) and return -1;
	}

    } else {
	gui_dialog_error("unknown igp-assignment [$method]");
	return -1;
    }

    return 0;
}

# -----[ graph_assign_capacities ]-----------------------------------
#
# -------------------------------------------------------------------
sub graph_assign_capacities($$)
{
    my ($graph, $spec)= @_;

    my @spec_fields= split /\:/, $spec;
    my $method= shift @spec_fields;

    if (exists($igen_capacity_methods{$method})) {
	my $capacity_fct= $igen_capacity_methods{$method};

	if (defined($capacity_fct)) {
	    (&$capacity_fct($graph, @spec_fields)) and return -1;
	}

    } else {
	gui_dialog_error("unknown capacity-assignment [$method]");
	return -1;
    }

    return 0;
}

# -----[ graph_build_network ]---------------------------------------
#
# -------------------------------------------------------------------
sub graph_build_network($$$$$$)
{
    my ($graph, $cluster_spec, $bb_spec, $pop_spec, $igp_spec, $capa_spec)= @_;
    my @bb_nodes= ();
    my $network= Graph::Undirected->new();
    $network->set_attribute(UCL::Graph::ATTR_TM,
			    $graph->get_attribute(UCL::Graph::ATTR_TM));
    $network->set_attribute(UCL::Graph::ATTR_AS,
			    $graph->get_attribute(UCL::Graph::ATTR_AS));
    $network->set_attribute(UCL::Graph::ATTR_GFX,
			    $graph->get_attribute(UCL::Graph::ATTR_GFX));

    # ---| Build clusters |---
    my $clusters= graph_build_clusters($graph, $cluster_spec->{spec});
    $network->set_attribute(UCL::Graph::ATTR_CLUSTERS, $clusters);
    if ($cluster_spec->{show}) {
	gui_menu_show_clusters();
    }

    # ---| Build POPs |---
    my @pop_spec_fields= split /\:/, $pop_spec->{mesh};
    foreach my $cluster (@$clusters) {
	my @vertices= keys %{$cluster->[1]};
	my $pop_graph= graph_extract_subgraph($graph, \@vertices);
	$pop_graph= graph_build_pop($pop_graph,
				    $pop_spec_fields[1],
				    $pop_spec_fields[2]);
	(!defined($pop_graph)) and return undef;
	foreach my $u ($pop_graph->vertices()) {
	    if ($pop_graph->has_attribute(UCL::Graph::ATTR_TYPE, $u) &&
		($pop_graph->get_attribute(UCL::Graph::ATTR_TYPE, $u) eq
		 'backbone')) {
		push @bb_nodes, ($u);
	    }
	}
	graph_add_subgraph($network, $pop_graph);
    }

    # ---| Build backbone |---
    my $bb_graph= graph_extract_subgraph($graph, \@bb_nodes);
    my $mesh= graph_build_mesh($bb_graph, $bb_spec->{mesh});
    (!defined($mesh)) and return undef;
    graph_add_subgraph($network, $mesh);

    # ---| Assign IGP weights |---
    (graph_assign_weights($network, $igp_spec)) and return undef;

    # ---| Assign capacities |---
    (graph_assign_capacities($network, $capa_spec)) and return undef;

    return $network;
}


#####################################################################
#
# COMPLETE INTERDOMAIN GRAPH BUILDING METHOD
#
#####################################################################

# -----[ graphs_add_vertex ]-----------------------------------------
sub graphs_add_vertex($$$)
{
    my ($igraph, $u, $u_graph)= @_;

    my $u_as= $u_graph->get_attribute(UCL::Graph::ATTR_AS);
    my $u_id= "$u_as:$u";

    $igraph->add_vertex($u_id);
    $igraph->set_attribute(UCL::Graph::ATTR_AS, $u_id, $u_as);
    if ($u_graph->get_attribute(UCL::Graph::ATTR_COORD, $u)) {
	my $u_coord= $u_graph->get_attribute(UCL::Graph::ATTR_COORD, $u);
	$igraph->set_attribute(UCL::Graph::ATTR_COORD, $u_id, $u_coord);
    }
}

# -----[ graphs_add_edge ]-------------------------------------------
sub graphs_add_edge($$$$$$)
{
    my ($igraph, $u, $u_graph, $v, $v_graph, $relation)= @_;

    my $u_as= $u_graph->get_attribute(UCL::Graph::ATTR_AS);
    my $u_id= "$u_as:$u";
    my $v_as= $v_graph->get_attribute(UCL::Graph::ATTR_AS);
    my $v_id= "$v_as:$v";

    (!$igraph->has_edge($u_id, $v_id)) and
	$igraph->delete_edge($u_id, $v_id);
    $igraph->add_edge($u_id, $v_id);
    $igraph->set_attribute(UCL::Graph::ATTR_RELATION,
			   $u_id, $v_id, $relation);
}

# -----[ graphs_connect_two_domains ]--------------------------------
#
# -------------------------------------------------------------------
sub graphs_connect_two_domains($$$$$)
{
    my ($igraph, $graph_1, $graph_2, $relation, $num_links)= @_;

    # Copy lists of vertices
    my @vertices_1= $graph_1->vertices();
    my @vertices_2= $graph_2->vertices();

    my $as_1= $graph_1->get_attribute(UCL::Graph::ATTR_AS);
    my $as_2= $graph_2->get_attribute(UCL::Graph::ATTR_AS);

    # Repeat until N interdomain links are added
    while ($num_links > 0) {

	# Find the closest nodes in AS1 and AS2
	my $best_dist= undef;
	my @best_pair= undef;
	my @best_pair_index= undef;
	for (my $i= 0; $i < scalar(@vertices_1); $i++) {
	    my $vertex_i= $vertices_1[$i];
	    my $coord_i= $graph_1->get_attribute(UCL::Graph::ATTR_COORD,
						 $vertex_i);
	    
	    for (my $j= 0; $j < scalar(@vertices_2); $j++) {
		my $vertex_j= $vertices_2[$j];
		my $coord_j= $graph_2->get_attribute(UCL::Graph::ATTR_COORD,
						 $vertex_j);

		my $dist= UCL::Graph::Base::pt_distance($coord_i, $coord_j);
		
		if (($best_dist == undef) ||
		    ($best_dist > $dist)) {
		    $best_dist= $dist;
		    @best_pair= ($vertex_i, $vertex_j);
		    @best_pair_index= ($i, $j);
		}
	    }
	}

	(!defined($best_dist)) and last;

	#print "connect $best_pair[0] and $best_pair[1]".
	#    " (dist: $best_dist) : relation: [$relation]\n";

	my $src= $as_1.':'.$best_pair[0];
	my $dst= $as_2.':'.$best_pair[1];

	# ---| Add interdomain link |---
	graphs_add_vertex($igraph, $best_pair[0], $graph_1);
	graphs_add_vertex($igraph, $best_pair[1], $graph_2);
	graphs_add_edge($igraph,
			$best_pair[0], $graph_1,
			$best_pair[1], $graph_2,
			$relation);
	
	# ---| Remove those clusters from the search |---
	splice @vertices_1, $best_pair_index[0], 1;
	splice @vertices_2, $best_pair_index[1], 1;
	
	$num_links--;
	
    }
    return 0;
}

# -----[ graphs_build_domains ]--------------------------------------
#
# -------------------------------------------------------------------
sub graphs_build_domains($)
{
    my ($graphs)= @_;
    my %built_domains= ();
    my $progress= new UCL::Progress;
    $progress->{message}= "Building domains";
    $progress->{verbose}= 1;
    $progress->{pace}= 0;
    $progress->{percent}= 1;

    my $cnt= 0;
    foreach my $as (keys %$graphs) {
	$progress->bar($cnt, scalar(keys %$graphs), 20, sprintf("AS%.5s    ", $as));
	my $network= graph_build_network($graphs->{$as},
					 {'spec'=>'k-medoids:10'},
					 {'mesh'=>'delaunay'},
					 {'mesh'=>'sprint:2:2'},
					 'distance:0',
					 'access-backbone:155M:10G');
	(!defined($network)) and return undef;
	$built_domains{$as}= $network;
	$cnt++;
    }
    $progress->{pace}= 0;
    $progress->bar($cnt, scalar(keys %$graphs), 20, "done         \n");
    return \%built_domains;
}

# -----[ graphs_connect_domains ]------------------------------------
#
# -------------------------------------------------------------------
sub graphs_connect_domains($$$)
{
    my ($graphs, $relations, $num_links)= @_;
    my $igraph= Graph::Directed->new();

    my $progress= new UCL::Progress;
    $progress->{message}= "Connecting domains";
    $progress->{verbose}= 1;
    $progress->{pace}= 1;
    $progress->{percent}= 1;

    # ---| Determine size of largest domain |---
    my @ases= keys %$graphs;
    my $max_size= undef;
    for (my $i= 0; $i < scalar(@ases); $i++) {
	my $size= scalar($graphs->{$ases[$i]}->vertices());
	(!defined($max_size) || ($size > $max_size)) and
	    $max_size= $size;
    }
    (!defined($max_size)) and return undef;

    # ---| Connect domains together |---
    my $cnt= 0;
    my @edges= $relations->edges();
    my $total= scalar(@edges)/2;
    for (my $i= 0; $i < scalar(@edges)/2; $i++) {
	my $as_i= $edges[$i*2];
	my $as_j= $edges[$i*2+1];

	(!exists($graphs->{$as_i}) ||
	 !exists($graphs->{$as_j})) and
	 next;

	# Determine the number of links to establish between these
	# domains
	my $n_links= $num_links;
	if ($n_links == 0) {
	    # ---| Determine number of links automatically |---
	    my $max_links= 10;
	    my $size_i= scalar($graphs->{$as_i}->vertices());
	    my $size_j= scalar($graphs->{$as_j}->vertices());
	    $n_links= 1+($size_i*$size_j)/($max_size*$max_size)*($max_links-1);
	}
	
	$progress->bar($cnt, $total, 20, sprintf("AS%.5s - AS%.5s        ",
						 $as_i, $as_j));
	
	if ($relations->has_edge($as_i, $as_j)) {
	    my $relation=
		$relations->get_attribute(UCL::Graph::ATTR_RELATION,
					  $as_i, $as_j);
	    my $result= graphs_connect_two_domains($igraph,
						   $graphs->{$as_i},
						   $graphs->{$as_j},
						   $relation,
						   $n_links);
	    ($result < 0) and return undef;
	}
	$cnt++;
    }
    $progress->{pace}= 0;
    $progress->bar($cnt, $total, 20, "done                       \n");

    return $igraph;
}

# -----[ graphs_build_internet ]-------------------------------------
#
# -------------------------------------------------------------------
sub graphs_build_internet($$)
{
    my ($graphs, $as_relations, $num_links)= @_;

    # ---| Build each domain |---
    #my $internet= $graphs;
    my $internet= graphs_build_domains($graphs);
    (!defined($internet)) and return undef;

    # ---| Connect all domains together |---
    my $igraph= graphs_connect_domains($internet, $as_relations, $num_links);
    (!defined($igraph)) and return undef;

    # ---| Connectivity check |---
    # To be provided...

    # ---| Update main graph |---
    $db_graph->{igraph}= $igraph;
    $db_graph->{as2graph}= $internet;
}


#####################################################################
#
# DATA DISPLAY FUNCTIONS
#
#####################################################################


#####################################################################
#
# TEST FUNCTIONS
#
#####################################################################

# -----[ gui_clear_lattice ]-----------------------------------------
#
# -------------------------------------------------------------------
sub gui_clear_lattice()
{
    $GUI{Canvas}->delete('lattice');
}

# -----[ gui_draw_lattice_cell ]-------------------------------------
#
# -------------------------------------------------------------------
sub gui_draw_lattice_cell($$$$)
{
    my ($x, $y, $dx, $dy)= @_;

    my $square= [[$x, $y],
		 [$x+$dx, $y],
		 [$x+$dx, $y+$dy],
		 [$x, $y+$dy]];

    my $color= 'gray';
    for my $polygon (values %igen_continents)  {
	if (poly_square_intersect($square, $polygon)) {
	    $color= undef;
	    last;
	}
    }

    my $canvas= $GUI{Canvas};
    $canvas->createRectangle(gui_x2screen($canvas, $x),
				  gui_y2screen($canvas, $y),
				  gui_x2screen($canvas, $x+$dx),
				  gui_y2screen($canvas, $y+$dy),
				  -fill=>$color,
				  -tags=>['lattice'],
				  );
}

# -----[ gui_draw_lattice ]------------------------------------------
#
# -------------------------------------------------------------------
sub gui_draw_lattice($$$$$$)
{
    my ($min_x, $min_y, $dx, $dy, $n_x_cells, $n_y_cells)= @_;
    my $canvas= $GUI{Canvas};

    for (my $i= 0; $i < $n_x_cells; $i++) {
	for (my $j= 0; $j < $n_y_cells; $j++) {
	    gui_draw_lattice_cell($min_x+$dx*$i,
				  $min_y+$dy*$j,
				  $dx,
				  $dy);
	}
    }
}

# -----[ igen_test ]-------------------------------------------------
sub igen_test($)
{
    my ($param_str)= @_;

    my @params= split /\:/, $param_str;
#    my @bounds= poly_bounds($igen_continents{'Europe_Asia:'});
#    db_graph_add(gen_points($bounds[0], $bounds[1], $bounds[2], $bounds[3],
#			    200, 10, 10));
#
#    return;
#    (scalar(@params) < 2) and
#	die "not enough parameters for the --test mode";
#    my $filename= shift @params;
#
#    #---| Test Pareto distribution generation |---
#    my $n= 100000;
#    my $shape= 1;
#    my $scale= 1;
#    my @array= ();
#    my $total= 0;
#    for (my $i= 0; $i < $n; $i++) {
#	my $value;
#	#$value= IGen::Random::zipf($params[0], $params[1]);
#	$value= IGen::Random::pareto($params[0], $params[1]);
#	#$value= IGen::Random::normal();
#
#	push @array, ($value);
#	$total+= $value;
#    }
#
#    my $stat= Statistics::Descriptive::Full->new();
#    $stat->add_data(@array);
#    $stat->frequency_distribution($stat->max());
#    gui_show_statistics($stat, -plottitle=>"Test-distribution");

    if (scalar(@params) < 5) {
	gui_dialog_error("Not enough parameters for test");
	return -1;
    }
    my $num_graphs= $params[0];
    my $file_prefix= $params[1];
    my $alpha= $params[2];
    my $beta= $params[3];
    my $m= $params[4];
    my $graph= db_graph_get_current_as();
    (!defined($graph)) and return -1;
    my $progress= new UCL::Progress();
    $progress->{message}= 'Building graphs ';
    $progress->{pace}= 1;
    $progress->{percent}= 1;
    my $cnt= 0;
    for (my $i= 0; $i < $num_graphs; $i++) {
	my $waxman= graph_waxman($graph, $alpha, $beta, $m,
				 WAXMAN_ALL());
	$progress->bar($i, $num_graphs, 20);
	my $filter= new IGen::FilterGML();
	$filter->export_graph($waxman, "$file_prefix$i.gml");
    }
    $progress->reset();
    $progress->bar($num_graphs, $num_graphs, 20);
    print "\n";
    return 0;
}

# -----[ graph_measure_cell_density ]--------------------------------
# Count the number of vertices in cells for the given graph.
# -------------------------------------------------------------------
sub graph_measure_cell_density($$$)
{
    my ($graph, $dx, $dy)= @_;

    my ($min_x, $min_y, $max_x, $max_y)=
	UCL::Graph::Base::bounds($graph);

    my $delta_x= $max_x-$min_x;
    my $delta_y= $max_y-$min_y;
    my $n_x_cells= int($delta_x/$dx);
    my $n_y_cells= int($delta_y/$dy);
    (($n_x_cells > 0) && ($n_y_cells > 0)) or
	return undef;
    my $dx= $delta_x/$n_x_cells;
    my $dy= $delta_y/$n_y_cells;

    # ---| Initialize per-cell count |---
    my @cells= ();
    for (my $i= 0; $i < $n_x_cells*$n_y_cells; $i++) {
	$cells[$i]= 0;
    }

    # ---| Add each vertex in corresponding cell |---
    my @vertices= $graph->vertices();
    for my $v (@vertices) {
	my $coord= $graph->get_attribute(UCL::Graph::ATTR_COORD, $v);
	my $i= int(($coord->[0]-$min_x)/$dx);
	my $j= int(($coord->[1]-$min_y)/$dy);
	$cells[$i*$n_y_cells+$j]++;
    }

    # ---| Compute statistics |---
    my $stat= new Statistics::Descriptive::Full();
    $stat->add_data(\@cells);
    my @bins= ();
    for (my $i= 0; $i <= $stat->max(); $i++) {
	push @bins, ($i);
    }
    $stat->frequency_distribution(\@bins);
    return $stat;
}

# -----[ graph_measure_betweenness_centrality ]----------------------
# This function computes the betweenness centrality of the given
# graph. The betweenness centrality is defined here as the
# distribution of the number of shortest-paths that pass through each
# vertex/edge of the graph.
#
# Arguments:
#   graph
#
# Return value:
#   statistics based on the array of SP counts.
# -------------------------------------------------------------------
sub graph_measure_betweenness_centrality($)
{
    my ($graph) =@_;
    my %edges_path_count= ();
    my %vertices_path_count= ();

    # Compute Routing Matrix (RM). Use the cached SPT if available.
    my $RM;
    ($graph->has_attribute(UCL::Graph::ATTR_RM)) and
	$RM= $graph->get_attribute(UCL::Base::ATTR_RM());
    (!defined($RM)) and
	$RM= graph_APSP($graph, $global_options->{ecmp},
			\&graph_dst_fct_weight);

    # Initialize...
    foreach ($graph->vertices()) {
	$vertices_path_count{$_}= 0;
    }
    my @edges= $graph->edges();
    while (my ($u, $v)= splice(@edges, 0, 2)) {
	$edges_path_count{$u}{$v}= 0;
    }

    # Compute vertex/edge betweenness-centrality:
    # -------------------------------------------
    # For each pair of vertices (u, v)
    #   S(u,v) is the number of shortest paths from u to v
    #   for each vertex i (different from u and v) on the path,
    #     increase by 1/S(u,v)
    #   for each edge (i,j) on the path,
    #     increase by 1/S(u,v)
    # Note: for edges (i,j) should we avoid to include the case where
    #       j=v ? NO, since (i,j) will be crossed by a path
    my $total_num_paths= 0;
    foreach my $u (keys %$RM) {
	foreach my $v (keys %{$RM->{$u}}) {
	    die "path from $u to $v" if ($u == $v);
	    my $paths= $RM->{$u}->{$v};
	    if (!defined($paths) || (@$paths == 0)) {
		print "warning: no route from $u to $v\n";
		next;
	    }
	    my $num_paths= scalar(@$paths);
	    foreach my $path (@$paths) {
		if (@$path <= 1) {
		    print "warning: incomplete path from $u to $v\n";
		    next;
		}
		for (my $t= 1; $t < @$path; $t++) {
		    my $i= $path->[$t-1];
		    my $j= $path->[$t];
		    # Contribution to vertex i
		    ($j != $v) and
			$vertices_path_count{$j}+= 1/$num_paths;
		    # Contribution to edge (i,j) regardless of direction
		    if (exists($edges_path_count{$i}{$j})) {
			$edges_path_count{$i}{$j}+= 1/$num_paths;
		    } elsif (exists($edges_path_count{$j}{$i})) {
			$edges_path_count{$j}{$i}+= 1/$num_paths;
		    } else {
			die;
		    }
		}
		$total_num_paths++;
	    }
	}
    }

    return (\%vertices_path_count, \%edges_path_count);
}

# -----[ graphs_measure_cell_num_domains ]---------------------------
# Count the number of domains present in cells.
#
# Arguments:
#  - interdomain graph
#  - nx: number of cells in x dimension
#  - ny: number of cells in y dimension
# -------------------------------------------------------------------
sub graphs_measure_cell_num_domains($$$)
{
    my ($graphs, $nx, $ny)= @_;

    my $min_x= XOFFSET();
    my $min_y= YOFFSET();
    my $delta_x= XBOUND();
    my $delta_y= YBOUND();
    my $dx= $delta_x/$nx;
    my $dy= $delta_y/$ny;

    # ---| Initialize per-cell count |---
    my @cells= ();
    for (my $i= 0; $i < $nx*$ny; $i++) {
	# each cell contains a hashtable
	$cells[$i]= {};
    }

    # ---| Add the domain of each vertex in corresponding cell |---
    my $progress= new UCL::Progress();
    $progress->{message}= 'Computing distances ';
    $progress->{pace}= 1;
    $progress->{percent}= 1;
    my $total= scalar(values %$graphs);
    my $cnt= 0;
    foreach my $graph (values %$graphs) {
	my @vertices= $graph->vertices();
	for my $v (@vertices) {
	    my $coord= $graph->get_attribute(UCL::Graph::ATTR_COORD, $v);
	    my $domain= $graph->get_attribute(UCL::Graph::ATTR_AS, $v);
	    my $i= int(($coord->[0]-$min_x)/$dx);
	    my $j= int(($coord->[1]-$min_y)/$dy);
	    my $index= $i*$ny+$j;
	    ($index >= $nx*$ny) and
		die "cell [ $index ] is accessed (x:".
		($coord->[0]-$min_x).",y:".($coord->[1]-$min_y).
		",nx:$nx,ny:$ny,i:$i,j:$j)";
	    $cells[$index]->{$domain}= 1;
	}
	$progress->bar($cnt, $total, 20);
	$cnt++;
    }
    $progress->reset();
    $progress->bar($cnt, $total, 20);
    print "\n";

    # ---| Initialize per-cell count |---
    my @cells_array= ();
    for (my $i= 0; $i < $nx*$ny; $i++) {
	# each cell contains a hashtable
	my $count= scalar(keys %{$cells[$i]});
	($count > 0) and
	    push @cells_array, ($count);
    }

    # ---| Compute statistics |---
    my $stat= new Statistics::Descriptive::Full();
    $stat->add_data(\@cells_array);
    my @bins= ();
    for (my $i= 0; $i <= $stat->max(); $i++) {
	push @bins, ($i);
    }
    $stat->frequency_distribution(\@bins);
    return $stat;
}

# -----[ lattice_from_cell ]-----------------------------------------
# Compute the lattice dimensions
# -------------------------------------------------------------------
sub lattice_from_cell($$$$$$)
{
    my ($min_x, $min_y, $delta_x, $delta_y, $dx, $dy)= @_;
    my ($_min_x, $_min_y, $_n_x_cells, $_n_y_cells);

    # ---| Compute number of cells |---
    $_n_x_cells= int($delta_x/$dx);
    $_n_y_cells= int($delta_y/$dy);

    # ---| Adjust number of cells |---
    ($_n_x_cells*$dx < $delta_x) and
	$_n_x_cells++;
    ($_n_y_cells*$dy < $delta_y) and
	$_n_y_cells++;

    # ---| Adjust starting bounds (min_x, min_y) |---
    $_min_x= $min_x+($delta_x-$_n_x_cells*$dx)/2;
    $_min_y= $min_y+($delta_y-$_n_y_cells*$dy)/2;
    
    return ($_min_x, $_min_y, $_n_x_cells, $_n_y_cells);
}

# -----[ gui_measure_cell_density ]----------------------------------
sub gui_measure_cell_density(;$$)
{
    my ($dx, $dy)= @_;

    my $graph= db_graph_get_current_as();
    (!defined($graph)) and return -1;

    my ($min_x, $min_y, $max_x, $max_y)=
	UCL::Graph::Base::bounds($graph);
    my $delta_x= $max_x-$min_x;
    my $delta_y= $max_y-$min_y;


    if (!defined($dx) || !defined($dy)) {
	
	my $dialog= IGen::DialogLatticeCellSize->new(-parent=>$GUI{Main},
						     -graph=>$graph,
						     -command=>
						     sub {
							 my ($dx, $dy)=
							     @_;

							 my ($_min_x, $_min_y, $_n_x_cells, $_n_y_cells)= lattice_from_cell($min_x, $min_y, $delta_x, $delta_y, $dx, $dy);
#							 my $n_x_cells= int($delta_x/$dx);
#							 my $n_y_cells=
#							     int($delta_y/$dy);
#							 ($n_x_cells*$dx <
#							  $delta_x) and
#							  $n_x_cells++;
#							 ($n_y_cells*$dy <
#							  $delta_y) and
#							  $n_y_cells++;
							 gui_clear_lattice();
							 gui_draw_lattice($_min_x, $_min_y, $dx, $dy, $_n_x_cells, $_n_y_cells);
						     });
	my $result= $dialog->show_modal();
	$dialog->destroy();
	(!defined($result)) and return 0;
	$dx= $result->{dx};
	$dy= $result->{dy};
    }

    my $stat= graph_measure_cell_density($graph, $dx, $dy);
    (!defined($stat)) and return -1;

    my $dialog= new IGen::DialogShowStatistics(-parent=>$GUI{Main},
					       -stat=>$stat,
					       -title=>"Cell density"
					       -xlabel=>"Number of vertices",
					       -ylabel=>"CDF",
					       -cumulative=>0,
					       -relative=>1,
					       -style=>'boxes',
					       -grid=>1,
					       );
    $dialog->show_modal();
    $dialog->destroy();

    my @stats= ();
    my ($dx, $dy)= (180, 180);
    
    do {
	print "computing density with cell size=($dx, $dy)\n";
	my ($_min_x, $_min_y, $_n_x_cells, $_n_y_cells)=
	    lattice_from_cell($min_x, $min_y, $delta_x, $delta_y, $dx, $dy);
	my $stat= graph_measure_cell_density($graph, $dx, $dy);
	if (defined($stat)) {
	    push @stats, ([$stat, "cell size $dx x $dy (".
			   ($_n_x_cells*$_n_y_cells).")"]);
	}
	$dx= int($dx/2);
	$dy= int($dy/2);
    } while (($dx > 0) && ($dy > 0));

    my $gnuplot= new IGen::Gnuplot(-grid=>1,
				   -xlogscale=>1,
				   -ylogscale=>1,
				   -xlabel=>'Number of locations',
				   -ylabel=>'ICDF');
    my $index= 0;
    foreach (@stats) {
	my $tmp_filename= "/tmp/.igen_gnuplot.$index";
	save_stat_fdistrib($_->[0], $tmp_filename,
			   -cumulative=>1,
			   -relative=>1,
			   -inverse=>1);
	$gnuplot->add_plot($tmp_filename,
			   -style=>'lp',
			   -plottitle=>$_->[1]);
	$index++;
    }
    $gnuplot->plot("test.eps",
		   -term=>'postscript eps "Helvetica" 24');

    return 0;
}

# -----[ gui_measure_internet_x_y_correlation ]----------------------
#
# -------------------------------------------------------------------
sub gui_measure_internet_x_y_correlation(;$)
{
    my $graphs= $db_graph->{as2graph};

    # Measure distribution of X and Y
    my @x_realisations= ();
    my @y_realisations= ();
    foreach my $graph (values %$graphs) {
	my @edges= $graph->vertices();
	foreach my $u (@edges) {
	    my $coord= $graph->get_attribute(UCL::Graph::ATTR_COORD(), $u);
	    my $x= $coord->[0];
	    my $y= $coord->[1];
	    push @x_realisations, ($x);
	    push @y_realisations, ($y);
	}
    }
    my $x_stat= new Statistics::Descriptive::Full();
    $x_stat->add_data(\@x_realisations);
    my $x_frequency= $x_stat->frequency_distribution($x_stat->max());
    my $x_mean= $x_stat->mean();
    my $y_stat= new Statistics::Descriptive::Full();
    $y_stat->add_data(\@y_realisations);
    my $y_frequency= $y_stat->frequency_distribution($y_stat->max());
    my $y_mean= $y_stat->mean();

    # Covariance of X and Y is defined as
    #   Cov(X,Y) = E[(E[X]-X)(E[Y]-Y)]
    # Correlation statistics (rho) is defined as
    #   Corr(X,Y) = ?
    my $corr= new Statistics::Basic::Correlation(\@x_realisations,
						 \@y_realisations);
    print "CORRELATION: ".$corr->query()."\n";
    return 0;
}

# -----[ gui_measure_betweenness_centrality ]------------------------
# This function measures the vertex- and edge-betweenness centrality,
# i.e. how many shortest-paths go through each vertex or edge.
#
# Options:
#   -nonames [1/0]
# -------------------------------------------------------------------
sub gui_measure_betweenness_centrality(;$%)
{
    my ($spec_fields, %spec_args)= @_;
    my $graph= db_graph_get_current_as();
    (!defined($graph)) and return -1;
    my ($v_centrality, $e_centrality)=
	graph_measure_betweenness_centrality($graph);

    if (!exists($spec_args{-vertex}) && !exists($spec_args{-edge})) {
	$spec_args{-vertex}= 1;
	$spec_args{-edge}= 1;
    }

    if (exists($spec_args{-vertex})) {
	# Compute vertices statistics:
	# ----------------------------
	my @array= ();
	my @v_centrality_array= ();
	foreach my $u (keys %$v_centrality) {
	    my $u_name= string2filename($graph->get_attribute(UCL::Graph::ATTR_NAME(),
					      $u));
	    push @v_centrality_array, ([uc($u), uc($u_name),
					$v_centrality->{$u}]);
	    push @array, ($v_centrality->{$u});
	}
	if (exists($spec_args{-distrib})) {
	    my $stat= new Statistics::Descriptive::Full();
	    $stat->add_data(\@array);
	    my @bins= ();
	    for (my $i= 0; $i <= $stat->max(); $i++) { push @bins, ($i); }
	    $stat->frequency_distribution(\@bins);
	    gui_show_statistics($stat,
				-plottitle=>'Vertex betweenness centrality (distribution)',
				-xlabel=>'Centrality',
				-ylabel=>'Number of vertices',
				%spec_args);
	} else {
	    my @v_centrality_sorted=
		sort {$b->[2] <=> $a->[2]} @v_centrality_array;
	    my $i= 0;
	    my @xtics;
	    foreach (@v_centrality_sorted) { push @xtics, ([$i++, $_->[1]]); }
	    my %args= %spec_args;
	    if (!exists($spec_args{-nonames}) || (!$spec_args{-nonames})) {
		$args{-xtics}= \@xtics;
		$args{-xticsfont}= '"Helvetica,12"';
		$args{-xticsrotate}= "by -90 ";
	    }
	    gui_show_data(\@v_centrality_sorted, %args,
			  %spec_args,
			  -plottitle=>'Vertex betweenness-centrality',
			  -index=>':3',
			  -style=>'lp',
#			  -xlabel=>'Vertices',
			  -ylabel=>'Centrality',
			  );
	}
    }
    
    if (exists($spec_args{-edge})) {
	# Compute edges statistics:
	# -------------------------
	my @array= ();
	my @e_centrality_array= ();
	foreach my $u (keys %$e_centrality) {
	    foreach my $v (keys %{$e_centrality->{$u}}) {
		my $u_name= string2filename($graph->get_attribute(UCL::Graph::ATTR_NAME(),
						  $u));
		my $v_name= string2filename($graph->get_attribute(UCL::Graph::ATTR_NAME(),
						  $v));
		push @e_centrality_array, ([uc("$u-$v"), uc("$u_name-$v_name"),
					    $e_centrality->{$u}{$v}]);
		push @array, ($e_centrality->{$u}{$v});
	    }
	}
	if (exists($spec_args{-distrib})) {
	    my $stat= new Statistics::Descriptive::Full();
	    $stat->add_data(\@array);
	    my @bins= ();
	    for (my $i= 0; $i <= $stat->max(); $i++) { push @bins, ($i); }
	    $stat->frequency_distribution(\@bins);
	    gui_show_statistics($stat,
				-plottitle=>'Edge betweenness centrality (distribution)',
				-xlabel=>'Centrality',
				-ylabel=>'Number of edges',
				%spec_args);
	} else {
	    my @e_centrality_sorted=
		sort {$b->[2] <=> $a->[2]} @e_centrality_array;
	    my $i= 0;
	    my @xtics;
	    foreach (@e_centrality_sorted) {
		push @xtics, ([$i++, $_->[1]]);
	    }
	    my %args= %spec_args;
	    if (!exists($spec_args{-nonames}) || (!$spec_args{-nonames})) {
		$args{-xtics}= \@xtics;
		$args{-xticsfont}= '"Helvetica,12"';
		$args{-xticsrotate}= "by -90 ";
	    }
	    gui_show_data(\@e_centrality_sorted, %args,
			  -plottitle=>'edge-betweenness-centrality',
			  -index=>':3',
			  -style=>'lp',
#			  -xlabel=>'Edges',
			  -ylabel=>'Centrality',
			  );
	}
    }

    return 0;
}

# -----[ gui_measure_domains_continents ]----------------------------
#
# -------------------------------------------------------------------
sub gui_measure_domains_continents()
{
    my $stat= graphs_domains_continents($db_graph->{as2graph});
    (!defined($stat)) and return -1;
    gui_show_statistics($stat,
			-plottitle=>"Domains continents",
			-xlabel=>"Diameter",
			-ylabel=>"Fraction of domains",
			-cumulative=>1,
			-relative=>1,
			-inverse=>1);
    return 0;    
}

sub gui_measure_domains_diameters()
{
    my $stat= graphs_domains_diameters($db_graph->{as2graph});
    (!defined($stat)) and return -1;
    gui_show_statistics($stat,
			-plottitle=>"Domains diameters",
			-xlabel=>"Diameter",
			-ylabel=>"Fraction of domains",
			-cumulative=>1,
			-relative=>1,
			-inverse=>1);

    return 0;
}

sub gui_measure_domains_same_pops($;$$)
{
    my ($graph, $nx, $ny)= @_;

    (!defined($nx)) and
	$nx= 10;
    (!defined($ny)) and
	$ny= 10;

    my $stat= graphs_measure_cell_num_domains($db_graph->{as2graph}, $nx, $ny);
    (!defined($stat)) and return -1;
    gui_show_statistics($stat,
			-plottitle=>"Domains same point of presence",
			-xlabel=>"Number of domains",
			-ylabel=>"Cells (points of presence)",
			-cumulative=>1,
			-relative=>1,
			-inverse=>1);
    return 0;    
}

sub gui_measure_domains_sizes()
{
    my $stat= graphs_domains_sizes($db_graph->{as2graph});
    (!defined($stat)) and return -1;
    gui_show_statistics($stat,
			-plottitle=>"Domains sizes");

    return 0;
}

# -----[ internet_measure_cell_density ]-----------------------------
# Count the number of vertices in cells for the given graph.
# -------------------------------------------------------------------
sub internet_measure_cell_density($$)
{
    my ($dx, $dy)= @_;

    my ($min_x, $min_y, $max_x, $max_y)=
	(-180, -90, 180, 90);

    my ($_min_x, $_min_y, $_n_x_cells, $_n_y_cells)=
	lattice_from_cell($min_x, $min_y, 360, 180, $dx, $dy);

    # ---| Initialize per-cell count |---
    my @cells= ();
    for (my $i= 0; $i < $_n_x_cells*$_n_y_cells; $i++) {
	$cells[$i]= 0;
    }

    # ---| Add each vertex in corresponding cell |---
    foreach my $graph (values %{$db_graph->{as2graph}}) {
	my @vertices= $graph->vertices();
	for my $v (@vertices) {
	    my $coord= $graph->get_attribute(UCL::Graph::ATTR_COORD, $v);
	    my $i= int(($coord->[0]-$_min_x)/$dx);
	    my $j= int(($coord->[1]-$_min_y)/$dy);
	    $cells[$i*$_n_y_cells+$j]++;
	}
    }

    # ---| Compute statistics |---
    my $stat= new Statistics::Descriptive::Full();
    $stat->add_data(\@cells);
    my @bins= ();
    for (my $i= 0; $i <= $stat->max(); $i++) {
	push @bins, ($i);
    }
    $stat->frequency_distribution(\@bins);

    return $stat;
}

# -----[ gui_measure_internet_cell_density ]-------------------------
sub gui_measure_internet_cell_density()
{
    my @stats= ();
    my ($dx, $dy)= (180, 180);
    
    do {
	print "computing density with cell size=($dx, $dy)\n";
	my $stat= internet_measure_cell_density($dx, $dy);
	if (defined($stat)) {
	    push @stats, ([$stat, "cell size $dx x $dy"]);
	}
	$dx= int($dx/2);
	$dy= int($dy/2);
    } while (($dx > 0) && ($dy > 0));

    my $gnuplot= new IGen::Gnuplot(-grid=>1,
				   -xlogscale=>1,
				   -ylogscale=>1,
				   -xlabel=>'Number of locations',
				   -ylabel=>'ICDF');
    my $index= 0;
    foreach (@stats) {
	my $tmp_filename= "/tmp/.igen_gnuplot.$index";
	save_stat_fdistrib($_->[0], $tmp_filename,
			   -cumulative=>1,
			   -relative=>1,
			   -inverse=>1);
	$gnuplot->add_plot($tmp_filename,
			   -style=>'lp',
			   -plottitle=>$_->[1]);
	$index++;
    }
    $gnuplot->plot("test.eps",
		   -term=>'postscript eps "Helvetica" 24');

    return 0;
}

# -----| console_dialog_yes_no ]-------------------------------------
# This function asks the user to answer 'yes' or 'no' to a question,
# through the console. If the answer is 'yes', the yes-callback is
# called. If the answer is 'no', the no-callback is called. If the
# answer is empty, the default 'yes' answer is used. If the answer is
# none of 'yes'/'no'/empty, then the user is asked to answer again.
#
# Arguments:
#  - message to display
#  - yes-callback [optional]
#  - no-callback [optional]
#
# Return value:
#  1  if the user answered 'yes'
#  0  if the user answered 'no'
# -------------------------------------------------------------------
sub console_dialog_yes_no($;$$) {
    my ($msg, $yes_cb, $no_cb)= @_;
    my $answer;

    while (1) {
	print STDERR "$msg [YES/no] ";
	$answer= lc(<STDIN>);
	chomp $answer;
	if (($answer eq "") || ($answer eq "yes")) {
	    (defined($yes_cb)) and
		&$yes_cb();
	    return 1;
	} elsif ($answer eq "no") {
	    (defined($no_cb)) and
		&$no_cb();
	    return 0;
	} else {
	    print STDERR "Please answer 'yes' or 'no'\n";
	}
    }
    return undef;
}

# -----| console_dialog_value ]--------------------------------------
# This function asks a value to the user through the console. If the
# answer does not conform to the check-callback, the user is asked to
# re-enter the value.
#
# Arguments:
#  - message to display
#  - default value [optional]
#  - check-callback [optional]
#
# Return value:
#  - the requested value
# -------------------------------------------------------------------
sub console_dialog_value($;$$) {
    my ($msg, $default, $check_cb)= @_;
    my $answer;
    
    while (1) {
	print STDERR "$msg ";
	(defined($default)) and
	    print STDERR "[$default] ";
	$answer= lc(<STDIN>);
	chomp $answer;
	($answer eq "") and
	    $answer= $default;
	(!defined($check_cb) || &$check_cb($answer)) and
	    last;
	print STDERR "The value is invalid. Try again\n";
    }
    return $answer;
}

# -----[ gui_show_statistics ]---------------------------------------
# This function show statistics as handled by the
# Statistics::Descriptive module. The statistics can either been
# displayed through the GUI or through the console. If the statistics
# are to be displayed through the console, summary statistics are
# written and the user is asked for a filename to save the complete
# statistics.
#
# Arguments:
#  - the statistics (Statistics::Descriptive)
#  - arguments for save_stat_fdistrib() and gnuplot() [optional]
#
# Return value:
#  0
#
# Options:
#  -summary  : if set (1), only a summary of the statistics will be
#              printed. The summary includes a name, the mean, the
#              std-dev,  the minimum, the maximum, the median and
#              percentiles 10 and 90.
#  -noprompt : if set (1), user will not be prompted
#  -out      : if set, the provided value will serve as the
#              output file name
# -------------------------------------------------------------------
sub gui_show_statistics($;%)
{
    my ($stat, %args)= @_;

    print "debug[\n";
    foreach (keys %args) {
	print STDERR "$_ => [$args{$_}]\n";
    }
    print "]\n";

    if (defined($GUI{Main})) {
	run IGen::DialogShowStatistics(-parent=>$GUI{Main},
				       -stat=>$stat,
				       %args);
    } else {
	my $title= 'unknown';
	(defined($args{-plottitle})) and
	    $title= string2filename(lc($args{-plottitle}));
	print "# <name> <mean> <std-dev> <min> <max> <median> <p-10> <p-90>\n";
	printf("$title\t%f\t%f\t%f\t%f\t%f\t%f\t%f\n",
	       $stat->mean(), $stat->standard_deviation(),
	       $stat->min(), $stat->max(), $stat->median(),
	       scalar($stat->percentile(10)),
	       scalar($stat->percentile(90)));

	my $file;
	if (!exists($args{-out}) || ($args{-out} =~ m/^\s*$/)) {
	    $file= "stat";
	    (exists($args{-title})) and
		$file.='-'.string2filename(lc($args{-title}));
	    (exists($args{-plottitle})) and
		$file.='-'.string2filename(lc($args{-plottitle}));
	} else {
	    $file= $args{-out};
	}

	if (!exists($args{-summary}) || !$args{-summary}) {
	    if ($args{-noprompt} ||
		console_dialog_yes_no("Save the statistics ?")) {
		my $file_dat= "$file.dat";
		(!$args{-noprompt}) and 
		    $file_dat= console_dialog_value("Destination file ?",
						    $file_dat);
		save_stat_fdistrib($stat, $file_dat, %args);
		if ($args{-noprompt} ||
		    console_dialog_yes_no("Generate Postscript ?")) {
		    my $file_eps= replace_file_ext($file_dat, 'eps');
		    (!$args{-noprompt}) and
			$file_eps= console_dialog_value("Destination file ?",
							"$file_eps");
		    my $gnuplot= new IGen::Gnuplot(%args);
		    $gnuplot->add_plot($file_dat, %args);
		    $gnuplot->plot($file_eps, %args);
		}
	    }
	} else {
	    my $file_dat= "$file.dat";
	    save_stat_fdistrib($stat, $file_dat, %args);	    
	    my $file_eps= replace_file_ext($file_dat, 'eps');
	    my $gnuplot= new IGen::Gnuplot(%args);
	    $gnuplot->add_plot($file_dat, %args);
	    $gnuplot->plot($file_eps, %args);	    
	}
    }
    return 0;
}

# -----[ gui_show_data ]---------------------------------------------
# This function shows an array of data (may be 2-dimensional).
#
# Arguments:
#  - the data array
#  - arguments for save_stat_data() and gnuplot() [optional]
#
# Options:
#  -noprompt : if set (1), user will not be prompted
#  -out      : if set, the provided value will serve as the
#              output file name
#
# TODO: implement the function in case the GUI is used.
# -------------------------------------------------------------------
sub gui_show_data($;%)
{
    my ($data, %args)= @_;

    foreach (keys %args) {
	print "[$_] -> [$args{$_}]\n";
    }
    
    if (defined($GUI{Main})) {
	run IGen::DialogShowData(-parent=>$GUI{Main},
				 -data=>$data,
				 %args);
    } else {
	my $file;
	if (!exists($args{-out}) || ($args{-out} =~ m/^\s*$/)) {
	    $file= "stat";
	    (exists($args{-title})) and
		$file.='-'.string2filename(lc($args{-title}));
	    (exists($args{-plottitle})) and
		$file.='-'.string2filename(lc($args{-plottitle}));
	} else {
	    $file= $args{-out};
	}

	if (!exists($args{-noprompt}) || !$args{-noprompt}) {
	    if (console_dialog_yes_no("Save the data ?")) {
		my $file_dat= console_dialog_value("Destination file ?",
						   "$file.dat");
		save_stat_data($data, $file_dat, %args);
		my $file_eps= replace_file_ext($file_dat, 'eps');
		if (console_dialog_yes_no("Generate Postscript ?")) {
		    $file_eps= console_dialog_value("Destination file ?",
						    "$file_eps");
		    my $gnuplot= new IGen::Gnuplot(%args);
		    $gnuplot->add_plot($file_dat, -index=>':1', %args);
		    $gnuplot->plot($file_eps, %args);
		}
	    }
	} else {
	}
    }
    return 0;    
}

# -----[ poly_square_intersect ]-------------------------------------
# Test if a polygon and a square intersect. The algorithm proceeds as
# follows:
# 1). If one of the vertices of the square belongs to the polygon, the
#     algorithm returns 1.
# 2). If one of the sides of the square intersects the polygon, the
#     algorithm returns 1.
# 3). Test if the square contains the polygon, i.e. if one vertex of
#     the polygon belongs to the square, returns 1.
# 4). Returns 0.
#
# Arguments:
#   - square bounds
#   - polygon
#
# Return value:
#   1  if the square intersects the polygon
#   0  otherwise
# -------------------------------------------------------------------
sub poly_square_intersect($$)
{
    my ($square, $polygon)= @_;

    # ---| Test if the square vertices belong to the polygon |---
    foreach (@$square) {
	(pt_in_poly($_, $polygon)) and return 1;
    }

    # ---| Test if one vertex of the polygon belongs to the square |---
    foreach (@$polygon) {
	(pt_in_poly($_, $square)) and return 1;
    }

    return 0;
}

# -----[ gen_single_point ]------------------------------------------
# Place a single point in the graph. The location of the point is
# generated using a Normal distribution, N(0,1) centered in
# (min_x+dx/2, min_y+dy/2).
#
# Arguments:
#   graph         graph that will contain the new node
#   min_x         offset of the cell
#   min_y
#   dx            size of the cell
#   dy
#   id            the ID of the new node
#   collisions    a reference to a hashtable containing already placed
#                 nodes
# -------------------------------------------------------------------
sub gen_single_point($$$$$$;$)
{
    my ($graph, $min_x, $min_y, $dx, $dy, $id, $collisions)= @_;
    print "num-nodes: ".scalar($graph->vertices())."\n";

    while (1) {
	# ---| Use N(0,1) distribution |---
	my $x= $min_x+$dx/2+IGen::Random::normal()*$dx/2;
	my $y= $min_y+$dy/2+IGen::Random::normal()*$dx/2;
	
	# ---| Check for collisions |---
	(defined($collisions->{$x}{$y})) and
	    next;
	$collisions->{$x}{$y}= $id;

	# ---| Add the node |---
	$graph->add_vertex($id);
	$graph->set_attribute(UCL::Graph::ATTR_COORD, $id, [$x, $y]);
	return ($x, $y);
    }
    
    return undef;
}

# -----[ gen_points ]------------------------------------------------
# Generate a graph with vertices placed according to a Zipf's law. The
# geographical extent of the graph is partitionned in a lattice with
# cells of size (dx, dy). The Zipf's law gives the number of vertices
# that will be placed in each individual cell. For each cell, the
# vertices are placed according to a Normal distribution centered in
# (dx/2, dy/2).
#
# Parameters:
#   min-x   geographical extent of lattice
#   min-y
#   max-x
#   max-y
#   N       maximum number of vertices that will be placed
#           (the tail of the distribution will be cut if required)
#   N-cell  maximum number of vertices / cell
#           (this is used as the parameter 'N' of the Zipf's law)
#   dx      size of a lattice's cell
#   dy
#
# Note: the method works on a projection of the sphere on a plane
# -------------------------------------------------------------------
sub gen_points_zipf($$$$$$$)
{
    my ($min_x, $min_y, $max_x, $max_y, $N, $dx, $dy)= @_;
    my $polygon= $igen_continents{'Africa'};
    (!defined($polygon)) and die "polygon is undefined";
    my %collisions= ();
    my $graph= new Graph::Undirected();
    $graph->set_attribute(UCL::Graph::ATTR_GFX, 1);
    
    # ---| Width and height of geographical area |---
    my $delta_x= $max_x-$min_x;
    my $delta_y= $max_y-$min_y;

    # ---| Number of cells in X/Y |---
    my $n_cells_x= int($delta_x/$dx);
    my $n_cells_y= int($delta_y/$dy);

    # ---| Update (dX, dY) |---
    $dx= $delta_x/$n_cells_x;
    $dy= $delta_y/$n_cells_y;
 
    # ---| Compute number of points in each cell |---
    my @cells;
    my $total= 0;
    for (my $i= 0; $i < $n_cells_x; $i++) {
	for (my $j= 0; $j < $n_cells_y; $j++) {
	    my $k= IGen::Random::zipf(2, 10)-1;
	    push @cells, ([$k, $i, $j]);
	    $total+= $k;
	}
    }
    
    # ---| Sort cells by number of routers |---
    my @sorted_cells= sort {$b->[0] <=> $a->[0]} @cells;
    my $index= 0;
    my $subset_total= 0;
    my $v_index= 0;
    while (($index < scalar(@sorted_cells)) &&
	    ($subset_total < $N)) {
	my $k= $sorted_cells[$index]->[0];
	if ($subset_total < $N) {
	    ($k > $N-$subset_total) and
		$k= $N-$subset_total;
	    $subset_total= $subset_total+$k;
	    my $i= $sorted_cells[$index]->[1];
	    my $j= $sorted_cells[$index]->[2];
	    while ($k > 0) {
		gen_single_point($graph,
				 $min_x+$i*$dx, $min_y+$j*$dy,
				 $dx, $dy, $v_index, \%collisions);
		$v_index++;
		$k--;
	    }	    
	} else {
	    last;
	}
	$index++;
    }
    
    return $graph;
}

# -----[ gui_create_link ]-------------------------------------------
#
# -------------------------------------------------------------------
sub gui_create_link()
{
    my ($graph)= db_graph_get_current_as();
    (!defined($graph)) and return -1;

    my $dialog= new IGen::DialogLinkCreate(-parent=>$GUI{Main},
					   -graph=>$graph);
    my $result= $dialog->show_modal();
    $dialog->destroy();
    
    gui_terminal_add("new link from $result->{router1} to $result->{router2}");
    $graph->add_edge($result->{router1}, $result->{router2});

    return 0;
}

# -----[ gui_compute_rm ]--------------------------------------------
#
# -------------------------------------------------------------------
sub gui_compute_rm() {
  my ($graph)= db_graph_get_current_as();
  (!defined($graph)) and return -1;

  my $RM= graph_APSP($graph, $global_options->{ecmp},
		     \&graph_dst_fct_weight);
  $graph->set_attribute(UCL::Graph::ATTR_RM, $RM);
}
