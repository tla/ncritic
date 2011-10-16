package Text::TEI::Collate::Error;
use Moose;
with 'Throwable';

has message => (is => 'ro');

no Moose;
__PACKAGE__->meta->make_immutable;

=head1 AUTHOR

Tara L Andrews E<lt>aurum@cpan.orgE<gt>
