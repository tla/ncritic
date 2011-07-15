package Text::TEI::Collate;

use strict;
use vars qw( $VERSION );
use Algorithm::Diff;
# use Contextual::Return ## TODO: examine
use JSON qw( decode_json );
use Text::TEI::Collate::Word;
use Text::TEI::Collate::Manuscript;
use XML::LibXML;

$VERSION = "1.1";

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
	fuzziness => { 'val' => 40, 'short' => 6, 'shortval' => 50 },
	binmode => 'utf8',
	# TODO make this all come from one language module.
	canonizer => undef,
	comparator => undef,
	%opts,
    };
    
    unless( defined $self->{distance_sub} ) {
	# Use the default.
	my $rc = eval { require Text::WagnerFischer };
	if( $rc ) {
	    $self->{distance_sub} = \&Text::WagnerFischer::distance;
	} else {
	    warn "No edit distance subroutine passed; default Text::WagnerFischer::distance unavailable.  Cannot initialize collator.";
	    return undef;
	}
    }
        
    if( my $b = $self->{'binmode'} ) {
	binmode STDERR, ":$b";
    }
    
    bless $self, $class;
    return $self;

}

=head2 read_source

Pass in a word source (a plaintext file, a TEI XML file, or a JSON structure) 
and a set of options, and get back one or more manuscript objects that can be 
collated.  Options include:

=over

=item *

canonizer - reference to a subroutine that returns the canonized (e.g. spell-
corrected) form of the original word.

=item *

comparator - reference to a subroutine that returns the normalized comparison
string (e.g. all lowercase, no accents) for a word.

=item *

encoding - The encoding of the word source if we are reading from a file.  
Defaults to utf-8.

=item *

sigil - The sigil that should be assigned to this manuscript in the collation 
output.  Should be a valid XML attribute value.  This can also be read from a
TEI XML source.

=item *

identifier - A string to identify this manuscript (e.g. library, MS number).
Can also be read from a TEI <msdesc/> element.

=back

=begin testing

use lib 't/lib';
use Text::TEI::Collate;
use XML::LibXML;
use Words::Armenian;

my $aligner = Text::TEI::Collate->new();

# Test a manuscript with a plaintext source, filename

my @mss = $aligner->read_source( 't/data/plaintext/test1.txt',
 	'sigil' => 'MsA',
	'identifier' => 'plaintext 1',
	'canonizer' => \&Words::Armenian::canonize_word,
	);
is( scalar @mss, 1, "Got a single object for a plaintext file");
my $ms = pop @mss;
	
is( ref( $ms ), 'Text::TEI::Collate::Manuscript', "Got manuscript object back" );
is( $ms->sigil, 'MsA', "Got correct sigil MsA");
is( scalar( @{$ms->words}), 181, "Got correct number of words in MsA");

# Test a manuscript with a plaintext source, string
open( T2, "t/data/plaintext/test2.txt" ) or die "Could not open test file";
my @lines = <T2>;
close T2;
@mss = $aligner->read_source( join( '', @lines ),
	'sigil' => 'MsB',
	'identifier' => 'plaintext 2',
	'canonizer' => \&Words::Armenian::canonize_word,
	);
is( scalar @mss, 1, "Got a single object for a plaintext string");
$ms = pop @mss;

is( ref( $ms ), 'Text::TEI::Collate::Manuscript', "Got manuscript object back" );
is( $ms->sigil, 'MsB', "Got correct sigil MsB");
is( scalar( @{$ms->words}), 183, "Got correct number of words in MsB");
is( $ms->identifier, 'plaintext 2', "Got correct identifier for MsB");

# Test two manuscripts with a JSON source
open( JS, "t/data/json/testwit.json" ) or die "Could not read test JSON";
@lines = <JS>;
close JS;
@mss = $aligner->read_source( join( '', @lines ),
	'canonizer' => \&Words::Armenian::canonize_word,
	);
is( scalar @mss, 2, "Got two objects from the JSON string" );
is( ref( $mss[0] ), 'Text::TEI::Collate::Manuscript', "Got manuscript object 1");
is( ref( $mss[1] ), 'Text::TEI::Collate::Manuscript', "Got manuscript object 2");
is( $mss[0]->sigil, 'MsAJ', "Got correct sigil for ms 1");
is( $mss[1]->sigil, 'MsBJ', "Got correct sigil for ms 2");
is( scalar( @{$mss[0]->words}), 182, "Got correct number of words in ms 1");
is( scalar( @{$mss[1]->words}), 263, "Got correct number of words in ms 2");
is( $mss[0]->identifier, 'JSON 1', "Got correct identifier for ms 1");
is( $mss[1]->identifier, 'JSON 2', "Got correct identifier for ms 2");

# Test a manuscript with an XML source
@mss = $aligner->read_source( 't/data/xml_plain/test3.xml',
	'canonizer' => \&Words::Armenian::canonize_word,
	);
is( scalar @mss, 1, "Got a single object from XML file" );
$ms = pop @mss;

is( ref( $ms ), 'Text::TEI::Collate::Manuscript', "Got manuscript object back" );
is( $ms->sigil, 'BL5260', "Got correct sigil BL5260");
is( scalar( @{$ms->words}), 178, "Got correct number of words in MsB");
is( $ms->identifier, 'London OR 5260', "Got correct identifier for MsB");

my $parser = XML::LibXML->new();
my $doc = $parser->parse_file( 't/data/xml_plain/test3.xml' );
@mss = $aligner->read_source( $doc,
	'canonizer' => \&Words::Armenian::canonize_word,
	);
is( scalar @mss, 1, "Got a single object from XML object" );
$ms = pop @mss;

is( ref( $ms ), 'Text::TEI::Collate::Manuscript', "Got manuscript object back" );
is( $ms->sigil, 'BL5260', "Got correct sigil BL5260");
is( scalar( @{$ms->words}), 178, "Got correct number of words in MsB");
is( $ms->identifier, 'London OR 5260', "Got correct identifier for MsB");

=end testing

=cut 

sub read_source {
	my( $self, $wordsource, %options ) = @_;
	my @docroots;
	my $format;
	
	if( !ref( $wordsource ) ) {  # Assume it's a filename.
		my $parser = XML::LibXML->new();
		my $doc;
		eval { $doc = $parser->parse_file( $wordsource ); };
		if( $doc ) {
			( $format, @docroots) = _get_xml_roots( $doc );
			return unless @docroots;
		} else {
			# It's not an XML document filename.  Determine plaintext
			# filename, plaintext string, or JSON string.
			my $encoding = delete $options{'binmode'};
			$encoding ||= 'utf8';
			my $binmode = "<:" . $encoding;
			my $rc = open( INFILE, $binmode, $wordsource );
			$format = 'plaintext';
			if( $rc ) {
				my @lines = <INFILE>;
				close INFILE;
				@docroots = ( join( '', @lines ) );
			} else {
				my $json;
				eval { $json = decode_json( $wordsource ) };
				if( $json ) {
					$format = 'json';
					push( @docroots, @{$json->{'witnesses'}} );
				} else {
					# Assume plain old string input.
					@docroots = ( $wordsource );
				}
			}
		}
	} elsif ( ref( $wordsource ) eq 'XML::LibXML::Document' ) { # A LibXML object
		( $format, @docroots ) = _get_xml_roots( $wordsource );
	} else {   
		warn "Unrecognized object $wordsource; reading no words";
		return ();
	}

	# We have the representations of the manuscript(s).  Initialize our object(s).
	my @ms_objects;
	foreach my $doc ( @docroots ) {
		push( @ms_objects, Text::TEI::Collate::Manuscript->new( 
			'sourcetype' => $format,
			'source' => $doc,
			%options,
			) );
	}
	return @ms_objects;
}

sub _get_xml_roots {
	my( $xmldoc ) = @_;
	my( @docroots, $format );
	if( $xmldoc->documentElement->nodeName =~ /^tei/i ) {
		# It is TEI format.
		@docroots = ( $xmldoc->documentElement );
		$format = 'xmldesc';
	} elsif( $xmldoc->documentElement->nodeName =~ /^examples/i ) {
		# It is CollateX simple input format.  Read the text
		# strings and then treat it as plaintext.
		my @collationtexts = $xmldoc->documentElement->getChildrenByTagName( 'example' );
		if( @collationtexts ) {
			# Use the first text example in the file; we do not handle multiple
			# collation runs on different texts.
			my @witnesses = $collationtexts[0]->getChildrenByTagName( 'witness' );
			@docroots = map { $_->textContent } @witnesses;
			$format = 'plaintext';
		} else {
			warn "Found no example elements in CollateX XML";
			return ();
		}
	} else {
		# Uh-oh, it is not a TEI or CollateX sort of document.
		warn "Cannot parse XML document type " 
			. $xmldoc->documentElement->nodeName . "; reading no words";
		return ();
	}
	return( $format, @docroots );
}

=head2 align

The meat of the program.  Takes a list of Text::TEI::Collate::Manuscript 
objects (created by new_manuscript above.)  Returns the same objects with 
their wordlists collated. 

=cut

sub align {
    my( $self, @manuscripts ) = @_;

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
	$self->debug( "Beginning run of build_array for text " . ($_+2) );
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

	    $self->debug( 'All arrays now ' . scalar @{$result_array[0]} 
			  . ' items long' );

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

    # Top and tail each array.
    $self->begin_end_mark( @manuscripts );
    return @manuscripts;
}

# Small utility to get a string out of an array of word objects.
sub _stripped_words {
    my $text = shift;
    my @words = map { $_->comparison_form } @$text;
    return @words;
}

sub empty_word {
    my $self = shift;
    unless( defined $self->{'null_word'} 
	    && ref( $self->{'null_word'} ) eq 'Text::TEI::Collate::Word' ) {
	# Make a null word and save it.
	$self->{'null_word'} = Text::TEI::Collate::Word->new( empty => 1 );
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
	    $self->debug( "Diff: collating words " 
			  . join( '.', $diff->Items( 1 ) ) . " / " 
			  . join( '.', $diff->Items( 2 ) ), 1 );
	    
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

    $self->check_gaps( \@base_result, \@new_result );
    $self->link_words( \@base_result, \@new_result );

    return( \@base_result, \@new_result );
}

## Diff handling functions.  Used in build_array and in match_and_align_words.  
## Thanks to our array-substitution trickery in match_and_align_words, we may
## not assume that the $diff object has the actual items we want.  Only the
## indices are meaningful.

sub _handle_diff_same {
    my $self = shift;
    my( $diff, $base_text, $new_text, $base_result, $new_result, $msg ) = @_;
    # Get the index range.
    $msg = 'same' unless $msg;
    my @rbase = $diff->Range( 1 );
    my @rnew = $diff->Range( 2 );
    my @base_wlist = @{$base_text}[@rbase];
    my @new_wlist = @{$new_text}[@rnew];
    my $msg_words = join( ' ', _stripped_words( \@base_wlist ) );
    $msg_words .= ' / ' . join( ' ', _stripped_words( \@new_wlist ) )
	unless( $msg eq 'same' );
    $self->debug( "Diff: pushing $msg words $msg_words", 2 );
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
    
    $self->debug( "DBrecord: pushing $op " 
		  . join( ' ',  _stripped_words( \@wlist ) ), 2 );
    push( @$to_result, ( $self->empty_word ) x scalar( @wlist ) );
    push( @$from_result, @wlist );
}


# generate_base: Take an array of text arrays and flatten them.  There
# should not be a blank element in the resulting base.  Currently
# used for only two input arrays at a time.  

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
	    if( $texts[$col]->[$idx]->comparison_form ne '' ) {
		$word = $texts[$col]->[$idx];
		$word->is_base( 1 );
		last;
	    }
	}
	# Disabled due to BEGIN shenanigans
	# warn( "No word found in any column at index $idx!" )
	    # if( $word eq $self->empty_word );
	push( @new_base, $word );
    }
    
    return \@new_base;
}

# Take a word source (a filename, a string, or an
# XML::LibXML::Document object), detect its type, and convert it into
# a manuscript object with a list of word objects.  The following
# sources are supported:
# - filename (for plaintext or TEI)
# - JSON string
# - plaintext file
# - XML::LibXML::Document that is TEI

sub read_manuscript_source {
    my $self = shift;
    my $wordsource = shift;

    my @docroots;
    my $format;
    
    if( !ref( $wordsource ) ) {  # Assume it's a filename.
	my $parser = XML::LibXML->new();
	my $doc;
	eval { $doc = $parser->parse_file( $wordsource ); };
	if( $doc && $doc->documentElement->nodeName =~ /^tei/i ) {
	    # It is TEI format.
	    @docroots = ( $doc->documentElement );
	    $format = 'xmldesc';
	} elsif( $doc && $doc->documentElement->nodeName =~ /^examples/i ) {
	    # It is CollateX simple input format.  Read the text
	    # strings and then treat it as plaintext.
	    my @collationtexts = $doc->documentElement->getChildrenByTagName( 'example' );
	    if( @collationtexts ) {
		# Use the first text example in the file; we do not handle multiple
		# collation runs on different texts.
		my @witnesses = $collationtexts[0]->getChildrenByTagName( 'witness' );
		@docroots = map { $_->textContent } @witnesses;
		$format = 'plaintext';
	    } else {
		warn "Found no example elements in CollateX XML";
		return ();
	    }
	} elsif( $doc ) {
	    # Uh-oh, it is not a TEI sort of document.
	    warn "Cannot parse XML document type " 
		. $doc->documentElement->nodeName . "; reading no words";
	    return ();
	} else {
	    # It's not an XML document filename.  Determine plaintext
	    # filename, plaintext string, or JSON string.
	    my $binmode = "<:" . $self->{'binmode'};
	    my $rc = open( INFILE, $binmode, $wordsource );
	    $format = 'plaintext';
	    if( $rc ) {
		my @lines = <INFILE>;
		close INFILE;
		@docroots = ( join( '', @lines ) );
	    } else {
		my $json;
		eval { $json = decode_json( $wordsource ) };
		if( $json ) {
		    $format = 'json';
		    push( @docroots, @{$json->{'witnesses'}} );
		} else {
		    # Assume plain old string input.
		    $self->debug( 'Assuming string input', 2 );
		    @docroots = ( $wordsource );
		}
	    }
	}
    } elsif ( ref( $wordsource ) eq 'XML::LibXML::Document' ) { # A LibXML object
	@docroots = ( $wordsource->getDocumentRoot );
	$format = 'xmldesc';
	if( $docroots[0]->nodeName eq 'TEI' ) {
	    # If we have been passed a TEI XML object, it's fair to assume 
	    # the user wants TEI parsing.
	    $self->{'TEI'} = 1;
	}
    } else {   
	warn "Unrecognized object $wordsource; reading no words";
	return ();
    }

    # We have the representations of the manuscript(s).  Initialize our object(s).
    my @ms_objects;
    foreach my $doc ( @docroots ) {
	push( @ms_objects, Text::TEI::Collate::Manuscript->new( 
		  'type' => $format,
		  'source' => $doc,
		  'canonizer' => $self->{'canonizer'},
		  'comparator' => $self->{'comparator'},
	      ) );
    }
    return @ms_objects;
}

# link_words: Another example of my startling inefficiency.  Build
# links on the base wordlist to the new wordlist, saying what is a
# fuzzy match and what is not.  For later apparatus construction.

sub link_words {
    my $self = shift;
    my( $base, $new ) = @_;

    # Again with the bloody index counting.
    foreach my $i ( 0 .. $#{$base} ) {
	my $word_obj = $base->[$i];
	my $new_word_obj = $new->[$i];

	# No links to the empty word.
	next if $word_obj eq $self->empty_word;
	next if $new_word_obj eq $self->empty_word;

	$self->debug( "Trying to set link for " . $word_obj->comparison_form . " / "
		      . $new_word_obj->comparison_form . "...", 1, 1 );

	# Now we have to repeat the distance checking that we did in
	# &match_and_align_words.  This cries out for refactoring, but
	# refactoring is hard because there we need the best match, and
	# here we need a yes/no answer.  We've partially refactored it
	# into _index_word_match anyway.
	my $match_answer = $self->_index_word_match( $base, $new, $i );
	if( $match_answer ne 'no' ) {
	    $word_obj->add_link( $new_word_obj );
	    $self->debug( "word match: $match_answer", 1 );
	} else {
	    # Trot out the list of variants.
	    my $found_variant_match = 0;
	    foreach my $var_obj ( $word_obj->variants ) {
		$match_answer = $self->_index_word_match( $base, $new, $i, $var_obj );
		if( $match_answer ne 'no' ) {
		    $var_obj->add_link( $new_word_obj );
		    $found_variant_match = 1;
		    $self->debug( "variant match: $match_answer to " 
				  . $var_obj->comparison_form, 1 );
		    last;
		}
	    }
	    unless( $found_variant_match ) {
		$word_obj->add_variant( $new_word_obj );
		$self->debug( "new variant" );
	    }
	}
    }
}
	
sub _index_word_match {
    my $self = shift;
    my( $words1, $words2, $idx, $alt_start ) = @_;

    # Possible return values are 'yes', 'glom', 'no'
    my $w1obj = $alt_start ? $alt_start : $words1->[$idx];
    my $w2obj = $words2->[$idx];
    return 'yes' if( $self->_is_near_word_match( $w1obj->comparison_form, $w2obj->comparison_form ) );

    my( $w1glom, $w2glom );
    if( length( $w1obj->comparison_form ) > length( $w2obj->comparison_form ) ) {
	$w1glom = $w1obj->comparison_form;
	$w2glom = $w2obj->comparison_form . ( $idx < $#{$words2} ? 
				   $words2->[$idx+1]->comparison_form : '' );
    } else {
	$w2glom = $w2obj->comparison_form;
	$w1glom = $w1obj->comparison_form . ( $idx < $#{$words1} ? 
				   $words1->[$idx+1]->comparison_form : '' );
    }
    return 'glom' if $self->_is_near_word_match( $w1glom, $w2glom );
    return 'no';
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
    my $dist = &$distance( $word1, $word2 );
    return( $self->_is_match( $word1, $word2, $dist ) );
}


# check_gaps: Run some heuristics on the new finished array, looking
# for orphan words in a sea of undefs.  Try to find a contiguous home
# for them.

# TODO: check & fix gaps in the base (i.e. previous arrays.)  Which is
# actually kind of hard.
sub check_gaps {
    my $self = shift;
    my( $base, $new ) = @_;
    
    # Will need some state vars.
    my @seq;
    my $last_def = 0;
    my $ctr = 0;
    foreach my $idx ( 0 .. $#{$new} ) {
	if( $new->[$idx] eq $self->empty_word ) {
	    if( $last_def ) {
		$last_def = 0;
		push( @seq, "word_$ctr" . '_' . ($idx-1) );
		$ctr = 1;
	    } else {
		$ctr++;
	    }
	} else {
	    if( $last_def ) {
		$ctr++;
	    } else {
		$last_def = 1;
		push( @seq, "empty_$ctr" . '_' . ($idx-1) ) if $idx > 0;
		$ctr = 1;
	    }
	}
    }
	
    $self->debug( "Check_array gave seq @seq" );
    # Looking for empty_big, word_small, empty_big sequence.
    my @orphans;
    my $last_orphan_idx;
    foreach my $idx( 0 .. $#seq ) {
	my( $stat, $mag, $colidx ) = split( /_/, $seq[$idx] );
	next if $stat eq 'empty';
	# b is before, a is after
	my $before = $idx > 0 ? $seq[$idx-1] : '';
	my( $bstat, $bmag, $b_colidx ) = $before ? split( /_/, $before ) : ( '' ) x 3;
	my $after = $idx < $#seq ? $seq[$idx+1] : '';
	my( $astat, $amag, $a_colidx ) = $after ? split( /_/, $after ) : ( '' ) x 3;
	if( $mag < 3 && 
	    ( $bstat eq '' || ( $bstat eq 'empty' && $bmag / $mag >= 4 ) ) &&
	    ( $astat eq '' || ( $astat eq 'empty' && $amag / $mag >= 4 ) ) ) {
	    # Disregard "orphans" that are sectioning markers.
	    my @words = _stripped_words( 
		[ $self->_wordlist_slice( $new, $seq[$idx] ) ] );
	    next if grep( /^__.*__$/, @words ) == scalar @words;
	    # Talk about it.
	    $self->debug( "Found orphan at index $colidx: entries are " .
		  join( ' ', $seq[$idx-1], $seq[$idx], $seq[$idx+1] ), 1 );
	    if( $last_orphan_idx && $last_orphan_idx == $idx - 2 ) {
		# It's probably the same orphan.  Add it to the last
		# datastructure.
		my $curr = pop( @orphans );
		push( @{$curr->{'words'}}, $seq[$idx] );
		$curr->{'after'} = $after;
		push( @orphans, $curr );
	    } else {
		push( @orphans, { 'before' => $before,
				  'words' => [$seq[$idx]],
				  'after' => $after } );
	    }
	    $last_orphan_idx = $idx;
	}
    }

    if( $self->{'debug'} ) {
	foreach( @orphans ) {
	    $self->debug( "Orphan group is " . join(' ', @{$_->{'words'}} ) );
	}
    }

    # Now.  For each of the orphan groups, smush the words back
    # together and look for a match closer to home, first at the next
    # block of words and then at the previous block (if any.)

    foreach( @orphans ) {
	my @orphaned_words;
	my @saved_state;
	foreach my $block ( @{$_->{'words'}} ) {
	    push( @orphaned_words, $self->_wordlist_slice( $new, $block ) );
	    @saved_state = map { $_->state } @orphaned_words;
	}
	
	# First try the after.
	my $better_match = undef;
	my $base_entry = '';  # Must construct this to use convenience fn.
	if( $_->{'after'} ) {
	    # Within this block $idx refers to the end of the 'after' gap.
	    my( $kind, $size, $idx ) = split( /_/, $_->{'after'} );
	    # Grab the base around that index, and pad it out with a few
	    # extra words.
	    my @base_words = 
		@{$base}[ ($idx - 4 - scalar @orphaned_words) .. ($idx) ];
	    my @base_state = map { $_->state } @base_words;
	    $base_entry = 'base_' . scalar( @base_words ) . "_$idx";
	    $self->debug( "Will try new alignment on words " 
			  . join( ' ', _stripped_words( \@orphaned_words ) ) 
			  . ' and ' 
			  . join( ' ', _stripped_words( \@base_words ) ) );

	    my( $rematch_base, $rematch_new, $quality ) = $self->match_and_align_words( \@base_words, \@orphaned_words, 1 );
	    if( $quality > 49 ) {
		$self->debug( "...match has quality $quality; will fix the array with this" );
		$better_match = [ $rematch_base, $rematch_new ];
	    } else {
		# Return the words to status quo.
		foreach my $jdx( 0 .. $#orphaned_words ) {
		    $orphaned_words[$jdx]->restore_state( $saved_state[$jdx] );
		}
		foreach my $jdx( 0 .. $#base_words ) {
		    $base_words[$jdx]->restore_state( $base_state[$jdx] );
		}
	    }
	}
	if( !$better_match && $_->{'before'} ) {
	    my( $kind, $size, $idx ) = split( /_/, $_->{'before'} );
	    # Here, $idx is the last index of the previous gap.  Move it
	    # to the end of the previous chunk of text.
	    $idx = $idx - $size;
	    my @base_words = @{$base}[ ($idx+1) .. 
				       ($idx+scalar(@orphaned_words)+4) ];
	    my @base_state = map { $_->state } @base_words;
	    $base_entry = 'base_' . scalar( @base_words ) . '_'
		. ( $idx+scalar(@orphaned_words)+4 );
	    $self->debug( "Will try next new alignment on words " 
			  . join( ' ', _stripped_words( \@orphaned_words ) ) 
			  . ' and ' 
			  . join( ' ', _stripped_words( \@base_words ) ) );
	    my( $rematch_base, $rematch_new, $quality ) = $self->match_and_align_words( \@base_words, \@orphaned_words, 1 );
	    if( $quality > 49 ) {
		$self->debug( "...match has quality $quality; will fix the array with this" );
		$better_match = [ $rematch_base, $rematch_new ];
	    } else {
		# Return the words to status quo.
		foreach my $jdx( 0 .. $#orphaned_words ) {
		    $orphaned_words[$jdx]->restore_state( $saved_state[$jdx] );
		}
		foreach my $jdx( 0 .. $#base_words ) {
		    $base_words[$jdx]->restore_state( $base_state[$jdx] );
		}
	    }
	}

	if( $better_match ) {
	    # Fix the array!  First blank out all the orphans from this set.
	    foreach my $block( @{$_->{'words'}} ) {
		$self->_wordlist_slice( $new, $block, 'empty' );
	    }
	    # Now splice in the better match.
	    $self->_wordlist_slice( $base, $base_entry, $better_match->[0] );
	    $self->_wordlist_slice( $new, $base_entry, $better_match->[1] );
	} else {
	    $self->debug( "...No better match found; leaving as is\n" );
	}
    }
	    
}

sub _wordlist_slice {
    my $self = shift;
    my( $list, $entry, $replace ) = @_;
    my( $toss, $size, $idx ) = split( /_/, $entry );
    if( $replace ) {
	my @repl_array;
	if( $replace eq 'empty' ) {
	    @repl_array = ( $self->empty_word ) x $size;
	} elsif( ref $replace eq 'ARRAY' ) {
	    @repl_array = @$replace;
	}
	splice( @$list, $idx-$size+1, $size, @repl_array );
    } else {
	return @{$list}[ ($idx-$size+1) .. $idx ];
    }
}

# begin_end_mark: Note, with special words spliced in, where each
# text actually begins and ends.
my $GAP_MIN_SIZE = 18;
sub begin_end_mark {
    my $self = shift;
    my @manuscripts = @_;
    foreach my $text( @manuscripts ) {
	my $wordlist = $text->words;
	my $sigil = $text->sigil;
	my $first_word_idx = -1;
	my $last_word_idx = -1;
	my $gap_start = -1;
	my $gap_end = -1;
	foreach my $idx( 0 .. $#{$wordlist} ) {
	    my $word_obj = $wordlist->[$idx];
	    if( $first_word_idx > -1 ) {
		# We have found and coped with the first word; 
		# now we are looking for substantive gaps.
		if ( $word_obj->comparison_form ) {
		    $last_word_idx = $idx;
		    if( $gap_start > 0 &&
			( $gap_end - $gap_start ) > $GAP_MIN_SIZE ) {
			# Put in the gap start & end markers.  Here we are
			# replacing a blank, rather than adding to the array.
 			foreach( $gap_start, $gap_end ) {
 			    my $tag =  $_ < $gap_end ? 'BEGINGAP' : 'ENDGAP';
 			    my $gapdesc = $tag . "_1_$_";
  			    $self->_wordlist_slice( $wordlist, $gapdesc,
 					    [ _special( $tag, $sigil ) ] );
 			}
		    }
		    # Either way we are not now in a gap.  Reset the counters.
		    $gap_end = $gap_start = -1;
		# else empty space; are we in a gap?
		} elsif( $gap_start < 0 ) { 
		    $gap_start = $idx;
		} else {
		    $gap_end = $idx;
		}
	    # else we are still looking for the first non-blank word.
	    } elsif( $word_obj->comparison_form ) {
		$first_word_idx = $idx;
		# We have found the first real word.  Splice in a begin marker.
		my $slicedesc = join( '_', 'begin', 0, $idx-1 );
		$self->_wordlist_slice( $wordlist, $slicedesc, 
					[ _special( 'BEGIN', $sigil ) ] );
	    } # else it's a blank before the first word.
	} ## end foreach
	
	# Now put in the END element after the last word found.
	# First account for the fact that we shifted the end of the array.
	my $end_idx = $last_word_idx == $#{$wordlist} - 1 ? 
	    $last_word_idx+1 : $last_word_idx;
	my $slicedesc = join( '_', 'end', 0, $end_idx );
	$self->_wordlist_slice( $wordlist, $slicedesc, 
				[ _special( 'END', $sigil ) ] );
    }
}
		
sub _special {
    my( $mark, $sigil ) = @_;
    return Text::TEI::Collate::Word->new( special => $mark, 
					  ms_sigil => $sigil );
}

# match_and_align_words: Do the fuzzy matching necessary to roughly
# align two columns (i.e. arrays) of words.  Takes two word arrays;
# returns two word arrays aligned via empty-string element padding.
# Here is where $self->{distance_sub} is used.
	    
sub match_and_align_words {
    my $self = shift;
    my( $set1, $set2, $return_quality ) = @_;

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

    my $matched = 0;
    foreach my $curr_idx ( 0 .. $#words1 ) {
	my $w = $words1[$curr_idx]->comparison_form();
	my $wplus = $w . ( defined( $words1[$curr_idx+1] ) 
			   ? $words1[$curr_idx+1]->comparison_form() : '' );
	my $best_distance;
	my $best_idx;

	foreach my $curr_idx2 ( 0 .. $#words2 ) {
	    my $w2 = $words2[$curr_idx2]->comparison_form();
	    my $w2plus = $w2 . ( defined( $words2[$curr_idx2+1] ) 
			   ? $words2[$curr_idx2+1]->comparison_form() : '' );
	    # See if $w best matches $w2.  If so, record the
	    # corresponding indices, if they aren't the same.
	    
	    my $dist = &$distance( $w, $w2 );
	    $self->debug( "Distance on $w / $w2 is $dist", 3 );

	    # If the words are not a match but start with the same letter,
	    # check to see what happens if you glom the next word onto the
	    # shorter of the current words.
	    if( !($self->_is_match( $w, $w2, $dist )) &&
		substr( $w, 0, 2 ) eq substr( $w2, 0, 2 ) ) {
		my $distplus;
		if( length( $w2 ) > length( $w ) ) {
		    $self->debug( "Trying glommed match $wplus / $w2", 3 );
		    $distplus = &$distance( $wplus, $w2 );
		    if( $self->_is_match( $wplus, $w2, $distplus ) ) {
			$self->debug( "Using glommed match $wplus / $w2", 1 );
			$words1[$curr_idx]->is_glommed( 1 );
			$dist = $distplus * ( length($w) / length($wplus) );
		    } else {
			# If this is a base word, remember any previous
			# glomming.
			$words1[$curr_idx]->is_glommed( 0 )
			    unless $words1[$curr_idx]->is_base;
		    }
		} else {
		    $self->debug( "Trying glommed match $w / $w2plus", 3 );
		    $distplus = &$distance( $w, $w2plus );
		    if( $self->_is_match( $w, $w2plus, $distplus ) ) {
			$self->debug( "Using glommed match $w / $w2plus", 1 );
			$words2[$curr_idx2]->is_glommed( 1 );
			$dist = $distplus;
		    } else {
			# If this is a base word, remember any previous
			# glomming.
			$words2[$curr_idx2]->is_glommed( 0 )
			    unless $words2[$curr_idx2]->is_base;
		    }
		}
	    }
	    $best_distance = $dist unless defined $best_distance;
	    $best_idx = $curr_idx2 unless defined $best_idx;
	    if( $dist < $best_distance ) {
		$best_distance = $dist;
		$best_idx = $curr_idx2;
	    }
	    $curr_idx2++;
	}
	 
	# So did we find a match?  Test against our configured fuzziness
	# values.
	my $best_w2 = $words2[$best_idx]->comparison_form();
	if( $self->_is_match( $w, $best_w2, $best_distance ) ) {
	    # this is enough of a match.
	    $self->debug( "matched $w to " . $best_w2
			  . "...", 1 );
	    # Make index_array2 match index_array1 for this word.
	    if( $index_array2[$best_idx] =~ /^[A-Z]+$/ ) {
		# Skip it.  This word has had an earlier match.
		$self->debug( "...but " . $best_w2 .
			      " already has a match.  Skipping.", 1 );
	    } else {
		$index_array2[$best_idx] = $index_array1[$curr_idx];
		$matched++;
	    }
	} else {
	    $self->debug( "Found no match for $w", 1 );
	}
	
	$curr_idx++;
    }

    # Do we want to return the match quality?  If so, it is 
    # $matched x 100 / scalar @w1.
    my $quality = $matched * 100 / scalar(@words1);

    # Now pass the index arrays to Algorithm::Diff, and use the diff
    # results on the original word arrays.
    my $minidiff = Algorithm::Diff->new( \@index_array1, \@index_array2 );
    my( @aligned1, @aligned2 );
    while( $minidiff->Next() ) {
	if( $minidiff->Same() ) {
	    $self->_handle_diff_same( $minidiff, \@words1, \@words2, \@aligned1, \@aligned2, 'matched' );
	} elsif( !scalar( $minidiff->Range( 1 ) ) ) {
	    $self->_handle_diff_interpolation( $minidiff, 2, \@words2, \@aligned2, \@aligned1 );
	} elsif( !scalar( $minidiff->Range( 2 ) ) ) {
	    $self->_handle_diff_interpolation( $minidiff, 1, \@words1, \@aligned1, \@aligned2 );
	} else {
	    ## Pad out the shorter one
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

    # Make sure we are returning the same number of word items per array.
    unless( scalar @aligned1 == scalar @aligned2 ) {
	warn "Uneven collation! " . join( ",", _stripped_words( \@aligned1 ) ) . " / "
	    . join( ",", _stripped_words( \@aligned2 ) ) ;
    }
    
    # Return the padded strings in the order in which we were given them.
    my @retvals;
    if( $inverted ) {
	@retvals = ( \@aligned2, \@aligned1 );
    } else {
	@retvals = ( \@aligned1, \@aligned2 );
    }
    push( @retvals, $quality ) if $return_quality;
    return @retvals;
}

sub _is_match {
    my $self = shift;
    my ( $str1, $str2, $dist ) = @_;
    if( defined( $self->{'fuzziness_sub'} ) ) {
	return &{$self->{'fuzziness_sub'}}( @_ );
    } else {
	my $ref_str = $str1;
	return( $dist < ( length( $ref_str ) * $self->{'fuzziness'} / 100 ) );
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

=head2 to_tei

=head2 to_json

=head2 to_graphml

=head2 to_svg

=cut

sub to_json {
	my( $self, @mss ) = @_;
	my $result = { 'alignment' => [] };
	$DB::single = 1;
	foreach my $ms ( @mss ) {
		push( @{$result->{'alignment'}},
			  { 'witness' => $ms->sigil,
				'tokens' => $ms->tokenize_as_json()->{'tokens'}, } );
	}
	return $result;
}

## Block for to_tei logic
{
	##  Counter variables
	my $app_id_ctr = 0;  # for xml:id of <app/> tags
	my $word_id_ctr = 0; # for xml:id of <w/> tags that have witDetails
	
	## Constants
	my $ns_uri = 'http://www.tei-c.org/ns/1.0';
	# Local globals
	my ( $doc, $body );

	sub to_tei {
		my( $self, @mss ) = @_;
		( $doc, $body ) = _make_tei_doc( @mss );

		##  Generate a base by flattening all the results                               
		my $initial_base = $self->generate_base( map { $_->words } @mss );
		foreach my $idx ( 0 .. $#{$initial_base} ) {
			my %seen;
			map { $seen{$_->sigil} = 0 } @mss;
			my $word_obj = $initial_base->[$idx];
			my $apparatus = _make_tei_app( $word_obj, %seen );
		}

		return $doc;
	}

	sub _make_tei_doc {
		my @mss = @_;
		my $doc = XML::LibXML->createDocument( '1.0', 'UTF-8' );
		my $root = $doc->createElementNS( $ns_uri, 'TEI' );

		# Make the header
		my $teiheader = $root->addNewChild( $ns_uri, 'teiHeader' );
		my $filedesc = $teiheader->addNewChild( $ns_uri, 'fileDesc' );
		$filedesc->addNewChild( $ns_uri, 'titleStmt' )->
			addNewChild( $ns_uri, 'title' )->
			appendText( 'this is a title' );
		$filedesc->addNewChild( $ns_uri, 'publicationStmt' )->
			addNewChild( $ns_uri, 'p' )->
			appendText( 'this is a publication statement' );
		my $witnesslist = $filedesc->addNewChild( $ns_uri, 'sourceDesc')->
			addNewChild( $ns_uri, 'listWit' );
		foreach my $m ( @mss ) {
			my $wit = $witnesslist->addNewChild( $ns_uri, 'witness' );
			$wit->setAttribute( 'xml:id', $m->sigil );
			$wit->appendText( $m->identifier );
		}

		# Make the body element
		my $body_p = $root->addNewChild( $ns_uri, 'text' )->
			addNewChild( $ns_uri, 'body' )->
			addNewChild( $ns_uri, 'div' )->
			addNewChild( $ns_uri, 'p' );  # TODO maybe this should be lg?

		# Set the root...
		$doc->setDocumentElement( $root );
		# ...and return the doc and the body
		return( $doc, $body_p );
	}

	sub _make_tei_app {
		my( $word_obj, %seen ) = @_;
		my $return_el;
		# Word object has links (matches) and variants (positional 
		# non-matches). If an ms has no word here, we will not have seen its 
		# sigil when we go through the variants.
		my @matches = $word_obj->links;
		my @variants = $word_obj->variants;
		map { $seen{$_->ms_sigil} = 1 } ( $word_obj, @matches, @variants );
		# Now see if we have any actual variation; are there non-matches?
		my $variation = @variants ? 1 : 0;
		# Also if any of the values of %seen are zero, we have variation.
		foreach my $val ( values %seen ) {
			unless( $val ) {
				$variation = 1;
				last;
			}
		}
		# Also if the matches aren't identical, we have variation.
		if( !@variants ) {
			foreach my $w ( @matches ) {
				if( $w->canonical_form ne $word_obj->canonical_form ) {
					$variation = 1;
					last;
				}
			}
		} 
		
		# If we do have variation, we create an <app/> element to describe 
		# it.  If we don't, we create a <w/> element to hold the common word.
		if( $variation ) {
			my $app_el = $body->addNewChild( $ns_uri, 'app');
			$app_el->setAttribute( 'xml:id', 'app'.$app_id_ctr++ );
			my %forms;
			# TODO figure out how to handle placeholders.
			# For each of $word_obj, @matches, @variants, we need a rdg tag
			# with the witness sigils converted to their XML IDs.
			foreach my $rdg ( $word_obj, @matches, @variants ) {
				push( @{$forms{$rdg->canonical_form}}, $rdg->ms_sigil );
			}
			foreach my $form ( keys %forms ) {
				my $rdg_el = $app_el->addNewChild( $ns_uri, 'rdg' );
				my $wit_str = join( ' ', map { '#'.$_ } @{$forms{$form}});
				$rdg_el->setAttribute( 'wit', $wit_str );
				_wrap_punct( $rdg_el, $form );
			}
			$return_el = $app_el;
		} else {
			# Just give back a word object.
			my $w_el = $body->addNewChild( $ns_uri, 'w');
			$w_el->setAttribute( 'xml:id', 'w'.$word_id_ctr++ );
			$return_el = _wrap_punct( $w_el, $word_obj->canonical_form );
		}
	}
	
	sub _wrap_punct {
		my( $w_el, $word_obj ) = @_;
		my $str = $word_obj->canonical_form;
		my @punct = $word_obj->punctuation;
		my $last_pos = -1;
		foreach my $p ( @punct ) {
			my @letters = split( '', $str );
			if( $p->{char} eq $letters[$p->{pos}] ) {
				my $wordpart = @letters[$last_pos+1..$p->{pos}];
				$w_el->appendText( $wordpart );
				my $char = $w_el->addNewchild( $ns_uri, 'c');
				$char->setAttribute( "type", "punct" );
				$char->appendText( $p->{char} );
				$last_pos = $p->{pos};
			}
		}
		# Now append what is left of the word after the last punctuation.
		if( $last_pos < length( $str ) - 1 ) {
			my @letters = split( '', $str );
			my $wordpart = @letters[$last_pos+1..-1];
			$w_el->appendText( $wordpart );
		}
		return $w_el;
	}

}

## Print a debugging message.
sub debug {
    my $self = shift;
    my( $msg, $lvl, $no_newline ) = @_;
    $lvl = 0 unless $lvl;
    print STDERR 'DEBUG ' . ($lvl+1) . ": $msg"
	. ( $no_newline ? '' : "\n" )
	if $self->{'debug'} > $lvl;
}

1;

=head1 BUGS / TODO

=over

=item *

Refactor the string matching; currently it's done twice

=item *

Proper documentation

=back

=head1 AUTHOR

Tara L Andrews E<lt>aurum@cpan.orgE<gt>
