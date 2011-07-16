package ncritic::Controller::TokenizeTEI;
use JSON;
use Moose;
use namespace::autoclean;
use Text::TEI::Collate;

BEGIN { extends 'Catalyst::Controller' }

=head1 NAME

ncritic::Controller::TokenizeTEI - Controller for ncritic text tokenization

=head1 DESCRIPTION

A collection of related microservices, each of which exports functionality from the Text::TEI::Collate library. This controller handles TEI XML word tokenization.

=head1 METHODS

=head2 tokenizetei

The base page for JSON tokenization of TEI manuscript files

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;
    $c->stash->{template} = 'tokenizeform.tt2';
}

=head2 tokenizetei/run_tokenize

URL to request for the actual tokenization.  Expects a POST request with a TEI file in the contents.

=cut

sub run_tokenize :Local {
    my( $self, $c ) = @_;

    my $parser = XML::LibXML->new();
    my $teitext;
	my $display = $c->request->params->{'display'};
	my $jsonresponse;
    eval {
        $teitext = $parser->parse_string( $c->request->params->{'xmltext'} );
    };
    if( $@ ) {
        my $error_msg = "Could not parse string as XML: $@\n"
            . "Original string: ''" . $c->request->params->{'xmltext'}
 			. "''\n";
        # TODO save form values
		if( $display ) {
			$c->stash->{error_msg} = $error_msg;
		} else {
			$jsonresponse = { 'error' => $error_msg };
		}
    } else {
        my $ms = Text::TEI::Collate::Manuscript->new( 
				'source' => $teitext->documentElement,
				'sourcetype' => 'xmldesc',
			);
		$jsonresponse = $ms->tokenize_as_json();
        if( $c->request->params->{'display'} ) {
            $c->stash->{word_tokens} = $jsonresponse->{'tokens'};
        } 
    }
	# Display whatever result we got.
	if( $display ) {
			$c->stash->{template} = 'tokenize_result.tt2';
	} else {
		$c->stash->{result} = $jsonresponse;
		$c->forward( 'View::JSON' );
	}
}

=head2 tokenizetei/doc

Usage information for the tokenization microservice.

=cut

sub doc :Local {
    my( $self, $c ) = @_;
    $c->stash->{template} = 'tokenizedoc.tt2';
}

=head1 AUTHOR

Tara L Andrews

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
