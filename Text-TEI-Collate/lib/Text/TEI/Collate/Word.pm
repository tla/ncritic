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
	next if( grep /\Q$p\E/, @{$self->{'accents'}} );
	push( @$punct, $p );
	$word =~ s/\Q$p\E//g;
    }
    $self->punctuation( $punct );

    my $accent_pattern = join( '', @{$self->{accents}} );
    # Has it an accent over a letter?  If so, record the accented form.
    # TODO: Make this work with composed characters.
    if( length $accent_pattern ) {
	if( $word =~ /[$accent_pattern]/ ) {
	    $self->accented_form( $word );
	    $word =~ s/[$accent_pattern]//g; # Strip all accents
	}
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
    return $self->{'word'};
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

## Subs for marking a word as a base, a true variant, or a grammatical /
## orthographical error.

sub accept_base {
    my $self = shift;
    $self->{'is_base'} = 1;
    $self->{'is_variant'} = 0;
    $self->{'is_error'} = 0;
}

sub is_base {
    my $self = shift;
    return $self->{'is_base'};
}

sub accept_variant {
    my $self = shift;
    $self->{'is_variant'} = 1;
    $self->{'is_base'} = 0;
    $self->{'is_error'} = 0;
}

sub is_variant {
    my $self = shift;
    return $self->{'is_variant'};
}

sub mark_error {
    my $self = shift;
    $self->{'is_error'} = 1;
    $self->{'is_base'} = 0;
    $self->{'is_variant'} = 0;
}

sub is_error {
    my $self = shift;
    return $self->{'is_error'};
}

sub add_ms {
    my $self = shift;
    my $new_ms = shift;
    if( ref( $new_ms ) ne 'Text::TEI::Collate::Manuscript' ) {
	warn( "Object $new_ms is not a manuscript; not adding" );
	return;
    }
    if( defined $self->{mss} ) {
	push( @{$self->{mss}}, $new_ms );
    } else {
	$self->{mss} = [ $new_ms ];
    }
}

sub in_mss {
    my $self = shift;
    return $self->{mss} if defined $self->{mss};
    return [];
}

sub add_link {
    my $self = shift;
    my $new_link = shift;
    if( ref( $new_link) ne 'Text::TEI::Collate::Word'
	|| $new_link->word eq '' ) {
	warn "Object $new_link is not a non-empty word; not linking";
	return;
    }
    if( defined $self->{links} ) {
	push( @{$self->{links}}, $new_link );
    } else {
	$self->{links} = [ $new_link ];
    }
}

sub get_links {
    my $self = shift;
    return $self->{links} if defined $self->{links};
    return [];
}


1; 


=head1 BUGS / TODO

Many things.  I shall enumerate them later.


=head1 AUTHOR

Tara L Andrews E<lt>aurum@cpan.orgE<gt>
