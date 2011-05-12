package Site::Engine;
use strict;
use warnings;
use Data::Dumper;
use CGI qw( path_info request_method );
use Site::Engine::Template;
use Site::Engine::Session;
use Exporter qw( import );
our @EXPORT = qw( header get post template start_site param session dump_env redirect );
our $VERSION = '0.01';

# Private

my %headers;
my $body;
my @routes;
my $config;
my $path_info;
my $request_method;
my $session;

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

sub session ($;$) {
    my ($id,$ret) = Site::Engine::Session::session($session, @_);
    if ($session ne $id) {
        header "Set-Cookie" => CGI::cookie(
                -name   =>"session",
                -value  =>$id,
                -expires=>"+".$config->{session_expires}."s"
            );
    }
    $ret;
}

sub get ($$) {
    my ($route, $sub) = @_;
    push @routes, ['GET',$route, $sub];
}

sub post ($$) {
    my ($route, $sub) = @_;
    push @routes, ['POST',$route, $sub];
}

sub template ($$;$) {
    Site::Engine::Template::template(@_);
}

sub dump_env {
    return Dumper(\$config, \%ENV);
}

sub redirect ($) {
    header "Status" => 303;
    header "Location" => shift();
    "";
}

sub start_site ($) {
    $config = shift;
    $path_info = path_info();
    $request_method = request_method();
    $session = CGI::cookie("session");
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
    if (!$body && !header("Status")) {
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
