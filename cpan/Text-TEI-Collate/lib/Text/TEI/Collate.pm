package Text::TEI::Collate;

use strict;
use vars qw( $VERSION );
# use Algorithm::Diff;
use File::Temp;
use IPC::Run qw( run binary );
use JSON qw( decode_json );
use Text::TEI::Collate::Diff;
use Text::TEI::Collate::Word;
use Text::TEI::Collate::Manuscript;
use XML::LibXML;

$VERSION = "2.0";

eval { no warnings; binmode $DB::OUT, ":utf8" };

=head1 NAME

Text::TEI::Collate - a collation program for variant manuscript texts

=head1 SYNOPSIS

  use Text::TEI::Collate;
  my $aligner = Text::TEI::Collate->new();

  # Read from strings.
  my @manuscripts;
  foreach my $str ( @strings_to_collate ) {
    push( @manuscripts, $aligner->read_source( $str ) );
  }
  $aligner->align( @manuscripts; );

  # Read from files.  Also works for XML::LibXML::Document objects.
  @manuscripts = ();
  foreach my $xml_file ( @TEI_files_to_collate ) {
    push( @manuscripts, $aligner->read_source( $xml_file ) )
  }
  $aligner->align( @manuscripts );

  # Read from a JSON input.
  @manuscripts = $aligner->read_source( $JSON_string );
  $aligner->align( @manuscripts );
  
=head1 DESCRIPTION

Text::TEI::Collate is the beginnings of a collation program for multiple
(transcribed) manuscript copies of a known text.  It is an
object-oriented interface, mostly for the convenience of the author
and for the ability to have global settings.

The object is the alignment engine, or "aligner". The methods that a user will
care about are "read_source" and "align", as well as the various output
methods; the other methods in this file are public in case a user needs a
subset of this package's functionality.

An aligner takes two or more texts; the texts can be strings, filenames, or
XML::LibXML::Document objects. It returns two or more Manuscript objects --
one for each text input -- in which identical and similar words are lined up
with each other, via empty-string padding.

Please see the documentation for L<Text::TEI::Collate::Manuscript> and
L<Text::TEI::Collate::Word> for more information about the manuscript and word
objects.

=head1 METHODS

=head2 new

Creates a new aligner object.  Takes a hash of options; available
options are listed.

=over 4

=item B<debug> - Default 0. The higher the number (between 0 and 3), the more
the debugging output.

=item B<distance_sub> - A reference to a function that calculates a
Levenshtein-like distance between two words. Default is
Text::WagnerFischer::distance.

=item B<fuzziness> - The maximum allowable word distance for an approximate
match, expressed as a percentage of Levenshtein distance / word length. It can
also be expressed as a hashref with keys 'val', 'short', and 'shortval', if
you want to increase the tolerance for short words (defined as at or below the
value of 'short').

=item B<canonizer> - Takes a subroutine ref. The sub should take a string and
return a string. If defined, it will be called to produce a canonical form of
the string in question. Useful for getting rid of ligatures, un-composing
characters, correcting common spelling mistakes, etc.

=back

=begin testing

use Text::TEI::Collate;

my $aligner = Text::TEI::Collate->new();

is( ref( $aligner ), 'Text::TEI::Collate', "Got a Collate object from new()" );

=end testing

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
	
	unless( ref( $self->{fuzziness}) ) {
		my $fuzz = $self->{fuzziness};
		$self->{fuzziness} = { val => $fuzz, short => '0', shortval => $fuzz };
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

=item B<canonizer> - reference to a subroutine that returns the canonized (e.g. spell-
corrected) form of the original word.

=item B<comparator> - reference to a subroutine that returns the normalized comparison
string (e.g. all lowercase, no accents) for a word.

=item B<encoding> - The encoding of the word source if we are reading from a file.  
Defaults to utf-8.

=item B<sigil> - The sigil that should be assigned to this manuscript in the collation 
output.  Should be a valid XML attribute value.  This can also be read from a
TEI XML source.

=item B<identifier> - A string to identify this manuscript (e.g. library, MS number).
Can also be read from a TEI <msdesc/> element.

=back

=begin testing

use lib 't/lib';
use XML::LibXML;
use Words::Armenian;

my $aligner = Text::TEI::Collate->new();

# Test a manuscript with a plaintext source, filename

my @mss = $aligner->read_source( 't/data/plaintext/test1.txt',
	'identifier' => 'plaintext 1',
	'canonizer' => \&Words::Armenian::canonize_word,
	);
is( scalar @mss, 1, "Got a single object for a plaintext file");
my $ms = pop @mss;
	
is( ref( $ms ), 'Text::TEI::Collate::Manuscript', "Got manuscript object back" );
is( $ms->sigil, 'A', "Got correct sigil A");
is( scalar( @{$ms->words}), 181, "Got correct number of words in A");

# Test a manuscript with a plaintext source, string
open( T2, "t/data/plaintext/test2.txt" ) or die "Could not open test file";
my @lines = <T2>;
close T2;
@mss = $aligner->read_source( join( '', @lines ),
	'identifier' => 'plaintext 2',
	'canonizer' => \&Words::Armenian::canonize_word,
	);
is( scalar @mss, 1, "Got a single object for a plaintext string");
$ms = pop @mss;

is( ref( $ms ), 'Text::TEI::Collate::Manuscript', "Got manuscript object back" );
is( $ms->sigil, 'B', "Got correct sigil B");
is( scalar( @{$ms->words}), 183, "Got correct number of words in B");
is( $ms->identifier, 'plaintext 2', "Got correct identifier for B");

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

## The mss we will test the rest of the tests with.
@mss = $aligner->read_source( 't/data/cx/john18-2.xml' );
is( scalar @mss, 28, "Got correct number of mss from CX file" );
my %wordcount = (
	'base' => 57,
	'P60' => 20,
	'P66' => 55,
	'w1' => 58,
	'w11' => 57,
	'w13' => 58,
	'w17' => 58,
	'w19' => 57,
	'w2' => 58,
	'w21' => 58,
	'w211' => 54,
	'w22' => 57,
	'w28' => 57,
	'w290' => 46,
	'w3' => 56,
	'w30' => 59,
	'w32' => 58,
	'w33' => 57,
	'w34' => 58,
	'w36' => 58,
	'w37' => 56,
	'w38' => 57,
	'w39' => 58,
	'w41' => 58,
	'w44' => 56,
	'w45' => 58,
	'w54' => 57,
	'w7' => 57,
);
foreach( @mss ) {
	is( scalar @{$_->words}, $wordcount{$_->sigil}, "Got correct number of words for " . $_->sigil );
}

=end testing

=cut 

sub read_source {
	my( $self, $wordsource, %options ) = @_;
	my @docroots;  # Holds an array of { sigil, source }
	my $format;
	
	if( !ref( $wordsource ) ) {  # Assume it's a filename.
		my $parser = XML::LibXML->new();
		my $doc;
		eval { local $SIG{__WARN__} = sub { 1 }; $doc = $parser->parse_file( $wordsource ); };
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
				# It is a filename, thus plaintext.
				my @lines = <INFILE>;
				close INFILE;
				@docroots = ( { source => join( '', @lines ) } );
			} else {
				my $json;
				eval { $json = decode_json( $wordsource ) };
				if( $json ) {
					# It is a JSON string.
					$format = 'json';
					push( @docroots, map { { source => $_ } } @{$json->{'witnesses'}} );
				} else {
					# Assume plain old string input.
					@docroots = ( { source => $wordsource } );
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
			%options,
			%$doc,
			) );
	}
	return @ms_objects;
}

sub _get_xml_roots {
	my( $xmldoc ) = @_;
	my( @docroots, $format );
	if( $xmldoc->documentElement->nodeName =~ /^tei/i ) {
		# It is TEI format.
		@docroots = ( { source => $xmldoc->documentElement } );
		$format = 'xmldesc';
	} elsif( $xmldoc->documentElement->nodeName =~ /^examples/i ) {
		# It is CollateX simple input format.  Read the text
		# strings and then treat it as plaintext.
		my @collationtexts = $xmldoc->documentElement->getChildrenByTagName( 'example' );
		if( @collationtexts ) {
			# Use the first text example in the file; we do not handle multiple
			# collation runs on different texts.
			my @witnesses = $collationtexts[0]->getChildrenByTagName( 'witness' );
			@docroots = map { { sigil => $_->getAttribute( 'id' ),
								source => $_->textContent } } @witnesses;
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

=begin testing

my $aligner = Text::TEI::Collate->new();
my @mss = $aligner->read_source( 't/data/cx/john18-2.xml' );
$aligner->align( @mss );
my $cols = 74;
foreach( @mss ) {
	is( scalar @{$_->words}, $cols, "Got correct collated columns for " . $_->sigil);
}

#TODO test the actual collation validity sometime

=end testing

=cut

sub align {
	my( $self, @manuscripts ) = @_;

 	if( scalar( @manuscripts ) == 1 ) {
		# That was easy then.
		return @manuscripts;
	}

	# At this point we have an array of arrays.  Each member array
 	# contains a hash object for each word, describing its
 	# characteristics.  These are the uncollated texts, now in the
 	# object form that we will eventually return.

 	# The first file becomes the base, for now.
 	# SOMEDAY: Work parsimony info into the choosing of a base
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
	    
	    # Generate the new base by flattening result2 onto the back of result1,
	    # filling in all the gaps.
	    $base_text = $self->generate_base( $result1, $result2 );
 	}

	# $base_text now holds all the words, linked in one way or another.
	# Make a result array from this.

  	my @result_array = map { [] } @manuscripts;
	my %ridx;
	foreach( 0 .. $#manuscripts ) {
  		$ridx{ $manuscripts[$_]->sigil } = $_;
	}
	foreach my $word ( @$base_text ) {
 		my %unseen;
 		map { $unseen{$_->sigil} = 1 } @manuscripts;
 		my @row_words;
 		push( @row_words, $word, $word->links );
 		foreach ( $word->variants ) {
			push( @row_words, $_, $_->links );
		}
 		foreach my $r ( @row_words ) {
			push( @{$result_array[$ridx{$r->ms_sigil}]}, $r );
			delete $unseen{$r->ms_sigil};
 		}
 		foreach my $s ( keys %unseen ) {
			push( @{$result_array[$ridx{$s}]}, $self->empty_word );
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

# Given two collections of word objects, return two collated collections of
# word objects.  Pass a ref to the whole array so far so that we can consult
# it if necessary.  That array should *not* be written to here below.
sub build_array {
 	my $self = shift;
 	my( $base_text, $text ) = @_;
 	my( @base_result, @new_result );   # All the good things we'll return.
	# Generate our fuzzy-match lookup table.
	$self->make_fuzzy_matches( $base_text, $text );
	# Do the diff.
 	my $diff = Text::TEI::Collate::Diff->new( $base_text, $text, $self );
	while( my $diffpos = $diff->Next ) {
		if( $diff->Same ) {
  			$self->_handle_diff_same( $diff, $base_text, $text, \@base_result, \@new_result );
		} elsif( !scalar( $diff->Range( 1 ) ) ) {  # Addition
 			$self->_handle_diff_interpolation( $diff, 2, $text, \@new_result, \@base_result );
		} elsif( !scalar( $diff->Range( 2 ) ) ) {  # Deletion
			$self->_handle_diff_interpolation( $diff, 1, $base_text, \@base_result, \@new_result );
		} else {  # No fuzzy matching here.
			$self->debug( "Diff: collating words " 
 				. join( '.', map { $_->comparison_form } $diff->Items( 1 ) ) . " / " 
 				. join( '.', map { $_->comparison_form } $diff->Items( 2 ) ), 1 );
	    
			# Grab the word sets from each text.
			my @base_wlist = @{$base_text}[$diff->Range( 1 )];
			my @new_wlist = @{$text}[$diff->Range( 2 )];
			# Does the base have variants against which we can collate the new words?
			# If so, try running against the variants, and collate according to the result.
			my @var_wlist;
 			my %base_idx;
 			map { push( @var_wlist, $_->variants ) } @base_wlist;
			my $matched_variants;
			my( $b, $n );
 			if( scalar @var_wlist ) {
				# Keep track of which base index each variant is at
				foreach my $i ( 0 .. $#base_wlist ) {
					foreach my $v ( $base_wlist[$i]->variants ) {
						$base_idx{$v} = $i;
					}
				}
				# Get the last variant(s) of the previous hunk
				if( @base_result ) {
					unshift( @var_wlist, $base_result[-1]->variants );
					foreach my $v ( $base_result[-1]->variants ) {
						$base_idx{$v} = -1;
					}
				}
				# Get the first variant(s) of the next hunk
				if( $diff->Next && $diff->Items(1) ) {
					my @next = $diff->Items(1);
					push( @var_wlist, $next[0]->variants );
					foreach my $v ( $next[0]->variants ) {
						$base_idx{$v} = scalar @base_wlist;
					}
				}
				# Put the diff back where it was.
				$diff->Reset( $diffpos );
			
				# Collate against the variants
				my @match_sets = $self->_match_variants( \@var_wlist, \@new_wlist, \%base_idx );
				if( @match_sets ) {
					$matched_variants = 1;
					( $b, $n ) = $self->_add_variant_matches( \@match_sets, \@base_wlist, \@new_wlist, \%base_idx );
				}
			}
			unless( $matched_variants ) {
				( $b, $n ) = ( \@base_wlist, \@new_wlist );
				$self->_balance_arrays( $b, $n );
			}
			push( @base_result, @$b );
			push( @new_result, @$n );
		}	
	}

 	return( \@base_result, \@new_result );
}

sub _balance_arrays {
 	my( $self, $base, $new, $nolink ) = @_;
 	my $difflen = @$base - @$new;
 	my $shorter = $difflen > 0 ? $new : $base;
	push( @$shorter, ( $self->empty_word ) x abs( $difflen ) ) if $difflen;
	# Set variant links.
	unless( $nolink ) {
		foreach my $i ( 0 .. $#{$base} ) {
			next if $base->[$i] eq $self->empty_word;
			next if $new->[$i] eq $self->empty_word;
			$base->[$i]->add_variant( $new->[$i] );
		}
	}
	return( $base, $new );
}

=begin testing

use Text::TEI::Collate;

my @test = (
    'the black dog had his day',
    'the white dog had her day',
    'the bright red dog had his day',
    'the bright white cat had her day',
);
my $aligner = Text::TEI::Collate->new();
my @mss = map { $aligner->read_source( $_ ) } @test;
$aligner->align( @mss );
my $base = $aligner->generate_base( @mss );
# Get rid of the specials
pop @$base;
shift @$base;
is( scalar @$base, 8, "Got right number of words" );
is( $base->[0]->word, 'the', "Got correct first word" );
is( scalar $base->[0]->links, 3, "Got 3 links" );
is( scalar $base->[0]->variants, 0, "Got 0 variants" );
is( $base->[1]->word, 'black', "Got correct second word" );
is( scalar $base->[1]->links, 0, "Got 0 links" );
is( scalar $base->[1]->variants, 1, "Got 1 variant" );
is( $base->[1]->get_variant(0)->word, 'bright', "Got correct first variant" );
is( scalar $base->[1]->get_variant(0)->links, 1, "Got a variant link" );
is( $base->[2]->word, 'white', "Got correct second word" );
is( scalar $base->[2]->links, 1, "Got 1 links" );
is( scalar $base->[2]->variants, 0, "Got 0 variants" );
is( $base->[3]->word, 'red', "Got correct third word" );
is( scalar $base->[3]->links, 0, "Got 0 links" );
is( scalar $base->[3]->variants, 1, "Got a variant" );
is( $base->[3]->get_variant(0)->word, 'cat', "Got correct second variant" );
is( scalar $base->[3]->get_variant(0)->links, 0, "Variant has no links" );
is( $base->[4]->word, 'dog', "Got correct fourth word" );
is( scalar $base->[4]->links, 2, "Got 2 links" );
is( scalar $base->[4]->variants, 0, "Got 0 variants" );
is( $base->[5]->word, 'had', "Got correct fifth word" );
is( scalar $base->[5]->links, 3, "Got 3 links" );
is( scalar $base->[5]->variants, 0, "Got 0 variants" );
is( $base->[6]->word, 'his', "Got correct sixth word" );
is( scalar $base->[6]->links, 1, "Got 1 link" );
is( scalar $base->[6]->variants, 1, "Got 1 variant" );
is( scalar $base->[6]->get_variant(0)->links, 1, "Got 1 variant link" );
is( $base->[6]->get_variant(0)->word, 'her', "Got correct third variant");
is( $base->[7]->word, 'day', "Got correct seventh word" );
is( scalar $base->[7]->links, 3, "Got 3 links" );
is( scalar $base->[7]->variants, 0, "Got 0 variants" );

=end testing

=cut

sub _match_variants {
	my( $self, $variants, $new, $base_idx ) = @_;
	my @match_sets;
	my $last_idx_matched = -1;
	my %variant_matched;
	foreach my $n_idx ( 0 .. $#{$new} ) {
		my $n = $new->[$n_idx];
		foreach my $v ( @$variants ) {
			next if $base_idx->{$v} < $last_idx_matched;
			next if exists $variant_matched{$v};
			if( $self->{fuzzy_matches}->{$n->comparison_form}
				eq $self->{fuzzy_matches}->{$v->comparison_form} ) {
				$v->add_link( $n );
				$variant_matched{$v} = 1;
				push( @match_sets, [ $base_idx->{$v}, $n_idx, $v ] );
				$last_idx_matched = $base_idx->{$v};
			}
		}
	}
	return @match_sets;
}

sub _add_variant_matches {
 	my( $self, $match_sets, $base, $new, $base_idx ) = @_;
 	my( $base_wlist, $new_wlist ) = ( [], [] );

 	my( $last_b, $last_n ) = ( 0, 0 );
	my %seen_base_indices;
	foreach my $p ( @$match_sets ) {
		my( $b_idx, $n_idx, $v ) = @$p;
		# Balance the arrays up to the indices we have.
		my( @tb, @tn );
		if( $b_idx > $last_b+1 
 			&& $b_idx < scalar @$base ) {
 			@tb = @{$base}[$last_b .. $b_idx-1];
		}
		if( $n_idx > $last_n+1 ) {
			@tn = @{$new}[$last_n .. $n_idx-1];
		}
		$self->_balance_arrays( \@tb, \@tn );
		push( @$base_wlist, @tb ) if @tb;
		push( @$new_wlist, @tn ) if @tn;

		# If this is the first occurrence of $b_idx, push the pair.
		# If it is not the first occurrence, unlink the variant and
		# then push the pair.
		if( $seen_base_indices{$b_idx} 
 			|| $b_idx == -1
			|| $b_idx == scalar( @$base ) ) {
  			# Unlink variant from base, push as extra.
			$DB::single = 1 unless $v->variant_of;
 			$v->variant_of->unlink_variant( $v );
 			# Push the variant.
			push( @$base_wlist, $v );
		} else {
 			# Just push the base.
 			push( @$base_wlist, $base->[$b_idx] );
		}
		# Either way, push the new.
		push( @$new_wlist, $new->[$n_idx] );
		$seen_base_indices{$b_idx} = 1;

		# Save the index pair we were just working on.
		( $last_b, $last_n ) = ( $b_idx, $n_idx );
    }

	# Now push whatever remains of each array.
	my( @tb, @tn );
	if( scalar @$base > $last_b+1 ) {
		@tb = @{$base}[$last_b+1 .. $#{$base}];
	}
	if( scalar @$new > $last_n+1 ) {
		@tn = @{$new}[$last_n+1 .. $#{$new}];
	}
	$self->_balance_arrays( \@tb, \@tn );
	push( @$base_wlist, @tb ) if @tb;
	push( @$new_wlist, @tn ) if @tn;

	# ...and return the whole.
	return( $base_wlist, $new_wlist );
}

=begin testing

use Test::More::UTF8;
use Text::TEI::Collate;
use Text::TEI::Collate::Word;

my $base_word = Text::TEI::Collate::Word->new( ms_sigil => 'A', string => 'հարիւրից' );
my $variant_word = Text::TEI::Collate::Word->new( ms_sigil => 'A', string => 'զ100ից' );
my $match_word = Text::TEI::Collate::Word->new( ms_sigil => 'A', string => 'զհարիւրից' );
my $new_word = Text::TEI::Collate::Word->new( ms_sigil => 'A', string => '100ից' );
my $different_word = Text::TEI::Collate::Word->new( ms_sigil => 'A', string => 'անգամ' );


my $aligner = Text::TEI::Collate->new();
$base_word->add_variant( $variant_word );
is( $aligner->word_match( $base_word, $match_word), $base_word, "Matched base word" );
is( $aligner->word_match( $base_word, $new_word), $variant_word, "Matched variant word" );
is( $aligner->word_match( $base_word, $different_word), undef, "Did not match irrelevant words" );

my( $ms1 ) = $aligner->read_source( 'Jn bedwange harde swaer Doe riepen si op gode met sinne' );
my( $ms2 ) = $aligner->read_source( 'Jn bedvanghe harde suaer. Doe riepsi vp gode met sinne.' );
$aligner->make_fuzzy_matches( $ms1->words, $ms2->words );
is( scalar keys %{$aligner->{fuzzy_matches}}, 15, "Got correct number of vocabulary words" );
my %unique;
map { $unique{$_} = 1 } values %{$aligner->{fuzzy_matches}};
is( scalar keys %unique, 11, "Got correct number of fuzzy matching words" );

=end testing

=cut

sub make_fuzzy_matches {
	my( $self, $base, $other ) = @_;
	my %frequency;
	map { $frequency{$_->comparison_form}++ } @$base;
	map { $frequency{$_->comparison_form}++ } @$other;
	my $fm = $self->{fuzzy_matches};
	unless( $fm ) {
		$fm = {};
		$self->{fuzzy_matches} = $fm;
	}
	my @all_words = sort { $frequency{$b} <=> $frequency{$a} } keys %frequency;
	while( @all_words ) {
		my $w = shift @all_words;
		# Skip it if we already have a fuzzy match for $w.
		next if exists $fm->{$w};
		# $w matches itself if nothing else.
		$fm->{$w} = $w;
		# What else does $w match?
		foreach my $x ( @all_words ) {
			if( $self->_is_near_word_match( $w, $x ) ) {
				$fm->{$x} = $w;
			}
		}
	}
}

# A key generation function for our Diff module.	Always return the comparison
# string for the base text word; if the non-base word is in $a and it doesn't
# match the base (which is therefore in $b), return its own comparison string.

sub diff_key {
	my( $self, $word ) = @_;
	return $self->{fuzzy_matches}->{$word->comparison_form};
}

sub word_match {
	# A and B are word objects.  We want to match if b matches a, 
	# but also if b matches a variant of a.
	my( $self, $a, $b ) = @_;
	if( $self->_is_near_word_match( $a->comparison_form, $b->comparison_form ) ) {
		return $a;
	}
	foreach my $v ( $a->variants ) {
		if( $self->_is_near_word_match( $v->comparison_form, $b->comparison_form ) ) {
			return $v;
		}
	}
	return undef;
}

=begin testing

use Test::More::UTF8;
use Text::TEI::Collate;

my $aligner = Text::TEI::Collate->new();
ok( $aligner->_is_near_word_match( 'Արդ', 'Արդ' ), "matched exact string" );
ok( $aligner->_is_near_word_match( 'հաւասն', 'զհաւասն' ), "matched near-exact string" );
ok( !$aligner->_is_near_word_match( 'հարիւրից', 'զ100ից' ), "did not match differing string" );
ok( !$aligner->_is_near_word_match( 'ժամանակական', 'զշարագրական' ), "did not match differing string 2" );
ok( $aligner->_is_near_word_match( 'ընթերցողք', 'ընթերցողսն' ), "matched near-exact string 2" );
ok( $aligner->_is_near_word_match( 'պատմագրացն', 'պատգամագրացն' ), "matched pretty close string" );

=end testing

=cut

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

  	# Now see if the distance is low enough to be a match.
	if( defined( $self->{'fuzziness_sub'} ) ) {
		return &{$self->{'fuzziness_sub'}}( $word1, $word2, $dist );
	} else {
		my $ref_str = length( $word1 ) < length( $word2 ) ? $word1 : $word2;
		my $fuzz = length( $ref_str ) > $self->{fuzziness}->{short}
			? $self->{fuzziness}->{val} : $self->{fuzziness}->{shortval};
		return( $dist <= ( length( $ref_str ) * $fuzz / 100 ) );
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
 	my $msg_words = join( ' ', _stripped_words( \@base_wlist ) );
	$msg_words .= ' / ' . join( ' ', _stripped_words( \@new_wlist ) );
 	$self->debug( "Diff: pushing matched words $msg_words", 2 );
	foreach my $i ( 0 .. $#base_wlist ) {
		# Link the word to its match.  This means having to compare
		# the words again, grr argh.
		my $matched = $self->word_match( $base_wlist[$i], $new_wlist[$i] );
		$matched->add_link( $new_wlist[$i] );
	}
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

	my @word_arrays;
	foreach( @texts ) {
		push( @word_arrays, 
			ref( $_ ) eq 'Text::TEI::Collate::Manuscript' ? $_->words : $_ );
	}
	
    # Error checking: are they all the same length?
    my $width = scalar @word_arrays;
    my $length = 0;
    foreach my $t ( @word_arrays ) {
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
	    if( $word_arrays[$col]->[$idx]->comparison_form ne '' ) {
		$word = $word_arrays[$col]->[$idx];
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

# Helper function for begin_end_mark
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

# Helper function for begin_end_mark, to create a mark
		
sub _special {
    my( $mark, $sigil ) = @_;
    return Text::TEI::Collate::Word->new( special => $mark, 
					  ms_sigil => $sigil );
}

=head1 OUTPUT METHODS

=head2 to_json

Takes a list of aligned manuscripts and returns a data structure suitable for 
JSON encoding; documented at L<http://gregor.middell.net/collatex/api/collate>

=begin testing

my $aligner = Text::TEI::Collate->new();
my @mss = $aligner->read_source( 't/data/cx/john18-2.xml' );
$aligner->align( @mss );
my $jsondata = $aligner->to_json( @mss );
ok( exists $jsondata->{alignment}, "to_json: Got alignment data structure back");
my @wits = @{$jsondata->{alignment}};
is( scalar @wits, 28, "to_json: Got correct number of witnesses back");
my $columns = 74;
foreach ( @wits ) {
	is( scalar @{$_->{tokens}}, $columns, "to_json: Got correct number of words back for witness")
}

=end testing

=cut

sub to_json {
	my( $self, @mss ) = @_;
	my $result = { 'alignment' => [] };
	foreach my $ms ( @mss ) {
		push( @{$result->{'alignment'}},
			  { 'witness' => $ms->sigil,
				'tokens' => $ms->tokenize_as_json()->{'tokens'}, } );
	}
	return $result;
}

=head2 to_tei

Takes a list of aligned Manuscript objects and returns a fairly simple TEI 
XML document in parallel segmentation format, with the words lexically marked 
as such.  At the moment returns a single paragraph, with the original div and
paragraph breaks for each witness marked as a <witDetail/> in the apparatus.

=begin testing

use lib 't/lib';
use Text::TEI::Collate;
use Text::WagnerFischer::Armenian;
use Words::Armenian;
use XML::LibXML::XPathContext;
# Get an alignment to test with
my $testdir = "t/data/xml_plain";
opendir( XF, $testdir ) or die "Could not open $testdir";
my @files = readdir XF;
my @mss;
my $aligner = Text::TEI::Collate->new(
	'fuzziness' => '50',
	'distance_sub' => \&Text::WagnerFischer::Armenian::distance,
	);
foreach ( sort @files ) {
	next if /^\./;
	push( @mss, $aligner->read_source( "$testdir/$_",
		'canonizer' => \&Words::Armenian::canonize_word
		) );
}
$aligner->align( @mss );

my $doc = $aligner->to_tei( @mss );
is( ref( $doc ), 'XML::LibXML::Document', "Made TEI document header" );
my $xpc = XML::LibXML::XPathContext->new( $doc->documentElement );
$xpc->registerNs( 'tei', $doc->documentElement->namespaceURI );

# Test the creation of a document header from TEI files
my @witdesc = $xpc->findnodes( '//tei:witness/tei:msDesc' );
is( scalar @witdesc, 5, "Found five msdesc nodes");

# Test the creation of apparatus entries
my @apps = $xpc->findnodes( '//tei:app' );
is( scalar @apps, 111, "Got the correct number of app entries");
my @words_not_in_app = $xpc->findnodes( '//tei:body/tei:div/tei:p/tei:w' );
is( scalar @words_not_in_app, 171, "Got the correct number of matching words");
my @details = $xpc->findnodes( '//tei:witDetail' );
my @detailwits;
foreach ( @details ) {
	my $witstr = $_->getAttribute( 'wit' );
	push( @detailwits, split( /\s+/, $witstr ));
}
is( scalar @detailwits, 13, "Found the right number of witness-detail wits");

# TODO test the reconstruction of witnesses from the parallel-seg.

=end testing

=cut

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
			_make_tei_app( $initial_base->[$idx], %seen );
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
			if( $m->has_msdesc ) {
				my $local_msdesc = $m->msdesc->cloneNode( 1 );
				$local_msdesc->removeAttribute( 'xml:id' );
				$wit->appendChild( $local_msdesc );
			} else {
				$wit->appendText( $m->identifier );
			}
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
		my @all_words = ( $word_obj, $word_obj->links, $word_obj->variants );
		foreach( $word_obj->variants ) {
			push( @all_words, $_->links );
		}
		# Do we have the exact same word across all manuscripts with no pesky
		# placeholders?  And which manuscripts have words?
		my $variation = 0;
		foreach( @all_words ) {
			$variation = 1 if $_->original_form ne $word_obj->original_form;
			# We need an <app/> tag if there is a placeholder to record too.
			$variation = 1 if $_->placeholders;
			$seen{$_->ms_sigil} = 1 if $_->ms_sigil;
		}
		# If we do have variation, we create an <app/> element to describe 
		# it.  If we don't, we create a <w/> element to hold the common word.
		if( $variation ) {
			my $app_el = $body->addNewChild( $ns_uri, 'app');
			$app_el->setAttribute( 'xml:id', 'app'.$app_id_ctr++ );
			# We want only one reading per unique original_form.
			my %forms;
			foreach my $rdg ( @all_words ) {
				my $rdgkey = $rdg->original_form;
				next unless $rdgkey;
				push( @{$forms{$rdgkey}}, $rdg );
			}
			# Now for each form, go through and get the reading witnesses and
			# placeholders.
			foreach my $form ( keys %forms ) {
				my $rdg_el = $app_el->addNewChild( $ns_uri, 'rdg' );
				# Set the witness string.
				my $wit_str = join( ' ', map { '#'.$_->ms_sigil } @{$forms{$form}});
				$rdg_el->setAttribute( 'wit', $wit_str );
				# Set the word element within the reading.
				my $w_el = $rdg_el->addNewChild( $ns_uri, 'w' );
				$w_el->setAttribute( 'xml:id', 'w'.$word_id_ctr++ );
				# Arbitrarily use the first reading of this form to get the punctuation.
				_wrap_punct( $w_el, $forms{$form}->[0] );
				# Add the placeholder information as <witDetail/> elements.
				my $witDetails;
				foreach my $rdg ( @{$forms{$form}} ) {
					foreach my $pl ( $rdg->placeholders ) {
						push( @{$witDetails->{'#'.$w_el->getAttribute( 'xml:id' )}->{$pl}}, '#'.$rdg->ms_sigil );
					}
				}
				foreach my $wd ( keys %$witDetails ) {
					foreach my $type ( keys %{$witDetails->{$wd}} ) {
						my $wd_el = $app_el->addNewChild( $ns_uri, 'witDetail' );
						$wd_el->setAttribute( 'target', $wd );
						$wd_el->setAttribute( 'wit', join( ' ', @{$witDetails->{$wd}->{$type}}) );
						$wd_el->appendText( $type );
					}
				}
			}
			my @empty = grep { $seen{$_} == 0 } keys( %seen );
			if( @empty ) {
				my $rdg_el = $app_el->addNewChild( $ns_uri, 'rdg' );
				my $wit_str = join( ' ', map { '#'.$_ } @empty );
				$rdg_el->setAttribute( 'wit', $wit_str );
			}
		} else {
			# No variation across manuscripts, just make a <w/> and use the initial
			# $word_obj to represent all mss.
			my $w_el = $body->addNewChild( $ns_uri, 'w');
			$w_el->setAttribute( 'xml:id', 'w'.$word_id_ctr++ );
			_wrap_punct( $w_el, $word_obj );
		}
	}
	
	sub _wrap_punct {
		my( $w_el, $word_obj ) = @_;
		my $str = $word_obj->original_form;
		my @punct = $word_obj->punctuation;
		my $last_pos = -1;
		foreach my $p ( @punct ) {
			my @letters = split( '', $str );
			if( $p->{char} eq $letters[$p->{pos}] ) {
				my @wordpart = @letters[$last_pos+1..$p->{pos}-1];
				$w_el->appendText( join( '', @wordpart ) );
				my $char = $w_el->addNewChild( $ns_uri, 'c');
				$char->setAttribute( "type", "punct" );
				$char->appendText( $p->{char} );
				$last_pos = $p->{pos};
			} else {
				warn "Punctuation mismatch: " . join( '/', $p->{char}, 
					$p->{pos} ) . " on " . $str;
			}
		}
		# Now append what is left of the word after the last punctuation.
		if( $last_pos < length( $str ) - 1 ) {
			my @letters = split( '', $str );
			my @wordpart = @letters[$last_pos+1..$#letters];
			$w_el->appendText( join( '', @wordpart ) );
		}
		return $w_el;
	}

}

=head2 to_graphml

Takes a list of aligned manuscript objects and returns a GraphML document that
represents the collation as a variant graph. Words in the same location with
the same canonized form are treated as the same node.

=cut

sub to_graphml {
	my( $self, @manuscripts ) = @_;
	my $graph = $self->to_graph( @manuscripts );
	
	# Make the XML doc
	my $GMLNS = 'http://graphml.graphdrawing.org/xmlns';
	my $graphml = XML::LibXML::Document->new('1.0', 'UTF-8');
	my $root = $graphml->createElementNS( $GMLNS, 'graphml' );
	$root->setNamespace( 'http://www.w3.org/2001/XMLSchema-instance', 'xsi', 0 );
	$root->setAttribute( 'xsi:schemaLocation', 'http://graphml.graphdrawing.org/xmlns http://graphml.graphdrawing.org/xmlns/1.0/graphml.xsd');
	
	# Make the interminable graph header
	my $graph_el = $root->addNewChild( $GMLNS, 'graph' );
	$graph_el->setAttribute( 'id', 'G' );
	$graph_el->setAttribute( 'edgedefault', 'directed' );
	my $nkey = $graph_el->addNewChild( $GMLNS, 'key' );
	$nkey->setAttribute( 'attr.name', 'number' );
	$nkey->setAttribute( 'attr.type', 'string' );
	$nkey->setAttribute( 'for', 'node' );
	$nkey->setAttribute( 'id', 'd0' );
	my $tkey = $graph_el->addNewChild( $GMLNS, 'key' );
	$tkey->setAttribute( 'attr.name', 'token' );
	$tkey->setAttribute( 'attr.type', 'string' );
	$tkey->setAttribute( 'for', 'node' );
	$tkey->setAttribute( 'id', 'd1' );
	my $ms_ctr = 0;
	my %ms_key;
	foreach my $ms ( @manuscripts ) {
		my $wkey = $graph_el->addNewChild( $GMLNS, 'key' );
		$wkey->setAttribute( 'attr.name', $ms->sigil );
		$wkey->setAttribute( 'attr.type', 'string' );
		$wkey->setAttribute( 'for', 'edge' );
		$wkey->setAttribute( 'id', 'w'.$ms_ctr++ );
		$ms_key{$ms->sigil} = $wkey->getAttribute( 'id' );
	}
	
	# Whew.  Now add all the nodes
	foreach my $n ( $graph->nodes ) {
		my $node_el = $graph_el->addNewChild( $GMLNS, 'node' );
		$node_el->setAttribute( 'id', $n->name );
		my $id_el = $node_el->addNewChild( $GMLNS, 'data' );
		$id_el->setAttribute( 'key', 'd0' );
		$id_el->appendText( $n->name );
		my $token_el = $node_el->addNewChild( $GMLNS, 'data' );
		$token_el->setAttribute( 'key', 'd1' );
		$token_el->appendText( $n->label );
	}
	
	# Finally, add the edges.
	my $edge_ctr = 0;
	foreach my $n ( $graph->nodes ) {
		foreach my $succ ( $n->successors() ) {
			my $edge_el = $graph_el->addNewChild( $GMLNS, 'edge' );
			$edge_el->setAttribute( 'id', 'e'.$edge_ctr++ );
			$edge_el->setAttribute( 'source', $n->name );
			$edge_el->setAttribute( 'target', $succ->name );
			foreach my $edge ( $n->edges_to( $succ ) ) {
				# The edge label is the sigil.  Add a data key for that sigil.
				my $sig = $edge->name;
				my $sig_el = $edge_el->addNewChild( $GMLNS, 'data' );
				$sig_el->setAttribute( 'key', $ms_key{$sig} );
				$sig_el->appendText( $sig );
			}
		}
	}
	$graphml->setDocumentElement( $root );
	return $graphml;
}

=head2 to_svg

Takes a list of aligned manuscript objects and returns an SVG representation
of the variant graph, as described for the to_graphml method.

=cut

sub to_svg {
	my( $self, @mss ) = @_;
        my $graph = $self->to_graph( @mss );
        $graph->set_attribute( 'node', 'shape', 'ellipse' );
        _combine_edges( $graph );
	my $dot = File::Temp->new();
	binmode( $dot, ':utf8' );
        print $dot $graph->as_graphviz();
	close $dot;
        my @cmd = qw/dot -Tsvg/;
	push( @cmd, $dot->filename );
	my( $svg, $err );
	run( \@cmd, ">", binary(), \$svg, '2>', \$err );
	warn $err if $err;
	return $svg;    
}

sub _combine_edges {
	my $graph = shift;
	foreach my $n ( $graph->nodes ) {
		foreach my $s ( $n->successors ) {
			my @edges = $n->edges_to( $s );
			my $new_edge = join( ', ', sort( map { $_->name } @edges ) );
			map { $graph->del_edge( $_ ) } @edges;
			$graph->add_edge( $n, $s, $new_edge );
		}
	}
}

=head2 to_graph

Base method for graph-based output - create the (Graph::Easy) graph that will
be used to generate graphml or svg.

=begin testing

use lib 't/lib';
use Text::TEI::Collate;
use Text::WagnerFischer::Armenian;
use Words::Armenian;
use XML::LibXML::XPathContext;

eval 'require Graph::Easy;';
unless( $@ ) {
# Get an alignment to test with
my $testdir = "t/data/xml_plain";
opendir( XF, $testdir ) or die "Could not open $testdir";
my @files = readdir XF;
my @mss;
my $aligner = Text::TEI::Collate->new(
	'fuzziness' => '50',
	'distance_sub' => \&Text::WagnerFischer::Armenian::distance,
	);
foreach ( sort @files ) {
	next if /^\./;
	push( @mss, $aligner->read_source( "$testdir/$_",
		'canonizer' => \&Words::Armenian::canonize_word
		) );
}
$aligner->align( @mss );

my $graph = $aligner->to_graph( @mss );

is( ref( $graph ), 'Graph::Easy', "Got a graph object from to_graph" );
is( scalar( $graph->nodes ), 381, "Got the right number of nodes" );
is( scalar( $graph->edges ), 992, "Got the right number of edges" );
}

=end testing

=cut

sub to_graph {
	my( $self, @manuscripts ) = @_;
	eval 'require Graph::Easy;';
	if( $@ ) {
		warn "Graph generation requires module Graph::Easy";
		return;
	}
	my $graph = Graph::Easy->new();
	# All manuscripts run from START to END.
	my $start_node = $graph->add_node( 'n0' );
	$start_node->set_attribute( 'label', '#START#');
	my $end_node = $graph->add_node( 'n1' );
	$end_node->set_attribute( 'label', '#END#');
	my $textlen = $#{$manuscripts[0]->words};
	my $paths = {};  # A list of nodes per manuscript sigil.
	my $node_counter = 2;  # We've used n0 and n1 already
	foreach my $idx ( 0..$textlen ) {
		my $unique_words;
		my @location_words = map { $_->words->[$idx] } @manuscripts;
		foreach my $w ( @location_words ) {
			if( $w->special && $w->special eq 'BEGIN' ) {
				$paths->{$w->ms_sigil} = [ $start_node ];
			} elsif( $w->special && $w->special eq 'END' ) {
				push( @{$paths->{$w->ms_sigil}}, $end_node );
			} elsif( !$w->is_empty && !$w->special ) {
				push( @{$unique_words->{$w->canonical_form}}, $w->ms_sigil )
			}
		}
		foreach my $w ( keys %$unique_words ) {
			# Make the node.
			my $n = $graph->add_node( 'n'.$node_counter++ );
			$n->set_attribute( 'label', $w );
			foreach my $sig ( @{$unique_words->{$w}} ) {
				push( @{$paths->{$sig}}, $n );
			}
		}
	}
	# Have the nodes, now make the edges.
	foreach my $sig ( keys %$paths ) {
		my $from = shift @{$paths->{$sig}};
		foreach my $to ( @{$paths->{$sig}} ) {
			$graph->add_edge( $from, $to, $sig );
			$from = $to;
		}
	}
	return $graph;
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


=head1 AUTHOR

Tara L Andrews E<lt>aurum@cpan.orgE<gt>
