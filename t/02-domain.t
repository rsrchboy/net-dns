# $Id: 02-domain.t 915 2011-10-10 14:25:06Z willem $	-*-perl-*-

use strict;
use diagnostics;
use Test::More tests => 46;


use constant UTF8 => eval {
	require Encode;
	Encode::decode_utf8( chr(91) ) eq '[';			# specifically not UTF-EBCDIC
};

use constant LIBIDN => eval { require Net::LibIDN; };		# optional IDN support

use constant LIBIDNOK => eval {					# tested and working
	LIBIDN && Net::LibIDN::idn_to_ascii( pack( 'U*', 20013, 22269 ), 'utf-8' ) eq 'xn--fiqs8s';
};



BEGIN {
	use_ok('Net::DNS::Domain');
}


{
	my $domain = new Net::DNS::Domain('example.com');
	isa_ok( $domain,  'Net::DNS::Domain', 'object returned by new() constructor' );
}


{
	eval { my $domain = new Net::DNS::Domain(); };
	my $exception = $1 if $@ =~ /^(.+)\n/;
	ok( $exception ||= '', "empty argument list\t[$exception]" );
}


{
	eval { my $domain = new Net::DNS::Domain(undef); };
	my $exception = $1 if $@ =~ /^(.+)\n/;
	ok( $exception ||= '', "argument undefined\t[$exception]" );
}


t5: {
	my $domain = new Net::DNS::Domain('example.com');
	my $labels = $domain->label;
	is( $labels, 2, 'domain labels separated by dots' );
}


use constant ESC => '\\';

{
	my $case   = ESC . '.';
	my $domain = new Net::DNS::Domain("example${case}com");
	my $labels = $domain->label;
	is( $labels, 1, "$case devoid of special meaning" );
}


{
	my $case   = ESC . ESC;
	my $domain = new Net::DNS::Domain("example${case}.com");
	my $labels = $domain->label;
	is( $labels, 2, "$case devoid of special meaning" );
}


{
	my $case   = ESC . ESC . ESC . '.';
	my $domain = new Net::DNS::Domain("example${case}com");
	my $labels = $domain->label;
	is( $labels, 1, "$case devoid of special meaning" );
}


{
	my $case   = '\092';
	my $domain = new Net::DNS::Domain("example${case}.com");
	my $labels = $domain->label;
	is( $labels, 2, "$case devoid of special meaning" );
}


t10: {
	my $name   = 'example.com';
	my $domain = new Net::DNS::Domain("$name...");
	is( $domain->name, $name, 'ignore gratuitous trailing dots' );
}


{
	my $left   = 'example';
	my $right  = 'com';
	my $domain = new Net::DNS::Domain("$left..$right");
	is( $domain->name, "$left.$right", 'ignore interior null label' );
}


{
	my $domain = new Net::DNS::Domain('');
	is( $domain->name, '.', 'DNS root represented as single dot' );
}


{
	my $name   = 'simple-name';
	my $suffix = 'example.com';
	my $domain = new Net::DNS::Domain($name);
	is( $domain->name, $name, "$name absolute by default" );

	my $create = origin Net::DNS::Domain($suffix);
	my $result = &$create( sub{ new Net::DNS::Domain($name); } );
	my $expect = new Net::DNS::Domain("$name.$suffix");
	is( $result->name, $expect->name, "suffix appended to $name" );
}


t15: {
	foreach my $char ( qw($ ' " ; @) ) {
		my $string = $char . 'example.com.';
		my $domain = new Net::DNS::Domain($string);
		is( $domain->string, ESC . $string, "escape leading $char in string" );
	}
}


t20: {
	eval { my $domain = new Net::DNS::Domain('.example.com') };
	my $exception = $1 if $@ =~ /^(.+)\n/;
	ok( $exception ||= '', "null domain label\t[$exception]" );
}


{
	my @warnings;
	local $SIG{__WARN__} = sub { push( @warnings, "@_" ); };
	my $name      = 'LO-O-O-O-O-O-O-O-O-O-O-O-O-O-O-O-O-O-O-O-O-O-O-O-O-O-O-O-O-O-NG!';
	my $domain    = new Net::DNS::Domain("$name");
	my ($warning) = @warnings;
	chomp $warning;
	ok( $warning, "long domain label\t[$warning]" );
}


{
	my $ldh	      = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-0123456789';
	my $domain    = new Net::DNS::Domain($ldh);
	is( $domain->name, $ldh, '63 octet LDH character label' );
}


SKIP: {
	skip( 'IDN test - Unicode/UTF-8 not supported', 8 ) unless UTF8;
	skip( 'IDN test - Net::LibIDN not installed', 8 ) unless LIBIDN;
	skip( 'IDN test - Net::LibIDN not working', 8 ) unless LIBIDNOK;
	my $a_label = 'xn--fiqs8s';
	my $u_label = eval{ pack( 'U*', 20013, 22269 ); };
	is( new Net::DNS::Domain($a_label)->identifier, $a_label, 'IDN A-label domain->identifier' );
	is( new Net::DNS::Domain($a_label)->string, "$a_label.", 'IDN A-label domain->string' );
	is( new Net::DNS::Domain($a_label)->name, $u_label, 'IDN A-label domain->name' );
	is( new Net::DNS::Domain($a_label)->fqdn, "$u_label.", 'IDN A-label domain->fqdn' );

	is( new Net::DNS::Domain($u_label)->identifier, $a_label, 'IDN U-label domain->identifier' );
	is( new Net::DNS::Domain($u_label)->string, "$a_label.", 'IDN U-label domain->string' );
	is( new Net::DNS::Domain($u_label)->name, $u_label, 'IDN U-label domain->name' );
	is( new Net::DNS::Domain($u_label)->fqdn, "$u_label.", 'IDN U-label domain->fqdn' );
}


t31:{
	foreach my $case (
		'\000\001\002\003\004\005\006\007\008\009\010\011\012\013\014\015',
		'\016\017\018\019\020\021\022\023\024\025\026\027\028\029\030\031'
		) {
		my $domain = new Net::DNS::Domain($case);
		is( $domain->name, $case, "C0 controls:\t$case" );
	}
}


{
	foreach my $case (
		'\032!"#$%&\'()*+,-\./',			#  32 .. 47
		'0123456789:;<=>?',				#  48 ..
		'@ABCDEFGHIJKLMNO',				#  64 ..
		'PQRSTUVWXYZ[\\\\]^_',				#  80 ..
		'`abcdefghijklmno',				#  96 ..
		'pqrstuvwxyz{|}~\127'				# 112 ..
		) {
		my $domain = new Net::DNS::Domain($case);
		is( $domain->name, $case, "G0 graphics:\t$case" );
	}
}


t39: {
	foreach my $case (
		'\128\129\130\131\132\133\134\135\136\137\138\139\140\141\142\143',
		'\144\145\146\147\148\149\150\151\152\153\154\155\156\157\158\159',
		'\160\161\162\163\164\165\166\167\168\169\170\171\172\173\174\175',
		'\176\177\178\179\180\181\182\183\184\185\186\187\188\189\190\191',
		'\192\193\194\195\196\197\198\199\200\201\202\203\204\205\206\207',
		'\208\209\210\211\212\213\214\215\216\217\218\219\220\221\222\223',
		'\224\225\226\227\228\229\230\231\232\233\234\235\236\237\238\239',
		'\240\241\242\243\244\245\246\247\248\249\250\251\252\253\254\255'
		) {
		my $domain = new Net::DNS::Domain($case);
		is( $domain->name, $case, "8-bit codes:\t$case" );
	}
}


exit;
