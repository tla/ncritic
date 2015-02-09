package ncritic::Model::WitnessSet;

use strict;
use base 'Catalyst::Model::DBIC::Schema';

__PACKAGE__->config(
    schema_class => 'Text::Tradition::WitnessSet',    
);

=head1 NAME

ncritic::Model::WitnessSet - Catalyst DBIC Schema Model

=head1 SYNOPSIS

See L<ncritic>

=head1 DESCRIPTION

L<Catalyst::Model::DBIC::Schema> Model using schema L<Text::Tradition::WitnessSet>

=head1 GENERATED BY

Catalyst::Helper::Model::DBIC::Schema - 0.62

=head1 AUTHOR

Tara L Andrews

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;