package Text::TEI::Collate::Lang::Greek;

use strict;
use warnings;
use Text::WagnerFischer;
use Unicode::Normalize;

=head2 distance

Use Text::WagnerFischer::distance.

=cut

sub distance {
    return Text::WagnerFischer::distance( @_ );
}

=head2 canonizer

This is essentially just the lc() builtin function.

=cut

sub canonizer {
    return lc( $_[0] );
}

=head2 comparator

This is a function that replaces all characters with their base character 
after an NFKD (Normalization Form Compatibility Decomposition) operation.

=begin testing

use Test::More::UTF8;
use Text::TEI::Collate::Lang::Greek;

my $comp = \&Text::TEI::Collate::Lang::Greek::comparator;
is( $comp->( 'abcd' ), 'abcd', "Got correct no-op comparison string" );
is( $comp->( "ἔστιν" ), "εστιν", "Got correct unaccented comparison string");

=end testing

=cut

sub comparator {
   	my $word = shift;
	my @normalized;
	my @letters = split( '', lc( $word ) );
	foreach my $l ( @letters ) {
		my $d = chr( ord( NFKD( $l ) ) );
		push( @normalized, $d );
	}
	return join( '', @normalized );
}

1;