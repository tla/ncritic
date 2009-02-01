package Text::TEI::Collate::Word;

use strict;
use vars qw( $VERSION );

$VERSION = "0.01";

=head1 DESCRIPTION

Text::TEI::Collate::Word is an object that describes a word in a collated
text.  This may be a useful way for editors of other things to plug in
their own logic.

=head1 METHODS

=head2 new

Creates a new word object.  Should not be called directly.

=cut

sub new {
    my $proto = shift;
    my %opts = @_;
    my $class = ref( $proto ) || $proto;
    my $init_string;
    if( exists $opts{'string'} ) {
	$init_string = delete $opts{'string'};
    }
    my $self = { 'not_punct' => [],
		 'accents' => [],
		 'canonizer' => undef,
		 'comparator' => undef,
		 %opts,
    };
    
    bless $self, $class;
    if( $self->{'special'} ) {
	$self->{'invisible'} = 1;
    }
    $init_string = '' if( $self->{'empty'} );
    $self->evaluate_word( $init_string );
    return $self;
}

sub evaluate_word {
    my $self = shift;
    my $word = shift;

    unless( defined $word ) {
	$word = '';
	return;
    }

    # Preserve the original word, weird orthography and all.
    if( $self->original_form ) {
	warn "Called evaluate_word on an object that already has a word";
	return undef;
    } else {
	$self->original_form( $word );
    }

    # Canonicalize the word.  Should not yet get rid of any attributes.
    if( defined $self->canonizer ) {
	$word = &{$self->canonizer}( $word );
    }
    $self->canonical_form( $word );

    # Need to ascertain a few characteristics.
    # Has it any punctuation to go with the word, that is not in our
    # list of "not really punctuation"?
    my( $punct, $accent ) = ( [], undef );	    
    my @punct_instances = $word =~ /([[:punct:]])/g;
    foreach my $p ( @punct_instances ) {
	next if( grep /\Q$p\E/, @{$self->{'not_punct'}} );
	push( @$punct, $p );
	$word =~ s/\Q$p\E//g;
    }
    $self->punctuation( $punct );
    # TODO: something sensible with accent marks

    if( defined $self->comparator ) {
	$self->comparison_form( &{$self->comparator}( $word ) );
    } else {
	$self->comparison_form( $word );
    }

    $self->word( $word );
}

# Accessors.

=head1 Access methods

=head2 word

If called with an argument, sets the stripped form of the word that
should be used for comparison.  Returns the word's stripped form.

=cut

sub word {
    my $self = shift;
    my $form = shift;
    if( defined $form ) {
	$self->{'word'} = $form;
    } 	
    return $self->{'invisible'} ? '' : $self->{'word'}
}

=head2 printable

Return either the word or the 'special', as applicable

=cut

sub printable {
    my $self = shift;
    return $self->special ? $self->special : $self->canonical_form;
}

=head2 original_form

If called with an argument, sets the form of the word, punctuation and
all, that was originally passed.  Returns the word's original form.

=cut

sub original_form {
    my $self = shift;
    my $form = shift;
    if( defined $form ) {
	$self->{'original_form'} = $form;
    }
    return $self->{'original_form'};
}

=head2 accented_form

If called with an argument, sets the accented form of the word (minus
punctuation).  Returns the word's accented form.

=cut

sub accented_form {
    my $self = shift;
    my $form = shift;
    if( defined $form ) {
	$self->{'accented_form'} = $form;
    }
    return $self->{'accented_form'};
}

=head2 canonical_form

If called with an argument, sets the canonical form of the word (minus
punctuation).  Returns the word's canonical form.

=cut

sub canonical_form {
    my $self = shift;
    my $form = shift;
    if( defined $form ) {
	$self->{'canonical_form'} = $form;
    }
    return $self->{'canonical_form'};
}

=head2 comparison_form

If called with an argument, sets the comparison form of the word
(using a set standard for orthographic equivalence.)  Returns the
word's comparison form.

=cut

sub comparison_form {
    my $self = shift;
    my $form = shift;
    if( defined $form ) {
	$self->{'comparison_form'} = $form;
    }
    return $self->{'comparison_form'};
}

=head2 punctuation

If called with an argument, sets the punctuation marks that were
passed with the word.  Returns the word's puncutation.

=cut

sub punctuation {
    my $self = shift;
    my $punct = shift;
    if( $punct ) {
	$self->{'punctuation'} = $punct;
    }
    return @{$self->{'punctuation'}};
}

=head2 canonizer

If called with an argument, sets the canonizer subroutine that the
word object should use.  Returns the subroutine.

=cut

sub canonizer {
    my $self = shift;
    my $punct = shift;
    if( $punct ) {
	$self->{'canonizer'} = $punct;
    }
    return $self->{'canonizer'};
}

=head2 comparator

If called with an argument, sets the comparator subroutine that the
word object should use.  Returns the subroutine.

=cut

sub comparator {
    my $self = shift;
    my $punct = shift;
    if( $punct ) {
	$self->{'comparator'} = $punct;
    }
    return $self->{'comparator'};
}

=head2 special

Returns a word's special value.  Used for meta-words like
BEGIN and END.

=cut

sub special {
    my $self = shift;
    return unless exists( $self->{'special'} );
    return $self->{'special'};
}

=head2 is_empty

Returns whether this is an empty word.  Useful to distinguish from a
special word.

=cut

sub is_empty {
    my $self = shift;
    return $self->{'empty'};
}

=head2 state

Returns a hash of all the values that might be changed by a 
re-comparison.  Useful to 'back up' a word before attempting a
rematch.  Currently does not expect any of the 'mutable' keys
to contain data structure refs.

=cut

my @mutable_keys = qw( glommed );
sub state {
    my $self = shift;
    my $opts = {};
    foreach my $key( @mutable_keys ) {
	warn( "Not making full copy of ref stored in $key" ) 
	    if ref( $self->{$key} );
	$opts->{$key} = $self->{$key};
    }
    return $opts;
}

sub restore_state {
    my $self = shift;
    my $opts = shift;
    return unless ref( $opts ) eq 'HASH';
    foreach my $key( @mutable_keys ) {
	$self->{$key} = $opts->{$key};
    }
}

=head2 is_glommed

Returns true if the word has been matched together with its
following word.  If passed with an argument, sets this value.

=cut

sub is_glommed {
    my $self = shift;
    my $val = shift;
    if( defined( $val ) ) {
	$self->{'glommed'} = $val;
    }
    return $self->{'glommed'};
}

=head2 is_base

Returns true if the word has been matched together with its
following word.  If passed with an argument, sets this value.

=cut

sub is_base {
    my $self = shift;
    my $val = shift;
    if( defined( $val ) ) {
	$self->{'base'} = $val;
    }
    return $self->{'base'};
}

=head2 placeholders

Returns the sectional markers, if any, that go before the word.

=cut

sub placeholders {
    my $self = shift;
    return exists $self->{'placeholders'} ? @{$self->{'placeholders'}} : ();
}

=head2 add_placeholder

Adds a sectional marker that should precede the word in question.

=cut

sub add_placeholder {
    my $self = shift;
    my $new_ph = shift;
    unless( $self->{'placeholders'} ) {
	$self->{'placeholders'} = [];
    }
    push( @{$self->{'placeholders'}}, $new_ph );
}
    

=head2 ms_sigil

Returns the sigil of the manuscript wherein this word appears.

=cut

sub ms_sigil {
    my $self = shift;
    return exists $self->{'ms_sigil'} ? $self->{'ms_sigil'} : '';
}

### Links

=head2 links

Returns the list of links, or an empty list.

=cut

sub links {
    my $self = shift;
    return exists $self->{'links'} ? @{$self->{'links'}} : ();
}

=head2 add_link

Adds to the list of 'like' words in this word's column.

=cut

sub add_link {
    my $self = shift;
    my $new_obj = shift;
    unless( ref( $new_obj ) eq 'Text::TEI::Collate::Word' ) {
	warn "Cannot add a link to a non-word";
	return;
    }
    my $links = exists $self->{'links'} ? $self->{'links'} : [];
    push( @$links, $new_obj );
    $self->{'links'} = $links;
}

=head2 variants

Returns the list of variants, or an empty list.

=cut

sub variants {
    my $self = shift;
    return exists $self->{'variants'} ? @{$self->{'variants'}} : ();
}

=head2 add_variant

Adds to the list of 'different' words in this word's column.

=cut

sub add_variant {
    my $self = shift;
    my $new_obj = shift;
    unless( ref( $new_obj ) eq 'Text::TEI::Collate::Word' ) {
	warn "Cannot add a non-word as a variant";
	return;
    }
    my $variants = exists $self->{'variants'} ? $self->{'variants'} : [];
    push( @$variants, $new_obj );
    $self->{'variants'} = $variants;
}

=head1 BUGS / TODO

Many things.  I shall enumerate them later.


=head1 AUTHOR

Tara L Andrews E<lt>aurum@cpan.orgE<gt>
