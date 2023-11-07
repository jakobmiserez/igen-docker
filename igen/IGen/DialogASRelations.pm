# ===================================================================
# IGen::DialogASRelations.pm
#
# (c) 2005, Networking team
#           Computing Science and Engineering Dept.
#           Université catholique de Louvain
#           Belgium
#
# author Bruno Quoitin (bqu@info.ucl.ac.be)
# date 03/10/2005
# lastdate 04/10/2005
# ===================================================================

package IGen::DialogASRelations;

require Exporter;
@ISA= qw(Exporter UCL::Tk::Dialog);

use Tk 800.000;
use Tk::Toplevel;

use strict;
use UCL::Tk::Dialog;
use UCL::Graph::Base;
use IGen::Definitions;

# -----[ _init ]-----------------------------------------------------
#
# -------------------------------------------------------------------
sub _init()
{
    my ($self)= @_;
    
    $self->SUPER::_init(-title=>"Links",
			-btn_okcancel);

    # ---| Check arguments |---
    if (!defined($self->{args}{-relations})) {
	$self->{relations}= new Graph::Directed;
    } else {
	$self->{relations}= $self->{args}{-relations};
    }
    $self->{result}= {};

    # ---| Build window |---
    my $frame=
	$self->{top}->Frame(-relief=>'sunken',
			    -borderwidth=>1
			    )->pack(-side=>'top',
				    -fill=>'both',
				    -expand=>1);
    $self->{Top}{top}= $frame;
    my $subframe= $frame->Frame()->pack(-side=>'top',
					-fill=>'both',
					-expand=>1);
    my @headers= ('From', 'To', 'Relation');
    my $relationsList= $subframe->Scrolled("HList",
					   -header=>1,
					   -columns=>scalar(@headers),
					   -selectbackground=>'lightblue',
					   -background=>'white',
					   -scrollbars=>'osoe',
					   -command=>[\&_select_relation, $self],
					   )->pack(-expand=>1,
						   -fill=>'both');
    $self->{RelationsList}= $relationsList;
    $self->{StyleRight}= $self->{RelationsList}->ItemStyle('text',
							   -justify=>'right');
    $self->{StyleLeft}= $self->{RelationsList}->ItemStyle('text',
							  -justify=>'left');
    my $column= 0;
    foreach my $header (@headers) {
	$relationsList->header('create', $column++,
			       -text=>$header,
			       -borderwidth=>1,
			       -headerbackground=>'gray');
    }
    $self->_show_relations();
    $frame= $self->{top}->Frame()->pack(-side=>'top',
					-after=>$self->{Top}{top});
    my $subframe= $frame->Frame()->pack(-side=>'top',
					-fill=>'x',
					-expand=>1);
    $subframe->Label(-text=>'From:')->pack(-side=>'left');
    $self->{result}{from}= undef;
    $self->{FromEntry}= $subframe->Entry(-textvariable=>\$self->{result}{from}
					 )->pack(-side=>'right');
    my $subframe= $frame->Frame()->pack(-side=>'top',
					-fill=>'x',
					-expand=>1);
    $subframe->Label(-text=>'To:')->pack(-side=>'left');
    $self->{result}{to}= undef;
    $self->{ToEntry}= $subframe->Entry(-textvariable=>\$self->{result}{to}
				       )->pack(-side=>'right');
    my $subframe= $frame->Frame()->pack(-side=>'top',
					-fill=>'x',
					-expand=>1);
    $subframe->Label(-text=>'Relation:')->pack(-side=>'left');
    $self->{result}{relation}= undef;
    my @relations= values %{ILINK_RELATIONS()};
    $self->{RelationOptionMenu}=
	$subframe->BrowseEntry(-choices=>\@relations,
			       -variable=>\$self->{result}{relation},
			       -state=>'readonly',
			       )->pack(-side=>'right');
    my $subframe= $frame->Frame()->pack(-side=>'top',
					-fill=>'x',
					-expand=>1);
    $subframe->Button(-text=>'Import',
		   -command=>[\&_import_relations, $self]
    		  )->pack(-side=>'left',
			  -fill=>'x',
			  -expand=>1);
    $subframe->Button(-text=>'Export',
		   -command=>[\&_export_relations, $self]
    		  )->pack(-side=>'left',
			  -fill=>'x',
			  -expand=>1);
    $subframe->Button(-text=>'Create/update',
		   -command=>[\&_update_relation, $self]
    		  )->pack(-side=>'right',
			  -fill=>'x',
			  -expand=>1);
    $subframe->Button(-text=>'Delete',
		   -command=>[\&_delete_relation, $self]
    		  )->pack(-side=>'right',
			  -fill=>'x',
			  -expand=>1);
}

# -----[ _import_relations ]-----------------------------------------
sub _import_relations()
{
    my ($self)= @_;

    my $filename= $self->{main}->getOpenFile(-filetypes=>
					     [
					      ['AS Relation files',
					       '.relation'],
					      ['All files', '*']
					      ]);
    (!defined($filename)) and return;

    my $filter= new IGen::FilterASRelations();
    my $as_relations= $filter->import_graph($filename);
    (!defined($as_relations)) and return;
    $self->{relations}= $as_relations;

    $self->_show_relations();
}

# -----[ _export_relations ]-----------------------------------------
sub _export_relations()
{
    my ($self)= @_;

    my $filename= $self->{main}->getSaveFile(-filetypes=>
					     [
					      ['AS Relation files',
					       '.relation'],
					      ['All files', '*']
					      ]);
    (!defined($filename)) and return;

    my $filter= new IGen::FilterASRelations();
    my $result= $filter->export_graph($self->{relations}, $filename);
    ($result < 0) and return;
}

# -----[ _update_relation ]------------------------------------------
sub _update_relation()
{
    my ($self)= @_;

    my $src= $self->{result}{from};
    my $dst= $self->{result}{to};
    my $relation= $self->{result}{relation};

    # ---| Add edge if does not exist. Update otherwise... |---
    if ($self->{relations}->has_edge($dst, $src)) {
	# Remove previous relation (in reverse direction)
	$self->{relations}->delete_edge($dst, $src);
	$self->{RelationsList}->delete('entry', "$dst:$src");
    }
    if ($self->{relations}->has_edge($src, $dst)) {
	# Add new relation
	my $relation_id= ILINK_RELATIONS_NAMES->{$relation};
	$self->{relations}->set_attribute(UCL::Graph::ATTR_RELATION, 
					  $src, $dst,
					  $relation_id);
	$relation= ILINK_RELATIONS->{$relation_id};
	$self->{RelationsList}->itemConfigure("$src:$dst", 2,
					      -text=>$relation);
    } else  {
	$self->{relations}->add_edge($src, $dst);
	$self->{relations}->set_attribute(UCL::Graph::ATTR_RELATION, 
					  $src, $dst,
					  ILINK_RELATIONS_NAMES->{$relation});
	$self->_add_relation($src, $dst, $relation);
    }
}

# -----[ _add_relation ]---------------------------------------------
sub _add_relation()
{
    my ($self, $src, $dst, $relation)= @_;

    my $path= "$src:$dst";
    $self->{RelationsList}->add($path, -data=>[$src, $dst]);
    $self->{RelationsList}->itemCreate($path, 0,
				       -text=>"$src",
				       -style=>$self->{StyleLeft});
    $self->{RelationsList}->itemCreate($path, 1,
				       -text=>"$dst",
				       -style=>$self->{StyleLeft});
    my $relation_name= $relation;
    $self->{RelationsList}->itemCreate($path, 2,
				       -text=>$relation_name,
				       -style=>$self->{StyleLeft});
}

# -----[ _show_relations ]-------------------------------------------
sub _show_relations()
{
    my ($self)= @_;

    $self->{RelationsList}->delete('all');
    my @edges= $self->{relations}->edges();
    for (my $i= 0; $i < scalar(@edges)/2; $i++) {
	my $src= $edges[$i*2];
	my $dst= $edges[$i*2+1];
	my $relation=
	    $self->{relations}->get_attribute(UCL::Graph::ATTR_RELATION,
					      $src, $dst);
	$self->_add_relation($src, $dst, ILINK_RELATIONS->{$relation});
    }
}

# -----[ _select_relation ]------------------------------------------
sub _select_relation()
{
    my ($self)= @_;

    my @selected= $self->{RelationsList}->info('selection');
    (!defined(@selected) || (scalar(@selected) > 1)) and return -1;

    my $src_dst= $self->{RelationsList}->info('data', $selected[0]);
    
    $self->{result}{from}= $src_dst->[0];
    $self->{result}{to}= $src_dst->[1];
    my $relation= $self->{relations}->get_attribute(UCL::Graph::ATTR_RELATION,
						   $src_dst->[0], $src_dst->[1]);
    $self->{result}{relation}= ILINK_RELATIONS->{$relation};
}

# -----[ _delete_relation ]------------------------------------------
sub _delete_relation()
{
    my ($self)= @_;
    
    my $src= $self->{result}{from};
    my $dst= $self->{result}{to};
    if ($self->{RelationsList}->info('exists', "$src:$dst")) {
	$self->{RelationsList}->delete('entry', "$src:$dst");
    }
    if ($self->{RelationsList}->info('exists', "$dst:$src")) {
	$self->{RelationsList}->delete('entry', "$dst:$src");
    }
    $self->{result}{from}= undef;
    $self->{result}{to}= undef;
    $self->{result}{relation}= undef;
}

# -----[ _on_close ]-------------------------------------------------
sub _on_close()
{
    my ($self)= @_;

    if (defined($self->{result})) {
	$self->{result}{relations}= $self->{relations};
    }
}
