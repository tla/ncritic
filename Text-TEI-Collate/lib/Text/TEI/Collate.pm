package Text::TEI::Collate;

use strict;
use vars qw( $VERSION );
use Algorithm::Diff;
# use Contextual::Return ## TODO: examine
use Text::TEI::Collate::Word;
use Text::TEI::Collate::Manuscript;
use XML::LibXML;

$VERSION = "1.0";

=head1 SYNOPSIS

  use Text::TEI::Collate;
  my $aligner = Text::TEI::Collate->new();

  # Read from strings.
  my @collated_texts = $aligner->align( $string1, $string2, [ .. $stringN ] );

  # Read from filehandles.
  my $fh1 = new IO::File;
  $fh1->open( $first_file, "<:utf8" );
  my $fh2 = new IO::File;
  $fh2->open( $first_file, "<:utf8" );
  # ...
  my @collated_from_fh = $aligner->align( $fh1, $fh2, [ .. $fhN ] );
  
=head1 DESCRIPTION

Text::TEI::Collate is the beginnings of a collation program for multiple
(transcribed) manuscript copies of a known text.  It is an
object-oriented interface, mostly for the convenience of the author
and for the ability to have global settings.

The object is the alignment engine, or "aligner".  The method that a
user will care about is "align"; the other methods in this file are
public in case a user needs a subset of this package's functionality.

An aligner takes two or more texts; the texts can either be strings or
IO::File objects.  It returns two or more arrays -- one for each text
input -- in which identical and similar words are lined up with each
other, via empty-string padding.

* TODO: describe word objects

=head1 METHODS

=head2 new

Creates a new aligner object.  Takes a hash of options; available
options are listed.

=over 4

=item B<debug> - Default 0.  The higher the number (between 0 and 3), the more the debugging output.

=item B<distance_sub> - A reference to a function that calculates a  Levenshtein-like distance between two words.  Default is Text::WagnerFischer::distance.

=item B<fuzziness> - The maximum allowable word distance for an approximate match, expressed as a percentage of Levenshtein distance / word length.

=item B<punct_as_word> - Treat punctuation as separate words.  Not yet implemented

=item B<not_punct> - Takes an array ref full of characters that should not be treated as punctuation.

=item B<accents> - Takes an array ref full of characters that should be treated as accent marks. (TODO: discuss diff between punctuation & accents)

=item B<canonizer> - Takes a subroutine ref.  The sub should take a string and return a string.  If defined, it will be called to produce a canonical form of the string in question.  Useful for getting rid of ligatures, un-composing characters, correcting common spelling mistakes, etc.

=back

=cut

# Set the options.  Main option is a pointer to the fuzzy matching algorithm
# that the user wishes to use.
sub new {
    my $proto = shift;
    my $class = ref( $proto ) || $proto;
    my %opts = @_;
    my $self = {
	debug => 0,
	distance_sub => undef,
	fuzziness => 40,
	binmode => 'utf8',
	punct_as_word => 0,
	not_punct => [],
	accents => [],
	canonizer => undef,
	%opts,
    };
    
    unless( defined $self->{distance_sub} ) {
	# Use the default.
	use Text::WagnerFischer qw( distance );
	$self->{distance_sub} = &Text::WagnerFischer::distance;
    }

    # Initialize the "transpositions" array.  This will be a set of
    # tuples giving the length and start-item of any word
    # transpositions we find.
    $self->{'transpositions'} = {};

    if( my $b = $self->{'binmode'} ) {
	binmode STDERR, ":$b";
    }
    
    bless $self, $class;
    return $self;

}
    
=head2 align

This is the meat of the program.  Takes a list of strings, or a list
of IO::File objects.  (The latter is useful if the text you are
collating is particularly long.)  Returns a list of collated texts.
Currently each "text" is simply a list of words, padded for collation
with empty strings; soon it will be a list of word objects which I
have yet to describe.

=cut

# align - Main function.
# Takes a list of strings, or a list of filehandles.  Returns a list
# of aligned word arrays.

sub align {
    my( $self, @texts ) = @_;

    my @word_chars;
    my %VARIANTS;
    foreach ( @texts ) {
	# Break down each text into word-object arrays.
	push( @word_chars, $self->extract_words( $_ ) );
    }

    # This will hold many arrays, one for each collated text.  Each member
    # array will be a list of word objects.  We will eventually return it.
    my @result_array;

    if( scalar( @word_chars ) == 1 ) {
	# That was easy then.
	return @word_chars;
    }

    # At this point we have an array of arrays.  Each member array
    # contains a hash object for each word, describing its
    # characteristics.  These are the uncollated texts, now in the
    # object form that we will eventually return.

    # The first file becomes the base, for now.
    # TODO: Work parsimony info into the choosing of a base
    my $base_text = shift @word_chars;

    for ( 0 .. $#word_chars ) {
	my $text = $word_chars[$_];
	print STDERR "Beginning run of build_array for text " . ($_+2) . "\n"
	    if $self->{debug};
	my( $result1, $result2 ) = $self->build_array( $base_text, $text );
 
	# Are the resulting arrays the same length?
	if( scalar( @$result1 ) != scalar( @$result2 ) ) {
	    warn "Result arrays for text $_ are not the same length!";
	}

	# Now we have the fun trick of folding these into the overall array.
	if( !scalar( @result_array ) ) {
	    # These are the first two texts.  No problem.
	    @result_array = ( $result1, $result2 );
	} else {
	    # Make all existing arrays the same length as $result1, with gaps
	    # for padding in the same place that $result1 has them.
	    my @padding = map { $_ eq $self->empty_word } @$result1;
	    foreach my $idx ( 0 .. $#padding ) {
		if( $padding[$idx] ) {
		    foreach my $arr ( @result_array ) {
			splice( @$arr, $idx, 0, $self->empty_word );
		    }
		} 
	    }

	    print STDERR "All arrays now " . scalar @{$result_array[0]} . " items long\n"
		if $self->{debug};    

	    # Add result2 to the output.
	    push( @result_array, $result2 );
	}

	# If there is another text to come, generate the new base text by 
	# flattening result2 onto the back of result1, filling in the gaps.
	if( $_ < $#word_chars ) {
	    $base_text = $self->generate_base( \%VARIANTS, $result1, $result2 );
	}
    }

    return ( \%VARIANTS, @result_array );
}

# Small utility to get a string out of an array of word objects.
sub _stripped_words {
    my $text = shift;
    my @words = map { $_->word } @$text;
    return @words;
}

# The object that should be used to pad the arrays.  Default here is a
# word object with an empty string.
sub new_word {
    my $self = shift;
    my $string = shift;
    my $msobj = shift;
    $string = '' unless $string;
    my $word = Text::TEI::Collate::Word->new( string => $string,
					 not_punct => $self->{not_punct},
					 accents => $self->{accents},
					 canonizer => $self->{canonizer},
					 manuscript => $msobj,
	);
    return $word;
}

sub empty_word {
    my $self = shift;
    unless( defined $self->{'null_word'} 
	    && ref( $self->{'null_word'} ) eq 'Text::TEI::Collate::Word' ) {
	# Make a null word and save it.
	$self->{'null_word'} = $self->new_word();
    }
    return $self->{'null_word'};
}

# Given two collections of word object, return two collated collections of
# word objects.  Pass a ref to the whole array so far so that we can consult
# it if necessary.  That array should *not* be written to here below.
sub build_array {
    my $self = shift;
    my( $base_text, $text ) = @_;
    my( @base_result, @new_result );   # All the good things we'll return.
    my $base_idx = 0;

    my @base_words = _stripped_words( $base_text );
    my @new_words = _stripped_words( $text );

    my $diff = Algorithm::Diff->new( \@base_words, \@new_words );
    while( $diff->Next ) {
	if( $diff->Same ) {
	    $self->_handle_diff_same( $diff, $base_text, $text, \@base_result, \@new_result );
	} elsif( !scalar( $diff->Range( 1 ) ) ) {  # Addition
	    $self->_handle_diff_interpolation( $diff, 2, $text, \@new_result, \@base_result );
	} elsif( !scalar( $diff->Range( 2 ) ) ) {  # Deletion
	    $self->_handle_diff_interpolation( $diff, 1, $base_text, \@base_result, \@new_result );
	} else {  # Change
	    # A true change.  Time to pull out some fuzzy matching then.
	    print STDERR "Diff: collating words " . join( '.', $diff->Items( 1 ) ) . " / " .
		join( '.', $diff->Items( 2 ) ) . "\n" if $self->{debug} > 1;
	    
	    # Grab the word sets from each text.
	    my @base_wlist = @{$base_text}[$diff->Range( 1 )];
	    my @new_wlist = @{$text}[$diff->Range( 2 )];

	    # Match them up.  This will create the links between aligned words.
	    my( $aligned1, $aligned2 ) = $self->match_and_align_words( \@base_wlist, \@new_wlist );
	    
	    # Push it all on.
	    push( @base_result, @$aligned1 );
	    push( @new_result, @$aligned2 );
	}	
    }

    return( \@base_result, \@new_result );
}

my $varprint = 0;
sub print_link {
    # Debug method
    my( $w1, $w2 ) = @_;
    if( $varprint == 1 ) {
	print STDERR "Linking " . $w1->word . " / ";
	my $sc1 = scalar( $w1 );
	$sc1 =~ s/Text::TEI::Collate::Word=HASH//;
	print STDERR $sc1 . " to " . $w2->word . " / ";
	my $sc2 = scalar( $w2 );
	$sc2 =~ s/Text::TEI::Collate::Word=HASH//;
	print STDERR "$sc2\n";
    }
}
sub print_variant {
    # Debug method
    my( $w1, $w2 ) = @_;
    if ( $varprint == 1 ) {
	print STDERR "Adding variant of " . $w1->word . " / ";
	my $sc1 = scalar( $w1 );
	$sc1 =~ s/Text::TEI::Collate::Word=HASH//;
	print STDERR $sc1 . " to be " . $w2->word . " / ";
	my $sc2 = scalar( $w2 );
	$sc2 =~ s/Text::TEI::Collate::Word=HASH//;
	print STDERR "$sc2\n";
    }
}

## Diff handling functions.  Used in build_array and in match_and_align_words.  
## Thanks to our array-substitution trickery in match_and_align_words, we may
## not assume that the $diff object has the actual items we want.  Only the
## indices are meaningful.

sub _handle_diff_same {
    my $self = shift;
    my( $diff, $base_text, $new_text, $base_result, $new_result ) = @_;
    # Get the index range.
    my @rbase = $diff->Range( 1 );
    my @rnew = $diff->Range( 2 );
    my @base_wlist = @{$base_text}[@rbase];
    my @new_wlist = @{$new_text}[@rnew];
    print STDERR "Diff: pushing same words " . join( ' ', _stripped_words( \@base_wlist ) ) . "\n" 
	if $self->{debug} > 2;
    push( @$base_result, @base_wlist );
    push( @$new_result, @new_wlist );
    # Create the links between words.
    foreach my $i ( 0 .. $#base_wlist ) {
	print_link( $base_wlist[$i], $new_wlist[$i] );
	$base_wlist[$i]->add_link( $new_wlist[$i] );
    }
}

sub _handle_diff_interpolation {
    my $self = shift;
    my( $diff, $which, $from_text, $from_result, $to_result ) = @_;
    
    # $which has either 1 or 2, stating which array in $diff has the items.
    # $from_result corresponds to $which.
    my $op = $which == 1 ? 'deletion' : 'addition';
    my @range = $diff->Range( $which );
    my @wlist = @{$from_text}[@range];
    
    print STDERR "DBrecord: pushing $op " . join( ' ',  _stripped_words( \@wlist ) ) . "\n"
	if $self->{debug} > 2;
    push( @$to_result, ( $self->empty_word ) x scalar( @wlist ) );
    push( @$from_result, @wlist );
}


# generate_base: Take an array of text arrays and flatten them.  There
# should not be a blank element in the resulting base.  Currently
# used for only two input arrays at a time.  Optionally takes a hash to
# record the dissimilar variants on each base word.

sub generate_base {
    my $self = shift;
    my $variants = shift;
    unless( ref( $variants ) eq 'HASH' ) {
	unshift( @_, $variants );
	$variants = undef;
    }
    my @texts = @_;

    # Error checking: are they all the same length?
    my $width = scalar @texts;
    my $length = 0;
    foreach my $t ( @texts ) {
	$length = scalar( @$t ) unless $length;
	warn "ERROR: texts are not all same length"
	    if scalar( @$t ) ne $length;
    }

    # Get busy.  Take a word from T0 if it's there; otherwise take a word
    # from T1, otherwise T2, etc.  Record the variants if we have a hash
    # in which to do so.
    my @new_base;
    foreach my $idx ( 0 .. $length-1 ) {
	my $word = $self->empty_word;  # We should never end up using this
	                             # word, but just in case there is a
	                             # gap, it should be the right object.
	foreach my $col ( 0 .. $width - 1 ) {
	    if( $texts[$col]->[$idx]->word() ne '' ) {
		$word = $texts[$col]->[$idx];
		if( defined $variants ) {
		    # Look through the rest of the arrays at this index,
		    # comparing the words, and record as variants any
		    # non-matching ones.  Any matching ones should already
		    # be linked for previous runs.  Ideally we would link
		    
		    # TODO: Add test for similar-word link existence
		    foreach my $rcol ( $col+1 .. $width-1 ) {
			my $rword = $texts[$rcol]->[$idx];
			# Ignore a blank column word.
			next if $rword eq $self->empty_word;
			# See if the word is already linked to our word.
			next if grep( $_ eq $rword, @{$word->get_links} ) == 1;
			# When we trust the linking, we can dispense with the
			# re-run of the distance sub, i.e. this next if statement.
			if( !( $self->_is_near_word_match( $word, $rword ) ) ) {
			    # It is a variant.  Is it already there?
			    $variants->{scalar( $word )} = [] 
				unless defined $variants->{scalar( $word )};
			    # See if we already have it.
			    my @list = @{$variants->{scalar( $word )}};
			    if( grep( $_ eq $rword, @list ) == 0 ) {
				# We have to match against what is
				# already in list, and link rword if
				# it matches something there.
				my $matched = 0;
				foreach my $lword( @list ) {
				    if( $self->_is_near_word_match( $rword, $lword ) ) {
					print_link( $lword, $rword );
					$lword->add_link( $rword );
					$matched = 1;
					last;
				    }
				}
				unless( $matched ) {
				    # It's a new variant.  What fun.  Add it here
				    # and link future similar variants to it.
				    print_variant( $word, $rword );
				    push( @list, $rword );
				}
				$variants->{scalar( $word )} = \@list;
			    } # else it's already in the list; no action
			} elsif( $rword->word ne '' ) { # endif not_near_word_match
			    # Not linked, but a near match.  Scream.
			    warn( "Word " . $rword->word . "is an unlinked near match to "
				  . $word->word . "at row $idx" );
			}
		    }
		}  ## endif defined $variants
		last;
	    }
	}
	warn( "No word found in any column at index $idx!" )
	    if( $word eq $self->empty_word );
	push( @new_base, $word );
    }
    
    return \@new_base;
}

sub _is_near_word_match {
    my $self = shift;
    my( $word1, $word2 ) = @_;
    
    # Find our distance routine in case we need it.
    unless( ref $self->{distance_sub} ) {
	warn "No word distance algorithm specified.  Cannot compare words.";
	return;
    }
    my $distance = $self->{'distance_sub'};
    my $dist = &$distance( $word1->word, $word2->word );
    return ( $dist < ( length( $word1->word ) * $self->{fuzziness} / 100 ) );
}

sub _get_transposition {
    my ( $self, $word ) = @_;
    if( exists $self->{'transpositions'}->{ scalar $word } ) {
	return delete $self->{'transpositions'}->{$word};
    } else {
	return 0;
    }
}

# Take a word sources, and extract the words from it into an array.
# Return the array.  Word sources can be strings or IO::File
# filehandles.
# TODO: filter for, e.g., punctuation stripping.  Right now it is hard-
# coded to strip Armenian punctuation.

sub extract_words {
    my $self = shift;
    my $wordsource = shift;

    my @words;

    if( $self->{'TEI'} ) {
	# The wordsource should either be a filehandle with XML
	# on the other end, or an XML::LibXML::Document.
	my $docroot;
	if( ref( $wordsource ) eq 'IO::File' ) {
	    my $parser = XML::LibXML->new();
	    my $doc = $parser->parse_fh( $wordsource );
	    $docroot = $doc->getDocumentRoot;
	} else {
	    $docroot = $wordsource->getDocumentRoot;
	}
	
	# We have the doc.  Get the manuscript data out.
	my @msnodes = $docroot->getElementsByTagName( 'msDesc' );
	my $ms_obj;
	if( @msnodes ) {
	    $ms_obj = Text::TEI::Collate::Manuscript->new( 'xml' => $msnodes[0] );
	} else {
	    warn "Could not find manuscript description in doc; creating generic manuscript";
	    $ms_obj = Text::TEI::Collate::Manuscript->new(
		'identifier' => 'Unknown ms',
		);
	}
	push( @{$self->{'manuscripts'}}, $ms_obj );


	# Now get the words.
	# Assume for now one body text
	my @teitext = $docroot->getElementsByTagName( 'text' );
	if( @teitext ) {
	    # Strip out the words.
	    # TODO: this could use spec consultation.
	    my @divs = $teitext[0]->getElementsByTagName( 'div' );
	    foreach( @divs ) {
		my $place_str;
		if( my $n = $_->getAttribute( 'n' ) ) {
		    $place_str = '__DIV_' . $n . '__';
		} else {
		    $place_str = '__DIV__';
		}
		push( @words, $self->_new_placeholder( $place_str ) );
		push( @words, $self->_read_paragraphs( $_ ) );
	    }  # foreach <div/>

	    # But maybe we don't have any divs.  Just paragraphs.
	    unless( @divs ) {
		push( @words, $self->_read_paragraphs( $teitext[0] ) );
	    }
		    
	} else {
	    warn "No text in document '" . $ms_obj->identifier . "!";
	}
    } else {  
	## No XML, just plain words.
	my @raw_words;
	if( ref( $wordsource ) eq 'IO::File' ) {
	    # It's a filehandle, not a string.  Roleplay accordingly.
	    while( <$wordsource> ) {
		chomp;
		push( @raw_words, split );
	    }
	    
	} else {
	    @raw_words = split( /\s+/, $wordsource );
	}
    
	foreach my $w ( @raw_words ) {
	    my $w_obj = $self->new_word( $w );
	    # For now, skip "words" that are nothing but punctuation.
	    next if( length( $w_obj->original_form ) > 0 
		     && length( $w_obj->word ) == 0 );
	    
	    push( @words, $w_obj );
	}
    
    }
    return \@words;
}

sub _read_paragraphs {
    my( $self, $element, $msobj ) = @_;

    my @words;
    my @pgraphs = $element->getElementsByTagName( 'p' );
    return () unless @pgraphs;
    foreach my $pg( @pgraphs ) {
	push( @words, $self->_new_placeholder( '__PG__', $msobj ) );
	# Are the words tagged?  If so, suck them out.
	if( $pg->getElementsByTagName( 'w' ) ) {
	    # We need <w/>, but we also need <seg/>, and in their
	    # original order.
	    foreach my $c ( $pg->childNodes() ) {
		if( $c->nodeName eq 'w' ) {
		    push( @words, $self->_new_word( $c->textContent, $msobj ) );
		} elsif ( $c->nodeName eq 'seg' &&
			  $c->getAttribute( 'type' ) eq 'word' ) {
		    # Trickier.  Need to parse the tags.
		    my $word = $self->_get_text_from_node( $c );
		    push( @words, $self->_new_word( $word, $msobj ) );
		} # if node is word or seg
	    }
	} else {  # if w / seg tags don't exist
	    # We have to split the words by whitespace.
	    my $string = $self->_get_text_from_node( $pg );
	    my @raw_words = split( /\s+/, $string );
	    foreach my $w ( @raw_words ) {
		my $w_obj = $self->new_word( $w, $msobj );
		# For now, skip "words" that are nothing but punctuation.
		next if( length( $w_obj->original_form ) > 0 
			 && length( $w_obj->word ) == 0 );
		
		push( @words, $w_obj );
	    }
	}
    }

    return @words;
}

# Given a node, whether a paragraph or a word, reconstruct the text
# string that ought to come out.  If it is a word or a seg, sanity
# check it for lack of spaces.
sub _get_text_from_node {
    my( $self, $node ) = @_;
    my $text;
    foreach my $c ($node->childNodes() ) {
	if( ref( $c ) eq 'XML::LibXML::Text' ) {
	    $text .= $c->textContent;
	} elsif( $c->nodeName eq 'num' 
		 && defined $c->getAttribute( 'value' ) ) {
	    # Push the number.
	    $text .= $c->getAttribute( 'value' );
	} elsif ( $c->nodeName eq 'del'
		  || $c->textContent eq '' ) {
	    next;
	} else {
	    $text .= $c->textContent;
	}
    }
    # Sanity check
    if( $node->nodeName eq 'w'
	|| ( $node->nodeName eq 'seg' 
	     && $node->getAttribute( 'type' ) eq 'word' ) 
	&& $text =~ /\s+/ ) {
	warn "Extracted text =$text= containing space from word element\n "
	    . $node->toString();
    }
    return $text;
}


# match_and_align_words: Do the fuzzy matching necessary to roughly
# align two columns (i.e. arrays) of words.  Takes two word arrays;
# returns two word arrays aligned via empty-string element padding.
# Here is where $self->{distance_sub} is used.
	    
sub match_and_align_words {
    my $self = shift;
    my( $set1, $set2 ) = @_;

    # Resolve what string comparison algorithm we ought to be using.
    my $distance;
    unless( ref $self->{distance_sub} ) {
	warn "No word distance algorithm specified.  Cannot align words.";
	return( $set1, $set2 );
    }
    $distance = $self->{distance_sub};

    # Put the shorter array into words1.  Keep track if we have
    # done this.
    my( @words1, @words2 );
    my $inverted = 0;
    if( scalar( @$set1 ) > scalar( @$set2 ) ) {
	@words1 = @$set2;
	@words2 = @$set1;
	$inverted = 1;
    } else {
	@words1 = @$set1;
	@words2 = @$set2;
    }

    # Ugly hack!  Or genius use of others' code, take your pick.  We
    # want to diff the word arrays again, but first we want to
    # convince Algorithm::Diff that approximate string matches are
    # matches.  We will use substitute arrays for this.
    my( @index_array1, @index_array2 );
    # Array 1 is A-Z
    foreach( 0 .. $#words1 ) { push( @index_array1, _return_alpha_string( $_ ) ) };
    # Array 2 starts as 0-9; this will change
    foreach( 0 .. $#words2 ) { push( @index_array2, $_ ) };

    foreach my $curr_idx ( 0 .. $#words1 ) {
	my $w = $words1[$curr_idx]->word();
	my $best_distance;
	my $best_idx;

	foreach my $curr_idx2 ( 0 .. $#words2 ) {
	    my $w2 = $words2[$curr_idx2]->word();
	    # See if $w best matches $w2.  If so, record the
	    # corresponding indices, if they aren't the same.
	    
	    my $dist = &$distance( $w, $w2 );
	    $best_distance = $dist unless defined $best_distance;
	    $best_idx = $curr_idx2 unless defined $best_idx;
	    if( $dist < $best_distance ) {
		$best_distance = $dist;
		$best_idx = $curr_idx2;
	    }
	    $curr_idx2++;
	}
	 
	# So did we find a match?  Test against our configured fuzziness
	# value.  Distance should be no more than $fuzziness percent of
	# length.
	if( $best_distance < ( length( $w ) * $self->{fuzziness} / 100 ) ) { 
	    # this is enough of a match.
	    print STDERR "matched $w to " . $words2[$best_idx]->word() . "...\n"
		if $self->{debug} > 1;
	    # Make index_array2 match index_array1 for this word.
	    if( $index_array2[$best_idx] =~ /^[A-Z]+$/ ) {
		# Skip it.  This word has had an earlier match.
		print STDERR "...but " . $words2[$best_idx]->word() . 
		    " already has a match.  Skipping.\n"
		    if $self->{debug} > 1;
	    } else {
		$index_array2[$best_idx] = $index_array1[$curr_idx];
	    }
	} else {
	    print STDERR "Found no match for $w\n"
		if $self->{debug} > 1;
	}
	
	$curr_idx++;
    }

    # Now pass the index arrays to Algorithm::Diff, and use the diff
    # results on the original word arrays.
    my $minidiff = Algorithm::Diff->new( \@index_array1, \@index_array2 );
    my( @aligned1, @aligned2 );
    while( $minidiff->Next() ) {
	if( $minidiff->Same() ) {
	    $self->_handle_diff_same( $minidiff, \@words1, \@words2, \@aligned1, \@aligned2 );
	} elsif( !scalar( $minidiff->Range( 1 ) ) ) {
	    $self->_handle_diff_interpolation( $minidiff, 2, \@words2, \@aligned2, \@aligned1 );
	} elsif( !scalar( $minidiff->Range( 2 ) ) ) {
	    $self->_handle_diff_interpolation( $minidiff, 1, \@words1, \@aligned1, \@aligned2 );
	} else {
	    ## Just pad out the shorter one.
	    my @r1 = $minidiff->Range( 1 );
	    my @r2 = $minidiff->Range( 2 );
	    push( @aligned1, @words1[@r1] );
	    push( @aligned2, @words2[@r2] );

	    my $pad_needed = scalar( @r1 ) - scalar( @r2 );
	    if( $pad_needed > 0 ) {
		push( @aligned2, ( $self->empty_word ) x $pad_needed );
	    } elsif( $pad_needed < 0 ) {
		push( @aligned1, ( $self->empty_word ) x abs( $pad_needed ) );
	    }
	}
    }

    ### TODO: Look for transpositions before we return.

    # Make sure we are returning the same number of word items per array.
    unless( scalar @aligned1 == scalar @aligned2 ) {
	warn "Uneven collation! " . join( ",", _stripped_words( \@aligned1 ) ) . " / "
	    . join( ",", _stripped_words( \@aligned2 ) ) ;
    }
    
    # Return the padded strings in the order in which we were given them.
    if( $inverted ) {
	return( \@aligned2, \@aligned1 );
    } else {
	return( \@aligned1, \@aligned2 );
    }
}

# Helper function.  Returns a string composed of upper-case ASCII
# characters based on an index number.  Handles overflow past 26.
sub _return_alpha_string {
    my $idx = shift;
    return 'A' if $idx == 0;

    my @chars;
    while( $idx > 0 ) {
	push( @chars, chr( ( $idx % 26 ) + 65 ) );
	$idx = int( $idx / 26 );
    }
    return scalar( reverse @chars );
}

1;

=head1 BUGS / TODO

=over

=item *

Make transposition work properly

=item *

Refactor the string matching; currently it's done twice

=item *

Proper documentation

=back

=head1 AUTHOR

Tara L Andrews E<lt>aurum@cpan.orgE<gt>
