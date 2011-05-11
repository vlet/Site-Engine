package Site::Engine;
use strict;
use warnings;
use CGI qw( cookie path_info request_method );
use Exporter 'import';
our @EXPORT = qw( header get template start_site param );
our $VERSION = '0.01';

# Private

my %headers;
my $body;
my @routes;
my $config;
my $path_info;
my $request_method;

sub _escape_html ($) {
    my $data = shift;
    return "" if (!$data);
    $data =~ s/&/&amp;/g;
    $data =~ s/</&lt;/g;
    $data =~ s/>/&gt;/g;
    $data =~ s/"/&quot;/g;
    $data =~ s/'/&#39;/g;
    return $data;
}

sub _template ($$) {
    my ($template, $vars) = @_;
    my $file = $config->{htdocs} . "/" . $template . ".tt";
    die "Template $template not found" if (! -f $file);
    local $/;
    open my $fh, "<", $file or die $!;
    my $data = <$fh>;
    close $fh;
    $data =~ s/\[:\s(\w+?)\s\|\sraw\s:\]/(exists $vars->{$1} )?$vars->{$1}:""/eg;
    $data =~ s/\[:\s(\w+?)\s:\]/_escape_html $vars->{$1}/eg;
    return $data;
}

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

sub get ($$) {
    my ($route, $sub) = @_;
    push @routes, ['GET',$route, $sub];
}

sub template ($$;$) {
    my ($template, $vars, $conf) = @_;
    my $data = _template($template, $vars);
    my $layout = (defined $conf && exists $conf->{layout}) ?
            $conf->{layout} :
            $config->{layout} || "main";
    if (defined $layout) {
        $vars->{content} = $data;
        $data = _template($layout, $vars)
    }
    return $data;
}

sub start_site ($) {
    $config = shift;
    $path_info = path_info();
    $request_method = request_method();
    %headers = ();
    $body = "";

    header "Content-Type" => "text/html";

    foreach my $route (@routes) {
        if ($request_method eq $route->[0] && $path_info =~ /^$route->[1]$/ ) {
            my @matches = ($path_info =~ /^$route->[1]$/);
            $body = $route->[2]->(@matches);
            last;
        }
    }
    if (!$body) {
        $body =<<EOF;
<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
<html><head>
<title>404 Not Found</title>
</head><body>
<h1>Not Found</h1>
<p>The requested URL was not found on this server.</p>
</body></html>
EOF
        header "Status" => 404;
    }

    print join "\n", map { $_ . ": " . $headers{$_} } keys %headers ;
    print "\n\n";
    print $body;
}

1;
