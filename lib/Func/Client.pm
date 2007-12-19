package Func::Client;

use 5.006001;
use strict;
use warnings;

our $VERSION = '0.04';
$VERSION = eval $VERSION;  # see L<perlmodstyle>

use Carp;
use Params::Validate qw(SCALAR validate);
use Regexp::Common;
use Frontier::Client;
require File::Spec;

# package-global defaults
# this matches func's defaults for "just works" configuration
our $__pki_dir  = '/etc/pki/func';
our $__key      = 'ca/funcmaster.key';
our $__cert     = 'ca/funcmaster.crt';
our $__ca_cert  = 'ca.cert';
our $__port     = 51234;
our $__certmaster_config = '/etc/func/certmaster.conf';

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
            optional => undef
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
        minion   => normalize_minion_uri( $params{minion} ),
        pki_dir  => $params{pki_dir} || $__pki_dir,
        key      => $params{key}     || $__key,
        cert     => $params{cert}    || $__cert,
        ca_cert  => $params{ca_cert} || $__ca_cert
    }, $type;

    $self->save_env;

    $self->{xmlrpc} = Frontier::Client->new( url => $self->{minion} );

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

    return $r;
}

=item list_minions()

Returns a list of minion hostnames based on Func's certificate database.

 foreach my $minion ( Func::Client->list_minions ) {
     print "Minion: $minion\n";
 }

=cut

# if anybody uses this with a crazy number of hosts, it might be worth
# modifying this to return a tied array backed on the directory listing
sub list_minions {
    my $class = shift;
    my @minions = ();

    # this is the same list as list_certs, but with the path and '.cert' chopped off
    foreach my $cert ( $class->list_certs ) {
        $cert =~ s/.*\/(.*)\.cert$/$1/;
        push @minions, $cert;
    }
    return @minions;
}

=item list_certs()

List all the certs this master knows about.

=cut

sub list_certs {
    my $class = shift;
    my @certs = ();

    open my $fh, "< $__certmaster_config"
        or die "Unable to open $__certmaster_config for reading: $!";

    my $certroot = '/var/lib/func/certmaster/certs';
    while ( my $line = <$fh> ) {
        if ( $line =~ /certroot\s+=\s*([^\s]+)$/ ) {
            $certroot = $1;
        }
    }
    close $fh;

    opendir my $dir_fh, "$certroot";
    while ( my $file = readdir $dir_fh ) {
        my $certfile = File::Spec->catfile( $certroot, $file );
        next unless ( -f $certfile && $certfile =~ /\.cert$/ );
        push @certs, $certfile;
    }

    return @certs;
}

# minion uri normalization method - split out of new() mainly so it can be tested easily
sub normalize_minion_uri {
    my $minion = shift;

    # https://foo.com:4000 or https://foo.com
    if ( $minion =~ /^$RE{URI}{HTTP}{-scheme => 'https'}{ -keep}/ ) {
        my $port = $4 || $__port;

        if ( defined($5) and $5 ne '/' ) { # $5 is path/query, which are invalid
            confess "Func::Client does not understand URI's with paths beyond the root '/' and you provided '$5'";
        }

        return "https://$3:$port/";
    }

    # 127.0.0.1
    elsif ( $minion =~ /^$RE{net}{IPv4}{dec}{-keep}$/ ) {
        return "https://$1:$__port/";
    }

    # 127.0.0.1:4000
    elsif ( $minion =~ /^$RE{net}{IPv4}{dec}{-keep}:\d+$/ ) {
        my $host = $1;
        my $port = (split(/:/, $minion, 2))[1] || $__port;
        return "https://$host:$port/";
    }

    # foo.bar.com
    elsif ( $minion =~ /^$RE{net}{domain}{-keep}$/ ) {
        return "https://$1:$__port/";
    }

    # foo.bar.com:4000
    elsif ( $minion =~ /^$RE{net}{domain}{-keep}{-nospace}:\d+$/ ) {
        my $host = $1;
        my $port = (split(/:/, $minion, 2))[1] || $__port;
        return "https://$host:$port/";
    }

    # Be helpful and mention that other URI's (like http://), while valid
    # in their own right, are not accepted by this module.
    elsif ( $minion =~ /$RE{URI}/ ) {
        confess "Only https:// URI's are accepted.";
    }

    # else
    confess "Invalid minion address '$minion'.";
}

# Crypt::SSLeay/Net::SSL require environment variables to set up client
# certificates and to force SSLv3.
# local() does not seem to work, even if it's in the same lexical scope as
# call().
sub save_env {
    my $self = shift;
    unless ( $self->{__global_env} ) {
        my %oldenv = ();
        foreach my $key (qw(HTTPS_CERT_FILE HTTPS_KEY_FILE HTTPS_VERSION)) {
            $oldenv{$key} = $ENV{$key};
        }
        $self->{__global_env} = \%oldenv;
    }
}

sub set_env {
    my $self = shift;
    # Net::SSLeay options
    $ENV{HTTPS_CERT_FILE} = File::Spec->catdir( $self->{pki_dir}, $self->{cert} );
    $ENV{HTTPS_KEY_FILE}  = File::Spec->catdir( $self->{pki_dir}, $self->{key}  );
    $ENV{HTTPS_VERSION}   = 3;
}

sub restore_env {
    my $self = shift;
    foreach my $key (qw(HTTPS_CERT_FILE HTTPS_KEY_FILE HTTPS_VERSION)) {
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

If your program is using any of the HTTPS_* environment variables you might encounter some weirdness because this module has to swap them out for every call().  It should "just work", but it's worth checking if you're seeing weirdness around environment variables.

=head1 SEE ALSO

 * func - https://hosted.fedoraproject.org/func/
 * Frontier::Client

=head1 AUTHOR

Al Tobey <tobert@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 by Albert P. Tobey <tobert@gmail.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.

=cut

