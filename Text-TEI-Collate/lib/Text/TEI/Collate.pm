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
	my $rc = eval { require Text::WagnerFischer };
	if( $rc ) {
	    $self->{distance_sub} = &Text::WagnerFischer::distance;
	} else {
	    warn "No edit distance subroutine passed; default Text::WagnerFischer::distance unavailable.  Cannot initialize collator.";
	    return undef;
	}
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

    my @manuscripts;
    foreach ( @texts ) {
	# Break down each text into word-object arrays.
	push( @manuscripts, $self->read_manuscript_source( $_ ) );
    }

    # This will hold many arrays, one for each collated text.  Each member
    # array will be a list of word objects.  We will eventually return it.
    my @result_array;

    if( scalar( @manuscripts ) == 1 ) {
	# That was easy then.
	return @manuscripts;
    }

    # At this point we have an array of arrays.  Each member array
    # contains a hash object for each word, describing its
    # characteristics.  These are the uncollated texts, now in the
    # object form that we will eventually return.

    # The first file becomes the base, for now.
    # TODO: Work parsimony info into the choosing of a base
    my @ms_texts = map { $_->words } @manuscripts;
    my $base_text = shift @ms_texts;

    for ( 0 .. $#ms_texts ) {
	my $text = $ms_texts[$_];
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
	if( $_ < $#ms_texts ) {
	    $base_text = $self->generate_base( $result1, $result2 );
	}
    }

    # Take the contents of @result_array and put them back into the
    # manuscripts.

    foreach my $i ( 0 .. $#result_array ) {
	$manuscripts[$i]->replace_words( $result_array[$i] );
    }
    return @manuscripts;
}

# Small utility to get a string out of an array of word objects.
sub _stripped_words {
    my $text = shift;
    my @words = map { defined $_->placeholder ? $_->placeholder : $_->word } @$text;
    return @words;
}

sub empty_word {
    my $self = shift;
    unless( defined $self->{'null_word'} 
	    && ref( $self->{'null_word'} ) eq 'Text::TEI::Collate::Word' ) {
	# Make a null word and save it.
	$self->{'null_word'} = Text::TEI::Collate::Word->new( string => '' );
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

	    # Match them up.
	    my( $aligned1, $aligned2 ) = $self->match_and_align_words( \@base_wlist, \@new_wlist );
	    
	    # Push it all on.
	    push( @base_result, @$aligned1 );
	    push( @new_result, @$aligned2 );
	}	
    }

    return( \@base_result, \@new_result );
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
    # from T1, otherwise T2, etc.  
    my @new_base;
    foreach my $idx ( 0 .. $length-1 ) {
	my $word = $self->empty_word;  # We should never end up using this
	                             # word, but just in case there is a
	                             # gap, it should be the right object.
	foreach my $col ( 0 .. $width - 1 ) {
	    if( $texts[$col]->[$idx]->word() ne '' ) {
		$word = $texts[$col]->[$idx];
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

# Take a word source and convert it into a manuscript object with a
# list of word objects.  The following sources are supported:
# - plaintext files
# - XML::LibXML::Documents

sub read_manuscript_source {
    my $self = shift;
    my $wordsource = shift;

    my @words;

    # The wordsource should either be a filename or an
    # XML::LibXML::Document.

    my $docroot;
    
    # Now we have either a filehandle or an XML doc.
    if( !ref( $wordsource ) ) {  # Assume it's a filename.
	if( $self->{'TEI'} ) {
	    my $parser = XML::LibXML->new();
	    my $doc;
	    eval { $doc = $parser->parse_file( $wordsource ); };
	    unless( $doc ) {
		warn "Failed to parse file $wordsource into valid XML; reading no words";
		return @words;
	    }
	    $docroot = $doc->documentElement;
	} else {
	    # It's a plaintext file.  Put it all in a string.
	    my $binmode = "<:" . $self->{'binmode'};
	    my $rc = open( INFILE, $binmode, $wordsource );
	    unless( $rc ) {
		warn "Failed to open file $wordsource; reading no words";
		return @words;
	    }
	    my @lines = <INFILE>;
	    close INFILE;
	    $docroot = join( '', @lines );
	}
    } elsif ( ref( $wordsource ) eq 'XML::LibXML::Document' ) { # A LibXML object
	$docroot = $wordsource->getDocumentRoot;
	if( $docroot->nodeName eq 'TEI' ) {
	    # If we have been passed a TEI XML object, it's fair to assume 
	    # the user wants TEI parsing.
	    $self->{'TEI'} = 1;
	}
    } else {   
	warn "Unrecognized object $wordsource; reading no words";
	return @words;
    }

    # We have the XML doc.  Get the manuscript data out.
    my $parse_input = $self->{'TEI'} ? 'xmldesc' : 'plaintext';
    my $ms_obj = Text::TEI::Collate::Manuscript->new( 
	'type' => $parse_input,
	'source' => $docroot,
	'canonizer' => $self->{'canonizer'} 
	);
    
    # Now get the words.
    # Assume for now one body text
    return $ms_obj;
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
    # Array 1 has alpha strings
    foreach( 0 .. $#words1 ) { push( @index_array1, _return_alpha_string( $_ ) ) };
    # Array 2 starts with numeric strings; this will change as
    # matches are found.
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
	    print STDERR "Distance on $w / $w2 is $dist\n"
		if $self->{'debug'} > 3;
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
