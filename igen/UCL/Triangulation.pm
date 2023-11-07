# ===================================================================
# Triangulation.pm
#
# author Bruno Quoitin (bqu@info.ucl.ac.be)
# date 17/06/2004
# lastdate 27/06/2004
# ===================================================================
# Note: this implementation is based on the second edition of the book
# entitled "Computational Geometry: Algorithms and Applications" by
# M. de Berg et al.
#
# However, if the book describes the principles of the triangulation
# algorithm, it does not cover the details of the data structure, in
# particular the Directed Acyclic Graph and the Fast Triangle
# Adjacency List. Moreover, some operations on polygons and circles
# were required for the algorithm to work. These operations are
# provided in the side-module UCL::Geometry.pm.
# ===================================================================

package Triangulation;

require Exporter;
@ISA= qw(Exporter);
@EXPORT= qw();
$VERSION= '0.1';

use strict;
use UCL::Geometry;

use constant DEBUG => 0;
use constant INFO => 0;

# -----[ new ]-------------------------------------------------------
# Create a new Triangulation instance.
# -------------------------------------------------------------------
sub new()
{
    my $tri_ref= {
	DAG => [],          # Directed Acyclic Graph used to
                            # maintain the current triangulation
	FTAL => {},         # Fast Triangle Adjacency List, i.e.
	                    # Structure that makes possible a fast
                            # retrieval of the two triangles that
                            # share a given edge.
	points => [],       # Set of points (sites of the Voronoi
                            # diagram)
	npoints => -1,
	it_cb => undef,     # Iteration callback (if defined, it is
                            # called after each iteration of the
                            # computation)
    };
    bless $tri_ref;
    return $tri_ref;
}

# -----[ set_callback ]----------------------------------------------
#
# -------------------------------------------------------------------
sub set_callback($)
{
    my $self= shift;

    $self->{it_cb}= shift;
}

# -----[ triangle2string ]-------------------------------------------
sub triangle2string($)
{
    my $triangle_r= shift;

    return "(".$triangle_r->[0]->[0].",".$triangle_r->[0]->[1].
	")-(".$triangle_r->[1]->[0].",".$triangle_r->[1]->[1].
	")-(".$triangle_r->[2]->[0].",".$triangle_r->[2]->[1].")";
}

# -----[ random_permutation ]----------------------------------------
# Compute a random permutation of the given array (Durstenfeld, 1964,
# CACM).
# -------------------------------------------------------------------
sub random_permutation($)
{
    my $N= shift;
    my @array_out= ();
    
    for (my $i= 0; $i < $N; $i++) {
	$array_out[$i]= $i;
    }

    for (my $i= 0; $i < scalar(@array_out); $i++) {
	my $random_i= int(rand(scalar(@array_out)));
	my $tmp= $array_out[$i];
	$array_out[$i]= $array_out[$random_i]; 
	$array_out[$random_i]= $tmp;
    }
    return \@array_out;
}

# -----[ getTA ]-----------------------------------------------------
# Return the triangles that are adjacent to the given edge. Up to two
# triangles are returned in an array.
#
# Parameters:
# - Pi and Pj, the endpoints of the given edge.
# -------------------------------------------------------------------
sub getTA($$)
{
    my $self= shift;

    my $pi= shift;
    my $pj= shift;

    if (exists($self->{FTAL}{$pi}{$pj})) {
	return $self->{FTAL}{$pi}{$pj};
    } elsif (exists($self->{FTAL}{$pj}{$pi})) {
	return $self->{FTAL}{$pj}{$pi};
    }
    return undef;
}

# -----[ setTA ]-----------------------------------------------------
#
# -------------------------------------------------------------------
sub setTA($$$)
{
    my $self= shift;

    my $pi= shift;
    my $pj= shift;
    my $adj= shift;

    die "Error: setTA with Pi[$pi] == Pj[$pj]" if ($pi == $pj);

    #DEBUG and print "setTA($pi,$pj,[".adjacency_dump($adj)."])\n";

    # Check that both triangles are different
    if (scalar(@$adj) == 2) {
	my @tri0= sort {$a <=> $b} @{$adj->[0]->{triangle}};
	my @tri1= sort {$a <=> $b} @{$adj->[1]->{triangle}};
	my $identical= 1;
	for (my $i= 0; $i < scalar(@tri0); $i++) {
	    if ($tri0[$i] != $tri1[$i]) {
		$identical= 0;
		last;
	    }
	}
	if ($identical) {
	    print STDERR  "Error: triangles are identical\n";
	    return -1;
	}
    }

    $self->{FTAL}{$pi}{$pj}= $adj;
    $self->{FTAL}{$pj}{$pi}= $adj;

    return 0;
}

# -----[ clearTA ]---------------------------------------------------
#
sub clearTA($$)
{
    my $self= shift;

    my $pi= shift;
    my $pj= shift;

    DEBUG and print "clearTA($pi,$pj)\n";

    undef $self->{FTAL}{$pi}{$pj};
    delete $self->{FTAL}{$pi}{$pj};
    undef $self->{FTAL}{$pj}{$pi};
    delete $self->{FTAL}{$pj}{$pi};
}

# -----[ updateTA ]--------------------------------------------------
#
# -------------------------------------------------------------------
sub updateTA($$$$)
{
    my $self= shift;

    my $pi= shift;
    my $pj= shift;
    my $old_adj= shift;
    my $new_adj= shift;

    DEBUG and print "updateTA($pi,$pj,[".triangle_dump($old_adj)." -> ".
	triangle_dump($new_adj)."])\n";

    my $adj= $self->getTA($pi, $pj);
    if (!defined($adj)) {
	print STDERR "Error: missing adjacency\n";
	return -1;
    }

    if (scalar(@$adj) == 1) {
	die "Error: old adjacency mismatch (#1)"
	    if ($adj->[0] != $old_adj);
	$adj->[0]= $new_adj;
    } elsif (scalar(@$adj) == 2) {
	if ($adj->[0] == $old_adj) {
	    $adj->[0]= $new_adj;
	} elsif ($adj->[1] == $old_adj) {
	    $adj->[1]= $new_adj
	} else {
	    print STDERR "updateTA($pi,$pj)\n";
	    print STDERR "old-adj($pi,$pj): ".triangle_dump($old_adj)."\n";
	    print STDERR "new-adj($pi,$pj): ".triangle_dump($new_adj)."\n";
	    print STDERR "adj-0: ".triangle_dump($adj->[0])."\n";
	    print STDERR "adj-1: ".triangle_dump($adj->[1])."\n";
	    die "Error: old adjacency mismatch (#2)";
	}
    } else {
	die "Error: invalid adjacency (size=".scalar(@$adj).")";
    }

    return $self->setTA($pi, $pj, $adj);
}

# -----[ node_get_triangle ]-----------------------------------------
#
# -------------------------------------------------------------------
sub node_get_triangle($)
{
    my $self= shift;

    my $node= shift;
    
    return [
	    $self->{points}->[$node->{triangle}->[0]],
	    $self->{points}->[$node->{triangle}->[1]],
	    $self->{points}->[$node->{triangle}->[2]]
	    ];
}

# -----[ node_new ]--------------------------------------------------
#
# -------------------------------------------------------------------
sub node_new($$$)
{
    my $self= shift;

    my $triangle= shift;
    my $parents= shift;
    my $children= shift;

    return {
	triangle => $triangle,
	parents => $parents,
	children => $children,
    };
}

# -----[ node_remove_from_parents ]----------------------------------
# Remove a node from its parents. Each node has at most two parents.
# -------------------------------------------------------------------
sub node_remove_from_parents($)
{
    my $self= shift;

    my $node= shift;
    
    if (defined($node->{parents})) {
	foreach my $parent (@{$node->{parents}}) {
	    if (defined($parent->{children})) {
		for (my $i= 0; $i < scalar(@{$parent->{children}}); $i++) {
		    if ($parent->{children}->[$i] == $node) {
			splice @{$parent->{children}}, $i, 1;
			last;
		    }
		}
	    }
	}
    }
}

sub triangle_dump($)
{
    my $node= shift;

    return $node->{triangle}->[0].",".
	$node->{triangle}->[1].",".
	$node->{triangle}->[2];
}

sub adjacency_dump($)
{
    my $adj= shift;

    if (!defined($adj)) {
	return "UNDEF";
    } elsif (scalar(@$adj) == 1) {
	return triangle_dump($adj->[0]);
    } elsif (scalar(@$adj) == 2) {
	return triangle_dump($adj->[0])." ; ".triangle_dump($adj->[1]);
    } else {
	return "INVALID";
    }
}

sub dag_dump($$)
{
    my $node= shift;
    my $prefix= shift;

    if (defined($node->{children})) {
	print $prefix."[".triangle_dump($node)."]\n";
	foreach my $child (@{$node->{children}}) {
	    dag_dump($child, "$prefix\t");
	}
    } else {
	print $prefix."*[".triangle_dump($node)."]*\n";
    }
}

# -----[ find_adj_triangles ]----------------------------------------
# Find the triangle adjacent to another triangle along the given
# edge.
#
# Parameters:
# - triangle PiPjPk, we search for the triangle adjacent to PiPj
# -------------------------------------------------------------------
sub find_adj_triangles($$$)
{
    my $self= shift;

    my $pi= shift;
    my $pj= shift;
    my $pr= shift;

    DEBUG and print "*** FIND_ADJ_TRIANGLES PiPjPr ($pi, $pj, $pr) ***\n";

    my $pk= -1; # Point in the adjacent triangle

    # Get the adjacency of edge PiPj. Check that it is defined and
    # that it contains two triangles.
    my $adj= $self->getTA($pi, $pj);
    if (!defined($adj) || (scalar(@$adj) != 2)) {
	DEBUG and print STDERR "Warning: undefined/single adjacency\n";
	return undef;
    }

    if (DEBUG) {
	print "adj0: ".triangle_dump($adj->[0])."\n";
	print "adj1: ".triangle_dump($adj->[1])."\n";
    }

    # Find the triangle that contains Pr and the other triangle
    my $adj_ijr;
    my $adj_ijk;
    if (($pr == $adj->[0]->{triangle}->[0]) ||
	($pr == $adj->[0]->{triangle}->[1]) ||
	($pr == $adj->[0]->{triangle}->[2])) {
	$adj_ijr= $adj->[0];
	$adj_ijk= $adj->[1];
    } else {
	$adj_ijr= $adj->[1];
	$adj_ijk= $adj->[0];
    }

    # Find in the adjacent triangle the vertex that does not belong to
    # the first triangle
    foreach my $vertex (@{$adj_ijk->{triangle}}) {
	if (($vertex != $pi) && ($vertex != $pj)) {
	    $pk= $vertex;
	    last;
	}
    }

    # Check that Pk has been found !
    if ($pk == -1) {
	DEBUG and print STDERR "Warning: could not find Pk !\n";
	return undef;
    }

    # Check that Pk is different from Pr !
    die "Error: Pk[$pk] == Pr[$pr]" if ($pk == $pr);

    return [$adj_ijk, $adj_ijr, $pk];
}
    
# -----[ legalize_edge ]---------------------------------------------
# Test if the edge PiPj is legal or not. In the latter case, legalize
# the edge and recursively test that the potentially changed edges are
# still legal. The algorithm terminates since it strictly increases
# the sum of angles of triangles, which is bounded.
#
# Parameters:
# - Pr, the latest added point
# - Pi and Pj, endpoints of the edge to be legalized
# -------------------------------------------------------------------
sub legalize_edge($$$)
{
    my $self= shift;

    my $pr= shift;
    my $pi= shift;
    my $pj= shift;

    INFO and print "*** LEGALIZE $pr=(".$self->{points}->[$pr]->[0].",".
	$self->{points}->[$pr]->[1].") [$pi,$pj]=(".
	$self->{points}->[$pi]->[0].",".
	$self->{points}->[$pi]->[1].")-(".
	$self->{points}->[$pj]->[0].",".
	$self->{points}->[$pj]->[1].") ***\n";

    if (($pi >= $self->{npoints}) && ($pj >= $self->{npoints})) {

	# In this case, the edge is legal because we must keep the
	# edges of the bounding triangle
	return 0;

    } else {

	# Let PiPjPk be the triangle adjacent to PiPjPr along edge
	# PiPj. We find Pk based on the FTAL
	my $triangles= $self->find_adj_triangles($pi, $pj, $pr);
	die "Error: invalid adjacency for edge PiPj" if (!defined($triangles));
	my $adj_ijk= $triangles->[0];
	my $adj_ijr= $triangles->[1];
	my $pk= $triangles->[2];
	
	if (INFO) {
	    print "Pi[$pi]: (".$self->{points}->[$pi]->[0].",".
		$self->{points}->[$pi]->[1].") ";
	    print "Pj[$pj]: (".$self->{points}->[$pj]->[0].",".
		$self->{points}->[$pj]->[1].") ";
	    print "Pr[$pr]: (".$self->{points}->[$pr]->[0].",".
		$self->{points}->[$pr]->[1].") ";
	    print "Pk[$pk]: (".$self->{points}->[$pk]->[0].",".
		$self->{points}->[$pk]->[1].")\n";
	}

	if (DEBUG) {
	    print "adj(PiPr): ".adjacency_dump($self->getTA($pi,$pr))."\n";
	    print "adj(PrPj): ".adjacency_dump($self->getTA($pr,$pj))."\n";
	    print "adj(PjPk): ".adjacency_dump($self->getTA($pj,$pk))."\n";
	    print "adj(PkPi): ".adjacency_dump($self->getTA($pk,$pi))."\n";
	}

	if (($pi < $self->{npoints}) && ($pj < $self->{npoints}) &&
	    ($pr < $self->{npoints}) && ($pk < $self->{npoints})) {

	    if (Geometry::tri_colinear($self->{points}->[$pi],
				       $self->{points}->[$pr],
				       $self->{points}->[$pk])) {
		INFO and print "WARNING: points Pi, Pr and Pk are colinear, change is not allowed\n";
		return 0;
	    }
	    if (Geometry::tri_colinear($self->{points}->[$pj],
				       $self->{points}->[$pr],
				       $self->{points}->[$pk])) {
		INFO and print "WARNING: points P, Pr and Pk are colinear, change is not allowed\n";
		return 0;
	    }
	    if (Geometry::tri_colinear($self->{points}->[$pi],
				       $self->{points}->[$pj],
				       $self->{points}->[$pr])) {
		INFO and print "WARNING: points Pi, Pj and Pr are colinear, change is not allowed\n";
		return 0;
	    }
	    if (Geometry::tri_colinear($self->{points}->[$pi],
				       $self->{points}->[$pj],
				       $self->{points}->[$pk])) {
		INFO and print "WARNING: points P, Pj and Pk are colinear, change is not allowed\n";
		return 0;
	    }

	    # This is the normal case, i.e. no points of the bounding
	    # triangle are involved.

	    # Test that points Pi, Pj and Pr are ccw-oriented. If so,
	    # the determinant returned by 'pt_in_circle' is positive
	    # if the point Pk is inside. If the points Pi, Pj and Pr
	    # are cw-oriented, the test is inverted and the
	    # determinant is negative if the point Pk is inside the
	    # circle.
	    if (Geometry::pt_is_left($self->{points}->[$pi],
				     $self->{points}->[$pr],
				     $self->{points}->[$pj]) > 0) {
		INFO and print "ok, Pj is at left of PiPr\n";
		if (Geometry::pt_in_circle($self->{points}->[$pi],
					   $self->{points}->[$pr],
					   $self->{points}->[$pj],
					   $self->{points}->[$pk]) > 0) {
		    INFO and print "-> Illegal (Pk is inside circle PiPjPr)\n";
		} else {
		    # Legal (outside of circle)
		    return 0;
		}

	    } else {
		INFO and print "Test inverted\n";
		if (Geometry::pt_in_circle($self->{points}->[$pi],
					   $self->{points}->[$pr],
					   $self->{points}->[$pj],
					   $self->{points}->[$pk]) < 0) {
		    INFO and print "-> Illegal (Pk is inside circle PiPjPr)\n";
		} else {
		    # Legal (outside of circle)
		    return 0;
		}

	    }


	} else {

	    # If the quadrilatere is not convex, do not allow the edge
	    # to be flipped since this can cause an overlap between
	    # triangles
	    if (!Geometry::poly_convex([$self->{points}->[$pi],
					$self->{points}->[$pr],
					$self->{points}->[$pj],
					$self->{points}->[$pk]])) {
		INFO and print "Polygon is not convex, change is not allowed\n";
		return 0;
	    }

	    if (Geometry::tri_colinear($self->{points}->[$pi],
				       $self->{points}->[$pr],
				       $self->{points}->[$pk])) {
		INFO and print "WARNING: points Pi, Pr and Pk are colinear, change is not allowed\n";
		return 0;
	    }
	    if (Geometry::tri_colinear($self->{points}->[$pj],
				       $self->{points}->[$pr],
				       $self->{points}->[$pk])) {
		INFO and print "WARNING: points P, Pr and Pk are colinear, change is not allowed\n";
		return 0;
	    }


	    # This is the "abnormal" case...

	    # Three cases are possible now:
	    # (1) Pk is a special point and one of Pi and Pj is also a
	    #     special point
	    # (2) Pk is a special point and Pi and Pj are normal
	    #     points
	    # (3) one of Pi and Pj is a special point
            #
	    # Indeed, it is not possible that both Pi and Pj are
	    # special points (this case is treated at the beginning of
	    # the method). Furthermore, Pr cannot be a special
	    # point since it has just been added.

	    if ($pk >= $self->{npoints}) {

		if (($pi >= $self->{npoints}) ||
		    ($pj >= $self->{npoints})) {

		    # Case (1)
		    my $neg= undef;
		    if ($pi >= $self->{npoints}) {
			$neg= $pi;
		    } else {
			$neg= $pj;
		    }
		    if ($neg > $pk) {
			# Case (1): Legal
			return 0;
		    } else {
			INFO and print "-> Illegal (1)\n";
		    }

		} else {

		    # Case (2): legal
		    return 0;

		}

	    } else {

		# Case (3): illegal
		INFO and print "-> Illegal (3)\n";

	    }

	}

	INFO and print "Process illegal edge (flip)...\n";

	# Remove the adjacencies from the FTAL
	$self->clearTA($pi, $pj);
	
	# Add new triangles to the DAG. Their parents are the former
	# triangles.
	my $new_irk= $self->node_new([$pi, $pr, $pk],
				     [$adj_ijr, $adj_ijk], undef);
	my $new_jkr= $self->node_new([$pj, $pk, $pr],
				     [$adj_ijr, $adj_ijk], undef);
	DEBUG and print "new triangle: ".triangle_dump($new_irk)."\n";
	DEBUG and print "new triangle: ".triangle_dump($new_jkr)."\n";
	$adj_ijr->{children}= [$new_irk, $new_jkr];
	$adj_ijk->{children}= [$new_irk, $new_jkr];

	#DEBUG and dag_dump($self->{DAG}, "");
	
	# Add new adjacencies to the FTAL
	$self->setTA($pr, $pk, [$new_irk, $new_jkr]);
	
	# Update the adjacencies of edges PiPk, PkPj, PjPr and PrPi
	!$self->updateTA($pi, $pk, $adj_ijk, $new_irk) or return -1;
	!$self->updateTA($pk, $pj, $adj_ijk, $new_jkr) or return -1;
	!$self->updateTA($pj, $pr, $adj_ijr, $new_jkr) or return -1;
	!$self->updateTA($pr, $pi, $adj_ijr, $new_irk) or return -1;

	if ($self->{it_cb} != undef) {
	    $self->{it_cb}($self);
	}

	INFO and print "-->> RECURSE...\n";

	# Recursively call itself on edges PiPk and PkPj
	!$self->legalize_edge($pr, $pi, $pk) or return -1;
	!$self->legalize_edge($pr, $pk, $pj) or return -1;

    }

    return 0;
}

# -----[ insert_point_inside ]---------------------------------------
# Insert a new point in the triangulation. The given triangle is
# splitted into three new triangles. There are three edges to
# legalize. The DAG and the FTAL are updated accordingly.
#
# Parameters:
# - the node of the DAG that contains the new point
# - the new point Pr
# -------------------------------------------------------------------
sub insert_point_inside($$)
{
    my $self= shift;

    my $node= shift;
    my $tri= $node->{triangle}; # Former triangle
    my $pr= shift;  # New point

    INFO and print "*** INSERT $pr INSIDE (".triangle_dump($node).") ***\n";

    my $pi= $tri->[0];
    my $pj= $tri->[1];
    my $pk= $tri->[2];

    # Create three new smaller triangles
    my $tri_ijr= $self->node_new([$pi, $pj, $pr], [$node], undef);
    my $tri_jkr= $self->node_new([$pj, $pk, $pr], [$node], undef);
    my $tri_kir= $self->node_new([$pk, $pi, $pr], [$node], undef);

    # Update DAG with the new triangles (the 3 triangles are childs of
    # the former triangle)
    $node->{children}= [$tri_ijr, $tri_jkr, $tri_kir];

    # Update the adjacency of edges. If the edge belongs to the
    # bounding triangle, the adjacency contains a single triangle that
    # must be replaced by the new smaller triangle that is adjacent to
    # the edge. Otherwise, if the edge does not belong to the bounding
    # triangle, the adjacency contains two triangles. One of them is
    # the former triangle and it must be replaced by the new smaller
    # triangle adjacent to the edge.

    # Edge PiPj
    !$self->updateTA($pi, $pj, $node, $tri_ijr) or return -1;
    # Edge PjPk
    !$self->updateTA($pj, $pk, $node, $tri_jkr) or return -1;
    # Edge PkPi
    !$self->updateTA($pk, $pi, $node, $tri_kir) or return -1;

    # Edge PiPr
    $self->setTA($pi, $pr, [$tri_ijr, $tri_kir]);
    # Edge PjPr
    $self->setTA($pj, $pr, [$tri_jkr, $tri_ijr]);
    # Edge PkPr
    $self->setTA($pk, $pr, [$tri_kir, $tri_jkr]);

    # Legalize the edges of the former triangle
    !$self->legalize_edge($pr, $pi, $pj) or return -1;
    !$self->legalize_edge($pr, $pj, $pk) or return -1;
    !$self->legalize_edge($pr, $pk, $pi) or return -1;

    return 0;
}

# -----[ insert_point_on_edge ]--------------------------------------
# Insert a new point into the triangulation. The point lies on an edge
# between two triangles. In this case, the two triangles are changed
# into four triangles and we have four edges to legalize. The DAG and
# the FTAL are updated accordingly.
#
# Parameters:
# - node1 and node2, the two triangles adjacent to the edge on which
#   the point lies
# - the new point Pr
# -------------------------------------------------------------------
sub insert_point_on_edge()
{
    my $self= shift;

    my $node1= shift;
    my $node2= shift;
    my $pr= shift;

    INFO and print "*** INSERT $pr ONTO (".triangle_dump($node1).") AND (".
	triangle_dump($node2).") ***\n";

    my $tri1= $node1->{triangle};
    my $tri2= $node2->{triangle};

    # Find the points on the common edge: Pi and Pj and the other
    # points Pk and Pl with Pk being a vertex of node1 and Pl being a
    # vertex of node2
    my %points= ();
    foreach my $pt (@$tri1) { $points{$pt}= 1; };
    foreach my $pt (@$tri2) { $points{$pt}= 1; };
    my ($pi, $pj, $pk, $pl)= (-1, -1, -1, -1);
    foreach my $pt (keys %points) {
	my $in_tri1= Geometry::poly_has_vertex($tri1, $pt);
	my $in_tri2= Geometry::poly_has_vertex($tri2, $pt);
	INFO and print "$pt [$in_tri1, $in_tri2]\n";
	if ($in_tri1 && $in_tri2) {
	    INFO and print "=> edge\n";
	    if ($pi < 0) {
		$pi= $pt;
	    } elsif ($pj < 0) {
		$pj= $pt;
	    } else {
		die "Bèèèèèèèèèh !";
	    }
	} elsif ($in_tri1) {
	    INFO and print "=> !edge\n";
	    if ($pk < 0) {
		$pk= $pt;
	    } else { die; }
	} elsif ($in_tri2) {
	    INFO and print "=> !edge\n";
	    if ($pl < 0) {
		$pl= $pt;
	    } else { die; }
	}
    }

    INFO and print "Pi=$pi Pj=$pj Pk=$pk Pl=$pl\n";

    if (($pi < 0) || ($pj < 0) || ($pk < 0) || ($pl < 0)) {
	die;
    }

    # Create four new smaller triangles
    my $tri_ikr= $self->node_new([$pi, $pk, $pr], [$node1, $node2], undef);
    my $tri_kjr= $self->node_new([$pk, $pj, $pr], [$node1, $node2], undef);
    my $tri_jlr= $self->node_new([$pj, $pl, $pr], [$node1, $node2], undef);
    my $tri_lir= $self->node_new([$pl, $pi, $pr], [$node1, $node2], undef);

    # Update the DAG with the new triangles: node1 has children
    # PiPkPr and PkPjPr while node2 has children PjPlPr and PlPiPr
    $node1->{children}= [$tri_ikr, $tri_kjr];
    $node2->{children}= [$tri_jlr, $tri_lir];

    # Update the FTAL
    $self->setTA($pi, $pr, [$tri_ikr, $tri_lir]);
    $self->setTA($pj, $pr, [$tri_kjr, $tri_jlr]);
    $self->setTA($pk, $pr, [$tri_ikr, $tri_kjr]);
    $self->setTA($pl, $pr, [$tri_jlr, $tri_lir]);

    !$self->updateTA($pi, $pk, $node1, $tri_ikr) or return -1;
    !$self->updateTA($pk, $pj, $node1, $tri_kjr) or return -1;
    !$self->updateTA($pj, $pl, $node2, $tri_jlr) or return -1;
    !$self->updateTA($pl, $pi, $node2, $tri_lir) or return -1;

    # Legalize the edges of the former triangle. Note that the new
    # edges, i.e. edges that are incident to Pr, are legal by
    # construction. We must then wheck PiPk, PkPj, PjPl and PlPi
    !$self->legalize_edge($pr, $pi, $pk) or return -1;
    !$self->legalize_edge($pr, $pk, $pj) or return -1;
    !$self->legalize_edge($pr, $pj, $pl) or return -1;
    !$self->legalize_edge($pr, $pl, $pi) or return -1;

    return 0;
}

# -----[ find_triangles ]--------------------------------------------
# Find in the DAG the triangles that contain the given point. The
# "real" triangles are leaves into the DAG. Note that a node in the
# DAG has at most 3 children.
#
# Parameters:
# - index of the point R
# -------------------------------------------------------------------
sub find_triangles($)
{
    my $self= shift;

    my $r= shift;
    
    my %visited= ();
    my @stack= ($self->{DAG});
    my %leaves_unique= ();
    while (scalar(@stack) > 0) {
	my $node= shift(@stack);

	# Check that this node has not yet been visited
	if (exists($visited{$node})) {
	    next;
	}
	$visited{$node}= $node;

	my $tri= $self->node_get_triangle($node);
	#print "Triangle ".triangle2string($tri)."\n";
	
	if (defined($node->{children}) &&
	    (scalar(@{$node->{children}}) > 0)) {
	    foreach my $child (@{$node->{children}}) {
		my $tri= $self->node_get_triangle($child);
		if (Geometry::pt_in_triangle($tri->[0],
					     $tri->[1],
					     $tri->[2],
					     $self->{points}->[$r])) {
		    push @stack, ($child);
		}
	    }
	} else {
	    $leaves_unique{$node}= $node;
	}
    }

    my @leaves= values %leaves_unique;
    return \@leaves;
}

# -----[ compute ]---------------------------------------------------
# Compute the Delaunay triangulation of the given set of points. This
# implementation is based on the description found in "Computational
# Geometry: Algorithms and Applications, 2nd Edition" by M. de Berg
# et al. It computes the Delaunay triangulation incrementally.
#
# Complexity: O(n.log(n)) where n is the number of points
#
# Parameters:
# - reference to the set of points to triangulate. Each point is a
#   reference to a couple of coordinates X and Y. Hypothesis: there
#   are no two points at the same location.
# -------------------------------------------------------------------
sub compute($)
{
    my $self= shift;

    # Input set of points
    $self->{points}= shift;
    $self->{npoints}= scalar(@{$self->{points}});

    # Compute bounding triangle: (P_1, P_2, P_3) such that all the
    # points of the input set are contained in the triangle. These
    # vertices (P_i) are added to the set of points, with negative
    # indices so that they can be treated in a specific manner during
    # edge validity check.
    # The bounding triangle is defined as P_1= (3M,0), P_2=(0,3M) and
    # P_3=(-3M,-3M) where M is the maximum absolute value of any
    # cordinate in the input set.
    my $M= 0;
    foreach my $pt (@{$self->{points}}) {
	if (abs($pt->[0]) > $M) {
	    $M= abs($pt->[0]);
	}
	if (abs($pt->[1]) > $M) {
	    $M= abs($pt->[1]);
	}
    }
    push @{$self->{points}}, ([3*$M, 0], [0, 3*$M], [-3*$M, -3*$M]);

    # Initialize the triangulation (DAG) with the bounding triangle
    # and no child node
    $self->{DAG}= $self->node_new([$self->{npoints},
				   $self->{npoints}+1,
				   $self->{npoints}+2],
				  undef, undef);
    
    # Initialize the FTAL with the bounding triangle
    $self->setTA($self->{npoints}, $self->{npoints}+1, [$self->{DAG}]);
    $self->setTA($self->{npoints}+1, $self->{npoints}+2, [$self->{DAG}]);
    $self->setTA($self->{npoints}+2, $self->{npoints}, [$self->{DAG}]);
    
    # Generate a random permutation of the input set
    my $permut_r= random_permutation($self->{npoints});

    my $np= 0;

    # Compute the Delaunay triangulation incrementally
    for my $r (@$permut_r) {
	
	# Insert the point at index R into the triangulation.
	# First, find in the DAG the triangles that contain the
	# point...
	my $nodes= $self->find_triangles($r);

	# Then two cases are possible:
	# (1) the point lies inside a unique triangle
	# (2) the point lies on the edge between two triangles
	if (scalar(@$nodes) == 1) {

	    !$self->insert_point_inside($nodes->[0], $r) or return -1;

	} elsif (scalar(@$nodes) == 2) {

	    !$self->insert_point_on_edge($nodes->[0],
					 $nodes->[1],
					 $r) or return -1;

	} else {

	    # Note: the point cannot be contained by more than two
	    # triangles since it would require that two points have
	    # the same location (cf. hypothesis on the set of
	    # points).
	    print STDERR "Error: wrong number of triangles (".
		scalar(@$nodes).")!\n";
	    print STDERR "Error: point[$r]=(".
		$self->{points}->[$r]->[0].",". 
		$self->{points}->[$r]->[1].")\n";
	    foreach my $node (@$nodes) {
		print "TRI-> ".triangle_dump($node)." ref:".$node."\n";
	    }
	    die;
	    return -1;

	}

	# Callback that can be used to monitor the progression of the
	# triangulation...
	($self->{it_cb} != undef) and $self->{it_cb}($self);

	# Debug code used to limit the triangulation to a subset of
	# points
	if (DEBUG) {
	    $np++;
	    #($np >= 10) and return 0;
	}

    }

    return 0;
}

# -----[ get ]-------------------------------------------------------
# Return the list of triangles that compose the triangulation.
# -------------------------------------------------------------------
sub get()
{
    my $self= shift;
    my @triangles= ();

    my @stack= ($self->{DAG});

    #DEBUG and dag_dump($self->{DAG}, "");

    my %visited= ();

    while (scalar(@stack) > 0) {
	my $node= shift @stack;

	if (exists($visited{$node})) {
	    next;
	}
	$visited{$node}= $node;

	# Leaves contain the final triangles
	if (!defined($node->{children}) ||
	    (scalar(@{$node->{children}}) < 1)) {

	    if (defined($node->{children})) {
		#print "GET #:".scalar(@{$node->{children}})."\n";
		}
	    
	    my $color= 'black';
	    my $priority= 0;

	    # Skip triangles that contain a vertice from the bounding
	    # triangle 
	    if (($node->{triangle}->[0] >= $self->{npoints}) ||
		($node->{triangle}->[1] >= $self->{npoints}) ||
		($node->{triangle}->[2] >= $self->{npoints})) {
		$color= 'lightblue';
		$priority= 1;
		next;
	    }

	    DEBUG and print "triangle: ".triangle_dump($node)."  ".
		triangle2string($self->node_get_triangle($node))."\n";
	    
	    # Add the triangle to the list
	    push @triangles, ([$self->{points}->[$node->{triangle}->[0]],
			       $self->{points}->[$node->{triangle}->[1]],
			       $self->{points}->[$node->{triangle}->[2]],
			       $color, $priority]);

	} else {

	    # Add internal nodes onto the stack
	    foreach my $child (@{$node->{children}}) {
		push @stack, ($child);
	    }

	}
    }

    @triangles= sort {$b->[4] <=> $a->[4]} @triangles;

    return \@triangles;
}
