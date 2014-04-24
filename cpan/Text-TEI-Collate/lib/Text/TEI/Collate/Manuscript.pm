package Text::TEI::Collate::Manuscript;

use vars qw( $VERSION %assigned_sigla %tags );
use Moose;
use Moose::Util::TypeConstraints;
use Text::TEI::Collate::Error;
use Text::TEI::Collate::Word;
use XML::LibXML;
use XML::Easy::Syntax qw( $xml10_name_rx );

$VERSION = "1.1";
%assigned_sigla = ();

subtype 'SourceType',
	as 'Str',
	where { $_ =~ /^(xmldesc|plaintext|json)$/ },
	message { 'Source type must be one of xmldesc, plaintext, json' };
	
subtype 'Sigil',
	as 'Str',
	where { $_ =~ /\A$xml10_name_rx\z/ },
	message { 'Sigil must be a valid XML attribute string' };

has 'sigil' => (
	is => 'rw',
	isa => 'Sigil', 
	default => sub { auto_assign_sigil() },
	);

has 'identifier' => (
	is => 'rw',
	isa => 'Str',
	default => 'Unidentified ms',
	);

has 'settlement' => (
	is => 'rw',
	isa => 'Str',
	);

has 'repository' => (
	is => 'rw',
	isa => 'Str',
	);

has 'idno' => (
	is => 'rw',
	isa => 'Str',
	);

has 'sourcetype' => (
	is => 'ro',
	isa => 'SourceType',
	required => 1, 
);

has 'language' => (
    is => 'ro',
    isa => 'Str',
    default => 'Default',
    );

has 'source' => (  # Can be XML obj, JSON data struct, or string.
	is => 'ro',
	required => 1,
	writer => '_set_source',
);

has 'msdesc' => (  # if we started with a TEI doc
	is => 'ro',
	isa => 'XML::LibXML::Element',
	predicate => 'has_msdesc',
	writer => '_save_msdesc',
	);

has 'words' => (
	is => 'ro',
	isa => 'ArrayRef[Text::TEI::Collate::Word]',
	default => sub { [] },
	writer => 'replace_words',
);

has '_xpc' => (
	is => 'ro',
	isa => 'XML::LibXML::XPathContext',
	writer => '_set_xpc',
	clearer => '_clear_xpc',
);

has 'collated' => (
    is => 'rw',
    isa => 'Bool',
    default => undef,
    );

no Moose::Util::TypeConstraints;

=head1 NAME

Text::TEI::Collate::Manuscript - represent a manuscript text for collation

=head1 DESCRIPTION

Text::TEI::Collate::Manuscript is an object that describes a manuscript.

=head1 CONSTRUCTOR

=head2 new

Creates a new manuscript object.  This would normally be called via read_source in L<Text::TEI::Collate>; however, the following options (apart from those listed in
ACCESSORS below) are usually sufficient:

=over 4

=item *

B<sourcetype> - Can be one of xmldesc (that is, TEI parallel-segmentation), json (see L<http://gregor.middell.net/collatex/> for a description of the JSON format used), or plaintext.

=item *

B<source> - For sourcetype 'xmldesc', this should be an XML::LibXML object representing the document.  For sourcetype 'json', it should be the data object parsed from JSON.  For sourcetype 'plaintext', it should be the text as a string.

=item *

B<sigil> - The sigil for this manuscript. See description in ACCESSORS below.

=back

=head1 ACCESSORS

=head2 sigil

The sigil by which to identify this manuscript, which must conform to the specification for XML attribute strings (broadly speaking, it must begin with a letter and can have only a few sorts of punctuation characters in it.)

=head2 identifier

A freeform name by which to identify the manuscript, which may be longer than the sigil.  Defaults to 'Unidentified ms', but will be taken from the TEI msName attribute, or constructed from the settlement and idno if supplied.

=head2 settlement

The city, town, etc. where the manuscript is held. Will be read from the TEI msDesc element if supplied.

=head2 repository

The institution that holds the manuscript. Will be read from the TEI msDesc element if supplied.

=head2 idno

The identification or call number of the manuscript.  Will be read from the TEI msDesc element if supplied.

=head2 sourcetype

=head2 source

See the documentation for 'new' above.

=head2 language

The name of the applicable L<Text::TEI::Collate::Lang> module for language handling. Usually inherited from the language set in the L<Text::TEI::Collate> object.

=head2 words

The array of L<Text::TEI::Collate::Word> objects that form the manuscript text.

=cut

sub BUILD {
	my $self = shift;
	my $init_sub = '_init_from_' . $self->sourcetype;
	$self->$init_sub( $self->source );
	$assigned_sigla{$self->sigil} = 1;
	# Remove our XML / source objects; we no longer need them.
	$self->_clear_xpc;
	$self->_set_source( 0 );
	return $self;
}

sub _init_from_xmldesc {
	my( $self, $xmlobj ) = @_;
	unless( $xmlobj->nodeName eq 'TEI' ) {
		throw( ident => "bad source", 
		       message => "Source XML must be TEI (this is " . $xmlobj->nodeName . ")" );
	}

	# Set up the tags we need, with or without namespaces.
	map { $tags{$_} = "//$_" } qw/ msDesc msName settlement repository idno p lg /;
	# Set up our XPath object
	my $xpc = XML::LibXML::XPathContext->new( $xmlobj );
	# Use namespace-aware tags if we have to 
	if( $xmlobj->namespaceURI ) {
	    $xpc->registerNs( 'tei', $xmlobj->namespaceURI );
	    map { $tags{$_} = "//tei:$_" } keys %tags;
	}
	$self->_set_xpc( $xpc );

	# Get the identifier
	if( my $desc = $xpc->find( $tags{msDesc} ) ) {
		my $descnode = $desc->get_node(1);
		$self->_save_msdesc( $descnode );
		# First try to use settlement/repository/idno.
		my( $setNode, $reposNode, $idNode ) =
			( $xpc->find( $tags{settlement}, $descnode )->get_node(1),
			  $xpc->find( $tags{repository}, $descnode )->get_node(1),
			  $xpc->find( $tags{idno}, $descnode )->get_node(1) );
		$self->settlement( $setNode ? $setNode->textContent : '' );
		$self->repository( $reposNode ? $reposNode->textContent : '' );
		$self->idno( $idNode ? $idNode->textContent : '' );
		if( $self->settlement && $self->idno ) {
	    	$self->identifier( join( ' ', $self->{'settlement'}, $self->{'idno'} ) );
		} else {
		    # Look for an msName.
		    my $msNameNode = $xpc->find( $tags{msName}, $descnode )->get_node(1);
		    if( $msNameNode ) {
                $self->identifier( $msNameNode->textContent );
            } else {
                # We have an msDesc but who knows what is in it?
                my $desc = $descnode->textContent;
                $desc =~ s/\n/ /gs;
                $desc =~ s/\s+/ /g;
                $self->identifier( $desc );
            }
        }
        if( $descnode->hasAttribute('xml:id') ) {
			$self->sigil( $descnode->getAttribute('xml:id') );
		} else {
			$self->auto_assign_sigil();
		}
	} else {
	    throw( ident => "bad source",
	           message => "Could not find manuscript description element in TEI header" );
	}

	# Now get the words out.
	# Assume for now one body text, since "more than one text per
	# file" could mean anything.  May eventually want to allow
	# collation of "Nth text in this manuscript", or of "all texts in
	# this manuscript against each other."
	my @words;
	my @textnodes = $xmlobj->getElementsByTagName( 'text' );
	my $teitext = $textnodes[0];
	if( $teitext ) {
		@words = _tokenize_text( $self, $teitext );
	} else {
	    throw( ident => "bad source",
	           message => "No text element in document '" . $self->{'identifier'} . "!" );
	}
	
	$self->replace_words( \@words );
}

sub _tokenize_text {
	my( $self, $teitext ) = @_;
	# Strip out the words.
	# TODO: this could use spec consultation.
	my @words;
	my $xpc = $self->_xpc;
	my @divs = $xpc->findnodes( '//*[starts-with(name(.), "div")]', $teitext );
	foreach( @divs ) {
		my $place_str;
		if( my $n = $_->getAttribute( 'n' ) ) {
			$place_str = '__DIV_' . $n . '__';
		} else {
			$place_str = '__DIV__';
		}
		push( @words, $self->_read_paragraphs_or_lines( $_, $place_str ) );
	}  # foreach <div/>
    
	# But maybe we don't have any divs.  Just paragraphs.
	unless( @divs ) {
		push( @words, $self->_read_paragraphs_or_lines( $teitext ) );
	}
	return @words;
}

sub _read_paragraphs_or_lines {
	my( $self, $element, $divmarker ) = @_;

	my @words;
	my $xpc = $self->_xpc;
	my $xpexpr = '.' . $tags{p} . '|.' . $tags{lg};
 	my @pgraphs = $xpc->findnodes( $xpexpr, $element );
    return () unless @pgraphs;
	foreach my $pg( @pgraphs ) {
		# If this paragraph is the descendant of a note element,
		# skip it.
		my @noop_container = $xpc->findnodes( 'ancestor::note', $pg );
		next if scalar @noop_container;
		# If there are any #text nodes that are direct children of
		# this paragraph, the whole thing needs to be processed.
		if( my @textnodes = $xpc->findnodes( 'child::text()', $pg ) ) {
			# We have to split the words by whitespace.
			my $string = _get_text_from_node( $pg );
			my @pg_words = $self->_split_words( $string );
			# Set the relevant sectioning markers on the first word, if we
			# are using word objects.
			if( ref( $pg_words[0] ) eq 'Text::TEI::Collate::Word' ) {
				my $placeholder = uc( $pg->nodeName );
				$placeholder .= '_' . $pg->getAttribute( 'n' )
					if $pg->getAttribute( 'n' );
				if( $divmarker ) {
					$pg_words[0]->add_placeholder( $divmarker );
					$divmarker = undef;
				}
				$pg_words[0]->add_placeholder( "__${placeholder}__" );
			}
			push( @words, @pg_words );
		} else {  # if everything is wrapped in w / seg tags
			# Get the text of each node
			my $first_word = 1;
			foreach my $c ( $pg->childNodes() ) {
				# Trickier.  Need to parse the component tags.
				my $text;
				$text = _get_text_from_node( $c );
				# Some of the nodes might come back with multiple words.
				# TODO: make a better check for this
				my @textwords = split( /\s+/, $text );
				print STDERR "DEBUG: space found in element node "
					. $c->nodeName . "\n" if scalar @textwords > 1;
				foreach( @textwords ) {
					my $w = Text::TEI::Collate::Word->new( 'string' => $_,
						'ms_sigil' => $self->sigil,
						'language' => $self->language );
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
	my $word_excluded = $node->nodeName =~ /^(lb|pb|#comment)$/;
	foreach my $c ($node->childNodes() ) {
		if ( $c->nodeName =~ /^[lp]b$/ ) {
			# Set a flag that strips leading whitespace until we
			# get to the next bit of non-whitespace.
			$strip_leading_space = 1;
		} elsif ( $c->nodeName eq 'del'
				  || $c->nodeName eq 'fw'	 # for catchwords
				  || $c->nodeName eq 'sic'
				  || $c->nodeName eq 'note'	 #TODO: decide how to deal with notes
				  || $c->textContent eq '' 
				  || ref( $c ) eq 'XML::LibXML::Comment' ) {
			$word_excluded = 1;
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
	throw( ident => "text not found",
	       tags => [ $node->nodeName ],
	       message => "No text found in node " . $node->nodeName )
	    unless $text || $word_excluded;
	return $text;
}

sub _split_words {
	my( $self, $string ) = @_;
 	my @raw_words = split( /\s+/, $string );
 	my @words;
	foreach my $w ( @raw_words ) {
		my %opts = ( 'string' => $w, 'ms_sigil' => $self->sigil );
		$opts{'language'} = $self->language;
		my $w_obj = Text::TEI::Collate::Word->new( %opts );
 		# Skip any words that have been canonized out of existence.
		next if( length( $w_obj->word ) == 0 );
		push( @words, $w_obj );
 	}
 	return @words;
}

sub _init_from_json {
	my( $self, $wit ) = @_;
	$self->sigil( $wit->{'id'} );
	$self->identifier( $wit->{'name'} || $wit->{'id'} );
	my @words;
	if( exists $wit->{'content'} ) {
		# We need to tokenize the text ourselves.
		@words = _split_words( $self, $wit->{'content'} );
	} elsif( exists $wit->{'tokens'} ) {
		# We have a bunch of pretokenized words.
		foreach my $token ( @{$wit->{'tokens'}} ) {
			my $w_obj = Text::TEI::Collate::Word->new( 
				'json' => $token,
				'ms_sigil' => $self->sigil );
			push( @words, $w_obj );
		}
	}
	$self->replace_words( \@words );
}

sub _init_from_plaintext {
    my( $self, $str ) = @_;
    my @words = _split_words( $self, $str );
	$self->replace_words( \@words );
}

{
	my $curr_auto_sigil = 0;
	sub auto_assign_sigil {
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
		$curr_auto_sigil++;
		return $curr_sig;
	}
	
}

=head1 OUTPUT METHODS

=head2 tokenize_as_json

Returns a JSON serialization of the Manuscript object, of the form:

 { id: $self->sigil, name: $self->identifier, tokens: [ WORDLIST ] }

where each Word object in the word list is serialized as

 { t: $w->word, c: $w->canonical_form, n: $w->comparison_form,
   punctuation: [ $w->punctuation ], placeholders: [ $w->placeholders ] }
   
This method optionally takes a list of array indices to skip when serializing
the wordlist (useful when we want to exclude certain special tokens.)

=cut

sub tokenize_as_json {
	my $self = shift;
	my %skiprow;
	map { $skiprow{$_} = 1 } @_;

	my @wordlist;
	foreach my $i ( 0 .. $#{$self->words} ) {
	    next if $skiprow{$i};
	    my $w = $self->words->[$i];
		push( @wordlist, $w->json_serialize );
    }
	return { 
		'id' => $self->sigil,
		'tokens' => \@wordlist,
		'name' => $self->identifier,
	};
}

sub throw {
    Text::TEI::Collate::Error->throw( @_ );
}

no Moose;
__PACKAGE__->meta->make_immutable;

my $end_msg = 'get a printing press already';

=head1 BUGS / TODO

Many things.  Tests for instance.  I shall enumerate them later.


=head1 AUTHOR

Tara L Andrews E<lt>aurum@cpan.orgE<gt>
