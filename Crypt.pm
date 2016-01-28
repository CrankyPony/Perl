package Mdc::Crypt;
$VERSION = 1.00;		# 11:19 PM 2004-11-08

=head1	Description

 Mdc::Crypt - Version 1.00 2004-11-08

Description of module


=head1	Synopsis

 use Mdc::Crypt;
 $OBJ = new Mdc::Crypt;


=head1	Methods

=cut



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
require 5.008_000;
require Exporter;
@ISA=qw(Exporter);
@EXPORT_OK=qw/encipher decipher encryptFile decryptFile/;
use strict;
use Carp;
use Digest::MD5 qw/md5/;
use constant hL => 16;					# length of hash string



sub encryptFile {
	my($file, $key) = @_;
	open(FL, '+<', $file) or die 'file error';
	binmode FL;
	use integer;
	my $p = 0;

	# calculate checksum
	read  FL, my($cs), 1;				# get first char
	until( eof FL ){
		read  FL, my($c), 1;			# XOR with next char
		$cs ^= $c;
	}
	$key .= $cs;
	my $hash = md5 $key;				# create hash

	seek  FL, 0, 0;
	until( eof FL ){
		read  FL, my($recd), hL;
		$hash = substr($hash,0,length $recd) if hL > length $recd;
		seek  FL, $p, 0;
		print FL  $recd ^= $hash;
		$hash = md5 $recd.$key;
		seek  FL, $p += hL, 0;
	}

	seek  FL, -s $file, 0;
	print FL $cs;
	close FL;
}

sub decryptFile {
	my($file, $key) = @_;
	open(FL, '+<', $file) or die 'file error';
	binmode FL;
	use integer;

	my $tmpfile = "$file.tmp";
	while( -f $tmpfile ){
		my $i++;
		$tmpfile = "$file.tmp$i";
	}
	open OUT, ">$tmpfile" or die 'file error';
	binmode OUT;

	my $p = 0;
	seek  FL, (-s $file)-1, 0;
	read  FL, my($cs), 1, 0;			# get checksum char
	$key .= $cs;

	my $hash = md5 $key;				# create hash
	seek  FL, 0, 0;
	until( eof FL ){
		read  FL, my($recd), hL;
		chop $recd if eof FL;
		last if not length $recd;
		$hash = substr($hash,0,length $recd) if hL > length $recd;
		seek  FL, $p, 0;
		print OUT $recd ^ $hash;
		$hash = md5 $recd.$key;
		seek  FL, $p += hL, 0;
	}
	close FL;
	close OUT;
	unlink $file;
	rename $tmpfile, $file;
}


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

=head2	encipher

 encipher( SCALAR REF, SCALAR)

Encrypt a string.

=cut

sub encipher {
	my($ref, $key) = @_;
	## my $cs = _checksum($ref);			# get checksum
	my $hash = md5 $key;				# create hash
	my $l = int(length($$ref) / hL) * hL;		# number of blocks
	my $r = int(length($$ref) % hL);		# remainder
	my $i;
	for( $i=0; $i<$l; $i+=hL ){
		substr($$ref,$i,hL) = substr($$ref,$i,hL) ^ $hash;
		$hash = md5 substr($$ref,$i,hL).$key;
	}
	substr($$ref,$i,$r) = substr($$ref,$i,$r) ^ substr($hash,0,$r) if $r;
	## $$ref .= substr($key,0,1) ^ $cs;		# append checksum to result
	return;
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

=head2	decipher

 decipher( SCALAR REF, SCALAR)

Decrypt a string.

=cut

sub decipher {
	my($ref, $key) = @_;
	## my $cs = substr($key,0,1) ^ substr $$ref, length($$ref)-1, 1;		# get checksum
	## chop $$ref;								# remove checksum
	my $l = int(length($$ref) / hL) * hL;
	my $r = int(length($$ref) % hL);
	my $hash = md5 $key;
	my $i;
	for( $i=0; $i<$l; $i+=hL ){
		my $phash = substr($$ref,$i,hL);
		substr($$ref,$i,hL) = substr($$ref,$i,hL) ^ $hash;
		$hash = md5 $phash.$key;
	}
	substr($$ref,$i,$r) = substr($$ref,$i,$r) ^ substr($hash,0,$r) if $r;
	return;
}



# Calculate the checksum of a string
sub _checksum {
	my $r = shift;
	my $l = length $$r;
	my $c = substr $$r, 0, 1;		# get first char
	foreach( 1 ... $l ){
		$c = $c ^ substr $$r, $_, 1;	# XOR with next char
	}
	return $c;				# return result
}



1;
__END__





# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

=head1	Examples

 $text = "Testing, one, two, three...";
 cipher( \$text, 'XyZ' );


=head1	Author and Copyright

 Mdc::Crypt Copyright (c) 2004 Mark K Mueller. All rights reserved.
 www.markmueller.com

=for html
	<hr>
	<small>MkM 2004/11/08</small>

=cut
