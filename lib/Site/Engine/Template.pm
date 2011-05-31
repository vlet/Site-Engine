package Site::Engine::Template;
use strict;
use warnings;
use Exporter qw( import );
our @EXPORT  = qw( escape_html clear_html );
our $VERSION = '0.01';

my $config;

# Public

sub init ($) {
    $config = shift;
}

sub escape_html ($) {
    my $data = shift;
    return "" if ( !defined $data );
    $data =~ s/&/&amp;/g;
    $data =~ s/</&lt;/g;
    $data =~ s/>/&gt;/g;
    $data =~ s/"/&quot;/g;
    $data =~ s/'/&#39;/g;
    return $data;
}

sub clear_html ($) {
    my $data = shift;
    return "" if ( !defined $data );
    $data =~ s/\r//g;
    $data =~ s/\<(br|p)\s?\/?\>/\n/g;
    $data =~ s/\<\/p\>/\n\n/g;
    $data =~ s/&\w+;/ /g;
    $data =~ s/\<.+?\>//sg;
    escape_html $data;
}

sub template {
    my ( $template, $vars, $conf ) = @_;
    my $data = &_template( $template, $vars );
    my $layout =
      ( exists $conf->{layout} )
      ? $conf->{layout}
      : $config->{layout} || "main";
    if ( defined $layout ) {
        $vars->{content} = $data;
        $data = &_template( $layout, $vars );
    }
    return $data;
}

# Private

sub _ifs ($$$$$$$) {
    my ( $not, $var, $subvar, $value, $subvalue, $block, $vars ) = @_;
    if ( !exists $vars->{$var} ) {
        return ($not) ? $block : "";
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
    if ( defined $ret ) {
        if ( defined $value && $value !~ /\D/ ) {
            $ret = ( $ret !~ /\D/ ) ? ( $ret == $value ) : 0;
        }
        elsif ( defined $value && exists $vars->{$value} ) {
            if ( defined $subvalue ) {
                $ret =
                    ( defined $vars->{$value}->{$subvalue} )
                  ? ( $ret == $vars->{$value}->{$subvalue} )
                  : 0;
            }
            else {
                $ret =
                  ( defined $vars->{$value} ) ? ( $ret == $vars->{$value} ) : 0;
            }
        }
        elsif ( defined $value ) {
            $ret = 0;
        }
    }
    $ret = !$ret if ($not);
    ($ret) ? $block : "";
}

sub _set ($$$) {
    my ( $var, $value, $vars ) = @_;
    $vars->{$var} = $value;
    "";
}

sub _inc ($$$$) {
    my ( $template, $var, $subvar, $vars ) = @_;
    if ( defined $var && exists $vars->{$var} ) {
        if ( !defined $subvar ) {
            $template = $vars->{$var};
        }
        elsif ( ref $vars->{$var} eq "HASH" && exists $vars->{$var}->{$subvar} )
        {
            $template = $vars->{$var}->{$subvar};
        }
        elsif ( ref $vars->{$var} eq "ARRAY" && $subvar !~ /\D/ ) {
            $template = $vars->{$var}->[$subvar];
        }
        else {
            return "";
        }
    }
    elsif ( !defined $template ) {
        return "";
    }
    &_template( $template, $vars );
}

sub _var ($$$$) {
    my ( $var, $subvar, $attr, $vars ) = @_;
    return "" if ( !exists $vars->{$var} );

    my $ret = "";
    if ( !defined($subvar) ) {
        $ret = $vars->{$var};
    }
    elsif ( ref $vars->{$var} eq "HASH" && exists $vars->{$var}->{$subvar} ) {
        $ret = $vars->{$var}->{$subvar};
    }
    elsif ( ref $vars->{$var} eq "ARRAY" && $subvar !~ /\D/ ) {
        $ret = $vars->{$var}->[$subvar];
    }
    if ( !defined $attr ) {
        $ret = escape_html $ret;
    }
    elsif ( $attr eq "raw" ) {
        $ret = $ret;
    }
    elsif ( $attr eq "clear" ) {
        $ret = clear_html $ret;
    }
    elsif ( $attr eq "clear_para" ) {
        $ret = clear_html $ret;
        $ret = substr $ret, 0, index( $ret, "\n\n" );
    }
    elsif ( $attr =~ /^length(\d+)/ ) {
        my $len = $1;
        $ret = substr( $ret, 0, $len ) . "..." if ( length $ret > $len );
        $ret = escape_html $ret;
    }
    else {
        $ret = escape_html $ret;
    }
    $ret;
}

{
    my $set_re = qr/\[%\sSET\s(\w+)\s?=\s?\"(.+?)\"\s%\]/;
    my $inc_re = qr/\[%\sINCLUDE\s(?:\"(\w+)\")?(?:(\w+)(?:\.(\w+))?)?\s%\]/;
    my $ifs_re =
qr/\[%\sIF\s(!\s?)?(\w+?)(?:\.(\w+?))?(?:==(\w+)(?:\.(\w+))?)?\s%\](.+?)\[%\sFI\s%\]/s;
    my $var_re = qr/\[%\s(\w+?)(?:\.(\w+))?(?:\s\|\s(\w+))?\s%\]/;
    my $oth_re = qr/\[%.+?%\]/;

    sub _vars ($$) {
        my ( $ref, $vars ) = @_;
        $$ref =~ s/$ifs_re/_ifs $1, $2, $3, $4, $5, $6, $vars/eg;
        $$ref =~ s/$set_re/_set $1, $2, $vars/eg;
        $$ref =~ s/$inc_re/_inc $1, $2, $3, $vars/eg;
        $$ref =~ s/$var_re/_var $1, $2, $3, $vars/eg;

        # remove all other tags
        $$ref =~ s/$oth_re//g;
    }
}

sub _foreach ($$$$) {
    my ( $hash_name, $array_name, $block, $vars ) = @_;
    my $output = "";
    return "" if ( !exists $vars->{$array_name} );
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
        my ( $template, $vars ) = @_;
        my $file = $config->{templates} . "/" . $template . ".tt";
        die "Template $template not found" if ( !-f $file );
        local $/;
        open my $fh, "<:encoding(UTF-8)", $file or die $!;
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

=head1 DESCRIPTION

This module provide simple support for templates.

=head1 METHODS

=head2 init( \%config )

init module with configuration

=head2 escape_html( $html )

escape html symbols

=head2 clear_html( $html )

try to convert html to plain text (remove tags and html entities)

=head2 template( $template, $vars, $conf )

create page from $template file with $vars and $conf

=over

=item $template - name of file (without extension .tt)

=item $vars - ref to hash with values

=item $conf - ref to hash with configuration ( for example layout )

=back

=head1 EXAMPLE

    template 'name_of_template_file', {
        data => "some data",
        array => [ "first" , "second" ],
        hash  => {
            this => "that",
        },
    }, { layout => 'name_of_template_of_layout' };

    Templates dir is fetched from config (key 'templates'), templates default extension is .tt

=head1 SYNTAX

=head2 [% var %] - substitute variable

=over

=item [% var %]      - SCALAR

=item [% var.4 %]    - ARRAY ( 4th element of array var )

=item [% var.prop %] - HASH  ( value of key 'prop' of hash var )

=back

=over

=item [% var %] - by default value is escaped ( by escape_html() )

=item [% var | raw %] - show variable as is ( no escaping )

=item [% var | clear %] - clear html (remove all tags and enities)

=item [% var | clear_para %] - clear html and return only first paragraph of text

=item [% var | lengthXX %] - return only first XX symbols (escaped)

=back

=head2 [% IF condition %] some data [% FI %] - condition for inserting data. Doesn't support nesting!!!

=over

=item [% IF var %] - check that var is true (not 0, not empty string, not undef)

=item [% IF !var %] - check that var is false

=item [% IF var==1 %] - check if condition var == number is true

=item [% IF var1==var2 %] - check if condition var1 == var2 is true

=back

=head2 [% SET var="string" %] - set var with value of "string"

=head2 [% INCLUDE var %] - include another template

=over

=item [% INCLUDE var %] - include template with name from variable var

=item [% INCLUDE "string" %] - include template with name "string"

=back

=head2 [% FOREACH element IN array %] ... [% END %] - foreach cycle.

    Doesn't support nesting!!!

=head1 BUGS and WORKAROUNDS

FOREACH and IF doesn't support nesting, but you can use INCLUDE


    Wrong !!!!                              Correct

    [%IF condition1 %]              |       [%IF condition1 %]
        data1                       |           data1
        [% IF confition2 %]         |           [% INCLUDE "template_with_confition2" %]
            data2                   |       [% FI %]
        [% FI %]                    |
    [% FI %]                        |       In file template_with_confition2.tt:
                                    |       [% IF confition2 %]
                                    |            data2
                                    |       [% FI %]

=head1 COPYRIGHT AND LICENSE

Copyright 2011 by crux E<lt>thecrux@gmail.comE<gt>

This module is free software and is published under the same terms as Perl itself.

=cut
