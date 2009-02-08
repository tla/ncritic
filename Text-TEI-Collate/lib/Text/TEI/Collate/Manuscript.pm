package Text::TEI::Collate::Manuscript;

use strict;
use vars qw( $VERSION );
use Text::TEI::Collate::Word;

$VERSION = "0.01";

=head1 DESCRIPTION

Text::TEI::Collate::Manuscript is an object that describes a manuscript.

=head1 METHODS

=head2 new

Creates a new manuscript object.  Right now this is just a container.

=cut

my %assigned_sigla = ();

sub new {
    my $proto = shift;
    my %opts = @_;
    my $class = ref( $proto ) || $proto;
    my $self = { 'sigil' => undef,
		 'identifier' => 'Unidentified ms',
		 'canonizer' => undef,
		 'comparator' => undef,
		 'type' => 'plaintext',
		 %opts,
    };
    bless $self, $class;

    my $type = delete $self->{'type'};
    die "Cannot initialize manuscript without XML or string text"     
	unless( $type =~ /^(xmldesc|plaintext)$/ );
    my $source = delete $self->{'source'};
    die "Cannot initialize manuscript without a data source"
	unless defined $source;
    
    if( $type eq 'xmldesc' ) {
        $self->_init_from_xml( $source );
	unless( exists $self->{'sigil'} ) {
	    # Should not actually get here
	    warn( 'No sigil definition occurred!  Danger Will Robinson!' );
	}
    } else {
	$self->auto_assign_sigil();
	$self->_init_from_string( $source );
    }
    
    $assigned_sigla{$self->{'sigil'}} = 1;
    
    return $self;
}

sub _init_from_xml {
    my( $self, $xmlobj ) = @_;
    unless( $xmlobj->nodeName eq 'TEI' ) {
	warn "Manuscript initialization needs a TEI document!";
	return;
    }
    # Get the identifier
    my $xpc = XML::LibXML::XPathContext->new( $xmlobj );
    $xpc->registerNs( 'tei', $xmlobj->namespaceURI );
    if( my $desc = $xpc->find( '//tei:msDesc' ) ) {
	my $descnode = $desc->get_node(1);
	my( $setNode, $reposNode, $idNode ) =
	    ( $xpc->find( '//tei:settlement' )->get_node(1),
	      $xpc->find( '//tei:repository' )->get_node(1),
	      $xpc->find( '//tei:idno' )->get_node(1) );
	$self->{'settlement'} = $setNode ? $setNode->textContent : '';
	$self->{'repository'} = $reposNode ? $reposNode->textContent : '';
	$self->{'idno'} = $idNode ? $idNode->textContent : '';
	if( $descnode->hasAttribute('xml:id') ) {
	    $self->{'sigil'} = $descnode->getAttribute('xml:id');
	} else {
	    $self->auto_assign_sigil();
	}
    } else {
	warn "Could not find manuscript description in doc; creating generic manuscript";
	$self->{'identifier'} = '==Unknown manuscript==';
    }
    $self->{'identifier'} = join( ' ', $self->{'settlement'}, $self->{'idno'} );

    # Now get the words out.
    # Assume for now one body text, since "more than one text per
    # file" could mean anything.  May eventually want to allow
    # collation of "Nth text in this manuscript", or of "all texts in
    # this manuscript against each other."
    my @words;
    my @textnodes = $xmlobj->getElementsByTagName( 'text' );
    my $teitext = $textnodes[0];
    if( $teitext ) {
	# Strip out the words.
	# TODO: this could use spec consultation.
	my @divs = $teitext->getElementsByTagName( 'div' );
	foreach( @divs ) {
	    my $place_str;
	    if( my $n = $_->getAttribute( 'n' ) ) {
		$place_str = '__DIV_' . $n . '__';
	    } else {
		$place_str = '__DIV__';
	    }
	    push( @words, $self->_read_paragraphs( $_, $place_str ) );
	}  # foreach <div/>
	
	# But maybe we don't have any divs.  Just paragraphs.
	unless( @divs ) {
	    push( @words, $self->_read_paragraphs( $teitext ) );
	}
    } else {
	warn "No text in document '" . $self->{'identifier'} . "!";
    }
    
    $self->{'words'} = \@words;
}

sub _read_paragraphs {
    my( $self, $element, $divmarker ) = @_;

    my @words;
    my @pgraphs = $element->getElementsByTagName( 'p' );
    return () unless @pgraphs;
    foreach my $pg( @pgraphs ) {
	# If there are any #text nodes that are direct children of
	# this paragraph, the whole thing needs to be processed.
	my $xpc = XML::LibXML::XPathContext->new( $pg );
	$xpc->registerNs( 'tei', $pg->namespaceURI );
	
	if( my @textnodes = $xpc->findnodes( 'child::text()' ) ) {
	    # We have to split the words by whitespace.
	    my $string = _get_text_from_node( $pg );
	    my @pg_words = $self->_split_words( $string );
	    # Set the relevant sectioning markers on the first word.
	    if( $divmarker ) {
		$pg_words[0]->add_placeholder( $divmarker );
		$divmarker = undef;
	    }
	    $pg_words[0]->add_placeholder( '__PG__' );
	    push( @words, @pg_words );
	} else {  # if everything is wrapped in w / seg tags
	    # Get the text of each node
	    my $first_word = 1;
	    foreach my $c ( $pg->childNodes() ) {
		# Trickier.  Need to parse the component tags.
		my $text = _get_text_from_node( $c );
		unless( defined $text ) {
		    print STDERR "WARNING: no text in node " . $c->nodeName 
			. "\n" unless $c->nodeName eq 'lb';
		    next;
		}
		# Some of the nodes might come back with multiple words.
		# TODO: make a better check for this
		my @textwords = split( /\s+/, $text );
		print STDERR "DEBUG: space found in element node "
		    . $c->nodeName . "\n" if scalar @textwords > 1;
		foreach( @textwords ) {
		    my $w = Text::TEI::Collate::Word->new( 'string' => $_,
				   'ms_sigil' => $self->{'sigil'},
				   'comparator' => $self->{'comparator'},
				   'canonizer' => $self->{'canonizer'} );
		    if( $first_word ) {
			$first_word = 0;
			# Set the relevant sectioning markers 
			if( $divmarker ) {
			    $w->add_placeholder( $divmarker );
			    $divmarker = undef;
			}
			$w->add_placeholder( '__PG__' );
		    }
		    push( @words, $w );
		}
	    }
	}
    }

    return @words;
}

# Given a node, whether a paragraph or a word, reconstruct the text
# string that ought to come out.  If it is a word or a seg, sanity
# check it for lack of spaces.  

sub _get_text_from_node {
    my( $node ) = @_;
    my $text = '';
    # We can have an lb or pb in the middle of a word; if we do, the
    # whitespace (including \n) after the break becomes insignificant
    # and we want to nuke it.
    my $strip_leading_space = 0; 
    foreach my $c ($node->childNodes() ) {
	if( $c->nodeName eq 'num' 
	    && defined $c->getAttribute( 'value' ) ) {
	    # Push the number.
	    $text .= $c->getAttribute( 'value' );
	    # If this is just after a line/page break, return to normal behavior.
	    $strip_leading_space = 0;
	} elsif ( $c->nodeName =~ /^[lp]b$/ ) {
	    # Set a flag that strips leading whitespace until we
	    # get to the next bit of non-whitespace.
	    $strip_leading_space = 1;
	} elsif ( $c->nodeName eq 'del'
		  || $c->nodeName eq 'fw'    # for catchwords
		  || $c->nodeName eq 'sic'
		  || $c->nodeName eq 'note'  #TODO: decide how to deal with notes
		  || $c->textContent eq '' 
		  || ref( $c ) eq 'XML::LibXML::Comment' ) {
	    next;
	} else {
	    my $tagtxt;
	    if( ref( $c ) eq 'XML::LibXML::Text' ) {
		# A text node.
		$tagtxt = $c->textContent;
	    } else {
		$tagtxt = _get_text_from_node( $c );
	    }
	    if( $strip_leading_space ) {
		$tagtxt =~ s/^[\s\n]+//s;
		# Unset the flag as soon as we see non-whitespace.
		$strip_leading_space = 0 if $tagtxt;
	    }
	    $text .= $tagtxt;
	} 
    }
    # If this is in a w tag, strip all the whitespace.
    if( $node->nodeName eq 'w'
	|| ( $node->nodeName eq 'seg' 
	     && $node->getAttribute( 'type' ) eq 'word' ) ) {
	$text =~ s/\s+//g;
    }
    return $text;
}

sub _split_words {
    my( $self, $string ) = @_;
    my @raw_words = split( /\s+/, $string );
    my @words;
    foreach my $w ( @raw_words ) {
	my $w_obj = Text::TEI::Collate::Word->new( 'string' => $w,
						   'ms_sigil' => $self->{'sigil'},
						   'comparator' => $self->{'comparator'},
						   'canonizer' => $self->{'canonizer'} );
	# Skip any words that have been canonized out of existence.
	next if( length( $w_obj->word ) == 0 );
	
	push( @words, $w_obj );
    }
    return @words;
}

sub _init_from_string {
    my( $self, $str ) = @_;
    # Do we have a sigil?
    unless( $self->{'auto_sigla'} 
	    || $self->{'sigil'} ) {
	warn "No sigil defined!  Turning on auto_sigla.";
	$self->{'auto_sigla'} = 1;
    }

    # Now look at the string.
    my @words = $self->_split_words( $str );
    $self->{'words'} = \@words;

    return $self;
}

{
    my $curr_auto_sigil = 0;
    
    sub auto_assign_sigil {
	my $self = shift;
	my $curr_sig;
	until( $curr_sig ) {
	    if( $curr_auto_sigil > 25 ) {
		$curr_sig = chr( ( $curr_auto_sigil % 26 ) + 65 ) x int( $curr_auto_sigil / 26 + 1 );
	    } else {
		$curr_sig = chr( $curr_auto_sigil + 65 );
	    }
	    # Make sure it isn't in use
	    if( grep( /^$curr_sig$/, keys( %assigned_sigla ) ) > 0 ) {
		$curr_sig = undef;
		$curr_auto_sigil++;
	    }
	}
	$self->{sigil} = $curr_sig;
	$curr_auto_sigil++;
    }
    
}

sub identifier {
    my $self = shift;
    return ( exists $self->{'identifier'} ) ? $self->{'identifier'} : undef;
}

sub sigil {
    my $self = shift;
    return ( exists $self->{'sigil'} ) ? $self->{'sigil'} : undef;
}

sub words {
    my $self = shift;
    return ( exists $self->{'words'} 
	     && ref( $self->{'words'} ) eq 'ARRAY' ) ? $self->{'words'} : undef;
}

sub replace_words {
    my ( $self, $newtext ) = @_;
    unless( ref $newtext eq 'ARRAY' ) {
	warn "New text $newtext not an array ref; not replacing";
	return;
    }
    $self->{'words'} = $newtext;
}

my $end_msg = 'get a printing press already';

=head1 BUGS / TODO

Many things.  Tests for instance.  I shall enumerate them later.


=head1 AUTHOR

Tara L Andrews E<lt>aurum@cpan.orgE<gt>
