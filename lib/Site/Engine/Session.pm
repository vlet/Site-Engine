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
        if (   !exists $config->{"session_dir"}
            || !-d     $config->{"session_dir"} );
    $config->{session_expires} = $config->{session_expires} || 60*60*24*30;
}

sub session {
    my ($id, $field, $value) = @_;
    if (   defined $id
        && length $id == 16
        && $id !~ /\W/
        && -f $config->{"session_dir"} . "/" . $id
    ) {
        my $file = $config->{"session_dir"} . "/" . $id;
        my $dt = time - ( stat($file) )[9];
        if ($dt < $config->{session_expires}) {
            open my $fh, "<", $file or die $!;
            my %s;
            while (<$fh>) {
                chomp();
                my ($var,@value) = split /=/, $_;
                $s{$var} = join "=", @value;
            }
            close $fh;
            if (defined $value && defined $field && $field ne "id") {
                $s{$field} = $value;
                open my $fh, ">", $file or die $!;
                foreach my $key (keys %s) {
                    print $fh $key."=".$s{$key}."\n";
                }
                close $fh;
            }
            elsif (defined $field) {
                $value = ($field eq "id")?$id:$s{$field};
            }
            else {
                $s{id} = $id;
                $value = \%s;
            }
            return ($id,$value);
        }
        else {

            # delete old session file
            unlink $file;
        }
    }
    $id = &_generate_session($field, $value);
    return ($id);
}

# Private

sub _generate_session ($$) {
    my ($field, $value) = @_;
    my $id;
    foreach my $i (0..9) {
        $id = join '',
              ( "_", 0 .. 9, "a" .. "z", "A" .. "Z" )
                    [ map { int( rand 63 ) } ( 1 .. 16 ) ];
        if ( sysopen my $fh, $config->{"session_dir"} ."/". $id, O_CREAT|O_EXCL|O_WRONLY )  {
            print $fh $field ."=". $value ."\n" if (defined $value && defined $field && $field ne "id");
            close ($fh);
            last;
        }
        else { 
            $id = undef;
        }
    }
    $id;
}

1;
