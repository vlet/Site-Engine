package Site::Engine;
use strict;
use warnings;
use Data::Dumper;
use CGI qw( path_info request_method );
use Site::Engine::Template;
use Site::Engine::Session;
use Site::Engine::Database;
use Exporter qw( import );
our @EXPORT = qw( header get post template start_site param session dump_env redirect config prefix );
our $VERSION = '0.01';

# Private

my (%headers, $body, @routes, $config, $path_info, $request_method, $session, $addr, $ua);
my $prefix = "";

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
    my ($id,$ret) = Site::Engine::Session::session($session, $addr, @_);
    if (! defined $session || $session ne $id) {
        header "Set-Cookie" => CGI::cookie(
                -name   =>"session",
                -value  =>$id,
                -expires=>"+".$config->{session_expires}."s"
            );
    }
    $ret;
}

sub prefix ($) {
    $prefix = shift;
}

sub get ($$) {
    my ($route, $sub) = @_;
    push @routes, ['GET', $prefix, $route, $sub];
}

sub post ($$) {
    my ($route, $sub) = @_;
    push @routes, ['POST', $prefix, $route, $sub];
}

sub template ($$;$) {
    Site::Engine::Template::template(@_);
}

sub dump_env {
    return join "", Dumper(\$config, \%ENV);
}

sub redirect ($) {
    header "Status" => 303;
    header "Location" => shift();
    "";
}

sub config {
    $config
}

sub start_site ($) {
    $config = shift;
    $path_info = path_info();
    $request_method = request_method();
    $addr = $ENV{"REMOTE_ADDR"};
    $ua   = $ENV{"HTTP_USER_AGENT"};
    $session = CGI::cookie("session");
    %headers = ();
    $body = "";

    Site::Engine::Template::init($config);
    Site::Engine::Session::init($config);
    Site::Engine::Database::init($config);

    header "Content-Type" => "text/html";

    foreach my $route (@routes) {
        if ($request_method eq $route->[0] && $path_info =~ /^$route->[1]$route->[2]$/ ) {
            my @matches = ($path_info =~ /^$route->[1]$route->[2]$/);
            eval {
                $body = $route->[3]->(@matches);
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
__END__

=pod

=head1 NAME

Site::Engine - Ugly CGI-based web-framework with templates, sessions and databases support

=head1 DESCRIPTION

This is simple CGI-based web-framework. Use this only if your hosting has plain perl and
doesn't provide support for modern PSGI-based WF like Dancer or Mojolicious

=head1 SYNOPSIS

    #!/usr/bin/perl
    use strict;
    use warnings;
    use Site::Engine;

    # Configuration of site
    my %config = (
        "htdocs" => "/path/to/templates/dir";
        "db" => {
           "type"   => "mysql",
           "db"     => "db"
           "dbuser" => "dbuser",
           "dbpass" => "dbpass",
        },
        "debug" => 1
    );

    # Routes
    get qr{/} => sub {
        template 'index', {
            data => "hello world!"
        }, { layout => 'main' }
    }

    post qr{/login} => sub {
        my $user = param('user');
        my $pass = paran('pass');
        if ($user eq "admin" && $pass eq "secret") {
            session "user" => "admin";
            redirect '/';
        } else {
            redirect '/?error=badpass'
        }
    }

    # Start engine

    start_site \%config;

=head1 METHODS

=head2 start_site \%config - start processing request

...
 
=head1 COPYRIGHT AND LICENSE

Copyright 2011 by crux E<lt>thecrux@gmail.comE<gt>

This module is free software and is published under the same terms as Perl itself.

=cut
