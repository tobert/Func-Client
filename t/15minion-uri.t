#!/usr/local/bin/perl

use strict;
use warnings;
use lib qw( ./lib ../lib );
use Test::More tests => 48;
use Test::Exception;
use Func::Client;

my @valid_examples = qw(
    foo
    127.0.0.1
    127.0.0.1:5000
    https://127.0.0.1/
    https://127.0.0.1:5000/
    localhost
    localhost:5001
    https://localhost/
    https://localhost:5002/
    foo.bar.com
    foo.bar.baz.bark.woof.meow.moo.org
    https://hosted.fedoraproject.org:51234/
    hosted.fedoraproject.org
    www.kernel-panic.org
);

my @invalid_examples = qw(
    http://127.0.0.1:51234/
    323.1.1.1
    tcp://127.0.0.1:51234/
    https://localhost:5002/foo/bar
    127.0.0.1/abc
    127.0.0.1:5001/abc
);

foreach my $uri ( @valid_examples ) {
    diag( '' );
    diag( "Valid URI: $uri" );
    my $res;
    lives_ok( sub { $res = Func::Client::normalize_minion_uri( $uri ) },
              "normalization lives" );
    my $res2;
    lives_ok( sub { $res2 = Func::Client::normalize_minion_uri( $res ) },
              "Result of previous test passes inspection." );
    is( $res2, $res, "Output of previous two normalizations are exactly the same." );

    diag( $res2 );
}

foreach my $uri ( @invalid_examples ) {
    diag( '' );
    diag( "Invalid URI: $uri" );
    dies_ok( sub { Func::Client::normalize_minion_uri( $uri ) },
             "throw an exception on invalid input" );
}

