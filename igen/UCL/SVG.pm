# ===================================================================
# SVG.pm
#
# author Bruno Quoitin (bruno.quoitin@uclouvain.be)
# date 26/06/2004
# lastdate 11/02/2009
# ===================================================================
# Changes:
# (11/02/2009) SVG namespace added
# ===================================================================

package SVG;

require Exporter;
@ISA= qw(Exporter);
@EXPORT= qw(new save line rect ellipse);
$VERSION= '0.1';

use strict;
use Symbol;

# -----[ object types ]-----
use constant OT_LINE => 2;
use constant OT_RECT => 3;
use constant OT_ELLIPSE => 4;

# -----[ new ]-------------------------------------------------------
# Create a new SVG object with default parameters and an empty space.
# -------------------------------------------------------------------
sub new()
{
    my $svg_ref= {
	'width' => undef,
	'height' => undef,
	'bounds' => undef,
	'objects' => [],
	'unit' => 'pt',
	'fillcolor' => '#ffffff', # White
	'pencolor' => '#000000',  # Black
	'penwidth' => 0.1,
	'stream' => gensym(),
    };
    bless $svg_ref;
    return $svg_ref;
}

# -----[ fill_style2svg ]--------------------------------------------
#
# -------------------------------------------------------------------
sub fill_style2svg($)
{
    my $fill_style= shift;

    # The fill style is composed of the fill color
    return "fill: ".$fill_style->[0]."; fill-opacity: 127";
}

# -----[ pen_style2svg ]---------------------------------------------
#
# -------------------------------------------------------------------
sub pen_style2svg($)
{
    my $pen_style= shift;

    if ($pen_style == undef) {
	return undef;
    }

    # The pen style is composed of the pen color and the pen width
    return "stroke-width: ".$pen_style->[1]."; stroke: ".$pen_style->[0];
}

# -----[ translate_x ]-----------------------------------------------
#
# -------------------------------------------------------------------
sub translate_x($)
{
    my $self= shift;
    my $x= shift;

    return $x-$self->{bounds}->[0];
}

# -----[ translate_y ]-----------------------------------------------
#
# -------------------------------------------------------------------
sub translate_y($)
{
    my $self= shift;
    my $y= shift;

    return $y-$self->{bounds}->[1];
}

# -----[ stream_write ]----------------------------------------------
#
# -------------------------------------------------------------------
sub stream_write($)
{
    my $self= shift;
    my $things= shift;

    my $stream= $self->{stream};

    print $stream $things;
}

# -----[ save_object ]-----------------------------------------------
# Save an object from the SVG to the opened file.
# -------------------------------------------------------------------
sub save_object($)
{
    my $self= shift;
    my $object= shift;

    my $obj_type= $object->[0];
    my $fill_style= fill_style2svg($object->[1]);
    my $pen_style= pen_style2svg($object->[2]);

    if ($obj_type == OT_LINE) {

	my $x1= $self->translate_x($object->[3]);
	my $y1= $self->translate_y($object->[4]);
	my $x2= $self->translate_x($object->[5]);
	my $y2= $self->translate_y($object->[6]);

	$self->stream_write("<line ");
	$self->stream_write("style=\"$fill_style; $pen_style\" ");
	$self->stream_write("x1=\"$x1\" y1=\"$y1\" x2=\"$x2\" y2=\"$y2\" ");
	$self->stream_write("/>\n");

    } elsif ($obj_type == OT_RECT) {

	my $x= $self->translate_x($object->[3]);
	my $y= $self->translate_y($object->[4]);
	my $width= $object->[5];
	my $height= $object->[6];

	$self->stream_write("<rect ");
	$self->stream_write("style=\"$fill_style; $pen_style\" ");
	$self->stream_write("x=\"$x\" y=\"$y\" width=\"$width\" height=\"$height\" ");
	$self->stream_write("/>\n");

    } elsif ($obj_type == OT_ELLIPSE) {

	my $cx= $self->translate_x($object->[3]);
	my $cy= $self->translate_y($object->[4]);
	my $rx= $object->[5];
	my $ry= $object->[6];

	$self->stream_write("<ellipse ");
	$self->stream_write("style=\"$fill_style; $pen_style\" ");
	$self->stream_write("cx=\"$cx\" cy=\"$cy\" rx=\"$rx\" ry=\"$ry\" ");
	$self->stream_write("/>\n");

    }
}

# -----[ save ]------------------------------------------------------
# Save the complete graph in SVG
# -------------------------------------------------------------------
sub save($)
{
    my $self= shift;
    my $filename= shift;

    my $result= open($self->{stream}, ">$filename");
    if (!$result) {
	print STDERR "Error: unable to create \"$filename\": $!\n";
	return(-1);
    }

    # XML header
    $self->stream_write("<?xml version=\"1.0\" encoding=\"UTF-8\" ".
			"standalone=\"no\" ?>\n");
    # SVG namespace
    $self->stream_write("<!DOCTYPE svg PUBLIC \"-//W3C//DTD SVG 1.1//EN\" ".
			"\"http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd\">");

    $self->{width}= ($self->{bounds}->[2]-$self->{bounds}->[0]).
	$self->{unit};
    $self->{height}= ($self->{bounds}->[3]-$self->{bounds}->[1]).
	$self->{unit};

    # SVG opening tag
    $self->stream_write("<svg width=\"".$self->{width}.
			"\" height=\"".$self->{height}."\" >\n");

    # Save all objects
    for my $object (@{$self->{objects}}) {
	$self->save_object($object);
    }

    # SVG closing tag
    $self->stream_write("</svg>\n");

    close(OUT);
    return(0);
}

# -----[ extend ]----------------------------------------------------
#
# -------------------------------------------------------------------
sub extend($$$$)
{
    my $self= shift;
    my ($x1, $y1, $x2, $y2)= @_;

    if ($self->{bounds} == undef) {

	$self->{bounds}= [$x1, $y1, $x2, $y2];

    } else {

	# Minimum X
	if ($self->{bounds}->[0] > $x1) {
	    $self->{bounds}->[0]= $x1;
	}
	# Minimum Y
	if ($self->{bounds}->[1] > $y1) {
	    $self->{bounds}->[1]= $y1;
	}
	# Maximum X
	if ($self->{bounds}->[2] < $x2) {
	    $self->{bounds}->[2]= $x2;
	}
	# Maximum Y
	if ($self->{bounds}->[3] < $y2) {
	    $self->{bounds}->[3]= $y2;
	}

    }
}

# -----[ line ]------------------------------------------------------
#
# -------------------------------------------------------------------
sub line($$$$)
{
    my $self= shift;
    my ($x1, $y1, $x2, $y2)= @_;
    
    $self->extend($x1, $y1, $x2, $y2);

    push(@{$self->{objects}},
	 ([OT_LINE,
	   [$self->{fillcolor}],
	   [$self->{pencolor}, $self->{penwidth}],
	   $x1, $y1, $x2, $y2]));

    return 0;
}

# -----[ rect ]------------------------------------------------------
#
# -------------------------------------------------------------------
sub rect($$$$)
{
    my $self= shift;
    my ($x1, $y1, $x2, $y2)= @_;

    (($x2 >= $x1) && ($y2 >= $y1)) or return -1;

    $self->extend($x1, $y1, $x2, $y2);

    push(@{$self->{objects}},
	 ([OT_RECT,
	   [$self->{fillcolor}],
	   [$self->{pencolor}, $self->{penwidth}],
	   $x1, $y1, $x2-$x1, $y2-$y1]));

    return 0;
}

# -----[ ellipse ]---------------------------------------------------
#
# -------------------------------------------------------------------
sub ellipse()
{
    my $self= shift;
    my ($cx, $cy, $rx, $ry)= @_;

    $self->extend($cx-$rx, $cy-$ry, $cx+$rx, $cy+$ry);

    push(@{$self->{objects}},
	 ([OT_ELLIPSE,
	   [$self->{fillcolor}],
	   [$self->{pencolor}, $self->{penwidth}],
	   $cx, $cy, $rx, $ry]));

    return 0;
}
