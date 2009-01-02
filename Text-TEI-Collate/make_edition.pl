#!/usr/bin/perl -w -CDS

use strict;
use lib 'lib';
use Data::Dumper;
use Text::WagnerFischer::Armenian qw( distance );
use Text::TEI::Collate;
use Words::Armenian;
use XML::LibXML;

eval { no warnings; binmode $DB::OUT, ":utf8"; };

my( @files ) = @ARGV;

# and how fuzzy a match we can tolerate.
my $fuzziness = "50";  # this is n%

my $aligner = Text::TEI::Collate->new( 'fuzziness' => $fuzziness,
				       'debug' => 0,
				       'distance_sub' => \&Text::WagnerFischer::Armenian::distance,
				       'canonizer' => \&Words::Armenian::canonize_word,
				       'TEI' => 1,
    );


my @results = $aligner->align( @files );

my $ns_uri = 'http://www.tei-c.org/ns/1.0';
my ( $doc, $body ) = make_tei_doc( @results );

# Get the new base.  This should have all the links.
my $initial_base = $aligner->generate_base( map { $_->words } @results );
# Undef if not begun, 1 if begun and not ended, 0 if ended
my $app_id_ctr = 0;
my %text_active;
my %text_on_vacation;  # We all need a break sometimes.
my $in_app = 0;
my @app_waiting = ();
foreach my $idx ( 0 .. $#{$initial_base} ) {
    # Mark which texts are on duty
    foreach my $w ( map { $_->words->[$idx] } @results ) {
	$text_active{$w->ms_sigil} = 0 if $w->special && $w->special eq 'END';
	$text_on_vacation{$w->ms_sigil} = 1 
	    if $w->special && $w->special eq 'BEGINGAP';
    }

    # Get all the words; if all active texts are accounted for make the
    # single word an app.  If not, open/add to an app until the next row
    # in which all active texts are accounted for.
    my $word_obj = $initial_base->[$idx];
    my %text_unseen;
    map { $text_unseen{$_} = 1 if ( $text_active{$_} 
				    && !$text_on_vacation{$_} ) } 
        keys( %text_active );
    if( keys( %text_unseen ) ) {
	my @links = $word_obj->links;
	my @variants = $word_obj->variants;
	
	my @line_words;
	# The main word makes a group in %line_words, and then each variant
	# makes its own group.
	push( @line_words, class_words( $word_obj, \%text_unseen ) );
	foreach( @variants ) {
	    push( @line_words, class_words( $_, \%text_unseen ) );
	}
	
	# Either make the apparatus entry, or defer it.
	if( keys( %text_unseen ) ) {
	    push( @app_waiting, \@line_words );
	    $in_app = 1;
	} else {
	    if( $in_app ) {
		make_app( @app_waiting );
		@app_waiting = ();
		$in_app = 0;
	    }
	    make_app( \@line_words );
	}
    }

    # Mark which texts will now turn up
    foreach my $w ( map { $_->words->[$idx] } @results ) {
	$text_active{$w->ms_sigil} = 1 
	    if $w->special && $w->special eq 'BEGIN';
	$text_on_vacation{$w->ms_sigil} = 0 
	    if $w->special && $w->special eq 'ENDGAP';
    }
}

print $doc->toString(1);
print STDERR "Done.\n";

sub make_tei_doc {
    my @mss = @_;
    my $doc = XML::LibXML->createDocument( '1.0', 'UTF-8' );
    $doc->createProcessingInstruction( 'oxygen', 
			       'RNGSchema="tei_ms_crit.rng" type="xml"' );
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
	addNewChild( $ns_uri, 'p' );
    
    # Set the root...
    $doc->setDocumentElement( $root );
    # ...and return the doc and the body
    return( $doc, $body_p );
}

# Returns a hashref that has looked at the punct-free forms of each
# word and grouped the identical witnesses.  Take each ms we see out
# of the 'unseen' array that was passed in.
	# line_words = { word1 => [ s1, s2, ... ],
	#                word2 => [ s3, s4, ... ] },
	#              { other1 => [ s1, s2, ... ]
	#                other2 => [ s3, s4, ... ] },
	#              { meta => 'yes',
	#                sections => { div => [ s2, ... ],
	#                              p   => [ s2, s6, ... ], },
	#                punct => { '\x{554}' => [ s3, ... ] }, },

sub class_words {
    my( $word_obj, $unseen ) = @_;
    my $varhash = {};
    my $meta = {};
    _add_word_to_varhash( $varhash, $meta, $word_obj );
    delete $unseen->{ $word_obj->ms_sigil };
    foreach my $w ( $word_obj->links ) {
	_add_word_to_varhash( $varhash, $meta, $w );
	delete $unseen->{ $w->ms_sigil };
    }
    if( keys %$meta ) {
	$varhash->{'meta'} = $meta;
    }
    return $varhash;
}

# general utility function
sub _add_hash_entry {
    my( $hash, $key, $entry ) = @_;
    if( exists( $hash->{$key} ) ) {
	push( @{$hash->{$key}}, $entry );
    } else {
	$hash->{$key} = [ $entry ];
    }
}

# utility function for class_words
sub _add_word_to_varhash {
    my( $varhash, $meta, $word_obj ) = @_;
    _add_hash_entry( $varhash, $word_obj->word, $word_obj->ms_sigil );
    if( $word_obj->punctuation ) {
	$meta->{'punct'} = {} unless $meta->{'punct'};
	foreach my $punct( $word_obj->punctuation ) {
	    _add_hash_entry( $meta->{'punct'}, $punct,
			     $word_obj->ms_sigil );
	}
    }
    if( $word_obj->placeholders ) {
	$meta->{'sections'} = {} unless $meta->{'sections'};
	foreach my $ph( $word_obj->placeholders ) {
	    _add_hash_entry( $meta->{'sections'}, $ph, $word_obj->ms_sigil );
	}
    }
}

# Write out the apparatus entry to our root element.
sub make_app {
    my( @app_entries ) = @_;
    my $app = $body->addNewChild( $ns_uri, 'app' );
    $app->setAttribute( 'xml:id', "App$app_id_ctr" );
    $app_id_ctr++;
    if( scalar( @app_entries ) == 1 ) {
	my $line_entry = $app_entries[0];
	my $single_reading = scalar( @$line_entry ) == 1;
	foreach my $entry ( @$line_entry ) {
	    my $meta;
	    my $el;
	    if( $single_reading ) {
		$el = $app;
	    } else {
		my $rdg_grp = $app->addNewChild( $ns_uri, 'rdgGrp' );
		$rdg_grp->setAttribute( 'type', 'subvariants' );
		$el = $rdg_grp;
	    }
	    foreach my $rdg_word ( keys %$entry ) {
		if( $rdg_word eq 'meta' ) {
		    $meta = $entry->{$rdg_word};
		    next;
		}
		my $wits = $entry->{$rdg_word};
		my $wit_string = _make_wit_string( @$wits );
		my $rdg = $el->addNewChild( $ns_uri, 'rdg' );
		$rdg->setAttribute( 'wit', $wit_string );
		$rdg->appendText( $rdg_word );
	    }
	    add_meta_info( $app, $meta ) if $meta;
	}
    } else {
	# Combine the entries into distinct phrases, keyed by sigil.
	my %phrases;
	# Keep track of the meta-information we have seen.  It will be
	# placemarked via the $mmidx.
	my $mmidx = 0;
	my %meta_mark;
	foreach my $entry ( @app_entries ) {
	    foreach my $reading ( @$entry ) {
		my $meta;
		if ( exists $reading->{'meta'} ) {
		    $meta = delete $reading->{'meta'};
		    $meta_mark{++$mmidx} = $meta;
		}
		foreach my $word ( keys %$reading ) {
		    foreach my $sigil ( @{$reading->{$word}} ) {
			my $wordstr = $word;
			$wordstr .= '_META_MARK_' . $mmidx . '_'
			    if $meta;
			if( $phrases{$sigil} ) {
			    $phrases{$sigil} .= " $wordstr";
			} else {
			    $phrases{$sigil} = $wordstr;
			}
		    }
		}
	    }
	}
	
	# Now invert the hash, so to speak.
	my %distinct_phrases = invert_hash( %phrases );
	foreach my $phrase ( keys %distinct_phrases ) {
	    my $wit_string = _make_wit_string( @{$distinct_phrases{$phrase}} );
	    my $rdg = $app->addNewChild( $ns_uri, 'rdg' );
	    $rdg->setAttribute( 'wit', $wit_string );
	    metamark_subst( $rdg, $phrase, \%meta_mark );
	}
	# Sanity check - at this point, all the entries should have
	# been deleted from every hash in %meta_mark.
	foreach my $m ( values %meta_mark ) {
	    warn "Some witDetail got omitted!" if scalar( keys( %$m ) );
	}
    }
}

sub metamark_subst {
    my( $rdg, $phrase, $meta_marks ) = @_;
    while( $phrase =~ /^(.*?)_META_MARK_(\d+)_(.*)$/ ) {
	my( $text, $mmidx, $rest ) = ( $1, $2, $3 );
	$rdg->appendText( $text );
	add_meta_info( $rdg, $meta_marks->{$mmidx} );
	$phrase = $rest;
    }
    if( $phrase ) {
	$rdg->appendText( $phrase );
    }
}

sub add_meta_info {
    my( $element, $meta ) = @_;
    # Find an XML id.
    my $xmlid;
    if( $element->hasAttribute( 'xml:id' ) ) {
	$xmlid = $element->getAttribute( 'xml:id' );
    } elsif( $element->parentNode()->hasAttribute( 'xml:id' ) ) {
	$xmlid = $element->parentNode()->getAttribute( 'xml:id' );
    } else {
	warn "Could not find ID for element!";
	$xmlid = 'NONE';
    }
    # See if the element in question has a witness restriction.
    my %relevant_witnesses;
    if( $element->hasAttribute( 'wit' ) ) {
	my @wits = map { substr( $_, 1 ) } 
	               split( /\s+/, $element->getAttribute( 'wit' ) );
	@relevant_witnesses{@wits} = ( 1 ) x scalar @wits;
    }

    foreach my $key ( qw( sections punct ) ) {
	if( $meta->{$key} ) {
	    foreach my $item ( keys %{$meta->{$key}} ) {
		my @wits = @{$meta->{$key}->{$item}};
		if( keys %relevant_witnesses ) {
		    my $relevant = 0;
		    foreach ( @wits ) {
			if( $relevant_witnesses{$_} ) {
			    $relevant = 1;
			    last;
			}
		    }
		    next unless $relevant;
		}
		my $wit_string = _make_wit_string( @wits );
		my $witDetail = $element->addNewChild( $ns_uri, 'witDetail' );
		$witDetail->setAttribute( 'target', '#'.$xmlid );
		$witDetail->setAttribute( 'wit', $wit_string );
		my $type = $key eq 'punct' ? 'punctuation' : 'sectionDivision';
		$witDetail->setAttribute( 'type', $type );
		$witDetail->appendText( $item );
		# Use this to check that all meta tags got used
		delete $meta->{$key}->{$item};
	    }
	    delete $meta->{$key} unless keys( %{$meta->{$key}} )
	}
    }
}

sub _make_wit_string {
    return join( ' ', map { '#'.$_ } @_ );
}

# general utility function
sub invert_hash {
    my %hash = @_;
    my %new_hash;
    foreach my $key ( keys %hash ) {
	my $val = $hash{$key};
	if( exists ( $new_hash{$val} ) ) {
	    push( @{$new_hash{$val}}, $key );
	} else {
	    $new_hash{$val} = [ $key ];
	}
    }
    return %new_hash;
}
	
