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
		 %opts,
    };
    
    bless $self, $class;
    $self->evaluate_word( $init_string );
    return $self;
}

sub evaluate_word {
    my $self = shift;
    my $word = shift;

    $word = '' unless defined $word;

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

    my( $punct, $accent ) = ( [], undef );	    

    # Need to ascertain a few characteristics.
    # Has it any punctuation to go with the word, that is not in our
    # list of "not really punctuation"?
    my @punct_instances = $word =~ /([[:punct:]])/;
    foreach my $p ( @punct_instances ) {
	next if( grep /\Q$p\E/, @{$self->{'not_punct'}} );
	push( @$punct, $p );
	$word =~ s/\Q$p\E//g;
    }
    $self->punctuation( $punct );
    # TODO: something sensible with accent marks

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
    return '' if $self->{'invisible'};
    return ( $self->placeholder ? $self->placeholder : $self->{'word'} );
}

=head2 printable

Passes either the canonical form or the placeholder string of the word.

=cut

sub printable {
    my $self = shift;
    if( $self->placeholder ) {
	return $self->placeholder;
    } else {
	return $self->canonical_form;
    }
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
    return $self->{'punctuation'};
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

=head2 placeholder

If this word is a placeholder, returns the type (e.g. __DIV__).
Otherwise returns undef.

=cut

sub placeholder {
    my $self = shift;
    return exists $self->{'placeholder'} ? $self->{'placeholder'} : undef;
}

1; 

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
