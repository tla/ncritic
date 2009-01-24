#!/usr/bin/perl -w -CDS

use strict;
use lib 'lib';
use Getopt::Long;
use Words::Armenian;
use XML::LibXML;

eval { no warnings; binmode $DB::OUT, ":utf8"; };

my( $infile, $outfile, $lang_module );

GetOptions( 
    'i|infile=s' => \$infile,
    'o|outfile=s' => \$outfile,
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

my %SPELLINGS = %Words::Armenian::SPELLINGS;
my %PREFIXES = %Words::Armenian::PREFIXES;
my %SUFFIXES = %Words::Armenian::SUFFIXES;

my $ns_uri = 'http://www.tei-c.org/ns/1.0';
my $parser = XML::LibXML->new();
my $doc = $parser->parse_file( $infile );
my $xpc = XML::LibXML::XPathContext->new( $doc );
$xpc->registerNs( 'tei', $ns_uri );

# This is where the action happens.
make_edition( $doc );
print_results();
print STDERR "Done.\n";

sub make_edition {
    my ( $doc ) = @_;

    # TODO: separate appLists for each element that can be in <text/>
    my $appList = $xpc->find( '//tei:app', $doc );
    
    my $context = [];
    foreach my $app( $appList->get_nodelist() ) {
	process_app( $app, $context );
    }
    return $doc;
}

sub process_app {
    my( $app, $context ) = @_;
    
    # Now, for each thing in the app node list, do the following:
    # - Look for section breaks, ask user if we want one
    # - Un-app any words that have no divergence
    # - For each rdgGrp, check %SPELLINGS and ask if necessary
    #   - hmm, need a %NOTSPELLINGS.
    # - Ask what we can't figure out
    # - Ask about punctuation (maybe as a last pass? )

    # If it already has a lemma, it is processed.
    # TODO: add option for reprocessing
    my $id = $app->getAttribute( 'xml:id' );
    my $curr_lemma;
    my @new_context;
    if( my @lemmas = $app->getChildrenByTagName( 'lem' ) ) {
	print STDERR "app $id already has a lemma\n";
	$curr_lemma = $lemmas[0];
    } else {
	print "Context: " . join( ' ', @$context ) . "\n\n";
	
	print STDERR "Looking at app $id\n";
	# Get the chidren of this app entry
	my @contents = $app->childNodes();
	# The children should be either readings or rdgGrps.
	my( @group, @reading );
	foreach my $child( @contents ) {
	    my $node = $child->nodeName;
	    if( $node eq 'rdgGrp' ) {
		push( @group, $child );
	    } elsif( $node eq 'rdg' ) {
		push( @reading, $child );
	    } else {
		warn "Unexpected app child node $node"
		    unless $node eq '#text';
	    }
	}
	if( @reading && @group ) {
	    warn "Found mixed rdg and rdgGrp in app; " . 
		"treating top-level readings as one group";
	}
	my @to_process;
	foreach my $rdgGrp ( @group ) {
	    push( @to_process, $rdgGrp->childNodes() );
	} 
	push( @to_process, \@reading );
	# This return value is not necessarily a lemma.  Display
	# it differently if not.
	$curr_lemma = process_reading( $app, @to_process );
    }

    # Now add the words from the new lemma to the context.
    foreach my $word ( $curr_lemma->getChildrenByTagName( 'w' ) ) {
	push( @new_context, $word->textContent() );
    }
    unless( $curr_lemma->nodeName eq 'lem' ) {
	# Surround the thing in some brackets so we know it isn't real.
	unshift( @new_context, '[' );
	push( @new_context, ']' );
    }
    push( @$context, @new_context );
    while( scalar @$context > 15 ) {
	shift @$context;
    }
}

sub process_reading {
    my( $app, @set ) = @_;
    
    # We need to know where we are with our sectioning.
    my $cur_p = $app->parentNode;
    my $cur_sec;
    if( $cur_p->parentNode eq 'div' ) {
	$cur_sec = $cur_p->parentNode;
    }
    my $first_app_id = $xpc->find( 'tei:app[1]/@xml:id', $cur_p )
	->string_value;
    
    my %readings;
    my $rdg_idx = 0;
    my %witDetails;
    my $detail_idx = 0;
    foreach my $rdg_group ( @set ) {
	# Each group has a list of readings.
	foreach my $rdg ( @$rdg_group ) {
	    # Each reading has one or more words and zero or more
	    # witDetails.
	    unless ( $rdg->nodeName eq 'rdg') {
		warn "something that is not a reading is in a reading group!"
		    . $rdg->nodeName;
		next;
	    }
	    # Assign each reading to an index, and get the words out while
	    # we have the xpc object.
	    $readings{ ++$rdg_idx } = { 'rdg' => $rdg,
					'words' => $xpc->find( 'tei:w', $rdg ) };
	    
	    # Now find the witDetails.
	    my $detailList = $xpc->find( 'tei:witDetail', $rdg );
	    foreach my $det ( $detailList->get_nodelist ) {
		my $val = $det->textContent();
		my $target = $det->getAttribute( 'target' );
		my $detailWitList = $det->getAttribute( 'wit' );
		my $detailType = $det->getAttribute( 'type' );
		# Note the structure of this hash...
		$witDetails{++$detail_idx} = { 'target' => $target, 
					       'wit' => $detailWitList,
					       'type' => $detailType,
					       'obj' => $det,
					       'val' => $val,
		};
	    }
	}  # foreach reading
    }  # foreach rdgGrp; we're ignoring the separation of groups at the moment.
    
    my $need_answer = 0;  # For sanity check
    my $return_rdg;
    my %word_from_id;
    if( keys %readings > 1 ) {
	print "Available readings:\n";
    } else {
	# There is only one reading.  Lemmatize it.
	my $rdg = $readings{1}->{'rdg'};
	$rdg->setNodeName( 'lem' );
	$return_rdg = $rdg;
    }
    foreach my $disp_idx ( keys %readings ) {
	my $rdg = $readings{$disp_idx}->{'rdg'};
	my @display_text;
	foreach my $word_obj ( $readings{$disp_idx}->{'words'}->get_nodelist ) {
	    my $word = $word_obj->textContent;
	    if( $word_obj->hasAttribute( 'xml:id' ) ) {
		$word_from_id{ '#' . $word_obj->getAttribute( 'xml:id' ) }
		= { 'string' => $word, 'obj' => $word_obj };
	    }
	    push( @display_text, $word );
	}
	my $witnesses = $rdg->getAttribute( 'wit' );
	printf( "%-2s: %s (%s )\n", $disp_idx, 
		join( ' ', @display_text ), $witnesses );
	$need_answer = 1 unless $return_rdg;
    }
    
    # Do we need to assign punctuation or section divisions?
    my %detailClasses;
    if( keys %witDetails ) {
	print "\nManuscript details:\n";
	foreach my $idx ( keys %witDetails ) {
	    my $detailData = $witDetails{$idx};
	    my $detail = $detailData->{'val'};
	    my $type = $detailData->{'type'};
	    
	    # Safeguard...
	    unless( $type =~ /^(section_div|punctuation)$/ ) {
		warn( "Unrecognized witDetail type $type" );
		next;
	    }
	    # Section division is irrelevant if we are already at
	    # the start of a p or div.
	    next if( $type eq 'section_div'
		     && $app->getAttribute( 'xml:id' ) eq $first_app_id );
	    
	    # Record the fact that a decision needs to be made...
	    $detailClasses{$type} = 1;
	    $need_answer = 1;
	    
	    # and print the choice.
	    my $pos = $type eq 'section_div' ? 'before' : 'after';
	    print "$idx: Witness(es) " . $detailData->{'wit'} .
		" contain a $detail $pos " 
		. $word_from_id{ $detailData->{'target'} }->{'string'} . "\n";
	}
    }
    
    if( $need_answer ) {
	print " --> ";
	my $picked = defined( $return_rdg );
	my $detail_needed = scalar keys( %detailClasses );
	until( $picked && !$detail_needed ) {
	    my $answer = <STDIN>;
	    chomp $answer;
	    if( $answer =~ /^q(uit)?\s*$/ ) {
		print_results();
		exit;
	    } elsif( $answer =~ /^(accept|a)\s+(\d+)/ ) {
		$return_rdg = $readings{$2}->{'rdg'};
		$return_rdg->setNodeName( 'lem' );
		$picked = 1;
	    } elsif( $answer =~ /^(accept\s+detail|a\s*d)\s+(\d+)/ ) {
		## TODO deal with Armenian mid-word punctuation
		my $id = $2;
		my $detail = $witDetails{$id};
		# The punctuation should get added to the main reading if
		# applicable; otherwise to the reading on which it was
		# observed.
		my $word_obj = $word_from_id{ $detail->{'target'} }->{'obj'};
		# Add the required detail to the relevant word.
		#  TODO currently assumes append, i.e. assumes punct
		if( $detail->{'type'} eq 'punctuation' ) {
		    $word_obj->appendText( $detail->{'val'} );
		    $word_obj->parentNode->removeChild( $detail->{'obj'} );
		} else {
		    print STDERR "TODO: close out a paragraph and/or div here\n";
		}
		$detail_needed--;
	    } elsif( $answer =~ /^n(ext)?\s*$/ ) {
		# Return the first reading for context purposes, but don't 
		# lemmatize it.
		$return_rdg = $readings{1}->{'rdg'};
		$picked = 1;
		$detail_needed = 0;
	    } elsif( $answer =~ /^sp(ell(ing)?)?\s+(\d+)\s+(\d+)/ ) {
		my( $var, $std ) = ( $3, $4 );
		$SPELLINGS{$var} = $std;
	    } elsif( $answer =~ /^emend\s+(\S+.*)$/ ) {
		# Put a placeholder lemma in this apparatus, and add
		# an editorial note with the text.
		# TODO: Can't enter the emendation as utf-8 at the terminal.
		# This will need a different interface someday.
		my $ed_note = $1;
		# Add the unattested lemma...
		$return_rdg = XML::LibXML::Element->new( 'lem' );
		$return_rdg->setAttribute( 'resp', '#tla' );
		$return_rdg->appendTextChild( 'wit', '[unattested]' );
		$app->insertBefore( $return_rdg, $app->firstChild() );
		# ...and add the explanatory note.
		my $note_obj = XML::LibXML::Element->new( 'note' );
		$note_obj->setAttribute( 'type', 'emendation' );
		# TODO Should so not be hardcoded.
		$note_obj->setAttribute( 'resp', '#tla' );
		$note_obj->appendText( $ed_note );
		$app->appendChild( $note_obj );
	    } elsif( $answer =~ /^h(elp)?/ ) {
		print 'Available commands:
accept (#)
accept detail (#)
spelling (# alternate) (# canonical)
emend (note)
next
help
quit
 -->';
	    } else {
		print 'Huh? (h for help) -->';
	    }
	}
    }
    return $return_rdg;
}

sub print_results {
    # Write it all out.
    $doc->toFile( $outfile, 1 );
    foreach ( sort keys %SPELLINGS ) {
	print "    $_ => " . $SPELLINGS{$_} . ",\n";
    }
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
