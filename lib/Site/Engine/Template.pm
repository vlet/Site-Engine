package Site::Engine::Template;
use strict;
use warnings;
use Exporter qw( import );
our @EXPORT = qw( escape_html );
our $VERSION = '0.01';

my $config;

# Public

sub init ($) {
    $config = shift;
}

sub escape_html ($) {
    my $data = shift;
    return "" if (!$data);
    $data =~ s/&/&amp;/g;
    $data =~ s/</&lt;/g;
    $data =~ s/>/&gt;/g;
    $data =~ s/"/&quot;/g;
    $data =~ s/'/&#39;/g;
    return $data;
}

sub template {
    my ($template, $vars, $conf) = @_;
    my $data = &_template($template, $vars);
    my $layout = (defined $conf && exists $conf->{layout}) ?
            $conf->{layout} :
            $config->{layout} || "main";
    if (defined $layout) {
        $vars->{content} = $data;
        $data = &_template($layout, $vars)
    }
    return $data;
}

# Private

sub _if ($$$) {
    my ($var, $block, $vars) = @_;
    return $block if ( exists $vars->{$var} && $vars->{$var} );
    "";
}

sub _set ($$$) {
    my ($var, $value, $vars) = @_;
    $vars->{$var} = $value;
    "";
}

sub _include ($$) {
    my ($template, $vars) = @_;
    &_template($template, $vars);
}

sub _vars ($$) {
    my ($ref, $vars) = @_;
    $$ref =~ s/\[%\sSET\s(\w+)\s?=\s?\"(.+?)\"\s%\]/_set $1,$2,$vars/eg;
    $$ref =~ s/\[%\sINCLUDE\s(\w+)\s%\]/_include $1, $vars/eg;
    $$ref =~ s/\[%\sIF\s([\w\.]+)\s%\](.+?)\[%\sFI\s%\]/_if $1,$2,$vars/seg;
    $$ref =~ s/\[%\s([\w\.]+?)\s\|\sraw\s%\]/(exists $vars->{$1} )?$vars->{$1}:""/eg;
    $$ref =~ s/\[%\s([\w\.]+?)\s%\]/escape_html $vars->{$1}/eg;

    # remove all other tags
    $$ref =~ s/\[%.+?%\]//g;
}

sub _foreach ($$$$) {
    my ($hash_name, $array_name, $block, $vars) = @_;
    my $output = "";
    return "" if (! exists $vars->{$array_name});
    foreach my $h_ref ( @{ $vars->{$array_name} } ) {
        foreach my $key ( keys %$h_ref ) {
            $vars->{$hash_name.".".$key} = $h_ref->{$key};
        }
        my $copy = $block;
        _vars \$copy, $vars;
        $output .= $copy;
        foreach my $key ( keys %$h_ref ) {
            delete $vars->{$hash_name.".".$key};
        }
    }
    return $output;
}

sub _template ($$) {
    my ($template, $vars) = @_;
    my $file = $config->{htdocs} . "/" . $template . ".tt";
    die "Template $template not found" if (! -f $file);
    local $/;
    open my $fh, "<", $file or die $!;
    my $data = <$fh>;
    close $fh;
    $data =~ s/\[%\sFOREACH\s(\w+)\sIN\s(\w+)\s%\](.+?)\[%\sEND\s%\]/_foreach $1,$2,$3,$vars/seg;
    _vars \$data, $vars;
    return $data;
}

1;
