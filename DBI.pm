# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
=head1	Name

Mdc::DBI v1.01


=head1	Description

Simple interface for DBI. Only three methods needed: new, Sql, and Fetchrow.


=head1	Synopsis

 use Mdc::DBI;
 my $DB = new Mdc::DBI( database=>"test", username=>"me", password=>"" );
 $DB->Sql( "select * from sometable" );
 my $row = $DB->Fetchrow();

=cut

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
# Initialize global variables
#
package     Mdc::DBI;
our         $VERSION        = 1.01;             # 9/20/2007 5:30PM
require                       5.008;
use         strict;
use         Carp;
require     Exporter;
our         @ISA            = qw( Exporter );
our         @EXPORT_OK      = qw( $VERSION );
use         DBI;
my          %_default       = (   dbdriver => "mysql",
                                  hostname => "localhost",
                                  timeout  => 10 );
my          @_required      = qw( database username password );
our         $msg            = _messages();





# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
=head1  Methods

=head2  new

Connect to database and return new object. Parameters should be supplied as
a hash.

 Example:
 my  $DB = new Mdc::DBI(    dbdriver => "mysql",
                            hostname => "localhost",
                            database => "test",
                            username => "me",
                            password => "",
                            timeout  => 10  );

=head3  Parameters

=over

=item   dbdriver

Installed database driver. See DBI man page.  Default is 'mysql'.

=item   hostname

Host were database resides. Default is 'localhost'.

=item   timeout

The connect request to the server will timeout if it has not been successful
after the given number of seconds. Default is 10 seconds.

=item   database

Required parameter.

=item   username

Required parameter.

=item   password

Required parameter.

=back

=cut

sub new {
    my $self = bless {}, shift;
    %$self   = (%_default, @_);
    # check required parameters
    foreach ( @_required ){
        croak( $msg->{101} . " ($_)") if not defined $self->{$_};
    }
    $self->_connect();
    return $self;
}


=head2  Sql

Prepare and execute an sql statement. Return number of rows selected if successful.
Return undefined if not.

=cut

sub Sql {
    my ($self, $sql) = @_;
    croak $msg->{111} if not defined $sql;
    $self->{sth}->finish()  if defined $self->{sth};
    $self->{sth} = $self->{dbo}->prepare($sql);
    return if not $self->{sth};
    if( not $self->{sth}->execute() ){
        undef $self->{sth};
        return;
    }
    return $self->{sth}->rows;
}


=head2  Fetchrow

Fetch a single row from most recent query.  Return

=cut

sub Fetchrow {
    my $self = shift;
    croak $msg->{112}   if not defined $self->{sth};
    return $self->{sth}->fetchrow_hashref();
}


sub DESTROY {
    my $self = shift;
    $self->{sth}->finish() if defined $self->{sth};
    $self->_disconnect();
    undef %$self;
}






# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
# Private methods
#
# The following methods are considered private to this package,
# but who's going to stop you from using them?
#


# Create a new database connection object.
#
sub _connect {
    my $self = shift;
    my $dbinfo = "$self->{dbdriver}:$self->{database}:$self->{hostname}";
    $dbinfo   .= ":mysql_connect_timeout=$self->{timeout}" if $self->{dbdriver} eq 'mysql';
    $self->{dbo} = DBI->connect("DBI:$dbinfo", $self->{username} ,$self->{password}, {RaiseError=>0} );
    croak(110 . " $dbinfo")  if not defined $self->{dbo};
}


# Disconnect from host
#
sub _disconnect {
    my $self = shift;
    return if not defined $self->{dbo};
    $self->{dbo}->disconnect();
    undef $self->{dbo};
}


# Substitute tokens with parameters from the supplied hash reference
#
sub _substitute {
    foreach ( keys %{$_[1]} ) {
        my $val = (defined $_[1]->{$_})? $_[1]->{$_}: '';
        $_[0] =~ s/~$_~/$val/g;
    }
}


# Define a bunch of error messages
#
sub _messages {
    return {
        101 => "parameter not defined",
        110 => "unable to make connection",
        111 => "sql statement not defined",
        112 => "attempted fetch on undefined cursor"
    };
}


1;
__END__



=head1	Author and Copyright

 StringUtils - Copyright (c) 2006-2007, Mark K Mueller
 Mueller Design and Consulting
 www.MarkMueller.com
 All Rights Reserved.

=for html
 <small> Doc updated: 11/22/2006 </small>
