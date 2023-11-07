# ===================================================================
# IGen::DialogInternet
#
# (c) 2005, Networking team
#           Computing Science and Engineering Dept.
#           Université catholique de Louvain
#           Belgium
#
# author Bruno Quoitin (bqu@info.ucl.ac.be)
# date 05/07/2005
# lastdate 04/09/2005
# ===================================================================

package IGen::DialogInternet;

require Exporter;
@ISA= qw(Exporter UCL::Tk::Dialog);

use Tk 800.000;
use Tk::Toplevel;

use strict;
use UCL::Tk::Dialog;
use IGen::DialogNetwork;

# -----[ _add_attribute_header ]-------------------------------------
#
# -------------------------------------------------------------------
sub _add_attribute_header($$)
{
    my ($self, $header)= @_;

    my $subframe=
	$self->{Top}{top}->Frame()->pack(-side=>'top',
					 -fill=>'x',
					 -expand=>1);
    $subframe->Label(-relief=>'sunken',
		     -borderwidth=>0,
		     -text=>$header,
		     -background=>'darkgray',
		     )->pack(-expand=>1,
			     -fill=>'x');
}

# -----[ _init ]-----------------------------------------------------
#
# -------------------------------------------------------------------
sub _init()
{
    my ($self)= @_;
    
    $self->SUPER::_init(-title=>'Build Internet',
			-btn_okcancel);

    # ---| Check parameters |---
    if (!defined($self->{result})) {
	$self->{result}{'as_relations_file'}= undef;
	$self->{result}{'as_relations_source'}= 'file';
	$self->{result}{'as_relations'}= undef;
	$self->{result}{'as_relations_defined'}= 'undef';
	$self->{result}{'num_links'}= 3;
    }

    # ---| Build dialog box |---
    $self->{Top}{top}=
	$self->{top}->Frame(-relief=>'sunken',
			    -borderwidth=>1
			    )->pack(-side=>'top',
				    -fill=>'x',
				    -expand=>1);
    my $frame= $self->{Top}{top};
    # ---| Relationships |---
    $self->_add_attribute_header('Relationships');
    my $subframe= $frame->Frame()->pack(-side=>'top',
					-fill=>'x',
					-expand=>1);
    $subframe->Radiobutton(-text=>'from file:',
			   -value=>'file',
			   -variable=>\$self->{result}{as_relations_source},
			   -command=>sub {
			       $self->{result}{as_relations}= undef;
			       $self->{result}{as_relations_defined}= 'undef';
			   }
			   )->pack(-side=>'left');
    $subframe->Button(-text=>'...',
		      -command=>[\&_edit_as_relations_file, $self]
		      )->pack(-side=>'right');
    $subframe->Entry(-textvariable=>\$self->{result}{'as_relations_file'},
		     -state=>'disabled'
		     )->pack(-side=>'right');
    my $subframe= $frame->Frame()->pack(-side=>'top',
					-fill=>'x',
					-expand=>1);
    $subframe->Radiobutton(-text=>'manually:',
			   -value=>'manual',
			   -variable=>\$self->{result}{as_relations_source},
			   -command=>sub {
			       $self->{result}{as_relations}= undef;
			       $self->{result}{as_relations_defined}= 'undef';
			   }
			   )->pack(-side=>'left');
    $subframe->Button(-text=>'...',
		      -command=>[\&_edit_as_relations, $self]
		      )->pack(-side=>'right');
    $subframe->Entry(-textvariable=>\$self->{result}{'as_relations_defined'},
		     -state=>'disabled'
		     )->pack(-side=>'right');

    # ---| Parameters |---
    $self->_add_attribute_header('Parameters');
    my $subframe= $frame->Frame()->pack(-side=>'top',
					-fill=>'x',
					-expand=>1);
    $subframe->Label(-text=>'Number of links:'
		     )->pack(-side=>'left');
    $subframe->Spinbox(-from=>0,
		       -to=>100,
		       -textvariable=>\$self->{result}{'num_links'}
		       )->pack(-side=>'right');
}

# -----[ _edit_as_relations_file ]-----------------------------------
sub _edit_as_relations_file($)
{
    my ($self)= @_;

    my $filename= $self->{main}->getOpenFile(-filetypes=>
					     [
					      ['AS Relation files',
					       '.relation'],
					      ['All files', '*']
					      ]);
    (!defined($filename)) and return;
    $self->{result}{'as_relations_file'}= $filename;
}

# -----[ _edit_as_relations ]----------------------------------------
sub _edit_as_relations($)
{
    my ($self)= @_;

    my $dialog= new IGen::DialogASRelations(-parent=>$self->{main},
					    -relations=>$self->{result}{as_relations});
    my $result= $dialog->show_modal();
    $dialog->destroy();
    (!defined($result)) and return;

    $self->{result}{as_relations}= $result->{relations};
    $self->{result}{as_relations_defined}= 'defined';
}
