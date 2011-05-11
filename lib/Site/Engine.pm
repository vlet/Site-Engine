package Site::Engine;
use strict;
use warnings;
use CGI qw( path_info request_method );
use Site::Engine::Template;
use Site::Engine::Session;
use Exporter qw( import );
our @EXPORT = qw( header get template start_site param cookie );
our $VERSION = '0.01';

# Private

my %headers;
my $body;
my @routes;
my $config;
my $path_info;
my $request_method;
my $cookie;

# Public 
sub header ($;$) {
    my $header = shift;
    if (defined $_[0]) {
        $headers{$header} = $_[0];
    } else {
        return (exists $headers{$header})?
            $headers{$header} :
            undef;
    }
}

sub param (;$) {
    CGI::param(shift());
}

sub cookie (;$) {
    CGI::cookie(shift());
}

sub session ($;$) {
    Site::Engine::Session::session(@_);
}

sub get ($$) {
    my ($route, $sub) = @_;
    push @routes, ['GET',$route, $sub];
}

sub template ($$;$) {
    Site::Engine::Template::template(@_);
}

sub start_site ($) {
    $config = shift;
    $path_info = path_info();
    $request_method = request_method();
    $cookie = CGI::cookie();
    %headers = ();
    $body = "";

    Site::Engine::Template::init($config);
    Site::Engine::Session::init($config);

    header "Content-Type" => "text/html";

    foreach my $route (@routes) {
        if ($request_method eq $route->[0] && $path_info =~ /^$route->[1]$/ ) {
            my @matches = ($path_info =~ /^$route->[1]$/);
            eval {
                $body = $route->[2]->(@matches);
            };
            if ($@) {
                my $err = "";
                if ($config->{debug}) {
                    $err = escape_html($@);
                } 
                $body = qq{
                    <!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
                    <html><head>
                    <title>500 Internal Error</title>
                    </head><body>
                    <h1>Sorry, error</h1>
                    <pre>$err</pre>
                    <p>Please report to webmaster.</p>
                    </body></html>
                };
                $body =~ s/\n\s+/\n/sg;
                header "Status" => 500;
            }
            last;
        }
    }
    if (!$body) {
        $body = qq{
            <!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
            <html><head>
            <title>404 Not Found</title>
            </head><body>
            <h1>Not Found</h1>
            <p>The requested URL was not found on this server.</p>
            </body></html>
        };
        $body =~ s/\n\s+/\n/sg;
        header "Status" => 404;
    }

    print join "\n", map { $_ . ": " . $headers{$_} } keys %headers ;
    print "\n\n";
    print $body;
}

1;
