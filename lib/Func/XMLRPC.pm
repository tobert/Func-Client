package Func::XMLRPC;

use 5.006001;
use strict;
use warnings;

our $VERSION = '0.00_01';
$VERSION = eval $VERSION;  # see L<perlmodstyle>

=head1 NAME

Func::XMLRPC - perl interface to Func over XMLRPC

=head1 SYNOPSIS

  use Func::XMLRPC;

  my $func = Func::XMLRPC->new( master => '127.0.0.1' );
  $func->call( '' );

=head1 DESCRIPTION

=head1 METHODS

=over 4

=item new()

=cut

sub new {

}

1;

__END__

=back

=back

=head1 SEE ALSO

 * func - 
 * XMLRPC::Lite

=head1 AUTHOR

Al Tobey <tobert@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 by Albert P. Tobey <tobert@gmail.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.

=cut

