package Text::TEI::Collate::Lang::Latin;

use strict;
use warnings;

=head2 distance

This is the same as what is in Default. Really I should subclass that.

=cut

sub distance {
	my( $word1, $word2 ) = @_;
	my @l1 = split( '', $word1 );
	my @l2 = split( '', $word2 );
	my( %f1, %f2 );
	foreach( @l1 ) {
		$f1{$_} += 1;
	}
	foreach( @l2 ) {
		$f2{$_} += 1;
	}
	my $distance = 0;
	my %seen;
	foreach( keys %f1 ) {
		$seen{$_} = 1;
		my $val1 = $f1{$_};
		my $val2 = $f2{$_} || 0;
		$distance += abs( $val1 - $val2 );
	}
	foreach( keys %f2 ) {
		next if $seen{$_};
		my $val1 = $f1{$_} || 0;
		my $val2 = $f2{$_} || 0;
		$distance += abs( $val1 - $val2 );
	}
	return $distance;
}

=head2 canonizer

This is essentially just the lc() builtin function.

=cut

sub canonizer {
    return lc( $_[0] );
}

=head2 comparator

This is a function to normalize some Latin spelling.

=cut

sub comparator {
   	my $word = shift;
    $word =~ s/\W//g;
    $word =~ s/v/u/g;
    $word =~ s/j/i/g;
    $word =~ s/cha/ca/g;
    return $word;
}

1;