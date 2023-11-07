# ===================================================================
# IGen::FilterBase
#
# Base class for Graph import/export filters.
#
# (c) 2005, Networking team
#           Computing Science and Engineering Dept.
#           Université catholique de Louvain
#           Belgium
#
# author Bruno Quoitin (bqu@info.ucl.ac.be)
# date 22/08/2005
# lastdate 05/10/2005
# ===================================================================
#
# WRITTING A FILTER
# -----------------
#
# In order to write a Filter, you need to inherit from
# IGen::FilterBase and follow the steps described below:
#
# 1). In the _init() method, you need to setup the filter capabilities
# using the set_capabilities() method. The capabilities are currently
# as follows:
# - EXPORT_SINGLE   : the filter is able to export a single domain
# - EXPORT_MULTIPLE : the filter is able to export multiple domains
# - IMPORT_SINGLE   : the filter is able to import a single domain
# - IMPORT_MULTIPLE : the filter is able to import multiple domains
# These capabilities can be ORed in order to advertise the support of
# multiple capabilities.
#
# 2). Depending on the capabilities you have advertised, you must
# provide methods that support them. If you advertise any IMPORT_*
# capability, you must provide an import_graph() method. If you
# advertise any EXPORT_* capability, you must provide an
# export_graph() method.
# The import_graph() method takes a single argument: a filename. The
# method returns a single CPAN Graph or a hash containing multiple
# CPAN Graphs (see below).
# The export_graph() method takes two arguments: a filename and a
# graph or hash. The method returns 0 on success and -1 on error.
#
# 3). Multiple domains are supported through a hash table structured
# as follows. It contains the following two keys/values:
# - as2graph : which is a reference to a hash of CPAN Graphs (these
#              are the multiple domains). The keys in this hash are
#              the AS numbers of the contained domains
# - igraph   : which is a CPAN Graph containing the interdomain links
#
# 4). If the import_graph() or export_graph() methods fail, they can
# provide more information on the reason of the error through the
# set_error() method. This method takes a single string argument which
# is the error message. If no error is generated, the above method
# must clear the error by calling set_error() with no argument before
# returning.
#
# 5). It is possible to ask for more import/export options by
# providing configuration methods in the Filter instance. THIS IS NOT
# DOCUMENTED YET.
# ===================================================================

package IGen::FilterBase;

require Exporter;
@ISA= qw(Exporter);

use strict;

use constant EXPORT_SINGLE => 0x01;
use constant EXPORT_MULTIPLE => 0x02;
use constant IMPORT_SINGLE => 0x04;
use constant IMPORT_MULTIPLE => 0x08;

# -----[ new ]-------------------------------------------------------
#
# -------------------------------------------------------------------
sub new($%)
{
    my ($class, %args)= @_;
    my $self= {
	'args' => \%args,
	'capabilities' => 0,
	'extensions' => undef,
	'export_dialog' => undef,
    };
    bless $self, $class;
    $self->_init();
    return $self;
}

# -----[ _init ]-----------------------------------------------------
#
# -------------------------------------------------------------------
sub _init($)
{
    my ($self)= @_;
}

# -----[ get_error ]-------------------------------------------------
#
# -------------------------------------------------------------------
sub get_error($)
{
    my ($self)= @_;

    if (defined($self->{'error'})) {
	return $self->{'error'};
    } else {
	return 'success';
    }
}

# -----[ set_error ]-------------------------------------------------
#
# -------------------------------------------------------------------
sub set_error($;$)
{
    my ($self, $error)= @_;

    if (defined($error)) {
	$self->{'error'}= $error;
    } else {
	$self->{'error'}= undef;
    }
}

# -----[ set_capabilities ]------------------------------------------
#
# -------------------------------------------------------------------
sub set_capabilities($$)
{
    my ($self, $capabilities)= @_;

    $self->{capabilities}= $capabilities;
}

# -----[ has_capability ]--------------------------------------------
#
# -------------------------------------------------------------------
sub has_capability($$)
{
    my ($self, $capability)= @_;

    if (($self->{capabilities} & $capability) == $capability) {
	return 1;
    } else {
	return 0;
    }
}

# -----[ set_extensions ]--------------------------------------------
#
# -------------------------------------------------------------------
sub set_extensions($$)
{
    my ($self, @extensions)= @_;

    $self->{extensions}= [];
    foreach (@extensions) {
	push @{$self->{extensions}}, ($_);
    }
}

# -----[ set_export_dialog ]-----------------------------------------
#
# -------------------------------------------------------------------
sub set_export_dialog($$)
{
    my ($self, $dialog_class)= @_;

    $self->{'export_dialog'}= $dialog_class;
}

# -----[ configure_export ]------------------------------------------
#
# -------------------------------------------------------------------
sub configure_export($,%)
{
    my ($self, %args)= @_;

    if (defined($self->{'export_dialog'})) {
	my $fct= $self->{'export_dialog'};
	return &$fct(%args);
    } else {
	return undef;
    }
}

# -----[ configure_import ]------------------------------------------
#
# -------------------------------------------------------------------
sub configure_import($,%)
{
}
