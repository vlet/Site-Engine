package Site::Engine::Database;
use strict;
use warnings;
use DBI;
use Exporter qw( import );
our @EXPORT  = qw( dbh );
our $VERSION = '0.01';

my $config;
my $dbh;
my $dbi = {
    sqlite => sub {
        my $db_conf = shift;
        DBI->connect( "dbi:SQLite:dbname=" . $db_conf->{db_file},
            "", "", { RaiseError => 1, sqlite_unicode => 1 } );
    },
    mysql => sub {
        my $db_conf = shift;
        DBI->connect(
            "DBI:mysql:database=" 
              . $db_conf->{db}
              . (
                ( exists $db_conf->{db_host} ) ? ";host=" . $db_conf->{db_host}
                : ""
              )
              . (
                ( exists $db_conf->{db_port} ) ? ";port=" . $db_conf->{db_port}
                : ""
              ),
            $db_conf->{db_user},
            $db_conf->{db_pass},
            { RaiseError => 1, mysql_enable_utf8 => 1 }
        );
    },
};

# Public

sub dbh {
    $dbh;
}

sub init ($) {
    $config = shift;
    die "Unsupported type of db" if ( !exists $dbi->{ $config->{db}->{type} } );
    $dbh = $dbi->{ $config->{db}->{type} }->( $config->{db} );
}

1;
__END__

=pod

=head1 NAME

Site::Engine::Database - simple support for SQL databases

=head1 DESCRIPTION

This module provide simple database support for MySQL and SQLite

    # MySQL
    my %config = (
        ...
        "db" => {
           "type"   => "mysql",
           "db"     => "db",
           "dbhost" => "mysql.server",  # optional
           "dbport" => 3306,            # optional
           "dbuser" => "dbuser",
           "dbpass" => "dbpass",
        },
        ...
    );

    # SQLite
    my %config = (
        ...
        "db" => {
           "type"   => "sqlite",
           "db_file"=> "/path/to/sqlite.db",
           "dbuser" => "",
           "dbpass" => "",
        },
        ...
    );

=head1 COPYRIGHT AND LICENSE

Copyright 2011 by crux E<lt>thecrux@gmail.comE<gt>

This module is free software and is published under the same terms as Perl itself.

=cut
