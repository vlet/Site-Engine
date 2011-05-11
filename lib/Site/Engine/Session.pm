package Site::Engine::Session;
use strict;
use warnings;
use Fcntl;
use CGI qw( cookie );

our $VERSION = '0.01';

my $config;

# Public

sub init ($) {
    $config = shift;
}

sub session {
    my $field = shift;
    if (exists cookie("session")) {
        
    }
}

# Private

sub _generate_session {
    die "failed to setup session dir" if (
           !exists $config->{"session_dir"}
        || ! -d $config->{"session_dir"} );

    my $id;
    foreach my $i (0..9) {
        $id = join '',
              ( "_", 0 .. 9, "a" .. "z", "A" .. "Z" )
                    [ map { int( rand 63 ) } ( 1 .. 16 ) ];
        
        if ( sysopen my $fh, $config->{"session_dir"} ."/". $id, O_CREAT|O_EXCL )  {
            close ($fh);
            last;
        } else {
            $id = undef;
        }
    }
    $id;
}

1;
