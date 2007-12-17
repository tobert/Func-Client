package Func::Client;

use 5.006001;
use strict;
use warnings;

our $VERSION = '0.03';
$VERSION = eval $VERSION;  # see L<perlmodstyle>

use Carp;
use Params::Validate qw(SCALAR validate);
use XMLRPC::Lite;
require File::Spec;

# package-global defaults
# this matches func's defaults for "just works" configuration
our $__pki_dir  = '/etc/pki/func';
our $__key      = 'ca/funcmaster.key';
our $__cert     = 'ca/funcmaster.crt';
our $__ca_cert  = 'ca.cert';

=head1 NAME

Func::Client - perl interface to Func over XMLRPC

=head1 SYNOPSIS

  use Func::Client;

  my $func = Func::Client->new( minion => '127.0.0.1' );
  $func->call( 'test.add', [ 1, 2 ] );

=head1 DESCRIPTION

This is a lightweight wrapper around XMLRPC::Lite and sane defaults for the
Fedora Unified Network Controller (https://hosted.fedoraproject.org/func/).

=head1 METHODS

=over 4

=item new()

Create a Func::Client object.  Objects are 1:1 with minions, so to execute
on multiple minions, loop through them and create an object for each.   The
object is reusable for multiple call()'s.

 my $func = Func::Client->new();

 my $func = Func::Client->new(
    minion => "https://minion.mydomain.com:51234"
 );

=cut

sub new {
    my $type = shift;

    my %params = validate( @_, {
        __testing => 0,
        minion  => {
            type => SCALAR,
            optional => undef,
            callbacks => { 'invalid URI' => sub { $_[0] =~ m#https://.*:\d+# } }
        },
        pki_dir => {
            type => SCALAR,
            optional => 1,
            callbacks => { 'invalid path' => sub { -d $_[0] } }
        },
        key     => {
            type => SCALAR,
            optional => 1,
            callbacks => {
                'not a relative path' => sub { $_[0] !~ m#^/# },
                'cannot read file'    => sub { -r $_[0] }
            }
        },
        cert    => {
            type => SCALAR,
            optional => 1,
            callbacks => {
                'not a relative path' => sub { $_[0] !~ m#^/# },
                'cannot read file'    => sub { -r $_[0] }
            }
        },
        ca_cert => {
            type => SCALAR,
            optional => 1,
            callbacks => {
                'not a relative path' => sub { $_[0] !~ m#^/# },
                'cannot read file'    => sub { -r $_[0] }
            }
        }
    } );

    # create the object
    my $self = bless {
        minion   => $params{minion},
        pki_dir  => $params{pki_dir} || $__pki_dir,
        key      => $params{key}     || $__key,
        cert     => $params{cert}    || $__cert,
        ca_cert  => $params{ca_cert} || $__ca_cert
    }, $type;

    unless ( $self->{__global_env} ) {
        my %oldenv = ();
        foreach my $key (qw(HTTPS_CERT_FILE HTTPS_KEY_FILE HTTPS_VERSION HTTPS_CA_FILE)) {
            $oldenv{$key} = $ENV{$key};
        }
        $self->{__global_env} = \%oldenv;
    }

    $self->{xmlrpc} = XMLRPC::Lite->new();
    $self->{xmlrpc}->on_fault( \&__faultcroak );
    $self->{xmlrpc}->proxy( $self->{minion} );

    return $self;
}

=item call()

Call a method in funcd on the minion.   This is analogous to "call" in the func command-line
program, except you specify $module.$method then arguments in list format.

Multiple call()'s can be made on the same object.

 my $result = $func->call( 'test.add', 4, 3 );
 print Data::Dumper::Dumper( $result );

=cut

sub call {
    my( $self, $method, @args ) = @_;
    my $r = undef;

    $self->set_env;

    # Catch exceptions from the request so that we can be sure
    # to restore the %ENV variables that set_env() mucks with.
    eval {
        $r = $self->{xmlrpc}->call( $method, @args );
    };

    $self->restore_env;

    # Now propagate any caught exceptions.
    if ( $@ ) {
        confess "XMLRPC request for method '$method' failed: $@";
    }

    # This occasionally happened during testing of XMLRPC::Lite when
    # I had the certificates configured wrong.
    unless ( ref $r ) {
        confess "Result is not a reference.   Something must have gone wrong during the XMLRPC transaction, but I don't know what it is.   Most likely, there is a problem with your program and funcd agreeing on certificate authentication.";
    }

    return $r->result;
}

# SOAP::Transport::HTTP uses Crypt::SSLeay for SSL sockets.
# It looks like there isn't a cleaner way to pass certificate information
# around other than these environment variables.   So, take the hit and
# be careful to set/unset them in call().
# local() does not seem to work, even if it's in the same lexical scope as
# call().
sub set_env {
    my $self = shift;
    # Net::SSLeay options
    $ENV{HTTPS_CERT_FILE} = File::Spec->catdir( $self->{pki_dir}, $self->{cert} );
    $ENV{HTTPS_KEY_FILE}  = File::Spec->catdir( $self->{pki_dir}, $self->{key}  );
    $ENV{HTTPS_VERSION}   = 3;
    $ENV{HTTPS_CA_FILE}   = File::Spec->catdir( $self->{pki_dir}, $self->{ca_cert} );
}

sub restore_env {
    my $self = shift;
    foreach my $key (qw(HTTPS_CERT_FILE HTTPS_KEY_FILE HTTPS_VERSION HTTPS_CA_FILE)) {
        $ENV{$key} = $self->{__global_env}{$key};
    }
}

# might make it an option to override this method in the future ...
sub __faultcroak {
    my( $self, $xmlrpc ) = @_;

    if ( ref $xmlrpc ) {
        confess "XMLRPC Request failed with fault: ". $xmlrpc->faultstring();
    }
    else {
        confess "XMLRPC Request failed. ($xmlrpc)";
    }
}

1;

__END__

=pod

=back

=head1 NOTES OF INTEREST

If your program is using any of the environment variables HTTPS_CERT_FILE, HTTPS_KEY_FILE, HTTPS_VERSION, or HTTPS_CA_FILE, you might encounter some weirdness because this module has to swap them out for every call().  It should "just work", but it's worth checking if you're seeing weirdness around environment variables.

=head1 SEE ALSO

 * func - https://hosted.fedoraproject.org/func/
 * XMLRPC::Lite

=head1 AUTHOR

Al Tobey <tobert@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 by Albert P. Tobey <tobert@gmail.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.

=cut

