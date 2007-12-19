#!/usr/local/bin/perl

use XMLRPC::Lite;
use XMLRPC::Lite ( qw( trace all ));

use Data::Dumper;
use Scalar::Util;

$ENV{HTTPS_CERT_FILE} = '/etc/pki/func/ca/funcmaster.crt';
$ENV{HTTPS_KEY_FILE}  = '/etc/pki/func/ca/funcmaster.key';
$ENV{HTTPS_VERSION} = 3;
$ENV{HTTPS_CA_FILE}   = '/etc/pki/func/ca.cert';

my $x = XMLRPC::Lite->new();
$x->on_fault( sub { die "Failed: ".$_[1]->faultstring() } );
$x->proxy( 'https://localhost:51234/' );
my $res = $x->call( 'test.add', 1, 2 );
#my $res = $x->call( 'test.list_methods' );
print "RESULT: ", Dumper($res->result), "\n";

exit 0;

