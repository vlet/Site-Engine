package Site::Engine::Database;
use strict;
use warnings;
use Exporter qw( import );
our @EXPORT = qw( connect );
our $VERSION = '0.01';

my $config;

# Public

sub init ($) {
    $config = shift;
}

1;
__END__
=pod

=head1 NAME

Site::Engine::Database - simple support for SQL databases

=head1 METHODS

=head1 DESCRIPTION

This module provide simple database support for MySQL and SQLite

=head1 COPYRIGHT AND LICENSE

Copyright 2011 by crux E<lt>thecrux@gmail.comE<gt>

This module is free software and is published under the same terms as Perl itself.

=cut
