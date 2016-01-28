# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
=head1  Name

DataMapper


=head1  Synopsis

 use Mdc::DataMapper;
 my $Mapper = new Mdc::DataMapper
 $Mapper->remap( \%fromhash, \%tohash );
 $Mapper->reformat( \%tohash );


=head1  Description

Provide methods to remap fields, reformat data and error checking.


=head1  Version

Version 1.06


=head1  Methods

=cut



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
package Mdc::DataMapper;
$VERSION = 1.06;                # 7/27/2006
require 5.008_000;
use strict;
use vars qw(@ISA @EXPORT_OK $VERSION);
use Carp;
use Mdc::StringUtils qw( 1.029 CommaGroupedNumber Lpad );
use Mdc::FormatTime;
use Mdc::IniFile;
require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw( $VERSION );
my $TIME = new Mdc::FormatTime;

my %msg = (
    101 => "parameter reqired ",
    601 => "file does not exist "
);

my %default_params = (
    truncate    => 0,
    reformat    => 0,
    skip_not_defined => 0
);



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
=head2  new

Create new mapping object.

 my $obj = new Mdc::DataMapper $cfgfile;

=over

=item   param1

Mapfile

=back

=cut

sub new {
    my $class = shift;
    bless my $self = {}, $class;
    my ($cfgfile, %params) = @_;
    croak($msg{101}) if not defined $cfgfile;
    croak($msg{601} . $cfgfile ) if not -f $cfgfile;
    %{$self->{' params'}} = %default_params;                # Set default parameters

    my $fileObj = new Mdc::IniFile($cfgfile);
    my $cfg = $fileObj->DataRef;
    foreach ( keys %{$cfg} ) {
        if ( ref $cfg->{$_} ) {
            %{$self->{' map'}{$_}} = %{$cfg->{$_}};
        }
        else {
            $self->{' params'}{$_} = $cfg->{$_};            # Set parameters defined in config
        }                                                   # These override the defaults
    }
    undef $fileObj;

    # Finally, any parameters defined during object init will override all
    %{$self->{' params'}} = ( %{$self->{' params'}}, %params );

    return $self;
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
=head2  remap

Remap keys in %fromhash place in %tohash. Will remap only those keys that exist
in both %fromhash and the configuration file.

 remap( \%fromhash, \%tohash );

=cut

sub remap {
    my $self = shift;
    my ( $inref, $outref ) = @_;

    foreach my $mapkey ( sort keys %{$self->{' map'}} ) {
        next if not exists $self->{' map'}{$mapkey}{remap};
        my $remap = $self->{' map'}{$mapkey}{remap};
        if ($remap =~ m/~\S+~/) {
            my $ok = 0;
            while ( $remap =~ m/~(\w+)~{1}?/i ) {         # look for tokens
                my $v = (defined $inref->{$1})? $inref->{$1}: "";
                $remap =~ s/~$1~/$v/;
                $ok = $v ne '';
            }
            $outref->{$mapkey} = $remap if $ok;
        }else{
            next if not defined $inref->{$remap};
            $outref->{$mapkey} = $inref->{$remap};
        }
    }
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
=head2  reformat

Reformat data in supplied hash

 reformat( \%hash );




=cut

sub reformat {
    my $self = shift;
    my ( $inref ) = @_;

    foreach my $mapkey ( sort keys %{$self->{' map'}} ) {
        my $Map = $self->{' map'}{$mapkey};
        my $value = $inref->{$mapkey};

        # this value will override the input value
        if ( defined $Map->{value} ) {
            $inref->{$mapkey} = $Map->{value};
            next;
        }

        # if value is not defined, use default
        if ( !defined $value and defined $Map->{default} ) {
            $value = $Map->{default};
        }

        # regex
        if ( exists $Map->{'regex'} ) {
            $value = $self->_eval( $Map, $value, $mapkey, $inref );
        }

        # eval
        if ( exists $Map->{'eval'} ) {
            $value = $self->_eval( $Map, $value, $mapkey, $inref );
        }

        # predefined formatting
        if ( defined $Map->{'format'} ) {
            $value = $self->_format($Map->{'format'},$value);
        }

        # function
        if ( defined $Map->{'function'} ) {
            $value = $self->_function( $Map, $value, $inref );
        }

        next if !defined $value and !&main::DEBUG;
        $value='' if( !defined $value and &main::DEBUG);

        # array
        if ( defined $Map->{array} ) {
            next if ( not $value =~ /^\d+$/ );
            if ( defined $Map->{array}[$value] ) {
                $value = $Map->{array}[$value];
            }else{
                next;
            }
        }

        # truncate to length
        if (  (defined $Map->{'length'} and $Map->{'length'})  ) {
            $value = substr( $value, 0 , $Map->{'length'} );
        }

        next if $value eq '' and !&main::DEBUG;

        # assign the value and loop
        $inref->{$mapkey} = $value;
    }
    return;
}


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
=head2  _eval

Eval data

=cut

sub _eval {
    my $self = shift;
    use vars qw( $value );

    my ($cfg, $value, $key, $input)  = @_;
    return '' if not defined $value;
    return '' if $value eq '';

    if( defined $cfg->{regex} and $cfg->{regex} =~ m/^s/ ){
        my $_eval = '$value=~' . $cfg->{regex};
        my $result = eval $_eval;
        if ( !defined $result ) {
                warn "undefined result from regex/eval ($key)\n"
        }
        return $value;
    }else{
        my $_eval = $cfg->{'eval'};
        $_ = $value;
        my $result = eval $_eval;
        return $result if defined $result;
        warn "undefined result from eval ($key)\n";
        return '';
    }

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
=head2  _format

Format value using predefined formats

; phone             999-9999 or 999-999-9999
; ssn               999-99-9999
; words             a-z, 0-9, space, comma, hyphen, underscore, period.
; alpha             a-z
; alphanumeric      a-z and 0-9
; integer           0-9
; decimal(n)        999999.9999 decimal number to the nth place (with rounding)
; money             99,999.99 (with rounding)
; lpad(n)           pad with leading spaces to n characters (alphanumeric)
; lzeros(n)         pad with leading zeros to n digits (integer)

=cut

sub _format {
    my $self = shift;
    my ($fmt, $value) = @_;
    return '' if !defined $value;

    $_ = $value;
    if ( 'phone' eq $fmt ) {
        tr/[0-9]//cd;
        s/^(...)(...)(....)$/$1-$2-$3/ or
        s/^(...)(....)$/$1-$2/;
    }elsif ( 'ssn' eq $fmt ) {
        tr/[0-9]//cd;
        s/^(...)(..)(....)$/$1-$2-$3/ ;
    }elsif ( 'words' eq $fmt ) {
        tr/[a-zA-Z0-9 _\.\-\,]//cd;
    }elsif ( 'alpha' eq $fmt ) {
        tr/[a-zA-Z]//cd;
    }elsif ( 'alphanumeric' eq $fmt ) {
        tr/[a-zA-Z0-9]//cd;
    }elsif ( $fmt =~ /^int/ ) {
        tr/[0-9\.]//cd;
        $_ = int($_) if $_ ne '';
    }elsif ( $fmt =~ m!^decimal\((.+)\)! ) {
        my $n = $1;
        if( s/(\d+)\.?(\d*)/$1.$2/ ) {
            $_ = int(($_ * 10**$n)+.5)/10**$n;
        }
    }elsif ( 'money' eq $fmt ) {
        if( s/(\d+)\.?(\d*)/$1.$2/ ) {
            $_ = int(($_ * 100)+.5)/100;
        }
        $_ = CommaGroupedNumber($_);
    }elsif ( 'pennies' eq $fmt ) {
        $_ = sprintf("%.2f",$_);        # format to fixed 2-place decimal
        s/\.//;                         # remove the decimal point
    }elsif ( $fmt =~ m!^lpad\((.+)\)! ) {
        $_ = Lpad($_, $1, ' ');
    }elsif ( $fmt =~ m!^lzeros\((.+)\)! ) {
        $_ = Lpad($_, $1, 0);
    }

    return $_;
}


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
=head2  _function


=head3  functions

=over

=item curr_time

Current time

 %Y             single digit year
 %YY            two digit year
 %YYYY          four digit year
 %M             month
 %MM            two digit month with leading zero
 %MMM           three character month (Jan)
 %MMMM          complete month (January)
 %D             date
 %DD            two digit date with leading zero
 %W             numeric day of the week (1=Sunday,7=Saturday)
 %WW            two character day of the week (Su)
 %WWW           three character day of the week (Sun)
 %WWWW          complete day of the week (Sunday)
 %h             hour
 %hh            two digit hour with leading zero
 %m             minute
 %mm            two digit minute with leading zero
 %s             seconds
 %ss            two digit seconds with leading zero
 %u             tenths of a second
 %uu            hundredths of a second
 %uuu           milliseconds
 %uuuu          tenths of a millisecond
 %uuuuu         hundredths of a millisecond
 %uuuuuu        microseconds

Directives to specify 12 hour mode:

 %ap            12 hour time mode with lower case "a" or "p"
 %ampm          12 hour time mode with lower case "am" or "pm"
 %AP            12 hour time mode with upper case "A" or "P"
 %AMPM          12 hour time mode with upper case "AM" or "PM"

Offset directives:

 +5h            add five hours
 -5D            subtract five days


=back

=cut

sub _function {
    my $self = shift;
    my ($Map, $value, $inref) = @_;

    $Map->{'function'} =~ m!^(\S+)\((.+)\)!;
    my $fn = $1;
    my $arg = $2;
    return $value if not defined $fn;

    if ( 'curr_time' eq $fn ) {
        $value = $TIME->Now($arg);
    }

    return $value;
}


1;
__END__



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
=head1  Author

Mark K Mueller (www.markmueller.com)


=for html
    <hr>

=cut
