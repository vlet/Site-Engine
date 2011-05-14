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

sub _ifs ($$$$$$) {
    my ($not, $var, $subvar, $value, $block, $vars) = @_;
    if (! exists $vars->{$var}) {
        return ($not)?$block:"";
    }
    my $ret;
    if ( !defined($subvar) ) {
        $ret = $vars->{$var};
    }
    elsif ( ref $vars->{$var} eq "HASH" && exists $vars->{$var}->{$subvar} ) {
        $ret = $vars->{$var}->{$subvar};
    }
    elsif ( ref $vars->{$var} eq "ARRAY" && $subvar !~ /\D/ ) {
        $ret = $vars->{$var}->[$subvar];
    }
    $ret = ($ret == $value) if ($value);
    $ret = !$ret if ($not);
    ($ret)?$block:"";
}

sub _set ($$$) {
    my ($var, $value, $vars) = @_;
    $vars->{$var} = $value;
    "";
}

sub _inc ($$) {
    my ($template, $vars) = @_;
    &_template($template, $vars);
}

sub _var ($$$$) {
    my ($var, $subvar, $attr, $vars) = @_;
    return "" if (! exists $vars->{$var});

    my $ret = "";
    if (!defined($subvar) ) {
        $ret = $vars->{$var};
    }
    elsif (ref $vars->{$var} eq "HASH" && exists $vars->{$var}->{$subvar}) {
        $ret = $vars->{$var}->{$subvar};
    }
    elsif (ref $vars->{$var} eq "ARRAY" && $subvar !~ /\D/ ) {
        $ret = $vars->{$var}->[$subvar];
    }
    if (!defined $attr) {
        $ret = escape_html $ret;
    }
    elsif ($attr eq "raw") {
        $ret = $ret;
    }
    else {
        $ret = escape_html $ret;
    }
    $ret;
}

{
    my $set_re = qr/\[%\sSET\s(\w+)\s?=\s?\"(.+?)\"\s%\]/;
    my $inc_re = qr/\[%\sINCLUDE\s(\w+)\s%\]/;
    my $ifs_re = qr/\[%\sIF\s(!\s?)?(\w+?)(?:\.(\w+?))?(?:==(\d+))?\s%\](.+?)\[%\sFI\s%\]/s;
    my $var_re = qr/\[%\s(\w+?)(?:\.(\w+))?(?:\s\|\s(\w+))?\s%\]/;
    my $oth_re = qr/\[%.+?%\]/;

    sub _vars ($$) {
        my ($ref, $vars) = @_;
        $$ref =~ s/$ifs_re/_ifs $1, $2, $3, $4, $5, $vars/eg;
        $$ref =~ s/$set_re/_set $1, $2, $vars/eg;
        $$ref =~ s/$inc_re/_inc $1, $vars/eg;
        $$ref =~ s/$var_re/_var $1, $2, $3, $vars/eg;

        # remove all other tags
        $$ref =~ s/$oth_re//g;
    }
}

sub _foreach ($$$$) {
    my ($hash_name, $array_name, $block, $vars) = @_;
    my $output = "";
    return "" if (! exists $vars->{$array_name});
    foreach my $h_ref ( @{ $vars->{$array_name} } ) {
        $vars->{$hash_name} = $h_ref;
        my $copy = $block;
        _vars \$copy, $vars;
        $output .= $copy;
        delete $vars->{$hash_name};
    }
    return $output;
}

{
    my $for_re = qr/\[%\sFOREACH\s(\w+)\sIN\s(\w+)\s%\](.+?)\[%\sEND\s%\]/s;

    sub _template ($$) {
        my ($template, $vars) = @_;
        my $file = $config->{htdocs} . "/" . $template . ".tt";
        die "Template $template not found" if (! -f $file);
        local $/;
        open my $fh, "<", $file or die $!;
        my $data = <$fh>;
        close $fh;
        $data =~ s/$for_re/_foreach $1, $2, $3, $vars/eg;
        _vars \$data, $vars;
        return $data;
    }
}

1;
__END__
=pod

=head1 NAME

Site::Engine::Template - simple TT's like template engine

=head1 METHODS

=head1 DESCRIPTION

This module provide simple support for templates.

=head1 COPYRIGHT AND LICENSE

Copyright 2011 by crux E<lt>thecrux@gmail.comE<gt>

This module is free software and is published under the same terms as Perl itself.

=cut
