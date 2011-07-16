package ncritic::View::TT;

use strict;
use warnings;

use base 'Catalyst::View::TT';

__PACKAGE__->config(
    TEMPLATE_EXTENSION => '.tt2',
    INCLUDE_PATH => [
        ncritic->path_to( 'root', 'src' ),
    ],
    WRAPPER => 'wrapper.tt2',
    render_die => 1,
);

=head1 NAME

ncritic::View::TT - Wrapped TT View for ncritic

=head1 DESCRIPTION

TT View for ncritic.  Meant for interactive display.

=head1 SEE ALSO

L<ncritic>

=head1 AUTHOR

Tara L Andrews

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
