package ncritic::View::TEI;

use strict;
use base 'Catalyst::View';
use Encode qw( decode_utf8 );

sub process {
	my( $self, $c ) = @_;
	$c->res->content_type( 'application/xml' );
	$c->res->content_encoding( 'UTF-8' );
	$c->res->output( decode_utf8( $c->stash->{result}->toString(1) ) );
}

1;