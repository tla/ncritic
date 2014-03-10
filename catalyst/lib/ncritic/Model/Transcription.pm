package ncritic::Model::Transcription;
use Moose;
use namespace::autoclean;
use XML::LibXML;
use XML::LibXML::XPathContext;

extends 'Catalyst::Model';

has 'xml' => (
	is => 'ro',
	isa => 'XML::LibXML::Document',
	predicate => 'has_xml',
	writer => '_set_xmlobj'
	);
	
has 'text' => (
	is => 'ro',
	isa => 'Str',
	predicate => 'has_text',
	writer => 'set_text'
	);
	
sub set_xml {
	my $self = shift;
	my $p = XML::LibXML->new();
	my $doc = $p->parse_string( @_ );
	$self->_set_xmlobj( $doc );
}

sub as_html {
	my( $self ) = @_;
	my $textroot = $self->xml;
	return unless $textroot;
	my $xpc = _xpc_for_el( $textroot );
	# Sigil and name, that's easy
	my $sigil = $xpc->findvalue( '//tei:msDesc/attribute::xml:id' );
	my @msid = ( 
		$xpc->findvalue( '//tei:msIdentifier/tei:settlement' ),
		$xpc->findvalue( '//tei:msIdentifier/tei:repository' ),
		$xpc->findvalue( '//tei:msIdentifier/tei:idno' ) );
	my $msidstr;
	if( $msid[0] && $msid [1] ) {
		$msidstr = sprintf( "%s, %s %s", @msid );
	} else {
		$msidstr = sprintf( "%s %s", $msid[0] || $msid[1], $msid[2] );
	}
	my $return_hash = { 'textsigil' => $sigil,
		'textidentifier' => $msidstr };
	# Description blurb also not too hard
	$return_hash->{'textdescription'} = join( '',
		map { $_->toString } $xpc->findnodes( '//tei:msDesc/tei:p' ) );
	# Now comes the fun part - parse the body.
	$return_hash->{'textcontent'} = _html_transform( 
		$xpc->findnodes( '/tei:TEI/tei:text/tei:body' ),
		$xpc->exists( '//tei:cb' ) );
	return $return_hash;
}

sub _html_transform {
	my( $element, $usecolumns ) = @_;
	my %span_map = (
		'add' => 'addition',
		'del' => 'deletion',
		'abbr|num' => 'number',
		'hi' => 'highlight',
		'ex' => 'expansion',
		'expan' => 'expansion',
		);
	my @return_words;
	## NONRECURSING ELEMENTS
	if( $element->nodeType == XML_TEXT_NODE ) {
		my $text = $element->data;
		$text =~ s/^\s+//gs;
		$text =~ s/\s+$//gs;
		push( @return_words, $text );
	} elsif( $element->nodeName eq 'w' ) {
		# Simple word, just the text content.
		push( @return_words, $element->textContent . ' ' );
	} elsif( $element->nodeName eq 'lb' ) {
		push( @return_words, '<br/>' );
	} elsif( $element->nodeName eq 'damage' ) {
		my $len = $element->getAttribute('extent');
		push( @return_words, 'X' x $len );


	## RECURSING ELEMENTS
	} elsif( $element->nodeName =~ /^(body|seg|subst|num)$/ ) {
		# No wrapping, just pass-through
		@return_words = map { _html_transform( $_, $usecolumns ) } $element->childNodes;
		# but if it's a segword, put in a space.
		push( @return_words, ' ' ) if $element->nodeName eq 'seg';
	} elsif( $element->nodeName eq 'div' ) {
		# Section marker, then recurse
		my $secnum = $element->hasAttribute('n') ? $element->getAttribute('n') : '';
		push( @return_words, sprintf( "<div class=\"section\">\x{A7} %s</div>", $secnum ) );
		push( @return_words, map { _html_transform( $_, $usecolumns ) } $element->childNodes );

	} elsif( exists $span_map{$element->nodeName} ) {
		# Span wrapping
		my $spantype = $span_map{$element->nodeName};
		push( @return_words, "<span class=\"$spantype\">" );
		push( @return_words, map { _html_transform( $_, $usecolumns ) } $element->childNodes );
		push( @return_words, '</span>' );

	} elsif( $element->nodeName eq 'p' ) {
		# Paragraph wrapping
		push( @return_words, '<p>' );
		push( @return_words, map { _html_transform( $_, $usecolumns ) } $element->childNodes );
		push( @return_words, '</p>' );

	} elsif( $element->nodeName eq 'abbr' 
		&& $element->parentNode->nodeName eq 'num' ) {
		# A special case
		push( @return_words, "<span class=\"number\">" );
		push( @return_words, map { _html_transform( $_, $usecolumns ) } $element->childNodes );
		push( @return_words, '</span>' );


	## OTHER ELEMENTS
	} elsif( $element->nodeName eq 'pb' ) {
		# Now we get to the more complicated one.
		# Close the preceding paragraph if necessary, then a div, then reopen
		# a paragraph if necessary.
		my $xpc = _xpc_for_el( $element );
		my $midpg = $xpc->exists( 'ancestor::tei:p' );
		push( @return_words, '</p>' ) if $midpg;
		push( @return_words, '</td></tr></table>' ) if $usecolumns;
		push( @return_words, '<div class="pagenum">' );
		push( @return_words, $element->getAttribute('n') );
		push( @return_words, '</div>' );
		push( @return_words, '<table class="pagecolumn"><tr><td class="left">' )
			if $usecolumns;
		push( @return_words, '<p class="followpg">' ) if $midpg;
	} elsif( $element->nodeName eq 'cb' ) {
		## usecolumns had better be 1.
		my $xpc = _xpc_for_el( $element );
		my $midpg = $xpc->exists( 'ancestor::tei:p' );
		push( @return_words, '</p>' ) if $midpg;
		push( @return_words, '</td><td class="right">' );
		push( @return_words, '<p class="followpg">' ) if $midpg;
	}

	return join( '', @return_words );
}
sub _xpc_for_el {
	my $el = shift;
	my $xpc = XML::LibXML::XPathContext->new( $el );
	$xpc->registerNs( 'tei', 'http://www.tei-c.org/ns/1.0' );
	return $xpc;
}

=head1 NAME

ncritic::Model::Transcription - Catalyst Model

=head1 DESCRIPTION

Catalyst Model.


=encoding utf8

=head1 AUTHOR

Tara L Andrews

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
