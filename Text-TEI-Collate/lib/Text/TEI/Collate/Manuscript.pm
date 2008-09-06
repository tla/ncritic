package Text::TEI::Collate::Manuscript;

use strict;
use vars qw( $VERSION );

$VERSION = "0.01";

=head1 DESCRIPTION

Text::TEI::Collate::Manuscript is an object that describes a manuscript.

=head1 METHODS

=head2 new

Creates a new manuscript object.  Right now this is just a container.

=cut

sub new {
    my $proto = shift;
    my %opts = @_;
    my $class = ref( $proto ) || $proto;
    my $init_string;
    if( exists $opts{'string'} ) {
	$init_string = delete $opts{'string'};
    }
    my $self = { 'sigil' => 'X',
		 'identifier' => 'Unidentified ms',
		 'auto_sigla' => 1,
		 %opts,
    };
    
    bless $self, $class;
    $self->auto_assign_sigil() if $self->{auto_sigla};
    return $self;
}

{
    my $curr_auto_sigil = 0;

    sub auto_assign_sigil {
	my $self = shift;
	my $curr_sig;
	if( $curr_auto_sigil > 25 ) {
	    $curr_sig = chr( ( $curr_auto_sigil % 26 ) + 65 ) x int( $curr_auto_sigil / 26 + 1 );
	} else {
	    $curr_sig = chr( $curr_auto_sigil + 65 );
	}
	$self->{sigil} = $curr_sig;
	$curr_auto_sigil++;
    }

}

my $end_msg = 'get a printing press already';

=head1 BUGS / TODO

Many things.  Tests for instance.  I shall enumerate them later.


=head1 AUTHOR

Tara L Andrews E<lt>aurum@cpan.orgE<gt>
