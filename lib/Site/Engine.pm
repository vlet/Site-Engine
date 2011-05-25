package Site::Engine;
use strict;
use warnings;
use Data::Dumper;
use Time::HiRes qw( gettimeofday tv_interval );
my $t0 = [gettimeofday];
use CGI qw( path_info request_method );
use Site::Engine::Template;
use Site::Engine::Session;
use Site::Engine::Database;
use Exporter qw( import );
our @EXPORT = qw( header get post template start_site param session dump_env redirect config prefix database to_dumper layout escape url_escape );
our $VERSION = '0.01';

# Private

my (%headers, $body, @routes, $config, $path_info, $request_method, $session, $addr, $ua, $layout);
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

sub escape ($) {
    escape_html(shift());
}

sub url_escape ($) {
    CGI::escape(shift());
}

sub session (;$$) {
    if (scalar @_ == 1 && !defined $_[0]) {
        Site::Engine::Session::destroy_session($session, $addr);
        $session = undef;
    }
    else {
        my ($id,$ret) = Site::Engine::Session::session($session, $addr, @_);
        if (! defined $session || $session ne $id) {
            header "Set-Cookie" => CGI::cookie(
                    -name   =>"session",
                    -value  =>$id,
                    #-expires=>"+".$config->{session_expires}."s"
                );
        }
        return $ret;
    }
}

sub prefix ($) {
    $prefix = shift;
}

sub layout ($) {
    $layout = shift;
}

sub get ($$) {
    my ($route, $sub) = @_;
    push @routes, ['GET', $prefix, $route, $sub, $layout];
}

sub post ($$) {
    my ($route, $sub) = @_;
    push @routes, ['POST', $prefix, $route, $sub, $layout];
}

sub template ($$;$) {
    if (! exists $_[1]->{prefix} ) {
        $_[1]->{prefix} = $prefix;
    }
    my $conf = (scalar @_ == 3)?pop(@_):{};
    if (!exists $conf->{layout} && defined $layout) {
        $conf->{layout} = $layout;
    }
    Site::Engine::Template::template(@_, $conf);
}

sub dump_env {
    return join "", Dumper(\$config, \%ENV);
}

sub redirect ($) {
    my $location = shift;
    $location = $prefix.$location if ($location !~ m'^\w+://');
    header "Status" => 303;
    header "Location" => $location;
    "";
}

sub config {
    $config
}

sub database {
    dbh;
}

sub to_dumper {
    Dumper(shift());
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
            $prefix = $route->[1];
            $layout = $route->[4];
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
    header "X-Elapsed-Time" => tv_interval ( $t0 );

    binmode STDOUT, ":utf8";

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
        "templates" => "/path/to/templates/dir";
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
