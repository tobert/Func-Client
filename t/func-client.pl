#!/usr/local/bin/perl

use lib qw( ./lib ../lib );
use Func::Client;
use Data::Dumper;

my $x = Func::Client->new( minion => 'https://localhost:51234' );

my $res = $x->call( 'test.list_methods' );
print "RESULT: ", Dumper($res), "\n";

$res = $x->call( 'test.add', 1, 3 );
print "RESULT: ", Dumper($res), "\n";

exit 0;

