# $Id: 99-cleanup.t 1068 2012-12-06 10:38:51Z willem $ -*-perl-*-
use Test::More;
plan tests => 1;

diag ("Cleaning");

unlink("t/online.disabled") if (-e "t/online.disabled");
unlink("t/IPv6.disabled") if (-e "t/IPv6.disabled");

ok(1,"Dummy");



