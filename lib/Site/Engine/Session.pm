package Site::Engine::Session;
use strict;
use warnings;
use Fcntl;

our $VERSION = '0.01';

my $config;

# Public

sub init ($) {
    $config = shift;
    die "failed to setup session dir"
      if ( !exists $config->{"session_dir"}
        || !-d $config->{"session_dir"} );
    $config->{session_expires} = $config->{session_expires} || 60 * 30;
}

sub destroy_session ($$) {
    my $file = _session_file(@_);
    if ( defined $file ) {
        unlink $file;
    }
}

sub session {
    my ( $id, $addr, $field, $value ) = @_;

    my $file = _session_file( $id, $addr );

    if ( defined $file ) {
        my $time = time;
        my $dt = $time - ( stat($file) )[9];
        if ( $dt < $config->{session_expires} ) {
            open my $fh, "<", $file or die $!;
            my %s;
            while (<$fh>) {
                chomp();
                my ( $var, @value ) = split /=/, $_;
                $s{$var} = join "=", @value;
            }
            close $fh;
            if ( defined $value && defined $field && $field ne "id" ) {
                $s{$field} = $value;
                open my $fh, ">", $file or die $!;
                foreach my $key ( keys %s ) {
                    print $fh $key . "=" . $s{$key} . "\n";
                }
                close $fh;
            }
            elsif ( defined $field ) {
                $value = ( $field eq "id" ) ? $id : $s{$field};
            }
            else {
                $s{id} = $id;
                $value = \%s;
            }
            utime $time, $time, $file;
            return ( $id, $value );
        }
        else {

            # delete old session file
            unlink $file;
        }
    }
    $id = &_generate_session( $addr, $field, $value );
    return ($id);
}

# Private

sub _session_file ($$) {
    my ( $id, $addr ) = @_;

    # is addr sane
    return if ( $addr !~ /^[\d\.]+$/ );

    my $file = $config->{"session_dir"} . "/" . $addr . "-";
    if (   defined $id
        && length $id == 16
        && $id !~ /\W/
        && -f $file . $id )
    {
        return $file . $id;
    }
    return;
}

sub _generate_session ($$) {
    my ( $addr, $field, $value ) = @_;

    # is addr sane
    return if ( $addr !~ /^[\d\.]+$/ );

    my $id;
    foreach my $i ( 0 .. 9 ) {
        $id = join '',
          ( "_", 0 .. 9, "a" .. "z", "A" .. "Z" )
          [ map { int( rand 63 ) } ( 1 .. 16 ) ];
        if (
            sysopen my $fh,
            $config->{"session_dir"} . "/" . $addr . "-" . $id,
            O_CREAT | O_EXCL | O_WRONLY
          )
        {
            print $fh $field . "=" . $value . "\n"
              if ( defined $value && defined $field && $field ne "id" );
            close($fh);
            last;
        }
        else {
            $id = undef;
        }
    }
    $id;
}

1;
__END__

=pod

=head1 NAME

Site::Engine::Sesion - Session handling

=head1 METHODS

=head2 init ( \%config ) - init module with configuration

=over

=item "session_dir"     - existed and writable directory for session files

=item "session_expires" - lifetime in seconds of session

=back
        
=head2 session( $id, $addr, $key, $value ) - get/set values for current session.

=over

=item $id    - id (16 random symbols \w) of current session or undef (to create new session)

=item $addr  - ip-address of client (REMOTE_ADDR)

=item $key   - get/set some attribute of current session (if undefined - return ref to hash with all values)

=item $value - set attribute $key with specified $value (if undefined - function is getter)

=back

=head1 DESCRIPTION

This module provide simple session support based on a plain files (one per
session) with key=value in each line. Name of session file is $addr-$id

=head1 COPYRIGHT AND LICENSE

Copyright 2011 by crux E<lt>thecrux@gmail.comE<gt>

This module is free software and is published under the same terms as Perl itself.

=cut
