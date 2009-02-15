#!/usr/bin/perl -w -CDS

use strict;
use utf8;
use lib 'lib';
use Date::Format;
use Getopt::Long;
use XML::LibXML;
use Words::Armenian qw( am_downcase );

eval { no warnings; binmode $DB::OUT, ":utf8"; };

my( $infile, $outfile, $lang_module, $include_orthography, $include_spelling );

GetOptions( 
    'i|infile=s' => \$infile,
    'o|outfile=s' => \$outfile,
    'orth' => \$include_orthography,
    'spell' => \$include_spelling,
    );

if( scalar( @ARGV ) == 1 && !$infile ) {
    $infile = shift @ARGV;
} elsif( @ARGV ) {
    warn "Extraneous arguments '@ARGV'";
}
unless( defined( $infile ) && defined( $outfile ) ) {
    print STDERR "Need to define input and output files\n";
    exit;
}
$include_spelling = 1 if $include_orthography;
# TODO pull this entirely from XML.
my %orth = %Words::Armenian::ORTHOGRAPHY;
my %spell = %Words::Armenian::SPELLINGS;

## Extra orthography entries.
$orth{'Եւ'} = 'և';
$orth{'և'} = 'Եւ';
$orth{'եւ'} = 'Եւ';
$orth{'եւ'} = 'և';
$orth{'և'} = 'եւ';

my $parser = XML::LibXML->new();
my $input_doc = $parser->parse_file( $infile );
my $ns_uri = 'http://www.tei-c.org/ns/1.0';
my $xpc = XML::LibXML::XPathContext->new( $input_doc );
$xpc->registerNs( 'tei', $ns_uri );

# This is where the action happens.
open( OUT, ">$outfile" ) or die "Could not open $outfile for writing: $@";
binmode( OUT, ':utf8' );
write_header();
latex_conv();
# print OUT "\\end{document}\n";
print STDERR "Done.\n";

sub write_header {

    # Get the title.
    my $title = $xpc->findvalue( '//tei:titleStmt/tei:title[text()]' );
    my $date = time2str( "%e %b %Y", time() );

    while( <DATA> ) {  # Read in the header from below.
	s/__TITLE__/$title/;
	s/__DATE__/$date/;
	if( /__WITNESSLIST__/ ) {
	    
	    my @wit_list = $xpc->findnodes( '//tei:listWit/tei:witness' );
	    if( @wit_list ) {
		print OUT "\\begin\{tabular\}\{ll\}\n";
		foreach my $witness ( sort { $a->getAttribute( 'xml:id' )
						 cmp
						$b->getAttribute( 'xml:id' ) }
				      @wit_list ) {
		    # Hack for our not-really manuscripts.
		    my $sigil = $witness->getAttribute( 'xml:id' );
		    my $qualifier = $sigil =~ /^[CGE]$/ 
			? ' (as found in 1898 Vałaršapat edition)' : '';
		    print OUT $sigil . ' & ' . $witness->textContent() 
			. $qualifier . "\\\\\n";
		}
		print OUT "\\end\{tabular\}\n";
	    } else {
		warn "No witnesses found in header!!";
	    }
	} else {
	    print OUT $_;
	}
    }
}

sub latex_conv {
    # First get the divs and the paragraphs
    my $div_counter = 0;
    foreach my $section ( $xpc->findnodes( '//tei:div' ) ) {
	$div_counter++;
	print OUT "\\pagebreak\n" unless $div_counter == 1;
	print OUT "\\subsection\{Section $div_counter\}\n\n";
	print OUT "\\beginnumbering\n";

	# Then the paragraphs.
	foreach my $pg ( $xpc->findnodes( './/tei:p', $section ) ) {
	    my @words_out;
	    my %last_word;
	    my %need_anchor;

	    # Before we do anything, build a list of omissions for
	    # this paragraph.  Usual plethora of hashes for
	    # re-jiggering into a better lookup form.
	    my %omissions_for_wit;
	    my %omission_start;
	    my %hold;
	    my $last_app = '';
	    foreach my $rdg ( $xpc->findnodes( './/tei:rdg[@type=\'omission\']', $pg ) ) {
		my @wits = split( /\s+/, $rdg->getAttribute( 'wit' ) );
		my $app = $rdg->parentNode;
		my ( $prev_app ) = $xpc->findnodes( 'preceding-sibling::tei:app[position() = 1]', $app );
		unless( $prev_app &&
			$last_app eq $prev_app->getAttribute( 'xml:id' ) ) {
		    # Mark that this is an omission, but it isn't a
		    # continuing omission yet, so don't do anything.
		    $last_app = $app->getAttribute( 'xml:id' );
		    next;
		}
		my $this_app = $app->getAttribute( 'xml:id' );
		foreach my $wit ( @wits ) {
		    if( exists $hold{$wit} ) {
			$hold{$wit}->{'end'} = $this_app;
		    } else {
			$hold{$wit} = { 'start' => $last_app,
					'end' => $this_app };
		    }
		}
		# Now go through the hold hash and close out any apps
		# that don't have an ending of 'now'.  And get rid of
		# any apps that have the same start and end.
		foreach my $wit ( keys %hold ) {
		    unless( $hold{$wit}->{'end'} eq $last_app ) {
			my $om = delete $hold{$wit};
			# This line shouldn't be necessary anymore
			next if( $om->{'start'} eq $om->{'end'} );
			_add_hash_entry( \%omissions_for_wit, $wit, $om );
		    }
		}
		$last_app = $this_app;
	    }	    
	    # One more time to close out the last app entry.
	    foreach my $wit ( keys %hold ) {
		my $om = delete $hold{$wit};
		# This line shouldn't be necessary anymore
		next if( $om->{'start'} eq $om->{'end'} );
		_add_hash_entry( \%omissions_for_wit, $wit, $om );
	    }
	    # Now re-sort the hash by start ID.
	    foreach my $wit ( keys %omissions_for_wit ) {
		foreach my $om ( @{$omissions_for_wit{$wit}} ) {
		    my $new_om = { 'wit' => $wit, 'end' => $om->{'end'} };
		    _add_hash_entry( \%omission_start, $om->{'start'}, 
				     $new_om );
		}
	    }


	    # Now that we have our multi-word omissions, look at each word
	    # of the apparatus in turn.  Keep track of mss that are in
	    # the middle of a multi-word omission.
	    my %currently_omitted;
	    foreach my $app ( $xpc->findnodes( './/tei:app', $pg ) ) {
		my $app_id = $app->getAttribute( 'xml:id' ) || '';
		#print STDERR "Looking at $app_id\n";
		my $lemma = $xpc->find( './/tei:lem', $app );
		my $false_lemma = 0;
		my $rdg_xpath = './/tei:rdg';
		my @readings = $xpc->findnodes( $rdg_xpath, $app );
		if( $lemma ) {
		    $lemma = $lemma->get_node( 1 );
		} else {
		    # Follow A for now.  Ignore other readings.
		    foreach( @readings ) {
			if( $_->getAttribute( 'wit' ) =~ /\#A/ ) {
			    $lemma = $_;
			}
		    }
		    $false_lemma = 1;
		    # Don't show variants, as we haven't really selected
		    # a lemma.
		    @readings = ();
		}

		unless( $lemma ) {
		    warn "No lemma and no A reading for app $app_id";
		    next;
		}
		
		my $lem_txt = extract_text( $lemma, 1, $false_lemma );
		my $lem_wit = witness_string( $lemma->getAttribute( 'wit' ) );
		# For dictionary comparison
		my $lem_str = $lem_txt;
		$lem_str =~ s/\\arm\{(.*)\}/$1/;
		$lem_str =~ s/[[:punct:]]//g;
		$lem_str = am_downcase( $lem_str );

		# Look for omissions that begin here.
		unless( $false_lemma ) {
		    foreach my $o ( @{$omission_start{$app_id}} ) {
			$currently_omitted{$o->{'wit'}} = $o->{'end'};
		    }
		}

		# Get any readings.
		my @rdg_out;
		foreach my $r( @readings ) {
		    my @witnesses = split( /\s+/, $r->getAttribute( 'wit' ) );
		    my( $txt ) = extract_text( $r );

		    # Is this reading part of a multi-word omission?
		    my @relevant_wit;
		    foreach my $w ( @witnesses ) {
			unless( $currently_omitted{$w} ) {
			    push( @relevant_wit, $w );
			}
		    }
		    next unless @relevant_wit;
		    
		    my $rdg_str = $txt;
		    $rdg_str =~ s/\\arm\{(.*)\}/$1/;
		    $rdg_str =~ s/[[:punct:]]//g;
		    $rdg_str = am_downcase( $rdg_str );

		    my $type = $r->getAttribute( 'type' ) || '';
		    unless( $include_orthography ) {
			next if $type eq 'orth_variant';
			next if $rdg_str eq $lem_str;
			next if ( exists $orth{$rdg_str}
				  && $orth{$rdg_str} eq $lem_str );
		    }
		    unless( $include_spelling ) {
			next if $type eq 'spelling_variant';
			next if ( exists $spell{$rdg_str} 
				  && $spell{$rdg_str} eq $lem_str );
		    }
		    
		    my $wits = witness_string( \@relevant_wit );
		    push( @rdg_out, { 'txt' => $txt, 'wit' => $wits } );
		}

		# Get any editorial notes.
		# Get all the notes within this apparatus.
		my @all_notes = $xpc->findnodes( './/tei:note', $app );
		my @notes;
		foreach my $n ( @all_notes ) {
		    # Assume only one note per apparatus for now.
		    warn "More than one note for app $app_id" if @notes;
		    my $note_type = $n->getAttribute( 'type' ) || '';
		    if( $note_type eq 'emend_spelling' ) {
			next unless $include_spelling;
		    }
		    if( $note_type eq 'emend_orth' ) {
			next unless $include_orthography;
		    }
		    push( @notes, $n );
		}

		# Get any multi-word omissions that start here.
		my $curr_omission;
		if( exists $omission_start{$app_id} ) {
		    $curr_omission = construct_omissions( $app, 
						  $omission_start{$app_id} );
		}
		# ...and unmark any omissions that end here.
		foreach my $sig ( keys %currently_omitted ) {
		    delete $currently_omitted{$sig} if
			$currently_omitted{$sig} eq $app_id;
		}

		# Now construct the LaTeX expression.
		# Do we have a lemma to hang it all on?
		if( $lem_txt ) {
		    # TODO Check for orphaned footnotes
		    my( $lem_rdg, $lem_note ) = ( \@rdg_out, \@notes );
		    %last_word = ( 'lemma' => $lem_txt,
				   'readings' => $lem_rdg,
				   'notes' => $lem_note );
		    if( keys %need_anchor ) {
			rehome_orphans( \%last_word, 
					\%need_anchor );
		    }

		    # Do we have any omissions to add to the apparatus?
		    if( keys %$curr_omission ) {
			$last_word{ 'omissions' } = $curr_omission;
		    }
		    my $latex_app = latex_for_lemma( %last_word );
		    push( @words_out, $latex_app );
		    %need_anchor = ();
		} else {
		    # We have no lemma.  If there is a previous lemma
		    # available, hang the reading on that.  Otherwise
		    # store it to hang on the next word.
		    if( exists $last_word{'lemma'} ) {
			# Doing it this way b/c data structure consistency
			# problems otherwise.
			my %orphans;
			_add_hash_entry( \%orphans, 'rdg', \@rdg_out );
			_add_hash_entry( \%orphans, 'notes', \@notes );

			rehome_orphans( \%last_word, \%orphans );
			pop( @words_out );
			push( @words_out, latex_for_lemma( %last_word ) );
		    } else {
			_add_hash_entry( \%need_anchor, 'rdg', \@rdg_out );
			_add_hash_entry( \%need_anchor, 'notes', \@notes );
		    }
		}

	    } # foreach app

	    print OUT "\n\\pstart\n";
	    print OUT join( ' ', @words_out );
	    print OUT "\n\\pend\n";
	}  # foreach paragraph
	print OUT "\\endnumbering\n";
    } # foreach div

}

sub witness_string {
    my $attr_string = shift;
    return '' unless $attr_string;
    my @input;
    if( ref( $attr_string ) eq 'ARRAY' ) {
	@input = @$attr_string;
    } else {
	@input = split( /\s+/, $attr_string );
    }
    my @output;
    foreach( sort @input ) {
	s/^\#//;
	push( @output, $_ );
    }
    return join( ' ', @output );
}

sub latex_for_lemma {
    my( %lemma ) = @_;
    my $latex_app;
    my $app_footnote = join( '; ', map { $_->{wit} . " " . $_->{txt} } 
			     @{$lemma{'readings'}} );
    my $ed_footnote .= join( ' // ', map { $_->textContent } 
			     @{$lemma{'notes'}} );
    my @omission_footnotes;
    foreach my $olem ( keys %{$lemma{'omissions'}} ) {
	push( @omission_footnotes, 
	      sprintf( '{\\lemma{\\arm{%s}} \\Afootnote{%s \\emph{om.}}}', 
		       $olem, $lemma{'omissions'}->{$olem} ) );
    }
    
    if( $app_footnote || $ed_footnote ) {
	my $latex_fn = '';
	if( $app_footnote ) {
	    $latex_fn .= "\\Afootnote\{$app_footnote\}";
	}
	if( $ed_footnote ) {
	    $latex_fn .= "\\Bfootnote\{$ed_footnote\}";
	}
	if( @omission_footnotes ) {
	    $latex_fn .= join( ' ', @omission_footnotes );
	}
	$latex_app =  sprintf( '\\edtext{%s}{%s}', 
			       $lemma{'lemma'}, $latex_fn );
    } else {
	$latex_app = $lemma{'lemma'};
    }
}

# Find the lemmas necessary to represent multi-word omissions.
sub construct_omissions {
    my( $app, $omissions ) = @_;
    my $om_lemma_wit = {};
    my( $first_follow, $second_follow ) = 
	$xpc->findnodes( 'following-sibling::tei:app[position() <= 2]', $app );
    foreach my $o ( @$omissions ) {
	my @words = ( word_string( $xpc->findnodes( './/tei:lem', $app ) ),
		      word_string( $xpc->findnodes( './/tei:lem', 
						    $first_follow ) ) );
	if( $second_follow &&
	    $o->{'end'} eq $second_follow->getAttribute( 'xml:id' ) ) {
	    push( @words, word_string( $xpc->findnodes( './/tei:lem', 
							$second_follow ) ) );
	} elsif( $o->{'end'} ne $first_follow->getAttribute( 'xml:id' ) ) {
	    my $end_path = '//tei:app[@xml:id="' . $o->{'end'} . '"]/tei:lem';
	    push( @words, '...', word_string( $xpc->findnodes( $end_path ) ) );
	}
	# HACK for debug
	# unshift( @words, $app->getAttribute( 'xml:id' ) );

	# Now flatten out the words into a lemma and add its witness to
	# our list.
	_add_hash_entry( $om_lemma_wit, join( ' ', @words ), $o->{'wit'} );
    }
    foreach my $lem ( keys %$om_lemma_wit ) {
	# Fix the witness string.
	$om_lemma_wit->{$lem} = witness_string( $om_lemma_wit->{$lem} );
    }
    return $om_lemma_wit;
}
	
sub word_string {
    my( $rdg ) = @_;
    unless( $rdg ) {
	warn "No reading passed to word_string!  You don't want that.";
	return '';
    }
    my @words = map { $_->textContent } $xpc->findnodes( './/tei:w', $rdg );
    return join( ' ', @words );
}
	

# Add the contents of $orph_* to the reading & note arrays.
sub rehome_orphans {
    my( $current, $orphans ) = @_;
    
    # Notes are easy.  Do them first.
    foreach ( @{$orphans->{'notes'}} ) {
	push( @{$current->{'notes'}}, @$_ );
    }
    
    # Readings are hard.  We have to break them down and
    # join them back up.
    my $lemma_txt = $current->{'lemma'};
    my $witness_rdg = {};
    foreach my $rdg ( @{$current->{'readings'}} ) {
	my @wits = split( /\s+/, $rdg->{'wit'} );
	foreach( @wits ) {
	    _add_hash_entry( $witness_rdg, $_, $rdg->{'txt'} );
	}
    }
    # ...and any sigil not now in $witness_rdg should use the lemma text.

    # Now for each set of orphaned readings...
    foreach my $group( @{$orphans->{'rdg'}} ) {
	# ...for each reading within the set...
	foreach my $rdg( @$group ) {
	    # ...add the word to the string associated with its witness(es).
	    my @wits = split( /\s+/, $rdg->{'wit'} );
	    foreach my $wit ( @wits ) {
		unless( exists( $witness_rdg->{$wit} ) ) {
		    _add_hash_entry( $witness_rdg, $wit, $lemma_txt );
		}
		_add_hash_entry( $witness_rdg, $wit, $rdg->{'txt'} );
	    }
	}
    }

    # Now we have the word lists; join them into strings.
    foreach my $wit( keys %$witness_rdg ) {
	# Join up the strngs.
	my $reading_str = join( ' ', @{$witness_rdg->{$wit}} );
	$witness_rdg->{$wit} = $reading_str;
    }

    my %joined_rdgs = invert_hash( $witness_rdg );
    my @readings;
    foreach my $rdg_txt ( keys %joined_rdgs ) {
	push( @readings, { 'txt' => $rdg_txt,
			   'wit' => join( ' ', @{$joined_rdgs{$rdg_txt}}) } );
    }
    $current->{'readings'} = \@readings;
}
    

sub extract_text {
    my ( $rdg, $is_lemma, $false_lemma ) = @_;

    my $out_str = '';
    if( $rdg->hasAttribute( 'type' ) 
	&& $rdg->getAttribute( 'type' ) eq 'omission'
	&& !$is_lemma ) {
	$out_str = '\emph{om.}';
    } elsif( !$rdg->textContent() && !$is_lemma ) {
	warn "Empty reading not marked as omission";
	$out_str = '\emph{om.}';
    } else {
	my @words;
	foreach my $word ( $xpc->findnodes( 'tei:w', $rdg ) ) {
	    my @word_nodes = $word->childNodes();
	    my $word_str = '';
	    my $punct = '';
	    # In theory we could have a special c element in the middle
	    # of a word.  Look at the text nodes in a loop.
	    foreach( @word_nodes ) {
		if( $_->nodeName eq '#text' ) {
		    $word_str .= $_->data;
		} elsif( $_->nodeName eq 'c' 
			 && $_->hasAttribute( 'type' )
			 && $_->getAttribute( 'type' ) eq 'punct' ) {
		    $punct .= $_->textContent;
		}
	    }

	    if( $is_lemma &&
		exists( $Words::Armenian::PROPER_NAMES{ $word_str } ) ) {
		# Make any names proper names.
		$word_str = $Words::Armenian::PROPER_NAMES{ $word_str };
	    }

	    my $word_id = $word->getAttribute( 'xml:id' );
	    if( $false_lemma && $word_id ) {
		my $xpathExp = 'tei:witDetail[@target=' . "'\#$word_id' and "
		    . '@type=\'punctuation\']';
		my @details = $xpc->findnodes( $xpathExp, $rdg );
		foreach my $det ( @details ) {
		    if( $det->getAttribute( 'wit' ) =~ /\#A/ ) {
			$punct .= $det->textContent;
		    }
		}
	    }
	    push( @words, $word_str . $punct );
	}
	if( @words ) {
	    $out_str = '\\arm{' . join( ' ', @words ) . '}';
	}
    }
    return( $out_str );
}

sub _add_hash_entry {
    my( $hash, $key, $entry ) = @_;
    if( exists( $hash->{$key} ) ) {
	push( @{$hash->{$key}}, $entry );
    } else {
	$hash->{$key} = [ $entry ];
    }
}

sub invert_hash {
    my ( $hash, $plaintext_keys ) = @_;
    my %new_hash;
    foreach my $key ( keys %$hash ) {
	my $val = $hash->{$key};
	my $valkey = $val;
	if( $plaintext_keys 
	    && ref( $val ) ) {
	    $valkey = $plaintext_keys->{ scalar( $val ) };
	    warn( "No plaintext value given for $val" ) unless $valkey;
	}
	if( exists ( $new_hash{$valkey} ) ) {
	    push( @{$new_hash{$valkey}}, $key );
	} else {
	    $new_hash{$valkey} = [ $key ];
	}
    }
    return %new_hash;
}

__DATA__
\section{List of witnesses} 

__WITNESSLIST__

\pagebreak
\section{Text}
