package ncritic::Controller::Collate;
use Encode qw/ encode_utf8 decode_utf8 /;
use JSON qw( encode_json );
use Moose;
use namespace::autoclean;
use Text::TEI::Collate;

BEGIN { extends 'Catalyst::Controller' }

=head1 NAME

ncritic::Controller::Root - Controller for ncritic text collation

=head1 DESCRIPTION

A collection of related microservices, each of which exports functionality from the Text::TEI::Collate library. This controller handles actual collation.

=head1 METHODS

=head2 index

The root page (/collate)

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;
    $c->stash->{template} = 'collateform.tt2';	
}

## This is the list of output MIME types we recognize, and which 'as_*' 
## function we call in the collator for each one.

my %output_action = (
	'application/xml' => 'TEI',
	'application/json' => 'JSON',
	'application/graphml+xml' => 'GraphML',
	'image/svg+xml' => 'SVG',
	'application/xhtml+xml' => 'HTML',
	'text/html' => 'HTML'
	);

sub run_collation :Local {
	my( $self, $c ) = @_;
	# If called interactively, we have params 'display', 'output', 'witnesses'
	# If called non-interactively, we look at headers and content.
	my( $json, $format );
	if( $c->request->params->{interactive} ) {
		$json = encode_utf8( $c->request->params->{witnesses} );
		$format = _restore_format( $c->request->params->{output} );
	} else {
		# The body is actually a File::Temp object; this is undocumented but 
		# so it seems to be.
		my $fh = $c->request->body;
		my @lines = <$fh>;
		$json = join( '', @lines );
		$format = $c->request->header( 'Accept' );
	}
	$c->log->debug( "Requested format $format");
	# Run the collation from our JSON string.
	# TODO exception handling!
	my $collator = Text::TEI::Collate->new();
	my @manuscripts = $collator->read_source( $json );
	$c->log->debug( "Parsed " . scalar(@manuscripts) . " mss from the JSON");
	$collator->align( @manuscripts );
	# Now we have a list of Text::TEI::Manuscript objects.  Time to figure out 
	# how to render them.
	if( $output_action{$format} eq 'HTML' ) {
		$c->stash->{template} = 'collation_bare_html.tt2';
		$c->stash->{mss} = \@manuscripts;
		$c->forward( 'View::HTML')
			unless $c->request->params->{interactive};
	} else {
		my $action = "to_" . lc( $output_action{$format} );
		my $view = "View::" . $output_action{$format};
		unless( $action ) {
			$c->stash->{error_msg} = 'Format $format not supported';
		}
		$c->stash->{result} = $collator->$action( @manuscripts );
		$c->forward( $view );
	}
}

sub _restore_format {
	# Small helper function to get around the inability of form values to 
	# contain a '+' character.
	my $format = shift;
	if( $format eq 'application/graphml'
		|| $format eq 'image/svg' ) {
			$format .= '+xml';
	}
	return $format;
}

=head2 collate/doc

Usage information for the tokenization microservice.

=cut

sub doc :Local {
    my( $self, $c ) = @_;
    $c->stash->{template} = 'collatedoc.tt2';
}

=head1 AUTHOR

Tara L Andrews

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
